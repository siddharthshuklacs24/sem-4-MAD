import 'connection_service.dart';
import 'node_service.dart';
import 'path_service.dart';
import 'package:latlong2/latlong.dart';

enum NavMode { indoor, outdoor }

Future<List<LatLng>> getPath({
  required NavMode mode,
  required String source,
  required String destination,
}) async {
  if (mode == NavMode.outdoor) {
    // 1. Load your CUSTOM road graph instead of calling OSRM
    final connections = await ConnectionService.loadOutdoorConnections();
    final nodeCoordinates = await NodeService.getOutdoorNodeCoordinates();

    return PathService.getIndoorPath(
      source,
      destination,
      connections,
      nodeCoordinates,
    );
  } else {
    // Indoor remains the same
    final connections = await ConnectionService.getConnections();
    final nodeCoordinates = await NodeService.getNodeCoordinates();

    return PathService.getIndoorPath(
      source, 
      destination, 
      connections, 
      nodeCoordinates
    );
  }
}