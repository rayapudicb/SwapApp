import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/medusa_flutter_theme.dart';
import '../providers/bootstrap_provider.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bootstrap = context.watch<BootstrapProvider>();
    final medusa = context.medusa;
    final textTheme = Theme.of(context).textTheme;
    final reason =
        bootstrap.maintenanceReason ??
        'Swappy services are currently undergoing scheduled maintenance. Please check back shortly.';

    return Scaffold(
      backgroundColor: medusa.bgSubtle,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: medusa.tagOrangeBg,
                    borderRadius: BorderRadius.circular(
                      MedusaTheme.radiusLarge,
                    ),
                    border: Border.all(
                      color: medusa.tagOrangeText.withValues(alpha: 0.25),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.construction_outlined,
                    color: medusa.tagOrangeText,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Under Maintenance',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    color: medusa.fgBase,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: medusa.fgSubtle,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: bootstrap.isLoading ? null : bootstrap.initialize,
                  style: FilledButton.styleFrom(
                    backgroundColor: medusa.buttonPrimary,
                    foregroundColor: medusa.onColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MedusaTheme.radiusMedium,
                      ),
                    ),
                    minimumSize: const Size(180, 46),
                  ),
                  icon: bootstrap.isLoading
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: medusa.onColor,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('Check status again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
