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
  Future<Map<String, dynamic>> getSession(String token, {String? officer}) async {
    final response = await _client.get(
      '/api/v1/onboarding/session/$token',
      queryParameters: officer != null && officer.trim().isNotEmpty ? {'officer': officer.trim()} : null,
    );
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/onboarding/session/{token}/save-draft
  Future<Map<String, dynamic>> saveDraft(
    String token,
    Map<String, dynamic> payload, {
    String? scopedOfficer,
  }) async {
    final response = await _client.post(
      '/api/v1/onboarding/session/$token/save-draft',
      data: {
        'payload': payload,
        if (scopedOfficer != null && scopedOfficer.trim().isNotEmpty)
          'scoped_officer': scopedOfficer.trim(),
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/onboarding/session/{token}/upload-excel
  Future<Map<String, dynamic>> uploadExcelBytes(
    String token,
    Uint8List fileBytes,
    String filename, {
    String? scopedOfficer,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: filename,
      ),
    });

    final response = await _client.post(
      '/api/v1/onboarding/session/$token/upload-excel',
      data: formData,
      queryParameters: scopedOfficer != null && scopedOfficer.trim().isNotEmpty
          ? {'scoped_officer': scopedOfficer.trim()}
          : null,
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

  // =========================================================================
  // CREDIT OFFICER ENDPOINTS (100% Data Isolation)
  // =========================================================================

  /// GET /api/v1/onboarding/officer/{co_token}
  Future<Map<String, dynamic>> getOfficerWorkspace(String coToken) async {
    final response = await _client.get('/api/v1/onboarding/officer/$coToken');
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/onboarding/officer/{co_token}/save-draft
  Future<Map<String, dynamic>> saveOfficerDraft(String coToken, Map<String, dynamic> payload) async {
    final response = await _client.post(
      '/api/v1/onboarding/officer/$coToken/save-draft',
      data: {'payload': payload},
    );
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/onboarding/officer/{co_token}/upload-excel
  Future<Map<String, dynamic>> uploadOfficerExcelBytes(
    String coToken,
    Uint8List fileBytes,
    String filename,
  ) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: filename,
      ),
    });

    final response = await _client.post(
      '/api/v1/onboarding/officer/$coToken/upload-excel',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/onboarding/officer/{co_token}/submit
  Future<Map<String, dynamic>> submitOfficerRoster(String coToken) async {
    final response = await _client.post('/api/v1/onboarding/officer/$coToken/submit');
    return response.data as Map<String, dynamic>;
  }

  // =========================================================================
  // BRANCH MANAGER & SUPERVISOR MANAGEMENT METHODS
  // =========================================================================

  /// POST /api/v1/onboarding/session/{token}/officers
  Future<Map<String, dynamic>> provisionOfficer(
    String branchToken, {
    required String name,
    String? phone,
    bool isMiscManager = false,
  }) async {
    final response = await _client.post(
      '/api/v1/onboarding/session/$branchToken/officers',
      data: {
        'name': name.trim(),
        'phone': phone?.trim(),
        'is_misc_savings_manager': isMiscManager,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/onboarding/session/{token}/officers/{officer_id}/unlock
  Future<Map<String, dynamic>> unlockOfficer(String branchToken, String officerId) async {
    final response = await _client.post('/api/v1/onboarding/session/$branchToken/officers/$officerId/unlock');
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/onboarding/session/{token}/bm-submit
  Future<Map<String, dynamic>> bmSubmitPackage(String branchToken) async {
    final response = await _client.post('/api/v1/onboarding/session/$branchToken/bm-submit');
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/onboarding/session/{token}/am-approve
  Future<Map<String, dynamic>> amApprovePackage(String branchToken, {String? notes}) async {
    final response = await _client.post(
      '/api/v1/onboarding/session/$branchToken/am-approve',
      data: {'approval_notes': notes},
    );
    return response.data as Map<String, dynamic>;
  }

  // =========================================================================
  // ADMINISTRATIVE METHODS (RBAC-Protected)
  // =========================================================================

  /// POST /api/v1/onboarding/admin/sessions/create
  Future<Map<String, dynamic>> createAdminSession({
    required String branchName,
    required String branchCode,
    String? contactPerson,
    String? contactPhone,
  }) async {
    final response = await _client.post(
      '/api/v1/onboarding/admin/sessions/create',
      data: {
        'branch_name': branchName,
        'branch_code': branchCode,
        'contact_person': contactPerson,
        'contact_phone': contactPhone,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/onboarding/admin/sessions
  Future<List<Map<String, dynamic>>> listAdminSessions({String? statusFilter}) async {
    final response = await _client.get(
      '/api/v1/onboarding/admin/sessions',
      queryParameters: statusFilter != null ? {'status_filter': statusFilter} : null,
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['sessions'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// POST /api/v1/onboarding/admin/sessions/{session_id}/approve
  Future<Map<String, dynamic>> approveAdminSession(String sessionId, {String? notes}) async {
    final response = await _client.post(
      '/api/v1/onboarding/admin/sessions/$sessionId/approve',
      data: {'approval_notes': notes},
    );
    return response.data as Map<String, dynamic>;
  }
}

