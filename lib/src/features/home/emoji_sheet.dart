import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'emoji_catalog.dart';
import 'smiley_catalog.dart';

class EmojiPanelSelection {
  const EmojiPanelSelection.item(this.item) : isDelete = false;
  const EmojiPanelSelection.delete()
      : item = null,
        isDelete = true;

  final EmojiPanelItem? item;
  final bool isDelete;
}

/// A horizontally swipable category whose contents scroll vertically.
class EmojiCategory {
  const EmojiCategory({required this.label, required this.items});

  final String label;
  final List<EmojiPanelItem> items;
}

class OriginalEmojiSheet extends StatefulWidget {
  const OriginalEmojiSheet({
    super.key,
    required this.entries,
    this.categories,
    this.onSelection,
  });

  final List<OriginalEmoji> entries;

  /// Optional extension point for future packs such as QQ.
  /// When omitted, the panel exposes one native Emoji category.
  final List<EmojiCategory>? categories;

  /// When provided, selections are reported without dismissing the sheet.
  final ValueChanged<EmojiPanelSelection>? onSelection;

  @override
  State<OriginalEmojiSheet> createState() => _OriginalEmojiSheetState();
}

class _OriginalEmojiSheetState extends State<OriginalEmojiSheet> {
  static const columns = 8;
  late final PageController _categories;
  late final List<EmojiCategory> _itemsByCategory;
  var _category = 0;

  @override
  void initState() {
    super.initState();
    _categories = PageController();
    _itemsByCategory = widget.categories ??
        [
          EmojiCategory(label: '原生 Emoji', items: widget.entries),
          EmojiCategory(label: 'QQ', items: qqSmileyCatalog),
          EmojiCategory(label: '滑稽', items: huajiSmileyCatalog),
          EmojiCategory(label: 'Doge', items: dogeSmileyCatalog),
        ];
  }

  @override
  void dispose() {
    _categories.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = math.min(420.0, MediaQuery.sizeOf(context).height * .62);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _categories,
                itemCount: _itemsByCategory.length,
                onPageChanged: (value) => setState(() => _category = value),
                itemBuilder: (context, index) => _categoryGrid(
                  context,
                  _itemsByCategory[index],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0;
                            index < _itemsByCategory.length;
                            index++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: index == _category
                                  ? Theme.of(context).colorScheme.secondary
                                  : Theme.of(context).disabledColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      tooltip: '删除',
                      onPressed: () =>
                          _select(const EmojiPanelSelection.delete()),
                      icon: const Icon(Icons.backspace_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(EmojiPanelSelection selection) {
    final callback = widget.onSelection;
    if (callback != null) {
      callback(selection);
    } else {
      Navigator.pop(context, selection);
    }
  }

  Widget _categoryGrid(BuildContext context, EmojiCategory category) =>
      GridView.builder(
        key: PageStorageKey<String>(category.label),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 1,
        ),
        itemCount: category.items.length,
        itemBuilder: (context, index) {
          final item = category.items[index];
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _select(EmojiPanelSelection.item(item)),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                item.asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => Text(
                  item.fallbackText,
                  style: const TextStyle(fontSize: 25),
                ),
              ),
            ),
          );
        },
      );
}
