import 'package:cloud_firestore/cloud_firestore.dart';

/// How long after an entry is first saved it can still be corrected
/// without being marked as edited, such as fixing a slip right away.
const editGrace = Duration(minutes: 1);

/// True when an entry was changed after it was first saved, so every
/// member can see it was edited, by an admin or by its owner. An entry
/// saved without [createdAt], from before it was recorded, is never
/// marked.
bool isEdited({required DateTime? createdAt, required DateTime? updatedAt}) {
  if (createdAt == null || updatedAt == null) return false;

  return updatedAt.difference(createdAt) > editGrace;
}

/// [isEdited] for a saved meal or expense, from its `createdAt` and
/// `updatedAt`.
bool isEditedEntry(Map<String, dynamic> data) {
  DateTime? time(Object? value) => value is Timestamp ? value.toDate() : null;

  return isEdited(
    createdAt: time(data['createdAt']),
    updatedAt: time(data['updatedAt']),
  );
}
