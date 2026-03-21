/// Model for a road damage complaint
///
/// Fields will be populated as screens are built
class Complaint {
  final String id;
  final String title;
  final String description;
  final List<String> imageUrls;
  final DateTime createdAt;

  Complaint({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.createdAt,
  });
}
