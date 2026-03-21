import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<void> upsertProfile(Map<String, dynamic> payload) async {
    await _client.from('profiles').upsert(payload);
  }

  Future<Map<String, dynamic>?> getOfficialRoleByEmail(String email) async {
    return await _client
        .from('user_roles')
        .select()
        .eq('email', email.toLowerCase())
        .maybeSingle();
  }
}
