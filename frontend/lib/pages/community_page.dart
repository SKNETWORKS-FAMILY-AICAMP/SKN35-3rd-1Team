import 'package:flutter/material.dart';
import '../ui/design.dart';
import '../ui/diary_feed.dart';

/// Every member's public impressions in one photo-feed column.
class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});
  @override
  Widget build(BuildContext context) => PageWidth(
    vertical: 40,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScrollReveal(child: Text('감상 피드', style: serif(32))),
            const SizedBox(height: 10),
            Text('한 점의 그림에서 시작된, 각자의 이야기.', style: sans(14, color: muted)),
            const SizedBox(height: 28),
            const DiaryFeedView(),
          ],
        ),
      ),
    ),
  );
}
