import 'package:flutter/material.dart';
import '../../services/category_service.dart';
import '../../models/category_model.dart';

class AddCategoryScreen extends StatefulWidget {
  final String type; // 'Income' or 'Expense'
  final Category? category;

  const AddCategoryScreen({super.key, required this.type, this.category});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final CategoryService _categoryService = CategoryService();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.category?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Category name is required.';
    }
    return null;
  }

  String _cleanErrorMessage(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.category == null) {
        await _categoryService.createCategory(
          name: _nameController.text.trim(),
          type: widget.type,
        );
      } else {
        await _categoryService.updateCategory(
          categoryId: widget.category!.categoryId!,
          name: _nameController.text.trim(),
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_cleanErrorMessage(e))),
        );
      }
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
        title: Text('${widget.category == null ? 'Add' : 'Edit'} ${widget.type} Category'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(),
              ),
              validator: _validateName,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
                child: _isSaving
                  ? const Text('Saving...')
                  : Text(widget.category == null ? 'Create Category' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}