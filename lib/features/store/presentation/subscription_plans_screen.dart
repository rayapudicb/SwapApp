import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/store_models.dart';
import '../providers/store_provider.dart';
import 'mobile_checkout_sheet.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  String? _selectedProductId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().load();
    });
  }

  void _openCheckout(StoreProduct plan) async {
    final provider = context.read<StoreProvider>();
    final receipt = await showModalBottomSheet<BillingReceipt>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MobileCheckoutSheet(
        plan: plan,
        onComplete: ({
          required String cardNumber,
          required String cardBrand,
          required String expMonth,
          required String expYear,
          required String cvc,
          required String zipCode,
        }) {
          return provider.processCheckout(
            productId: plan.productId,
            cardNumber: cardNumber,
            cardBrand: cardBrand,
            expMonth: expMonth,
            expYear: expYear,
            cvc: cvc,
            zipCode: zipCode,
          );
        },
      ),
    );

    if (receipt != null && mounted) {
      _showSuccessDialog(receipt);
    }
  }

  void _showSuccessDialog(BillingReceipt receipt) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Subscribed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You have successfully activated ${receipt.planTitle}.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Receipt #${receipt.receiptNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Total Paid: ${receipt.totalFormatted} (${receipt.cardBrand} •••• ${receipt.cardLast4})', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Upload Allowance: ${receipt.uploadQuota} Tickets (${receipt.validityDays} Days)', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<StoreProvider>();

    final entitlement = provider.entitlement;
    final activeSub = entitlement?.activeSubscription;
    final quota = entitlement?.availableCredits ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions & Quotas'),
        elevation: 0,
      ),
      body: provider.loading && provider.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => provider.load(force: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Active Plan Status Header Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF3B0764), const Color(0xFF1E1B4B)]
                            : [const Color(0xFF7C3AED), const Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withAlpha(60),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'CURRENT ALLOWANCE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                activeSub != null ? 'Active Plan' : 'Free Quota',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$quota',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Uploads Remaining',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (activeSub != null) ...[
                          Text(
                            '${activeSub.planTitle} • Expires in ${activeSub.daysRemaining} days',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ] else ...[
                          const Text(
                            'Upgrade to a season plan for unlimited multi-ticket matching.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select an Upload Plan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'USA Market',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Plans List
                  ...provider.products.map((plan) {
                    final isSelected = _selectedProductId == plan.productId;
                    final isCurrentPlan = activeSub?.productId == plan.productId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18181B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isDark ? 30 : 10),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedProductId = plan.productId);
                          _openCheckout(plan);
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            plan.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          if (isCurrentPlan) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withAlpha(30),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text('CURRENT', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${plan.uploadQuota} Ticket Uploads • ${plan.validityMonths} Mo Validity',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    plan.priceFormatted,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              ...plan.features.map(
                                (feature) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          feature,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: FilledButton(
                                  onPressed: () => _openCheckout(plan),
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text('Choose ${plan.title}'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
