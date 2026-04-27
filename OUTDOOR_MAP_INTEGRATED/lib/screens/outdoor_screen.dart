import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

// Service imports
import '../services/navigation_controller.dart';
import '../services/node_service.dart';

enum MapUI {
  googleRoadmap("Google Roadmap", 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'),
  googleSatellite("Google Satellite", 'https://{s}.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'),
  googleHybrid("Google Hybrid", 'https://{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'),
  voyager("Voyager", 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png');

  final String label;
  final String url;
  const MapUI(this.label, this.url);
}

class OutdoorScreen extends StatefulWidget {
  const OutdoorScreen({super.key});

  @override
  State<OutdoorScreen> createState() => _OutdoorScreenState();
}

class _OutdoorScreenState extends State<OutdoorScreen> {
  final MapController mapController = MapController();
  final SearchController fromSearchController = SearchController();
  final SearchController toSearchController = SearchController();

  final LatLng campusCenter = const LatLng(12.9410, 77.5654);
  MapUI selectedUI = MapUI.googleRoadmap;

  bool isDebugMode = false; 
  bool showGoogleLabels = true; 
  
  Map<String, LatLng> allNodesCoordinates = {}; 
  Map<String, List<String>> adjacencyList = {}; 

  final Map<String, List<String>> targetPOIs = {
    "PJ BLOCK": ["PJ_FRONT", "PJ_BACK", "PJ_LEFT", "PJ_RIGHT"],
    "PG BLOCK": ["PG_BLOCK_ENTRY_1", "PG_BLOCK_ENTRY_2", "PG_BLOCK_ENTRY_3"],
    "SCIENCE BLOCK": ["SCIENCE_BLOCK"],
    "MESS BLOCK": ["MESS_BLOCK"], // Path: MESS_ENTRY -> MESS_ROAD -> MESS_BLOCK
    "SPORTS BLOCK": ["SPORTS_BLOCK_FRONT", "SPORTS_BLOCK_BACK"],
    "MECHANICAL BLOCK": ["MECH_BLOCK_ENTRY"], 
    "CAMPUS BOOK MART": ["CAMPUS_BOOK_MART"],
    "CANTEEN": ["CANTEEN"],
    "VIDYAARTHI KHAANA": ["VIDYAARTHI_KHAANA"],
  };

  LatLng? userPos;
  List<LatLng> routePoints = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadNodes();
    await _initLocation();
  }

  Future<void> _loadNodes() async {
    try {
      final nodes = await NodeService.getOutdoorNodeCoordinates();
      final roads = await NodeService.getOutdoorAdjacencyList(); 
      setState(() {
        allNodesCoordinates = nodes;
        adjacencyList = roads;
      });
    } catch (e) {
      debugPrint("Data Load Error: $e");
    }
  }

  Future<void> _initLocation() async {
    try {
      if (!kIsWeb) await Permission.location.request();
      Position pos = await Geolocator.getCurrentPosition();
      setState(() => userPos = LatLng(pos.latitude, pos.longitude));
      mapController.move(userPos!, 17);
    } catch (e) {
      debugPrint("GPS error: $e");
    }
  }

  double _getDistance(LatLng p1, LatLng p2) {
    var p = 0.017453292519943295;
    var c = math.cos;
    var a = 0.5 - c((p2.latitude - p1.latitude) * p) / 2 +
        c(p1.latitude * p) * c(p2.latitude * p) *
            (1 - c((p2.longitude - p1.longitude) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  String _findNearestEntrance(List<String> entryIds, LatLng reference) {
    if (entryIds.isEmpty) return "";
    String nearestId = entryIds.first;
    double minDistance = double.infinity;

    for (String id in entryIds) {
      LatLng? coord = allNodesCoordinates[id];
      if (coord != null) {
        double dist = _getDistance(reference, coord);
        if (dist < minDistance) {
          minDistance = dist;
          nearestId = id;
        }
      }
    }
    return nearestId;
  }

  List<Polyline> _buildDebugEdges() {
    List<Polyline> edges = [];
    adjacencyList.forEach((startNodeId, neighbors) {
      final startCoord = allNodesCoordinates[startNodeId];
      if (startCoord != null) {
        for (var neighborId in neighbors) {
          final endCoord = allNodesCoordinates[neighborId];
          if (endCoord != null) {
            edges.add(Polyline(
              points: [startCoord, endCoord],
              color: Colors.red.withOpacity(0.6),
              strokeWidth: 3.0,
            ));
          }
        }
      }
    });
    return edges;
  }

  Future<void> calculateRoute() async {
    String fromText = fromSearchController.text.trim().toUpperCase();
    String toText = toSearchController.text.trim().toUpperCase();

    if (fromText.isEmpty || toText.isEmpty || fromText == toText) return;

    setState(() => isLoading = true);
    try {
      LatLng startRef = userPos ?? campusCenter;
      String startNode = targetPOIs.containsKey(fromText) 
          ? _findNearestEntrance(targetPOIs[fromText]!, startRef) 
          : fromText;

      LatLng startCoord = allNodesCoordinates[startNode] ?? startRef;
      String endNode = targetPOIs.containsKey(toText) 
          ? _findNearestEntrance(targetPOIs[toText]!, startCoord) 
          : toText;

      final result = await getPath(
        mode: NavMode.outdoor,
        source: startNode,
        destination: endNode,
      );

      setState(() => routePoints = result);
      
      if (routePoints.isNotEmpty) {
        mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(routePoints),
          padding: const EdgeInsets.only(top: 240, left: 50, right: 50, bottom: 50),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No valid path found."))
        );
      }
    } catch (e) {
      debugPrint("Routing Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _getMapUrl() {
    String base = selectedUI.url;
    if (!showGoogleLabels && base.contains("google.com")) {
      return '$base&apistyle=s.e:l|p.v:off'; 
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "debug_toggle",
            mini: true,
            backgroundColor: isDebugMode ? Colors.redAccent : Colors.white,
            onPressed: () => setState(() => isDebugMode = !isDebugMode),
            child: Icon(Icons.bug_report, color: isDebugMode ? Colors.white : Colors.grey),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "label_toggle",
            mini: true,
            backgroundColor: showGoogleLabels ? Colors.blueAccent : Colors.white,
            onPressed: () => setState(() => showGoogleLabels = !showGoogleLabels),
            child: Icon(showGoogleLabels ? Icons.label : Icons.label_off, color: showGoogleLabels ? Colors.white : Colors.blueAccent),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "style_picker",
            backgroundColor: Colors.white,
            onPressed: _showStylePicker,
            child: const Icon(Icons.layers_rounded, color: Colors.blueAccent),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(initialCenter: campusCenter, initialZoom: 17),
            children: [
              TileLayer(
                urlTemplate: _getMapUrl(),
                subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                tileProvider: CancellableNetworkTileProvider(),
              ),
              if (isDebugMode) PolylineLayer(polylines: _buildDebugEdges()),

              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: routePoints, color: Colors.blueAccent.withOpacity(0.3), strokeWidth: 12),
                    Polyline(points: routePoints, color: Colors.blueAccent, strokeWidth: 6, strokeCap: StrokeCap.round),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (userPos != null)
                    Marker(point: userPos!, child: const Icon(Icons.my_location, color: Colors.blue, size: 28)),
                  
                  if (isDebugMode)
                    ...allNodesCoordinates.entries.map((entry) => Marker(
                      point: entry.value,
                      width: 140, height: 60,
                      child: Column(
                        children: [
                          const Icon(Icons.circle, color: Colors.red, size: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.red, width: 1),
                            ),
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    )),

                  if (!isDebugMode && allNodesCoordinates.isNotEmpty)
                    ...targetPOIs.keys.map((poiName) {
                      String mainNodeId = targetPOIs[poiName]!.first;
                      LatLng? pos = allNodesCoordinates[mainNodeId];
                      if (pos == null) return Marker(point: campusCenter, child: const SizedBox());

                      return Marker(
                        point: pos,
                        width: 120, height: 85,
                        child: GestureDetector(
                          onTap: () {
                            if (poiName == "MESS BLOCK") {
                              debugPrint("Navigating to MESS Indoor Map...");
                              // Navigator.push(context, MaterialPageRoute(builder: (c) => const MessIndoorScreen()));
                            } else {
                              setState(() => toSearchController.text = poiName);
                            }
                          },
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white, 
                                  borderRadius: BorderRadius.circular(8), 
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                                ),
                                child: Text(poiName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              Icon(
                                Icons.location_on, 
                                color: poiName == "MESS BLOCK" ? Colors.green : Colors.redAccent, 
                                size: 32
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
          _buildSearchOverlay(),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchField(fromSearchController, "Starting Point"),
            const SizedBox(height: 10),
            _buildSearchField(toSearchController, "Where to?"),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : calculateRoute,
                icon: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : const Icon(Icons.directions),
                label: Text(isLoading ? "Finding Path..." : "Get Campus Directions"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(SearchController controller, String hint) {
    return SearchAnchor(
      searchController: controller,
      builder: (context, controller) {
        return SearchBar(
          controller: controller,
          hintText: hint,
          onTap: () => controller.openView(),
          onChanged: (_) => controller.openView(),
          leading: const Icon(Icons.search, color: Colors.blueAccent),
          backgroundColor: WidgetStateProperty.all(Colors.white),
          elevation: WidgetStateProperty.all(2),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          trailing: [
            if (controller.text.isNotEmpty)
              IconButton(icon: const Icon(Icons.clear), onPressed: () => controller.clear())
          ],
        );
      },
      suggestionsBuilder: (context, controller) {
        final query = controller.text.toUpperCase();
        final matches = targetPOIs.keys.where((poiName) => poiName.contains(query)).toList();

        return matches.map((poiName) => ListTile(
          leading: const Icon(Icons.place_outlined, size: 20),
          title: Text(poiName),
          onTap: () {
            setState(() {
              controller.closeView(poiName);
            });
          },
        ));
      },
    );
  }

  void _showStylePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: MapUI.values.map((style) => ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(style.label),
            onTap: () {
              setState(() => selectedUI = style);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }
}