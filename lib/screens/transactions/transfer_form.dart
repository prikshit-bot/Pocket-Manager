import 'package:flutter/material.dart';
import '../../models/account_model.dart';
import '../../models/transfer_model.dart';
import '../../services/account_service.dart';
import '../../services/transfer_service.dart';
import '../../utils/currency_formatter.dart';

class TransferForm extends StatefulWidget {
  final Transfer? initialTransfer;

  const TransferForm({super.key, this.initialTransfer});

  @override
  State<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<TransferForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _accountService = AccountService();
  final _transferService = TransferService();

  List<Account> _accounts = [];
  int? _fromAccountId;
  int? _toAccountId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final transfer = widget.initialTransfer;
    if (transfer != null) {
      _amountController.text = transfer.amount.toStringAsFixed(2);
      _noteController.text = transfer.note ?? '';
      _fromAccountId = transfer.fromAccountId;
      _toAccountId = transfer.toAccountId;
      _selectedDate = transfer.date;
    }
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _accountService.getActiveAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _cleanError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromAccountId == null || _toAccountId == null) {
      _showError('Select both accounts.');
      return;
    }
    if (_fromAccountId == _toAccountId) {
      _showError('Source and destination accounts must be different.');
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final transfer = Transfer(
      transferId: widget.initialTransfer?.transferId,
      amount: double.parse(_amountController.text.trim()),
      fromAccountId: _fromAccountId!,
      toAccountId: _toAccountId!,
      date: _selectedDate,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      createdAt: widget.initialTransfer?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (widget.initialTransfer == null) {
        await _transferService.createTransfer(transfer);
      } else {
        await _transferService.updateTransfer(transfer);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError(_cleanError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_accounts.length < 2) {
      return const Center(child: Text('Add at least two active accounts first.'));
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
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              final amount = double.tryParse(value?.trim() ?? '');
              return amount == null || amount <= 0 ? 'Enter a valid amount.' : null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _fromAccountId,
            decoration: const InputDecoration(labelText: 'From account', border: OutlineInputBorder()),
            items: _accounts.map((a) => DropdownMenuItem(value: a.accountId, child: Text(a.name))).toList(),
            onChanged: (value) => setState(() => _fromAccountId = value),
            validator: (value) => value == null ? 'Select a source account.' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _toAccountId,
            decoration: const InputDecoration(labelText: 'To account', border: OutlineInputBorder()),
            items: _accounts.map((a) => DropdownMenuItem(value: a.accountId, child: Text(a.name))).toList(),
            onChanged: (value) => setState(() => _toAccountId = value),
            validator: (value) => value == null ? 'Select a destination account.' : null,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
              child: Text(_formatDate(_selectedDate)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? 'Saving...' : 'Save Transfer'),
          ),
        ],
      ),
    );
  }
}
