import 'package:equatable/equatable.dart';

class ProcessClient extends Equatable {
  final String commandLine;
  final int processId;

  const ProcessClient({required this.commandLine, required this.processId});

  /// Parse from WMI COM API structured response (list of maps)
  static List<ProcessClient> fromPlatformList(List<dynamic> data) {
    return data
        .whereType<Map>()
        .map((entry) => ProcessClient(
              commandLine: entry['commandLine'] as String? ?? '',
              processId: entry['pid'] as int? ?? 0,
            ))
        .where((p) => p.commandLine.isNotEmpty)
        .toList();
  }

  @override
  List<Object?> get props => [commandLine, processId];
}
