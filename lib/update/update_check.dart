// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _repository = 'hirofumi-iwasaki/musha-bin-editor';
const _apiUrl = 'https://api.github.com/repos/$_repository/releases/latest';
const _maxResponseBytes = 1024 * 1024;
const _normalInterval = Duration(hours: 24);

abstract interface class UpdatePreferences {
  Future<bool?> getBool(String key);
  Future<int?> getInt(String key);
  Future<String?> getString(String key);
  Future<void> setBool(String key, bool value);
  Future<void> setInt(String key, int value);
  Future<void> setString(String key, String value);
}

class SharedUpdatePreferences implements UpdatePreferences {
  SharedUpdatePreferences(this._preferences);
  final SharedPreferences _preferences;

  static Future<SharedUpdatePreferences> create() async =>
      SharedUpdatePreferences(await SharedPreferences.getInstance());
  @override
  Future<bool?> getBool(String key) async => _preferences.getBool(key);
  @override
  Future<int?> getInt(String key) async => _preferences.getInt(key);
  @override
  Future<String?> getString(String key) async => _preferences.getString(key);
  @override
  Future<void> setBool(String key, bool value) async =>
      _preferences.setBool(key, value);
  @override
  Future<void> setInt(String key, int value) async =>
      _preferences.setInt(key, value);
  @override
  Future<void> setString(String key, String value) async =>
      _preferences.setString(key, value);
}

class ReleaseResponse {
  const ReleaseResponse(this.statusCode, this.headers, this.body);
  final int statusCode;
  final Map<String, String> headers;
  final String body;
}

abstract interface class ReleaseHttpClient {
  Future<ReleaseResponse> get(Uri url, Map<String, String> headers);
  void close();
}

class GithubReleaseHttpClient implements ReleaseHttpClient {
  GithubReleaseHttpClient() : _client = HttpClient();
  final HttpClient _client;
  var _closed = false;

  @override
  Future<ReleaseResponse> get(Uri url, Map<String, String> headers) async {
    final request = await _client.getUrl(url);
    headers.forEach(request.headers.set);
    final response = await request.close();
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > _maxResponseBytes) {
        throw const FormatException('Release response is too large.');
      }
    }
    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      if (values.isNotEmpty) responseHeaders[name.toLowerCase()] = values.first;
    });
    return ReleaseResponse(
      response.statusCode,
      responseHeaders,
      utf8.decode(bytes),
    );
  }

  @override
  void close() {
    if (!_closed) {
      _closed = true;
      _client.close(force: true);
    }
  }
}

abstract interface class ExternalLinkOpener {
  Future<bool> open(Uri url);
}

class SystemExternalLinkOpener implements ExternalLinkOpener {
  @override
  Future<bool> open(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}

enum RuntimeTarget {
  windowsX64,
  windowsArm64,
  linuxX64,
  linuxArm64,
  macosArm64,
  unsupported,
}

RuntimeTarget currentRuntimeTarget() {
  final abi = Abi.current();
  if (Platform.isWindows) {
    return abi == Abi.windowsX64
        ? RuntimeTarget.windowsX64
        : abi == Abi.windowsArm64
        ? RuntimeTarget.windowsArm64
        : RuntimeTarget.unsupported;
  }
  if (Platform.isLinux) {
    return abi == Abi.linuxX64
        ? RuntimeTarget.linuxX64
        : abi == Abi.linuxArm64
        ? RuntimeTarget.linuxArm64
        : RuntimeTarget.unsupported;
  }
  if (Platform.isMacOS && abi == Abi.macosArm64) {
    return RuntimeTarget.macosArm64;
  }
  return RuntimeTarget.unsupported;
}

String? _assetName(RuntimeTarget target) => switch (target) {
  RuntimeTarget.windowsX64 => 'musha-bin-edit-windows-x64.zip',
  RuntimeTarget.windowsArm64 => 'musha-bin-edit-windows-arm64.zip',
  RuntimeTarget.linuxX64 => 'musha-bin-edit-linux-x64.tar.gz',
  RuntimeTarget.linuxArm64 => 'musha-bin-edit-linux-arm64.tar.gz',
  RuntimeTarget.macosArm64 => 'musha-bin-edit-macos.zip',
  RuntimeTarget.unsupported => null,
};

class StableVersion implements Comparable<StableVersion> {
  const StableVersion(this.major, this.minor, this.patch);
  final int major;
  final int minor;
  final int patch;

  static StableVersion? parse(String value) {
    final match = RegExp(
      r'^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\+\d+)?$',
    ).firstMatch(value);
    if (match == null) return null;
    return StableVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }

  static StableVersion? parseReleaseTag(String value) {
    if (value.contains('+')) return null;
    return parse(value);
  }

  @override
  int compareTo(StableVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final result = pair.$1.compareTo(pair.$2);
      if (result != 0) return result;
    }
    return 0;
  }

