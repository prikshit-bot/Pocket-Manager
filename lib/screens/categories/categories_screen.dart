import 'package:flutter/material.dart';
import '../../services/category_service.dart';
import '../../models/category_model.dart';
import 'add_category_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  final CategoryService _categoryService = CategoryService();
  late TabController _tabController;
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _categoriesFuture = _categoryService.getAllCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _categoriesFuture = _categoryService.getAllCategories();
    });
    await _categoriesFuture;
  }

  Future<void> _openAddCategory(String type) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AddCategoryScreen(type: type)),
    );
    if (result == true) {
      _refresh();
    }
  }

  Future<void> _openEditCategory(Category category) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddCategoryScreen(
          type: category.type,
          category: category,
        ),
      ),
    );
    if (result == true) _refresh();
  }

  Future<void> _confirmDelete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete "${category.name}"? Past transactions using it will keep showing it, but it won\'t be selectable for new ones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _categoryService.deleteCategory(category.categoryId!);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_cleanErrorMessage(e))),
        );
      }
    }
  }

  String _cleanErrorMessage(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Widget _buildList(List<Category> categories, String type) {
    final filtered = categories.where((c) => c.type == type).toList();

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No categories yet.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final category = filtered[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: type == 'Income'
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.red.withValues(alpha: 0.15),
              child: Icon(
                type == 'Income' ? Icons.arrow_downward : Icons.arrow_upward,
                color: type == 'Income' ? Colors.green : Colors.red,
              ),
            ),
            title: Text(category.name),
            subtitle: category.isDefault ? const Text('Default') : null,
            trailing: category.isDefault
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit category',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openEditCategory(category),
                      ),
                      IconButton(
                        tooltip: 'Delete category',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(category),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Income'),
            Tab(text: 'Expense'),
          ],
        ),
      ),
      body: FutureBuilder<List<Category>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final categories = snapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(categories, 'Income'),
              _buildList(categories, 'Expense'),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final type = _tabController.index == 0 ? 'Income' : 'Expense';
          _openAddCategory(type);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}