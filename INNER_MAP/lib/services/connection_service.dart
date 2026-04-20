import 'dart:convert';
import 'package:flutter/services.dart';

class ConnectionService {
  static Future<Map<String, List<String>>> loadConnections() async {
    final data = await rootBundle.loadString(
      'assets/connections/mess/floor1.json',
    );

    final Map<String, dynamic> jsonResult = json.decode(data);

    return jsonResult.map((key, value) {
      return MapEntry(
        key,
        List<String>.from(value),
      );
    });
  }

  static Future<Map<String, List<String>>> loadGroundConnections() async {
    final data = await rootBundle.loadString(
      'assets/connections/mess/ground_floor.json',
    );

    final Map<String, dynamic> jsonResult = json.decode(data);

    return jsonResult.map((key, value) {
      return MapEntry(key, List<String>.from(value));
    });
  }

  static Future<Map<String, List<String>>> loadInterFloorConnections() async {
    final data = await rootBundle.loadString(
      'assets/connections/mess/inter_floor.json',
    );

    final Map<String, dynamic> jsonResult = json.decode(data);

    return jsonResult.map((key, value) {
      return MapEntry(key, List<String>.from(value));
    });
  }
}