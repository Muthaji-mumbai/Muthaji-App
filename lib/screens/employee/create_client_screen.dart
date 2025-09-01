// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:responsive_framework/responsive_framework.dart';
// import '../../constants/app_constants.dart';
// import '../../widgets/custom_button.dart';
// import '../../widgets/custom_text_field.dart';
// import '../../services/user_service.dart';
// import '../../providers/auth_provider.dart';
// import '../../models/user.dart';

// class CreateClientScreen extends StatefulWidget {
//   const CreateClientScreen({super.key});

//   @override
//   State<CreateClientScreen> createState() => _CreateClientScreenState();
// }

// class _CreateClientScreenState extends State<CreateClientScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _emailController = TextEditingController();
//   final _phoneController = TextEditingController();
//   final _addressController = TextEditingController();
//   final _passwordController = TextEditingController();
//   bool _isLoading = false;
//   bool _isSuccess = false;
//   bool _useDefaultPassword = true;

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _phoneController.dispose();
//     _addressController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   Future<void> _createClient() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isLoading = true);

//     try {
//       final authProvider = context.read<AuthProvider>();
//       final token = authProvider.currentUser?.token;

//       if (token == null) throw Exception('No authentication token available');

//       await UserService.createUser(
//         name: _nameController.text.trim(),
//         email: _emailController.text.trim(),
//         password: _useDefaultPassword ? 'defaultClient123' : _passwordController.text.trim(),
//         phone: _phoneController.text.trim(),
//         role: UserRole.client,
//         address: _addressController.text.trim().isEmpty ? 'Not provided' : _addressController.text.trim(),
//         token: token,
//       );

//       setState(() {
//         _isLoading = false;
//         _isSuccess = true;
//       });

//       // Clear form
//       _nameController.clear();
//       _emailController.clear();
//       _phoneController.clear();
//       _addressController.clear();
//       _passwordController.clear();

//       // Show success message
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Client created successfully!'),
//             backgroundColor: AppConstants.successColor,
//             behavior: SnackBarBehavior.floating,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }

//       // Reset success state after a delay
//       Future.delayed(const Duration(seconds: 3), () {
//         if (mounted) {
//           setState(() => _isSuccess = false);
//         }
//       });
//     } catch (e) {
//       setState(() => _isLoading = false);

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error creating client: $e'),
//             backgroundColor: AppConstants.errorColor,
//             behavior: SnackBarBehavior.floating,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }

//   Future<bool> _onWillPop() async {
//     if (_nameController.text.isNotEmpty ||
//         _emailController.text.isNotEmpty ||
//         _phoneController.text.isNotEmpty ||
//         _addressController.text.isNotEmpty ||
//         _passwordController.text.isNotEmpty) {
//       final shouldPop = await showDialog<bool>(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: const Text('Discard Changes?'),
//           content: const Text('You have unsaved changes. Are you sure you want to leave?'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context, false),
//               child: const Text('Cancel'),
//             ),
//             TextButton(
//               onPressed: () => Navigator.pop(context, true),
//               style: TextButton.styleFrom(foregroundColor: AppConstants.errorColor),
//               child: const Text('Discard'),
//             ),
//           ],
//         ),
//       );
//       return shouldPop ?? false;
//     }
//     return true;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: _onWillPop,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Create New Client'),
//           backgroundColor: AppConstants.primaryColor,
//           foregroundColor: Colors.white,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back),
//             onPressed: () async {
//               if (await _onWillPop()) {
//                 Navigator.pop(context);
//               }
//             },
//           ),
//         ),
//         body: SingleChildScrollView(
//           padding: EdgeInsets.all(
//             ResponsiveValue<double>(
//               context,
//               defaultValue: AppConstants.spacingM,
//               conditionalValues: [
//                 const Condition.equals(name: MOBILE, value: AppConstants.spacingM),
//                 const Condition.equals(name: TABLET, value: AppConstants.spacingL),
//                 const Condition.equals(name: DESKTOP, value: AppConstants.spacingXL),
//               ],
//             ).value!,
//           ),
//           child: Center(
//             child: ConstrainedBox(
//               constraints: BoxConstraints(
//                 maxWidth: ResponsiveValue<double>(
//                   context,
//                   defaultValue: 600,
//                   conditionalValues: [
//                     const Condition.equals(name: MOBILE, value: double.infinity),
//                     const Condition.equals(name: TABLET, value: 700),
//                     const Condition.equals(name: DESKTOP, value: 600),
//                   ],
//                 ).value!,
//               ),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Header
//                     Container(
//                       padding: const EdgeInsets.all(AppConstants.spacingM),
//                       decoration: BoxDecoration(
//                         color: AppConstants.primaryColor.withOpacity(0.05),
//                         borderRadius: BorderRadius.circular(AppConstants.radiusM),
//                         boxShadow: AppConstants.cardShadow,
//                       ),
//                       child: Row(
//                         children: [
//                           CircleAvatar(
//                             backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
//                             child: Icon(
//                               Icons.person_add,
//                               color: AppConstants.primaryColor,
//                               size: 24,
//                             ),
//                           ),
//                           const SizedBox(width: AppConstants.spacingM),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   'Add New Client',
//                                   style: AppConstants.headingSmall.copyWith(color: AppConstants.textPrimaryColor),
//                                 ),
//                                 const SizedBox(height: AppConstants.spacingXS),
//                                 Text(
//                                   'Create a new client account for order management',
//                                   style: AppConstants.bodyMedium.copyWith(color: AppConstants.textSecondaryColor),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: AppConstants.spacingL),

