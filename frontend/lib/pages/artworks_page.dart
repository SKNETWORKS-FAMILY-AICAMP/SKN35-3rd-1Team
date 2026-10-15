import 'package:flutter/material.dart';
import '../models.dart';
import '../state.dart';
import '../ui/design.dart';
import 'artists_page.dart';

/// Artwork list with one search for artworks and artists, and a
/// 그림 리스트 / 작가 리스트 toggle.
class ArtworksPage extends StatefulWidget {
  const ArtworksPage({super.key, this.initialView = 'works'});
  final String initialView;
  @override
  State<ArtworksPage> createState() => _ArtworksPageState();
}

class _ArtworksPageState extends State<ArtworksPage> {
  late bool artistsView = widget.initialView == 'artists';
  String movement = '', query = '';
  int visible = 12;
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  bool _matchesWork(ArtlogState s, Artwork a) =>
      query.isEmpty ||
      '${a.title} ${a.titleEn} ${s.artistName(a)} ${s.artistEnglish(a)}'
          .toLowerCase()
          .contains(query.toLowerCase());

  void _setView(bool artists) => setState(() {
    artistsView = artists;
    visible = 12;
  });

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    final lower = query.toLowerCase();
    final matchedWorks = s.artworks.where((a) => _matchesWork(s, a));
    final works = matchedWorks
        .where((a) => movement.isEmpty || a.movementId == movement)
        .toList();
    final artistIdsFromWorks = matchedWorks.map((a) => a.artistId).toSet();
    final artists = s.artists
        .where(
          (a) =>
              query.isEmpty ||
              '${a.name} ${a.english} ${s.artistMovement(a)}'
                  .toLowerCase()
                  .contains(lower) ||
              artistIdsFromWorks.contains(a.id),
        )
        .toList();
    return PageWidth(
      vertical: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('THE COLLECTION'),
          const SizedBox(height: 12),
          Text('작품 리스트', style: serif(compact(context) ? 30 : 36)),
          const SizedBox(height: 10),
          Text('그림과 작가를 한 번에 찾아보세요.', style: sans(14, color: muted)),
          const SizedBox(height: 26),
          TextField(
            key: const ValueKey('artworks-search'),
            controller: search,
            style: sans(14),
            onChanged: (v) => setState(() {
              query = v.trim();
              visible = 12;
            }),
            decoration: InputDecoration(
              hintText: '작가 이름이나 그림 제목으로 검색',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '검색어 지우기',
                      onPressed: () {
                        search.clear();
                        setState(() => query = '');
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          _ViewToggle(artists: artistsView, onChanged: _setView),
          const SizedBox(height: 18),
          if (!artistsView)
            _Tabs(
              items: [('', '전체'), for (final m in s.movements) (m.id, m.name)],
              selected: movement,
              onSelected: (id) => setState(() {
                movement = id;
                visible = 12;
              }),
            ),
          const SizedBox(height: 24),
          if (!artistsView) ...[
            Text('총 ${works.length}점의 작품', style: sans(12, color: muted)),
            const SizedBox(height: 16),
            if (works.isEmpty)
              const EmptyView(
                '찾는 그림이 없어요.',
                description: '다른 사조를 고르거나 검색어를 바꿔 보세요.',
              )
            else
              ArtworkGrid(works.take(visible).toList()),
            if (works.length > visible)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(
                  child: ArtButton(
                    '더보기',
                    key: const ValueKey('artworks-more'),
                    icon: Icons.add,
                    outline: true,
                    onTap: () => setState(() => visible += 12),
                  ),
                ),
              ),
          ] else
            ArtistGrid(artists),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.artists, required this.onChanged});
  final bool artists;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: soft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in [(false, '그림 리스트'), (true, '작가 리스트')])
          Semantics(
            selected: artists == item.$1,
            child: TextButton(
              key: ValueKey('artworks-view-${item.$1 ? 'artists' : 'works'}'),
              onPressed: () => onChanged(item.$1),
              style: editorialButtonStyle(
                dark: artists == item.$1,
                quiet: artists != item.$1,
                minimumSize: const Size(120, 40),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: Text(
                item.$2,
                style: sans(
                  13,
                  height: 1.2,
                  color: artists == item.$1 ? Colors.white : muted,
                  weight: artists == item.$1
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.items,
    required this.selected,
    required this.onSelected,
  });
  final List<(String, String)> items;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items)
            DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected == item.$1 ? ink : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: TextButton(
                key: ValueKey('artworks-tab-${item.$1}'),
                onPressed: () => onSelected(item.$1),
                style: editorialButtonStyle(
                  quiet: true,
                  radius: 0,
                  minimumSize: const Size(44, 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ).copyWith(side: const WidgetStatePropertyAll(BorderSide.none)),
                child: Text(
                  item.$2,
                  style: sans(
                    13,
                    color: selected == item.$1 ? ink : muted,
                    weight: selected == item.$1
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
