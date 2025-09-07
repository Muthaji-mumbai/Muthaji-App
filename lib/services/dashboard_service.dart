import '../constants/app_constants.dart';
import 'api_service.dart';

class AdminDashboardService {
  static Future<Map<String, dynamic>> getDashboardStatistics(
    String token,
  ) async {
    try {
      final response = await ApiService.get(
        AppConstants.dashboardEndpoint,
        token: token,
      );

      if (response['success'] == true) {
        return response['data'];
      } else {
        throw Exception(
          response['message'] ?? 'Failed to fetch dashboard statistics',
        );
      }
    } catch (e) {
      throw Exception('Error fetching dashboard statistics: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getGraphData(
    String token,
    String startDate,
    String endDate,
  ) async {
    try {
      final response = await ApiService.get(
        '${AppConstants.dashboardGraphEndpoint}?startDate=$startDate&endDate=$endDate',
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch graph data');
      }
    } catch (e) {
      throw Exception('Error fetching graph data: $e');
    }
  }
}
