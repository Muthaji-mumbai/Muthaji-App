import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../providers/auth_provider.dart';

class CreateClientScreen extends StatefulWidget {
  const CreateClientScreen({super.key});

  @override
  State<CreateClientScreen> createState() => _CreateClientScreenState();
}

class _CreateClientScreenState extends State<CreateClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _createClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token == null) {
        throw Exception('No authentication token available');
      }

      await UserService.createUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: '123456', // Default password for clients
        phone: _phoneController.text.trim(),
        role: UserRole.client,
        address: 'Address not provided', // Default address
        token: token,
      );

      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });

      // Clear form
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Client created successfully!'),
            backgroundColor: AppConstants.successColor,
          ),
        );
      }

      // Reset success state after a delay
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isSuccess = false);
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating client: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Muthaji - Create New Client'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          ResponsiveValue<double>(
            context,
            defaultValue: 16,
            conditionalValues: [
              const Condition.equals(name: MOBILE, value: 16.0),
              const Condition.equals(name: TABLET, value: 24.0),
              const Condition.equals(name: DESKTOP, value: 32.0),
            ],
          ).value!,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  ResponsiveValue<double>(
                    context,
                    defaultValue: 600,
                    conditionalValues: [
                      const Condition.equals(
                        name: MOBILE,
                        value: double.infinity,
                      ),
                      const Condition.equals(name: TABLET, value: 700.0),
                      const Condition.equals(name: DESKTOP, value: 600.0),
                    ],
                  ).value!,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppConstants.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add,
                          color: AppConstants.primaryColor,
                          size: 32,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create New Client Account',
                                style: AppConstants.headingSmall.copyWith(
                                  color: AppConstants.primaryColor,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Add a new client to the system',
                                style: AppConstants.bodyMedium.copyWith(
                                  color: AppConstants.primaryColor.withOpacity(
                                    0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  // Success Message
                  if (_isSuccess)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppConstants.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppConstants.successColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppConstants.successColor,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Client created successfully! You can now create another client.',
                              style: AppConstants.bodyMedium.copyWith(
                                color: AppConstants.successColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_isSuccess) SizedBox(height: 24),

                  // Form Fields
                  CustomTextField(
                    controller: _nameController,
                    labelText: 'Full Name',
                    hintText: 'Enter client\'s full name',
                    prefixIcon: Icons.person,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 20),

                  CustomTextField(
                    controller: _emailController,
                    labelText: 'Email Address',
                    hintText: 'Enter client\'s email address',
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 20),

                  CustomTextField(
                    controller: _phoneController,
                    labelText: 'Phone Number',
                    hintText: 'Enter client\'s phone number',
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Phone number is required';
                      }
                      if (value.trim().length < 10) {
                        return 'Phone number must be at least 10 digits';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: _isLoading ? 'Creating Client...' : 'Create Client',
                      onPressed: _isLoading ? null : _createClient,
                      isLoading: _isLoading,
                    ),
                  ),

                  SizedBox(height: 24),

                  // Info Section
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConstants.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppConstants.textSecondaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppConstants.accentColor,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Important Information',
                              style: AppConstants.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppConstants.textPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          '• The client will be able to log in using their email address\n'
                          '• A default password will be set (they can change it later)\n'
                          '• The client will have access to create orders and view their history\n'
                          '• You can manage client accounts from the admin dashboard',
                          style: AppConstants.bodySmall.copyWith(
                            color: AppConstants.textSecondaryColor,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
