import '../../../core/api/api_client.dart';

class DeviceRegistrationClient {
  const DeviceRegistrationClient({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    final response = await _apiClient.post(
      '/v1/me/devices',
      body: {'token': token, 'platform': platform.toLowerCase()},
    );
    ApiClient.requireSuccess(response);
  }
}
