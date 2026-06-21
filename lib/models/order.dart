import 'package:flutter/material.dart';
import 'package:soloshine/constants/app_constants.dart';

enum OrderStatus {
  pending,
  Casted,
  Wax,
  DC,
  cancelled,
  delay,
  due,
  partialDelivery,
  PendingDisp,
  Completed,
  Delivered, // <-- Added new status
}

class PartialDeliveryEntry {
  final DateTime deliverydate;
  final int qty;

  final String? deliverynote;

  PartialDeliveryEntry({
    required this.deliverydate,
    required this.qty,
    this.deliverynote,
  });

  factory PartialDeliveryEntry.fromJson(Map<String, dynamic> json) {
    return PartialDeliveryEntry(
      deliverydate: DateTime.parse(
        (json['deliverydate'] ?? json['date']).toString(),
      ),
      qty:
          (json['qty'] ?? json['quantity'] ?? 0) is int
              ? (json['qty'] ?? json['quantity'] ?? 0)
              : int.tryParse(
                    (json['qty'] ?? json['quantity'] ?? '0').toString(),
                  ) ??
                  0,
      deliverynote: json['deliverynote']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deliverydate': deliverydate.toIso8601String(),
      'qty': qty,
      if (deliverynote != null && deliverynote!.isNotEmpty)
        'deliverynote': deliverynote,
    };
  }
}

class StatusHistoryEntry {
  final OrderStatus status;
  final String? updatedBy;
  final DateTime updatedAt;

