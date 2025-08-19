import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../providers/auth_provider.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
Future<void> _handleLogin() async {
  if (_formKey.currentState!.validate()) {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error == 'Invalid Password' ? 'Invalid Password' : authProvider.error ?? 'An unexpected error occurred'),
          backgroundColor: AppConstants.errorColor,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  ResponsiveValue<double>(
                    context,
                    defaultValue: AppConstants.spacingXL,
                    conditionalValues: [
                      const Condition.equals(
                        name: MOBILE,
                        value: AppConstants.spacingM,
                      ),
                      const Condition.equals(
                        name: TABLET,
                        value: AppConstants.spacingL,
                      ),
                      const Condition.equals(
                        name: DESKTOP,
                        value: AppConstants.spacingXL,
                      ),
                    ],
                  ).value!,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        ResponsiveValue<double>(
                          context,
                          defaultValue: 400,
                          conditionalValues: [
                            const Condition.equals(
                              name: MOBILE,
                              value: double.infinity,
                            ),
                            const Condition.equals(name: TABLET, value: 500),
                            const Condition.equals(name: DESKTOP, value: 400),
                          ],
                        ).value!,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Heading
                      Text(
                        'Welcome to Muthaji',
                        style: AppConstants.headingSmall.copyWith(
                          color: AppConstants.textPrimaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppConstants.spacingXXL),

                      // Login Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            CustomTextField(
                              controller: _emailController,
                              labelText: 'Email',
                              hintText: 'Enter your email',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: AppConstants.spacingM),

                            CustomTextField(
                              controller: _passwordController,
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: Icons.lock_outlined,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: AppConstants.textSecondaryColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: AppConstants.spacingL),

                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                return CustomButton(
                                  onPressed:
                                      authProvider.isLoading
                                          ? null
                                          : _handleLogin,
                                  text:
                                      authProvider.isLoading
                                          ? 'Signing in...'
                                          : 'Sign In',
                                  isLoading: authProvider.isLoading,
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppConstants.spacingXL),

                      // Demo Credentials Section
                      // Container(
                      //   padding: const EdgeInsets.all(AppConstants.spacingM),
                      //   decoration: BoxDecoration(
                      //     color: AppConstants.surfaceColor,
                      //     borderRadius: BorderRadius.circular(
                      //       AppConstants.radiusM,
                      //     ),
                      //     border: Border.all(
                      //       color: AppConstants.primaryColor.withOpacity(0.2),
                      //     ),
                      //   ),
                      //   child: Column(
                      //     crossAxisAlignment: CrossAxisAlignment.start,
                      //     children: [
                      //       Row(
                      //         children: [
                      //           Icon(
                      //             Icons.info_outline,
                      //             color: AppConstants.primaryColor,
                      //             size: 20,
                      //           ),
                      //           const SizedBox(width: AppConstants.spacingS),
                      //           Text(
                      //             'Demo Credentials',
                      //             style: AppConstants.bodyMedium.copyWith(
                      //               fontWeight: FontWeight.w600,
                      //               color: AppConstants.textPrimaryColor,
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //       const SizedBox(height: AppConstants.spacingS),
                      //       _buildDemoCredential('Admin', 'codoit53@gmail.com'),
                      //       _buildDemoCredential('Password', '123456'),
                      //       const SizedBox(height: AppConstants.spacingXS),
                      //       Text(
                      //         'Role will be determined by the backend response',
                      //         style: AppConstants.bodySmall.copyWith(
                      //           color: AppConstants.textSecondaryColor,
                      //           fontStyle: FontStyle.italic,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: AppConstants.spacingM,
            left: AppConstants.spacingM,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  child: Image.asset(
                    'assets/icons/logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Muthaji',
                      style: AppConstants.headingSmall.copyWith(
                        color: AppConstants.primaryColor,
                      ),
                    ),
                 
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoCredential(String role, String email) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$role: ',
            style: AppConstants.bodySmall.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(
            email,
            style: AppConstants.bodySmall.copyWith(
              color: AppConstants.primaryColor,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
