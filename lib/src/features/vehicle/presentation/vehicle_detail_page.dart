import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app.dart';
import '../models/vehicle_detail_models.dart';
import '../cubit/vehicle_detail_cubit.dart';

class VehicleDetailPage extends StatefulWidget {
  const VehicleDetailPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<VehicleDetailCubit>().load(widget.vehicleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Detail'),
        actions: [
          IconButton(
            onPressed: () {
              final shellTabs = context.read<ShellTabController>();
              shellTabs.showAlerts();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.warning_amber_outlined),
            tooltip: 'Open alerts',
          ),
          IconButton(
            onPressed: () {
              context.read<VehicleDetailCubit>().refresh();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<VehicleDetailCubit, VehicleDetailState>(
        builder: (context, state) {
          final snapshot = state.snapshot;

          if (state.status == VehicleDetailStatus.loading && snapshot == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == VehicleDetailStatus.error && snapshot == null) {
            return _ErrorState(
              message: state.errorMessage ?? state.statusMessage,
              onRetry: () => context.read<VehicleDetailCubit>().refresh(),
            );
          }

          if (snapshot == null) {
            return const SizedBox.shrink();
          }

          return RefreshIndicator(
            onRefresh: () => context.read<VehicleDetailCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _VehicleHeader(
                  identity: snapshot.identity,
                  currentGeofenceName: snapshot.currentGeofenceName,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Readings Register',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...snapshot.readings.map((reading) => _ReadingCard(reading: reading)),
                const SizedBox(height: 12),
                _HistoryTripsTabs(
                  socHistory: snapshot.socHistory,
                  recentTrips: snapshot.recentTrips,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryTripsTabs extends StatelessWidget {
  const _HistoryTripsTabs({
    required this.socHistory,
    required this.recentTrips,
  });

  final List<SocHistoryPoint> socHistory;
  final List<VehicleTripRow> recentTrips;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'History & Trips',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'SOC History'),
                  Tab(text: 'Recent Trips'),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 280,
                child: TabBarView(
                  children: [
                    _SocHistoryTable(points: socHistory),
                    _TripList(trips: recentTrips),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({
    required this.identity,
    required this.currentGeofenceName,
  });

  final VehicleIdentity identity;
  final String currentGeofenceName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(identity.regNumber, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(identity.model),
            const SizedBox(height: 8),
            Text('Current geofence: $currentGeofenceName'),
          ],
        ),
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.reading});

  final VehicleReadingRow reading;

  @override
  Widget build(BuildContext context) {
    final signalId = _signalId(reading.signal);

    return Card(
      key: ValueKey('reading-row-$signalId'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reading.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    _valueText(reading),
                    key: ValueKey('reading-value-$signalId'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _ageText(reading),
                    key: ValueKey('reading-age-$signalId'),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (reading.verdict != VehicleReadingVerdict.none)
              _VerdictPill(
                key: ValueKey('reading-pill-$signalId'),
                verdict: reading.verdict,
              ),
          ],
        ),
      ),
    );
  }

  String _signalId(VehicleSignalKey signal) {
    switch (signal) {
      case VehicleSignalKey.soc:
        return 'soc';
      case VehicleSignalKey.rangeKm:
        return 'range';
      case VehicleSignalKey.speed:
        return 'speed';
      case VehicleSignalKey.batteryTemp:
        return 'battery_temp';
      case VehicleSignalKey.odometer:
        return 'odometer';
      case VehicleSignalKey.lastPing:
        return 'last_ping';
    }
  }

  String _valueText(VehicleReadingRow row) {
    if (!row.hasReported) {
      return '—';
    }

    final value = row.value;
    switch (row.signal) {
      case VehicleSignalKey.soc:
        return value == null ? '—' : '${value.toStringAsFixed(0)}%';
      case VehicleSignalKey.rangeKm:
        return value == null ? '—' : '${value.toStringAsFixed(0)} km';
      case VehicleSignalKey.speed:
        return value == null ? '—' : '${value.toStringAsFixed(0)} km/h';
      case VehicleSignalKey.batteryTemp:
        return value == null ? '—' : '${value.toStringAsFixed(1)} C';
      case VehicleSignalKey.odometer:
        return value == null ? '—' : '${value.toStringAsFixed(1)} km';
      case VehicleSignalKey.lastPing:
        return row.eventTime == null ? '—' : _formatTimestamp(row.eventTime!);
    }
  }

  String _ageText(VehicleReadingRow row) {
    if (!row.hasReported) {
      return 'Never reported';
    }

    final ageSeconds = row.ageSeconds;
    if (ageSeconds == null) {
      return 'Age unavailable';
    }

    return 'Age ${_formatDuration(ageSeconds)}';
  }

  String _formatDuration(int ageSeconds) {
    if (ageSeconds < 60) {
      return '${ageSeconds}s';
    }
    final minutes = ageSeconds ~/ 60;
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    return '${hours}h ${remMinutes}m';
  }

  String _formatTimestamp(DateTime value) {
    final utc = value.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final hh = utc.hour.toString().padLeft(2, '0');
    final mm = utc.minute.toString().padLeft(2, '0');
    final ss = utc.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss UTC';
  }
}

class _VerdictPill extends StatelessWidget {
  const _VerdictPill({super.key, required this.verdict});

  final VehicleReadingVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (verdict) {
      VehicleReadingVerdict.none => ('', Colors.transparent),
      VehicleReadingVerdict.normal => ('NORMAL', Colors.green),
      VehicleReadingVerdict.alert => ('ALERT', Colors.red),
      VehicleReadingVerdict.stale => ('STALE', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SocHistoryTable extends StatelessWidget {
  const _SocHistoryTable({required this.points});

  final List<SocHistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No SOC history in retained event log.'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Event time')),
          DataColumn(label: Text('SOC')),
        ],
        rows: points
            .map(
              (point) => DataRow(
                cells: [
                  DataCell(Text(_formatTimestamp(point.eventTime))),
                  DataCell(Text('${point.soc.toStringAsFixed(1)}%')),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final utc = value.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final hh = utc.hour.toString().padLeft(2, '0');
    final mm = utc.minute.toString().padLeft(2, '0');
    final ss = utc.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss UTC';
  }
}

class _TripList extends StatelessWidget {
  const _TripList({required this.trips});

  final List<VehicleTripRow> trips;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No trips derived yet from confirmed transitions.'),
      );
    }

    return ListView(
      children: trips
          .map((trip) => _TripCard(trip: trip))
          .toList(growable: false),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final VehicleTripRow trip;

  @override
  Widget build(BuildContext context) {
    final statusLabel = trip.status == VehicleTripStatus.completed
        ? 'COMPLETED'
        : 'IN PROGRESS';
    final statusColor = trip.status == VehicleTripStatus.completed
        ? Colors.green
        : Colors.orange;

    final destination = trip.destinationGeofenceName ?? 'Pending entry';

    return Card(
      key: ValueKey('trip-row-${trip.tripId}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${trip.originGeofenceName} -> $destination',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Start: ${_formatTimestamp(trip.startEventTime)}'),
            Text(
              trip.endEventTime == null
                  ? 'End: -'
                  : 'End: ${_formatTimestamp(trip.endEventTime!)}',
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final utc = value.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final hh = utc.hour.toString().padLeft(2, '0');
    final mm = utc.minute.toString().padLeft(2, '0');
    final ss = utc.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss UTC';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
