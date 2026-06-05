import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'config/config_store.dart';
import 'services/vendor_registry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ConfigStore.instance.init();

  VendorRegistry.instance.init();

  runApp(const ProviderScope(child: SchedulifyApp()));
}

class SchedulifyApp extends ConsumerWidget {
  const SchedulifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Schedulify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
