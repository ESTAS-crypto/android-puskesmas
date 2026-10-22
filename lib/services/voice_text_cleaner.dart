/// Merapikan hasil pengenalan suara bahasa Indonesia.
/// Mesin suara sering mengembalikan angka sebagai kata ("seratus tiga puluh per delapan puluh").
/// Kelas ini mengubahnya jadi "130/80" dan merapikan huruf besar sesuai jenis kolom.
enum VoiceKind { name, address, digits, number, text }

class VoiceTextCleaner {
  VoiceTextCleaner._();

  static const Map<String, int> _units = {
    'nol': 0, 'kosong': 0, 'satu': 1, 'dua': 2, 'tiga': 3, 'empat': 4,
    'lima': 5, 'enam': 6, 'tujuh': 7, 'delapan': 8, 'sembilan': 9,
  };
  static const Set<String> _numberWords = {
    'nol', 'kosong', 'satu', 'dua', 'tiga', 'empat', 'lima', 'enam', 'tujuh',
    'delapan', 'sembilan', 'sepuluh', 'sebelas', 'belas', 'puluh', 'seratus',
    'ratus', 'seribu', 'ribu',
  };

  /// Pasangan "salah dengar" → "benar". KOSONG sengaja.
  /// Isi berdasarkan kesalahan nyata yang Anda catat saat uji lapangan, contoh:
  ///   'tensi darah': 'tensi'
  static const Map<String, String> fixes = {};

  static String clean(String raw, VoiceKind kind) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    switch (kind) {
      case VoiceKind.digits:
        return _digitsOnly(s);
      case VoiceKind.number:
        return _normalizeNumbers(s, slash: true).replaceAll(' ', '');
      case VoiceKind.name:
        return _titleCase(s.replaceAll(RegExp(r'[.,]+$'), ''));
      case VoiceKind.address:
        return _address(_applyFixes(_normalizeNumbers(s)));
      case VoiceKind.text:
        return _sentence(_applyFixes(_normalizeNumbers(s)));
    }
  }

  // ── angka ──
  static String _digitsOnly(String s) {
    final b = StringBuffer();
    for (final tok in s.toLowerCase().split(RegExp(r'\s+'))) {
      final u = _units[tok];
      if (u != null) {
        b.write(u);
      } else {
        b.write(tok.replaceAll(RegExp(r'[^0-9]'), ''));
      }
    }
    return b.toString();
  }

  static int _parse(List<String> words) {
    var total = 0, cur = 0, unit = 0;
    for (final w in words) {
      final u = _units[w];
      if (u != null) {
        unit += u;
        continue;
      }
      switch (w) {
        case 'sepuluh':
          cur += 10;
          break;
        case 'sebelas':
          cur += 11;
          break;
        case 'belas':
          cur += unit + 10;
          unit = 0;
          break;
        case 'puluh':
          cur += (unit == 0 ? 1 : unit) * 10;
          unit = 0;
          break;
        case 'seratus':
          cur += 100;
          break;
        case 'ratus':
          cur += (unit == 0 ? 1 : unit) * 100;
          unit = 0;
          break;
        case 'seribu':
          total += 1000;
          break;
        case 'ribu':
          final base = cur + unit;
          total += (base == 0 ? 1 : base) * 1000;
          cur = 0;
          unit = 0;
          break;
      }
    }
    return total + cur + unit;
  }

  static String _normalizeNumbers(String s, {bool slash = false}) {
    final t = s.split(RegExp(r'\s+'));
    final out = <String>[];
    var i = 0;
    while (i < t.length) {
      final low = t[i].toLowerCase();
      if (_numberWords.contains(low)) {
        var j = i;
        while (j < t.length && _numberWords.contains(t[j].toLowerCase())) {
          j++;
        }
        var val = _parse(t.sublist(i, j).map((e) => e.toLowerCase()).toList())
            .toString();
        if (j + 1 < t.length &&
            t[j].toLowerCase() == 'koma' &&
            _units.containsKey(t[j + 1].toLowerCase())) {
          var k = j + 1;
          final dec = StringBuffer();
          while (k < t.length && _units.containsKey(t[k].toLowerCase())) {
            dec.write(_units[t[k].toLowerCase()]);
            k++;
          }
          val = '$val,${dec.toString()}';
          j = k;
        }
        out.add(val);
        i = j;
      } else {
        out.add(t[i]);
        i++;
      }
    }
    var r = out.join(' ');
    if (slash) {
      r = r.replaceAllMapped(
          RegExp(r'(\d)\s+per\s+(\d)', caseSensitive: false),
          (m) => '${m[1]}/${m[2]}');
      r = r.replaceAllMapped(
          RegExp(r'(\d)\s*/\s*(\d)'), (m) => '${m[1]}/${m[2]}');
    }
    return r;
  }

  // ── huruf & istilah ──
  static String _applyFixes(String s) {
    var r = s;
    fixes.forEach((wrong, right) {
      r = r.replaceAll(
          RegExp('\\b${RegExp.escape(wrong)}\\b', caseSensitive: false), right);
    });
    return r;
  }

  static String _titleCase(String s) => s
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  static String _address(String s) => s
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) {
        final l = w.toLowerCase();
        if (l == 'rt' || l == 'rw') return l.toUpperCase();
        return w[0].toUpperCase() + w.substring(1);
      })
      .join(' ');

  static String _sentence(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
