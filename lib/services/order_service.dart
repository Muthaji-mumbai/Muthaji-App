import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/order.dart';
import 'api_service.dart';
import '../constants/app_constants.dart';
import 'dart:developer' as developer;

class OrderService {
  // Get all orders
  static Future<List<Order>> getAllOrders(
    String? token, {
    OrderStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? userId, // Add user-based filtering
    String? orderType, // 'Single' | 'Bulk'
    String? partyId, // For APIs that expect partyname instead of userid
    String? partyname, // Direct partyname parameter
  }) async {
    try {
      // Validate token
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is required');
      }

      // Validate date range if both dates are provided
      if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
        throw Exception('Start date cannot be after end date');
      }

      // Build query parameters
      final queryParams = <String, String>{};

      if (status != null) {
        queryParams['status'] = Order.statusToApiString(status);
      }

      if (startDate != null) {
        queryParams['startDate'] = DateFormat('yyyy-MM-dd').format(startDate);
      }

      if (endDate != null) {
        queryParams['endDate'] = DateFormat('yyyy-MM-dd').format(endDate);
      }

      if (userId != null && userId.isNotEmpty) {
        queryParams['userid'] = userId;
      }

      if (orderType != null && orderType.isNotEmpty) {
        queryParams['ordertype'] = orderType;
      }

      // Some endpoints expect partyname for client-scoped lookups
      // Priority: partyname > partyId (use whichever is provided)
      if (partyname != null && partyname.isNotEmpty) {
        queryParams['partyname'] = partyname;
      } else if (partyId != null && partyId.isNotEmpty) {
        queryParams['partyname'] = partyId;
      }

