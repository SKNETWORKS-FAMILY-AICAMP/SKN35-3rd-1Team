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
    if (widget.works.isEmpty) return const SizedBox.shrink();
    final s = ArtlogScope.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 850;
    final height = (MediaQuery.sizeOf(context).height - 128).clamp(
      540.0,
      1000.0,
    );
    final current = widget.works[selected.clamp(0, widget.works.length - 1)];
    final actions = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ArtButton(
          '작품 감상하기',
          light: true,
          onTap: () => context.go('/artwork/${current.id}'),
        ),
        TextButton(
          style: editorialButtonStyle(dark: true, quiet: true).copyWith(
            side: const WidgetStatePropertyAll(
              BorderSide(color: Color(0xff72786c)),
            ),
          ),
          onPressed: widget.onExplore,
          child: const Text('작품 둘러보기'),
        ),
      ],
    );
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Eyebrow('THE DAILY SELECTION', color: Color(0xffc1c5bc)),
        const SizedBox(height: 12),
        Text('오늘, 이 그림', style: sans(12, color: const Color(0xffc1c5bc))),
        const SizedBox(height: 5),
        Text(
          current.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: serif(mobile ? 30 : 42, color: Colors.white, height: 1.3),
        ),
        const SizedBox(height: 12),
        Text(
          '${s.artistName(current)} · ${current.year}',
          style: sans(13, color: const Color(0xffc1c5bc)),
        ),
      ],
    );
    final information = Container(
      color: ink,
      padding: EdgeInsets.all(mobile ? 24 : 32),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [description, const SizedBox(height: 20), actions],
            )
          : Row(
              children: [
                Expanded(child: description),
                const SizedBox(width: 32),
                SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ArtButton(
                        '작품 감상하기',
                        light: true,
                        onTap: () => context.go('/artwork/${current.id}'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: editorialButtonStyle(dark: true, quiet: true)
                            .copyWith(
                              side: const WidgetStatePropertyAll(
                                BorderSide(color: Color(0xff72786c)),
                              ),
                            ),
                        onPressed: widget.onExplore,
                        child: const Text('작품 둘러보기'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
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
          Positioned(
            top: 20,
            right: mobile ? 16 : 40,
            child: Container(
              color: ink,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(selected + 1).toString().padLeft(2, '0')} / ${widget.works.length.toString().padLeft(2, '0')}',
                    style: sans(12, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '이전 오늘의 그림',
                    style: editorialButtonStyle(dark: true, quiet: true),
                    onPressed: widget.works.length > 1
                        ? () => go(
                            (selected - 1 + widget.works.length) %
                                widget.works.length,
                          )
                        : null,
                    icon: const Icon(Icons.arrow_back, size: 18),
                  ),
                  IconButton(
                    tooltip: '다음 오늘의 그림',
                    style: editorialButtonStyle(dark: true, quiet: true),
                    onPressed: widget.works.length > 1
                        ? () => go((selected + 1) % widget.works.length)
                        : null,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: mobile ? 0 : 40,
            left: mobile ? 0 : null,
            child: mobile
                ? information
                : SizedBox(
                    width: MediaQuery.sizeOf(context).width * .68,
                    child: information,
                  ),
          ),
        ],
      ),
    );
  }
}
