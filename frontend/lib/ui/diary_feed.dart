import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../diary.dart';
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
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(
        eyebrow: 'ART, TOGETHER',
        title: '서로의 감상',
        subtitle: '같은 그림, 서로 다른 마음. 공개된 감상평을 만나보세요.',
        trailing: IconButton(
          tooltip: '감상 피드 새로고침',
          onPressed: loading ? null : () => load(),
          icon: const Icon(Icons.refresh),
        ),
      ),
      const SizedBox(height: 20),
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassSurface(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xffe6efef),
                      child: Icon(Icons.person_outline, size: 19, color: green),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.author,
                        style: sans(12, weight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      entry.date.replaceAll('-', '.'),
                      style: sans(10, color: muted),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.public, size: 14, color: muted),
                  ],
                ),
                const SizedBox(height: 14),
                Text(entry.content, style: sans(13)),
                if (entry.artwork case final art?) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => context.go('/artwork/${art.id}'),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ArtImage(art.image, width: 48, height: 56),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(art.title, style: sans(12)),
                              Text(
                                art.artistName,
                                style: sans(10, color: muted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.north_east, size: 16, color: green),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      if (loading)
        const Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: CircularProgressIndicator(color: green)),
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
          description: '내 서재에서 첫 번째 감상평을 남겨보세요.',
        ),
      if (!loading && error == null && cursor != null)
        ArtButton('감상평 더 보기', outline: true, onTap: () => load(more: true)),
    ],
  );
}
