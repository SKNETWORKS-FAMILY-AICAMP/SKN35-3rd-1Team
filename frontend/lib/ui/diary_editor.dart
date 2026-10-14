import 'package:flutter/material.dart';
import '../diary.dart';
import '../api/artlog_api.dart';
import '../models.dart';
import 'design.dart';
import 'collection_workspace.dart' show AccountGuard;
import '../state.dart';

/// Owns typing state so each keystroke does not rebuild the calendar or images.
class DiaryEditor extends StatefulWidget {
  const DiaryEditor({
    super.key,
    required this.date,
    this.entry,
    this.works = const [],
    this.legacyNote = '',
    this.initialArtworkId,
    required this.onSaved,
    required this.onDeleted,
  });
  final String date, legacyNote;
  final String? initialArtworkId;
  final DiaryEntry? entry;
  final List<Artwork> works;
  final ValueChanged<DiaryEntry> onSaved;
  final VoidCallback onDeleted;
  @override
  State<DiaryEditor> createState() => DiaryEditorState();
}

class DiaryEditorState extends State<DiaryEditor> {
  late final TextEditingController content;
  late bool isPublic;
  String? artworkId;
  bool dirty = false, busy = false, saved = false;
  @override
  void initState() {
    super.initState();
    content = TextEditingController(
      text: widget.entry?.content ?? widget.legacyNote,
    );
    isPublic = widget.entry?.isPublic ?? false;
    artworkId = widget.entry != null
        ? widget.entry!.artwork?.id
        : widget.works.any((w) => w.id == widget.initialArtworkId)
        ? widget.initialArtworkId
        : null;
  }

  @override
  void dispose() {
    content.dispose();
    super.dispose();
  }

