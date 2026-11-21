import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

final procurementRefreshSignalProvider = StateProvider<int>((ref) => 0);

final procurementApiServiceProvider = Provider<ProcurementApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return ProcurementApiService(client);
});

/// API service powering the dedicated Procurement Officer & Admin Asset Hub.
class ProcurementApiService {
  final ApiClient _client;
  ProcurementApiService(this._client);

  Future<Map<String, dynamic>> getOverview({String? branchId}) async {
    final query = <String, dynamic>{};
    if (branchId != null && branchId.isNotEmpty && branchId != 'ALL') {
      query['branch_id'] = branchId;
    }
    final response = await _client.get('/api/v1/procurement/overview', queryParameters: query);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getStockMatrix({
    String? category,
    String? search,
    bool inStockOnly = false,
  }) async {
    final query = <String, dynamic>{
      'in_stock_only': inStockOnly,
    };
    if (category != null && category.isNotEmpty && category != 'ALL') {
      query['category'] = category;
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    final response = await _client.get('/api/v1/procurement/stock-matrix', queryParameters: query);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> receiveStockBatch(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/procurement/receive-stock', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> transferStock(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/procurement/transfer-stock', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> recordWriteOff(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/procurement/write-off', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> upsertCatalogItem(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/v1/procurement/catalog-item', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> bulkUpdatePrices(List<Map<String, dynamic>> updates) async {
    final response = await _client.post('/api/v1/procurement/catalog-prices/bulk', data: {'updates': updates});
    return Map<String, dynamic>.from(response.data as Map);
  }
}
