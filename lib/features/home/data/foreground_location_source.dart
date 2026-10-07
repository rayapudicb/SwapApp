import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/discovered_event.dart';

enum LocationAccessIssue {
  serviceDisabled,
  denied,
  deniedForever,
  timedOut,
  unavailable,
}

class LocationAccessException implements Exception {
  const LocationAccessException(this.issue, this.message);

  final LocationAccessIssue issue;
  final String message;

  bool get canOpenSettings =>
      issue == LocationAccessIssue.serviceDisabled ||
      issue == LocationAccessIssue.deniedForever;

  @override
  String toString() => message;
}

abstract interface class ForegroundLocationGateway {
  Future<LocationObservation> currentObservation({String? countryCode});

  Future<bool> openSettings(LocationAccessIssue issue);
}

/// Requests one foreground observation only after a participant action.
/// It never subscribes to location updates and does not retain coordinates.
class GeolocatorForegroundLocationGateway implements ForegroundLocationGateway {
  const GeolocatorForegroundLocationGateway();

  @override
  Future<LocationObservation> currentObservation({String? countryCode}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationAccessException(
          LocationAccessIssue.serviceDisabled,
          'Location services are off. Turn them on to check nearby events.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const LocationAccessException(
          LocationAccessIssue.denied,
          'Location permission was not granted. You can still search by city.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationAccessException(
          LocationAccessIssue.deniedForever,
          'Location permission is blocked. Enable it in app settings, or '
          'continue searching by city.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationObservation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        observedAt: position.timestamp,
        countryCode: countryCode,
      );
    } on LocationAccessException {
      rethrow;
    } on TimeoutException {
      throw const LocationAccessException(
        LocationAccessIssue.timedOut,
        'A fresh location was not available in time. Move to an open area and '
        'try again.',
      );
    } on PermissionDeniedException {
      throw const LocationAccessException(
        LocationAccessIssue.denied,
        'Location permission was not granted. You can still search by city.',
      );
    } on LocationServiceDisabledException {
      throw const LocationAccessException(
        LocationAccessIssue.serviceDisabled,
        'Location services are off. Turn them on to check nearby events.',
      );
    } catch (_) {
      throw const LocationAccessException(
        LocationAccessIssue.unavailable,
        'A fresh location is unavailable right now. Try again or search by city.',
      );
    }
  }

  @override
  Future<bool> openSettings(LocationAccessIssue issue) => switch (issue) {
    LocationAccessIssue.serviceDisabled => Geolocator.openLocationSettings(),
    LocationAccessIssue.deniedForever => Geolocator.openAppSettings(),
    _ => Future.value(false),
  };
}
