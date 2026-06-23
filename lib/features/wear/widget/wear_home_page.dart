import 'package:flutter/material.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/wear/model/wear_connection_state.dart';
import 'package:hiddify/features/wear/widget/wear_connect_button.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Main watch screen. The watch runs the VPN core locally in proxy mode; this
/// drives the real connection providers. Connect button is centered, the
/// active-profile chip above and status / mini-stats below.
class WearHomePage extends ConsumerWidget {
  const WearHomePage({super.key, required this.onOpenProfiles});

  final VoidCallback onOpenProfiles;

  static const double _gap = 14;

  String _statusText(WearConnectionState s) => switch (s) {
        WearConnectionState.disconnected => 'Tap to connect',
        WearConnectionState.connecting => 'Connecting…',
        WearConnectionState.connected => 'Connected',
        WearConnectionState.disconnecting => 'Disconnecting…',
      };

  String? _subtitle(ProfileEntity? profile) {
    if (profile is RemoteProfileEntity && profile.subInfo != null) {
      final s = profile.subInfo!;
      return '${s.consumption.size()} / ${s.total.size()}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final minSide = size.shortestSide;
    final buttonDiameter = (minSide * 0.40).clamp(84.0, 116.0);

    final state = wearStateFromStatus(ref.watch(connectionNotifierProvider));
    final profile = ref.watch(activeProfileProvider).valueOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final radius = buttonDiameter / 2;
        final centerY = h / 2;

        return Stack(
          children: [
            Center(
              child: WearConnectButton(
                state: state,
                diameter: buttonDiameter,
                onTap: () => ref.read(connectionNotifierProvider.notifier).toggleConnection(),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: (centerY - radius - _gap).clamp(0.0, h),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.14),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _ProfileChip(
                    theme: theme,
                    name: profile?.name ?? 'No profile',
                    subtitle: _subtitle(profile),
                    onTap: onOpenProfiles,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              top: centerY + radius + _gap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.10),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _StatusBlock(theme: theme, label: _statusText(state), connected: state.isConnected),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.theme,
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final ThemeData theme;
  final String name;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _StatusBlock extends ConsumerWidget {
  const _StatusBlock({required this.theme, required this.label, required this.connected});

  final ThemeData theme;
  final String label;
  final bool connected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (connected) ...[
          const SizedBox(height: 4),
          _StatsRow(theme: theme),
        ],
      ],
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsNotifierProvider).valueOrNull;
    final ping = ref.watch(activeProxyNotifierProvider).valueOrNull?.urlTestDelay ?? 0;
    final down = (stats?.downlink.toInt() ?? 0).speed();
    final up = (stats?.uplink.toInt() ?? 0).speed();

    return DefaultTextStyle.merge(
      style: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.south_rounded, size: 12),
          Flexible(child: Text(' $down', maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          const Icon(Icons.north_rounded, size: 12),
          Flexible(child: Text(' $up', maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (ping > 0) ...[
            const SizedBox(width: 6),
            Text('$ping ms'),
          ],
        ],
      ),
    );
  }
}
