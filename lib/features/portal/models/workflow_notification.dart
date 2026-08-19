/// The kind of workflow event a notification was raised for (drives its icon).
enum WorkflowEvent {
  checkin, // security checked a truck in
  loadConfirmed, // controller confirmed a load
  stockpileUpdated, // stockpile deducted after a load
  released, // security released a loaded truck
  stockpileAllocated, // supervisor allocated a new stockpile
}

/// An in-app workflow notification, targeted at a role and (optionally)
/// carrying a navigation target (which portal tab + which truck to open).
///
/// [targetRole] is one of: 'security', 'controller', 'mine'. A user sees a
/// notification when their role key equals [targetRole], and the mine
/// (owner / admin / management) sees everything.
class WorkflowNotification {
  final String id;
  final String targetRole;
  final WorkflowEvent kind;
  final String title;
  final String body;
  final String? tabLabel; // portal tab to open on tap
  final String? reg; // truck reg to preselect on tap
  final DateTime at;
  final bool read;

  const WorkflowNotification({
    required this.id,
    required this.targetRole,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.tabLabel,
    this.reg,
    this.read = false,
  });

  bool get isActionable => tabLabel != null;

  WorkflowNotification copyWith({bool? read}) => WorkflowNotification(
        id: id,
        targetRole: targetRole,
        kind: kind,
        title: title,
        body: body,
        tabLabel: tabLabel,
        reg: reg,
        at: at,
        read: read ?? this.read,
      );
}
