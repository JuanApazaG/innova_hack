import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/route_model.dart';
import 'navigation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RouteModel? rutaAsignada;
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
            rutaAsignada = RouteModel.fromJson(rutas[4]);
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
                          // Navegar a pantalla de navegación
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NavigationScreen(route: rutaAsignada!),
                            ),
                          );
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFE3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Menú hamburguesa
              IconButton(
                icon: const Icon(Icons.menu, size: 28, color: Color(0xFFF75307)),
                onPressed: () {
                  // TODO: Abrir menú lateral
                  print('Abrir menú');
                },
                padding: const EdgeInsets.all(8),
              ),
              
              // Logos empresas
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLogo(
                      'assets/logos/logo_swisscontact.png',
                      'Swisscontact',
                      url: 'https://www.swisscontact.org/es',
                    ),
                    _buildLogo(
                      'assets/logos/logo_emacruz.png',
                      'Emacruz',
                      url: 'https://www.emacruz.com.bo/',
                    ),
                    _buildLogo(
                      'assets/logos/logo_ciudades_circulates.png',
                      'Ciudades Circulares',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(String assetPath, String label, {String? url}) {
    Widget logoWidget = Container(
      height: 80,
      width: 90,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFE3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Placeholder si no existe la imagen
          return Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
    
    // Si tiene URL, hacer que sea clickable
    if (url != null) {
      return InkWell(
        onTap: () => _launchURL(url),
        borderRadius: BorderRadius.circular(8),
        child: logoWidget,
      );
    }
    
    return logoWidget;
  }
  
  Future<void> _launchURL(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir el enlace: $urlString'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                text: 'Hola  Agustin Apaza',
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
          color: Color(0xFF148040),
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

  Widget _buildMapa(RouteModel ruta) {
    if (ruta.coordinates.isEmpty) {
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
    
    // Crear markers solo para inicio (verde) y final (rojo)
    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('inicio'),
        position: ruta.startPoint,
        infoWindow: const InfoWindow(title: 'Inicio'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('final'),
        position: ruta.endPoint,
        infoWindow: const InfoWindow(title: 'Final'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
    
    // Crear la polilínea que conecta los puntos
    final Set<Polyline> polylines = {
      Polyline(
        polylineId: const PolylineId('ruta'),
        points: ruta.coordinates,
        color: const Color(0xFF148040),
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
    
    return Container(
      height: 300,
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
            target: ruta.center,
            zoom: 15.0,
          ),
          markers: markers,
          polylines: polylines,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          rotateGesturesEnabled: false,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: false,
          zoomGesturesEnabled: true,
          mapType: MapType.normal,
          minMaxZoomPreference: const MinMaxZoomPreference(12, 18),
        ),
      ),
    );
  }

  Widget _buildRutaCard({
    required BuildContext context,
    required RouteModel ruta,
    required VoidCallback onIniciarRuta,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 241, 231, 206),
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
            ruta.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Información adicional
          Text(
            '${ruta.pointCount} puntos en la ruta',
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
