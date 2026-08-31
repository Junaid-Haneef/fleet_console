part of '../app.dart';

class ShellTabController extends ValueNotifier<int> {
  ShellTabController() : super(0);

  void showFleet() => value = 0;
  void showAlerts() => value = 1;
  void showGeofences() => value = 2;
  void showScale() => value = 3;
  void showManualLab() => value = 4;
}
