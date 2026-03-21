// ESCALATION CONFIGURATION
// ⚠️ THIS IS TENTATIVE AND WILL BE BACKEND-CONFIGURABLE
// DO NOT HARDCODE THESE VALUES IN BUSINESS LOGIC
//
// CORRECT MUNICIPAL HIERARCHY:
// JE (3 days) -> AE (7 days) -> DE (11 days) -> City Engineer (final approval)

class EscalationConfig {
  // SLA Timers (in days) - CONFIGURABLE
  static const int juniorEngineerSLA = 3;
  static const int assistantEngineerSLA = 7;
  static const int deputyEngineerSLA = 11;
  // City Engineer has no SLA - final technical authority

  // Warning threshold (% of SLA before showing alert)
  static const double warningThreshold = 0.75; // 75%

  // Days before reminder
  static const int reminderBeforeEscalation = 1;

  // Get SLA days based on role
  static int getSLAForRole(String role) {
    switch (role.toLowerCase()) {
      case 'juniorengineer':
      case 'junior_engineer':
        return juniorEngineerSLA;
      case 'assistantengineer':
      case 'assistant_engineer':
        return assistantEngineerSLA;
      case 'deputyengineer':
      case 'deputy_engineer':
        return deputyEngineerSLA;
      default:
        return juniorEngineerSLA;
    }
  }

  // Get SLA days based on severity (overrides role SLA if more urgent)
  static int getSLAForSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 1;
      case 'high':
        return 2;
      case 'medium':
        return juniorEngineerSLA;
      case 'low':
        return 5;
      default:
        return juniorEngineerSLA;
    }
  }

  // Get effective SLA (minimum of role SLA and severity SLA)
  static int getEffectiveSLA(String role, String severity) {
    final roleSLA = getSLAForRole(role);
    final severitySLA = getSLAForSeverity(severity);
    return roleSLA < severitySLA ? roleSLA : severitySLA;
  }

  // Check if complaint should auto-escalate
  static bool shouldEscalate(
    DateTime submittedDate,
    String currentRole,
    String severity,
  ) {
    final daysPending = DateTime.now().difference(submittedDate).inDays;
    final effectiveSLA = getEffectiveSLA(currentRole, severity);
    return daysPending >= effectiveSLA;
  }

  // Get escalation risk level (0 = no risk, 1 = at limit, >1 = overdue)
  static double getEscalationRisk(
    DateTime submittedDate,
    String role,
    String severity,
  ) {
    final daysPending = DateTime.now().difference(submittedDate).inDays;
    final sla = getEffectiveSLA(role, severity);
    return daysPending / sla;
  }

  // Get display message for escalation risk
  static String getEscalationMessage(double risk, int sla) {
    if (risk >= 1.0) {
      return 'OVERDUE';
    } else if (risk >= warningThreshold) {
      final daysLeft = (sla - (risk * sla)).ceil();
      return '$daysLeft day${daysLeft == 1 ? '' : 's'} left';
    }
    return '';
  }

  // Get next escalation level
  static String getNextEscalationLevel(String currentRole) {
    switch (currentRole.toLowerCase()) {
      case 'juniorengineer':
      case 'junior_engineer':
        return 'Assistant Engineer';
      case 'assistantengineer':
      case 'assistant_engineer':
        return 'Deputy Engineer';
      case 'deputyengineer':
      case 'deputy_engineer':
        return 'City Engineer';
      case 'cityengineer':
      case 'city_engineer':
        return 'City Engineer';
      default:
        return 'Higher Authority';
    }
  }

  // Future hook: AI-based priority scoring
  // TODO: Integrate ML model for dynamic priority calculation
  // static Future<double> getAIPriorityScore(Complaint complaint) async {
  //   // Backend ML endpoint
  // }
}
