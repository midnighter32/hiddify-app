import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hiddify/core/logger/logger.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Feeds the watch-face complication: writes connection state, ping and the
/// connected country's flag (rendered to a PNG) into shared preferences the
/// native `HiddifyComplicationService` reads, then asks the system to refresh.
class WearComplication {
  static const _channel = MethodChannel('com.hiddify.app/wear_proxy');

  static Future<void> update(ProviderContainer container) async {
    try {
      final prefs = container.read(sharedPreferencesProvider).requireValue;
      final connected = container.read(connectionNotifierProvider).valueOrNull is Connected;
      await prefs.setBool('hiddify_wear_connected', connected);

      if (connected) {
        final proxy = container.read(activeProxyNotifierProvider).valueOrNull;
        final ping = proxy?.urlTestDelay ?? 0;
        await prefs.setString('hiddify_wear_ping', (ping > 0 && ping < 65000) ? '$ping' : '--');
        final cc = proxy?.ipinfo.countryCode ?? '';
        if (cc.isNotEmpty) {
          final path = await _renderFlag(cc);
          if (path != null) await prefs.setString('hiddify_wear_flag_path', path);
        }
      }

      try {
        await _channel.invokeMethod('requestComplicationUpdate');
      } catch (_) {}
    } catch (e, st) {
      Logger.bootstrap.warning("wear complication update failed", e, st);
    }
  }

  static String _flagEmoji(String cc) {
    final c = cc.trim().toUpperCase();
    if (c.length != 2) return '';
    final a = c.codeUnitAt(0);
    final b = c.codeUnitAt(1);
    if (a < 0x41 || a > 0x5A || b < 0x41 || b > 0x5A) return '';
    const base = 0x1F1E6; // regional indicator 'A'
    return String.fromCharCode(base + (a - 0x41)) + String.fromCharCode(base + (b - 0x41));
  }

  static Future<String?> _renderFlag(String cc) async {
    final code = cc.trim().toLowerCase();
    if (code.length != 2) return null;
    try {
      // Prefer the clean round flag used on the phone (circle_flags), fall back
      // to a rendered flag emoji if that country's asset is missing.
      String? svg;
      try {
        svg = await rootBundle.loadString('packages/circle_flags/assets/svg/$code.svg');
      } catch (_) {
        svg = null;
      }
      final image =
          (svg != null && svg.isNotEmpty) ? await _renderRectFlag(svg) : await _renderEmojiFlag(cc);
      if (image == null) return null;

      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/wear_flag_$code.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      return file.path;
    } catch (e, st) {
      Logger.bootstrap.warning("wear complication flag render failed", e, st);
      return null;
    }
  }

  // Rounded-rectangle flag (matches the phone): 4:3, full-bleed, scaled to
  // cover and centre-cropped so the square flag art isn't distorted. The
  // watch-face's round mask may trim the corners — that's acceptable (bigger).
  static Future<ui.Image> _renderRectFlag(String svgString) async {
    const w = 192.0;
    const h = 144.0;
    const radius = 28.0;
    final info = await vg.loadPicture(SvgStringLoader(svgString), null);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.clipRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, w, h), const Radius.circular(radius)),
    );
    final s = info.size;
    if (s.width > 0 && s.height > 0) {
      final scale = math.max(w / s.width, h / s.height);
      canvas.translate((w - s.width * scale) / 2, (h - s.height * scale) / 2);
      canvas.scale(scale);
    }
    canvas.drawPicture(info.picture);
    info.picture.dispose();
    return recorder.endRecording().toImage(w.toInt(), h.toInt());
  }

  static Future<ui.Image?> _renderEmojiFlag(String cc) async {
    final emoji = _flagEmoji(cc);
    if (emoji.isEmpty) return null;
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: 120)),
      textDirection: TextDirection.ltr,
    )..layout();
    final recorder = ui.PictureRecorder();
    tp.paint(Canvas(recorder), Offset.zero);
    final w = tp.width.ceil().clamp(1, 320);
    final h = tp.height.ceil().clamp(1, 320);
    return recorder.endRecording().toImage(w, h);
  }
}