//                     // Success Message
//                     AnimatedCrossFade(
//                       firstChild: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.all(AppConstants.spacingM),
//                         decoration: BoxDecoration(
//                           color: AppConstants.successColor.withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(AppConstants.radiusM),
//                           border: Border.all(color: AppConstants.successColor),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(
//                               Icons.check_circle,
//                               color: AppConstants.successColor,
//                               size: 24,
//                             ),
//                             const SizedBox(width: AppConstants.spacingS),
//                             Expanded(
//                               child: Text(
//                                 'Client created successfully! You can create another client or return to the dashboard.',
//                                 style: AppConstants.bodyMedium.copyWith(
//                                   color: AppConstants.successColor,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       secondChild: const SizedBox.shrink(),
//                       crossFadeState: _isSuccess ? CrossFadeState.showFirst : CrossFadeState.showSecond,
//                       duration: const Duration(milliseconds: 300),
//                     ),
//                     if (_isSuccess) const SizedBox(height: AppConstants.spacingM),

//                     // Form Fields
//                     Text('Client Details', style: AppConstants.headingSmall),
//                     const SizedBox(height: AppConstants.spacingM),
//                     CustomTextField(
//                       controller: _nameController,
//                       labelText: 'Full Name',
//                       hintText: 'Enter client\'s full name',
//                       prefixIcon: Icons.person,
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return 'Name is required';
//                         }
//                         if (value.trim().length < 2) {
//                           return 'Name must be at least 2 characters';
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: AppConstants.spacingM),
//                     CustomTextField(
//                       controller: _emailController,
//                       labelText: 'Email Address',
//                       hintText: 'Enter client\'s email address',
//                       prefixIcon:  Icons.email,
//                       keyboardType: TextInputType.emailAddress,
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return 'Email is required';
//                         }
//                         if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
//                           return 'Please enter a valid email address';
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: AppConstants.spacingM),
//                     CustomTextField(
//                       controller: _phoneController,
//                       labelText: 'Phone Number',
//                       hintText: 'Enter client\'s phone number',
//                       prefixIcon: Icons.phone,
//                       keyboardType: TextInputType.phone,
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return 'Phone number is required';
//                         }
//                         if (value.trim().length < 10) {
//                           return 'Phone number must be at least 10 digits';
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: AppConstants.spacingM),
//                     CustomTextField(
//                       controller: _addressController,
//                       labelText: 'Address (Optional)',
//                       hintText: 'Enter client\'s address',
//                       prefixIcon:  (Icons.location_on),
//                       maxLines: 3,
//                     ),
//                     const SizedBox(height: AppConstants.spacingM),
//                     Row(
//                       children: [
//                         Checkbox(
//                           value: _useDefaultPassword,
//                           onChanged: (value) {
//                             setState(() => _useDefaultPassword = value ?? true);
//                           },
//                         ),
//                         Expanded(
//                           child: Text(
//                             'Use default password (defaultClient123)',
//                             style: AppConstants.bodyMedium.copyWith(color: AppConstants.textSecondaryColor),
//                           ),
//                         ),
//                       ],
//                     ),
//                     if (!_useDefaultPassword) ...[
//                       const SizedBox(height: AppConstants.spacingM),
//                       CustomTextField(
//                         controller: _passwordController,
//                         labelText: 'Password',
//                         hintText: 'Enter a custom password',
//                         prefixIcon: (Icons.lock),
//                         obscureText: true,
//                         validator: (value) {
//                           if (value == null || value.trim().isEmpty) {
//                             return 'Password is required';
//                           }
//                           if (value.trim().length < 6) {
//                             return 'Password must be at least 6 characters';
//                           }
//                           return null;
//                         },
//                       ),
//                     ],
//                     const SizedBox(height: AppConstants.spacingL),

//                     // Action Buttons
//                     Row(
//                       children: [
//                         Expanded(
//                           child: CustomButton(
//                             text: 'Cancel',
//                             onPressed: () async {
//                               if (await _onWillPop()) {
//                                 Navigator.pop(context);
//                               }
//                             },
//                             backgroundColor: AppConstants.errorColor,
//                             isFullWidth: true,
//                           ),
//                         ),
//                         const SizedBox(width: AppConstants.spacingM),
//                         Expanded(
//                           child: CustomButton(
//                             text: _isLoading ? 'Creating...' : 'Create Client',
//                             onPressed: _isLoading ? null : _createClient,
//                             backgroundColor: AppConstants.successColor,
//                             isFullWidth: true,
//                             isLoading: _isLoading,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: AppConstants.spacingL),

//                     // Info Section
//                     Container(
//                       padding: const EdgeInsets.all(AppConstants.spacingM),
//                       decoration: BoxDecoration(
//                         color: AppConstants.surfaceColor,
//                         borderRadius: BorderRadius.circular(AppConstants.radiusM),
//                         boxShadow: AppConstants.cardShadow,
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               Icon(
//                                 Icons.info_outline,
//                                 color: AppConstants.accentColor,
//                                 size: 20,
//                               ),
//                               const SizedBox(width: AppConstants.spacingS),
//                               Text(
//                                 'Client Account Details',
//                                 style: AppConstants.bodyMedium.copyWith(
//                                   fontWeight: FontWeight.w600,
//                                   color: AppConstants.textPrimaryColor,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: AppConstants.spacingS),
//                           Text(
//                             '• Clients can log in using their email and password\n'
//                             '• Default password is "defaultClient123" unless customized\n'
//                             '• Clients can create orders and view their history\n'
//                             '• Manage client accounts from the admin dashboard',
//                             style: AppConstants.bodySmall.copyWith(
//                               color: AppConstants.textSecondaryColor,
//                               height: 1.5,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }