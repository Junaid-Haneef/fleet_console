import 'package:flutter/material.dart';

import '../../telemetry/models/telemetry_replay_options.dart';

class ScaleTelemetryCounts {
  const ScaleTelemetryCounts({
    required this.vehicleRows,
    required this.signalRows,
    required this.locationRows,
    required this.transitionRows,
    required this.tripRows,
    required this.inProgressTrips,
    required this.completedTrips,
  });

  final int vehicleRows;
  final int signalRows;
  final int locationRows;
  final int transitionRows;
  final int tripRows;
  final int inProgressTrips;
  final int completedTrips;
}

class ScaleReplayResult {
  const ScaleReplayResult({
    required this.summary,
    required this.counts,
    required this.elapsed,
  });

  final TelemetryReplaySummary summary;
  final ScaleTelemetryCounts counts;
  final Duration elapsed;
}

class ScaleExercisePage extends StatefulWidget {
  const ScaleExercisePage({
    super.key,
    required this.onClearData,
    required this.onRunReplay,
    required this.onRunSingleVehicleTripMock,
    required this.onLoadCounts,
  });

  final Future<ScaleTelemetryCounts> Function() onClearData;
  final Future<ScaleReplayResult> Function(TelemetryReplayOptions options)
  onRunReplay;
  final Future<String> Function() onRunSingleVehicleTripMock;
  final Future<ScaleTelemetryCounts> Function() onLoadCounts;

  @override
  State<ScaleExercisePage> createState() => _ScaleExercisePageState();
}

class _ScaleExercisePageState extends State<ScaleExercisePage> {
  late final TextEditingController _seedController;
  late final TextEditingController _vehicleCountController;
  late final TextEditingController _packetsPerVehicleController;
  late final TextEditingController _duplicateRateController;
  late final TextEditingController _lateRateController;
  late final TextEditingController _missingRateController;

  bool _busy = false;
  String? _error;
  String? _status;
  ScaleTelemetryCounts? _counts;

  @override
  void initState() {
    super.initState();
    _seedController = TextEditingController(text: '42');
    _vehicleCountController = TextEditingController(text: '8');
    _packetsPerVehicleController = TextEditingController(text: '16');
    _duplicateRateController = TextEditingController(text: '0.20');
    _lateRateController = TextEditingController(text: '0.25');
    _missingRateController = TextEditingController(text: '0.10');
    _loadCounts();
  }

  @override
  void dispose() {
    _seedController.dispose();
    _vehicleCountController.dispose();
    _packetsPerVehicleController.dispose();
    _duplicateRateController.dispose();
    _lateRateController.dispose();
    _missingRateController.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    setState(() {
      _error = null;
    });

    try {
      final counts = await widget.onLoadCounts();
      if (!mounted) {
        return;
      }
      setState(() {
        _counts = counts;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not load counts: $error';
      });
    }
  }

