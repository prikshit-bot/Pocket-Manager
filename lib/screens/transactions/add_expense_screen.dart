import 'package:flutter/material.dart';
import 'transcation_form.dart';

class AddExpenseScreen extends StatelessWidget {
  const AddExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: const TransactionForm(type: 'Expense'),
    );
  }
}