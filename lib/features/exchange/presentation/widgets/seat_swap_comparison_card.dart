import 'package:flutter/material.dart';

import '../models/swap_comparison_view_data.dart';

class SeatSwapComparisonCard extends StatelessWidget {
  const SeatSwapComparisonCard({
    required this.comparison,
    this.title = 'Seats in this swap',
    this.supportingText,
    super.key,
  });

  final SwapComparisonViewData comparison;
  final String title;
  final String? supportingText;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.swap_horiz,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (supportingText != null) ...[
            const SizedBox(height: 5),
            Text(supportingText!),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final horizontal =
                  constraints.maxWidth >= 560 && textScale <= 1.3;
              if (horizontal) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SeatLeg(
                        label: 'YOU GIVE',
                        icon: Icons.call_made,
                        seat: comparison.youGive,
                      ),
                    ),
                    const ExcludeSemantics(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.arrow_forward),
                      ),
                    ),
                    Expanded(
                      child: _SeatLeg(
                        label: 'YOU RECEIVE',
                        icon: Icons.call_received,
                        seat: comparison.youReceive,
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _SeatLeg(
                    label: 'YOU GIVE',
                    icon: Icons.call_made,
                    seat: comparison.youGive,
                  ),
                  const ExcludeSemantics(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Icon(Icons.arrow_downward),
                    ),
                  ),
                  _SeatLeg(
                    label: 'YOU RECEIVE',
                    icon: Icons.call_received,
                    seat: comparison.youReceive,
                  ),
                ],
              );
            },
          ),
          if (comparison.cashSummary != null) ...[
            const Divider(height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.payments_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(comparison.cashSummary!)),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _SeatLeg extends StatelessWidget {
  const _SeatLeg({required this.label, required this.icon, required this.seat});

  final String label;
  final IconData icon;
  final SwapSeatViewData seat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '$label. ${seat.semanticsLabel}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: colors.primary),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  seat.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (seat.venue != null) ...[
                  const SizedBox(height: 3),
                  Text(seat.venue!),
                ],
                const SizedBox(height: 8),
                Text(
                  seat.assignment,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (seat.quantity != null) ...[
                  const SizedBox(height: 3),
                  Text('Quantity: ${seat.quantity}'),
                ],
                const SizedBox(height: 10),
                Text(
                  seat.trustLabel,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  seat.trustExplanation,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
