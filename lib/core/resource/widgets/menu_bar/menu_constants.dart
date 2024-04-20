import 'dart:developer';
import 'dart:io';

import 'package:command_center/config/routes/app_pages.dart';
import 'package:command_center/feature/music/controller/music_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:menu_bar/menu_bar.dart';

final MusicController _musicController = Get.find();

const menuStyle = MenuStyle(
  padding: MaterialStatePropertyAll(EdgeInsets.zero),
  backgroundColor: MaterialStatePropertyAll(Color(0xFF2b2b2b)),
  maximumSize: MaterialStatePropertyAll(Size(double.infinity, 28.0)),
);

const buttonStyle = ButtonStyle(
  padding: MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 6.0)),
  minimumSize: MaterialStatePropertyAll(Size(0.0, 32.0)),
);

const menuButtonStyle = ButtonStyle(
  minimumSize: MaterialStatePropertyAll(Size.fromHeight(36.0)),
  padding: MaterialStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0)),
);

final List<BarButton> menuButtons = [
  BarButton(
    text: const Text(
      'Bots',
      style: TextStyle(color: Colors.white),
    ),
    submenu: SubMenu(
      menuItems: [
        MenuButton(
          onTap: () => Get.offNamed(Routes.initial),
          text: const Text('Home'),
          icon: Image.asset(
            'assets/images/frieren.png',
            width: 24,
            height: 24,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
        MenuButton(
          onTap: () => Get.offNamed(Routes.status),
          text: const Text('Status'),
        ),
        MenuButton(
          onTap: () => {},
          text: const Text('Deploy/Stop'),
        ),
        const MenuDivider(),
        MenuButton(
          text: const Text('Preferences'),
          icon: const Icon(Icons.settings),
          submenu: SubMenu(
            menuItems: [
              MenuButton(
                onTap: () {},
                icon: const Icon(Icons.keyboard),
                text: const Text('Shortcuts'),
              ),
              const MenuDivider(),
              MenuButton(
                onTap: () {},
                icon: const Icon(Icons.extension),
                text: const Text('Extensions'),
              ),
              const MenuDivider(),
              MenuButton(
                icon: const Icon(Icons.looks),
                text: const Text('Change theme'),
                submenu: SubMenu(
                  menuItems: [
                    MenuButton(
                      onTap: () {},
                      icon: const Icon(Icons.light_mode),
                      text: const Text('Light theme'),
                    ),
                    const MenuDivider(),
                    MenuButton(
                      onTap: () {},
                      icon: const Icon(Icons.dark_mode),
                      text: const Text('Dark theme'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
  BarButton(
    text: const Text(
      'Misc',
      style: TextStyle(color: Colors.white),
    ),
    submenu: SubMenu(
      menuItems: [
        MenuButton(
          onTap: () => _musicController.isPlaying.value
              ? _musicController.pauseAudio()
              : _musicController.playAudio(),
          text: Obx(
            () => _musicController.isPlaying.value
                ? const Text('Stop Music')
                : const Text('Play music'),
          ),
          icon: Obx(
            () => _musicController.isPlaying.value
                ? const Icon(Icons.pause, size: 24.0)
                : const Icon(Icons.play_arrow, size: 24.0),
          ),
        ),
      ],
    ),
  ),
  BarButton(
    text: const Text(
      'Help',
      style: TextStyle(color: Colors.white),
    ),
    submenu: SubMenu(
      menuItems: [
        MenuButton(
          onTap: () {},
          text: const Text('Check for updates'),
        ),
        const MenuDivider(),
        MenuButton(
          onTap: () {},
          icon: const Icon(Icons.info),
          text: const Text('About'),
        ),
        const MenuDivider(),
        MenuButton(
          onTap: () {
            debugger();
            exit(0);
          },
          shortcutText: 'Ctrl+Q',
          text: const Text('Exit'),
          icon: const Icon(Icons.exit_to_app),
        ),
      ],
    ),
  ),
];
