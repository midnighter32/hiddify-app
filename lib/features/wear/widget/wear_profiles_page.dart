import 'package:flutter/material.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Profile list on the watch. Tapping a profile makes it active (the local
/// core reconnects to it). Empty state hints at syncing from the phone.
class WearProfilesPage extends ConsumerWidget {
  const WearProfilesPage({super.key, required this.onSelected, this.scrollController});

  final VoidCallback onSelected;
  final ScrollController? scrollController;

  String _subtitle(ProfileEntity p) {
    if (p is RemoteProfileEntity && p.subInfo != null) {
      final s = p.subInfo!;
      return '${s.consumption.size()} / ${s.total.size()}';
    }
    return 'Local config';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final hPad = size.width * 0.12;

    final profiles = ref.watch(profilesNotifierProvider).valueOrNull ?? const [];
    final activeId = ref.watch(activeProfileProvider).valueOrNull?.id;

    if (profiles.isEmpty) {
      return _EmptyState(theme: theme, pad: hPad);
    }

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(hPad, size.height * 0.22, hPad, size.height * 0.22),
      children: [
        Center(child: Text('Profiles', style: theme.textTheme.titleSmall)),
        const SizedBox(height: 8),
        for (final p in profiles)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: p.id == activeId
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () async {
                  await ref.read(profilesNotifierProvider.notifier).selectActiveProfile(p.id);
                  onSelected();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        p is RemoteProfileEntity ? Icons.cloud_sync_rounded : Icons.description_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                            Text(
                              _subtitle(p),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (p.id == activeId)
                        Icon(Icons.check_circle_rounded, size: 18, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme, required this.pad});

  final ThemeData theme;
  final double pad;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: pad + 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.watch_rounded, size: 28, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text('No profiles yet', textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Add a profile in the phone app to sync it here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
