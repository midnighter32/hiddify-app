import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Visual state of the watch connect button, derived from the real
/// [ConnectionStatus] provider.
enum WearConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting;

  bool get isConnected => this == WearConnectionState.connected;
  bool get isDisconnected => this == WearConnectionState.disconnected;
  bool get isSwitching =>
      this == WearConnectionState.connecting || this == WearConnectionState.disconnecting;
}

/// Maps the async connection status into a button state. Loading and errors
/// fall back to "disconnected" so the button stays tappable.
WearConnectionState wearStateFromStatus(AsyncValue<ConnectionStatus> status) {
  return switch (status) {
    AsyncData(value: Connected()) => WearConnectionState.connected,
    AsyncData(value: Connecting()) => WearConnectionState.connecting,
    AsyncData(value: Disconnecting()) => WearConnectionState.disconnecting,
    AsyncData(value: Disconnected()) => WearConnectionState.disconnected,
    _ => WearConnectionState.disconnected,
  };
}
