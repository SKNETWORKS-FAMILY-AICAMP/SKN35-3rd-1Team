import 'package:flutter/material.dart';
import '../ui/design.dart';
import '../ui/diary_feed.dart';

/// Every member's public impressions as a full-width collage (up to 1980px).
class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1980),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact(context) ? 16 : 40,
          vertical: 40,
        ),
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
