import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';

enum OperationsTab {
  minerals,
  transactions,
  weighbridge,
  loads,
  security,
  gate,
}

extension OperationsTabX on OperationsTab {
  String get id {
    switch (this) {
      case OperationsTab.minerals:
        return 'minerals';
      case OperationsTab.transactions:
        return 'transactions';
      case OperationsTab.weighbridge:
        return 'weighbridge';
      case OperationsTab.loads:
        return 'loads';
      case OperationsTab.security:
        return 'security';
      case OperationsTab.gate:
        return 'gate';
    }
  }

  String get label {
    switch (this) {
      case OperationsTab.minerals:
        return 'Minerals';
      case OperationsTab.transactions:
        return 'Transactions';
      case OperationsTab.weighbridge:
        return 'Weighbridge';
      case OperationsTab.loads:
        return 'Loads';
      case OperationsTab.security:
        return 'Security';
      case OperationsTab.gate:
        return 'Gate Checks';
    }
  }

  IconData get icon {
    switch (this) {
      case OperationsTab.minerals:
        return Icons.diamond_outlined;
      case OperationsTab.transactions:
        return Icons.receipt_long_outlined;
      case OperationsTab.weighbridge:
        return Icons.scale_outlined;
      case OperationsTab.loads:
        return Icons.inventory_2_outlined;
      case OperationsTab.security:
        return Icons.security_outlined;
      case OperationsTab.gate:
        return Icons.sensor_door_outlined;
    }
  }

  static OperationsTab fromId(String? id) {
    return OperationsTab.values.firstWhere(
      (tab) => tab.id == id,
      orElse: () => OperationsTab.transactions,
    );
  }
}

class OperationsAccessPolicy {
  const OperationsAccessPolicy._();

  /// The tabs an org type has anyone to staff.
  ///
  /// Not a matter of taste — the role model already says it.
  /// `UserRole.getRolesForOrgType` gives `security` and `controllerWB` to
  /// **mineSupplier only**, so a weighbridge or a mine gate on a buyer's
  /// console is a surface nobody at that organisation could ever operate.
  static const Map<OrgType, List<OperationsTab>> _tabsByOrgType = {
    OrgType.mineSupplier: OperationsTab.values,
    // A buyer receives loads and settles transactions. It owns no pile, runs
    // no weighbridge and keeps no gate.
    OrgType.buyer: [OperationsTab.transactions, OperationsTab.loads],
    // A transporter hauls. Same two surfaces, from the other side.
    OrgType.transporter: [OperationsTab.transactions, OperationsTab.loads],
  };

  /// Tabs this session may open.
  ///
  /// [orgType] is required and is an **access input**, not a hint. It used to
  /// exist only on `OperationsKey`, where it was referenced by `==` and
  /// `hashCode` and nothing else — a cache-key discriminator. Meanwhile this
  /// method opened with `if (canEditAll) return OperationsTab.values;`, and
  /// `canEditAll` is true for *every company account*
  /// (`_OperationsAccess.fromState`), so a buyer or transporter owner was
  /// handed all six tabs including the mine floor (S6-26).
  static List<OperationsTab> visibleTabs({
    required bool canEditAll,
    required OrgType orgType,
    UserRole? role,
  }) {
    final allowed = _tabsByOrgType[orgType] ?? const [OperationsTab.transactions];

    if (canEditAll) {
      return allowed;
    }

    // A role can only ever narrow what its org type offers, never widen it.
    List<OperationsTab> narrow(List<OperationsTab> byRole) =>
        byRole.where(allowed.contains).toList(growable: false);

    switch (role) {
      case UserRole.security:
        return narrow(const [
          OperationsTab.security,
          OperationsTab.gate,
          OperationsTab.transactions,
        ]);
      case UserRole.controllerWB:
        return narrow(
            const [OperationsTab.transactions, OperationsTab.weighbridge]);
      case UserRole.supervisorForeman:
        return narrow(
            const [OperationsTab.transactions, OperationsTab.weighbridge]);
      case UserRole.driver:
        return narrow(const [OperationsTab.transactions, OperationsTab.loads]);
      default:
        return narrow(const [OperationsTab.transactions]);
    }
  }

