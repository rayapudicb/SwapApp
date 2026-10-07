import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../home/data/foreground_location_source.dart';
import '../domain/exchange_models.dart';
import '../providers/exchange_provider.dart';

class AgreementHoldScreen extends StatefulWidget {
  const AgreementHoldScreen({
    required this.agreementId,
    this.locationGateway = const GeolocatorForegroundLocationGateway(),
    super.key,
  });

  final String agreementId;
  final ForegroundLocationGateway locationGateway;

  @override
  State<AgreementHoldScreen> createState() => _AgreementHoldScreenState();
}

class _AgreementHoldScreenState extends State<AgreementHoldScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() =>
      context.read<ExchangeProvider>().loadAgreement(widget.agreementId);

  Future<void> _runPresenceAction(
    SwapAgreement agreement,
    Future<bool> Function(ExchangeProvider provider) action,
  ) async {
    final provider = context.read<ExchangeProvider>();
    final acquired = await provider.acquireFreshEventPresenceGrant(
      contextRef: agreement.contextRef,
      loadObservation: widget.locationGateway.currentObservation,
    );
    if (!mounted || !acquired) return;
    await action(provider);
  }

  @override
  Widget build(BuildContext context) {
    final exchange = context.watch<ExchangeProvider>();
    final agreement = exchange.activeAgreement?.id == widget.agreementId
        ? exchange.activeAgreement
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Swap agreement')),
      body: SafeArea(
        child: _AgreementBody(
          agreement: agreement,
          loading: exchange.isLoadingAgreement,
          actionRunning:
              exchange.isLoadingAgreement || exchange.presenceGrantLoading,
          error: exchange.agreementError ?? exchange.presenceGrantError,
          onRetry: _refresh,
          onConsent: agreement == null
              ? null
              : () => _runPresenceAction(
                  agreement,
                  (provider) => provider.recordAgreementConsent(
                    agreement: agreement,
                    contextRef: agreement.contextRef,
                  ),
                ),
          onHandoff: agreement == null
              ? null
              : () => _runPresenceAction(
                  agreement,
                  (provider) => provider.recordAgreementHandoff(
                    agreement: agreement,
                    contextRef: agreement.contextRef,
                  ),
                ),
          onCash: agreement == null
              ? null
              : () => _runPresenceAction(
                  agreement,
                  (provider) => provider.recordAgreementCashConfirmation(
                    agreement: agreement,
                    contextRef: agreement.contextRef,
                  ),
                ),
        ),
      ),
    );
  }
}

class _AgreementBody extends StatelessWidget {
  const _AgreementBody({
    required this.agreement,
    required this.loading,
    required this.actionRunning,
    required this.error,
    required this.onRetry,
    required this.onConsent,
    required this.onHandoff,
    required this.onCash,
  });

  final SwapAgreement? agreement;
  final bool loading;
  final bool actionRunning;
  final String? error;
  final Future<void> Function() onRetry;
  final Future<void> Function()? onConsent;
  final Future<void> Function()? onHandoff;
  final Future<void> Function()? onCash;

