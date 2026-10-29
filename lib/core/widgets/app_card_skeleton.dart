import 'package:flutter/material.dart';

import '../style/theme/app_dimens.dart';
import '../style/theme/context_extension.dart';
import 'app_skeleton.dart';

/// The placeholder for a card, drawn as the card: real border, real radius,
/// real [AppDimens.cardPadding]. Only the contents are grey.
///
/// Keeping the frame means the page's composition is already correct while it
/// waits — the gaps between cards, the column widths, the scroll height — so
/// the arriving content fills a hole of exactly its own size.
class AppCardSkeleton extends StatelessWidget {
  const AppCardSkeleton({
    super.key,
    this.lines = 3,
    this.showHeader = true,
    this.height,
  });

  /// Body lines to draw. The last is drawn short, the way a paragraph ends.
  final int lines;

  /// Draws a badge and a title line above the body, matching the header strip
  /// the app's cards carry.
  final bool showHeader;

  /// Forces the card to a known height — for a slot whose real content is
  /// taller than its text, such as a chart or a stat tile.
  final double? height;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        decoration: BoxDecoration(
          color: context.color.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: context.color.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showHeader) ...<Widget>[
              Row(
                children: <Widget>[
                  const AppSkeleton(
                    width: AppDimens.iconLg,
                    height: AppDimens.iconLg,
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  const Expanded(
                    child: AppSkeleton.line(width: 120, height: 11),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceLg),
            ],
            for (var i = 0; i < lines; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: AppDimens.spaceMd),
              FractionallySizedBox(
                widthFactor: i == lines - 1 ? 0.55 : 1,
                child: const AppSkeleton.line(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A grid of [AppCardSkeleton]s for a dashboard's figure row.
///
/// Sized and gapped like the real stat cards so the four figures do not shift
/// when they resolve, and folded to two columns under
/// [AppDimens.statFoldWidth] by the same rule the real row folds on.
class AppStatRowSkeleton extends StatelessWidget {
  const AppStatRowSkeleton({
    super.key,
    this.count = 4,
    this.cardHeight = 96,
    this.perRow,
    this.foldedPerRow = 2,
  });

  final int count;
  final double cardHeight;

  /// Columns above the fold. Defaults to [count] capped at four, which is the
  /// shape of a figure row; a page whose real grid uses a different count must
  /// say so, or the skeleton and the content it stands in for would wrap
  /// differently and the page would jump when the data lands.
  final int? perRow;

  /// Columns below [AppDimens.statFoldWidth].
  final int foldedPerRow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = perRow ?? (count < 4 ? count : 4);
        final columns = constraints.maxWidth < AppDimens.statFoldWidth
            ? foldedPerRow
            : wide;
        final gaps = (columns - 1) * AppDimens.cardGap;
        final width = (constraints.maxWidth - gaps) / columns;

        return Wrap(
          spacing: AppDimens.cardGap,
          runSpacing: AppDimens.cardGap,
          children: <Widget>[
            for (var i = 0; i < count; i++)
              SizedBox(
                width: width,
                child: AppCardSkeleton(
                  lines: 1,
                  showHeader: true,
                  height: cardHeight,
                ),
              ),
          ],
        );
      },
    );
  }
}
