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

/// Returns a color for a fraud score (0-100, lower = better).
/// - 0-30  → green  (excellent)
/// - 31-60 → yellow (fair)
/// - 61-80 → orange (poor)
/// - 81-100 → red   (bad)
AccentColor getScoreColor(double fraudScore, {bool hasBeenScored = true}) {
  if (!hasBeenScored) return Colors.grey.toAccentColor();
  if (fraudScore <= 30) return Colors.green;
  if (fraudScore <= 60) return Colors.yellow;
  if (fraudScore <= 80) return Colors.orange;
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
        getScoreColor(ip.fraudScore, hasBeenScored: ip.hasBeenScored);

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
            ip.hasBeenScored ? ip.fraudScore.toStringAsFixed(0) : '?',
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
