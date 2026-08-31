import 'package:flutter/material.dart';

enum ManualScenario {
  idle,
  moving,
  stopped,
  offline,
  warning,
  critical,
  tripCompleted,
}

class ManualTelemetryRowInput {
  const ManualTelemetryRowInput({
    required this.vehicleId,
    required this.regNumber,
    required this.model,
    required this.minutesAgo,
    required this.soc,
    required this.speed,
    required this.ignition,
    required this.batteryTemp,
    required this.odometer,
    required this.includeLocation,
    required this.lat,
    required this.lon,
    required this.accuracyM,
    required this.eventTimeUtc,
  });

  final String vehicleId;
  final String regNumber;
  final String model;
  final int minutesAgo;
  final double soc;
  final double speed;
  final double ignition;
  final double batteryTemp;
  final double odometer;
  final bool includeLocation;
  final double lat;
  final double lon;
  final double accuracyM;
  final DateTime eventTimeUtc;
}

class ManualVehicleLabPage extends StatefulWidget {
  const ManualVehicleLabPage({
    super.key,
    required this.onUpsertVehicle,
    required this.onAppendRow,
    required this.onRunScenario,
  });

  final Future<String> Function({
    required String vehicleId,
    required String regNumber,
    required String model,
  }) onUpsertVehicle;

  final Future<String> Function(ManualTelemetryRowInput input) onAppendRow;

  final Future<String> Function({
    required ManualScenario scenario,
    required String vehicleId,
    required String regNumber,
    required String model,
  }) onRunScenario;

  @override
  State<ManualVehicleLabPage> createState() => _ManualVehicleLabPageState();
}

class _ManualVehicleLabPageState extends State<ManualVehicleLabPage> {
  late final TextEditingController _vehicleIdController;
  late final TextEditingController _regController;
  late final TextEditingController _modelController;
  late final TextEditingController _rowController;

  bool _busy = false;
  String? _status;
  String? _error;
  late DateTime _timelineAnchorUtc;

  @override
  void initState() {
    super.initState();
    _vehicleIdController = TextEditingController(text: 'VH-LAB-001');
    _regController = TextEditingController(text: 'KA-01-LB-1001');
    _modelController = TextEditingController(text: 'E-Truck X1');
    final now = DateTime.now().toUtc();
    _timelineAnchorUtc = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    _rowController = TextEditingController(
      text:
          'VH-LAB-001,KA-01-LB-1001,E-Truck X1,0,62,0,1,34,12000,12.971600,77.594600,8',
    );
  }

  @override
  void dispose() {
    _vehicleIdController.dispose();
    _regController.dispose();
    _modelController.dispose();
    _rowController.dispose();
    super.dispose();
  }

  Future<void> _upsertVehicle() async {
    await _withBusy(() async {
      final status = await widget.onUpsertVehicle(
        vehicleId: _vehicleIdController.text.trim(),
        regNumber: _regController.text.trim(),
        model: _modelController.text.trim(),
      );
      setState(() {
        _status = status;
      });
    });
  }

  Future<void> _appendRowFromCsv() async {
    final input = _readRowInput();
    if (input == null) {
      return;
    }

    await _withBusy(() async {
      final status = await widget.onAppendRow(input);
      setState(() {
        _status = status;
      });
    });
  }

  Future<void> _runScenario(ManualScenario scenario) async {
    await _withBusy(() async {
      final status = await widget.onRunScenario(
        scenario: scenario,
        vehicleId: _vehicleIdController.text.trim(),
        regNumber: _regController.text.trim(),
        model: _modelController.text.trim(),
      );
      setState(() {
        _status = status;
      });
    });
  }

