import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ScoreDetailTable extends StatelessWidget {
  final ProxyIpAddressEntity ip;

  const ScoreDetailTable({super.key, required this.ip});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildScoreRow('Fraud Score', ip.fraudScore, Colors.red),
        const SizedBox(height: 8),
        _buildScoreRow(
          'Abuse Confidence',
          ip.abuseConfidence.toDouble(),
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildScoreRow(String label, double value, AccentColor color) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: ProgressBar(
            value: value,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            activeColor: color,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(0),
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }
}
