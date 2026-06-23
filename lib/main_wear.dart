import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/bootstrap_wear.dart';
import 'package:hiddify/core/model/environment.dart';

/// Entry point for the Wear OS build.
///
///   flutter build apk -t lib/main_wear.dart --target-platform android-arm
///
/// Runs the trimmed watch UI ([WearApp]) on top of the shared Hiddify provider
/// graph via [lazyBootstrapWear].
Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  return await lazyBootstrapWear(widgetsBinding, Environment.dev);
}
