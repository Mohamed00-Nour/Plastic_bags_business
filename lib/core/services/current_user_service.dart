class CurrentUserService {
  static final instance = CurrentUserService._();
  CurrentUserService._();

  String _userId = '';
  String _userName = '';

  String get userId => _userId;
  String get userName => _userName;

  void set(String userId, String userName) {
    _userId = userId;
    _userName = userName;
  }

  void clear() {
    _userId = '';
    _userName = '';
  }
}
