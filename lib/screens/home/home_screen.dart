import 'package:flutter/material.dart';
import '../../services/home_service.dart';
import '../../models/home_summary_model.dart';
import '../../models/transaction_model.dart';
import '../../models/goal_model.dart';
import '../transactions/add_income_screen.dart';
import '../transactions/add_expense_screen.dart';
import '../transactions/transfer_form.dart';
import '../transactions/transactions_screen.dart';
import '../goals/goals_screen.dart';
import '../../utils/currency_formatter.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeService _homeService = HomeService();
  late Future<HomeSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _homeService.getHomeSummary();
  }

  Future<void> _refresh() async {
    setState(() {
      _summaryFuture = _homeService.getHomeSummary();
    });
    await _summaryFuture;
  }

  String _formatCurrency(double amount) {
    // Basic INR formatting. Replace with a proper currency formatter
    // (e.g. intl package + AppSettingService.getCurrency()) later.
    return CurrencyFormatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manager')),
      body: FutureBuilder<HomeSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Something went wrong loading your data.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final summary = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _BalanceHeader(
                  totalBalance: summary.totalBalance,
                  availableBalance: summary.availableBalance,
                  totalReserved: summary.totalReserved,
                  formatCurrency: _formatCurrency,
                ),
                const SizedBox(height: 16),
                _MonthlySummaryCards(
                  income: summary.monthlyIncome,
                  expense: summary.monthlyExpense,
                  net: summary.monthlyNet,
                  formatCurrency: _formatCurrency,
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Recent Transactions',
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TransactionsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _RecentTransactionsList(
                  transactions: summary.recentTransactions,
                  formatCurrency: _formatCurrency,
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Goals',
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GoalsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _GoalsPreviewList(goals: summary.goals),
                const SizedBox(height: 80), // room above the FAB
              ],
            ),
          );
        },
      ),
      floatingActionButton: _AddActionButton(onAdded: _refresh),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  final double totalBalance;
  final double availableBalance;
  final double totalReserved;
  final String Function(double) formatCurrency;

  const _BalanceHeader({
    required this.totalBalance,
    required this.availableBalance,
    required this.totalReserved,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Balance',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrency(totalBalance),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (totalReserved > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reserved for goals: ${formatCurrency(totalReserved)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Available: ${formatCurrency(availableBalance)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthlySummaryCards extends StatelessWidget {
  final double income;
  final double expense;
  final double net;
  final String Function(double) formatCurrency;

  const _MonthlySummaryCards({
    required this.income,
    required this.expense,
    required this.net,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Income',
            value: formatCurrency(income),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: 'Expense',
            value: formatCurrency(expense),
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: 'Net',
            value: formatCurrency(net),
            color: net >= 0 ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

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

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

class _RecentTransactionsList extends StatelessWidget {
  final List<Transaction> transactions;
  final String Function(double) formatCurrency;

  const _RecentTransactionsList({
    required this.transactions,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No transactions yet.'),
      );
    }

    return Column(
      children: transactions.map((t) {
        final isIncome = t.type == 'Income';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: isIncome
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
          title: Text(t.note?.isNotEmpty == true ? t.note! : t.type),
          subtitle: Text(
            '${t.date.day}/${t.date.month}/${t.date.year}',
          ),
          trailing: Text(
            '${isIncome ? '+' : '-'}${formatCurrency(t.amount)}',
            style: TextStyle(
              color: isIncome ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GoalsPreviewList extends StatelessWidget {
  final List<Goal> goals;

  const _GoalsPreviewList({required this.goals});

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No active goals yet.'),
      );
    }

    return Column(
      children: goals.map((g) {
        final progress =
            g.targetAmount > 0 ? (g.savedAmount / g.targetAmount).clamp(0.0, 1.0) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(g.name, style: Theme.of(context).textTheme.bodyMedium),
                  Text('${(progress * 100).toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AddActionButton extends StatelessWidget {
  final VoidCallback onAdded;

  const _AddActionButton({required this.onAdded});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showAddSheet(context),
      child: const Icon(Icons.add),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.arrow_downward, color: Colors.green),
                title: const Text('Income'),
                onTap: () async {
                    Navigator.pop(context);

                    final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                        builder: (_) => const AddIncomeScreen(),
                        ),
                    );

                    if (result == true) {
                        onAdded();
                    }
                    },
              ),
            ListTile(
            leading: const Icon(Icons.arrow_upward, color: Colors.red),
            title: const Text('Expense'),
            onTap: () async {
                Navigator.pop(context);

                final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddExpenseScreen(),
                ),
                );

                if (result == true) {
                onAdded();
                }
                },
            ),
            ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Transfer'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Add Transfer')),
                        body: const TransferForm(),
                      ),
                    ),
                  );
                  if (result == true) onAdded();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}