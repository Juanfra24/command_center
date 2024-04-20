import 'package:command_center/core/resource/widgets/menu_bar/menu_constants.dart';
import 'package:flutter/material.dart';
import 'package:menu_bar/menu_bar.dart';

class MenuBar extends StatelessWidget {
  const MenuBar({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MenuBarWidget(
      barButtons: menuButtons,
      barStyle: menuStyle,
      barButtonStyle: buttonStyle,
      menuButtonStyle: menuButtonStyle,
      enabled: true,
      child: child,
    );
  }
}
