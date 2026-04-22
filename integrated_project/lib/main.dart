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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
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

  

  String formatNodeName(String rawId) {
    if (rawId.contains('_')) {
      final parts = rawId.split('_');
      final floorPrefix = parts[0];
      parts.removeAt(0);
      final name = parts.map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : "").join(' ');
      return "$name ($floorPrefix)";
    }
    return rawId;
  }

  void calculatePathIfReady() async {
  if (startNodeId != null && endNodeId != null) {
    if (startNodeId == endNodeId) {
      setState(() => path = []);
      return;
    }

    try {
      final result = await getPath(
        mode: selectedMode,
        source: startNodeId!,
        destination: endNodeId!,
      );

      if (selectedMode == NavMode.indoor) {
        // ✅ define newPath HERE
        final newPath = result.map((p) {
          final node = nodes.firstWhere(
            (n) =>
                (n.x - p.latitude).abs() < 1 &&
                (n.y - p.longitude).abs() < 1,
          );
          return node.id;
        }).toList();

        // ✅ use it inside same block
        setState(() {
          path = newPath;

          if (path.isNotEmpty) {
            final startNode =
                nodes.firstWhereOrNull((n) => n.id == path.first);
            if (startNode != null) {
              currentFloor = startNode.floor.trim().toUpperCase();
            }
          }
        });
      } else {
        // 🚀 outdoor mode
        print("OUTDOOR PATH: $result");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Outdoor path fetched (check console)"),
          ),
        );
      }
    } catch (e) {
      print("ERROR: $e");
    }
  }
}

  String getMapImage() {
    return currentFloor == "FG"
        ? "assets/images/mess/ground_floorDigital.png"
        : "assets/images/mess/FLOOR1Digital.png";
  }

  String getFloorName(String floorCode) {
    return floorCode == "FG" ? "Ground Floor" : "Floor $floorCode";
  }

  @override
  Widget build(BuildContext context) {
    // We only filter nodes for the visual DOTS, not for the path line calculation
    final currentFloorNodes = nodes.where((n) => n.floor.trim().toUpperCase() == currentFloor.trim().toUpperCase()).toList();

    // Determine which floors have parts of the path
    List<String> floorsInPath = [];
    for (var id in path) {
      final node = nodes.firstWhereOrNull((n) => n.id == id);
      if (node != null) floorsInPath.add(node.floor.trim().toUpperCase());
    }

    List<String> floorsToShow = path.isEmpty
        ? nodes.map((n) => n.floor.trim().toUpperCase()).toSet().toList()
        : floorsInPath.toSet().toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Navigation"),
        actions: [

          // 🔥 NEW: Mode toggle
    DropdownButton<NavMode>(
      value: selectedMode,
      items: const [
        DropdownMenuItem(value: NavMode.indoor, child: Text("Indoor")),
        DropdownMenuItem(value: NavMode.outdoor, child: Text("Outdoor")),
      ],
      onChanged: (val) {
  if (val != null) {
    if (val == NavMode.outdoor) {
      // 🚀 NAVIGATE TO OUTDOOR SCREEN
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OutdoorScreen(),
        ),
      );
    } else {
      // stay on indoor
      setState(() {
        selectedMode = NavMode.indoor;
        path = [];
        startNodeId = null;
        endNodeId = null;
      });
    }
  }
},
    ),

    
          if (startNodeId != null || endNodeId != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.red),
              onPressed: () => setState(() {
                startNodeId = null; endNodeId = null; path = [];
                startSearchController.clear(); endSearchController.clear();
              }),
            ),
          DropdownButton<String>(
            // Safety: ensure currentFloor is actually in the list of floors we're showing
            value: floorsToShow.contains(currentFloor) ? currentFloor : (floorsToShow.isNotEmpty ? floorsToShow.first : null),
            items: floorsToShow.map((f) => DropdownMenuItem(value: f, child: Text(getFloorName(f)))).toList(),
            onChanged: (val) { if (val != null) setState(() => currentFloor = val); },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(2000),
            minScale: 0.1,
            maxScale: 4.0,
            child: SizedBox(
              width: 700, // 🚀 RESTORED: Locks the coordinate system
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 🚀 RESTORED: Forces image to match JSON coordinate scale
                  Image.asset(getMapImage(), width: 700, fit: BoxFit.fitWidth),

                  Positioned.fill(
                      child: CustomPaint(
                          painter: GraphPainter(nodes, currentFloor, connections, path)
                      )
                  ),
                  ...currentFloorNodes.map((node) {
                    Color nodeColor = node.id == startNodeId ? Colors.green : (node.id == endNodeId ? Colors.orange : Colors.red.withOpacity(0.5));
                    double size = (node.id == startNodeId || node.id == endNodeId) ? 20 : 12;
                    return Positioned(
                      left: node.x - (size/2), top: node.y - (size/2),
                      child: Container(
                          width: size, height: size,
                          decoration: BoxDecoration(color: nodeColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          Positioned(
            top: 10, left: 10, right: 10,
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildSearchField("From", startSearchController, (id) {
                      startNodeId = id;
                      calculatePathIfReady();
                    }),
                    const Divider(),
                    buildSearchField("To", endSearchController, (id) {
                      endNodeId = id;
                      calculatePathIfReady();
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSearchField(String label, SearchController controller, Function(String) onSelected) {
    return SearchAnchor(
      searchController: controller,
      builder: (context, controller) {
        return SearchBar(
          controller: controller,
          hintText: label,
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
          leading: Icon(label == "From" ? Icons.my_location : Icons.location_on, color: label == "From" ? Colors.green : Colors.orange),
          onTap: () => controller.openView(),
        );
      },
      suggestionsBuilder: (context, controller) {
        final keyword = controller.text.toLowerCase();
        return nodes
            .where((n) => formatNodeName(n.id).toLowerCase().contains(keyword))
            .map((n) => ListTile(
          title: Text(formatNodeName(n.id)),
          subtitle: Text("Located on ${getFloorName(n.floor)}"),
          onTap: () {
            controller.closeView(formatNodeName(n.id));
            onSelected(n.id);
          },
        )).toList();
      },
    );
  }
}

class GraphPainter extends CustomPainter {
  final List<Node> allNodes;
  final String activeFloor;
  final Map<String, List<String>> connections;
  final List<String> path;

  GraphPainter(this.allNodes, this.activeFloor, this.connections, this.path);

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = Colors.blue.withOpacity(0.05)..strokeWidth = 1.0;
    final pathPaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw background connections ONLY for nodes physically on this floor
    for (var entry in connections.entries) {
      final fNode = allNodes.firstWhereOrNull((n) => n.id == entry.key);
      if (fNode == null || fNode.floor.trim().toUpperCase() != activeFloor) continue;

      for (var tId in entry.value) {
        final tNode = allNodes.firstWhereOrNull((n) => n.id == tId);
        if (tNode != null && tNode.floor.trim().toUpperCase() == activeFloor) {
          canvas.drawLine(Offset(fNode.x, fNode.y), Offset(tNode.x, tNode.y), basePaint);
        }
      }
    }

    // Draw active path segments ONLY if they are on the current floor
    if (path.isNotEmpty) {
      for (int i = 0; i < path.length - 1; i++) {
        final fNode = allNodes.firstWhereOrNull((n) => n.id == path[i]);
        final tNode = allNodes.firstWhereOrNull((n) => n.id == path[i + 1]);

        if (fNode != null && tNode != null) {
          if (fNode.floor.trim().toUpperCase() == activeFloor &&
              tNode.floor.trim().toUpperCase() == activeFloor) {
            canvas.drawLine(Offset(fNode.x, fNode.y), Offset(tNode.x, tNode.y), pathPaint);
          }
        }
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}