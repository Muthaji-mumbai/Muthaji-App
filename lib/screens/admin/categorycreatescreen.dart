import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/category_service.dart';
import '../../widgets/custom_button.dart';
import '../../models/category.dart';

class CreateCategoryScreen extends StatefulWidget {
  const CreateCategoryScreen({super.key});

  @override
  State<CreateCategoryScreen> createState() => _CreateCategoryScreenState();
}

class _CreateCategoryScreenState extends State<CreateCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categoryNameController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingCategories = false;
  List<Datum> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token == null) {
        throw Exception('User not authenticated');
      }

      final categoryResponse = await CategoryService.getAllCategories(token);

      if (!mounted) return;

      setState(() {
        _categories = categoryResponse.data;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load categories: $e'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _createCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token == null) {
        throw Exception('User not authenticated');
      }

      await CategoryService.createCategory(
        _categoryNameController.text.trim(),
        token,
      );

      if (!mounted) return;

      // Clear the form and refresh categories list
      _categoryNameController.clear();
      await _loadCategories();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category created successfully!'),
          backgroundColor: AppConstants.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create category: $e'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories Management'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCategories,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Create Category Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Category',
                        style: AppConstants.headingMedium,
                      ),
                      const SizedBox(height: AppConstants.spacingM),
                      TextFormField(
                        controller: _categoryNameController,
                        decoration: InputDecoration(
                          labelText: 'Category Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusM,
                            ),
                          ),
                          filled: true,
                          fillColor: AppConstants.surfaceColor,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a category name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.spacingL),
                      CustomButton(
                        text: 'Create Category',
                        isLoading: _isLoading,
                        onPressed: _createCategory,
                        backgroundColor: AppConstants.successColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppConstants.spacingL),

            // Categories List Section
            Text('All Categories', style: AppConstants.headingMedium),
            const SizedBox(height: AppConstants.spacingM),

            if (_isLoadingCategories)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppConstants.spacingL),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_categories.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingL),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: AppConstants.spacingM),
                        Text(
                          'No categories found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingS),
                        Text(
                          'Create your first category above',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return Card(
                    margin: const EdgeInsets.only(
                      bottom: AppConstants.spacingS,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppConstants.primaryColor.withOpacity(
                          0.1,
                        ),
                        child: Text(
                          category.categoryname.isNotEmpty
                              ? category.categoryname[0].toUpperCase()
                              : 'C',
                          style: TextStyle(
                            color: AppConstants.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        category.categoryname,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'update') {
                            await _showUpdateDialog(category);
                          }
                        },
                        itemBuilder:
                            (context) => [
                              const PopupMenuItem(
                                value: 'update',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Update'),
                                  ],
                                ),
                              ),
                            ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUpdateDialog(Datum category) async {
    final TextEditingController updateController = TextEditingController(
      text: category.categoryname,
    );

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Category'),
          content: TextField(
            controller: updateController,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Update'),
              onPressed: () async {
                if (updateController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  await _updateCategory(
                    category.id,
                    updateController.text.trim(),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateCategory(String categoryId, String newName) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token == null) {
        throw Exception('User not authenticated');
      }

      await CategoryService.updateCategory(categoryId, newName, token);

      if (!mounted) return;

      // Refresh the categories list
      await _loadCategories();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category updated successfully!'),
          backgroundColor: AppConstants.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update category: $e'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    }
  }
}
