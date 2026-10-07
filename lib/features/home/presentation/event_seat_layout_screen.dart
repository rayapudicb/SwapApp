import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../exchange/presentation/seat_marketplace_screen.dart';
import '../domain/discovered_event.dart';
import '../providers/home_feed_provider.dart';

class EventSeatLayoutScreen extends StatefulWidget {
  const EventSeatLayoutScreen({
    required this.eventTitle,
    required this.venue,
    required this.contextRef,
    required this.ticketmasterEventId,
    required this.ticketmasterSeatMapUrl,
    super.key,
  });

  final String eventTitle;
  final String venue;
  final String contextRef;
  final String ticketmasterEventId;
  final String? ticketmasterSeatMapUrl;

  @override
  State<EventSeatLayoutScreen> createState() => _EventSeatLayoutScreenState();
}

class _EventSeatLayoutScreenState extends State<EventSeatLayoutScreen> {
  EventLayoutProjection? _layout;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final layout = await context.read<HomeFeedProvider>().getEventLayout(
        widget.contextRef,
      );
      if (!mounted) return;
      setState(() => _layout = layout);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    final mapUrl = layout?.staticSeatMapUrl ?? widget.ticketmasterSeatMapUrl;
    return Scaffold(
      appBar: AppBar(title: const Text('Event layout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            layout?.eventName ?? widget.eventTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(layout?.venueName ?? widget.venue),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.35,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : layout?.schematic != null
                    ? _SectionSchematic(schematic: layout!.schematic!)
                    : mapUrl == null
                    ? _MapUnavailable(
                        eventId: widget.ticketmasterEventId,
                        failed: _error != null,
                        onRetry: _load,
                      )
                    : InteractiveViewer(
                        minScale: 1,
                        maxScale: 6,
                        child: Image.network(
                          mapUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _MapUnavailable(
                            eventId: widget.ticketmasterEventId,
                            failed: true,
                            onRetry: _load,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    SeatMarketplaceScreen(contextRef: widget.contextRef),
              ),
            ),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Find swaps for this event'),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This section layout is event context only. '
                      'Ticket availability comes only from current participant '
                      'Posts. It is not an exact seat coordinate map and does '
                      'not represent provider inventory or prices.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionSchematic extends StatelessWidget {
  const _SectionSchematic({required this.schematic});

  final VenueSectionSchematic schematic;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    minScale: 1,
    maxScale: 3,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: schematic.zones
                .map((zone) => _ZoneCard(zone: zone))
                .toList(growable: false),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 92, minHeight: 62),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(blurRadius: 18, color: Color(0x33000000)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              schematic.centerLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone});

  final VenueSectionZone zone;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(zone.label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            zone.sections.join(' • '),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({
    required this.eventId,
    required this.failed,
    required this.onRetry,
  });

  final String eventId;
  final bool failed;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, size: 48),
          const SizedBox(height: 10),
          Text(
            failed
                ? 'The event layout could not be loaded.'
                : 'A section layout is not available for this event.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            'Event reference: $eventId',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry layout'),
          ),
        ],
      ),
    ),
  );
}
