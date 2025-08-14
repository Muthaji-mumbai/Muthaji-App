import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../models/user.dart';

class OrderService {
  static final List<Order> _orders = [];
  static final _uuid = Uuid();

  // Initialize with some mock data
  static void initializeMockData() {
    if (_orders.isEmpty) {
      _orders.addAll([
        Order(
          id: _uuid.v4(),
          clientId: '3',
          clientName: 'Client User',
          description: 'Website Development Project',
          amount: 2500.0,
          status: OrderStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        Order(
          id: _uuid.v4(),
          clientId: '3',
          clientName: 'Client User',
          description: 'Mobile App Development',
          amount: 5000.0,
          status: OrderStatus.inProgress,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          assignedEmployeeId: '2',
        ),
        Order(
          id: _uuid.v4(),
          clientId: '3',
          clientName: 'Client User',
          description: 'Logo Design',
          amount: 500.0,
          status: OrderStatus.completed,
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          assignedEmployeeId: '2',
        ),
      ]);
    }
  }

  // Get all orders
  static List<Order> getAllOrders() {
    initializeMockData();
    return List.from(_orders);
  }

  // Get orders by client ID
  static List<Order> getOrdersByClient(String clientId) {
    initializeMockData();
    return _orders.where((order) => order.clientId == clientId).toList();
  }

  // Get orders by status
  static List<Order> getOrdersByStatus(OrderStatus status) {
    initializeMockData();
    return _orders.where((order) => order.status == status).toList();
  }

  // Get order by ID
  static Order? getOrderById(String orderId) {
    initializeMockData();
    try {
      return _orders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  // Create new order
  static Order createOrder({
    required String clientId,
    required String clientName,
    required String description,
    required double amount,
    String? notes,
  }) {
    final order = Order(
      id: _uuid.v4(),
      clientId: clientId,
      clientName: clientName,
      description: description,
      amount: amount,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      notes: notes,
    );

    _orders.add(order);
    return order;
  }

  // Update order status
  static Order? updateOrderStatus(String orderId, OrderStatus newStatus, {String? assignedEmployeeId}) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex != -1) {
      final updatedOrder = _orders[orderIndex].copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
        assignedEmployeeId: assignedEmployeeId,
      );
      _orders[orderIndex] = updatedOrder;
      return updatedOrder;
    }
    return null;
  }

  // Update order
  static Order? updateOrder(String orderId, {
    String? description,
    double? amount,
    String? notes,
    OrderStatus? status,
  }) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex != -1) {
      final updatedOrder = _orders[orderIndex].copyWith(
        description: description,
        amount: amount,
        notes: notes,
        status: status,
        updatedAt: DateTime.now(),
      );
      _orders[orderIndex] = updatedOrder;
      return updatedOrder;
    }
    return null;
  }

  // Delete order
  static bool deleteOrder(String orderId) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex != -1) {
      _orders.removeAt(orderIndex);
      return true;
    }
    return false;
  }

  // Get orders assigned to employee
  static List<Order> getOrdersByEmployee(String employeeId) {
    initializeMockData();
    return _orders.where((order) => order.assignedEmployeeId == employeeId).toList();
  }

  // Get order statistics
  static Map<String, dynamic> getOrderStatistics() {
    initializeMockData();
    
    final totalOrders = _orders.length;
    final pendingOrders = _orders.where((order) => order.status == OrderStatus.pending).length;
    final inProgressOrders = _orders.where((order) => order.status == OrderStatus.inProgress).length;
    final completedOrders = _orders.where((order) => order.status == OrderStatus.completed).length;
    final cancelledOrders = _orders.where((order) => order.status == OrderStatus.cancelled).length;
    
    final totalRevenue = _orders
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
  }

  // Search orders
  static List<Order> searchOrders(String query) {
    initializeMockData();
    if (query.isEmpty) return getAllOrders();
    
    final lowercaseQuery = query.toLowerCase();
    return _orders.where((order) =>
      order.description.toLowerCase().contains(lowercaseQuery) ||
      order.clientName.toLowerCase().contains(lowercaseQuery) ||
      order.id.toLowerCase().contains(lowercaseQuery)
    ).toList();
  }
}
