import 'package:flutter/material.dart';

import '../../models/vehicle_detail_models.dart';
import 'soc_history_table.dart';
import 'trip_list.dart';

class HistoryTripsTabs extends StatelessWidget {
  const HistoryTripsTabs({
    required this.socHistory,
    required this.recentTrips,
    super.key,
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
                    SocHistoryTable(points: socHistory),
                    TripList(trips: recentTrips),
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