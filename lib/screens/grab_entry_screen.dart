import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../providers/finance_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_period.dart';
import '../utils/grouping.dart';
import '../widgets/amount_field.dart';

/// Quick-entry screen for a Grab trip.
///
/// - Tunai (cash): driver types what was billed and what the customer
///   handed over; any extra cash (e.g. billed 7.000, given 7.700, no
///   change given back) is booked as a Tip.
/// - Non-Tunai (cashless): there's no separate billing step — the app
///   just records exactly what was received — so this just asks for
///   that amount, plus an optional manual Tip field (left blank = 0)
///   for any in-app tip Grab reports separately.
/// - Grab guarantees a minimum fare ([kGrabMinimumFare]). If the billed
///   amount is below that, the recorded "Ongkos Grab" is topped up to the
///   minimum automatically — this isn't a tip or a bonus, it's just how
///   Grab's payout works.
/// - Tunai trips can also have a system cut that isn't visible in the
///   cash itself — e.g. billed 16.000, customer hands over 17.000 cash,
///   but Grab's system only credits 14.000 as the fare. The optional
///   "Uang Bersih" field books that real net payout as the fare while the
///   Tip (here, 1.000 — 17.000 minus the 16.000 billed) is still worked
///   out from the cash alone.
///
/// Saving the trip returns to the previous screen right away.
/// Cara Bayar for a trip — Tunai and Non-Tunai go through the Grab app as
/// usual (minimum fare guarantee, possible system cut); Offline is a trip
/// flagged down outside the app, so none of that app-specific billing
/// applies and the money lands straight in Bank instead of Saldo Grab.
/// Offline otherwise uses the same simple form as Non-Tunai (an amount
/// plus an optional manual Tip) since there's no separate billing step
/// either way.
enum _PaymentMethod { tunai, nonTunai, offline }

class GrabEntryScreen extends StatefulWidget {
  /// When set, edits this trip in place (same fare/tip transaction ids,
  /// same groupId) instead of recording a brand-new one.
  final DisplayEntry? existing;

  const GrabEntryScreen({super.key, this.existing});

  @override
  State<GrabEntryScreen> createState() => _GrabEntryScreenState();
}

class _GrabEntryScreenState extends State<GrabEntryScreen> {
  final _fareCtrl = TextEditingController();
  final _receivedCtrl = TextEditingController();
  final _netPayoutCtrl = TextEditingController();
  final _nonTunaiTipCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _makanCtrl = TextEditingController();
  final _fareFocus = FocusNode();
  DateTime _date = nowWib();
  _PaymentMethod _method = _PaymentMethod.tunai;

  bool get _isCash => _method == _PaymentMethod.tunai;
  bool get _isOffline => _method == _PaymentMethod.offline;

  /// Non-tunai/Offline only — whether the Tip itself was handed over as physical
  /// cash (goes to dompet Cash) or through the app like the fare (goes
  /// to dompet Saldo Grab, pending withdrawal like the rest of the trip).
  bool _tipIsCash = false;
  bool _catatMakan = false;
  bool _telur = false;
  int _telurCount = 1;

  bool get _isEdit => widget.existing != null;

  /// The trip's existing tip transaction, if it had one — null for a
  /// brand-new trip, or an edited trip that never had a tip.
  TransactionModel? get _existingTip {
    final existing = widget.existing;
    if (existing == null) return null;
    for (final t in existing.transactions) {
      if (t.categoryId == 'tip') return t;
    }
    return null;
  }

  /// The trip's "potongan" row, if it had one — the other 'grab'-category
  /// transaction in the group besides the fare itself (see
  /// [FinanceProvider.addGrabTrip]).
  TransactionModel? get _existingPotongan {
    final existing = widget.existing;
    if (existing == null) return null;
    final fareId = existing.primary.id;
    for (final t in existing.transactions) {
      if (t.categoryId == 'grab' && t.id != fareId) return t;
    }
    return null;
  }

