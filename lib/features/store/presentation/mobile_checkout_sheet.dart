import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/store_models.dart';

class MobileCheckoutSheet extends StatefulWidget {
  const MobileCheckoutSheet({
    super.key,
    required this.plan,
    required this.onComplete,
  });

  final StoreProduct plan;
  final Future<BillingReceipt> Function({
    required String cardNumber,
    required String cardBrand,
    required String expMonth,
    required String expYear,
    required String cvc,
    required String zipCode,
  }) onComplete;

  @override
  State<MobileCheckoutSheet> createState() => _MobileCheckoutSheetState();
}

class _MobileCheckoutSheetState extends State<MobileCheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController(text: '4242 4242 4242 4242');
  final _expController = TextEditingController(text: '12/28');
  final _cvcController = TextEditingController(text: '123');
  final _zipController = TextEditingController(text: '94107');

  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expController.dispose();
    _cvcController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _handlePay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final expParts = _expController.text.split('/');
      final expMonth = expParts.isNotEmpty ? expParts[0].trim() : '12';
      final expYear = expParts.length > 1 ? expParts[1].trim() : '28';

      final receipt = await widget.onComplete(
        cardNumber: _cardNumberController.text.replaceAll(' ', ''),
        cardBrand: _detectBrand(_cardNumberController.text),
        expMonth: expMonth,
        expYear: expYear,
        cvc: _cvcController.text.trim(),
        zipCode: _zipController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(receipt);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isProcessing = false;
      });
    }
  }

  String _detectBrand(String num) {
    final clean = num.replaceAll(' ', '');
    if (clean.startsWith('4')) return 'Visa';
    if (clean.startsWith('5')) return 'Mastercard';
    if (clean.startsWith('3')) return 'Amex';
    if (clean.startsWith('6')) return 'Discover';
    return 'Visa';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF18181B) : Colors.white;
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
    final primary = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                  Text(
                    'Checkout',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Order Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.plan.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          widget.plan.priceFormatted,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${widget.plan.uploadQuota} Verified Ticket Uploads',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        Text(
                          '${widget.plan.validityMonths} Months (${widget.plan.validityDays}d)',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated Sales Tax (USA)', style: TextStyle(fontSize: 13)),
                        const Text('\$0.00', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Due Today', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          widget.plan.priceFormatted,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                'Payment Method',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),

              // Card Number Input
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  _CardNumberFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: 'Card Number',
                  prefixIcon: const Icon(Icons.credit_card),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFFAFAFA),
                ),
                validator: (val) {
                  if (val == null || val.replaceAll(' ', '').length < 15) {
                    return 'Enter valid card number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expController,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(5),
                        _CardExpiryFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'MM/YY',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFFAFAFA),
                      ),
                      validator: (val) {
                        if (val == null || val.length < 5) return 'MM/YY';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cvcController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: InputDecoration(
                        labelText: 'CVC',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFFAFAFA),
                      ),
                      validator: (val) {
                        if (val == null || val.length < 3) return 'CVC';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _zipController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [LengthLimitingTextInputFormatter(5)],
                      decoration: InputDecoration(
                        labelText: 'Zip Code',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFFAFAFA),
                      ),
                      validator: (val) {
                        if (val == null || val.length < 5) return 'Zip';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withAlpha(100)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Pay Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isProcessing ? null : _handlePay,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'Pay ${widget.plan.priceFormatted}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Encrypted 256-bit SSL Checkout • No Card Saved In Dev',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) text = text.substring(0, 16);
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll('/', '');
    if (text.length > 4) text = text.substring(0, 4);
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
