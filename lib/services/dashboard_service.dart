import 'package:http/http.dart' as http;
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
}