  static const List<double> _quickAmounts = [7000, 7700];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      final fare = existing.primary;
      final billedFare = fare.billedAmount ?? fare.amount;
      final tipAmount = _existingTip?.amount ?? 0;
      // Older trips saved before this field existed don't have it — fall
      // back to the old (shortage-unaware) reconstruction for those.
      final receivedAmount = fare.receivedAmount ?? (billedFare + tipAmount);
      if (fare.isOffline ?? false) {
        _method = _PaymentMethod.offline;
      } else if (fare.isCash ?? true) {
        _method = _PaymentMethod.tunai;
      } else {
        _method = _PaymentMethod.nonTunai;
      }
      _date = fare.date;
      _noteCtrl.text = fare.note ?? '';
      _fareCtrl.text = formatPlainThousands(billedFare);
      if (_isCash) {
        _receivedCtrl.text = formatPlainThousands(receivedAmount);
        if (fare.netPayoutAmount != null) {
          _netPayoutCtrl.text = formatPlainThousands(fare.netPayoutAmount!);
        }
      } else if (tipAmount > 0) {
        _nonTunaiTipCtrl.text = formatPlainThousands(tipAmount);
        _tipIsCash = _existingTip?.walletId == kWalletCash;
      }
    }
  }

  double get _fare => parseFormattedAmount(_fareCtrl.text);
  double get _received => parseFormattedAmount(_receivedCtrl.text);

  /// What to treat as "received" for both the preview and the actual
  /// save — if the field is still empty, assume exact payment (no tip,
  /// no shortage) rather than treating it as the customer paying zero.
  double get _receivedForCalc => _received > 0 ? _received : _fare;

  /// Cash trips only — what Grab's system actually credited as the fare,
  /// when that's less than the billed amount suggests (the system took a
  /// cut that isn't reflected in the cash handed over). Left blank = not
  /// known separately, so the usual billed/minimum-fare math is used.
  double? get _netPayout {
    final v = parseFormattedAmount(_netPayoutCtrl.text);
    return v > 0 ? v : null;
  }

  /// For non-cash, there's no separate billing step, so [_fare] is
  /// already what was received and the tip is just whatever was typed in
  /// the manual Tip field. For cash, the actual fare/tip split (which
  /// accounts for a possible shortage or a system cut) comes from the
  /// same formula the provider uses to save, so the preview always
  /// matches what's booked.
  double get _effectiveFare {
    if (_isCash) {
      return FinanceProvider.resolveFareAndTip(_fare, _receivedForCalc, netPayout: _netPayout).$1;
    }
    // Offline skips the minimum-fare guarantee — that's Grab's system, and
    // an offline trip never goes through it.
    if (_isOffline) return _fare;
    return _fare < kGrabMinimumFare ? kGrabMinimumFare : _fare;
  }

  double get _tip {
    if (_isCash) {
      return FinanceProvider.resolveFareAndTip(_fare, _receivedForCalc, netPayout: _netPayout).$2;
    }
    return parseFormattedAmount(_nonTunaiTipCtrl.text);
  }
  double get _makanAmount => parseFormattedAmount(_makanCtrl.text);

  @override
  void dispose() {
    _fareCtrl.dispose();
    _receivedCtrl.dispose();
    _netPayoutCtrl.dispose();
    _nonTunaiTipCtrl.dispose();
    _noteCtrl.dispose();
    _makanCtrl.dispose();
    _fareFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FinanceProvider>();
    final shortage = _isCash && _received > 0 && _received < _fare;
    final colorScheme = Theme.of(context).colorScheme;
    final total = _effectiveFare + _tip;
    final hargaTelur = provider.hargaTelur;
    final totalMakan = _makanAmount + (_telur ? _telurCount * hargaTelur : 0);

    // Meal cost only needs recording once a day — if a "Makan" expense
    // already exists for the selected date, lock the checkbox instead of
    // prompting for it again on every trip that day.
    final dayStart = DateTime(_date.year, _date.month, _date.day);
    final dayRange = PeriodRange(dayStart, dayStart.add(const Duration(days: 1)), '');
    final todaysMakan = provider.transactionsInRange(dayRange, categoryId: 'makan');
    final alreadyRecordedMakan = todaysMakan.isNotEmpty;
    final existingMakanTotal = todaysMakan.fold(0.0, (s, t) => s + t.amount);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Trip Grab' : 'Trip Grab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.onPrimaryContainer, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isOffline
                        ? 'Trip offline (di luar aplikasi) — cukup isi jumlah yang diterima, tidak ada minimal ongkos/potongan sistem.'
                        : 'Isi tagihan trip. Minimal ongkos Rp${formatPlainThousands(kGrabMinimumFare)} otomatis dari sistem. Kalau bayar tunai dan ada kelebihan uang, otomatis jadi Tip.',
                    style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Cara Bayar', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<_PaymentMethod>(
            segments: const [
              ButtonSegment(value: _PaymentMethod.tunai, label: Text('Tunai'), icon: Icon(Icons.payments_outlined)),
              ButtonSegment(value: _PaymentMethod.nonTunai, label: Text('Non-Tunai'), icon: Icon(Icons.credit_card)),
              ButtonSegment(value: _PaymentMethod.offline, label: Text('Offline'), icon: Icon(Icons.handshake_outlined)),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 20),
          AmountField(
            controller: _fareCtrl,
            label: _isCash ? 'Tagihan ke Customer' : 'Uang yang Didapat',
            autofocus: true,
            focusNode: _fareFocus,
            onChanged: (_) => setState(() {}),
          ),
          if (_isCash) ...[
            const SizedBox(height: 20),
            AmountField(
              controller: _receivedCtrl,
              label: 'Uang Diterima dari Customer',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Pas (tanpa tip)'),
                  onPressed: _fare <= 0 ? null : () => setState(() => _receivedCtrl.text = formatPlainThousands(_fare)),
                ),
                ..._quickAmounts.map(
                  (amt) => ActionChip(
                    label: Text(formatRupiah(amt, withSymbol: false)),
                    onPressed: () => setState(() => _receivedCtrl.text = formatPlainThousands(amt)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AmountField(
              controller: _netPayoutCtrl,
              label: 'Uang Bersih (opsional)',
              onChanged: (_) => setState(() {}),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Isi kalau pendapatan trip yang dikredit sistem Grab lebih kecil dari tagihan (ada potongan), walau customer bayar tunai sesuai tagihan/lebih. Kosongkan kalau tidak ada potongan.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            AmountField(
              controller: _nonTunaiTipCtrl,
              label: 'Tip',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _tipIsCash,
              onChanged: (v) => setState(() => _tipIsCash = v),
              title: const Text('Tip diterima tunai', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                _tipIsCash ? 'Masuk dompet Cash' : (_isOffline ? 'Masuk dompet Bank' : 'Masuk dompet Saldo Grab (lewat aplikasi)'),
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          ],
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(formatShortDate(_date)),
                ],
              ),
            ),
          ),
          if (!_isEdit && provider.aktifCatatMakan) ...[
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                CheckboxListTile(
                  value: _catatMakan && !alreadyRecordedMakan,
                  onChanged: alreadyRecordedMakan ? null : (v) => setState(() => _catatMakan = v ?? false),
                  title: const Text('Catat Biaya Makan'),
                  subtitle: alreadyRecordedMakan ? Text('Sudah dicatat hari ini: ${formatRupiah(existingMakanTotal)}') : null,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_catatMakan && !alreadyRecordedMakan) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: AmountField(controller: _makanCtrl, label: 'Biaya Makan', onChanged: (_) => setState(() {})),
                  ),
                  CheckboxListTile(
                    value: _telur,
                    onChanged: (v) => setState(() => _telur = v ?? false),
                    title: Text('+ Telur (Rp${formatPlainThousands(hargaTelur)} / butir), bisa diubah di Pengaturan'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_telur)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          const Text('Jumlah telur'),
                          const Spacer(),
                          IconButton(
                            onPressed: _telurCount > 1 ? () => setState(() => _telurCount--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$_telurCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            onPressed: () => setState(() => _telurCount++),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  if (totalMakan > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('Total Makan: ${formatRupiah(totalMakan)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ],
            ),
          ),
          ],
          const SizedBox(height: 20),
          if (shortage) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: colorScheme.errorContainer, borderRadius: BorderRadius.circular(10)),
              child: Text(
                'Uang yang diterima kurang ${formatRupiah(_fare - _received)} dari tagihan — tetap bisa disimpan.',
                style: TextStyle(color: colorScheme.onErrorContainer, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_fare > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _breakdownRow('Ongkos Grab', _effectiveFare, colorScheme.onTertiaryContainer),
                  if (_tip > 0) ...[
                    const SizedBox(height: 8),
                    _breakdownRow('Tip', _tip, colorScheme.onTertiaryContainer),
                  ],
                  if (_isCash && _netPayout != null) ...[
                    const SizedBox(height: 8),
                    _breakdownRow(
                      'Potongan Sistem',
                      -((_fare < kGrabMinimumFare ? kGrabMinimumFare : _fare) - _netPayout!),
                      colorScheme.onTertiaryContainer,
                    ),
                  ],
                  Divider(height: 20, color: colorScheme.onTertiaryContainer.withOpacity(0.25)),
                  _breakdownRow('Total Masuk', total, colorScheme.onTertiaryContainer, bold: true),
                  if (_isCash && _netPayout != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Uang tunai di tangan: ${formatRupiah(_receivedForCalc)}',
                        style: TextStyle(color: colorScheme.onTertiaryContainer.withOpacity(0.7), fontSize: 11.5),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Catatan'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _fare <= 0 ? null : () => _save(context, provider),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double value, Color color, {bool bold = false}) {
    final text = value < 0 ? '-${formatRupiah(-value)}' : formatRupiah(value);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(text, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: nowWib().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  Future<void> _save(BuildContext context, FinanceProvider provider) async {
    final receivedAmount = _isCash ? _receivedForCalc : (_fare + _tip);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final netPayoutAmount = _isCash ? _netPayout : null;

    if (_isEdit) {
      final existing = widget.existing!;
      await provider.updateGrabTrip(
        existingFare: existing.primary,
        groupId: existing.groupId!,
        existingTip: _existingTip,
        existingPotongan: _existingPotongan,
        fareAmount: _fare,
        receivedAmount: receivedAmount,
        date: _date,
        isCash: _isCash,
        note: note,
        netPayoutAmount: netPayoutAmount,
        tipIsCash: _tipIsCash,
        isOffline: _isOffline,
      );
      if (context.mounted) Navigator.pop(context);
      return;
    }

    await provider.addGrabTrip(
      fareAmount: _fare,
      receivedAmount: receivedAmount,
      date: _date,
      isCash: _isCash,
      note: note,
      netPayoutAmount: netPayoutAmount,
      tipIsCash: _tipIsCash,
      isOffline: _isOffline,
    );
    final dayStart = DateTime(_date.year, _date.month, _date.day);
    final dayRange = PeriodRange(dayStart, dayStart.add(const Duration(days: 1)), '');
    final alreadyRecordedMakan = provider.transactionsInRange(dayRange, categoryId: 'makan').isNotEmpty;
    final totalMakan = _makanAmount + (_telur ? _telurCount * provider.hargaTelur : 0);
    if (_catatMakan && !alreadyRecordedMakan && totalMakan > 0) {
      final telurNote = _telurCount == 1 ? 'Telur' : '$_telurCount Telur';
      await provider.addTransaction(TransactionModel(
        id: provider.generateId(),
        type: TxType.expense,
        amount: totalMakan,
        categoryId: 'makan',
        date: _date,
        note: _telur ? 'Makan + $telurNote' : 'Makan',
        groupLabel: 'Trip Grab',
        walletId: kWalletCash,
      ));
    }
    if (context.mounted) Navigator.pop(context);
  }
}
