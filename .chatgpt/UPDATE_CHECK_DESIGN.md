# Update Check Design

## Status and scope

This document designs an **update notification only** feature for the desktop
application. It does not download, install, or apply updates. The update check
must never delay startup, opening files, comparison, editing, saving, or
shutdown.

The baseline is `release/0.5.0` at `506bda6`. The public repository is
`hirofumi-iwasaki/musha-bin-editor`. The current application version is
`0.4.0+4` in `pubspec.yaml`; the `0.5.0` release must first set the release
version there, so the runtime version and the release tag can be compared.

## Decision record (ADR-UC-001)

### Context

The product is a Flutter desktop app for macOS, Windows, and Linux. It already
uses an application-owned bottom status row in `CompareWindow`, but has no
network client, package metadata reader, URL launcher, or update UI.

GitHub's `GET /repos/{owner}/{repo}/releases/latest` endpoint returns the
latest *published full* release: it excludes drafts and prereleases. GitHub
defines “latest” by the release target commit's `created_at`, rather than the
time a release was drafted or published. Consequently, it is not a Semantic
Version ordering operation. A release whose target commit has an older date can
be a semantically newer version and still not be returned by this endpoint.

### Proposed decision

Use the GitHub `releases/latest` endpoint as the sole automatic discovery
request (a proposed implementation choice). Treat its `tag_name` as an update only if it parses as a
stable Semantic Version and is strictly greater than the installed app version.
Do not list releases or select a tag by sorting tags locally. This makes the
feature match GitHub's published “latest release” setting while preventing an
older or malformed tag from being offered as an upgrade.

If the returned release has no compatible asset, show the release page, not an
invented archive URL. The feature opens a link only after the user clicks it.

### Consequences

* A maintainer who republishes version order out of target-commit order can
  cause a newer semver release not to be automatically discovered. Release
  publishing must therefore target a suitably recent commit, or the policy can
  later be deliberately changed to `GET /releases` plus stable SemVer maximum.
* Drafts and prereleases remain invisible. Tags such as `v0.5.0` are accepted
  after a single leading `v` is removed; pre-release identifiers and build
  metadata are not candidates for this stable-only channel.
* The app needs outbound-network capability in sandboxed macOS Release and
  Debug/Profile builds.

## Recommended behavior

1. After `runApp`, schedule one check after the first frame. It starts on the
   normal Dart event loop and is deliberately unawaited by application startup.
2. Respect the stored preference. The default is enabled; an explicit user
   choice disables all automatic checks. A future settings UI may also expose
   “Check now”.
3. Before a request, consult persisted update-check state. Do not request again
   until the normal interval has elapsed. Recommended normal interval: 24 hours
   from the last completed successful validation (200 or 304). A manual check
   bypasses that interval but still respects an active server-directed backoff.
4. Request:

   ```text
   GET https://api.github.com/repos/hirofumi-iwasaki/musha-bin-editor/releases/latest
   Accept: application/vnd.github+json
   X-GitHub-Api-Version: <current supported GitHub API version>
   User-Agent: mushagaeshi-binary-editor/<installed-version>
   If-None-Match: <persisted ETag, if any>
   ```

   Do not attach an `Authorization` header, a PAT, OAuth credentials, or any
   secret. The repository is public and the endpoint supports unauthenticated
   access. The request sends no file contents, paths, hashes, comparison data,
   edits, account identity, or telemetry. GitHub and the network operator can
   observe the originating IP address and the limited User-Agent.
5. Bound the entire request and response read by a 5-second timeout and a 1 MiB response limit. Allow one
   in-flight request at a time. If disposed, cancel/close the client and ignore
   its result; no callback may update an unmounted widget.
6. On `304`, retain the previously validated result, record the successful
   check time, and do not show a notification unless a prior cached update was
   already relevant. On `200`, validate the small JSON schema, persist the
   response ETag if present, and evaluate the release. On `404`, treat the
   repository as having no published full release and retry only at the normal
   interval. Other results are failures.
7. Compare SemVer core versions (`major.minor.patch`) numerically. A
   production release requires exactly that stable form after optional `v`;
   reject malformed, pre-release, and build-metadata tags for automatic offer.
   Parse the installed version from package metadata, ignoring Flutter's `+`
   build number for precedence. `0.5.0+5` and `0.5.0+6` are equal for this
   stable release comparison.
8. When a newer release is found, select a compatible uploaded asset using the
   exact release asset names described below. Display one compact notification
   in the bottom status row: `Update 0.5.0 available` and a user-clickable
   `Download` link. Use its `browser_download_url` if a compatible asset exists;
   otherwise label the link `View release` and open `html_url`.
