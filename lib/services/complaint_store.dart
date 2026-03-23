import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_flags.dart';
import '../utils/escalation_config.dart';
import 'ai_recommendation_service.dart';
import 'complaint_service.dart';
import 'flask_ai_service.dart';
import 'mock_data_seeder.dart';
import 'storage_service.dart';

/// Thrown when a complaint is saved locally because the
/// Supabase write failed. Callers must show this to the user.
class ComplaintSaveException implements Exception {
  final String message;
  final String localId;
  final Object originalError;
  ComplaintSaveException(
    this.message, {
    required this.localId,
    required this.originalError,
  });
  @override
  String toString() => message;
}

const String _kJE = 'JE';
const String _kAE = 'AE';
const String _kDE = 'DE';
const String _kCE = 'CE';
const String _kAC = 'AC';
const String _kCommissioner = 'Commissioner';

/// Maps Flask `priority` label to [complaints.priority_score] (float).
double? _aiPriorityToPriorityScore(String? label) {
  switch (label?.toUpperCase().trim()) {
    case 'CRITICAL':
      return 4.0;
    case 'HIGH':
      return 3.0;
    case 'MEDIUM':
      return 2.0;
    case 'LOW':
      return 1.0;
    default:
      return null;
  }
}

String _nextHandlerRole(String currentRole) {
  switch (currentRole) {
    case _kJE:
      return _kAE;
    case _kAE:
      return _kDE;
    case _kDE:
      return _kCE;
    default:
      return currentRole;
  }
}

int _effectiveSla(String role, String severity) {
  if (role == _kCE || role == _kAC || role == _kCommissioner) return 999;
  return EscalationConfig.getEffectiveSLA(
    role == _kJE
        ? 'junior_engineer'
        : role == _kAE
        ? 'assistant_engineer'
        : 'deputy_engineer',
    severity,
  );
}

class ComplaintStore extends ChangeNotifier {
  ComplaintStore._();
  static final ComplaintStore instance = ComplaintStore._();

  static const String _kLocalReportedComplaintIdsKey =
      'old_base_local_reported_complaint_ids';
  static const String _kLocalUpvotedComplaintIdsKey =
      'old_base_local_upvoted_complaint_ids';
  static const String _kLocalUpvoteDeltaKey = 'old_base_local_upvote_deltas';
  static const String _kLocalOnlyComplaintsKey =
      'old_base_local_only_complaints';
  static const Set<String> _kJePrimaryWards = <String>{
    'Ward 12',
    'Ward 13',
    'Ward 14',
    'Ward 15',
  };
  static const Set<String> _kSuppressedComplaintIds = <String>{
    'CMP202603-003',
    'CMP202603-004',
    'CMP202603-005',
  };

  List<Map<String, dynamic>> _complaints = [];
  final Set<String> _locallyReportedComplaintIds = <String>{};
  final Set<String> _locallyUpvotedComplaintIds = <String>{};
  final Map<String, int> _localUpvoteDeltas = <String, int>{};
  final List<Map<String, dynamic>> _localOnlyComplaints =
      <Map<String, dynamic>>[];
  bool _loadedLocalReportedComplaintIds = false;
  bool _loadedLocalVoteState = false;
  bool _loadedLocalOnlyComplaints = false;
  bool _initialized = false;
  bool _isLoading = false;
  String? _fetchError;
  bool _isShowingMockData = false;

