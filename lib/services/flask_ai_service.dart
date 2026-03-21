import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart';

class FlaskAiService {
  static String get _baseUrl => AppConstants.flaskUrl;

  /// Roboflow + scoring can exceed 15s; keep client in sync with Flask work.
  static const Duration _httpTimeout = Duration(seconds: 90);

  static Future<Map<String, dynamic>> analyzeImages({
    required List<dynamic> images,
    double? latitude,
    double? longitude,
  }) async {
    debugPrint('═══ AI PIPELINE START ═══');
    debugPrint('Flask URL: $_baseUrl');
    debugPrint('Images: ${images.length}');
    debugPrint('Coords: $latitude, $longitude');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/detect-flutter'),
    );

    for (var img in images) {
      if (img is XFile) {
        final bytes = await img.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('images', bytes, filename: img.name),
        );
      } else if (img is String) {
        if (img.startsWith('http')) {
          final bytes = await http.get(Uri.parse(img)).then((r) => r.bodyBytes);
          request.files.add(
            http.MultipartFile.fromBytes(
              'images',
              bytes,
              filename: 'remote.jpg',
            ),
          );
        } else {
          try {
            final xfile = XFile(img);
            final bytes = await xfile.readAsBytes();
            final name = img.split('/').last.split(r'\').last;
            request.files.add(
              http.MultipartFile.fromBytes(
                'images',
                bytes,
                filename: name.isEmpty ? 'photo.jpg' : name,
              ),
            );
          } catch (e) {
            debugPrint('Failed to attach image: $e');
          }
        }
      }
    }
    if (latitude != null && longitude != null) {
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
    }

    final streamed = await request.send().timeout(_httpTimeout);
    final body = await streamed.stream.bytesToString().timeout(_httpTimeout);

    if (streamed.statusCode != 200) {
      throw Exception(
        'Failed to analyze images. Status: ${streamed.statusCode}',
      );
    }

    final result = jsonDecode(body) as Map<String, dynamic>;
    debugPrint('═══ AI RESULT (ROBOFLOW REAL) ═══');
    debugPrint('Potholes: ${result['total_potholes']}');
    debugPrint('Severity: ${result['severity_score']}');
    debugPrint('EPDO: ${result['epdo_score']}');
    debugPrint('Priority: ${result['priority']}');
    return result;
  }

  static Future<Map<String, dynamic>> checkDuplicate({
    required double latitude,
    required double longitude,
    required List<Map<String, dynamic>> nearbyComplaints,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/check-duplicate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'latitude': latitude,
            'longitude': longitude,
            'nearby_complaints': nearbyComplaints,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Duplicate check failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> verifyRepair({
    required dynamic beforeImage,
    required dynamic afterImage,
    required String complaintId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/verify-repair'),
    );
    Future<void> addImage(String field, dynamic image) async {
      if (image is XFile) {
        final bytes = await image.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(field, bytes, filename: image.name),
        );
      } else if (image is String) {
        if (image.startsWith('http')) {
          final bytes = await http
              .get(Uri.parse(image))
              .then((r) => r.bodyBytes);
          request.files.add(
            http.MultipartFile.fromBytes(field, bytes, filename: '$field.jpg'),
          );
        } else {
          final path = image;
          final xfile = XFile(path);
          final bytes = await xfile.readAsBytes();
          final name = path.split('/').last.split(r'\').last;
          request.files.add(
            http.MultipartFile.fromBytes(
              field,
              bytes,
              filename: name.isEmpty ? '$field.jpg' : name,
            ),
          );
        }
      } else {
        throw Exception('Unsupported image type for $field');
      }
    }

    await addImage('before_image', beforeImage);
    await addImage('after_image', afterImage);
    request.fields['complaint_id'] = complaintId;

    final streamed = await request.send().timeout(_httpTimeout);
    final body = await streamed.stream.bytesToString().timeout(_httpTimeout);
    if (streamed.statusCode != 200) {
      throw Exception('Verify repair failed: ${streamed.statusCode}');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }
}
