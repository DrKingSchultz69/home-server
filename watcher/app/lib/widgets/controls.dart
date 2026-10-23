import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Tracks hover and press so widgets can pick the kit's state colours.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.builder, this.onTap, this.enabled = true});

  final Widget Function(BuildContext context, bool hovered, bool pressed) builder;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: active ? (_) => setState(() => _down = true) : null,
        onTapUp: active ? (_) => setState(() => _down = false) : null,
        onTapCancel: active ? () => setState(() => _down = false) : null,
        onTap: active ? widget.onTap : null,
        child: widget.builder(context, active && _hover, active && _down),
      ),
    );
  }
}

class Spinner extends StatefulWidget {
  const Spinner({super.key, this.color = WColors.text, this.size = 18});
  final Color color;
  final double size;

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: _ArcPainter(widget.color)),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = Offset.zero & size;
    canvas.drawArc(r.deflate(1), 0, 4.71, false, p);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}

enum WButtonKind { primary, secondary, destructive, plain }

class WButton extends StatelessWidget {
  const WButton(
    this.label, {
    super.key,
    this.kind = WButtonKind.primary,
    this.onPressed,
    this.loading = false,
    this.small = false,
    this.expand = false,
  });

  final String label;
  final WButtonKind kind;
  final VoidCallback? onPressed;
  final bool loading;
  final bool small;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Pressable(
      onTap: loading ? null : onPressed,
      builder: (context, hover, down) {
        final (bg, fg, spin) = _colors(enabled, hover, down);
        final weight = kind == WButtonKind.secondary || kind == WButtonKind.plain ? FontWeight.w500 : FontWeight.w600;
        final child = loading
            ? Spinner(color: spin, size: 18)
            : Text(label,
                style: TextStyle(fontSize: small ? 13 : 15, fontWeight: weight, color: fg));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: small ? 36 : WSpace.hit,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(small ? 10 : WRadius.control)),
          child: child,
        );
      },
    );
  }

  (Color bg, Color fg, Color spin) _colors(bool enabled, bool hover, bool down) {
    switch (kind) {
      case WButtonKind.primary:
        if (!enabled) return (WColors.raised, WColors.disabled, WColors.text);
        return (down ? WColors.primaryPressed : hover ? WColors.primaryHover : WColors.primary, WColors.text, WColors.text);
      case WButtonKind.secondary:
        if (!enabled) return (WColors.surface, WColors.disabled, WColors.text);
        return (down ? WColors.raisedPressed : hover ? WColors.raisedHover : WColors.raised, WColors.text, WColors.text);
      case WButtonKind.destructive:
        if (!enabled) return (WColors.surface, WColors.disabled, WColors.down);
        if (down) return (WColors.down, WColors.text, WColors.text);
        return (WColors.tint(WColors.down, hover ? .22 : .15), WColors.down, WColors.down);
      case WButtonKind.plain:
        if (!enabled) return (Colors.transparent, WColors.disabled, WColors.primary);
        final bg = down ? WColors.tint(WColors.primary, .18) : hover ? WColors.tint(WColors.primary, .1) : Colors.transparent;
        return (bg, WColors.primary, WColors.primary);
    }
  }
}

class WIconButton extends StatelessWidget {
  const WIconButton({super.key, required this.icon, this.onPressed, this.tooltip});
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final b = Pressable(
      onTap: onPressed,
      builder: (context, hover, down) => Container(
        width: WSpace.hit,
        height: WSpace.hit,
        decoration: BoxDecoration(
          color: down ? WColors.raisedPressed : hover ? WColors.raisedHover : WColors.raised,
          borderRadius: BorderRadius.circular(WRadius.control),
        ),
        child: Icon(icon, size: 20, color: WColors.text),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

class WTextField extends StatefulWidget {
  const WTextField({
    super.key,
    this.hint,
    this.controller,
    this.error,
    this.enabled = true,
    this.obscure = false,
    this.leading,
    this.height = WSpace.hit,
    this.onChanged,
  });

  final String? hint;
  final TextEditingController? controller;
  final String? error;
  final bool enabled;
  final bool obscure;
  final IconData? leading;
  final double height;
  final ValueChanged<String>? onChanged;

  @override
  State<WTextField> createState() => _WTextFieldState();
}

class _WTextFieldState extends State<WTextField> {
  final _focus = FocusNode();
  late bool _hidden = widget.obscure;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = widget.error != null
        ? WColors.down
        : _focus.hasFocus
            ? WColors.primary
            : null;
    final field = Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: widget.enabled ? WColors.surface : WColors.inputDisabled,
        borderRadius: BorderRadius.circular(WRadius.control),
        boxShadow: ring == null ? null : [BoxShadow(color: ring, spreadRadius: 2)],
      ),
      child: Row(children: [
        if (widget.leading != null) ...[
          Icon(widget.leading, size: 16, color: WColors.secondary),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            obscureText: _hidden,
            onChanged: widget.onChanged,
            style: WText.body.copyWith(color: widget.enabled ? WColors.text : WColors.disabled),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: WText.body.copyWith(color: widget.enabled ? WColors.secondary : WColors.disabled),
            ),
          ),
        ),
        if (widget.obscure)
          GestureDetector(
            onTap: () => setState(() => _hidden = !_hidden),
            child: Text(_hidden ? 'Show' : 'Hide',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: WColors.primary)),
          ),
      ]),
    );
    if (widget.error == null) return field;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      field,
      const SizedBox(height: 6),
      Text(widget.error!, style: WText.caption.copyWith(color: WColors.down)),
    ]);
  }
}

/// iOS-style switch, 51x31, green when on.
class WToggle extends StatelessWidget {
  const WToggle({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: Pressable(
        onTap: enabled ? () => onChanged!(!value) : null,
        builder: (context, _, __) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 51,
          height: 31,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? WColors.ok : WColors.raisedHover,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 27,
              height: 27,
              decoration: const BoxDecoration(color: WColors.text, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

class WSegmented extends StatelessWidget {
  const WSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.mono = false,
    this.compact = false,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool mono;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: WColors.surface,
        borderRadius: BorderRadius.circular(compact ? 10 : WRadius.control),
      ),
      child: Row(children: [
        for (final o in options)
          Expanded(
            child: Pressable(
              onTap: () => onChanged(o),
              builder: (context, _, __) => AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(vertical: compact ? 7 : 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: o == selected ? WColors.raisedHover : Colors.transparent,
                  borderRadius: BorderRadius.circular(compact ? 8 : 10),
                ),
                child: Text(o,
                    style: TextStyle(
                      fontFamily: mono ? 'GeistMono' : 'Geist',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: o == selected ? WColors.text : WColors.secondary,
                    )),
              ),
            ),
          ),
      ]),
    );
  }
}
