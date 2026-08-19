import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Replace with your Supabase URL and API key
const supabaseUrl = 'https://kkcseqmpgzzrogatdoqi.supabase.co';
const supabaseKey = 'your-supabase-key'; // Replace with your actual key

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Employee-Company Link Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final _supabase = Supabase.instance.client;
  String _status = 'Ready to test';
  String _employeeId = '';
  String _companyId = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee-Company Link Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Employee ID'),
              onChanged: (value) => _employeeId = value,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Company ID'),
              onChanged: (value) => _companyId = value,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _testDirectLink,
              child: const Text('Test Direct Link'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testWebhookLink,
              child: const Text('Test Webhook Link'),
            ),
            const SizedBox(height: 24),
            Text('Status: $_status'),
          ],
        ),
      ),
    );
  }

  Future<void> _testDirectLink() async {
    if (_employeeId.isEmpty || _companyId.isEmpty) {
      setState(() {
        _status = 'Please enter both Employee ID and Company ID';
      });
      return;
    }

    setState(() {
      _status = 'Testing direct link...';
    });

    try {
      // Call the Edge Function directly
      final response = await _supabase.functions.invoke(
        'employee-company-link',
        body: {
          'employee_id': _employeeId,
          'company_id': _companyId,
        },
      );

      setState(() {
        _status = 'Direct link result: ${response.data}';
      });
    } catch (e) {
      setState(() {
        _status = 'Error in direct link: $e';
      });
    }
  }

  Future<void> _testWebhookLink() async {
    if (_employeeId.isEmpty || _companyId.isEmpty) {
      setState(() {
        _status = 'Please enter both Employee ID and Company ID';
      });
      return;
    }

    setState(() {
      _status = 'Testing webhook link...';
    });

    try {
      // Update the employee record to trigger the webhook
      await _supabase
          .from('employees')
          .update({'company_id': _companyId})
          .eq('id', _employeeId);

      setState(() {
        _status = 'Webhook triggered. Check logs for results.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error triggering webhook: $e';
      });
    }
  }
}
