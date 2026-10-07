import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/store_models.dart';
import '../providers/store_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StoreProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Plans & posting credits')),
      body: RefreshIndicator(
        onRefresh: () => store.load(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (store.loading && store.entitlement == null) ...[
              const SizedBox(height: 100),
              const Center(child: CircularProgressIndicator()),
            ] else if (store.error != null && store.entitlement == null)
              _StoreError(message: store.error!, onRetry: store.load)
            else ...[
              if (store.entitlement != null)
                _CreditSummary(entitlement: store.entitlement!),
              if (store.error != null) ...[
                const SizedBox(height: 12),
                _StoreError(message: store.error!, onRetry: store.load),
              ],
              const SizedBox(height: 18),
              Text(
                'Available options',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (store.products.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No plans are currently available.'),
                  ),
                )
              else
                ...store.products.map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProductCard(product: product),
                  ),
                ),
              const SizedBox(height: 6),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'App Store and Google Play checkout are not connected '
                          'in this build. Prices and purchase buttons stay '
                          'hidden until native store verification is enabled.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreditSummary extends StatelessWidget {
  const _CreditSummary({required this.entitlement});

  final OfferingEntitlement entitlement;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entitlement.availableCredits} posting credits',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            entitlement.canPublish
                ? 'You can publish a ticket-admission Post.'
                : 'Add credits before publishing another Post.',
          ),
          if (entitlement.activeSubscription != null) ...[
            const Divider(height: 26),
            Text(
              'Active: ${entitlement.activeSubscription!.productId}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Current period ends ${_date(entitlement.activeSubscription!.expiresAt)}',
            ),
          ],
        ],
      ),
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final StoreProduct product;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                product.isSubscription
                    ? Icons.workspace_premium_outlined
                    : Icons.add_card_outlined,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  product.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(product.description),
          const SizedBox(height: 10),
          Text(
            '${product.creditsGranted} posting credits',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const OutlinedButton(
            onPressed: null,
            child: Text('Purchase unavailable in this build'),
          ),
        ],
      ),
    ),
  );
}

class _StoreError extends StatelessWidget {
  const _StoreError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
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

String _date(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}
