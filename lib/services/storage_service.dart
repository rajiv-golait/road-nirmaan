import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const String complaintImagesBucket = 'complaint-images';

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<String>> uploadComplaintImages({
    required List<String> localPaths,
    required String folder,
    String? userId,
  }) async {
    final uploaded = <String>[];
    final uid = userId ?? _client.auth.currentUser?.id ?? 'anonymous';

    for (var i = 0; i < localPaths.length; i++) {
      final localPath = localPaths[i];
      final dotIndex = localPath.lastIndexOf('.');
      final extension = dotIndex >= 0 ? localPath.substring(dotIndex) : '.jpg';
      final storagePath =
          '$folder/$uid/${DateTime.now().microsecondsSinceEpoch}_$i$extension';
      try {
        if (kIsWeb && localPath.startsWith('blob:')) {
          final uri = Uri.parse(localPath);
          final bytes = await http.get(uri).then((r) => r.bodyBytes);
          await _client.storage
              .from(complaintImagesBucket)
              .uploadBinary(
                storagePath,
                bytes,
                fileOptions: const FileOptions(upsert: true),
              );
        } else {
          await _client.storage
              .from(complaintImagesBucket)
              .upload(
                storagePath,
                File(localPath),
                fileOptions: const FileOptions(upsert: true),
              );
        }
        uploaded.add(
          _client.storage.from(complaintImagesBucket).getPublicUrl(storagePath),
        );
      } catch (_) {
        uploaded.add(localPath);
      }
    }

    return uploaded;
  }
}