  @override
  String toString() => '$major.$minor.$patch';
}

class UpdateOffer {
  const UpdateOffer({
    required this.version,
    required this.tag,
    required this.url,
    required this.linkLabel,
  });
  final StableVersion version;
  final String tag;
  final Uri url;
  final String linkLabel;
}

class UpdateCheckController extends ChangeNotifier {
  UpdateCheckController({
    required this.installedVersion,
    required this._preferences,
    required this._httpClient,
    required this._opener,
    required this._now,
    RuntimeTarget? runtimeTarget,
    this._clientFactory,
    this._requestTimeout = const Duration(seconds: 5),
  }) : _runtimeTarget = runtimeTarget ?? currentRuntimeTarget();

  static Future<UpdateCheckController> create() async {
    final info = await PackageInfo.fromPlatform();
    return UpdateCheckController(
      installedVersion: info.version,
      preferences: await SharedUpdatePreferences.create(),
      httpClient: GithubReleaseHttpClient(),
      clientFactory: GithubReleaseHttpClient.new,
      opener: SystemExternalLinkOpener(),
      now: DateTime.now,
    );
  }

  final String installedVersion;
  final UpdatePreferences _preferences;
  ReleaseHttpClient _httpClient;
  final ReleaseHttpClient Function()? _clientFactory;
  final Duration _requestTimeout;
  final ExternalLinkOpener _opener;
  final DateTime Function() _now;
  final RuntimeTarget _runtimeTarget;
  UpdateOffer? _offer;
  bool _disposed = false;
  bool _checking = false;

  UpdateOffer? get offer => _offer;
  bool get checking => _checking;

  Future<void> checkAutomatic() => _check(manual: false);
  Future<void> checkNow() => _check(manual: true);

  Future<void> _check({required bool manual}) async {
    if (_disposed || _checking) return;
    _checking = true;
    try {
      if ((await _preferences.getBool('autoUpdateCheckEnabled')) == false) {
        return;
      }
      if (_disposed) return;
      final now = _now();
      final backoff = _date(await _preferences.getInt('updateBackoffUntil'));
      final cached = await _cachedOffer();
      if (_disposed) return;
      if (cached != null) _setOffer(cached);
      if (backoff != null && now.isBefore(backoff)) return;
      if (!manual) {
        final validated = _date(
          await _preferences.getInt('updateLastValidatedAt'),
        );
        if (_disposed) return;
        if (validated != null && now.difference(validated) < _normalInterval) {
          return;
        }
      }
      await _preferences.setInt(
        'updateLastAttemptAt',
        now.millisecondsSinceEpoch,
      );
      final etag = await _preferences.getString('updateEtag');
      if (_disposed) return;
      final headers = <String, String>{
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'mushagaeshi-binary-editor/$installedVersion',
      };
      if (etag != null && etag.isNotEmpty) headers['If-None-Match'] = etag;
      final response = await _httpClient
          .get(Uri.parse(_apiUrl), headers)
          .timeout(
            _requestTimeout,
            onTimeout: () {
              _httpClient.close();
              if (!_disposed && _clientFactory != null) {
                _httpClient = _clientFactory();
              }
              throw TimeoutException('GitHub release request timed out.');
            },
          );
      if (_disposed) return;
      if (response.statusCode == 200) {
        final offer = _validateOffer(response.body);
        if (offer != null) {
          await _saveValidatedOffer(offer, response.headers['etag']);
        } else {
          await _clearCachedOffer();
        }
        await _success();
        _setOffer(offer);
      } else if (response.statusCode == 304) {
        final cached = await _cachedOffer();
        if (cached == null) {
          await _clearCachedOffer();
          await _transientFailure();
        } else {
          await _success();
        }
        _setOffer(cached);
      } else if (response.statusCode == 404) {
        await _clearCachedOffer();
        await _success();
        _setOffer(null);
      } else if (response.statusCode == 403 || response.statusCode == 429) {
        await _rateLimitFailure(response.headers);
      } else {
        await _transientFailure();
      }
    } catch (_) {
      if (!_disposed) {
        try {
          await _transientFailure();
        } catch (_) {
          // Persistence failures are as silent as network failures.
        }
      }
    } finally {
      _checking = false;
    }
  }

