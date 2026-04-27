import 'package:latlong2/latlong.dart';
class PathService {
  static List<String> findPath(
      String start,
      String end,
      Map<String, List<String>> connections,
      ) {
    final queue = <List<String>>[];
    final visited = <String>{};

    queue.add([start]);

    while (queue.isNotEmpty) {
      final currentPath = queue.removeAt(0);
      final node = currentPath.last;

      if (node == end) return currentPath;

      if (!visited.contains(node)) {
        visited.add(node);

        for (var neighbor in connections[node] ?? []) {
          final newPath = List<String>.from(currentPath);
          newPath.add(neighbor);
          queue.add(newPath);
        }
      }
    }

    return [];
  }

  //function for controller 
  static List<LatLng> getIndoorPath(
    String start,
    String end,
    Map<String, List<String>> connections,
    Map<String, LatLng> nodeCoordinates, // 👈 important
  ) {
    final path = findPath(start, end, connections);

    return path.map((node) {
      return nodeCoordinates[node] ?? LatLng(0, 0); // convert name → LatLng
    }).toList();
  }
}