import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteModel {
  final String id;
  final String name;
  final List<LatLng> coordinates;
  final bool assigned;

  RouteModel({
    required this.id,
    required this.name,
    required this.coordinates,
    this.assigned = false,
  });

  // Crear desde JSON del API
  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> coords = json['coordinates'] ?? [];
    final List<LatLng> points = coords.map((coord) {
      final List<dynamic> punto = coord as List<dynamic>;
      // API envía [lng, lat], Google Maps usa [lat, lng]
      return LatLng(punto[1], punto[0]);
    }).toList();

    return RouteModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Ruta sin nombre',
      coordinates: points,
      assigned: json['assigned'] ?? false,
    );
  }

  // Obtener punto de inicio
  LatLng get startPoint => coordinates.isNotEmpty ? coordinates.first : const LatLng(0, 0);

  // Obtener punto final
  LatLng get endPoint => coordinates.isNotEmpty ? coordinates.last : const LatLng(0, 0);

  // Obtener centro del mapa
  LatLng get center {
    if (coordinates.isEmpty) return const LatLng(0, 0);
    
    double latSum = 0;
    double lngSum = 0;
    for (var point in coordinates) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }
    return LatLng(latSum / coordinates.length, lngSum / coordinates.length);
  }

  // Obtener número de puntos
  int get pointCount => coordinates.length;
}
