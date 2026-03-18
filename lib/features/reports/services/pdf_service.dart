import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/services.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  static const List<String> _checklistItems = <String>[
    'Mantenimiento general',
    'Calibración sensores',
    'Rodillo dañado',
    'Cabezal dañado',
    'Sensor ribbon dañado',
    'Sensor papel dañado',
    'Pruebas',
    'Otros',
  ];

  static const List<String> _monthNames = <String>[
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} '
        '${_monthNames[date.month - 1]} ${date.year}';
  }

  static Future<Uint8List> generateReportPdf({
    required String reportId,
    required AppDatabase database,
  }) async {
    // ── Cargar datos base ────────────────────────────────────────────────────
    final Report? report = await (database.select(database.reports)
          ..where((r) => r.id.equals(reportId)))
        .getSingleOrNull();

    if (report == null) {
      throw Exception('Reporte no encontrado: $reportId');
    }

    final Printer? printer = await (database.select(database.printers)
          ..where((p) => p.id.equals(report.printerId)))
        .getSingleOrNull();

    Client? client;
    CatalogModel? catalogModel;
    Plant? plant;
    Area? area;

    if (printer != null) {
      client = await (database.select(database.clients)
            ..where((c) => c.id.equals(printer.clientId)))
          .getSingleOrNull();
      catalogModel = await (database.select(database.catalogModels)
            ..where((m) => m.id.equals(printer.modelId)))
          .getSingleOrNull();
      plant = await (database.select(database.plants)
            ..where((p) => p.id.equals(printer.plantId)))
          .getSingleOrNull();
      area = await (database.select(database.areas)
            ..where((a) => a.id.equals(printer.areaId)))
          .getSingleOrNull();
    }

    final User? technician = await (database.select(database.users)
          ..where((u) => u.id.equals(report.techId)))
        .getSingleOrNull();

    // Tipo de etiqueta
    CatalogLabelType? catalogLabelType;
    if (report.labelTypeId != null) {
      catalogLabelType = await (database.select(database.catalogLabelTypes)
            ..where((l) => l.id.equals(report.labelTypeId!)))
          .getSingleOrNull();
    }

    final String technicianName = technician?.name ?? 'No especificado';

    // ── Logo ────────────────────────────────────────────────────────────────
    pw.ImageProvider? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('lib/img/logo_smp.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    // ── Firma del cliente ───────────────────────────────────────────────────
    pw.ImageProvider? clientSignatureImage;
    final String? sigPath = report.signatureImagePath;
    if (sigPath != null && io.File(sigPath).existsSync()) {
      try {
        final Uint8List sigBytes = await io.File(sigPath).readAsBytes();
        clientSignatureImage = pw.MemoryImage(sigBytes);
      } catch (_) {}
    }

    // ── Firma del técnico ───────────────────────────────────────────────────
    pw.ImageProvider? techSignatureImage;
    final String? techSigPath = technician?.signaturePath;
    if (techSigPath != null && io.File(techSigPath).existsSync()) {
      try {
        final Uint8List techSigBytes = await io.File(techSigPath).readAsBytes();
        techSignatureImage = pw.MemoryImage(techSigBytes);
      } catch (_) {}
    }

    // ── Fotos del reporte ───────────────────────────────────────────────────
    final List<String> rawPaths = List<String>.from(
      (jsonDecode(report.photoPaths) as List<dynamic>),
    );
    final List<pw.ImageProvider> photoImages = <pw.ImageProvider>[];
    for (final String path in rawPaths) {
      if (io.File(path).existsSync()) {
        try {
          final Uint8List bytes = await io.File(path).readAsBytes();
          photoImages.add(pw.MemoryImage(bytes));
        } catch (_) {}
      }
    }

    // ── Checklist ───────────────────────────────────────────────────────────
    final Map<String, dynamic> checkboxes = report.technicalCheckboxes;

    // ── Construir PDF ────────────────────────────────────────────────────────
    final pw.Document pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context ctx) =>
            _buildHeader(ctx, logoImage, report),
        footer: (pw.Context ctx) => _buildFooter(ctx),
        build: (pw.Context ctx) {
          return <pw.Widget>[
            // ── Información del cliente  |  Datos de la impresora ────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Expanded(
                  child: _buildClientInfoSection(client, plant, area),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: _buildPrinterSection(
                    printer,
                    catalogModel,
                    report,
                    catalogLabelType,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            _buildChecklistSection(checkboxes),
            if ((report.notes ?? '').isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 16),
              _buildNotesSection(report.notes!),
            ],
            pw.SizedBox(height: 16),
            _buildSignaturesSection(
              signerName: report.signatureName,
              signerRole: report.signatureRole,
              clientSignatureImage: clientSignatureImage,
              technicianName: technicianName,
              techSignatureImage: techSignatureImage,
            ),
            // ── Página de fotos ──────────────────────────────────────────
            if (photoImages.isNotEmpty) ...<pw.Widget>[
              pw.NewPage(),
              _buildPhotosSection(photoImages),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  // Columna derecha: título + código (azul) + tipo de servicio + fecha
  static pw.Widget _buildHeader(
    pw.Context ctx,
    pw.ImageProvider? logoImage,
    Report report,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey300),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          // Logo
          if (logoImage != null)
            pw.Image(logoImage, width: 60, height: 60)
          else
            pw.Container(
              width: 60,
              height: 60,
              color: PdfColors.blueGrey100,
              child: pw.Center(
                child: pw.Text(
                  'SMP',
                  style: pw.TextStyle(
                    color: PdfColors.blueGrey700,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          pw.SizedBox(width: 16),
          // Título + código + tipo + fecha
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: <pw.Widget>[
                pw.Text(
                  'REPORTE DE SERVICIO TÉCNICO',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  report.code ??
                      'R-${report.id.substring(0, 8).toUpperCase()}',
                  style: pw.TextStyle(
                    fontSize: 13,
                    color: PdfColors.blue700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  report.serviceType,
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.blueGrey600,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  _formatDate(report.serviceDate),
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.blueGrey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.blueGrey200),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            'Documento generado por Servicios Main PC App',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey400,
            ),
          ),
          pw.Text(
            'Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.blue700, width: 3),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey800,
        ),
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              '$label:',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.blueGrey600,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sección: INFORMACIÓN DEL CLIENTE ────────────────────────────────────────
  static pw.Widget _buildClientInfoSection(
    Client? client,
    Plant? plant,
    Area? area,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _buildSectionTitle('INFORMACIÓN DEL CLIENTE'),
        _buildInfoRow('Nombre', client?.name ?? '—'),
        _buildInfoRow('RFC', client?.rfc ?? '—'),
        _buildInfoRow('Dirección', client?.address ?? '—'),
        _buildInfoRow('Planta', plant?.name ?? '—'),
        _buildInfoRow('Área', area?.name ?? '—'),
      ],
    );
  }

  // ── Sección: DATOS DE LA IMPRESORA ──────────────────────────────────────────
  static pw.Widget _buildPrinterSection(
    Printer? printer,
    CatalogModel? catalogModel,
    Report report,
    CatalogLabelType? catalogLabelType,
  ) {
    final String serialNumber = printer?.serialNumber ?? '—';
    final String modelName = catalogModel != null
        ? '${catalogModel.brand} ${catalogModel.modelName} '
            '${catalogModel.dpi}dpi'
        : '—';
    final String printerCode = printer == null
        ? '—'
        : (printer.code ?? printer.id.substring(0, 8));
    final String counter = '${report.linearInchesCounter} pulg.';
    final String darkness =
        report.darknessLevel != null ? '${report.darknessLevel}' : '—';
    final String labelType = catalogLabelType?.name ?? '—';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _buildSectionTitle('DATOS DE LA IMPRESORA'),
        _buildInfoRow('Código', printerCode),
        _buildInfoRow('Serie', 'S/N: $serialNumber'),
        _buildInfoRow('Modelo', modelName),
        _buildInfoRow('Contador', counter),
        _buildInfoRow('Temperatura', darkness),
        _buildInfoRow('Etiqueta', labelType),
      ],
    );
  }

  // ── Sección: CHECKLIST ───────────────────────────────────────────────────────
  static pw.Widget _buildChecklistSection(Map<String, dynamic> checkboxes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _buildSectionTitle('LISTA TÉCNICA DE VERIFICACIÓN'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey200),
          columnWidths: <int, pw.TableColumnWidth>{
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
          },
          children: <pw.TableRow>[
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.blueGrey100),
              children: <pw.Widget>[
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Elemento',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Estado',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
            ..._checklistItems.map((String item) {
              final bool checked = checkboxes[item] == true;
              return pw.TableRow(
                children: <pw.Widget>[
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      item,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        color: checked
                            ? PdfColors.green100
                            : PdfColors.blueGrey50,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(3),
                        ),
                      ),
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: pw.Text(
                        checked ? 'Si' : 'No',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: checked
                              ? PdfColors.green800
                              : PdfColors.blueGrey500,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── Sección: NOTAS ──────────────────────────────────────────────────────────
  static pw.Widget _buildNotesSection(String notes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _buildSectionTitle('NOTAS DEL SERVICIO'),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey200),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(notes, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  // ── Sección: FIRMAS (técnico izquierda | cliente derecha) ───────────────────
  static pw.Widget _buildSignaturesSection({
    required String? signerName,
    required String? signerRole,
    required pw.ImageProvider? clientSignatureImage,
    required String technicianName,
    required pw.ImageProvider? techSignatureImage,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          child: _buildSignatureBox(
            title: 'FIRMA DEL TÉCNICO',
            name: technicianName,
            role: null, // añade spacer para alinear con cargo del cliente
            signatureImage: techSignatureImage,
            emptyLabel: 'Pendiente',
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: _buildSignatureBox(
            title: 'FIRMA DE CONFORMIDAD DEL CLIENTE',
            name: signerName ?? 'No especificado',
            role: signerRole ?? 'No especificado',
            signatureImage: clientSignatureImage,
            emptyLabel: 'Sin firma',
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSignatureBox({
    required String title,
    required String name,
    required String? role,
    required pw.ImageProvider? signatureImage,
    required String emptyLabel,
  }) {
    // Calcula altura de una fila de info para el spacer de alineación
    const double infoRowHeight = 16;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _buildSectionTitle(title),
        _buildInfoRow('Nombre', name),
        // Si no tiene cargo (técnico), agrega spacer equivalente a una fila
        // para que el recuadro de firma quede alineado con el del cliente
        if (role == null)
          pw.SizedBox(height: infoRowHeight)
        else
          _buildInfoRow('Cargo', role),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 80,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey200),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: signatureImage != null
              ? pw.Center(
                  child: pw.Image(
                    signatureImage,
                    height: 70,
                    fit: pw.BoxFit.contain,
                  ),
                )
              : pw.Center(
                  child: pw.Text(
                    emptyLabel,
                    style: const pw.TextStyle(
                      color: PdfColors.blueGrey300,
                      fontSize: 10,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Sección: EVIDENCIA FOTOGRÁFICA ──────────────────────────────────────────
  static pw.Widget _buildPhotosSection(
    List<pw.ImageProvider> images,
  ) {
    // Agrupa de 2 en 2 para grid de 2 columnas
    final List<List<pw.ImageProvider>> rows = <List<pw.ImageProvider>>[];
    for (int i = 0; i < images.length; i += 2) {
      rows.add(images.sublist(i, i + 2 > images.length ? images.length : i + 2));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _buildSectionTitle('EVIDENCIA FOTOGRÁFICA'),
        pw.SizedBox(height: 8),
        ...rows.map((List<pw.ImageProvider> pair) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Expanded(child: _buildPhotoCell(pair[0])),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pair.length > 1
                      ? _buildPhotoCell(pair[1])
                      : pw.SizedBox(), // celda vacía si es impar
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildPhotoCell(pw.ImageProvider image) {
    return pw.Container(
      height: 180,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 4,
        verticalRadius: 4,
        child: pw.Image(image, fit: pw.BoxFit.contain),
      ),
    );
  }
}
