import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_flags.dart';

class MockDataSeeder {
  MockDataSeeder._();
  static final MockDataSeeder instance = MockDataSeeder._();

  SupabaseClient get _client => Supabase.instance.client;

  static const List<Map<String, dynamic>> _mockComplaints = [
    {
      'id': 'MOCK-001',
      'title': 'Severe Potholes on MG Road',
      'description':
          'Multiple large potholes filled with water near Central Mall causing traffic jams and risk of accidents. Several two-wheelers have fallen here in the past week.',
      'damage_type': 'Pothole',
      'location': 'MG Road, Near Central Mall, Solapur',
      'ward': 'Ward 12',
      'lat': 17.6715,
      'lng': 75.9101,
      'severity': 'High',
      'status': 'InProgress',
      'current_handler': 'JE',
      'assigned_to': 'Sharma Contractors Pvt Ltd',
      'assigned_party_type': 'Contractor',
      'official_remarks':
          'Contractor mobilized. Patching work started on site.',
      'reported_by': 'citizen',
      'upvotes': 42,
      'images': [
        'assets/Screenshot 2026-03-17 022153.png',
        'assets/Screenshot 2026-03-17 022201.png',
      ],
      'days_ago': 10,
      'verified_days_ago': 8,
    },
    {
      'id': 'MOCK-002',
      'title': 'Waterlogged Road Near Railway Station',
      'description':
          'Severe waterlogging with deep potholes making road nearly impassable. Commuters forced to wade through knee-deep water. Drainage appears completely blocked.',
      'damage_type': 'Waterlogging',
      'location': 'Railway Station Road, Solapur',
      'ward': 'Ward 14',
      'lat': 17.6620,
      'lng': 75.9020,
      'severity': 'Critical',
      'status': 'Escalated',
      'current_handler': 'AE',
      'escalated_from': 'JE',
      'official_remarks':
          '[Manual escalation] JE SLA expired. Escalated for urgent intervention.',
      'reported_by': 'citizen',
      'upvotes': 78,
      'images': [
        'assets/Screenshot 2026-03-17 022322.png',
        'assets/Screenshot 2026-03-17 022330.png',
      ],
      'days_ago': 15,
      'manually_escalated_days_ago': 3,
    },
    {
      'id': 'MOCK-003',
      'title': 'Cracked Surface at Hotgi Road',
      'description':
          'Road surface has developed deep cracks and loose gravel near the temple area. Potholes filled with muddy water after rain making them invisible to drivers.',
      'damage_type': 'Surface Crack',
      'location': 'Hotgi Road, Near Siddheshwar Temple, Solapur',
      'ward': 'Ward 13',
      'lat': 17.6550,
      'lng': 75.9150,
      'severity': 'Medium',
      'status': 'Verified',
      'current_handler': 'JE',
      'official_remarks':
          'Verified on field. Road surface severely degraded. Awaiting contractor assignment.',
      'reported_by': 'citizen',
      'upvotes': 18,
      'images': [
        'assets/Screenshot 2026-03-17 022206.png',
        'assets/Screenshot 2026-03-17 022243.png',
      ],
      'days_ago': 7,
      'verified_days_ago': 4,
    },
    {
      'id': 'MOCK-004',
      'title': 'Deep Pothole at Traffic Signal',
      'description':
          'Large, deep pothole right at the traffic signal junction. Vehicles swerving to avoid it causing near-miss accidents. Immediate repair needed for safety.',
      'damage_type': 'Pothole',
      'location': 'Murarji Peth Main Road, Solapur',
      'ward': 'Ward 8',
      'lat': 17.6680,
      'lng': 75.9080,
      'severity': 'High',
      'status': 'Open',
      'current_handler': 'JE',
      'reported_by': 'citizen',
      'upvotes': 25,
      'images': [
        'assets/Screenshot 2026-03-17 022223.png',
        'assets/Screenshot 2026-03-17 022302.png',
      ],
      'days_ago': 2,
    },
    {
      'id': 'MOCK-005',
      'title': 'Highway Bridge Approach Damage',
      'description':
          'Bridge approach road has collapsed in multiple places. Heavy vehicles are getting stuck. Risk of structural damage to the bridge expansion joints.',
      'damage_type': 'Structural Damage',
      'location': 'Old Pune Naka Bridge, Solapur',
      'ward': 'Ward 10',
      'lat': 17.6780,
      'lng': 75.8980,
      'severity': 'Critical',
      'status': 'PendingCEApproval',
      'current_handler': 'CE',
      'escalated_from': 'DE',
      'official_remarks':
          'Requires major repair. Estimated cost exceeds JE approval limit. Submitted for CE authorization.',
      'reported_by': 'nagarsevak',
      'upvotes': 95,
      'images': [
        'assets/Screenshot 2026-03-17 022214.png',
        'assets/Screenshot 2026-03-17 022232.png',
      ],
      'days_ago': 20,
      'verified_days_ago': 18,
    },
    {
      'id': 'MOCK-006',
      'title': 'Multiple Potholes on Bhavani Peth Road',
      'description':
          'Entire stretch of 200 meters has multiple potholes. Auto-rickshaws and scooters face extreme difficulty navigating. Residents have complained multiple times.',
      'damage_type': 'Pothole',
      'location': 'Bhavani Peth Road, Solapur',
      'ward': 'Ward 15',
      'lat': 17.6750,
      'lng': 75.9250,
      'severity': 'High',
      'status': 'InProgress',
      'current_handler': 'JE',
      'assigned_to': 'Municipal Work Gang B',
      'assigned_party_type': 'Work Gang',
      'work_gang': 'Gang B - Surface Repair Unit',
      'official_remarks':
          'Work gang deployed. Cold mix patching underway. Expected completion in 3 days.',
      'reported_by': 'citizen',
      'upvotes': 56,
      'images': [
        'assets/Screenshot 2026-03-17 022338.png',
        'assets/Screenshot 2026-03-17 022358.png',
      ],
      'days_ago': 12,
      'verified_days_ago': 9,
    },
    {
      'id': 'MOCK-007',
      'title': 'Road Edge Erosion Near Park',
      'description':
          'Road edge has eroded significantly near the park entrance. Shoulder has given way with loose gravel spreading on the main road. Dangerous for pedestrians.',
      'damage_type': 'Edge Erosion',
      'location': 'Vijay Nagar, Near Park, Solapur',
      'ward': 'Ward 5',
      'lat': 17.6600,
      'lng': 75.9000,
      'severity': 'Medium',
      'status': 'Open',
      'current_handler': 'JE',
      'reported_by': 'citizen',
      'upvotes': 8,
      'images': [
        'assets/Screenshot 2026-03-17 022238.png',
        'assets/Screenshot 2026-03-17 022251.png',
      ],
      'days_ago': 3,
    },
    {
      'id': 'MOCK-008',
      'title': 'Broken Paver Block Road',
      'description':
          'Paver blocks have completely broken and sunk near the auto-rickshaw stand. Exposed foundation causing tripping hazard for pedestrians and damage to vehicles.',
      'damage_type': 'Paver Block Damage',
      'location': 'Station Road, Near Bus Stand, Solapur',
      'ward': 'Ward 3',
      'lat': 17.6650,
      'lng': 75.9050,
      'severity': 'Medium',
      'status': 'Resolved',
      'current_handler': 'JE',
      'assigned_to': 'Sharma Contractors Pvt Ltd',
      'assigned_party_type': 'Contractor',
      'official_remarks':
          'Paver blocks replaced and compacted. Road restored to original condition. Site cleared.',
      'reported_by': 'citizen',
      'upvotes': 31,
      'images': [
        'assets/Screenshot 2026-03-17 022407.png',
        'assets/download (2).jpg',
      ],
      'days_ago': 25,
      'verified_days_ago': 22,
    },
    {
      'id': 'MOCK-009',
      'title': 'Severe Surface Damage Under Flyover',
      'description':
          'Service road under the flyover has severe surface damage with deep craters. Water accumulates making driving extremely hazardous especially at night.',
      'damage_type': 'Surface Damage',
      'location': 'Solapur Flyover Service Road, Solapur',
      'ward': 'Ward 12',
      'lat': 17.6800,
      'lng': 75.9200,
      'severity': 'High',
      'status': 'Under Review',
      'current_handler': 'JE',
      'reported_by': 'official',
      'upvotes': 15,
      'images': [
        'assets/Screenshot 2026-03-17 022330.png',
        'assets/Screenshot 2026-03-17 022420.png',
      ],
      'days_ago': 5,
    },
    {
      'id': 'MOCK-010',
      'title': 'Pothole Cluster on Vijapur Road',
      'description':
          'A cluster of 8-10 potholes in a 100-meter stretch. Road surface has deteriorated completely after recent heavy rains. Two-wheelers are most affected.',
      'damage_type': 'Pothole',
      'location': 'Vijapur Road, Solapur',
      'ward': 'Ward 7',
      'lat': 17.6500,
      'lng': 75.9100,
      'severity': 'Medium',
      'status': 'InProgress',
      'current_handler': 'JE',
      'assigned_to': 'Municipal Work Gang A',
      'assigned_party_type': 'Work Gang',
      'work_gang': 'Gang A - Road Repair Unit',
      'official_remarks': 'Work gang dispatched. Patching InProgress.',
      'reported_by': 'citizen',
      'upvotes': 22,
      'images': [
        'assets/Screenshot 2026-03-17 022420.png',
        'assets/Screenshot 2026-03-17 022153.png',
      ],
      'days_ago': 8,
      'verified_days_ago': 6,
    },
    {
      'id': 'MOCK-011',
      'title': 'Road Subsidence at Siddheshwar Peth',
      'description':
          'Road has subsided by 6 inches over a 50-meter stretch. Underground drainage issue suspected. Vehicles tilting dangerously when passing through.',
      'damage_type': 'Subsidence',
      'location': 'Siddheshwar Peth, Solapur',
      'ward': 'Ward 9',
      'lat': 17.6850,
      'lng': 75.8850,
      'severity': 'High',
      'status': 'Escalated',
      'current_handler': 'DE',
      'escalated_from': 'AE',
      'official_remarks':
          'Escalated to Deputy Engineer. Subsidence likely caused by drainage pipe burst. Multi-department coordination needed.',
      'reported_by': 'citizen',
      'upvotes': 67,
      'images': [
        'assets/images (2).jpg',
        'assets/Screenshot 2026-03-17 022201.png',
      ],
      'days_ago': 18,
      'auto_escalated_days_ago': 2,
    },
    {
      'id': 'MOCK-012',
      'title': 'Minor Road Damage Near Bus Stand',
      'description':
          'Small potholes and uneven surface near the main bus stand entrance. Low severity but affects heavy foot traffic area.',
      'damage_type': 'Pothole',
      'location': 'Solapur Bus Stand Road, Solapur',
      'ward': 'Ward 14',
      'lat': 17.6599,
      'lng': 75.9064,
      'severity': 'Low',
      'status': 'Resolved',
      'current_handler': 'JE',
      'assigned_to': 'Municipal Work Gang A',
      'assigned_party_type': 'Work Gang',
      'work_gang': 'Gang A - Road Repair Unit',
      'official_remarks':
          'Potholes filled with hot mix asphalt. Surface leveled and compacted. Site cleared.',
      'reported_by': 'citizen',
      'upvotes': 12,
      'images': ['assets/download (3).jpg', 'assets/images (3).jpg'],
      'days_ago': 30,
      'verified_days_ago': 27,
    },
    {
      'id': 'MOCK-013',
      'title': 'Pothole Hazard at School Zone',
      'description':
          'Dangerous pothole right outside school gate. School buses and children walking are at risk. Urgent action required before school reopens on Monday.',
      'damage_type': 'Pothole',
      'location': 'Sadar Bazar School Area, Solapur',
      'ward': 'Ward 6',
      'lat': 17.6450,
      'lng': 75.9350,
      'severity': 'Critical',
      'status': 'Open',
      'current_handler': 'JE',
      'reported_by': 'nagarsevak',
      'upvotes': 35,
      'images': [
        'assets/Screenshot 2026-03-17 022251.png',
        'assets/Screenshot 2026-03-17 022302.png',
        'assets/images (5).jpg',
      ],
      'days_ago': 1,
    },
    {
      'id': 'MOCK-014',
      'title': 'Surface Erosion on Akkalkot Road',
      'description':
          'Road surface has eroded with loose gravel and debris. Multiple potholes forming after recent rainfall. Need resurfacing over 150-meter stretch.',
      'damage_type': 'Surface Erosion',
      'location': 'Akkalkot Road, Solapur',
      'ward': 'Ward 11',
      'lat': 17.6500,
      'lng': 75.9450,
      'severity': 'Medium',
      'status': 'Verified',
      'current_handler': 'JE',
      'official_remarks':
          'Field verified. Surface erosion confirmed over 150m stretch. Awaiting work gang assignment.',
      'reported_by': 'citizen',
      'upvotes': 14,
      'images': [
        'assets/images (4).jpg',
        'assets/Screenshot 2026-03-17 022358.png',
      ],
      'days_ago': 9,
      'verified_days_ago': 6,
    },
    {
      'id': 'MOCK-015',
      'title': 'Waterlogged Road at Market Area',
      'description':
          'Chronic waterlogging at Shivaji Market with deep potholes hidden under standing water. Several shops affected. Drainage system needs complete overhaul.',
      'damage_type': 'Waterlogging',
      'location': 'Shivaji Market Area, Solapur',
      'ward': 'Ward 5',
      'lat': 17.6650,
      'lng': 75.9150,
      'severity': 'High',
      'status': 'InProgress',
      'current_handler': 'AE',
      'escalated_from': 'JE',
      'assigned_to': 'Patil Infrastructure Works',
      'assigned_party_type': 'Contractor',
      'official_remarks':
          'Contractor engaged for drainage clearing and road repair. Work expected to take 5 days.',
      'reported_by': 'citizen',
      'upvotes': 48,
      'images': [
        'assets/Screenshot 2026-03-17 022322.png',
        'assets/Screenshot 2026-03-17 022338.png',
        'assets/images (6).jpg',
      ],
      'days_ago': 14,
      'verified_days_ago': 12,
    },
    {
      'id': 'MOCK-016',
      'title': 'Fresh Pothole Cluster Near Civil Hospital',
      'description':
          'Newly reported pothole cluster outside Civil Hospital entrance. Ambulance lane is affected and requires immediate JE review.',
      'damage_type': 'Pothole',
      'location': 'Civil Hospital Road, Solapur',
      'ward': 'Ward 12',
      'lat': 17.6732,
      'lng': 75.9118,
      'severity': 'High',
      'status': 'Open',
      'current_handler': 'JE',
      'reported_by': 'citizen',
      'upvotes': 11,
      'images': [
        'assets/Screenshot 2026-03-17 022153.png',
        'assets/Screenshot 2026-03-17 022302.png',
      ],
      'days_ago': 1,
    },
    {
      'id': 'MOCK-017',
      'title': 'Verified Road Patch Work Near MIDC Gate',
      'description':
          'JE verified a damaged stretch near MIDC gate and assigned contractor for patch restoration. Work is currently active.',
      'damage_type': 'Surface Damage',
      'location': 'MIDC Gate Road, Solapur',
      'ward': 'Ward 14',
      'lat': 17.6618,
      'lng': 75.9049,
      'severity': 'Medium',
      'status': 'InProgress',
      'current_handler': 'JE',
      'assigned_to': 'Sharma Contractors Pvt Ltd',
      'assigned_party_type': 'Contractor',
      'official_remarks':
          'Verified and assigned. Contractor started milling and patch prep.',
      'reported_by': 'citizen',
      'upvotes': 16,
      'images': [
        'assets/Screenshot 2026-03-17 022201.png',
        'assets/Screenshot 2026-03-17 022338.png',
      ],
      'days_ago': 2,
      'verified_days_ago': 1,
    },
    {
      'id': 'MOCK-018',
      'title': 'Verified Shoulder Repair Near Water Tank',
      'description':
          'JE verified edge damage near the municipal water tank and assigned a work gang for shoulder repair and compaction.',
      'damage_type': 'Edge Erosion',
      'location': 'Municipal Water Tank Road, Solapur',
      'ward': 'Ward 13',
      'lat': 17.6562,
      'lng': 75.9134,
      'severity': 'Medium',
      'status': 'Verified',
      'current_handler': 'JE',
      'assigned_to': 'Municipal Work Gang B',
      'assigned_party_type': 'Work Gang',
      'work_gang': 'Gang B - Surface Repair Unit',
      'official_remarks':
          'Field verification completed. Work gang assigned and mobilization done.',
      'reported_by': 'citizen',
      'upvotes': 13,
      'images': [
        'assets/Screenshot 2026-03-17 022238.png',
        'assets/Screenshot 2026-03-17 022358.png',
      ],
      'days_ago': 3,
      'verified_days_ago': 2,
    },
    {
      'id': 'MOCK-019',
      'title': 'In-Progress Pothole Restoration at Tilak Chowk',
      'description':
          'Complaint verified by JE and assigned to contractor. Milling and pothole filling are currently InProgress on site.',
      'damage_type': 'Pothole',
      'location': 'Tilak Chowk Main Road, Solapur',
      'ward': 'Ward 15',
      'lat': 17.6744,
      'lng': 75.9242,
      'severity': 'High',
      'status': 'InProgress',
      'current_handler': 'JE',
      'assigned_to': 'Sharma Contractors Pvt Ltd',
      'assigned_party_type': 'Contractor',
      'official_remarks':
          'Verified and assigned. Contractor started restoration in first 80m stretch.',
      'reported_by': 'citizen',
      'upvotes': 21,
      'images': [
        'assets/Screenshot 2026-03-17 022201.png',
        'assets/Screenshot 2026-03-17 022330.png',
      ],
      'days_ago': 4,
      'verified_days_ago': 2,
    },
    {
      'id': 'MOCK-020',
      'title': 'New Road Crack Near Collector Office',
      'description':
          'Fresh longitudinal cracking reported near Collector Office junction. JE review required before the next rain spell.',
      'damage_type': 'Road Crack',
      'location': 'Collector Office Junction, Solapur',
      'ward': 'Ward 12',
      'lat': 17.6693,
      'lng': 75.9092,
      'severity': 'Medium',
      'status': 'Open',
      'current_handler': 'JE',
      'reported_by': 'citizen',
      'upvotes': 9,
      'images': ['assets/download (2).jpg', 'assets/download (3).jpg'],
      'days_ago': 1,
    },
    {
      'id': 'MOCK-021',
      'title': 'Verified Patch Assignment at Navi Peth',
      'description':
          'JE completed verification and assigned contractor for urgent pothole patching across the main carriageway.',
      'damage_type': 'Pothole',
      'location': 'Navi Peth Main Road, Solapur',
      'ward': 'Ward 14',
      'lat': 17.6637,
      'lng': 75.9041,
      'severity': 'High',
      'status': 'InProgress',
      'current_handler': 'JE',
      'assigned_to': 'Solapur Road Builders',
      'assigned_party_type': 'Contractor',
      'official_remarks':
          'Verified and assigned. Patching and compaction started on first lane.',
      'reported_by': 'citizen',
      'upvotes': 19,
      'images': ['assets/download (6).jpg', 'assets/download (1).jpg'],
      'days_ago': 2,
      'verified_days_ago': 1,
    },
    {
      'id': 'MOCK-0222',
      'title': 'Severe Road Surface Depression at Railway Overbridge',
      'description':
          'Large sunken area near the railway overbridge expansion joint. Vehicles experience heavy impact when crossing. Critical safety concern for night-time traffic.',
      'damage_type': 'Subsidence',
      'location': 'Railway Overbridge Approach, Solapur',
      'ward': '',
      'lat': 17.6740,
      'lng': 75.9125,
      'severity': 'Medium',
      'status': 'Open',
      'current_handler': 'JE',
      'reported_by': 'citizen',
      'upvotes': 5,
      'days_ago': -5,
    },
  ];

