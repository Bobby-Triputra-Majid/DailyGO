import 'package:flutter/material.dart';

/// Fixed palette of icons selectable for a category. Keeping this as a
/// static const list (rather than looking icons up dynamically) ensures
/// Flutter's icon tree-shaker keeps the glyphs in the release build.
const List<IconData> categoryIconChoices = [
  Icons.local_taxi,
  Icons.directions_car,
  Icons.two_wheeler,
  Icons.attach_money,
  Icons.card_giftcard,
  Icons.payments,
  Icons.account_balance_wallet,
  Icons.work,
  Icons.savings,
  Icons.restaurant,
  Icons.local_gas_station,
  Icons.build,
  Icons.phone_android,
  Icons.shopping_cart,
  Icons.home,
  Icons.favorite,
  Icons.medical_services,
  Icons.school,
  Icons.pets,
  Icons.sports_esports,
  Icons.local_offer,
  Icons.handshake,
  Icons.category,
  Icons.more_horiz,
];

IconData iconFromCodePoint(int codePoint) {
  for (final icon in categoryIconChoices) {
    if (icon.codePoint == codePoint) return icon;
  }
  return Icons.category;
}

/// Fixed palette of colors (as ARGB ints) selectable for a category.
const List<int> categoryColorValues = [
  0xFF2E7D32,
  0xFF1565C0,
  0xFFF9A825,
  0xFFD84315,
  0xFF6A1B9A,
  0xFF00897B,
  0xFFAD1457,
  0xFF37474F,
  0xFFC62828,
  0xFF283593,
];
