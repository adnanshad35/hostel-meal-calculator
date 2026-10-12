import 'dart:async';
import 'dart:convert';
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
/// installed app (for example `v1.1.0`) is all it takes for users to
/// be asked to update.
class UpdateService {
  UpdateService._();

  static const String _latestReleaseUrl =
      'https://api.github.com/repos/adnanshad35/hostel-meal-calculator'
      '/releases/latest';

  /// Returns the available update, or null when the app is up to date
  /// or the check could not be completed.
  static Future<AppUpdate?> check() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);

    try {
      final info = await PackageInfo.fromPlatform();

      final request = await client.getUrl(Uri.parse(_latestReleaseUrl));
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );

      final response =
          await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != HttpStatus.ok) return null;

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));
      final release = jsonDecode(body);
      if (release is! Map<String, dynamic>) return null;

      return updateFromRelease(release, installedVersion: info.version);
    } catch (_) {
      // Offline or unexpected response: stay quiet and retry next launch.
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Reads a GitHub release and returns it as an update when it is
  /// newer than [installedVersion].
  static AppUpdate? updateFromRelease(
    Map<String, dynamic> release, {
    required String installedVersion,
  }) {
    if (release['draft'] == true || release['prerelease'] == true) {
      return null;
    }

    final tag = release['tag_name'];
    if (tag is! String || !isNewer(tag, installedVersion)) return null;

    // Prefer a direct APK download, otherwise open the release page.
    String? downloadUrl;
    final assets = release['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = asset['name'];
        final url = asset['browser_download_url'];
        if (name is String &&
            url is String &&
            name.toLowerCase().endsWith('.apk')) {
          downloadUrl = url;
          break;
        }
      }
    }

    downloadUrl ??= release['html_url'] as String?;
    if (downloadUrl == null) return null;

    final notes = release['body'];

    return AppUpdate(
      version: _numbers(tag).join('.'),
      downloadUrl: downloadUrl,
      notes: notes is String ? notes.trim() : '',
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
