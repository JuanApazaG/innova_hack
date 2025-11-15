import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/route_model.dart';

class NavigationScreen extends StatefulWidget {
  final RouteModel route;

  const NavigationScreen({super.key, required this.route});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  double _distanceToEnd = 0;
  bool _isWithinFinishRadius = false;
  bool _hasLocationPermission = false;
  String _statusMessage = 'Cargando ubicación...';
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  
  // WebSocket tracking
  WebSocketChannel? _wsChannel;
  bool _isWsConnected = false;
  String _lastSyncTime = 'Sin sincronizar';
  Timer? _locationTimer;
  bool _isTrackingPaused = false;
  static const String _userId = '6918c21792cd6492dbd79515'; // Agustin Apaza

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStartTracking();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    _sheetController.dispose();
    _locationTimer?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  Future<void> _checkPermissionsAndStartTracking() async {
    // Verificar si el servicio de ubicación está habilitado
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _statusMessage = 'Activa el GPS para continuar';
      });
      return;
    }

    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _statusMessage = 'Permiso de ubicación denegado';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _statusMessage = 'Permiso de ubicación denegado permanentemente';
      });
      return;
    }

    // Permiso concedido, iniciar seguimiento
    setState(() {
      _hasLocationPermission = true;
      _statusMessage = 'Siguiendo la ruta';
    });

    _startLocationTracking();
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Actualizar cada 10 metros
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updatePosition(position);
    });
  }

  void _updatePosition(Position position) {
    setState(() {
      _currentPosition = position;

      // Calcular distancia al final
      _distanceToEnd = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.route.endPoint.latitude,
        widget.route.endPoint.longitude,
      );

      // Verificar si está dentro del radio de finalización (30 metros)
      _isWithinFinishRadius = _distanceToEnd <= 30;

      // Actualizar mensaje de estado
      if (_isWithinFinishRadius) {
        _statusMessage = '¡Llegaste al final!';
      } else {
        _statusMessage = 'Siguiendo la ruta';
      }
    });

    // Mover la cámara del mapa para seguir al usuario
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(position.latitude, position.longitude),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  String _formatTime(double meters) {
    // Asumimos velocidad de caminata: 5 km/h = 1.39 m/s
    final seconds = (meters / 1.39).round();
    if (seconds < 60) {
      return '$seconds seg';
    } else {
      final minutes = (seconds / 60).round();
      return '$minutes min';
    }
  }

  // ============ WEBSOCKET TRACKING ============
  
  void _connectWebSocket() {
    try {
      final wsUrl = 'ws://innovahack.onrender.com/ws/tracker/$_userId';
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Escuchar mensajes del servidor
      _wsChannel!.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          setState(() {
            _isWsConnected = false;
          });
          _reconnectWebSocket();
        },
        onDone: () {
          print('WebSocket closed');
          setState(() {
            _isWsConnected = false;
          });
          _reconnectWebSocket();
        },
      );
      
      setState(() {
        _isWsConnected = true;
      });
      
      // Iniciar timer de envío de ubicación cada 5 segundos
      _startLocationTimer();
      
    } catch (e) {
      print('Error connecting WebSocket: $e');
      setState(() {
        _isWsConnected = false;
      });
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = json.decode(message);
      print('WebSocket received: $data');
      
      if (data['type'] == 'connected') {
        print('WebSocket connected: ${data['message']}');
      } else if (data['type'] == 'location_received') {
        setState(() {
          _lastSyncTime = _formatCurrentTime();
        });
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  void _startLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isTrackingPaused && _currentPosition != null && _isWsConnected) {
        _sendLocationToServer();
      }
    });
  }

  void _sendLocationToServer() {
    if (_wsChannel == null || _currentPosition == null) return;
    
    try {
      final locationData = {
        'type': 'location_update',
        'lat': _currentPosition!.latitude,
        'lng': _currentPosition!.longitude,
      };
      
      _wsChannel!.sink.add(json.encode(locationData));
      print('Location sent: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      
    } catch (e) {
      print('Error sending location: $e');
    }
  }

  void _reconnectWebSocket() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_isWsConnected) {
        print('Attempting to reconnect WebSocket...');
        _connectWebSocket();
      }
    });
  }

  void _toggleTracking() {
    setState(() {
      _isTrackingPaused = !_isTrackingPaused;
    });
    
    if (_isTrackingPaused) {
      print('Tracking paused');
    } else {
      print('Tracking resumed');
    }
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa de Google Maps
          _buildMap(),

          // Tarjeta flotante con información
          if (_hasLocationPermission && _currentPosition != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              child: _buildInfoCard(),
            ),

          // Panel inferior deslizable (BottomSheet)
          _buildDraggableBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('inicio'),
        position: widget.route.startPoint,
        infoWindow: const InfoWindow(title: 'Inicio'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('final'),
        position: widget.route.endPoint,
        infoWindow: const InfoWindow(title: 'Final'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    final Set<Polyline> polylines = {
      Polyline(
        polylineId: const PolylineId('ruta'),
        points: widget.route.coordinates,
        color: const Color(0xFF148040),
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.route.startPoint,
        zoom: 16.0,
      ),
      markers: markers,
      polylines: polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: true,
      zoomGesturesEnabled: true,
      mapType: MapType.normal,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isWithinFinishRadius ? Icons.check_circle : Icons.navigation,
                color: _isWithinFinishRadius ? const Color(0xFF148040) : const Color(0xFFF75307),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isWithinFinishRadius ? const Color(0xFF148040) : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.place, color: Color(0xFFF75307), size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatDistance(_distanceToEnd)} al final',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.access_time, color: Color(0xFF148040), size: 22),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(_distanceToEnd),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _calculateProgress(),
              minHeight: 12,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF148040)),
            ),
          ),
          
          // Indicador de conexión WebSocket
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _isWsConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isWsConnected ? 'Tracking activo' : 'Desconectado',
                style: TextStyle(
                  fontSize: 13,
                  color: _isWsConnected ? Colors.green[700] : Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                _lastSyncTime,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateProgress() {
    if (_currentPosition == null) return 0.0;
    
    final distanceStart = Geolocator.distanceBetween(
      widget.route.startPoint.latitude,
      widget.route.startPoint.longitude,
      widget.route.endPoint.latitude,
      widget.route.endPoint.longitude,
    );
    
    final progress = 1 - (_distanceToEnd / distanceStart);
    return progress.clamp(0.0, 1.0);
  }

  Widget _buildDraggableBottomSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.30, // 30% de la pantalla inicialmente
      minChildSize: 0.15, // Mínimo 15% (modo colapsado)
      maxChildSize: 0.60, // Máximo 60% (modo expandido)
      snap: true,
      snapSizes: const [0.15, 0.30, 0.60], // Puntos de anclaje
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4EFE3),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(0),
            children: [
              // Barra de arrastre (handle)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Título de la ruta
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  widget.route.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Divider(height: 24, thickness: 1),

              // Contenido del panel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Botón "LLEGUÉ AL FINAL"
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _isWithinFinishRadius ? _showFinishConfirmation : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isWithinFinishRadius
                              ? const Color(0xFF148040)
                              : Colors.grey[400],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: _isWithinFinishRadius ? 4 : 0,
                        ),
                        child: Text(
                          _isWithinFinishRadius ? '✓ LLEGUÉ AL FINAL' : '📍 LLEGUÉ AL FINAL',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botón "REPORTAR PROBLEMA"
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: OutlinedButton(
                        onPressed: _showProblemReport,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFF75307), width: 2),
                          foregroundColor: const Color(0xFFF75307),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '⚠️ REPORTAR PROBLEMA',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botón "CANCELAR RUTA"
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: TextButton(
                        onPressed: _showCancelConfirmation,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'CANCELAR RUTA',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botón "PAUSAR/REANUDAR TRACKING"
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _toggleTracking,
                        icon: Icon(_isTrackingPaused ? Icons.play_arrow : Icons.pause),
                        label: Text(
                          _isTrackingPaused ? 'REANUDAR TRACKING' : 'PAUSAR TRACKING',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _isTrackingPaused ? Colors.green : Colors.orange,
                            width: 2,
                          ),
                          foregroundColor: _isTrackingPaused ? Colors.green : Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Información adicional (visible al expandir)
                    _buildRouteInfo(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información de la ruta',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on, '${widget.route.pointCount} puntos en la ruta'),
          const SizedBox(height: 8),
          if (_currentPosition != null)
            _buildInfoRow(Icons.directions_walk, '${_formatDistance(_distanceToEnd)} restantes'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.schedule, 'Tiempo estimado: ${_formatTime(_distanceToEnd)}'),
          
          const Divider(height: 20, thickness: 1),
          
          // Información de tracking
          Row(
            children: [
              Icon(
                _isWsConnected ? Icons.cloud_done : Icons.cloud_off,
                size: 20,
                color: _isWsConnected ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isWsConnected 
                    ? 'Tracking: ${_isTrackingPaused ? "Pausado" : "Activo"}'
                    : 'Sin conexión al servidor',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 20, color: Color(0xFF148040)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Última sincronización: $_lastSyncTime',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF148040)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  void _showFinishConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '¿Completaste la ruta?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Confirma que terminaste la recolección en esta ruta.',
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'NO, CONTINUAR',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccessModal();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF148040),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'SÍ, TERMINÉ',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '¡Ruta completada! 🎉',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Has completado la ruta de recolección.',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Ruta: ${widget.route.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF75307),
                minimumSize: const Size(double.infinity, 56),
              ),
              child: const Text(
                'VOLVER AL INICIO',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showProblemReport() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '⚠️ Reportar Problema',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProblemButton('🚧 Calle bloqueada'),
              _buildProblemButton('🐕 Perro peligroso'),
              _buildProblemButton('🏚️ Zona peligrosa'),
              _buildProblemButton('✍️ Otro problema'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCELAR',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProblemButton(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Problema reportado: $text',
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: const Color(0xFF148040),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 50),
        ),
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '¿Cancelar ruta?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Si cancelas, perderás el progreso de esta ruta.',
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'NO, CONTINUAR',
                style: TextStyle(fontSize: 18),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'SÍ, CANCELAR',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
