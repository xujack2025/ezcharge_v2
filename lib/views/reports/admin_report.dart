import 'package:flutter/material.dart';

import 'package:ezcharge/views/reports/charging_usage_report.dart';
import 'package:ezcharge/views/reports/complaint_resolution_report.dart';
import 'package:ezcharge/views/reports/charging_pile_utilization_report.dart';

class PrintReportScreen extends StatelessWidget {
  const PrintReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Report to Print")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReportTile(context, "📊 Charging Usage Report", ChargingUsageReport()),
          _buildReportTile(context, "🛠️ Complaint Resolution Report", ComplaintResolutionReport()),
          //_buildReportTile(context, "💰 Financial Performance Report", FinancialPerformanceReport()),
          _buildReportTile(context, "🔌 Charging Pile Utilization Report", ChargingPileUtilizationReport()),
        ],
      ),
    );
  }

  Widget _buildReportTile(BuildContext context, String title, Widget reportPage) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => reportPage),
        ),
      ),
    );
  }
}
