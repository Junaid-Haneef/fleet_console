import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/alerts_bloc.dart';
import 'actions/alerts_page_actions.dart';
import 'widgets/alerts_content.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlertsBloc, AlertsState>(
      builder: (context, state) => AlertsContent(
        state: state,
        onDismissPressed: (alert) {
          AlertsPageActions.onDismissPressed(context, alert);
        },
      ),
    );
  }
}
