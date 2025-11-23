class Client {
  final String id;
  final String name;
  final DateTime createdAt;
  final double? lat;
  final double? lng;

  Client({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lat,
    this.lng,
  });

  factory Client.fromMap(Map<String, dynamic> map) {
    double? parseNullableDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return Client(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      lat: parseNullableDouble(map['lat']),
      lng: parseNullableDouble(map['lng']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'lat': lat,
      'lng': lng,
    };
  }

  @override
  String toString() => 'Client(id: $id, name: $name, created_at: $createdAt, lat: $lat, lng: $lng)';
}
