import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A newer version of the app that is available to download.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.downloadUrl,
    this.notes = '',
    this.isRequired = true,
  });

  final String version;
  final String downloadUrl;
  final String notes;

  /// True when the installed version is too old to keep using, so the
  /// update cannot be put off.
  final bool isRequired;
}

/// The newest release and the oldest one still allowed, as the super
/// admin saved them in `config/appUpdate`.
class UpdateConfig {
  const UpdateConfig({
    required this.version,
    this.minVersion = '',
    this.notes = '',
    this.downloadUrl = '',
  });

  /// Null when nothing usable is saved.
  static UpdateConfig? fromData(Map<String, dynamic>? data) {
    final version = (data?['version'] as String? ?? '').trim();
    if (version.isEmpty) return null;

    return UpdateConfig(
      version: version,
      minVersion: (data!['minVersion'] as String? ?? '').trim(),
      notes: (data['notes'] as String? ?? '').trim(),
      downloadUrl: (data['downloadUrl'] as String? ?? '').trim(),
    );
  }

  final String version;

  /// Older versions must update; empty when every version may stay.
  final String minVersion;

  /// What is new in [version].
  final String notes;

  /// Where the APK is; empty for the newest GitHub release.
  final String downloadUrl;
}

/// Finds out whether a newer version is out, and what is new in the
/// one just installed.
///
/// The super admin sets the newest version in `config/appUpdate`. Until
/// that exists, the newest GitHub release is used. Publishing a release
/// tagged with a higher version (for example `v1.1.0`), with the APK
/// attached as `HostelMate.apk`, is still needed: it is what is
/// downloaded, and what older app versions check.
class UpdateService {
  UpdateService._();

  static const String _repository =
      'https://github.com/adnanshad35/hostel-meal-calculator';

  /// Redirects to the page of the newest release, whose address ends
  /// with its tag. Used instead of the GitHub API because the API
  /// allows only 60 requests an hour per network, which a hostel's
  /// shared Wi-Fi or a mobile carrier can easily use up.
  static const String _latestReleaseUrl = '$_repository/releases/latest';

  /// Always serves the APK attached to the newest release.
  static const String _downloadUrl =
      '$_repository/releases/latest/download/HostelMate.apk';

  static DocumentReference<Map<String, dynamic>> get _config =>
      FirebaseFirestore.instance.collection('config').doc('appUpdate');

  /// The saved update settings, or null when there are none.
  static Future<UpdateConfig?> loadConfig() async {
    final snapshot = await _config.get().timeout(const Duration(seconds: 8));
    return UpdateConfig.fromData(snapshot.data());
  }

  static Stream<UpdateConfig?> watchConfig() {
    return _config.snapshots().map(
      (snapshot) => UpdateConfig.fromData(snapshot.data()),
    );
  }

  /// Saves the newest version for every user. Only the super admin
  /// may; the security rules check it.
  static Future<void> saveConfig(UpdateConfig config) {
    return _config.set({
      'version': config.version.trim(),
      'minVersion': config.minVersion.trim(),
      'notes': config.notes.trim(),
      'downloadUrl': config.downloadUrl.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns the available update, or null when the app is up to date
  /// or the check could not be completed.
  static Future<AppUpdate?> check() async {
    // The web version is served fresh on every visit, so there is
    // nothing to download or install.
    if (kIsWeb) return null;

    try {
      final info = await PackageInfo.fromPlatform();

      UpdateConfig? config;
      try {
        config = await loadConfig();
      } catch (_) {
        // Offline or unreadable: GitHub may still answer.
      }

      if (config != null) {
        return updateFromConfig(config, installedVersion: info.version);
      }
      return await _checkGitHub(info.version);
    } catch (_) {
      // Offline or unexpected response: stay quiet and retry next launch.
      return null;
    }
  }

  static Future<AppUpdate?> _checkGitHub(String installedVersion) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);

    try {
      final request = await client.getUrl(Uri.parse(_latestReleaseUrl));
      request.followRedirects = false;

      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();

      return updateFromLocation(location, installedVersion: installedVersion);
    } finally {
      client.close(force: true);
    }
  }

  /// The update [config] offers to [installedVersion]: required below
  /// its minimum version, optional below its newest one, and nothing
  /// once the app is up to date.
  static AppUpdate? updateFromConfig(
    UpdateConfig config, {
    required String installedVersion,
  }) {
    if (!isNewer(config.version, installedVersion)) return null;

    return AppUpdate(
      version: _numbers(config.version).join('.'),
      downloadUrl: config.downloadUrl.isEmpty
          ? _downloadUrl
          : config.downloadUrl,
      notes: config.notes,
      isRequired:
          config.minVersion.isNotEmpty &&
          isNewer(config.minVersion, installedVersion),
    );
  }

  /// Reads the address the latest-release link redirects to, such as
  /// `.../releases/tag/v1.2.0`, and returns it as an update when its
  /// version is newer than [installedVersion].
  static AppUpdate? updateFromLocation(
    String? location, {
    required String installedVersion,
  }) {
    if (location == null) return null;

    final match = RegExp(r'/releases/tag/([^/?#]+)').firstMatch(location);
    if (match == null) return null;

    final tag = Uri.decodeComponent(match.group(1)!);
    if (!isNewer(tag, installedVersion)) return null;

    return AppUpdate(
      version: _numbers(tag).join('.'),
      downloadUrl: _downloadUrl,
    );
  }

  static const String _lastOpenedKey = 'lastOpenedVersion';

  /// What is new in the installed version, the first time it opens
  /// after an update. Null on a first install, on any later launch, or
  /// when nothing was written about it.
  static Future<String?> notesAfterUpdate() async {
    if (kIsWeb) return null;

    try {
      final info = await PackageInfo.fromPlatform();
      final prefs = await SharedPreferences.getInstance();
      final lastOpened = prefs.getString(_lastOpenedKey);
      await prefs.setString(_lastOpenedKey, info.version);

      if (!isFirstOpenAfterUpdate(lastOpened, info.version)) return null;

      final config = await loadConfig();
      if (config == null || config.notes.isEmpty) return null;
      // Only notes written for this very version.
      if (isNewer(config.version, info.version) ||
          isNewer(info.version, config.version)) {
        return null;
      }
      return config.notes;
    } catch (_) {
      return null;
    }
  }

  /// True when [installed] is newer than the version last opened. A
  /// first install has no last version, so it is not an update.
  static bool isFirstOpenAfterUpdate(String? lastOpened, String installed) {
    return lastOpened != null && isNewer(installed, lastOpened);
  }

  /// Whether version [candidate] is higher than [installed]. Accepts
  /// forms like `v1.2.0`, `1.2`, and `1.2.0+5`.
  static bool isNewer(String candidate, String installed) {
    final candidateParts = _numbers(candidate);
    final installedParts = _numbers(installed);
    if (candidateParts.isEmpty) return false;

    for (var index = 0; index < 3; index++) {
      final a = index < candidateParts.length ? candidateParts[index] : 0;
      final b = index < installedParts.length ? installedParts[index] : 0;
      if (a != b) return a > b;
    }

    return false;
  }

  /// Whether [version] reads as a version number, such as `1.7.0`.
  static bool isValidVersion(String version) =>
      RegExp(r'^v?\d+(\.\d+){0,2}$').hasMatch(version.trim());

  static List<int> _numbers(String version) {
    final match = RegExp(r'\d+(\.\d+){0,2}').firstMatch(version);
    if (match == null) return const [];

    return match.group(0)!.split('.').map(int.parse).toList();
  }
}
