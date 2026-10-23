import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'activity_log.dart';

/// How long a hostel may be used. A hostel whose period has ended is
/// read-only: its records stay visible but nothing can be added.
///
/// Stored as a start time plus a number of days, because the security
/// rules can check "now is before start + days" but a phone cannot be
/// trusted to supply an end date.
class HostelSubscription {
  const HostelSubscription({
    required this.periodStart,
    required this.days,
    this.voucherCode,
    this.isSaving = false,
    this.editingDisabled = false,
    this.accessDisabled = false,
  });

  factory HostelSubscription.fromData(Map<String, dynamic>? data) {
    if (data == null) return const HostelSubscription.none();

    final start = data['periodStart'];

    return HostelSubscription(
      periodStart: start is Timestamp ? start.toDate() : null,
      days: (data['days'] as num?)?.toInt() ?? 0,
      voucherCode: data['voucherCode'] as String?,
      // The server has not stamped the start time yet.
      isSaving: start == null && data.containsKey('periodStart'),
      editingDisabled: data['editingDisabled'] == true,
      accessDisabled: data['accessDisabled'] == true,
    );
  }

  /// A hostel that has never been activated.
  const HostelSubscription.none()
    : periodStart = null,
      days = 0,
      voucherCode = null,
      isSaving = false,
      editingDisabled = false,
      accessDisabled = false;

  final DateTime? periodStart;
  final int days;
  final String? voucherCode;

  /// True for the moment between activating and the server confirming.
  final bool isSaving;

  /// Set by the super admin to make the hostel read-only even while
  /// its period is running.
  final bool editingDisabled;

  /// Set by the super admin to close the hostel to its members.
  final bool accessDisabled;

  /// Whether members can add or change records right now.
  bool canEdit(DateTime now) {
    return isActive(now) && !editingDisabled && !accessDisabled;
  }

  DateTime? get activeUntil {
    return periodStart?.add(Duration(days: days));
  }

  bool isActive(DateTime now) {
    if (isSaving && days > 0) return true;

    final end = activeUntil;
    return end != null && now.isBefore(end);
  }

  /// Whole days remaining, rounded up, or 0 when not active.
  int daysLeft(DateTime now) {
    final end = activeUntil;
    if (end == null || !now.isBefore(end)) return 0;

    return (end.difference(now).inMinutes / (24 * 60)).ceil();
  }

  /// How long the hostel stays active, in words: days, or hours once
  /// less than a day is left. Empty when it is not active.
  String timeLeftText(DateTime now) {
    final end = activeUntil;
    if (end == null || !now.isBefore(end)) return '';

    final minutes = end.difference(now).inMinutes;

    if (minutes < 24 * 60) {
      final hours = (minutes / 60).ceil();
      return hours <= 1 ? '1 hour left' : '$hours hours left';
    }

    final days = daysLeft(now);
    return days == 1 ? '1 day left' : '$days days left';
  }
}

/// A code that activates a hostel for a number of days. Each hostel
/// can use a given voucher once.
class Voucher {
  const Voucher({
    required this.code,
    required this.days,
    this.active = true,
    this.note = '',
    this.createdAt,
  });

