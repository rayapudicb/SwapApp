import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';

class SwapRatingBottomSheet extends StatefulWidget {
  const SwapRatingBottomSheet({
    super.key,
    required this.agreementId,
    required this.counterpartyName,
    required this.api,
    this.onSubmitted,
  });

  final String agreementId;
  final String counterpartyName;
  final ApiClient api;
  final VoidCallback? onSubmitted;

  static Future<void> show(
    BuildContext context, {
    required String agreementId,
    required String counterpartyName,
    required ApiClient api,
    VoidCallback? onSubmitted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SwapRatingBottomSheet(
        agreementId: agreementId,
        counterpartyName: counterpartyName,
        api: api,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  State<SwapRatingBottomSheet> createState() => _SwapRatingBottomSheetState();
}

class _SwapRatingBottomSheetState extends State<SwapRatingBottomSheet> {
  int _score = 5;
  final Set<String> _selectedTags = {'Punctual', 'Great Seat'};
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  static const _availableTags = [
    'Punctual',
    'Great Seat',
    'Smooth Handoff',
    'Responsive',
    'Accurate Section',
    'Friendly Fan',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final response = await widget.api.post(
        '/v1/me/swap-agreements/${widget.agreementId}/review',
        body: {
          'score': _score,
          'tags': _selectedTags.toList(),
          'comment': _commentController.text.trim(),
        },
      );
      ApiClient.requireSuccess(response);

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSubmitted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you! Rating submitted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rate Your Swap',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'How was your experience swapping with ${widget.counterpartyName}?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Star Rating Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  iconSize: 40,
                  icon: Icon(
                    starValue <= _score ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => _score = starValue),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Tags Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Optional Comment
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add an optional note about the swap...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFFAFAFA),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Rating', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
