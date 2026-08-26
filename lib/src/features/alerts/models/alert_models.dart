enum AlertType { batterySoc, batteryTemp }

enum AlertSeverity { warning, critical }

enum AlertDismissReason {
  iAmOnIt,
  wrongAlert,
  somethingElse,
}

class ActiveAlertRow {
  const ActiveAlertRow({
    required this.vehicleId,
    required this.regNumber,
    required this.model,
    required this.type,
    required this.severity,
    required this.sourceEventTime,
  });

  final String vehicleId;
  final String regNumber;
  final String model;
  final AlertType type;
  final AlertSeverity severity;
  final DateTime sourceEventTime;
}

String alertTypeLabel(AlertType type) {
  switch (type) {
    case AlertType.batterySoc:
      return 'Battery SOC alert';
    case AlertType.batteryTemp:
      return 'Battery overheating alert';
  }
}

String alertSeverityLabel(AlertSeverity severity) {
  switch (severity) {
    case AlertSeverity.warning:
      return 'Warning';
    case AlertSeverity.critical:
      return 'Critical';
  }
}

String alertDismissReasonLabel(AlertDismissReason reason) {
  switch (reason) {
    case AlertDismissReason.iAmOnIt:
      return 'I am on it';
    case AlertDismissReason.wrongAlert:
      return 'Wrong alert';
    case AlertDismissReason.somethingElse:
      return 'Something else…';
  }
}
