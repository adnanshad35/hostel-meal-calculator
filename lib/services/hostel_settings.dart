import 'package:cloud_firestore/cloud_firestore.dart';

import 'month_rules.dart';

/// How a hostel's admins have chosen to run it. Saved on the hostel
/// itself. Everything is on unless switched off, so a hostel that
/// never opened these settings works as it always did.
///
/// The permissions are under `settings`, where every app version reads
/// them. Everything newer is under `options`: earlier app versions
/// save `settings` as a whole, and would otherwise wipe what they do
/// not know.
class HostelSettings {
  const HostelSettings({
    this.membersCanAddMeals = true,
    this.membersCanAddExpenses = true,
    this.membersCanEdit = true,
    this.fixedCostsEnabled = true,
    this.specialPermission = false,
    this.removeAllLimits = const RemoveAllLimits(),
    this.balanceOptions = const BalanceOptions(),
  });

  /// Reads the settings from a `groups/{id}` document.
  factory HostelSettings.fromGroupData(Map<String, dynamic>? group) {
    final savedSettings = group?['settings'];
    final settings = savedSettings is Map
        ? savedSettings
        : const <String, dynamic>{};
    final savedOptions = group?['options'];
    final options = savedOptions is Map
        ? savedOptions
        : const <String, dynamic>{};

    // Test builds kept these under `settings`; `options` comes first.
    Object? option(String key) =>
        options.containsKey(key) ? options[key] : settings[key];

    return HostelSettings(
      membersCanAddMeals: settings['membersCanAddMeals'] != false,
      membersCanAddExpenses: settings['membersCanAddExpenses'] != false,
      membersCanEdit: settings['membersCanEdit'] != false,
      fixedCostsEnabled: settings['fixedCostsEnabled'] != false,
      specialPermission: settings['specialPermission'] == true,
      removeAllLimits: RemoveAllLimits(
        maxMeals: _positive(
          option('removeAllMaxMeals'),
          RemoveAllLimits.defaultMaxMeals,
        ),
        maxExpense: _positive(
          option('removeAllMaxExpense'),
          RemoveAllLimits.defaultMaxExpense,
        ),
      ),
      balanceOptions: BalanceOptions(
        minimumMealsChanges: _changes(
          options['minimumMealsChanges'],
          legacyOffFrom: settings['minimumMealsOffFrom'],
        ),
        shopDueChanges: _changes(
          options['shopDueChanges'],
          legacyOffFrom: settings['shopDueOffFrom'],
        ),
        initialShare: option('initialShareEnabled') == true,
        bestManager: option('bestManagerEnabled') == true,
        fixedCostsChanges: _changes(options['fixedCostsChanges']),
        monthTrend: options['monthTrendEnabled'] != false,
      ),
    );
  }

  static bool _isMonthKey(Object? value) =>
      value is String && RegExp(r'^\d{4}-\d{2}$').hasMatch(value);

  static Map<String, bool> _changes(Object? saved, {Object? legacyOffFrom}) {
    if (saved is Map) {
      return {
        for (final entry in saved.entries)
          if (_isMonthKey(entry.key) && entry.value is bool)
            entry.key as String: entry.value as bool,
      };
    }
    return _isMonthKey(legacyOffFrom)
        ? {legacyOffFrom as String: false}
        : const {};
  }

