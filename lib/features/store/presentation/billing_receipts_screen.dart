import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/store_models.dart';
import '../providers/store_provider.dart';

class BillingReceiptsScreen extends StatefulWidget {
  const BillingReceiptsScreen({super.key});

  @override
  State<BillingReceiptsScreen> createState() => _BillingReceiptsScreenState();
}

class _BillingReceiptsScreenState extends State<BillingReceiptsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().load();
    });
  }

  void _showReceiptDetail(BillingReceipt receipt) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Digital Receipt',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('PAID', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Receipt #${receipt.receiptNumber}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const Divider(height: 24),
            _receiptRow('Plan Description', receipt.planTitle),
            _receiptRow('Upload Quota', '${receipt.uploadQuota} Verified Tickets'),
            _receiptRow('Validity Period', '${receipt.validityDays} Days'),
            _receiptRow('Payment Method', '${receipt.cardBrand} •••• ${receipt.cardLast4}'),
            _receiptRow('Date & Time', '${receipt.createdAt.toLocal()}'),
            const Divider(height: 24),
            _receiptRow('Base Plan Amount', receipt.amountFormatted),
            _receiptRow('Sales Tax (USA)', receipt.taxFormatted),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Billed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(receipt.totalFormatted, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<StoreProvider>();
    final receipts = provider.receipts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Receipts'),
      ),
      body: provider.loading && receipts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : receipts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No receipts yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your digital subscription receipts will appear here.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: receipts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final receipt = receipts[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18181B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                        ),
                      ),
                      child: ListTile(
                        onTap: () => _showReceiptDetail(receipt),
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withAlpha(25),
                          child: Icon(Icons.receipt, color: theme.colorScheme.primary),
                        ),
                        title: Text(receipt.planTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${receipt.receiptNumber} • ${receipt.cardBrand} •••• ${receipt.cardLast4}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              receipt.totalFormatted,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              '${receipt.uploadQuota} Uploads',
                              style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
