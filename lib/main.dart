import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'constants/app_constants.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: ResponsiveBreakpoints.builder(
        child: MaterialApp(
          title: 'Muthaji',
          debugShowCheckedModeBanner: false,
          theme: AppConstants.lightTheme,
          // darkTheme: AppConstants.darkTheme,
          // themeMode: ThemeMode.system,
          home: const AuthWrapper(),
        ),
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
          const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.initializeAuth();
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppConstants.primaryColor,
              ),
              SizedBox(height: AppConstants.spacingM),
              Text(
                'Loading...',
                style: TextStyle(
                  color: AppConstants.textPrimaryColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoggedIn) {
          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}