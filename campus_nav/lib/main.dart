import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class CampusBlock {
  final String name;
  final LatLng location;
  CampusBlock({required this.name, required this.location});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  final LatLng campusCenter = const LatLng(12.9410, 77.5654);

  final List<CampusBlock> blocks = [
    CampusBlock(name: "MESS BLOCK", location: const LatLng(12.9399, 77.5653)),
    CampusBlock(name: "SPORTS BLOCK", location: const LatLng(12.9406, 77.5660)),
    CampusBlock(name: "MECH BLOCK", location: const LatLng(12.9420, 77.5653)),
    CampusBlock(name: "PJ BLOCK", location: const LatLng(12.9407, 77.5654)),
    CampusBlock(name: "PG BLOCK", location: const LatLng(12.9415, 77.5658)),
    CampusBlock(name: "SCIENCE BLOCK", location: const LatLng(12.9407, 77.5650)),
  ];

  // 🔥 ENTRANCES
  Map<String, List<LatLng>> entrances = {
    "PJ BLOCK": [
      LatLng(12.940804822842074, 77.56568758587403),
      LatLng(12.941188882805164, 77.56551063865933),
      LatLng(12.94083769613996, 77.56523353596553),
      LatLng(12.940423870283793, 77.56537893585175),
    ],
    "PG BLOCK": [
      LatLng(12.941328829051773, 77.56565066488143),
      LatLng(12.941722931065895, 77.5653547818649),
      LatLng(12.941812645257562, 77.56573614217993),
    ],
    "SPORTS BLOCK": [
      LatLng(12.940633541861871, 77.56614709080672),
      LatLng(12.940750491223438, 77.56580518155876),
    ],
  };

  LatLng? userPos;
  List<LatLng> routePoints = [];
  bool isLoading = false;

  List<CampusBlock> suggestions = [];

  @override
  void initState() {
    super.initState();
    initLocation();
  }

  Future<void> initLocation() async {
    try {
      if (!kIsWeb) await Permission.location.request();

      Position pos = await Geolocator.getCurrentPosition();

      setState(() {
        userPos = LatLng(pos.latitude, pos.longitude);
      });

      mapController.move(userPos!, 17);
    } catch (e) {
      debugPrint("GPS error: $e");
    }
  }

  LatLng? getBlock(String name) {
    try {
      return blocks
          .firstWhere((b) =>
              b.name.toLowerCase() == name.toLowerCase())
          .location;
    } catch (_) {
      return null;
    }
  }

  LatLng getNearestEntrance(LatLng from, String blockName) {
    if (!entrances.containsKey(blockName)) return from;

    final list = entrances[blockName]!;

    list.sort((a, b) {
      double d1 = Distance().as(LengthUnit.Meter, from, a);
      double d2 = Distance().as(LengthUnit.Meter, from, b);
      return d1.compareTo(d2);
    });

    return list.first;
  }

  Future<void> calculateRoute() async {
    setState(() => isLoading = true);

    LatLng? start = getBlock(fromController.text);
    LatLng? end = getBlock(toController.text);

    if (start == null || end == null) {
      showMsg("Invalid location");
      setState(() => isLoading = false);
      return;
    }

    String fromName = fromController.text.toUpperCase();
    String toName = toController.text.toUpperCase();

    if (entrances.containsKey(fromName)) {
      start = getNearestEntrance(end, fromName);
    }

    if (entrances.containsKey(toName)) {
      end = getNearestEntrance(start, toName);
    }

    try {
      final url =
          "https://router.project-osrm.org/route/v1/foot/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson";

      final res = await http.get(Uri.parse(url));
      final data = json.decode(res.body);

      if (data['routes'] == null || data['routes'].isEmpty) {
        throw Exception();
      }

      final coords =
          data['routes'][0]['geometry']['coordinates'] as List;

      routePoints =
          coords.map((c) => LatLng(c[1], c[0])).toList();

      mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(routePoints),
        padding: const EdgeInsets.all(60),
      ));

      setState(() {});
    } catch (_) {
      showMsg("Route failed");
    }

    setState(() => isLoading = false);
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _searchBox(TextEditingController ctrl, String hint) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6)
            ],
          ),
          child: TextField(
            controller: ctrl,
            onChanged: (value) {
              if (value.isEmpty) {
                setState(() => suggestions.clear());
                return;
              }

              setState(() {
                suggestions = blocks
                    .where((b) => b.name
                        .toLowerCase()
                        .contains(value.toLowerCase()))
                    .toList();
              });
            },
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
              border: InputBorder.none,
            ),
          ),
        ),

        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView(
              shrinkWrap: true,
              children: suggestions.map((b) {
                return ListTile(
                  title: Text(b.name),
                  onTap: () {
                    ctrl.text = b.name;
                    setState(() => suggestions.clear());
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: campusCenter,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),

              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: Colors.blue,
                      strokeWidth: 5,
                    )
                  ],
                ),

              MarkerLayer(
                markers: [
                  if (userPos != null)
                    Marker(
                      point: userPos!,
                      child: const Icon(Icons.my_location,
                          color: Colors.blue, size: 30),
                    ),
                  ...blocks.map((b) => Marker(
                        point: b.location,
                        child: const Icon(Icons.location_on,
                            color: Colors.red),
                      )),
                ],
              ),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _searchBox(fromController, "From"),
                  const SizedBox(height: 8),
                  _searchBox(toController, "To"),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: calculateRoute,
                    child: const Text("Get Route"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}