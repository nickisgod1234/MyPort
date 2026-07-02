import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/secrets.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/storage_service.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  if ((storage.apiKey == null || storage.apiKey!.isEmpty) &&
      kDefaultFmpApiKey != null &&
      kDefaultFmpApiKey!.isNotEmpty) {
    await storage.setApiKey(kDefaultFmpApiKey!);
  }

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
      child: const MyWealthApp(),
    ),
  );
}

class MyWealthApp extends ConsumerWidget {
  const MyWealthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(storageServiceProvider).darkMode;

    return MaterialApp.router(
      title: 'My Wealth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
