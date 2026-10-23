import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_meal_calculator/services/update_service.dart';
import 'package:hostel_meal_calculator/theme/app_theme.dart';
import 'package:hostel_meal_calculator/widgets/update_prompt.dart';

void main() {
  group('isNewer', () {
    test('compares major, minor and patch numbers', () {
      expect(UpdateService.isNewer('1.0.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewer('1.1.0', '1.0.9'), isTrue);
      expect(UpdateService.isNewer('2.0.0', '1.9.9'), isTrue);
      expect(UpdateService.isNewer('1.10.0', '1.9.0'), isTrue);
    });

    test('is false for the same or an older version', () {
      expect(UpdateService.isNewer('1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewer('1.0.0', '1.0.1'), isFalse);
      expect(UpdateService.isNewer('0.9.9', '1.0.0'), isFalse);
    });

    test('accepts a v prefix, short versions and build numbers', () {
      expect(UpdateService.isNewer('v1.2.0', '1.1.0'), isTrue);
      expect(UpdateService.isNewer('v1.2', '1.2.0'), isFalse);
      expect(UpdateService.isNewer('1.2', '1.1.5'), isTrue);
      expect(UpdateService.isNewer('1.0.1+7', '1.0.0+9'), isTrue);
      expect(UpdateService.isNewer('1.0.0+9', '1.0.0+1'), isFalse);
    });

    test('ignores tags without a version number', () {
      expect(UpdateService.isNewer('latest', '1.0.0'), isFalse);
      expect(UpdateService.isNewer('', '1.0.0'), isFalse);
    });
  });

  group('updateFromLocation', () {
    const repo = 'https://github.com/adnanshad35/hostel-meal-calculator';

    test('a newer release tag becomes an update with the APK link', () {
      final update = UpdateService.updateFromLocation(
        '$repo/releases/tag/v1.2.1',
        installedVersion: '1.2.0',
      );

      expect(update, isNotNull);
      expect(update!.version, '1.2.1');
      expect(
        update.downloadUrl,
        '$repo/releases/latest/download/HostelMate.apk',
      );
    });

    test('returns nothing when the app is already up to date', () {
      expect(
        UpdateService.updateFromLocation(
          '$repo/releases/tag/v1.2.1',
          installedVersion: '1.2.1',
        ),
        isNull,
      );
      expect(
        UpdateService.updateFromLocation(
          '$repo/releases/tag/v1.2.1',
          installedVersion: '1.3.0',
        ),
        isNull,
      );
    });

    test('ignores a missing redirect or a page without a tag', () {
      expect(
        UpdateService.updateFromLocation(null, installedVersion: '1.0.0'),
        isNull,
      );
      // What the link redirects to when no release exists yet.
      expect(
        UpdateService.updateFromLocation(
          '$repo/releases',
          installedVersion: '1.0.0',
        ),
        isNull,
      );
      expect(
        UpdateService.updateFromLocation(
          '$repo/releases/tag/latest',
          installedVersion: '1.0.0',
        ),
        isNull,
      );
    });
  });

  testWidgets('update dialog shows the version and notes and cannot '
      'be dismissed', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: UpdateDialog(
            update: AppUpdate(
              version: '1.1.0',
              downloadUrl: 'https://example.com/app.apk',
              notes: 'Shadow members\nAdd Meal dialog',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Update Required'), findsOneWidget);
    expect(find.textContaining('HostelMate 1.1.0 is ready'), findsOneWidget);
    expect(find.text('Shadow members\nAdd Meal dialog'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(find.text('Update'), findsOneWidget);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    expect(tester.takeException(), isNull);
  });

  group('updateFromConfig', () {
    const config = UpdateConfig(
      version: '1.7.0',
      minVersion: '1.6.0',
      notes: 'Guide page',
    );

    test('below the minimum, the update is required', () {
      final update = UpdateService.updateFromConfig(
        config,
        installedVersion: '1.5.2',
      );

      expect(update!.isRequired, isTrue);
      expect(update.version, '1.7.0');
      expect(update.notes, 'Guide page');
      expect(update.downloadUrl, endsWith('/download/HostelMate.apk'));
    });

    test('between the minimum and the latest, it is optional', () {
      final update = UpdateService.updateFromConfig(
        config,
        installedVersion: '1.6.0',
      );

      expect(update!.isRequired, isFalse);
    });

    test('without a minimum, no version must update', () {
      final update = UpdateService.updateFromConfig(
        const UpdateConfig(version: '2.0.0'),
        installedVersion: '1.0.0',
      );

      expect(update!.isRequired, isFalse);
    });

    test('nothing once the app is up to date', () {
      expect(
        UpdateService.updateFromConfig(config, installedVersion: '1.7.0'),
        isNull,
      );
    });

    test('a saved APK link is used in place of GitHub', () {
      final update = UpdateService.updateFromConfig(
        const UpdateConfig(
          version: '1.7.0',
          downloadUrl: 'https://example.com/HostelMate.apk',
        ),
        installedVersion: '1.6.0',
      );

      expect(update!.downloadUrl, 'https://example.com/HostelMate.apk');
    });
  });

  test('a saved config needs a version', () {
    expect(UpdateConfig.fromData(null), isNull);
    expect(UpdateConfig.fromData({'version': ' '}), isNull);
    expect(UpdateConfig.fromData({'version': '1.7.0'})!.minVersion, '');
  });

  test('What\'s New shows only on the first open after an update', () {
    expect(UpdateService.isFirstOpenAfterUpdate(null, '1.7.0'), isFalse);
    expect(UpdateService.isFirstOpenAfterUpdate('1.6.0', '1.7.0'), isTrue);
    expect(UpdateService.isFirstOpenAfterUpdate('1.7.0', '1.7.0'), isFalse);
  });

  test('versions are checked before they are saved', () {
    expect(UpdateService.isValidVersion('1.7.0'), isTrue);
    expect(UpdateService.isValidVersion('v2'), isTrue);
    expect(UpdateService.isValidVersion('1.7.0 beta'), isFalse);
    expect(UpdateService.isValidVersion(''), isFalse);
  });

  testWidgets('an optional update can be put off', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: UpdateDialog(
            update: AppUpdate(
              version: '1.7.0',
              downloadUrl: 'https://example.com/app.apk',
              isRequired: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Update Available'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
    expect(tester.takeException(), isNull);
  });
}
