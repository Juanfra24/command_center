class ProxyHealthData {
  final int excellentCount; // fraudScore 0-30
  final int fairCount;      // fraudScore 31-60
  final int poorCount;      // fraudScore 61-80
  final int badCount;       // fraudScore 81-100
  final int unscoredCount;
  final List<ProxyAttentionItem> attentionItems;

  const ProxyHealthData({
    this.excellentCount = 0,
    this.fairCount = 0,
    this.poorCount = 0,
    this.badCount = 0,
    this.unscoredCount = 0,
    this.attentionItems = const [],
  });

  factory ProxyHealthData.empty() => const ProxyHealthData();

  int get totalCount =>
      excellentCount + fairCount + poorCount + badCount + unscoredCount;
}

class ProxyAttentionItem {
  final int slotId;
  final String slotName;
  final double? fraudScore;
  final String? connectionType;
  final bool isUnscored;

  const ProxyAttentionItem({
    required this.slotId,
    required this.slotName,
    this.fraudScore,
    this.connectionType,
    this.isUnscored = false,
  });
}
