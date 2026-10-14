import 'package:flutter/material.dart';
import '../models.dart';
import '../state.dart';
import 'design.dart';

class PersonalRecommendations extends StatefulWidget {
  const PersonalRecommendations({super.key, this.inverse = false});
  final bool inverse;
  @override
  State<PersonalRecommendations> createState() =>
      _PersonalRecommendationsState();
}

class _PersonalRecommendationsState extends State<PersonalRecommendations> {
  String? signature;
  Future<List<Artwork>>? works;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ArtlogScope.of(context);
    final likes = s.likes.toList()..sort();
    final follows = s.follows.toList()..sort();
    final next =
        '${s.userKey}/${s.authenticated}/${likes.join(',')}/${follows.join(',')}';
    if (signature != next) {
      signature = next;
      if (s.authenticated) {
        works = s.config.demo
            ? Future.value(demoRecommendations(s))
            : s.personalArtworks();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    // Signed-out visitors do not see this section at all.
    if (!s.authenticated) return const SizedBox.shrink();
    final inverse = widget.inverse;
    return PageWidth(
      vertical: 35,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            inverse: inverse,
            eyebrow: 'CURATED FOR YOU',
            title: '취향이 이어지는 다음 그림',
            subtitle: '마음에 담은 작품과 감상 기록을 따라 골랐어요.',
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Artwork>>(
            key: ValueKey('works/$signature'),
            future: works,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _loading();
              }
              if (snapshot.hasError) {
                return _error(
                  snapshot.error!,
                  () => setState(() {
                    works = s.personalArtworks(force: true);
                  }),
                );
              }
              if (snapshot.data?.isEmpty ?? true) {
                return EmptyView(
                  '마음에 드는 그림에 좋아요를 눌러 보세요.',
                  description: '좋아요와 감상 기록을 따라 다음 그림을 골라 드려요.',
                  inverse: inverse,
                );
              }
              return ArtworkGrid(
                snapshot.data!.take(3).toList(),
                maxColumns: 3,
                museum: inverse,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _loading() => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: CircularProgressIndicator(
        color: widget.inverse ? museumText : green,
      ),
    ),
  );
  Widget _error(Object error, VoidCallback retry) => EmptyView(
    ArtlogState.message(error),
    inverse: widget.inverse,
    action: ArtButton(
      '추천 다시 불러오기',
      outline: !widget.inverse,
      light: widget.inverse,
      onTap: retry,
    ),
  );
}

/// Preview recommendations from local likes: same artists and movements first.
List<Artwork> demoRecommendations(ArtlogState s) {
  final liked = s.likes.map(s.workFor).whereType<Artwork>().toList();
  if (liked.isEmpty && s.follows.isEmpty) return const [];
  final artists = {...liked.map((a) => a.artistId), ...s.follows};
  final movements = liked.map((a) => a.movementId).toSet();
  int score(Artwork a) =>
      (artists.contains(a.artistId) ? 2 : 0) +
      (movements.contains(a.movementId) ? 1 : 0);
  final candidates =
      s.artworks.where((a) => !s.likes.contains(a.id) && score(a) > 0).toList()
        ..sort((a, b) => score(b).compareTo(score(a)));
  return candidates.take(3).toList();
}
