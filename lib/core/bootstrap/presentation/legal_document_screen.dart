import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/medusa_flutter_theme.dart';
import '../domain/platform_bootstrap.dart';
import '../providers/bootstrap_provider.dart';

typedef LegalDocumentLoader = Future<LegalDocument> Function(String slug);

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    required this.slug,
    required this.fallbackTitle,
    this.loader,
    super.key,
  });

  final String slug;
  final String fallbackTitle;
  final LegalDocumentLoader? loader;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  Future<LegalDocument>? _document;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _document ??= _loadDocument();
  }

  Future<LegalDocument> _loadDocument() async {
    final loader =
        widget.loader ??
        (slug) => Provider.of<BootstrapProvider>(context, listen: false)
            .getLegalDocument(
              slug,
              locale: Localizations.localeOf(context).toLanguageTag(),
            );
    final document = await loader(widget.slug);
    if (document.slug != widget.slug ||
        document.version <= 0 ||
        document.title.trim().isEmpty ||
        document.contentMarkdown.trim().isEmpty) {
      throw const FormatException('Invalid legal document.');
    }
    return document;
  }

  void _retry() {
    setState(() {
      _document = _loadDocument();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.fallbackTitle)),
    body: SafeArea(
      child: FutureBuilder<LegalDocument>(
        future: _document,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Semantics(
                liveRegion: true,
                label: 'Loading legal document',
                child: const CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _DocumentError(onRetry: _retry);
          }
          return _DocumentContent(document: snapshot.requireData);
        },
      ),
    ),
  );
}

class _DocumentContent extends StatelessWidget {
  const _DocumentContent({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final medusa = context.medusa;
    final localizations = MaterialLocalizations.of(context);
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Semantics(
            header: true,
            child: Text(
              document.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: medusa.fgBase,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Version ${document.version} · Updated '
            '${localizations.formatMediumDate(document.effectiveAt.toLocal())}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: medusa.fgMuted),
          ),
          const SizedBox(height: 20),
          Text(
            document.contentMarkdown,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: medusa.fgBase,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentError extends StatelessWidget {
  const _DocumentError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'Document unavailable',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Swappy could not verify this published document. Try again before accepting any policy.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
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
