// Design tokens from the Watcher UI Kit (Claude Design handoff, 2026-10-23).
// Dark only. Blue is the only interactive colour; teal is reserved for data.
import 'package:flutter/widgets.dart';

class WColors {
  WColors._();

  // Surfaces
  static const canvas = Color(0xFF050506); // outside the app frame
  static const base = Color(0xFF101011);
  static const surface = Color(0xFF1C1C1E);
  static const surfaceHover = Color(0xFF242426);
  static const raised = Color(0xFF2C2C2E);
  static const raisedHover = Color(0xFF3A3A3C);
  static const raisedPressed = Color(0xFF48484A);
  static const inputDisabled = Color(0xFF151517);
  static const logBg = Color(0xFF0A0A0B);
  static const separator = Color(0xFF2C2C2E);
  static const separatorOnRaised = Color(0xFF3A3A3C);

  // Text
  static const text = Color(0xFFF5F5F7);
  static const secondary = Color(0xFF8E8E93);
  static const disabled = Color(0xFF5A5A5E);
  static const checkBorder = Color(0xFF48484A);

  // Accents
  static const primary = Color(0xFF0A84FF);
  static const primaryHover = Color(0xFF3395FF);
  static const primaryPressed = Color(0xFF0070DB);
  static const data = Color(0xFF30D5C8);

  // Status
  static const ok = Color(0xFF30D158);
  static const warning = Color(0xFFFF9F0A);
  static const down = Color(0xFFFF453A);

  /// Status colour at 15% for badges and banners.
  static Color tint(Color c, [double opacity = .15]) => c.withValues(alpha: opacity);
}

enum WStatus { ok, warn, down, busy, unknown }

extension WStatusColors on WStatus {
  Color get color => switch (this) {
        WStatus.ok => WColors.ok,
        WStatus.warn => WColors.warning,
        WStatus.down => WColors.down,
        WStatus.busy => WColors.primary,
        WStatus.unknown => WColors.secondary,
      };

  Color get tint => this == WStatus.unknown ? WColors.raised : WColors.tint(color);
}

enum WRole { user, family, admin }

extension WRoleStyle on WRole {
  String get label => switch (this) {
        WRole.user => 'User',
        WRole.family => 'Family',
        WRole.admin => 'Admin',
      };
  Color get bg => switch (this) {
        WRole.user => WColors.raised,
        WRole.family => WColors.tint(WColors.data),
        WRole.admin => WColors.tint(WColors.primary, .18),
      };
  Color get fg => switch (this) {
        WRole.user => WColors.text,
        WRole.family => WColors.data,
        WRole.admin => WColors.primary,
      };
}

class WRadius {
  WRadius._();
  static const badge = 8.0;
  static const control = 12.0;
  static const card = 16.0;
  static const panel = 20.0;
}

class WSpace {
  WSpace._();
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Minimum hit target (dp).
  static const hit = 48.0;
}

class WText {
  WText._();
  static const _sans = 'Geist';
  static const _mono = 'GeistMono';
  static const _tab = [FontFeature.tabularFigures()];

  static const status = TextStyle(fontFamily: _sans, fontSize: 56, fontWeight: FontWeight.w700, letterSpacing: -2.24, height: 1, color: WColors.text);
  static const large = TextStyle(fontFamily: _sans, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -.6, color: WColors.text);
  static const pageTitle = TextStyle(fontFamily: _sans, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.52, color: WColors.text);
  static const title = TextStyle(fontFamily: _sans, fontSize: 17, fontWeight: FontWeight.w600, color: WColors.text);
  static const body = TextStyle(fontFamily: _sans, fontSize: 15, fontWeight: FontWeight.w400, color: WColors.text);
  static const bodyStrong = TextStyle(fontFamily: _sans, fontSize: 15, fontWeight: FontWeight.w600, color: WColors.text);
  static const caption = TextStyle(fontFamily: _sans, fontSize: 13, fontWeight: FontWeight.w400, color: WColors.secondary);
  static const label = TextStyle(fontFamily: _sans, fontSize: 12, fontWeight: FontWeight.w600, color: WColors.text);

  static const mono = TextStyle(fontFamily: _mono, fontSize: 13, fontWeight: FontWeight.w400, color: WColors.secondary, fontFeatures: _tab);
  static const monoValue = TextStyle(fontFamily: _mono, fontSize: 24, fontWeight: FontWeight.w500, color: WColors.text, fontFeatures: _tab);
  static const monoSmall = TextStyle(fontFamily: _mono, fontSize: 11, fontWeight: FontWeight.w400, color: WColors.secondary, fontFeatures: _tab);
  static const sectionLabel = TextStyle(fontFamily: _mono, fontSize: 12, letterSpacing: 1.2, color: WColors.secondary);
}
