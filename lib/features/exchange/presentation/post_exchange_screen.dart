import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../domain/exchange_models.dart';
import 'seat_marketplace_screen.dart';
import '../providers/exchange_provider.dart';
import '../../home/domain/discovered_event.dart';
import '../../home/providers/home_feed_provider.dart';
import '../../tickets/domain/ticket_models.dart';
import '../../tickets/providers/ticket_provider.dart';

class PostExchangeScreen extends StatefulWidget {
  const PostExchangeScreen({super.key});

  @override
  State<PostExchangeScreen> createState() => _PostExchangeScreenState();
}

class _PostExchangeScreenState extends State<PostExchangeScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TicketProvider>().load();
    });
  }

  Future<void> _chooseImage(ImageSource source) async {
    try {
      final selected = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        requestFullMetadata: false,
      );
      if (selected == null || !mounted) return;
      final bytes = await selected.readAsBytes();
      if (!mounted) {
        bytes.fillRange(0, bytes.length);
        return;
      }
      final safeFilename = _ticketImageFilename(bytes);
      if (bytes.length < 12 ||
          bytes.length > 10 * 1024 * 1024 ||
          safeFilename == null) {
        _showMessage('Choose one JPEG or PNG image no larger than 10 MiB.');
        bytes.fillRange(0, bytes.length);
        return;
      }
      bool? accepted;
      try {
        accepted = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                _TicketPreviewScreen(bytes: bytes, filename: safeFilename),
          ),
        );
      } finally {
        bytes.fillRange(0, bytes.length);
      }
      if (accepted == true && mounted) {
        await _openActiveImport();
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'The image could not be opened. Check photo permission and try again.',
        );
      }
    }
  }

  Future<void> _openActiveImport() async {
    final provider = context.read<TicketProvider>();
    final ticketImport = provider.activeImport;
    if (ticketImport == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TicketImportScreen(ticketImportId: ticketImport.id),
      ),
    );
    if (mounted) await provider.load();
  }

  Future<void> _openImport(TicketImportProjection ticketImport) async {
    final provider = context.read<TicketProvider>();
    await provider.resumeImport(ticketImport);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TicketImportScreen(ticketImportId: ticketImport.id),
      ),
    );
    if (mounted) await provider.load();
  }

  Future<void> _createPost(TicketBundleProjection ticket) async {
    final exchange = context.read<ExchangeProvider>();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _PostEditorSheet(
        ticket: ticket,
        onSubmit: (input) async {
          try {
            final succeeded = await exchange.createIntent(
              CreateSwapIntentRequest(
                offeredTicketBundleId: ticket.id,
                desiredAssignmentLabels: input.desiredAssignments,
                acceptsAnyAssignment: input.acceptsAny,
                cashDifferenceDirection: input.cashDirection,
                cashDifferenceAmountMinor: input.cashAmountMinor,
                cashDifferenceCurrency: input.cashCurrency,
                expiresAt: input.expiresAt,
              ),
            );
            return succeeded
                ? null
                : exchange.commandError ?? 'The Post could not be created.';
          } on ExchangeContractException catch (error) {
            return error.message;
          }
        },
      ),
    );
    if (created == true && mounted) {
      _showMessage('Post draft saved. Open Swaps to review and publish it.');
    }
  }

  Future<void> _chooseTicketForPost(
    List<TicketBundleProjection> tickets,
  ) async {
    if (tickets.length == 1) {
      await _createPost(tickets.first);
      return;
    }
    final selected = await showModalBottomSheet<TicketBundleProjection>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Choose a ticket to offer',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...tickets.map(
            (ticket) => ListTile(
              leading: const Icon(Icons.local_activity_outlined),
              title: Text(ticket.eventTitle),
              subtitle: Text(
                [
                  if (ticket.sectionLabel != null)
                    'Section ${ticket.sectionLabel}',
                  if (ticket.rowLabel != null) 'Row ${ticket.rowLabel}',
                  'Seats ${ticket.seatLabels.join(', ')}',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(ticket),
            ),
          ),
        ],
      ),
    );
    if (selected != null && mounted) await _createPost(selected);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _findSeats() => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const SeatMarketplaceScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final tickets = context.watch<TicketProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          IconButton(
            tooltip: 'Refresh tickets',
            onPressed: tickets.loading ? null : tickets.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: tickets.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _PostingChoicesCard(
                hasTickets: tickets.tickets.isNotEmpty,
                disabled: tickets.commandRunning,
                onOffer: tickets.tickets.isEmpty
                    ? () => _showAddTicketSheet(context)
                    : () => _chooseTicketForPost(tickets.tickets),
                onFind: _findSeats,
              ),
              const SizedBox(height: 14),
              const _TrustBoundaryCard(),
              Consumer<ExchangeProvider>(
                builder: (context, exchange, _) => exchange.commandError == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _ExchangeCommandErrorCard(exchange: exchange),
                      ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'My tickets',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('add-ticket'),
                    onPressed: tickets.commandRunning
                        ? null
                        : () => _showAddTicketSheet(context),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Add ticket'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Add a private ticket photo, confirm the detected event and '
                'seats, then use the resulting ticket to create a Post.',
              ),
              if (tickets.loading && tickets.tickets.isEmpty) ...[
                const SizedBox(height: 28),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 10),
                const Center(child: Text('Loading your tickets…')),
              ] else ...[
                if (tickets.error != null) ...[
                  const SizedBox(height: 14),
                  _TicketErrorCard(provider: tickets),
                ],
                const SizedBox(height: 14),
                if (tickets.tickets.isEmpty)
                  _EmptyTicketsCard(
                    disabled: tickets.commandRunning,
                    onCamera: () => _chooseImage(ImageSource.camera),
                    onGallery: () => _chooseImage(ImageSource.gallery),
                  )
                else
                  ...tickets.tickets.map(
                    (ticket) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TicketCard(
                        ticket: ticket,
                        onCreatePost: () => _createPost(ticket),
                      ),
                    ),
                  ),
                if (tickets.imports.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    'My uploads',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...tickets.imports.map(
                    (ticketImport) => Card(
                      child: ListTile(
                        leading: Icon(_importIcon(ticketImport.state)),
                        title: Text(
                          ticketImport.extracted.eventName ?? 'Ticket photo',
                        ),
                        subtitle: Text(_importStatus(ticketImport)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: tickets.commandRunning
                            ? null
                            : () => _openImport(ticketImport),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTicketSheet(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a ticket photo',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'The image is privately uploaded for OCR and event matching. '
                'It is not shown publicly and does not prove ownership, '
                'validity, or transferability.',
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _chooseImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose photo'),
                subtitle: const Text('JPEG or PNG · maximum 10 MiB'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _chooseImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      );
}

class _PostingChoicesCard extends StatelessWidget {
  const _PostingChoicesCard({
    required this.hasTickets,
    required this.disabled,
    required this.onOffer,
    required this.onFind,
  });

  final bool hasTickets;
  final bool disabled;
  final VoidCallback onOffer;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you want to do?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'A seat Post includes the ticket you offer and the seats you want. '
            'To request another Post, you need your own compatible published Post.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('offer-seats'),
                onPressed: disabled ? null : onOffer,
                icon: const Icon(Icons.local_activity_outlined),
                label: Text(
                  hasTickets ? 'Offer my seats' : 'Add seats to offer',
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('find-seats'),
                onPressed: disabled ? null : onFind,
                icon: const Icon(Icons.search),
                label: const Text('Find seats'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TicketPreviewScreen extends StatefulWidget {
  const _TicketPreviewScreen({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  @override
  State<_TicketPreviewScreen> createState() => _TicketPreviewScreenState();
}

class _TicketPreviewScreenState extends State<_TicketPreviewScreen> {
  final _country = TextEditingController(text: 'IN');

  @override
  void dispose() {
    _country.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final succeeded = await context.read<TicketProvider>().uploadTicketImage(
      countryCode: _country.text,
      bytes: widget.bytes,
      filename: widget.filename,
    );
    if (succeeded && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Review ticket photo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                widget.bytes,
                height: 330,
                fit: BoxFit.contain,
                semanticLabel: 'Selected private ticket photo preview',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _country,
              maxLength: 2,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Ticket country',
                helperText: 'Two-letter country code, for example IN or US.',
                border: OutlineInputBorder(),
              ),
            ),
            const _PhotoCheckWarning(),
            if (provider.error != null) ...[
              const SizedBox(height: 10),
              _TicketErrorCard(provider: provider),
            ],
            if (provider.commandRunning) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Uploading privately and starting ticket checks…'),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: provider.commandRunning ? null : _upload,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Upload privately'),
            ),
            TextButton(
              onPressed: provider.commandRunning
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class TicketImportScreen extends StatefulWidget {
  const TicketImportScreen({required this.ticketImportId, super.key});

  final String ticketImportId;

  @override
  State<TicketImportScreen> createState() => _TicketImportScreenState();
}

class _TicketImportScreenState extends State<TicketImportScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TicketProvider>();
      final current = provider.activeImport;
      if (current == null || current.id != widget.ticketImportId) {
        provider.refreshImport(widget.ticketImportId);
      }
    });
  }

  Future<void> _resumeUpload(
    TicketImportProjection ticketImport,
    ImageSource source,
  ) async {
    try {
      final selected = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        requestFullMetadata: false,
      );
      if (selected == null || !mounted) return;
      final bytes = await selected.readAsBytes();
      if (!mounted) {
        bytes.fillRange(0, bytes.length);
        return;
      }
      final filename = _ticketImageFilename(bytes);
      if (bytes.length < 12 ||
          filename == null ||
          bytes.length > 10 * 1024 * 1024) {
        bytes.fillRange(0, bytes.length);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Choose one JPEG or PNG image no larger than 10 MiB.',
              ),
            ),
          );
        }
        return;
      }
      try {
        await context.read<TicketProvider>().resumeAwaitingUpload(
          ticketImport: ticketImport,
          bytes: bytes,
          filename: filename,
        );
      } finally {
        bytes.fillRange(0, bytes.length);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The ticket image could not be opened.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketProvider>();
    final ticketImport = provider.activeImport?.id == widget.ticketImportId
        ? provider.activeImport
        : provider.imports.cast<TicketImportProjection?>().firstWhere(
            (item) => item?.id == widget.ticketImportId,
            orElse: () => null,
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket check'),
        actions: [
          IconButton(
            tooltip: 'Refresh ticket status',
            onPressed: provider.commandRunning
                ? null
                : () => provider.refreshImport(widget.ticketImportId),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (ticketImport == null) ...[
              const SizedBox(height: 80),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              _ImportStatusCard(ticketImport: ticketImport),
              if (provider.error != null) ...[
                const SizedBox(height: 12),
                _TicketErrorCard(provider: provider),
              ],
              if (ticketImport.state == TicketImportState.awaitingUpload) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Text(
                          'Choose the ticket image to continue this upload.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: provider.commandRunning
                                  ? null
                                  : () => _resumeUpload(
                                      ticketImport,
                                      ImageSource.camera,
                                    ),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Take photo'),
                            ),
                            OutlinedButton.icon(
                              onPressed: provider.commandRunning
                                  ? null
                                  : () => _resumeUpload(
                                      ticketImport,
                                      ImageSource.gallery,
                                    ),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Choose photo'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (provider.importCompleted(ticketImport.id) ||
                  ticketImport.state ==
                      TicketImportState.evidenceSubmitted) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 44),
                        const SizedBox(height: 10),
                        const Text(
                          'Ticket added to My tickets',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'It is photo checked only. Ownership and transfer '
                          'remain unverified.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to My tickets'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (ticketImport.state ==
                  TicketImportState.awaitingConfirmation) ...[
                const SizedBox(height: 16),
                _TicketConfirmationForm(ticketImport: ticketImport),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TicketConfirmationForm extends StatefulWidget {
  const _TicketConfirmationForm({required this.ticketImport});

  final TicketImportProjection ticketImport;

  @override
  State<_TicketConfirmationForm> createState() =>
      _TicketConfirmationFormState();
}

class _TicketConfirmationFormState extends State<_TicketConfirmationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _section;
  late final TextEditingController _row;
  late final TextEditingController _seats;
  String? _contextRef;
  DiscoveredEvent? _manualEvent;

  @override
  void initState() {
    super.initState();
    final extracted = widget.ticketImport.extracted;
    _section = TextEditingController(text: extracted.sectionLabel);
    _row = TextEditingController(text: extracted.rowLabel);
    _seats = TextEditingController(text: extracted.seatLabels.join(', '));
    _contextRef =
        widget.ticketImport.confirmedContextRef ??
        (widget.ticketImport.eventCandidates.isEmpty
            ? null
            : widget.ticketImport.eventCandidates.first.contextRef);
  }

  @override
  void dispose() {
    _section.dispose();
    _row.dispose();
    _seats.dispose();
    super.dispose();
  }

  List<String> get _seatLabels => _seats.text
      .split(RegExp(r'[,\n]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    final contextRef = _contextRef;
    if (contextRef == null) return;
    await context.read<TicketProvider>().confirmImport(
      ticketImport: widget.ticketImport,
      contextRef: contextRef,
      sectionLabel: _section.text,
      rowLabel: _row.text,
      seatLabels: _seatLabels,
    );
  }

  Future<void> _searchEvent() async {
    final selected = await showModalBottomSheet<DiscoveredEvent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ManualEventSearchSheet(
        countryCode: widget.ticketImport.countryCode,
        initialKeyword: widget.ticketImport.extracted.eventName,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _manualEvent = selected;
      _contextRef = selected.contextRef;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketProvider>();
    return Form(
      key: _formKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm event and seats',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'OCR values are suggestions—not verified facts. Correct every '
                'field before continuing.',
              ),
              const SizedBox(height: 14),
              if (_manualEvent != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(_manualEvent!.title),
                    subtitle: Text(
                      _manualEvent!.venueName ?? 'Venue not supplied',
                    ),
                    trailing: IconButton(
                      tooltip: 'Change selected event',
                      onPressed: _searchEvent,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                )
              else if (widget.ticketImport.eventCandidates.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _contextRef,
                  decoration: const InputDecoration(
                    labelText: 'Matched event',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.ticketImport.eventCandidates
                      .map(
                        (candidate) => DropdownMenuItem(
                          value: candidate.contextRef,
                          child: Text(
                            candidate.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: provider.commandRunning
                      ? null
                      : (value) => setState(() => _contextRef = value),
                  validator: (value) =>
                      value == null ? 'Select the correct event.' : null,
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: provider.commandRunning ? null : _searchEvent,
                  icon: const Icon(Icons.search),
                  label: Text(
                    widget.ticketImport.eventCandidates.isEmpty
                        ? 'Search for the event'
                        : 'None of these — search events',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _section,
                maxLength: 64,
                decoration: const InputDecoration(
                  labelText: 'Section (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _row,
                maxLength: 64,
                decoration: const InputDecoration(
                  labelText: 'Row (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _seats,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Seats',
                  helperText: 'Enter 1–3 unique seats separated by commas.',
                  border: OutlineInputBorder(),
                ),
                validator: (_) {
                  final seats = _seatLabels;
                  if (seats.isEmpty || seats.length > 3) {
                    return 'Enter one to three seats.';
                  }
                  if (seats.toSet().length != seats.length) {
                    return 'Each seat must be unique.';
                  }
                  if (seats.any((seat) => seat.length > 64)) {
                    return 'Each seat must be 64 characters or fewer.';
                  }
                  return null;
                },
              ),
              const _PhotoCheckWarning(),
              if (provider.commandRunning) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('Confirming and creating your photo ticket…'),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: provider.commandRunning || _contextRef == null
                    ? null
                    : _confirm,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm and add ticket'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualEventSearchSheet extends StatefulWidget {
  const _ManualEventSearchSheet({
    required this.countryCode,
    required this.initialKeyword,
  });

  final String countryCode;
  final String? initialKeyword;

  @override
  State<_ManualEventSearchSheet> createState() =>
      _ManualEventSearchSheetState();
}

class _ManualEventSearchSheetState extends State<_ManualEventSearchSheet> {
  final _formKey = GlobalKey<FormState>();
  final _city = TextEditingController();
  late final TextEditingController _country;
  late final TextEditingController _keyword;

  @override
  void initState() {
    super.initState();
    _country = TextEditingController(text: widget.countryCode);
    _keyword = TextEditingController(text: widget.initialKeyword);
  }

  @override
  void dispose() {
    _city.dispose();
    _country.dispose();
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<HomeFeedProvider>().discoverEvents(
      city: _city.text.trim(),
      countryCode: _country.text.trim().toUpperCase(),
      keyword: _keyword.text.trim().isEmpty ? null : _keyword.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = context.watch<HomeFeedProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Find the correct event',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose the event shown on the ticket. This corrects event '
              'matching; it does not verify the ticket.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Enter the event city.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _country,
              maxLength: 2,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Country code',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  RegExp(r'^[A-Za-z]{2}$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Use a two-letter country code.',
            ),
            TextFormField(
              controller: _keyword,
              decoration: const InputDecoration(
                labelText: 'Event name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: events.isLoading ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text('Search events'),
            ),
            if (events.isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (events.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                events.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            ...events.events.map(
              (event) => Card(
                child: ListTile(
                  title: Text(event.title),
                  subtitle: Text(
                    [
                      event.venueName,
                      event.city,
                      if (event.startsAt != null) _formatDate(event.startsAt!),
                    ].whereType<String>().join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pop(event),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustBoundaryCard extends StatelessWidget {
  const _TrustBoundaryCard();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Protected ticket upload',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                SizedBox(height: 6),
                Text(
                  'Swappy privately reads the image and matches its event. '
                  'The current pilot does not verify ownership, validity, or '
                  'transferability.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyTicketsCard extends StatelessWidget {
  const _EmptyTicketsCard({
    required this.disabled,
    required this.onCamera,
    required this.onGallery,
  });

  final bool disabled;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 46,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          const Text(
            'No tickets yet',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
          ),
          const SizedBox(height: 6),
          const Text(
            'Photograph a ticket or choose an existing JPEG/PNG to start the '
            'secure ticket-checking process.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: disabled ? null : onCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take photo'),
              ),
              OutlinedButton.icon(
                onPressed: disabled ? null : onGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose photo'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onCreatePost});

  final TicketBundleProjection ticket;
  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context) {
    final assignment = [
      if (ticket.sectionLabel != null) 'Section ${ticket.sectionLabel}',
      if (ticket.rowLabel != null) 'Row ${ticket.rowLabel}',
      'Seats ${ticket.seatLabels.join(', ')}',
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_activity_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ticket.eventTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                const Chip(label: Text('Photo checked')),
              ],
            ),
            const SizedBox(height: 8),
            if (ticket.venueName != null) Text(ticket.venueName!),
            if (ticket.startsAt != null) Text(_formatDate(ticket.startsAt!)),
            const SizedBox(height: 6),
            Text(assignment),
            const SizedBox(height: 10),
            _TicketVerificationSummary(verification: ticket.verification),
            const SizedBox(height: 8),
            Text(
              'A confirmed event match does not prove ticket ownership, '
              'validity, unused status, transferability, or seat assignment.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: ticket.state == TicketBundleState.active
                  ? onCreatePost
                  : null,
              icon: const Icon(Icons.post_add_outlined),
              label: const Text('Create Post'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketVerificationSummary extends StatelessWidget {
  const _TicketVerificationSummary({required this.verification});

  final TicketVerificationCapabilities verification;

  @override
  Widget build(BuildContext context) {
    final provider = verification.provider
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
    return Semantics(
      container: true,
      label: 'Ticket verification checks',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ticket checks',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _VerificationRow(
                label: 'Event match',
                status: verification.eventMatch,
              ),
              _VerificationRow(
                label: 'Ownership',
                status: verification.ownership,
              ),
              _VerificationRow(
                label: 'Ticket validity',
                status: verification.validity,
              ),
              _VerificationRow(
                label: 'Unused status',
                status: verification.unusedStatus,
              ),
              _VerificationRow(
                label: 'Transferability',
                status: verification.transferability,
              ),
              _VerificationRow(label: 'Seat', status: verification.seat),
              const SizedBox(height: 6),
              Text(
                'Source: $provider',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({required this.label, required this.status});

  final String label;
  final TicketVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final confirmed = status == TicketVerificationStatus.confirmed;
    final color = confirmed
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            confirmed ? Icons.check_circle_outline : Icons.help_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            confirmed ? 'Confirmed' : 'Unverified',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ImportStatusCard extends StatelessWidget {
  const _ImportStatusCard({required this.ticketImport});

  final TicketImportProjection ticketImport;

  @override
  Widget build(BuildContext context) {
    final busy = ticketImport.state.shouldPoll;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            if (busy) const CircularProgressIndicator(),
            if (busy) const SizedBox(height: 14),
            Icon(_importIcon(ticketImport.state), size: busy ? 28 : 46),
            const SizedBox(height: 10),
            Text(
              _importTitle(ticketImport.state),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(_importStatus(ticketImport), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _PhotoCheckWarning extends StatelessWidget {
  const _PhotoCheckWarning();

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.tertiaryContainer,
    child: const Padding(
      padding: EdgeInsets.all(14),
      child: Text(
        'Important: photo checking recognizes ticket and event details. It '
        'does not prove that the ticket is owned, valid, unused, or transferable.',
      ),
    ),
  );
}

class _PostEditorSheet extends StatefulWidget {
  const _PostEditorSheet({required this.ticket, required this.onSubmit});

  final TicketBundleProjection ticket;
  final Future<String?> Function(_PostDraftInput input) onSubmit;

  @override
  State<_PostEditorSheet> createState() => _PostEditorSheetState();
}

class _PostEditorSheetState extends State<_PostEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _assignments = TextEditingController();
  final _amount = TextEditingController();
  bool _acceptsAny = false;
  int _expiryDays = 7;
  CashDifferenceDirection _cashDirection = CashDifferenceDirection.none;
  bool _submitting = false;
  String? _submissionError;

  @override
  void dispose() {
    _assignments.dispose();
    _amount.dispose();
    super.dispose();
  }

  List<String> get _desiredAssignments => _assignments.text
      .split(RegExp(r'[,\n]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _submissionError = null;
    });
    final error = await widget.onSubmit(
      _PostDraftInput(
        desiredAssignments: _acceptsAny ? const [] : _desiredAssignments,
        acceptsAny: _acceptsAny,
        cashDirection: _cashDirection,
        cashAmountMinor: _cashDirection == CashDifferenceDirection.none
            ? null
            : _parseInrMinor(_amount.text),
        cashCurrency: _cashDirection == CashDifferenceDirection.none
            ? null
            : 'INR',
        expiresAt: DateTime.now().toUtc().add(Duration(days: _expiryDays)),
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
            'Create a Post',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(widget.ticket.eventTitle),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Accept any seat for this event'),
            value: _acceptsAny,
            onChanged: (value) => setState(() => _acceptsAny = value),
          ),
          TextFormField(
            controller: _assignments,
            enabled: !_acceptsAny,
            maxLines: 3,
            maxLength: 512,
            decoration: const InputDecoration(
              labelText: 'Seats or sections wanted',
              helperText: 'Separate up to 20 choices with commas.',
              border: OutlineInputBorder(),
            ),
            validator: (_) {
              if (_acceptsAny) return null;
              final values = _desiredAssignments;
              if (values.isEmpty) return 'Enter at least one seat or section.';
              if (values.length > 20) return 'Use no more than 20 choices.';
              if (values.any((value) => value.length > 128)) {
                return 'Each choice must be 128 characters or fewer.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CashDifferenceDirection>(
            initialValue: _cashDirection,
            decoration: const InputDecoration(
              labelText: 'Cash difference proposal',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: CashDifferenceDirection.none,
                child: Text('No cash difference'),
              ),
              DropdownMenuItem(
                value: CashDifferenceDirection.willPay,
                child: Text('I will pay extra'),
              ),
              DropdownMenuItem(
                value: CashDifferenceDirection.wantsToReceive,
                child: Text('I want to receive extra'),
              ),
            ],
            onChanged: (value) => setState(
              () => _cashDirection = value ?? CashDifferenceDirection.none,
            ),
          ),
          if (_cashDirection != CashDifferenceDirection.none) ...[
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
              validator: _validateInrAmount,
            ),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'This is a proposal only. Swappy does not currently protect '
                  'or process this payment.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _expiryDays,
            decoration: const InputDecoration(
              labelText: 'Post expires in',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 day')),
              DropdownMenuItem(value: 3, child: Text('3 days')),
              DropdownMenuItem(value: 7, child: Text('7 days')),
              DropdownMenuItem(value: 30, child: Text('30 days')),
              DropdownMenuItem(value: 90, child: Text('90 days')),
            ],
            onChanged: (value) => setState(() => _expiryDays = value ?? 7),
          ),
          const SizedBox(height: 18),
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
            icon: const Icon(Icons.save_outlined),
            label: Text(_submitting ? 'Saving…' : 'Save Post draft'),
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

class _PostDraftInput {
  const _PostDraftInput({
    required this.desiredAssignments,
    required this.acceptsAny,
    required this.cashDirection,
    required this.cashAmountMinor,
    required this.cashCurrency,
    required this.expiresAt,
  });

  final List<String> desiredAssignments;
  final bool acceptsAny;
  final CashDifferenceDirection cashDirection;
  final int? cashAmountMinor;
  final String? cashCurrency;
  final DateTime expiresAt;
}

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

class _TicketErrorCard extends StatelessWidget {
  const _TicketErrorCard({required this.provider});

  final TicketProvider provider;

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
            Text(provider.error!),
            if (provider.correlationId != null) ...[
              const SizedBox(height: 6),
              SelectableText('Support reference: ${provider.correlationId}'),
            ],
            if (provider.canRetryUnknownCommand) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: provider.commandRunning
                    ? null
                    : provider.retryUnknownCommand,
                icon: const Icon(Icons.replay),
                label: Text(
                  'Retry ${provider.pendingCommandLabel ?? 'same action'} safely',
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ExchangeCommandErrorCard extends StatelessWidget {
  const _ExchangeCommandErrorCard({required this.exchange});

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
            if (exchange.commandCorrelationId != null) ...[
              const SizedBox(height: 6),
              SelectableText(
                'Support reference: ${exchange.commandCorrelationId}',
              ),
            ],
            if (exchange.commandRetryAt != null)
              Text('Try again after ${_formatDate(exchange.commandRetryAt!)}.'),
            if (exchange.canRetryUnknownCommand) ...[
              const SizedBox(height: 10),
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

String? _ticketImageFilename(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'ticket.jpg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return 'ticket.png';
  }
  return null;
}

String _importStatus(TicketImportProjection ticketImport) =>
    switch (ticketImport.state) {
      TicketImportState.awaitingUpload => 'Waiting for a private image upload.',
      TicketImportState.uploaded => 'Upload received. Processing will begin.',
      TicketImportState.processing =>
        'Privately reading ticket text and finding event matches.',
      TicketImportState.awaitingConfirmation =>
        'Review the detected event and correct the seat details.',
      TicketImportState.confirmed =>
        'Ticket details were confirmed; secure conversion is pending.',
      TicketImportState.evidenceSubmitted =>
        'Added to My tickets as photo checked.',
      TicketImportState.failedRetryable =>
        'Processing was interrupted. Try again.',
      TicketImportState.rejected =>
        'This image could not be accepted as a supported ticket.',
      TicketImportState.quarantined =>
        'This upload needs a trust and safety review.',
      TicketImportState.expired => 'This private upload has expired.',
    };

String _importTitle(TicketImportState state) => switch (state) {
  TicketImportState.awaitingUpload => 'Waiting for upload',
  TicketImportState.uploaded => 'Upload received',
  TicketImportState.processing => 'Checking ticket photo',
  TicketImportState.awaitingConfirmation => 'Review detected details',
  TicketImportState.confirmed => 'Ticket confirmed',
  TicketImportState.evidenceSubmitted => 'Ticket added',
  TicketImportState.failedRetryable => 'Processing interrupted',
  TicketImportState.rejected => 'Ticket image rejected',
  TicketImportState.quarantined => 'Review required',
  TicketImportState.expired => 'Upload expired',
};

IconData _importIcon(TicketImportState state) => switch (state) {
  TicketImportState.awaitingUpload => Icons.cloud_upload_outlined,
  TicketImportState.uploaded ||
  TicketImportState.processing => Icons.document_scanner_outlined,
  TicketImportState.awaitingConfirmation => Icons.fact_check_outlined,
  TicketImportState.confirmed ||
  TicketImportState.evidenceSubmitted => Icons.check_circle_outline,
  TicketImportState.failedRetryable => Icons.sync_problem_outlined,
  TicketImportState.rejected => Icons.block_outlined,
  TicketImportState.quarantined => Icons.policy_outlined,
  TicketImportState.expired => Icons.timer_off_outlined,
};

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
