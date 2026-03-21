// COMPLAINT LIFECYCLE STATE MACHINE
// All transitions must be logged for accountability

enum ComplaintStatus {
  submitted,
  verified,
  assigned,
  inProgress,
  resolved,
  closed,

  // Special states
  escalated,
  reassigned,
  onHold,
}

extension ComplaintStatusExtension on ComplaintStatus {
  String get displayName {
    switch (this) {
      case ComplaintStatus.submitted:
        return 'Submitted';
      case ComplaintStatus.verified:
        return 'Verified';
      case ComplaintStatus.assigned:
        return 'Assigned';
      case ComplaintStatus.inProgress:
        return 'InProgress';
      case ComplaintStatus.resolved:
        return 'Resolved';
      case ComplaintStatus.closed:
        return 'Closed';
      case ComplaintStatus.escalated:
        return 'Escalated';
      case ComplaintStatus.reassigned:
        return 'Reassigned';
      case ComplaintStatus.onHold:
        return 'On Hold';
    }
  }

  // UI Color coding
  int get colorHex {
    switch (this) {
      case ComplaintStatus.submitted:
        return 0xFF4A90E2; // Blue
      case ComplaintStatus.verified:
        return 0xFF7DB89A; // Green tint
      case ComplaintStatus.assigned:
        return 0xFFC9A24D; // Accent
      case ComplaintStatus.inProgress:
        return 0xFFFF9800; // Orange
      case ComplaintStatus.resolved:
        return 0xFF4CAF50; // Green
      case ComplaintStatus.closed:
        return 0xFF607D8B; // Grey
      case ComplaintStatus.escalated:
        return 0xFFE53935; // Red
      case ComplaintStatus.reassigned:
        return 0xFFFFB300; // Amber
      case ComplaintStatus.onHold:
        return 0xFF9E9E9E; // Grey
    }
  }

  // Check if status can transition to another
  bool canTransitionTo(ComplaintStatus newStatus) {
    switch (this) {
      case ComplaintStatus.submitted:
        return newStatus == ComplaintStatus.verified ||
            newStatus == ComplaintStatus.escalated;

      case ComplaintStatus.verified:
        return newStatus == ComplaintStatus.assigned ||
            newStatus == ComplaintStatus.escalated ||
            newStatus == ComplaintStatus.onHold;

      case ComplaintStatus.assigned:
        return newStatus == ComplaintStatus.inProgress ||
            newStatus == ComplaintStatus.reassigned ||
            newStatus == ComplaintStatus.escalated;

      case ComplaintStatus.inProgress:
        return newStatus == ComplaintStatus.resolved ||
            newStatus == ComplaintStatus.escalated ||
            newStatus == ComplaintStatus.onHold;

      case ComplaintStatus.resolved:
        return newStatus == ComplaintStatus.closed ||
            newStatus == ComplaintStatus.inProgress; // Re-opened

      case ComplaintStatus.closed:
        return false; // Terminal state

      case ComplaintStatus.escalated:
        return newStatus == ComplaintStatus.assigned ||
            newStatus == ComplaintStatus.verified;

      case ComplaintStatus.reassigned:
        return newStatus == ComplaintStatus.assigned ||
            newStatus == ComplaintStatus.inProgress;

      case ComplaintStatus.onHold:
        return newStatus == ComplaintStatus.verified ||
            newStatus == ComplaintStatus.assigned ||
            newStatus == ComplaintStatus.inProgress;
    }
  }
}

// Severity levels
enum SeverityLevel { low, medium, high, critical }

extension SeverityLevelExtension on SeverityLevel {
  String get displayName {
    switch (this) {
      case SeverityLevel.low:
        return 'Low';
      case SeverityLevel.medium:
        return 'Medium';
      case SeverityLevel.high:
        return 'High';
      case SeverityLevel.critical:
        return 'Critical';
    }
  }

  int get colorHex {
    switch (this) {
      case SeverityLevel.low:
        return 0xFF4CAF50; // Green
      case SeverityLevel.medium:
        return 0xFFFF9800; // Orange
      case SeverityLevel.high:
        return 0xFFE53935; // Red
      case SeverityLevel.critical:
        return 0xFF8B0000; // Dark Red
    }
  }

  // Auto-escalation priority (higher = more urgent)
  int get priority {
    switch (this) {
      case SeverityLevel.low:
        return 1;
      case SeverityLevel.medium:
        return 2;
      case SeverityLevel.high:
        return 3;
      case SeverityLevel.critical:
        return 4;
    }
  }
}
