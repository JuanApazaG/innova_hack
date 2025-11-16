import 'package:flutter/material.dart';
import '../models/route_model.dart';

class CongratulationsScreen extends StatefulWidget {
  final RouteModel route;

  const CongratulationsScreen({super.key, required this.route});

  @override
  State<CongratulationsScreen> createState() => _CongratulationsScreenState();
}

class _CongratulationsScreenState extends State<CongratulationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // Título de felicitaciones
              const Text(
                '¡FELICIDADES!',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF148040),
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Subtítulo
              Text(
                'Completaste la ruta:\n${widget.route.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Imagen de felicitaciones
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/felicidades.png',
                    width: MediaQuery.of(context).size.width * 0.7,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: MediaQuery.of(context).size.width * 0.7,
                        height: 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFF148040),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.celebration,
                          size: 100,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Botón de tomar foto
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: _takePhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF75307),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.camera_alt, size: 32),
                  label: const Text(
                    'TOMAR FOTO',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Botón secundario para volver sin foto
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton(
                  onPressed: _returnHome,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Saltar por ahora',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  void _takePhoto() {
    // TODO: Implementar lógica de cámara
    print('📸 Abriendo cámara...');
    
    // Por ahora, mostrar un mensaje
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funcionalidad de cámara en desarrollo'),
        backgroundColor: Color(0xFF148040),
      ),
    );
  }

  void _returnHome() {
    // Volver a la pantalla principal (eliminar todas las pantallas anteriores)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
