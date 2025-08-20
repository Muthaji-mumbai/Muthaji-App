import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class ApiService {
  static const String _baseUrl = AppConstants.baseUrl;
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // Generic GET request
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    String? token,
  }) async {
    try {
      final headers = Map<String, String>.from(_headers);
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generic POST request
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final headers = Map<String, String>.from(_headers);
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generic PUT request
  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final headers = Map<String, String>.from(_headers);
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.put(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generic PATCH request for partial updates
  static Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final headers = Map<String, String>.from(_headers);
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.patch(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generic DELETE request
  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    String? token,
  }) async {
    try {
      final headers = Map<String, String>.from(_headers);
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl$endpoint'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // New method for multipart POST
  static Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    List<http.MultipartFile>? files,
    String? token,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$endpoint'));

      // Add token to headers if provided
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add fields to the multipart request
      request.fields.addAll(fields);

      // Add files to the multipart request if provided
      if (files != null) {
        request.files.addAll(files);
      }

      // Send the multipart request
      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      return _handleResponse(http.Response(responseBody.body, response.statusCode));
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Handle HTTP response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final responseData = json.decode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        return responseData; // Return error response for handling by caller
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Request failed with status: ${response.statusCode}',
        'data': null
      };
    }
  }
}