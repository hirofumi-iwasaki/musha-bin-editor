// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../infrastructure/safe_save.dart';

/// Platform boundary for dialogs, native drops and close interception.
///
/// macOS retains the existing Runner implementation. Windows and Linux use
/// Flutter-published desktop plugins so widgets do not need platform checks.
enum DesktopPane { left, right }

sealed class DesktopEvent {
  const DesktopEvent();
}

class DesktopFileDropped extends DesktopEvent {
  const DesktopFileDropped(this.path, {this.position, this.pane});
  final String path;
  final ({double x, double y})? position;
  final DesktopPane? pane;
}

class DesktopDropHoverChanged extends DesktopEvent {
  const DesktopDropHoverChanged({this.position, this.pane});
  final ({double x, double y})? position;
  final DesktopPane? pane;
}

class DesktopDropExited extends DesktopEvent {
  const DesktopDropExited();
}

class DesktopDropError extends DesktopEvent {
  const DesktopDropError(this.code, {this.detail});
  final DesktopDropErrorCode code;

  /// OS-provided diagnostic text. It is deliberately not translated or parsed.
  final String? detail;
}

enum DesktopDropErrorCode {
  tooManyFiles,
  notFinderFile,
  notReadableFile,
  couldNotOpen,
}

class DesktopCloseRequested extends DesktopEvent {
  const DesktopCloseRequested();
}

typedef DesktopEventHandler = Future<void> Function(DesktopEvent event);

abstract class DesktopPlatform {
  bool get usesWidgetDropTargets;
  String? get stagingDirectory;
  Future<void> initialize();
  void setEventHandler(DesktopEventHandler? handler);
  Future<String?> openFile(DesktopPane pane, String typeGroupLabel);
  Future<String?> saveFile(DesktopPane pane, String suggestedName);
  Future<SaveInstallResult> installSavedFile(
    String stagedPath,
    String destinationPath,
  );
  Future<void> confirmClose();
  Future<void> dispose();

  /// Validates a widget-plugin drop before passing it to the application.
  Future<void> reportDropFiles(List<String> paths, DesktopPane pane);
  void reportDropHover(DesktopPane pane, bool hovering);
}

DesktopPlatform createDesktopPlatform() => _DesktopPlatform();

class _DesktopPlatform extends DesktopPlatform with WindowListener {
  static const _channel = MethodChannel('mushagaeshi/files');
  DesktopEventHandler? _handler;
  var _closeConfirmed = false;

  bool get _isMacOS => Platform.isMacOS;
  @override
  bool get usesWidgetDropTargets => !_isMacOS;
  @override
  String? get stagingDirectory => _isMacOS ? Directory.systemTemp.path : null;

  @override
  Future<void> initialize() async {
    if (_isMacOS) {
      _channel.setMethodCallHandler(_handleMacEvent);
      return;
    }
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
  }

  @override
  void setEventHandler(DesktopEventHandler? handler) => _handler = handler;

  @override
  Future<String?> openFile(DesktopPane pane, String typeGroupLabel) async {
    if (_isMacOS) return _channel.invokeMethod<String>('openFile', _side(pane));
    final file = await file_selector.openFile(
      acceptedTypeGroups: [file_selector.XTypeGroup(label: typeGroupLabel)],
    );
    return file?.path;
  }

  @override
  Future<String?> saveFile(DesktopPane pane, String suggestedName) async {
    if (_isMacOS) {
      return _channel.invokeMethod<String>('saveFile', {
        ..._side(pane),
        'name': suggestedName,
      });
    }
    final location = await file_selector.getSaveLocation(
      suggestedName: suggestedName,
    );
    return location?.path;
  }

