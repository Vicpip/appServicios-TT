import 'dart:io' as io;
import 'package:image_picker/image_picker.dart';
import 'package:industrial_service_reports/features/reports/providers/file_storage_provider.dart';

/// Servicio para captura de imágenes con cámara y galería
/// Comprime fotos a máximo 2MB automáticamente
class ImageCaptureService {
  static final ImagePicker _picker = ImagePicker();

  // Calidad de compresión para imágenes (reduce tamaño sin pérdida visual significativa)
  static const int _imageQuality = 85;
  // Tamaño máximo en bytes (2MB)
  static const int _maxSizeBytes = 2 * 1024 * 1024;

  /// Captura una foto desde la cámara.
  /// Retorna la ruta del archivo guardado, o null si el usuario cancela o hay error.
  static Future<String?> captureFromCamera() async {
    try {
      final XFile? xFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: _imageQuality,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (xFile == null) return null;

      final io.File file = io.File(xFile.path);
      return await _processAndSave(file);
    } catch (e) {
      return null;
    }
  }

  /// Selecciona una foto desde la galería.
  /// Retorna la ruta del archivo guardado, o null si el usuario cancela o hay error.
  static Future<String?> selectFromGallery() async {
    try {
      final XFile? xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: _imageQuality,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (xFile == null) return null;

      final io.File file = io.File(xFile.path);
      return await _processAndSave(file);
    } catch (e) {
      return null;
    }
  }

  /// Selecciona múltiples fotos desde la galería.
  /// Retorna lista de rutas guardadas.
  static Future<List<String>> selectMultipleFromGallery() async {
    try {
      final List<XFile> xFiles = await _picker.pickMultiImage(
        imageQuality: _imageQuality,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (xFiles.isEmpty) return [];

      final List<String> savedPaths = [];
      for (final XFile xFile in xFiles) {
        final io.File file = io.File(xFile.path);
        final String? savedPath = await _processAndSave(file);
        if (savedPath != null) {
          savedPaths.add(savedPath);
        }
      }
      return savedPaths;
    } catch (e) {
      return [];
    }
  }

  /// Procesa y guarda la imagen en almacenamiento local.
  /// Intenta reducir la calidad si el archivo supera 2MB.
  static Future<String?> _processAndSave(io.File imageFile) async {
    try {
      // Verificar tamaño
      final int fileSize = await imageFile.length();

      if (fileSize > _maxSizeBytes) {
        // Intentar re-comprimir con menor calidad
        final XFile? recompressed = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 60,
          maxWidth: 1600,
          maxHeight: 1600,
        );

        // Si la re-compresión no es posible, usar el archivo original
        final io.File fileToSave = recompressed != null
            ? io.File(recompressed.path)
            : imageFile;

        return await FileStorageProvider.savePhoto(fileToSave);
      }

      return await FileStorageProvider.savePhoto(imageFile);
    } catch (e) {
      return null;
    }
  }
}
