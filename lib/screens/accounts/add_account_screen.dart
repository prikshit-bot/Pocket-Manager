import 'package:flutter/material.dart';
import '../../services/account_service.dart';
import '../../models/account_model.dart';
import '../../utils/currency_formatter.dart';

class AddAccountScreen extends StatefulWidget {
  final Account? account;

  const AddAccountScreen({super.key, this.account});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  final _noteController = TextEditingController();

  final AccountService _accountService = AccountService();

  String _selectedType = AccountService.validTypes.first; // 'Cash'
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    if (account != null) {
      _nameController.text = account.name;
      _balanceController.text = account.balance.toStringAsFixed(2);
      _noteController.text = account.note ?? '';
      _selectedType = account.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Account name is required.';
    }
    return null;
  }

  String? _validateBalance(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Opening balance is required.';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number.';
    }
    if (parsed < 0) {
      return 'Opening balance cannot be negative.';
    }
    return null;
  }

  String _cleanErrorMessage(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.account == null) {
        await _accountService.createAccount(
          name: _nameController.text.trim(),
          type: _selectedType,
          openingBalance: double.parse(_balanceController.text.trim()),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      } else {
        final account = widget.account!;
        await _accountService.updateAccount(
          Account(
            accountId: account.accountId,
            name: _nameController.text.trim(),
            type: _selectedType,
            balance: account.balance,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            isVisible: account.isVisible,
            isActive: account.isActive,
            createdAt: account.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'Add Account' : 'Edit Account'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Account Name',
                border: OutlineInputBorder(),
              ),
              validator: _validateName,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Account Type',
                border: OutlineInputBorder(),
              ),
              items: AccountService.validTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _balanceController,
              readOnly: widget.account != null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Opening Balance',
                prefixText: '${CurrencyFormatter.symbol()} ',
                border: OutlineInputBorder(),
              ),
              validator: _validateBalance,
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
                  : Text(widget.account == null ? 'Create Account' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}