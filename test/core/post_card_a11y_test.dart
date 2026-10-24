import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_community_app/core/theme/app_colors.dart';
import 'package:university_community_app/features/home/models/post_model.dart';
import 'package:university_community_app/features/home/widgets/post_card.dart';

Widget wrap(Widget child, Brightness b) {
  final dark = b == Brightness.dark;
  return MaterialApp(
    theme: ThemeData(
      brightness: b,
      colorScheme:
          ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: b)
              .copyWith(
        surface: dark ? AppColors.darkSurface : AppColors.lightSurface,
        onSurface:
            dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        onSurfaceVariant:
            dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      ),
      scaffoldBackgroundColor: dark ? AppColors.darkBg : AppColors.lightBg,
      extensions: [dark ? AppPalette.dark : AppPalette.light],
    ),
    home: Scaffold(body: ListView(children: [child])),
  );
}

PostModel post(String type) => PostModel(
      id: 'p1',
      authorId: 'u1',
      authorName: 'Amaka Osagie',
      authorUsername: 'amaka',
      authorLevel: 'CPE · 400L',
      type: type,
      title: 'Anyone placed at BEDC for SIWES this year?',
      body: 'Trying to find out how long they took to reply.',
      tags: const ['SIWES'],
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      helpfulCount: 3,
      commentCount: 2,
      isInternship: type == 'job' ? true : null,
      jobLocation: type == 'job' ? 'Benin City' : null,
      salary: type == 'job' ? '₦40,000 / month' : null,
    );

void main() {
  for (final b in Brightness.values) {
    for (final type in ['question', 'job', 'announcement']) {
      testWidgets('$type post card passes a11y guidelines (${b.name})',
          (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(wrap(
            PostCard(
                post: post(type),
                onTap: () {},
                onHelpful: () {},
                onComment: () {},
                onSave: () {},
                onAvatarTap: () {}),
            b));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }

  testWidgets('copy link puts a real link on the clipboard', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    await tester
        .pumpWidget(wrap(PostCard(post: post('question')), Brightness.light));
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    final set = calls.where((c) => c.method == 'Clipboard.setData').toList();
    expect(set, hasLength(1));
    expect((set.single.arguments as Map)['text'], 'unicon://open/post/p1');
    expect(find.text('Link copied'), findsOneWidget);
  });
}