  static double _positive(Object? value, double fallback) {
    return value is num && value >= 0 ? value.toDouble() : fallback;
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

  /// When Remove All is offered for a member who left.
  final RemoveAllLimits removeAllLimits;

  /// Which figures the Balance page uses.
  final BalanceOptions balanceOptions;

  HostelSettings copyWith({
    bool? membersCanAddMeals,
    bool? membersCanAddExpenses,
    bool? membersCanEdit,
    bool? fixedCostsEnabled,
    bool? specialPermission,
    RemoveAllLimits? removeAllLimits,
    BalanceOptions? balanceOptions,
  }) {
    return HostelSettings(
      membersCanAddMeals: membersCanAddMeals ?? this.membersCanAddMeals,
      membersCanAddExpenses:
          membersCanAddExpenses ?? this.membersCanAddExpenses,
      membersCanEdit: membersCanEdit ?? this.membersCanEdit,
      fixedCostsEnabled: fixedCostsEnabled ?? this.fixedCostsEnabled,
      specialPermission: specialPermission ?? this.specialPermission,
      removeAllLimits: removeAllLimits ?? this.removeAllLimits,
      balanceOptions: balanceOptions ?? this.balanceOptions,
    );
  }

  /// The permissions, as saved under `settings`.
  Map<String, dynamic> toMap() {
    return {
      'membersCanAddMeals': membersCanAddMeals,
      'membersCanAddExpenses': membersCanAddExpenses,
      'membersCanEdit': membersCanEdit,
      'fixedCostsEnabled': fixedCostsEnabled,
      'specialPermission': specialPermission,
    };
  }

  /// Everything newer, as saved under `options`.
  Map<String, dynamic> optionsMap() {
    return {
      'removeAllMaxMeals': removeAllLimits.maxMeals,
      'removeAllMaxExpense': removeAllLimits.maxExpense,
      'minimumMealsChanges': balanceOptions.minimumMealsChanges,
      'shopDueChanges': balanceOptions.shopDueChanges,
      'initialShareEnabled': balanceOptions.initialShare,
      'bestManagerEnabled': balanceOptions.bestManager,
      'fixedCostsChanges': balanceOptions.fixedCostsChanges,
      'monthTrendEnabled': balanceOptions.monthTrend,
    };
  }
}

/// Which figures a hostel's Balance page uses.
///
/// Min Meals and Shop Due are on unless an admin switched them off.
/// Each switch is remembered with the month it was made in, as
/// `{YYYY-MM: on}`, and a month follows the last switch made in it or
/// before it. So a switch changes the current month and the ones after
/// it, never an earlier month. A figure switched off counts as zero;
/// its saved value is kept, and counts again once switched back on.
class BalanceOptions {
  const BalanceOptions({
    this.minimumMealsChanges = const {},
    this.shopDueChanges = const {},
    this.initialShare = false,
    this.bestManager = false,
    this.fixedCostsChanges = const {},
    this.monthTrend = true,
  });

  final Map<String, bool> minimumMealsChanges;
  final Map<String, bool> shopDueChanges;

  /// When on, admins can add an Initial Share: money collected from
  /// members at the start of the month for the whole month's food.
  /// Switched off, no new one can be added; those already added stay,
  /// because that money was really collected.
  final bool initialShare;

  /// When on, the Balance page shows whose duty turn kept food
  /// cheapest, against the month's average.
  final bool bestManager;

  /// Rent and shared bills, set by admins. Off until switched on, and
  /// remembered by month like Min Meals.
  final Map<String, bool> fixedCostsChanges;

  /// When on, the Balance page shows the month's day-by-day chart.
  final bool monthTrend;

  /// The last switch made in [monthKey] or before it.
  static String? _lastChange(Map<String, bool> changes, String monthKey) {
    String? last;
    for (final key in changes.keys) {
      if (key.compareTo(monthKey) <= 0 &&
          (last == null || key.compareTo(last) > 0)) {
        last = key;
      }
    }
    return last;
  }

  static bool _isOnIn(
    Map<String, bool> changes,
    String monthKey, {
    bool byDefault = true,
  }) {
    final last = _lastChange(changes, monthKey);
    return last == null ? byDefault : changes[last]!;
  }

  /// [changes] with a switch to [isOn] in [monthKey]. A switch back to
  /// what the month had anyway is dropped, so the list stays short.
  static Map<String, bool> _switched(
    Map<String, bool> changes,
    bool isOn,
    String monthKey, {
    bool byDefault = true,
  }) {
    final updated = {
      for (final entry in changes.entries)
        if (entry.key.compareTo(monthKey) < 0) entry.key: entry.value,
    };
    if (_isOnIn(updated, monthKey, byDefault: byDefault) != isOn) {
      updated[monthKey] = isOn;
    }
    return updated;
  }