  @override
  Widget build(BuildContext context) {
    if (loading && agreement == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (agreement == null) {
      return _FailureState(error: error, onRetry: onRetry);
    }
    final currentAgreement = agreement!;
    final terminal = {
      AgreementState.reportedComplete,
      AgreementState.providerVerifiedComplete,
      AgreementState.cancelled,
      AgreementState.expired,
      AgreementState.disputed,
    }.contains(currentAgreement.state);
    final canConsent =
        currentAgreement.state == AgreementState.awaitingConsent &&
        !currentAgreement.youConsented;
    final canHandoff =
        !terminal &&
        currentAgreement.youConsented &&
        currentAgreement.counterpartyConsented &&
        !currentAgreement.youConfirmedHandoff;
    final cash = currentAgreement.cashSettlement;
    final canConfirmCash =
        !terminal &&
        currentAgreement.youConsented &&
        currentAgreement.counterpartyConsented &&
        cash != null &&
        !cash.youConfirmed;

    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.policy_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _headline(currentAgreement.state),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentAgreement.state == AgreementState.reportedComplete
                        ? 'Both participants reported the required handoff'
                              '${cash == null ? '' : ' and cash exchange'}. '
                              'Swappy has not independently verified either.'
                        : 'Each participant must record their own actions. '
                              'A fresh in-event location check is required; '
                              'the other person cannot confirm for you.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Status: ${_stateLabel(currentAgreement.state)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Last updated '
                    '${_formatTimestamp(currentAgreement.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Two-way progress',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProgressRow(
                    label: 'You agreed to swap',
                    complete: currentAgreement.youConsented,
                  ),
                  _ProgressRow(
                    label: 'Other participant agreed',
                    complete: currentAgreement.counterpartyConsented,
                  ),
                  _ProgressRow(
                    label: 'You reported ticket handoff',
                    complete: currentAgreement.youConfirmedHandoff,
                  ),
                  _ProgressRow(
                    label: 'Other participant reported ticket handoff',
                    complete: currentAgreement.counterpartyConfirmedHandoff,
                  ),
                  if (cash != null) ...[
                    const Divider(height: 24),
                    Text(
                      '${_cashAmount(cash)} cash difference',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Cash is arranged directly between participants. It is '
                      'not held, protected, or verified by Swappy.',
                    ),
                    const SizedBox(height: 10),
                    _ProgressRow(
                      label: cash.role == AgreementCashRole.payer
                          ? 'You reported cash paid'
                          : 'You reported cash received',
                      complete: cash.youConfirmed,
                    ),
                    _ProgressRow(
                      label: cash.role == AgreementCashRole.payer
                          ? 'Other participant reported cash received'
                          : 'Other participant reported cash paid',
                      complete: cash.counterpartyConfirmed,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (canConsent || canHandoff || canConfirmCash) ...[
            const SizedBox(height: 12),
            if (canConsent)
              FilledButton.icon(
                onPressed: actionRunning ? null : onConsent,
                icon: const Icon(Icons.handshake_outlined),
                label: const Text('Agree to this swap'),
              ),
            if (canHandoff) ...[
              if (canConsent) const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: actionRunning ? null : onHandoff,
                icon: const Icon(Icons.confirmation_number_outlined),
                label: const Text('I completed the ticket handoff'),
              ),
            ],
            if (canConfirmCash) ...[
              if (canConsent || canHandoff) const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: actionRunning ? null : onCash,
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  cash.role == AgreementCashRole.payer
                      ? 'I paid the cash'
                      : 'I received the cash',
                ),
              ),
            ],
            if (actionRunning) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(
          complete ? Icons.check_circle : Icons.radio_button_unchecked,
          color: complete ? Colors.green : null,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    ),
  );
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.error, required this.onRetry});

  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 44),
          const SizedBox(height: 12),
          Text(
            error ?? 'The agreement could not be loaded.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

String _stateLabel(AgreementState state) => switch (state) {
  AgreementState.awaitingConsent => 'Awaiting consent',
  AgreementState.readyForHandoff => 'Ready for handoff',
  AgreementState.onePartyConfirmed => 'One party reported handoff',
  AgreementState.awaitingCashConfirmation => 'Awaiting cash acknowledgement',
  AgreementState.reportedComplete => 'Reported complete — not verified',
  AgreementState.providerVerifiedComplete => 'Provider verified complete',
  AgreementState.cancelled => 'Cancelled',
  AgreementState.expired => 'Expired',
  AgreementState.disputed => 'Disputed',
  AgreementState.agreed => 'Agreed',
  AgreementState.holdLocked => 'Legacy hold',
  AgreementState.completed => 'Legacy completed — not verified',
};

String _headline(AgreementState state) => switch (state) {
  AgreementState.reportedComplete => 'Swap reported complete',
  AgreementState.providerVerifiedComplete => 'Swap provider verified',
  AgreementState.cancelled => 'Agreement cancelled',
  AgreementState.expired => 'Agreement expired',
  AgreementState.disputed => 'Agreement disputed',
  _ => 'Complete this swap together',
};

String _cashAmount(AgreementCashSettlement cash) =>
    '${cash.currency} ${(cash.amountMinor / 100).toStringAsFixed(2)}';

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
