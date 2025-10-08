import '../constants/app_constants.dart';
import 'api_service.dart';

class AdminDashboardService {
  static Future<Map<String, dynamic>> getDashboardStatistics(
    String token,
  ) async {   
    try {
      // Validate token
      if (token.isEmpty) {
        throw Exception('Authentication token is required');
      }

      final response = await ApiService.get(
        AppConstants.dashboardEndpoint,
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        try {
          final data = response['data'];
          if (data is Map<String, dynamic>) {
            return data;
          } else {
            throw Exception('Invalid dashboard data format');
          }
        } catch (e) {
          throw Exception(
            'Failed to parse dashboard statistics: ${e.toString()}',
          );
        }
      } else {
        final errorMessage =
            response['message'] ?? 'Failed to fetch dashboard statistics';
        throw Exception(errorMessage);
      }
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Network error')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else if (errorMessage.contains('timeout')) {
        throw Exception('Request timed out. Please try again.');
      } else if (errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized')) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (errorMessage.contains('403')) {
        throw Exception(
          'You do not have permission to view dashboard statistics.',
        );
      } else if (errorMessage.contains('404')) {
        throw Exception('Dashboard data not found.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception(
        'Unexpected error fetching dashboard statistics: ${e.toString()}',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getGraphData(
    String token,
    String startDate,
    String endDate,
  ) async {
    try {
      // Validate input parameters
      if (token.isEmpty) {
        throw Exception('Authentication token is required');
      }
      if (startDate.isEmpty) {
        throw Exception('Start date is required');
      }
      if (endDate.isEmpty) {
        throw Exception('End date is required');
      }

      // Validate date format (basic check)
      try {
        DateTime.parse(startDate);
        DateTime.parse(endDate);
      } catch (e) {
        throw Exception('Invalid date format. Please use YYYY-MM-DD format.');
      }

      // Validate date range
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      if (start.isAfter(end)) {
        throw Exception('Start date cannot be after end date');
      }

      final response = await ApiService.get(
        '${AppConstants.dashboardGraphEndpoint}?startDate=$startDate&endDate=$endDate',
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        try {
          final data = response['data'];
          if (data is List) {
            return List<Map<String, dynamic>>.from(data);
          } else {
            throw Exception('Invalid graph data format');
          }
        } catch (e) {
          throw Exception('Failed to parse graph data: ${e.toString()}');
        }
      } else {
        final errorMessage =
            response['message'] ?? 'Failed to fetch graph data';
        throw Exception(errorMessage);
      }
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Network error')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else if (errorMessage.contains('timeout')) {
        throw Exception('Request timed out. Please try again.');
      } else if (errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized')) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (errorMessage.contains('403')) {
        throw Exception('You do not have permission to view graph data.');
      } else if (errorMessage.contains('404')) {
        throw Exception('Graph data not found for the specified date range.');
      } else if (errorMessage.contains('400')) {
        throw Exception('Invalid date range. Please check your input.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error fetching graph data: ${e.toString()}');
    }
  }
}
