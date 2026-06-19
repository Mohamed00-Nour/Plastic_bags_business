import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:store_manager/core/bloc/locale_cubit.dart';
import 'package:store_manager/core/bloc/theme_cubit.dart';
import 'package:store_manager/core/theme/app_theme.dart';
import 'package:store_manager/core/widgets/admin_shell.dart';
import 'package:store_manager/data/models/user_model.dart';
import 'package:store_manager/data/repositories/auth_repository.dart';
import 'package:store_manager/data/repositories/shop_repository.dart';
import 'package:store_manager/data/repositories/supplier_repository.dart';
import 'package:store_manager/data/repositories/product_repository.dart';
import 'package:store_manager/data/repositories/order_repository.dart';
import 'package:store_manager/data/repositories/transaction_repository.dart';
import 'package:store_manager/data/repositories/stock_log_repository.dart';
import 'package:store_manager/data/repositories/user_repository.dart';
import 'package:store_manager/features/auth/bloc/auth_bloc.dart';
import 'package:store_manager/features/auth/bloc/auth_event.dart';
import 'package:store_manager/features/auth/bloc/auth_state.dart';
import 'package:store_manager/features/auth/presentation/screens/login_screen.dart';
import 'package:store_manager/features/auth/presentation/screens/admin_setup_screen.dart';
import 'package:store_manager/features/shop_app/presentation/screens/shop_app_shell.dart';
import 'package:store_manager/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:store_manager/features/products/bloc/product_bloc_new.dart';
import 'package:store_manager/features/shops/bloc/shop_bloc.dart';
import 'package:store_manager/features/suppliers/bloc/supplier_bloc_new.dart';
import 'package:store_manager/features/orders/bloc/order_bloc.dart';
import 'package:store_manager/features/transactions/bloc/transaction_bloc.dart';
import 'package:store_manager/features/reports/bloc/report_bloc_new.dart';
import 'package:store_manager/features/users/bloc/user_bloc.dart';
import 'package:store_manager/data/repositories/raw_material_repository.dart';
import 'package:store_manager/data/repositories/manufacturing_mix_repository.dart';
import 'package:store_manager/data/repositories/production_run_repository.dart';
import 'package:store_manager/data/repositories/waste_machine_repository.dart';
import 'package:store_manager/data/repositories/waste_processing_repository.dart';
import 'package:store_manager/data/repositories/manufacturing_expense_repository.dart';
import 'package:store_manager/data/repositories/material_supplier_repository.dart';
import 'package:store_manager/data/repositories/material_stock_log_repository.dart';
import 'package:store_manager/data/repositories/damaged_inventory_repository.dart';
import 'package:store_manager/features/manufacturing/bloc/raw_material_bloc.dart';
import 'package:store_manager/features/manufacturing/bloc/raw_material_event.dart';
import 'package:store_manager/features/manufacturing/bloc/manufacturing_mix_bloc.dart';
import 'package:store_manager/features/manufacturing/bloc/manufacturing_mix_event.dart';
import 'package:store_manager/features/manufacturing/bloc/production_run_bloc.dart';
import 'package:store_manager/features/manufacturing/bloc/production_run_event.dart';
import 'package:store_manager/features/manufacturing/bloc/waste_processing_bloc.dart';
import 'package:store_manager/features/manufacturing/bloc/waste_processing_event.dart';
import 'package:store_manager/features/manufacturing/bloc/manufacturing_expense_bloc.dart';
import 'package:store_manager/features/manufacturing/bloc/manufacturing_expense_event.dart';
import 'package:store_manager/features/manufacturing/bloc/material_supplier_bloc.dart';
import 'package:store_manager/features/manufacturing/bloc/material_supplier_event.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:store_manager/core/services/firebase_desktop_init.dart';
import 'package:store_manager/core/services/notification_service.dart';
import 'firebase_options.dart';

bool get _isMobilePlatform =>
    !kIsWeb &&
    (Platform.isAndroid || Platform.isIOS);

