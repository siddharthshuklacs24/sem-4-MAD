import 'package:flutter/material.dart';
import '../models/node.dart';
import '../services/node_service.dart';
import '../services/navigation_controller.dart';
import '../models/destination.dart';
import '../services/destination_service.dart';

class MapScreen extends StatefulWidget {
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Node> nodes = [];
  List<Offset> pathPoints = [];

  NavMode selectedMode = NavMode.indoor; // ✅ NEW

  @override
  void initState() {
    super.initState();
    loadNodes();
  }

  void loadNodes() async {
    nodes = await NodeService.loadNodes();
    setState(() {});
  }

  Future<void> runNavigation() async {
    try {
      var path = await getPath(
        mode: selectedMode,
        source: "FG_ENTRANCE",      // ⚠️ change later to dynamic
        destination: "FG_MESS_HALL",
      );

      print("PATH: $path");

      if (selectedMode == NavMode.indoor) {
        // ✅ draw on indoor map
        setState(() {
          pathPoints = path
              .map((p) => Offset(p.longitude, p.latitude))
              .toList();
        });
      } else {
        // 🚀 outdoor (temporary)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Outdoor path fetched (see console)")),
        );
      }
    } catch (e) {
      print("ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Navigation"),

        // ✅ MODE TOGGLE ADDED
        actions: [
          DropdownButton<NavMode>(
            value: selectedMode,
            items: [
              DropdownMenuItem(
                  value: NavMode.indoor, child: Text("Indoor")),
              DropdownMenuItem(
                  value: NavMode.outdoor, child: Text("Outdoor")),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  selectedMode = val;
                  pathPoints = []; // reset path
                });
              }
            },
          ),
          SizedBox(width: 10),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: runNavigation,
        child: Icon(Icons.play_arrow),
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth;
          double height = constraints.maxHeight;

          return Stack(
            children: [
              // MAP IMAGE (only relevant for indoor)
              if (selectedMode == NavMode.indoor)
                Image.asset(
                  'assets/images/mess/FLOOR1Digital.png',
                  width: width,
                  height: height,
                  fit: BoxFit.fill,
                ),

              // PATH DRAWING (only indoor)
              if (selectedMode == NavMode.indoor)
                CustomPaint(
                  size: Size(width, height),
                  painter: PathPainter(pathPoints),
                ),

              // NODES (only indoor)
              if (selectedMode == NavMode.indoor)
                ...nodes.map((node) {
                  return Positioned(
                    left: node.x,
                    top: node.y,
                    child: _buildNode(),
                  );
                }).toList(),

              // OUTDOOR PLACEHOLDER
              if (selectedMode == NavMode.outdoor)
                Center(
                  child: Text(
                    "Outdoor mode active\n(Check console for path)",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNode() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ✅ PATH PAINTER
class PathPainter extends CustomPainter {
  final List<Offset> points;

  PathPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}