  Future<bool> isDatabaseEmpty() async {
    try {
      final response = await _client.from('complaints').select('id').limit(1);
      return (response as List).isEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<void> seedIfEmpty() async {
    if (!AppFlags.allowMockData) return;
    final empty = await isDatabaseEmpty();
    if (!empty) return;
    await seed();
  }

  Future<void> seed() async {
    if (!AppFlags.allowMockData) return;
    final now = DateTime.now();

    for (final mock in _mockComplaints) {
      final daysAgo = mock['days_ago'] as int? ?? 0;
      final verifiedDaysAgo = mock['verified_days_ago'] as int?;
      final manualEscDaysAgo = mock['manually_escalated_days_ago'] as int?;
      final autoEscDaysAgo = mock['auto_escalated_days_ago'] as int?;

      final submittedDate = now.subtract(Duration(days: daysAgo));
      final verifiedDate = verifiedDaysAgo != null
          ? now.subtract(Duration(days: verifiedDaysAgo))
          : null;
      final manualEscDate = manualEscDaysAgo != null
          ? now.subtract(Duration(days: manualEscDaysAgo))
          : null;
      final autoEscDate = autoEscDaysAgo != null
          ? now.subtract(Duration(days: autoEscDaysAgo))
          : null;

      final row = <String, dynamic>{
        'id': mock['id'],
        'title': mock['title'],
        'description': mock['description'],
        'damage_type': mock['damage_type'],
        'location': mock['location'],
        'ward': mock['ward'],
        'lat': mock['lat'],
        'lng': mock['lng'],
        'severity': mock['severity'],
        'status': mock['status'],
        'submitted_date': submittedDate.toIso8601String(),
        'last_update': now
            .subtract(Duration(hours: daysAgo * 2))
            .toIso8601String(),
        'current_handler': mock['current_handler'],
        'received_at_current_level':
            (autoEscDate ?? manualEscDate ?? submittedDate).toIso8601String(),
        'reported_by': mock['reported_by'],
        'upvotes': mock['upvotes'] ?? 0,
        'images': mock['images'],
      };

      if (mock['assigned_to'] != null) row['assigned_to'] = mock['assigned_to'];
      if (mock['assigned_party_type'] != null)
        row['assigned_party_type'] = mock['assigned_party_type'];
      if (mock['work_gang'] != null) row['work_gang'] = mock['work_gang'];
      if (mock['official_remarks'] != null)
        row['official_remarks'] = mock['official_remarks'];
      if (mock['escalated_from'] != null)
        row['escalated_from'] = mock['escalated_from'];
      if (verifiedDate != null)
        row['verified_date'] = verifiedDate.toIso8601String();
      if (manualEscDate != null)
        row['manually_escalated_at'] = manualEscDate.toIso8601String();
      if (autoEscDate != null)
        row['auto_escalated_at'] = autoEscDate.toIso8601String();

      final missingColPattern = RegExp(r"'([^']+)' column");
      var attempt = Map<String, dynamic>.from(row);

      for (var retry = 0; retry < 5; retry++) {
        try {
          await _client.from('complaints').upsert(attempt);
          break;
        } catch (e) {
          final match = missingColPattern.firstMatch(e.toString());
          final badCol = match?.group(1);
          if (badCol != null && attempt.containsKey(badCol)) {
            attempt.remove(badCol);
          } else {
            debugPrint('[MockSeeder] Failed ${mock['id']}: $e');
            break;
          }
        }
      }
    }
  }

  List<Map<String, dynamic>> buildLocalMockComplaints() {
    if (!AppFlags.allowMockData) return <Map<String, dynamic>>[];
    final now = DateTime.now();
    return _mockComplaints.map((mock) {
      final daysAgo = mock['days_ago'] as int? ?? 0;
      final verifiedDaysAgo = mock['verified_days_ago'] as int?;
      final manualEscDaysAgo = mock['manually_escalated_days_ago'] as int?;
      final autoEscDaysAgo = mock['auto_escalated_days_ago'] as int?;

      final submittedDate = now.subtract(Duration(days: daysAgo));
      final verifiedDate = verifiedDaysAgo != null
          ? now.subtract(Duration(days: verifiedDaysAgo))
          : null;
      final manualEscDate = manualEscDaysAgo != null
          ? now.subtract(Duration(days: manualEscDaysAgo))
          : null;
      final autoEscDate = autoEscDaysAgo != null
          ? now.subtract(Duration(days: autoEscDaysAgo))
          : null;

      return <String, dynamic>{
        'id': mock['id'],
        'title': mock['title'],
        'description': mock['description'],
        'damageType': mock['damage_type'],
        'location': mock['location'],
        'ward': mock['ward'],
        'wardZone': mock['ward'],
        'coords': LatLng(
          (mock['lat'] as num?)?.toDouble() ?? 17.6599,
          (mock['lng'] as num?)?.toDouble() ?? 75.9064,
        ),
        'severity': mock['severity'] ?? 'Medium',
        'status': mock['status'] ?? 'Open',
        'submittedDate': submittedDate,
        'verifiedDate': verifiedDate,
        'lastUpdate': now.subtract(Duration(hours: daysAgo * 2)),
        'assignedTo': mock['assigned_to'],
        'assignedPartyType': mock['assigned_party_type'],
        'workGang': mock['work_gang'],
        'officialRemarks': mock['official_remarks'],
        'images': (mock['images'] as List<dynamic>? ?? const []).cast<String>(),
        'currentHandler': mock['current_handler'] ?? 'JE',
        'receivedAtCurrentLevel': autoEscDate ?? manualEscDate ?? submittedDate,
        'escalatedFrom': mock['escalated_from'],
        'autoEscalatedAt': autoEscDate,
        'manuallyEscalatedAt': manualEscDate,
        'reportedBy': mock['reported_by'] ?? 'citizen',
        'reportedByUserId': null,
        'upvotes': mock['upvotes'] ?? 0,
      };
    }).toList();
  }
}
