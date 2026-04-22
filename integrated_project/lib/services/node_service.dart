import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/node.dart';
import 'package:latlong2/latlong.dart';
class NodeService {
  // Inside NodeService.dart
  static Future<List<Node>> loadNodes() async {
    // Load both files
    final String f1String = await rootBundle.loadString('assets/nodes/mess/floor1.json');
    final String fgString = await rootBundle.loadString('assets/nodes/mess/ground_floor.json');

    // Parse both
    final List<dynamic> f1Json = json.decode(f1String);
    final List<dynamic> fgJson = json.decode(fgString);

    // Combine them into one big list
    final combined = [...f1Json, ...fgJson];
    return combined.map((json) => Node.fromJson(json)).toList();
  }

  static Future<Map<String, LatLng>> getNodeCoordinates() async {
  final nodes = await loadNodes();

  final Map<String, LatLng> nodeMap = {};

  for (var node in nodes) {
    nodeMap[node.id] = LatLng(node.x, node.y);
  }

  return nodeMap;
}
}