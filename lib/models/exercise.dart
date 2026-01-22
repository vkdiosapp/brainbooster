class Exercise {
  final int id;
  final int categoryId;
  final String name;
  final String desc;
  final String? imageUrl;
  final bool isPro;
  final bool isRecommended;
  final int timeRequired; // in milliseconds

  Exercise({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.desc,
    this.imageUrl,
    this.isPro = false,
    this.isRecommended = false,
    this.timeRequired = 350, // default 350ms
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as int,
      categoryId: json['categoryId'] as int,
      name: json['name'] as String,
      desc: json['desc'] as String,
      imageUrl: json['imageUrl'] as String?,
      isPro: json['isPro'] as bool? ?? false,
      isRecommended: json['isRecommended'] as bool? ?? false,
      timeRequired: json['timeRequired'] as int? ?? 350,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'name': name,
      'desc': desc,
      'imageUrl': imageUrl,
      'isPro': isPro,
      'isRecommended': isRecommended,
      'timeRequired': timeRequired,
    };
  }
}
