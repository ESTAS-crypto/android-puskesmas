import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_theme.dart';

/// Ikon kustom "Laut & Langit": 24px, garis 2px membulat + isian lembut (duotone).
/// Satu warna masuk, isian otomatis 18% dari warna itu.
class AppGlyph {
  AppGlyph._();
  static const home = 'home';
  static const report = 'report';
  static const patient = 'patient';
  static const users = 'users';
  static const userAdd = 'userAdd';
  static const history = 'history';
  static const export = 'export';
  static const shield = 'shield';
  static const crown = 'crown';
  static const code = 'code';
  static const heart = 'heart';
  static const camera = 'camera';
  static const trash = 'trash';
  static const edit = 'edit';
  static const check = 'check';
  static const tick = 'tick';
  static const cloud = 'cloud';
  static const update = 'update';
  static const spark = 'spark';
  static const bandage = 'bandage';
  static const trendUp = 'trendUp';
  static const search = 'search';
  static const back = 'back';
  static const chevron = 'chevron';
  static const plus = 'plus';
  static const arrow = 'arrow';
  static const warning = 'warning';
  static const logout = 'logout';
  static const login = 'login';
  static const heartPulse = 'heartPulse';
  static const chat = 'chat';
  static const flag = 'flag';
  static const pin = 'pin';
  static const idcard = 'idcard';
  static const eye = 'eye';
  static const eyeOff = 'eyeOff';
  static const lock = 'lock';
  static const mail = 'mail';
  static const hospital = 'hospital';
  static const drag = 'drag';
}

/// Pengganti `Icon`. Menerima AppGlyph (String) atau IconData biasa.
class AppIcon extends StatelessWidget {
  final Object glyph;
  final double? size;
  final Color? color;
  const AppIcon(this.glyph, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? AppTheme.text;
    if (glyph is IconData) return Icon(glyph as IconData, size: s, color: c);
    final body = _glyphs[glyph] ?? _glyphs['warning']!;
    final hex = '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<g opacity="${c.a}" stroke-linecap="round" stroke-linejoin="round">'
        '${body.replaceAll('{c}', hex)}</g></svg>';
    return ExcludeSemantics(child: SvgPicture.string(svg, width: s, height: s));
  }
}

