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
            Text('나만 볼 수 있는 작은 전시를 만들어 보세요.', style: sans(12, color: muted)),
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
      error = null;
    });
    try {
      final result = await s.collections(force: true);
      if (mounted && request == serial && s.userKey == identity) {
        setState(() => rows = result);
      }
    } catch (e) {
      if (mounted && request == serial && s.userKey == identity) {
        setState(() => error = ArtlogState.message(e));
      }
    } finally {
      if (mounted && request == serial) setState(() => loading = false);
    }
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
          Wrap(
            spacing: 10,
            children: [
              IconButton(
                tooltip: '컬렉션 새로고침',
                onPressed: loading ? null : load,
                icon: const Icon(Icons.refresh),
              ),
              ArtButton('새 컬렉션', onTap: loading ? null : create),
            ],
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (loading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      if (error != null)
        EmptyView(error!, action: ArtButton('다시 불러오기', onTap: load)),
      if (!loading && error == null)
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
                for (final group in rows)
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
                                  child: SizedBox(
                                    height: 190,
                                    child: group.previews.isEmpty
                                        ? Container(
                                            color: soft,
                                            child: const Center(
                                              child: Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                size: 35,
                                                color: sage,
                                              ),
                                            ),
                                          )
                                        : Row(
                                            children: [
                                              for (final a in group.previews)
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 2,
                                                        ),
                                                    child: ArtImage(
                                                      a.image,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
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
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
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
      ExpansionTile(
        title: Text('대화로 컬렉션 정리', style: sans(14, weight: FontWeight.w500)),
        subtitle: Text('작품을 찾아 담거나 새 컬렉션을 만들어요', style: sans(12, color: muted)),
        maintainState: true,
        children: [CollectionAssistant(groups: rows, onChanged: load)],
      ),
    ],
  );
}

/// Default collection: every liked artwork lands here automatically.
class _LikedCollectionCard extends StatelessWidget {
  const _LikedCollectionCard();
  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    final works = s.likedWorks;
    return SurfacePanel(
      key: const ValueKey('collection-liked-default'),
      padding: const EdgeInsets.all(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => context.push('/collection/likes'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 190,
                child: works.isEmpty
                    ? Container(
                        color: soft,
                        child: const Center(
                          child: Icon(
                            Icons.favorite_border,
                            size: 35,
                            color: sage,
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          for (final a in works.take(3))
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 2),
                                child: ArtImage(a.image, fit: BoxFit.cover),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('좋아요한 작품', style: serif(20))),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: soft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('기본', style: sans(10, color: green)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${works.length}점 · 좋아요를 누르면 자동으로 담겨요',
              style: sans(11, color: muted),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class CollectionAssistant extends StatefulWidget {
  const CollectionAssistant({
    super.key,
    required this.groups,
    required this.onChanged,
  });
  final List<ArtCollection> groups;
  final Future<void> Function() onChanged;
  @override
  State<CollectionAssistant> createState() => _CollectionAssistantState();
}

class _CollectionAssistantState extends State<CollectionAssistant> {
  final input = TextEditingController();
  String? selected, error;
  bool busy = false;
  List<CollectionReply> replies = [];
  final Set<CollectionProposal> consumed = {};
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CollectionAssistant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (selected != null && !widget.groups.any((c) => c.id == selected)) {
      selected = null;
    }
  }

  Future<void> send() async {
    if (busy || input.text.trim().isEmpty) return;
    final s = ArtlogScope.of(context),
        identity = ArtlogScope.of(context).userKey;
    final message = input.text.trim();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final reply = await s.collectionChat(message, collectionId: selected);
      if (mounted && identity == s.userKey) {
        setState(() {
          replies = [
            ...replies.skip(replies.length > 5 ? replies.length - 5 : 0),
            reply,
          ];
          input.clear();
        });
      }
    } catch (e) {
      if (mounted && identity == s.userKey) {
        setState(() => error = ArtlogState.message(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> apply(CollectionProposal p) async {
    if (busy || consumed.contains(p)) return;
    final s = ArtlogScope.of(context),
        identity = ArtlogScope.of(context).userKey;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await s.applyCollectionProposal(p);
      if (!mounted || identity != s.userKey) return;
      setState(() => consumed.add(p));
      await widget.onChanged();
    } catch (e) {
      if (mounted) setState(() => error = ArtlogState.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SurfacePanel(
    padding: EdgeInsets.all(compact(context) ? 18 : 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('말로 만드는 나의 전시', style: serif(24)),
        const SizedBox(height: 10),
        Text(
          '“고요한 풍경 컬렉션 만들어줘”\n“별이 빛나는 밤을 고요한 풍경에 담아줘”',
          style: sans(12, color: muted, height: 1.9),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(
            '${widget.groups.map((c) => c.id).join(',')}/$selected',
          ),
          initialValue: widget.groups.any((c) => c.id == selected)
              ? selected
              : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '담을 컬렉션 (선택)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('대화에서 직접 이름 말하기')),
            for (final c in widget.groups)
              DropdownMenuItem(
                value: c.id,
                child: Text(c.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: busy ? null : (v) => setState(() => selected = v),
        ),
        const SizedBox(height: 16),
        for (final r in replies)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SurfacePanel(
              tinted: true,
              radius: 20,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.answer, style: sans(13)),
                  if (r.proposal != null) ...[
                    const SizedBox(height: 12),
                    ArtButton(
                      consumed.contains(r.proposal)
                          ? '완료했어요'
                          : r.proposal!.action == 'create'
                          ? '이 컬렉션 만들기'
                          : '이 작품 담기',
                      onTap: busy || consumed.contains(r.proposal)
                          ? null
                          : () => apply(r.proposal!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        TextField(
          controller: input,
          enabled: !busy,
          minLines: 1,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: '컬렉션에 어떤 그림을 담을까요?',
            hintText: '원하는 컬렉션이나 작품을 말해 주세요.',
          ),
          onSubmitted: (_) => send(),
        ),
        const SizedBox(height: 10),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: sans(12, color: Colors.red.shade800)),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: ArtButton(
            busy ? '확인하고 있어요…' : '요청 보내기',
            onTap: busy ? null : send,
          ),
        ),
      ],
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
