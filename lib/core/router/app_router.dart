import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/router/router_notifier.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/presentation/login_screen.dart';
import 'package:industrial_service_reports/features/clients/presentation/add_client_screen.dart';
import 'package:industrial_service_reports/features/clients/presentation/client_detail_screen.dart';
import 'package:industrial_service_reports/features/clients/presentation/client_list_screen.dart';
import 'package:industrial_service_reports/features/dashboard/presentation/main_dashboard_screen.dart';
import 'package:industrial_service_reports/features/policies/presentation/policy_dashboard_screen.dart';
import 'package:industrial_service_reports/features/printers/presentation/printer_confirmation_screen.dart';
import 'package:industrial_service_reports/features/printers/presentation/printer_detail_screen.dart';
import 'package:industrial_service_reports/features/printers/presentation/printer_inventory_screen.dart';
import 'package:industrial_service_reports/features/printers/presentation/quick_add_printer_screen.dart';
import 'package:industrial_service_reports/features/printers/presentation/service_history_screen.dart';
import 'package:industrial_service_reports/features/profile/presentation/technician_profile_screen.dart';
import 'package:industrial_service_reports/features/qr_scanner/presentation/qr_scanner_screen.dart';
import 'package:industrial_service_reports/features/reports/presentation/express_capture_screen.dart';
import 'package:industrial_service_reports/features/reports/presentation/report_summary_screen.dart';
import 'package:industrial_service_reports/features/signature/presentation/signature_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final RouterNotifier notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        name: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: AppRoutes.dashboard,
        builder: (_, __) => const MainDashboardScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: AppRoutes.profile,
        builder: (_, __) => const TechnicianProfileScreen(),
      ),
      GoRoute(
        path: '/clients',
        name: AppRoutes.clients,
        builder: (_, __) => ClientListScreen(database: localDatabase),
      ),
      GoRoute(
        path: '/clients/add',
        name: AppRoutes.addClient,
        builder: (_, state) {
          final AddClientArgs? args = state.extra as AddClientArgs?;
          return AddClientScreen(
            database: localDatabase,
            client: args?.client,
          );
        },
      ),
      GoRoute(
        path: '/clients/detail',
        name: AppRoutes.clientDetail,
        builder: (_, state) {
          final ClientDetailArgs args = state.extra! as ClientDetailArgs;
          return ClientDetailScreen(
            database: localDatabase,
            client: args.client,
          );
        },
      ),
      GoRoute(
        path: '/qr-scanner',
        name: AppRoutes.qrScanner,
        builder: (_, __) => QrScannerScreen(database: localDatabase),
      ),
      GoRoute(
        path: '/printer-confirm',
        name: AppRoutes.printerConfirm,
        builder: (_, state) {
          final PrinterConfirmArgs args = state.extra! as PrinterConfirmArgs;
          return PrinterConfirmationScreen(printer: args.printer);
        },
      ),
      GoRoute(
        path: '/printer/:serialNumber',
        name: AppRoutes.printerDetail,
        builder: (_, state) {
          final PrinterDetailArgs args = state.extra! as PrinterDetailArgs;
          return PrinterDetailScreen(
            serialNumber: args.serialNumber,
            model: args.model,
            client: args.client,
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'history',
            name: AppRoutes.serviceHistory,
            builder: (_, state) {
              final ServiceHistoryArgs args =
                  state.extra! as ServiceHistoryArgs;
              final String printerId =
                  state.pathParameters['serialNumber'] ?? '';
              return ServiceHistoryScreen(
                printerId: printerId,
                model: args.model,
                serialNumber: args.serialNumber,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/printer-inventory',
        name: AppRoutes.printerInventory,
        builder: (_, __) =>
            PrinterInventoryScreen(database: localDatabase),
      ),
      GoRoute(
        path: '/printer-add',
        name: AppRoutes.quickAddPrinter,
        builder: (_, __) => QuickAddPrinterScreen(database: localDatabase),
      ),
      GoRoute(
        path: '/capture',
        name: AppRoutes.capture,
        builder: (_, state) {
          final CaptureArgs? args = state.extra as CaptureArgs?;
          return ExpressCaptureScreen(printerId: args?.printerId);
        },
      ),
      GoRoute(
        path: '/report-summary',
        name: AppRoutes.reportSummary,
        builder: (_, __) => const ReportSummaryScreen(),
      ),
      GoRoute(
        path: '/signature',
        name: AppRoutes.signature,
        builder: (_, __) => const SignatureScreen(),
      ),
      GoRoute(
        path: '/policies',
        name: AppRoutes.policies,
        builder: (_, __) => const PolicyDashboardScreen(),
      ),
    ],
  );
});
