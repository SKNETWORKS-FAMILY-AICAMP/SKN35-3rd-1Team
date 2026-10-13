import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/design.dart';
import '../ui/diary_feed.dart';
import '../ui/diary_editor.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    final feed = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('감상 피드', style: serif(32)),
        const SizedBox(height: 10),
        Text('한 점의 그림에서 시작된, 각자의 이야기.', style: sans(14, color: muted)),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: () => showDiaryComposer(context),
          style: editorialButtonStyle(padding: const EdgeInsets.all(18)),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: soft,
                child: Icon(Icons.edit_outlined, size: 18, color: green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('오늘의 감상을 남겨보세요', style: sans(13, color: muted)),
              ),
              const Icon(Icons.add, size: 19),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const DiaryFeedView(),
      ],
    );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Eyebrow('YOUR SPACE'),
        const SizedBox(height: 16),
        Text(
          s.memberProfile?.nickname.isNotEmpty == true
              ? s.memberProfile!.nickname
              : '나의 감상 공간',
          style: serif(22),
        ),
        const SizedBox(height: 12),
        Text(
          '좋아한 그림 ${s.likes.length}점 · 관심 작가 ${s.follows.length}명',
          style: sans(12, color: muted),
        ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: () => context.go('/mypage'),
          icon: const Icon(Icons.person_outline, size: 18),
          label: const Text('마이페이지'),
        ),
        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 24),
        const Eyebrow('BEHIND THE WORK'),
        const SizedBox(height: 16),
        Text('작가를 더 가까이', style: serif(21)),
        const SizedBox(height: 14),
        for (final artist in s.artists.take(3))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 42,
              height: 48,
              child: ArtImage(s.representativeImage(artist)),
            ),
            title: Text(artist.name, style: sans(13)),
            subtitle: Text(
              s.artistMovement(artist),
              style: sans(11, color: muted),
            ),
            trailing: const Icon(Icons.chevron_right, size: 17),
            onTap: () => context.go('/artist/${artist.id}'),
          ),
        TextButton(
          onPressed: () => context.go('/artists'),
          child: const Text('작가 모두 보기 →'),
        ),
        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 20),
        Text(
          '공개한 감상만 피드에 표시됩니다.\n개인 기록은 내 서재에서 관리하세요.',
          style: sans(12, color: muted),
        ),
        TextButton(
          onPressed: () => context.go('/library'),
          child: const Text('내 서재 열기 →'),
        ),
      ],
    );
    return PageWidth(
      vertical: 40,
      child: LayoutBuilder(
        builder: (context, c) => Align(
          alignment: Alignment.topCenter,
          child: c.maxWidth >= 1000
              ? SizedBox(
                  width: 1016,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: feed),
                      const SizedBox(width: 64),
                      SizedBox(width: 260, child: side),
                    ],
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 660),
                  child: feed,
                ),
        ),
      ),
    );
  }
}
