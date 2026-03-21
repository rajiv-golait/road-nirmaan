import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_role.dart';
import '../services/user_service.dart';
import '../utils/app_flags.dart';

import '../screens/dashboards/commissioner_dashboard.dart'
    deferred as commissioner;
import '../screens/dashboards/chief_engineer_dashboard.dart'
    deferred as chief_engineer;
import '../screens/dashboards/deputy_engineer_dashboard.dart'
    deferred as deputy_engineer;
import '../screens/dashboards/assistant_engineer_dashboard.dart'
    deferred as assistant_engineer;
import '../screens/dashboards/jr_engineer_dashboard.dart'
    deferred as jr_engineer;
import '../screens/dashboards/work_gang_dashboard.dart' deferred as work_gang;
import '../screens/dashboards/contractor_dashboard.dart' deferred as contractor;
import '../screens/dashboards/nagarsevak_dashboard.dart' deferred as nagarsevak;
import '../screens/dashboards/citizen_dashboard.dart' deferred as citizen;

class AuthService {
  static UserRole? _currentUserRole;
  static String? _currentUserEmail;
  static String? _currentUserId;

  static UserRole? get currentUserRole => _currentUserRole;
  static String? get currentUserEmail => _currentUserEmail;
  static String? get currentUserId => _currentUserId;

  static bool authenticate(String email, String password) {
    if (!AppFlags.allowDemoLogin) return false;
    if (password != '123') return false;
    final role = getRoleFromEmail(email);
    if (role != null) {
      _currentUserRole = role;
      _currentUserEmail = email;
      _currentUserId = Supabase.instance.client.auth.currentUser?.id;
      return true;
    }
    return false;
  }

  static void logout() {
    _currentUserRole = null;
    _currentUserEmail = null;
    _currentUserId = null;
  }

  static void setUserFromEmail(String email) {
    final role = getRoleFromEmail(email);
    if (role != null) {
      _currentUserRole = role;
      _currentUserEmail = email;
      _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    }
  }

  static void setUser({
    required UserRole role,
    required String email,
    String? userId,
  }) {
    _currentUserRole = role;
    _currentUserEmail = email;
    _currentUserId = userId ?? Supabase.instance.client.auth.currentUser?.id;
  }

  static bool hasPermission(String permission) {
    if (_currentUserRole == null) return false;
    switch (permission) {
      case 'verify_complaints':
        return _currentUserRole!.canVerifyComplaints;
      case 'assign_work':
        return _currentUserRole!.canAssignWork;
      case 'escalate':
        return _currentUserRole!.canEscalate;
      case 'city_wide_access':
        return _currentUserRole!.hasCityWideAccess;
      case 'daily_updates':
        return _currentUserRole!.canSubmitDailyUpdates;
      default:
        return false;
    }
  }
}

UserRole? _roleFromString(String? role) {
  switch ((role ?? '').toLowerCase()) {
    case 'commissioner':
      return UserRole.commissioner;
    case 'assistant_commissioner':
    case 'assistant commissioner':
      return UserRole.assistantCommissioner;
    case 'city_engineer':
    case 'city engineer':
    case 'chief_engineer':
    case 'chief engineer':
      return UserRole.cityEngineer;
    case 'deputy_engineer':
    case 'deputy engineer':
      return UserRole.deputyEngineer;
    case 'assistant_engineer':
    case 'assistant engineer':
      return UserRole.assistantEngineer;
    case 'junior_engineer':
    case 'junior engineer':
      return UserRole.juniorEngineer;
    case 'work_gang':
    case 'work gang':
      return UserRole.workGang;
    case 'contractor':
      return UserRole.contractor;
    case 'nagarsevak':
    case 'nagar sevak':
      return UserRole.nagarSevak;
    case 'citizen':
      return UserRole.citizen;
    default:
      return null;
  }
}

Future<UserRole?> resolveRoleForAuthenticatedUser(String email) async {
  final user = UserService.instance.currentUser;
  if (user != null) {
    try {
      final profile = await UserService.instance.getCurrentProfile();
      final profileRole = _roleFromString(profile?['role'] as String?);
      if (profileRole != null) {
        AuthService.setUser(
          role: profileRole,
          email: (profile?['email'] as String?) ?? email,
          userId: user.id,
        );
        return profileRole;
      }
    } catch (_) {}

    try {
      final officialRole = await UserService.instance.getOfficialRoleByEmail(
        email,
      );
      final mapped = _roleFromString(officialRole?['role'] as String?);
      if (mapped != null) {
        AuthService.setUser(
          role: mapped,
          email: (officialRole?['email'] as String?) ?? email,
          userId: user.id,
        );
        return mapped;
      }
    } catch (_) {}
  }

  final fallback = getRoleFromEmail(email);
  if (fallback != null) {
    AuthService.setUser(role: fallback, email: email, userId: user?.id);
  }
  return fallback;
}

bool isValidDemoCredentials(String email, String password) {
  if (!AppFlags.allowDemoLogin) return false;
  if (password != '123') return false;
  return [
    'commissioner@solapur.gov.in',
    'ac@solapur.gov.in',
    'chiefengineer@solapur.gov.in',
    'cityengineer@solapur.gov.in',
    'assistantengineer@solapur.gov.in',
    'deputyengineer@solapur.gov.in',
    'jrengineer@solapur.gov.in',
    'workgang@solapur.gov.in',
    'contractor@company.com',
    'nagarsevak@solapur.gov.in',
    'citizen@gmail.com',
  ].contains(email.toLowerCase());
}

Future<Widget> loadDashboardForRole(String email, String password) async {
  var role = AuthService.currentUserRole;
  role ??= await resolveRoleForAuthenticatedUser(email);
  if (role == null && AuthService.authenticate(email, password)) {
    role = AuthService.currentUserRole;
  }
  if (role == null) {
    await citizen.loadLibrary();
    return citizen.CitizenDashboard();
  }

  switch (role) {
    case UserRole.commissioner:
      await commissioner.loadLibrary();
      return commissioner.CommissionerDashboard();
    case UserRole.assistantCommissioner:
      await citizen.loadLibrary();
      return citizen.CitizenDashboard();
    case UserRole.cityEngineer:
      await chief_engineer.loadLibrary();
      return chief_engineer.ChiefEngineerDashboard();
    case UserRole.deputyEngineer:
      await deputy_engineer.loadLibrary();
      return deputy_engineer.DeputyEngineerDashboard();
    case UserRole.assistantEngineer:
      await assistant_engineer.loadLibrary();
      return assistant_engineer.AssistantEngineerDashboard();
    case UserRole.juniorEngineer:
      await jr_engineer.loadLibrary();
      return jr_engineer.JrEngineerDashboard();
    case UserRole.workGang:
      await work_gang.loadLibrary();
      return work_gang.WorkGangDashboard();
    case UserRole.contractor:
      await contractor.loadLibrary();
      return contractor.ContractorDashboard();
    case UserRole.nagarSevak:
      await nagarsevak.loadLibrary();
      return nagarsevak.NagarsevakDashboard();
    case UserRole.citizen:
      await citizen.loadLibrary();
      return citizen.CitizenDashboard();
  }
}

Future<Widget> loadCitizenDashboard() async {
  await citizen.loadLibrary();
  return citizen.CitizenDashboard();
}