  ManualTelemetryRowInput? _readRowInput() {
    final raw = _rowController.text.trim();
    final parts = raw.split(',').map((value) => value.trim()).toList(growable: false);

    if (parts.length < 12) {
      setState(() {
        _error =
            'Row needs at least 12 comma-separated values: vehicle_id,reg_number,model,minutes_ago,soc,speed,ignition,battery_temp,odometer,lat,lon,accuracy_m';
      });
      return null;
    }

    final vehicleId = parts[0];
    final regNumber = parts[1];
    final model = parts[2];
    final minutesAgo = int.tryParse(parts[3]);
    final soc = double.tryParse(parts[4]);
    final speed = double.tryParse(parts[5]);
    final ignition = double.tryParse(parts[6]);
    final batteryTemp = double.tryParse(parts[7]);
    final odometer = double.tryParse(parts[8]);
    final lat = double.tryParse(parts[9]);
    final lon = double.tryParse(parts[10]);
    final accuracy = double.tryParse(parts[11]);

    if (vehicleId.isEmpty || regNumber.isEmpty || model.isEmpty) {
      setState(() {
        _error = 'Vehicle id, reg number, and model are required in row.';
      });
      return null;
    }

    if (minutesAgo == null ||
        minutesAgo < 0 ||
        soc == null ||
        speed == null ||
        ignition == null ||
        batteryTemp == null ||
        odometer == null) {
      setState(() {
        _error = 'Invalid row input. Check numeric fields.';
      });
      return null;
    }

    final includeLocation = lat != null && lon != null && accuracy != null;
    final eventTimeUtc = _timelineAnchorUtc.subtract(Duration(minutes: minutesAgo));

    _vehicleIdController.text = vehicleId;
    _regController.text = regNumber;
    _modelController.text = model;

    return ManualTelemetryRowInput(
      vehicleId: vehicleId,
      regNumber: regNumber,
      model: model,
      minutesAgo: minutesAgo,
      soc: soc,
      speed: speed,
      ignition: ignition,
      batteryTemp: batteryTemp,
      odometer: odometer,
      includeLocation: includeLocation,
      lat: lat ?? 0,
      lon: lon ?? 0,
      accuracyM: accuracy ?? 8,
      eventTimeUtc: eventTimeUtc,
    );
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Manual Vehicle Lab',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Create one vehicle and append your own telemetry rows to force scenarios.',
        ),
        const SizedBox(height: 4),
        const Text(
          'Note: SOC < 10 and battery_temp > 45 are separate critical alerts, so setting both shows two entries.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _field('Vehicle ID', _vehicleIdController),
                const SizedBox(height: 8),
                _field('Reg Number', _regController),
                const SizedBox(height: 8),
                _field('Model', _modelController),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _upsertVehicle,
                    icon: const Icon(Icons.directions_car),
                    label: const Text('Upsert Vehicle'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Paste Single Row',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Format: vehicle_id,reg_number,model,minutes_ago,soc,speed,ignition,battery_temp,odometer,lat,lon,accuracy_m[,expected]',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Timeline anchor (UTC): ${_timelineAnchorUtc.toIso8601String()}',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              final now = DateTime.now().toUtc();
                              setState(() {
                                _timelineAnchorUtc = DateTime.utc(
                                  now.year,
                                  now.month,
                                  now.day,
                                  now.hour,
                                  now.minute,
                                );
                                _status =
                                    'Timeline anchor reset to ${_timelineAnchorUtc.toIso8601String()}';
                              });
                            },
                      child: const Text('Reset Anchor'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  enabled: !_busy,
                  controller: _rowController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _appendRowFromCsv,
                    icon: const Icon(Icons.add_chart),
                    label: const Text('Append This Row'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : () => _runScenario(ManualScenario.idle),
              child: const Text('Idle'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _runScenario(ManualScenario.moving),
              child: const Text('Moving'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _runScenario(ManualScenario.stopped),
              child: const Text('Stopped'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _runScenario(ManualScenario.offline),
              child: const Text('Offline'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _runScenario(ManualScenario.warning),
              child: const Text('Warning'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _runScenario(ManualScenario.critical),
              child: const Text('Critical'),
            ),
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _runScenario(ManualScenario.tripCompleted),
              child: const Text('Trip Completed'),
            ),
          ],
        ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_status!),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, {bool enabled = true}) {
    return TextField(
      enabled: enabled && !_busy,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
