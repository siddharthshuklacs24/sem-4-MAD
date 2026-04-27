class Node {
  final String id;
  final double x;
  final double y;
  final String floor;

  Node({
    required this.id,
    required this.x,
    required this.y,
    required this.floor,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'],
      x: (json['x']).toDouble(),
      y: (json['y']).toDouble(),
      floor: json['floor'],
    );
  }
}