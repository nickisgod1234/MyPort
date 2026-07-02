import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:port_invest/data/models/portfolio_models.dart';
import 'package:port_invest/data/services/storage_service.dart';
import 'package:port_invest/features/dca/dca_screen.dart';
import 'package:port_invest/providers/app_providers.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('myport_hive').path;
  }
}

void main() {
  late StorageService storage;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = _FakePathProvider();
    storage = StorageService();
    await storage.init();
  });

  testWidgets('My Wealth app loads', (tester) async {
    const emptySummary = PortfolioSummary(
      totalValueThb: 0,
      totalInvestedThb: 0,
      totalProfitThb: 0,
      totalReturnPercent: 0,
      holdings: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          portfolioSummaryProvider.overrideWith((ref) async => emptySummary),
          marketQuotesProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: const DcaScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('ลงทุนครอบครัว'), findsOneWidget);
  });
}
