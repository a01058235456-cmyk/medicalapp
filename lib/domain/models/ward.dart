class Ward {
  final String id;
  final String name;

  const Ward({required this.id, required this.name});

  factory Ward.fromJson(Map<String, dynamic> json) {
    return Ward(
      id: (json['wardId'] ?? json['id']) as String,
      name: (json['wardName'] ?? json['name']) as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'wardId': id,
    'wardName': name,
  };
}
