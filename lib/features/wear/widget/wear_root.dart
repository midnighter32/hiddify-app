import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/wear/notifier/wear_system_proxy.dart';
import 'package:hiddify/features/wear/widget/wear_home_page.dart';
import 'package:hiddify/features/wear/widget/wear_profiles_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

/// Root of the watch UI. Two vertically-paged screens (Wear OS convention):
/// Home (connect) and Profiles. Rotary input switches pages and scrolls the
/// profile list; swipe-to-dismiss / back returns to home.
class WearRoot extends ConsumerStatefulWidget {
  const WearRoot({super.key});

  @override
  ConsumerState<WearRoot> createState() => _WearRootState();
}

class _WearRootState extends ConsumerState<WearRoot> with WidgetsBindingObserver {
  final PageController _pages = PageController();
  final ScrollController _profilesScroll = ScrollController();
  StreamSubscription<RotaryEvent>? _rotarySub;
  int _page = 0;

  // Caps the scroll increment per rotary event for smooth, controlled motion.
  static const double _maxIncrement = 50;
  // Guards against re-triggering a page change while one is animating.
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _rotarySub = rotaryEvents.listen(_onRotary);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleTileAction());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _handleTileAction();
  }

  // Toggle the connection when launched/resumed from the quick-toggle tile.
  Future<void> _handleTileAction() async {
    final action = await WearSystemProxy.consumeTileAction();
    if (action == 'toggle' && mounted) {
      await ref.read(connectionNotifierProvider.notifier).toggleConnection();
    }
  }

  void _onRotary(RotaryEvent event) {
    if (_switching) return;
    final clockwise = event.direction == RotaryDirection.clockwise;
    final increment = min(event.magnitude ?? _maxIncrement, _maxIncrement);

    if (_page == 0) {
      if (clockwise) _goTo(1);
      return;
    }

    if (!_profilesScroll.hasClients) return;
    final pos = _profilesScroll.position;
    if (clockwise) {
      _profilesScroll.jumpTo(min(_profilesScroll.offset + increment, pos.maxScrollExtent));
    } else {
      if (_profilesScroll.offset <= pos.minScrollExtent) {
        _goTo(0);
      } else {
        _profilesScroll.jumpTo(max(_profilesScroll.offset - increment, pos.minScrollExtent));
      }
    }
  }

  void _goTo(int page) {
    if (_page == page) return;
    _switching = true;
    _pages
        .animateToPage(
          page,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        )
        .whenComplete(() => _switching = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rotarySub?.cancel();
    _pages.dispose();
    _profilesScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // On profiles, the Wear OS swipe-to-dismiss (and back) returns to home
    // instead of exiting the app; on home it falls through to exit.
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goTo(0);
      },
      child: Scaffold(
        backgroundColor: Colors.black, // OLED-friendly for always-on faces
        body: Stack(
          children: [
            PageView(
              controller: _pages,
              scrollDirection: Axis.vertical,
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                WearHomePage(onOpenProfiles: () => _goTo(1)),
                WearProfilesPage(
                  scrollController: _profilesScroll,
                  onSelected: () => _goTo(0),
                ),
              ],
            ),
            // Page indicator dots along the right edge.
            Positioned(
              right: 6,
              top: 0,
              bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 2; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _page == i
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white24,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