      // Build endpoint with query parameters
      String endpoint = AppConstants.ordersEndpoint;
      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        endpoint = '$endpoint?$queryString';
      }

      final response = await ApiService.get(endpoint, token: token);
      developer.log('response: $response');

      if (response['success'] == true && response['data'] != null) {
        try {
          final List<dynamic> ordersData = response['data'];
          return ordersData.map((orderData) {
            try {
              return Order.fromJson(orderData);
            } catch (e) {
              developer.log('Error parsing order data: $e');
              throw Exception('Failed to parse order data: ${e.toString()}');
            }
          }).toList();
        } catch (e) {
          throw Exception('Failed to parse orders data: ${e.toString()}');
        }
      } else {
        final errorMessage = response['message'] ?? 'Failed to fetch orders';
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
        throw Exception('You do not have permission to view orders.');
      } else if (errorMessage.contains('404')) {
        throw Exception('Orders not found.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error fetching orders: ${e.toString()}');
    }
  }

  // Get orders by client ID with optional date filtering
  static Future<List<Order>> getOrdersByClient(
    String clientId,
    String? token, {
    DateTime? startDate,
    DateTime? endDate,
    String? orderType,
  }) async {
    try {
      // Mapping rules (per API requirements):
      // - All types: partyname=<clientId>
      // - Bulk: partyname=<clientId>&ordertype=Bulk
      // - Single: partyname=<clientId>&ordertype=Single
      final orders = await getAllOrders(
        token,
        partyId: clientId,
        startDate: startDate,
        endDate: endDate,
        orderType: orderType,
      );
      developer.log('Orders fetched for client $clientId: ${orders.length}');
      return orders;
    } catch (e) {
      throw Exception('Error fetching client orders: $e');
    }
  }

  // Get orders by status
  static Future<List<Order>> getOrdersByStatus(
    OrderStatus status,
    String? token,
  ) async {
    try {
      // Use the API filtering for better performance
      return await getAllOrders(token, status: status);
    } catch (e) {
      throw Exception('Error fetching orders by status: $e');
    }
  }

  // Get order by ID
  static Future<Order?> getOrderById(String orderId, String? token) async {
    try {
      final response = await ApiService.get(
        '${AppConstants.ordersEndpoint}/$orderId',
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        return Order.fromJson(response['data']);
      } else {
        return null;
      }
    } catch (e) {
      developer.log('Error fetching order by ID: $e');
      return null;
    }
  }

  // Create new order
  static Future<Order> createOrder({
    required String clientId,
    required String clientName,
    String? description,
    double? amount,
    String? notes,
    DateTime? orderDate,
    String? orderType,
    String? orderpriority, // "Regular" | "Urgent"
    required List<Map<String, dynamic>> ornamentDetails,
    List<List<PlatformFile>>? ornamentImages, // per-ornament images group
    String? partyname, // Party ID for bulk orders
    String? token,
    String? orderno,
  }) async {
    try {
      // Validate input parameters
      if (clientId.isEmpty) {
        throw Exception('Client ID is required');
      }
      if (clientName.isEmpty) {
        throw Exception('Client name is required');
      }
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is required');
      }
      if (ornamentDetails.isEmpty) {
        throw Exception('At least one ornament detail is required');
      }

      // Validate ornament details
      for (int i = 0; i < ornamentDetails.length; i++) {
        final detail = ornamentDetails[i];
        if (detail.isEmpty) {
          throw Exception('Ornament detail at index $i is empty');
        }
      }

      // Validate amount if provided
      if (amount != null && amount < 0) {
        throw Exception('Amount cannot be negative');
      }

      // Validate order priority
      if (orderpriority != null &&
          !['Regular', 'Urgent'].contains(orderpriority)) {
        throw Exception('Order priority must be either "Regular" or "Urgent"');
      }

      // Prepare the request fields
      final fields = <String, String>{
        'userid': clientId,
        if (description != null && description.isNotEmpty)
          'description': description.trim(),
        if (amount != null) 'amount': amount.toString(),
        if (notes != null && notes.isNotEmpty) 'notes': notes.trim(),
        'ordertype': orderType ?? 'Single',
        'orderdate': (orderDate ?? DateTime.now()).toIso8601String(),
        'orderpriority': orderpriority ?? 'Regular',
        // API expects camelCase key per screenshot
        'ornamentDetails': jsonEncode(ornamentDetails),
        // Include party ID for bulk orders
        if (partyname != null && partyname.isNotEmpty) 'partyname': partyname,
        if (orderno != null && orderno.isNotEmpty)
          'orderno': orderno, // <-- Ensure orderno is sent
      };
      developer.log('Sending create order fields: $fields');

      // Build multipart files as image0, image1, ... based on ornament index
      List<http.MultipartFile>? multipartFiles;
      if (ornamentImages != null && ornamentImages.isNotEmpty) {
        multipartFiles = [];
        for (int i = 0; i < ornamentImages.length; i++) {
          final filesForItem = ornamentImages[i];
          for (final file in filesForItem) {
            if (file.bytes == null || file.bytes!.isEmpty) {
              developer.log('Skipping empty file: ${file.name}');
              continue;
            }
            multipartFiles.add(
              http.MultipartFile.fromBytes(
                'image$i', // image0, image1, ...
                file.bytes!,
                filename: file.name,
              ),
            );
          }
        }
      }

      // Use multipart request when any images are present, else regular POST
      final response =
          (multipartFiles != null && multipartFiles.isNotEmpty)
              ? await ApiService.postMultipart(
                AppConstants.ordersEndpoint,
                fields: fields,
                files: multipartFiles,
                token: token,
              )
              : await ApiService.post(
                AppConstants.ordersEndpoint,
                body: fields,
                token: token,
              );

      if (response['success'] == true && response['data'] != null) {
        try {
          return Order.fromJson(response['data']);
        } catch (e) {
          throw Exception(
            'Failed to parse created order data: ${e.toString()}',
          );
        }
      } else {
        final errorMessage = response['message'] ?? 'Failed to create order';
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
        throw Exception('Invalid order data. Please check your input.');
      } else if (errorMessage.contains('403')) {
        throw Exception('You do not have permission to create orders.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error creating order: ${e.toString()}');
    }
  }

  // Update order
  static Future<Order> updateOrder({
    required String orderId,
    required Map<String, dynamic> updateData,
    String? token,
    // required String userid,
  }) async {
    try {
      // Validate order ID
      if (orderId.isEmpty) {
        throw Exception('Order ID cannot be empty');
      }

      // Include the order ID in the request body as the backend expects
      final requestBody = Map<String, dynamic>.from(updateData);

      // Always send IDs as strings to avoid type mismatches across backends
      requestBody['_id'] = orderId;
      requestBody['id'] = orderId;

      // Also try orderId field as some APIs expect this
      requestBody['orderId'] = orderId;

      developer.log('Sending update request for order: $orderId');
      developer.log('Request body: $requestBody');

      // Try the specific endpoint first
      try {
        final response = await ApiService.patch(
          '${AppConstants.ordersEndpoint}/$orderId',
          body: requestBody,
          token: token,
        );

        if (response['success'] == true && response['data'] != null) {
          return Order.fromJson(response['data']);
        } else {
          throw Exception(response['message'] ?? 'Failed to update order');
        }
      } catch (e) {
        developer.log('Specific endpoint failed, trying root endpoint: $e');

        // If specific endpoint fails, try the root endpoint
        final response = await ApiService.patch(
          AppConstants.ordersEndpoint,
          body: requestBody,
          token: token,
        );

        if (response['success'] == true && response['data'] != null) {
          return Order.fromJson(response['data']);
        } else {
          throw Exception(response['message'] ?? 'Failed to update order');
        }
      }
    } catch (e) {
      developer.log('Error in updateOrder: $e');
      throw Exception('Error updating order: $e');
    }
  }

  // Update order status
  static Future<Order> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? assignedEmployeeId,
    String? userId,
    String? token,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': Order.statusToApiString(newStatus),
      };

      if (assignedEmployeeId != null) {
        updateData['assignedEmployeeId'] = assignedEmployeeId;
      }

      if (userId != null) {
        updateData['updatedby'] = userId;
      }

      developer.log('Updating order status for order ID: $orderId');
      developer.log('Update data: $updateData');

      return await updateOrder(
        orderId: orderId,
        updateData: updateData,
        token: token,
      );
    } catch (e) {
      developer.log('Error in updateOrderStatus: $e');
      throw Exception('Error updating order status: $e');
    }
  }

  // Delete order
  static Future<bool> deleteOrder({
    required String orderId,
    String? token,
  }) async {
    try {
      final response = await ApiService.delete(
        '${AppConstants.ordersEndpoint}/$orderId',
        token: token,
      );

      return response['success'] == true;
    } catch (e) {
      throw Exception('Error deleting order: $e');
    }
  }

  // Get orders assigned to employee
  static Future<List<Order>> getOrdersByEmployee(
    String employeeId,
    String? token,
  ) async {
    try {
      final allOrders = await getAllOrders(token);
      return allOrders
          .where((order) => order.assignedEmployeeId == employeeId)
          .toList();
    } catch (e) {
      throw Exception('Error fetching employee orders: $e');
    }
  }

  // Get order statistics
  static Future<Map<String, dynamic>> getOrderStatistics(String? token) async {
    try {
      final allOrders = await getAllOrders(token);

      final totalOrders = allOrders.length;
      final pendingOrders =
          allOrders
              .where((order) => order.status == OrderStatus.pending)
              .length;
      final WaxOrders =
          allOrders.where((order) => order.status == OrderStatus.Wax).length;
      final DCOrders =
          allOrders.where((order) => order.status == OrderStatus.DC).length;
      final cancelledOrders =
          allOrders
              .where((order) => order.status == OrderStatus.cancelled)
              .length;
      final CastedOrders =
          allOrders.where((order) => order.status == OrderStatus.Casted).length;
      final completedOrders =
          allOrders
              .where((order) => order.status == OrderStatus.Completed)
              .length;
      final DeliveredOrders =
          allOrders
              .where((order) => order.status == OrderStatus.Delivered)
              .length;
      final partialDeliveryOrders =
          allOrders
              .where((order) => order.status == OrderStatus.partialDelivery)
              .length;
      final PendingDispOrders =
          allOrders
              .where((order) => order.status == OrderStatus.PendingDisp)
              .length;

      final totalRevenue = allOrders
          .where((order) => order.status == OrderStatus.DC)
          .fold(0.0, (sum, order) => sum + order.amount);

      return {
        'totalOrders': totalOrders,
        'pendingOrders': pendingOrders,
        'WaxOrders': WaxOrders,
        'DCOrders': DCOrders,
        'CastedOrders': CastedOrders,
        'cancelledOrders': cancelledOrders,
        'completedOrders': completedOrders,
        'Delivered': DeliveredOrders,
        'Partial Delivery': partialDeliveryOrders,
        'PendingDisp': PendingDispOrders,
        'totalRevenue': totalRevenue,
      };
    } catch (e) {
      // Return default statistics on error
      return {
        'totalOrders': 0,
        'pendingOrders': 0,
        'WaxOrders': 0,
        'DCOrders': 0,
        'CastedOrders': 0,
        'cancelledOrders': 0,
        'completedOrders': 0,
        'Delivered': 0,
        'Partial Delivery': 0,
        'PendingDisp': 0,
        'totalRevenue': 0.0,
      };
    }
  }

  // Search orders
  static Future<List<Order>> searchOrders(String query, String? token) async {
    try {
      final allOrders = await getAllOrders(token);
      if (query.isEmpty) return allOrders;

      final lowercaseQuery = query.toLowerCase();
      return allOrders
          .where(
            (order) =>
                order.description.toLowerCase().contains(lowercaseQuery) ||
                order.clientName.toLowerCase().contains(lowercaseQuery) ||
                order.id.toLowerCase().contains(lowercaseQuery),
          )
          .toList();
    } catch (e) {
      throw Exception('Error searching orders: $e');
    }
  }
}
