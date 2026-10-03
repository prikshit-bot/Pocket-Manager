import 'package:flutter/material.dart';
import '../../services/account_service.dart';
import '../../services/category_service.dart';
import '../../services/transaction_service.dart';
import '../../models/account_model.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../utils/currency_formatter.dart';

class TransactionForm extends StatefulWidget {
  final String type; // 'Income' or 'Expense'
  final Transaction? initialTransaction;

  const TransactionForm({
    super.key,
    required this.type,
    this.initialTransaction,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  final AccountService _accountService = AccountService();
  final CategoryService _categoryService = CategoryService();
  final TransactionService _transactionService = TransactionService();

  List<Account> _accounts = [];
  List<Category> _categories = [];

  int? _selectedAccountId;
  int? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();

  bool _isLoadingOptions = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final transaction = widget.initialTransaction;
    if (transaction != null) {
      _amountController.text = transaction.amount.toStringAsFixed(2);
      _noteController.text = transaction.note ?? '';
      _selectedAccountId = transaction.accountId;
      _selectedCategoryId = transaction.categoryId;
      _selectedDate = transaction.date;
    }
    _loadFormOptions();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadFormOptions() async {
    try {
      final accounts = await _accountService.getActiveAccounts();
      final categories = widget.type == 'Income'
          ? await _categoryService.getIncomeCategories()
          : await _categoryService.getExpenseCategories();

      setState(() {
        _accounts = accounts;
        _categories = categories;
        _isLoadingOptions = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Failed to load accounts/categories: $e';
        _isLoadingOptions = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required.';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number.';
    }
    if (parsed <= 0) {
      return 'Amount must be greater than 0.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedAccountId == null) {
      _showError('Please select an account.');
      return;
    }
    if (_selectedCategoryId == null) {
      _showError('Please select a category.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final amount = double.parse(_amountController.text.trim());
      final now = DateTime.now();

      final transaction = Transaction(
        transactionId: widget.initialTransaction?.transactionId,
        type: widget.type,
        amount: amount,
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdAt: widget.initialTransaction?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.initialTransaction == null) {
        await _transactionService.createTransaction(transaction);
      } else {
        await _transactionService.updateTransaction(transaction);
      }

      if (mounted) {
        Navigator.pop(context, true); // true = something was saved
      }
    } catch (e) {
      _showError(_cleanErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Service errors come through as "Exception: message" — strip the prefix
  // for a cleaner SnackBar.
  String _cleanErrorMessage(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingOptions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_loadError!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_accounts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Add an account first before recording a transaction.'),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${CurrencyFormatter.symbol()} ',
              border: OutlineInputBorder(),
            ),
            validator: _validateAmount,
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<int>(
            initialValue: _selectedCategoryId,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: _categories
                .map((c) => DropdownMenuItem(
                      value: c.categoryId,
                      child: Text(c.name),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategoryId = value;
              });
            },
            validator: (value) =>
                value == null ? 'Please select a category.' : null,
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<int>(
            initialValue: _selectedAccountId,
            decoration: const InputDecoration(
              labelText: 'Account',
              border: OutlineInputBorder(),
            ),
            items: _accounts
                .map((a) => DropdownMenuItem(
                      value: a.accountId,
                      child: Text(a.name),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedAccountId = value;
              });
            },
            validator: (value) =>
                value == null ? 'Please select an account.' : null,
          ),
          const SizedBox(height: 16),

          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(_formatDate(_selectedDate)),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Optional',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isSaving
                ? const Text('Saving...')
              : Text(widget.initialTransaction == null
                ? 'Save ${widget.type}'
                : 'Save Changes'),
          ),
        ],
      ),
    );
  }
}