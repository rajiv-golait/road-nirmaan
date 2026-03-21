import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'screens/login_screen.dart';
import 'services/complaint_store.dart';
import 'services/ward_assignment_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fxndnmlemadevxyovbql.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ4bmRubWxlbWFkZXZ4eW92YnFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA1NTY3NTAsImV4cCI6MjA4NjEzMjc1MH0.e7kfK65csCBcv4Ob9jZrB_ONO424QsU1T092ZQiMUSc',
  );

  ComplaintStore.instance.initialize();
  await WardAssignmentService.refresh();
  await ComplaintStore.instance.fetchComplaints();
  runApp(const RoadNirmanApp());
}

class RoadNirmanApp extends StatefulWidget {
  const RoadNirmanApp({super.key});

  @override
  State<RoadNirmanApp> createState() => _RoadNirmanAppState();
}

class _RoadNirmanAppState extends State<RoadNirmanApp>
    with WidgetsBindingObserver {
  Timer? _escalationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _escalationTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await ComplaintStore.instance.runAutoEscalation();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ComplaintStore.instance.runAutoEscalation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _escalationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROADNIRMAN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F5F7B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        appBarTheme: const AppBarTheme(
          elevation: 2,
          centerTitle: true,
          backgroundColor: Color(0xFFEAF0F7),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFEAF0F7),
          selectedItemColor: Color(0xFF3F5F7B),
          unselectedItemColor: Color(0xFF637381),
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      initialRoute: '/login',
      routes: {'/login': (context) => const LoginScreen()},
    );
  }
}
