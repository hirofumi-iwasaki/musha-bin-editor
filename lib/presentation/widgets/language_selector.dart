// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../application/language_controller.dart';

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static LanguageController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.notifier;
}

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.maybeOf(context);
    return SizedBox(
      width: 195,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Language / 言語',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<AppLanguage>(
            key: const ValueKey('language-selector'),
            isDense: true,
            isExpanded: true,
            value: controller?.selection ?? AppLanguage.system,
            items: const [
              DropdownMenuItem(
                value: AppLanguage.system,
                child: Text('System / システム'),
              ),
              DropdownMenuItem(value: AppLanguage.en, child: Text('English')),
              DropdownMenuItem(value: AppLanguage.ja, child: Text('日本語')),
            ],
            onChanged: controller == null
                ? null
                : (value) {
                    if (value != null) controller.select(value);
                  },
          ),
        ),
      ),
    );
  }
}
