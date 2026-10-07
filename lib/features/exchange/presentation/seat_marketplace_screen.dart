import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/exchange_marketplace_models.dart';
import '../domain/exchange_models.dart';
import '../providers/exchange_provider.dart';
import 'agreement_hold_screen.dart';
import 'models/swap_comparison_view_data.dart';
import 'swap_conversation_screen.dart';
import 'widgets/seat_swap_comparison_card.dart';

class SeatMarketplaceScreen extends StatefulWidget {
  const SeatMarketplaceScreen({this.contextRef, super.key});

  final String? contextRef;

  @override
  State<SeatMarketplaceScreen> createState() => _SeatMarketplaceScreenState();
}

class _SeatMarketplaceScreenState extends State<SeatMarketplaceScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final exchange = context.read<ExchangeProvider>();
    await Future.wait([
      exchange.loadPublishedPosts(contextRef: widget.contextRef, force: true),
      exchange.loadIntents(state: SwapIntentState.published),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final exchange = context.watch<ExchangeProvider>();
    final posts = exchange.publishedPosts;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contextRef == null ? 'Find seats' : 'Event swaps'),
        actions: [
          IconButton(
            tooltip: 'Refresh published Posts',
            onPressed: exchange.publishedPostsLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const _MarketplaceBoundaryCard(),
              if (exchange.publishedPostsLoading && posts.isEmpty) ...[
                const SizedBox(height: 40),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 10),
                const Center(child: Text('Loading published seat Posts…')),
              ] else if (exchange.publishedPostsError != null && posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _ErrorCard(
                    message: exchange.publishedPostsError!,
                    onRetry: _load,
                  ),
                )
              else if (posts.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: _EmptyMarketplaceCard(),
                )
              else ...[
                if (exchange.publishedPostsError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _ErrorCard(
                      message: exchange.publishedPostsError!,
                      onRetry: _load,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Seat offers',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Open an offer, then compare it with one of your available seats.',
                ),
                const SizedBox(height: 12),
                ...posts.map(
                  (post) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PostCard(
                      post: post,
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              PublishedPostDetailScreen(postId: post.post.id),
                        ),
                      ),
                    ),
                  ),
                ),
                if (exchange.hasMorePublishedPosts)
                  OutlinedButton.icon(
                    onPressed: exchange.publishedPostsLoadingMore
                        ? null
                        : exchange.loadMorePublishedPosts,
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      exchange.publishedPostsLoadingMore
                          ? 'Loading more…'
                          : 'Load more Posts',
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

class PublishedPostDetailScreen extends StatefulWidget {
  const PublishedPostDetailScreen({required this.postId, super.key});

  final String postId;

  @override
  State<PublishedPostDetailScreen> createState() =>
      _PublishedPostDetailScreenState();
}

class _PublishedPostDetailScreenState extends State<PublishedPostDetailScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final exchange = context.read<ExchangeProvider>();
    await Future.wait([
      exchange.loadPublishedPostDetail(widget.postId),
      exchange.loadIntents(state: SwapIntentState.published),
    ]);
  }

  List<SwapIntentProjection> _compatiblePosts(
    ExchangeProvider exchange,
    SwapPostProjection target,
  ) {
    if (!target.post.expiresAt.isAfter(
      DateTime.now().toUtc().add(const Duration(minutes: 5, seconds: 2)),
    )) {
      return const [];
    }
    return exchange.intents
        .where(
          (own) =>
              own.state == SwapIntentState.published &&
              own.id != target.post.id &&
              swapIntentContextRef(own) == swapIntentContextRef(target.post) &&
              swapIntentQuantity(own) == swapIntentQuantity(target.post) &&
              own.expiresAt.isAfter(
                DateTime.now().toUtc().add(
                  const Duration(minutes: 5, seconds: 10),
                ),
              ),
        )
        .toList(growable: false);
  }

  Future<void> _openRequest(
    SwapPostProjection target,
    List<SwapIntentProjection> compatible,
  ) async {
    final exchange = context.read<ExchangeProvider>();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _SwapRequestSheet(
        target: target,
        compatiblePosts: compatible,
        onSubmit: (input) async {
          try {
            final succeeded = await exchange.createSwapRequest(
              target,
              input.ownPost,
              CreateSwapRequestRequest(
                counterpartyIntentId: input.ownPost.id,
                targetIntentVersion: target.post.version,
                counterpartyIntentVersion: input.ownPost.version,
                cashDirection: input.cashDirection,
                cashAmountMinor: input.cashAmountMinor,
                cashCurrency: input.cashCurrency,
                expiresAt: input.expiresAt,
              ),
            );
            return succeeded
                ? null
                : exchange.commandError ??
                      'The Swap Request could not be sent.';
          } on ExchangeContractException catch (error) {
            return error.message;
          }
        },
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Swap Request sent. No ticket or money was transferred.',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final exchange = context.watch<ExchangeProvider>();
    final detail = exchange.publishedPostDetail?.post.id == widget.postId
        ? exchange.publishedPostDetail
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seat offer'),
        actions: [
          IconButton(
            tooltip: 'Refresh Post',
            onPressed: exchange.publishedPostDetailLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (exchange.publishedPostDetailLoading && detail == null) ...[
                const SizedBox(height: 80),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 10),
                const Center(child: Text('Loading the latest Post…')),
              ] else if (exchange.publishedPostDetailError != null &&
                  detail == null)
                _ErrorCard(
                  message: exchange.publishedPostDetailError!,
                  onRetry: _load,
                )
              else if (detail != null) ...[
                _PostSummary(post: detail.post, heading: 'Seat offered'),
                const SizedBox(height: 12),
                const _TrustWarning(),
                const SizedBox(height: 18),
                if (detail.isOwnPost)
                  const _InformationCard(
                    icon: Icons.person_outline,
                    title: 'This is your Post',
                    message:
                        'Manage it from My Posts. You cannot request your own Post.',
                  )
                else if (!detail.requestable)
                  const _InformationCard(
                    icon: Icons.block_outlined,
                    title: 'Requests are unavailable',
                    message:
                        'This Post is not accepting Swap Requests right now.',
                  )
                else
                  Builder(
                    builder: (context) {
                      final targetCanAccept = detail.post.expiresAt.isAfter(
                        DateTime.now().toUtc().add(
                          const Duration(minutes: 5, seconds: 2),
                        ),
                      );
                      if (!targetCanAccept) {
                        return const _InformationCard(
                          icon: Icons.timer_off_outlined,
                          title: 'This Post is about to expire',
                          message:
                              'There is not enough time to create a valid request. Refresh to find another Post.',
                        );
                      }
                      final compatible = _compatiblePosts(exchange, detail);
                      if (exchange.intentsLoading && exchange.intents.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (compatible.isEmpty) {
                        return _InformationCard(
                          icon: Icons.add_box_outlined,
                          title: 'Add and publish your seat first',
                          message:
                              'The current service requires your own published seat for the same event and quantity before you can request this offer.',
                          actionLabel: 'Create or publish my Post',
                          onAction: () => Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst),
                        );
                      }
                      return FilledButton.icon(
                        key: const ValueKey('send-swap-request'),
                        onPressed: exchange.commandBlocked
                            ? null
                            : () => _openRequest(detail, compatible),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Offer my seat'),
                      );
                    },
                  ),
                if (exchange.commandRunning) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 6),
                  const Text('Sending your request…'),
                ],
                if (exchange.commandError != null) ...[
                  const SizedBox(height: 14),
                  _CommandErrorCard(exchange: exchange),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SwapRequestsScreen extends StatefulWidget {
  const SwapRequestsScreen({super.key});

  @override
  State<SwapRequestsScreen> createState() => _SwapRequestsScreenState();
}

class _SwapRequestsScreenState extends State<SwapRequestsScreen>
    with WidgetsBindingObserver {
  SwapRequestRole _role = SwapRequestRole.targetOwner;
  SwapRequestState? _stateFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ExchangeProvider>().loadSwapRequests(state: _stateFilter);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ExchangeProvider>().loadSwapRequests(state: _stateFilter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exchange = context.watch<ExchangeProvider>();
    final requests = _role == SwapRequestRole.targetOwner
        ? exchange.incomingSwapRequests
        : exchange.outgoingSwapRequests;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swap Requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh requests',
            onPressed: exchange.swapRequestsLoading
                ? null
                : () => exchange.loadSwapRequests(state: _stateFilter),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => exchange.loadSwapRequests(state: _stateFilter),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              SegmentedButton<SwapRequestRole>(
                segments: const [
                  ButtonSegment(
                    value: SwapRequestRole.targetOwner,
                    icon: Icon(Icons.call_received),
                    label: Text('Incoming'),
                  ),
                  ButtonSegment(
                    value: SwapRequestRole.requester,
                    icon: Icon(Icons.call_made),
                    label: Text('Outgoing'),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (value) {
                  setState(() => _role = value.single);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SwapRequestState?>(
                initialValue: _stateFilter,
                decoration: const InputDecoration(
                  labelText: 'Request status',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<SwapRequestState?>(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  ...SwapRequestState.values.map(
                    (state) => DropdownMenuItem<SwapRequestState?>(
                      value: state,
                      child: Text(_humanize(state.name)),
                    ),
                  ),
                ],
                onChanged: exchange.swapRequestsLoading
                    ? null
                    : (value) {
                        setState(() => _stateFilter = value);
                        exchange.loadSwapRequests(state: value);
                      },
              ),
              const SizedBox(height: 14),
              const _InformationCard(
                icon: Icons.info_outline,
                title: 'Interest, not a completed swap',
                message:
                    'Selecting a request pauses both Posts and opens a participant-reported agreement. It does not reserve or transfer tickets, verify cash, or process money.',
              ),
              if (exchange.swapRequestsError != null &&
                  exchange.swapRequests.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _ErrorCard(
                    message:
                        'Showing saved results. ${exchange.swapRequestsError!}',
                    onRetry: () =>
                        exchange.loadSwapRequests(state: _stateFilter),
                  ),
                ),
              if (exchange.swapRequestsLoading &&
                  exchange.swapRequests.isEmpty) ...[
                const SizedBox(height: 36),
                const Center(child: CircularProgressIndicator()),
              ] else if (exchange.swapRequestsError != null &&
                  exchange.swapRequests.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _ErrorCard(
                    message: exchange.swapRequestsError!,
                    onRetry: () =>
                        exchange.loadSwapRequests(state: _stateFilter),
                  ),
                )
              else if (requests.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _InformationCard(
                    icon: Icons.inbox_outlined,
                    title: _role == SwapRequestRole.targetOwner
                        ? 'No incoming requests'
                        : 'No outgoing requests',
                    message: _role == SwapRequestRole.targetOwner
                        ? 'Requests appear here after another participant offers a compatible published Post.'
                        : 'Browse Find seats to request another participant’s published Post.',
                  ),
                )
              else ...[
                const SizedBox(height: 14),
                ...requests.map(
                  (request) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RequestCard(
                      request: request,
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              SwapRequestDetailScreen(requestId: request.id),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (exchange.hasMoreSwapRequests) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: exchange.swapRequestsLoadingMore
                      ? null
                      : exchange.loadMoreSwapRequests,
                  icon: const Icon(Icons.expand_more),
                  label: Text(
                    exchange.swapRequestsLoadingMore
                        ? 'Loading more…'
                        : 'Load more Requests',
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

class SwapRequestDetailScreen extends StatefulWidget {
  const SwapRequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  State<SwapRequestDetailScreen> createState() =>
      _SwapRequestDetailScreenState();
}

class _SwapRequestDetailScreenState extends State<SwapRequestDetailScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ExchangeProvider>().loadSwapRequestDetail(
          widget.requestId,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ExchangeProvider>().loadSwapRequestDetail(widget.requestId);
    }
  }

  Future<void> _run(
    String action,
    SwapRequestProjection request,
    Future<bool> Function(ExchangeProvider, SwapRequestProjection) command,
  ) async {
    final message = switch (action) {
      'Select' =>
        'Selecting pauses both Posts and opens a two-way agreement. Each person must then confirm consent, ticket handoff, and any cash directly exchanged.',
      'Reject' => 'Reject this incoming request?',
      _ => 'Withdraw this outgoing request?',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$action Swap Request?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final exchange = context.read<ExchangeProvider>();
    final succeeded = await command(exchange, request);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? action == 'Select'
                    ? 'Request accepted. Open the agreement to continue.'
                    : 'Swap Request updated.'
              : exchange.commandError ?? 'The action could not be completed.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exchange = context.watch<ExchangeProvider>();
    final detail =
        exchange.swapRequestDetail?.swapRequest.id == widget.requestId
        ? exchange.swapRequestDetail
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swap Request'),
        actions: [
          IconButton(
            tooltip: 'Refresh request',
            onPressed: exchange.swapRequestDetailLoading
                ? null
                : () => exchange.loadSwapRequestDetail(widget.requestId),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => exchange.loadSwapRequestDetail(widget.requestId),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (exchange.swapRequestDetailLoading && detail == null) ...[
                const SizedBox(height: 80),
                const Center(child: CircularProgressIndicator()),
              ] else if (exchange.swapRequestDetailError != null &&
                  detail == null)
                _ErrorCard(
                  message: exchange.swapRequestDetailError!,
                  onRetry: () =>
                      exchange.loadSwapRequestDetail(widget.requestId),
                )
              else if (detail != null) ...[
                if (exchange.swapRequestDetailError != null) ...[
                  _ErrorCard(
                    message: exchange.swapRequestDetailError!,
                    onRetry: () =>
                        exchange.loadSwapRequestDetail(widget.requestId),
                  ),
                  const SizedBox(height: 12),
                ],
                _RequestHeader(request: detail.swapRequest),
                const SizedBox(height: 12),
                SeatSwapComparisonCard(
                  comparison: SwapComparisonViewData.fromRequest(
                    detail.swapRequest,
                  ),
                  title: 'Seats in this request',
                  supportingText:
                      'Review the current seat details before taking action.',
                ),
                const SizedBox(height: 12),
                _InformationCard(
                  icon: Icons.info_outline,
                  title: 'What this means',
                  message: detail.swapRequest.warning,
                ),
                if (detail.swapRequest.state == SwapRequestState.selected &&
                    detail.swapRequest.agreementId != null) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => AgreementHoldScreen(
                          agreementId: detail.swapRequest.agreementId!,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.handshake_outlined),
                    label: const Text('Open swap agreement'),
                  ),
                ],
                if (detail.swapRequest.state == SwapRequestState.submitted) ...[
                  const SizedBox(height: 14),
                  if (requestPostsChangedSinceSubmission(
                    detail.swapRequest,
                  )) ...[
                    const _InformationCard(
                      icon: Icons.sync_problem_outlined,
                      title: 'A seat offer changed',
                      message:
                          'One of the Posts changed after this request was sent. Refresh and create a new request so both people review the same seats.',
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (detail.swapRequest.role == SwapRequestRole.targetOwner &&
                      exchange.selectionRetryAt?.isAfter(
                            DateTime.now().toUtc(),
                          ) ==
                          true) ...[
                    _InformationCard(
                      icon: Icons.schedule,
                      title: 'Daily selection limit reached',
                      message:
                          'You can select another request after '
                          '${_formatDate(exchange.selectionRetryAt!)}.',
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (detail.swapRequest.role == SwapRequestRole.targetOwner)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              exchange.selectionBlocked ||
                                  requestPostsChangedSinceSubmission(
                                    detail.swapRequest,
                                  ) ||
                                  exchange.swapRequestDetailError != null
                              ? null
                              : () => _run(
                                  'Select',
                                  detail.swapRequest,
                                  (provider, request) =>
                                      provider.selectSwapRequest(request),
                                ),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Select interest'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              exchange.commandBlocked ||
                                  exchange.swapRequestDetailError != null
                              ? null
                              : () => _run(
                                  'Reject',
                                  detail.swapRequest,
                                  (provider, request) =>
                                      provider.rejectSwapRequest(request),
                                ),
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                        ),
                      ],
                    )
                  else
                    OutlinedButton.icon(
                      onPressed:
                          exchange.commandBlocked ||
                              exchange.swapRequestDetailError != null
                          ? null
                          : () => _run(
                              'Withdraw',
                              detail.swapRequest,
                              (provider, request) =>
                                  provider.withdrawSwapRequest(request),
                            ),
                      icon: const Icon(Icons.undo),
                      label: const Text('Withdraw Request'),
                    ),
                ],
                if (exchange.commandRunning) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(),
                ],
                if (exchange.commandError != null) ...[
                  const SizedBox(height: 14),
                  _CommandErrorCard(exchange: exchange),
                ],
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => SwapConversationScreen(
                          requestId: detail.swapRequest.id,
                          canSend:
                              detail.swapRequest.state ==
                                  SwapRequestState.submitted ||
                              detail.swapRequest.state ==
                                  SwapRequestState.selected,
                        ),
                      ),
                    );
                    if (context.mounted) {
                      await context
                          .read<ExchangeProvider>()
                          .loadSwapRequestDetail(widget.requestId);
                    }
                  },
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Open conversation'),
                ),
                const SizedBox(height: 22),
                Text(
                  'Timeline',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (detail.timeline.isEmpty)
                  const Text('No request activity yet.')
                else
                  ...detail.timeline.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history),
                      title: Text(
                        '${item.fromState ?? 'Created'} → ${_humanize(item.toState)}',
                      ),
                      subtitle: Text(
                        '${_humanize(item.reasonCode)} · ${_formatDate(item.occurredAt)}',
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

class _SwapRequestSheet extends StatefulWidget {
  const _SwapRequestSheet({
    required this.target,
    required this.compatiblePosts,
    required this.onSubmit,
  });

  final SwapPostProjection target;
  final List<SwapIntentProjection> compatiblePosts;
  final Future<String?> Function(_SwapRequestInput input) onSubmit;

  @override
  State<_SwapRequestSheet> createState() => _SwapRequestSheetState();
}

class _SwapRequestSheetState extends State<_SwapRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late SwapIntentProjection _ownPost;
  RequestCashDirection _cashDirection = RequestCashDirection.none;
  Duration? _duration;
  bool _submitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _ownPost = widget.compatiblePosts.first;
    final durations = _durations;
    _duration = durations.isEmpty ? null : durations.first;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  DateTime get _latestExpiry {
    final nowLimit = DateTime.now().toUtc().add(const Duration(days: 30));
    var value = widget.target.post.expiresAt.toUtc();
    if (_ownPost.expiresAt.toUtc().isBefore(value)) value = _ownPost.expiresAt;
    if (nowLimit.isBefore(value)) value = nowLimit;
    return value;
  }

  List<Duration> get _durations {
    final now = DateTime.now().toUtc();
    final maximum = _latestExpiry.difference(now);
    final standard = const [
      Duration(hours: 1),
      Duration(days: 1),
      Duration(days: 3),
      Duration(days: 7),
      Duration(days: 30),
    ].where((duration) => duration + const Duration(seconds: 1) < maximum);
    final values = standard.toList(growable: true);
    if (values.isEmpty && maximum > const Duration(minutes: 5)) {
      values.add(maximum - const Duration(seconds: 2));
    }
    return values;
  }

  void _selectOwnPost(SwapIntentProjection value) {
    setState(() {
      _ownPost = value;
      final options = _durations;
      if (!options.contains(_duration)) {
        _duration = options.isEmpty ? null : options.first;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final duration = _duration;
    if (duration == null) return;
    final now = DateTime.now().toUtc();
    final ceiling = _latestExpiry.subtract(const Duration(seconds: 1));
    final proposed = now.add(duration);
    final expiresAt = proposed.isAfter(ceiling) ? ceiling : proposed;
    if (!expiresAt.isAfter(now.add(const Duration(minutes: 5)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The selected Posts expire too soon. Refresh them.'),
        ),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _submissionError = null;
    });
    final error = await widget.onSubmit(
      _SwapRequestInput(
        ownPost: _ownPost,
        cashDirection: _cashDirection,
        cashAmountMinor: _cashDirection == RequestCashDirection.none
            ? null
            : _parseInrMinor(_amount.text),
        cashCurrency: _cashDirection == RequestCashDirection.none
            ? null
            : 'INR',
        expiresAt: expiresAt,
      ),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _submissionError = error;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            'Review Swap Request',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SwapIntentProjection>(
            initialValue: _ownPost,
            decoration: const InputDecoration(
              labelText: 'Seat you will give',
              border: OutlineInputBorder(),
            ),
            items: widget.compatiblePosts
                .map(
                  (post) => DropdownMenuItem(
                    value: post,
                    child: Text(
                      _ticketAssignment(post),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) _selectOwnPost(value);
            },
          ),
          const SizedBox(height: 12),
          SeatSwapComparisonCard(
            comparison: SwapComparisonViewData.fromPosts(
              youGive: _ownPost,
              youReceive: widget.target.post,
              cashSummary: requestCashSummaryForViewer(
                direction: _cashDirection,
                amountMinor: _cashDirection == RequestCashDirection.none
                    ? null
                    : _parseInrMinor(_amount.text),
                currency: _cashDirection == RequestCashDirection.none
                    ? null
                    : 'INR',
                role: SwapRequestRole.requester,
              ),
            ),
            title: 'Your proposed swap',
            supportingText:
                'Check both seats before sending. Current matching confirms the event and seat count, not every seat preference.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Duration>(
            key: ValueKey(_duration),
            initialValue: _duration,
            decoration: const InputDecoration(
              labelText: 'Request expires in',
              border: OutlineInputBorder(),
            ),
            items: _durations
                .map(
                  (duration) => DropdownMenuItem(
                    value: duration,
                    child: Text(_durationLabel(duration)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _duration = value);
            },
            validator: (value) => value == null
                ? 'These Posts expire too soon. Refresh and try again.'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RequestCashDirection>(
            initialValue: _cashDirection,
            decoration: const InputDecoration(
              labelText: 'Cash top-up (optional)',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: RequestCashDirection.none,
                child: Text('No top-up'),
              ),
              DropdownMenuItem(
                value: RequestCashDirection.requesterPaysOwner,
                child: Text('I will add cash'),
              ),
              DropdownMenuItem(
                value: RequestCashDirection.ownerPaysRequester,
                child: Text('I want them to add cash'),
              ),
            ],
            onChanged: (value) => setState(
              () => _cashDirection = value ?? RequestCashDirection.none,
            ),
          ),
          if (_cashDirection != RequestCashDirection.none) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (INR)',
                helperText: 'Up to two decimal places.',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: _validateInrAmount,
            ),
          ],
          const SizedBox(height: 12),
          const _InformationCard(
            icon: Icons.info_outline,
            title: 'This sends interest only',
            message:
                'Sending does not reserve or transfer either ticket. Swappy does not process or protect cash top-ups.',
          ),
          const SizedBox(height: 16),
          if (_submissionError != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                _submissionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_submitting) const LinearProgressIndicator(),
          if (_submitting) const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: const Icon(Icons.send_outlined),
            label: Text(_submitting ? 'Sending…' : 'Send Swap Request'),
          ),
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}

class _SwapRequestInput {
  const _SwapRequestInput({
    required this.ownPost,
    required this.cashDirection,
    required this.cashAmountMinor,
    required this.cashCurrency,
    required this.expiresAt,
  });

  final SwapIntentProjection ownPost;
  final RequestCashDirection cashDirection;
  final int? cashAmountMinor;
  final String? cashCurrency;
  final DateTime expiresAt;
}

class _MarketplaceBoundaryCard extends StatelessWidget {
  const _MarketplaceBoundaryCard();

  @override
  Widget build(BuildContext context) => const _InformationCard(
    icon: Icons.search,
    title: 'Find a seat to swap',
    message:
        'Browse freely. To request a seat today, you need your own published seat for the same event and quantity.',
  );
}

class _EmptyMarketplaceCard extends StatelessWidget {
  const _EmptyMarketplaceCard();

  @override
  Widget build(BuildContext context) => const _InformationCard(
    icon: Icons.event_seat_outlined,
    title: 'No seat offers yet',
    message:
        'Pull to refresh later. Only seats currently offered for swapping appear here.',
  );
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap});

  final SwapPostProjection post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _ticketTitle(post.post),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                if (post.isOwnPost) const Chip(label: Text('Your Post')),
              ],
            ),
            const SizedBox(height: 6),
            Text(_ticketAssignment(post.post)),
            const SizedBox(height: 4),
            Text('Wants: ${_desired(post.post)}'),
            Text('Quantity: ${swapIntentQuantity(post.post)}'),
            Text('Cash: ${_postCash(post.post.cashDifference)}'),
            const SizedBox(height: 8),
            Text(
              '${_trustLabel(post.post)} · Expires ${_formatDate(post.post.expiresAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Any cash is a proposal only; payment is not protected.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _PostSummary extends StatelessWidget {
  const _PostSummary({required this.post, required this.heading});

  final SwapIntentProjection post;
  final String heading;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _ticketTitle(post),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(_ticketAssignment(post)),
          Text('Wants: ${_desired(post)}'),
          Text('Quantity: ${swapIntentQuantity(post)}'),
          Text('Cash: ${_postCash(post.cashDifference)}'),
          Text('Expires: ${_formatDate(post.expiresAt)}'),
          const SizedBox(height: 8),
          Text(
            _trustLabel(post),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _TrustWarning extends StatelessWidget {
  const _TrustWarning();

  @override
  Widget build(BuildContext context) => const _InformationCard(
    icon: Icons.photo_outlined,
    title: 'Check the trust label',
    message:
        'Photo checked means event and seat details were recognized. It does not verify ownership, validity, or transferability.',
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final SwapRequestProjection request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final comparison = SwapComparisonViewData.fromRequest(request);
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          request.role == SwapRequestRole.targetOwner
              ? Icons.call_received
              : Icons.call_made,
        ),
        title: Text(
          'Give ${comparison.youGive.shortAssignment} → '
          'Receive ${comparison.youReceive.shortAssignment}',
        ),
        subtitle: Text(
          '${_requestStateLabel(request)} · Expires ${_formatDate(request.expiresAt)}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _RequestHeader extends StatelessWidget {
  const _RequestHeader({required this.request});

  final SwapRequestProjection request;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.role == SwapRequestRole.targetOwner
                      ? 'Incoming request'
                      : 'Outgoing request',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(_requestStateLabel(request)),
                Text('Expires: ${_formatDate(request.expiresAt)}'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(message),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
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
            OutlinedButton.icon(
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exchange.commandError!),
            if (exchange.commandCorrelationId != null)
              SelectableText(
                'Support reference: ${exchange.commandCorrelationId}',
              ),
            if (exchange.commandRetryAt != null)
              Text('Try again after ${_formatDate(exchange.commandRetryAt!)}.'),
            if (exchange.canRetryUnknownCommand) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: exchange.commandRunning
                    ? null
                    : exchange.retryUnknownCommand,
                icon: const Icon(Icons.replay),
                label: Text(
                  'Retry ${exchange.pendingCommandLabel ?? 'same action'} safely',
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

String _ticketTitle(SwapIntentProjection post) =>
    post.offeredTicketBundle?.eventTitle ??
    (post.offeredEntitlement == null ? 'Seat Post' : 'Provider-verified seat');

String _ticketAssignment(SwapIntentProjection post) {
  final ticket = post.offeredTicketBundle;
  if (ticket == null) {
    return post.offeredEntitlement?.assignmentLabel ?? 'Seat unavailable';
  }
  return [
    if (ticket.venueName != null) ticket.venueName!,
    if (ticket.sectionLabel != null) 'Section ${ticket.sectionLabel}',
    if (ticket.rowLabel != null) 'Row ${ticket.rowLabel}',
    'Seats ${ticket.seatLabels.join(', ')}',
  ].join(' · ');
}

String _desired(SwapIntentProjection post) => post.acceptsAnyAssignment
    ? 'Any seat for this event'
    : post.desiredAssignmentLabels.join(', ');

String _trustLabel(SwapIntentProjection post) =>
    post.offeredSource == SwapIntentOfferedSource.photoChecked
    ? 'Photo checked — ownership and transfer not verified'
    : 'Provider verified';

String _requestStateLabel(SwapRequestProjection request) =>
    switch (request.state) {
      SwapRequestState.submitted =>
        request.role == SwapRequestRole.targetOwner
            ? 'Needs your response'
            : 'Waiting for response',
      SwapRequestState.selected => 'Accepted',
      SwapRequestState.rejected => 'Declined',
      SwapRequestState.withdrawn => 'Withdrawn',
      SwapRequestState.expired => 'Expired',
    };

String _postCash(PostCashDifference cash) => switch (cash.direction) {
  CashDifferenceDirection.none => 'None',
  CashDifferenceDirection.willPay =>
    'Offers ${_currencyAmount(cash.currency!, cash.amountMinor!)} — payment is not handled by Swappy',
  CashDifferenceDirection.wantsToReceive =>
    'Asks for ${_currencyAmount(cash.currency!, cash.amountMinor!)} — payment is not handled by Swappy',
};

String _currencyAmount(String currency, int minor) => currency == 'INR'
    ? 'INR ${(minor ~/ 100)}.${(minor % 100).toString().padLeft(2, '0')}'
    : '$currency $minor minor units';

String? _validateInrAmount(String? value) {
  final normalized = value?.trim() ?? '';
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) {
    return 'Enter INR with up to two decimal places.';
  }
  final minor = _parseInrMinor(normalized);
  return minor == null || minor < 1 || minor > 100000000
      ? 'Enter an amount from INR 0.01 to INR 1,000,000.'
      : null;
}

int? _parseInrMinor(String value) {
  final parts = value.trim().split('.');
  if (parts.isEmpty || parts.length > 2) return null;
  final whole = int.tryParse(parts.first);
  if (whole == null) return null;
  final fraction = parts.length == 1 ? '' : parts.last;
  if (fraction.length > 2) return null;
  final paddedFraction = fraction.padRight(2, '0');
  final minorFraction = int.tryParse(
    paddedFraction.isEmpty ? '0' : paddedFraction,
  );
  if (minorFraction == null) return null;
  return whole * 100 + minorFraction;
}

String _durationLabel(Duration value) {
  if (value.inDays >= 1 && value.inHours % 24 == 0) {
    return '${value.inDays} ${value.inDays == 1 ? 'day' : 'days'}';
  }
  if (value.inHours >= 1) {
    return '${value.inHours} ${value.inHours == 1 ? 'hour' : 'hours'}';
  }
  return '${value.inMinutes} minutes';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _humanize(String value) => value
    .replaceAll('_', ' ')
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match[1]} ${match[2]}',
    )
    .split(' ')
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');