/// Must be a top-level function — required by FCM for background messages.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureFirebaseAuthForWindows();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await configureFirestoreForWindows();
  if (_isMobilePlatform) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await NotificationService.init();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Repositories
    final authRepository = AuthRepository();
    final shopRepository = ShopRepository();
    final supplierRepository = SupplierRepository();
    final productRepository = ProductRepository();
    final orderRepository = OrderRepository();
    final transactionRepository = TransactionRepository();
    final stockLogRepository = StockLogRepository();
    final userRepository = UserRepository();
    final rawMaterialRepository = RawMaterialRepository();
    final manufacturingMixRepository = ManufacturingMixRepository();
    final productionRunRepository = ProductionRunRepository();
    final wasteMachineRepository = WasteMachineRepository();
    final wasteProcessingRepository = WasteProcessingRepository();
    final manufacturingExpenseRepository = ManufacturingExpenseRepository();
    final materialSupplierRepository = MaterialSupplierRepository();
    final materialStockLogRepository = MaterialStockLogRepository();
    final damagedInventoryRepository = DamagedInventoryRepository();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: shopRepository),
        RepositoryProvider.value(value: supplierRepository),
        RepositoryProvider.value(value: productRepository),
        RepositoryProvider.value(value: orderRepository),
        RepositoryProvider.value(value: transactionRepository),
        RepositoryProvider.value(value: stockLogRepository),
        RepositoryProvider.value(value: userRepository),
        RepositoryProvider.value(value: rawMaterialRepository),
        RepositoryProvider.value(value: manufacturingMixRepository),
        RepositoryProvider.value(value: productionRunRepository),
        RepositoryProvider.value(value: wasteMachineRepository),
        RepositoryProvider.value(value: wasteProcessingRepository),
        RepositoryProvider.value(value: manufacturingExpenseRepository),
        RepositoryProvider.value(value: materialSupplierRepository),
        RepositoryProvider.value(value: materialStockLogRepository),
        RepositoryProvider.value(value: damagedInventoryRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<LocaleCubit>(
            create: (_) => LocaleCubit(),
          ),
          BlocProvider<ThemeCubit>(
            create: (_) => ThemeCubit(),
          ),
          BlocProvider<AuthBloc>(
            create: (_) => AuthBloc(authRepository: authRepository)
              ..add(AuthCheckRequested()),
          ),
          BlocProvider<DashboardBloc>(
            create: (_) => DashboardBloc(),
          ),
          BlocProvider<ProductBloc>(
            create: (_) => ProductBloc(
              productRepository: productRepository,
              stockLogRepository: stockLogRepository,
            ),
          ),
          BlocProvider<ShopBloc>(
            create: (_) => ShopBloc(
              shopRepository: shopRepository,
              transactionRepository: transactionRepository,
              authRepository: authRepository,
            ),
          ),
          BlocProvider<SupplierBloc>(
            create: (_) => SupplierBloc(
              supplierRepository: supplierRepository,
            ),
          ),
          BlocProvider<OrderBloc>(
            create: (_) => OrderBloc(
              orderRepository: orderRepository,
              productRepository: productRepository,
              shopRepository: shopRepository,
              transactionRepository: transactionRepository,
              stockLogRepository: stockLogRepository,
            ),
          ),
          BlocProvider<TransactionBloc>(
            create: (_) => TransactionBloc(
              transactionRepository: transactionRepository,
            ),
          ),
          BlocProvider<ReportBloc>(
            create: (_) => ReportBloc(
              orderRepository: orderRepository,
              transactionRepository: transactionRepository,
            ),
          ),
          BlocProvider<UserManagementBloc>(
            create: (_) => UserManagementBloc(
              userRepository: userRepository,
              authRepository: authRepository,
            ),
          ),
          BlocProvider<RawMaterialBloc>(
            create: (_) => RawMaterialBloc(
              repository: rawMaterialRepository,
              stockLogRepository: materialStockLogRepository,
            ),
          ),
          BlocProvider<ManufacturingMixBloc>(
            create: (_) => ManufacturingMixBloc(
              repository: manufacturingMixRepository,
              materialRepository: rawMaterialRepository,
            ),
          ),
          BlocProvider<ProductionRunBloc>(
            create: (_) => ProductionRunBloc(
              repository: productionRunRepository,
              damagedRepository: damagedInventoryRepository,
              productRepository: productRepository,
              stockLogRepository: stockLogRepository,
            ),
          ),
          BlocProvider<MaterialSupplierBloc>(
            create: (_) => MaterialSupplierBloc(
              repository: materialSupplierRepository,
            ),
          ),
          BlocProvider<WasteProcessingBloc>(
            create: (_) => WasteProcessingBloc(
              machineRepository: wasteMachineRepository,
              processingRepository: wasteProcessingRepository,
              materialRepository: rawMaterialRepository,
              supplierRepository: materialSupplierRepository,
              damagedRepository: damagedInventoryRepository,
            ),
          ),
          BlocProvider<ManufacturingExpenseBloc>(
            create: (_) => ManufacturingExpenseBloc(
              repository: manufacturingExpenseRepository,
            ),
          ),
        ],
        child: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) {
            return BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, themeMode) {
            return MaterialApp(
              title: 'Mr.John',
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en'),
                Locale('ar'),
              ],
              locale: locale,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              home: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state is AuthAuthenticated) {
                    // Route based on role
                    if (state.user.role == UserRole.admin) {
                      return const AdminShell();
                    } else {
                      return const ShopAppShell();
                    }
                  }
                  if (state is AdminSetupRequired) {
                    return const AdminSetupScreen();
                  }
                  if (state is AuthUnauthenticated || state is AuthError) {
                    return const LoginScreen();
                  }
                  // AuthInitial / AuthLoading
                  return const _SplashScreen();
                },
              ),
            );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store, size: 72, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)?.splashTitle ?? 'Mr.John\'s dashboard',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}