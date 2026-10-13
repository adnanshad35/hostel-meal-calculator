import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'hostel_fund.dart';
import 'monthly_calculator.dart';

/// Reads and saves `groups/{groupId}/deposits`: money members gave to
/// the hostel fund.
class FundService {
  FundService._();

  static CollectionReference<Map<String, dynamic>> _deposits(String groupId) {
    return FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('deposits');
  }

  static List<FundDeposit> _read(QuerySnapshot<Map<String, dynamic>> data) {
    return [
      for (final document in data.docs)
        FundDeposit(
          id: document.id,
          memberId: document.data()['memberId'] as String? ?? '',
          memberName: document.data()['memberName'] as String? ?? 'Member',
          amount: (document.data()['amount'] as num?)?.toDouble() ?? 0,
          date: (document.data()['date'] as Timestamp?)?.toDate(),
        ),
    ];
  }

  static Stream<List<FundDeposit>> watch(String groupId) {
    return _deposits(groupId).snapshots().map(_read);
  }

  static Future<List<FundDeposit>> fetch(String groupId) async {
    return _read(await _deposits(groupId).get());
  }

  static Future<void> add({
    required String groupId,
    required String memberId,
    required String memberName,
    required double amount,
    required DateTime date,
  }) {
    return _deposits(groupId).add({
      'memberId': memberId,
      'memberName': memberName,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'enteredBy': FirebaseAuth.instance.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String groupId, String depositId) {
    return _deposits(groupId).doc(depositId).delete();
  }

  /// A saved expense, reduced to what the calculations need.
  static ExpenseRecord expenseRecord(Map<String, dynamic> data) {
    return ExpenseRecord(
      name: data['name'] as String?,
      paidById: data['paidById'] as String?,
      paidByName: data['paidByName'] as String?,
      date: (data['date'] as Timestamp?)?.toDate(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      fromFund: (data['fromFund'] as num?)?.toDouble() ?? 0,
      isBill: data['category'] == 'bill',
    );
  }
}
