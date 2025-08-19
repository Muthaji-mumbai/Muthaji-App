import 'package:file_picker/file_picker.dart';

import '../models/order.dart';
import '../models/user.dart';
import 'api_service.dart';
import '../constants/app_constants.dart';

class OrderService {
  // Get all orders
  static Future<List<Order>> getAllOrders(String? token) async {
    try {
      final response = await ApiService.get(
        AppConstants.ordersEndpoint,
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> ordersData = response['data'];
        return ordersData
            .map((orderData) => Order.fromJson(orderData))
            .toList();
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch orders');
      }
    } catch (e) {
      throw Exception('Error fetching orders: $e');
    }
  }

  // Get orders by client ID
  static Future<List<Order>> getOrdersByClient(
    String clientId,
    String? token,
  ) async {
    try {
      final allOrders = await getAllOrders(token);
      return allOrders.where((order) => order.clientId == clientId).toList();
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
      final allOrders = await getAllOrders(token);
      return allOrders.where((order) => order.status == status).toList();
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
      print('Error fetching order by ID: $e');
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
    String? orderType,
    DateTime? orderDate,
    List<Map<String, dynamic>>? ornamentDetails,
    List<PlatformFile>? files,
    List<String>? images,
    String? token,
  }) async {
    try {
      final response = await ApiService.post(
        AppConstants.ordersEndpoint,
        body: {
          'userid': clientId,
          'description': description ?? '',
          'amount': amount ?? 0.0,
          'notes': notes ?? '',
          'ordertype': orderType ?? 'Single',
          'orderdate':
              orderDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
          'ornamentdetails': ornamentDetails ?? [],
          'image': images ?? [],
        },
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        return Order.fromJson(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      throw Exception('Error creating order: $e');
    }
  }

  // Update order
  static Future<Order> updateOrder({
    required String orderId,
    required Map<String, dynamic> updateData,
    String? token,
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

      print('Sending update request for order: $orderId');
      print('Request body: $requestBody');

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
        print('Specific endpoint failed, trying root endpoint: $e');

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
      print('Error in updateOrder: $e');
      throw Exception('Error updating order: $e');
    }
  }

  // Update order status
  static Future<Order> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? assignedEmployeeId,
    String? token,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus.toString().split('.').last,
      };

      if (assignedEmployeeId != null) {
        updateData['assignedEmployeeId'] = assignedEmployeeId;
      }

      print('Updating order status for order ID: $orderId');
      print('Update data: $updateData');

      return await updateOrder(
        orderId: orderId,
        updateData: updateData,
        token: token,
      );
    } catch (e) {
      print('Error in updateOrderStatus: $e');
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
      final inProgressOrders =
          allOrders
              .where((order) => order.status == OrderStatus.inProgress)
              .length;
      final completedOrders =
          allOrders
              .where((order) => order.status == OrderStatus.completed)
              .length;
      final cancelledOrders =
          allOrders
              .where((order) => order.status == OrderStatus.cancelled)
              .length;

      final totalRevenue = allOrders
          .where((order) => order.status == OrderStatus.completed)
          .fold(0.0, (sum, order) => sum + order.amount);

      return {
        'totalOrders': totalOrders,
        'pendingOrders': pendingOrders,
        'inProgressOrders': inProgressOrders,
        'completedOrders': completedOrders,
        'cancelledOrders': cancelledOrders,
        'totalRevenue': totalRevenue,
      };
    } catch (e) {
      // Return default statistics on error
      return {
        'totalOrders': 0,
        'pendingOrders': 0,
        'inProgressOrders': 0,
        'completedOrders': 0,
        'cancelledOrders': 0,
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
