class Ward {
  final int hospitalStCode;   // hospital_st_code
  final String categoryName;  // category_name
  final int sortOrder;        // sort_order

  const Ward({
    required this.hospitalStCode,
    required this.categoryName,
    required this.sortOrder,
  });



  factory Ward.fromJson(Map<String, dynamic> json) {
    return Ward(
      hospitalStCode: (json['hospital_st_code'] as num).toInt(),
      categoryName: (json['category_name'] as String),
      sortOrder: (json['sort_order'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'hospital_st_code': hospitalStCode,
    'category_name': categoryName,
    'sort_order': sortOrder,
  };
}
