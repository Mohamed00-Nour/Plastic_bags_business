class AppConstants {
  AppConstants._();

  static const String appName = 'Mr.John\'s Dashboard';
  static const String appVersion = '1.0.0';

  // Firestore collection names
  static const String usersCollection = 'users';
  static const String shopsCollection = 'shops';
  static const String suppliersCollection = 'suppliers';
  static const String productsCollection = 'products';
  static const String ordersCollection = 'orders';
  static const String transactionsCollection = 'transactions';
  static const String stockLogsCollection = 'stock_logs';

  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
}
