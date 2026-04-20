import 'package:flutter/material.dart';
import '../models/node.dart';
import '../services/node_service.dart';

class MapScreen extends StatefulWidget {
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Node> nodes = [];

  @override
  void initState() {
    super.initState();
    loadNodes();
  }

  void loadNodes() async {
    nodes = await NodeService.loadNodes();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Indoor Map")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth;
          double height = constraints.maxHeight;

          return Stack(
            children: [
              // MAP IMAGE
              Image.asset(
                'assets/images/mess/FLOOR1Digital.png',
                width: width,
                height: height,
                fit: BoxFit.fill, // IMPORTANT
              ),

              // NODES
              ...nodes.map((node) {
                return Positioned(
                  left: node.x,
                  top: node.y,
                  child: _buildNode(),
                );
              }).toList(),
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