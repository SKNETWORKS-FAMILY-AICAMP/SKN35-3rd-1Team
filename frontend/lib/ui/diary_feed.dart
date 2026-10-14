import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../diary.dart';
import '../models.dart';
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
  Widget build(BuildContext context) {
    final comments = widget.artworkId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                comments ? '이 작품의 감상 ${entries.length}' : '최근 감상',
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
        if (comments) ...[
          ImpressionComposer(
            artworkId: widget.artworkId!,
            onSaved: () => load(),
          ),
          const SizedBox(height: 8),
        ],
        for (final entry in entries)
          comments
              ? ImpressionComment(key: ValueKey(entry.id), entry: entry)
              : DiaryPostCard(key: ValueKey(entry.id), entry: entry),
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
          comments
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    '아직 남겨진 감상이 없어요. 첫 감상을 남겨 보세요.',
                    style: sans(12, color: muted),
                  ),
                )
              : const EmptyView(
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
}

/// Opens the author's profile. Entries without a public id are not links.
void openAuthor(BuildContext context, DiaryEntry e) {
  if (e.authorId.isNotEmpty) {
    context.go('/user/${Uri.encodeComponent(e.authorId)}');
  }
}

class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar(this.name, {super.key, this.radius = 18});
  final String name;
  final double radius;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: soft,
    child: Text(
      name.isEmpty ? 'D' : name.characters.first,
      style: sans(radius * .7, weight: FontWeight.w600),
    ),
  );
}

/// One public impression shown as a comment under an artwork.
class ImpressionComment extends StatefulWidget {
  const ImpressionComment({super.key, required this.entry});
  final DiaryEntry entry;
  @override
  State<ImpressionComment> createState() => _ImpressionCommentState();
}

class _ImpressionCommentState extends State<ImpressionComment> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final long = e.content.characters.length > 160;
    return Container(
      key: ValueKey('comment-${e.id}'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: e.authorId.isEmpty ? null : () => openAuthor(context, e),
            child: AuthorAvatar(e.author, radius: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: InkWell(
                        key: ValueKey('comment-author-${e.id}'),
                        onTap: e.authorId.isEmpty
                            ? null
                            : () => openAuthor(context, e),
                        child: Text(
                          e.author,
                          overflow: TextOverflow.ellipsis,
                          style: sans(13, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e.date.replaceAll('-', '.'),
                      style: sans(11, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  long && !expanded
                      ? '${e.content.characters.take(160)}…'
                      : e.content,
                  style: sans(13, height: 1.8),
                ),
                if (long)
                  TextButton(
                    onPressed: () => setState(() => expanded = !expanded),
                    child: Text(expanded ? '접기' : '더 보기'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Saves the member's public impression of this artwork, like posting a comment.
/// One per artwork; writing again replaces it after confirmation.
class ImpressionComposer extends StatefulWidget {
  const ImpressionComposer({
    super.key,
    required this.artworkId,
    required this.onSaved,
  });
  final String artworkId;
  final VoidCallback onSaved;
  @override
  State<ImpressionComposer> createState() => _ImpressionComposerState();
}

class _ImpressionComposerState extends State<ImpressionComposer> {
  final input = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final text = input.text.trim();
    if (text.isEmpty || busy) return;
    if (!await ensureLogin(context) || !mounted) return;
    final s = ArtlogScope.of(context), identity = s.userKey;
    final today = seoulDate();
    setState(() => busy = true);
    try {
      // One impression per artwork: confirm before replacing the earlier one.
      final existing = await s.diaryForArtwork(widget.artworkId);
      if (!mounted || s.userKey != identity) return;
      if (existing != null) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (c) => SurfaceDialog(
            title: const Text('이 작품의 감상을 바꿀까요?'),
            content: const Text(
              '감상은 작품마다 한 편 남길 수 있어요. 이 작품에 남긴 감상이 이 내용으로 바뀌어요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('바꾸기'),
              ),
            ],
          ),
        );
        if (replace != true || !mounted) return;
      }
      await s.saveDiary(
        today,
        text,
        true,
        widget.artworkId,
        id: existing?.id,
      );
      if (!mounted || s.userKey != identity) return;
      input.clear();
      widget.onSaved();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    final name = s.memberProfile?.nickname ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AuthorAvatar(name.isEmpty ? '나' : name, radius: 16),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            key: const ValueKey('impression-input'),
            controller: input,
            enabled: !busy,
            maxLength: 2000,
            minLines: 1,
            maxLines: 3,
            style: sans(13),
            onSubmitted: (_) => submit(),
            decoration: InputDecoration(
              hintText: '이 그림에 대한 감상을 남겨 보세요 (공개)',
              hintStyle: sans(12, color: muted),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          key: const ValueKey('impression-submit'),
          onPressed: busy ? null : submit,
          child: Text(busy ? '저장 중' : '게시'),
        ),
      ],
    );
  }
}

/// Public entries only, shown like a photo feed. Reactions save the linked
/// artwork, never an invented post count.
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
    final long = e.content.characters.length > 140;
    return ScrollReveal(
      child: Container(
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
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: e.authorId.isEmpty
                        ? null
                        : () => openAuthor(context, e),
                    child: AuthorAvatar(e.author, radius: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      key: ValueKey('feed-author-${e.id}'),
                      onTap: e.authorId.isEmpty
                          ? null
                          : () => openAuthor(context, e),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.author,
                            style: sans(13, weight: FontWeight.w600),
                          ),
                          if (art != null)
                            Text(
                              '${art.artistName.isEmpty ? s.artistName(art) : art.artistName} · ${art.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: sans(11, color: muted),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (art != null)
              InkWell(
                onTap: () => context.go('/artwork/${art.id}'),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(
                    color: museumBlack,
                    child: ArtImage(
                      art.image,
                      fit: BoxFit.contain,
                      label: '${art.title} 작품 보기',
                    ),
                  ),
                ),
              ),
            if (art != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                child: Row(
                  children: [
                    LikeButton(
                      compactIcon: true,
                      liked: s.likes.contains(art.id),
                      subject: art.title,
                      onPressed: s.pendingLikes.contains(art.id)
                          ? null
                          : () => likeArtwork(context, art),
                    ),
                    IconButton(
                      tooltip: '${art.title} 작품의 감상 보기',
                      onPressed: () => context.go('/artwork/${art.id}'),
                      icon: const Icon(Icons.mode_comment_outlined, size: 21),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '내 컬렉션에 작품 저장',
                      onPressed: () =>
                          pickCollectionForArtwork(context, s, art),
                      icon: const Icon(Icons.bookmark_border, size: 22),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: AnimatedSize(
                duration: reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${e.author}  ',
                        style: sans(13, weight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: long && !expanded
                            ? '${e.content.characters.take(140)}…'
                            : e.content,
                      ),
                    ],
                  ),
                  style: sans(13, height: 1.8),
                ),
              ),
            ),
            if (long)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => expanded = !expanded),
                  child: Text(expanded ? '접기' : '더 보기'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
              child: Text(
                e.date.replaceAll('-', '.'),
                style: sans(11, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
