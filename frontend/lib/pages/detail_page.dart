import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../state.dart';
import '../ui/design.dart';
import '../ui/docent_chat.dart';
import '../ui/diary_feed.dart';
import '../ui/collection_workspace.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.id});
  final String id;
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Future<Artwork>? future;
  Future<List<Artwork>>? related;
  bool info = false;
  final chatKey = GlobalKey();
  String? identity;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= _load();
    final s = ArtlogScope.of(context);
    final next = '${s.userKey}/${s.authenticated}';
    if (identity != next) {
      identity = next;
      _recordViewWhenLoaded(future!);
    }
  }

  void _recordViewWhenLoaded(Future<Artwork> work) {
    final s = ArtlogScope.of(context), currentIdentity = identity;
    unawaited(
      work
          .then((art) async {
            if (mounted && identity == currentIdentity) {
              await s.recordView(art.id);
            }
          })
          .catchError((Object e) {
            if (mounted && identity == currentIdentity) showError(context, e);
          }),
    );
  }

  Future<Artwork> _load() async {
    final s = ArtlogScope.of(context);
    final art = await s.detail(widget.id);
    related = s.similar(art);
    return art;
  }

  @override
  Widget build(BuildContext context) => PageWidth(
    vertical: 30,
    child: FutureBuilder<Artwork>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyView(
            ArtlogState.message(snapshot.error!),
            action: ArtButton(
              '다시 불러오기',
              onTap: () {
                setState(() {
                  future = _load();
                });
                _recordViewWhenLoaded(future!);
              },
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 500,
            child: Center(child: CircularProgressIndicator(color: green)),
          );
        }
        final art = snapshot.data!,
            s = ArtlogScope.of(context),
            artist = s.artistFor(art.artistId);
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: compact(context) ? 380 : 500,
              child: SizedBox(
                key: const ValueKey('detail-artwork-surface'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: EdgeInsets.zero,
                      child: ArtImage(
                        art.image,
                        fit: BoxFit.contain,
                        label: art.title,
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: paper.withValues(alpha: 0.9),
                        ),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (c) => Dialog.fullscreen(
                            backgroundColor: const Color(0xff141e25),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: InteractiveViewer(
                                    minScale: 0.8,
                                    maxScale: 5,
                                    child: Padding(
                                      padding: const EdgeInsets.all(40),
                                      child: ArtImage(
                                        art.image,
                                        fit: BoxFit.contain,
                                        label: art.title,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 15,
                                  right: 15,
                                  child: IconButton(
                                    tooltip: '확대 화면 닫기',
                                    style: editorialButtonStyle(
                                      dark: true,
                                      quiet: true,
                                    ),
                                    onPressed: () => Navigator.pop(c),
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 15,
                                  left: 20,
                                  child: Text(
                                    '${s.artistName(art)} · ${art.title}',
                                    style: sans(12, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_full, size: 15),
                        label: Text('크게 보기', style: sans(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('${s.movementName(art)} · ${art.year}'),
                      const SizedBox(height: 9),
                      Text(art.title, style: serif(29)),
                      Text(art.titleEn, style: english(24, color: muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                HoverLikeButton(
                  key: const ValueKey('detail-artwork-like'),
                  label: '작품 좋아요',
                  liked: s.likes.contains(art.id),
                  subject: art.title,
                  onPressed: s.pendingLikes.contains(art.id)
                      ? null
                      : () => likeArtwork(context, art),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (artist != null)
              Row(
                children: [
                  artist.portrait.isEmpty
                      ? Semantics(
                          label: '${artist.name} 작가 사진 준비 중',
                          child: CircleAvatar(
                            radius: 21,
                            backgroundColor: soft,
                            child: Text(
                              artist.name.isEmpty
                                  ? '작'
                                  : artist.name.characters.first,
                              style: sans(16),
                            ),
                          ),
                        )
                      : ClipOval(
                          child: ArtImage(
                            artist.portrait,
                            width: 42,
                            height: 42,
                            label: '${artist.name} 작가 사진',
                          ),
                        ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: InkWell(
                      onTap: () => context.go('/artist/${art.artistId}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.artistName(art),
                            style: sans(12, weight: FontWeight.w600),
                          ),
                          Text(
                            '${artist.english} · ${artist.years}',
                            style: sans(10, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  HoverLikeButton(
                    key: const ValueKey('detail-artist-like'),
                    label: '작가 좋아요',
                    liked: s.follows.contains(artist.id),
                    subject: artist.name,
                    onPressed: s.pendingFollows.contains(artist.id)
                        ? null
                        : () => likeArtist(context, artist),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                _tab('감상 노트', !info, () => setState(() => info = false)),
                const SizedBox(width: 26),
                _tab('작품 정보 · 출처', info, () => setState(() => info = true)),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 23),
            if (!info) ...[
              Text(
                '잠시 멈추어, 그림을 바라보세요.',
                style: sans(13, weight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Text(
                art.description.isEmpty
                    ? '작품에서 느껴지는 첫인상을 도슨트와 나눠보세요.'
                    : art.description,
                style: sans(14, color: muted, height: 2),
              ),
              const SizedBox(height: 17),
              Text('작품에서 느껴지는 첫인상을 도슨트와 나눠보세요.', style: sans(11, color: muted)),
            ] else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in [
                    ('작가', s.artistName(art)),
                    ('제작 시기', art.year),
                    ('재료', art.medium),
                    ('크기', art.dimensions),
                    ('소장처', art.collection),
                    ('이미지 이용', art.imageLicense),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              entry.$1,
                              style: sans(11, color: muted),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.$2.isEmpty ? '정보 확인 중' : entry.$2,
                              style: sans(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (art.sourceUrl.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => openSource(context, art.sourceUrl),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('원본 작품 정보와 이용 조건'),
                    ),
                ],
              ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/artworks'),
              icon: const Icon(Icons.arrow_back, size: 15),
              label: Text(
                '작품 리스트  ›  ${s.artistName(art)}',
                style: sans(11, color: muted),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => pickCollectionForArtwork(context, s, art),
                  icon: const Icon(Icons.bookmark_border, size: 18),
                  label: const Text('컬렉션에 저장'),
                ),
                if (compact(context))
                  TextButton(
                    onPressed: () {
                      if (chatKey.currentContext != null) {
                        Scrollable.ensureVisible(
                          chatKey.currentContext!,
                          alignment: .03,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                        );
                      }
                    },
                    child: const Text('도슨트와 대화 ↓'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) => c.maxWidth > 800
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 38),
                        Expanded(
                          child: KeyedSubtree(
                            key: chatKey,
                            child: DocentChat(art, key: ValueKey(art.id)),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        left,
                        const SizedBox(height: 32),
                        KeyedSubtree(
                          key: chatKey,
                          child: DocentChat(art, key: ValueKey(art.id)),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 28),
            DiaryFeedView(artworkId: art.id),
            const SizedBox(height: 55),
            const Divider(),
            const SizedBox(height: 25),
            SectionTitle(
              eyebrow: 'CONTINUE YOUR JOURNEY',
              title: '함께 보면 좋은 작품',
              subtitle: s.config.demo
                  ? '작가와 사조를 따라 골라본 미리보기 작품이에요.'
                  : '이 작품과 함께 살펴볼 만한 그림이에요.',
            ),
            const SizedBox(height: 25),
            FutureBuilder<List<Artwork>>(
              future: related,
              builder: (context, r) {
                if (r.hasError) {
                  return EmptyView(
                    '추천 작품을 불러오지 못했어요.',
                    description: ArtlogState.message(r.error!),
                    action: ArtButton(
                      '추천 다시 보기',
                      outline: true,
                      onTap: () => setState(() {
                        related = s.similar(art);
                      }),
                    ),
                  );
                }
                if (!r.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(
                      child: CircularProgressIndicator(color: green),
                    ),
                  );
                }
                if (r.data!.isEmpty) {
                  return const EmptyView('다음 그림을 준비하고 있어요.');
                }
                return ArtworkGrid(r.data!, maxColumns: 3);
              },
            ),
            const SizedBox(height: 25),
          ],
        );
      },
    ),
  );
  Widget _tab(String label, bool selected, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        label,
        style: sans(
          12,
          color: selected ? green : muted,
          weight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}
