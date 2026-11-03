import 'package:flutter/material.dart';
import 'root_shell.dart';

/// Brief branded splash shown once at cold start: the logo scales/fades
/// in, holds for a moment, then hands off to the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  /// Loops for as long as the splash is shown — a glossy highlight
  /// sweeping across the background (not the logo/text), the usual
  /// visual cue that something's loading behind the scenes.
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack).drive(Tween(begin: 0.6, end: 1.0));
    _opacity = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6)).drive(Tween(begin: 0.0, end: 1.0));
    _controller.forward();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    _scheduleNext();
  }

  Future<void> _scheduleNext() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RootShell()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, _) {
              // Sweeps fully off-screen-left to off-screen-right each loop,
              // so the shine travels through and resets clean.
              final dx = -1.0 + 3.0 * _shimmerController.value;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(dx - 0.6, -1),
                    end: Alignment(dx + 0.6, 1),
                    colors: [colorScheme.primary, Colors.white.withOpacity(0.22), colorScheme.primary],
                    stops: const [0.35, 0.5, 0.65],
                  ),
                ),
              );
            },
          ),
          Center(
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The tightly-cropped square version (also used for the
                    // app icon) — the original logo_aplikasi.png is a wide
                    // 1024x559 file with lots of empty transparent margin
                    // around the circle, which BoxFit.contain would turn
                    // into an invisible gap above/below it here.
                    Image.asset('assets/images/app_icon_source.png', width: 128, height: 128, fit: BoxFit.contain),
                    const SizedBox(height: 6),
                    const Text(
                      'DailyGO',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Jadwal Teratur, Ongkos Terukur',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
