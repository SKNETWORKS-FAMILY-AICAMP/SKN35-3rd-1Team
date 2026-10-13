import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../state.dart';
import 'design.dart';

class PersonalRecommendations extends StatefulWidget {
  const PersonalRecommendations({super.key});
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
        works = s.api.recommendedArtworks();
        artists = s.api.recommendedArtists();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (s.config.demo || !s.authenticated) return const SizedBox.shrink();
    return PageWidth(
      vertical: 35,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
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
                  () => setState(() => works = s.api.recommendedArtworks()),
                );
              }
              if (snapshot.data?.isEmpty ?? true) {
                return const EmptyView('취향에 맞는 작품을 준비하고 있어요.');
              }
              return ArtworkGrid(snapshot.data!, maxColumns: 3);
            },
          ),
          const SizedBox(height: 35),
          Text('새롭게 만나볼 작가', style: serif(23)),
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
                  () => setState(() => artists = s.api.recommendedArtists()),
                );
              }
              if (snapshot.data?.isEmpty ?? true) {
                return const EmptyView('추천할 작가를 준비하고 있어요.');
              }
              return Column(
                children: [
                  for (final artist in snapshot.data!)
                    Card(
                      color: const Color(0xffeef0e7),
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
                          style: sans(13, weight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          artist.reason.isEmpty
                              ? s.artistMovement(artist)
                              : artist.reason,
                          style: sans(11, color: muted),
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

  Widget _loading() => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator(color: green)),
  );
  Widget _error(Object error, VoidCallback retry) => EmptyView(
    ArtlogState.message(error),
    action: ArtButton('추천 다시 불러오기', outline: true, onTap: retry),
  );
}
