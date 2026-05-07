import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/core/router/app_router.dart';
import 'package:industrial_service_reports/core/theme/app_theme.dart';
import 'package:industrial_service_reports/features/sync/providers/startup_sync_provider.dart';

class ServiceReportsApp extends ConsumerStatefulWidget {
  const ServiceReportsApp({super.key});

  @override
  ConsumerState<ServiceReportsApp> createState() => _ServiceReportsAppState();
}

class _ServiceReportsAppState extends ConsumerState<ServiceReportsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-ejecuta el sync cada vez que la app vuelve al primer plano.
  /// La guard interna de runAutoSync() evita ejecuciones concurrentes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      ref.read(startupSyncProvider.notifier).runAutoSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Industrial Service Reports',
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkIndustrial,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
