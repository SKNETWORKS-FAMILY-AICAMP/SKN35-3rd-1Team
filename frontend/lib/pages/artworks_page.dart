import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  String movement = '', artist = '', query = '';
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
    final selectedArtist = artist.isEmpty
        ? null
        : artists.where((a) => a.id == artist).firstOrNull;
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
          _Tabs(
            key: ValueKey('tabs-$artistsView'),
            items: artistsView
                ? [('', '전체'), for (final a in artists) (a.id, a.name)]
                : [('', '전체'), for (final m in s.movements) (m.id, m.name)],
            selected: artistsView ? artist : movement,
            onSelected: (id) => setState(() {
              if (artistsView) {
                artist = id;
              } else {
                movement = id;
              }
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
                    '그림 더 보기  ${works.length - visible}',
                    outline: true,
                    onTap: () => setState(() => visible += 12),
                  ),
                ),
              ),
          ] else if (selectedArtist == null)
            ArtistGrid(artists)
          else
            _ArtistSection(
              artist: selectedArtist,
              works: s.artworks
                  .where((a) => a.artistId == selectedArtist.id)
                  .toList(),
            ),
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
              ),
              child: Text(
                item.$2,
                style: sans(
                  13,
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
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });
  final List<(String, String)> items;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => DecoratedBox(
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
                  minimumSize: const Size(44, 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
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

class _ArtistSection extends StatelessWidget {
  const _ArtistSection({required this.artist, required this.works});
  final Artist artist;
  final List<Artwork> works;
  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ArtImage(
                s.representativeImage(artist),
                width: compact(context) ? 72 : 110,
                height: compact(context) ? 90 : 136,
                label: '${artist.name}의 작품 일부',
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(s.artistMovement(artist)),
                  const SizedBox(height: 6),
                  Text(artist.name, style: serif(26)),
                  Text(
                    '${artist.english}  ${artist.years}',
                    style: english(19, color: muted),
                  ),
                  if (artist.summary.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      artist.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: sans(13, color: muted),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      LikeButton(
                        liked: s.follows.contains(artist.id),
                        subject: artist.name,
                        onPressed: s.pendingFollows.contains(artist.id)
                            ? null
                            : () => likeArtist(context, artist),
                      ),
                      TextButton(
                        onPressed: () => context.go('/artist/${artist.id}'),
                        child: const Text('작가 페이지 보기 →'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (works.isEmpty)
          const EmptyView('작품을 준비하고 있어요.')
        else
          ArtworkGrid(works),
      ],
    );
  }
}
