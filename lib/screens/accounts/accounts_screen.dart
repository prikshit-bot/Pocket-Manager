import 'package:flutter/material.dart';
import '../../services/account_service.dart';
import '../../models/account_model.dart';
import '../../utils/currency_formatter.dart';
import 'add_account_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final AccountService _accountService = AccountService();
  late Future<List<Account>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountService.getAllAccounts();
  }

  Future<void> _refresh() async {
    setState(() {
      _accountsFuture = _accountService.getAllAccounts();
    });
    await _accountsFuture;
  }

  String _formatCurrency(double amount) {
    return CurrencyFormatter.format(amount);
  }

  String _cleanErrorMessage(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openAddAccount() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddAccountScreen()),
    );

    if (result == true) {
      _refresh();
    }
  }

  Future<void> _openEditAccount(Account account) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddAccountScreen(account: account),
      ),
    );

    if (result == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: FutureBuilder<List<Account>>(
        future: _accountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Something went wrong loading accounts.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final accounts = snapshot.data ?? [];

          if (accounts.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No accounts yet.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                account.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit account',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _openEditAccount(account),
                            ),
                            IconButton(
                              tooltip: account.isVisible
                                  ? 'Hide account from Home'
                                  : 'Show account on Home',
                              icon: Icon(account.isVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () async {
                                try {
                                  await _accountService.setVisibility(
                                    account.accountId!,
                                    !account.isVisible,
                                  );
                                  await _refresh();
                                } catch (e) {
                                  _showMessage(_cleanErrorMessage(e));
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          account.type,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text('Total: ${_formatCurrency(account.balance)}'),
                        const SizedBox(height: 4),
                        FutureBuilder<double>(
                          future: _accountService.getAvailableBalance(
                            account.accountId!,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox(
                                height: 20,
                                child: LinearProgressIndicator(),
                              );
                            }
                            return Text(
                              'Available: ${_formatCurrency(snapshot.data!)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddAccount,
        child: const Icon(Icons.add),
      ),
    );
  }
}