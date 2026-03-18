import 'package:flutter_test/flutter_test.dart';
import 'package:laporan_kunjungan/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LaporanKunjunganApp());
    expect(find.text('Laporan Kunjungan'), findsOneWidget);
  });
}