  Future<void> _clearData() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Clearing data...';
    });

    try {
      final counts = await widget.onClearData();
      if (!mounted) {
        return;
      }
      setState(() {
        _counts = counts;
        _status = 'Reset complete. Baseline geofences reseeded.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Reset failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _runReplay() async {
    final options = _readOptions();
    if (options == null) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _status = 'Replay running...';
    });

    try {
      final result = await widget.onRunReplay(options);
      if (!mounted) {
        return;
      }

      final signalRate = result.elapsed.inMilliseconds == 0
          ? result.counts.signalRows.toDouble()
          : result.counts.signalRows / (result.elapsed.inMilliseconds / 1000.0);

      setState(() {
        _counts = result.counts;
        _status =
            'Replay complete in ${result.elapsed.inMilliseconds} ms. '
            'Processed packets=${result.summary.packetsProcessed}, '
            'generated duplicates=${result.summary.packetDuplicatesGenerated}, '
            'dropped missing=${result.summary.packetsDroppedAsMissing}, '
            'stored signal rows/sec=${signalRate.toStringAsFixed(0)}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Replay failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _runSingleVehicleTripMock() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Running deterministic 1-vehicle trip scenario...';
    });

    try {
      final status = await widget.onRunSingleVehicleTripMock();
      if (!mounted) {
        return;
      }
      final counts = await widget.onLoadCounts();
      if (!mounted) {
        return;
      }
      setState(() {
        _counts = counts;
        _status = status;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Trip mock replay failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  TelemetryReplayOptions? _readOptions() {
    final seed = int.tryParse(_seedController.text.trim());
    final vehicleCount = int.tryParse(_vehicleCountController.text.trim());
    final packetsPerVehicle = int.tryParse(_packetsPerVehicleController.text.trim());
    final duplicateRate = double.tryParse(_duplicateRateController.text.trim());
    final lateRate = double.tryParse(_lateRateController.text.trim());
    final missingRate = double.tryParse(_missingRateController.text.trim());

    final validRate = (double? v) => v != null && v >= 0 && v <= 1;

    if (seed == null ||
        vehicleCount == null ||
        packetsPerVehicle == null ||
        !validRate(duplicateRate) ||
        !validRate(lateRate) ||
        !validRate(missingRate) ||
        vehicleCount < 1 ||
        packetsPerVehicle < 1) {
      setState(() {
        _error =
            'Invalid input. Use integers for seed/vehicle/packets and rates between 0.0 and 1.0.';
      });
      return null;
    }

    return TelemetryReplayOptions(
      seed: seed,
      vehicleCount: vehicleCount,
      packetsPerVehicle: packetsPerVehicle,
      duplicateRate: duplicateRate!,
      lateRate: lateRate!,
      missingRate: missingRate!,
    );
  }

  void _applyCorrectnessPreset() {
    _seedController.text = '19';
    _vehicleCountController.text = '1';
    _packetsPerVehicleController.text = '32';
    _duplicateRateController.text = '0.60';
    _lateRateController.text = '0.50';
    _missingRateController.text = '0.20';
    setState(() {
      _status = 'Applied correctness preset (single-vehicle stress).';
      _error = null;
    });
  }

  void _applyScalePreset() {
    _seedController.text = '42';
    _vehicleCountController.text = '500';
    _packetsPerVehicleController.text = '667';
    _duplicateRateController.text = '0.20';
    _lateRateController.text = '0.25';
    _missingRateController.text = '0.00';
    setState(() {
      _status = 'Applied scale preset (~2,001,000 signal rows).';
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Scale Exercise Lab',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Developer-only controls for phase 8 backfill and measurements.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : _applyCorrectnessPreset,
              child: const Text('Preset: 1 vehicle correctness'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _applyScalePreset,
              child: const Text('Preset: 500 vehicles / ~2M rows'),
            ),
            FilledButton.tonal(
              onPressed: _busy ? null : _runSingleVehicleTripMock,
              child: const Text('Run 1-vehicle trip mock'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInputCard(),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _runReplay,
              icon: const Icon(Icons.play_arrow),
              label: Text(_busy ? 'Running...' : 'Run Replay'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _clearData,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear Operational Data'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _loadCounts,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Counts'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_counts != null) _buildCountsCard(_counts!),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
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

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildField(
              label: 'Seed',
              controller: _seedController,
              hint: '42',
            ),
            const SizedBox(height: 8),
            _buildField(
              label: 'Vehicle count',
              controller: _vehicleCountController,
              hint: '500',
            ),
            const SizedBox(height: 8),
            _buildField(
              label: 'Packets per vehicle',
              controller: _packetsPerVehicleController,
              hint: '667',
            ),
            const SizedBox(height: 8),
            _buildField(
              label: 'Duplicate rate (0..1)',
              controller: _duplicateRateController,
              hint: '0.20',
            ),
            const SizedBox(height: 8),
            _buildField(
              label: 'Late rate (0..1)',
              controller: _lateRateController,
              hint: '0.25',
            ),
            const SizedBox(height: 8),
            _buildField(
              label: 'Missing rate (0..1)',
              controller: _missingRateController,
              hint: '0.00',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      enabled: !_busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildCountsCard(ScaleTelemetryCounts counts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stored Rows',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('vehicles: ${counts.vehicleRows}'),
            Text('signal_readings: ${counts.signalRows}'),
            Text('location_readings: ${counts.locationRows}'),
            Text('geofence_transitions: ${counts.transitionRows}'),
            Text('trips: ${counts.tripRows}'),
            Text('in_progress trips: ${counts.inProgressTrips}'),
            Text('completed trips: ${counts.completedTrips}'),
          ],
        ),
      ),
    );
  }
}
