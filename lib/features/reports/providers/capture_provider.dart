import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const List<String> kServiceTypes = <String>[
  'Preventivo',
  'Correctivo',
  'Diagnóstico',
  'Instalación',
];

const List<String> kLabelTypes = <String>[
  'Papel TT',
  'Papel TD',
  'Plástica (BOPP/Poliéster)',
];

const List<String> kChecklistItems = <String>[
  'Mantenimiento general',
  'Calibración sensores',
  'Rodillo dañado',
  'Cabezal dañado',
  'Sensor ribbon dañado',
  'Sensor papel dañado',
  'Pruebas',
  'Otros',
];

Map<String, bool> _emptyChecklist() => <String, bool>{
      for (final String item in kChecklistItems) item: false,
    };

@immutable
class CaptureState {
  const CaptureState({
    this.printerId,
    this.selectedServiceType = 'Preventivo',
    this.selectedLabelType = 'Papel TT',
    this.checkValues = const <String, bool>{},
    this.counterValue = '',
    this.darknessValue = '',
    this.notes = '',
    this.photoPaths = const <String>[],
    this.signatureImagePath,
    this.assignmentOverride = false,
  });

  final String? printerId;
  final String selectedServiceType;
  final String selectedLabelType;
  final Map<String, bool> checkValues;
  final String counterValue;
  final String darknessValue;
  final String notes;

  // Campos nuevos para multimedia
  final List<String> photoPaths;
  final String? signatureImagePath;

  /// Indica que el técnico aceptó trabajar en una impresora asignada a otro técnico.
  final bool assignmentOverride;

  List<String> get selectedDiagnostics => checkValues.entries
      .where((MapEntry<String, bool> e) => e.value)
      .map((MapEntry<String, bool> e) => e.key)
      .toList();

  /// Número de fotos capturadas
  int get photoCount => photoPaths.length;

  /// Verifica si hay al menos una foto
  bool get hasPhotos => photoPaths.isNotEmpty;

  CaptureState copyWith({
    String? printerId,
    String? selectedServiceType,
    String? selectedLabelType,
    Map<String, bool>? checkValues,
    String? counterValue,
    String? darknessValue,
    String? notes,
    List<String>? photoPaths,
    String? signatureImagePath,
    bool? assignmentOverride,
  }) {
    return CaptureState(
      printerId: printerId ?? this.printerId,
      selectedServiceType: selectedServiceType ?? this.selectedServiceType,
      selectedLabelType: selectedLabelType ?? this.selectedLabelType,
      checkValues: checkValues ?? this.checkValues,
      counterValue: counterValue ?? this.counterValue,
      darknessValue: darknessValue ?? this.darknessValue,
      notes: notes ?? this.notes,
      photoPaths: photoPaths ?? this.photoPaths,
      signatureImagePath: signatureImagePath ?? this.signatureImagePath,
      assignmentOverride: assignmentOverride ?? this.assignmentOverride,
    );
  }
}

class CaptureNotifier extends Notifier<CaptureState> {
  @override
  CaptureState build() => CaptureState(checkValues: _emptyChecklist());

  void setServiceType(String type) =>
      state = state.copyWith(selectedServiceType: type);

  void setLabelType(String type) =>
      state = state.copyWith(selectedLabelType: type);

  void toggleCheckItem(String item) {
    final Map<String, bool> updated =
        Map<String, bool>.from(state.checkValues);
    updated[item] = !(updated[item] ?? false);
    state = state.copyWith(checkValues: updated);
  }

  void commitFormValues({
    required String counter,
    required String darkness,
    required String notes,
  }) {
    state = state.copyWith(
      counterValue: counter,
      darknessValue: darkness,
      notes: notes,
    );
  }

  void setPrinterId(String? id) => state = state.copyWith(printerId: id);

  void setAssignmentOverride({required bool value}) =>
      state = state.copyWith(assignmentOverride: value);

  // ============================================================================
  // Métodos para manejo de fotos
  // ============================================================================

  /// Agrega una o más fotos a la captura
  void addPhotoPaths(List<String> paths) {
    final updatedPaths = <String>[...state.photoPaths, ...paths];
    state = state.copyWith(photoPaths: updatedPaths);
  }

  /// Elimina una foto por índice
  void removePhotoAt(int index) {
    if (index >= 0 && index < state.photoPaths.length) {
      final updatedPaths = <String>[...state.photoPaths];
      updatedPaths.removeAt(index);
      state = state.copyWith(photoPaths: updatedPaths);
    }
  }

  /// Limpia todas las fotos
  void clearPhotos() {
    state = state.copyWith(photoPaths: const <String>[]);
  }

  /// Reemplaza todas las fotos
  void setPhotoPaths(List<String> paths) {
    state = state.copyWith(photoPaths: paths);
  }

  // ============================================================================
  // Métodos para manejo de firma
  // ============================================================================

  /// Establece la ruta de la imagen de firma
  void setSignatureImagePath(String path) {
    state = state.copyWith(signatureImagePath: path);
  }

  /// Limpia la firma
  void clearSignature() {
    state = state.copyWith(signatureImagePath: null);
  }

  // ============================================================================
  // Reset
  // ============================================================================

  void resetCapture() => state = CaptureState(checkValues: _emptyChecklist());
}

final captureProvider = NotifierProvider<CaptureNotifier, CaptureState>(
  CaptureNotifier.new,
);
