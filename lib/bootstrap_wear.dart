import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/logger/logger.dart';
import 'package:hiddify/core/logger/logger_controller.dart';
import 'package:hiddify/core/model/environment.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_migration.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/log/data/log_data_providers.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/wear/notifier/wear_complication.dart';
import 'package:hiddify/features/wear/notifier/wear_system_proxy.dart';
import 'package:hiddify/features/wear/widget/wear_app.dart';
import 'package:hiddify/features/wear_sync/wear_sync_service.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service_provider.dart';
import 'package:hiddify/riverpod_observer.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// Kept alive for the lifetime of the app (holds Data Layer subscriptions).
WearSyncService? _wearSync;

/// Bootstrap for the Wear OS entrypoint. Mirrors the relevant parts of
/// [lazyBootstrap] (directories, prefs, logs, profile repo, translations,
/// hiddify-core) but skips desktop/tray/window/analytics and runs [WearApp].
Future<void> lazyBootstrapWear(WidgetsBinding widgetsBinding, Environment env) async {
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  LoggerController.preInit();
  FlutterError.onError = Logger.logFlutterError;
  WidgetsBinding.instance.platformDispatcher.onError = Logger.logPlatformDispatcherError;

  final stopWatch = Stopwatch()..start();
  final container = ProviderContainer(overrides: [environmentProvider.overrideWithValue(env)]);

  await _init("directories", () => container.read(appDirectoriesProvider.future));
  LoggerController.init(container.read(logPathResolverProvider).appFile().path);

  final appInfo = await _init("app info", () => container.read(appInfoProvider.future));
  await _init("preferences", () => container.read(sharedPreferencesProvider.future));

  await _init("preferences migration", () async {
    try {
      await PreferencesMigration(sharedPreferences: container.read(sharedPreferencesProvider).requireValue).migrate();
    } catch (e, stackTrace) {
      Logger.bootstrap.error("preferences migration failed", e, stackTrace);
      if (env == Environment.dev) rethrow;
      await container.read(sharedPreferencesProvider).requireValue.clear();
    }
  });

  final debug = container.read(debugModeNotifierProvider) || kDebugMode;

  await _init("logs repository", () => container.read(logRepositoryProvider.future));
  await _init("logger controller", () => LoggerController.postInit(debug));
  Logger.bootstrap.info(appInfo.format());

  await _init("profile repository", () => container.read(profileRepositoryProvider.future));
  await _init("translations", () => container.read(translationsProvider.future));
  await _safeInit("active profile", () => container.read(activeProfileProvider.future), timeout: 1000);
  await _safeInit("hiddify-core", () => container.read(hiddifyCoreServiceProvider).init());

  // Force evaluation so status streams are live when the UI builds.
  container.listen(activeProxyNotifierProvider, (previous, next) {});

  // Wear OS has no VPN service, so force proxy mode (ProxyService, no tun).
  await _safeInit(
    "force proxy mode",
    () async => container.read(ConfigOptions.serviceMode.notifier).update(ServiceMode.proxy),
  );

  // Import profiles synced from the phone so the watch can run them locally.
  _wearSync = WearSyncService(container);
  unawaited(_wearSync!.startReceiver());

  // Clear any stale proxy left over from a previous crash (a dangling
  // http_proxy with no running core would break the watch's HTTP apps).
  unawaited(WearSystemProxy.clear());

  // In proxy mode the core only opens a local proxy; point the watch's
  // device-wide HTTP proxy at it while connected so apps route through it.
  container.listen(connectionNotifierProvider, (previous, next) {
    switch (next.valueOrNull) {
      case Connected():
        unawaited(WearSystemProxy.set(container.read(ConfigOptions.mixedPort)));
      case Disconnected():
        unawaited(WearSystemProxy.clear());
      default:
        break;
    }
    unawaited(WearComplication.update(container));
  });
  // Refresh the complication (ping/flag) about once a minute while running.
  Timer.periodic(const Duration(seconds: 60), (_) => unawaited(WearComplication.update(container)));

  Logger.bootstrap.info("wear bootstrap took [${stopWatch.elapsedMilliseconds}ms]");
  stopWatch.stop();

  runApp(
    ProviderScope(
      parent: container,
      observers: [RiverpodObserver()],
      child: const WearApp(),
    ),
  );

  FlutterNativeSplash.remove();
}

Future<T> _init<T>(String name, Future<T> Function() initializer, {int? timeout}) async {
  Logger.bootstrap.info("initializing [$name]");
  Future<T> func() => timeout != null ? initializer().timeout(Duration(milliseconds: timeout)) : initializer();
  try {
    return await func();
  } catch (e, stackTrace) {
    Logger.bootstrap.error("[$name] error initializing", e, stackTrace);
    rethrow;
  }
}

Future<T?> _safeInit<T>(String name, Future<T> Function() initializer, {int? timeout}) async {
  try {
    return await _init(name, initializer, timeout: timeout);
  } catch (e) {
    return null;
  }
}
