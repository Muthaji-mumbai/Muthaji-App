import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import 'client/client_dashboard.dart';
import 'employee/employee_dashboard.dart';
import 'admin/admin_dashboard.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        
        if (user == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Show different dashboard based on user role
        switch (user.role) {
          case UserRole.client:
            return const ClientDashboard();
          case UserRole.employee:
            return const EmployeeDashboard();
          case UserRole.admin:
            return const AdminDashboard();
        }
      },
    );
  }
}

class DashboardScaffold extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget body;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final List<Widget>? floatingActionButtons;

  const DashboardScaffold({
    super.key,
    required this.title,
    required this.actions,
    required this.body,
    this.drawer,
    this.bottomNavigationBar,
    this.floatingActionButtons,
  });

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          title,
          style: AppConstants.headingSmall.copyWith(
            color: Colors.white,
          ),
        ),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          ...actions,
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
        // Remove mobile menu icon as requested
        leading: null,
      ),
      drawer: drawer,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButtons?.isNotEmpty == true
          ? floatingActionButtons!.length == 1
              ? floatingActionButtons!.first
              : FloatingActionButton.extended(
                  onPressed: () {
                    // Handle multiple FABs
                  },
                  label: const Text('Actions'),
                  icon: const Icon(Icons.add),
                )
          : null,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthProvider>().logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
