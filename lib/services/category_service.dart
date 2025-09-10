import 'package:soloshine/models/category.dart';
import 'package:soloshine/models/categoryResponse.dart';
import 'package:soloshine/services/api_service.dart';
import 'package:soloshine/constants/app_constants.dart';

class CategoryService {
  // Get all categories
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

  // Create a new category
  static Future<CategoryResponse> createCategory(
    String categoryName,
    List<String> size,
    List<String> unit,
    String token,
  ) async {
    try {
      final response = await ApiService.post(
        AppConstants.categoriesEndpoint,
        body: {
          'categoryname': categoryName,
          'size': size,
          'unit': unit,
        },
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        return CategoryResponse.fromJson(response);
      } else {
        throw Exception(response['message'] ?? 'Failed to create category');
      }
    } catch (e) {
      throw Exception('Error creating category: $e');
    }
  }

  // Update an existing category
  static Future<CategoryResponse> updateCategory(
    String categoryId,
    String categoryName,
    List<String> size,
    List<String> unit,
    String token,
  ) async {
    try {
      final response = await ApiService.patch(
        '${AppConstants.categoriesEndpoint}/$categoryId',
        body: {
          'categoryname': categoryName,
          'size': size,
          'unit': unit,
        },
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        return CategoryResponse.fromJson(response);
      } else {
        throw Exception(response['message'] ?? 'Failed to update category');
      }
    } catch (e) {
      throw Exception('Error updating category: $e');
    }
  }

  // Delete a category
  static Future<bool> deleteCategory(String categoryId, String token) async {
    try {
      final response = await ApiService.delete(
        '${AppConstants.categoriesEndpoint}/$categoryId',
        token: token,
      );

      if (response['success'] == true) {
        return true;
      } else {
        throw Exception(response['message'] ?? 'Failed to delete category');
      }
    } catch (e) {
      throw Exception('Error deleting category: $e');
    }
  }
}
