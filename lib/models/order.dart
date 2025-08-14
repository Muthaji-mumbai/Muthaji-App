import 'package:flutter/material.dart';

enum OrderStatus { pending, confirmed, inProgress, completed, cancelled }

class Order {
  final String id;
  final String clientId;
  final String clientName;
  final String description;
  final double amount;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final String? assignedEmployeeId;

  Order({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.description,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.notes,
    this.assignedEmployeeId,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      clientId: json['clientId'],
      clientName: json['clientName'],
      description: json['description'],
      amount: json['amount'].toDouble(),
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
      notes: json['notes'],
      assignedEmployeeId: json['assignedEmployeeId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'description': description,
      'amount': amount,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'notes': notes,
      'assignedEmployeeId': assignedEmployeeId,
    };
  }

  Order copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? description,
    double? amount,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    String? assignedEmployeeId,
  }) {
    return Order(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
    );
  }

  String get statusText {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get statusColor {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.inProgress:
        return Colors.purple;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }
}
