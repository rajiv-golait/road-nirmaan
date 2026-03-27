import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/escalation_config.dart';

const String complaintRoleJE = 'JE';
const String complaintRoleAE = 'AE';
const String complaintRoleDE = 'DE';
const String complaintRoleCE = 'CE';
const String complaintRoleAC = 'AC';
const String complaintRoleCommissioner = 'Commissioner';

String _nextHandlerRole(String currentRole) {
  switch (currentRole) {
    case complaintRoleJE:
      return complaintRoleAE;
    case complaintRoleAE:
      return complaintRoleDE;
    case complaintRoleDE:
      return complaintRoleCE;
    default:
      return currentRole;
  }
}

int _effectiveSla(String role, String severity) {
  if (role == complaintRoleCE ||
      role == complaintRoleAC ||
      role == complaintRoleCommissioner) {
    return 999;
  }
  return EscalationConfig.getEffectiveSLA(
    role == complaintRoleJE
        ? 'junior_engineer'
        : role == complaintRoleAE
        ? 'assistant_engineer'
        : 'deputy_engineer',
    severity,
  );
}

class ComplaintService {
  ComplaintService._();
  static final ComplaintService instance = ComplaintService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _recordEvent({
    required String complaintId,
    required String eventType,
    String? remarks,
    Map<String, dynamic>? metadata,
    String? fromStatus,
    String? toStatus,
  }) async {
    try {
      await _client.from('complaint_events').insert({
        'complaint_id': complaintId,
        'event_type': eventType,
        'actor_user_id': _client.auth.currentUser?.id,
        'actor_email': _client.auth.currentUser?.email,
        'remarks': remarks,
        'metadata': metadata,
        if (fromStatus != null) 'from_status': fromStatus,
        if (toStatus != null) 'to_status': toStatus,
      });
    } catch (e) {
      debugPrint(
        'Failed to record event: $e. Complaint saved but audit trail missing.',
      );
    }
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final raw = value.toString().trim();
    if (raw.isEmpty || raw == 'null') return null;
    return DateTime.tryParse(raw);
  }

  List<String> _parseImages(dynamic value) {
    if (value == null) return <String>[];
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty || raw == 'null') return <String>[];

