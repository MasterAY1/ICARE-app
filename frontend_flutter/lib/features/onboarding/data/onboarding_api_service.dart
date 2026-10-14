import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

final onboardingApiServiceProvider = Provider<OnboardingApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return OnboardingApiService(client);
});

class OnboardingApiService {
  final ApiClient _client;

  OnboardingApiService(this._client);

  /// GET /api/v1/onboarding/session/{token}
  Future<Map<String, dynamic>> getSession(String token) async {
    final response = await _client.get('/api/v1/onboarding/session/$token');
    return response.data as Map<String, dynamic>;
  }

  /// PUT /api/v1/onboarding/session/{token}/save-draft
  Future<Map<String, dynamic>> saveDraft(String token, Map<String, dynamic> payload) async {
    final response = await _client.put(
      '/api/v1/onboarding/session/$token/save-draft',
      data: {'payload': payload},
    );
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/onboarding/session/{token}/upload-excel
  Future<Map<String, dynamic>> uploadExcelBytes(String token, Uint8List fileBytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: filename,
      ),
    });

    final response = await _client.post(
      '/api/v1/onboarding/session/$token/upload-excel',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/onboarding/session/{token}/submit
  Future<Map<String, dynamic>> submitSession(String token) async {
    final response = await _client.post('/api/v1/onboarding/session/$token/submit');
    return response.data as Map<String, dynamic>;
  }
}
