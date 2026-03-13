import 'dart:typed_data';

import 'package:command_center/core/helper/logger.dart';
import 'package:equatable/equatable.dart';

class ProcessClient extends Equatable {
  final String commandLine;
  final int processId;

  const ProcessClient({required this.commandLine, required this.processId});

  static List<ProcessClient> parseProcessData(Uint8List data) {
    String decodedString = String.fromCharCodes(data.buffer.asUint16List());

    List<String> lines = decodedString.split('\n');
    List<ProcessClient> processes = [];

    String? currentCommand;
    for (var line in lines) {
      if (line.startsWith('CommandLine=')) {
        currentCommand = line.substring(12);
      } else if (line.startsWith('ProcessId=') && currentCommand != null) {
        int processId =
            int.tryParse(line.substring(10).replaceAll(RegExp('"'), '')) ?? 0;

        if (currentCommand.contains('client.jar')) {
          processes.add(
              ProcessClient(commandLine: currentCommand, processId: processId));
        }
        currentCommand = null; // Reset for the next command line
      }
    }
    logger.d('Parsed ${processes.length} Java processes');
    return processes;
  }

  @override
  List<Object?> get props => [commandLine, processId];
}
