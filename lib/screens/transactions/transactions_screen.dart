import 'package:flutter/material.dart';
import '../../services/transaction_service.dart';
import '../../services/transfer_service.dart';
import '../../services/account_service.dart';
import '../../services/category_service.dart';
import '../../models/transaction_model.dart';
import '../../models/transfer_model.dart';
import '../../models/account_model.dart';
import '../../models/category_model.dart';
import 'transcation_form.dart';
import 'transfer_form.dart';
import '../../utils/currency_formatter.dart';

// UI-only wrapper so transactions and transfers can share one sorted list.
class _HistoryItem {
  final DateTime date;
  final Transaction? transaction;
  final Transfer? transfer;

  _HistoryItem.fromTransaction(this.transaction)
      : date = transaction!.date,
        transfer = null;

  _HistoryItem.fromTransfer(this.transfer)
      : date = transfer!.date,
        transaction = null;
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  final TransferService _transferService = TransferService();
  final AccountService _accountService = AccountService();
  final CategoryService _categoryService = CategoryService();

  late TabController _tabController;
  late Future<_HistoryData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_HistoryData> _loadData() async {
    final transactions = await _transactionService.getAllTransactions();
    final transfers = await _transferService.getAllTransfers();
    final accounts = await _accountService.getAllAccounts();
    final categories = await _categoryService.getAllCategories();

    final accountsById = {for (final a in accounts) a.accountId!: a};
    final categoriesById = {for (final c in categories) c.categoryId!: c};

    final all = <_HistoryItem>[
      ...transactions.map((t) => _HistoryItem.fromTransaction(t)),
      ...transfers.map((t) => _HistoryItem.fromTransfer(t)),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return _HistoryData(
      all: all,
      transactions: transactions,
      transfers: transfers,
      accountsById: accountsById,
      categoriesById: categoriesById,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _loadData();
    });
    await _dataFuture;
  }

  Future<void> _openEditTransaction(Transaction transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Edit ${transaction.type}')),
          body: TransactionForm(
            type: transaction.type,
            initialTransaction: transaction,
          ),
        ),
      ),
    );

    if (result == true) {
      _refresh();
    }
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This will permanently delete the transaction.'),
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

    if (confirmed != true || transaction.transactionId == null) return;

    try {
      await _transactionService.deleteTransaction(transaction.transactionId!);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _openEditTransfer(Transfer transfer) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Edit Transfer')),
          body: TransferForm(initialTransfer: transfer),
        ),
      ),
    );
    if (result == true) _refresh();
  }

  Future<void> _deleteTransfer(Transfer transfer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transfer?'),
        content: const Text('This will reverse the transfer and delete it.'),
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
    if (confirmed != true || transfer.transferId == null) return;
    try {
      await _transferService.deleteTransfer(transfer.transferId!);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return CurrencyFormatter.format(amount);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildTransactionTile(
    Transaction t,
    Map<int, Account> accountsById,
    Map<int, Category> categoriesById,
  ) {
    final isIncome = t.type == 'Income';
    final accountName = accountsById[t.accountId]?.name ?? 'Unknown account';
    final categoryName = categoriesById[t.categoryId]?.name ?? 'Unknown category';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            isIncome
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIncome ? Colors.green : Colors.red,
        ),
      ),
      title: Text(categoryName),
      subtitle: Text('$accountName · ${_formatDate(t.date)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isIncome ? '+' : '-'}${_formatCurrency(t.amount)}',
            style: TextStyle(
              color: isIncome ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Transaction actions',
            onSelected: (value) {
              if (value == 'edit') {
                _openEditTransaction(t);
              } else if (value == 'delete') {
                _deleteTransaction(t);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      onTap: () => _openEditTransaction(t),
    );
  }

  Widget _buildTransferTile(Transfer t, Map<int, Account> accountsById) {
    final fromName = accountsById[t.fromAccountId]?.name ?? 'Unknown';
    final toName = accountsById[t.toAccountId]?.name ?? 'Unknown';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.withValues(alpha: 0.15),
        child: const Icon(Icons.swap_horiz, color: Colors.blue),
      ),
      title: Text('$fromName → $toName'),
      subtitle: Text(_formatDate(t.date)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatCurrency(t.amount),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          PopupMenuButton<String>(
            tooltip: 'Transfer actions',
            onSelected: (value) {
              if (value == 'edit') _openEditTransfer(t);
              if (value == 'delete') _deleteTransfer(t);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      onTap: () => _openEditTransfer(t),
    );
  }

  Widget _buildList(List<Widget> tiles) {
    if (tiles.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No records yet.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        itemCount: tiles.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) => tiles[index],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Income'),
            Tab(text: 'Expense'),
            Tab(text: 'Transfer'),
          ],
        ),
      ),
      body: FutureBuilder<_HistoryData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Something went wrong loading transactions.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data!;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(data.all.map((item) {
                if (item.transaction != null) {
                  return _buildTransactionTile(
                    item.transaction!,
                    data.accountsById,
                    data.categoriesById,
                  );
                }
                return _buildTransferTile(item.transfer!, data.accountsById);
              }).toList()),
              _buildList(data.transactions
                  .where((t) => t.type == 'Income')
                  .map((t) => _buildTransactionTile(
                      t, data.accountsById, data.categoriesById))
                  .toList()),
              _buildList(data.transactions
                  .where((t) => t.type == 'Expense')
                  .map((t) => _buildTransactionTile(
                      t, data.accountsById, data.categoriesById))
                  .toList()),
              _buildList(data.transfers
                  .map((t) => _buildTransferTile(t, data.accountsById))
                  .toList()),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryData {
  final List<_HistoryItem> all;
  final List<Transaction> transactions;
  final List<Transfer> transfers;
  final Map<int, Account> accountsById;
  final Map<int, Category> categoriesById;

  _HistoryData({
    required this.all,
    required this.transactions,
    required this.transfers,
    required this.accountsById,
    required this.categoriesById,
  });
}