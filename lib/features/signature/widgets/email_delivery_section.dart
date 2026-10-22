import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:industrial_service_reports/core/constants.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/features/auth/services/auth_service.dart';

/// Lógica y contenido de la tarjeta "Envío por correo" que comparten las tres
/// pantallas de firma (individual, grupal y entrega de póliza). Cada pantalla
/// la envuelve en su propia tarjeta para conservar su estilo.

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// true si [value] tiene formato de correo (algo@dominio.tld, sin espacios).
bool isValidEmail(String value) => _emailRegex.hasMatch(value.trim());

/// Punto de entrada que usan las pantallas para consultar los correos del
/// cliente. Las pruebas de widgets lo sustituyen para no tocar la red.
Future<List<String>?> Function(String clientId) contactEmailsFetcher =
    fetchClientContactEmails;

/// Correos de contacto activos del cliente, o null si no se pudieron
/// consultar (sin conexión, timeout o error del servidor). En ese caso las
/// pantallas NO muestran la tarjeta "Envío por correo".
Future<List<String>?> fetchClientContactEmails(
  String clientId, {
  http.Client? httpClient,
}) async {
  try {
    final String? authToken = await AuthService().getToken();
    final http.Response response = await (httpClient ?? http.Client())
        .get(
          Uri.parse(
              '$kServerBaseUrlDevice/api/admin/clients/$clientId/contact-emails'),
          headers: <String, String>{
            if (authToken != null) 'Authorization': 'Bearer $authToken',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((dynamic e) => (e as Map<String, dynamic>)['email'] as String)
        .toList();
  } catch (_) {
    return null;
  }
}

/// Estado del campo "Correo adicional": texto, formulario y visibilidad.
class ExtraEmailController {
  final TextEditingController text = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final ValueNotifier<bool> showField = ValueNotifier<bool>(false);

  /// Correo adicional válido, o null si está vacío o tiene formato inválido.
  String? get value {
    final String v = text.text.trim();
    if (v.isEmpty) return null;
    return isValidEmail(v) ? v : null;
  }

  /// Valida el campo antes de guardar. Vacío es válido (es opcional). Si el
  /// formato es inválido muestra "Correo inválido" (en el campo y en un
  /// SnackBar) y devuelve false para que NO se finalice la firma.
  bool validate(BuildContext context) {
    final String v = text.text.trim();
    if (v.isEmpty || isValidEmail(v)) return true;

    showField.value = true;
    // Tras mostrar el campo, dispara el error en línea ("Correo inválido").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      formKey.currentState?.validate();
    });
    formKey.currentState?.validate();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(
          'Correo inválido',
          style: TextStyle(color: Theme.of(context).colorScheme.onError),
        ),
      ),
    );
    return false;
  }

  void dispose() {
    text.dispose();
    showField.dispose();
  }
}

/// Contenido de la tarjeta "Envío por correo": "Se enviará a: …" /
/// "Sin correos registrados", botón "Agregar otro" y campo "Correo adicional".
class EmailDeliveryBody extends StatelessWidget {
  const EmailDeliveryBody({
    super.key,
    required this.contactEmails,
    required this.controller,
  });

  final List<String> contactEmails;
  final ExtraEmailController controller;

  @override
  Widget build(BuildContext context) {
    final bool hasContacts = contactEmails.isNotEmpty;
    return ValueListenableBuilder<bool>(
      valueListenable: controller.showField,
      builder: (BuildContext context, bool showField, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  hasContacts
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
                  color: hasContacts ? AppPalette.success : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasContacts
                        ? 'Se enviará a: ${contactEmails.join(', ')}'
                        : 'Sin correos registrados',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (hasContacts && !showField) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => controller.showField.value = true,
                  child: const Text('Agregar otro'),
                ),
              ),
            ],
            if (!hasContacts || showField) ...<Widget>[
              const SizedBox(height: 10),
              Form(
                key: controller.formKey,
                child: TextFormField(
                  controller: controller.text,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo adicional',
                    isDense: true,
                  ),
                  validator: (String? v) {
                    final String value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    return isValidEmail(value) ? null : 'Correo inválido';
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
