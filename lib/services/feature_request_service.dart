import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// An idea a user sent to the developer from the app.
class FeatureRequest {
  const FeatureRequest({
    required this.id,
    required this.message,
    this.userName = '',
    this.email = '',
    this.createdAt,
  });

  factory FeatureRequest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return FeatureRequest(
      id: document.id,
      message: data['message'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String message;
  final String userName;
  final String email;
  final DateTime? createdAt;
}

/// Reads and writes `featureRequests`. Any signed-in user can send
/// one; only the super admin can read or delete them.
class FeatureRequestService {
  FeatureRequestService._();

  /// The longest message that can be sent.
  static const int maxLength = 1000;

  static CollectionReference<Map<String, dynamic>> get _requests =>
      FirebaseFirestore.instance.collection('featureRequests');

  static Future<void> send(String message) {
    final user = FirebaseAuth.instance.currentUser!;

    return _requests.add({
      'userId': user.uid,
      'userName': user.displayName?.trim() ?? '',
      'email': user.email ?? '',
      'message': message.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Every request, newest first.
  static Future<List<FeatureRequest>> load() async {
    final snapshot = await _requests.get();
    final requests = snapshot.docs.map(FeatureRequest.fromDocument).toList();

    requests.sort((a, b) {
      final first = a.createdAt;
      final second = b.createdAt;
      if (first == null && second == null) return 0;
      if (first == null) return 1;
      if (second == null) return -1;
      return second.compareTo(first);
    });

    return requests;
  }

  static Future<void> delete(FeatureRequest request) {
    return _requests.doc(request.id).delete();
  }
}
