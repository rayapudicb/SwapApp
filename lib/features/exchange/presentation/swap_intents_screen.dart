import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/exchange_models.dart';
import '../providers/exchange_provider.dart';
import 'seat_marketplace_screen.dart';

class SwapIntentsScreen extends StatefulWidget {
  const SwapIntentsScreen({super.key});

  @override
  State<SwapIntentsScreen> createState() => _SwapIntentsScreenState();
}

class _SwapIntentsScreenState extends State<SwapIntentsScreen> {
  SwapIntentState? _stateFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ExchangeProvider>().loadIntents();
    });
  }

  Future<void> _setFilter(SwapIntentState? value) async {
    if (value == _stateFilter) return;
    setState(() => _stateFilter = value);
    await context.read<ExchangeProvider>().loadIntents(state: value);
  }

  @override
  Widget build(BuildContext context) {
    final exchange = context.watch<ExchangeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        actions: [
          IconButton(
            key: const ValueKey('swap-requests'),
            tooltip: 'Incoming and outgoing Swap Requests',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const SwapRequestsScreen()),
            ),
            icon: const Icon(Icons.move_to_inbox_outlined),
          ),
          IconButton(
            tooltip: 'Refresh swaps',
            onPressed: exchange.intentsLoading
                ? null
                : () => exchange.loadIntents(state: _stateFilter),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => exchange.loadIntents(state: _stateFilter),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _RequestsEntryCard(
                onOpen: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const SwapRequestsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              const _LifecycleBoundaryCard(),
              const SizedBox(height: 14),
              _StatusFilters(
                selected: _stateFilter,
                enabled:
                    !exchange.intentsLoading && !exchange.intentsLoadingMore,
                onSelected: _setFilter,
              ),
              if (exchange.intentsLoading && exchange.intents.isEmpty) ...[
                const SizedBox(height: 26),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 10),
                const Center(child: Text('Loading your Posts…')),
              ] else if (exchange.intentsError != null) ...[
                const SizedBox(height: 14),
                _ErrorCard(
                  message: exchange.intentsError!,
                  onRetry: () => exchange.loadIntents(state: _stateFilter),
                ),
              ] else if (exchange.intents.isEmpty) ...[
                const SizedBox(height: 24),
                const _EmptyIntentsCard(),
              ] else ...[
                const SizedBox(height: 18),
                ...exchange.intents.map(
                  (intent) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _IntentCard(intent: intent),
                  ),
                ),
                if (exchange.hasMoreIntents)
                  OutlinedButton.icon(
                    onPressed: exchange.intentsLoadingMore
                        ? null
                        : exchange.loadMoreIntents,
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      exchange.intentsLoadingMore
                          ? 'Loading swaps…'
                          : 'Load more swaps',
                    ),
                  ),
              ],
              if (exchange.commandError != null) ...[
                const SizedBox(height: 12),
                _CommandErrorCard(exchange: exchange),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsEntryCard extends StatelessWidget {
  const _RequestsEntryCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.move_to_inbox_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Swap Requests',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 3),
                Text('Review incoming interest and track outgoing requests.'),
              ],
            ),
          ),
          TextButton(onPressed: onOpen, child: const Text('Open')),
        ],
      ),
    ),
  );
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final SwapIntentState? selected;
  final bool enabled;
  final ValueChanged<SwapIntentState?> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Status',
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                key: const ValueKey('swap-filter-all'),
                label: const Text('All'),
                selected: selected == null,
                onSelected: enabled ? (_) => onSelected(null) : null,
              ),
            ),
            ...SwapIntentState.values.map(
              (state) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  key: ValueKey('swap-filter-${state.name}'),
                  label: Text(_humanize(state.name)),
                  selected: selected == state,
                  onSelected: enabled ? (_) => onSelected(state) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LifecycleBoundaryCard extends StatelessWidget {
  const _LifecycleBoundaryCard();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.swap_horiz, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'A Post shows what you are offering and what you want in return. '
              'Nothing is exchanged until both participants complete the '
              'required confirmation steps.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyIntentsCard extends StatelessWidget {
  const _EmptyIntentsCard();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 44,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          const Text(
            'No swap intents returned',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use Post to add a ticket and create a draft. No sample swaps are '
            'displayed.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({required this.intent});

  final SwapIntentProjection intent;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SwapIntentDetailScreen(intentId: intent.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _offeredTicketLabel(intent),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                Chip(label: Text(_humanize(intent.state.name))),
              ],
            ),
            const SizedBox(height: 6),
            Text(_desiredSummary(intent)),
            if (intent.cashDifference.direction !=
                CashDifferenceDirection.none) ...[
              const SizedBox(height: 4),
              Text(
                _cashSummary(intent.cashDifference),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Version ${intent.version} · Expires ${_formatDateTime(intent.expiresAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class SwapIntentDetailScreen extends StatefulWidget {
  const SwapIntentDetailScreen({required this.intentId, super.key});

  final String intentId;

  @override
  State<SwapIntentDetailScreen> createState() => _SwapIntentDetailScreenState();
}

class _SwapIntentDetailScreenState extends State<SwapIntentDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ExchangeProvider>().loadIntentDetail(widget.intentId);
      }
    });
  }

  Future<void> _run(
    Future<bool> Function(ExchangeProvider provider) command,
  ) async {
    final provider = context.read<ExchangeProvider>();
    final succeeded = await command(provider);
    if (succeeded && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post updated.')));
    }
  }

  Future<void> _edit(SwapIntentProjection intent) async {
    final changes = await showModalBottomSheet<_IntentChanges>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditIntentSheet(intent: intent),
    );
    if (changes == null || !mounted) return;
    await _run(
      (provider) => provider.updateIntent(
        intent.id,
        UpdateSwapIntentRequest(
          desiredAssignmentLabels: changes.labels,
          acceptsAnyAssignment: changes.acceptsAny,
          expiresAt: changes.expiresAt,
          expectedVersion: intent.version,
          cashDifferenceDirection: intent.cashDifference.direction,
          cashDifferenceAmountMinor: intent.cashDifference.amountMinor,
          cashDifferenceCurrency: intent.cashDifference.currency,
        ),
      ),
    );
  }

  Future<void> _confirmWithdraw(SwapIntentProjection intent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw this intent?'),
        content: const Text(
          'This Post will be closed and will no longer appear to other '
          'participants. You cannot reopen it after withdrawing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run((provider) => provider.withdrawIntent(intent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final exchange = context.watch<ExchangeProvider>();
    final detail = exchange.detail?.intent.id == widget.intentId
        ? exchange.detail
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Swap intent'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: exchange.detailLoading
                ? null
                : () => exchange.loadIntentDetail(widget.intentId),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => exchange.loadIntentDetail(widget.intentId),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (exchange.detailLoading && detail == null) ...[
                const SizedBox(height: 80),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 12),
                const Center(child: Text('Loading Post details…')),
              ] else if (exchange.detailError != null && detail == null)
                _ErrorCard(
                  message: exchange.detailError!,
                  onRetry: () => exchange.loadIntentDetail(widget.intentId),
                )
              else if (detail != null) ...[
                if (exchange.detailError != null) ...[
                  _ErrorCard(
                    message: exchange.detailError!,
                    onRetry: () => exchange.loadIntentDetail(widget.intentId),
                  ),
                  const SizedBox(height: 12),
                ],
                _IntentSummaryCard(intent: detail.intent),
                const SizedBox(height: 14),
                _LifecycleActions(
                  intent: detail.intent,
                  disabled:
                      exchange.commandBlocked || exchange.detailError != null,
                  onEdit: () => _edit(detail.intent),
                  onPublish: () =>
                      _run((provider) => provider.publishIntent(detail.intent)),
                  onPause: () =>
                      _run((provider) => provider.pauseIntent(detail.intent)),
                  onResume: () =>
                      _run((provider) => provider.resumeIntent(detail.intent)),
                  onWithdraw: () => _confirmWithdraw(detail.intent),
                ),
                if (exchange.commandRunning) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Saving changes…'),
                ],
                if (exchange.commandError != null) ...[
                  const SizedBox(height: 14),
                  _CommandErrorCard(exchange: exchange),
                ],
                const SizedBox(height: 22),
                Text(
                  'Lifecycle timeline',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                if (detail.timeline.isEmpty)
                  const Text('No activity yet.')
                else
                  ...detail.timeline.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history),
                      title: Text(
                        '${item.fromState == null ? 'Created' : _humanize(item.fromState!)} '
                        '→ ${_humanize(item.toState)}',
                      ),
                      subtitle: Text(
                        '${_humanize(item.actorType.name)} · '
                        '${_humanize(item.reasonCode)} · '
                        '${_formatDateTime(item.occurredAt)}',
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IntentSummaryCard extends StatelessWidget {
  const _IntentSummaryCard({required this.intent});

  final SwapIntentProjection intent;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _offeredTicketLabel(intent),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Chip(label: Text(_humanize(intent.state.name))),
            ],
          ),
          const SizedBox(height: 10),
          _KeyValue(label: 'Looking for', value: _desiredSummary(intent)),
          _KeyValue(label: 'Cash', value: _cashSummary(intent.cashDifference)),
          _KeyValue(label: 'Version', value: '${intent.version}'),
          _KeyValue(label: 'Expires', value: _formatDateTime(intent.expiresAt)),
          const Divider(height: 24),
          const Text(
            'A Post is not a completed swap. You will see each confirmation '
            'step before any exchange can proceed.',
          ),
        ],
      ),
    ),
  );
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _LifecycleActions extends StatelessWidget {
  const _LifecycleActions({
    required this.intent,
    required this.disabled,
    required this.onEdit,
    required this.onPublish,
    required this.onPause,
    required this.onResume,
    required this.onWithdraw,
  });

  final SwapIntentProjection intent;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final open = {
      SwapIntentState.draft,
      SwapIntentState.published,
      SwapIntentState.paused,
    }.contains(intent.state);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (intent.state == SwapIntentState.draft ||
            intent.state == SwapIntentState.paused)
          OutlinedButton.icon(
            onPressed: disabled ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        if (intent.state == SwapIntentState.draft)
          FilledButton.icon(
            onPressed: disabled ? null : onPublish,
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Publish'),
          ),
        if (intent.state == SwapIntentState.published)
          FilledButton.tonalIcon(
            onPressed: disabled ? null : onPause,
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('Pause'),
          ),
        if (intent.state == SwapIntentState.paused)
          FilledButton.icon(
            onPressed: disabled ? null : onResume,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Resume'),
          ),
        if (open)
          TextButton.icon(
            onPressed: disabled ? null : onWithdraw,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Withdraw'),
          ),
      ],
    );
  }
}

