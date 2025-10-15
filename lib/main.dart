import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'constants/app_constants.dart';
import 'services/navigation_service.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:listen_sharing_intent/listen_sharing_intent.dart';
import 'dart:async';
import 'screens/client/create_order_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Firebase initialization for Web
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyA8aMOr_tiQ6smcs0rXZY1W3Kjk1hKBeIA',
        authDomain: 'soloshine-906d5.firebaseapp.com',
        projectId: 'soloshine-906d5',
        storageBucket: 'soloshine-906d5.firebasestorage.app',
        messagingSenderId: '129231948033',
        appId: '1:129231948033:web:97d57a3bdac43a8ea0f300',
      ),
    );
  } else {
    await Firebase.initializeApp();
    // Init push notifications (foreground, background, terminated)
    await PushNotificationService.instance.initialize();
  }
  // Register a global unauthorized handler used by ApiService
  ApiService.setUnauthorizedHandler(AuthService.handleUnauthorized);
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
          navigatorKey: NavigationService.navigatorKey,
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
  StreamSubscription? _intentDataStreamSubscription;
  bool _hasSharedIntent = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
    _checkForSharedIntent();
  }
  
  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }
  
  // Check if app was opened with shared images
  void _checkForSharedIntent() {
    // Check for initial sharing when app was closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<dynamic> sharedFiles) {
      if (sharedFiles.isNotEmpty && mounted) {
        setState(() {
          _hasSharedIntent = true;
        });
      }
    });
    
    // Listen to media sharing while app is running
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<dynamic> sharedFiles) {
        if (sharedFiles.isNotEmpty && mounted) {
          setState(() {
            _hasSharedIntent = true;
          });
          _navigateToCreateOrder();
        }
      },
    );
  } 
  
  void _navigateToCreateOrder() {
    // Wait for auth to complete, then navigate
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        if (authProvider.isLoggedIn) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateOrderScreen(),
            ),
          );
        }
      }
    });
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
      return SplashScreen();
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoggedIn) {
          // If we have shared intent, navigate to create order after dashboard loads
          if (_hasSharedIntent) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _hasSharedIntent = false;
                });
                _navigateToCreateOrder();
              }
            });
          }
          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