9. Opening the link is a direct, user-initiated call to the platform URL
   launcher. The service validates a release-page URL as HTTPS, host exactly
   `github.com`, and path exactly
   `/hirofumi-iwasaki/musha-bin-editor/releases/tag/<validated-tag>`. It
   validates an asset URL as HTTPS, host exactly `github.com`, and path exactly
   `/hirofumi-iwasaki/musha-bin-editor/releases/download/<validated-tag>/<expected-asset>`.
   The external browser may follow GitHub's download redirect itself; the app
   must never receive or launch an arbitrary redirect target. Reject all other
   schemes, hosts, and paths. The app otherwise performs no update download or
   installation.
10. Network errors, malformed JSON, timeouts, unsupported tags, missing
    assets, launch failures, and rate limits are silent during automatic checks:
    they neither replace the comparison error panel nor show a SnackBar. A
    future explicit “Check now” action may present a concise local result.

## Cache, rate-limit, and retry policy

Persist only these update-specific preferences/state values in an appropriate
small local preferences store:

* `autoUpdateCheckEnabled` (default `true`)
* `lastValidatedAt` and `lastAttemptAt`
* ETag, validated release tag, validated release page URL, and selected asset
  name/URL only after validation
* `backoffUntil` and a bounded failure count
* optionally, the last notified version so a restart does not repeatedly
  announce the same release

No source file data or comparison state belongs in this store. Keep a cached
release only as a convenience; it is not authorization to open its URL without
revalidating it.

For unauthenticated public API access, GitHub documents a 60-requests-per-hour
primary limit per originating IP. The 24-hour cadence is intentionally far
below that. Send the saved ETag with `If-None-Match`; a 304 avoids decoding and
refreshes the local validation timestamp. GitHub's documentation says 304
responses are rate-limit-free only when correctly authorized, so this client
must not assume an unauthenticated 304 has zero cost.

On `403`/`429` with `x-ratelimit-remaining: 0`, set `backoffUntil` to
`x-ratelimit-reset` when valid, otherwise one hour from now. Honor `Retry-After`
when it is later. For transient timeout, DNS, TLS, connection, and 5xx failures,
use exponential retry only on later application launches/check opportunities:
1 hour, 6 hours, then 24 hours maximum, with small bounded jitter. Reset the
failure count after a 200 or 304. Never retry in a foreground loop and never
make concurrent release calls.

## Asset compatibility contract

The release producer and update checker share this exact asset naming contract:

| Runtime target | Required asset name |
| --- | --- |
| Windows x64 | `musha-bin-edit-windows-x64.zip` |
| Windows Arm64 | `musha-bin-edit-windows-arm64.zip` |
| Linux x64 | `musha-bin-edit-linux-x64.tar.gz` |
| Linux Arm64 | `musha-bin-edit-linux-arm64.tar.gz` |
| macOS Arm64 | `musha-bin-edit-macos.zip` |

Determine the runtime family with `Platform.isWindows`, `Platform.isLinux`, and
`Platform.isMacOS`. Determine CPU architecture through a small platform
abstraction/native value that returns only `x64` or `arm64`; do not infer it
from archive naming, process strings, or an unverified environment variable.
The current release plan supports only macOS Arm64. On an unsupported target or
when no exact uploaded asset (`state == uploaded`) is present, offer the
validated GitHub release page. This preserves visibility without claiming a
compatible download exists.

The app must not extract archives, verify archive checksums, replace binaries,
or restart itself. Those activities are explicitly outside this design.

## Proposed implementation boundaries

This section identifies future code locations; it is not an implementation
change.

| Area | Current evidence | Proposed change |
| --- | --- | --- |
| Application startup | `lib/main.dart`: `main()` initializes Flutter and immediately calls `runApp`. | Create and own an `UpdateCheckController`/service at app level; schedule the first unawaited check using `addPostFrameCallback` in `CompareWindow.initState`, after the UI is visible. Pass a read-only notifier/model into the window. |
| Status-bar presentation | `lib/main.dart`: `CompareWindow` has a 42px hash bar and then the final `Wrap` status row containing `controller.status` near lines 900–950. | Add the update text/link to that final status row. Keep it separate from `CompareController.error`, which is reserved for file/comparison errors near lines 782–791. |
| Lifecycle | `lib/main.dart`: `_CompareWindowState.dispose()` already disposes UI resources and desktop integration. | Dispose the update controller/client there, or above it in the app owner, and guard all completions with `mounted` / controller disposed state. |
| Version source | `pubspec.yaml`: currently `version: 0.4.0+4`; macOS `Info.plist` uses `FLUTTER_BUILD_NAME` and `FLUTTER_BUILD_NUMBER`. | Add a package metadata dependency supported by Flutter desktop (for example `package_info_plus`) and make the package version the single installed-version source. Before publishing 0.5.0, set `pubspec.yaml` to the agreed 0.5.0 build version. |
| HTTP and persistence | No HTTP client or preferences package is present in `pubspec.yaml`. | Add a narrowly scoped HTTPS client and a preference store. Inject abstractions for clock, HTTP, preferences, and URL launcher so tests do not use the network or filesystem. |
| External URLs | No URL launcher is present. | Add a launcher behind `ExternalLinkOpener`; validate scheme/host before calling it, and call it only from the status link's user gesture. |
| Platform architecture | `lib/platform/desktop_platform.dart` centralizes desktop distinctions and already imports `dart:io`. | Extend or add a neighboring `platform/runtime_target.dart` boundary for OS/architecture. Keep network/update policy in Dart, not native runner code. |
| macOS sandbox | `macos/Runner/Release.entitlements` currently allows app sandbox and user-selected read/write files only. `DebugProfile.entitlements` contains `network.server`, which does not grant outbound client access. | Add `com.apple.security.network.client` = true to both Release and DebugProfile entitlements. Preserve existing file permissions; server entitlement is unrelated to outbound update checks. |
| Packaging/release contract | `README.md` documents the five expected v0.4.0 release asset names; `tool/build_windows.ps1` and `tool/build_linux.sh` generate four matching archives. | Keep the names stable and make macOS packaging produce the documented `musha-bin-edit-macos.zip`. Verify the published release contains every named asset. |