  StatusHistoryEntry({
    required this.status,
    this.updatedBy,
    required this.updatedAt,
  });

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StatusHistoryEntry(
      status: Order._parseStatus(json['status']?.toString()),
      updatedBy: Order._parseUpdatedBy(json['updatedby']),
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': Order.statusToApiString(status),
      'updatedby': updatedBy,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

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
  final List<String> backupImages; // fallback images
  final String? size; // size from category
  final String? unit; // unit from category
  final String? colorstone; // colorstone option
  final String? rhodium; // rhodium option
  final String? dull; // dull option
  final int? deliverycount; // delivery count for partial delivery
  final List<PartialDeliveryEntry>?
  partialDelivery; // detailed partial delivery entries

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
    this.backupImages = const [],
    this.size,
    this.unit,
    this.colorstone,
    this.rhodium,
    this.dull,
    this.deliverycount,
    this.partialDelivery,
  });

  factory OrnamentDetail.fromJson(Map<String, dynamic> json) {
    // Handle name being string or nested object
    String nameId = '';
    String displayName = '';
    final rawName = json['name'];
    if (rawName is Map<String, dynamic>) {
      nameId = (rawName['_id'] ?? rawName['id'] ?? '').toString();
      displayName =
          (rawName['categoryname'] ?? rawName['name'] ?? '').toString();
    } else if (rawName != null) {
      nameId = rawName.toString();
      displayName = rawName.toString();
    }

    // Per-item images list (new API)
    List<String> itemImages = [];
    if (json['image'] is List) {
      itemImages = List<String>.from(json['image']);
    }

    List<String> itemBackupImages = [];
    if (json['backupimage'] is List) {
      itemBackupImages = List<String>.from(json['backupimage']);
    }

    // Partial delivery list (if provided by API)
    List<PartialDeliveryEntry> entries = [];
    if (json['partialdelivery'] is List) {
      entries =
          (json['partialdelivery'] as List)
              .whereType<dynamic>()
              .map(
                (e) =>
                    PartialDeliveryEntry.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList();
    }

    return OrnamentDetail(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      nameId: nameId,
      name: displayName,
      material: json['material'] ?? '',
      weight: (json['weight'] ?? 0).toDouble(),
      purity: json['purity'] ?? '',
      quantity:
          (json['quantity'] ?? 0) is int
              ? (json['quantity'] ?? 0)
              : int.tryParse((json['quantity'] ?? '0').toString()) ?? 0,
      remarks: json['remarks'],
      images: itemImages,
      backupImages: itemBackupImages,
      size: json['size']?.toString(),
      unit: json['unit']?.toString(),
      colorstone: json['colorstone']?.toString(),
      rhodium: json['rhodium']?.toString(),
      dull: json['dull']?.toString(),
      deliverycount:
          json['deliverycount'] != null
              ? int.tryParse(json['deliverycount'].toString())
              : null,
      partialDelivery: entries,
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
      if (backupImages.isNotEmpty) 'backupimage': backupImages,
      if (size != null) 'size': size,
      if (unit != null) 'unit': unit,
      if (colorstone != null) 'colorstone': colorstone,
      if (rhodium != null) 'rhodium': rhodium,
      if (dull != null) 'dull': dull,
      if (deliverycount != null) 'deliverycount': deliverycount,
      if (partialDelivery != null && partialDelivery!.isNotEmpty)
          'partialdelivery': partialDelivery!.map((e) => e.toJson()).toList(),
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
  final String? updatedBy;

  // New fields from API
  final String? orderType; // server may set it to "Single"
  final String? orderNo; // orderno (new)
  final DateTime? orderDate;
  final String? orderPriority; // "Regular" | "Urgent"
  final String? partyname; // Party ID for bulk orders
  final String? partynameDisplay; // Party name for display
  final List<OrnamentDetail> ornamentDetails;

  final List<String>
  images; // kept for backward compatibility if order-level images exist
  final List<String> backupImages; // fallback images
  final List<String> pdfs;
  final List<StatusHistoryEntry> statusHistory;

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
    this.updatedBy,
    this.orderType,
    this.orderNo,
    this.orderDate,
    this.orderPriority,
    this.partyname,
    this.partynameDisplay,
    this.ornamentDetails = const [],
    this.images = const [],
    this.backupImages = const [],
    this.pdfs = const [],
    this.statusHistory = const [],
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
      ornamentDetails =
          (json['ornamentdetails'] as List)
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

    List<String> backupImages = [];
    if (json['backupimage'] != null && json['backupimage'] is List) {
      backupImages = List<String>.from(json['backupimage']);
    }
    // Aggregate per-ornament backup images if order-level backup images are empty
    if (backupImages.isEmpty && ornamentDetails.isNotEmpty) {
      final agg = <String>[];
      for (final d in ornamentDetails) {
        if (d.backupImages.isNotEmpty) {
          agg.addAll(d.backupImages);
        }
      }
      backupImages = agg;
    }

    List<String> pdfs = [];
    if (json['pdf'] != null && json['pdf'] is List) {
      pdfs = List<String>.from(json['pdf']);
    }

    List<StatusHistoryEntry> statusHistory = [];
    if (json['statushistory'] != null && json['statushistory'] is List) {
      statusHistory =
          (json['statushistory'] as List)
              .whereType<dynamic>()
              .map(
                (e) =>
                    StatusHistoryEntry.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList();
    }

    return Order(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      clientId: clientId,
      clientName: clientName,
      description: json['description'] ?? 'Order',
      amount: (json['amount'] ?? 0).toDouble(),
      status: _parseStatus(json['status']),
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      notes: json['notes'],
      assignedEmployeeId: json['assignedEmployeeId'],
      updatedBy: _parseUpdatedBy(json['updatedby']),
      orderType: json['ordertype'],
      orderNo: json['orderno']?.toString(),
      orderDate:
          json['orderdate'] != null ? DateTime.parse(json['orderdate']) : null,
      orderPriority: (json['orderpriority'] ?? json['priority'])?.toString(),
      partyname: _parsePartyId(json['partyname']),
      partynameDisplay: _parsePartyName(json['partyname']),
      ornamentDetails: ornamentDetails,
      images: images,
      backupImages: backupImages,
      pdfs: pdfs,
      statusHistory: statusHistory,
    );
  }

  static OrderStatus _parseStatus(String? status) {
    if (status == null) return OrderStatus.pending;

    // Normalize: lowercase and remove spaces, underscores, and dashes
    final s = status.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

    switch (s) {
      case 'pending':
        return OrderStatus.pending;
      case 'pendingdisp':
        return OrderStatus.PendingDisp;
      case 'casted':
        return OrderStatus.Casted;
      case 'wax': // handles "Wax", "in_progress"
      case 'processing':
        return OrderStatus.Wax;
      case 'dc':
        return OrderStatus.DC;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      case 'delay':
        return OrderStatus.delay;
      case 'due':
        return OrderStatus.due;
      case 'partialdelivery': // handles "partial delivery", "partial_delivery"
      case 'partiallydelivered':
        return OrderStatus.partialDelivery;
      case 'completed':
        return OrderStatus.Completed;
      case 'delivered':
        return OrderStatus.Delivered;
      default:
        return OrderStatus.pending;
    }
  }

  // Parse party ID from partyname field (can be string or object)
  static String? _parsePartyId(dynamic partyname) {
    if (partyname == null) return null;
    if (partyname is String) return partyname;
    if (partyname is Map<String, dynamic>) {
      return (partyname['_id'] ?? partyname['id'])?.toString();
    }
    return partyname.toString();
  }

  // Parse party name from partyname field (can be string or object)
  static String? _parsePartyName(dynamic partyname) {
    if (partyname == null) return null;
    if (partyname is String)
      return null; // If it's just ID, we don't have the name
    if (partyname is Map<String, dynamic>) {
      return partyname['name']?.toString();
    }
    return null;
  }

  // Parse updated by from updatedby field (can be string or object)
  static String? _parseUpdatedBy(dynamic updatedby) {
    if (updatedby == null) return null;
    if (updatedby is String) return updatedby;
    if (updatedby is Map<String, dynamic>) {
      return updatedby['name']?.toString();
    }
    return updatedby.toString();
  }

  // Convert OrderStatus enum to API string format
  static String statusToApiString(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.Casted:
        return 'Casted';
      case OrderStatus.Wax:
        return 'Wax';
      case OrderStatus.DC:
        return 'DC';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.delay:
        return 'Delay';
      case OrderStatus.due:
        return 'Due';
      case OrderStatus.partialDelivery:
        return 'Partial Delivery';
      case OrderStatus.PendingDisp:
        return 'PendingDisp';
      case OrderStatus.Completed:
        return 'Completed';
      case OrderStatus.Delivered:
        return 'Delivered';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'description': description,
      'amount': amount,
      'status': statusToApiString(status),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'notes': notes,
      'assignedEmployeeId': assignedEmployeeId,
      'orderType': orderType,
      'orderNo': orderNo,
      'orderDate': orderDate?.toIso8601String(),
      if (orderPriority != null) 'orderpriority': orderPriority,
      if (partyname != null) 'partyname': partyname,
      if (partynameDisplay != null) 'partynameDisplay': partynameDisplay,
      'ornamentDetails': ornamentDetails.map((d) => d.toJson()).toList(),
      'images': images,
      'backupImages': backupImages,
      'pdfs': pdfs,
      if (statusHistory.isNotEmpty)
        'statushistory': statusHistory.map((h) => h.toJson()).toList(),
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
    String? updatedBy,
    String? orderType,
    String? orderNo,
    DateTime? orderDate,
    String? orderPriority,
    String? partyname,
    String? partynameDisplay,
    List<OrnamentDetail>? ornamentDetails,
    List<String>? images,
    List<String>? backupImages,
    List<String>? pdfs,
    List<StatusHistoryEntry>? statusHistory,
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
      updatedBy: updatedBy ?? this.updatedBy,
      orderType: orderType ?? this.orderType,
      orderNo: orderNo ?? this.orderNo,
      orderDate: orderDate ?? this.orderDate,
      orderPriority: orderPriority ?? this.orderPriority,
      partyname: partyname ?? this.partyname,
      partynameDisplay: partynameDisplay ?? this.partynameDisplay,
      ornamentDetails: ornamentDetails ?? this.ornamentDetails,
      images: images ?? this.images,
      backupImages: backupImages ?? this.backupImages,
      pdfs: pdfs ?? this.pdfs,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }

  String get statusText {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.Casted:
        return 'Casted';
      case OrderStatus.Wax:
        return 'Wax';
      case OrderStatus.DC:
        return 'DC';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.delay:
        return 'Delay';
      case OrderStatus.due:
        return 'Due';
      case OrderStatus.partialDelivery:
        return 'Partial Delivery';
      case OrderStatus.PendingDisp:
        return 'PendingDisp';
      case OrderStatus.Completed:
        return 'Completed';
      case OrderStatus.Delivered:
        return 'Delivered';
    }
  }

  Color get statusColor {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.Casted:
        return Colors.blue;
      case OrderStatus.Wax:
        return Colors.purple;
      case OrderStatus.DC:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.delay:
        return Colors.black;
      case OrderStatus.due:
        return Colors.red;
      case OrderStatus.partialDelivery:
        return AppConstants.partialDeliveryColor;
      case OrderStatus.PendingDisp:
        return AppConstants.PendingDisp;
      case OrderStatus.Completed:
        return AppConstants.Completed;
      case OrderStatus.Delivered:
        return AppConstants.deliveredColor; // Add this to AppConstants
    }
  }

  // Check if order should be automatically marked as delivered
  bool get shouldBeDelivered {
    if (status != OrderStatus.partialDelivery) return false;

    // Check if all ornament details have delivery count >= quantity
    for (final detail in ornamentDetails) {
      if (detail.deliverycount == null ||
          detail.deliverycount! < detail.quantity) {
        return false;
      }
    }
    return true;
  }

  // Get total delivery count across all ornament details
  int get totalDeliveryCount {
    return ornamentDetails.fold(
      0,
      (sum, detail) => sum + (detail.deliverycount ?? 0),
    );
  }

  // Get total quantity across all ornament details
  int get totalQuantity {
    return ornamentDetails.fold(0, (sum, detail) => sum + detail.quantity);
  }
}
