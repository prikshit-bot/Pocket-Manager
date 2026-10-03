import 'package:flutter/material.dart';
import '../../services/goal_service.dart';
import '../../models/goal_model.dart';
import '../../utils/currency_formatter.dart';

class AddGoalScreen extends StatefulWidget {
  final Goal? goal;

  const AddGoalScreen({super.key, this.goal});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _noteController = TextEditingController();

  final GoalService _goalService = GoalService();

  DateTime? _targetDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    if (goal != null) {
      _nameController.text = goal.name;
      _targetController.text = goal.targetAmount.toStringAsFixed(2);
      _noteController.text = goal.note ?? '';
      _targetDate = goal.targetDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Goal name is required.';
    }
    return null;
  }

  String? _validateTarget(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Target amount is required.';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number.';
    }
    if (parsed <= 0) {
      return 'Target amount must be greater than 0.';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
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
      if (widget.goal == null) {
        await _goalService.createGoal(
          name: _nameController.text.trim(),
          targetAmount: double.parse(_targetController.text.trim()),
          targetDate: _targetDate,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      } else {
        final goal = widget.goal!;
        await _goalService.updateGoal(
          Goal(
            goalId: goal.goalId,
            name: _nameController.text.trim(),
            targetAmount: double.parse(_targetController.text.trim()),
            savedAmount: goal.savedAmount,
            targetDate: _targetDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            status: goal.status,
            createdAt: goal.createdAt,
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
        title: Text(widget.goal == null ? 'Add Goal' : 'Edit Goal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Goal Name',
                border: OutlineInputBorder(),
              ),
              validator: _validateName,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Target Amount',
                prefixText: '${CurrencyFormatter.symbol()} ',
                border: OutlineInputBorder(),
              ),
              validator: _validateTarget,
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Target Date (optional)',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _targetDate == null ? 'Not set' : _formatDate(_targetDate!),
                ),
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
                  : Text(widget.goal == null ? 'Create Goal' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}