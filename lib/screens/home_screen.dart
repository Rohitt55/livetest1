import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../db/database_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  String selectedFilter = 'Today';
  List<Map<String, dynamic>> transactions = [];
  double? _monthlyBudget;

  final List<String> filterOptions = ['Today', 'Week', 'Month', 'Year'];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadBudget();
  }

  Future<void> _loadTransactions() async {
    final data = await DatabaseHelper.instance.getAllTransactions();
    setState(() => transactions = data.reversed.toList());
  }

  Future<void> _loadBudget() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _monthlyBudget = prefs.getDouble('monthly_budget');
    });
  }

  List<Map<String, dynamic>> get filteredTransactions {
    final now = DateTime.now();
    return transactions.where((tx) {
      final txDate = DateTime.parse(tx['date']);
      final normalizedTxDate = DateTime(txDate.year, txDate.month, txDate.day);

      switch (selectedFilter) {
        case 'Today':
          final today = DateTime(now.year, now.month, now.day);
          return normalizedTxDate == today;
        case 'Week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          return normalizedTxDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
              normalizedTxDate.isBefore(endOfWeek.add(const Duration(days: 1)));
        case 'Month':
          return txDate.year == now.year && txDate.month == now.month;
        case 'Year':
          return txDate.year == now.year;
        default:
          return true;
      }
    }).toList();
  }

  String getFormattedDate() {
    final now = DateTime.now();
    switch (selectedFilter) {
      case 'Today':
        return DateFormat('d/M/yyyy').format(now);
      case 'Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return "${DateFormat('d/M').format(startOfWeek)} - ${DateFormat('d/M').format(endOfWeek)}";
      case 'Month':
        return DateFormat('MMMM yyyy').format(now);
      case 'Year':
        return DateFormat('yyyy').format(now);
      default:
        return DateFormat('d/M/yyyy').format(now);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double incomeTotal = filteredTransactions
        .where((t) => t['type'] == 'Income')
        .fold(0.0, (sum, item) => sum + double.parse(item['amount'].toString()));

    final double expenseTotal = filteredTransactions
        .where((t) => t['type'] == 'Expense')
        .fold(0.0, (sum, item) => sum + double.parse(item['amount'].toString()));

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF7F0),
        elevation: 0,
        toolbarHeight: 80,
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.calendar_today, size: 20, color: Colors.black87),
              const SizedBox(width: 6),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "${getFormattedDate()}\n",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const TextSpan(
                      text: "Account Balance",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [_buildProfileImage()],
      ),
      body: Column(
        children: [
          if (_monthlyBudget != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Monthly Budget: ৳${_monthlyBudget!.toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (selectedFilter == 'Month')
                    Text("Remaining: ৳${(_monthlyBudget! - expenseTotal).toStringAsFixed(0)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: (expenseTotal > _monthlyBudget!) ? Colors.red : Colors.green,
                        )),
                ],
              ),
            ),
            if (selectedFilter == 'Month' && expenseTotal > _monthlyBudget!)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: const [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text("You’ve exceeded your monthly budget!",
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBalanceCard("Income", incomeTotal, Colors.green),
              _buildBalanceCard("Expenses", expenseTotal, Colors.red),
            ],
          ),
          const SizedBox(height: 10),
          _buildFilterRow(),
          const SizedBox(height: 10),
          _buildTransactionHeader(),
          Expanded(child: _buildTransactionList()),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add').then((_) => _loadTransactions()),
        backgroundColor: Colors.grey,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildProfileImage() {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          final prefs = snapshot.data!;
          final imagePath = prefs.getString('profile_image');
          if (imagePath != null && File(imagePath).existsSync()) {
            return Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: CircleAvatar(backgroundImage: FileImage(File(imagePath))),
            );
          } else {
            return const Padding(
              padding: EdgeInsets.only(right: 12.0),
              child: CircleAvatar(backgroundImage: AssetImage('assets/images/user.png')),
            );
          }
        } else {
          return const Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: CircleAvatar(backgroundColor: Colors.blue),
          );
        }
      },
    );
  }

  Widget _buildBalanceCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: 160,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(title == "Income" ? Icons.arrow_downward : Icons.arrow_upward,
                  color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text("৳${formatAmount(amount)}",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: filterOptions.map((option) {
          final isSelected = selectedFilter == option;
          return GestureDetector(
            onTap: () => setState(() => selectedFilter = option),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepPurple : Colors.grey[200],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                option,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Recent Transactions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/transactions'),
            child: const Text("View All",
                style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (filteredTransactions.isEmpty) {
      return const Center(child: Text("No transactions yet"));
    }

    final limitedList = filteredTransactions.take(5).toList();

    return ListView.builder(
      itemCount: limitedList.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemBuilder: (context, index) {
        final tx = limitedList[index];
        final isIncome = tx['type'] == 'Income';

        final cardColor = (isIncome ? Colors.greenAccent : Colors.redAccent).withOpacity(0.1);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? Colors.green : Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("৳${formatAmount(double.parse(tx['amount'].toString()))}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(tx['description'] ?? '',
                        style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
              Text(tx['type'],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? Colors.green : Colors.red,
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: (index) async {
        setState(() => selectedIndex = index);
        if (index == 1) {
          await Navigator.pushNamed(context, '/transactions');
          _loadTransactions();
        }
        if (index == 2) Navigator.pushNamed(context, '/statistics');
        if (index == 3) {
          await Navigator.pushNamed(context, '/profile');
          await _loadBudget(); // ✅ Refresh budget when returning from profile/settings
        }
      },
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.list), label: "Transactions"),
        BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: "Statistics"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}

String formatAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  } else {
    return amount.toStringAsFixed(2);
  }
}
