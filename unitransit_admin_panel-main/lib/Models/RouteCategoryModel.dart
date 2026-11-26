class RouteCategoryModel {
  final int id;
  final String slug;
  final String name;
  final bool isActive;

  RouteCategoryModel({
    required this.id,
    required this.slug,
    required this.name,
    this.isActive = true,
  });

  bool get isOutOfCity => slug.toLowerCase().contains('out') || name.toLowerCase().contains('out');

  factory RouteCategoryModel.fromMap(Map<String, dynamic> map) {
    return RouteCategoryModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      slug: map['slug'] ?? '',
      name: map['name'] ?? '',
      isActive: map['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'slug': slug,
      'name': name,
      'is_active': isActive,
    };
  }
}

class RouteTagModel {
  final int id;
  final String code; // 'S', 'SB', 'R', 'I', 'B'
  final String label;
  final String colorHex;
  final bool isActive;

  RouteTagModel({
    required this.id,
    required this.code,
    required this.label,
    required this.colorHex,
    this.isActive = true,
  });

  factory RouteTagModel.fromMap(Map<String, dynamic> map) {
    return RouteTagModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      code: map['code'] ?? '',
      label: map['label'] ?? '',
      colorHex: map['color_hex'] ?? '#2196F3',
      isActive: map['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'label': label,
      'color_hex': colorHex,
      'is_active': isActive,
    };
  }
}
