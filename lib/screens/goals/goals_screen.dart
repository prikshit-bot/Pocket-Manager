import 'package:flutter/material.dart';
import '../../services/goal_service.dart';
import '../../services/account_service.dart';
import '../../models/goal_model.dart';
import 'add_goal_screen.dart';
import '../../utils/currency_formatter.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final GoalService _goalService = GoalService();
  final AccountService _accountService = AccountService();

  List<Goal>? _goals;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final goals = await _goalService.getAllGoals();
      if (!mounted) return;
      setState(() {
        _goals = goals;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
      });
    }
  }

  Future<void> _refresh() => _loadGoals();

  String _formatCurrency(double amount) {
    return CurrencyFormatter.format(amount);
  }

  Future<void> _openAddGoal() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddGoalScreen()),
    );

    if (result == true) {
      if (!mounted) return;
      await _refresh();
    }
  }

  Future<void> _openEditGoal(Goal goal) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AddGoalScreen(goal: goal)),
    );
    if (result == true) {
      if (!mounted) return;
      await _refresh();
    }
  }

  Future<void> _changeGoalFunds(Goal goal, {bool withdraw = false}) async {
    final accounts = await _accountService.getActiveAccounts();
    if (!mounted) return;
    if (accounts.isEmpty) {
      _showMessage('Add an active account first.');
      return;
    }

    final amountController = TextEditingController();
    int selectedAccountId = accounts.first.accountId!;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(withdraw ? 'Withdraw from goal' : 'Add money to goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedAccountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: accounts
                    .map((account) => DropdownMenuItem(
                          value: account.accountId,
                          child: Text(account.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedAccountId = value);
                  }
                },
              ),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context, {
                  'accountId': selectedAccountId,
                  'amount': double.tryParse(amountController.text.trim()),
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();

    final amount = result?['amount'] as double?;
    if (result == null || amount == null || amount <= 0) {
      if (result != null) _showMessage('Enter a valid amount.');
      return;
    }

    try {
      final accountId = result['accountId'] as int;
      if (!withdraw) {
        final available = await _accountService.getAvailableBalance(accountId);
        if (amount > available) {
          _showWarning(
            'Not enough available money',
            'This account has ${CurrencyFormatter.format(available)} available, '
            'but you entered ${CurrencyFormatter.format(amount)}. '
            'Reduce the amount or choose another account.',
          );
          return;
        }
      }
      if (withdraw) {
        await _goalService.withdrawMoney(
          goalId: goal.goalId!,
          accountId: accountId,
          amount: amount,
        );
      } else {
        await _goalService.addMoney(
          goalId: goal.goalId!,
          accountId: accountId,
          amount: amount,
        );
      }
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      _showWarning(
        withdraw ? 'Unable to withdraw money' : 'Unable to add money',
        _cleanErrorMessage(e),
      );
    }
  }

  Future<void> _updateGoalStatus(Goal goal, {required bool cancel}) async {
    try {
      if (cancel) {
        await _goalService.cancelGoal(goal.goalId!);
      } else {
        await _goalService.completeGoal(goal.goalId!);
      }
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      _showMessage(_cleanErrorMessage(e));
    }
  }

  String _cleanErrorMessage(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showWarning(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete goal?'),
        content: Text(
          goal.savedAmount > 0
              ? 'Deleting this goal will release its saved money back to the accounts.'
              : 'This permanently deletes the goal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _goalService.deleteGoal(goal.goalId!);
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      _showWarning('Unable to delete goal', _cleanErrorMessage(e));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _displayStatus(Goal goal) {
    if (goal.status == GoalService.active &&
        goal.savedAmount >= goal.targetAmount) {
      return 'Sufficient money';
    }
    return goal.status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddGoal,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_goals == null && _loadError == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Something went wrong loading goals.\n$_loadError',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final goals = _goals!;

    if (goals.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No goals yet.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: goals.length,
        itemBuilder: (context, index) {
          final goal = goals[index];
          final progress = goal.targetAmount > 0
              ? (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0)
              : 0.0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          goal.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Chip(
                          label: Text(_displayStatus(goal)),
                        backgroundColor:
                            _statusColor(goal.status).withValues(alpha: 0.15),
                          labelStyle: TextStyle(color: _statusColor(goal.status)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Goal actions',
                        onSelected: (value) {
                          // Wait for the popup menu route teardown to finish before opening another route.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            if (value == 'edit') _openEditGoal(goal);
                            if (value == 'add') _changeGoalFunds(goal);
                            if (value == 'withdraw') _changeGoalFunds(goal, withdraw: true);
                            if (value == 'complete') _updateGoalStatus(goal, cancel: false);
                            if (value == 'cancel') _updateGoalStatus(goal, cancel: true);
                            if (value == 'delete') _deleteGoal(goal);
                          });
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit goal'),
                          ),
                          if (goal.status == GoalService.active) ...[
                            const PopupMenuItem(
                              value: 'add',
                              child: Text('Add money'),
                            ),
                            const PopupMenuItem(
                              value: 'withdraw',
                              child: Text('Withdraw money'),
                            ),
                            const PopupMenuItem(
                              value: 'complete',
                              child: Text('Mark complete'),
                            ),
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Text('Cancel goal'),
                            ),
                          ] else if (goal.status == GoalService.completed)
                            const PopupMenuItem(
                              value: 'withdraw',
                              child: Text('Withdraw money'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete goal'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_formatCurrency(goal.savedAmount)} of ${_formatCurrency(goal.targetAmount)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}