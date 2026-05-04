import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/shop_model_new.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import 'shop_event.dart';
import 'shop_state.dart';

class ShopBloc extends Bloc<ShopEvent, ShopState> {
  final ShopRepository _shopRepository;
  StreamSubscription? _subscription;
  List<ShopModel> _allShops = [];

  final AuthRepository _authRepository;

  ShopBloc({
    required ShopRepository shopRepository,
    required TransactionRepository transactionRepository,
    required AuthRepository authRepository,
  }) : _shopRepository = shopRepository,
       _authRepository = authRepository,
       super(ShopInitial()) {
    on<ShopLoadRequested>(_onLoad);
    on<ShopAddRequested>(_onAdd);
    on<ShopAddWithAccountRequested>(_onAddWithAccount);
    on<ShopUpdateRequested>(_onUpdate);
    on<ShopDeleteRequested>(_onDelete);
    on<ShopSearchRequested>(_onSearch);
  }

  Future<void> _onLoad(ShopLoadRequested event, Emitter<ShopState> emit) async {
    emit(ShopLoading());
    await _subscription?.cancel();
    _subscription = _shopRepository.getShops().listen(
      (shops) {
        _allShops = shops;
        if (!isClosed) {
          add(const ShopSearchRequested(query: ''));
        }
      },
      onError: (error) {
        if (!isClosed) {
          emit(ShopError(message: error.toString()));
        }
      },
    );
  }

  void _onSearch(ShopSearchRequested event, Emitter<ShopState> emit) {
    final query = event.query.toLowerCase();
    final filtered =
        query.isEmpty
            ? _allShops
            : _allShops
                .where(
                  (s) =>
                      s.name.toLowerCase().contains(query) ||
                      s.phone.contains(query),
                )
                .toList();
    emit(
      ShopLoaded(
        shops: _allShops,
        filteredShops: filtered,
        searchQuery: event.query,
      ),
    );
  }

  Future<void> _onAdd(ShopAddRequested event, Emitter<ShopState> emit) async {
    try {
      await _shopRepository.addShop(event.shop);
      emit(const ShopOperationSuccess(message: 'Shop added successfully'));
    } catch (e) {
      emit(ShopError(message: e.toString()));
    }
  }

  Future<void> _onAddWithAccount(
    ShopAddWithAccountRequested event,
    Emitter<ShopState> emit,
  ) async {
    try {
      // Create the shop with credentials stored on the document
      final shopWithCreds = event.shop.copyWith(
        loginEmail: event.email,
        loginPassword: event.password,
      );
      await _shopRepository.addShop(shopWithCreds);

      // Create the login credentials in Auth without duplicating in users collection
      await _authRepository.createShopAuthAccount(
        email: event.email,
        password: event.password,
      );

      emit(
        const ShopOperationSuccess(
          message: 'Shop and login account created successfully',
        ),
      );
    } catch (e) {
      emit(ShopError(message: e.toString()));
    }
  }

  Future<void> _onUpdate(
    ShopUpdateRequested event,
    Emitter<ShopState> emit,
  ) async {
    try {
      await _shopRepository.updateShop(event.shop);
      emit(const ShopOperationSuccess(message: 'Shop updated successfully'));
    } catch (e) {
      emit(ShopError(message: e.toString()));
    }
  }

  Future<void> _onDelete(
    ShopDeleteRequested event,
    Emitter<ShopState> emit,
  ) async {
    try {
      await _shopRepository.deleteShop(event.shopId);
      emit(const ShopOperationSuccess(message: 'Shop deleted successfully'));
    } catch (e) {
      emit(ShopError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
