import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mushagaeshi_binary_editor/main.dart';
import 'package:mushagaeshi_binary_editor/update/update_check.dart';

class MemoryPreferences implements UpdatePreferences {
  final values = <String, Object>{};
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<int?> getInt(String key) async => values[key] as int?;
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> setInt(String key, int value) async => values[key] = value;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

class FakeHttpClient implements ReleaseHttpClient {
  FakeHttpClient(this.response);
  ReleaseResponse response;
  Map<String, String>? requestHeaders;
  var calls = 0;
  var closed = false;
  @override
  Future<ReleaseResponse> get(Uri _, Map<String, String> headers) async {
    calls++;
    requestHeaders = headers;
    return response;
  }

  @override
  void close() => closed = true;
}

class PendingHttpClient extends FakeHttpClient {
  PendingHttpClient() : super(const ReleaseResponse(500, {}, ''));
  final responseCompleter = Completer<ReleaseResponse>();
  @override
  Future<ReleaseResponse> get(Uri _, Map<String, String> headers) {
    calls++;
    requestHeaders = headers;
    return responseCompleter.future;
  }
}

class ThrowingPreferences extends MemoryPreferences {
  @override
  Future<bool?> getBool(String key) => Future<bool?>.error(StateError('disk'));
}

class FakeOpener implements ExternalLinkOpener {
  Uri? opened;
  @override
  Future<bool> open(Uri url) async {
    opened = url;
    return true;
  }
}

String release({String tag = 'v0.6.0', String? asset, String? assetUrl}) =>
    '''
{"tag_name":"$tag","html_url":"https://github.com/hirofumi-iwasaki/musha-bin-editor/releases/tag/$tag","draft":false,"prerelease":false,"assets":[${asset == null ? '' : '{"name":"$asset","state":"uploaded","browser_download_url":"$assetUrl"}'}]}
''';

UpdateCheckController controller(
  MemoryPreferences prefs,
  FakeHttpClient http,
  FakeOpener opener, {
  RuntimeTarget target = RuntimeTarget.windowsX64,
  DateTime? now,
  Duration timeout = const Duration(seconds: 5),
  ReleaseHttpClient Function()? clientFactory,
}) => UpdateCheckController(
  installedVersion: '0.5.0+5',
  preferences: prefs,
  httpClient: http,
  opener: opener,
  now: () => now ?? DateTime.utc(2026, 1, 1),
  runtimeTarget: target,
  requestTimeout: timeout,
  clientFactory: clientFactory,
);

void cacheOffer(MemoryPreferences prefs) {
  prefs.values['updateCachedOffer'] = '{"tag":"v0.6.0","url":"https://github.com/hirofumi-iwasaki/musha-bin-editor/releases/tag/v0.6.0","label":"View release"}';
  prefs.values['updateEtag'] = 'old';
}

void main() {
  test(
    'parses stable installed versions and rejects prerelease release tags',
    () {
      expect(StableVersion.parse('0.5.0+5')!.toString(), '0.5.0');
      expect(
        StableVersion.parse('v0.6.0')!.compareTo(StableVersion.parse('0.5.0')!),
        greaterThan(0),
      );
      expect(StableVersion.parseReleaseTag('0.6.0+1'), isNull);
      expect(StableVersion.parseReleaseTag('0.6.0-rc.1'), isNull);
      expect(StableVersion.parse('01.6.0'), isNull);
    },
  );

  test('selects an exact uploaded asset and sends/saves ETag', () async {
    final prefs = MemoryPreferences();
    final http = FakeHttpClient(
      ReleaseResponse(
        200,
        {'etag': 'etag-1'},
        release(
          asset: 'musha-bin-edit-windows-x64.zip',
          assetUrl: 'https://github.com/hirofumi-iwasaki/musha-bin-editor/releases/download/v0.6.0/musha-bin-edit-windows-x64.zip',
        ),
      ),
    );
    final opener = FakeOpener();
    final check = controller(prefs, http, opener);
    await check.checkAutomatic();
    expect(check.offer?.linkLabel, 'Download');
    expect(check.offer?.version.toString(), '0.6.0');
    expect(prefs.values['updateEtag'], 'etag-1');
    await check.openOffer();
    expect(opener.opened, check.offer?.url);

    prefs.values['updateLastValidatedAt'] = 0;
    await check.checkAutomatic();
    expect(http.requestHeaders?['If-None-Match'], 'etag-1');
  });

  test('falls back to release page and rejects untrusted asset URLs', () async {
    final prefs = MemoryPreferences();
    final http = FakeHttpClient(
      ReleaseResponse(
        200,
        const {},
        release(
          asset: 'musha-bin-edit-windows-x64.zip',
          assetUrl: 'https://evil.example/download.zip',
        ),
      ),
    );
    final check = controller(prefs, http, FakeOpener());
    await check.checkAutomatic();
    expect(check.offer?.linkLabel, 'View release');

    final badPage = release().replaceFirst(
      'https://github.com/',
      'https://user@github.com/',
    );
    http.response = ReleaseResponse(200, const {}, badPage);
    prefs.values['updateLastValidatedAt'] = 0;
    await check.checkAutomatic();
    expect(check.offer, isNull);
  });

  test('304 without a valid cache clears ETag and backs off', () async {
    final prefs = MemoryPreferences()..values['updateEtag'] = 'old';
    final http = FakeHttpClient(const ReleaseResponse(304, {}, ''));
    final check = controller(prefs, http, FakeOpener());
    await check.checkAutomatic();
    expect(prefs.values['updateEtag'], '');
    expect(prefs.values['updateBackoffUntil'], isA<int>());
    expect(prefs.values['updateLastValidatedAt'], isNull);
  });

  test('disabled and cadence checks do not request', () async {
    final prefs = MemoryPreferences()
      ..values['autoUpdateCheckEnabled'] = false
      ..values['updateLastValidatedAt'] = DateTime.utc(
        2026,
        1,
        1,
      ).millisecondsSinceEpoch;
    final http = FakeHttpClient(const ReleaseResponse(500, {}, ''));
    final check = controller(prefs, http, FakeOpener());
    await check.checkAutomatic();
    expect(http.calls, 0);
  });

  test(
    'timeout closes the active client and a concurrent check does not overlap',
    () async {
      final prefs = MemoryPreferences();
      final pending = PendingHttpClient();
      final replacement = FakeHttpClient(const ReleaseResponse(404, {}, ''));
      final check = controller(
        prefs,
        pending,
        FakeOpener(),
        timeout: Duration.zero,
        clientFactory: () => replacement,
      );
      final first = check.checkAutomatic();
      final second = check.checkAutomatic();
      await Future.wait([first, second]);
      expect(pending.calls, 1);
      expect(pending.closed, isTrue);
      prefs.values['updateBackoffUntil'] = 0;
      await check.checkNow();
      expect(replacement.calls, 1);
    },
  );

  test(
    'dispose before or during a check prevents networking and notifications',
    () async {
      final prefs = MemoryPreferences();
      final unused = FakeHttpClient(const ReleaseResponse(200, {}, ''));
      final stopped = controller(prefs, unused, FakeOpener())..dispose();
      await stopped.checkAutomatic();
      expect(unused.calls, 0);

      final pending = PendingHttpClient();
      final running = controller(prefs, pending, FakeOpener());
      final future = running.checkAutomatic();
      await Future<void>.delayed(Duration.zero);
      running.dispose();
      pending.responseCompleter.complete(
        ReleaseResponse(200, const {}, release()),
      );
      await future;
      expect(running.offer, isNull);
    },
  );

  test('preference failures are silent', () async {
    final check = controller(
      ThrowingPreferences(),
      FakeHttpClient(const ReleaseResponse(500, {}, '')),
      FakeOpener(),
    );
    await check.checkAutomatic();
    expect(check.offer, isNull);
  });

  test('equal response and 404 invalidate a previously cached offer', () async {
    final prefs = MemoryPreferences();
    cacheOffer(prefs);
    final http = FakeHttpClient(
      ReleaseResponse(200, const {}, release(tag: 'v0.5.0')),
    );
    final check = controller(prefs, http, FakeOpener());
    await check.checkAutomatic();
    expect(check.offer, isNull);
    expect(prefs.values['updateCachedOffer'], '');
    expect(prefs.values['updateEtag'], '');

    http.response = ReleaseResponse(200, const {}, release(tag: 'v0.6.0'));
    prefs.values['updateLastValidatedAt'] = 0;
    await check.checkAutomatic();
    expect(check.offer?.version.toString(), '0.6.0');

    cacheOffer(prefs);
    prefs.values['updateLastValidatedAt'] = 0;
    http.response = const ReleaseResponse(404, {}, '');
    await check.checkAutomatic();
    expect(check.offer, isNull);
    expect(prefs.values['updateCachedOffer'], '');
  });

  test(
    'cached offer is restored before cadence and rate-limit backoff is honored',
    () async {
      final prefs = MemoryPreferences();
      cacheOffer(prefs);
      prefs.values['updateLastValidatedAt'] = DateTime.utc(
        2026,
        1,
        1,
      ).millisecondsSinceEpoch;
      final cached = controller(
        prefs,
        FakeHttpClient(const ReleaseResponse(500, {}, '')),
        FakeOpener(),
      );
      await cached.checkAutomatic();
      expect(cached.offer?.linkLabel, 'View release');

      prefs.values['updateLastValidatedAt'] = 0;
      final limited = FakeHttpClient(
        const ReleaseResponse(429, {'retry-after': '7200'}, ''),
      );
      final check = controller(prefs, limited, FakeOpener());
      await check.checkAutomatic();
      expect(
        prefs.values['updateBackoffUntil'],
        greaterThan(DateTime.utc(2026, 1, 1, 1).millisecondsSinceEpoch),
      );
    },
  );

  testWidgets(
    'shows a compact update link only after the injected checker finds one',
    (tester) async {
      final prefs = MemoryPreferences();
      final opener = FakeOpener();
      final http = FakeHttpClient(
        ReleaseResponse(
          200,
          const {},
          release(
            asset: 'musha-bin-edit-windows-x64.zip',
            assetUrl: 'https://github.com/hirofumi-iwasaki/musha-bin-editor/releases/download/v0.6.0/musha-bin-edit-windows-x64.zip',
          ),
        ),
      );
      final check = controller(prefs, http, opener);
      await tester.pumpWidget(MushagaeshiBinaryEditorApp(updateChecker: check));
      await tester.pumpAndSettle();
      expect(find.text('Update 0.6.0 available'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Download'), findsOneWidget);
      await tester.tap(find.text('Download'));
      await tester.pump();
      expect(opener.opened, check.offer?.url);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
