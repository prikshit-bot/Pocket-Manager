import 'package:flutter/material.dart';
import '../../services/transaction_service.dart';
import '../../services/category_service.dart';
import '../../models/category_model.dart';
import '../../utils/currency_formatter.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<_ReportData> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _loadReport();
  }

  Future<_ReportData> _loadReport() async {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1)
        .subtract(const Duration(milliseconds: 1));

    final transactions = await _transactionService.getTransactionsByDateRange(start, end);
    final categories = await _categoryService.getAllCategories();
    final categoriesById = {for (final c in categories) c.categoryId!: c};

    double income = 0;
    double expense = 0;
    final Map<int, double> incomeByCategory = {};
    final Map<int, double> expenseByCategory = {};

    for (final t in transactions) {
      if (t.type == 'Income') {
        income += t.amount;
        incomeByCategory[t.categoryId] = (incomeByCategory[t.categoryId] ?? 0) + t.amount;
      } else {
        expense += t.amount;
        expenseByCategory[t.categoryId] = (expenseByCategory[t.categoryId] ?? 0) + t.amount;
      }
    }

    return _ReportData(
      income: income,
      expense: expense,
      net: income - expense,
      incomeByCategory: incomeByCategory,
      expenseByCategory: expenseByCategory,
      categoriesById: categoriesById,
    );
  }

  Future<void> _changeMonth(int delta) async {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      _reportFuture = _loadReport();
    });
  }

  String _formatCurrency(double amount) => CurrencyFormatter.format(amount);

  String _formatMonth(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildBreakdown(
    String title,
    Map<int, double> byCategory,
    Map<int, Category> categoriesById,
    Color color,
  ) {
    if (byCategory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('No $title this month.'),
      );
    }

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...entries.map((entry) {
          final name = categoriesById[entry.key]?.name ?? 'Unknown';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name),
                Text(
                  _formatCurrency(entry.value),
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  _formatMonth(_selectedMonth),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<_ReportData>(
              future: _reportFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final data = snapshot.data!;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryTile(
                            label: 'Income',
                            value: _formatCurrency(data.income),
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryTile(
                            label: 'Expense',
                            value: _formatCurrency(data.expense),
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryTile(
                            label: 'Net',
                            value: _formatCurrency(data.net),
                            color: data.net >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildBreakdown(
                      'Income by Category',
                      data.incomeByCategory,
                      data.categoriesById,
                      Colors.green,
                    ),
                    const SizedBox(height: 24),
                    _buildBreakdown(
                      'Expense by Category',
                      data.expenseByCategory,
                      data.categoriesById,
                      Colors.red,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportData {
  final double income;
  final double expense;
  final double net;
  final Map<int, double> incomeByCategory;
  final Map<int, double> expenseByCategory;
  final Map<int, Category> categoriesById;

  _ReportData({
    required this.income,
    required this.expense,
    required this.net,
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.categoriesById,
  });
}