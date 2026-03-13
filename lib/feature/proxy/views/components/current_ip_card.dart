import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/feature/proxy/views/components/ip_score_indicator.dart';
import 'package:fluent_ui/fluent_ui.dart';

class CurrentIpCard extends StatelessWidget {
  final ProxyIpAddressEntity ip;

  const CurrentIpCard({super.key, required this.ip});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSimpleInfoRow('IP Address', ip.ipAddress),
          const SizedBox(height: 12),
          _buildSimpleInfoRow('Location', '${ip.cityName}, ${ip.countryCode}'),
          const SizedBox(height: 12),
          _buildSimpleInfoRow('Timezone', ip.ipTimezone),
          const SizedBox(height: 12),
          _buildSimpleInfoRow('Provider', ip.asnName),
          const SizedBox(height: 12),
          _buildSimpleInfoRow('ASN', ip.asnNumber.toString()),
          const SizedBox(height: 12),
          _buildSimpleInfoRow('Assigned', formatDate(ip.assignedAt)),
        ],
      ),
    );
  }

  Widget _buildSimpleInfoRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
