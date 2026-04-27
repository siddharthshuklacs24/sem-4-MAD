import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class CampusBlock {
  final String name;
  final LatLng location;

  CampusBlock({required this.name, required this.location});
}

// 🔹 Your building data (copy ALL from old file)
final List<CampusBlock> blocks = [
  CampusBlock(name: "MESS BLOCK", location: LatLng(12.9399, 77.5653)),
  CampusBlock(name: "SPORTS BLOCK", location: LatLng(12.9406, 77.5660)),
  CampusBlock(name: "MECH BLOCK", location: LatLng(12.9420, 77.5653)),
  CampusBlock(name: "PJ BLOCK", location: LatLng(12.9407, 77.5654)),
  CampusBlock(name: "PG BLOCK", location: LatLng(12.9415, 77.5658)),
  CampusBlock(name: "SCIENCE BLOCK", location: LatLng(12.9407, 77.5650)),
];

// 🔹 Convert name → LatLng
LatLng? getBlockLocation(String name) {
  try {
    return blocks.firstWhere(
      (b) => b.name.toLowerCase() == name.toLowerCase(),
    ).location;
  } catch (_) {
    return null;
  }
}

// 🔹 MAIN function (your code)
Future<List<LatLng>> getOutdoorPath(
    LatLng start, LatLng end) async {

  final url =
      "https://router.project-osrm.org/route/v1/foot/"
      "${start.longitude},${start.latitude};"
      "${end.longitude},${end.latitude}"
      "?overview=full&geometries=geojson";

  final res = await http.get(Uri.parse(url));
  final data = json.decode(res.body);

  if (data['routes'] == null || data['routes'].isEmpty) {
    throw Exception("Route failed");
  }

  final coords =
      data['routes'][0]['geometry']['coordinates'] as List;

  return coords
      .map((c) => LatLng(c[1], c[0]))
      .toList();
}