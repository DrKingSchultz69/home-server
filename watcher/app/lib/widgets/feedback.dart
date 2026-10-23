import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'controls.dart';
import 'lists.dart';

class WBanner extends StatelessWidget {
  const WBanner({super.key, required this.color, required this.title, required this.body, this.action, this.onAction});
  final Color color;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: WColors.tint(color), borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: WText.bodyStrong),
              const SizedBox(height: 2),
              Text(body, style: WText.caption),
            ]),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, left: 8),
                child: Text(action!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: WColors.primary)),
              ),
            ),
        ]),
      );
}

/// Floating toast. `leading` is a dot colour or null when [loading].
class WToast extends StatelessWidget {
  const WToast({super.key, required this.message, this.dot, this.loading = false, this.action, this.trailingText, this.onAction});
  final String message;
  final Color? dot;
  final bool loading;
  final String? action;
  final String? trailingText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: WColors.raised,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, 12))],
        ),
        child: Row(children: [
          if (loading)
            const Spinner(color: WColors.primary, size: 14)
          else if (dot != null)
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: WText.body)),
          if (trailingText != null) Text(trailingText!, style: WText.mono),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: WText.bodyStrong.copyWith(color: WColors.primary)),
            ),
        ]),
      );
}

void showWToast(BuildContext context, WToast toast) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: toast,
    backgroundColor: Colors.transparent,
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    padding: EdgeInsets.zero,
    duration: const Duration(seconds: 3),
  ));
}

class SheetAction {
  const SheetAction(this.label, {this.destructive = false, this.onTap});
  final String label;
  final bool destructive;
  final VoidCallback? onTap;
}

/// Bottom sheet body: grabber, header, grouped actions.
class WActionSheet extends StatelessWidget {
  const WActionSheet({super.key, required this.header, required this.actions});
  final Widget header;
  final List<SheetAction> actions;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: WColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(WRadius.card)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(width: 36, height: 5, decoration: BoxDecoration(color: WColors.raisedPressed, borderRadius: BorderRadius.circular(3))),
            ),
            const SizedBox(height: 14),
            header,
            const SizedBox(height: 14),
            WGroup(
              color: WColors.raised,
              separator: WColors.separatorOnRaised,
              radius: WRadius.control,
              children: [
                for (final a in actions)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: a.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Text(a.label, style: WText.body.copyWith(color: a.destructive ? WColors.down : WColors.text)),
                    ),
                  ),
              ],
            ),
          ]),
        ),
      );
}

Future<T?> showWActionSheet<T>(BuildContext context, WActionSheet sheet) => showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (_) => sheet,
    );

/// Centred confirm dialog that names its target. Returns true when confirmed.
class WConfirmDialog extends StatelessWidget {
  const WConfirmDialog({super.key, required this.title, required this.message, required this.confirmLabel, this.destructive = true});
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 290,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: WColors.raised, borderRadius: BorderRadius.circular(WRadius.card)),
          child: Material(
            type: MaterialType.transparency,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                child: Column(children: [
                  Text(title, style: WText.title, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(message, style: WText.caption.copyWith(height: 1.45), textAlign: TextAlign.center),
                ]),
              ),
              Container(height: 1, color: WColors.separatorOnRaised),
              SizedBox(
                height: WSpace.hit,
                child: Row(children: [
                  Expanded(
                    child: _DialogButton('Cancel', color: WColors.primary, onTap: () => Navigator.pop(context, false)),
                  ),
                  Container(width: 1, color: WColors.separatorOnRaised),
                  Expanded(
                    child: _DialogButton(confirmLabel,
                        color: destructive ? WColors.down : WColors.primary, bold: true, onTap: () => Navigator.pop(context, true)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _DialogButton extends StatelessWidget {
  const _DialogButton(this.label, {required this.color, required this.onTap, this.bold = false});
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        builder: (context, hover, down) => Container(
          alignment: Alignment.center,
          color: down ? WColors.raisedPressed : hover ? WColors.raisedHover : Colors.transparent,
          child: Text(label, style: WText.body.copyWith(color: color, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
}

Future<bool> showWConfirm(BuildContext context, {required String title, required String message, required String confirmLabel, bool destructive = true}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .5),
    builder: (_) => WConfirmDialog(title: title, message: message, confirmLabel: confirmLabel, destructive: destructive),
  );
  return r ?? false;
}
