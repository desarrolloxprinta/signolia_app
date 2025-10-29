import 'package:flutter/widgets.dart';

class SectionTitleScope extends InheritedWidget {
  const SectionTitleScope({
    super.key,
    required this.title,
    required super.child,
  });

  final String title;

  static SectionTitleScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SectionTitleScope>();
    }

  @override
  bool updateShouldNotify(SectionTitleScope oldWidget) => oldWidget.title != title;
}
