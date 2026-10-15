import 'package:flutter/material.dart';
import '../models.dart';
import '../conversations/docent_conversation.dart';
import '../state.dart';
import 'collection_workspace.dart' show CollectionCover, editCollection;
import 'design.dart';
import 'collection_assistant.dart';

class DocentChat extends StatefulWidget {
  const DocentChat(this.art, {super.key});
  final Artwork art;
  @override
  State<DocentChat> createState() => _DocentChatState();
}

class _DocentChatState extends State<DocentChat> {
  final input = TextEditingController(), scroll = ScrollController();
  DocentConversation? conversation;
  String identity = '';
  List<ChatTurn> get messages => conversation!.messages;
  bool get busy => !conversation!.canSend;
  String? get error => conversation!.error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    conversation ??= DocentConversation(ArtlogScope.of(context), widget.art)
      ..addListener(_changed);
    identity = conversation!.identity;
  }

  void _changed() {
    if (!mounted) return;
    if (identity != conversation!.identity) {
      identity = conversation!.identity;
      input.clear();
    }
    setState(() {});
    bottom();
  }

  Future<void> ask(String raw) async {
    if (raw.trim().isEmpty || busy) return;
    if (raw.trim().runes.length <= 500) input.clear();
    await conversation!.ask(raw);
  }

  Future<void> reset() async {
    final confirmedIdentity = conversation!.identity;
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => SurfaceDialog(
        title: const Text('이 작품의 대화를 초기화할까요?'),
        content: const Text('저장된 질문과 답변이 삭제됩니다. 작품 감상 기록과 좋아요는 유지돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('대화 초기화'),
          ),
        ],
      ),
    );
    if (approved != true ||
        !mounted ||
        conversation!.identity != confirmedIdentity) {
      return;
    }
    try {
      await conversation!.reset();
      if (conversation!.identity == confirmedIdentity) input.clear();
    } catch (e) {
      if (mounted && conversation!.identity == confirmedIdentity) {
        showError(context, e);
      }
    }
  }

  void bottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    conversation?.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    return SizedBox(
      height:
          (MediaQuery.sizeOf(context).height -
                  (MediaQuery.sizeOf(context).width < 850 ? 120 : 150))
              .clamp(560.0, 920.0),
      child: SurfacePanel(
        radius: 12,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI 도슨트',
                          style: sans(14, weight: FontWeight.w600),
                        ),
                        Text(
                          '설명 방식을 고르고 작품에 관해 물어보세요.',
                          style: sans(11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('docent-collection-assistant'),
                    tooltip: '컬렉션 요청',
                    onPressed: busy
                        ? null
                        : () => showCollectionAssistant(
                            context,
                            artwork: widget.art,
                          ),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 19),
                  ),
                  if (s.config.demo)
                    Text('미리보기', style: sans(11, color: muted)),
                  IconButton(
                    tooltip: '대화 초기화',
                    onPressed: busy || messages.isEmpty ? null : reset,
                    icon: const Icon(Icons.restart_alt, size: 19),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
              child: _StyleTabs(
                value: conversation!.style,
                onChanged: busy ? null : conversation!.setStyle,
              ),
            ),
            if (s.authenticated && !s.config.demo)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                child: Text(
                  '같은 작품에 3번 이상 질문하고 답변을 받으면 컬렉션 담기를 제안해요. '
                  '이미 담은 작품은 제외해요. '
                  '제안은 대화마다 한 번이며, 제안만으로 저장되지는 않아요.',
                  style: sans(11, color: muted),
                ),
              ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(24),
                children: [
                  if (messages.isEmpty) ...[
                    Text('무엇이 궁금한가요?', style: serif(22)),
                    const SizedBox(height: 8),
                    Text(
                      '작품의 작은 디테일부터 작가의 이야기까지.',
                      style: sans(13, color: muted),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (conversation!.loading) ...[
                    const LinearProgressIndicator(color: sage, minHeight: 2),
                    Text(
                      '이 작품과 나눈 대화를 불러오고 있어요.',
                      style: sans(11, color: muted),
                    ),
                  ],
                  if (conversation!.historyError != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '이전 대화를 불러오지 못했어요. ${conversation!.historyError}',
                          style: sans(12),
                        ),
                        TextButton(
                          onPressed: conversation!.restore,
                          child: const Text('대화 다시 불러오기'),
                        ),
                      ],
                    ),
                  for (final m in messages)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: m.role == 'user' ? 14 : 22,
                      ),
                      child: Column(
                        crossAxisAlignment: m.role == 'user'
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (m.role != 'user') ...[
                            Text(
                              '✳  Docentalk 도슨트',
                              style: sans(11, color: muted),
                            ),
                            const SizedBox(height: 7),
                          ],
                          m.role == 'user'
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: Container(
                                    key: const ValueKey('user-bubble'),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: ink,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(4),
                                      ),
                                    ),
                                    child: Text(
                                      m.content,
                                      style: sans(
                                        13,
                                        color: Colors.white,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: surfaceDecoration(radius: 16),
                                  child: Text(
                                    m.content,
                                    style: sans(
                                      13,
                                      color: m.refused ? muted : ink,
                                      height: 1.9,
                                    ),
                                  ),
                                ),
                          if (m.suggestion case final offer?) ...[
                            const SizedBox(height: 10),
                            _CollectOffer(
                              offer: offer,
                              onClose: () => conversation!.closeSuggestion(m),
                            ),
                          ],
                          if (m.sources.isNotEmpty) ...[
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                for (var i = 0; i < m.sources.length; i++)
                                  SourceChip(
                                    avatar: const Icon(
                                      Icons.article_outlined,
                                      size: 13,
                                    ),
                                    label: Text(
                                      '${i + 1} · ${m.sources[i].name.isEmpty ? m.sources[i].title : m.sources[i].name}',
                                      style: sans(11, color: muted),
                                    ),
                                    onPressed: () =>
                                        _showSources(context, m.sources),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (conversation!.busy || conversation!.resetting)
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const LinearProgressIndicator(
                            color: sage,
                            minHeight: 2,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            conversation!.resetting
                                ? '대화를 정리하고 있어요…'
                                : '도슨트가 답변하고 있어요…',
                            style: sans(12, color: muted),
                          ),
                        ],
                      ),
                    ),
                  if (error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: const Color(0xfff4eadc),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(error!, style: sans(12)),
                          if (conversation!.failedQuestion != null)
                            TextButton(
                              onPressed: busy ? null : conversation!.retry,
                              child: const Text('답변 다시 요청하기'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xffdce5f1))),
              ),
              child: Column(
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      for (final q in [
                        '어디부터 보면 좋을까요?',
                        '언제 그린 작품인가요?',
                        '작가에 대해 알려주세요',
                      ])
                        SourceChip(
                          label: Text(q, style: sans(11, color: muted)),
                          onPressed: busy ? null : () => ask(q),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          enabled: !busy,
                          maxLength: 500,
                          maxLines: 2,
                          minLines: 1,
                          style: sans(12),
                          textInputAction: TextInputAction.send,
                          onSubmitted: ask,
                          decoration: InputDecoration(
                            hintText: '이 그림에 대해 궁금한 점을 물어보세요.',
                            hintStyle: sans(11, color: muted),
                            counterText: '',
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      IconButton.filled(
                        tooltip: '질문 보내기',
                        style: editorialButtonStyle(dark: true),
                        onPressed: busy ? null : () => ask(input.text),
                        icon: const Icon(Icons.arrow_upward, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    s.config.demo
                        ? '미리보기 답변입니다. 실제 AI 답변과 구분해 주세요.'
                        : '도슨트의 해설은 출처 자료와 함께 살펴보세요.',
                    style: sans(9, color: muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSources(BuildContext context, List<Source> sources) => showDialog(
    context: context,
    builder: (c) => SurfaceDialog(
      backgroundColor: paper,
      title: Text('답변의 근거 자료', style: serif(22)),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final source in sources)
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.title,
                        style: sans(14, weight: FontWeight.w600),
                      ),
                      Text(
                        '${source.name.isEmpty ? '출처 정보 확인 중' : source.name} · ${source.typeLabel}',
                        style: sans(11, color: muted),
                      ),
                      if (source.license.isNotEmpty)
                        Text(
                          '이용 조건: ${source.license}',
                          style: sans(11, color: muted),
                        ),
                      if (source.url.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => openSource(context, source.url),
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('원문 확인하기'),
                        ),
                      if (source.basisSources.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '편집 보강 근거',
                          style: sans(11, weight: FontWeight.w600),
                        ),
                        for (final basis in source.basisSources)
                          basis.url.isNotEmpty
                              ? TextButton.icon(
                                  onPressed: () =>
                                      openSource(context, basis.url),
                                  icon: const Icon(Icons.open_in_new, size: 13),
                                  label: Text(
                                    basis.name.isEmpty ? '근거 자료' : basis.name,
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    basis.name,
                                    style: sans(11, color: muted),
                                  ),
                                ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('닫기')),
      ],
    ),
  );
}

/// Wording and explanation depth for the next answers. Old answers stay as written.
class _StyleTabs extends StatelessWidget {
  const _StyleTabs({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String>? onChanged;
  static const styles = [
    ('easy', 'Easy', '쉬운 말로 핵심을 설명'),
    ('standard', 'Standard', '미술 용어와 표현 효과를 함께 설명'),
    ('deep', 'Deep', '기법과 관련 맥락까지 폭넓고 깊이 있게 설명'),
  ];

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('docent-style-tabs'),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: soft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in styles)
              Tooltip(
                message: s.$3,
                child: Semantics(
                  selected: value == s.$1,
                  button: true,
                  label: '${s.$2} 설명, ${s.$3}',
                  child: TextButton(
                    key: ValueKey('docent-style-${s.$1}'),
                    onPressed: onChanged == null
                        ? null
                        : () => onChanged!(s.$1),
                    style:
                        editorialButtonStyle(
                          dark: value == s.$1,
                          quiet: value != s.$1,
                          radius: 999,
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                        ).copyWith(
                          shape: const WidgetStatePropertyAll(StadiumBorder()),
                        ),
                    child: Text(
                      s.$2,
                      style: sans(
                        12,
                        height: 1.2,
                        color: value == s.$1 ? Colors.white : muted,
                        weight: value == s.$1
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// The docent's offer to collect the artwork. Saves only when a button is tapped.
class _CollectOffer extends StatefulWidget {
  const _CollectOffer({required this.offer, required this.onClose});
  final CollectionSuggestion offer;
  final VoidCallback onClose;
  @override
  State<_CollectOffer> createState() => _CollectOfferState();
}

class _CollectOfferState extends State<_CollectOffer> {
  bool busy = false;

  Future<void> run(Future<String?> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final done = await action();
      if (!mounted || done == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      widget.onClose();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context), offer = widget.offer;
    return Container(
      key: const ValueKey('docent-collect-offer'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bookmark_add_outlined, size: 17, color: green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(offer.message, style: sans(12, height: 1.6)),
              ),
            ],
          ),
          if (offer.createsCollection && offer.artworks.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  for (final a in offer.artworks.take(5))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 46,
                          child: CollectionCover(a, height: 56),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              if (offer.createsCollection)
                SourceChip(
                  label: Text(
                    '‘${offer.name}’ 만들기',
                    style: sans(11, weight: FontWeight.w600),
                  ),
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          final c = await s.saveCollection(
                            offer.name ?? '',
                            '',
                            artworkIds: offer.artworkIds,
                          );
                          return '‘${c.name}’ 컬렉션을 만들었어요.';
                        }),
                )
              else ...[
                for (final (id, name) in offer.collections)
                  SourceChip(
                    label: Text('$name에 담기', style: sans(11)),
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            await s.collect(id, offer.artworkId);
                            return '‘$name’에 담았어요.';
                          }),
                  ),
                SourceChip(
                  avatar: const Icon(Icons.add, size: 13),
                  label: Text('새 컬렉션', style: sans(11)),
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          final c = await editCollection(
                            context,
                            s,
                            artworkIds: [offer.artworkId],
                          );
                          if (c == null) return null;
                          return '‘${c.name}’에 담았어요.';
                        }),
                ),
              ],
              SourceChip(
                label: Text('괜찮아요', style: sans(11, color: muted)),
                onPressed: busy ? null : widget.onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
