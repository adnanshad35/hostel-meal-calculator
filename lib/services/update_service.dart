import 'dart:async';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// A newer version of the app that is available to download.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.downloadUrl,
    this.notes = '',
  });

  final String version;
  final String downloadUrl;
  final String notes;
}

/// Checks the project's GitHub releases for a newer version.
///
/// Publishing a release tagged with a higher version than the
/// installed app (for example `v1.1.0`), with the APK attached as
/// `HostelMate.apk`, is all it takes for users to be asked to update.
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

  /// Returns the available update, or null when the app is up to date
  /// or the check could not be completed.
  static Future<AppUpdate?> check() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);

    try {
      final info = await PackageInfo.fromPlatform();

      final request = await client.getUrl(Uri.parse(_latestReleaseUrl));
      request.followRedirects = false;

      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();

      return updateFromLocation(location, installedVersion: info.version);
    } catch (_) {
      // Offline or unexpected response: stay quiet and retry next launch.
      return null;
    } finally {
      client.close(force: true);
    }
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

  static List<int> _numbers(String version) {
    final match = RegExp(r'\d+(\.\d+){0,2}').firstMatch(version);
    if (match == null) return const [];

    return match.group(0)!.split('.').map(int.parse).toList();
  }
}
