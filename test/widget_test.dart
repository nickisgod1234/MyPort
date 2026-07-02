import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:port_invest/main.dart';
import 'package:port_invest/data/services/storage_service.dart';
import 'package:port_invest/providers/app_providers.dart';

void main() {
  testWidgets('My Wealth app loads dashboard', (tester) async {
    final storage = StorageService();
    await storage.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: const MyWealthApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('My Wealth'), findsOneWidget);
  });
}
