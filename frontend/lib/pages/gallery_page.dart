import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../ui/design.dart';
import '../ui/personal_recommendations.dart';

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
    final hero =
        s.artworks.where((a) => a.isFeatured).firstOrNull ?? s.artworks.first;
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
        PageWidth(
          vertical: 46,
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 640;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined, size: 23, color: sage),
                      SizedBox(width: 9),
                      Expanded(child: Eyebrow('A LITTLE ART, EVERY DAY')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '그림을 보는 시간,\n나를 발견하는 순간'),
                        TextSpan(
                          text: '.',
                          style: serif(wide ? 42 : 34, color: sage),
                        ),
                      ],
                    ),
                    style: serif(
                      wide ? (c.maxWidth > 1050 ? 42 : 32) : 34,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 19),
                  Text(
                    '한 점의 그림에서 시작되는 새로운 이야기.\n나만의 속도로, 나만의 미술관을 만나보세요.',
                    style: sans(13, color: muted, height: 2),
                  ),
                  const SizedBox(height: 26),
                  ArtButton(
                    '오늘의 그림 발견하기',
                    onTap: () => Scrollable.ensureVisible(
                      collectionKey.currentContext!,
                      duration: const Duration(milliseconds: 400),
                    ),
                  ),
                  if (wide) ...[
                    const SizedBox(height: 35),
                    Row(
                      children: [
                        SizedBox(
                          width: 88,
                          height: 35,
                          child: Stack(
                            children: [
                              for (
                                var i = 0;
                                i < s.artworks.take(3).length;
                                i++
                              )
                                Positioned(
                                  left: i * 25.0,
                                  child: ClipOval(
                                    child: ArtImage(
                                      s.artworks[i].image,
                                      width: 34,
                                      height: 34,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${s.artists.length}명의 거장과 함께하는\n작지만 깊은 미술 여행',
                          style: sans(10, color: muted),
                        ),
                      ],
                    ),
                  ],
                ],
              );
              final image = Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Semantics(
                      label: '오늘의 작품 ${hero.title} 감상하기',
                      button: true,
                      child: InkWell(
                        onTap: () => context.go('/artwork/${hero.id}'),
                        child: SizedBox(
                          height: wide ? 432 : 330,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ArtImage(hero.image, label: hero.title),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.transparent,
                                      Color(0xb314231a),
                                    ],
                                  ),
                                ),
                              ),
                              const Positioned(
                                top: 24,
                                left: 25,
                                right: 25,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Eyebrow(
                                      'CURATOR’S PICK',
                                      color: Colors.white,
                                    ),
                                    Eyebrow('ART NOTE 01', color: Colors.white),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 29,
                                left: 29,
                                right: 29,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '오늘, 이 그림',
                                            style: sans(
                                              10,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            hero.title,
                                            style: serif(
                                              24,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '${s.artistName(hero)} · ${hero.year}',
                                            style: sans(
                                              11,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white60,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.north_east,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'A moment to pause, a world to discover.',
                          style: english(14, color: muted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Eyebrow('EST. 2026'),
                    ],
                  ),
                ],
              );
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 45, child: copy),
                        SizedBox(width: c.maxWidth > 1000 ? 52 : 28),
                        Expanded(flex: 55, child: image),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [copy, const SizedBox(height: 30), image],
                    );
            },
          ),
        ),
        PageWidth(
          child: Column(
            key: collectionKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                eyebrow: 'THE COLLECTION',
                title: '어떤 그림에 마음이 머무나요?',
                subtitle: '마음이 가는 작품을 고르고, 그 안의 이야기를 들어보세요.',
                trailing: Column(
                  children: [
                    Text(
                      '${s.artworks.length}',
                      style: english(38, color: muted),
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
                      const SizedBox(width: 26),
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
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                      ),
                    ),
                  );
                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: line)),
                    ),
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
                    ChoiceChip(
                      label: Text(
                        f.$2,
                        style: sans(
                          12,
                          color: filter == f.$1 ? Colors.white : muted,
                        ),
                      ),
                      selected: filter == f.$1,
                      showCheckmark: false,
                      selectedColor: green,
                      backgroundColor: paper,
                      side: BorderSide(color: filter == f.$1 ? green : line),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
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
        const PersonalRecommendations(),
        PageWidth(
          vertical: 65,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: green,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: EdgeInsets.all(compact(context) ? 28 : 45),
            child: LayoutBuilder(
              builder: (context, c) => Row(
                children: [
                  if (c.maxWidth > 700) ...[
                    Transform.rotate(
                      angle: -0.06,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        color: const Color(0xffe3e4d3),
                        child: ArtImage(
                          s.artworks
                                  .where((a) => s.artistName(a).contains('모네'))
                                  .firstOrNull
                                  ?.image ??
                              hero.image,
                          width: 220,
                          height: 230,
                        ),
                      ),
                    ),
                    const SizedBox(width: 55),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow(
                          '✳  YOUR PERSONAL DOCENT',
                          color: Color(0xffc2cbb1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '그림 앞에서 생긴 물음표,\n이야기가 되는 순간.',
                          style: serif(
                            compact(context) ? 23 : 28,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          '작품을 고르고 도슨트에게 물어보세요.\n답변의 출처까지, 함께 살펴볼 수 있어요.',
                          style: sans(12, color: const Color(0xffcad2bf)),
                        ),
                        const SizedBox(height: 25),
                        ArtButton(
                          '도슨트와 대화해 보기',
                          light: true,
                          onTap: () => context.go('/artwork/${hero.id}'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                                    borderRadius: BorderRadius.circular(2),
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
  Widget _tab(String label, bool active, VoidCallback action) => InkWell(
    onTap: action,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: active ? green : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(
        label,
        style: sans(
          12,
          color: active ? green : muted,
          weight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}
