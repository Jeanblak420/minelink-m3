import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    debug: true,
  );

  runApp(const TestEmployeesApp());
}

class TestEmployeesApp extends StatelessWidget {
  const TestEmployeesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Employees Table',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TestEmployeesPage(),
    );
  }
}

class TestEmployeesPage extends StatefulWidget {
  const TestEmployeesPage({super.key});

  @override
  TestEmployeesPageState createState() => TestEmployeesPageState();
}

class TestEmployeesPageState extends State<TestEmployeesPage> {
  final _supabase = Supabase.instance.client;
  String _message = 'Testing employees table...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testEmployeesTable();
  }

  Future<void> _testEmployeesTable() async {
    setState(() {
      _isLoading = true;
      _message = 'Testing employees table...';
    });

    try {
      // Try to select from the employees table
      final response = await _supabase.from('employees').select().limit(1);

      setState(() {
        _message = 'Success! Found employees table: ${response.toString()}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _message = 'Error accessing employees table: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _testInsertEmployee() async {
    setState(() {
      _isLoading = true;
      _message = 'Testing employee insertion...';
    });

    try {
      // Create a test user first
      final authResponse = await _supabase.auth.signUp(
        email: 'test_${DateTime.now().millisecondsSinceEpoch}@example.com',
        password: 'password123',
      );

      if (authResponse.user == null) {
        setState(() {
          _message = 'Failed to create test user';
          _isLoading = false;
        });
        return;
      }

      // Try to insert into the employees table
      final response = await _supabase.from('employees').insert({
        'user_id': authResponse.user!.id,
        'first_name': 'Test',
        'last_name': 'User',
        'whatsapp_number': '+1234567890',
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      setState(() {
        _message = 'Success! Inserted employee: ${response.toString()}';
        _isLoading = false;
      });

      // Sign out the test user
      await _supabase.auth.signOut();
    } catch (e) {
      setState(() {
        _message = 'Error inserting employee: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Employees Table'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Text(
                  _message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _testEmployeesTable,
                child: const Text('Test Select'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _testInsertEmployee,
                child: const Text('Test Insert'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
