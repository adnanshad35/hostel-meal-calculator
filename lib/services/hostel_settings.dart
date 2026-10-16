import 'package:cloud_firestore/cloud_firestore.dart';

/// How a hostel's admins have chosen to run it. Saved on the hostel
/// itself, under `settings`. Everything is on unless switched off, so
/// a hostel that never opened these settings works as it always did.
class HostelSettings {
  const HostelSettings({
    this.membersCanAddMeals = true,
    this.membersCanAddExpenses = true,
    this.membersCanEdit = true,
    this.fixedCostsEnabled = true,
    this.specialPermission = false,
  });

  /// Reads the settings from a `groups/{id}` document.
  factory HostelSettings.fromGroupData(Map<String, dynamic>? group) {
    final saved = group?['settings'];
    final settings = saved is Map ? saved : const <String, dynamic>{};

    return HostelSettings(
      membersCanAddMeals: settings['membersCanAddMeals'] != false,
      membersCanAddExpenses: settings['membersCanAddExpenses'] != false,
      membersCanEdit: settings['membersCanEdit'] != false,
      fixedCostsEnabled: settings['fixedCostsEnabled'] != false,
      specialPermission: settings['specialPermission'] == true,
    );
  }

  /// When off, only admins enter meals and meal plans.
  final bool membersCanAddMeals;

  /// When off, only admins enter and change expenses.
  final bool membersCanAddExpenses;

  /// When off, a member enters a meal or an expense once and cannot
  /// change it afterwards. Admins always can.
  final bool membersCanEdit;

  /// When off, the hostel settles meals only: rent and shared bills
  /// are left out of the monthly calculation.
  final bool fixedCostsEnabled;

  /// When on, the minimum meals and shop due can be entered on any
  /// day. Off by default: they are then open only from the 25th of
  /// the month to the 5th of the next.
  final bool specialPermission;

  HostelSettings copyWith({
    bool? membersCanAddMeals,
    bool? membersCanAddExpenses,
    bool? membersCanEdit,
    bool? fixedCostsEnabled,
    bool? specialPermission,
  }) {
    return HostelSettings(
      membersCanAddMeals: membersCanAddMeals ?? this.membersCanAddMeals,
      membersCanAddExpenses:
          membersCanAddExpenses ?? this.membersCanAddExpenses,
      membersCanEdit: membersCanEdit ?? this.membersCanEdit,
      fixedCostsEnabled: fixedCostsEnabled ?? this.fixedCostsEnabled,
      specialPermission: specialPermission ?? this.specialPermission,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'membersCanAddMeals': membersCanAddMeals,
      'membersCanAddExpenses': membersCanAddExpenses,
      'membersCanEdit': membersCanEdit,
      'fixedCostsEnabled': fixedCostsEnabled,
      'specialPermission': specialPermission,
    };
  }
}

class HostelSettingsService {
  HostelSettingsService._();

  static DocumentReference<Map<String, dynamic>> _group(String groupId) {
    return FirebaseFirestore.instance.collection('groups').doc(groupId);
  }

  static Stream<HostelSettings> watch(String groupId) {
    return _group(groupId)
        .snapshots()
        .map((group) => HostelSettings.fromGroupData(group.data()));
  }

  static Future<HostelSettings> fetch(String groupId) async {
    return HostelSettings.fromGroupData((await _group(groupId).get()).data());
  }

  /// Only a hostel admin can save; the security rules check it.
  static Future<void> save(String groupId, HostelSettings settings) {
    return _group(groupId).update({
      'settings': settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
