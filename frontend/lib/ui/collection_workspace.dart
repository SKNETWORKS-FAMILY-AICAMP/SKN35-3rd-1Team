import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../mypage.dart';
import '../state.dart';
import 'design.dart';

class AccountGuard extends StatefulWidget {
  const AccountGuard({super.key, required this.state, required this.child});
  final ArtlogState state;
  final Widget child;
  @override
  State<AccountGuard> createState() => _AccountGuardState();
}

class _AccountGuardState extends State<AccountGuard> {
  late final String identity;
  bool closing = false;
  @override
  void initState() {
    super.initState();
    identity = widget.state.userKey;
    widget.state.addListener(check);
  }

  void check() {
    if (!mounted ||
        closing ||
        (widget.state.authenticated && widget.state.userKey == identity)) {
      return;
    }
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null) return;
      final navigator = Navigator.of(context);
      if (route.isCurrent) {
        navigator.pop();
      } else {
        // A discard/confirmation dialog may cover this account's form.
        navigator.removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    widget.state.removeListener(check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<ArtCollection?> editCollection(
  BuildContext context,
  ArtlogState s, {
  ArtCollection? collection,
}) async => showDialog<ArtCollection>(
  context: context,
  builder: (_) => AccountGuard(
    state: s,
    child: _CollectionEditor(state: s, collection: collection),
  ),
);

class _CollectionEditor extends StatefulWidget {
  const _CollectionEditor({required this.state, this.collection});
  final ArtlogState state;
  final ArtCollection? collection;
  @override
  State<_CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<_CollectionEditor> {
  late final name = TextEditingController(text: widget.collection?.name ?? '');
  late final description = TextEditingController(
    text: widget.collection?.description ?? '',
  );
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final c = await widget.state.saveCollection(
        name.text,
        description.text,
        id: widget.collection?.id,
      );
      if (mounted) Navigator.pop(context, c);
    } catch (e) {
      if (mounted) setState(() => error = ArtlogState.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SurfaceDialog(
    title: Text(
      widget.collection == null ? '새 컬렉션 만들기' : '컬렉션 편집',
      style: serif(22),
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '나만 볼 수 있는 작은 전시를 만들어 보세요. 최대 $maxSavedCollections개, 각 $maxCollectionArtworks점까지 저장할 수 있어요.',
              style: sans(12, color: muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: name,
              enabled: !busy,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: '컬렉션 이름',
                hintText: '예: 비 오는 날의 풍경',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              enabled: !busy,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '취향 한 줄 (선택)'),
            ),
            if (error != null)
              Text(error!, style: sans(12, color: Colors.red.shade800)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      ArtButton(busy ? '저장 중…' : '컬렉션 저장', onTap: busy ? null : save),
    ],
  );
}

class CollectionWorkspace extends StatefulWidget {
  const CollectionWorkspace({super.key});
  @override
  State<CollectionWorkspace> createState() => _CollectionWorkspaceState();
}

class _CollectionWorkspaceState extends State<CollectionWorkspace> {
  List<ArtCollection> rows = [];
  List<AutoCollection> themes = [];
  bool themeLoading = true;
  String? themeMessage;
  bool started = false, loading = true;
  String? error;
  int serial = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  Future<void> load() async {
    final s = ArtlogScope.of(context),
        identity = ArtlogScope.of(context).userKey,
        request = ++serial;
    setState(() {
      loading = true;
      themeLoading = true;
      themeMessage = null;
      error = null;
    });

    bool current() => mounted && request == serial && s.userKey == identity;
    Future<void> saved() async {
      try {
        final result = await s.collections(force: true);
        if (current()) setState(() => rows = result);
      } catch (e) {
        if (current()) setState(() => error = ArtlogState.message(e));
      } finally {
        if (current()) setState(() => loading = false);
      }
    }

    Future<void> themed() async {
      try {
        final (result, message) = await s.themeCollections();
        if (current()) {
          setState(() {
            themes = result;
            themeMessage = message;
          });
        }
      } catch (e) {
        if (current()) {
          setState(
            () =>
                themeMessage = 'AI 취향 모음을 불러오지 못했어요. ${ArtlogState.message(e)}',
          );
        }
      } finally {
        if (current()) setState(() => themeLoading = false);
      }
    }

    await Future.wait([saved(), themed()]);
  }

  Future<void> create() async {
    if (await editCollection(context, ArtlogScope.of(context)) != null &&
        mounted) {
      await load();
    }
  }

  Future<void> remove(ArtCollection c) async {
    final s = ArtlogScope.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AccountGuard(
        state: s,
        child: SurfaceDialog(
          title: Text('컬렉션을 삭제할까요?', style: serif(21)),
          content: Text(
            '‘${c.name}’의 묶음이 삭제돼요. 좋아요와 다이어리 기록은 그대로 남아요.',
            style: sans(13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await s.deleteCollection(c.id);
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ArtlogState.message(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('나만의 컬렉션', style: serif(26)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  key: const ValueKey('collections-refresh'),
                  tooltip: '컬렉션 새로고침',
                  onPressed: loading || themeLoading ? null : load,
                  style: editorialButtonStyle(
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: FilledButton(
                  key: const ValueKey('collections-new'),
                  onPressed: loading ? null : create,
                  style: editorialButtonStyle(
                    dark: true,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '새 컬렉션',
                        style: sans(
                          13,
                          height: 1.2,
                          color: Colors.white,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.add, size: 17),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 18),
      Text(
        '그림을 둘러보고 마음에 드는 작품에 좋아요해 보세요. AI가 끌린 그림들의 분위기를 읽고 '
        '‘잔잔한 저녁에 어울리는 그림’ 같은 감성 컬렉션을 만들어 드려요.',
        style: sans(12, color: muted),
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('AI 취향 컬렉션은 언제 생기나요?', style: sans(12)),
        childrenPadding: const EdgeInsets.only(bottom: 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '작품 3점 정도를 감상하거나 좋아요하면 분위기가 다른 2~4개의 컬렉션이 생기고, '
            '아직 보지 않은 어울리는 그림도 함께 담겨요.\n'
            '좋아요가 바뀌거나 새 작품을 3점 이상 더 보면 새로 꾸며져요.\n'
            '마음에 드는 컬렉션은 상세에서 ‘내 컬렉션으로 저장’을 눌러 직접 편집할 수 있어요.',
            style: sans(12, color: muted, height: 1.8),
          ),
        ],
      ),
      if (themeLoading)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '감상한 그림에서 어울리는 분위기를 찾고 있어요…',
                  style: sans(12, color: muted),
                ),
              ),
            ],
          ),
        ),
      if (themeMessage != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(themeMessage!, style: sans(12, color: muted)),
        ),
      if (loading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      if (error != null)
        EmptyView(
          '저장한 컬렉션을 불러오지 못했어요. $error',
          action: ArtButton('다시 불러오기', onTap: load),
        ),
      LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth >= 900
              ? 3
              : c.maxWidth >= 540
              ? 2
              : 1;
          final width = (c.maxWidth - 16 * (columns - 1)) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(width: width, child: const _LikedCollectionCard()),
              for (final theme in themes)
                SizedBox(
                  width: width,
                  child: _SpecialCollectionCard(
                    key: ValueKey('collection-auto-${theme.key}'),
                    title: theme.name,
                    badge: 'AI 취향',
                    subtitle: '${theme.count}점 · ${theme.description}',
                    cover: theme.cover,
                    emptyIcon: Icons.auto_awesome_outlined,
                    onTap: () async {
                      await context.push(
                        '/collection/auto/${Uri.encodeComponent(theme.key)}',
                      );
                      if (mounted) await load();
                    },
                  ),
                ),
              for (final group
                  in loading || error != null ? <ArtCollection>[] : rows)
                SizedBox(
                  width: width,
                  child: SurfacePanel(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () async {
                            await context.push(
                              '/collection/${Uri.encodeComponent(group.id)}',
                            );
                            if (mounted) await load();
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CollectionCover(
                                  group.previews.firstOrNull,
                                  emptyIcon: Icons.add_photo_alternate_outlined,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(group.name, style: serif(20)),
                              const SizedBox(height: 5),
                              Text(
                                '${group.count}점 · 나만 보기',
                                style: sans(11, color: muted),
                              ),
                              if (group.description.isNotEmpty) ...[
                                const SizedBox(height: 9),
                                Text(
                                  group.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: sans(12, color: muted),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () async {
                                if (await editCollection(
                                          context,
                                          ArtlogScope.of(context),
                                          collection: group,
                                        ) !=
                                        null &&
                                    mounted) {
                                  await load();
                                }
                              },
                              child: const Text('편집'),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: '${group.name} 컬렉션 삭제',
                              onPressed: () => remove(group),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 30),
      const Divider(),
    ],
  );
}

/// One large cover image: the collection's first artwork fills the frame.
class CollectionCover extends StatelessWidget {
  const CollectionCover(
    this.art, {
    super.key,
    this.emptyIcon = Icons.photo_outlined,
    this.height = 190,
  });
  final Artwork? art;
  final IconData emptyIcon;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: art == null
        ? Container(
            color: soft,
            child: Center(child: Icon(emptyIcon, size: 35, color: sage)),
          )
        : ArtImage(art!.image, label: art!.title, fit: BoxFit.cover),
  );
}

/// Default collection: every liked artwork lands here automatically.
class _LikedCollectionCard extends StatelessWidget {
  const _LikedCollectionCard();
  @override
  Widget build(BuildContext context) {
    final works = ArtlogScope.of(context).likedWorks;
    return _SpecialCollectionCard(
      key: const ValueKey('collection-liked-default'),
      title: '좋아요한 작품',
      badge: '기본',
      subtitle: '${works.length}점 · 좋아요를 누르면 자동으로 담겨요',
      cover: works.firstOrNull,
      emptyIcon: Icons.favorite_border,
      onTap: () => context.push('/collection/likes'),
    );
  }
}

/// Collections the app fills by itself (likes, view history). Not editable.
class _SpecialCollectionCard extends StatelessWidget {
  const _SpecialCollectionCard({
    super.key,
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.cover,
    required this.emptyIcon,
    required this.onTap,
  });
  final String title, badge, subtitle;
  final Artwork? cover;
  final IconData emptyIcon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SurfacePanel(
    padding: const EdgeInsets.all(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CollectionCover(cover, emptyIcon: emptyIcon),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: serif(20),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(badge, style: sans(10, color: green)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: sans(11, color: muted),
          ),
          const SizedBox(height: 48),
        ],
      ),
    ),
  );
}

Future<void> pickCollectionForArtwork(
  BuildContext context,
  ArtlogState s,
  Artwork art,
) async {
  if (!await ensureLogin(context) || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => AccountGuard(
      state: s,
      child: _ArtworkCollectionPicker(state: s, art: art),
    ),
  );
}

class _ArtworkCollectionPicker extends StatefulWidget {
  const _ArtworkCollectionPicker({required this.state, required this.art});
  final ArtlogState state;
  final Artwork art;
  @override
  State<_ArtworkCollectionPicker> createState() =>
      _ArtworkCollectionPickerState();
}

class _ArtworkCollectionPickerState extends State<_ArtworkCollectionPicker> {
  late Future<List<ArtCollection>> future = widget.state.collections(
    force: true,
  );
  bool busy = false;
  String? error;
  Future<void> add(String id) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.state.collect(id, widget.art.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('내 컬렉션에 담았어요.')));
      }
    } catch (e) {
      if (mounted) setState(() => error = ArtlogState.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SurfaceDialog(
    title: Text('이 그림을 어디에 담을까요?', style: serif(21)),
    content: SizedBox(
      width: 420,
      height: 300,
      child: FutureBuilder<List<ArtCollection>>(
        future: future,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyView(
              ArtlogState.message(snap.error!),
              action: ArtButton(
                '다시 불러오기',
                onTap: () => setState(
                  () => future = widget.state.collections(force: true),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              Text(widget.art.title, style: sans(12, color: muted)),
              if (error != null)
                Text(error!, style: sans(12, color: Colors.red.shade800)),
              for (final c in snap.data!)
                ListTile(
                  title: Text(c.name),
                  subtitle: Text('${c.count}점'),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: busy ? null : () => add(c.id),
                ),
              if (snap.data!.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('컬렉션을 먼저 만들어 보세요.'),
                ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
      ArtButton(
        '새 컬렉션',
        onTap: busy
            ? null
            : () async {
                final c = await editCollection(context, widget.state);
                if (c != null && mounted) {
                  await add(c.id);
                }
              },
      ),
    ],
  );
}
