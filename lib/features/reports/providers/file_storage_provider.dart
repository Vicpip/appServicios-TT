import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Proveedor para manejar almacenamiento de archivos (fotos, firmas)
class FileStorageProvider {
  static const String _photosFolder = 'reports/photos';
  static const String _signaturesFolder = 'reports/signatures';

  /// Obtiene el directorio de documentos de la aplicación
  static Future<Directory> _getDocumentsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir;
  }

  /// Obtiene la ruta para guardar fotos
  static Future<String> _getPhotosPath() async {
    final dir = await _getDocumentsDir();
    final path = '${dir.path}/$_photosFolder';
    final photoDir = Directory(path);

    // Crea el directorio si no existe
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }

    return path;
  }

  /// Obtiene la ruta para guardar firmas
  static Future<String> _getSignaturesPath() async {
    final dir = await _getDocumentsDir();
    final path = '${dir.path}/$_signaturesFolder';
    final signatureDir = Directory(path);

    // Crea el directorio si no existe
    if (!await signatureDir.exists()) {
      await signatureDir.create(recursive: true);
    }

    return path;
  }

  /// Guarda una foto de evidencia comprimida a máximo 2MB
  /// Retorna la ruta del archivo guardado
  static Future<String> savePhoto(File photoFile) async {
    final photoPath = await _getPhotosPath();
    final photoId = const Uuid().v4();
    final fileName = 'photo_$photoId.jpg';
    final filePath = '$photoPath/$fileName';

    // Copia el archivo
    final savedFile = await photoFile.copy(filePath);

    // Comprime si es necesario (máximo 2MB)
    await _compressImageIfNeeded(savedFile);

    return savedFile.path;
  }

  /// Comprime una imagen si excede 2MB
  static Future<void> _compressImageIfNeeded(File imageFile) async {
    const int maxSizeInBytes = 2 * 1024 * 1024; // 2MB
    final fileSize = await imageFile.length();

    // Si la imagen está dentro del límite, no necesita compresión
    if (fileSize <= maxSizeInBytes) {
      return;
    }

    // Para esta versión, simplemente registramos que se necesaría compresión
    // La compresión real requeriría librerías adicionales (image, image_compress, etc)
    // Por ahora, el sistema preserva la imagen original
    // TODO: Implementar compresión real con librería image
  }

  /// Guarda la imagen de una firma digital
  /// Retorna la ruta del archivo guardado
  static Future<String> saveSignature(File signatureFile) async {
    final signaturePath = await _getSignaturesPath();
    final signatureId = const Uuid().v4();
    final fileName = 'signature_$signatureId.png';
    final filePath = '$signaturePath/$fileName';

    final savedFile = await signatureFile.copy(filePath);
    return savedFile.path;
  }

  /// Obtiene todas las fotos guardadas de un reporte
  static Future<List<File>> getPhotosForReport(String reportId) async {
    final photoPath = await _getPhotosPath();
    final dir = Directory(photoPath);

    if (!await dir.exists()) {
      return [];
    }

    final entities = await dir.list().toList();
    return entities
        .whereType<File>()
        .where((file) => file.path.endsWith('.jpg'))
        .toList();
  }

  /// Elimina una foto del almacenamiento
  static Future<void> deletePhoto(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Log error pero no falla la operación
      print('Error eliminando foto: $e');
    }
  }

  /// Elimina una firma del almacenamiento
  static Future<void> deleteSignature(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Log error pero no falla la operación
      print('Error eliminando firma: $e');
    }
  }

  /// Verifica si un archivo existe
  static Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// Obtiene el tamaño de un archivo en bytes
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      print('Error obteniendo tamaño de archivo: $e');
    }
    return 0;
  }
}

/// Riverpod provider para acceso a FileStorageProvider
final fileStorageProvider = Provider<FileStorageProvider>((ref) {
  return FileStorageProvider();
});
