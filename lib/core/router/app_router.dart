import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/analysis/analysis_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dca/dca_screen.dart';
import '../../features/portfolio/asset_detail_screen.dart';
import '../../features/portfolio/portfolio_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/portfolio',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PortfolioScreen(),
          ),
        ),
        GoRoute(
          path: '/dca',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DcaScreen(),
          ),
        ),
        GoRoute(
          path: '/analysis',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AnalysisScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/asset/:symbol',
      builder: (context, state) {
        final symbol = state.pathParameters['symbol']!;
        return AssetDetailScreen(symbol: symbol);
      },
    ),
  ],
);
