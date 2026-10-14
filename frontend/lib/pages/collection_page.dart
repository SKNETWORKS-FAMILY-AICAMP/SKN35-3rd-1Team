import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../mypage.dart';
import '../state.dart';
import '../ui/design.dart';
import '../ui/collection_workspace.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key, required this.id});
  final String id;
  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final search = TextEditingController();
  final searchKey = GlobalKey();
  ArtCollection? group;
  List<Artwork> works = [];
  String? identity, cursor, error;
  int serial = 0;
  bool loading = true, managing = false;
  final Set<String> busy = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ArtlogScope.of(context);
    final next = '${s.userKey}/${s.authenticated}';
    if (identity == next) return;
    identity = next;
    ++serial;
    group = null;
    works = [];
    cursor = error = null;
    busy.clear();
    search.clear();
    managing = false;
    loading = s.authenticated;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && s.authenticated) load(reset: true);
    });
  }

  @override
  void dispose() {
    ++serial;
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool reset = false}) async {
    final s = ArtlogScope.of(context), owner = identity, request = ++serial;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final groups = await s.collections(force: reset);
      if (!mounted || request != serial || identity != owner) return;
      final collection = groups.where((c) => c.id == widget.id).firstOrNull;
      if (collection == null) {
        setState(() {
          group = null;
          works = [];
          cursor = null;
        });
        return;
      }
      final page = await s.collectionItems(
        widget.id,
        cursor: reset ? null : cursor,
      );
      if (!mounted || request != serial || identity != owner) return;
      setState(() {
        group = collection;
        works = {
          for (final a in [...(reset ? <Artwork>[] : works), ...page.items])
            a.id: a,
        }.values.toList();
        cursor = page.cursor;
      });
    } catch (e) {
      if (mounted && request == serial && identity == owner) {
        setState(() => error = ArtlogState.message(e));
      }
    } finally {
      if (mounted && request == serial && identity == owner) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> collect(Artwork art, {bool remove = false}) async {
    if (loading || busy.isNotEmpty) return;
    final s = ArtlogScope.of(context), owner = identity;
    setState(() => busy.add(art.id));
    try {
      await s.collect(widget.id, art.id, remove: remove);
      if (!mounted || identity != owner) return;
      await load(reset: true);
      if (!mounted || identity != owner) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(remove ? '컬렉션에서 꺼냈어요.' : '컬렉션에 담았어요.')),
      );
    } catch (e) {
      if (mounted && identity == owner) showError(context, e);
    } finally {
      if (mounted && identity == owner) setState(() => busy.remove(art.id));
    }
  }

  Future<void> edit() async {
    final s = ArtlogScope.of(context), owner = identity;
    final changed = await editCollection(context, s, collection: group);
    if (changed != null && mounted && identity == owner) {
      await load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (!s.authenticated) {
      return PageWidth(
        vertical: 40,
        child: EmptyView(
          '나만의 전시는 로그인 후 볼 수 있어요.',
          action: ArtButton('로그인', onTap: () => ensureLogin(context)),
        ),
      );
    }
    if (group == null) {
      return PageWidth(
        vertical: 48,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : EmptyView(
                error ?? '컬렉션을 찾을 수 없어요.',
                description: error == null ? '삭제되었거나 이 계정의 컬렉션이 아닐 수 있어요.' : '',
                action: ArtButton(
                  error == null ? '내 컬렉션으로' : '다시 불러오기',
                  onTap: error == null
                      ? () => context.go('/mypage?tab=collections')
                      : () => load(reset: true),
                ),
              ),
      );
    }
    final c = group!;
    final q = search.text.trim().toLowerCase();
    final results = q.isEmpty
        ? <Artwork>[]
        : s.artworks
              .where(
                (a) =>
                    '${a.title} ${s.artistName(a)}'.toLowerCase().contains(q),
              )
              .take(8)
              .toList();
    final known = {...c.artworkIds, ...works.map((a) => a.id)};
    final cover = works.isEmpty ? c.previews : works;
    return PageWidth(
      vertical: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('collection-back'),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/mypage?tab=collections'),
              icon: const Icon(Icons.arrow_back, size: 17),
              label: const Text('내 컬렉션'),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            key: const ValueKey('collection-exhibition-header'),
            padding: EdgeInsets.all(compact(context) ? 24 : 40),
            color: museumBlack,
            child: LayoutBuilder(
              builder: (context, bounds) {
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Eyebrow('A PERSONAL EXHIBITION', color: museumMuted),
                    const SizedBox(height: 18),
                    Text(
                      c.name,
                      style: serif(
                        compact(context) ? 28 : 38,
                        color: museumText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      c.description.isEmpty
                          ? '내가 고른 그림, 나만의 시선으로.'
                          : c.description,
                      style: sans(13, color: museumMuted),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        Text(
                          '${c.count}점의 작품',
                          style: sans(12, color: museumText),
                        ),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: museumMuted,
                            ),
                            SizedBox(width: 5),
                            Text(
                              '나만 보기',
                              style: TextStyle(
                                fontSize: 12,
                                color: museumMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
                if (bounds.maxWidth < 720 || cover.isEmpty) return title;
                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 48),
                    SizedBox(
                      width: 320,
                      height: 210,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (final (i, art) in cover.take(3).indexed)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: i == 0 ? 0 : 8,
                                  top: i == 1 ? 25 : 0,
                                  bottom: i == 1 ? 0 : 25,
                                ),
                                child: ArtImage(art.image, label: art.title),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('컬렉션에 담긴 그림', style: serif(24)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: loading || busy.isNotEmpty ? null : edit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('소개 편집'),
                  ),
                  TextButton.icon(
                    onPressed: loading || busy.isNotEmpty
                        ? null
                        : () => setState(() => managing = !managing),
                    icon: Icon(managing ? Icons.check : Icons.tune, size: 16),
                    label: Text(managing ? '정리 완료' : '작품 정리'),
                  ),
                  ArtButton(
                    '작품 담기',
                    icon: Icons.add,
                    onTap: () => Scrollable.ensureVisible(
                      searchKey.currentContext!,
                      alignment: .2,
                      duration: reduceMotion(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 400),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (error != null)
            EmptyView(
              error!,
              action: ArtButton('다시 시도', onTap: () => load(reset: true)),
            ),
          if (works.isEmpty && !loading)
            EmptyView(
              '첫 그림을 기다리는 전시예요.',
              description: '아래에서 작품을 찾아 컬렉션에 담아 보세요.',
            ),
          LayoutBuilder(
            builder: (context, bounds) {
              final desiredColumns = bounds.maxWidth >= 1000
                  ? 3
                  : bounds.maxWidth >= 340
                  ? 2
                  : 1;
              final columns = desiredColumns.clamp(1, works.length.clamp(1, 3));
              final gap = compact(context) ? 16.0 : 28.0;
              final width = ((bounds.maxWidth - gap * (columns - 1)) / columns)
                  .clamp(0.0, columns == 1 ? 560.0 : double.infinity);
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: gap,
                runSpacing: 22,
                children: [
                  for (final (i, art) in works.indexed)
                    SizedBox(
                      width: width,
                      child: ScrollReveal(
                        key: ValueKey('collection-art-${art.id}'),
                        order: i % columns,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ArtworkCard(art),
                            if (managing)
                              OutlinedButton.icon(
                                onPressed: loading || busy.isNotEmpty
                                    ? null
                                    : () => collect(art, remove: true),
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 17,
                                ),
                                label: Text(
                                  busy.contains(art.id) ? '변경 중…' : '컬렉션에서 꺼내기',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (cursor != null && !loading)
            Center(
              child: ArtButton('그림 더 보기', outline: true, onTap: () => load()),
            ),
          const SizedBox(height: 44),
          const Divider(),
          const SizedBox(height: 24),
          Text('전시에 다음 그림을 더해보세요', style: serif(24)),
          const SizedBox(height: 10),
          Text('작품이나 작가를 검색해 컬렉션에 담을 수 있어요.', style: sans(12, color: muted)),
          const SizedBox(height: 20),
          TextField(
            key: searchKey,
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '담고 싶은 작품 찾기',
              hintText: '작품명 또는 작가',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          if (q.isNotEmpty && results.isEmpty) const EmptyView('일치하는 작품이 없어요.'),
          for (final art in results)
            ListTile(
              leading: SizedBox(
                width: 48,
                height: 56,
                child: ArtImage(art.image),
              ),
              title: Text(art.title, style: sans(13)),
              subtitle: Text(s.artistName(art), style: sans(11, color: muted)),
              trailing: IconButton(
                tooltip: '${art.title} 담기',
                onPressed: loading || busy.isNotEmpty || known.contains(art.id)
                    ? null
                    : () => collect(art),
                icon: Icon(
                  known.contains(art.id)
                      ? Icons.check
                      : Icons.add_circle_outline,
                ),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
