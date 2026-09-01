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
  late final TextEditingController _minutesAgoController;
  late final TextEditingController _socController;
  late final TextEditingController _speedController;
  late final TextEditingController _ignitionController;
  late final TextEditingController _batteryTempController;
  late final TextEditingController _odometerController;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  late final TextEditingController _accuracyController;

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
    _minutesAgoController = TextEditingController(text: '0');
    _socController = TextEditingController(text: '62');
    _speedController = TextEditingController(text: '0');
    _ignitionController = TextEditingController(text: '1');
    _batteryTempController = TextEditingController(text: '34');
    _odometerController = TextEditingController(text: '12000');
    _latController = TextEditingController(text: '12.971600');
    _lonController = TextEditingController(text: '77.594600');
    _accuracyController = TextEditingController(text: '8');
  }

  @override
  void dispose() {
    _vehicleIdController.dispose();
    _regController.dispose();
    _modelController.dispose();
    _minutesAgoController.dispose();
    _socController.dispose();
    _speedController.dispose();
    _ignitionController.dispose();
    _batteryTempController.dispose();
    _odometerController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _accuracyController.dispose();
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

  Future<void> _appendRowFromFields() async {
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
    final vehicleId = _vehicleIdController.text.trim();
    final regNumber = _regController.text.trim();
    final model = _modelController.text.trim();

    if (vehicleId.isEmpty || regNumber.isEmpty || model.isEmpty) {
      setState(() {
        _error = 'Vehicle ID, reg number, and model are required.';
      });
      return null;
    }

    final minutesAgo = int.tryParse(_minutesAgoController.text.trim());
    final soc = double.tryParse(_socController.text.trim());
    final speed = double.tryParse(_speedController.text.trim());
    final ignition = double.tryParse(_ignitionController.text.trim());
    final batteryTemp = double.tryParse(_batteryTempController.text.trim());
    final odometer = double.tryParse(_odometerController.text.trim());
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    final accuracy = double.tryParse(_accuracyController.text.trim());

    if (minutesAgo == null || minutesAgo < 0 ||
        soc == null || speed == null || ignition == null ||
        batteryTemp == null || odometer == null) {
      setState(() {
        _error = 'Invalid numeric field. Check minutes_ago, soc, speed, ignition, battery_temp, odometer.';
      });
      return null;
    }

    final includeLocation = lat != null && lon != null && accuracy != null;
    final eventTimeUtc = _timelineAnchorUtc.subtract(Duration(minutes: minutesAgo));

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
                    'Append Telemetry Row',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Uses Vehicle ID / Reg / Model from the card above.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Timeline anchor (UTC): ${_timelineAnchorUtc.toIso8601String()}',
                        style: const TextStyle(fontSize: 12),
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
                Row(
                  children: [
                    Expanded(child: _field('minutes_ago', _minutesAgoController)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('soc (%)', _socController)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('speed (km/h)', _speedController)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _field('ignition (0/1)', _ignitionController)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('battery_temp (°C)', _batteryTempController)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('odometer (km)', _odometerController)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _field('lat', _latController)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('lon', _lonController)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('accuracy (m)', _accuracyController)),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _appendRowFromFields,
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
