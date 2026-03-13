import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/feature/proxy/views/components/ip_score_indicator.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ScoreSummary extends StatelessWidget {
  final ProxyIpAddressEntity ip;

  const ScoreSummary({super.key, required this.ip});

  @override
  Widget build(BuildContext context) {
    final scoreColor =
        getScoreColor(ip.ipScore, hasBeenScored: ip.hasBeenScored);

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scoreColor, width: 4),
        color: scoreColor.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              ip.hasBeenScored ? ip.ipScore.toStringAsFixed(0) : '?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: scoreColor,
              ),
            ),
            Text(
              ip.scoreLevel.name.toUpperCase(),
              style: TextStyle(fontSize: 10, color: scoreColor),
            ),
          ],
        ),
      ),
    );
  }
}
