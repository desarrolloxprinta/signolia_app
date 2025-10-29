import 'package:flutter/widgets.dart';

class HomeShellScope extends InheritedWidget {
  const HomeShellScope({
    super.key,
    required this.setIndex,
    required super.child,
  });

  final void Function(int index) setIndex;

  static HomeShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeShellScope>();
  }

  @override
  bool updateShouldNotify(HomeShellScope oldWidget) => false;
}
