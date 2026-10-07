import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/exchange_conversation_models.dart';
import '../domain/exchange_marketplace_models.dart';
import '../providers/exchange_provider.dart';
import 'models/swap_comparison_view_data.dart';
import 'widgets/seat_swap_comparison_card.dart';

class SwapConversationScreen extends StatefulWidget {
  const SwapConversationScreen({
    required this.requestId,
    required this.canSend,
    super.key,
  });

  final String requestId;
  final bool canSend;

  @override
  State<SwapConversationScreen> createState() => _SwapConversationScreenState();
}

class _SwapConversationScreenState extends State<SwapConversationScreen>
    with WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _pollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refresh(includeRequest: false),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh({bool includeRequest = true}) async {
    if (!mounted) return;
    final exchange = context.read<ExchangeProvider>();
    final results = await Future.wait([
      exchange.loadSwapConversation(widget.requestId),
      if (includeRequest) exchange.loadSwapRequestDetail(widget.requestId),
    ]);
    final loaded = results.first;
    if (!loaded || !mounted) return;
    final conversation = exchange.conversation;
    if (conversation?.swapRequestId == widget.requestId &&
        conversation!.unreadCount > 0) {
      await exchange.markSwapConversationRead(widget.requestId);
    }
    _scrollToLatest();
  }

  Future<void> _send() async {
    final message = _composer.text.trim();
    if (message.isEmpty || message.length > 2000) return;
    final exchange = context.read<ExchangeProvider>();
    final request =
        exchange.swapRequestDetail?.swapRequest.id == widget.requestId
        ? exchange.swapRequestDetail?.swapRequest
        : null;
    if (!widget.canSend ||
        exchange.swapRequestDetailLoading ||
        exchange.swapRequestDetailError != null ||
        request == null ||
        !requestAllowsConversationMessages(request)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Messaging is unavailable until the current request is confirmed.',
            ),
          ),
        );
      }
      return;
    }
    final sent = await exchange.sendSwapConversationMessage(
      widget.requestId,
      message,
    );
    if (!mounted || !sent) return;
    _composer.clear();
    _scrollToLatest();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final exchange = context.watch<ExchangeProvider>();
    final conversation = exchange.conversationRequestId == widget.requestId
        ? exchange.conversation
        : null;
    final request =
        exchange.swapRequestDetail?.swapRequest.id == widget.requestId
        ? exchange.swapRequestDetail?.swapRequest
        : null;
    final requestChanged =
        request != null && requestPostsChangedSinceSubmission(request);
    final canSend =
        widget.canSend &&
        !exchange.swapRequestDetailLoading &&
        exchange.swapRequestDetailError == null &&
        request != null &&
        requestAllowsConversationMessages(request);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swap conversation'),
        actions: [
          IconButton(
            tooltip: 'Refresh conversation',
            onPressed: exchange.conversationLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _PrivacyNotice(),
            _PinnedSwapSummary(
              request: request,
              loading: exchange.swapRequestDetailLoading,
              error: exchange.swapRequestDetailError,
              onRetry: _refresh,
            ),
            Expanded(
              child: _ConversationBody(
                conversation: conversation,
                loading: exchange.conversationLoading,
                error: exchange.conversationError,
                onRetry: _refresh,
                scrollController: _scrollController,
              ),
            ),
            if (canSend)
              _Composer(
                controller: _composer,
                sending:
                    exchange.conversationSending ||
                    exchange.conversationSendOutcomeUnknown,
                onSend: _send,
              )
            else
              _ReadOnlyNotice(
                message: exchange.swapRequestDetailLoading
                    ? 'Checking the current request before enabling messages.'
                    : requestChanged
                    ? 'A seat offer changed. Create a new request before coordinating these seats.'
                    : request == null
                    ? 'Messaging is unavailable until the current request is confirmed.'
                    : 'This conversation is now read-only.',
              ),
          ],
        ),
      ),
    );
  }
}

class _ConversationBody extends StatelessWidget {
  const _ConversationBody({
    required this.conversation,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.scrollController,
  });

  final SwapConversationProjection? conversation;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (loading && conversation == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && conversation == null) {
      return _ConversationError(message: error!, onRetry: onRetry);
    }
    final messages = conversation?.messages ?? const <SwapMessageProjection>[];
    if (messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => onRetry(),
        child: ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 72),
            Icon(Icons.forum_outlined, size: 48),
            SizedBox(height: 12),
            Text(
              'No messages yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Use this conversation only to coordinate the current Swap Request.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        itemCount: messages.length + (error == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (error != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ConversationError(message: error!, onRetry: onRetry),
            );
          }
          final message = messages[index - (error == null ? 0 : 1)];
          return _MessageBubble(message: message);
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SwapMessageProjection message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isViewer
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Semantics(
        label: message.isViewer
            ? 'Your message'
            : 'Message from the other participant',
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: message.isViewer
                ? colors.primaryContainer
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.body),
              const SizedBox(height: 4),
              Text(
                _messageTime(message.createdAt),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (message.isFlagged) ...[
                const SizedBox(height: 4),
                Text(
                  'Flagged for safety review',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.error,
                    fontWeight: FontWeight.w700,
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 6,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        8,
        MediaQuery.viewInsetsOf(context).bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Coordinate this swap',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (!sending) onSend();
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: sending ? 'Sending message' : 'Send message',
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    ),
  );
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Keep ticket codes, booking details, ticket images, phone numbers, payment details, and transfer links out of chat.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _PinnedSwapSummary extends StatelessWidget {
  const _PinnedSwapSummary({
    required this.request,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final SwapRequestProjection? request;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final currentRequest = request;
    if (currentRequest == null && loading) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    if (currentRequest == null) {
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.sync_problem_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(error ?? 'Swap details are unavailable.')),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final comparison = SwapComparisonViewData.fromRequest(currentRequest);
    final changed = requestPostsChangedSinceSubmission(currentRequest);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ExpansionTile(
        key: ValueKey('swap-summary-${currentRequest.id}'),
        initiallyExpanded: true,
        leading: const Icon(Icons.swap_horiz),
        title: const Text(
          'Swap being discussed',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Give ${comparison.youGive.shortAssignment} → '
          'Receive ${comparison.youReceive.shortAssignment}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          if (changed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Semantics(
                liveRegion: true,
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.sync_problem_outlined),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'A seat offer changed after this request was sent. Do not coordinate these seats; create a new request.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SeatSwapComparisonCard(
                comparison: comparison,
                title: changed
                    ? 'Changed seat details'
                    : 'Your current request',
                supportingText: changed
                    ? 'These current Post details differ from the submitted request versions.'
                    : 'Use this summary to keep the conversation about the same seats.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _ConversationError extends StatelessWidget {
  const _ConversationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 6),
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

String _messageTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}
