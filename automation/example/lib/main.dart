import 'package:flutter/material.dart';
import 'package:automation/automation.dart';
import 'package:go_router/go_router.dart';
import 'app_tests.dart';

void main() {
  registerAppTests();
  runApp(const MyApp());
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/list',
      builder: (context, state) => const ItemsListScreen(),
    ),
    GoRoute(
      path: '/details/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '0';
        return DetailsScreen(itemId: id);
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AutomationInspectorWrapper(
      child: MaterialApp.router(
        routerConfig: _router,
        title: 'Automation Showcase',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            filled: true,
          ),
        ),
      ),
    );
  }
}

// --- Screens ---

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Automation Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              const TextField(
                key: Key('username_input'),
                decoration: InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 16),
              const TextField(
                key: Key('password_input'),
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  key: const Key('login_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // Simulate loading or validation
                    Future.delayed(const Duration(milliseconds: 500), () {
                        if (context.mounted) context.go('/list');
                    });
                  },
                  child: const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  // Trigger programmatic run
                  AutomationController.instance.runAllTests();
                }, 
                child: const Text("Run Tests Headless (CI Mode)"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class ItemsListScreen extends StatelessWidget {
  const ItemsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: ListView.builder(
        itemCount: 50,
        itemBuilder: (context, index) {
          final itemNumber = index + 1;
          return ListTile(
            leading: CircleAvatar(child: Text('$itemNumber')),
            title: Text('Item $itemNumber'),
            subtitle: Text('Description for item $itemNumber'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/details/$itemNumber'),
          );
        },
      ),
    );
  }
}

class DetailsScreen extends StatelessWidget {
  final String itemId;
  const DetailsScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Item $itemId Details')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                   const Icon(Icons.info_outline, color: Colors.blue),
                   const SizedBox(width: 12),
                   Text("Viewing details for #$itemId", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "This is the details view. We can verify that we arrived here by checking the title text or the id.",
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text("Go Back"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
