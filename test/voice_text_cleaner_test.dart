import 'package:flutter_test/flutter_test.dart';
import 'package:laporan_kunjungan/services/voice_text_cleaner.dart';

void main() {
  group('number', () {
    final cases = {
      'seratus tiga puluh per delapan puluh': '130/80',
      'seratus empat puluh lima per sembilan puluh': '145/90',
      '130 per 80': '130/80',
      '130 / 80': '130/80',
      'lima puluh dua koma lima': '52,5',
      'dua ratus sepuluh': '210',
      'seratus dua belas': '112',
    };
    cases.forEach((input, expected) {
      test(input, () => expect(VoiceTextCleaner.clean(input, VoiceKind.number), expected));
    });
  });

  test('digits', () {
    expect(VoiceTextCleaner.clean('tiga lima nol satu', VoiceKind.digits), '3501');
    expect(VoiceTextCleaner.clean('3501 2345', VoiceKind.digits), '35012345');
  });

  test('name', () {
    expect(VoiceTextCleaner.clean('bu rahmi.', VoiceKind.name), 'Bu Rahmi');
    expect(VoiceTextCleaner.clean('evant atharasya', VoiceKind.name), 'Evan Atharasya');
    expect(VoiceTextCleaner.clean('evan at', VoiceKind.name), 'Evan Atharasya');
  });

  test('address', () {
    expect(VoiceTextCleaner.clean('jalan melati rt tiga rw dua', VoiceKind.address),
        'Jalan Melati RT 3 RW 2');
  });

  test('text', () {
    expect(VoiceTextCleaner.clean('demam tiga hari', VoiceKind.text), 'Demam 3 hari');
    expect(VoiceTextCleaner.clean('', VoiceKind.text), '');
  });
}
