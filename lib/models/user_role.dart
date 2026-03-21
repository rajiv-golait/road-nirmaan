// AUTHORITATIVE USER ROLES FOR MUNICIPAL SYSTEM
// These are the only valid roles - do not add/remove without authorization

enum UserRole {
  commissioner,
  assistantCommissioner,
  cityEngineer,
  deputyEngineer,
  assistantEngineer,
  juniorEngineer,
  workGang,
  contractor,
  nagarSevak,
  citizen,
}

extension UserRoleExtension on UserRole {
  String get email {
    switch (this) {
      case UserRole.commissioner:
        return 'commissioner@solapur.gov.in';
      case UserRole.assistantCommissioner:
        return 'ac@solapur.gov.in';
      case UserRole.cityEngineer:
        return 'cityengineer@solapur.gov.in';
      case UserRole.deputyEngineer:
        return 'deputyengineer@solapur.gov.in';
      case UserRole.assistantEngineer:
        return 'assistantengineer@solapur.gov.in';
      case UserRole.juniorEngineer:
        return 'jrengineer@solapur.gov.in';
      case UserRole.workGang:
        return 'workgang@solapur.gov.in';
      case UserRole.contractor:
        return 'contractor@company.com';
      case UserRole.nagarSevak:
        return 'nagarsevak@solapur.gov.in';
      case UserRole.citizen:
        return 'citizen@gmail.com';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.commissioner:
        return 'Commissioner';
      case UserRole.assistantCommissioner:
        return 'Assistant Commissioner';
      case UserRole.cityEngineer:
        return 'City Engineer';
      case UserRole.deputyEngineer:
        return 'Deputy Engineer';
      case UserRole.assistantEngineer:
        return 'Assistant Engineer';
      case UserRole.juniorEngineer:
        return 'Junior Engineer';
      case UserRole.workGang:
        return 'Work Gang';
      case UserRole.contractor:
        return 'Contractor';
      case UserRole.nagarSevak:
        return 'Nagar Sevak';
      case UserRole.citizen:
        return 'Citizen';
    }
  }

  String get department {
    switch (this) {
      case UserRole.commissioner:
        return 'Solapur Municipal Corporation';
      case UserRole.assistantCommissioner:
        return 'Administration Department';
      case UserRole.cityEngineer:
        return 'Engineering Department - City Wide';
      case UserRole.deputyEngineer:
        return 'Engineering Department - Zonal';
      case UserRole.assistantEngineer:
        return 'Engineering Department - Zonal';
      case UserRole.juniorEngineer:
        return 'Engineering Department - Sub-Zonal';
      case UserRole.workGang:
        return 'Field Operations';
      case UserRole.contractor:
        return 'External Contractor';
      case UserRole.nagarSevak:
        return 'Ward Representative';
      case UserRole.citizen:
        return 'Public';
    }
  }

  // Bottom navigation tabs per role
  List<String> get bottomTabs {
    switch (this) {
      case UserRole.citizen:
        return ['Home', 'Track', 'Map', 'Activity', 'Profile'];
      case UserRole.workGang:
        return ['Home', 'Daily Updates', 'Map', 'Activity', 'Profile'];
      case UserRole.commissioner:
      case UserRole.assistantCommissioner:
      case UserRole.cityEngineer:
      case UserRole.deputyEngineer:
      case UserRole.assistantEngineer:
      case UserRole.juniorEngineer:
      case UserRole.nagarSevak:
      case UserRole.contractor:
        return ['Home', 'Desk', 'Map', 'Activity', 'Profile'];
    }
  }

  // Permissions
  bool get canVerifyComplaints {
    return this == UserRole.juniorEngineer ||
        this == UserRole.assistantEngineer ||
        this == UserRole.deputyEngineer ||
        this == UserRole.cityEngineer;
  }

  bool get canAssignWork {
    return this == UserRole.juniorEngineer ||
        this == UserRole.assistantEngineer ||
        this == UserRole.deputyEngineer ||
        this == UserRole.cityEngineer;
  }

  bool get canEscalate {
    return this == UserRole.juniorEngineer ||
        this == UserRole.assistantEngineer ||
        this == UserRole.deputyEngineer;
  }

  bool get canApproveResolution {
    return this == UserRole.cityEngineer;
  }

  bool get hasCityWideAccess {
    return this == UserRole.commissioner ||
        this == UserRole.assistantCommissioner ||
        this == UserRole.cityEngineer ||
        this == UserRole.contractor;
  }

  bool get canSubmitDailyUpdates {
    return this == UserRole.workGang;
  }

  bool get hasDesk {
    return this == UserRole.commissioner ||
        this == UserRole.assistantCommissioner ||
        this == UserRole.cityEngineer ||
        this == UserRole.deputyEngineer ||
        this == UserRole.assistantEngineer ||
        this == UserRole.juniorEngineer ||
        this == UserRole.nagarSevak ||
        this == UserRole.contractor;
  }

  // Get escalation hierarchy
  UserRole? get escalatesTo {
    switch (this) {
      case UserRole.juniorEngineer:
        return UserRole.assistantEngineer;
      case UserRole.assistantEngineer:
        return UserRole.deputyEngineer;
      case UserRole.deputyEngineer:
        return UserRole.cityEngineer;
      case UserRole.cityEngineer:
        return UserRole.assistantCommissioner;
      case UserRole.assistantCommissioner:
        return UserRole.commissioner;
      default:
        return null;
    }
  }

  // Get hierarchy level (lower number = higher authority)
  int get hierarchyLevel {
    switch (this) {
      case UserRole.commissioner:
        return 1;
      case UserRole.assistantCommissioner:
        return 2;
      case UserRole.cityEngineer:
        return 3;
      case UserRole.deputyEngineer:
        return 4;
      case UserRole.assistantEngineer:
        return 5;
      case UserRole.juniorEngineer:
        return 6;
      default:
        return 99; // Non-hierarchy roles
    }
  }
}

// Helper to get role from email (supports chiefengineer as alias for cityEngineer)
UserRole? getRoleFromEmail(String email) {
  final normalized = email.toLowerCase();
  if (normalized == 'chiefengineer@solapur.gov.in') {
    return UserRole.cityEngineer;
  }
  for (var role in UserRole.values) {
    if (role.email.toLowerCase() == normalized) {
      return role;
    }
  }
  return null;
}
