import 'package:soloshine/models/category.dart';
import 'package:soloshine/models/categoryResponse.dart';
import 'package:soloshine/services/api_service.dart';
import 'package:soloshine/constants/app_constants.dart';

class CategoryService {
  // Get all categories
  static Future<Category> getAllCategories(String token) async {
    try {
      // Validate token
      if (token.isEmpty) {
        throw Exception('Authentication token is required');
      }

      final response = await ApiService.get(
        AppConstants.categoriesEndpoint,
        token: token,
      );

      // Validate response structure
      if (response['success'] == true && response['data'] != null) {
        try {
          return Category.fromJson(response);
        } catch (e) {
          throw Exception('Failed to parse category data: ${e.toString()}');
        }
      } else {
        final errorMessage =
            response['message'] ?? 'Failed to fetch categories';
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
      } else if (errorMessage.contains('404')) {
        throw Exception('Categories not found.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error fetching categories: ${e.toString()}');
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
      // Validate input parameters
      if (categoryName.isEmpty) {
        throw Exception('Category name is required');
      }
      if (token.isEmpty) {
        throw Exception('Authentication token is required');
      }
      if (size.isEmpty) {
        throw Exception('At least one size is required');
      }
      if (unit.isEmpty) {
        throw Exception('At least one unit is required');
      }

      final response = await ApiService.post(
        AppConstants.categoriesEndpoint,
        body: {'categoryname': categoryName.trim(), 'size': size, 'unit': unit},
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        try {
          return CategoryResponse.fromJson(response);
        } catch (e) {
          throw Exception(
            'Failed to parse created category data: ${e.toString()}',
          );
        }
      } else {
        final errorMessage = response['message'] ?? 'Failed to create category';
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
      } else if (errorMessage.contains('400')) {
        throw Exception('Invalid category data. Please check your input.');
      } else if (errorMessage.contains('409')) {
        throw Exception('Category with this name already exists.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error creating category: ${e.toString()}');
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
      // Validate input parameters
      if (categoryId.isEmpty) {
        throw Exception('Category ID is required');
      }
      if (categoryName.isEmpty) {
        throw Exception('Category name is required');
      }
      if (token.isEmpty) {
        throw Exception('Authentication token is required');
      }
      if (size.isEmpty) {
        throw Exception('At least one size is required');
      }
      if (unit.isEmpty) {
        throw Exception('At least one unit is required');
      }

      final response = await ApiService.patch(
        '${AppConstants.categoriesEndpoint}/$categoryId',
        body: {'categoryname': categoryName.trim(), 'size': size, 'unit': unit},
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        try {
          return CategoryResponse.fromJson(response);
        } catch (e) {
          throw Exception(
            'Failed to parse updated category data: ${e.toString()}',
          );
        }
      } else {
        final errorMessage = response['message'] ?? 'Failed to update category';
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
      } else if (errorMessage.contains('404')) {
        throw Exception('Category not found.');
      } else if (errorMessage.contains('400')) {
        throw Exception('Invalid category data. Please check your input.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error updating category: ${e.toString()}');
    }
  }

  // Delete a category
  static Future<bool> deleteCategory(String categoryId, String token) async {
    try {
      // Validate input parameters
      if (categoryId.isEmpty) {
        throw Exception('Category ID is required');
      }
      if (token.isEmpty) {
        throw Exception('Authentication token is required');
      }

      final response = await ApiService.delete(
        '${AppConstants.categoriesEndpoint}/$categoryId',
        token: token,
      );

      if (response['success'] == true) {
        return true;
      } else {
        final errorMessage = response['message'] ?? 'Failed to delete category';
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
      } else if (errorMessage.contains('404')) {
        throw Exception('Category not found.');
      } else if (errorMessage.contains('403')) {
        throw Exception('You do not have permission to delete this category.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error deleting category: ${e.toString()}');
    }
  }
}
