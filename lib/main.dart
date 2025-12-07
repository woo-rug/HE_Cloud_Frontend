import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/how_it_works_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const HECloudApp());
}

class HECloudApp extends StatelessWidget {
  const HECloudApp({super.key});

  @override
  Widget build(BuildContext context) {
    // We now only need one provider for the whole app state.
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'HE Cloud',
        theme: AppTheme.theme(),
        debugShowCheckedModeBanner: false, // Hide the debug banner
        routes: {
          '/': (_) => const AuthWrapper(),
          '/how-it-works': (_) => const HowItWorksScreen(),
        },
      ),
    );
  }
}

// This widget acts as a gate, showing the correct screen based on login status.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // We listen to the AppProvider to know if the user is logged in.
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        switch (appProvider.authState) {
          // While checking, show a loading spinner.
          case AuthState.checking:
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          // If logged in, show the main app screen.
          case AuthState.loggedIn:
            return const MainShell();
          // If logged out, show the login screen.
          case AuthState.loggedOut:
            return const LoginScreen();
        }
      },
    );
  }
}
