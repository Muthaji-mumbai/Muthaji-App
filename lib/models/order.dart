import 'package:flutter/material.dart';

enum OrderStatus { pending, confirmed, inProgress, completed, cancelled }

class OrnamentDetail {
  final String id;
  // For new API: name is an object with id and categoryname. We store both.
  final String nameId; // maps from name._id or name (string id)
  final String name; // display name, e.g., categoryname or fallback string
  final String material; // kept for backward compatibility
  final double weight;
  final String purity;
  final int quantity;
  final String? remarks; // new
  final List<String> images; // per-ornament images (new API)

  OrnamentDetail({
    required this.id,
    required this.nameId,
    required this.name,
    this.material = '',
    required this.weight,
    required this.purity,
    required this.quantity,
    this.remarks,
    this.images = const [],
  });

  factory OrnamentDetail.fromJson(Map<String, dynamic> json) {
    // Handle name being string or nested object
    String nameId = '';
    String displayName = '';
    final rawName = json['name'];
    if (rawName is Map<String, dynamic>) {
      nameId = (rawName['_id'] ?? rawName['id'] ?? '').toString();
      displayName = (rawName['categoryname'] ?? rawName['name'] ?? '').toString();
    } else if (rawName != null) {
      nameId = rawName.toString();
      displayName = rawName.toString();
    }

    // Per-item images list (new API)
    List<String> itemImages = [];
    if (json['image'] is List) {
      itemImages = List<String>.from(json['image']);
    }

    return OrnamentDetail(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      nameId: nameId,
      name: displayName,
      material: json['material'] ?? '',
      weight: (json['weight'] ?? 0).toDouble(),
      purity: json['purity'] ?? '',
      quantity: (json['quantity'] ?? 0) is int
          ? (json['quantity'] ?? 0)
          : int.tryParse((json['quantity'] ?? '0').toString()) ?? 0,
      remarks: json['remarks'],
      images: itemImages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': nameId.isNotEmpty ? nameId : name,
      'material': material,
      'weight': weight,
      'purity': purity,
      'quantity': quantity,
      if (remarks != null) 'remarks': remarks,
      if (images.isNotEmpty) 'image': images,
    };
  }
}

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

  // New fields from API
  final String? orderType; // server may set it to "Single"
  final String? orderNo; // orderno (new)
  final DateTime? orderDate;
  final List<OrnamentDetail> ornamentDetails;
  final List<String> images; // kept for backward compatibility if order-level images exist
  final List<String> pdfs;

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
    this.orderType,
    this.orderNo,
    this.orderDate,
    this.ornamentDetails = const [],
    this.images = const [],
    this.pdfs = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Handle nested userid object from API
    String clientId = '';
    String clientName = '';

    if (json['userid'] != null) {
      final userData = json['userid'];
      // Some APIs return userid as object, others as scalar. Always coerce to String.
      if (userData is Map<String, dynamic>) {
        clientId = (userData['_id'] ?? userData['id'] ?? '').toString();
        clientName = (userData['name'] ?? '').toString();
      } else {
        clientId = userData.toString();
      }
    } else {
      clientId = (json['clientId'] ?? '').toString();
      clientName = (json['clientName'] ?? '').toString();
    }

    // Parse ornament details
    List<OrnamentDetail> ornamentDetails = [];
    if (json['ornamentdetails'] != null) {
      ornamentDetails = (json['ornamentdetails'] as List)
          .map((detail) => OrnamentDetail.fromJson(detail))
          .toList();
    }

    // Parse images and PDFs (older responses may have order-level images)
    List<String> images = [];
    if (json['image'] != null && json['image'] is List) {
      images = List<String>.from(json['image']);
    }
    // Aggregate per-ornament images if order-level images are empty
    if (images.isEmpty && ornamentDetails.isNotEmpty) {
      final agg = <String>[];
      for (final d in ornamentDetails) {
        if (d.images.isNotEmpty) {
          agg.addAll(d.images);
        }
      }
      images = agg;
    }

    List<String> pdfs = [];
    if (json['pdf'] != null && json['pdf'] is List) {
      pdfs = List<String>.from(json['pdf']);
    }

    return Order(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      clientId: clientId,
      clientName: clientName,
      description: json['description'] ?? 'Order',
      amount: (json['amount'] ?? 0).toDouble(),
      status: _parseStatus(json['status']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      notes: json['notes'],
      assignedEmployeeId: json['assignedEmployeeId'],
      orderType: json['ordertype'],
      orderNo: json['orderno']?.toString(),
      orderDate: json['orderdate'] != null ? DateTime.parse(json['orderdate']) : null,
      ornamentDetails: ornamentDetails,
      images: images,
      pdfs: pdfs,
    );
  }

  static OrderStatus _parseStatus(String? status) {
    if (status == null) return OrderStatus.pending;

    // Normalize: lowercase and remove spaces, underscores, and dashes
    final s = status.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

    switch (s) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'inprogress': // handles "in progress", "in_progress"
      case 'processing':
        return OrderStatus.inProgress;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
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
      'orderType': orderType,
      'orderNo': orderNo,
      'orderDate': orderDate?.toIso8601String(),
      'ornamentDetails': ornamentDetails.map((d) => d.toJson()).toList(),
      'images': images,
      'pdfs': pdfs,
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
    String? orderType,
    String? orderNo,
    DateTime? orderDate,
    List<OrnamentDetail>? ornamentDetails,
    List<String>? images,
    List<String>? pdfs,
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
      orderType: orderType ?? this.orderType,
      orderNo: orderNo ?? this.orderNo,
      orderDate: orderDate ?? this.orderDate,
      ornamentDetails: ornamentDetails ?? this.ornamentDetails,
      images: images ?? this.images,
      pdfs: pdfs ?? this.pdfs,
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