class _EditIntentSheet extends StatefulWidget {
  const _EditIntentSheet({required this.intent});

  final SwapIntentProjection intent;

  @override
  State<_EditIntentSheet> createState() => _EditIntentSheetState();
}

class _EditIntentSheetState extends State<_EditIntentSheet> {
  late final TextEditingController _labels;
  late bool _acceptsAny;
  int _extensionDays = 1;

  @override
  void initState() {
    super.initState();
    _acceptsAny = widget.intent.acceptsAnyAssignment;
    _labels = TextEditingController(
      text: widget.intent.desiredAssignmentLabels.join(', '),
    );
  }

  @override
  void dispose() {
    _labels.dispose();
    super.dispose();
  }

  List<String> get _parsedLabels => _labels.text
      .split(RegExp(r'[,\n]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);

  void _save() {
    final labels = _acceptsAny ? const <String>[] : _parsedLabels;
    if (!_acceptsAny && labels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one assignment.')),
      );
      return;
    }
    if (labels.length > 20 || labels.any((value) => value.length > 128)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use up to 20 labels, 128 characters each.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _IntentChanges(
        labels: labels,
        acceptsAny: _acceptsAny,
        expiresAt: DateTime.now().toUtc().add(Duration(days: _extensionDays)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 12,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        Text(
          'Edit version ${widget.intent.version}',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Accept any assignment'),
          value: _acceptsAny,
          onChanged: (value) => setState(() => _acceptsAny = value),
        ),
        TextField(
          controller: _labels,
          enabled: !_acceptsAny,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Desired assignments',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _extensionDays,
          decoration: const InputDecoration(
            labelText: 'New expiry from now',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 1, child: Text('1 day')),
            DropdownMenuItem(value: 3, child: Text('3 days')),
            DropdownMenuItem(value: 7, child: Text('7 days')),
            DropdownMenuItem(value: 30, child: Text('30 days')),
            DropdownMenuItem(value: 90, child: Text('90 days')),
          ],
          onChanged: (value) => setState(() => _extensionDays = value ?? 1),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save new version'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class _IntentChanges {
  const _IntentChanges({
    required this.labels,
    required this.acceptsAny,
    required this.expiresAt,
  });

  final List<String> labels;
  final bool acceptsAny;
  final DateTime expiresAt;
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CommandErrorCard extends StatelessWidget {
  const _CommandErrorCard({required this.exchange});

  final ExchangeProvider exchange;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exchange.commandError!),
            if (exchange.commandCorrelationId != null) ...[
              const SizedBox(height: 6),
              SelectableText(
                'Support reference: ${exchange.commandCorrelationId}',
              ),
            ],
            if (exchange.canRetryUnknownCommand) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: exchange.commandRunning
                    ? null
                    : exchange.retryUnknownCommand,
                icon: const Icon(Icons.replay),
                label: Text(
                  'Retry ${exchange.pendingCommandLabel ?? 'same request'} safely',
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

String _desiredSummary(SwapIntentProjection intent) =>
    intent.acceptsAnyAssignment
    ? 'Any assignment in the same context'
    : intent.desiredAssignmentLabels.join(', ');

String _offeredTicketLabel(SwapIntentProjection intent) {
  final providerTicket = intent.offeredEntitlement;
  if (providerTicket != null) return providerTicket.assignmentLabel;
  final photoTicket = intent.offeredTicketBundle;
  if (photoTicket == null) return 'Ticket unavailable';
  final assignment = [
    photoTicket.sectionLabel,
    photoTicket.rowLabel,
    if (photoTicket.seatLabels.isNotEmpty)
      'Seats ${photoTicket.seatLabels.join(', ')}',
  ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
  return assignment.isEmpty ? photoTicket.eventTitle : assignment;
}

String _cashSummary(PostCashDifference cash) {
  if (cash.direction == CashDifferenceDirection.none) {
    return 'No cash difference';
  }
  final amount = cash.amountMinor == null
      ? 'Amount unavailable'
      : _currencyAmount(cash.currency ?? '', cash.amountMinor!);
  final direction = cash.direction == CashDifferenceDirection.willPay
      ? 'Will pay $amount'
      : 'Wants to receive $amount';
  return '$direction · Proposal only · Payment not protected';
}

String _currencyAmount(String currency, int minor) => currency == 'INR'
    ? 'INR ${(minor ~/ 100)}.${(minor % 100).toString().padLeft(2, '0')}'
    : '$currency $minor minor units';

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
