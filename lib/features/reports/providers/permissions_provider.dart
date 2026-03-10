import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Estado de permisos
class PermissionState {
  final bool cameraGranted;
  final bool storageGranted;
  final bool cameraRequested;
  final bool storageRequested;

  PermissionState({
    required this.cameraGranted,
    required this.storageGranted,
    required this.cameraRequested,
    required this.storageRequested,
  });

  PermissionState copyWith({
    bool? cameraGranted,
    bool? storageGranted,
    bool? cameraRequested,
    bool? storageRequested,
  }) {
    return PermissionState(
      cameraGranted: cameraGranted ?? this.cameraGranted,
      storageGranted: storageGranted ?? this.storageGranted,
      cameraRequested: cameraRequested ?? this.cameraRequested,
      storageRequested: storageRequested ?? this.storageRequested,
    );
  }
}

/// Notifier para manejar permisos
class PermissionsNotifier extends StateNotifier<PermissionState> {
  PermissionsNotifier()
      : super(
          PermissionState(
            cameraGranted: false,
            storageGranted: false,
            cameraRequested: false,
            storageRequested: false,
          ),
        );

  /// Solicita permiso de cámara
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    state = state.copyWith(
      cameraGranted: status.isGranted,
      cameraRequested: true,
    );
    return status.isGranted;
  }

  /// Solicita permiso de almacenamiento
  Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();
    state = state.copyWith(
      storageGranted: status.isGranted,
      storageRequested: true,
    );
    return status.isGranted;
  }

  /// Verifica si la cámara tiene permiso
  Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.status;
    final isGranted = status.isGranted;
    state = state.copyWith(cameraGranted: isGranted);
    return isGranted;
  }

  /// Verifica si el almacenamiento tiene permiso
  Future<bool> checkStoragePermission() async {
    final status = await Permission.storage.status;
    final isGranted = status.isGranted;
    state = state.copyWith(storageGranted: isGranted);
    return isGranted;
  }

  /// Solicita ambos permisos
  Future<bool> requestAllPermissions() async {
    final cameraGranted = await requestCameraPermission();
    final storageGranted = await requestStoragePermission();
    return cameraGranted && storageGranted;
  }

  /// Abre la configuración de aplicación para que el usuario pueda habilitar permisos
  Future<void> openAppSettings() async {
    openAppSettings();
  }
}

/// Provider para el estado de permisos
final permissionsProvider =
    StateNotifierProvider<PermissionsNotifier, PermissionState>((ref) {
  return PermissionsNotifier();
});
