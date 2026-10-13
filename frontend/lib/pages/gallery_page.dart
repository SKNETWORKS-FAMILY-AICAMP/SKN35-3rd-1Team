import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../ui/design.dart';
import '../ui/personal_recommendations.dart';
import '../ui/daily_artwork_hero.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});
  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  bool byArtist = false;
  String filter = '', query = '', sort = 'curated';
  int visible = 8;
  final collectionKey = GlobalKey();
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (s.artworks.isEmpty) {
      return const PageWidth(
        child: EmptyView(
          '아직 전시 준비 중이에요.',
          description: '새로운 작품이 도착하면 이곳에서 만나볼 수 있어요.',
        ),
      );
    }
    final filters = byArtist
        ? s.artists.map((a) => (a.id, a.name)).toList()
        : s.movements.map((m) => (m.id, m.name)).toList();
    var list = s.artworks
        .where(
          (a) =>
              (filter.isEmpty ||
                  (byArtist ? a.artistId : a.movementId) == filter) &&
              '${a.title} ${a.titleEn} ${s.artistName(a)} ${s.artistEnglish(a)}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    if (sort == 'year') list.sort((a, b) => _year(a).compareTo(_year(b)));
    if (sort == 'name') list.sort((a, b) => a.title.compareTo(b.title));
    if (sort == 'curated' && !s.config.demo) {
      list = [
        ...list.where((a) => a.isFeatured),
        ...list.where((a) => !a.isFeatured),
      ];
    }
    if (sort == 'curated' && s.config.demo) {
      list.sort(
        (a, b) => (s.follows.contains(b.artistId) ? 1 : 0).compareTo(
          s.follows.contains(a.artistId) ? 1 : 0,
        ),
      );
    }
    return Column(
      children: [
        DailyArtworkHero(
          works: dailyArtworks(s.artworks, seoulDate()),
          onExplore: () => Scrollable.ensureVisible(
            collectionKey.currentContext!,
            alignment: .24,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 350),
          ),
        ),
        const SizedBox(height: 36),
        const PersonalRecommendations(),
        PageWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                key: collectionKey,
                eyebrow: 'THE COLLECTION',
                title: '소장 작품',
                subtitle: '작가와 사조를 따라, 다음 그림을 찾아보세요.',
                trailing: Column(
                  children: [
                    Text(
                      '${s.artworks.length}',
                      style: english(28, color: muted),
                    ),
                    const Eyebrow('ARTWORKS'),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              LayoutBuilder(
                builder: (context, c) {
                  final tabs = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _tab(
                        '사조별로 보기',
                        !byArtist,
                        () => setState(() {
                          byArtist = false;
                          filter = '';
                          visible = 8;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _tab(
                        '작가별로 보기',
                        byArtist,
                        () => setState(() {
                          byArtist = true;
                          filter = '';
                          visible = 8;
                        }),
                      ),
                    ],
                  );
                  final field = SizedBox(
                    width: c.maxWidth > 620 ? 230 : c.maxWidth,
                    child: TextField(
                      controller: search,
                      style: sans(12),
                      onChanged: (v) => setState(() {
                        query = v;
                        visible = 8;
                      }),
                      decoration: InputDecoration(
                        hintText: '어떤 작품을 찾으세요?',
                        hintStyle: sans(11, color: muted),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '검색어 지우기',
                                onPressed: () {
                                  search.clear();
                                  setState(() => query = '');
                                },
                                icon: const Icon(Icons.close, size: 16),
                              ),
                      ),
                    ),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: c.maxWidth > 620
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [tabs, field],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [tabs, field],
                          ),
                  );
                },
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 9,
                children: [
                  for (final f in [('', '전체'), ...filters])
                    FilterPill(
                      label: Text(
                        f.$2,
                        style: sans(
                          12,
                          color: filter == f.$1 ? Colors.white : muted,
                        ),
                      ),
                      selected: filter == f.$1,
                      onSelected: (_) => setState(() {
                        filter = f.$1;
                        visible = 8;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('총 ${list.length}점의 작품', style: sans(11, color: muted)),
                  DropdownButton<String>(
                    value: sort,
                    underline: const SizedBox.shrink(),
                    style: sans(11, color: muted),
                    items: const [
                      DropdownMenuItem(
                        value: 'curated',
                        child: Text('큐레이터 추천순'),
                      ),
                      DropdownMenuItem(value: 'year', child: Text('제작 연도순')),
                      DropdownMenuItem(value: 'name', child: Text('작품 이름순')),
                    ],
                    onChanged: (v) => setState(() => sort = v!),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                EmptyView(
                  '아직 만나지 못한 그림이네요.',
                  description: '다른 작품명이나 작가 이름으로 찾아보세요.',
                  action: ArtButton(
                    '모든 작품 보기',
                    outline: true,
                    onTap: () {
                      search.clear();
                      setState(() {
                        query = '';
                        filter = '';
                      });
                    },
                  ),
                )
              else
                ArtworkGrid(list.take(visible).toList()),
              if (list.length > visible)
                Padding(
                  padding: const EdgeInsets.only(top: 38),
                  child: Center(
                    child: ArtButton(
                      '그림 더 만나보기  ${list.length - visible}',
                      outline: true,
                      icon: Icons.arrow_forward,
                      onTap: () => setState(() => visible += 8),
                    ),
                  ),
                ),
            ],
          ),
        ),
        PageWidth(
          vertical: 56,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: line),
                bottom: BorderSide(color: line),
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
                    Text('그림을 보는 다른 시선', style: serif(24)),
                    const SizedBox(height: 6),
                    Text(
                      '다른 감상가의 이야기를 만나고, 나의 생각도 남겨보세요.',
                      style: sans(13, color: muted),
                    ),
                  ],
                ),
                ArtButton(
                  '감상 피드 둘러보기',
                  outline: true,
                  onTap: () => context.go('/community'),
                ),
              ],
            ),
          ),
        ),
        PageWidth(
          child: Column(
            children: [
              SectionTitle(
                eyebrow: 'BEHIND THE CANVAS',
                title: '그림 너머, 작가의 이야기',
                trailing: TextButton(
                  onPressed: () => context.go('/artists'),
                  child: Text('작가 모두 보기 ↗', style: sans(11, color: green)),
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
                    children: s.artists
                        .take(4)
                        .map(
                          (a) => SizedBox(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.artistMovement(a),
                                          style: sans(9, color: muted),
                                        ),
                                        Text(a.name, style: sans(12)),
                                        Text(
                                          a.english,
                                          style: english(14, color: muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  int _year(Artwork a) =>
      int.tryParse(RegExp(r'\d{4}').firstMatch(a.year)?.group(0) ?? '9999') ??
      9999;
  Widget _tab(String label, bool active, VoidCallback action) => TextButton(
    onPressed: action,
    style: editorialButtonStyle(
      dark: active,
      quiet: !active,
      minimumSize: const Size(44, 46),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    child: Text(
      label,
      style: sans(
        12,
        color: active ? Colors.white : muted,
        weight: active ? FontWeight.w600 : FontWeight.w500,
      ),
    ),
  );
}
