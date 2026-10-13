import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import 'design.dart';

List<Artwork> dailyArtworks(List<Artwork> works, String date) {
  final pictured = works.where((a) => a.image.isNotEmpty).toList();
  final featured = pictured.where((a) => a.isFeatured).toList();
  final pool = featured.length >= 3 ? featured : pictured;
  if (pool.isEmpty) {
    return [
      ...works.where((a) => a.isFeatured),
      ...works.where((a) => !a.isFeatured),
    ].take(3).toList();
  }
  final offset =
      DateTime.parse(date).difference(DateTime(2026)).inDays.abs() %
      pool.length;
  final ordered = [...pool.skip(offset), ...pool.take(offset)];
  final picked = <Artwork>[];
  for (final work in ordered) {
    if (picked.every((a) => a.artistId != work.artistId)) picked.add(work);
    if (picked.length == 3) break;
  }
  for (final work in ordered) {
    if (picked.length == 3) break;
    if (picked.every((a) => a.id != work.id)) picked.add(work);
  }
  return picked;
}

class DailyArtworkHero extends StatefulWidget {
  const DailyArtworkHero({
    super.key,
    required this.works,
    required this.onExplore,
  });
  final List<Artwork> works;
  final VoidCallback onExplore;
  @override
  State<DailyArtworkHero> createState() => _DailyArtworkHeroState();
}

class _DailyArtworkHeroState extends State<DailyArtworkHero> {
  final pages = PageController();
  int selected = 0;
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  void go(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      pages.jumpToPage(index);
    } else {
      pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context), small = compact(context);
    final height = MediaQuery.sizeOf(
      context,
    ).height.clamp(540.0, double.infinity);
    final current = widget.works[selected.clamp(0, widget.works.length - 1)];
    return SizedBox(
      key: const ValueKey('daily-fullscreen-hero'),
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: pages,
            itemCount: widget.works.length,
            onPageChanged: (i) => setState(() => selected = i),
            itemBuilder: (context, i) => Semantics(
              label: '오늘의 그림 ${i + 1}, ${widget.works[i].title}',
              image: true,
              child: ArtImage(
                widget.works[i].image,
                label: widget.works[i].title,
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .36, .65, 1],
                  colors: [
                    Color(0x55101e30),
                    Color(0x05101e30),
                    Color(0x55101e30),
                    Color(0xf0101e30),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: small ? 22 : 56,
            right: small ? 22 : 56,
            bottom: small ? 32 : 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Eyebrow('TODAY, THROUGH ART', color: Colors.white),
                const SizedBox(height: 14),
                Text(
                  '오늘, 이 그림',
                  style: sans(13, color: Colors.white.withValues(alpha: .85)),
                ),
                const SizedBox(height: 6),
                Text(
                  current.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: serif(
                    small ? 38 : 72,
                    color: Colors.white,
                    height: 1.22,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${s.artistName(current)} · ${current.year}',
                  style: sans(small ? 12 : 15, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ArtButton(
                      '작품 감상하기',
                      light: true,
                      onTap: () => context.go('/artwork/${current.id}'),
                    ),
                    TextButton(
                      onPressed: widget.onExplore,
                      style: crystalButtonStyle(
                        dark: true,
                        minimumSize: const Size(44, 48),
                      ),
                      child: const Text('작품 컬렉션 ↓'),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    GlassSurface(
                      dark: true,
                      radius: 100,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '이전 오늘의 그림',
                            style: crystalButtonStyle(
                              dark: true,
                              quiet: true,
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.all(11),
                            ),
                            onPressed: widget.works.length > 1
                                ? () => go(
                                    (selected - 1 + widget.works.length) %
                                        widget.works.length,
                                  )
                                : null,
                            icon: const Icon(
                              Icons.arrow_back,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '${(selected + 1).toString().padLeft(2, '0')} / ${widget.works.length.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '다음 오늘의 그림',
                            style: crystalButtonStyle(
                              dark: true,
                              quiet: true,
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.all(11),
                            ),
                            onPressed: widget.works.length > 1
                                ? () => go((selected + 1) % widget.works.length)
                                : null,
                            icon: const Icon(
                              Icons.arrow_forward,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (small && MediaQuery.sizeOf(context).width >= 360)
                      Text(
                        '오늘의 ${widget.works.length}점',
                        style: sans(11, color: Colors.white),
                      ),
                    if (!small)
                      for (var i = 0; i < widget.works.length; i++)
                        Semantics(
                          selected: i == selected,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: small ? 32 : 58,
                              height: small ? 44 : 58,
                              child: Tooltip(
                                message:
                                    '오늘의 그림 ${i + 1}: ${widget.works[i].title}',
                                child: InkWell(
                                  onTap: () => go(i),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: i == selected
                                            ? Colors.white
                                            : const Color(0x55ffffff),
                                        width: i == selected ? 2 : 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: ArtImage(widget.works[i].image),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