const Map<String, String> _glyphs = {
  'home': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M4 11.5 12 5l8 6.5V20H4z"/><path fill="none" stroke="{c}" stroke-width="2" d="M4 11.5 12 5l8 6.5V20H4z"/><path fill="none" stroke="{c}" stroke-width="2" d="M12 12v5M9.5 14.5h5"/>',
  'report': '<rect fill="{c}" fill-opacity=".18" stroke="none" x="5" y="3" width="14" height="18" rx="3"/><rect fill="none" stroke="{c}" stroke-width="2" x="5" y="3" width="14" height="18" rx="3"/><path fill="none" stroke="{c}" stroke-width="2" d="M9 8h6M9 12h6M9 16h3"/>',
  'patient': '<circle fill="{c}" fill-opacity=".18" stroke="none" cx="12" cy="8" r="4"/><circle fill="none" stroke="{c}" stroke-width="2" cx="12" cy="8" r="4"/><path fill="none" stroke="{c}" stroke-width="2" d="M4.5 20c.8-3.6 3.8-5.5 7.5-5.5s6.7 1.9 7.5 5.5"/>',
  'users': '<circle fill="{c}" fill-opacity=".18" stroke="none" cx="9" cy="8" r="3.5"/><circle fill="none" stroke="{c}" stroke-width="2" cx="9" cy="8" r="3.5"/><path fill="none" stroke="{c}" stroke-width="2" d="M2.5 19.5c.6-3 3-4.8 6.5-4.8s5.9 1.8 6.5 4.8M16 4.8a3.5 3.5 0 010 6.4M18 14.9c2 .5 3.3 2 3.7 4.6"/>',
  'userAdd': '<circle fill="{c}" fill-opacity=".18" stroke="none" cx="10" cy="8" r="4"/><circle fill="none" stroke="{c}" stroke-width="2" cx="10" cy="8" r="4"/><path fill="none" stroke="{c}" stroke-width="2" d="M2.5 20c.7-3.4 3.5-5.3 7.5-5.3 1.4 0 2.6.2 3.6.7M18 10v6M15 13h6"/>',
  'history': '<circle fill="{c}" fill-opacity=".18" stroke="none" cx="12" cy="12" r="8.5"/><path fill="none" stroke="{c}" stroke-width="2" d="M3.5 12a8.5 8.5 0 108.5-8.5c-2.4 0-4.4 1-5.9 2.6L3.5 9M3.5 4v5h5M12 7.5V12l3 2"/>',
  'export': '<rect fill="{c}" fill-opacity=".18" stroke="none" x="5" y="3" width="14" height="18" rx="3"/><rect fill="none" stroke="{c}" stroke-width="2" x="5" y="3" width="14" height="18" rx="3"/><path fill="none" stroke="{c}" stroke-width="2" d="M12 9v6M9.5 12.5 12 15l2.5-2.5"/>',
  'shield': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M12 3 20 6v6c0 4.6-3.2 7.7-8 9-4.8-1.3-8-4.4-8-9V6z"/><path fill="none" stroke="{c}" stroke-width="2" d="M12 3 20 6v6c0 4.6-3.2 7.7-8 9-4.8-1.3-8-4.4-8-9V6z"/><path fill="none" stroke="{c}" stroke-width="2" d="M8.5 12l2.5 2.5 4.5-5"/>',
  'crown': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M4 8l4 4 4-6 4 6 4-4-1.5 10h-13z"/><path fill="none" stroke="{c}" stroke-width="2" d="M4 8l4 4 4-6 4 6 4-4-1.5 10h-13z"/>',
  'code': '<rect fill="{c}" fill-opacity=".18" stroke="none" x="2.5" y="4" width="19" height="16" rx="4"/><path fill="none" stroke="{c}" stroke-width="2" d="M8 9l-3 3 3 3M16 9l3 3-3 3M13.5 8l-3 8"/>',
  'heart': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M12 20s-8-4.6-8-10.5A4.5 4.5 0 0112 7a4.5 4.5 0 018 2.5C20 15.4 12 20 12 20z"/><path fill="none" stroke="{c}" stroke-width="2" d="M12 20s-8-4.6-8-10.5A4.5 4.5 0 0112 7a4.5 4.5 0 018 2.5C20 15.4 12 20 12 20z"/>',
  'camera': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M3 8a2 2 0 012-2h2l1.5-2h7L17 6h2a2 2 0 012 2v10a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><path fill="none" stroke="{c}" stroke-width="2" d="M3 8a2 2 0 012-2h2l1.5-2h7L17 6h2a2 2 0 012 2v10a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><circle fill="none" stroke="{c}" stroke-width="2" cx="12" cy="13" r="3.5"/>',
  'trash': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M6 7l1 13h10l1-13z"/><path fill="none" stroke="{c}" stroke-width="2" d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v5M14 11v5"/>',
  'edit': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M4 20l1-4L16 5l3 3L8 19z"/><path fill="none" stroke="{c}" stroke-width="2" d="M4 20l1-4L16 5l3 3L8 19z"/><path fill="none" stroke="{c}" stroke-width="2" d="M14 7l3 3"/>',
  'check': '<circle fill="{c}" fill-opacity=".18" stroke="none" cx="12" cy="12" r="9"/><circle fill="none" stroke="{c}" stroke-width="2" cx="12" cy="12" r="9"/><path fill="none" stroke="{c}" stroke-width="2" d="M8 12.5l2.8 2.8L16.5 9.5"/>',
  'tick': '<path fill="none" stroke="{c}" stroke-width="2" d="M5 12.5l4.5 4.5L19 7.5"/>',
  'cloud': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M7 18a4.5 4.5 0 01-.6-8.96A6 6 0 0118 10.5 3.75 3.75 0 0117.25 18z"/><path fill="none" stroke="{c}" stroke-width="2" d="M7 18a4.5 4.5 0 01-.6-8.96A6 6 0 0118 10.5 3.75 3.75 0 0117.25 18z"/><path fill="none" stroke="{c}" stroke-width="2" d="M12 17v-5M9.8 13.8 12 11.6l2.2 2.2"/>',
  'update': '<circle fill="{c}" fill-opacity=".18" stroke="none" cx="12" cy="12" r="9"/><circle fill="none" stroke="{c}" stroke-width="2" cx="12" cy="12" r="9"/><path fill="none" stroke="{c}" stroke-width="2" d="M12 7.5v7M9 12l3 3 3-3"/>',
  'spark': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M12 3l2.2 5.8L20 11l-5.8 2.2L12 19l-2.2-5.8L4 11l5.8-2.2z"/><path fill="none" stroke="{c}" stroke-width="2" d="M12 3l2.2 5.8L20 11l-5.8 2.2L12 19l-2.2-5.8L4 11l5.8-2.2z"/>',
  'bandage': '<g transform="rotate(-45 12 12)"><rect fill="{c}" fill-opacity=".18" stroke="none" x="2" y="8.5" width="20" height="7" rx="3.5"/><rect fill="none" stroke="{c}" stroke-width="2" x="2" y="8.5" width="20" height="7" rx="3.5"/><path fill="none" stroke="{c}" stroke-width="2" d="M9.5 8.5v7M14.5 8.5v7"/></g>',
  'trendUp': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M4 17l5-5 4 4 7-8V20H4z"/><path fill="none" stroke="{c}" stroke-width="2" d="M4 17l5-5 4 4 7-8M15 8h5v5"/>',
  'search': '<circle fill="{c}" fill-opacity=".18" stroke="none" cx="10.5" cy="10.5" r="6.5"/><circle fill="none" stroke="{c}" stroke-width="2" cx="10.5" cy="10.5" r="6.5"/><path fill="none" stroke="{c}" stroke-width="2" d="M15.5 15.5 20 20"/>',
  'back': '<path fill="none" stroke="{c}" stroke-width="2" d="M15 5l-7 7 7 7"/>',
  'chevron': '<path fill="none" stroke="{c}" stroke-width="2" d="M9 5l7 7-7 7"/>',
  'plus': '<path fill="none" stroke="{c}" stroke-width="2" d="M12 5v14M5 12h14"/>',
  'arrow': '<path fill="none" stroke="{c}" stroke-width="2" d="M5 12h14M13 6l6 6-6 6"/>',
  'warning': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M12 3.5 21.5 20h-19z"/><path fill="none" stroke="{c}" stroke-width="2" d="M12 3.5 21.5 20h-19z"/><path fill="none" stroke="{c}" stroke-width="2" d="M12 10v4.5M12 17.3h.01"/>',
  'logout': '<rect fill="{c}" fill-opacity=".18" stroke="none" x="4" y="4" width="8" height="16" rx="2"/><path fill="none" stroke="{c}" stroke-width="2" d="M10 4H6a2 2 0 00-2 2v12a2 2 0 002 2h4M15 8l4 4-4 4M19 12H9"/>',
  'login': '<path fill="none" stroke="{c}" stroke-width="2" d="M15 4h3a2 2 0 012 2v12a2 2 0 01-2 2h-3M10 16l4-4-4-4M14 12H4"/>',
  'heartPulse': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M12 20s-8-4.6-8-10.5A4.5 4.5 0 0112 7a4.5 4.5 0 018 2.5C20 15.4 12 20 12 20z"/><path fill="none" stroke="{c}" stroke-width="2" d="M12 20s-8-4.6-8-10.5A4.5 4.5 0 0112 7a4.5 4.5 0 018 2.5C20 15.4 12 20 12 20z"/><path fill="none" stroke="{c}" stroke-width="2" d="M7 12h2l1.5-3 2 6 1.5-3H17"/>',
  'chat': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M4 6a3 3 0 013-3h10a3 3 0 013 3v8a3 3 0 01-3 3h-5l-4 3.5V17H7a3 3 0 01-3-3z"/><path fill="none" stroke="{c}" stroke-width="2" d="M4 6a3 3 0 013-3h10a3 3 0 013 3v8a3 3 0 01-3 3h-5l-4 3.5V17H7a3 3 0 01-3-3z"/><path fill="none" stroke="{c}" stroke-width="2" d="M8.5 8.5h7M8.5 12h4"/>',
  'flag': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M5 4h11l-2 4 2 4H5z"/><path fill="none" stroke="{c}" stroke-width="2" d="M5 21V4M5 4h11l-2 4 2 4H5"/>',
  'pin': '<path fill="{c}" fill-opacity=".18" stroke="none" d="M12 21s7-5.6 7-11a7 7 0 10-14 0c0 5.4 7 11 7 11z"/><path fill="none" stroke="{c}" stroke-width="2" d="M12 21s7-5.6 7-11a7 7 0 10-14 0c0 5.4 7 11 7 11z"/><circle fill="none" stroke="{c}" stroke-width="2" cx="12" cy="10" r="2.5"/>',
  'idcard': '<rect fill="{c}" fill-opacity=".18" stroke="none" x="3" y="5" width="18" height="14" rx="3"/><rect fill="none" stroke="{c}" stroke-width="2" x="3" y="5" width="18" height="14" rx="3"/><circle fill="none" stroke="{c}" stroke-width="2" cx="9" cy="11" r="2"/><path fill="none" stroke="{c}" stroke-width="2" d="M6.5 16c.4-1.6 1.4-2.3 2.5-2.3s2.1.7 2.5 2.3M14 10h4M14 13.5h3"/>',
  'eye': '<path fill="none" stroke="{c}" stroke-width="2" d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle fill="none" stroke="{c}" stroke-width="2" cx="12" cy="12" r="3"/>',
  'eyeOff': '<path fill="none" stroke="{c}" stroke-width="2" d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle fill="none" stroke="{c}" stroke-width="2" cx="12" cy="12" r="3"/><path fill="none" stroke="{c}" stroke-width="2" d="M4 4l16 16"/>',
  'lock': '<rect fill="{c}" fill-opacity=".18" stroke="none" x="5" y="10.5" width="14" height="10" rx="3"/><rect fill="none" stroke="{c}" stroke-width="2" x="5" y="10.5" width="14" height="10" rx="3"/><path fill="none" stroke="{c}" stroke-width="2" d="M8 10.5V8a4 4 0 018 0v2.5"/>',
  'mail': '<rect fill="{c}" fill-opacity=".18" stroke="none" x="3" y="5.5" width="18" height="13" rx="3"/><rect fill="none" stroke="{c}" stroke-width="2" x="3" y="5.5" width="18" height="13" rx="3"/><path fill="none" stroke="{c}" stroke-width="2" d="M4 8l8 5.5L20 8"/>',
  'hospital': '<rect fill="{c}" fill-opacity=".18" stroke="none" x="4" y="7" width="16" height="14" rx="2"/><rect fill="none" stroke="{c}" stroke-width="2" x="4" y="7" width="16" height="14" rx="2"/><path fill="none" stroke="{c}" stroke-width="2" d="M12 10v4M10 12h4M10 21v-3h4v3"/>',
  'drag': '<path fill="none" stroke="{c}" stroke-width="2.6" d="M9 6h.01M15 6h.01M9 12h.01M15 12h.01M9 18h.01M15 18h.01"/>',
};