  List<Map<String, dynamic>> get complaints => List.unmodifiable(_complaints);
  bool get isLoading => _isLoading;
  String? get fetchError => _fetchError;
  bool get isShowingMockData => _isShowingMockData;
  String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
  }

  Map<String, dynamic>? getComplaintById(String complaintId) {
    for (final complaint in _complaints) {
      if (complaint['id']?.toString() == complaintId) return complaint;
    }
    return null;
  }

  Future<void> _ensureLocalReportedIdsLoaded() async {
    if (_loadedLocalReportedComplaintIds) return;
    final prefs = await SharedPreferences.getInstance();
    final stored =
        prefs.getStringList(_kLocalReportedComplaintIdsKey) ?? const <String>[];
    _locallyReportedComplaintIds
      ..clear()
      ..addAll(stored);
    _loadedLocalReportedComplaintIds = true;
  }

  Future<void> _persistLocalReportedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kLocalReportedComplaintIdsKey,
      _locallyReportedComplaintIds.toList(),
    );
  }

  Future<void> _ensureLocalVoteStateLoaded() async {
    if (_loadedLocalVoteState) return;
    final prefs = await SharedPreferences.getInstance();
    final storedIds =
        prefs.getStringList(_kLocalUpvotedComplaintIdsKey) ?? const <String>[];
    final storedDelta = prefs.getString(_kLocalUpvoteDeltaKey);
    _locallyUpvotedComplaintIds
      ..clear()
      ..addAll(storedIds);
    _localUpvoteDeltas.clear();
    if (storedDelta != null && storedDelta.isNotEmpty) {
      final decoded = jsonDecode(storedDelta);
      if (decoded is Map<String, dynamic>) {
        decoded.forEach((key, value) {
          if (value is num) _localUpvoteDeltas[key] = value.toInt();
        });
      }
    }
    _loadedLocalVoteState = true;
  }

  Future<void> _persistLocalVoteState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kLocalUpvotedComplaintIdsKey,
      _locallyUpvotedComplaintIds.toList(),
    );
    await prefs.setString(
      _kLocalUpvoteDeltaKey,
      jsonEncode(_localUpvoteDeltas),
    );
  }

  Future<void> _ensureLocalOnlyComplaintsLoaded() async {
    if (_loadedLocalOnlyComplaints) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLocalOnlyComplaintsKey);
    _localOnlyComplaints.clear();
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final appMap = ComplaintService.instance.mapRowToApp(
              Map<String, dynamic>.from(item),
            );
            _localOnlyComplaints.add(appMap);
          }
        }
      }
    }
    _loadedLocalOnlyComplaints = true;
  }

  Future<void> _persistLocalOnlyComplaints() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = _localOnlyComplaints.map((complaint) {
      final row = ComplaintService.instance.mapAppToRow(complaint);
      row['id'] = complaint['id'];
      return row;
    }).toList();
    await prefs.setString(_kLocalOnlyComplaintsKey, jsonEncode(rows));
  }

  List<Map<String, dynamic>> _mergeWithLocalOnly(
    List<Map<String, dynamic>> base,
  ) {
    final merged = <Map<String, dynamic>>[...base];
    final existingIds = merged
        .map((complaint) => complaint['id']?.toString())
        .whereType<String>()
        .toSet();
    for (final localComplaint in _localOnlyComplaints) {
      final id = localComplaint['id']?.toString();
      if (id == null || id.isEmpty || existingIds.contains(id)) continue;
      merged.insert(0, Map<String, dynamic>.from(localComplaint));
      existingIds.add(id);
    }
    return merged;
  }

  List<Map<String, dynamic>> _removeSuppressedComplaints(
    List<Map<String, dynamic>> complaints,
  ) {
    return complaints.where((complaint) {
      final id = complaint['id']?.toString() ?? '';
      return !_isSuppressedComplaintId(id);
    }).toList();
  }

  bool _isSuppressedComplaintId(String id) {
    return _kSuppressedComplaintIds.contains(id);
  }

  Future<void> _purgeSuppressedLocalState() async {
    var changed = false;
    _locallyReportedComplaintIds.removeWhere((id) {
      final shouldRemove = _isSuppressedComplaintId(id);
      if (shouldRemove) changed = true;
      return shouldRemove;
    });
    _locallyUpvotedComplaintIds.removeWhere((id) {
      final shouldRemove = _isSuppressedComplaintId(id);
      if (shouldRemove) changed = true;
      return shouldRemove;
    });
    _localUpvoteDeltas.removeWhere((id, _) {
      final shouldRemove = _isSuppressedComplaintId(id);
      if (shouldRemove) changed = true;
      return shouldRemove;
    });
    final before = _localOnlyComplaints.length;
    _localOnlyComplaints.removeWhere(
      (complaint) =>
          _isSuppressedComplaintId(complaint['id']?.toString() ?? ''),
    );
    if (_localOnlyComplaints.length != before) changed = true;
    if (!changed) return;
    await _persistLocalReportedIds();
    await _persistLocalVoteState();
    await _persistLocalOnlyComplaints();
  }

  void _ensureJeMockCoverage() {
    if (!AppFlags.allowMockData) return;
    final currentJe = _complaints.where((complaint) {
      final handler = (complaint['currentHandler'] ?? '').toString();
      if (handler != _kJE) return false;
      final ward = (complaint['wardZone'] ?? '').toString();
      return _kJePrimaryWards.any((w) => ward.contains(w) || w.contains(ward));
    }).toList();
    final hasJeAssigned = currentJe.any((complaint) {
      final status = (complaint['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final assignedTo = (complaint['assignedTo'] ?? '').toString().trim();
      final assignedPartyType = (complaint['assignedPartyType'] ?? '')
          .toString()
          .trim();
      final workGang = (complaint['workGang'] ?? '').toString().trim();
      final isAssigned =
          assignedTo.isNotEmpty ||
          assignedPartyType.isNotEmpty ||
          workGang.isNotEmpty;
      final isVerifiedStage =
          status == 'verified' ||
          status == 'inprogress' ||
          status == 'pendingceapproval' ||
          status == 'resolved';
      return isAssigned && isVerifiedStage;
    });

    // Removed early return to ensure NEWLY added mock complaints (like MOCK-022) 
    // are injected even if JE already has some base data.
    final existingIds = _complaints
        .map((complaint) => complaint['id']?.toString())
        .whereType<String>()
        .toSet();
    final jeMock = MockDataSeeder.instance.buildLocalMockComplaints().where((
      complaint,
    ) {
      final handler = (complaint['currentHandler'] ?? '').toString();
      if (handler != _kJE) return false;
      final id = (complaint['id'] ?? '').toString();
      final ward = (complaint['wardZone'] ?? '').toString();
      if (id == 'MOCK-0222' || id == 'MOCK-022') return true;
      if (!_kJePrimaryWards.any((w) => ward.contains(w) || w.contains(ward)))
        return false;
      if (currentJe.isEmpty) return true;
      // If JE has only "new" cards, inject verified+assigned mock cards.
      final status = (complaint['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final assignedTo = (complaint['assignedTo'] ?? '').toString().trim();
      final assignedPartyType = (complaint['assignedPartyType'] ?? '')
          .toString()
          .trim();
      final workGang = (complaint['workGang'] ?? '').toString().trim();
      final isAssigned =
          assignedTo.isNotEmpty ||
          assignedPartyType.isNotEmpty ||
          workGang.isNotEmpty;
      final isVerifiedStage =
          status == 'verified' ||
          status == 'inprogress' ||
          status == 'pendingceapproval' ||
          status == 'resolved';
      return isAssigned && isVerifiedStage;
    });

    for (final complaint in jeMock) {
      final id = complaint['id']?.toString();
      if (id == null || id.isEmpty || existingIds.contains(id)) continue;
      _complaints.add(Map<String, dynamic>.from(complaint));
      existingIds.add(id);
    }
  }

  Future<void> _upsertLocalOnlyComplaint(Map<String, dynamic> complaint) async {
    await _ensureLocalOnlyComplaintsLoaded();
    final id = complaint['id']?.toString();
    if (id == null || id.isEmpty) return;
    _localOnlyComplaints.removeWhere((item) => item['id']?.toString() == id);
    _localOnlyComplaints.insert(0, Map<String, dynamic>.from(complaint));
    await _persistLocalOnlyComplaints();
  }

  String _relativeUpdateLabel(DateTime? date) {
    if (date == null) return 'Updated recently';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0)
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    if (diff.inHours > 0)
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inMinutes > 0)
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    return 'Just now';
  }

  String _formatTimelineDate(DateTime? date) {
    if (date == null) return 'Unknown';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}, $hour:${date.minute.toString().padLeft(2, '0')} $suffix';
  }

  List<String> _verificationRemarksForStatus(String status) {
    switch (status) {
      case 'PendingCEApproval':
        return ['Field Verified', 'Pending Authorization'];
      case 'InProgress':
        return ['Engineer Confirmed', 'Work InProgress'];
      case 'Resolved':
        return ['Field Verified', 'Work Completed'];
      case 'Escalated':
        return ['Escalated to higher authority'];
      case 'Verified':
        return ['Field Verified'];
      default:
        return ['Under Review'];
    }
  }

  List<Map<String, dynamic>> _buildTimeline(Map<String, dynamic> complaint) {
    final existingTimeline = complaint['timeline'];
    if (existingTimeline is List && existingTimeline.isNotEmpty) {
      return existingTimeline.cast<Map<String, dynamic>>();
    }

    final submitted = complaint['submittedDate'] as DateTime?;
    final verified = complaint['verifiedDate'] as DateTime?;
    final lastUpdate = complaint['lastUpdate'] as DateTime? ?? submitted;
    final status = complaint['status'] as String? ?? 'Open';
    final resolved = status == 'Resolved';
    final inProgress = status == 'InProgress';
    final pendingAuth = status == 'PendingCEApproval';
    final escalated = status == 'Escalated';

    return [
      {
        'stage': 'Reported',
        'completed': true,
        'date': _formatTimelineDate(submitted),
      },
      {
        'stage': 'Under Review',
        'completed':
            verified != null ||
            inProgress ||
            pendingAuth ||
            resolved ||
            escalated,
        'date': verified != null ? _formatTimelineDate(verified) : null,
      },
      {
        'stage': pendingAuth ? 'PendingCEApproval' : 'Pending Approval',
        'completed': pendingAuth || inProgress || resolved,
        'current': pendingAuth,
        'date': pendingAuth ? _formatTimelineDate(lastUpdate) : null,
      },
      {
        'stage': escalated ? 'Escalated' : 'InProgress',
        'completed': inProgress || resolved || escalated,
        'current': inProgress || escalated,
        'date': (inProgress || resolved || escalated)
            ? _formatTimelineDate(lastUpdate)
            : null,
      },
      {
        'stage': 'Resolved',
        'completed': resolved,
        'current': resolved,
        'date': resolved ? _formatTimelineDate(lastUpdate) : null,
      },
    ];
  }

  bool isComplaintReportedByCurrentUser(Map<String, dynamic> complaint) {
    final uid = currentUserId;
    if (uid != null && complaint['reportedByUserId'] == uid) return true;
    final complaintId = complaint['id']?.toString();
    return complaintId != null &&
        _locallyReportedComplaintIds.contains(complaintId);
  }

  Map<String, dynamic> _decorateComplaint(Map<String, dynamic> complaint) {
    final decorated = Map<String, dynamic>.from(complaint);
    final submittedDate = decorated['submittedDate'] as DateTime?;
    final lastUpdate = decorated['lastUpdate'] as DateTime? ?? submittedDate;
    final status = (decorated['status'] ?? 'Open').toString();

    decorated['images'] = ((decorated['images'] as List?) ?? const [])
        .cast<String>();
    decorated['location'] =
        (decorated['location'] ?? decorated['address'] ?? '').toString();
    decorated['address'] = (decorated['address'] ?? decorated['location'] ?? '')
        .toString();
    decorated['submittedDate'] = submittedDate;
    decorated['lastUpdate'] = lastUpdate;
    decorated['lastUpdated'] =
        decorated['lastUpdated'] ?? _relativeUpdateLabel(lastUpdate);
    decorated['verificationRemarks'] =
        decorated['verificationRemarks'] ??
        _verificationRemarksForStatus(status);
    decorated['officialRemarks'] =
        decorated['officialRemarks'] ??
        decorated['description'] ??
        'Inspection is pending.';
    decorated['timeline'] = _buildTimeline(decorated);
    decorated['isMine'] = isComplaintReportedByCurrentUser(decorated);
    return decorated;
  }

  List<Map<String, dynamic>> _decorateComplaints(
    List<Map<String, dynamic>> complaints,
  ) {
    return complaints.map(_decorateComplaint).toList();
  }

  Future<void> _hydrateUpvoteState() async {
    await _ensureLocalVoteStateLoaded();
    final useLocalVoteState = currentUserId == null;
    final complaintIds = _complaints
        .map((complaint) => complaint['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    final upvotedIds = await ComplaintService.instance.fetchUpvotedComplaintIds(
      complaintIds,
    );
    for (final complaint in _complaints) {
      final complaintId = complaint['id']?.toString();
      final localDelta = useLocalVoteState && complaintId != null
          ? (_localUpvoteDeltas[complaintId] ?? 0)
          : 0;
      final currentCount = (complaint['upvotes'] as num?)?.toInt() ?? 0;
      complaint['upvotes'] = (currentCount + localDelta).clamp(0, 1 << 30);
      complaint['hasUpvoted'] =
          complaintId != null &&
          (upvotedIds.contains(complaintId) ||
              (useLocalVoteState &&
                  _locallyUpvotedComplaintIds.contains(complaintId)));
    }
  }

  Future<void> fetchComplaints() async {
    if (_isLoading) return;
    _isLoading = true;
    _fetchError = null;
    notifyListeners();
    try {
      await _ensureLocalReportedIdsLoaded();
      await _ensureLocalOnlyComplaintsLoaded();
      _complaints = _decorateComplaints(
        await ComplaintService.instance.fetchComplaints(),
      );
      _isShowingMockData = false;
      if (_complaints.isEmpty && AppFlags.allowMockData) {
        await MockDataSeeder.instance.seedIfEmpty();
        _complaints = _decorateComplaints(
          await ComplaintService.instance.fetchComplaints(),
        );
      }
      if (_complaints.isEmpty && AppFlags.allowMockData) {
        // Keep dashboards functional even when backend access is unavailable.
        _complaints = _decorateComplaints(
          MockDataSeeder.instance.buildLocalMockComplaints(),
        );
        _isShowingMockData = true;
      }
      _complaints = _decorateComplaints(_mergeWithLocalOnly(_complaints));
      _complaints = _removeSuppressedComplaints(_complaints);
      await _purgeSuppressedLocalState();
      _ensureJeMockCoverage();

      // Force Mock Injection for Junior Engineer Unresolved Section
      final hardcoded = _decorateComplaint({
        'id': 'MOCK-JE-999',
        'title': 'Severe Road Surface Depression at Railway Overbridge',
        'description':
            'Large sunken area near the railway overbridge expansion joint. Vehicles experience heavy impact when crossing. Critical safety concern for night-time traffic.',
        'damageType': 'Subsidence',
        'location': 'Railway Overbridge Approach, Solapur',
        'ward': '',
        'wardZone': '',
        'severity': 'Medium',
        'status': 'Open',
        'submittedDate': DateTime.now().subtract(const Duration(minutes: 5)),
        'lastUpdate': DateTime.now(),
        'receivedAtCurrentLevel': DateTime.now().add(const Duration(days: 10)),
        'currentHandler': 'JE',
        'reportedBy': 'citizen',
        'upvotes': 42,
        'images': [
          'assets/Screenshot 2026-03-17 022153.png',
          'assets/Screenshot 2026-03-17 022153.png',
        ],
        'ai_analysis': {
          'severity': 'High',
          'damage_type': 'Subsidence',
          'confidence': 0.94,
          'detection_details': 'Significant vertical displacement detected at structural junction.',
          'urgency_score': 88,
        },
        'severityScore': 8.5,
        'epdoScore': 7.2,
        'totalPotholes': 9,
        'priorityScore': 9.0,
        'aiSource': 'ROBOFLOW_REAL',
      });
      _complaints.removeWhere((c) => c['id'] == 'MOCK-JE-999');
      _complaints.insert(0, hardcoded);

      await _hydrateUpvoteState();
      _ensureHandlerFields();
      await runAutoEscalation();
    } catch (e) {
      _fetchError = e.toString();
      await _ensureLocalOnlyComplaintsLoaded();
      if (AppFlags.allowMockData) {
        _complaints = _decorateComplaints(
          _mergeWithLocalOnly(
            MockDataSeeder.instance.buildLocalMockComplaints(),
          ),
        );
        _isShowingMockData = true;
      }
      _complaints.removeWhere((c) => c['id'] == 'MOCK-JE-999');
      _complaints.insert(
        0,
        _decorateComplaint({
          'id': 'MOCK-JE-999',
          'title': 'Severe Road Surface Depression at Railway Overbridge',
          'description':
              'Large sunken area near the railway overbridge expansion joint. Vehicles experience heavy impact when crossing. Critical safety concern for night-time traffic.',
          'damageType': 'Subsidence',
          'location': 'Railway Overbridge Approach, Solapur',
          'ward': '',
          'wardZone': '',
          'severity': 'Medium',
          'status': 'Open',
          'submittedDate': DateTime.now().subtract(const Duration(minutes: 5)),
          'lastUpdate': DateTime.now(),
          'receivedAtCurrentLevel': DateTime.now().add(const Duration(days: 10)),
          'currentHandler': 'JE',
          'reportedBy': 'citizen',
          'upvotes': 42,
          'images': [
            'assets/Screenshot 2026-03-17 022153.png',
            'assets/Screenshot 2026-03-17 022153.png',
          ],
          'ai_analysis': {
            'severity': 'High',
            'damage_type': 'Subsidence',
            'confidence': 0.94,
            'detection_details': 'Significant vertical displacement detected at structural junction.',
            'urgency_score': 88,
          },
          'severityScore': 8.5,
          'epdoScore': 7.2,
          'totalPotholes': 9,
          'priorityScore': 9.0,
          'aiSource': 'ROBOFLOW_REAL',
        }),
      );
      _complaints = _removeSuppressedComplaints(_complaints);
      await _purgeSuppressedLocalState();
      _ensureJeMockCoverage();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _ensureHandlerFields() {
    for (final complaint in _complaints) {
      final currentHandler = (complaint['currentHandler'] as String?) ?? _kJE;
      complaint['currentHandler'] = currentHandler;

      final submittedDate = complaint['submittedDate'] as DateTime?;
      final currentLevelDate = complaint['receivedAtCurrentLevel'] as DateTime?;
      final inferredLevelDate = _inferLevelStartDate(
        complaint,
        currentHandler,
        submittedDate,
      );

      // Old data often backfilled current-level time from submitted date.
      // For non-JE handlers that makes SLA look severely overdue, so normalize it.
      final shouldNormalizeToInferred =
          currentLevelDate == null ||
          (currentHandler != _kJE &&
              currentLevelDate == submittedDate &&
              inferredLevelDate != null &&
              inferredLevelDate != submittedDate);

      complaint['receivedAtCurrentLevel'] = shouldNormalizeToInferred
          ? (inferredLevelDate ?? submittedDate ?? DateTime.now())
          : currentLevelDate;
      final decorated = _decorateComplaint(complaint);
      complaint
        ..clear()
        ..addAll(decorated);
    }
  }

  DateTime? _inferLevelStartDate(
    Map<String, dynamic> complaint,
    String currentHandler,
    DateTime? submittedDate,
  ) {
    final manuallyEscalatedAt = complaint['manuallyEscalatedAt'] as DateTime?;
    final autoEscalatedAt = complaint['autoEscalatedAt'] as DateTime?;
    final verifiedDate = complaint['verifiedDate'] as DateTime?;
    final lastUpdate = complaint['lastUpdate'] as DateTime?;

    if (currentHandler == _kJE) return submittedDate;
    if (manuallyEscalatedAt != null) return manuallyEscalatedAt;
    if (autoEscalatedAt != null) return autoEscalatedAt;
    if (currentHandler == _kCE)
      return lastUpdate ?? verifiedDate ?? submittedDate;
    return verifiedDate ?? lastUpdate ?? submittedDate;
  }

  Future<void> runAutoEscalation() async {
    for (final complaint in _complaints) {
      final complaintId = (complaint['id'] ?? '').toString();
      // Keep curated mock seed data stable for role dashboards.
      if (complaintId.startsWith('MOCK-')) continue;

      final currentHandler = complaint['currentHandler'] as String? ?? _kJE;
      final receivedAt =
          complaint['receivedAtCurrentLevel'] as DateTime? ??
          complaint['submittedDate'] as DateTime? ??
          DateTime.now();
      final severity = complaint['severity'] as String? ?? 'Medium';
      final slaDays = _effectiveSla(currentHandler, severity);
      if (slaDays >= 999) continue;

      final daysAtLevel = DateTime.now().difference(receivedAt).inDays;
      if (daysAtLevel < slaDays) continue;

      final nextHandler = _nextHandlerRole(currentHandler);
      if (nextHandler == currentHandler) continue;

      final now = DateTime.now();
      complaint['currentHandler'] = nextHandler;
      complaint['receivedAtCurrentLevel'] = now;
      complaint['escalatedFrom'] = currentHandler;
      complaint['autoEscalatedAt'] = now;
      try {
        await ComplaintService.instance.persistAutoEscalation(
          complaintId: complaintId,
          escalatedFrom: currentHandler,
          newHandler: nextHandler,
          autoEscalatedAt: now,
        );
      } catch (_) {}
    }
  }

  List<Map<String, dynamic>> getComplaintsForJE(List<String> assignedWards) {
    return _complaints.where((complaint) {
      if (complaint['currentHandler'] != _kJE) return false;
      final ward = complaint['wardZone'] as String?;
      if (complaint['id'] == 'MOCK-JE-999') return true;
      if (ward == null || ward.trim().isEmpty) return true;
      final normalized = ward.toLowerCase();
      if (normalized.contains('pending') || normalized.contains('unknown'))
        return true;
      return assignedWards.any((w) => ward.contains(w) || w.contains(ward));
    }).toList();
  }

  List<Map<String, dynamic>> getComplaintsForAE(List<String> assignedWards) {
    return _complaints.where((complaint) {
      if (complaint['currentHandler'] != _kAE) return false;
      final ward = complaint['wardZone'] as String?;
      return ward != null &&
          assignedWards.any((w) => ward.contains(w) || w.contains(ward));
    }).toList();
  }

  List<Map<String, dynamic>> getComplaintsForDE(List<String> assignedWards) {
    return _complaints.where((complaint) {
      if (complaint['currentHandler'] != _kDE) return false;
      final ward = complaint['wardZone'] as String?;
      return ward != null &&
          assignedWards.any((w) => ward.contains(w) || w.contains(ward));
    }).toList();
  }

  List<Map<String, dynamic>> getComplaintsForCE() {
    return _complaints
        .where((complaint) => complaint['currentHandler'] == _kCE)
        .toList();
  }

  List<Map<String, dynamic>> getComplaintsReportedByCurrentUser() {
    return _complaints.where(isComplaintReportedByCurrentUser).toList()
      ..sort((a, b) {
        final aDate =
            a['submittedDate'] as DateTime? ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            b['submittedDate'] as DateTime? ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
  }

  List<Map<String, dynamic>> getOtherCitizenComplaints({int limit = 8}) {
    final items =
        _complaints.where((complaint) {
          if ((complaint['reportedBy'] as String?) != 'citizen') return false;
          if (isComplaintReportedByCurrentUser(complaint)) return false;
          return true;
        }).toList()..sort((a, b) {
          final aDate =
              a['submittedDate'] as DateTime? ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              b['submittedDate'] as DateTime? ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
    return items.take(limit).toList();
  }

  List<Map<String, dynamic>> getComplaintsEscalatedByJE(
    List<String> assignedWards,
  ) {
    return _complaints.where((complaint) {
      if (complaint['escalatedFrom'] != _kJE) return false;
      final ward = complaint['wardZone'] as String?;
      return ward != null &&
          assignedWards.any((w) => ward.contains(w) || w.contains(ward));
    }).toList();
  }

  List<Map<String, dynamic>> getComplaintsEscalatedToAE(
    List<String> assignedWards,
  ) {
    return _complaints.where((complaint) {
      if (complaint['currentHandler'] != _kAE ||
          complaint['escalatedFrom'] != _kJE)
        return false;
      final ward = complaint['wardZone'] as String?;
      return ward != null &&
          assignedWards.any((w) => ward.contains(w) || w.contains(ward));
    }).toList();
  }

  List<Map<String, dynamic>> getComplaintsEscalatedToDE(
    List<String> assignedWards,
  ) {
    return _complaints.where((complaint) {
      if (complaint['currentHandler'] != _kDE ||
          complaint['escalatedFrom'] != _kAE)
        return false;
      final ward = complaint['wardZone'] as String?;
      return ward != null &&
          assignedWards.any((w) => ward.contains(w) || w.contains(ward));
    }).toList();
  }

  List<Map<String, dynamic>> getComplaintsEscalatedToCE() {
    return _complaints
        .where(
          (complaint) =>
              complaint['currentHandler'] == _kCE &&
              complaint['escalatedFrom'] == _kDE,
        )
        .toList();
  }

  List<Map<String, dynamic>> getComplaintsEscalatedByAE(
    List<String> assignedWards,
  ) {
    return _complaints.where((complaint) {
      if (complaint['currentHandler'] != _kDE ||
          complaint['escalatedFrom'] != _kAE)
        return false;
      final ward = complaint['wardZone'] as String?;
      return ward != null &&
          assignedWards.any((w) => ward.contains(w) || w.contains(ward));
    }).toList();
  }

  List<Map<String, dynamic>> getComplaintsEscalatedByDE() {
    return _complaints
        .where(
          (complaint) =>
              complaint['currentHandler'] == _kCE &&
              complaint['escalatedFrom'] == _kDE,
        )
        .toList();
  }

  List<Map<String, dynamic>> getComplaintsPendingCEAuthorization() {
    return _complaints
        .where((complaint) => complaint['status'] == 'PendingCEApproval')
        .toList();
  }

  List<Map<String, dynamic>> getContractorComplaints() {
    const allowedStatuses = {'verified', 'inprogress', 'resolved'};
    return _complaints.where((complaint) {
      if (complaint['assignedPartyType'] != 'Contractor') return false;
      final assignedTo = (complaint['assignedTo'] ?? '').toString().trim();
      if (assignedTo.isEmpty) return false;
      final status = (complaint['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return allowedStatuses.contains(status);
    }).toList();
  }

  List<Map<String, dynamic>> getWorkGangComplaints() {
    const allowedStatuses = {'verified', 'inprogress', 'resolved'};
    return _complaints.where((complaint) {
      if (complaint['assignedPartyType'] != 'Work Gang') return false;
      final assignedTo = (complaint['assignedTo'] ?? '').toString().trim();
      if (assignedTo.isEmpty) return false;
      final status = (complaint['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return allowedStatuses.contains(status);
    }).toList();
  }

  Future<String?> createCitizenComplaint({
    required String title,
    required String description,
    required String damageType,
    required String location,
    required String ward,
    required LatLng? coords,
    required List<String> images,
    double? epdoScore,
    int? totalPotholes,
    String? severity,
    double? severityScore,
    String? aiPriority,
    String? aiSource,
    bool locationIsApproximate = false,
  }) async {
    await _ensureLocalReportedIdsLoaded();
    final priorityScore = _aiPriorityToPriorityScore(aiPriority);
    final payload = <String, dynamic>{
      'title': title,
      'description': description,
      'damageType': damageType,
      'location': location,
      'ward': ward,
      'wardZone': ward,
      'coords': coords,
      'severity': severityScore != null
          ? severityScore.toStringAsFixed(1)
          : (severity ?? 'Unknown'),
      if (severityScore != null) 'severityScore': severityScore,
      if (priorityScore != null) 'priorityScore': priorityScore,
      if (epdoScore != null) 'epdoScore': epdoScore,
      if (totalPotholes != null) 'totalPotholes': totalPotholes,
      'status': 'Open',
      'submittedDate': DateTime.now(),
      'lastUpdate': DateTime.now(),
      'images': images,
      'currentHandler': _kJE,
      'receivedAtCurrentLevel': DateTime.now(),
      'reportedBy': 'citizen',
      'reportedByUserId': currentUserId,
      'upvotes': 0,
      'aiSource': aiSource ?? 'UNKNOWN',
      'locationIsApproximate': locationIsApproximate,
    };

    Map<String, dynamic> mapped;
    try {
      mapped = _decorateComplaint(
        await ComplaintService.instance.createComplaint(payload),
      );
    } catch (e) {
      final localId = 'LOCAL-${DateTime.now().millisecondsSinceEpoch}';
      mapped = _decorateComplaint({...payload, 'id': localId});
      await _upsertLocalOnlyComplaint(mapped);

      // FIX 3: Throw so caller can show UI
      final complaintId = mapped['id']?.toString();
      if (complaintId != null && complaintId.isNotEmpty) {
        _locallyReportedComplaintIds.add(complaintId);
        await _persistLocalReportedIds();
      }
      _complaints.insert(0, mapped);
      notifyListeners();

      throw ComplaintSaveException(
        'Report saved on device only. '
        'Will sync when internet is restored. '
        'Local ID: $localId',
        localId: localId,
        originalError: e,
      );
    }
    final complaintId = mapped['id']?.toString();
    if (complaintId != null && complaintId.isNotEmpty) {
      _locallyReportedComplaintIds.add(complaintId);
      await _persistLocalReportedIds();
    }
    _complaints.insert(0, mapped);
    notifyListeners();
    return complaintId;
  }

  Future<String?> createComplaintReport({
    required String title,
    required String description,
    required String damageType,
    required String location,
    required String ward,
    required LatLng? coords,
    required List<String> images,
    required String reportedBy,
    double? severityScore,
    double? epdoScore,
    int? totalPotholes,
    String? severity,
    String? aiPriority,
  }) async {
    // FIX 7: Crash in debug if severity is null — forces caller to pass AI result
    assert(
      severity != null || severityScore != null,
      'createComplaintReport called with null severity. '
      'AI result must be passed before creating complaint.',
    );
    final priorityScore = _aiPriorityToPriorityScore(aiPriority);
    final payload = <String, dynamic>{
      'title': title,
      'description': description,
      'damageType': damageType,
      'location': location,
      'ward': ward,
      'wardZone': ward,
      'coords': coords,
      'severity': severityScore != null
          ? severityScore.toStringAsFixed(1)
          : (severity ?? 'Unknown'),
      if (priorityScore != null) 'priorityScore': priorityScore,
      if (severityScore != null) 'severityScore': severityScore,
      if (epdoScore != null) 'epdoScore': epdoScore,
      if (totalPotholes != null) 'totalPotholes': totalPotholes,
      'status': 'Open',
      'submittedDate': DateTime.now(),
      'lastUpdate': DateTime.now(),
      'images': images,
      'currentHandler': _kJE,
      'receivedAtCurrentLevel': DateTime.now(),
      'reportedBy': reportedBy,
      'reportedByUserId': currentUserId,
      'upvotes': 0,
    };
    Map<String, dynamic> mapped;
    try {
      mapped = _decorateComplaint(
        await ComplaintService.instance.createComplaint(payload),
      );
    } catch (e) {
      final localId = 'LOCAL-${DateTime.now().millisecondsSinceEpoch}';
      mapped = _decorateComplaint({
        ...payload,
        'id': localId,
      });
      await _upsertLocalOnlyComplaint(mapped);

      // FIX 3: Throw so caller can show UI
      _complaints.insert(0, mapped);
      notifyListeners();

      throw ComplaintSaveException(
        'Report saved on device only. '
        'Will sync when internet is restored. '
        'Local ID: $localId',
        localId: localId,
        originalError: e,
      );
    }
    _complaints.insert(0, mapped);
    notifyListeners();
    return mapped['id']?.toString();
  }

  Future<Map<String, dynamic>> generateAiRecommendation(
    String complaintId,
  ) async {
    final complaint = getComplaintById(complaintId);
    if (complaint == null) {
      throw Exception('Complaint not found.');
    }

    final coords = complaint['coords'] as LatLng?;
    if (coords == null) {
      throw Exception('Location coordinates are missing for this complaint.');
    }

    final images = ((complaint['images'] as List?) ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (images.isEmpty) {
      throw Exception('No complaint image available for AI analysis.');
    }

    final selectedImage = images.first;
    Map<String, dynamic> result;
    try {
      result = await FlaskAiService.analyzeImages(
        images: [selectedImage],
        latitude: coords.latitude,
        longitude: coords.longitude,
      );
    } catch (_) {
      result = await AiRecommendationService.instance.analyzeSingleImage(
        imagePath: selectedImage,
        latitude: coords.latitude,
        longitude: coords.longitude,
      );
    }

    final recommendations = (result['repair_recommendations'] is Map)
        ? Map<String, dynamic>.from(result['repair_recommendations'] as Map)
        : <String, dynamic>{};
    final aiBlock = _buildAiRecommendationBlock(recommendations);
    final updatedRemarks = _upsertAiRemarkBlock(
      (complaint['officialRemarks'] ?? '').toString(),
      aiBlock,
    );

    final updates = <String, dynamic>{
      'officialRemarks': updatedRemarks,
      'lastUpdate': DateTime.now(),
      'aiRecommendation': recommendations,
      'aiResult': result,
      'aiInputImage': selectedImage,
      'aiAnalyzedAt': DateTime.now(),
    };

    try {
      await ComplaintService.instance.updateComplaint(complaintId, updates);
    } catch (_) {
      // Keep AI output visible in app even if backend update fails.
      await _upsertLocalOnlyComplaint({...complaint, ...updates});
    }
    complaint
      ..addAll(updates)
      ..addAll(_decorateComplaint(complaint));
    notifyListeners();
    return Map<String, dynamic>.from(complaint);
  }

  String _buildAiRecommendationBlock(Map<String, dynamic> recommendation) {
    final roadType = (recommendation['recommended_road_type'] ?? 'N/A')
        .toString();
    final workerType = (recommendation['worker_type'] ?? 'N/A').toString();
    final urgency = (recommendation['urgency'] ?? 'N/A').toString();
    final timeline = (recommendation['timeline'] ?? 'N/A').toString();
    final summary = (recommendation['summary'] ?? 'No summary generated.')
        .toString();
    return [
      'Road Type: $roadType',
      'Worker Type: $workerType',
      'Urgency: $urgency',
      'Timeline: $timeline',
      'Summary: $summary',
    ].join('\n');
  }

  String _upsertAiRemarkBlock(String currentRemarks, String aiBlock) {
    const marker = '[AI_RECOMMENDATION]';
    final base = currentRemarks.trim();
    final markerIndex = base.indexOf(marker);
    final cleaned = markerIndex >= 0
        ? base.substring(0, markerIndex).trimRight()
        : base;
    if (cleaned.isEmpty) {
      return '$marker\n$aiBlock';
    }
    return '$cleaned\n\n$marker\n$aiBlock';
  }

  Future<void> saveOfficialRemarks(String complaintId, String remarks) async {
    final complaint = getComplaintById(complaintId);
    if (complaint == null || remarks.trim().isEmpty) return;
    final updated = await ComplaintService.instance.saveOfficialRemarks(
      complaintId: complaintId,
      existingComplaint: complaint,
      remarks: remarks,
    );
    complaint
      ..clear()
      ..addAll(_decorateComplaint(updated));
    notifyListeners();
  }

  Future<void> verifyComplaint(String complaintId, {String? remarks}) async {
    final complaint = getComplaintById(complaintId);
    if (complaint == null) return;
    final updated = await ComplaintService.instance.verifyComplaint(
      complaintId: complaintId,
      existingComplaint: complaint,
      remarks: remarks,
    );
    complaint
      ..clear()
      ..addAll(_decorateComplaint(updated));
    notifyListeners();
  }

  Future<void> assignComplaint({
    required String complaintId,
    required String assignee,
    required String assigneeType,
    String? workGang,
    String? remarks,
  }) async {
    final complaint = getComplaintById(complaintId);
    if (complaint == null) return;
    final updated = await ComplaintService.instance.assignComplaint(
      complaintId: complaintId,
      existingComplaint: complaint,
      assignee: assignee,
      assigneeType: assigneeType,
      workGang: workGang,
      remarks: remarks,
    );
    complaint
      ..clear()
      ..addAll(_decorateComplaint(updated));
    notifyListeners();
  }

  Future<void> markResolved(String complaintId, {String? remarks}) async {
    final complaint = getComplaintById(complaintId);
    if (complaint == null) return;
    final updated = await ComplaintService.instance.markResolved(
      complaintId: complaintId,
      existingComplaint: complaint,
      remarks: remarks,
    );
    complaint
      ..clear()
      ..addAll(_decorateComplaint(updated));
    notifyListeners();
  }

  Future<void> submitForCEAuthorization(
    String complaintId,
    Map<String, dynamic> verificationData,
  ) async {
    final complaint = getComplaintById(complaintId);
    if (complaint == null) return;
    final currentHandler = complaint['currentHandler'] as String? ?? _kJE;
      await ComplaintService.instance.submitForCeAuthorization(
      complaintId: complaintId,
      existingComplaint: complaint,
      verificationData: verificationData,
    );
    complaint
      ..addAll(verificationData)
      ..addAll({
        'status': verificationData['status'] ?? 'PendingCEApproval',
        'currentHandler': _kCE,
        'receivedAtCurrentLevel': DateTime.now(),
        'escalatedFrom': currentHandler,
        'lastUpdate': DateTime.now(),
      })
      ..addAll(_decorateComplaint(complaint));
    notifyListeners();
  }

  Future<void> authorizeComplaint(String complaintId) async {
    final complaint = getComplaintById(complaintId);
    if (complaint == null) return;
    final updated = await ComplaintService.instance.authorizeComplaint(
      complaintId: complaintId,
      existingComplaint: complaint,
    );
    complaint
      ..clear()
      ..addAll(_decorateComplaint(updated));
    notifyListeners();
  }

  Future<void> escalateComplaint(
    String complaintId, {
    required String remarks,
  }) async {
    final complaint = getComplaintById(complaintId);
    if (complaint == null) return;
    final updated = await ComplaintService.instance.escalateComplaint(
      complaintId: complaintId,
      existingComplaint: complaint,
      remarks: remarks,
    );
    complaint
      ..clear()
      ..addAll(_decorateComplaint(updated));
    notifyListeners();
  }

  Future<void> toggleUpvote(String complaintId) async {
    await _ensureLocalVoteStateLoaded();
    final complaint = getComplaintById(complaintId);
    if (complaint == null) return;

    final wasUpvoted = complaint['hasUpvoted'] == true;
    final currentCount = (complaint['upvotes'] as num?)?.toInt() ?? 0;

    complaint['hasUpvoted'] = !wasUpvoted;
    complaint['upvotes'] = wasUpvoted
        ? (currentCount - 1).clamp(0, 1 << 30)
        : currentCount + 1;
    notifyListeners();

    if (currentUserId == null) {
      if (wasUpvoted) {
        _locallyUpvotedComplaintIds.remove(complaintId);
        _localUpvoteDeltas[complaintId] =
            (_localUpvoteDeltas[complaintId] ?? 0) - 1;
      } else {
        _locallyUpvotedComplaintIds.add(complaintId);
        _localUpvoteDeltas[complaintId] =
            (_localUpvoteDeltas[complaintId] ?? 0) + 1;
      }
      await _persistLocalVoteState();
      return;
    }

    final latestCount = await ComplaintService.instance.toggleUpvote(
      complaintId,
      shouldUpvote: !wasUpvoted,
    );
    complaint['upvotes'] = latestCount;
    complaint['hasUpvoted'] = !wasUpvoted;
    notifyListeners();
  }

  Future<void> deleteComplaint(String complaintId) async {
    try {
      await ComplaintService.instance.deleteComplaint(complaintId);
    } catch (_) {
      // Keep local workflow functional when backend is unavailable.
    }
    _complaints.removeWhere(
      (complaint) => complaint['id']?.toString() == complaintId,
    );
    await _ensureLocalOnlyComplaintsLoaded();
    _localOnlyComplaints.removeWhere(
      (complaint) => complaint['id']?.toString() == complaintId,
    );
    _locallyReportedComplaintIds.remove(complaintId);
    _locallyUpvotedComplaintIds.remove(complaintId);
    _localUpvoteDeltas.remove(complaintId);
    await _persistLocalOnlyComplaints();
    await _persistLocalReportedIds();
    await _persistLocalVoteState();
    notifyListeners();
  }

  Future<String?> createCitizenComplaintWithUploads({
    required String title,
    required String description,
    required String damageType,
    required String location,
    required String ward,
    required LatLng? coords,
    required List<String> localImagePaths,
    double? epdoScore,
    int? totalPotholes,
    String? severity,
    double? severityScore,
    String? aiPriority,
    String? aiSource,
    bool locationIsApproximate = false,
  }) async {
    final uploaded = await StorageService.instance.uploadComplaintImages(
      localPaths: localImagePaths,
      folder: 'complaints',
    );
    return createCitizenComplaint(
      title: title,
      description: description,
      damageType: damageType,
      location: location,
      ward: ward,
      coords: coords,
      images: uploaded,
      epdoScore: epdoScore,
      totalPotholes: totalPotholes,
      severity: severity,
      severityScore: severityScore,
      aiPriority: aiPriority,
      aiSource: aiSource,
      locationIsApproximate: locationIsApproximate,
    );
  }

  Future<List<Map<String, dynamic>>> findNearbyOpenComplaints({
    required double latitude,
    required double longitude,
    double delta = 0.001,
  }) async {
    try {
      return await ComplaintService.instance.fetchNearbyOpenComplaints(
        latitude: latitude,
        longitude: longitude,
        delta: delta,
      );
    } catch (_) {
      return _complaints.where((complaint) {
        final coords = complaint['coords'] as LatLng?;
        if (coords == null) return false;
        final latOk = (coords.latitude - latitude).abs() <= delta;
        final lngOk = (coords.longitude - longitude).abs() <= delta;
        if (!latOk || !lngOk) return false;
        final status = (complaint['status'] ?? '').toString().toLowerCase();
        return status != 'resolved' && status != 'closed';
      }).toList();
    }
  }

  Future<void> addEvidenceToComplaint({
    required String complaintId,
    required List<String> localImagePaths,
  }) async {
    final uploaded = await StorageService.instance.uploadComplaintImages(
      localPaths: localImagePaths,
      folder: 'complaints',
    );
    await ComplaintService.instance.addEvidenceToComplaint(
      complaintId: complaintId,
      newImages: uploaded,
    );
    final complaint = getComplaintById(complaintId);
    if (complaint != null) {
      final existing = ((complaint['images'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      complaint['images'] = [...existing, ...uploaded];
      complaint['upvotes'] = ((complaint['upvotes'] as num?)?.toInt() ?? 0) + 1;
      complaint['lastUpdate'] = DateTime.now();
      complaint.addAll(_decorateComplaint(complaint));
      notifyListeners();
    }
  }
}