  /// Whether this session may create a record on [tab].
  ///
  /// [orgType] gates it for the same reason as [visibleTabs]: `canEditAll`
  /// returned `true` for every tab, so a buyer company account was handed a
  /// create button for a weighbridge record it has no weighbridge to weigh on.
  static bool canCreate({
    required bool canEditAll,
    required OperationsTab tab,
    required OrgType orgType,
    UserRole? role,
  }) {
    final allowed =
        _tabsByOrgType[orgType] ?? const [OperationsTab.transactions];
    if (!allowed.contains(tab)) {
      return false;
    }

    if (canEditAll) {
      return true;
    }

    switch (tab) {
      case OperationsTab.weighbridge:
        return role == UserRole.controllerWB;
      case OperationsTab.security:
      case OperationsTab.gate:
        return role == UserRole.security;
      case OperationsTab.loads:
      case OperationsTab.transactions:
      case OperationsTab.minerals:
        return false;
    }
  }
}

class MineralRecord {
  final String id;
  final String companyId;
  final String name;
  final String? grade;
  final String? description;
  final String unitOfMeasure;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MineralRecord({
    required this.id,
    required this.companyId,
    required this.name,
    this.grade,
    this.description,
    required this.unitOfMeasure,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MineralRecord.fromJson(Map<String, dynamic> json) {
    return MineralRecord(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      grade: json['grade'] as String?,
      description: json['description'] as String?,
      unitOfMeasure: (json['unit_of_measure'] as String?) ?? 'ton',
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class OperationTransaction {
  final String id;
  final String? mineralId;
  final String? supplierCompanyId;
  final String? buyerCompanyId;
  final String? transporterCompanyId;
  final String referenceNumber;
  final String status;

  /// The ORDERED / agreed amount from the request. Frequently 0 or unset — it
  /// is NOT what actually shipped. For real outbound tonnage use [netTonsOut].
  final double quantity;

  /// Real outbound tonnage = sum of this transaction's trips' weighbridge
  /// Net Mass (Gross − Tare), from `trips.net_tons`. Populated when a snapshot
  /// is built (see `LogisticsService`); 0 when no load has been recorded yet.
  /// This is the authoritative "tons out" figure the recon table shows — never
  /// aggregate [quantity] for tonnage. See migration
  /// 20260714000000_dashboard_tons_from_net_mass.sql (same fix, server side).
  final double netTonsOut;
  final Map<String, dynamic> metadata;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OperationTransaction({
    required this.id,
    this.mineralId,
    this.supplierCompanyId,
    this.buyerCompanyId,
    this.transporterCompanyId,
    required this.referenceNumber,
    required this.status,
    required this.quantity,
    this.netTonsOut = 0,
    required this.metadata,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OperationTransaction.fromJson(Map<String, dynamic> json) {
    return OperationTransaction(
      id: json['id'] as String,
      mineralId: json['mineral_id'] as String?,
      supplierCompanyId: json['supplier_company_id'] as String?,
      buyerCompanyId: json['buyer_company_id'] as String?,
      transporterCompanyId: json['transporter_company_id'] as String?,
      referenceNumber: json['reference_number'] as String,
      status: (json['status'] as String?) ?? 'draft',
      quantity: ((json['quantity'] as num?) ?? 0).toDouble(),
      netTonsOut: ((json['net_tons_out'] as num?) ?? 0).toDouble(),
      metadata: Map<String, dynamic>.from(
        (json['metadata'] as Map?) ?? const <String, dynamic>{},
      ),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  OperationTransaction copyWith({double? netTonsOut}) {
    return OperationTransaction(
      id: id,
      mineralId: mineralId,
      supplierCompanyId: supplierCompanyId,
      buyerCompanyId: buyerCompanyId,
      transporterCompanyId: transporterCompanyId,
      referenceNumber: referenceNumber,
      status: status,
      quantity: quantity,
      netTonsOut: netTonsOut ?? this.netTonsOut,
      metadata: metadata,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class WeighbridgeRecord {
  final String id;
  final String? transactionId;
  final String? companyId;
  final String? vehicleId;
  final String direction;
  final double? grossWeight;
  final double? tareWeight;
  final double? netWeight;
  final String? recordedBy;
  final DateTime recordedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WeighbridgeRecord({
    required this.id,
    this.transactionId,
    this.companyId,
    this.vehicleId,
    required this.direction,
    this.grossWeight,
    this.tareWeight,
    this.netWeight,
    this.recordedBy,
    required this.recordedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WeighbridgeRecord.fromJson(Map<String, dynamic> json) {
    return WeighbridgeRecord(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String?,
      companyId: json['company_id'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      direction: (json['direction'] as String?) ?? 'inbound',
      grossWeight: (json['gross_weight'] as num?)?.toDouble(),
      tareWeight: (json['tare_weight'] as num?)?.toDouble(),
      netWeight: (json['net_weight'] as num?)?.toDouble(),
      recordedBy: json['recorded_by'] as String?,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class MineralLoadRecord {
  final String id;
  final String? transactionId;
  final String? vehicleId;
  final String? mineralId;
  final String? loaderEmployeeId;
  final String? notes;
  final DateTime loadedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MineralLoadRecord({
    required this.id,
    this.transactionId,
    this.vehicleId,
    this.mineralId,
    this.loaderEmployeeId,
    this.notes,
    required this.loadedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MineralLoadRecord.fromJson(Map<String, dynamic> json) {
    return MineralLoadRecord(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      mineralId: json['mineral_id'] as String?,
      loaderEmployeeId: json['loader_employee_id'] as String?,
      notes: json['notes'] as String?,
      loadedAt: DateTime.parse(json['loaded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class SecurityIncidentRecord {
  final String id;
  final String companyId;
  final String? employeeId;
  final String? vehicleId;
  final String severity;
  final String title;
  final String? description;
  final String status;
  final String? reportedBy;
  final String? resolvedBy;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SecurityIncidentRecord({
    required this.id,
    required this.companyId,
    this.employeeId,
    this.vehicleId,
    required this.severity,
    required this.title,
    this.description,
    required this.status,
    this.reportedBy,
    this.resolvedBy,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SecurityIncidentRecord.fromJson(Map<String, dynamic> json) {
    return SecurityIncidentRecord(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      employeeId: json['employee_id'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      severity: (json['severity'] as String?) ?? 'low',
      title: json['title'] as String,
      description: json['description'] as String?,
      status: (json['status'] as String?) ?? 'open',
      reportedBy: json['reported_by'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class GateCheckRecord {
  final String id;
  final String companyId;
  final String? employeeId;
  final String? vehicleId;
  final String checkType;
  final String gateStatus;
  final String? notes;
  final String? checkedBy;
  final DateTime checkedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GateCheckRecord({
    required this.id,
    required this.companyId,
    this.employeeId,
    this.vehicleId,
    required this.checkType,
    required this.gateStatus,
    this.notes,
    this.checkedBy,
    required this.checkedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GateCheckRecord.fromJson(Map<String, dynamic> json) {
    return GateCheckRecord(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      employeeId: json['employee_id'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      checkType: (json['check_type'] as String?) ?? 'entry',
      gateStatus: (json['gate_status'] as String?) ?? 'pending',
      notes: json['notes'] as String?,
      checkedBy: json['checked_by'] as String?,
      checkedAt: DateTime.parse(json['checked_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class BroadcastUpdate {
  final String id;
  final String event;
  final Map<String, dynamic> payload;
  final String? createdBy;
  final DateTime timestamp;

  const BroadcastUpdate({
    required this.id,
    required this.event,
    required this.payload,
    this.createdBy,
    required this.timestamp,
  });

  factory BroadcastUpdate.fromJson(Map<String, dynamic> json) {
    return BroadcastUpdate(
      id: json['id'] as String,
      event: json['event'] as String,
      payload: Map<String, dynamic>.from(
        (json['payload'] as Map?) ?? const <String, dynamic>{},
      ),
      createdBy: json['created_by'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  String? get companyId => payload['company_id'] as String?;
  String get title => (payload['title'] as String?) ?? event;
  String get message => (payload['message'] as String?) ?? '';
  String get importance => (payload['importance'] as String?) ?? 'normal';
}