`CompareController` already uses isolates for large file comparison and hashing.
The update check must not use an isolate: HTTPS I/O is asynchronous and
non-blocking on the Dart event loop, JSON is tiny, and spawning an isolate
would add lifecycle, message-passing, and cancellation complexity with no
responsiveness benefit. The controller must be independent of comparison jobs
so an update check cannot contend with their cancellation or state.

## State model

```text
disabled ──────────────────────────────> idle
startup (after first frame) ───────────> eligible?
eligible + no active backoff ──────────> checking
checking + 200 + newer + valid link ───> updateAvailable
checking + 200/304 + no newer ─────────> idle
checking + 403/429 ────────────────────> backedOff
checking + network/parse/5xx failure ──> idle (next eligible time delayed)
dispose ───────────────────────────────> disposed
```

The UI binds only to `updateAvailable`. All other automatic states are silent.
The status notification is non-modal and must not take keyboard focus.

## Verification plan

Unit tests using a fake HTTP client, fake clock, fake preferences, and fake
link opener should cover:

* installed/release SemVer parsing and strict ordering, including `v` prefix,
  `+` build number, prerelease, malformed tag, equal, and downgrade cases;
* 200 with matching, missing, and wrong-architecture assets; fallback to
  `html_url`; and rejection of non-HTTPS/unapproved-host URLs;
* ETag save/send, 304 handling, 404, timeout, malformed JSON, 5xx, rate-limit
  reset, Retry-After, cadence, exponential backoff, and one in-flight request;
* disabled preference, manual-check interval bypass, disposal before completion,
  and no automatic visible error;
* UI notification visibility, accessible label, and a user click causing only
  the validated link opener invocation.

Run static analysis and the existing test suite after implementation. Build
Debug/Profile and Release macOS applications and inspect their signed
entitlements with `codesign -d --entitlements :-`. On clean supported Windows,
Linux, and macOS systems, use a controlled fake release endpoint or injected
test service to verify first-frame responsiveness, correct asset link/fallback,
blocked automatic launch, and silent offline/rate-limited behavior. Finally,
perform a public GitHub release smoke test after publishing a stable 0.5.0
release with all five assets.

## Open items and minimal defaults

These do not block the design or the release branch:

* **Exact 0.5.0 build number:** choose the package build suffix during release
  preparation; recommendation: increment from `+4` to `0.5.0+5` unless the
  release process assigns a different monotonic number.
* **Settings surface:** start with automatic checks enabled and no visible
  settings UI if the release scope cannot include one. Persist the flag now so
  a later Preferences command can expose it without changing the checker.
* **macOS x64 support:** the documented release assets have only macOS Arm64;
  macOS x64 therefore falls back to the release page.
* **GitHub's non-SemVer latest ordering:** retain the proposed endpoint policy
  for 0.5.0. Revisit only if the maintainer needs SemVer-max selection across
  releases.

## Sources

* GitHub, [Get the latest release](https://docs.github.com/en/rest/releases/releases#get-the-latest-release): endpoint, public unauthenticated access, and latest-release definition.
* GitHub, [Best practices for the REST API](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api): ETag/`If-None-Match` conditional requests and 304 behavior.
* GitHub, [Rate limits for the REST API](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api): unauthenticated IP-based 60/hour limit, response rate-limit headers, and 403/429 reset handling.
* Project sources cited in the implementation-boundaries table, inspected at `release/0.5.0` commit `506bda6`.

## Implementation sequence

1. Implement and test the isolated update service, version comparison, cache and URL/asset selection.
2. Integrate after-first-frame startup and the independent status-row notification.
3. Add desktop metadata/URL support and macOS outbound-network entitlements.
4. Extend the CI push trigger to `release/0.5.0`; run analysis, tests and native builds.
5. Verify offline startup, disposal, editing responsiveness and download links on supported platforms.

The user approved the feature requirements; the interval, timeout, dependencies and detailed policy above remain design proposals. Implementation has not started.
