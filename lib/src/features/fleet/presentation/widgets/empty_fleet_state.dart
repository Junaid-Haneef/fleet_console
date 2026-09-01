import 'package:flutter/material.dart';

class EmptyFleetState extends StatelessWidget {
  const EmptyFleetState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No vehicles match this filter.'),
    );
  }
}