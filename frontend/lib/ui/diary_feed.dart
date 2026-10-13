import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../diary.dart';
import '../state.dart';
import 'design.dart';
import 'collection_workspace.dart';

class DiaryFeedView extends StatefulWidget {
  const DiaryFeedView({super.key, this.artworkId});
  final String? artworkId;
  @override
  State<DiaryFeedView> createState() => _DiaryFeedViewState();
}

class _DiaryFeedViewState extends State<DiaryFeedView> {
  List<DiaryEntry> entries = [];
  String? cursor, error, signature;
  bool loading = true;
  int revision = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ArtlogScope.of(context);
    final next = '${s.userKey}/${s.diaryRevision}/${widget.artworkId}';
    if (signature == next) return;
    signature = next;
    ++revision;
    entries = [];
    cursor = error = null;
    loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  Future<void> load({bool more = false}) async {
    final s = ArtlogScope.of(context), current = ++revision;
    setState(() {
      loading = true;
      error = null;
      if (!more) {
        entries = [];
        cursor = null;
      }
    });
    try {
      final result = await s.diaryFeed(
        cursor: more ? cursor : null,
        artworkId: widget.artworkId,
      );
      if (!mounted || current != revision) return;
      setState(() {
        entries = more ? [...entries, ...result.entries] : result.entries;
        cursor = result.nextCursor;
      });
    } catch (e) {
      if (mounted && current == revision) {
        setState(() => error = ArtlogState.message(e));
      }
    } finally {
      if (mounted && current == revision) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              widget.artworkId == null ? '최근 감상' : '이 작품의 감상',
              style: sans(15, weight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: '감상 피드 새로고침',
            onPressed: loading ? null : () => load(),
            icon: const Icon(Icons.refresh, size: 19),
          ),
        ],
      ),
      const SizedBox(height: 12),
      for (final entry in entries)
        DiaryPostCard(key: ValueKey(entry.id), entry: entry),
      if (loading)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      if (error != null)
        EmptyView(
          error!,
          action: ArtButton(
            '다시 불러오기',
            onTap: () => load(more: entries.isNotEmpty),
          ),
        ),
      if (!loading && error == null && entries.isEmpty)
        const EmptyView(
          '아직 공개된 감상평이 없어요.',
          description: '그림을 보고 떠오른 생각을 나눠보세요.',
          icon: Icons.chat_bubble_outline,
        ),
      if (!loading && error == null && cursor != null)
        Center(
          child: ArtButton(
            '감상평 더 보기',
            outline: true,
            onTap: () => load(more: true),
          ),
        ),
    ],
  );
}

/// Public entries only. Reactions save the linked artwork, never an invented post count.
class DiaryPostCard extends StatefulWidget {
  const DiaryPostCard({super.key, required this.entry});
  final DiaryEntry entry;
  @override
  State<DiaryPostCard> createState() => _DiaryPostCardState();
}

class _DiaryPostCardState extends State<DiaryPostCard> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final e = widget.entry, s = ArtlogScope.of(context), art = e.artwork;
    final long = e.content.characters.length > 220;
    return Container(
      key: ValueKey('feed-post-${e.id}'),
      margin: const EdgeInsets.only(bottom: 28),
      decoration: const BoxDecoration(
        color: pearl,
        border: Border.fromBorderSide(BorderSide(color: line)),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: soft,
                  child: Text(
                    e.author.isEmpty ? 'D' : e.author.characters.first,
                    style: sans(13, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.author, style: sans(13, weight: FontWeight.w600)),
                      Text(
                        e.date.replaceAll('-', '.'),
                        style: sans(11, color: muted),
                      ),
                    ],
                  ),
                ),
                const Tooltip(
                  message: '공개 감상',
                  child: Icon(Icons.public, size: 16, color: muted),
                ),
              ],
            ),
          ),
          if (art != null)
            InkWell(
              onTap: () => context.go('/artwork/${art.id}'),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ColoredBox(
                  color: soft,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: ArtImage(
                      art.image,
                      fit: BoxFit.contain,
                      label: '${art.title} 작품 보기',
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (art != null) ...[
                  Text(art.title, style: sans(14, weight: FontWeight.w600)),
                  Text(
                    art.artistName.isEmpty ? s.artistName(art) : art.artistName,
                    style: sans(12, color: muted),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  long && !expanded
                      ? '${e.content.characters.take(220)}…'
                      : e.content,
                  style: sans(14, height: 1.9),
                ),
                if (long)
                  TextButton(
                    onPressed: () => setState(() => expanded = !expanded),
                    child: Text(expanded ? '접기' : '더 읽기'),
                  ),
              ],
            ),
          ),
          if (art != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip:
                        '${art.title} ${s.likes.contains(art.id) ? '좋아요 취소' : '작품 좋아요'}',
                    onPressed: s.pendingLikes.contains(art.id)
                        ? null
                        : () => likeArtwork(context, art),
                    icon: Icon(
                      s.likes.contains(art.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 21,
                    ),
                  ),
                  IconButton(
                    tooltip: '내 컬렉션에 작품 저장',
                    onPressed: () => pickCollectionForArtwork(context, s, art),
                    icon: const Icon(Icons.bookmark_border, size: 21),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/artwork/${art.id}'),
                    child: const Text('작품 보기 →'),
                  ),
                ],
              ),
            ),
          if (art == null) const SizedBox(height: 16),
        ],
      ),
    );
  }
}
