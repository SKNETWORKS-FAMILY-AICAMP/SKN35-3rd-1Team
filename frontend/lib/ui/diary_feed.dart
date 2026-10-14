import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../diary.dart';
import '../models.dart';
import '../state.dart';
import 'design.dart';

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
      var page = result.entries;
      // My own private comment is visible only to me, above the public ones.
      if (!more && widget.artworkId != null && s.authenticated) {
        final own = await s.diaryForArtwork(widget.artworkId!);
        if (!mounted || current != revision) return;
        if (own != null && !page.any((e) => e.id == own.id)) {
          page = [own, ...page];
        }
      }
      setState(() {
        entries = more ? [...entries, ...page] : page;
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
        if (comments)
          for (final entry in entries)
            ImpressionComment(key: ValueKey(entry.id), entry: entry)
        else if (entries.isNotEmpty)
          _Collage(entries),
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
                    if (!e.isPublic) ...[
                      const SizedBox(width: 6),
                      const Tooltip(
                        message: '나만 보는 감상',
                        child: Icon(Icons.lock_outline, size: 13, color: muted),
                      ),
                    ],
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
  bool busy = false, isPublic = true;
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
        isPublic,
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
    final field = TextField(
      key: const ValueKey('impression-input'),
      controller: input,
      enabled: !busy,
      maxLength: 2000,
      minLines: 1,
      maxLines: 3,
      style: sans(13),
      onSubmitted: (_) => submit(),
      decoration: InputDecoration(
        hintText: '이 그림에 대한 감상을 남겨 보세요',
        hintStyle: sans(12, color: muted),
        counterText: '',
      ),
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: isPublic ? '모두에게 공개' : '나만 보기',
          child: Semantics(
            toggled: isPublic,
            label: '감상 공개',
            child: InkWell(
              key: const ValueKey('impression-visibility'),
              borderRadius: BorderRadius.circular(999),
              onTap: busy ? null : () => setState(() => isPublic = !isPublic),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isPublic ? soft : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPublic ? Icons.public : Icons.lock_outline,
                      size: 15,
                      color: isPublic ? green : muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPublic ? '공개' : '비공개',
                      style: sans(
                        11,
                        height: 1.2,
                        color: isPublic ? green : muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const ValueKey('impression-submit'),
          onPressed: busy ? null : submit,
          style: editorialButtonStyle(
            dark: true,
            minimumSize: const Size(64, 36),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(
            busy ? '저장 중' : '게시',
            style: sans(
              13,
              height: 1.2,
              color: Colors.white,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, c) {
        final avatar = AuthorAvatar(name.isEmpty ? '나' : name, radius: 16);
        // Narrow screens put the visibility toggle and button under the field.
        if (c.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(child: field),
                ],
              ),
              const SizedBox(height: 8),
              controls,
            ],
          );
        }
        return Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(child: field),
            const SizedBox(width: 8),
            controls,
          ],
        );
      },
    );
  }
}

/// Feed posts in staggered columns, filling the width like a collage.
class _Collage extends StatelessWidget {
  const _Collage(this.entries);
  final List<DiaryEntry> entries;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth;
      final columns = w >= 1600
          ? 5
          : w >= 1200
          ? 4
          : w >= 840
          ? 3
          : w >= 520
          ? 2
          : 1;
      const gap = 20.0;
      return Row(
        key: const ValueKey('feed-collage'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var col = 0; col < columns; col++) ...[
            if (col > 0) const SizedBox(width: gap),
            Expanded(
              child: Column(
                children: [
                  for (var i = col; i < entries.length; i += columns)
                    DiaryPostCard(
                      key: ValueKey(entries[i].id),
                      entry: entries[i],
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// One public impression: author line with follow, the artwork, the text.
class DiaryPostCard extends StatefulWidget {
  const DiaryPostCard({super.key, required this.entry});
  final DiaryEntry entry;
  @override
  State<DiaryPostCard> createState() => _DiaryPostCardState();
}

class _DiaryPostCardState extends State<DiaryPostCard> {
  bool expanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ArtlogScope.of(context);
    if (s.authenticated && !s.config.demo) s.loadFollowing();
  }

  Future<void> follow(ArtlogState s, bool enable) async {
    if (!await ensureLogin(context) || !mounted) return;
    try {
      await s.followMember(widget.entry.authorId, enable);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry, s = ArtlogScope.of(context), art = e.artwork;
    final long = e.content.characters.length > 140;
    final mine =
        e.authorId == s.myPublicId || e.authorId == SocialState.demoMemberId;
    final following = s.followingMembers.contains(e.authorId);
    return ScrollReveal(
      child: Container(
        key: ValueKey('feed-post-${e.id}'),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: const BoxDecoration(
          color: pearl,
          border: Border.fromBorderSide(BorderSide(color: line)),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: e.authorId.isEmpty
                        ? null
                        : () => openAuthor(context, e),
                    child: AuthorAvatar(e.author, radius: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      key: ValueKey('feed-author-${e.id}'),
                      onTap: e.authorId.isEmpty
                          ? null
                          : () => openAuthor(context, e),
                      child: Text(
                        e.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sans(13, height: 1.3, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (e.authorId.isNotEmpty && !mine)
                    TextButton(
                      key: ValueKey('feed-follow-${e.id}'),
                      onPressed: s.pendingMemberFollows.contains(e.authorId)
                          ? null
                          : () => follow(s, !following),
                      style: editorialButtonStyle(
                        quiet: following,
                        dark: !following,
                        radius: 999,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Text(
                        following ? '팔로잉' : '+ 팔로우',
                        style: sans(
                          12,
                          height: 1.2,
                          weight: FontWeight.w600,
                          color: following ? muted : Colors.white,
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
                  aspectRatio: (art.imageAspectRatio ?? .8).clamp(.55, 1.8),
                  child: ColoredBox(
                    color: museumBlack,
                    child: ArtImage(
                      art.image,
                      fit: BoxFit.cover,
                      label: '${art.title} 작품 보기',
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (art != null)
                    Text(
                      '${art.artistName.isEmpty ? s.artistName(art) : art.artistName} · ${art.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sans(11, color: muted),
                    ),
                  const SizedBox(height: 4),
                  AnimatedSize(
                    duration: reduceMotion(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topLeft,
                    child: Text(
                      long && !expanded
                          ? '${e.content.characters.take(140)}…'
                          : e.content,
                      style: sans(13, height: 1.75),
                    ),
                  ),
                ],
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
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
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
