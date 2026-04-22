import 'campus_nav_service.dart';
import 'path_service.dart'; // your indoor final path logic
import 'package:latlong2/latlong.dart';
import 'connection_service.dart';
import 'node_service.dart';
enum NavMode { indoor, outdoor }

Future<List<LatLng>> getPath({
  required NavMode mode,
  required String source,
  required String destination,
}) async {
  if (mode == NavMode.outdoor) {
    // 🔹 Convert names → coordinates
    final start = getBlockLocation(source);
    final end = getBlockLocation(destination);

    if (start == null || end == null) {
      throw Exception("Invalid building name");
    }

    return await getOutdoorPath(start, end);
  } else {
    // 🔹 get indoor data
    final connections = await ConnectionService.getConnections();
    final nodeCoordinates = await NodeService.getNodeCoordinates();

    return PathService.getIndoorPath(
      source,
      destination,
      connections,
      nodeCoordinates,
    );
  }
}