import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class ApiService {
  static const String _baseUrl = AppConstants.baseUrl;
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // Unauthorized handler registration
  static Future<void> Function()? _onUnauthorized;
  static void setUnauthorizedHandler(Future<void> Function() handler) {
    _onUnauthorized = handler;
  }

  // Generic GET request
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    String? token,
  }) async {
    try {
      // Validate endpoint
      if (endpoint.isEmpty) {
        throw Exception('Endpoint cannot be empty');
      }

      final headers = Map<String, String>.from(_headers);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('$_baseUrl$endpoint');

      final response = await http
          .get(uri, headers: headers)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Request timeout: Server did not respond within 30 seconds',
              );
            },
          );

      return _handleResponse(response);
    } on FormatException catch (e) {
      throw Exception('Invalid URL format: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('Network connection failed: ${e.message}');
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('timeout')) {
        throw Exception(
          'Request timed out. Please check your internet connection.',
        );
      } else if (errorMessage.contains('SocketException')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected network error: $e');
    }
  }

  // Generic POST request
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      // Validate endpoint
      if (endpoint.isEmpty) {
        throw Exception('Endpoint cannot be empty');
      }

      final headers = Map<String, String>.from(_headers);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      String? requestBody;
      if (body != null) {
        try {
          requestBody = json.encode(body);
        } catch (e) {
          throw Exception('Failed to encode request body: $e');
        }
      }

      final uri = Uri.parse('$_baseUrl$endpoint');

      final response = await http
          .post(uri, headers: headers, body: requestBody)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Request timeout: Server did not respond within 30 seconds',
              );
            },
          );

      return _handleResponse(response);
    } on FormatException catch (e) {
      throw Exception('Invalid URL format or JSON encoding: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('Network connection failed: ${e.message}');
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('timeout')) {
        throw Exception(
          'Request timed out. Please check your internet connection.',
        );
      } else if (errorMessage.contains('SocketException')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected network error: $e');
    }
  }

  // Generic PUT request
  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      // Validate endpoint
      if (endpoint.isEmpty) {
        throw Exception('Endpoint cannot be empty');
      }

      final headers = Map<String, String>.from(_headers);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      String? requestBody;
      if (body != null) {
        try {
          requestBody = json.encode(body);
        } catch (e) {
          throw Exception('Failed to encode request body: $e');
        }
      }

      final uri = Uri.parse('$_baseUrl$endpoint');

      final response = await http
          .put(uri, headers: headers, body: requestBody)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Request timeout: Server did not respond within 30 seconds',
              );
            },
          );

      return _handleResponse(response);
    } on FormatException catch (e) {
      throw Exception('Invalid URL format or JSON encoding: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('Network connection failed: ${e.message}');
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('timeout')) {
        throw Exception(
          'Request timed out. Please check your internet connection.',
        );
      } else if (errorMessage.contains('SocketException')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected network error: $e');
    }
  }

  // Generic PATCH request for partial updates
  static Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      // Validate endpoint
      if (endpoint.isEmpty) {
        throw Exception('Endpoint cannot be empty');
      }

      final headers = Map<String, String>.from(_headers);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      String? requestBody;
      if (body != null) {
        try {
          requestBody = json.encode(body);
        } catch (e) {
          throw Exception('Failed to encode request body: $e');
        }
      }

      final uri = Uri.parse('$_baseUrl$endpoint');

      final response = await http
          .patch(uri, headers: headers, body: requestBody)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Request timeout: Server did not respond within 30 seconds',
              );
            },
          );

      return _handleResponse(response);
    } on FormatException catch (e) {
      throw Exception('Invalid URL format or JSON encoding: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('Network connection failed: ${e.message}');
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('timeout')) {
        throw Exception(
          'Request timed out. Please check your internet connection.',
        );
      } else if (errorMessage.contains('SocketException')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected network error: $e');
    }
  }

  // Generic DELETE request
  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    String? token,
  }) async {
    try {
      // Validate endpoint
      if (endpoint.isEmpty) {
        throw Exception('Endpoint cannot be empty');
      }

      final headers = Map<String, String>.from(_headers);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('$_baseUrl$endpoint');

      final response = await http
          .delete(uri, headers: headers)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Request timeout: Server did not respond within 30 seconds',
              );
            },
          );

      return _handleResponse(response);
    } on FormatException catch (e) {
      throw Exception('Invalid URL format: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('Network connection failed: ${e.message}');
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('timeout')) {
        throw Exception(
          'Request timed out. Please check your internet connection.',
        );
      } else if (errorMessage.contains('SocketException')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected network error: $e');
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
      // Validate endpoint
      if (endpoint.isEmpty) {
        throw Exception('Endpoint cannot be empty');
      }

      // Validate fields
      if (fields.isEmpty) {
        throw Exception('Fields cannot be empty for multipart request');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl$endpoint'),
      );

      // Add token to headers if provided
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add fields to the multipart request
      request.fields.addAll(fields);

      // Add files to the multipart request if provided
      if (files != null && files.isNotEmpty) {
        // Validate files
        for (final file in files) {
          if (file.length == 0) {
            throw Exception('File ${file.filename} is empty or corrupted');
          }
        }
        request.files.addAll(files);
      }

      // Send the multipart request with timeout
      final response = await request.send().timeout(
        const Duration(seconds: 60), // Longer timeout for file uploads
        onTimeout: () {
          throw Exception(
            'Upload timeout: Server did not respond within 60 seconds',
          );
        },
      );

      final responseBody = await http.Response.fromStream(response);

      return _handleResponse(
        http.Response(responseBody.body, response.statusCode),
      );
    } on FormatException catch (e) {
      throw Exception('Invalid URL format: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('Network connection failed: ${e.message}');
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('timeout')) {
        throw Exception(
          'Upload timed out. Please check your internet connection.',
        );
      } else if (errorMessage.contains('SocketException')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected network error during file upload: $e');
    }
  }

  // New method for multipart PATCH
  static Future<Map<String, dynamic>> patchMultipart(
    String endpoint, {
    required Map<String, String> fields,
    List<http.MultipartFile>? files,
    String? token,
  }) async {
    try {
      // Validate endpoint
      if (endpoint.isEmpty) {
        throw Exception('Endpoint cannot be empty');
      }

      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('$_baseUrl$endpoint'),
      );

      // Add token to headers if provided
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add fields to the multipart request
      request.fields.addAll(fields);

      // Add files to the multipart request if provided
      if (files != null && files.isNotEmpty) {
        request.files.addAll(files);
      }

      // Send the multipart request with timeout
      final response = await request.send().timeout(
        const Duration(seconds: 60), // Longer timeout for file uploads
        onTimeout: () {
          throw Exception(
            'Upload timeout: Server did not respond within 60 seconds',
          );
        },
      );

      final responseBody = await http.Response.fromStream(response);

      return _handleResponse(
        http.Response(responseBody.body, response.statusCode),
      );
    } on FormatException catch (e) {
      throw Exception('Invalid URL format: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('Network connection failed: ${e.message}');
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('timeout')) {
        throw Exception(
          'Upload timed out. Please check your internet connection.',
        );
      } else if (errorMessage.contains('SocketException')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected network error during file upload: $e');
    }
  }

  // Handle HTTP response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to parse the actual error message from the response body
        String errorMessage = 'Unauthorized access. Please log in again.';
        try {
          if (response.body.isNotEmpty) {
            final body = json.decode(response.body);
            if (body is Map<String, dynamic> && body['message'] != null) {
              errorMessage = body['message'];
            }
          }
        } catch (_) {}

        // Only trigger unauthorized handler if it's not a login-related error
        // (login errors like "Invalid Password" should not force logout)
        final isLoginError =
            errorMessage == 'Invalid Password' ||
            errorMessage == 'User not found' ||
            errorMessage == 'Invalid credentials';
        if (!isLoginError) {
          _onUnauthorized?.call();
        }

        return {'success': false, 'message': errorMessage, 'data': null};
      }

      // Handle different HTTP status codes
      if (response.statusCode == 404) {
        return {
          'success': false,
          'message': 'Resource not found',
          'data': null,
        };
      }

      if (response.statusCode == 500) {
        return {
          'success': false,
          'message': 'Internal server error. Please try again later.',
          'data': null,
        };
      }

      if (response.statusCode == 503) {
        return {
          'success': false,
          'message': 'Service temporarily unavailable. Please try again later.',
          'data': null,
        };
      }

      if (response.statusCode == 429) {
        return {
          'success': false,
          'message': 'Too many requests. Please wait a moment and try again.',
          'data': null,
        };
      }

      // Handle empty response body
      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Empty response from server',
          'data': null,
        };
      }

      // Try to parse JSON response
      Map<String, dynamic> responseData;
      try {
        responseData = json.decode(response.body);
      } on FormatException catch (e) {
        return {
          'success': false,
          'message': 'Invalid response format from server: ${e.message}',
          'data': null,
        };
      } catch (e) {
        return {
          'success': false,
          'message': 'Failed to parse server response: $e',
          'data': null,
        };
      }

      // Response data is already validated as Map<String, dynamic> from json.decode

      // Handle successful responses (2xx)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Ensure success field exists
        if (!responseData.containsKey('success')) {
          responseData['success'] = true;
        }
        return responseData;
      } else {
        // Handle client errors (4xx) and server errors (5xx)
        return {
          'success': false,
          'message':
              responseData['message'] ??
              'Request failed with status: ${response.statusCode}',
          'data': responseData['data'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Unexpected error processing response: $e',
        'data': null,
      };
    }
  }
}
