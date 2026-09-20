import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendence/core/style/theme/app_theme.dart';
import 'package:attendence/core/style/theme/context_extension.dart';
import 'package:attendence/core/style/colors/colors_dark.dart';
import 'package:attendence/core/style/colors/colors_light.dart';

void main() {
  testWidgets('tokens resolve from the active theme in both brightnesses', (
    tester,
  ) async {
    late BuildContext ctx;

    Widget app(ThemeData theme) => MaterialApp(
      theme: theme,
      home: Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    );

    await tester.pumpWidget(app(AppTheme.light()));
    await tester.pumpAndSettle();
    expect(ctx.color.primary, ColorsLight.primary);
    expect(ctx.color.warningSoft, ColorsLight.warningSoft);
    expect(ctx.color.infoSoft, ColorsLight.infoSoft);
    expect(ctx.color.background, ColorsLight.background);
    expect(ctx.textStyle.fontSize, 13);

    // MyColors.lerp animates the swap, so settle before reading the tokens.
    await tester.pumpWidget(app(AppTheme.dark()));
    await tester.pumpAndSettle();
    expect(ctx.color.primary, ColorsDark.primary);
    expect(ctx.color.warningSoft, ColorsDark.warningSoft);
    expect(ctx.color.infoSoft, ColorsDark.infoSoft);
    expect(ctx.color.background, ColorsDark.background);
  });
}