  Future<bool> confirmDiscard() async {
    if (busy) return false;
    if (!dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => SurfaceDialog(
            title: const Text('작성 중인 감상평이 있어요'),
            content: const Text('저장하지 않은 변경을 지우고 이동할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('계속 작성'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('이동하기'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> save() async {
    if (content.text.trim().isEmpty || content.text.runes.length > 2000) {
      showError(context, const ApiException('감상평은 1~2,000자로 작성해 주세요.'));
      return;
    }
    final s = ArtlogScope.of(context),
        identity = ArtlogScope.of(context).userKey;
    setState(() => busy = true);
    try {
      final result = await s.saveDiary(
        widget.date,
        content.text,
        isPublic,
        artworkId,
      );
      if (!mounted || s.userKey != identity) return;
      setState(() {
        dirty = false;
        saved = true;
      });
      widget.onSaved(result);
    } catch (e) {
      if (mounted && s.userKey == identity) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => SurfaceDialog(
        title: const Text('감상평을 삭제할까요?'),
        content: const Text('다이어리와 공개 피드에서 함께 삭제돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final s = ArtlogScope.of(context),
        identity = ArtlogScope.of(context).userKey;
    setState(() => busy = true);
    try {
      await s.deleteDiary(widget.date);
      if (!mounted || s.userKey != identity) return;
      content.clear();
      setState(() {
        isPublic = dirty = saved = false;
        artworkId = null;
      });
      widget.onDeleted();
    } catch (e) {
      if (mounted && s.userKey == identity) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    final choices = {for (final w in widget.works) w.id: w};
    final linked = widget.entry?.artwork;
    if (linked != null) {
      choices[linked.id] = linked;
    }
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘의 감상평', style: serif(21)),
          const SizedBox(height: 12),
          if (widget.legacyNote.isNotEmpty && widget.entry == null)
            Text(
              '이 브라우저의 기존 메모를 가져왔어요. 저장하면 다이어리에 등록돼요.',
              style: sans(12, color: muted),
            ),
          TextField(
            key: const ValueKey('diary-content'),
            controller: content,
            enabled: !busy,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            style: sans(14),
            onChanged: (_) => setState(() {
              dirty = true;
              saved = false;
            }),
            decoration: const InputDecoration(
              hintText: '그림을 보며 떠오른 생각을 남겨보세요.',
            ),
          ),
          if (choices.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              key: ValueKey('artwork/$artworkId'),
              initialValue: artworkId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '함께 남길 작품'),
              items: [
                const DropdownMenuItem(value: '', child: Text('작품 없이 기록')),
                for (final w in choices.values)
                  DropdownMenuItem(
                    value: w.id,
                    child: Text(w.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      artworkId = v == '' ? null : v;
                      dirty = true;
                      saved = false;
                    }),
            ),
            const SizedBox(height: 10),
          ],
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              isPublic ? '공개 감상평' : '나만 보는 감상평',
              style: sans(12, weight: FontWeight.w600),
            ),
            subtitle: Text(
              isPublic
                  ? '저장하면 닉네임·감상평·선택한 작품이 피드에 보여요.'
                  : '저장한 감상평은 내 다이어리에서만 보여요.',
              style: sans(12, color: muted),
            ),
            secondary: Icon(
              isPublic ? Icons.public : Icons.lock_outline,
              color: green,
              size: 20,
            ),
            value: isPublic,
            onChanged: busy
                ? null
                : (v) => setState(() {
                    isPublic = v;
                    dirty = true;
                    saved = false;
                  }),
          ),
          if (dirty)
            Text('변경한 공개 범위는 저장 후 적용돼요.', style: sans(12, color: muted)),
          if (s.config.demo)
            Text(
              '체험 모드에서는 이 브라우저에 저장되며 다른 사용자에게 전송되지 않아요.',
              style: sans(12, color: muted),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ArtButton(
                busy
                    ? '저장 중…'
                    : saved
                    ? '저장했어요'
                    : '감상평 저장',
                icon: saved ? Icons.check : Icons.edit_outlined,
                onTap: busy ? null : save,
              ),
              if (widget.entry != null)
                TextButton(
                  onPressed: busy ? null : remove,
                  child: const Text('삭제'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showDiaryComposer(BuildContext context) async {
  if (!await ensureLogin(context) || !context.mounted) return;
  final state = ArtlogScope.of(context);
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AccountGuard(
      state: state,
      child: _DiaryComposer(state: state),
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('감상을 저장했어요. 공개한 글은 피드에 표시됩니다.')),
    );
  }
}

class _DiaryComposer extends StatefulWidget {
  const _DiaryComposer({required this.state});
  final ArtlogState state;
  @override
  State<_DiaryComposer> createState() => _DiaryComposerState();
}

class _DiaryComposerState extends State<_DiaryComposer> {
  final editor = GlobalKey<DiaryEditorState>();
  final today = seoulDate();
  late Future<List<DiaryEntry>> entries;
  @override
  void initState() {
    super.initState();
    entries = widget.state.diaryMonth(today.substring(0, 7));
  }

  bool closing = false;
  Future<void> close() async {
    if (closing) return;
    closing = true;
    try {
      if ((await editor.currentState?.confirmDiscard() ?? true) && mounted) {
        Navigator.pop(context);
      }
    } finally {
      closing = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: SurfaceDialog(
      title: Row(
        children: [
          Expanded(child: Text('감상 남기기', style: serif(24))),
          IconButton(
            tooltip: '작성 창 닫기',
            icon: const Icon(Icons.close, size: 20),
            onPressed: close,
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: FutureBuilder<List<DiaryEntry>>(
            future: entries,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return EmptyView(
                  ArtlogState.message(snapshot.error!),
                  action: ArtButton(
                    '다시 불러오기',
                    onTap: () => setState(
                      () => entries = widget.state.diaryMonth(
                        today.substring(0, 7),
                      ),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final entry = snapshot.data!
                  .where((e) => e.date == today)
                  .firstOrNull;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$today · 오늘의 기록은 내 서재에도 함께 저장됩니다.',
                    style: sans(12, color: muted),
                  ),
                  const SizedBox(height: 20),
                  DiaryEditor(
                    key: editor,
                    date: today,
                    entry: entry,
                    works: widget.state.artworks,
                    onSaved: (_) => Navigator.pop(context, true),
                    onDeleted: () => Navigator.pop(context, true),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
