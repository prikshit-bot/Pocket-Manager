import 'package:flutter/material.dart';
import 'transcation_form.dart';

class AddIncomeScreen extends StatelessWidget {
  const AddIncomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Income')),
      body: const TransactionForm(type: 'Income'),
    );
  }
}