  factory Voucher.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return Voucher(
      code: document.id,
      days: (data['days'] as num?)?.toInt() ?? 0,
      active: data['active'] == true,
      note: data['note'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String code;
  final int days;
  final bool active;
  final String note;
  final DateTime? createdAt;
}

enum PaymentStatus { pending, approved, rejected }

/// A bKash payment a hostel admin reported, awaiting or after review.
class PaymentRequest {
  const PaymentRequest({
    required this.trxId,
    required this.groupId,
    required this.groupName,
    required this.amount,
    required this.status,
    this.senderNumber = '',
    this.submittedByName = '',
    this.createdAt,
    this.daysGranted = 0,
    this.note = '',
  });

  factory PaymentRequest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return PaymentRequest(
      trxId: document.id,
      groupId: data['groupId'] as String? ?? '',
      groupName: data['groupName'] as String? ?? 'Hostel',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      status: switch (data['status']) {
        'approved' => PaymentStatus.approved,
        'rejected' => PaymentStatus.rejected,
        _ => PaymentStatus.pending,
      },
      senderNumber: data['senderNumber'] as String? ?? '',
      submittedByName: data['submittedByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      daysGranted: (data['daysGranted'] as num?)?.toInt() ?? 0,
      note: data['note'] as String? ?? '',
    );
  }

  final String trxId;
  final String groupId;
  final String groupName;
  final double amount;
  final PaymentStatus status;
  final String senderNumber;
  final String submittedByName;
  final DateTime? createdAt;
  final int daysGranted;
  final String note;
}

/// Where and how hostels should pay, set by the super admin.
class PaymentInfo {
  const PaymentInfo({this.bkashNumber = '', this.instructions = ''});

  factory PaymentInfo.fromData(Map<String, dynamic>? data) {
    return PaymentInfo(
      bkashNumber: data?['bkashNumber'] as String? ?? '',
      instructions: data?['instructions'] as String? ?? '',
    );
  }

  final String bkashNumber;
  final String instructions;

  bool get isEmpty => bkashNumber.isEmpty && instructions.isEmpty;
}

/// App-wide switches set by the super admin.
class AppConfig {
  const AppConfig({this.maintenance = false, this.maintenanceMessage = ''});

  factory AppConfig.fromData(Map<String, dynamic>? data) {
    return AppConfig(
      maintenance: data?['maintenance'] == true,
      maintenanceMessage: data?['maintenanceMessage'] as String? ?? '',
    );
  }

  /// While true, everyone except the super admin sees a maintenance
  /// screen instead of the app.
  final bool maintenance;
  final String maintenanceMessage;
}

/// Thrown with a message that can be shown to the user as it is.
class SubscriptionException implements Exception {
  const SubscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SubscriptionService {
  SubscriptionService._();

  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _subscription(String groupId) {
    return _firestore.collection('subscriptions').doc(groupId);
  }

  static CollectionReference<Map<String, dynamic>> get _vouchers =>
      _firestore.collection('vouchers');

  static CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('payments');

  static DocumentReference<Map<String, dynamic>> get _paymentInfo =>
      _firestore.collection('config').doc('payment');

  /// Codes and transaction IDs are compared without spaces or case.
  static String normalizeCode(String text) {
    return text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  static bool isValidCode(String code) {
    return RegExp(r'^[A-Z0-9]{4,20}$').hasMatch(code);
  }

  /// The fields to save when [addDays] are added to [current]. An
  /// active period simply gets longer; an ended (or missing) one
  /// starts again from now. The security rules require exactly this.
  static Map<String, dynamic> extensionFields(
    HostelSubscription current, {
    required int addDays,
    required DateTime now,
  }) {
    if (current.isActive(now) && current.periodStart != null) {
      return {'days': current.days + addDays};
    }

    return {'periodStart': FieldValue.serverTimestamp(), 'days': addDays};
  }

  static Stream<HostelSubscription> watch(String groupId) {
    return _subscription(groupId)
        .snapshots()
        .map((snapshot) => HostelSubscription.fromData(snapshot.data()));
  }

  static Stream<PaymentInfo> watchPaymentInfo() {
    return _paymentInfo.snapshots().map(
      (snapshot) => PaymentInfo.fromData(snapshot.data()),
    );
  }

  /// The payments the signed-in admin reported for a hostel, newest
  /// first.
  static Stream<List<PaymentRequest>> watchGroupPayments(String groupId) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return _payments
        .where('groupId', isEqualTo: groupId)
        .where('submittedBy', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(PaymentRequest.fromDocument).toList()
            ..sort((a, b) {
              final aTime = a.createdAt ?? DateTime.now();
              final bTime = b.createdAt ?? DateTime.now();
              return bTime.compareTo(aTime);
            });
        });
  }

  /// Activates or extends a hostel with a voucher. Hostel admins only.
  /// Returns the number of days added.
  static Future<int> redeemVoucher({
    required String groupId,
    required String code,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final voucherCode = normalizeCode(code);

    if (!isValidCode(voucherCode)) {
      throw const SubscriptionException('This voucher code is not valid.');
    }

    final voucherReference = _vouchers.doc(voucherCode);
    final redemption = voucherReference.collection('redemptions').doc(groupId);

    try {
      final voucherSnapshot = await voucherReference.get();
      if (!voucherSnapshot.exists) {
        throw const SubscriptionException('This voucher code is not valid.');
      }

      final voucher = Voucher.fromDocument(voucherSnapshot);
      if (!voucher.active || voucher.days <= 0) {
        throw const SubscriptionException('This voucher is no longer active.');
      }

      final current = HostelSubscription.fromData(
        (await _subscription(groupId).get()).data(),
      );

      final batch = _firestore.batch();

      batch.set(_subscription(groupId), {
        ...extensionFields(current, addDays: voucher.days, now: DateTime.now()),
        'voucherCode': voucherCode,
        'lastSource': 'voucher',
        'updatedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(redemption, {
        'groupId': groupId,
        'redeemedBy': user.uid,
        'redeemedAt': FieldValue.serverTimestamp(),
      });
      ActivityLog.addTo(
        batch,
        groupId,
        kind: ActivityKind.hostelActivated,
        subject: voucherCode,
        details: 'Voucher $voucherCode · ${voucher.days} days added',
      );

      await batch.commit();
      return voucher.days;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const SubscriptionException(
          'This voucher cannot be used. It may already have been used '
          'for this hostel, or only an admin can activate the hostel.',
        );
      }
      throw SubscriptionException(
        error.message ?? 'Unable to use the voucher. Please try again.',
      );
    }
  }

  /// Reports a bKash payment for the super admin to check.
  static Future<void> submitPayment({
    required String groupId,
    required String groupName,
    required String trxId,
    required double amount,
    required String senderNumber,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final id = normalizeCode(trxId);

    if (!isValidCode(id)) {
      throw const SubscriptionException(
        'Please enter the transaction ID exactly as bKash shows it.',
      );
    }

    try {
      // The transaction ID is the document id, so the same payment can
      // never be reported twice.
      final batch = _firestore.batch()
        ..set(_payments.doc(id), {
          'trxId': id,
          'groupId': groupId,
          'groupName': groupName,
          'amount': amount,
          'senderNumber': senderNumber.trim(),
          'submittedBy': user.uid,
          'submittedByName': user.displayName ?? '',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      ActivityLog.addTo(
        batch,
        groupId,
        kind: ActivityKind.paymentSent,
        subject: id,
        details: '৳${ActivityLog.number(amount)} · TrxID $id',
      );
      await batch.commit();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const SubscriptionException(
          'This transaction ID has already been submitted, or only a '
          'hostel admin can report a payment.',
        );
      }
      throw SubscriptionException(
        error.message ?? 'Unable to submit the payment.',
      );
    }
  }

  // ─── Super admin ───────────────────────────────────────────────

  /// Adds [days] to a hostel, by hand or when approving a payment.
  static Future<void> grantDays({
    required String groupId,
    required int days,
    String source = 'admin',
    PaymentRequest? payment,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final current = HostelSubscription.fromData(
      (await _subscription(groupId).get()).data(),
    );

    final batch = _firestore.batch();

    batch.set(_subscription(groupId), {
      ...extensionFields(current, addDays: days, now: DateTime.now()),
      'lastSource': source,
      'updatedBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (payment != null) {
      batch.update(_payments.doc(payment.trxId), {
        'status': 'approved',
        'daysGranted': days,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    }

    ActivityLog.addTo(
      batch,
      groupId,
      kind: ActivityKind.hostelActivated,
      details: payment == null
          ? '$days days added'
          : 'bKash payment ${payment.trxId} approved · $days days added',
    );

    await batch.commit();
  }

  /// Sets how many days a hostel has left, counted from now. Zero
  /// ends its period immediately.
  static Future<void> setDaysLeft({
    required String groupId,
    required int days,
  }) {
    final batch = _firestore.batch()
      ..set(_subscription(groupId), {
        'periodStart': FieldValue.serverTimestamp(),
        'days': days,
        'lastSource': 'admin',
        'updatedBy': FirebaseAuth.instance.currentUser!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    ActivityLog.addTo(
      batch,
      groupId,
      kind: ActivityKind.activationSet,
      details: days == 0 ? 'Activation ended' : '$days days left',
    );
    return batch.commit();
  }

  /// Switches editing or access for a hostel off or on, whatever its
  /// period says.
  static Future<void> setHostelControls(
    String groupId, {
    bool? editingDisabled,
    bool? accessDisabled,
  }) {
    return _subscription(groupId).set({
      'editingDisabled': ?editingDisabled,
      'accessDisabled': ?accessDisabled,
      'updatedBy': FirebaseAuth.instance.currentUser!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static DocumentReference<Map<String, dynamic>> get _appConfig =>
      _firestore.collection('config').doc('app');

  static Stream<AppConfig> watchAppConfig() {
    return _appConfig.snapshots().map(
      (snapshot) => AppConfig.fromData(snapshot.data()),
    );
  }

  static Future<AppConfig> loadAppConfig() async {
    return AppConfig.fromData((await _appConfig.get()).data());
  }

  /// Turns maintenance mode on or off for every user.
  static Future<void> saveAppConfig({
    required bool maintenance,
    required String message,
  }) {
    return _appConfig.set({
      'maintenance': maintenance,
      'maintenanceMessage': message.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> rejectPayment(
    PaymentRequest payment, {
    String note = '',
  }) {
    return _payments.doc(payment.trxId).update({
      'status': 'rejected',
      'note': note.trim(),
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> createVoucher({
    required String code,
    required int days,
    String note = '',
  }) async {
    final voucherCode = normalizeCode(code);

    if (!isValidCode(voucherCode)) {
      throw const SubscriptionException(
        'Use 4 to 20 letters and numbers for the code.',
      );
    }

    final reference = _vouchers.doc(voucherCode);

    if ((await reference.get()).exists) {
      throw const SubscriptionException(
        'A voucher with this code already exists.',
      );
    }

    await reference.set({
      'days': days,
      'active': true,
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setVoucherActive(Voucher voucher, bool active) {
    return _vouchers.doc(voucher.code).update({'active': active});
  }

  /// Removes a voucher for good. Hostels that already used it keep the
  /// days it gave them.
  static Future<void> deleteVoucher(Voucher voucher) {
    return _vouchers.doc(voucher.code).delete();
  }

  /// Removes a reported payment from the records. Days already given
  /// for it stay with the hostel.
  static Future<void> deletePayment(PaymentRequest payment) {
    return _payments.doc(payment.trxId).delete();
  }

  static Future<void> savePaymentInfo({
    required String bkashNumber,
    required String instructions,
  }) {
    return _paymentInfo.set({
      'bkashNumber': bkashNumber.trim(),
      'instructions': instructions.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<Map<String, HostelSubscription>> loadSubscriptions() async {
    final snapshot = await _firestore.collection('subscriptions').get();

    return {
      for (final document in snapshot.docs)
        document.id: HostelSubscription.fromData(document.data()),
    };
  }

  static Future<List<Voucher>> loadVouchers() async {
    final snapshot = await _vouchers.get();

    return snapshot.docs.map(Voucher.fromDocument).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  /// Every reported payment: waiting ones first, then newest first.
  static Future<List<PaymentRequest>> loadPayments() async {
    final snapshot = await _payments.get();

    return snapshot.docs.map(PaymentRequest.fromDocument).toList()
      ..sort((a, b) {
        final aPending = a.status == PaymentStatus.pending ? 0 : 1;
        final bPending = b.status == PaymentStatus.pending ? 0 : 1;
        if (aPending != bPending) return aPending - bPending;

        final aTime = a.createdAt ?? DateTime.now();
        final bTime = b.createdAt ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
  }

  static Future<PaymentInfo> loadPaymentInfo() async {
    return PaymentInfo.fromData((await _paymentInfo.get()).data());
  }
}
