import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Project + funding links (single source of truth).
const String kRepoOwner = 'RamazanBerk20';
const String kRepoName = 'chess';
const String repoUrl = 'https://github.com/$kRepoOwner/$kRepoName';
const String sponsorUrl = 'https://github.com/sponsors/$kRepoOwner';
const String _latestReleaseApi =
    'https://api.github.com/repos/$kRepoOwner/$kRepoName/releases/latest';

/// A newer release found on GitHub.
class UpdateInfo {
  final String version; // e.g. "1.0.1"
  final String htmlUrl; // release page
  final String? apkUrl; // android .apk asset, if present
  const UpdateInfo({required this.version, required this.htmlUrl, this.apkUrl});
}

/// Open [url] in the external browser. Returns false if it couldn't open.
Future<bool> openUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// The running app's version string (e.g. "1.0.0").
Future<String> currentVersion() async =>
    (await PackageInfo.fromPlatform()).version;

/// Query GitHub Releases for a version newer than the running build. Returns
/// null when up to date or the check fails (offline, rate-limited, no release).
Future<UpdateInfo?> checkForUpdate() async {
  try {
    final current = _parse((await PackageInfo.fromPlatform()).version);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final req = await client.getUrl(Uri.parse(_latestReleaseApi));
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    req.headers.set(HttpHeaders.userAgentHeader, 'chess-app');
    final resp = await req.close();
    if (resp.statusCode != 200) {
      client.close();
      return null;
    }
    final body = await resp.transform(utf8.decoder).join();
    client.close();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String?) ?? '';
    if (!_isNewer(_parse(tag), current)) return null;
    String? apkUrl;
    for (final a in (json['assets'] as List?) ?? const []) {
      final name = ((a as Map)['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apkUrl = a['browser_download_url'] as String?;
        break;
      }
    }
    return UpdateInfo(
      version: tag.replaceFirst(RegExp(r'^v'), ''),
      htmlUrl: (json['html_url'] as String?) ?? repoUrl,
      apkUrl: apkUrl,
    );
  } catch (_) {
    return null; // offline / parse error / rate-limited — fail quietly
  }
}

List<int> _parse(String v) => v
    .replaceFirst(RegExp(r'^v'), '')
    .split('+')
    .first
    .split('.')
    .map((p) => int.tryParse(p.trim()) ?? 0)
    .toList();

bool _isNewer(List<int> a, List<int> b) {
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
