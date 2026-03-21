import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'complaint_store.dart';

class LegacyDashboardAdapter {
  LegacyDashboardAdapter._();

  static List<Map<String, dynamic>> allComplaints() {
    return ComplaintStore.instance.complaints
        .map(_toLegacyListComplaint)
        .toList();
  }

  static List<Map<String, dynamic>> detailComplaints(
    Iterable<Map<String, dynamic>> complaints,
  ) {
    return complaints.map(_toLegacyDetailComplaint).toList();
  }

  static List<Map<String, dynamic>> citizenMyComplaints() {
    return ComplaintStore.instance
        .getComplaintsReportedByCurrentUser()
        .map(_toLegacyDetailComplaint)
        .toList();
  }

  static List<Map<String, dynamic>> citizenOtherComplaints() {
    return ComplaintStore.instance
        .getOtherCitizenComplaints(limit: 100)
        .map(_toLegacyDetailComplaint)
        .toList();
  }

  static List<Map<String, dynamic>> jeNewComplaints(
    List<String> assignedWards,
  ) {
    return ComplaintStore.instance
        .getComplaintsForJE(assignedWards)
        .where((c) => (c['status'] ?? 'New') == 'New')
        .map(_toLegacyDetailComplaint)
        .toList();
  }

  static List<Map<String, dynamic>> jeAssignedComplaints(
    List<String> assignedWards,
  ) {
    return ComplaintStore.instance
        .getComplaintsForJE(assignedWards)
        .where(_isVerifiedAndAssigned)
        .map(_toLegacyDetailComplaint)
        .toList();
  }

  static List<Map<String, dynamic>> aeNewComplaints(
    List<String> assignedWards,
  ) {
    return ComplaintStore.instance
        .getComplaintsForAE(assignedWards)
        .where(
          (c) =>
              (c['status'] ?? 'New') == 'New' ||
              (c['status'] ?? '') == 'Escalated',
        )
        .map(_toLegacyDetailComplaint)
        .toList();
  }

  static List<Map<String, dynamic>> aeAssignedComplaints(
    List<String> assignedWards,
  ) {
    return ComplaintStore.instance
        .getComplaintsForAE(assignedWards)
        .where(_isVerifiedAndAssigned)
        .map(_toLegacyDetailComplaint)
        .toList();
  }

  static List<Map<String, dynamic>> deNewComplaints(
    List<String> assignedWards,
  ) {
    return ComplaintStore.instance
        .getComplaintsForDE(assignedWards)
        .where(
          (c) =>
              (c['status'] ?? 'New') == 'New' ||
              (c['status'] ?? '') == 'Escalated',
        )
        .map(_toLegacyDetailComplaint)
        .toList();
  }

  static List<Map<String, dynamic>> deAssignedComplaints(
    List<String> assignedWards,
  ) {
    return ComplaintStore.instance
        .getComplaintsForDE(assignedWards)
        .where(_isVerifiedAndAssigned)
        .map(_toLegacyDetailComplaint)
        .toList();
  }

  static List<Map<String, dynamic>> ceEscalatedComplaints() {
    return ComplaintStore.instance
        .getComplaintsPendingCEAuthorization()
        .map(
          (c) => {
            ..._toLegacyDetailComplaint(c),
            'escalatedDate': c['lastUpdate'] ?? c['submittedDate'],
            'escalatedFrom': c['escalatedFrom'] ?? 'Engineer',
            'escalationReason':
                c['officialRemarks'] ?? 'Submitted for final authorization',
            'daysPending': _daysPending(c['submittedDate'] as DateTime?),
          },
        )
        .toList();
  }

  static List<Map<String, dynamic>> ceHighSeverityComplaints() {
    return ComplaintStore.instance.complaints
        .where(
          (c) =>
              ['High', 'Critical'].contains((c['severity'] ?? '').toString()),
        )
        .map(
          (c) => {
            ..._toLegacyDetailComplaint(c),
            'riskType': (c['severity'] ?? '').toString() == 'Critical'
                ? 'Accident-prone'
                : 'Infrastructure risk',
            'estimatedCost': 'Pending estimate',
          },
        )
        .toList();
  }

  static List<Map<String, dynamic>> ceLongPendingComplaints() {
    return ComplaintStore.instance.complaints
        .where((c) => _daysPending(c['submittedDate'] as DateTime?) >= 7)
        .map(
          (c) => {
            ..._toLegacyDetailComplaint(c),
            'daysPending': _daysPending(c['submittedDate'] as DateTime?),
            'jeName': c['escalatedFrom'] ?? 'Field Engineer',
            'contractor': c['assignedTo'],
          },
        )
        .toList();
  }

  static List<Map<String, dynamic>> contractorComplaints() {
    return ComplaintStore.instance
        .getContractorComplaints()
        .where(_isVerifiedAndAssigned)
        .map(_toLegacyDetailComplaint)
        .toList();
  }

