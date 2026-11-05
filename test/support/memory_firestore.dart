// SDK interface fakes are limited to tests; production uses the real plugin.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal Firestore test double for invoice transactions. Rejects reads after
/// writes, and commits transaction writes only after the callback succeeds.
class MemoryFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  int _nextId = 0;
  final _changes = StreamController<void>.broadcast();

  /// Re-emits every live `snapshots()` stream after a committed write.
  void notifyChanged() => _changes.add(null);

  Stream<T> _watch<T>(Future<T> Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? changes;
    void emit() => read().then((value) {
      if (!controller.isClosed) controller.add(value);
    });
    controller = StreamController<T>(
      onListen: () {
        changes = _changes.stream.listen((_) => emit());
        emit();
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction(this);
    final result = await transactionHandler(transaction);
    for (final write in transaction.writes) {
      write();
    }
    if (transaction.writes.isNotEmpty) notifyChanged();
    return result;
  }

  @override
  WriteBatch batch() => _Batch(this);
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final MemoryFirestore store;
  @override
  final String path;
  final Map<String, Object?> filters;

  _Collection(this.store, this.path, [this.filters = const {}]);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(store, '${this.path}/${path ?? 'auto-${store._nextId++}'}');

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _Collection(store, path, {...filters, field.toString(): isEqualTo});

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final docs = store.documents.entries.where((entry) {
      return entry.key.startsWith('$path/') &&
          entry.key.split('/').length == path.split('/').length + 1 &&
          filters.entries.every(
            (filter) => entry.value[filter.key] == filter.value,
          );
    });
    return _QuerySnapshot([
      for (final entry in docs)
        _Snapshot(_Document(store, entry.key), Map.of(entry.value)),
    ]);
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => store._watch(get);
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final MemoryFirestore store;
  @override
  final String path;

  _Document(this.store, this.path);

  @override
  String get id => path.split('/').last;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(store, '${this.path}/$path');

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(
    this,
    store.documents[path] == null ? null : Map.of(store.documents[path]!),
  );

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => store._watch(get);

  @override
  bool operator ==(Object other) => other is _Document && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

class _Snapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic>? contents;

  _Snapshot(this.reference, this.contents);

  @override
  String get id => reference.id;

  @override
  bool get exists => contents != null;

  @override
  Map<String, dynamic> data() => contents ?? {};
}

class _QuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  _QuerySnapshot(this.docs);
}

class _Transaction extends Fake implements Transaction {
  final MemoryFirestore store;
  final writes = <void Function()>[];

  _Transaction(this.store);

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async {
    if (writes.isNotEmpty) throw StateError('Transaction read after write');
    return await (ref as _Document).get() as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    writes.add(() {
      store.documents[ref.path] = {
        if (options?.merge == true) ...?store.documents[ref.path],
        ...data as Map<String, dynamic>,
      };
    });
    return this;
  }

  @override
  Transaction update(DocumentReference ref, Map<Object, Object?> data) {
    writes.add(() {
      final document = store.documents[ref.path];
      if (document == null) throw StateError('Missing document ${ref.path}');
      document.addAll(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    });
    return this;
  }

  @override
  Transaction delete(DocumentReference ref) {
    writes.add(() => store.documents.remove(ref.path));
    return this;
  }
}

class _Batch extends Fake implements WriteBatch {
  final MemoryFirestore store;
  final writes = <void Function()>[];

  _Batch(this.store);

  @override
  void delete(DocumentReference document) =>
      writes.add(() => store.documents.remove(document.path));

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    writes.add(() {
      store.documents[document.path] = {
        if (options?.merge == true) ...?store.documents[document.path],
        ...data as Map<String, dynamic>,
      };
    });
  }

  @override
  void update(DocumentReference document, Map<Object, Object?> data) {
    writes.add(() {
      final existing = store.documents[document.path];
      if (existing == null) {
        throw StateError('Missing document ${document.path}');
      }
      existing.addAll(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    });
  }

  @override
  Future<void> commit() async {
    // Like Firestore, apply all writes or none of them.
    final before = {
      for (final entry in store.documents.entries)
        entry.key: Map<String, dynamic>.of(entry.value),
    };
    try {
      for (final write in writes) {
        write();
      }
    } catch (_) {
      store.documents
        ..clear()
        ..addAll(before);
      rethrow;
    }
    if (writes.isNotEmpty) store.notifyChanged();
  }
}
