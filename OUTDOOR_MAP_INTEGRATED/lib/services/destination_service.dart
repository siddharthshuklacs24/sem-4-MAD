import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/destination.dart';

class DestinationService {
  static Future<List<Destination>> loadDestinations() async {
    final String f1Raw = await rootBundle.loadString('assets/destinations/mess/floor1.json');
    final String fgRaw = await rootBundle.loadString('assets/destinations/mess/ground_floor.json');

    final Map<String, dynamic> f1Json = json.decode(f1Raw);
    final Map<String, dynamic> fgJson = json.decode(fgRaw);

    final List<Destination> destinations = [];

    f1Json.forEach((name, nodeId) {
      destinations.add(Destination(name: name, nodeId: nodeId as String, floor: 'F1'));
    });

    fgJson.forEach((name, nodeId) {
      destinations.add(Destination(name: name, nodeId: nodeId as String, floor: 'FG'));
    });

    return destinations;
  }
}