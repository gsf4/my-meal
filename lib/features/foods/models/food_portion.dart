class FoodPortion {
  final String id;
  final String name; // ex: "Ovo médio", "Ovo grande", "Fatia", "1 dosador"
  final double grams; // ex: 55.0, 65.0, 25.0, 30.0

  const FoodPortion({
    required this.id,
    required this.name,
    required this.grams,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'grams': grams,
    };
  }

  factory FoodPortion.fromMap(Map<String, dynamic> map) {
    return FoodPortion(
      id: map['id'] as String,
      name: map['name'] as String,
      grams: (map['grams'] as num).toDouble(),
    );
  }

  FoodPortion copyWith({
    String? id,
    String? name,
    double? grams,
  }) {
    return FoodPortion(
      id: id ?? this.id,
      name: name ?? this.name,
      grams: grams ?? this.grams,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodPortion &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          grams == other.grams;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ grams.hashCode;

  @override
  String toString() => 'FoodPortion(id: $id, name: $name, grams: $grams)';
}
