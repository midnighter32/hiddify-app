import 'dart:async';

import 'package:hiddify/core/logger/logger.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
import 'package:hiddify/features/wear_sync/wear_sync_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

/// Syncs profiles from the phone to the watch over the Data Layer so the watch
/// can run them locally (proxy mode). Phone publishes the profile list via the
/// replicated application context; the watch imports any it doesn't have.
///
/// Best-effort: never throws into the bootstrap path (needs Play Services + a
/// paired device).
class WearSyncService {
  WearSyncService(this._container);

  final ProviderContainer _container;
  final _wc = WatchConnectivity();
  StreamSubscription<Map<String, dynamic>>? _contextSub;
  ProviderSubscription<AsyncValue<List<ProfileEntity>>>? _profilesSub;

  Future<bool> _supported() async {
    try {
      return await _wc.isSupported;
    } catch (e, st) {
      Logger.bootstrap.warning("wear sync: isSupported failed", e, st);
      return false;
    }
  }

  // --- Phone side: publish profiles --------------------------------------

  Future<void> startSender() async {
    if (!await _supported()) {
      Logger.bootstrap.info("wear sync: not supported, sender disabled");
      return;
    }
    _profilesSub = _container.listen<AsyncValue<List<ProfileEntity>>>(
      profilesNotifierProvider,
      (previous, next) {
        final profiles = next.valueOrNull;
        if (profiles != null) unawaited(_pushProfiles(profiles));
      },
      fireImmediately: true,
    );
    Logger.bootstrap.info("wear sync: sender started");
  }

  Future<void> _pushProfiles(List<ProfileEntity> profiles) async {
    try {
      final repo = _container.read(profileRepositoryProvider).requireValue;
      final payload = <SyncProfile>[];
      for (final p in profiles) {
        if (p is RemoteProfileEntity) {
          payload.add(SyncProfile(name: p.name, kind: SyncProfileKind.url, payload: p.url));
        } else {
          final raw = await repo.getRawConfig(p.id).run();
          raw.match((_) {}, (content) {
            payload.add(SyncProfile(name: p.name, kind: SyncProfileKind.raw, payload: content));
          });
        }
      }
      await _wc.updateApplicationContext(encodeSyncProfiles(payload));
      Logger.bootstrap.info("wear sync: pushed ${payload.length} profiles to watch");
    } catch (e, st) {
      Logger.bootstrap.warning("wear sync: push failed", e, st);
    }
  }

  // --- Watch side: import profiles ---------------------------------------

  Future<void> startReceiver() async {
    if (!await _supported()) {
      Logger.bootstrap.info("wear sync: not supported, receiver disabled");
      return;
    }
    try {
      await _import(decodeSyncProfiles(await _wc.applicationContext));
    } catch (e, st) {
      Logger.bootstrap.warning("wear sync: initial import failed", e, st);
    }
    _contextSub = _wc.contextStream.listen((ctx) => unawaited(_import(decodeSyncProfiles(ctx))));
    Logger.bootstrap.info("wear sync: receiver started");
  }

  Future<void> _import(List<SyncProfile> incoming) async {
    if (incoming.isEmpty) return;
    final repo = _container.read(profileRepositoryProvider).requireValue;
    final existing = (await repo.watchAll().first).getOrElse((_) => <ProfileEntity>[]);
    final existingUrls = existing.whereType<RemoteProfileEntity>().map((e) => e.url).toSet();
    final existingNames = existing.map((e) => e.name).toSet();

    for (final sp in incoming) {
      try {
        if (sp.kind == SyncProfileKind.url) {
          if (existingUrls.contains(sp.payload)) continue;
          await repo.upsertRemote(sp.payload).run();
          Logger.bootstrap.info("wear sync: imported subscription '${sp.name}'");
        } else {
          if (existingNames.contains(sp.name)) continue;
          await repo.addLocal(sp.payload).run();
          Logger.bootstrap.info("wear sync: imported config '${sp.name}'");
        }
      } catch (e, st) {
        Logger.bootstrap.warning("wear sync: importing '${sp.name}' failed", e, st);
      }
    }
  }

  void dispose() {
    _contextSub?.cancel();
    _profilesSub?.close();
  }
}
