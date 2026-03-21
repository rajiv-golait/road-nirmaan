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
import '../../services/ai_recommendation_service.dart';
import '../../services/flask_ai_service.dart';
import '../../utils/app_flags.dart';
import '../../utils/map_tile_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Color palette (top-level for all widgets)
const Color primary = Color(0xFF4A5D6B);
const Color accent = Color(0xFFC9A24D);
const Color background = Color(0xFFF6F4EF);
const Color surface = Color(0xFFE7E2D8);
const Color textPrimary = Color(0xFF2B2B2B);
const Color textSecondary = Color(0xFF6F6F6F);

List<Map<String, dynamic>> get allComplaints =>
    LegacyDashboardAdapter.detailComplaints(ComplaintStore.instance.complaints);

ImageProvider<Object> _complaintImageProvider(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  if (path.startsWith('file://')) {
    return FileImage(File(path.replaceFirst('file://', '')));
  }
  if (path.startsWith('/') || path.contains(':\\')) {
    return FileImage(File(path));
  }
  return AssetImage(path);
}

class CitizenDashboard extends StatefulWidget {
  const CitizenDashboard({super.key});

  @override
  State<CitizenDashboard> createState() => _CitizenDashboardState();
}

class _CitizenDashboardState extends State<CitizenDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<_MapViewState> _mapKey = GlobalKey<_MapViewState>();

  final List<String> _titles = [
    'Citizen Home',
    'Track Complaints',
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
        builder: (context, _) => IndexedStack(
          index: _selectedIndex,
          children: [
            _HomeView(onLocationClick: _jumpToLocationOnMap),
            _TrackView(onLocationClick: _jumpToLocationOnMap),
            _MapView(key: _mapKey, onLocationClick: _jumpToLocationOnMap),
            const _ActivityView(),
            _ProfileView(onLocationClick: _jumpToLocationOnMap),
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
            icon: Icon(Icons.track_changes_rounded),
            label: 'Track',
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

  List<Map<String, dynamic>> get _dashboardComplaints => allComplaints;
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
              label: 'Work in Progress',
              value: '$_workInProgress',
              color: const Color(0xFF7D622A), // Darker authoritative amber
              bgColor: const Color(0xFFEBDDBE), // Stronger muted sand
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _ComplaintListView(
                    title: 'Work in Progress',
                    filterStatus: 'In Progress',
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

class _TrackView extends StatelessWidget {
  final Function(LatLng, String) onLocationClick;
  const _TrackView({super.key, required this.onLocationClick});

  static List<Map<String, dynamic>> get myComplaints =>
      LegacyDashboardAdapter.citizenMyComplaints();

  static List<Map<String, dynamic>> get otherComplaints =>
      LegacyDashboardAdapter.citizenOtherComplaints();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // MY COMPLAINTS SECTION
        const Text(
          'My Complaints',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Complaints submitted by you',
          style: TextStyle(fontSize: 13, color: textSecondary),
        ),
        const SizedBox(height: 12),
        ...myComplaints.map(
          (c) => _ComplaintTrackCard(data: c, onLocationClick: onLocationClick),
        ),

        const SizedBox(height: 24),

        // OTHER COMPLAINTS SECTION
        const Text(
          'Other Complaints Near You',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Public complaints in your area',
          style: TextStyle(fontSize: 13, color: textSecondary),
        ),
        const SizedBox(height: 12),
        ...otherComplaints.map(
          (c) => _ComplaintTrackCard(data: c, onLocationClick: onLocationClick),
        ),
      ],
    );
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
      case 'In Progress':
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
  Map<String, dynamic> get _currentComplaint {
    final complaintId = widget.data['id']?.toString();
    if (complaintId == null || complaintId.isEmpty) return widget.data;
    return ComplaintStore.instance.getComplaintById(complaintId) ?? widget.data;
  }

  Future<void> _toggleUpvote() async {
    final complaintId = _currentComplaint['id']?.toString();
    if (complaintId == null || complaintId.isEmpty) return;
    await ComplaintStore.instance.toggleUpvote(complaintId);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteComplaint() async {
    final complaintId = _currentComplaint['id']?.toString();
    if (complaintId == null || complaintId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Complaint'),
        content: const Text(
          'This complaint will be removed from all dashboards. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC75D5D),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ComplaintStore.instance.deleteComplaint(complaintId);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Complaint deleted successfully')),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Under Review':
        return const Color(0xFF757575);
      case 'Pending Approval':
        return Colors.orange;
      case 'Pending':
        return const Color(0xFFCBB17D);
      case 'In Progress':
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
    final complaint = _currentComplaint;
    final statusColor = _getStatusColor(complaint['status'] ?? 'Pending');
    final timeline = complaint['timeline'] as List<dynamic>? ?? [];
    final isMine = complaint['isMine'] as bool? ?? false;
    final verificationRemarks =
        complaint['verificationRemarks'] as List<dynamic>?;
    final officialRemarks = complaint['officialRemarks'] as String?;
    final images = (complaint['images'] as List<dynamic>? ?? const [])
        .cast<String>();
    final upvoteCount = (complaint['upvotes'] as num?)?.toInt() ?? 0;
    final hasUpvoted = complaint['hasUpvoted'] == true;

    // Handle location being either String or LatLng
    String locationText = 'Location details not available';
    if (complaint['location'] is String) {
      locationText = complaint['location'];
    } else if (complaint['address'] is String) {
      locationText = complaint['address'];
    } else if (complaint['location'] != null) {
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
        actions: [
          if (isMine)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFC75D5D)),
              tooltip: 'Delete complaint',
              onPressed: _deleteComplaint,
            ),
        ],
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
                        'Complaint ID: ${complaint['id']}',
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
                          complaint['status'] ?? 'Pending',
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
                    complaint['title'] ?? 'N/A',
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
                      if (complaint['coords'] != null) {
                        Navigator.pop(context);
                        widget.onLocationClick(
                          complaint['coords'],
                          complaint['id'],
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
                          isMine
                              ? 'Reported by you'
                              : 'Reported by another citizen',
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
            if (images.isNotEmpty) ...[
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
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final imagePath = images[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _ImagePreviewScreen(
                              images: images,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 130,
                        margin: EdgeInsets.only(
                          right: index < images.length - 1 ? 10 : 0,
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
                            image: _complaintImageProvider(imagePath),
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
      case 'In Progress':
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
                  _legendItem('In Progress', Colors.blue),
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
  // Demo-only municipal feed (debug + ALLOW_MOCK_DATA); see [AppFlags.showAssetDemoUi].
  static const Map<String, dynamic> _pinnedDemo = {
    'title': 'Night road works scheduled from 10 PM – 5 AM across city zones',
    'timestamp': 'Updated 3 hours ago',
  };

  static Map<String, dynamic>? get pinnedUpdate =>
      AppFlags.showAssetDemoUi ? _pinnedDemo : null;

  // Activity timeline data (ALL ROAD-RELATED UPDATES)
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
            'Municipal Corporation has initiated pothole repair work on Hotgi Road following multiple citizen complaints. The repair crew has been deployed and work is currently in progress.\n\nWork Details:\n- Location: Hotgi Road, near Siddheshwar Temple\n- Expected completion: 2 days\n- Work timings: 8 AM - 6 PM\n\nMinor traffic delays are expected during work hours. Motorists are requested to exercise caution.',
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

  static List<Map<String, dynamic>> get activities =>
      AppFlags.showAssetDemoUi ? _demoActivities : <Map<String, dynamic>>[];

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
              'No demo activity feed. Run a debug build with ALLOW_MOCK_DATA=true for sample stories, or connect official announcements via Supabase.',
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
                Text( _userProfile?['name']?.toString() ?? 'Rajesh Kumar', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary) ),
                const SizedBox(height: 4),
                Text( _userProfile?['mobile']?.toString() ?? '+91 9876543210', style: const TextStyle(color: textSecondary, fontSize: 15) ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7DB89A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: Color(0xFF7DB89A)),
                      SizedBox(width: 4),
                      Text(
                        'Verified Citizen',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7DB89A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 2️⃣ CITIZEN CREDIBILITY / TRUST SECTION
          _sectionCard(
            title: 'Citizen Status',
            icon: Icons.verified_user_outlined,
            children: [
              _trustBadge(
                '🟢  Verified Citizen',
                'Identity confirmed via OTP',
                const Color(0xFF7DB89A),
              ),
              const SizedBox(height: 10),
              _trustBadge(
                '🏅  Active Reporter',
                'Regular contributor',
                const Color(0xFF4A90D9),
              ),
              const SizedBox(height: 10),
              _trustBadge(
                '⭐  Trusted Contributor',
                'High-quality reports',
                accent,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3️⃣ PERSONAL IMPACT SUMMARY
          _sectionCard(
            title: 'Personal Impact Summary',
            icon: Icons.assessment_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _impactStat(
                      'Complaints\nRaised',
                      '12',
                      Icons.report_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _impactStat(
                      'Issues\nResolved',
                      '8',
                      Icons.check_circle_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _impactStat(
                'Average Resolution Time',
                '4.5 days',
                Icons.schedule_outlined,
                fullWidth: true,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4️⃣ "YOUR IMPACT ON THE CITY" SECTION
          _sectionCard(
            title: 'Your Impact on the City',
            icon: Icons.location_city_outlined,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.celebration_outlined, color: primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your reports helped fix roads in 3 locations.',
                        style: TextStyle(
                          fontSize: 14,
                          color: textPrimary,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Areas improved:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              _areaChip('MG Road'),
              const SizedBox(height: 6),
              _areaChip('Station Road'),
              const SizedBox(height: 6),
              _areaChip('Hotgi Road'),
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
                      'Work in Progress',
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
                          'Work in Progress',
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
                            // Work in Progress
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
      'Work in Progress',
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
                  _calcRow('Work Currently in Progress', '$workInProgress'),
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
                      _legendItem('In Progress', const Color(0xFFCBB17D)),
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

    final double? scoreVal = (c['severityScore'] as num?)?.toDouble();
    final Color severityColor;
    if (scoreVal != null) {
      severityColor = scoreVal >= 7
          ? Colors.red.shade700
          : scoreVal >= 4
          ? Colors.orange.shade700
          : Colors.green.shade700;
    } else {
      switch (c['severity']?.toString()) {
        case 'High':
        case 'Critical':
          severityColor = Colors.red.shade700;
          break;
        case 'Medium':
          severityColor = Colors.orange.shade700;
          break;
        default:
          severityColor = Colors.green.shade700;
      }
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
                              image: kIsWeb
                                  ? NetworkImage(entry.value.path)
                                        as ImageProvider
                                  : FileImage(File(entry.value.path)),
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
      if (kIsWeb) {
        final picker = ImagePicker();
        final List<XFile> images = await picker.pickMultiImage();
        if (images.isNotEmpty) {
          setState(() {
            for (var img in images) {
              if (_selectedPhotos.length < 3) {
                _selectedPhotos.add(img);
                // On web, just add a dummy location since GPS isn't guaranteed
                _photoLocations.add(
                  Position(
                    longitude: 75.9064,
                    latitude: 17.6599,
                    timestamp: DateTime.now(),
                    accuracy: 1,
                    altitude: 1,
                    heading: 1,
                    speed: 1,
                    speedAccuracy: 1,
                    altitudeAccuracy: 1,
                    headingAccuracy: 1,
                    isMocked: true,
                  ),
                );
              }
            }
          });
        }
        return;
      }

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

  Future<void> _submitReport() async {
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

    final effectiveCategory = _selectedCategory == 'Other'
        ? _otherCategoryController.text.trim()
        : _selectedCategory;
    final primaryPosition = _photoLocations.whereType<Position>().isNotEmpty
        ? _photoLocations.whereType<Position>().first
        : null;

    LatLng? coords;
    bool locationIsApproximate = false;

    if (primaryPosition != null) {
      coords = LatLng(primaryPosition.latitude, primaryPosition.longitude);
    } else {
      // FIX 2: Show blocking dialog — do not silently use hardcoded coordinates
      final useApproximate = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Location unavailable'),
          content: const Text(
            'Could not get your GPS location. '
            'Use approximate Solapur city center '
            'coordinates instead? '
            'Your report will still be submitted '
            'but location may be inaccurate.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use approximate')),
          ],
        ),
      );

      if (useApproximate != true) return; // abort submit

      coords = LatLng(17.6868, 75.9074);
      locationIsApproximate = true;
    }

    final locationText = coords != null
        ? '${coords.latitude.toStringAsFixed(6)}, ${coords.longitude.toStringAsFixed(6)}'
        : 'Location not detected';
    final localPaths = _selectedPhotos.map((photo) => photo.path).toList();
    final lat = coords?.latitude ?? 17.6868;
    final lng = coords?.longitude ?? 75.9074;

    try {
      final nearby = await ComplaintStore.instance.findNearbyOpenComplaints(
        latitude: lat,
        longitude: lng,
      );
      final nearbyPayload = nearby.map((item) {
        final c = item['coords'] as LatLng?;
        return <String, dynamic>{
          'id': item['id']?.toString(),
          'lat': c?.latitude,
          'lng': c?.longitude,
          'status': item['status']?.toString(),
        };
      }).toList();
      final dedup = await FlaskAiService.checkDuplicate(
        latitude: lat,
        longitude: lng,
        nearbyComplaints: nearbyPayload,
      );
      if ((dedup['is_duplicate'] == true) &&
          (dedup['master_id']?.toString().isNotEmpty == true)) {
        await ComplaintStore.instance.addEvidenceToComplaint(
          complaintId: dedup['master_id'].toString(),
          localImagePaths: localPaths,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Duplicate complaint found. Evidence attached to existing complaint.',
            ),
            backgroundColor: primary,
          ),
        );
        return;
      }
    } catch (e) {
      // FIX 6: Duplicate check failed — ask user what to do
      final proceedAnyway = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Duplicate check unavailable'),
          content: const Text(
            'Could not check for nearby reports. '
            'Do you want to submit anyway? '
            'Your report might be a duplicate.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit anyway')),
          ],
        ),
      );
      if (proceedAnyway != true) return;
      // User explicitly chose to proceed — that's fine
    }

    Map<String, dynamic>? aiResult;
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analyzing images with AI...'),
            backgroundColor: primary,
            duration: Duration(seconds: 3),
          ),
        );
      }
      aiResult = await FlaskAiService.analyzeImages(
        images: _selectedPhotos,
        latitude: lat,
        longitude: lng,
      );
    } catch (e) {
      debugPrint('AI Analysis fallback to local model: $e');
      try {
        aiResult = await AiRecommendationService.instance.analyzeSingleImage(
          imagePath: localPaths.first,
          latitude: lat,
          longitude: lng,
        );
      } catch (fallbackErr) {
        debugPrint('Local AI fallback failed: $fallbackErr');
      }
    }

    String? severity;
    double? severityScore;
    double? epdoScore;
    int? totalPotholes;
    String? aiPriority;
    String? aiSource;

    if (aiResult != null && aiResult['success'] == true) {
      final String priority = aiResult['priority']?.toString() ?? 'MEDIUM';
      aiPriority = aiResult['priority']?.toString();
      severity = priority == 'CRITICAL'
          ? 'Critical'
          : priority == 'HIGH'
          ? 'High'
          : priority == 'LOW'
          ? 'Low'
          : 'Medium';
      severityScore = (aiResult['severity_score'] as num?)?.toDouble();
      epdoScore = (aiResult['epdo_score'] as num?)?.toDouble() ?? 5.0;
      totalPotholes = (aiResult['total_potholes'] as num?)?.toInt() ?? 1;
      aiSource = aiResult['is_offline_estimate'] == true
          ? 'OFFLINE_ESTIMATE'
          : 'ROBOFLOW_REAL';

      // FIX 1: Warn user when AI result is an offline estimate
      if (aiResult['is_offline_estimate'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not reach AI server. '
              'Severity is an estimate. '
              'Report will still be submitted.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } else {
      aiSource = 'UNKNOWN';
    }

    try {
      await ComplaintStore.instance.createCitizenComplaintWithUploads(
        title: '$effectiveCategory reported by citizen',
        description: _descriptionController.text.trim(),
        damageType: effectiveCategory,
        location: locationText,
        ward: 'Ward Pending',
        coords: coords,
        localImagePaths: localPaths,
        severity: severity,
        severityScore: severityScore,
        epdoScore: epdoScore,
        totalPotholes: totalPotholes ?? 0,
        aiPriority: aiPriority,
        aiSource: aiSource,
        locationIsApproximate: locationIsApproximate,
      );
    } on ComplaintSaveException catch (e) {
      // FIX 3: Report saved locally — tell user clearly
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
      // Still navigate — report IS saved locally
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
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
              'Your complaint has been registered in the backend and will be reviewed by municipal officials within 24-48 hours.',
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
            'In Progress',
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
      case 'In Progress':
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
              kIsWeb
                  ? Image.network(_capturedImage!.path, fit: BoxFit.contain)
                  : Image.file(File(_capturedImage!.path), fit: BoxFit.contain),
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



