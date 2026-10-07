import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/exchange_models.dart';
import '../providers/exchange_provider.dart';

enum ExchangeResourceKind { evidence, entitlement }

class ExchangeResourceDetailScreen extends StatefulWidget {
  const ExchangeResourceDetailScreen.evidence({
    required this.resourceId,
    super.key,
  }) : kind = ExchangeResourceKind.evidence;

  const ExchangeResourceDetailScreen.entitlement({
    required this.resourceId,
    super.key,
  }) : kind = ExchangeResourceKind.entitlement;

  final ExchangeResourceKind kind;
  final String resourceId;

  @override
  State<ExchangeResourceDetailScreen> createState() =>
      _ExchangeResourceDetailScreenState();
}

class _ExchangeResourceDetailScreenState
    extends State<ExchangeResourceDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() => switch (widget.kind) {
    ExchangeResourceKind.evidence =>
      context.read<ExchangeProvider>().loadEvidenceDetail(widget.resourceId),
    ExchangeResourceKind.entitlement =>
      context.read<ExchangeProvider>().loadEntitlementDetail(widget.resourceId),
  };

  @override
  Widget build(BuildContext context) {
    final exchange = context.watch<ExchangeProvider>();
    final evidence = exchange.evidenceDetail?.id == widget.resourceId
        ? exchange.evidenceDetail
        : null;
    final entitlement = exchange.entitlementDetail?.id == widget.resourceId
        ? exchange.entitlementDetail
        : null;
    final available = evidence != null || entitlement != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.kind == ExchangeResourceKind.evidence
              ? 'Evidence status'
              : 'Entitlement status',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: exchange.resourceDetailLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (exchange.resourceDetailLoading && !available) ...[
                const SizedBox(height: 80),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 10),
                const Center(child: Text('Checking ticket status…')),
              ] else if (exchange.resourceDetailError != null && !available)
                _ErrorCard(message: exchange.resourceDetailError!, retry: _load)
              else if (evidence != null)
                _EvidenceDetail(evidence: evidence)
              else if (entitlement != null)
                _EntitlementDetail(entitlement: entitlement),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenceDetail extends StatelessWidget {
  const _EvidenceDetail({required this.evidence});

  final EvidenceProjection evidence;

  @override
  Widget build(BuildContext context) {
    final eligibility = evidence.latestEligibility;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BoundaryCard(
          text:
              'This is a processing record. Protected upload/provider '
              'references are write-only and are never displayed.',
        ),
        const SizedBox(height: 14),
        _StatusCard(
          title: _humanize(evidence.evidenceType),
          rows: [
            ('Processing state', _humanize(evidence.state.name)),
            ('Provider', _humanize(evidence.providerKey)),
            ('Vertical', _humanize(evidence.verticalKey)),
            ('Received', _formatDateTime(evidence.createdAt)),
            if (evidence.retentionUntil != null)
              ('Retention until', _formatDateTime(evidence.retentionUntil!)),
          ],
        ),
        const SizedBox(height: 14),
        _StatusCard(
          title: 'Eligibility decision',
          rows: eligibility == null
              ? const [('Decision', 'Not decided')]
              : [
                  ('Decision', _humanize(eligibility.decision.name)),
                  ('Reason', _humanize(eligibility.reasonCode)),
                  ('Valid until', _formatDateTime(eligibility.validUntil)),
                  ('Policy', eligibility.policyVersion),
                ],
        ),
      ],
    );
  }
}

class _EntitlementDetail extends StatelessWidget {
  const _EntitlementDetail({required this.entitlement});

  final EntitlementProjection entitlement;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _BoundaryCard(
        text:
            'Ticket status reflects available provider and Swappy checks. '
            'Protected ticket details stay private.',
      ),
      const SizedBox(height: 14),
      _StatusCard(
        title: entitlement.assignmentLabel,
        rows: [
          ('State', _humanize(entitlement.state.name)),
          ('Version', '${entitlement.version}'),
          ('Provider', _humanize(entitlement.providerKey)),
          ('Vertical', _humanize(entitlement.verticalKey)),
          ('Updated', _formatDateTime(entitlement.updatedAt)),
          ('Eligibility', _humanize(entitlement.eligibility.decision.name)),
          ('Valid until', _formatDateTime(entitlement.eligibility.validUntil)),
        ],
      ),
    ],
  );
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_outlined),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      row.$1,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(child: Text(row.$2)),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _humanize(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
