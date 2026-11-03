import 'package:finova/app/app.dart';
import 'package:finova/app/routes/app_destinations.dart';
import 'package:finova/app/routes/app_router.dart';
import 'package:finova/app/theme/app_theme.dart';
import 'package:finova/core/utils/rupiah.dart';
import 'package:finova/features/menu/presentation/menu_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Format Rupiah mempertahankan integer, nol, dan nilai negatif', () {
    expect(formatRupiah(48750000), 'Rp 48.750.000');
    expect(formatRupiah(0), 'Rp 0');
    expect(formatRupiah(-1250000), '-Rp 1.250.000');
  });

  testWidgets('Dashboard menampilkan ringkasan dan transaksi contoh', (
    tester,
  ) async {
    await tester.pumpWidget(const FinovaApp());
    await tester.pumpAndSettle();
    expect(find.text('finova'), findsOneWidget);
    expect(find.text('Rp 48.750.000'), findsOneWidget);
    expect(find.text('Oktober 2026'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Transaksi terbaru'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Menunggu'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pembayaran proyek website'), findsOneWidget);
    expect(find.text('Menunggu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tab utama dan seluruh modul menu dapat dibuka', (tester) async {
    await tester.pumpWidget(const FinovaApp());
    await tester.pumpAndSettle();
    for (final label in ['Transaksi', 'Persetujuan']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('Ruang untuk langkah berikutnya'), findsOneWidget);
      await tester.tap(find.text('Ke Beranda'));
      await tester.pumpAndSettle();
      expect(find.text('finova'), findsOneWidget);
    }
    for (final destination in AppDestination.values) {
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      final target = find.widgetWithText(ListTile, destination.label);
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(
        find.text(
          destination == AppDestination.dashboard
              ? 'finova'
              : 'Ruang untuk langkah berikutnya',
        ),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MenuPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Deep link dan rute tidak dikenal dapat dipulihkan', (
    tester,
  ) async {
    final router = createAppRouter(initialLocation: '/reports');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.text('Laporan'), findsOneWidget);
    router.go('/unknown');
    await tester.pumpAndSettle();
    expect(find.text('Halaman tidak ditemukan'), findsOneWidget);
    await tester.tap(find.text('Ke Beranda'));
    await tester.pumpAndSettle();
    expect(find.text('finova'), findsOneWidget);
  });

  for (final scale in [1.0, 1.6, 2.0]) {
    testWidgets('Dashboard layar 320dp, skala teks $scale, tanpa overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const FinovaApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