  @override
  Future<SaveInstallResult> installSavedFile(
    String stagedPath,
    String destinationPath,
  ) async {
    try {
      final response = await _channel.invokeMethod<Object?>(
        'installSavedFile',
        {'stagedPath': stagedPath, 'destinationPath': destinationPath},
      );
      // The established macOS channel returns no value after a successful
      // replacement. Windows and Linux return a structured recovery result.
      if (response == null) return const SaveInstallResult.installed();
      if (response is Map) {
        final status = response['status'];
        final message = response['message'];
        final recoveryPath = response['recoveryPath'];
        if (status == 'installed') return const SaveInstallResult.installed();
        if (status == 'ambiguous' && recoveryPath is String) {
          return SaveInstallResult.ambiguous(
            message is String ? message : 'The save result is ambiguous.',
            recoveryPath,
          );
        }
        if (status == 'failed') {
          return SaveInstallResult.failed(
            message is String ? message : 'Unable to install the saved file.',
          );
        }
      }
      return const SaveInstallResult.failed(
        'The native save backend returned an invalid result.',
      );
    } on PlatformException catch (error) {
      return SaveInstallResult.failed(
        error.message ?? 'Unable to install the saved file.',
      );
    } on MissingPluginException {
      return const SaveInstallResult.failed(
        'Safe file installation is not available on this platform.',
      );
    }
  }

  @override
  Future<void> confirmClose() async {
    if (_isMacOS) return _channel.invokeMethod<void>('confirmClose');
    _closeConfirmed = true;
    await windowManager.destroy();
  }

  @override
  Future<void> dispose() async {
    if (_isMacOS) {
      _channel.setMethodCallHandler(null);
    } else {
      windowManager.removeListener(this);
    }
    _handler = null;
  }

  @override
  Future<void> reportDropFiles(List<String> paths, DesktopPane pane) async {
    if (paths.length != 1) {
      await _emit(const DesktopDropError(DesktopDropErrorCode.tooManyFiles));
      return;
    }
    final type = await FileSystemEntity.type(paths.single, followLinks: true);
    if (type != FileSystemEntityType.file) {
      await _emit(const DesktopDropError(DesktopDropErrorCode.notReadableFile));
      return;
    }
    await _emit(DesktopFileDropped(paths.single, pane: pane));
  }

  @override
  void reportDropHover(DesktopPane pane, bool hovering) {
    unawaited(
      _emit(
        hovering
            ? DesktopDropHoverChanged(pane: pane)
            : const DesktopDropExited(),
      ),
    );
  }

  @override
  void onWindowClose() {
    if (!_closeConfirmed) unawaited(_emit(const DesktopCloseRequested()));
  }

  Future<void> _handleMacEvent(MethodCall call) async {
    switch (call.method) {
      case 'fileDropped':
        final arguments = call.arguments;
        if (arguments is Map &&
            arguments['path'] is String &&
            arguments['x'] is num &&
            arguments['y'] is num) {
          await _emit(
            DesktopFileDropped(
              arguments['path'] as String,
              position: (
                x: (arguments['x'] as num).toDouble(),
                y: (arguments['y'] as num).toDouble(),
              ),
            ),
          );
        } else {
          await _emit(
            const DesktopDropError(DesktopDropErrorCode.couldNotOpen),
          );
        }
        return;
      case 'fileDragUpdated':
        final arguments = call.arguments;
        if (arguments is Map &&
            arguments['x'] is num &&
            arguments['y'] is num) {
          await _emit(
            DesktopDropHoverChanged(
              position: (
                x: (arguments['x'] as num).toDouble(),
                y: (arguments['y'] as num).toDouble(),
              ),
            ),
          );
        }
        return;
      case 'fileDragExited':
        await _emit(const DesktopDropExited());
        return;
      case 'fileDropError':
        final arguments = call.arguments;
        await _emit(
          DesktopDropError(
            switch (arguments is Map ? arguments['code'] : null) {
              'tooManyFiles' => DesktopDropErrorCode.tooManyFiles,
              'notFinderFile' => DesktopDropErrorCode.notFinderFile,
              'notReadableFile' => DesktopDropErrorCode.notReadableFile,
              _ => DesktopDropErrorCode.couldNotOpen,
            },
            detail: arguments is Map && arguments['detail'] is String
                ? arguments['detail'] as String
                : null,
          ),
        );
        return;
      case 'requestClose':
        await _emit(const DesktopCloseRequested());
        return;
    }
  }

  Future<void> _emit(DesktopEvent event) async {
    final handler = _handler;
    if (handler != null) await handler(event);
  }

  Map<String, String> _side(DesktopPane pane) => {
    'side': pane == DesktopPane.left ? 'Left' : 'Right',
  };
}
