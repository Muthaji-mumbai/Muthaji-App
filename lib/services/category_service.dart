import 'package:soloshine/models/category.dart';
import 'package:soloshine/services/api_service.dart';
import 'package:soloshine/constants/app_constants.dart';

class CategoryService {
  static Future<Category> getAllCategories(String token) async {
    try {
      final response = await ApiService.get(
        AppConstants.categoriesEndpoint,
        token: token,
      );
      
      // The API returns the full Category structure directly
      if (response['success'] == true && response['data'] != null) {
        return Category.fromJson(response);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch categories');
      }
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }
}