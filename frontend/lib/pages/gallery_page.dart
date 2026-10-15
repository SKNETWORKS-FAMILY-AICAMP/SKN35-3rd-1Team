import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/design.dart';
import '../ui/personal_recommendations.dart';
import '../ui/daily_artwork_hero.dart';
import '../ui/museum_theme.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});
  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final collectionKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (s.artworks.isEmpty) {
      return const PageWidth(
        child: EmptyView(
          '아직 전시 준비 중이에요.',
          inverse: true,
          description: '새로운 작품이 도착하면 이곳에서 만나볼 수 있어요.',
        ),
      );
    }
    final list = [
      ...s.artworks.where((a) => a.isFeatured),
      ...s.artworks.where((a) => !a.isFeatured),
    ];
    return MuseumTheme(
      child: ColoredBox(
        color: museumBlack,
        child: Column(
          children: [
            DailyArtworkHero(
              works: randomArtworks(s.artworks, s.heroSeed),
              onExplore: () => Scrollable.ensureVisible(
                collectionKey.currentContext!,
                alignment: 0,
                duration: reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
              ),
            ),
            const PersonalRecommendations(inverse: true),
            const _ArtistStories(),
            const SizedBox(height: sectionGap),
            PageWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(
                    key: collectionKey,
                    inverse: true,
                    eyebrow: 'ON VIEW',
                    title: '지금 전시 중인 그림',
                    subtitle: '작가와 사조를 따라, 다음 그림을 찾아보세요.',
                    trailing: Column(
                      children: [
                        Text(
                          '${s.artworks.length}',
                          style: english(28, color: museumMuted),
                        ),
                        const Eyebrow('ARTWORKS', color: museumMuted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ArtworkGrid(list.take(6).toList(), museum: true),
                  Padding(
                    padding: const EdgeInsets.only(top: 38),
                    child: Center(
                      child: OutlinedButton.icon(
                        key: const ValueKey('gallery-more-artworks'),
                        label: const Text('그림 더 만나보기'),
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () => context.go('/artworks?view=works'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: sectionGap),
            PageWidth(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: museumLine),
                    bottom: BorderSide(color: museumLine),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 24,
                  runSpacing: 18,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '그림을 보는 다른 시선',
                          style: serif(24, color: museumText),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '다른 감상가의 이야기를 만나고, 나의 생각도 남겨보세요.',
                          style: sans(13, color: museumMuted),
                        ),
                      ],
                    ),
                    ArtButton(
                      '감상 피드 둘러보기',
                      light: true,
                      onTap: () => context.go('/community'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Artist cards that used to close the page now follow the recommendations.
class _ArtistStories extends StatelessWidget {
  const _ArtistStories();
  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: sectionGap),
      child: PageWidth(
        child: Column(
          children: [
            SectionTitle(
              inverse: true,
              eyebrow: 'BEHIND THE CANVAS',
              title: '그림 너머, 작가의 이야기',
              trailing: TextButton(
                onPressed: () => context.go('/artworks?view=artists'),
                child: Text('작가 모두 보기 ↗', style: sans(11, color: museumText)),
              ),
            ),
            const SizedBox(height: 25),
            LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth <= 0) return const SizedBox.shrink();
                final cols = c.maxWidth > 800
                    ? 4
                    : c.maxWidth >= 280
                    ? 2
                    : 1;
                final width = (c.maxWidth - (cols - 1) * 24) / cols;
                return Wrap(
                  spacing: 24,
                  runSpacing: 20,
                  children: [
                    for (final a in s.artists.take(4))
                      SizedBox(
                        width: width,
                        child: InkWell(
                          onTap: () => context.go('/artist/${a.id}'),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ArtImage(
                                  s.representativeImage(a),
                                  width: 50,
                                  height: 64,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.artistMovement(a),
                                      style: sans(9, color: museumMuted),
                                    ),
                                    Text(
                                      a.name,
                                      style: sans(12, color: museumText),
                                    ),
                                    Text(
                                      a.english,
                                      style: english(14, color: museumMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
