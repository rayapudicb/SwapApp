import 'package:flutter/material.dart';
import 'package:passwordless_identity/passwordless_identity.dart';

import 'bootstrap.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (!config.isConfigured) {
    runSwappyConfigurationError(config.configurationError!);
    return;
  }

  runConfiguredSwappy(
    config: config,
    identityRepository: HttpPasswordlessAuthRepository(
      baseUri: config.apiBaseUri!,
    ),
  );
}
