import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/portfolio_profiles.dart';
import '../data/services/storage_service.dart';
import 'app_providers.dart';

final activeProfileIdProvider =
    StateNotifierProvider<ActiveProfileIdNotifier, String>((ref) {
  return ActiveProfileIdNotifier(ref.watch(storageServiceProvider));
});

final activePortfolioProfileProvider = Provider<PortfolioProfile>((ref) {
  return PortfolioProfiles.byId(ref.watch(activeProfileIdProvider));
});

class ActiveProfileIdNotifier extends StateNotifier<String> {
  ActiveProfileIdNotifier(this._storage) : super(_storage.activeProfileId);

  final StorageService _storage;

  Future<void> setProfile(String id) async {
    await _storage.setActiveProfileId(id);
    state = id;
  }
}
