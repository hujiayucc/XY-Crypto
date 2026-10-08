import 'package:flutter/foundation.dart';

/// A visual item that can be placed in a future category, such as QQ.
abstract interface class EmojiPanelItem {
  const EmojiPanelItem();

  String get asset;
  int? get codePoint;
  String get insertionText;
  String get fallbackText;
}

/// Standard Emoji order and artwork retained from the XY 1.3.1 EmojiBoard.
/// The original 12 custom entries are intentionally excluded.
@immutable
class OriginalEmoji implements EmojiPanelItem {
  const OriginalEmoji(this.codePoint, this.asset);

  @override
  final int codePoint;

  @override
  final String asset;

  @override
  String get insertionText => String.fromCharCode(codePoint);

  @override
  String get fallbackText => insertionText;
}

const originalEmojiCatalog = <OriginalEmoji>[
  OriginalEmoji(0x1f603, 'assets/emoji/emoji_000.png'),
  OriginalEmoji(0x1f600, 'assets/emoji/emoji_001.png'),
  OriginalEmoji(0x1f60a, 'assets/emoji/emoji_002.png'),
  OriginalEmoji(0x263a, 'assets/emoji/emoji_003.png'),
  OriginalEmoji(0x1f609, 'assets/emoji/emoji_004.png'),
  OriginalEmoji(0x1f60d, 'assets/emoji/emoji_005.png'),
  OriginalEmoji(0x1f618, 'assets/emoji/emoji_006.png'),
  OriginalEmoji(0x1f61a, 'assets/emoji/emoji_007.png'),
  OriginalEmoji(0x1f61c, 'assets/emoji/emoji_008.png'),
  OriginalEmoji(0x1f61d, 'assets/emoji/emoji_009.png'),
  OriginalEmoji(0x1f633, 'assets/emoji/emoji_010.png'),
  OriginalEmoji(0x1f601, 'assets/emoji/emoji_011.png'),
  OriginalEmoji(0x1f614, 'assets/emoji/emoji_012.png'),
  OriginalEmoji(0x1f60c, 'assets/emoji/emoji_013.png'),
  OriginalEmoji(0x1ff12, 'assets/emoji/emoji_014.png'),
  OriginalEmoji(0x1f61f, 'assets/emoji/emoji_015.png'),
  OriginalEmoji(0x1f61e, 'assets/emoji/emoji_016.png'),
  OriginalEmoji(0x1f623, 'assets/emoji/emoji_017.png'),
  OriginalEmoji(0x1f622, 'assets/emoji/emoji_018.png'),
  OriginalEmoji(0x1f602, 'assets/emoji/emoji_019.png'),
  OriginalEmoji(0x1f62d, 'assets/emoji/emoji_020.png'),
  OriginalEmoji(0x1f62a, 'assets/emoji/emoji_021.png'),
  OriginalEmoji(0x1f630, 'assets/emoji/emoji_022.png'),
  OriginalEmoji(0x1f605, 'assets/emoji/emoji_023.png'),
  OriginalEmoji(0x1f613, 'assets/emoji/emoji_024.png'),
  OriginalEmoji(0x1f62b, 'assets/emoji/emoji_025.png'),
  OriginalEmoji(0x1f629, 'assets/emoji/emoji_026.png'),
  OriginalEmoji(0x1f628, 'assets/emoji/emoji_027.png'),
  OriginalEmoji(0x1f631, 'assets/emoji/emoji_028.png'),
  OriginalEmoji(0x1f621, 'assets/emoji/emoji_029.png'),
  OriginalEmoji(0x1f624, 'assets/emoji/emoji_030.png'),
  OriginalEmoji(0x1f616, 'assets/emoji/emoji_031.png'),
  OriginalEmoji(0x1f606, 'assets/emoji/emoji_032.png'),
  OriginalEmoji(0x1f60b, 'assets/emoji/emoji_033.png'),
  OriginalEmoji(0x1f637, 'assets/emoji/emoji_034.png'),
  OriginalEmoji(0x1f60e, 'assets/emoji/emoji_035.png'),
  OriginalEmoji(0x1f634, 'assets/emoji/emoji_036.png'),
  OriginalEmoji(0x1f632, 'assets/emoji/emoji_037.png'),
  OriginalEmoji(0x1f62e, 'assets/emoji/emoji_038.png'),
  OriginalEmoji(0x1f608, 'assets/emoji/emoji_039.png'),
  OriginalEmoji(0x1f47f, 'assets/emoji/emoji_040.png'),
  OriginalEmoji(0x1f62f, 'assets/emoji/emoji_041.png'),
  OriginalEmoji(0x1f62c, 'assets/emoji/emoji_042.png'),
  OriginalEmoji(0x1f615, 'assets/emoji/emoji_043.png'),
  OriginalEmoji(0x1f635, 'assets/emoji/emoji_044.png'),
  OriginalEmoji(0x1f636, 'assets/emoji/emoji_045.png'),
  OriginalEmoji(0x1f607, 'assets/emoji/emoji_046.png'),
  OriginalEmoji(0x1f60f, 'assets/emoji/emoji_047.png'),
  OriginalEmoji(0x1f611, 'assets/emoji/emoji_048.png'),
  OriginalEmoji(0x1f648, 'assets/emoji/emoji_049.png'),
  OriginalEmoji(0x1f649, 'assets/emoji/emoji_050.png'),
  OriginalEmoji(0x1f64a, 'assets/emoji/emoji_051.png'),
  OriginalEmoji(0x1f47d, 'assets/emoji/emoji_052.png'),
  OriginalEmoji(0x1f4a9, 'assets/emoji/emoji_053.png'),
  OriginalEmoji(0x2764, 'assets/emoji/emoji_054.png'),
  OriginalEmoji(0x1f494, 'assets/emoji/emoji_055.png'),
  OriginalEmoji(0x1f525, 'assets/emoji/emoji_056.png'),
  OriginalEmoji(0x1f4a2, 'assets/emoji/emoji_057.png'),
  OriginalEmoji(0x1f4a4, 'assets/emoji/emoji_058.png'),
  OriginalEmoji(0x1f6ab, 'assets/emoji/emoji_059.png'),
  OriginalEmoji(0x2b50, 'assets/emoji/emoji_060.png'),
  OriginalEmoji(0x26a1, 'assets/emoji/emoji_061.png'),
  OriginalEmoji(0x1f319, 'assets/emoji/emoji_062.png'),
  OriginalEmoji(0x2600, 'assets/emoji/emoji_063.png'),
  OriginalEmoji(0x26c5, 'assets/emoji/emoji_064.png'),
  OriginalEmoji(0x2601, 'assets/emoji/emoji_065.png'),
  OriginalEmoji(0x2744, 'assets/emoji/emoji_066.png'),
  OriginalEmoji(0x2614, 'assets/emoji/emoji_067.png'),
  OriginalEmoji(0x26c4, 'assets/emoji/emoji_068.png'),
  OriginalEmoji(0x1f44d, 'assets/emoji/emoji_069.png'),
  OriginalEmoji(0x1f44e, 'assets/emoji/emoji_070.png'),
  OriginalEmoji(0x1f44c, 'assets/emoji/emoji_071.png'),
  OriginalEmoji(0x1f44a, 'assets/emoji/emoji_072.png'),
  OriginalEmoji(0x270a, 'assets/emoji/emoji_073.png'),
  OriginalEmoji(0x270c, 'assets/emoji/emoji_074.png'),
  OriginalEmoji(0x270b, 'assets/emoji/emoji_075.png'),
  OriginalEmoji(0x1f64f, 'assets/emoji/emoji_076.png'),
  OriginalEmoji(0x261d, 'assets/emoji/emoji_077.png'),
  OriginalEmoji(0x1f44f, 'assets/emoji/emoji_078.png'),
  OriginalEmoji(0x1f91d, 'assets/emoji/emoji_079.png'),
  OriginalEmoji(0x1f4aa, 'assets/emoji/emoji_080.png'),
  OriginalEmoji(0x1f46a, 'assets/emoji/emoji_081.png'),
  OriginalEmoji(0x1f46b, 'assets/emoji/emoji_082.png'),
  OriginalEmoji(0x1f47c, 'assets/emoji/emoji_083.png'),
  OriginalEmoji(0x1f434, 'assets/emoji/emoji_084.png'),
  OriginalEmoji(0x1f436, 'assets/emoji/emoji_085.png'),
  OriginalEmoji(0x1f437, 'assets/emoji/emoji_086.png'),
  OriginalEmoji(0x1f47b, 'assets/emoji/emoji_087.png'),
  OriginalEmoji(0x1f339, 'assets/emoji/emoji_088.png'),
  OriginalEmoji(0x1f33b, 'assets/emoji/emoji_089.png'),
  OriginalEmoji(0x1f332, 'assets/emoji/emoji_090.png'),
  OriginalEmoji(0x1f384, 'assets/emoji/emoji_091.png'),
  OriginalEmoji(0x1f381, 'assets/emoji/emoji_092.png'),
  OriginalEmoji(0x1f389, 'assets/emoji/emoji_093.png'),
  OriginalEmoji(0x1f4b0, 'assets/emoji/emoji_094.png'),
  OriginalEmoji(0x1f382, 'assets/emoji/emoji_095.png'),
  OriginalEmoji(0x1f356, 'assets/emoji/emoji_096.png'),
  OriginalEmoji(0x1f35a, 'assets/emoji/emoji_097.png'),
  OriginalEmoji(0x1f366, 'assets/emoji/emoji_098.png'),
  OriginalEmoji(0x1f36b, 'assets/emoji/emoji_099.png'),
  OriginalEmoji(0x1f349, 'assets/emoji/emoji_100.png'),
  OriginalEmoji(0x1f377, 'assets/emoji/emoji_101.png'),
  OriginalEmoji(0x1f37b, 'assets/emoji/emoji_102.png'),
  OriginalEmoji(0x2615, 'assets/emoji/emoji_103.png'),
  OriginalEmoji(0x1f3c0, 'assets/emoji/emoji_104.png'),
  OriginalEmoji(0x26bd, 'assets/emoji/emoji_105.png'),
  OriginalEmoji(0x1f3c2, 'assets/emoji/emoji_106.png'),
  OriginalEmoji(0x1f6b2, 'assets/emoji/emoji_107.png'),
  OriginalEmoji(0x1f3a4, 'assets/emoji/emoji_108.png'),
  OriginalEmoji(0x1f3b5, 'assets/emoji/emoji_109.png'),
  OriginalEmoji(0x1f3b2, 'assets/emoji/emoji_110.png'),
  OriginalEmoji(0x1f004, 'assets/emoji/emoji_111.png'),
  OriginalEmoji(0x1f451, 'assets/emoji/emoji_112.png'),
  OriginalEmoji(0x1f484, 'assets/emoji/emoji_113.png'),
  OriginalEmoji(0x1f48b, 'assets/emoji/emoji_114.png'),
  OriginalEmoji(0x1f48d, 'assets/emoji/emoji_115.png'),
  OriginalEmoji(0x1f4da, 'assets/emoji/emoji_116.png'),
  OriginalEmoji(0x1f393, 'assets/emoji/emoji_117.png'),
  OriginalEmoji(0x270f, 'assets/emoji/emoji_118.png'),
  OriginalEmoji(0x1f3e1, 'assets/emoji/emoji_119.png'),
  OriginalEmoji(0x1f6bf, 'assets/emoji/emoji_120.png'),
  OriginalEmoji(0x1f4a1, 'assets/emoji/emoji_121.png'),
  OriginalEmoji(0x1f4de, 'assets/emoji/emoji_122.png'),
  OriginalEmoji(0x1f4e2, 'assets/emoji/emoji_123.png'),
  OriginalEmoji(0x1f556, 'assets/emoji/emoji_124.png'),
  OriginalEmoji(0x23f0, 'assets/emoji/emoji_125.png'),
  OriginalEmoji(0x23f3, 'assets/emoji/emoji_126.png'),
  OriginalEmoji(0x1f4a3, 'assets/emoji/emoji_127.png'),
  OriginalEmoji(0x1f52b, 'assets/emoji/emoji_128.png'),
  OriginalEmoji(0x1f48a, 'assets/emoji/emoji_129.png'),
  OriginalEmoji(0x1f680, 'assets/emoji/emoji_130.png'),
  OriginalEmoji(0x1f30f, 'assets/emoji/emoji_131.png'),
];
