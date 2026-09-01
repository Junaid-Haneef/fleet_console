import 'package:flutter/material.dart';

import '../../models/alert_models.dart';

Future<AlertDismissReason?> showAlertDismissReasonSheet(
  BuildContext context,
  ActiveAlertRow alert,
) {
  final reasons = [
    AlertDismissReason.iAmOnIt,
    AlertDismissReason.wrongAlert,
    AlertDismissReason.somethingElse,
  ];

  return showModalBottomSheet<AlertDismissReason>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Dismiss reason',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              dense: true,
              title: Text(
                alertReasonLabel(
                  type: alert.type,
                  severity: alert.severity,
                ),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('Vehicle: ${alert.regNumber}'),
            ),
            ...reasons.map(
              (reason) => ListTile(
                title: Text(alertDismissReasonLabel(reason)),
                onTap: () => Navigator.of(sheetContext).pop(reason),
              ),
            ),
          ],
        ),
      );
    },
  );
}