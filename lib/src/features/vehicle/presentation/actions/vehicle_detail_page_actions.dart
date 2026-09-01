import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app.dart';

class VehicleDetailPageActions {
  const VehicleDetailPageActions._();

  static void openAlerts(BuildContext context) {
    final shellTabs = context.read<ShellTabController>();
    shellTabs.showAlerts();
    Navigator.of(context).pop();
  }
}