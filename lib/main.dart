import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const InnovaHackApp());
}

class InnovaHackApp extends StatelessWidget {
  const InnovaHackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Innova Hack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF148040),
          primary: const Color(0xFF148040),
        ),
        scaffoldBackgroundColor: const Color(0xFF148040),
        useMaterial3: true,
      ),
      home: const PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  Map<String, dynamic>? rutaAsignada;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _cargarRutaAsignada();
  }

  Future<void> _cargarRutaAsignada() async {
    try {
      final response = await http.get(
        Uri.parse('https://innovahack.onrender.com/api/routes/'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> rutas = json.decode(response.body);
        
        // Buscar la ruta asignada (assigned: true)
        // Por ahora usamos la primera ruta como ejemplo
        // TODO: El backend debe enviar el ID de la ruta asignada al usuario
        if (rutas.isNotEmpty) {
          setState(() {
            rutaAsignada = rutas[0];
            isLoading = false;
          });
        } else {
          setState(() {
            error = 'No hay rutas disponibles';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'Error al cargar rutas';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error de conexión: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE3),
      body: SafeArea(
        child: Column(
          children: [
            // Header con logos
            _buildHeader(),
            
            // Contenido principal con scroll
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Saludo
                    _buildSaludo(),
                    
                    const SizedBox(height: 30),
                    
                    // Mostrar contenido según el estado
                    if (isLoading)
                      _buildLoading()
                    else if (error != null)
                      _buildError()
                    else if (rutaAsignada != null)
                      _buildRutaCard(
                        context: context,
                        ruta: rutaAsignada!,
                        onIniciarRuta: () {
                          // TODO: Navegar a pantalla de navegación de ruta
                          print('Iniciar Ruta: ${rutaAsignada!['_id']}');
                        },
                      ),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFE3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Menú hamburguesa
          IconButton(
            icon: const Icon(Icons.menu, size: 32, color: Color(0xFFF75307)),
            onPressed: () {
              // TODO: Abrir menú lateral
              print('Abrir menú');
            },
            padding: const EdgeInsets.all(12),
          ),
          // Logo izquierda
          _buildLogo('assets/logos/logo_swisscontact.png', 'Logo Izquierda'),
          
          
          
          // Logo derecha
          _buildLogo('assets/logos/logo_emacruz.png', 'Logo Derecha'),
        ],
      ),
    );
  }

  Widget _buildLogo(String assetPath, String label) {
    return Container(
      height: 70,
      width: 120,
      decoration: BoxDecoration( color: Colors.white,
      
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Placeholder si no existe la imagen
          return Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSaludo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Texto "Nombre Hola" en tamaño grande
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
            children: [
              
              TextSpan(
                text: 'Hola Agustin',
                style: TextStyle(color: Color(0xFF3C8F4F)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'selecciona la ruta',
          style: TextStyle(
            fontSize: 24,
            color: Colors.black,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40.0),
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 4,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            error ?? 'Error desconocido',
            style: const TextStyle(fontSize: 18, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                isLoading = true;
                error = null;
              });
              _cargarRutaAsignada();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf75307),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMapa(Map<String, dynamic> ruta) {
    final List<dynamic> coordinates = ruta['coordinates'] ?? [];
    
    if (coordinates.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No hay coordenadas disponibles'),
        ),
      );
    }
    
    // Convertir coordenadas del API a LatLng
    final List<LatLng> puntos = coordinates.map((coord) {
      final List<dynamic> punto = coord as List<dynamic>;
      return LatLng(punto[1], punto[0]); // API envía [lng, lat], Google Maps usa [lat, lng]
    }).toList();
    
    // Calcular el centro del mapa (promedio de coordenadas)
    double latSum = 0;
    double lngSum = 0;
    for (var punto in puntos) {
      latSum += punto.latitude;
      lngSum += punto.longitude;
    }
    final LatLng centro = LatLng(latSum / puntos.length, lngSum / puntos.length);
    
    // Crear markers para cada punto
    final Set<Marker> markers = {};
    for (int i = 0; i < puntos.length; i++) {
      markers.add(
        Marker(
          markerId: MarkerId('punto_$i'),
          position: puntos[i],
          infoWindow: InfoWindow(
            title: 'Punto ${i + 1}',
            snippet: '${puntos[i].latitude.toStringAsFixed(4)}, ${puntos[i].longitude.toStringAsFixed(4)}',
          ),
          icon: i == 0
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              : i == puntos.length - 1
                  ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
                  : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }
    
    // Crear la polilínea que conecta los puntos
    final Set<Polyline> polylines = {
      Polyline(
        polylineId: const PolylineId('ruta'),
        points: puntos,
        color: const Color(0xFF148040),
        width: 4,
      ),
    };
    
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[400]!,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: centro,
            zoom: 14.5,
          ),
          markers: markers,
          polylines: polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: true,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }

  Widget _buildRutaCard({
    required BuildContext context,
    required Map<String, dynamic> ruta,
    required VoidCallback onIniciarRuta,
  }) {
    final String nombreRuta = ruta['name'] ?? 'Ruta sin nombre';
    final int cantidadPuntos = (ruta['coordinates'] as List?)?.length ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de la ruta
          Text(
            nombreRuta,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Información adicional
          Text(
            '$cantidadPuntos puntos de parada',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Vista de Google Maps con coordenadas reales
          _buildMapa(ruta),
          
          const SizedBox(height: 20),
          
          // Botón "Iniciar ruta"
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: onIniciarRuta,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf75307),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: const Text(
                'Iniciar ruta',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
