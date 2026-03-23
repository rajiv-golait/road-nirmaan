import 'dart:io';

import 'package:flutter/material.dart';
import '../../utils/demo_role_router.dart';
import '../../services/user_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/complaint_store.dart';
import '../../services/legacy_dashboard_adapter.dart';
import '../../services/dashboard_metrics.dart';
import '../../utils/escalation_config.dart';
import '../../services/ward_assignment_service.dart';
import '../../utils/app_flags.dart';
import '../../utils/map_tile_config.dart';

// Color palette (top-level for all widgets)
const Color primary = Color(0xFF4A5D6B);
const Color accent = Color(0xFFC9A24D);
const Color background = Color(0xFFF6F4EF);
const Color surface = Color(0xFFE7E2D8);
const Color textPrimary = Color(0xFF2B2B2B);
const Color textSecondary = Color(0xFF6F6F6F);

// Global Dummy Data

List<Map<String, dynamic>> get allComplaints =>
    LegacyDashboardAdapter.detailComplaints(ComplaintStore.instance.complaints);

ImageProvider<Object> _complaintImageProvider(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  if (path.startsWith('/') || path.contains(r':\')) {
    return FileImage(File(path));
  }
  return AssetImage(path);
}

class CommissionerDashboard extends StatefulWidget {
  const CommissionerDashboard({super.key});

  @override
  State<CommissionerDashboard> createState() => _CommissionerDashboardState();
}

class _CommissionerDashboardState extends State<CommissionerDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<_MapViewState> _mapKey = GlobalKey<_MapViewState>();

  final List<String> _titles = [
    'Commissioner Home',
    'My Desk',
    'Complaint Map',
    'City Activity',
    'My Profile',
  ];

  void _jumpToLocationOnMap(LatLng coords, String id) {
    setState(() {
      _selectedIndex = 2; // Index of Map View
    });
    // Use a small delay to ensure the MapView is rendered before moving camera
    Future.delayed(const Duration(milliseconds: 100), () {
      _mapKey.currentState?.moveCamera(coords, id);
    });
  }

  Future<void> _refreshDashboardData() async {
    await ComplaintStore.instance.fetchComplaints();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 1.5,
        titleSpacing: 0,
        leading: Container(
          width: 80,
          padding: const EdgeInsets.all(4),
          child: Image.asset(
            'assets/Gemini_Generated_Image_5goo3w5goo3w5goo (1).png',
            fit: BoxFit.contain,
          ),
        ),
        leadingWidth: 80,
        title: Text(
          _selectedIndex < _titles.length ? _titles[_selectedIndex] : '',
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primary, size: 24),
            tooltip: 'Refresh',
            onPressed: _refreshDashboardData,
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: primary,
                  size: 28,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const _NotificationScreen(),
                    ),
                  );
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: ComplaintStore.instance,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ComplaintStore.instance.isShowingMockData)
              Container(
                width: double.infinity,
                color: Colors.orange.shade100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange.shade800,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Demo data — Supabase unavailable',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _HomeView(onLocationClick: _jumpToLocationOnMap),
                  _DeskView(onLocationClick: _jumpToLocationOnMap),
                  _MapView(key: _mapKey, onLocationClick: _jumpToLocationOnMap),
                  const _ActivityView(),
                  _ProfileView(onLocationClick: _jumpToLocationOnMap),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _ReportDamageScreen(),
                  ),
                );
              },
              backgroundColor: primary,
              label: const Text(
                'Report Damage',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              icon: const Icon(Icons.add_a_photo_outlined, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            label: 'Desk',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline_rounded),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeView extends StatefulWidget {
  final Function(LatLng, String) onLocationClick;
  const _HomeView({super.key, required this.onLocationClick});

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  bool _showAll = false;

  List<Map<String, dynamic>> get _dashboardComplaints => 
      LegacyDashboardAdapter.detailComplaints(ComplaintStore.instance.complaints);
  int get _totalAvailable => _dashboardComplaints.length;
  int get _displayCount =>
      _showAll ? _totalAvailable : (_totalAvailable > 4 ? 4 : _totalAvailable);
  int get _totalComplaints => DashboardMetrics.total(_dashboardComplaints);
  int get _workInProgress => DashboardMetrics.inProgress(_dashboardComplaints);
  int get _resolvedComplaints =>
      DashboardMetrics.resolved(_dashboardComplaints);
  String get _resolutionRate =>
      DashboardMetrics.resolutionRateLabel(_dashboardComplaints);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Quick Stats Section
        Row(
          children: [
            _StatCard(
              icon: Icons.assignment_outlined,
              label: 'Total Complaints',
              value: '$_totalComplaints',
              color: primary,
              bgColor: const Color(0xFFCFD9E0), // Stronger muted slate
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _TotalComplaintsOverview(
                    onLocationClick: widget.onLocationClick,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.construction_outlined,
              label: 'Work InProgress',
              value: '$_workInProgress',
              color: const Color(0xFF7D622A), // Darker authoritative amber
              bgColor: const Color(0xFFEBDDBE), // Stronger muted sand
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _ComplaintListView(
                    title: 'Work InProgress',
                    filterStatus: 'InProgress',
                    onLocationClick: widget.onLocationClick,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(
              icon: Icons.task_alt,
              label: 'Completed',
              value: '$_resolvedComplaints',
              color: const Color(0xFF2E5A3D), // Authoritative green
              bgColor: const Color(0xFFD6E4D9), // Muted green
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _ComplaintListView(
                    title: 'Completed Complaints',
                    filterStatus: 'Resolved',
                    onLocationClick: widget.onLocationClick,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.check_circle_outline,
              label: 'Resolution Rate (%)',
              value: _resolutionRate,
              color: const Color(0xFF385E44), // Authoritative deep green
              bgColor: const Color(0xFFDCE4DD), // Muted olive
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const _ResolutionRateDetailView(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        // Recent Complaints Section
        const Text(
          'Recent Complaints',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: List.generate(
            _displayCount,
            (i) => _ComplaintCard(
              index: i,
              onLocationClick: widget.onLocationClick,
            ),
          ),
        ),
        if (_displayCount < _totalAvailable)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAll = true;
                  });
                },
                icon: const Icon(Icons.expand_more, color: primary),
                label: const Text(
                  'Load More Complaints',
                  style: TextStyle(color: primary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }
}

// SLA Configuration - Configurable escalation timers
class _SLAConfig {
  static int getRoleSlaDays(String? handler) {
    switch ((handler ?? 'JE').toUpperCase()) {
      case 'JE':
        return EscalationConfig.juniorEngineerSLA;
      case 'AE':
        return EscalationConfig.assistantEngineerSLA;
      case 'DE':
        return EscalationConfig.deputyEngineerSLA;
      case 'CE':
        return 999;
      default:
        return EscalationConfig.juniorEngineerSLA;
    }
  }

  static String getEscalationTarget(Map<String, dynamic> complaint) {
    switch ((complaint['currentHandler'] ?? 'JE').toString().toUpperCase()) {
      case 'JE':
        return 'Assistant Engineer';
      case 'AE':
        return 'Deputy Engineer';
      case 'DE':
        return 'City Engineer';
      case 'CE':
        return 'Final Authorization';
      default:
        return 'Higher Authority';
    }
  }

  static DateTime _levelStart(Map<String, dynamic> complaint) {
    return complaint['receivedAtCurrentLevel'] as DateTime? ??
        complaint['submittedDate'] as DateTime? ??
        DateTime.now();
  }

  static int getDaysRemaining(Map<String, dynamic> complaint) {
    final slaDays = getRoleSlaDays(complaint['currentHandler']?.toString());
    if (slaDays >= 999) return 999;
    final deadline = _levelStart(complaint).add(Duration(days: slaDays));
    return deadline.difference(DateTime.now()).inDays;
  }

  static bool isNearEscalation(Map<String, dynamic> complaint) {
    final daysRemaining = getDaysRemaining(complaint);
    return daysRemaining <= 1;
  }

  static double getProgressValue(
    int daysRemaining,
    Map<String, dynamic> complaint,
  ) {
    final slaDays = getRoleSlaDays(complaint['currentHandler']?.toString());
    if (slaDays <= 0 || slaDays >= 999) return 0.0;
    if (daysRemaining < 0) return 1.0;
    return 1.0 - (daysRemaining / slaDays).clamp(0.0, 1.0);
  }

  static Color getEscalationColor(int daysRemaining) {
    if (daysRemaining < 0) return Colors.red;
    if (daysRemaining <= 1) return Colors.orange;
    if (daysRemaining <= 2) return Colors.amber;
    return Colors.green;
  }
}

// Junior Engineer Assigned Wards (Mock data)
class _JEConfig {
  static List<String> get assignedWards => WardAssignmentService.assignedWards;
  static const String department = 'Roads Division';
  static const String name = 'Rajesh Kumar';
  static const String employeeId = 'JE-SMC-2024-089';
}

class _DeskView extends StatefulWidget {
  final Function(LatLng, String) onLocationClick;
  const _DeskView({super.key, required this.onLocationClick});

  @override
  State<_DeskView> createState() => _DeskViewState();
}

class _DeskViewState extends State<_DeskView> {
  List<Map<String, dynamic>> get newComplaints =>
      LegacyDashboardAdapter.detailComplaints(
        ComplaintStore.instance.complaints.where((c) {
          final status = (c['status'] ?? '').toString().trim().toLowerCase();
          return status == 'Open' ||
              status == 'under review' ||
              status == 'escalated';
        }),
      );

  List<Map<String, dynamic>> get assignedComplaints =>
      LegacyDashboardAdapter.detailComplaints(
        ComplaintStore.instance.complaints.where((c) {
          final assignedTo = (c['assignedTo'] ?? '').toString().trim();
          if (assignedTo.isEmpty) return false;
          final status = (c['status'] ?? '').toString().trim().toLowerCase();
          return status == 'verified' ||
              status == 'InProgress' ||
              status == 'resolved';
        }),
      );

  @override
  Widget build(BuildContext context) {
    // Filter escalation risk complaints
    final escalationRiskComplaints = [
      ...newComplaints,
      ...assignedComplaints,
    ].where((c) => _SLAConfig.isNearEscalation(c)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // HEADER
        Row(
          children: [
            Icon(Icons.work_outline_rounded, color: primary, size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'My Work Desk',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_JEConfig.assignedWards.length} Wards',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Complaints assigned to your responsibility',
          style: TextStyle(fontSize: 13, color: textSecondary),
        ),
        const SizedBox(height: 20),

        // SECTION: ESCALATION RISK (if any)
        if (escalationRiskComplaints.isNotEmpty) ...[
          _buildSectionHeader(
            'Escalation Risk',
            Icons.warning_amber_rounded,
            Colors.red,
            '${escalationRiskComplaints.length} urgent',
          ),
          const SizedBox(height: 12),
          ...escalationRiskComplaints.map(
            (c) => _JEDeskCard(
              data: c,
              onLocationClick: widget.onLocationClick,
              showSLA: true,
              isEscalation: true,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // SECTION A: NEW/UNVERIFIED COMPLAINTS
        _buildSectionHeader(
          'New & Unverified',
          Icons.fiber_new_rounded,
          const Color(0xFF4A90D9),
          '${newComplaints.length} pending',
        ),
        const SizedBox(height: 12),
        if (newComplaints.isEmpty)
          _buildEmptyState(
            'No new complaints',
            'All complaints in your wards have been reviewed.',
          )
        else
          ...newComplaints.map(
            (c) => _JEDeskCard(
              data: c,
              onLocationClick: widget.onLocationClick,
              showSLA: true,
            ),
          ),
        const SizedBox(height: 24),

        // SECTION B: VERIFIED/ASSIGNED COMPLAINTS
        _buildSectionHeader(
          'Verified & Assigned',
          Icons.assignment_turned_in_rounded,
          const Color(0xFF7DB89A),
          '${assignedComplaints.length} active',
        ),
        const SizedBox(height: 12),
        if (assignedComplaints.isEmpty)
          _buildEmptyState(
            'No active assignments',
            'Verified complaints will appear here.',
          )
        else
          ...assignedComplaints.map(
            (c) => _JEDeskCard(
              data: c,
              onLocationClick: widget.onLocationClick,
              showSLA: false,
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
    String count,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            color: textSecondary.withOpacity(0.5),
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w600, color: textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: textSecondary.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// JUNIOR ENGINEER DESK CARD
class _JEDeskCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Function(LatLng, String) onLocationClick;
  final bool showSLA;
  final bool isEscalation;

  const _JEDeskCard({
    required this.data,
    required this.onLocationClick,
    this.showSLA = true,
    this.isEscalation = false,
  });

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return const Color(0xFFCBB17D);
      case 'low':
        return const Color(0xFF7DB89A);
      default:
        return textSecondary;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return const Color(0xFF4A90D9);
      case 'Verified':
        return const Color(0xFF7DB89A);
      case 'InProgress':
        return const Color(0xFFC9A24D);
      case 'Resolved':
        return const Color(0xFF4CAF50);
      default:
        return textSecondary;
    }
  }

  String _getDaysText(int days) {
    if (days < 0) return 'Overdue ${-days}d';
    if (days == 0) return 'Due today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _getSeverityColor(data['severity']);
    final statusColor = _getStatusColor(data['status']);
    final daysRemaining = showSLA ? _SLAConfig.getDaysRemaining(data) : 999;
    final slaColor = _SLAConfig.getEscalationColor(daysRemaining);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _JEComplaintDetailScreen(
              data: data,
              onLocationClick: onLocationClick,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEscalation ? Colors.red.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isEscalation
              ? Border.all(color: Colors.red.withOpacity(0.3), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP ROW: ID, Severity, Status
            Row(
              children: [
                Text(
                  data['id'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    data['severity'],
                    style: TextStyle(
                      color: severityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data['status'],
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // TITLE
            Text(
              data['title'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // LOCATION + WARD
            GestureDetector(
              onTap: () {
                if (data['coords'] != null) {
                  onLocationClick(data['coords'], data['id']);
                }
              },
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${data['location']} • ${data['ward']}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: primary,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // SLA INDICATOR (for new complaints)
            if (showSLA) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: slaColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: slaColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      daysRemaining < 0
                          ? Icons.error_rounded
                          : Icons.timer_outlined,
                      size: 14,
                      color: slaColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getDaysText(daysRemaining),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: slaColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'before escalation',
                      style: TextStyle(
                        fontSize: 11,
                        color: slaColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ASSIGNED INFO (for verified complaints)
            if (!showSLA && data['assignedTo'] != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7DB89A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF7DB89A).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.assignment_ind_outlined,
                      size: 14,
                      color: const Color(0xFF7DB89A),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Assigned: ${data['assignedTo']}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7DB89A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // BOTTOM ROW: Last update
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: textSecondary.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  'Updated: ${_formatDate(data['lastUpdate'] ?? data['submittedDate'])}',
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// COMPLAINT TRACK CARD
class _ComplaintTrackCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Function(LatLng, String) onLocationClick;
  const _ComplaintTrackCard({
    required this.data,
    required this.onLocationClick,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Under Review':
        return const Color(0xFF757575);
      case 'Pending Approval':
        return Colors.orange;
      case 'Pending':
        return const Color(0xFFCBB17D);
      case 'InProgress':
        return const Color(0xFF4A90D9);
      case 'Resolved':
        return const Color(0xFF7DB89A);
      default:
        return textSecondary;
    }
  }

  Color _getRemarkColor(String remark) {
    if (remark.contains('Confirmed') ||
        remark.contains('Verified') ||
        remark.contains('Completed')) {
      return const Color(0xFF7DB89A);
    } else if (remark.contains('Progress')) {
      return const Color(0xFF4A90D9);
    } else if (remark.contains('Pending') || remark.contains('Review')) {
      return const Color(0xFFCBB17D);
    }
    return textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(data['status']);
    final verificationRemarks = data['verificationRemarks'] as List<dynamic>?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _ComplaintDetailScreen(
              data: data,
              onLocationClick: onLocationClick,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data['id'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data['status'],
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Title
            Text(
              data['title'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            // Location
            GestureDetector(
              onTap: () {
                if (data['coords'] != null) {
                  onLocationClick(data['coords'], data['id']);
                }
              },
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      data['location'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: primary,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Verification Badges (if available)
            if (verificationRemarks != null &&
                verificationRemarks.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: verificationRemarks.take(2).map((remark) {
                  final remarkColor = _getRemarkColor(remark);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: remarkColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 12, color: remarkColor),
                        const SizedBox(width: 4),
                        Text(
                          remark,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: remarkColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            // Last Updated
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: textSecondary.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  'Updated ${data['lastUpdated']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary.withOpacity(0.7),
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, size: 20, color: textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// COMPLAINT DETAIL SCREEN
class _ComplaintDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(LatLng, String) onLocationClick;
  const _ComplaintDetailScreen({
    required this.data,
    required this.onLocationClick,
  });

  @override
  State<_ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<_ComplaintDetailScreen> {
  late int upvoteCount;
  late bool hasUpvoted;

  @override
  void initState() {
    super.initState();
    upvoteCount = widget.data['upvotes'] ?? 0;
    hasUpvoted = widget.data['hasUpvoted'] ?? false;
  }

  void _toggleUpvote() {
    setState(() {
      if (hasUpvoted) {
        upvoteCount--;
        hasUpvoted = false;
      } else {
        upvoteCount++;
        hasUpvoted = true;
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Under Review':
        return const Color(0xFF757575);
      case 'Pending Approval':
        return Colors.orange;
      case 'Pending':
        return const Color(0xFFCBB17D);
      case 'InProgress':
        return const Color(0xFF4A90D9);
      case 'Resolved':
        return const Color(0xFF7DB89A);
      default:
        return textSecondary;
    }
  }

  Color _getRemarkColor(String remark) {
    if (remark.contains('Confirmed') ||
        remark.contains('Verified') ||
        remark.contains('Completed')) {
      return const Color(0xFF7DB89A);
    } else if (remark.contains('Progress')) {
      return const Color(0xFF4A90D9);
    } else if (remark.contains('Pending') || remark.contains('Review')) {
      return const Color(0xFFCBB17D);
    }
    return textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.data['status'] ?? 'Pending');
    final timeline = widget.data['timeline'] as List<dynamic>? ?? [];
    final isMine = widget.data['isMine'] as bool? ?? false;
    final verificationRemarks =
        widget.data['verificationRemarks'] as List<dynamic>?;
    final officialRemarks = widget.data['officialRemarks'] as String?;

    // Handle location being either String or LatLng
    String locationText = 'Location details not available';
    if (widget.data['location'] is String) {
      locationText = widget.data['location'];
    } else if (widget.data['address'] is String) {
      locationText = widget.data['address'];
    } else if (widget.data['location'] != null) {
      locationText = 'Solapur City Area'; // Fallback
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Complaint Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SUMMARY CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ID and Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Complaint ID: ${widget.data['id']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.data['status'] ?? 'Pending',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Text(
                    widget.data['title'] ?? 'N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Location
                  GestureDetector(
                    onTap: () {
                      if (widget.data['coords'] != null) {
                        Navigator.pop(context);
                        widget.onLocationClick(
                          widget.data['coords'],
                          widget.data['id'],
                        );
                      }
                    },
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 18, color: primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            locationText,
                            style: const TextStyle(
                              fontSize: 14,
                              color: primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Submitted Date
                  _infoRow(
                    Icons.calendar_today_outlined,
                    'Submitted on',
                    widget.data['submittedDate'],
                  ),
                  const SizedBox(height: 8),
                  // Last Updated
                  _infoRow(
                    Icons.update,
                    'Last updated',
                    widget.data['lastUpdated'],
                  ),

                  // Not Mine indicator
                  if (!isMine) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline, size: 14, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            'Reported by another citizen',
                            style: TextStyle(
                              fontSize: 12,
                              color: accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // UPVOTE SECTION
            GestureDetector(
              onTap: _toggleUpvote,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: hasUpvoted ? primary.withOpacity(0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasUpvoted
                        ? primary
                        : textSecondary.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                      color: hasUpvoted ? primary : textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasUpvoted ? 'Upvoted' : 'Upvote this complaint',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: hasUpvoted ? primary : textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: hasUpvoted ? primary.withOpacity(0.2) : surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$upvoteCount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: hasUpvoted ? primary : textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // VERIFICATION REMARKS
            if (verificationRemarks != null &&
                verificationRemarks.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Verification Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: verificationRemarks.map((remark) {
                  final remarkColor = _getRemarkColor(remark);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: remarkColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 14, color: remarkColor),
                        const SizedBox(width: 6),
                        Text(
                          remark,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: remarkColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // OFFICIAL REMARKS
            if (officialRemarks != null && officialRemarks.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Official Remarks',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            officialRemarks,
                            style: const TextStyle(
                              fontSize: 13,
                              color: textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // REPORTED IMAGES SECTION (if available)
            if (widget.data['images'] != null &&
                (widget.data['images'] as List).isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Reported Images',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (widget.data['images'] as List).length,
                  itemBuilder: (context, index) {
                    final imagePath = (widget.data['images'] as List)[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _ImagePreviewScreen(
                              images: List<String>.from(widget.data['images']),
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 130,
                        margin: EdgeInsets.only(
                          right:
                              index < (widget.data['images'] as List).length - 1
                              ? 10
                              : 0,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: primary.withOpacity(0.15)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image(
                            image: _complaintImageProvider(
                              imagePath.toString(),
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: surface,
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: textSecondary,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),

            // STATUS TIMELINE
            const Text(
              'Status Timeline',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: timeline.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stage = entry.value;
                  final isLast = index == timeline.length - 1;
                  return _timelineItem(
                    stage['stage'],
                    stage['date'],
                    stage['completed'] ?? false,
                    stage['current'] ?? false,
                    isLast,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, Object? value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: textSecondary)),
        Expanded(
          child: Text(
            _displayValue(value),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _displayValue(Object? value) {
    if (value is DateTime) {
      return '${value.day}/${value.month}/${value.year} ${value.hour}:${value.minute.toString().padLeft(2, '0')}';
    }
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null') return 'N/A';
    return raw;
  }

  Widget _timelineItem(
    String stage,
    String? date,
    bool completed,
    bool current,
    bool isLast,
  ) {
    final Color dotColor = completed
        ? const Color(0xFF7DB89A)
        : current
        ? const Color(0xFF4A90D9)
        : const Color(0xFFE0E0E0);
    final Color textColor = completed || current
        ? textPrimary
        : textSecondary.withOpacity(0.5);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: current
                    ? Border.all(color: const Color(0xFF4A90D9), width: 3)
                    : null,
              ),
              child: completed
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : current
                  ? Container(
                      margin: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: completed
                    ? const Color(0xFF7DB89A)
                    : const Color(0xFFE0E0E0),
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Stage info
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage,
                  style: TextStyle(
                    fontWeight: completed || current
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                if (date != null)
                  Text(
                    date,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                if (current)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90D9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Current',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A90D9),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// JUNIOR ENGINEER COMPLAINT DETAIL SCREEN
class _JEComplaintDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(LatLng, String) onLocationClick;
  const _JEComplaintDetailScreen({
    required this.data,
    required this.onLocationClick,
  });

  @override
  State<_JEComplaintDetailScreen> createState() =>
      _JEComplaintDetailScreenState();
}

class _JEComplaintDetailScreenState extends State<_JEComplaintDetailScreen> {
  String? _selectedAction;
  final TextEditingController _remarksController = TextEditingController();
  String? _selectedContractor;
  String? _selectedWorkGang;

  final List<String> _contractors = [
    'Sharma Contractors Pvt Ltd',
    'Solapur Road Builders',
    'Maharashtra Infra Corp',
    'City Maintenance Services',
  ];

  final List<String> _workGangs = [
    'Gang A - Road Repair Unit',
    'Gang B - Pothole Specialists',
    'Gang C - Emergency Response',
    'Gang D - Night Shift Crew',
  ];

  @override
  Widget build(BuildContext context) {
    final daysRemaining = _SLAConfig.getDaysRemaining(widget.data);
    final slaColor = _SLAConfig.getEscalationColor(daysRemaining);
    final isNew = widget.data['status'] == 'Open';
    final isVerified =
        widget.data['status'] == 'Verified' ||
        widget.data['status'] == 'InProgress';

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 1,
        title: Text(
          widget.data['id'],
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (isNew)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: slaColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: slaColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: slaColor),
                  const SizedBox(width: 4),
                  Text(
                    daysRemaining < 0 ? 'Overdue' : '$daysRemaining days left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: slaColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // COMPLAINT HEADER
          _buildComplaintHeader(),
          const SizedBox(height: 20),

          // IMAGES
          if (widget.data['images'] != null)
            _buildImageCarousel(widget.data['images'] as List<dynamic>),
          const SizedBox(height: 20),

          // SLA TIMELINE (for new complaints)
          if (isNew) ...[
            _buildSLATimeline(daysRemaining, slaColor, widget.data),
            const SizedBox(height: 20),
          ],

          // CURRENT ASSIGNMENT (if assigned)
          if (!isNew && widget.data['assignedTo'] != null) ...[
            _buildAssignmentCard(),
            const SizedBox(height: 20),
          ],

          // ACTION BUTTONS (for new complaints)
          if (isNew) ...[
            _buildSectionTitle('Actions Required'),
            const SizedBox(height: 12),
            _buildActionButton(
              'Verify Complaint',
              Icons.verified_outlined,
              const Color(0xFF7DB89A),
              () => _showVerifyDialog(),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Assign to Contractor',
              Icons.business_outlined,
              const Color(0xFF4A90D9),
              () => _showAssignContractorDialog(),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Assign Work Gang',
              Icons.engineering_outlined,
              const Color(0xFFC9A24D),
              () => _showAssignWorkGangDialog(),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Escalate to Chief Engineer',
              Icons.arrow_upward_rounded,
              Colors.orange,
              () => _showEscalateDialog(),
              isDestructive: true,
            ),
            const SizedBox(height: 20),
          ],

          // OFFICIAL REMARKS
          _buildSectionTitle('Official Remarks'),
          const SizedBox(height: 12),
          _buildRemarksSection(),
          const SizedBox(height: 20),

          // COMPLAINT TIMELINE
          _buildSectionTitle('Complaint Timeline'),
          const SizedBox(height: 12),
          _buildTimeline(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildComplaintHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSeverityColor(
                    widget.data['severity'],
                  ).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.data['severity'],
                  style: TextStyle(
                    color: _getSeverityColor(widget.data['severity']),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    widget.data['status'],
                  ).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.data['status'],
                  style: TextStyle(
                    color: _getStatusColor(widget.data['status']),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.data['title'],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              if (widget.data['coords'] != null) {
                widget.onLocationClick(
                  widget.data['coords'],
                  widget.data['id'],
                );
              }
            },
            child: Row(
              children: [
                Icon(Icons.location_on, size: 16, color: primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${widget.data['location']} • ${widget.data['ward']}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submitted: ${_formatDateTime(widget.data['submittedDate'])}',
            style: TextStyle(
              fontSize: 12,
              color: textSecondary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(List<dynamic> images) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: _complaintImageProvider(images[index].toString()),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSLATimeline(
    int daysRemaining,
    Color color,
    Map<String, dynamic> complaint,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                'SLA Timeline',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _SLAConfig.getProgressValue(daysRemaining, complaint),
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            daysRemaining < 0
                ? '⚠️ Overdue by ${-daysRemaining} days. Escalation required!'
                : '⏰ ${_getDaysText(daysRemaining)} before auto-escalation to ${_SLAConfig.getEscalationTarget(complaint)}',
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF7DB89A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7DB89A).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                color: Color(0xFF7DB89A),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Current Assignment',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF7DB89A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Assigned To',
            widget.data['assignedTo'] ?? 'Not assigned',
          ),
          if (widget.data['workGang'] != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Work Gang', widget.data['workGang']),
          ],
          const SizedBox(height: 8),
          _buildInfoRow(
            'Last Updated',
            _formatDateTime(widget.data['lastUpdate']),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.white : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive ? color : color.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDestructive ? color : textPrimary,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRemarksSection() {
    return Column(
      children: [
        TextField(
          controller: _remarksController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add official remarks...',
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // Save remarks
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Remarks saved successfully')),
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Remarks'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline() {
    final timeline = [
      {
        'stage': 'Complaint Submitted',
        'date': widget.data['submittedDate'],
        'completed': true,
      },
      if (widget.data['verifiedDate'] != null)
        {
          'stage': 'Verified by JE',
          'date': widget.data['verifiedDate'],
          'completed': true,
        },
      if (widget.data['assignedTo'] != null)
        {
          'stage': 'Assigned to ${widget.data['assignedTo']}',
          'date': widget.data['lastUpdate'],
          'completed': true,
        },
      {
        'stage': 'Current Status: ${widget.data['status']}',
        'date': null,
        'completed': false,
        'current': true,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: timeline.asMap().entries.map((entry) {
          final index = entry.key;
          final stage = entry.value;
          final isLast = index == timeline.length - 1;
          final completed = stage['completed'] as bool;
          final isCurrent = stage['current'] as bool? ?? false;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: completed
                          ? const Color(0xFF7DB89A)
                          : (isCurrent ? const Color(0xFF4A90D9) : surface),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      completed
                          ? Icons.check
                          : (isCurrent ? Icons.circle : Icons.circle_outlined),
                      color: completed || isCurrent
                          ? Colors.white
                          : textSecondary,
                      size: completed ? 16 : 12,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 40,
                      color: completed ? const Color(0xFF7DB89A) : surface,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage['stage'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: completed || isCurrent
                            ? textPrimary
                            : textSecondary,
                      ),
                    ),
                    if (stage['date'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(stage['date']),
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary.withOpacity(0.8),
                        ),
                      ),
                    ],
                    if (!isLast) const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: textSecondary)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return const Color(0xFFCBB17D);
      case 'low':
        return const Color(0xFF7DB89A);
      default:
        return textSecondary;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return const Color(0xFF4A90D9);
      case 'Verified':
        return const Color(0xFF7DB89A);
      case 'InProgress':
        return const Color(0xFFC9A24D);
      case 'Resolved':
        return const Color(0xFF4CAF50);
      default:
        return textSecondary;
    }
  }

  String _getDaysText(int days) {
    if (days < 0) return 'Overdue ${-days}d';
    if (days == 0) return 'Due today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }

  String _formatDateTime(Object? date) {
    if (date == null) return 'N/A';
    if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    final raw = date.toString().trim();
    if (raw.isEmpty || raw == 'null') return 'N/A';
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return '${parsed.day}/${parsed.month}/${parsed.year} ${parsed.hour}:${parsed.minute.toString().padLeft(2, '0')}';
    }
    return raw;
  }

  String _displayValue(Object? value) {
    if (value is DateTime) return _formatDateTime(value);
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null') return 'N/A';
    return raw;
  }

  void _showVerifyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Complaint'),
        content: const Text(
          'Mark this complaint as verified after field inspection?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Complaint verified successfully'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7DB89A),
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showAssignContractorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Contractor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _contractors
              .map(
                (c) => RadioListTile<String>(
                  title: Text(c, style: const TextStyle(fontSize: 14)),
                  value: c,
                  groupValue: _selectedContractor,
                  onChanged: (value) =>
                      setState(() => _selectedContractor = value),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Assigned to $_selectedContractor')),
              );
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _showAssignWorkGangDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Work Gang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _workGangs
              .map(
                (g) => RadioListTile<String>(
                  title: Text(g, style: const TextStyle(fontSize: 14)),
                  value: g,
                  groupValue: _selectedWorkGang,
                  onChanged: (value) =>
                      setState(() => _selectedWorkGang = value),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Assigned to $_selectedWorkGang')),
              );
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _showEscalateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escalate to Chief Engineer'),
        content: const Text(
          'This complaint will be escalated to the Chief Engineer. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Complaint escalated to Chief Engineer'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );
  }
}

class _MapView extends StatefulWidget {
  final Function(LatLng, String) onLocationClick;
  const _MapView({super.key, required this.onLocationClick});

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final List<Marker> _markers = [];
  List<Map<String, dynamic>> _filteredLocations = [];
  Position? _currentPosition;
  bool _isLoading = true;
  String? _highlightedId;

  // Method to move camera to a specific location and highlight marker
  void moveCamera(LatLng point, [String? id]) {
    setState(() {
      _highlightedId = id;
    });
    _mapController.move(point, 15);
    _loadMarkers();

    // Clear highlight after 3 seconds
    if (id != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _highlightedId == id) {
          setState(() {
            _highlightedId = null;
          });
          _loadMarkers();
        }
      });
    }
  }

  // Solapur city center
  static const LatLng _solapurCenter = LatLng(17.6599, 75.9064);

  // Sample complaint markers with real Solapur locations

  List<Map<String, dynamic>> get _complaintLocations =>
      LegacyDashboardAdapter.mapLocations(ComplaintStore.instance.complaints);

  @override
  void initState() {
    super.initState();
    _filteredLocations = List.from(_complaintLocations);
    _loadMarkers();
    _getCurrentLocation();
  }

  void _onSearchChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _filteredLocations = List.from(_complaintLocations);
      } else {
        _filteredLocations = _complaintLocations
            .where(
              (loc) =>
                  loc['title'].toString().toLowerCase().contains(
                    value.toLowerCase(),
                  ) ||
                  loc['id'].toString().toLowerCase().contains(
                    value.toLowerCase(),
                  ),
            )
            .toList();
      }
      _loadMarkers();
    });
  }

  void _loadMarkers() {
    _markers.clear();
    for (var complaint in _filteredLocations) {
      final bool isHighlighted = _highlightedId == complaint['id'];
      _markers.add(
        Marker(
          width: isHighlighted ? 80 : 45,
          height: isHighlighted ? 80 : 45,
          point: complaint['location'],
          rotate: true,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _showComplaintDetails(complaint),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              child: isHighlighted
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulse effect
                        TweenAnimationBuilder(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 1000),
                          builder: (context, double value, child) {
                            return Container(
                              width: 60 * value,
                              height: 60 * value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (complaint['color'] as Color)
                                    .withOpacity(1.0 - value),
                              ),
                            );
                          },
                        ),
                        Icon(
                          Icons.location_on,
                          color: complaint['color'],
                          size: 60,
                        ),
                      ],
                    )
                  : Icon(
                      Icons.location_on,
                      color: complaint['color'],
                      size: 45,
                    ),
            ),
          ),
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentPosition = position;
          // Add current location marker
          _markers.add(
            Marker(
              width: 40,
              height: 40,
              point: LatLng(position.latitude, position.longitude),
              child: const Icon(
                Icons.my_location,
                color: Colors.blueAccent,
                size: 30,
              ),
            ),
          );
        });

        _mapController.move(LatLng(position.latitude, position.longitude), 14);
      }
    } catch (e) {
      // Handle error
    }
  }

  void _showComplaintDetails(Map<String, dynamic> complaint) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ComplaintDetailScreen(
          data: complaint,
          onLocationClick: widget.onLocationClick,
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'InProgress':
        color = const Color(0xFF4A90D9);
        break;
      case 'Pending':
        color = const Color(0xFFE74C3C);
        break;
      case 'Resolved':
        color = const Color(0xFF7DB89A);
        break;
      case 'Pending Approval':
        color = Colors.orange;
        break;
      case 'Under Review':
        color = const Color(0xFF757575);
        break;
      default:
        color = textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: _solapurCenter,
            initialZoom: 13,
            maxZoom: 18,
            minZoom: 3,
          ),
          children: [
            MapTileConfig.buildTileLayer(),
            MarkerLayer(markers: _markers),
          ],
        ),
        // Search Bar
        Positioned(
          top: 16,
          left: 16,
          right: 70, // Leave space for Solapur Center Button
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by ID or Title...',
                hintStyle: const TextStyle(fontSize: 14, color: textSecondary),
                prefixIcon: const Icon(Icons.search, color: primary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
        // Solapur Center Button
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: () => _mapController.move(_solapurCenter, 13),
            backgroundColor: Colors.white,
            child: const Icon(Icons.location_city, color: primary),
          ),
        ),
        // Legend overlay
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _legendItem('Resolved', Colors.green),
                  const SizedBox(width: 12),
                  _legendItem('InProgress', Colors.blue),
                  const SizedBox(width: 12),
                  _legendItem('Pending Approval', Colors.orange),
                  const SizedBox(width: 12),
                  _legendItem('Pending', Colors.red),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(color: primary),
            ),
          ),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ActivityView extends StatefulWidget {
  const _ActivityView();

  @override
  State<_ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<_ActivityView> {
  // Demo-only feed (debug + ALLOW_MOCK_DATA); see [AppFlags.showAssetDemoUi].
  static const Map<String, dynamic> _pinnedDemo = {
    'title': 'Night road works scheduled from 10 PM – 5 AM across city zones',
    'timestamp': 'Updated 3 hours ago',
  };

  static Map<String, dynamic>? get pinnedUpdate => _pinnedDemo;

  static final List<Map<String, dynamic>> _demoActivities = [
    // MAINTENANCE
    {
      'title': 'Night resurfacing work on MG Road',
      'timestamp': '1 hour ago',
      'category': 'Maintenance',
      'description': 'Asphalt resurfacing scheduled tonight',
      'department': 'Roads Division',
      'status': 'ongoing',
      'details': {
        'full_content':
            'The Roads Division has scheduled asphalt resurfacing work on MG Road starting tonight at 10 PM. The work is expected to continue for 3 nights until completion. Traffic will be diverted through alternate routes during work hours.\n\nWork Schedule:\n- Duration: 3 nights (10 PM - 5 AM)\n- Affected stretch: MG Road from Central Mall to Railway Crossing\n- Alternate route: Station Road via Budhwar Peth\n\nCitizens are advised to plan their travel accordingly.',
        'location': 'MG Road, Central Mall to Railway Crossing',
        'contact': 'Roads Division Helpline: 0217-2612345',
      },
    },
    // COMPLAINT & REPAIR
    {
      'title': 'Work started at Hotgi Road',
      'timestamp': '2 hours ago',
      'category': 'Repair',
      'description': 'Pothole repair work initiated',
      'department': 'Roads Division',
      'status': 'started',
      'visualEvidence': {
        'before': 'assets/download (1).jpg',
        'after': 'assets/download (3).jpg',
      },
      'details': {
        'full_content':
            'Municipal Corporation has initiated pothole repair work on Hotgi Road following multiple citizen complaints. The repair crew has been deployed and work is currently InProgress.\n\nWork Details:\n- Location: Hotgi Road, near Siddheshwar Temple\n- Expected completion: 2 days\n- Work timings: 8 AM - 6 PM\n\nMinor traffic delays are expected during work hours. Motorists are requested to exercise caution.',
        'location': 'Hotgi Road, near Siddheshwar Temple',
        'estimated_completion': '2 days',
      },
    },
    // TRAFFIC UPDATE
    {
      'title': 'Temporary lane diversion at Railway Station Road',
      'timestamp': '4 hours ago',
      'category': 'Traffic Update',
      'description': 'Left lane closed for utility work',
      'department': 'Traffic Management',
      'status': 'active',
      'details': {
        'full_content':
            'Traffic Police has announced a temporary lane diversion on Railway Station Road due to ongoing utility maintenance work by the Water Supply Department.\n\nDiversion Details:\n- Affected: Left lane (northbound)\n- Duration: 3 days\n- Alternate route: Use right lane or divert via Market Yard Road\n\nTraffic marshals will be deployed at key junctions to manage flow. Citizens are advised to allow extra travel time.',
        'location': 'Railway Station Road (Northbound)',
        'duration': '3 days',
        'more_info': 'https://solapurtraffic.gov.in/diversions',
      },
    },
    // COMPLETED REPAIR
    {
      'title': 'Repair completed at Station Road',
      'timestamp': '1 day ago',
      'category': 'Repair',
      'description': 'Surface damage repair completed',
      'department': 'Roads Division',
      'status': 'completed',
      'before_image': 'assets/download (1).jpg',
      'after_image': 'assets/download (3).jpg',
      'details': {
        'full_content':
            'The Roads Division has successfully completed surface damage repair work on Station Road. The damaged stretch has been restored and is now open for regular traffic.\n\nWork Summary:\n- Completed on: January 30, 2026\n- Work duration: 4 days\n- Area covered: 250 meters\n- Material used: Hot mix asphalt\n\nThe road surface has been inspected and certified safe for use.',
        'location': 'Station Road, near Bus Stand',
        'completion_date': 'January 30, 2026',
      },
    },
    // ADMINISTRATIVE
    {
      'title': 'Sanction approved for Jule Solapur Road',
      'timestamp': '2 days ago',
      'category': 'Administrative',
      'description': 'Budget allocation sanctioned',
      'department': 'Finance & Planning',
      'status': 'approved',
      'details': {
        'full_content':
            'The Municipal Standing Committee has approved a budget of ₹8.5 Lakhs for comprehensive road repair work on Jule Solapur Road. The tender process will begin next week.\n\nProject Details:\n- Sanctioned amount: ₹8.5 Lakhs\n- Work scope: Road resurfacing, drainage improvement\n- Expected timeline: 45 days after tender award\n\nThe project proposal is available for public viewing at the Municipal Corporation office.',
        'location': 'Jule Solapur Road',
        'budget': '₹8.5 Lakhs',
        'documents': 'Available at Municipal Corporation Office',
      },
    },
    // SEASONAL NOTICE
    {
      'title': 'Pre-monsoon road inspection drive started',
      'timestamp': '3 days ago',
      'category': 'Seasonal Notice',
      'description': 'City-wide road assessment for monsoon readiness',
      'department': 'City Planning',
      'status': 'ongoing',
      'details': {
        'full_content':
            'Solapur Municipal Corporation has launched its annual pre-monsoon road inspection drive. Teams will inspect all major and arterial roads to identify areas requiring preventive maintenance.\n\nInspection Coverage:\n- Duration: 15 days\n- Roads covered: 145 km across all wards\n- Focus areas: Drainage, potholes, surface cracks\n\nCitizens can report road issues through the official app or helpline. Preventive repairs will begin from February 15.',
        'duration': '15 days',
        'helpline': '0217-2612345',
        'more_info': 'https://solmun.gov.in/monsoon-drive',
      },
    },
    // TRAFFIC RESTRICTION
    {
      'title': 'Heavy vehicle restrictions on Pune Highway',
      'timestamp': '4 days ago',
      'category': 'Traffic Update',
      'description': 'Trucks banned during peak hours (7 AM - 10 AM)',
      'department': 'Traffic Police',
      'status': 'active',
      'details': {
        'full_content':
            'Traffic Police has imposed time-based restrictions on heavy vehicles on Pune-Solapur Highway (within city limits) to reduce road wear and ease congestion during peak hours.\n\nRestriction Details:\n- Vehicles affected: Trucks above 12 tonnes\n- Restricted hours: 7 AM - 10 AM and 5 PM - 8 PM\n- Effective from: January 25, 2026\n- Penalty for violation: ₹5,000\n\nAlternate timings are available for essential goods vehicles with proper permits.',
        'location': 'Pune-Solapur Highway (City limits)',
        'effective_date': 'January 25, 2026',
        'permit_info': 'Contact RTO Office: 0217-2634567',
      },
    },
    // MAINTENANCE
    {
      'title': 'Road marking work at Hotgi Junction',
      'timestamp': '5 days ago',
      'category': 'Maintenance',
      'description': 'Lane markings and zebra crossing repaint',
      'department': 'Roads Division',
      'status': 'completed',
      'visualEvidence': {
        'before': 'assets/download (2).jpg',
        'after': 'assets/download (6).jpg',
      },
      'details': {
        'full_content':
            'Road marking and zebra crossing repainting work has been completed at Hotgi Junction. The work included lane markings, stop lines, and pedestrian crossing markers.\n\nWork Completed:\n- Lane markings: 400 meters\n- Zebra crossings: 6 locations\n- Reflective paint used for night visibility\n\nThe markings will improve traffic discipline and pedestrian safety at this busy junction.',
        'location': 'Hotgi Junction',
        'completion_date': 'January 27, 2026',
      },
    },
  ];

  static List<Map<String, dynamic>> get activities => _demoActivities;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // PINNED OFFICIAL UPDATE
        if (pinnedUpdate != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.campaign, color: primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pinnedUpdate!['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pinnedUpdate!['timestamp'],
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ACTIVITY TIMELINE
        if (activities.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No demo activity feed. Enable debug + ALLOW_MOCK_DATA=true for sample stories.',
              style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
            ),
          )
        else
          ...activities.map((activity) => _ActivityStoryCard(data: activity)),
      ],
    );
  }
}

// ACTIVITY STORY CARD
class _ActivityStoryCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ActivityStoryCard({required this.data});

  @override
  State<_ActivityStoryCard> createState() => _ActivityStoryCardState();
}

class _ActivityStoryCardState extends State<_ActivityStoryCard> {
  bool _showBefore = true; // Toggle for before/after images

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Repair':
        return const Color(0xFFCBB17D);
      case 'Maintenance':
        return const Color(0xFF4A90D9);
      case 'Traffic Update':
        return const Color(0xFF9C6FDE);
      case 'Administrative':
        return const Color(0xFF7DB89A);
      case 'Seasonal Notice':
        return const Color(0xFFE89A6F);
      default:
        return textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.data['status'] as String;
    final hasBeforeAfter =
        widget.data['before_image'] != null &&
        widget.data['after_image'] != null;
    final category = widget.data['category'] as String;
    final categoryColor = _getCategoryColor(category);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _NewsDetailScreen(data: widget.data),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: categoryColor.withOpacity(0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CATEGORY LABEL
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: categoryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // PRIMARY HEADLINE
            Text(
              widget.data['title'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            // TIMESTAMP
            Text(
              widget.data['timestamp'],
              style: TextStyle(
                fontSize: 12,
                color: textSecondary.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 10),
            // DESCRIPTION
            Text(
              widget.data['description'],
              style: const TextStyle(
                fontSize: 13,
                color: textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            // DEPARTMENT
            Row(
              children: [
                Icon(Icons.business_outlined, size: 13, color: textSecondary),
                const SizedBox(width: 6),
                Text(
                  widget.data['department'],
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, size: 20, color: textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// NEWS DETAIL SCREEN
class _NewsDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const _NewsDetailScreen({required this.data});

  @override
  State<_NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<_NewsDetailScreen> {
  bool _showBefore = true;

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Repair':
        return const Color(0xFFCBB17D);
      case 'Maintenance':
        return const Color(0xFF4A90D9);
      case 'Traffic Update':
        return const Color(0xFF9C6FDE);
      case 'Administrative':
        return const Color(0xFF7DB89A);
      case 'Seasonal Notice':
        return const Color(0xFFE89A6F);
      default:
        return textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.data['category'] as String;
    final categoryColor = _getCategoryColor(category);
    final details = widget.data['details'] as Map<String, dynamic>;
    final visualEvidence =
        widget.data['visualEvidence'] as Map<String, dynamic>?;
    final hasBeforeAfter =
        visualEvidence != null &&
        visualEvidence['before'] != null &&
        visualEvidence['after'] != null;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          widget.data['title'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CATEGORY BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: categoryColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // HEADLINE
            Text(
              widget.data['title'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            // TIMESTAMP & DEPARTMENT
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: textSecondary),
                const SizedBox(width: 4),
                Text(
                  widget.data['timestamp'],
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(width: 16),
                Icon(Icons.business_outlined, size: 14, color: textSecondary),
                const SizedBox(width: 4),
                Text(
                  widget.data['department'],
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            // FULL CONTENT
            Text(
              details['full_content'],
              style: const TextStyle(
                fontSize: 14,
                color: textPrimary,
                height: 1.6,
              ),
            ),
            // BEFORE/AFTER IMAGES (IF AVAILABLE)
            if (hasBeforeAfter) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.compare, size: 16, color: primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Visual Evidence',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _showBefore = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _showBefore ? primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Before',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _showBefore
                                    ? Colors.white
                                    : textSecondary,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _showBefore = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: !_showBefore
                                  ? primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'After',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: !_showBefore
                                    ? Colors.white
                                    : textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(
                  image: _complaintImageProvider(
                    (_showBefore
                            ? visualEvidence!['before']
                            : visualEvidence!['after'])
                        .toString(),
                  ),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 220,
                    color: surface,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: textSecondary),
                    ),
                  ),
                ),
              ),
            ],
            // LOCATION (IF AVAILABLE)
            if (details['location'] != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  // Open location in maps (in real app, use url_launcher with google maps link)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening location: ${details['location']}'),
                      backgroundColor: primary,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, size: 18, color: primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Location',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              details['location'],
                              style: TextStyle(fontSize: 13, color: primary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.open_in_new, size: 16, color: primary),
                    ],
                  ),
                ),
              ),
            ],
            // MORE INFO LINK (IF AVAILABLE)
            if (details['more_info'] != null) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  // Open link (in real app, use url_launcher package)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening: ${details['more_info']}'),
                      backgroundColor: primary,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new, size: 16, color: primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'View more details online',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: primary),
                    ],
                  ),
                ),
              ),
            ],
            // CONTACT/HELPLINE (IF AVAILABLE)
            if (details['contact'] != null || details['helpline'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        details['contact'] ?? details['helpline'] ?? '',
                        style: TextStyle(fontSize: 13, color: textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileView extends StatefulWidget {
  final Function(LatLng, String) onLocationClick;
  const _ProfileView({super.key, required this.onLocationClick});

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final email = AuthService.currentUserEmail ?? '';
      final profile = await UserService.instance.getCurrentProfile();
      final officialRole = await UserService.instance.getOfficialRoleByEmail(email);
      
      if (mounted) {
        setState(() {
          _userProfile = {
            'name': (profile != null && profile['full_name'] != null && profile['full_name'].toString().trim().isNotEmpty) ? profile['full_name'] : email.split('@')[0],
            'mobile': profile != null && profile['mobile'] != null ? profile['mobile'] : '',
            'email': email,
            'role': officialRole != null ? officialRole['role'] : (profile != null ? profile['role'] : 'Citizen'),
          };
        });
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
    }
  }

  bool _notifyMyComplaints = true;
  bool _notifyRoadAlerts = true;
  bool _notifyMonsoon = false;
  String? _profileImagePath;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1️⃣ PROFILE HEADER (IDENTITY FIRST)
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: surface,
                      backgroundImage: _profileImagePath != null
                          ? FileImage(File(_profileImagePath!))
                          : null,
                      child: _profileImagePath == null
                          ? const Icon(
                              Icons.person_outline,
                              size: 50,
                              color: primary,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Upload Profile Photo'),
                              content: const Text('Choose photo source'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _pickImage(ImageSource.camera);
                                  },
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.camera_alt, size: 18),
                                      SizedBox(width: 6),
                                      Text('Camera'),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _pickImage(ImageSource.gallery);
                                  },
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.photo_library, size: 18),
                                      SizedBox(width: 6),
                                      Text('Gallery'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text( _userProfile?['name']?.toString() ?? 'Shri. Mahesh Patil', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary) ),
                const SizedBox(height: 4),
                Text( _userProfile?['mobile']?.toString() ?? '+91 9876543210', style: const TextStyle(color: textSecondary, fontSize: 15) ),
                const SizedBox(height: 8),
                // ROLE BADGE
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A5D6B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_outlined,
                        size: 14,
                        color: Color(0xFF8B4513),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Commissioner',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8B4513),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _JEConfig.employeeId,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 2️⃣ OFFICIAL ROLE SECTION
          _sectionCard(
            title: 'Official Role',
            icon: Icons.badge_outlined,
            children: [
              _infoRow('Department', 'Solapur Municipal Corporation'),
              const Divider(height: 16),
              _infoRow('Designation', 'Municipal Commissioner'),
              const Divider(height: 16),
              _infoRow('Employee ID', 'COM-SMC-2024-001'),
            ],
          ),
          const SizedBox(height: 16),

          // 3️⃣ JURISDICTION SECTION
          _sectionCard(
            title: 'Jurisdiction',
            icon: Icons.location_on_outlined,
            children: [
              const Text(
                'Administrative authority for entire Solapur city:',
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primary.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_city, color: primary),
                    SizedBox(width: 12),
                    Text(
                      'Solapur City - All Wards',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4️⃣ CITY OVERVIEW
          _sectionCard(
            title: 'City Overview',
            icon: Icons.assessment_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _impactStat(
                      'Total\nComplaints',
                      '312',
                      Icons.folder_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _impactStat(
                      'Pending\n>11 Days',
                      '23',
                      Icons.warning_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _impactStat(
                'System Efficiency',
                '91%',
                Icons.trending_up_outlined,
                fullWidth: true,
              ),
              const SizedBox(height: 12),
              _impactStat(
                'Citizen Satisfaction',
                '4.2/5',
                Icons.star_outline,
                fullWidth: true,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 5️⃣ REPORT QUALITY FEEDBACK
          _sectionCard(
            title: 'Report Quality',
            icon: Icons.star_outline,
            children: [
              _qualityIndicator(
                '📸  Image clarity',
                'Good',
                const Color(0xFF7DB89A),
              ),
              const SizedBox(height: 10),
              _qualityIndicator(
                '📍  Location accuracy',
                'High',
                const Color(0xFF7DB89A),
              ),
              const SizedBox(height: 10),
              _qualityIndicator(
                '❗  False reports',
                '0',
                const Color(0xFF7DB89A),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 6️⃣ NOTIFICATION & PREFERENCE CONTROLS
          _sectionCard(
            title: 'Notification Preferences',
            icon: Icons.notifications_outlined,
            children: [
              _toggleRow('Updates on my complaints', _notifyMyComplaints, (
                val,
              ) {
                setState(() => _notifyMyComplaints = val);
              }),
              const Divider(height: 20),
              _toggleRow('Road closure alerts near me', _notifyRoadAlerts, (
                val,
              ) {
                setState(() => _notifyRoadAlerts = val);
              }),
              const Divider(height: 20),
              _toggleRow('Monsoon / maintenance notices', _notifyMonsoon, (
                val,
              ) {
                setState(() => _notifyMonsoon = val);
              }),
            ],
          ),
          const SizedBox(height: 16),

          // 7️⃣ PERSONAL HISTORY ENTRY POINTS
          _sectionCard(
            title: 'History',
            icon: Icons.history_outlined,
            children: [
              _navigationTile(
                'My Complaints History',
                Icons.folder_outlined,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _ComplaintsHistoryScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 16),
              _navigationTile(
                'My Resolved Issues',
                Icons.check_circle_outline,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _ResolvedIssuesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 8️⃣ SECURITY & ACCOUNT CONTROLS
          _sectionCard(
            title: 'Security & Account',
            icon: Icons.security_outlined,
            children: [
              _navigationTile('Change phone number', Icons.phone_outlined, () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Change Phone Number'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TextField(
                          decoration: InputDecoration(
                            labelText: 'New Phone Number',
                            prefixText: '+91 ',
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('OTP sent to new number'),
                            ),
                          );
                        },
                        child: const Text('Send OTP'),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 16),
              _navigationTile('Re-verify identity', Icons.verified_outlined, () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Re-verify Identity'),
                    content: const Text(
                      'An OTP will be sent to your registered phone number +91 9876543210',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('OTP sent successfully'),
                            ),
                          );
                        },
                        child: const Text('Send OTP'),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 16),
              const Row(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 16,
                    color: textSecondary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your data is protected under municipal privacy policy',
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // 9️⃣ LOGOUT BUTTON
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx); // Close dialog
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (route) => false,
                          );
                        },
                        child: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: textSecondary, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _trustBadge(String title, String subtitle, Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: textSecondary)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _impactStat(
    String label,
    String value,
    IconData icon, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: fullWidth
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: primary),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Icon(icon, size: 22, color: primary),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _areaChip(String area) {
    return GestureDetector(
      onTap: () {
        // Map common areas to specific coordinates
        final Map<String, LatLng> areaCoords = {
          'MG Road': LatLng(17.6715, 75.9101),
          'Station Road': LatLng(17.6600, 75.9000),
          'Hotgi Road': LatLng(17.6550, 75.9150),
        };
        if (areaCoords.containsKey(area)) {
          widget.onLocationClick(areaCoords[area]!, 'AREA_$area');
        }
      },
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 14, color: primary),
          const SizedBox(width: 6),
          Text(
            area,
            style: const TextStyle(
              fontSize: 12,
              color: primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qualityIndicator(String label, String status, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: textPrimary)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _toggleRow(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: textPrimary),
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeColor: primary),
      ],
    );
  }

  Widget _navigationTile(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: textSecondary),
        ],
      ),
    );
  }
}

class _NotificationScreen extends StatelessWidget {
  const _NotificationScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _notifItem(
            'Your complaint CMP202601 is under review',
            'Just now',
            Icons.rate_review_outlined,
          ),
          _notifItem(
            'Road repair completed near MG Road',
            '1 hour ago',
            Icons.done_all_rounded,
          ),
          _notifItem(
            'Municipal Alert: Traffic diversion on Station Road',
            '3 hours ago',
            Icons.warning_amber_rounded,
          ),
          _notifItem(
            'Work started on your complaint CMP202603',
            '5 hours ago',
            Icons.construction_outlined,
          ),
        ],
      ),
    );
  }

  Widget _notifItem(String title, String time, IconData icon) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: primary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(time, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _TotalComplaintsOverview extends StatefulWidget {
  final Function(LatLng, String) onLocationClick;
  const _TotalComplaintsOverview({required this.onLocationClick});

  @override
  State<_TotalComplaintsOverview> createState() =>
      _TotalComplaintsOverviewState();
}

class _TotalComplaintsOverviewState extends State<_TotalComplaintsOverview> {
  int _touchedIndex = -1;
  int _selectedIndex = -1; // For persistent donut selection
  int _selectedLineIndex = -1; // For persistent line chart selection
  double _selectedLineX = -1; // X coordinate of selected point

  @override
  Widget build(BuildContext context) {
    // Analytics data
    final totalComplaints = DashboardMetrics.total(allComplaints);
    final resolved = DashboardMetrics.resolved(allComplaints);
    final workInProgress = DashboardMetrics.inProgress(allComplaints);
    final pendingApproval = DashboardMetrics.pending(allComplaints);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 1.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Total Complaints Overview',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: primary),
            onPressed: null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. FIXED TOP SUMMARY STRIP WITH PROPER SPACING
            Row(
              children: [
                _compactPill(
                  'Total',
                  '$totalComplaints',
                  const Color(0xFF7C8E9C),
                  const Color(0xFFE3E9ED),
                ),
                const SizedBox(width: 8),
                _compactPill(
                  'WIP',
                  '$workInProgress',
                  const Color(0xFFA89158),
                  const Color(0xFFF3EBDA),
                ),
                const SizedBox(width: 8),
                _compactPill(
                  'Pending',
                  '$pendingApproval',
                  const Color(0xFFB89D5F),
                  const Color(0xFFF5ECD9),
                ),
                const SizedBox(width: 8),
                _compactPill(
                  'Resolved',
                  '$resolved',
                  const Color(0xFF5D8A6D),
                  const Color(0xFFE1EFE5),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 2 & 3. FIXED DONUT CHART WITH LIGHTER COLORS AND PERSISTENT SELECTION
            const Text(
              'Complaint Status Distribution',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTapDown: (details) {
                // Detect tap outside chart to deselect
                setState(() {
                  _selectedIndex = -1;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: surface, width: 1),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (event is FlTapUpEvent) {
                                      // Persistent selection on tap
                                      if (pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection ==
                                              null) {
                                        return;
                                      }
                                      _selectedIndex = pieTouchResponse
                                          .touchedSection!
                                          .touchedSectionIndex;
                                    }
                                  });
                                },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 60,
                          sections: [
                            PieChartSectionData(
                              color: const Color(
                                0xFF7DB89A,
                              ), // Lighter muted green
                              value: resolved.toDouble(),
                              title: _selectedIndex == 0 ? '$resolved' : '',
                              radius: _selectedIndex == 0 ? 65 : 55,
                              titleStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              color: const Color(0xFFCBB17D), // Lighter amber
                              value: workInProgress.toDouble(),
                              title: _selectedIndex == 1
                                  ? '$workInProgress'
                                  : '',
                              radius: _selectedIndex == 1 ? 65 : 55,
                              titleStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              color: const Color(0xFFD4B97E), // Lighter sand
                              value: pendingApproval.toDouble(),
                              title: _selectedIndex == 2
                                  ? '$pendingApproval'
                                  : '',
                              radius: _selectedIndex == 2 ? 65 : 55,
                              titleStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Persistent detailed stats
                    _statusStatRow(
                      'Resolved',
                      resolved,
                      totalComplaints,
                      const Color(0xFF7DB89A),
                      _selectedIndex == 0,
                    ),
                    const SizedBox(height: 8),
                    _statusStatRow(
                      'Work InProgress',
                      workInProgress,
                      totalComplaints,
                      const Color(0xFFCBB17D),
                      _selectedIndex == 1,
                    ),
                    const SizedBox(height: 8),
                    _statusStatRow(
                      'Pending Approval',
                      pendingApproval,
                      totalComplaints,
                      const Color(0xFFD4B97E),
                      _selectedIndex == 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // COMBINED COMPLAINT TRENDS & PROGRESS GRAPH
            const Text(
              'Complaint Trends & Progress',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Multi-curve comparison across all complaint categories',
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 16),

            // Single unified container with multi-line chart
            GestureDetector(
              onTapDown: (details) {
                // Detect tap outside chart to deselect
                setState(() {
                  _selectedLineIndex = -1;
                  _selectedLineX = -1;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: surface, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Legend
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildLegendItem(
                          'Total Complaints',
                          const Color(0xFF7C8E9C),
                        ),
                        _buildLegendItem('Resolved', const Color(0xFF7DB89A)),
                        _buildLegendItem(
                          'Work InProgress',
                          const Color(0xFFCBB17D),
                        ),
                        _buildLegendItem(
                          'Pending/Paperwork',
                          const Color(0xFFD4B97E),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Show selected point details persistently
                    if (_selectedLineIndex != -1 && _selectedLineX >= 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: primary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, size: 16, color: primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getSelectedPointInfo(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      height: 240,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 2,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(color: surface, strokeWidth: 1);
                            },
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              axisNameWidget: const Text(
                                'Complaints',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                interval: 2,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(
                                      color: textSecondary,
                                      fontSize: 11,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text(
                                'Day of Week',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  const days = [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun',
                                  ];
                                  if (value.toInt() >= 0 &&
                                      value.toInt() < days.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        days[value.toInt()],
                                        style: const TextStyle(
                                          color: textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          maxY: 10,
                          lineTouchData: LineTouchData(
                            enabled: true,
                            handleBuiltInTouches: false,
                            touchSpotThreshold:
                                20, // Only detect points within 20px of touch
                            getTouchedSpotIndicator:
                                (
                                  LineChartBarData barData,
                                  List<int> spotIndexes,
                                ) {
                                  // Hide default indicators - we'll handle selection ourselves
                                  return spotIndexes.map((spotIndex) {
                                    return TouchedSpotIndicatorData(
                                      FlLine(color: Colors.transparent),
                                      FlDotData(show: false),
                                    );
                                  }).toList();
                                },
                            touchCallback:
                                (
                                  FlTouchEvent event,
                                  LineTouchResponse? response,
                                ) {
                                  if (event is FlTapUpEvent) {
                                    setState(() {
                                      if (response == null ||
                                          response.lineBarSpots == null ||
                                          response.lineBarSpots!.isEmpty) {
                                        return;
                                      }

                                      // Get touch position in pixels
                                      final touchY = event.localPosition.dy;

                                      // Chart dimensions (must match SizedBox height minus padding)
                                      const chartHeight = 240.0;
                                      const topPadding = 20.0;
                                      const bottomPadding = 40.0;
                                      const dataMinY = 0.0;
                                      const dataMaxY = 10.0;

                                      // Convert touch Y to data Y coordinate
                                      final usableHeight =
                                          chartHeight -
                                          topPadding -
                                          bottomPadding;
                                      final touchDataY =
                                          dataMaxY -
                                          ((touchY - topPadding) /
                                              usableHeight *
                                              (dataMaxY - dataMinY));

                                      // Get X position from first spot (all spots at same X)
                                      final touchedX =
                                          response.lineBarSpots!.first.x;

                                      // Data arrays for all curves
                                      const curveData = [
                                        [
                                          3.0,
                                          5.0,
                                          4.0,
                                          7.0,
                                          9.0,
                                          6.0,
                                          8.0,
                                        ], // Total (0)
                                        [
                                          2.0,
                                          3.0,
                                          3.0,
                                          5.0,
                                          6.0,
                                          5.0,
                                          7.0,
                                        ], // Resolved (1)
                                        [
                                          1.0,
                                          2.0,
                                          1.0,
                                          2.0,
                                          3.0,
                                          1.0,
                                          1.0,
                                        ], // WIP (2)
                                        [
                                          0.0,
                                          0.0,
                                          0.0,
                                          0.0,
                                          0.0,
                                          0.0,
                                          0.0,
                                        ], // Pending (3)
                                      ];

                                      // Find which curve is closest to touch Y
                                      final xIndex = touchedX.toInt();
                                      double minDistance = double.infinity;
                                      int closestCurve = 0;

                                      for (
                                        int i = 0;
                                        i < curveData.length;
                                        i++
                                      ) {
                                        final curveY = curveData[i][xIndex];
                                        final distance = (curveY - touchDataY)
                                            .abs();
                                        if (distance < minDistance) {
                                          minDistance = distance;
                                          closestCurve = i;
                                        }
                                      }

                                      _selectedLineIndex = closestCurve;
                                      _selectedLineX = touchedX;
                                    });
                                  }
                                },
                            touchTooltipData: LineTouchTooltipData(
                              // Completely disable fl_chart's built-in tooltips
                              getTooltipColor: (touchedSpot) =>
                                  Colors.transparent,
                              tooltipPadding: EdgeInsets.zero,
                              tooltipMargin: 0,
                              getTooltipItems: (spots) => [],
                            ),
                          ),
                          lineBarsData: [
                            // Total Complaints
                            _buildLineBarData(
                              0,
                              const [
                                FlSpot(0, 3),
                                FlSpot(1, 5),
                                FlSpot(2, 4),
                                FlSpot(3, 7),
                                FlSpot(4, 9),
                                FlSpot(5, 6),
                                FlSpot(6, 8),
                              ],
                              const Color(0xFF7C8E9C),
                              true,
                            ),
                            // Resolved Complaints
                            _buildLineBarData(
                              1,
                              const [
                                FlSpot(0, 2),
                                FlSpot(1, 3),
                                FlSpot(2, 3),
                                FlSpot(3, 5),
                                FlSpot(4, 6),
                                FlSpot(5, 5),
                                FlSpot(6, 7),
                              ],
                              const Color(0xFF7DB89A),
                              false,
                            ),
                            // Work InProgress
                            _buildLineBarData(
                              2,
                              const [
                                FlSpot(0, 1),
                                FlSpot(1, 2),
                                FlSpot(2, 1),
                                FlSpot(3, 2),
                                FlSpot(4, 3),
                                FlSpot(5, 1),
                                FlSpot(6, 1),
                              ],
                              const Color(0xFFCBB17D),
                              false,
                            ),
                            // Pending/Paperwork
                            _buildLineBarData(
                              3,
                              const [
                                FlSpot(0, 0),
                                FlSpot(1, 0),
                                FlSpot(2, 0),
                                FlSpot(3, 0),
                                FlSpot(4, 0),
                                FlSpot(5, 0),
                                FlSpot(6, 0),
                              ],
                              const Color(0xFFD4B97E),
                              false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // INSIGHT BLOCK
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECEF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withOpacity(0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: primary, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Highest complaints from MG Road & Station Road. Most cases involve potholes & surface cracks.',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // COMPLAINT LIST
            const Text(
              'All Complaints',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: List.generate(
                allComplaints.length,
                (index) => _ComplaintCard(
                  index: index,
                  data: allComplaints[index],
                  onLocationClick: (coords, id) {
                    Navigator.pop(context);
                    widget.onLocationClick(coords, id);
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _compactPill(String label, String value, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusStatRow(
    String label,
    int count,
    int total,
    Color color,
    bool isSelected,
  ) {
    final percentage = ((count / total) * 100).toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: color, width: 2) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($percentage%)',
            style: const TextStyle(
              fontSize: 13,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  LineChartBarData _buildLineBarData(
    int barIndex,
    List<FlSpot> spots,
    Color color,
    bool showBelowBar,
  ) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          // Check if THIS specific point on THIS specific curve is selected
          final isThisPointSelected =
              (_selectedLineIndex == barIndex && _selectedLineX == spot.x);

          if (isThisPointSelected) {
            // Selected point: Large, bold, very visible
            return FlDotCirclePainter(
              radius: 7,
              color: color,
              strokeWidth: 3,
              strokeColor: Colors.white,
            );
          } else {
            // Normal point: Small, subtle
            return FlDotCirclePainter(
              radius: 4,
              color: color,
              strokeWidth: 2,
              strokeColor: Colors.white,
            );
          }
        },
      ),
      belowBarData: BarAreaData(
        show: showBelowBar,
        color: color.withOpacity(0.08),
      ),
    );
  }

  String _getSelectedPointInfo() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const curveNames = [
      'Total Complaints',
      'Resolved',
      'Work InProgress',
      'Pending/Paperwork',
    ];

    // Data arrays matching the charts - MUST match the order of lineBarsData
    const dataArrays = [
      [3, 5, 4, 7, 9, 6, 8], // Total Complaints (barIndex 0)
      [2, 3, 3, 5, 6, 5, 7], // Resolved (barIndex 1)
      [1, 2, 1, 2, 3, 1, 1], // WIP (barIndex 2)
      [0, 0, 0, 0, 0, 0, 0], // Pending (barIndex 3)
    ];

    if (_selectedLineIndex >= 0 &&
        _selectedLineIndex < curveNames.length &&
        _selectedLineX >= 0) {
      final curveName = curveNames[_selectedLineIndex];
      final dayIndex = _selectedLineX.toInt();
      if (dayIndex >= 0 && dayIndex < days.length) {
        final day = days[dayIndex];
        final value = dataArrays[_selectedLineIndex][dayIndex];
        return '$curveName · $day · $value complaint${value == 1 ? "" : "s"}';
      }
    }
    return 'Tap any point to see details';
  }
}

class _ComplaintListView extends StatefulWidget {
  final String title;
  final String? filterStatus;
  final Function(LatLng, String) onLocationClick;

  const _ComplaintListView({
    required this.title,
    this.filterStatus,
    required this.onLocationClick,
  });

  @override
  State<_ComplaintListView> createState() => _ComplaintListViewState();
}

class _ComplaintListViewState extends State<_ComplaintListView> {
  bool _isTimeline = false;
  int _selectedPointIndex = -1;

  @override
  Widget build(BuildContext context) {
    final filteredComplaints = widget.filterStatus == null
        ? allComplaints
        : allComplaints
              .where((c) => c['status'] == widget.filterStatus)
              .toList();

    // Get trend data based on filter
    final trendData = _getTrendDataForStatus(widget.filterStatus);
    final trendColor = _getColorForStatus(widget.filterStatus);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isTimeline ? Icons.view_day_outlined : Icons.timeline_rounded,
              color: primary,
            ),
            onPressed: () => setState(() => _isTimeline = !_isTimeline),
            tooltip: _isTimeline
                ? 'Switch to Card View'
                : 'Switch to Timeline View',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isTimeline
          ? _buildTimeline(filteredComplaints)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // GRAPH SECTION
                GestureDetector(
                  onTapDown: (_) => setState(() => _selectedPointIndex = -1),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: trendColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 20,
                              decoration: BoxDecoration(
                                color: trendColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.title} Trend (Last 7 Days)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // PERSISTENT INFO BOX
                        if (_selectedPointIndex >= 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: trendColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: trendColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: trendColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getPointInfo(trendData),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: trendColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(
                          height: 150,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 2,
                                getDrawingHorizontalLine: (value) =>
                                    FlLine(color: surface, strokeWidth: 1),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) {
                                      if (value % 2 == 0) {
                                        return Text(
                                          '${value.toInt()}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: textSecondary,
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      const days = [
                                        'M',
                                        'T',
                                        'W',
                                        'T',
                                        'F',
                                        'S',
                                        'S',
                                      ];
                                      if (value.toInt() < days.length) {
                                        return Text(
                                          days[value.toInt()],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: textSecondary,
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              minX: 0,
                              maxX: 6,
                              minY: 0,
                              maxY: 10,
                              lineTouchData: LineTouchData(
                                enabled: true,
                                handleBuiltInTouches: false,
                                touchCallback:
                                    (
                                      FlTouchEvent event,
                                      LineTouchResponse? response,
                                    ) {
                                      if (event is FlTapUpEvent) {
                                        setState(() {
                                          if (response != null &&
                                              response.lineBarSpots != null &&
                                              response
                                                  .lineBarSpots!
                                                  .isNotEmpty) {
                                            _selectedPointIndex = response
                                                .lineBarSpots!
                                                .first
                                                .x
                                                .toInt();
                                          }
                                        });
                                      }
                                    },
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (_) => Colors.transparent,
                                  getTooltipItems: (_) => [],
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: trendData,
                                  isCurved: true,
                                  color: trendColor,
                                  barWidth: 3,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter:
                                        (spot, percent, bar, index) =>
                                            FlDotCirclePainter(
                                              radius:
                                                  _selectedPointIndex ==
                                                      spot.x.toInt()
                                                  ? 7
                                                  : 4,
                                              color: trendColor,
                                              strokeWidth:
                                                  _selectedPointIndex ==
                                                      spot.x.toInt()
                                                  ? 3
                                                  : 2,
                                              strokeColor: Colors.white,
                                            ),
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: trendColor.withOpacity(0.1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _miniStat(
                              'Total',
                              '${filteredComplaints.length}',
                              trendColor,
                            ),
                            _miniStat(
                              'Avg/Day',
                              '${(filteredComplaints.length / 7).toStringAsFixed(1)}',
                              trendColor,
                            ),
                            _miniStat(
                              'Peak',
                              _getPeakDay(trendData),
                              trendColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  'All ${widget.title} (${filteredComplaints.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...filteredComplaints.map(
                  (c) => _ComplaintCard(
                    index: filteredComplaints.indexOf(c),
                    data: c,
                    onLocationClick: (coords, id) {
                      Navigator.pop(context);
                      widget.onLocationClick(coords, id);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  String _getPointInfo(List<FlSpot> data) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (_selectedPointIndex >= 0 && _selectedPointIndex < data.length) {
      final value = data[_selectedPointIndex].y.toInt();
      return '${widget.title} · ${days[_selectedPointIndex]} · $value complaint${value == 1 ? "" : "s"}';
    }
    return '';
  }

  Widget _buildTimeline(List<Map<String, dynamic>> complaints) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: complaints.length,
      itemBuilder: (context, index) {
        final c = complaints[index];
        return IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  Expanded(
                    child: index != complaints.length - 1
                        ? Container(width: 2, color: primary.withOpacity(0.3))
                        : const SizedBox(),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['date'] ?? 'Jan 2026',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: accent,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        c['location'],
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          c['status'],
                          style: const TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: textSecondary)),
      ],
    );
  }

  String _getPeakDay(List<FlSpot> data) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    double maxY = 0;
    int maxIndex = 0;
    for (int i = 0; i < data.length; i++) {
      if (data[i].y > maxY) {
        maxY = data[i].y;
        maxIndex = i;
      }
    }
    return days[maxIndex];
  }

  List<FlSpot> _getTrendDataForStatus(String? status) {
    if (status == 'Physical Work') {
      return const [
        FlSpot(0, 1),
        FlSpot(1, 2),
        FlSpot(2, 1),
        FlSpot(3, 2),
        FlSpot(4, 3),
        FlSpot(5, 1),
        FlSpot(6, 1),
      ];
    } else if (status == 'Resolved') {
      return const [
        FlSpot(0, 2),
        FlSpot(1, 3),
        FlSpot(2, 3),
        FlSpot(3, 5),
        FlSpot(4, 6),
        FlSpot(5, 5),
        FlSpot(6, 7),
      ];
    }
    return const [
      FlSpot(0, 3),
      FlSpot(1, 5),
      FlSpot(2, 4),
      FlSpot(3, 7),
      FlSpot(4, 9),
      FlSpot(5, 6),
      FlSpot(6, 8),
    ];
  }

  Color _getColorForStatus(String? status) {
    if (status == 'Physical Work') return const Color(0xFFCBB17D);
    if (status == 'Resolved') return const Color(0xFF7DB89A);
    return const Color(0xFF7C8E9C);
  }
}

class _ResolutionRateDetailView extends StatefulWidget {
  const _ResolutionRateDetailView();

  @override
  State<_ResolutionRateDetailView> createState() =>
      _ResolutionRateDetailViewState();
}

class _ResolutionRateDetailViewState extends State<_ResolutionRateDetailView> {
  int _selectedTrendIndex = -1;

  @override
  Widget build(BuildContext context) {
    const trendData = [
      FlSpot(0, 58),
      FlSpot(1, 62),
      FlSpot(2, 65),
      FlSpot(3, 68),
      FlSpot(4, 70),
      FlSpot(5, 72),
    ];
    const months = ['Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan'];
    const trendColor = Color(0xFF385E44);
    final totalComplaints = DashboardMetrics.total(allComplaints);
    final resolvedCount = DashboardMetrics.resolved(allComplaints);
    final workInProgress = DashboardMetrics.inProgress(allComplaints);
    final pendingReview = DashboardMetrics.pending(allComplaints);
    final resolutionRate = DashboardMetrics.resolutionRateLabel(allComplaints);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Resolution Analysis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFDCE4DD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF385E44).withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Current Resolution Rate',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resolutionRate,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF385E44),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _calcRow('Total Complaints Reported', '$totalComplaints'),
                  _calcRow('Successfully Resolved', '$resolvedCount'),
                  _calcRow('Work Currently InProgress', '$workInProgress'),
                  _calcRow('Pending Initial Review', '$pendingReview'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // DONUT CHART FOR BREAKDOWN
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status Distribution',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 45,
                        sections: [
                          PieChartSectionData(
                            color: const Color(0xFF7DB89A),
                            value: DashboardMetrics.chartValue(
                              resolvedCount,
                              totalComplaints,
                            ),
                            title: DashboardMetrics.percentageLabel(
                              resolvedCount,
                              totalComplaints,
                            ),
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: const Color(0xFFCBB17D),
                            value: DashboardMetrics.chartValue(
                              workInProgress,
                              totalComplaints,
                            ),
                            title: DashboardMetrics.percentageLabel(
                              workInProgress,
                              totalComplaints,
                            ),
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: const Color(0xFFD4B97E),
                            value: DashboardMetrics.chartValue(
                              pendingReview,
                              totalComplaints,
                            ),
                            title: DashboardMetrics.percentageLabel(
                              pendingReview,
                              totalComplaints,
                            ),
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _legendItem('Resolved', const Color(0xFF7DB89A)),
                      _legendItem('InProgress', const Color(0xFFCBB17D)),
                      _legendItem('Pending', const Color(0xFFD4B97E)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // MONTHLY TREND
            GestureDetector(
              onTapDown: (_) => setState(() => _selectedTrendIndex = -1),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resolution Rate Trend (6 Months)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // PERSISTENT INFO BOX
                    if (_selectedTrendIndex >= 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: trendColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: trendColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: trendColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Resolution Rate · ${months[_selectedTrendIndex]} · ${trendData[_selectedTrendIndex].y.toInt()}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      height: 150,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 20,
                            getDrawingHorizontalLine: (value) =>
                                FlLine(color: background, strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 35,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: textSecondary,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() < months.length) {
                                    return Text(
                                      months[value.toInt()],
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: textSecondary,
                                      ),
                                    );
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 5,
                          minY: 0,
                          maxY: 100,
                          lineTouchData: LineTouchData(
                            enabled: true,
                            handleBuiltInTouches: false,
                            touchCallback:
                                (
                                  FlTouchEvent event,
                                  LineTouchResponse? response,
                                ) {
                                  if (event is FlTapUpEvent) {
                                    setState(() {
                                      if (response != null &&
                                          response.lineBarSpots != null &&
                                          response.lineBarSpots!.isNotEmpty) {
                                        _selectedTrendIndex = response
                                            .lineBarSpots!
                                            .first
                                            .x
                                            .toInt();
                                      }
                                    });
                                  }
                                },
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => Colors.transparent,
                              getTooltipItems: (_) => [],
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: trendData,
                              isCurved: true,
                              color: trendColor,
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) =>
                                    FlDotCirclePainter(
                                      radius:
                                          _selectedTrendIndex == spot.x.toInt()
                                          ? 7
                                          : 4,
                                      color: trendColor,
                                      strokeWidth:
                                          _selectedTrendIndex == spot.x.toInt()
                                          ? 3
                                          : 2,
                                      strokeColor: Colors.white,
                                    ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: trendColor.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Improving +14% over 6 months',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF385E44),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'How it is calculated?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              'The resolution rate is calculated based on the number of successfully resolved complaints against the total verified complaints received by the municipal corporation.',
              style: TextStyle(color: textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              color: surface.withOpacity(0.5),
              child: Center(
                child: Text(
                  DashboardMetrics.resolutionFormula(allComplaints),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Maintenance Efficiency',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            _perfItem('Pothole Filling', 0.88),
            _perfItem('Surface Patching', 0.72),
            _perfItem('Speed Breaker Repair', 0.91),
            _perfItem('Highway Crack Sealing', 0.58),
            _perfItem('Road Shoulder Leveling', 0.45),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: textSecondary)),
      ],
    );
  }

  Widget _calcRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: textPrimary)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _perfItem(String label, double progress) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: surface,
            color: primary,
            minHeight: 6,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: textPrimary.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic>? data;
  final Function(LatLng, String) onLocationClick;
  const _ComplaintCard({
    required this.index,
    this.data,
    required this.onLocationClick,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null && allComplaints.isEmpty) {
      return const SizedBox.shrink();
    }
    final c = data ?? allComplaints[index % allComplaints.length];
    final List<String> images = (c['images'] as List).cast<String>();

    Color severityColor;
    switch (c['severity']) {
      case 'High':
        severityColor = Colors.red.shade700;
        break;
      case 'Medium':
        severityColor = Colors.orange.shade700;
        break;
      default:
        severityColor = Colors.green.shade700;
    }
    Color statusColor;
    switch (c['status']) {
      case 'Resolved':
        statusColor = Colors.green.shade700;
        break;
      case 'Pending':
        statusColor = accent;
        break;
      default:
        statusColor = primary;
    }
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _ComplaintDetailScreen(
              data: c,
              onLocationClick: onLocationClick,
            ),
          ),
        );
      },
      child: Card(
        color: Colors.white,
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 20),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel
            SizedBox(
              height: 180,
              child: PageView.builder(
                itemCount: images.length,
                controller: PageController(viewportFraction: 0.95),
                padEnds: false,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image(
                        image: _complaintImageProvider(images[i].toString()),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: surface,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: textSecondary,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Road damage image",
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        c['id']!.toString(),
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c['severity']!.toString(),
                          style: TextStyle(
                            color: severityColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    c['title']!.toString(),
                    style: const TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      if (c['coords'] != null) {
                        onLocationClick(c['coords'], c['id']);
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            c['location']!.toString(),
                            style: const TextStyle(
                              color: primary,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      c['status']!.toString(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// REPORT DAMAGE SCREEN
class _ReportDamageScreen extends StatefulWidget {
  const _ReportDamageScreen();

  @override
  State<_ReportDamageScreen> createState() => _ReportDamageScreenState();
}

class _ReportDamageScreenState extends State<_ReportDamageScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = '';
  final _otherCategoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<XFile> _selectedPhotos = [];
  final List<Position?> _photoLocations = [];
  final ImagePicker _picker = ImagePicker();
  bool _isDetectingLocation = false;

  final categories = [
    'Pothole',
    'Road Crack',
    'Surface Damage',
    'Waterlogging',
    'Speed Breaker Issue',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Report Road Damage',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SINGLE LARGE CAMERA BUTTON
              GestureDetector(
                onTap: _addPhotos,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary.withOpacity(0.08),
                        primary.withOpacity(0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedPhotos.isEmpty
                          ? primary
                          : primary.withOpacity(0.6),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_a_photo_rounded,
                          color: primary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isDetectingLocation)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primary,
                            ),
                          ),
                        ),
                      Text(
                        _isDetectingLocation
                            ? 'Detecting Location...'
                            : 'Tap to Add Photos',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Take photos of road damage',
                        style: TextStyle(fontSize: 13, color: textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC75D5D).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Required: 2-3 photos',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFC75D5D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // PHOTO PREVIEWS
              if (_selectedPhotos.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Captured Locations:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                ..._photoLocations
                    .asMap()
                    .entries
                    .where((e) => e.value != null)
                    .map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Photo ${e.key + 1}: ${e.value!.latitude.toStringAsFixed(6)}, ${e.value!.longitude.toStringAsFixed(6)} (Verified)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _selectedPhotos.asMap().entries.map((entry) {
                    final hasLocation = _photoLocations[entry.key] != null;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            image: DecorationImage(
                              image: FileImage(File(entry.value.path)),
                              fit: BoxFit.cover,
                            ),
                            border: Border.all(
                              color: primary.withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                        ),
                        // Aesthetic Location Badge
                        if (hasLocation)
                          Positioned(
                            bottom: 6,
                            left: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF7DB89A),
                                    size: 10,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      '${_photoLocations[entry.key]!.latitude.toStringAsFixed(4)},${_photoLocations[entry.key]!.longitude.toStringAsFixed(4)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Close Button Aesthetic
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPhotos.removeAt(entry.key);
                                _photoLocations.removeAt(entry.key);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC75D5D),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
              if (_selectedPhotos.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '⚠ At least 2 photos are required',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFFC75D5D),
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              // DAMAGE TYPE
              const Text(
                'Damage Type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select the type of road damage',
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: primary.withOpacity(0.2),
                    backgroundColor: surface,
                    side: BorderSide(
                      color: isSelected ? primary : Colors.transparent,
                      width: 1.5,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? primary : textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = cat;
                          if (cat != 'Other') {
                            _otherCategoryController.clear();
                          }
                        });
                      }
                    },
                  );
                }).toList(),
              ),

              // SHOW TEXT INPUT IF "OTHER" IS SELECTED
              if (_selectedCategory == 'Other') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _otherCategoryController,
                  decoration: InputDecoration(
                    hintText: 'Specify the type of road damage',
                    filled: true,
                    fillColor: surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primary.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (_selectedCategory == 'Other' &&
                        (value?.isEmpty ?? true)) {
                      return 'Please specify the damage type';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),

              // DESCRIPTION (MANDATORY)
              const Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Describe the road damage in detail',
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Example: Large pothole causing vehicle damage, approximately 2 feet wide...',
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: const Color(0xFFC75D5D),
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please provide a description';
                  }
                  if (value!.length < 10) {
                    return 'Please provide more details (at least 10 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Submit Report',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Your report will be reviewed within 24-48 hours',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _addPhotos() async {
    if (_selectedPhotos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠ Maximum 3 photos allowed'),
          backgroundColor: Color(0xFFC75D5D),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw 'No cameras found';
      }

      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => _CameraScreen(cameras: cameras),
        ),
      );

      if (result != null) {
        final XFile photo = result['image'];
        final Position? position = result['position'];

        setState(() {
          _selectedPhotos.add(photo);
          _photoLocations.add(position);
        });

        if (position != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Photo captured with verified location!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2E5A3D),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera Error: ${e.toString()}'),
          backgroundColor: const Color(0xFFC75D5D),
        ),
      );
    }
  }

  void _submitReport() {
    // VALIDATE PHOTOS (MINIMUM 2)
    if (_selectedPhotos.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠ Please add at least 2 photos'),
          backgroundColor: Color(0xFFC75D5D),
        ),
      );
      return;
    }

    // VALIDATE DAMAGE TYPE
    if (_selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠ Please select a damage type'),
          backgroundColor: Color(0xFFC75D5D),
        ),
      );
      return;
    }

    // VALIDATE FORM (OTHER TEXT FIELD)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // SUCCESS
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7DB89A).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF7DB89A),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Report Submitted', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thank you for reporting road damage.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Your complaint has been registered and will be reviewed by municipal officials within 24-48 hours.',
              style: TextStyle(color: textSecondary, height: 1.4),
            ),
            if (_photoLocations.any((loc) => loc != null)) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFF7DB89A),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Real-time location detected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E5A3D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Builder(
                builder: (context) {
                  final loc = _photoLocations.firstWhere((l) => l != null);
                  return Text(
                    'Location: ${loc!.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)} (High Accuracy)',
                    style: const TextStyle(fontSize: 11, color: textSecondary),
                  );
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'OK',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// IMAGE PREVIEW SCREEN (FULL-SCREEN SWIPEABLE GALLERY)
class _ImagePreviewScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ImagePreviewScreen({required this.images, required this.initialIndex});

  @override
  State<_ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<_ImagePreviewScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Image ${_currentIndex + 1} of ${widget.images.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image(
                image: _complaintImageProvider(widget.images[index].toString()),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      size: 80,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Image not available',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// COMPLAINTS HISTORY SCREEN
class _ComplaintsHistoryScreen extends StatelessWidget {
  const _ComplaintsHistoryScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'My Complaints History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _historyCard(
            'CMP202601',
            'Pothole on MG Road',
            'InProgress',
            '2 days ago',
          ),
          _historyCard(
            'CMP202605',
            'Broken speed breaker',
            'Under Review',
            '5 days ago',
          ),
          _historyCard(
            'CMP202603',
            'Damaged road sign',
            'Resolved',
            '1 week ago',
          ),
          _historyCard(
            'CMP202599',
            'Large crack on Highway',
            'Resolved',
            '2 weeks ago',
          ),
        ],
      ),
    );
  }

  Widget _historyCard(String id, String title, String status, String date) {
    Color statusColor;
    switch (status) {
      case 'InProgress':
        statusColor = const Color(0xFF4A90D9);
        break;
      case 'Under Review':
        statusColor = const Color(0xFF757575);
        break;
      case 'Resolved':
        statusColor = const Color(0xFF7DB89A);
        break;
      default:
        statusColor = textSecondary;
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  id,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time, size: 13, color: textSecondary),
                const SizedBox(width: 4),
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// RESOLVED ISSUES SCREEN
class _ResolvedIssuesScreen extends StatelessWidget {
  const _ResolvedIssuesScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'My Resolved Issues',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _resolvedCard(
            'CMP202603',
            'Damaged road sign',
            '1 week ago',
            '5 days',
          ),
          _resolvedCard(
            'CMP202599',
            'Large crack on Highway',
            '2 weeks ago',
            '4 days',
          ),
          _resolvedCard(
            'CMP202591',
            'Pothole near school',
            '3 weeks ago',
            '6 days',
          ),
        ],
      ),
    );
  }

  Widget _resolvedCard(
    String id,
    String title,
    String resolvedDate,
    String resolutionTime,
  ) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  id,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7DB89A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: Color(0xFF7DB89A),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Resolved',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7DB89A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  size: 14,
                  color: textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Resolved in $resolutionTime',
                  style: const TextStyle(fontSize: 12, color: textSecondary),
                ),
                const Spacer(),
                Text(
                  resolvedDate,
                  style: const TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// REAL CAMERA SCREEN FOR WEB AND MOBILE
class _CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _CameraScreen({required this.cameras});

  @override
  State<_CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<_CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  int _selectedCameraIndex = 0;
  XFile? _capturedImage;
  Position? _currentPosition;
  bool _isTakingPicture = false;
  bool _isDetectingLocation = false;

  @override
  void initState() {
    super.initState();
    _initCamera(_selectedCameraIndex);
  }

  void _initCamera(int index) {
    _controller = CameraController(
      widget.cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCamera() {
    if (widget.cameras.length < 2) return;
    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
      _initCamera(_selectedCameraIndex);
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isDetectingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isDetectingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isDetectingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _isDetectingLocation = false;
      });
    } catch (e) {
      debugPrint(e.toString());
      setState(() => _isDetectingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _capturedImage == null ? 'Capture Damage' : 'Review Photo',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_capturedImage == null && widget.cameras.length > 1)
            IconButton(
              icon: const Icon(
                Icons.flip_camera_ios_rounded,
                color: Colors.white,
              ),
              onPressed: _toggleCamera,
            ),
        ],
      ),
      body: _capturedImage == null
          ? _buildCameraPreview()
          : _buildImagePreview(),
    );
  }

  Widget _buildCameraPreview() {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Stack(
            children: [
              Center(child: CameraPreview(_controller)),
              // Camera Overlay UI
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Center(
                    child: _isTakingPicture
                        ? const CircularProgressIndicator(color: Colors.white)
                        : GestureDetector(
                            onTap: () async {
                              try {
                                setState(() => _isTakingPicture = true);
                                await _initializeControllerFuture;
                                final image = await _controller.takePicture();
                                await _getCurrentLocation();
                                setState(() {
                                  _capturedImage = image;
                                  _isTakingPicture = false;
                                });
                              } catch (e) {
                                setState(() => _isTakingPicture = false);
                                debugPrint(e.toString());
                              }
                            },
                            child: Container(
                              height: 80,
                              width: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                color: Colors.white24,
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
      },
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(_capturedImage!.path), fit: BoxFit.contain),
              // Location Tag Overlay
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Verified Location',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _isDetectingLocation
                                ? const Text(
                                    'Detecting...',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  )
                                : Text(
                                    _currentPosition != null
                                        ? '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}'
                                        : 'Location not found',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _capturedImage = null;
                      _currentPosition = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Retake',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'image': _capturedImage,
                      'position': _currentPosition,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Use Photo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}



