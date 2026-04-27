import 'package:flutter/material.dart';
import 'package:indoor_navigation/services/path_service.dart';
import 'package:collection/collection.dart';

import '../models/node.dart';
import '../services/node_service.dart';
import '../services/graph_service.dart';
import '../services/navigation_controller.dart';
import 'screens/outdoor_screen.dart';

void main() {
  runApp(const IndoorNavigationApp());
}

class IndoorNavigationApp extends StatelessWidget {
  const IndoorNavigationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Node> nodes = [];
  Map<String, List<String>> connections = {};

  NavMode selectedMode = NavMode.indoor;

  String currentFloor = "F1";
  String? startNodeId;
  String? endNodeId;

  List<String> path = [];
  List<String> recentSearches = [];

  double mapScale = 1.0;

  final SearchController startSearchController = SearchController();
  final SearchController endSearchController = SearchController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    final loadedNodes = await NodeService.loadNodes();
    final graph = await GraphService.buildGraph();
    if (!mounted) return;
    setState(() {
      nodes = loadedNodes;
      connections = graph;
    });
  }

  Future<void> switchFloorAnimated(String newFloor) async {
    if (newFloor == currentFloor) return;
    setState(() => currentFloor = newFloor);
  }

  void saveRecent(String id) {
    setState(() {
      recentSearches.remove(id);
      recentSearches.insert(0, id);
      if (recentSearches.length > 5) recentSearches.removeLast();
    });
  }

  void calculatePathIfReady() async {
    if (startNodeId != null && endNodeId != null) {
      final result = await getPath(
        mode: NavMode.indoor,
        source: startNodeId!,
        destination: endNodeId!,
      );

      final newPath = result.map((p) {
        final node = nodes.firstWhere(
          (n) =>
              (n.x - p.latitude).abs() < 1 &&
              (n.y - p.longitude).abs() < 1,
        );
        return node.id;
      }).toList();

      setState(() {
        path = newPath;
        mapScale = 1.3;
      });
    }
  }

  String getMapImage() {
    return currentFloor == "FG"
        ? "assets/images/mess/ground_floorDigital.png"
        : "assets/images/mess/FLOOR1Digital.png";
  }

  String formatNodeName(String rawId) {
    if (rawId.contains('_')) {
      final parts = rawId.split('_');
      final floorPrefix = parts[0];
      parts.removeAt(0);
      final name =
          parts.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
      return "$name ($floorPrefix)";
    }
    return rawId;
  }

  @override
  Widget build(BuildContext context) {
    final currentFloorNodes = nodes
        .where((n) =>
            n.floor.trim().toUpperCase() ==
            currentFloor.trim().toUpperCase())
        .toList();

    final floors = nodes
        .map((n) => n.floor.trim().toUpperCase())
        .toSet()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Campus Navigator"),
        actions: [
          Row(
            children: [
              ChoiceChip(
                label: const Text("Indoor"),
                selected: selectedMode == NavMode.indoor,
                onSelected: (_) =>
                    setState(() => selectedMode = NavMode.indoor),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text("Outdoor"),
                selected: selectedMode == NavMode.outdoor,
                onSelected: (_) {
                  setState(() => selectedMode = NavMode.outdoor);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OutdoorScreen()),
                  );
                },
              ),
            ],
          ),
          DropdownButton<String>(
            value: currentFloor,
            underline: const SizedBox(),
            items: floors.map((f) {
              return DropdownMenuItem(
                value: f,
                child:
                    Text(f == "FG" ? "Ground Floor" : "Floor $f"),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) switchFloorAnimated(val);
            },
          ),
        ],
      ),

      body: Stack(
        children: [
          Center(
            child: AnimatedScale(
              scale: mapScale,
              duration: const Duration(milliseconds: 300),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: SizedBox(
                  width: 700,
                  child: Stack(
                    children: [
                      Image.asset(getMapImage(),
                          fit: BoxFit.cover),

                      Positioned.fill(
                        child: CustomPaint(
                          painter: GraphPainter(
                              nodes,
                              currentFloor,
                              connections,
                              path),
                        ),
                      ),

                      ...currentFloorNodes.map((node) {
                        return Positioned(
                          left: node.x - 12,
                          top: node.y - 24,
                          child: Icon(Icons.location_on,
                              color: node.id == startNodeId
                                  ? Colors.green
                                  : node.id == endNodeId
                                      ? Colors.orange
                                      : Colors.blue),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),

          /// SEARCH
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                constraints:
                    const BoxConstraints(maxWidth: 520),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 25,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    buildModernSearchField(
                      "From",
                      Icons.my_location,
                      Colors.green,
                      startSearchController,
                      (id) {
                        startNodeId = id;
                        saveRecent(id);
                        calculatePathIfReady();
                      },
                    ),
                    const SizedBox(height: 10),
                    buildModernSearchField(
                      "To",
                      Icons.location_on,
                      Colors.orange,
                      endSearchController,
                      (id) {
                        endNodeId = id;
                        saveRecent(id);
                        calculatePathIfReady();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 UPDATED SEARCH FIELD WITH RECENT SEARCHES
  Widget buildModernSearchField(
    String label,
    IconData icon,
    Color color,
    SearchController controller,
    Function(String) onSelected,
  ) {
    return SearchAnchor(
      searchController: controller,
      builder: (context, controller) {
        return GestureDetector(
          onTap: () => controller.openView(),
          child: AbsorbPointer(
            child: Container(
              height: 52,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: label,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },

      suggestionsBuilder: (context, controller) {
        final keyword = controller.text.toLowerCase();

        final filtered = nodes.where((n) =>
            formatNodeName(n.id)
                .toLowerCase()
                .contains(keyword));

        final recentWidgets = recentSearches.map((id) {
          return ListTile(
            leading:
                const Icon(Icons.history, color: Colors.grey),
            title: Text(formatNodeName(id)),
            onTap: () {
              controller.closeView(formatNodeName(id));
              onSelected(id);
            },
          );
        }).toList();

        final searchWidgets = filtered.map((n) {
          return ListTile(
            leading:
                const Icon(Icons.place, color: Colors.blue),
            title: Text(formatNodeName(n.id)),
            onTap: () {
              controller.closeView(formatNodeName(n.id));
              onSelected(n.id);
            },
          );
        }).toList();

        return [
          if (recentSearches.isNotEmpty && keyword.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
              child: Text("Recent Searches",
                  style:
                      TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...recentWidgets,
            const Divider(),
          ],
          ...searchWidgets,
        ];
      },
    );
  }
}

class GraphPainter extends CustomPainter {
  final List<Node> nodes;
  final String floor;
  final Map<String, List<String>> connections;
  final List<String> path;

  GraphPainter(this.nodes, this.floor, this.connections, this.path);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 4
      ..color = Colors.blueAccent;

    for (int i = 0; i < path.length - 1; i++) {
      final a =
          nodes.firstWhereOrNull((n) => n.id == path[i]);
      final b =
          nodes.firstWhereOrNull((n) => n.id == path[i + 1]);

      if (a == null || b == null) continue;
      if (a.floor != floor || b.floor != floor) continue;

      canvas.drawLine(
          Offset(a.x, a.y), Offset(b.x, b.y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      true;
}