  static List<Map<String, dynamic>> workGangComplaints() {
    return ComplaintStore.instance
        .getWorkGangComplaints()
        .where(_isVerifiedAndAssigned)
        .map(_toLegacyDetailComplaint)
        .toList();
  }

  static List<Map<String, dynamic>> mapLocations(
    Iterable<Map<String, dynamic>> complaints,
  ) {
    return complaints
        .where((c) => c['coords'] is LatLng)
        .map(
          (c) => {
            'id': c['id'],
            'title': c['title'],
            'location': c['coords'],
            'status': c['status'],
            'color': _markerColor((c['status'] ?? '').toString()),
            'isMine': c['isMine'] ?? false,
            'address': c['location'],
            'submittedDate': _formatLegacyDate(c['submittedDate']),
            'lastUpdated': c['lastUpdated'],
            'upvotes': c['upvotes'] ?? 0,
            'hasUpvoted': c['hasUpvoted'] ?? false,
            'images': c['images'] ?? const [],
            'timeline': c['timeline'] ?? const [],
            'verificationRemarks': c['verificationRemarks'] ?? const [],
            'officialRemarks': c['officialRemarks'],
            'coords': c['coords'],
            'currentHandler': c['currentHandler'],
            'receivedAtCurrentLevel': c['receivedAtCurrentLevel'],
            'escalatedFrom': c['escalatedFrom'],
          },
        )
        .toList();
  }

  static Map<String, dynamic> _toLegacyListComplaint(
    Map<String, dynamic> complaint,
  ) {
    return {
      'id': complaint['id'],
      'title': complaint['title'],
      'location': complaint['location'],
      'coords': complaint['coords'],
      'severity': complaint['severity'] ?? 'Medium',
      'status': complaint['status'] ?? 'New',
      'date': _legacyShortDate(complaint['submittedDate'] as DateTime?),
      'images': complaint['images'] ?? const [],
    };
  }

  static Map<String, dynamic> _toLegacyDetailComplaint(
    Map<String, dynamic> complaint,
  ) {
    return {
      'id': complaint['id'],
      'title': complaint['title'],
      'location': complaint['location'],
      'coords': complaint['coords'],
      'ward': complaint['ward'] ?? 'Ward',
      'status': complaint['status'] ?? 'New',
      'severity': complaint['severity'] ?? 'Medium',
      'submittedDate': complaint['submittedDate'],
      'lastUpdate': complaint['lastUpdate'] ?? complaint['submittedDate'],
      'lastUpdated':
          complaint['lastUpdated'] ??
          _relative(complaint['lastUpdate'] as DateTime?),
      'isMine': complaint['isMine'] ?? false,
      'upvotes': complaint['upvotes'] ?? 0,
      'hasUpvoted': complaint['hasUpvoted'] ?? false,
      'verificationRemarks': complaint['verificationRemarks'] ?? const [],
      'officialRemarks': complaint['officialRemarks'] ?? '',
      'images': complaint['images'] ?? const [],
      'timeline': complaint['timeline'] ?? const [],
      'currentHandler': complaint['currentHandler'],
      'receivedAtCurrentLevel': complaint['receivedAtCurrentLevel'],
      'escalatedFrom': complaint['escalatedFrom'],
      'assignedTo': complaint['assignedTo'],
      'assignedPartyType': complaint['assignedPartyType'],
      'workGang': complaint['workGang'],
      'reportedBy': complaint['reportedBy'],
      'aiRecommendation': complaint['aiRecommendation'],
      'aiResult': complaint['aiResult'],
      'aiInputImage': complaint['aiInputImage'],
      'aiAnalyzedAt': complaint['aiAnalyzedAt'],
      'date': _legacyShortDate(complaint['submittedDate'] as DateTime?),
    };
  }

  static Color _markerColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'pending ce authorization':
      case 'pending approval':
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'escalated':
        return Colors.red;
      default:
        return Colors.red;
    }
  }

  static String _legacyShortDate(DateTime? date) {
    if (date == null) return 'Jan 2026';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _formatLegacyDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day.toString().padLeft(2, '0')} Jan ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  static String _relative(DateTime? date) {
    if (date == null) return 'Updated recently';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minutes ago';
    return 'Just now';
  }

  static int _daysPending(DateTime? date) {
    if (date == null) return 0;
    return DateTime.now().difference(date).inDays;
  }

  static bool _isVerifiedAndAssigned(Map<String, dynamic> complaint) {
    final status = (complaint['status'] ?? '').toString().trim().toLowerCase();
    final isVerifiedStage =
        status == 'verified' ||
        status == 'in progress' ||
        status == 'pending ce authorization' ||
        status == 'resolved';
    if (!isVerifiedStage) return false;

    final assignedTo = (complaint['assignedTo'] ?? '').toString().trim();
    final assignedPartyType = (complaint['assignedPartyType'] ?? '')
        .toString()
        .trim();
    final workGang = (complaint['workGang'] ?? '').toString().trim();
    return assignedTo.isNotEmpty ||
        assignedPartyType.isNotEmpty ||
        workGang.isNotEmpty;
  }
}
