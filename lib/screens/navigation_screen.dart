import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';
import 'congratulations_screen.dart';

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
  bool _isClosing = false; // Flag para evitar reconexiones durante cierre
  String _lastSyncTime = 'Sin sincronizar';
  Timer? _locationTimer;
  bool _isTrackingPaused = false;
  static const String _userId = '6918e47e92cd6492dbd7953a'; // Agustin Apaza
  
  // Detección de desviación de ruta
  bool _isOffRoute = false;
  double _distanceToRoute = 0.0;
  DateTime? _lastOffRouteAlert;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStartTracking();
    _connectWebSocket();
  }

  @override
  void dispose() {
    print('🧹 NavigationScreen dispose() llamado');
    
    // Marcar que se está cerrando para evitar reconexiones
    _isClosing = true;
    
    // Cancelar timer primero
    _locationTimer?.cancel();
    
    // Cancelar stream de ubicación
    _positionStream?.cancel();
    
    // Cerrar WebSocket de forma segura
    try {
      _wsChannel?.sink.close();
    } catch (e) {
      print('⚠️ Error al cerrar WebSocket en dispose: $e');
    }
    
    // Liberar controladores
    _mapController?.dispose();
    _sheetController.dispose();
    
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
      
      // Verificar si se salió de la ruta
      _checkIfOffRoute(position);
    });

    // Mover la cámara del mapa para seguir al usuario
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(position.latitude, position.longitude),
      ),
    );
  }
  
  // Verificar si el usuario se salió de la ruta
  void _checkIfOffRoute(Position position) {
    if (widget.route.coordinates.length < 2) return;
    
    // Calcular distancia mínima a la polilínea de la ruta
    double minDistance = double.infinity;
    
    for (int i = 0; i < widget.route.coordinates.length - 1; i++) {
      final point1 = widget.route.coordinates[i];
      final point2 = widget.route.coordinates[i + 1];
      
      final distance = _distanceToLineSegment(
        LatLng(position.latitude, position.longitude),
        point1,
        point2,
      );
      
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    _distanceToRoute = minDistance;
    
    // Tolerancia: 25 metros para activar, 20 metros para desactivar (histéresis)
    if (!_isOffRoute && minDistance > 25) {
      // Se salió de la ruta
      _isOffRoute = true;
      _showOffRouteAlert();
    } else if (_isOffRoute && minDistance < 20) {
      // Regresó a la ruta
      _isOffRoute = false;
    }
  }
  
  // Calcular distancia de un punto a un segmento de línea
  double _distanceToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    // Convertir a coordenadas cartesianas aproximadas (en metros)
    final x = point.longitude;
    final y = point.latitude;
    final x1 = lineStart.longitude;
    final y1 = lineStart.latitude;
    final x2 = lineEnd.longitude;
    final y2 = lineEnd.latitude;
    
    final A = x - x1;
    final B = y - y1;
    final C = x2 - x1;
    final D = y2 - y1;
    
    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    double param = -1;
    
    if (lenSq != 0) {
      param = dot / lenSq;
    }
    
    double xx, yy;
    
    if (param < 0) {
      xx = x1;
      yy = y1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
    } else {
      xx = x1 + param * C;
      yy = y1 + param * D;
    }
    
    // Calcular distancia en metros usando Haversine
    return Geolocator.distanceBetween(point.latitude, point.longitude, yy, xx);
  }
  
  // Mostrar alerta de desviación
  void _showOffRouteAlert() {
    // Evitar alertas repetitivas (cooldown de 10 segundos)
    if (_lastOffRouteAlert != null &&
        DateTime.now().difference(_lastOffRouteAlert!) < const Duration(seconds: 10)) {
      return;
    }
    
    _lastOffRouteAlert = DateTime.now();
    
    // Enviar alerta al servidor
    _sendAlertToServer();
    
    // Vibrar el teléfono
    _vibratePhone();
    
    // Mostrar banner de alerta
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '⚠️ TE SALISTE DE LA RUTA',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Estás a ${_distanceToRoute.round()}m de la ruta',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'ENTENDIDO',
            textColor: Colors.white,
            onPressed: () {
              // Cerrar el snackbar
            },
          ),
        ),
      );
    }
  }
  
  // Vibrar el teléfono y reproducir sonido de alerta
  Future<void> _vibratePhone() async {
    // Reproducir sonido de notificación 5 veces
    final player = AudioPlayer();
    try {
      for (int i = 0; i < 5; i++) {
        await player.play(AssetSource('sounds/notificacion.mp3'));
        // Esperar a que termine el sonido antes de reproducir el siguiente
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } catch (e) {
      print('Error al reproducir sonido: $e');
    }
    
    // Vibrar el teléfono
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      // Patrón: vibrar 500ms, pausar 200ms, vibrar 500ms
      Vibration.vibrate(duration: 500);
      await Future.delayed(const Duration(milliseconds: 700));
      Vibration.vibrate(duration: 500);
    }
  }
  
  // Enviar alerta al servidor cuando se sale de la ruta
  Future<void> _sendAlertToServer() async {
    print('🚨 Enviando alerta al servidor...');
    print('   User ID: $_userId');
    print('   Route ID: ${widget.route.id}');
    
    // 1. Enviar al endpoint de alertas principal
    try {
      final response = await http.post(
        Uri.parse('https://innovahack.onrender.com/api/alerts/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'route_id': widget.route.id,
          'user_id': _userId,
        }),
      );
      
      print('📡 Respuesta del servidor principal:');
      print('   Status: ${response.statusCode}');
      print('   Body: ${response.body}');
      
      if (response.statusCode == 201) {
        print('✅ Alerta enviada exitosamente al servidor principal');
        final data = json.decode(response.body);
        print('   Mensaje: ${data['message']}');
        print('   Usuario: ${data['name_user']}');
        print('   Ruta: ${data['route_name']}');
      } else {
        print('❌ Error al enviar alerta al servidor principal: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error enviando alerta al servidor principal: $e');
    }
    
    // 2. Enviar al webhook de Telegram (n8n)
    try {
      print('\n📱 Enviando notificación a Telegram...');
      final webhookResponse = await http.post(
        Uri.parse('https://n8n.juanagustinapaza.me/webhook/notificacion'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'route_id': widget.route.id,
          'user_id': _userId,
          'message': 'Se desvió de su ruta',
          'route_name': widget.route.name,
          'distance': _distanceToRoute.round(),
        }),
      );
      
      print('📡 Respuesta del webhook Telegram:');
      print('   Status: ${webhookResponse.statusCode}');
      print('   Body: ${webhookResponse.body}');
      
      if (webhookResponse.statusCode == 200 || webhookResponse.statusCode == 201) {
        print('✅ Notificación enviada exitosamente a Telegram');
      } else {
        print('❌ Error al enviar notificación a Telegram: ${webhookResponse.statusCode}');
      }
    } catch (e) {
      print('❌ Error enviando notificación a Telegram: $e');
    }
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
    _locationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !_isWsConnected && !_isClosing) {
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
          const SizedBox(height: 16),
          
          // Barra de progreso profesional con imagen personalizada
          _buildCustomProgressBar(),
          
          const SizedBox(height: 16),
          
          
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

  Widget _buildCustomProgressBar() {
    final progress = _calculateProgress();
    final percentage = (progress * 100).round();
    
    return Column(
      children: [
        // Línea superior con info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // INICIO
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INICIO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            
            // Porcentaje y distancia (centro)
            Column(
              children: [
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF148040),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            
            // FINAL
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'FINAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Barra de progreso con imagen personalizada
        SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Contenedor de la línea de progreso
              Positioned(
                left: 16,
                right: 16,
                child: Stack(
                  children: [
                    // Línea de fondo (gris claro)
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    
                    // Línea de progreso (verde con gradiente)
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0d5c2e),
                              Color(0xFF148040),
                              Color(0xFF1ea34f),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF148040).withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Icono de bandera INICIO (verde)
              Positioned(
                left: 6,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF148040),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.flag,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
              
              // Icono de pin FINAL (rojo)
              Positioned(
                right: 6,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFdc3545),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
              
              // IMAGEN PERSONALIZADA - Marcador de posición actual
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                left: _calculateImagePosition(progress),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 48,
                        height: 48,
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/progreso.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback si la imagen no carga
                              return Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF75307),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.navigation,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  onEnd: () {
                    // Repetir animación de escala
                    if (mounted) {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) setState(() {});
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _calculateImagePosition(double progress) {
    // Calcular posición de la imagen en la barra
    // Considerando el ancho de la pantalla y los márgenes
    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = 40.0; // 20px de cada lado
    final availableWidth = screenWidth - cardPadding - 64; // 64 = espacio para iconos
    
    // La imagen debe moverse entre los iconos (posición 28 a availableWidth - 28)
    final minPosition = 28.0;
    final maxPosition = availableWidth - 20;
    
    return minPosition + (progress * (maxPosition - minPosition));
  }

  Widget _buildDraggableBottomSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.25, // 25% de la pantalla inicialmente
      minChildSize: 0.12, // Mínimo 12% (modo colapsado)
      maxChildSize: 0.40, // Máximo 40% (modo expandido)
      snap: true,
      snapSizes: const [0.12, 0.25, 0.40], // Puntos de anclaje
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

                    // Botón "TERMINAR RUTA"
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _showFinishConfirmation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF148040),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'TERMINAR RUTA',
                          style: TextStyle(
                            fontSize: 20,
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

  void _showSuccessModal() async {
    // Marcar que se está cerrando para evitar reconexiones
    _isClosing = true;
    
    // Limpiar recursos antes de navegar
    print('🧹 Limpiando recursos antes de navegar...');
    
    // Cancelar timer de ubicación
    _locationTimer?.cancel();
    
    // Cerrar WebSocket de forma segura
    try {
      await _wsChannel?.sink.close();
      print('✅ WebSocket cerrado correctamente');
    } catch (e) {
      print('⚠️ Error al cerrar WebSocket: $e');
    }
    
    // Cancelar stream de ubicación
    await _positionStream?.cancel();
    print('✅ Stream de ubicación cancelado');
    
    // Pequeña pausa para asegurar que todo se limpió
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Navegar a la pantalla de felicitaciones
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CongratulationsScreen(route: widget.route),
        ),
      );
    }
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