  UpdateOffer? _validateOffer(String body) {
    final installed = StableVersion.parse(installedVersion);
    if (installed == null) return null;
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final tag = json['tag_name'];
      final page = json['html_url'];
      if (tag is! String || page is! String) return null;
      final version = StableVersion.parseReleaseTag(tag);
      if (json['draft'] != false ||
          json['prerelease'] != false ||
          version == null ||
          version.compareTo(installed) <= 0) {
        return null;
      }
      final pageUrl = _validReleasePage(Uri.tryParse(page), tag);
      if (pageUrl == null) return null;
      final expectedAsset = _assetName(_runtimeTarget);
      if (expectedAsset != null && json['assets'] is List) {
        for (final asset in json['assets'] as List) {
          if (asset is! Map ||
              asset['name'] != expectedAsset ||
              asset['state'] != 'uploaded') {
            continue;
          }
          final download = asset['browser_download_url'];
          final url = download is String
              ? _validAsset(Uri.tryParse(download), tag, expectedAsset)
              : null;
          if (url != null) {
            return UpdateOffer(
              version: version,
              tag: tag,
              url: url,
              linkLabel: 'Download',
            );
          }
        }
      }
      return UpdateOffer(
        version: version,
        tag: tag,
        url: pageUrl,
        linkLabel: 'View release',
      );
    } catch (_) {
      return null;
    }
  }

  bool _trustedGithubUri(Uri? uri) =>
      uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'github.com' &&
      (uri.port == 443 || !uri.hasPort) &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;
  Uri? _validReleasePage(Uri? uri, String tag) =>
      _trustedGithubUri(uri) && uri!.path == '/$_repository/releases/tag/$tag'
      ? uri
      : null;
  Uri? _validAsset(Uri? uri, String tag, String name) =>
      _trustedGithubUri(uri) &&
          uri!.path == '/$_repository/releases/download/$tag/$name'
      ? uri
      : null;

  Future<void> _saveValidatedOffer(UpdateOffer offer, String? etag) async {
    await _preferences.setString(
      'updateCachedOffer',
      jsonEncode({
        'tag': offer.tag,
        'url': offer.url.toString(),
        'label': offer.linkLabel,
      }),
    );
    await _preferences.setString(
      'updateEtag',
      etag != null && etag.length <= 1024 ? etag : '',
    );
  }

  Future<void> _clearCachedOffer() async {
    await _preferences.setString('updateCachedOffer', '');
    await _preferences.setString('updateEtag', '');
  }

  Future<UpdateOffer?> _cachedOffer() async {
    try {
      final raw = await _preferences.getString('updateCachedOffer');
      if (raw == null || raw.isEmpty || raw.length > 4096) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final tag = json['tag'];
      final rawUrl = json['url'];
      final label = json['label'];
      if (tag is! String || rawUrl is! String || label is! String) return null;
      final version = StableVersion.parseReleaseTag(tag);
      final url = Uri.tryParse(rawUrl);
      final installed = StableVersion.parse(installedVersion);
      if (version == null ||
          installed == null ||
          version.compareTo(installed) <= 0 ||
          url == null ||
          (label != 'Download' && label != 'View release')) {
        return null;
      }
      final valid = label == 'Download'
          ? _validAsset(url, tag, _assetName(_runtimeTarget) ?? '')
          : _validReleasePage(url, tag);
      return valid == null
          ? null
          : UpdateOffer(
              version: version,
              tag: tag,
              url: valid,
              linkLabel: label,
            );
    } catch (_) {
      return null;
    }
  }

  Future<void> _success() async {
    await _preferences.setInt(
      'updateLastValidatedAt',
      _now().millisecondsSinceEpoch,
    );
    await _preferences.setInt('updateFailureCount', 0);
    await _preferences.setInt('updateBackoffUntil', 0);
  }

  Future<void> _rateLimitFailure(Map<String, String> headers) async {
    final now = _now();
    DateTime until = now.add(const Duration(hours: 1));
    if (headers['x-ratelimit-remaining'] == '0') {
      final reset = int.tryParse(headers['x-ratelimit-reset'] ?? '');
      if (reset != null) {
        until = DateTime.fromMillisecondsSinceEpoch(reset * 1000);
      }
    }
    final retryAfter = int.tryParse(headers['retry-after'] ?? '');
    if (retryAfter != null) {
      until = _later(until, now.add(Duration(seconds: retryAfter)));
    }
    await _preferences.setInt(
      'updateBackoffUntil',
      until.millisecondsSinceEpoch,
    );
  }

  Future<void> _transientFailure() async {
    final previous = await _preferences.getInt('updateFailureCount') ?? 0;
    final count = (previous + 1).clamp(1, 3);
    final hours = count == 1
        ? 1
        : count == 2
        ? 6
        : 24;
    final until = _now().add(Duration(hours: hours, minutes: count * 2));
    await _preferences.setInt('updateFailureCount', count);
    await _preferences.setInt(
      'updateBackoffUntil',
      until.millisecondsSinceEpoch,
    );
  }

  DateTime? _date(int? millis) => millis == null || millis <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis);
  DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  void _setOffer(UpdateOffer? offer) {
    if (_disposed) return;
    _offer = offer;
    notifyListeners();
  }

  Future<void> openOffer() async {
    final offer = _offer;
    if (offer == null || _disposed) return;
    try {
      await _opener.open(offer.url);
    } catch (_) {
      // A launcher failure is intentionally silent.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _httpClient.close();
    super.dispose();
  }
}
