import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';

class CongratulationsScreen extends StatefulWidget {
  final RouteModel route;

  const CongratulationsScreen({super.key, required this.route});

  @override
  State<CongratulationsScreen> createState() => _CongratulationsScreenState();
}

class _CongratulationsScreenState extends State<CongratulationsScreen> {
  File? _capturedImage;
  String? _imageBase64;
  bool _isUploading = false;
  bool _photoTaken = false;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _photoTaken ? _buildPhotoPreview() : _buildInitialView(),
        ),
      ),
    );
  }

  // Vista inicial con felicitaciones
  Widget _buildInitialView() {
    return Column(
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
    );
  }

  // Vista con preview de foto capturada
  Widget _buildPhotoPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        
        // Título
        const Text(
          '✓ Foto tomada exitosamente',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF148040),
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 32),
        
        // Preview de la foto
        if (_capturedImage != null)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(
                _capturedImage!,
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.4,
                fit: BoxFit.cover,
              ),
            ),
          ),
        
        const Spacer(flex: 1),
        
        // Loading indicator durante envío
        if (_isUploading)
          Column(
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF148040)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enviando foto...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF148040),
                ),
              ),
            ],
          ),
        
        // Botones cuando no está enviando
        if (!_isUploading) ...[
          // Botón ENVIAR FOTO
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _uploadPhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF148040),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.send, size: 28),
              label: const Text(
                'ENVIAR FOTO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Botón VOLVER A TOMAR
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _retakePhoto,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF75307),
                side: const BorderSide(color: Color(0xFFF75307), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 24),
              label: const Text(
                'VOLVER A TOMAR',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
        
        const Spacer(flex: 1),
      ],
    );
  }

  // Abrir cámara y capturar foto
  Future<void> _takePhoto() async {
    print('📸 Abriendo cámara...');
    
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Buena calidad (0-100)
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (photo != null) {
        print('✅ Foto capturada: ${photo.path}');
        
        // Leer bytes de la imagen
        final bytes = await photo.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        setState(() {
          _capturedImage = File(photo.path);
          _imageBase64 = base64Image;
          _photoTaken = true;
        });
        
        print('📦 Imagen convertida a base64 (${base64Image.length} caracteres)');
      } else {
        print('❌ Usuario canceló la cámara');
        // Usuario canceló, permanece en la pantalla de felicitaciones
      }
    } catch (e) {
      print('❌ Error al tomar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir cámara: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Volver a tomar foto
  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
      _imageBase64 = null;
      _photoTaken = false;
    });
    
    // Abrir cámara nuevamente
    _takePhoto();
  }

  // Enviar foto al servidor
  Future<void> _uploadPhoto() async {
    if (_imageBase64 == null) return;
    
    setState(() {
      _isUploading = true;
    });
    
    print('📤 Enviando foto al servidor...');
    print('   Base64 length: ${_imageBase64!.length} caracteres');
    
    try {
      final response = await http.post(
        Uri.parse('https://innovahack.onrender.com/api/agent/analyze-trash-bin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image_base64': _imageBase64,
        }),
      );
      
      print('📡 Respuesta del servidor:');
      print('   Status: ${response.statusCode}');
      print('   Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Foto enviada exitosamente');
        
        if (mounted) {
          // Mostrar mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Envío exitoso',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF148040),
              duration: Duration(seconds: 2),
            ),
          );
          
          // Esperar 2 segundos y volver al home
          await Future.delayed(const Duration(seconds: 2));
          
          if (mounted) {
            _returnHome();
          }
        }
      } else {
        print('❌ Error al enviar foto: ${response.statusCode}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al enviar: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error al enviar foto: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _returnHome() {
    // Volver a la pantalla principal (eliminar todas las pantallas anteriores)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