    if (raw.startsWith('[') && raw.endsWith(']')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList();
        }
      } catch (e) {
        debugPrint('Failed to parse image list: $e');
      }
    }

    if (raw.startsWith('{') && raw.endsWith('}')) {
      final inner = raw.substring(1, raw.length - 1).trim();
      if (inner.isEmpty) return <String>[];
      return inner
          .split(',')
          .map((item) => item.trim().replaceAll('"', ''))
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final single = raw.replaceAll('"', '').trim();
    return single.isEmpty ? <String>[] : <String>[single];
  }

  Map<String, dynamic> mapRowToApp(Map<String, dynamic> row) {
    final lat = row['latitude'] as num?;
    final lng = row['longitude'] as num?;
    return {
      'id': row['id'],
      'title': row['title'],
      'description': row['description'],
      'damageType': row['damage_type'],
      'location': row['location'],
      'wardZone': row['ward_zone'],
      'ward': row['ward_zone'],
      'coords': (lat != null && lng != null)
          ? LatLng(lat.toDouble(), lng.toDouble())
          : null,
      'severity': row['severity'] ?? 'Medium',
      'severityScore': (row['severity_score'] as num?)?.toDouble(),
      'priorityScore': (row['priority_score'] as num?)?.toDouble(),
      'epdoScore': (row['epdo_score'] as num?)?.toDouble(),
      'totalPotholes': (row['total_potholes'] as num?)?.toInt(),
      'aiSource': row['ai_source'],
      'locationIsApproximate': row['location_is_approximate'] as bool? ?? false,
      'status': row['status'] ?? 'Open',
      'submittedDate': _toDateTime(row['created_at']),
      'verifiedDate': _toDateTime(row['verified_date']),
      'lastUpdate': _toDateTime(row['last_update']),
      'assignedTo': row['assigned_to'],
      'assignedPartyType': row['assigned_party_type'],
      'workGang': row['work_gang'],
      'officialRemarks': row['official_remarks'],
      'images': _parseImages(row['images']),
      'beforeImages': _parseImages(row['before_images']),
      'afterImages': _parseImages(row['after_images']),
      'ssimScore': (row['ssim_score'] as num?)?.toDouble(),
      'verificationStatus': row['verification_status'],
      'verificationHash': row['verification_hash'],
      'currentHandler': row['current_handler'] ?? complaintRoleJE,
      'receivedAtCurrentLevel': _toDateTime(row['received_at_current_level']),
      'escalatedFrom': row['escalated_from'],
      'autoEscalatedAt': _toDateTime(row['auto_escalated_at']),
      'manuallyEscalatedAt': _toDateTime(row['manually_escalated_at']),
      'reportedBy': row['reported_by'] ?? 'citizen',
      'reportedByUserId': row['reported_by_user_id'],
      'upvotes': row['upvotes'] ?? 0,
    };
  }

  Map<String, dynamic> mapAppToRow(Map<String, dynamic> app) {
    final row = <String, dynamic>{};
    if (app.containsKey('title')) row['title'] = app['title'];
    if (app.containsKey('description')) row['description'] = app['description'];
    if (app.containsKey('damageType')) row['damage_type'] = app['damageType'];
    if (app.containsKey('location')) row['location'] = app['location'];
    if (app.containsKey('wardZone')) {
      row['ward_zone'] = app['wardZone'];
    } else if (app.containsKey('ward')) {
      row['ward_zone'] = app['ward'];
    }
    if (app['coords'] != null) {
      final coords = app['coords'] as LatLng;
      row['latitude'] = coords.latitude;
      row['longitude'] = coords.longitude;
    }
    if (app.containsKey('severity')) row['severity'] = app['severity'];
    if (app.containsKey('severityScore'))
      row['severity_score'] = app['severityScore'];
    if (app.containsKey('priorityScore'))
      row['priority_score'] = app['priorityScore'];
    if (app.containsKey('epdoScore')) row['epdo_score'] = app['epdoScore'];
    if (app.containsKey('totalPotholes'))
      row['total_potholes'] = app['totalPotholes'];
    if (app.containsKey('status')) row['status'] = app['status'];
    if (app.containsKey('submittedDate'))
      row['created_at'] = (app['submittedDate'] as DateTime)
          .toIso8601String();
    if (app.containsKey('verifiedDate'))
      row['verified_date'] = (app['verifiedDate'] as DateTime?)
          ?.toIso8601String();
    if (app.containsKey('lastUpdate'))
      row['last_update'] = (app['lastUpdate'] as DateTime?)?.toIso8601String();
    if (app.containsKey('assignedTo')) row['assigned_to'] = app['assignedTo'];
    if (app.containsKey('assignedPartyType'))
      row['assigned_party_type'] = app['assignedPartyType'];
    if (app.containsKey('workGang')) row['work_gang'] = app['workGang'];
    if (app.containsKey('officialRemarks'))
      row['official_remarks'] = app['officialRemarks'];
    if (app.containsKey('images')) {
      final images = app['images'];
      if (images is List) {
        row['images'] = images.map((item) => item.toString()).toList();
      } else {
        row['images'] = images;
      }
    }
    if (app.containsKey('beforeImages')) {
      final beforeImages = app['beforeImages'];
      if (beforeImages is List) {
        row['before_images'] = beforeImages
            .map((item) => item.toString())
            .toList();
      } else {
        row['before_images'] = beforeImages;
      }
    }
    if (app.containsKey('afterImages')) {
      final afterImages = app['afterImages'];
      if (afterImages is List) {
        row['after_images'] = afterImages
            .map((item) => item.toString())
            .toList();
      } else {
        row['after_images'] = afterImages;
      }
    }
    if (app.containsKey('ssimScore')) row['ssim_score'] = app['ssimScore'];
    if (app.containsKey('verificationStatus'))
      row['verification_status'] = app['verificationStatus'];
    if (app.containsKey('verificationHash'))
      row['verification_hash'] = app['verificationHash'];
    if (app.containsKey('currentHandler'))
      row['current_handler'] = app['currentHandler'];
    if (app.containsKey('receivedAtCurrentLevel')) {
      row['received_at_current_level'] =
          (app['receivedAtCurrentLevel'] as DateTime?)?.toIso8601String();
    }
    if (app.containsKey('escalatedFrom'))
      row['escalated_from'] = app['escalatedFrom'];
    if (app.containsKey('autoEscalatedAt'))
      row['auto_escalated_at'] = (app['autoEscalatedAt'] as DateTime?)
          ?.toIso8601String();
    if (app.containsKey('manuallyEscalatedAt')) {
      row['manually_escalated_at'] = (app['manuallyEscalatedAt'] as DateTime?)
          ?.toIso8601String();
    }
    if (app.containsKey('reportedBy')) row['reported_by'] = app['reportedBy'];
    if (app.containsKey('reportedByUserId'))
      row['reported_by_user_id'] = app['reportedByUserId'];
    if (app.containsKey('upvotes')) row['upvotes'] = app['upvotes'];
    if (app.containsKey('aiSource')) row['ai_source'] = app['aiSource'];
    if (app.containsKey('locationIsApproximate')) {
      row['location_is_approximate'] = app['locationIsApproximate'];
    }
    return row;
  }

  Future<List<Map<String, dynamic>>> fetchComplaints() async {
    final response = await _client.from('complaints').select();
    final rows = (response as List<dynamic>).cast<Map<String, dynamic>>();
    return rows
        .where(
          (row) => (row['status'] ?? '').toString().toLowerCase() != 'deleted',
        )
        .map(mapRowToApp)
        .toList();
  }

  Future<Map<String, dynamic>> createComplaint(
    Map<String, dynamic> payload,
  ) async {
    final row = Map<String, dynamic>.from(mapAppToRow(payload));
    final missingColumnPattern = RegExp(r"'([^']+)' column");

    while (true) {
      try {
        final inserted = await _client
            .from('complaints')
            .insert(row)
            .select()
            .single();
        final mapped = mapRowToApp(inserted);

        // FIX 8: Record creation event for audit trail
        try {
          await _recordEvent(
            complaintId: inserted['id'].toString(),
            eventType: 'SUBMITTED',
            remarks: 'Complaint submitted by citizen. '
                'AI source: ${payload['aiSource'] ?? 'UNKNOWN'}. '
                'Location approximate: '
                '${payload['locationIsApproximate'] ?? false}.',
            metadata: <String, dynamic>{
              'ai_source': payload['aiSource'],
              'location_is_approximate': payload['locationIsApproximate'],
            },
          );
        } catch (e) {
          debugPrint(
            'Failed to record submission event: $e. Continuing without audit row.',
          );
        }

        return mapped;
      } on PostgrestException catch (e) {
        final match = missingColumnPattern.firstMatch(e.message);
        final missingColumn = match?.group(1);
        if (missingColumn == null || !row.containsKey(missingColumn)) rethrow;
        row.remove(missingColumn);
      }
    }
  }

  Future<void> updateComplaint(
    String complaintId,
    Map<String, dynamic> updates,
  ) async {
    final row = mapAppToRow(updates);
    if (row.isEmpty) return;
    await _client.from('complaints').update(row).eq('id', complaintId);
  }

  Future<void> deleteComplaint(String complaintId) async {
    try {
      final deletedRows = await _client
          .from('complaints')
          .delete()
          .eq('id', complaintId)
          .select('id');
      if (deletedRows is List && deletedRows.isNotEmpty) {
        return;
      }
    } catch (e) {
      debugPrint(
        'Hard delete failed for $complaintId, falling back to soft delete: $e',
      );
    }

    final updatedRows = await _client
        .from('complaints')
        .update({
          'status': 'Deleted',
          'last_update': DateTime.now().toIso8601String(),
        })
        .eq('id', complaintId)
        .select('id, status');
    if (updatedRows is! List || updatedRows.isEmpty) {
      throw Exception('Delete failed for complaint $complaintId.');
    }
    await _recordEvent(
      complaintId: complaintId,
      eventType: 'deleted',
      toStatus: 'Deleted',
      remarks: 'Complaint deleted by reporting user.',
    );
  }

  Future<Map<String, dynamic>> saveOfficialRemarks({
    required String complaintId,
    required Map<String, dynamic> existingComplaint,
    required String remarks,
  }) async {
    final update = {
      'officialRemarks': remarks.trim(),
      'lastUpdate': DateTime.now(),
    };
    await updateComplaint(complaintId, update);
    await _recordEvent(
      complaintId: complaintId,
      eventType: 'remarks_saved',
      remarks: remarks.trim(),
    );
    return {...existingComplaint, ...update};
  }

  Future<Map<String, dynamic>> verifyComplaint({
    required String complaintId,
    required Map<String, dynamic> existingComplaint,
    String? remarks,
  }) async {
    final update = {
      'status': 'Verified',
      'verifiedDate':
          existingComplaint['verifiedDate'] as DateTime? ?? DateTime.now(),
      'lastUpdate': DateTime.now(),
      if (remarks != null && remarks.trim().isNotEmpty)
        'officialRemarks': remarks.trim(),
    };
    await updateComplaint(complaintId, update);
    await _recordEvent(
      complaintId: complaintId,
      eventType: 'verified',
      remarks: remarks?.trim(),
    );
    return {...existingComplaint, ...update};
  }

  Future<Map<String, dynamic>> assignComplaint({
    required String complaintId,
    required Map<String, dynamic> existingComplaint,
    required String assignee,
    required String assigneeType,
    String? workGang,
    String? remarks,
  }) async {
    final normalizedRemarks = remarks?.trim();
    final update = {
      'status': 'InProgress',
      'assignedTo': assignee,
      'assignedPartyType': assigneeType,
      'workGang': workGang,
      'verifiedDate':
          existingComplaint['verifiedDate'] as DateTime? ?? DateTime.now(),
      'lastUpdate': DateTime.now(),
      if (normalizedRemarks != null && normalizedRemarks.isNotEmpty)
        'officialRemarks': normalizedRemarks,
    };
    await updateComplaint(complaintId, update);
    await _recordEvent(
      complaintId: complaintId,
      eventType: 'assigned',
      remarks: normalizedRemarks,
      metadata: {
        'assignee': assignee,
        'assigneeType': assigneeType,
        'workGang': workGang,
      },
    );
    return {...existingComplaint, ...update};
  }

  Future<Map<String, dynamic>> markResolved({
    required String complaintId,
    required Map<String, dynamic> existingComplaint,
    String? remarks,
  }) async {
    final normalizedRemarks = remarks?.trim();
    final update = {
      'status': 'Resolved',
      'lastUpdate': DateTime.now(),
      if (normalizedRemarks != null && normalizedRemarks.isNotEmpty)
        'officialRemarks': normalizedRemarks,
    };
    await updateComplaint(complaintId, update);
    await _recordEvent(
      complaintId: complaintId,
      eventType: 'resolved',
      remarks: normalizedRemarks,
    );
    return {...existingComplaint, ...update};
  }

  Future<void> submitForCeAuthorization({
    required String complaintId,
    required Map<String, dynamic> existingComplaint,
    required Map<String, dynamic> verificationData,
  }) async {
    final currentHandler =
        existingComplaint['currentHandler'] as String? ?? complaintRoleJE;
    final payload = mapAppToRow({
      ...existingComplaint,
      ...verificationData,
      'status': verificationData['status'] ?? 'PendingCEApproval',
      'currentHandler': complaintRoleCE,
      'receivedAtCurrentLevel': DateTime.now(),
      'escalatedFrom': currentHandler,
    });
    await _client.from('complaints').update(payload).eq('id', complaintId);
    final ssim = verificationData['ssimScore'];
    final vhash = verificationData['verificationHash'];
    Map<String, dynamic>? meta;
    if (ssim != null || vhash != null) {
      meta = {
        if (ssim != null) 'ssim_score': ssim,
        if (vhash != null) 'verification_hash': vhash,
      };
    }
    await _recordEvent(
      complaintId: complaintId,
      eventType: 'REPAIR_VERIFIED',
      remarks: verificationData['officialRemarks']?.toString(),
      fromStatus: existingComplaint['status']?.toString(),
      toStatus: 'PendingCEApproval',
      metadata: meta,
    );
  }

  Future<Map<String, dynamic>> authorizeComplaint({
    required String complaintId,
    required Map<String, dynamic> existingComplaint,
  }) async {
    final update = {
      'status': 'Resolved',
      'lastUpdate': DateTime.now(),
      'receivedAtCurrentLevel': DateTime.now(),
    };
    await updateComplaint(complaintId, update);
    await _recordEvent(complaintId: complaintId, eventType: 'authorized');
    return {...existingComplaint, ...update};
  }

  Future<Map<String, dynamic>> escalateComplaint({
    required String complaintId,
    required Map<String, dynamic> existingComplaint,
    required String remarks,
  }) async {
    final currentHandler =
        existingComplaint['currentHandler'] as String? ?? complaintRoleJE;
    final nextHandler = _nextHandlerRole(currentHandler);
    if (nextHandler == currentHandler) return existingComplaint;
    final note = '[Manual escalation] ${remarks.trim()}';
    final update = {
      'currentHandler': nextHandler,
      'receivedAtCurrentLevel': DateTime.now(),
      'escalatedFrom': currentHandler,
      'manuallyEscalatedAt': DateTime.now(),
      'officialRemarks': note,
    };
    await updateComplaint(complaintId, update);
    await _recordEvent(
      complaintId: complaintId,
      eventType: 'escalated',
      remarks: note,
      metadata: {'fromHandler': currentHandler, 'toHandler': nextHandler},
    );
    return {...existingComplaint, ...update};
  }

  Future<Map<String, dynamic>?> applyAutoEscalation(
    Map<String, dynamic> complaint,
  ) async {
    final currentHandler =
        complaint['currentHandler'] as String? ?? complaintRoleJE;
    final receivedAt =
        complaint['receivedAtCurrentLevel'] as DateTime? ??
        complaint['submittedDate'] as DateTime? ??
        DateTime.now();
    final severity = complaint['severity'] as String? ?? 'Medium';
    final slaDays = _effectiveSla(currentHandler, severity);
    if (slaDays >= 999) return null;

    final daysAtLevel = DateTime.now().difference(receivedAt).inDays;
    if (daysAtLevel < slaDays) return null;

    final nextHandler = _nextHandlerRole(currentHandler);
    if (nextHandler == currentHandler) return null;

    final update = {
      'currentHandler': nextHandler,
      'receivedAtCurrentLevel': DateTime.now(),
      'escalatedFrom': currentHandler,
      'autoEscalatedAt': DateTime.now(),
    };
    await updateComplaint(complaint['id'] as String, update);
    return {...complaint, ...update};
  }

  Future<void> persistAutoEscalation({
    required String complaintId,
    required String escalatedFrom,
    required String newHandler,
    required DateTime autoEscalatedAt,
  }) async {
    await updateComplaint(complaintId, {
      'currentHandler': newHandler,
      'receivedAtCurrentLevel': autoEscalatedAt,
      'escalatedFrom': escalatedFrom,
      'autoEscalatedAt': autoEscalatedAt,
      'lastUpdate': autoEscalatedAt,
    });
    await _recordEvent(
      complaintId: complaintId,
      eventType: 'AUTO_ESCALATED',
      metadata: {
        'fromHandler': escalatedFrom,
        'toHandler': newHandler,
        'actor_id': 'SYSTEM',
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchNearbyOpenComplaints({
    required double latitude,
    required double longitude,
    double delta = 0.001,
  }) async {
    final response = await _client
        .from('complaints')
        .select()
        .gte('latitude', latitude - delta)
        .lte('latitude', latitude + delta)
        .gte('longitude', longitude - delta)
        .lte('longitude', longitude + delta);
    final rows = (response as List<dynamic>).cast<Map<String, dynamic>>();
    return rows
        .where((row) {
          final status = (row['status'] ?? '').toString().toLowerCase();
          return status != 'resolved' &&
              status != 'closed' &&
              status != 'deleted';
        })
        .map(mapRowToApp)
        .toList();
  }

  Future<void> addEvidenceToComplaint({
    required String complaintId,
    required List<String> newImages,
  }) async {
    final existing = await _client
        .from('complaints')
        .select('images, upvotes')
        .eq('id', complaintId)
        .single();
    final currentImages = _parseImages(existing['images']);
    final merged = [...currentImages, ...newImages];
    final upvotes = ((existing['upvotes'] as num?)?.toInt() ?? 0) + 1;
    await _client
        .from('complaints')
        .update({
          'images': merged,
          'upvotes': upvotes,
          'last_update': DateTime.now().toIso8601String(),
        })
        .eq('id', complaintId);
    await _recordEvent(
      complaintId: complaintId,
      eventType: 'duplicate_evidence_appended',
      metadata: {'newImagesCount': newImages.length},
    );
  }

  Future<bool> hasUpvoted(String complaintId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final vote = await _client
        .from('complaint_votes')
        .select('complaint_id')
        .eq('complaint_id', complaintId)
        .eq('user_id', userId)
        .maybeSingle();
    return vote != null;
  }

  Future<Set<String>> fetchUpvotedComplaintIds(
    List<String> complaintIds,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || complaintIds.isEmpty) return <String>{};

    try {
      final votes = await _client
          .from('complaint_votes')
          .select('complaint_id')
          .eq('user_id', userId)
          .inFilter('complaint_id', complaintIds);

      return (votes as List<dynamic>)
          .map(
            (vote) =>
                (vote as Map<String, dynamic>)['complaint_id']?.toString(),
          )
          .whereType<String>()
          .toSet();
    } catch (e) {
      debugPrint('Failed to fetch upvoted complaints: $e');
      return <String>{};
    }
  }

  Future<int> toggleUpvote(
    String complaintId, {
    required bool shouldUpvote,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You must be logged in to upvote a complaint.');
    }

    if (shouldUpvote) {
      await _client.from('complaint_votes').upsert({
        'complaint_id': complaintId,
        'user_id': userId,
      });
    } else {
      await _client
          .from('complaint_votes')
          .delete()
          .eq('complaint_id', complaintId)
          .eq('user_id', userId);
    }

    final complaint = await _client
        .from('complaints')
        .select('upvotes')
        .eq('id', complaintId)
        .single();
    return (complaint['upvotes'] as num?)?.toInt() ?? 0;
  }
}
