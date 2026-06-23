import 'package:flutter/services.dart';
import 'package:hiddify/core/logger/logger.dart';

/// Sets/clears the watch's device-wide HTTP proxy so apps route through the
/// locally-running proxy core. Requires WRITE_SECURE_SETTINGS (granted once via
/// `adb shell pm grant app.hiddify.com android.permission.WRITE_SECURE_SETTINGS`).
class WearSystemProxy {
  static const _channel = MethodChannel('com.hiddify.app/wear_proxy');

  static Future<void> set(int port) async {
    try {
      await _channel.invokeMethod('setSystemProxy', {'host': '127.0.0.1', 'port': port});
      Logger.bootstrap.info("wear proxy: system proxy set to 127.0.0.1:$port");
    } catch (e, st) {
      Logger.bootstrap.warning("wear proxy: set failed (grant WRITE_SECURE_SETTINGS?)", e, st);
    }
  }

  static Future<void> clear() async {
    try {
      await _channel.invokeMethod('clearSystemProxy');
      Logger.bootstrap.info("wear proxy: system proxy cleared");
    } catch (e, st) {
      Logger.bootstrap.warning("wear proxy: clear failed", e, st);
    }
  }

  /// Returns and clears a pending action requested from the Wear OS tile
  /// (e.g. "toggle"), or null if none.
  static Future<String?> consumeTileAction() async {
    try {
      return await _channel.invokeMethod<String>('consumeTileAction');
    } catch (_) {
      return null;
    }
  }
}
