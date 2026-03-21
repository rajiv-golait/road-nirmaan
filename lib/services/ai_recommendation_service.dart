import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;

import 'flask_ai_service.dart';

class AiRecommendationService {
  AiRecommendationService._();
  static final AiRecommendationService instance = AiRecommendationService._();

  Future<Map<String, dynamic>> analyzeSingleImage({
    required String imagePath,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final raw = await FlaskAiService.analyzeImages(
        images: <dynamic>[imagePath],
        latitude: latitude,
        longitude: longitude,
      );
      if (raw['success'] == true) {
        final detections = (raw['detections'] as List<dynamic>?) ?? const [];
        final sev = raw['severity_score'];
        debugPrint(
          'REAL AI: got ${detections.length} detections, severity=$sev',
        );
        return _normalizeFlaskResponse(raw, imagePath);
      }
      throw Exception('Flask returned success!=true');
    } catch (e) {
      debugPrint('AI: Flask unavailable, using offline fallback: $e');
      return _fallbackAnalyze(
        imagePath,
        latitude ?? 0,
        longitude ?? 0,
      );
    }
  }

  /// Maps Flask `/detect-flutter` JSON to the shape [citizen_dashboard] and
  /// [ComplaintStore.generateAiRecommendation] expect, plus legacy `image_details`.
  Map<String, dynamic> _normalizeFlaskResponse(
    Map<String, dynamic> flask,
    String imagePath,
  ) {
    final filename = _filenameOf(imagePath);
    final potholes = (flask['total_potholes'] as num?)?.toInt() ?? 0;
    final severity = (flask['severity_score'] as num?)?.toDouble() ?? 0.0;
    return <String, dynamic>{
      ...flask,
      'image_details': <Map<String, dynamic>>[
        <String, dynamic>{
          'image_path': imagePath,
          'filename': filename,
          'total_potholes': potholes,
          'severity_score': severity,
        },
      ],
    };
  }

  /// Offline deterministic fallback (filename + coordinates). Not Roboflow.
  Map<String, dynamic> _fallbackAnalyze(
    String imagePath,
    double latitude,
    double longitude,
  ) {
    debugPrint('⚠ AI FALLBACK RUNNING ⚠');
    debugPrint('Reason: Flask unreachable');
    debugPrint('THIS IS AN ESTIMATE, NOT REAL AI');
    final filename = _filenameOf(imagePath);
    final signal = _signalFrom(filename, latitude, longitude);
    final locationParameters = _deriveLocationParameters(
      latitude,
      longitude,
      signal,
    );

    final potholes = 1 + (signal % 9);
    final severity = _severityScore(
      potholes: potholes,
      trafficLevel: locationParameters['traffic_level']!.toString(),
      roadClassification: locationParameters['road_classification']!.toString(),
      locationType: locationParameters['location_type']!.toString(),
      signal: signal,
    );

    final repair = _generateRepairRecommendations(
      severityScore: severity,
      locationType: locationParameters['location_type']!.toString(),
      trafficLevel: locationParameters['traffic_level']!.toString(),
      roadClassification: locationParameters['road_classification']!.toString(),
    );

    final priority = severity >= 7
        ? 'CRITICAL'
        : severity >= 5
        ? 'HIGH'
        : severity >= 3
        ? 'MEDIUM'
        : 'LOW';

    return <String, dynamic>{
      'success': true,
      'is_offline_estimate': true,
      'warning': 'AI server unreachable. This is an estimate only.',
      'severity_score': severity,
      'epdo_score': 5.0,
      'priority': priority,
      'total_potholes': potholes,
      'input': <String, dynamic>{
        'image_count': 1,
        'latitude': latitude,
        'longitude': longitude,
      },
      'location_parameters': locationParameters,
      'analysis_summary': <String, dynamic>{
        'total_images': 1,
        'average_severity_score': severity,
        'total_potholes_detected': potholes,
      },
      'repair_recommendations': repair,
      'image_details': <Map<String, dynamic>>[
        <String, dynamic>{
          'image_path': imagePath,
          'filename': filename,
          'total_potholes': potholes,
          'severity_score': severity,
        },
      ],
    };
  }

  String _filenameOf(String path) {
    final cleaned = path.trim();
    if (cleaned.isEmpty) return 'complaint.jpg';
    final slash = cleaned.replaceAll('\\', '/');
    final file = slash.split('/').last;
    return file.isEmpty ? 'complaint.jpg' : file;
  }

  int _signalFrom(String filename, double latitude, double longitude) {
    var hash = 17;
    for (final code in filename.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    hash =
        (hash +
            (latitude.abs() * 10000).round() +
            (longitude.abs() * 10000).round()) &
        0x7fffffff;
    return hash;
  }

  Map<String, String> _deriveLocationParameters(
    double latitude,
    double longitude,
    int signal,
  ) {
    final roadTypes = <String>['asphalt', 'concrete', 'gravel'];
    final roadClasses = <String>['highway', 'arterial', 'collector', 'local'];
    final traffic = <String>['low', 'medium', 'high'];
    final locationType = (latitude.abs() + longitude.abs()) % 2 > 1
        ? 'urban'
        : 'rural';
    return <String, String>{
      'road_type': roadTypes[signal % roadTypes.length],
      'road_classification': roadClasses[(signal ~/ 3) % roadClasses.length],
      'traffic_level': traffic[(signal ~/ 7) % traffic.length],
      'location_type': locationType,
    };
  }

  double _severityScore({
    required int potholes,
    required String trafficLevel,
    required String roadClassification,
    required String locationType,
    required int signal,
  }) {
    var score = 1.5 + potholes * 0.7;
    if (trafficLevel == 'high') {
      score += 1.4;
    }
    if (trafficLevel == 'medium') {
      score += 0.7;
    }
    if (roadClassification == 'highway' || roadClassification == 'arterial') {
      score += 1.2;
    }
    if (locationType == 'urban') {
      score += 0.5;
    }
    score += ((signal % 100) / 100.0) * 0.8;
    return double.parse(min(10.0, max(0.5, score)).toStringAsFixed(2));
  }

  Map<String, dynamic> _generateRepairRecommendations({
    required double severityScore,
    required String locationType,
    required String trafficLevel,
    required String roadClassification,
  }) {
    final usePremix = locationType == 'urban' || trafficLevel == 'high';
    final roadType = usePremix ? 'Premix' : 'Hotmix';
    final roadReason = usePremix
        ? 'Urban area / High traffic volume'
        : 'Lower traffic corridor';

    final contractor =
        severityScore >= 6.0 ||
        roadClassification == 'highway' ||
        trafficLevel == 'high';
    final workerType = contractor ? 'Contractor' : 'Work Gang';
    final workerReason = contractor
        ? 'Critical damage requiring reconstruction'
        : 'Suitable for municipal maintenance team';

    final urgency = severityScore >= 7
        ? 'HIGH'
        : severityScore >= 4.5
        ? 'MODERATE'
        : 'LOW';
    final timeline = severityScore >= 7
        ? '1-2 weeks'
        : severityScore >= 4.5
        ? '2-4 weeks'
        : '1-2 months';

    return <String, dynamic>{
      'recommended_road_type': roadType,
      'road_type_reason': roadReason,
      'worker_type': workerType,
      'worker_reason': workerReason,
      'urgency': urgency,
      'timeline': timeline,
      'summary':
          '$urgency priority repair needed. Use $roadType and assign $workerType.',
    };
  }
}
