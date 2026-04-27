import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/node.dart';
import 'package:latlong2/latlong.dart';

class NodeService {
  /// Loads indoor nodes for Mess Block
  static Future<List<Node>> loadNodes() async {
    try {
      final String f1String = await rootBundle.loadString('assets/nodes/mess/floor1.json');
      final String fgString = await rootBundle.loadString('assets/nodes/mess/ground_floor.json');

      final List<dynamic> f1Json = json.decode(f1String);
      final List<dynamic> fgJson = json.decode(fgString);

      final combined = [...f1Json, ...fgJson];
      return combined.map((json) => Node.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error loading indoor nodes: $e");
      return [];
    }
  }

  /// Maps indoor node IDs to coordinates
  static Future<Map<String, LatLng>> getNodeCoordinates() async {
    final nodes = await loadNodes();
    final Map<String, LatLng> nodeMap = {};
    for (var node in nodes) {
      nodeMap[node.id] = LatLng(node.x, node.y);
    }
    return nodeMap;
  }

  /// Fetches outdoor coordinates
  /// MATCHES YAML: assets/nodes/outdoor/nodes.json
  static Future<Map<String, LatLng>> getOutdoorNodeCoordinates() async {
    try {
      const String path = 'assets/nodes/outdoor/nodes.json';
      final String response = await rootBundle.loadString(path);
      final Map<String, dynamic> data = json.decode(response);
      
      return data.map((key, value) {
        return MapEntry(
          key, 
          LatLng(value[0] as double, value[1] as double)
        );
      });
    } catch (e) {
      debugPrint("Error loading outdoor nodes: $e");
      return {};
    }
  }

  /// NEW: Fetches the road network
  /// MATCHES YAML: assets/connections/outdoor/roads.json
  static Future<Map<String, List<String>>> getOutdoorAdjacencyList() async {
    try {
      // THIS PATH NOW MATCHES YOUR YAML EXACTLY
      const String path = 'assets/connections/outdoor/roads.json';
      
      final String response = await rootBundle.loadString(path);
      final Map<String, dynamic> data = json.decode(response);
      
      return data.map((key, value) {
        return MapEntry(
          key, 
          List<String>.from(value as List)
        );
      });
    } catch (e) {
      debugPrint("Error loading outdoor roads from connections folder: $e");
      return {};
    }
  }
}