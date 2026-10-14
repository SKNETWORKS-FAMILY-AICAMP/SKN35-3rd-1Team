import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  Future<List<Artist>>? artists;
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
      if (!s.config.demo && s.authenticated) {
        works = s.personalArtworks();
        artists = s.personalArtists();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (s.config.demo || !s.authenticated) return const SizedBox.shrink();
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
                return EmptyView('취향에 맞는 작품을 준비하고 있어요.', inverse: inverse);
              }
              return ArtworkGrid(
                snapshot.data!.take(3).toList(),
                maxColumns: 3,
                museum: inverse,
              );
            },
          ),
          const SizedBox(height: 35),
          Text(
            '새롭게 만나볼 작가',
            style: serif(23, color: inverse ? museumText : ink),
          ),
          const SizedBox(height: 15),
          FutureBuilder<List<Artist>>(
            key: ValueKey('artists/$signature'),
            future: artists,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _loading();
              }
              if (snapshot.hasError) {
                return _error(
                  snapshot.error!,
                  () => setState(() {
                    artists = s.personalArtists(force: true);
                  }),
                );
              }
              if (snapshot.data?.isEmpty ?? true) {
                return EmptyView('추천할 작가를 준비하고 있어요.', inverse: inverse);
              }
              return Column(
                children: [
                  for (final artist in snapshot.data!.take(3))
                    Card(
                      color: inverse ? museumBlack : const Color(0xffe8eeee),
                      shape: inverse
                          ? const RoundedRectangleBorder(
                              side: BorderSide(color: museumLine),
                            )
                          : null,
                      elevation: 0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        leading: SizedBox(
                          width: 42,
                          height: 55,
                          child: ArtImage(s.representativeImage(artist)),
                        ),
                        title: Text(
                          artist.name,
                          style: sans(
                            13,
                            color: inverse ? museumText : ink,
                            weight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          artist.reason.isEmpty
                              ? s.artistMovement(artist)
                              : artist.reason,
                          style: sans(11, color: inverse ? museumMuted : muted),
                        ),
                        onTap: () => context.go('/artist/${artist.id}'),
                        trailing: IconButton(
                          tooltip:
                              '${artist.name} ${s.follows.contains(artist.id) ? '팔로우 취소' : '팔로우'}',
                          onPressed: s.pendingFollows.contains(artist.id)
                              ? null
                              : () => followArtist(context, artist),
                          icon: Icon(
                            s.follows.contains(artist.id)
                                ? Icons.check
                                : Icons.person_add_alt,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                ],
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
