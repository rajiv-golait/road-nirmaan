class DashboardMetrics {
  DashboardMetrics._();

  static int total(List<Map<String, dynamic>> complaints) => complaints.length;

  static int resolved(List<Map<String, dynamic>> complaints) {
    return complaints
        .where((complaint) => _statusOf(complaint) == 'resolved')
        .length;
  }

  static int inProgress(List<Map<String, dynamic>> complaints) {
    return complaints.where((complaint) {
      final status = _statusOf(complaint);
      return status == 'in progress' || status == 'pending ce authorization';
    }).length;
  }

  static int pending(List<Map<String, dynamic>> complaints) {
    return complaints.where((complaint) {
      final status = _statusOf(complaint);
      return status != 'resolved' &&
          status != 'in progress' &&
          status != 'pending ce authorization';
    }).length;
  }

  static int resolutionRate(List<Map<String, dynamic>> complaints) {
    final totalCount = total(complaints);
    if (totalCount == 0) return 0;
    return ((resolved(complaints) / totalCount) * 100).round();
  }

  static String resolutionRateLabel(List<Map<String, dynamic>> complaints) {
    return '${resolutionRate(complaints)}%';
  }

  static String percentageLabel(int count, int totalCount) {
    if (totalCount == 0) return '0%';
    return '${((count / totalCount) * 100).round()}%';
  }

  static double chartValue(int count, int totalCount) {
    if (totalCount == 0) return 1;
    return count.toDouble();
  }

  static String resolutionFormula(List<Map<String, dynamic>> complaints) {
    final resolvedCount = resolved(complaints);
    final totalCount = total(complaints);
    return '($resolvedCount / $totalCount) × 100 = ${resolutionRate(complaints)}%';
  }

  static String _statusOf(Map<String, dynamic> complaint) {
    return (complaint['status'] ?? '').toString().trim().toLowerCase();
  }
}
