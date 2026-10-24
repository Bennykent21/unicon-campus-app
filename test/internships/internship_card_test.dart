import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_community_app/core/theme/app_colors.dart';
import 'package:university_community_app/features/internships/models/internship.dart';
import 'package:university_community_app/features/internships/widgets/internship_card.dart';

// Built without AppTheme so tests don't fetch Google Fonts over the network.
Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  return MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary, brightness: brightness)
          .copyWith(
        surface: dark ? AppColors.darkSurface : AppColors.lightSurface,
        onSurface:
            dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        onSurfaceVariant:
            dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      ),
      extensions: [dark ? AppPalette.dark : AppPalette.light],
    ),
    home: Scaffold(body: ListView(children: [child])),
  );
}

Internship listing(
        {ListingStatus status = ListingStatus.rolling, int alumni = 0}) =>
    Internship(
      id: '1',
      companyId: 'c',
      companyName: 'Seplat Energy',
      title: 'Undergraduate internship scheme',
      kind: InternshipKind.siwes,
      duration: '3, 6 or 12 months',
      status: status,
      alumniCount: alumni,
      unibenNote: 'Open to students of any Nigerian university.',
    );

void main() {
  testWidgets('shows title, company, facts and timing', (tester) async {
    await tester.pumpWidget(wrap(InternshipCard(
        internship: listing(),
        stage: null,
        onTap: () {},
        onToggleSave: () {})));
    expect(find.text('Undergraduate internship scheme'), findsOneWidget);
    expect(find.text('Seplat Energy'), findsOneWidget);
    expect(find.text('SIWES / IT'), findsOneWidget);
    expect(find.text('3, 6 or 12 months'), findsOneWidget);
    expect(find.text('Apply any time'), findsOneWidget);
    expect(find.text('Open to students of any Nigerian university.'),
        findsOneWidget);
  });

  testWidgets('alumni count replaces the generic note', (tester) async {
    await tester.pumpWidget(wrap(InternshipCard(
        internship: listing(alumni: 3),
        stage: null,
        onTap: () {},
        onToggleSave: () {})));
    expect(find.text('3 UNIBEN students trained here'), findsOneWidget);
    expect(find.text('Open to students of any Nigerian university.'),
        findsNothing);
  });

  testWidgets('save button toggles and has a label', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(InternshipCard(
        internship: listing(),
        stage: null,
        onTap: () {},
        onToggleSave: () => taps++)));
    await tester.tap(find.byTooltip('Save'));
    expect(taps, 1);

    await tester.pumpWidget(wrap(InternshipCard(
        internship: listing(),
        stage: ApplicationStage.saved,
        onTap: () {},
        onToggleSave: () {})));
    expect(find.byTooltip('Remove from saved'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('meets Android tap target and contrast guidelines (${b.name})',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(
          InternshipCard(
              internship: listing(status: ListingStatus.expected),
              stage: ApplicationStage.applied,
              onTap: () {},
              onToggleSave: () {}),
          brightness: b));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}
