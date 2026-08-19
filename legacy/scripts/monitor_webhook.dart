import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:logger/logger.dart';

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
      title: 'Webhook Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MonitorScreen(),
    );
  }
}

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  MonitorScreenState createState() => MonitorScreenState();
}

class MonitorScreenState extends State<MonitorScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _statusHistory = [];
  List<Map<String, dynamic>> _notifications = [];
  Timer? _refreshTimer;
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh data every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadData();
    });
  }

  void _logMessage(String message) {
    _logger.i(message);
  }

  @override
  void dispose() {
    _logMessage('Disposing MonitorScreenState');
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load employees
      final employeesResponse = await _supabase
          .from('employees')
          .select('*')
          .order('created_at', ascending: false)
          .limit(10);

      // Load status history
      final historyResponse = await _supabase
          .from('employee_status_history')
          .select('*')
          .order('timestamp', ascending: false)
          .limit(10);

      // Load notifications
      final notificationsResponse = await _supabase
          .from('notifications')
          .select('*')
          .order('created_at', ascending: false)
          .limit(10);

      setState(() {
        _employees = List<Map<String, dynamic>>.from(employeesResponse);
        _statusHistory = List<Map<String, dynamic>>.from(historyResponse);
        _notifications = List<Map<String, dynamic>>.from(notificationsResponse);
      });
    } catch (e) {
      _logger.e('Error loading data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Webhook Monitor'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Employees'),
              Tab(text: 'Status History'),
              Tab(text: 'Notifications'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildEmployeesList(),
            _buildStatusHistoryList(),
            _buildNotificationsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeesList() {
    return ListView.builder(
      itemCount: _employees.length,
      itemBuilder: (context, index) {
        final employee = _employees[index];
        return ListTile(
          title: Text('${employee['first_name']} ${employee['last_name']}'),
          subtitle: Text('ID: ${employee['id']}'),
          trailing: Text('Company: ${employee['company_id'] ?? 'None'}'),
        );
      },
    );
  }

  Widget _buildStatusHistoryList() {
    return ListView.builder(
      itemCount: _statusHistory.length,
      itemBuilder: (context, index) {
        final history = _statusHistory[index];
        return ListTile(
          title: Text('Status: ${history['status']}'),
          subtitle: Text('Employee ID: ${history['employee_id']}'),
          trailing: Text('${history['timestamp']}'),
        );
      },
    );
  }

  Widget _buildNotificationsList() {
    return ListView.builder(
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return ListTile(
          title: Text('${notification['title']}'),
          subtitle: Text('${notification['message']}'),
          trailing: Text('${notification['created_at']}'),
        );
      },
    );
  }
}
