import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool showIncome = false;
  DateTime selectedWeekStart = _getStartOfCurrentWeek();
  List<Map<String, dynamic>> allTransactions = [];

  static DateTime _getStartOfCurrentWeek() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final data = await DatabaseHelper.instance.getAllTransactions();
    setState(() => allTransactions = data);
  }

  List<Map<String, dynamic>> get filteredByWeekAndType {
    final weekEnd = selectedWeekStart.add(const Duration(days: 6));

    return allTransactions.where((tx) {
      final txDate = DateTime.parse(tx['date']);
      return tx['type'] == (showIncome ? 'Income' : 'Expense') &&
          txDate.isAfter(selectedWeekStart.subtract(const Duration(days: 1))) &&
          txDate.isBefore(weekEnd.add(const Duration(days: 1)));
    }).toList();
  }

  List<BarChartGroupData> get weeklyBars {
    return List.generate(7, (i) {
      final day = selectedWeekStart.add(Duration(days: i));
      double total = 0;
      for (var tx in filteredByWeekAndType) {
        final txDate = DateTime.parse(tx['date']);
        if (txDate.year == day.year &&
            txDate.month == day.month &&
            txDate.day == day.day) {
          total += (tx['amount'] as num).toDouble();
        }
      }
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: total,
          width: 12,
          borderRadius: BorderRadius.circular(4),
          color: showIncome ? Colors.green : Colors.redAccent,
        )
      ]);
    });
  }

  Map<String, int> get groupedByCategory {
    Map<String, int> result = {};
    for (var tx in filteredByWeekAndType) {
      final category = tx['category'];
      final amount = (tx['amount'] as num).toDouble();
      result[category] = (result[category] ?? 0) + amount.toInt();
    }
    return result;
  }

  void _selectWeek(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedWeekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedWeekStart = picked.subtract(Duration(days: picked.weekday - 1));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryData = groupedByCategory;
    final total = categoryData.values.fold(0, (a, b) => a + b);
    final weekRange = "${DateFormat('MMM d').format(selectedWeekStart)} - ${DateFormat('MMM d').format(selectedWeekStart.add(const Duration(days: 6)))}";

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF7F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Weekly Report", style: TextStyle(color: Colors.black)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text("Week: ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _selectWeek(context),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(weekRange),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 3,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildBarChart(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildToggleButton("Expense", !showIncome, () => setState(() => showIncome = false), Colors.redAccent),
                const SizedBox(width: 12),
                _buildToggleButton("Income", showIncome, () => setState(() => showIncome = true), Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildCategoryList(categoryData, total)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Weekly ${showIncome ? 'Income' : 'Expenses'}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 1.7,
          child: BarChart(
            BarChartData(
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      return Text(days[value.toInt() % 7], style: const TextStyle(fontSize: 11));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1000,
                    reservedSize: 36,
                    getTitlesWidget: (value, _) {
                      return Text("${value.toInt()}", style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
              ),
              barGroups: weeklyBars,
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withOpacity(0.3),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
                drawVerticalLine: false,
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(String label, bool selected, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))]
              : [],
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.black)),
      ),
    );
  }

  Widget _buildCategoryList(Map<String, int> categoryData, int total) {
    if (categoryData.isEmpty) {
      return const Center(child: Text("No data available"));
    }

    return ListView(
      children: categoryData.entries.map((entry) {
        final percent = total == 0 ? 0.0 : entry.value / total;
        final color = showIncome ? Colors.green : Colors.redAccent;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 6, backgroundColor: color),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500))),
                Text("৳ ${entry.value}", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 14),
          ],
        );
      }).toList(),
    );
  }
}
