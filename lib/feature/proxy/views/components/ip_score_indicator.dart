import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:fluent_ui/fluent_ui.dart';

// Extension to convert ShadedColor to AccentColor
extension ShadedColorToAccent on ShadedColor {
  AccentColor toAccentColor() {
    return AccentColor.swatch({
      'darkest': this,
      'darker': this,
      'dark': this,
      'normal': this,
      'light': this,
      'lighter': this,
      'lightest': this,
    });
  }
}

AccentColor getScoreColor(double score, {bool hasBeenScored = true}) {
  if (!hasBeenScored) return Colors.grey.toAccentColor();
  if (score >= 90) return Colors.green;
  if (score >= 70) return Colors.teal;
  if (score >= 50) return Colors.orange;
  return Colors.red;
}

String formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

class IpScoreIndicator extends StatelessWidget {
  final ProxyIpAddressEntity ip;

  const IpScoreIndicator({super.key, required this.ip});

  @override
  Widget build(BuildContext context) {
    final scoreColor =
        getScoreColor(ip.ipScore, hasBeenScored: ip.hasBeenScored);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            ip.hasBeenScored ? ip.ipScore.toStringAsFixed(0) : '?',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: scoreColor,
            ),
          ),
        ],
      ),
    );
  }
}
