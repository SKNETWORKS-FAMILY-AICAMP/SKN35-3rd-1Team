import 'package:flutter/material.dart';
import '../ui/design.dart';
import '../ui/diary_feed.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const PageWidth(vertical: 36, child: DiaryFeedView());
}
