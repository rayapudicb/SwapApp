import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/medusa_flutter_theme.dart';

class AgreementCountdownTimer extends StatefulWidget {
  const AgreementCountdownTimer({
    required this.expiresAt,
    this.totalDuration = const Duration(minutes: 15),
    this.onExpired,
    super.key,
  });

  final DateTime expiresAt;
  final Duration totalDuration;
  final VoidCallback? onExpired;

  @override
  State<AgreementCountdownTimer> createState() =>
      _AgreementCountdownTimerState();
}

class _AgreementCountdownTimerState extends State<AgreementCountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateRemaining();
    });
  }

  @override
  void didUpdateWidget(covariant AgreementCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _updateRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final now = DateTime.now().toUtc();
    final diff = widget.expiresAt.toUtc().difference(now);
    if (diff.isNegative) {
      if (_remaining != Duration.zero) {
        widget.onExpired?.call();
      }
      setState(() => _remaining = Duration.zero);
    } else {
      setState(() => _remaining = diff);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medusa = context.medusa;
    final textTheme = Theme.of(context).textTheme;

    final totalSeconds = widget.totalDuration.inSeconds > 0
        ? widget.totalDuration.inSeconds
        : 900;
    final remainingSeconds = _remaining.inSeconds.clamp(0, totalSeconds);
    final progress = remainingSeconds / totalSeconds;

    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    final formattedTime =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final isUrgent = remainingSeconds <= 180; // 3 minutes remaining
    final timerColor = isUrgent ? medusa.error : medusa.interactive;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: medusa.borderBase,
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedTime,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: timerColor,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                remainingSeconds == 0 ? 'HOLD EXPIRED' : 'HOLD TIME LEFT',
                style: textTheme.labelSmall?.copyWith(
                  color: medusa.fgMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
