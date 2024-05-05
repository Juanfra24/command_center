import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class StatusScreen extends GetView<StatusController> {
  const StatusScreen({super.key});

  IconData getProcessIcon(String characterName) {
    return controller.processClients.containsKey(characterName)
        ? Icons.circle
        : Icons.circle_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(
          () => Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: DataTable(
                columnSpacing: 38.0,
                columns: const [
                  DataColumn(label: Text('Account Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Password')),
                  DataColumn(label: Text('Character Name')),
                  DataColumn(label: Text('Proxy Address')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: controller.accountList
                    .expand(
                      (user) => user.characters.map(
                        (character) {
                          final haveRunningProcess = controller.processClients
                              .containsKey(character.name);
                          return DataRow(
                            cells: [
                              DataCell(Text(user.accountName)),
                              DataCell(
                                Row(
                                  children: [
                                    Text(user.email),
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: () => controller
                                          .copyToClipboard(user.email, context),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    Text(user.password),
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: () =>
                                          controller.copyToClipboard(
                                              user.password, context),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text(character.name)),
                              DataCell(Text(user.proxyAddress)),
                              DataCell(
                                Row(
                                  children: [
                                    haveRunningProcess
                                        ? IconButton(
                                            icon: const Icon(Icons.stop),
                                            tooltip: 'Stop',
                                            onPressed: () async {
                                              await controller.stopGameClient(
                                                  controller.processClients[
                                                      character.name]);
                                            },
                                          )
                                        : IconButton(
                                            icon: const Icon(Icons.play_arrow),
                                            tooltip: 'Start',
                                            onPressed: () async {
                                              await controller
                                                  .runGameClient(user);
                                            },
                                          ),
                                    IconButton(
                                      icon: haveRunningProcess
                                          ? const Icon(
                                              Icons.circle,
                                              color: Colors.lightGreen,
                                            )
                                          : const Icon(
                                              Icons.circle,
                                              color: Colors.grey,
                                            ),
                                      tooltip: haveRunningProcess
                                          ? "Running"
                                          : "Unkown",
                                      onPressed: () {},
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.open_in_browser),
                                      tooltip: 'Launch Browser',
                                      onPressed: () async {
                                        await controller.runPythonScript(
                                          user.proxyAddress,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
