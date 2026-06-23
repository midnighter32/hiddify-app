import 'package:flutter/material.dart';
import 'package:hiddify/features/wear/model/wear_connection_state.dart';

/// Large circular connect/disconnect button sized for a round watch face.
/// Color + icon reflect the connection state; pulses gently while connected.
class WearConnectButton extends StatefulWidget {
  const WearConnectButton({
    super.key,
    required this.state,
    required this.onTap,
    required this.diameter,
  });

  final WearConnectionState state;
  final VoidCallback onTap;
  final double diameter;

  @override
  State<WearConnectButton> createState() => _WearConnectButtonState();
}

class _WearConnectButtonState extends State<WearConnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant WearConnectButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _syncPulse();
  }

  void _syncPulse() {
    if (widget.state.isConnected) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color _color(ColorScheme scheme) => switch (widget.state) {
        WearConnectionState.connected => const Color(0xFF34C759),
        WearConnectionState.disconnected => scheme.primary,
        WearConnectionState.connecting ||
        WearConnectionState.disconnecting =>
          const Color(0xFFB9B067),
      };

  IconData get _icon => switch (widget.state) {
        WearConnectionState.connected => Icons.power_settings_new_rounded,
        WearConnectionState.disconnected => Icons.power_settings_new_rounded,
        WearConnectionState.connecting ||
        WearConnectionState.disconnecting =>
          Icons.power_settings_new_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color(scheme);
    final busy = widget.state.isSwitching;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = 0.25 + 0.18 * _pulse.value;
        return Semantics(
          button: true,
          enabled: !busy,
          label: switch (widget.state) {
            WearConnectionState.connected => 'Disconnect',
            WearConnectionState.disconnected => 'Connect',
            _ => 'Switching',
          },
          child: GestureDetector(
            onTap: busy ? null : widget.onTap,
            child: Container(
              width: widget.diameter,
              height: widget.diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.14),
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: glow),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Center(
                child: busy
                    ? SizedBox(
                        width: widget.diameter * 0.38,
                        height: widget.diameter * 0.38,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      )
                    : Icon(_icon, color: color, size: widget.diameter * 0.38),
              ),
            ),
          ),
        );
      },
    );
  }
}
