import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../state.dart';
import '../ui/design.dart';

/// Artist cards used by the artwork list's artist view.
class ArtistGrid extends StatelessWidget {
  const ArtistGrid(this.artists, {super.key});
  final List<Artist> artists;
  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (artists.isEmpty) {
      return const EmptyView(
        '검색된 작가가 없어요.',
        description: '다른 이름이나 작품명으로 찾아보세요.',
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1000
            ? 4
            : c.maxWidth >= 650
            ? 3
            : 2;
        final gap = compact(context) ? 16.0 : 28.0;
        final width = (c.maxWidth - (cols - 1) * gap) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: 32,
          children: [
            for (final (index, a) in artists.indexed)
              SizedBox(
                key: ValueKey(a.id),
                width: width,
                child: ScrollReveal(
                  order: index % cols,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => context.go('/artist/${a.id}'),
                        child: AspectRatio(
                          aspectRatio: .9,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: ArtImage(
                              s.representativeImage(a),
                              label: '${a.name}의 작품 일부',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => context.go('/artist/${a.id}'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.name,
                                    style: sans(14, weight: FontWeight.w600),
                                  ),
                                  Text(
                                    a.english,
                                    style: english(17, color: muted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          HoverLikeButton(
                            label: '작가 좋아요',
                            liked: s.follows.contains(a.id),
                            subject: a.name,
                            onPressed: s.pendingFollows.contains(a.id)
                                ? null
                                : () => likeArtist(context, a),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(s.artistMovement(a), style: sans(11, color: muted)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
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
        final image = Padding(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ArtImage(
              artist.portrait.isNotEmpty
                  ? artist.portrait
                  : works.firstOrNull?.image ?? '',
              height: compact(context) ? 310 : 390,
              label: '${artist.name}의 작품 일부',
            ),
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
            HoverLikeButton(
              label: '작가 좋아요',
              liked: s.follows.contains(artist.id),
              subject: artist.name,
              onPressed: s.pendingFollows.contains(artist.id)
                  ? null
                  : () => likeArtist(context, artist),
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/artworks?view=artists'),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('작가 리스트'),
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
