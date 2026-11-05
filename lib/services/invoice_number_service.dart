import 'package:cloud_firestore/cloud_firestore.dart';

/// The independent serial sequences (#1, #2, #3…).
enum InvoiceSequence {
  salesInvoice('sales_invoices', 'sales'),
  salesReturn('sales_returns', 'return');

  const InvoiceSequence(this.counterId, this.reservationPrefix);

  /// Document id in `counters/` holding the highest number used so far.
  final String counterId;

  /// Prefix of the reservation document ids in `invoice_numbers/`.
  final String reservationPrefix;
}

/// Thrown when the chosen number already belongs to another invoice/return.
class DuplicateInvoiceNumberException implements Exception {
  final int number;
  final int nextAvailable;

  const DuplicateInvoiceNumberException(this.number, this.nextAvailable);

  @override
  String toString() =>
      'Number #$number is already used. Next available: #$nextAvailable';
}

/// Numbers read inside a transaction, before any write.
class InvoiceNumberCheck {
  final InvoiceSequence sequence;
  final int number;
  final int lastNumber;
  final bool taken;

  const InvoiceNumberCheck._(
    this.sequence,
    this.number,
    this.lastNumber,
    this.taken,
  );
}

/// Hands out serial invoice numbers and guarantees each is used once.
///
/// Every used number has a document `invoice_numbers/{prefix}_{n}`; creating
/// it in the same transaction as the invoice makes duplicates impossible,
/// even across devices. `counters/{sequence}.lastNumber` is the highest
/// number used, so the suggestion continues after skipped numbers. Old
/// timestamp numbers (INV-…, RET-…) are not part of the sequence.
class InvoiceNumberService {
  final FirebaseFirestore _firestore;

  InvoiceNumberService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Parses user input such as "5" or "#5". Returns null when it is not a
  /// whole number above zero.
  static int? parse(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.startsWith('#')) text = text.substring(1).trim();
    if (!RegExp(r'^\d{1,9}$').hasMatch(text)) return null;
    final value = int.parse(text);
    return value > 0 ? value : null;
  }

  DocumentReference<Map<String, dynamic>> _counterRef(InvoiceSequence s) =>
      _firestore.collection('counters').doc(s.counterId);

  DocumentReference<Map<String, dynamic>> reservationRef(
    InvoiceSequence s,
    int number,
  ) => _firestore
      .collection('invoice_numbers')
      .doc('${s.reservationPrefix}_$number');

  static int _lastNumberFrom(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.exists ? snap.data() : null;
    final raw = data == null ? null : data['lastNumber'];
    return raw is num ? raw.toInt() : 0;
  }

  /// The number to pre-fill on a new invoice: highest used + 1.
  Future<int> suggestNext(InvoiceSequence s) async {
    return _lastNumberFrom(await _counterRef(s).get()) + 1;
  }

  /// Reads the counter and reservation. Call before any write in [t].
  Future<InvoiceNumberCheck> check(
    Transaction t,
    InvoiceSequence s,
    int number,
  ) async {
    final counter = await t.get(_counterRef(s));
    final reservation = await t.get(reservationRef(s, number));
    return InvoiceNumberCheck._(
      s,
      number,
      _lastNumberFrom(counter),
      reservation.exists,
    );
  }

  /// Throws if the number is taken; otherwise reserves it and raises the
  /// counter when needed. Call after [check], in the same transaction.
  void reserve(Transaction t, InvoiceNumberCheck c, {required String docId}) {
    if (c.taken) {
      throw DuplicateInvoiceNumberException(c.number, c.lastNumber + 1);
    }
    t.set(reservationRef(c.sequence, c.number), {
      'number': c.number,
      'documentId': docId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (c.number > c.lastNumber) {
      t.set(_counterRef(c.sequence), {
        'lastNumber': c.number,
      }, SetOptions(merge: true));
    }
  }

  /// Reserves a number in its own transaction (for batch-based saves).
  Future<void> reserveStandalone(
    InvoiceSequence s,
    int number, {
    required String docId,
  }) {
    return _firestore.runTransaction((t) async {
      final c = await check(t, s, number);
      reserve(t, c, docId: docId);
    });
  }

  /// Frees a number so it can be typed in again. Old-style numbers are
  /// ignored. The counter is not lowered.
  Future<void> release(InvoiceSequence s, String? invoiceNumber) async {
    final number = parse(invoiceNumber);
    if (number == null) return;
    final batch = _firestore.batch();
    batch.delete(reservationRef(s, number));
    await batch.commit();
  }
}
