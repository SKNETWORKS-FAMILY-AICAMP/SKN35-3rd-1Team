import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../state.dart';
import '../ui/design.dart';

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});
  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    final artists = s.artists
        .where(
          (a) => '${a.name} ${a.english} ${s.artistMovement(a)}'
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    return PageWidth(
      vertical: 45,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('THE ARTISTS'),
          const SizedBox(height: 17),
          Text('그림을 남긴 사람들.', style: serif(compact(context) ? 32 : 40)),
          const SizedBox(height: 14),
          Text(
            '시대도, 시선도 다른 ${s.artists.length}명의 거장.\n마음이 닿는 작가의 세계로 들어가 보세요.',
            style: sans(13, color: muted),
          ),
          const SizedBox(height: 15),
          Text(
            'Meet the minds behind the masterpieces.',
            style: english(21, color: sage),
          ),
          const SizedBox(height: 30),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${artists.length}명의 작가',
                  style: sans(12, color: muted),
                ),
              ),
              SizedBox(
                width: compact(context) ? 180 : 250,
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  style: sans(12),
                  decoration: InputDecoration(
                    hintText: '작가 또는 사조 검색',
                    hintStyle: sans(11, color: muted),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (artists.isEmpty)
            const EmptyView('검색된 작가가 없어요.', description: '다른 이름이나 사조로 찾아보세요.')
          else
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 1000
                    ? 4
                    : c.maxWidth > 680
                    ? 3
                    : 2;
                final gap = compact(context) ? 17.0 : 25.0;
                final width = (c.maxWidth - (cols - 1) * gap) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: 34,
                  children: artists
                      .map(
                        (a) => SizedBox(
                          width: width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: InkWell(
                                  onTap: () => context.go('/artist/${a.id}'),
                                  child: SizedBox(
                                    height: compact(context) ? 210 : 300,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ArtImage(
                                          s.representativeImage(a),
                                          label: '${a.name}의 작품 일부',
                                        ),
                                        Positioned(
                                          top: 14,
                                          left: 14,
                                          child: Container(
                                            color: paper.withValues(alpha: 0.9),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 5,
                                            ),
                                            child: Text(
                                              s.artistMovement(a),
                                              style: sans(9, color: green),
                                            ),
                                          ),
                                        ),
                                        const Positioned(
                                          bottom: 15,
                                          right: 15,
                                          child: Icon(
                                            Icons.north_east,
                                            color: Colors.white,
                                            size: 23,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 13),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () =>
                                          context.go('/artist/${a.id}'),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a.name,
                                            style: serif(
                                              compact(context) ? 17 : 20,
                                            ),
                                          ),
                                          Text(
                                            a.english,
                                            style: english(18, color: muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                        '${a.name} ${s.follows.contains(a.id) ? '팔로우 취소' : '팔로우'}',
                                    onPressed: s.pendingFollows.contains(a.id)
                                        ? null
                                        : () => followArtist(context, a),
                                    icon: Icon(
                                      s.follows.contains(a.id)
                                          ? Icons.check_circle_outline
                                          : Icons.add_circle_outline,
                                      size: 23,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 9),
                              Text(
                                a.summary,
                                style: sans(11, color: muted),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class ArtistDetailPage extends StatefulWidget {
  const ArtistDetailPage({super.key, required this.id});
  final String id;
  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  Future<(Artist, List<Artwork>)>? future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<(Artist, List<Artwork>)> load() async {
    final s = ArtlogScope.of(context);
    final results = await Future.wait<Object>([
      s.artistDetail(widget.id),
      s.config.demo
          ? Future.value(
              s.artworks.where((a) => a.artistId == widget.id).toList(),
            )
          : s.api.artworks(artistId: widget.id),
    ]);
    return (results[0] as Artist, results[1] as List<Artwork>);
  }

  @override
  Widget build(BuildContext context) => PageWidth(
    vertical: 40,
    child: FutureBuilder<(Artist, List<Artwork>)>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyView(
            ArtlogState.message(snapshot.error!),
            action: ArtButton(
              '다시 불러오기',
              onTap: () => setState(() {
                future = load();
              }),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 450,
            child: Center(child: CircularProgressIndicator(color: green)),
          );
        }
        final (artist, works) = snapshot.data!;
        final s = ArtlogScope.of(context);
        final image = ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: ArtImage(
            artist.portrait.isNotEmpty
                ? artist.portrait
                : works.firstOrNull?.image ?? '',
            height: compact(context) ? 310 : 390,
            label: '${artist.name}의 작품 일부',
          ),
        );
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('BEHIND THE CANVAS · ${s.artistMovement(artist)}'),
            const SizedBox(height: 18),
            Text(artist.name, style: serif(35)),
            Text(
              '${artist.english}  ${artist.years}',
              style: english(23, color: muted),
            ),
            const SizedBox(height: 23),
            Text(artist.summary, style: sans(14, color: muted, height: 2)),
            const SizedBox(height: 27),
            ArtButton(
              s.follows.contains(artist.id) ? '팔로우하고 있어요' : '작가 팔로우',
              icon: s.follows.contains(artist.id) ? Icons.check : Icons.add,
              onTap: s.pendingFollows.contains(artist.id)
                  ? null
                  : () => followArtist(context, artist),
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/artists'),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('모든 작가'),
            ),
            const SizedBox(height: 25),
            LayoutBuilder(
              builder: (context, c) => c.maxWidth > 700
                  ? Row(
                      children: [
                        Expanded(child: image),
                        const SizedBox(width: 60),
                        Expanded(child: copy),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [image, const SizedBox(height: 28), copy],
                    ),
            ),
            const SizedBox(height: 50),
            SectionTitle(
              eyebrow: 'SELECTED WORKS',
              title: '${artist.name}의 작품 ${works.length}',
            ),
            const SizedBox(height: 24),
            works.isEmpty
                ? const EmptyView('작품을 준비하고 있어요.')
                : ArtworkGrid(works),
          ],
        );
      },
    ),
  );
}
