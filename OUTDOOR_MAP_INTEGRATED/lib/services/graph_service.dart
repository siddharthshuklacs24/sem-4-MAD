import 'connection_service.dart';

class GraphService {
  static Future<Map<String, List<String>>> buildGraph() async {
    // Load floor-wise connections
    final floor1 = await ConnectionService.loadConnections();
    final ground = await ConnectionService.loadGroundConnections(); // you'll create this
    final interFloor = await ConnectionService.loadInterFloorConnections();

    final Map<String, List<String>> graph = {};

    void addAll(Map<String, List<String>> source) {
      for (var entry in source.entries) {
        graph.putIfAbsent(entry.key, () => []);
        graph[entry.key]!.addAll(entry.value);
      }
    }

    addAll(floor1);
    addAll(ground);
    addAll(interFloor);

    return graph;
  }
}