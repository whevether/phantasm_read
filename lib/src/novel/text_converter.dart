/// Optional, lightweight Simplified <-> Traditional Chinese converter.
///
/// Uses a compact built-in character table covering common characters. It is
/// character-level only (no phrase-level rules), so hosts needing full accuracy
/// should convert text with a dedicated library before passing it in.
class ChineseTextConverter {
  const ChineseTextConverter._();

  static const String _simplified =
      '们个为这来时说国会对发学后无开关长门间问还过动车东书买卖读写爱听见觉点现经师电产业务实应进种机边认让话请谁难欢乐龙马鸟鱼风飞凤';
  static const String _traditional =
      '們個為這來時說國會對發學後無開關長門間問還過動車東書買賣讀寫愛聽見覺點現經師電產業務實應進種機邊認讓話請誰難歡樂龍馬鳥魚風飛鳳';

  static final Map<int, int> _toTraditional = _build(_simplified, _traditional);
  static final Map<int, int> _toSimplified = _build(_traditional, _simplified);

  static Map<int, int> _build(String from, String to) {
    final a = from.runes.toList();
    final b = to.runes.toList();
    final n = a.length < b.length ? a.length : b.length;
    final map = <int, int>{};
    for (var i = 0; i < n; i++) {
      map.putIfAbsent(a[i], () => b[i]);
    }
    return map;
  }

  static String toTraditional(String text) => _convert(text, _toTraditional);

  static String toSimplified(String text) => _convert(text, _toSimplified);

  static String _convert(String text, Map<int, int> map) {
    final out = StringBuffer();
    for (final r in text.runes) {
      out.writeCharCode(map[r] ?? r);
    }
    return out.toString();
  }
}
