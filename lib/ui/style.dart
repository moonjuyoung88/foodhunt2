import 'package:flutter/material.dart';

class Ui {
  static const bgTop = Color(0xFF2D2F6B);
  static const bgBottom = Color(0xFF14152F);
  static const panel = Color(0xFF23254F);
  static const panelLight = Color(0xFF34377A);
  static const belt = Color(0xFF3E4291);
  static const beltDot = Color(0xFF6A6FD0);
  static const boardBg = Color(0xFF191A3A);
  static const yellow = Color(0xFFFFC93C);
  static const pink = Color(0xFFFF5D8F);
  static const green = Color(0xFF4ADE80);
  static const text = Color(0xFFF4F4FF);
  static const textDim = Color(0xFFA9ACD9);

  static const background = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [bgTop, bgBottom],
    ),
  );

  static Color darken(Color c, [double f = 0.3]) =>
      Color.lerp(c, Colors.black, f)!;
  static Color lighten(Color c, [double f = 0.3]) =>
      Color.lerp(c, Colors.white, f)!;
  static bool isLight(Color c) => c.computeLuminance() > 0.55;
}

/// 눌리는 느낌이 나는 두툼한 버튼.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.child,
    required this.onTap,
    this.color = Ui.yellow,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    this.radius = 18,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsets padding;
  final double radius;
  final bool enabled;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.enabled ? widget.color : const Color(0xFF5A5C86);
    const depth = 5.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        margin: EdgeInsets.only(top: _down ? depth : 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(
              color: Ui.darken(c, 0.38),
              offset: Offset(0, _down ? 0 : depth),
            ),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: Ui.isLight(c) ? const Color(0xFF2A2140) : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(size: 22),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: const TextStyle(
              color: Ui.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Ui.yellow,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB8860B), width: size * 0.12),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.3,
        height: size * 0.3,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF1B8),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
