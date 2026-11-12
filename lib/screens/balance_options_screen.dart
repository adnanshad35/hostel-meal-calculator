import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/hostel_settings.dart';
import '../services/monthly_calculator.dart';
import '../widgets/app_tiles.dart';

/// Which figures the Balance page uses: Min Meals, Shop Due, Initial
/// Share and Best Manager. Opened from Admin Settings, or from the +
/// on the Balance page. Admins only.
///
/// Switching Min Meals or Shop Due off counts it as zero from this
/// month on; earlier months and the saved figures stay as they are.
class BalanceOptionsScreen extends StatefulWidget {
  const BalanceOptionsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<BalanceOptionsScreen> createState() => _BalanceOptionsScreenState();
}

class _BalanceOptionsScreenState extends State<BalanceOptionsScreen> {
  late final Stream<HostelSettings> _settings = HostelSettingsService.watch(
    widget.groupId,
  );

  Future<void> _save(HostelSettings settings) async {
    try {
      await HostelSettingsService.save(widget.groupId, settings);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Only an admin can change these settings.'
                : error.message ?? 'Unable to save the settings.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balance Options')),
      body: StreamBuilder<HostelSettings>(
        stream: _settings,
        builder: (context, snapshot) {
          final settings = snapshot.data;
          if (settings == null) {
            return snapshot.hasError
                ? const Center(child: Text('Unable to load the settings.'))
                : const Center(child: CircularProgressIndicator());
          }

          final options = settings.balanceOptions;
          final thisMonth = MonthlyCalculator.monthKey(DateTime.now());

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              TileGroup(
                children: [
                  SwitchTile(
                    icon: Icons.restaurant_menu_outlined,
                    title: 'Min Meals',
                    value: options.usesMinimumMeals(thisMonth),
                    onChanged: (isOn) => _save(
                      settings.copyWith(
                        balanceOptions: options.withMinimumMeals(
                          isOn,
                          thisMonth,
                        ),
                      ),
                    ),
                  ),
                  SwitchTile(
                    icon: Icons.storefront_outlined,
                    title: 'Shop Due',
                    value: options.usesShopDue(thisMonth),
                    onChanged: (isOn) => _save(
                      settings.copyWith(
                        balanceOptions: options.withShopDue(isOn, thisMonth),
                      ),
                    ),
                  ),
                  SwitchTile(
                    icon: Icons.savings_outlined,
                    title: 'Initial Share',
                    value: options.initialShare,
                    onChanged: (isOn) => _save(
                      settings.copyWith(
                        balanceOptions: options.withInitialShare(isOn),
                      ),
                    ),
                  ),
                  SwitchTile(
                    icon: Icons.home_work_outlined,
                    title: 'Fixed Costs',
                    value: options.usesFixedCosts(thisMonth),
                    onChanged: (isOn) => _save(
                      settings.copyWith(
                        balanceOptions: options.withFixedCosts(isOn, thisMonth),
                      ),
                    ),
                  ),
                  if (options.usesFixedCosts(thisMonth))
                    SwitchTile(
                      icon: Icons.add_card_outlined,
                      title: 'Meal + Fixed Cost',
                      value: options.mealPlusFixed,
                      onChanged: (isOn) => _save(
                        settings.copyWith(
                          balanceOptions: options.withMealPlusFixed(isOn),
                        ),
                      ),
                    ),
                  SwitchTile(
                    icon: Icons.emoji_events_outlined,
                    title: 'Best Manager',
                    value: options.bestManager,
                    onChanged: (isOn) => _save(
                      settings.copyWith(
                        balanceOptions: options.withBestManager(isOn),
                      ),
                    ),
                  ),
                  SwitchTile(
                    icon: Icons.show_chart,
                    title: 'Month Trend',
                    value: options.monthTrend,
                    onChanged: (isOn) => _save(
                      settings.copyWith(
                        balanceOptions: options.withMonthTrend(isOn),
                      ),
                    ),
                  ),
                ],
              ),
              // Min Meals and Shop Due open from the 25th to the 5th,
              // unless this is on.
              if (options.usesMinimumMeals(thisMonth) ||
                  options.usesShopDue(thisMonth)) ...[
                const SizedBox(height: 22),
                TileGroup(
                  children: [
                    SwitchTile(
                      icon: Icons.lock_open_outlined,
                      title: 'Min Meals & Shop Due Any Day',
                      value: settings.specialPermission,
                      onChanged: (isOn) =>
                          _save(settings.copyWith(specialPermission: isOn)),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