  bool usesFixedCosts(String monthKey) =>
      _isOnIn(fixedCostsChanges, monthKey, byDefault: false);

  /// The month Fixed Costs were last switched on, up to [monthKey].
  /// Only figures saved from then on count, so rent entered long ago,
  /// before a switch off, never comes back by itself. Null when off.
  String? fixedCostsSince(String monthKey) {
    if (!usesFixedCosts(monthKey)) return null;
    return _lastChange(fixedCostsChanges, monthKey);
  }

  bool usesMinimumMeals(String monthKey) =>
      _isOnIn(minimumMealsChanges, monthKey);

  bool usesShopDue(String monthKey) => _isOnIn(shopDueChanges, monthKey);

  /// The minimum meals that count in [monthKey], from its saved
  /// `monthlySettings`.
  double minimumMealsOf(Map<String, dynamic>? monthSettings, String monthKey) {
    if (!usesMinimumMeals(monthKey)) return 0;
    return (monthSettings?['minimumMeals'] as num?)?.toDouble() ?? 0;
  }

  /// The shop due that counts in [monthKey].
  double shopDueOf(Map<String, dynamic>? monthSettings, String monthKey) {
    if (!usesShopDue(monthKey)) return 0;
    return (monthSettings?['shopDue'] as num?)?.toDouble() ?? 0;
  }

  BalanceOptions _copy({
    Map<String, bool>? minimumMealsChanges,
    Map<String, bool>? shopDueChanges,
    bool? initialShare,
    bool? bestManager,
    Map<String, bool>? fixedCostsChanges,
    bool? monthTrend,
  }) {
    return BalanceOptions(
      minimumMealsChanges: minimumMealsChanges ?? this.minimumMealsChanges,
      shopDueChanges: shopDueChanges ?? this.shopDueChanges,
      initialShare: initialShare ?? this.initialShare,
      bestManager: bestManager ?? this.bestManager,
      fixedCostsChanges: fixedCostsChanges ?? this.fixedCostsChanges,
      monthTrend: monthTrend ?? this.monthTrend,
    );
  }

  /// These options with Min Meals switched on or off from [monthKey].
  BalanceOptions withMinimumMeals(bool isOn, String monthKey) => _copy(
    minimumMealsChanges: _switched(minimumMealsChanges, isOn, monthKey),
  );

  BalanceOptions withShopDue(bool isOn, String monthKey) =>
      _copy(shopDueChanges: _switched(shopDueChanges, isOn, monthKey));

  BalanceOptions withInitialShare(bool isOn) => _copy(initialShare: isOn);

  BalanceOptions withBestManager(bool isOn) => _copy(bestManager: isOn);

  BalanceOptions withFixedCosts(bool isOn, String monthKey) => _copy(
    fixedCostsChanges: _switched(
      fixedCostsChanges,
      isOn,
      monthKey,
      byDefault: false,
    ),
  );

  BalanceOptions withMonthTrend(bool isOn) => _copy(monthTrend: isOn);

  /// True when [other] counts Min Meals and Shop Due the same way in
  /// [monthKey].
  bool countsLike(BalanceOptions other, String monthKey) =>
      usesMinimumMeals(monthKey) == other.usesMinimumMeals(monthKey) &&
      usesShopDue(monthKey) == other.usesShopDue(monthKey);
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

  /// Saves each setting on its own, so nothing else on the hostel,
  /// such as a setting a newer app version added, is lost. Only a
  /// hostel admin can save; the security rules check it.
  static Future<void> save(String groupId, HostelSettings settings) {
    return _group(groupId).update({
      for (final entry in settings.toMap().entries)
        'settings.${entry.key}': entry.value,
      for (final entry in settings.optionsMap().entries)
        'options.${entry.key}': entry.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
