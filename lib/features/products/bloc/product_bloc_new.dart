import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/product_model_new.dart';
import '../../../data/models/stock_log_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_log_repository.dart';
import 'product_event.dart';
import 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository _productRepository;
  final StockLogRepository _stockLogRepository;
  StreamSubscription? _subscription;
  List<ProductModel> _allProducts = [];

  ProductBloc({
    required ProductRepository productRepository,
    required StockLogRepository stockLogRepository,
  })  : _productRepository = productRepository,
        _stockLogRepository = stockLogRepository,
        super(ProductInitial()) {
    on<ProductLoadRequested>(_onLoad);
    on<ProductAddRequested>(_onAdd);
    on<ProductUpdateRequested>(_onUpdate);
    on<ProductDeleteRequested>(_onDelete);
    on<ProductStockIncreased>(_onStockIncrease);
    on<ProductStockDecreased>(_onStockDecrease);
    on<ProductSearchRequested>(_onSearch);
  }

  Future<void> _onLoad(
    ProductLoadRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(ProductLoading());
    await _subscription?.cancel();
    _subscription = _productRepository.getProducts().listen(
      (products) {
        _allProducts = products;
        if (!isClosed) {
          add(const ProductSearchRequested(query: ''));
        }
      },
      onError: (error) {
        if (!isClosed) {
          emit(ProductError(message: error.toString()));
        }
      },
    );
  }

  void _onSearch(
    ProductSearchRequested event,
    Emitter<ProductState> emit,
  ) {
    final query = event.query.toLowerCase();
    final filtered = query.isEmpty
        ? _allProducts
        : _allProducts
            .where((p) =>
                p.name.toLowerCase().contains(query) ||
                p.size.toLowerCase().contains(query) ||
                (p.supplierName?.toLowerCase().contains(query) ?? false))
            .toList();
    emit(ProductLoaded(
      products: _allProducts,
      filteredProducts: filtered,
      searchQuery: event.query,
    ));
  }

  Future<void> _onAdd(
    ProductAddRequested event,
    Emitter<ProductState> emit,
  ) async {
    try {
      await _productRepository.addProduct(event.product);
      emit(const ProductOperationSuccess(message: 'Product added successfully'));
    } catch (e) {
      emit(ProductError(message: e.toString()));
    }
  }

  Future<void> _onUpdate(
    ProductUpdateRequested event,
    Emitter<ProductState> emit,
  ) async {
    try {
      await _productRepository.updateProduct(event.product);
      emit(const ProductOperationSuccess(
          message: 'Product updated successfully'));
    } catch (e) {
      emit(ProductError(message: e.toString()));
    }
  }

  Future<void> _onDelete(
    ProductDeleteRequested event,
    Emitter<ProductState> emit,
  ) async {
    try {
      await _productRepository.deleteProduct(event.productId);
      emit(const ProductOperationSuccess(
          message: 'Product deleted successfully'));
    } catch (e) {
      emit(ProductError(message: e.toString()));
    }
  }

  Future<void> _onStockIncrease(
    ProductStockIncreased event,
    Emitter<ProductState> emit,
  ) async {
    try {
      final product = await _productRepository.getProduct(event.productId);
      final stockBefore = product.stockQuantity;
      await _productRepository.incrementStock(event.productId, event.amount);

      await _stockLogRepository.addLog(StockLogModel(
        id: const Uuid().v4(),
        productId: event.productId,
        productName: product.name,
        type: StockMovementType.incoming,
        quantity: event.amount,
        stockBefore: stockBefore,
        stockAfter: stockBefore + event.amount,
        note: event.note,
        supplierId: event.supplierId,
        supplierName: event.supplierName,
        createdBy: 'admin',
        createdAt: DateTime.now(),
      ));
      emit(const ProductOperationSuccess(
          message: 'Stock increased successfully'));
    } catch (e) {
      emit(ProductError(message: e.toString()));
    }
  }

  Future<void> _onStockDecrease(
    ProductStockDecreased event,
    Emitter<ProductState> emit,
  ) async {
    try {
      final product = await _productRepository.getProduct(event.productId);
      final stockBefore = product.stockQuantity;
      await _productRepository.decrementStock(event.productId, event.amount);

      await _stockLogRepository.addLog(StockLogModel(
        id: const Uuid().v4(),
        productId: event.productId,
        productName: product.name,
        type: StockMovementType.outgoing,
        quantity: event.amount,
        stockBefore: stockBefore,
        stockAfter: stockBefore - event.amount,
        note: event.note,
        createdBy: 'admin',
        createdAt: DateTime.now(),
      ));
      emit(const ProductOperationSuccess(
          message: 'Stock decreased successfully'));
    } catch (e) {
      emit(ProductError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
