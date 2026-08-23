import 'package:flutter/material.dart';

class ShareFitSlidingSegmentedControl extends StatelessWidget {
  const ShareFitSlidingSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.badgedIndices = const <int>{},
    this.height = 56,
    this.padding = 5,
    this.borderRadius = 20,
    this.indicatorBorderRadius = 16,
    this.backgroundColor,
    this.borderColor,
    this.unselectedForegroundColor,
    this.icons,
  }) : assert(labels.length > 1),
       assert(icons == null || icons.length == labels.length),
       assert(selectedIndex >= 0 && selectedIndex < labels.length);

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Set<int> badgedIndices;
  final double height;
  final double padding;
  final double borderRadius;
  final double indicatorBorderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? unselectedForegroundColor;
  final List<IconData>? icons;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final innerHeight = height - (padding * 2);

    return Container(
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surfaceContainer,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: segmentWidth * selectedIndex,
                top: 0,
                width: segmentWidth,
                height: innerHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(indicatorBorderRadius),
                  ),
                ),
              ),
              Row(
                children: List.generate(labels.length, (index) {
                  final selected = index == selectedIndex;
                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: selected,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(index),
                        child: Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (icons == null)
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 160),
                                  curve: Curves.easeOut,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : unselectedForegroundColor ??
                                              colors.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  child: Text(labels[index]),
                                )
                              else
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  child: Icon(
                                    icons![index],
                                    key: ValueKey(
                                      '${icons![index].codePoint}-$selected',
                                    ),
                                    color: selected
                                        ? Colors.white
                                        : unselectedForegroundColor ??
                                              colors.onSurface,
                                    size: 24,
                                  ),
                                ),
                              if (badgedIndices.contains(index))
                                Positioned(
                                  top: -7,
                                  right: -17,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: colors.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text(
                                      '!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        height: 1,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
