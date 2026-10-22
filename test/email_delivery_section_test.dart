// Tarjeta "Envío por correo" compartida por la firma individual, la grupal y la
// firma de entrega de póliza.
//
//   flutter test test/email_delivery_section_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:industrial_service_reports/features/signature/widgets/email_delivery_section.dart';

Future<ExtraEmailController> _pump(
  WidgetTester tester,
  List<String> contacts,
) async {
  final ExtraEmailController controller = ExtraEmailController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => Column(
          children: <Widget>[
            EmailDeliveryBody(contactEmails: contacts, controller: controller),
            TextButton(
              onPressed: () => controller.validate(context),
              child: const Text('validar'),
            ),
          ],
        ),
      ),
    ),
  ));
  return controller;
}

void main() {
  group('isValidEmail', () {
    test('acepta correos con formato válido', () {
      expect(isValidEmail('a@b.co'), isTrue);
      expect(isValidEmail('  nombre.apellido@dominio.com.mx '), isTrue);
    });
    test('rechaza formatos inválidos', () {
      for (final String bad in <String>['', 'sin-arroba', 'a@b', 'a b@c.com', '@c.com']) {
        expect(isValidEmail(bad), isFalse, reason: bad);
      }
    });
  });

  group('tarjeta con correos registrados', () {
    testWidgets('muestra "Se enviará a" y el botón "Agregar otro"', (tester) async {
      await _pump(tester, <String>['a@x.com', 'b@x.com']);
      expect(find.text('Se enviará a: a@x.com, b@x.com'), findsOneWidget);
      expect(find.text('Agregar otro'), findsOneWidget);
      expect(find.text('Correo adicional'), findsNothing);
    });

    testWidgets('"Agregar otro" revela el campo "Correo adicional"', (tester) async {
      await _pump(tester, <String>['a@x.com']);
      await tester.tap(find.text('Agregar otro'));
      await tester.pump();
      expect(find.text('Correo adicional'), findsOneWidget);
      expect(find.text('Agregar otro'), findsNothing);
    });
  });

  group('tarjeta sin correos registrados', () {
    testWidgets('muestra "Sin correos registrados" y el campo directo', (tester) async {
      await _pump(tester, <String>[]);
      expect(find.text('Sin correos registrados'), findsOneWidget);
      expect(find.text('Correo adicional'), findsOneWidget);
      expect(find.text('Agregar otro'), findsNothing);
    });
  });

  group('validación del correo adicional', () {
    testWidgets('vacío es válido y value es null (el campo es opcional)', (tester) async {
      final ExtraEmailController c = await _pump(tester, <String>[]);
      await tester.tap(find.text('validar'));
      await tester.pump();
      expect(find.text('Correo inválido'), findsNothing);
      expect(c.value, isNull);
    });

    testWidgets('formato inválido: muestra "Correo inválido" y no deja continuar', (tester) async {
      final ExtraEmailController c = await _pump(tester, <String>['a@x.com']);
      // El campo está oculto; validate() lo revela aunque el usuario no lo abriera.
      c.text.text = 'no-es-correo';
      late bool ok;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Column(
              children: <Widget>[
                EmailDeliveryBody(contactEmails: const <String>['a@x.com'], controller: c),
                TextButton(
                  onPressed: () => ok = c.validate(context),
                  child: const Text('validar'),
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.tap(find.text('validar'));
      await tester.pump();
      await tester.pump();
      expect(ok, isFalse);
      expect(c.value, isNull, reason: 'un valor inválido nunca se manda');
      expect(find.text('Correo inválido'), findsWidgets); // campo + SnackBar
      expect(find.text('Correo adicional'), findsOneWidget);
    });

    testWidgets('correo válido: validate() pasa y value lo devuelve recortado', (tester) async {
      final ExtraEmailController c = await _pump(tester, <String>[]);
      await tester.enterText(find.byType(TextFormField), '  firma@cliente.com ');
      await tester.tap(find.text('validar'));
      await tester.pump();
      expect(find.text('Correo inválido'), findsNothing);
      expect(c.value, 'firma@cliente.com');
    });
  });
}
