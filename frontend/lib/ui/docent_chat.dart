import 'package:flutter/material.dart';
import '../models.dart';
import '../state.dart';
import 'design.dart';

class DocentChat extends StatefulWidget {
  const DocentChat(this.art, {super.key});
  final Artwork art;
  @override
  State<DocentChat> createState() => _DocentChatState();
}

class _DocentChatState extends State<DocentChat> {
  final input = TextEditingController(), scroll = ScrollController();
  final List<ChatTurn> messages = [];
  bool busy = false;
  String? error, failedQuestion;
  Future<void> ask(String raw) async {
    final q = raw.trim();
    if (q.isEmpty || busy) return;
    final s = ArtlogScope.of(context);
    final history = List<ChatTurn>.from(messages);
    setState(() {
      messages.add(ChatTurn('user', q));
      busy = true;
      error = null;
      failedQuestion = null;
      input.clear();
    });
    bottom();
    try {
      final reply = await s.ask(widget.art, q, history);
      if (!mounted) return;
      setState(
        () => messages.add(
          ChatTurn(
            'assistant',
            reply.answer,
            sources: reply.sources,
            refused: reply.refused,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error = ArtlogState.message(e);
          failedQuestion = q;
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        bottom();
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
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    return Container(
      height: compact(context) ? 720 : 790,
      decoration: BoxDecoration(
        color: const Color(0xfff1f3e9),
        border: Border.all(color: const Color(0xffdee4d3)),
        borderRadius: BorderRadius.circular(5),
      ),
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
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('나의 도슨트', style: sans(14, weight: FontWeight.w600)),
                      Text('작품 속 이야기를 함께 발견해요.', style: sans(10, color: muted)),
                    ],
                  ),
                ),
                if (s.config.demo) Text('미리보기', style: sans(10, color: muted)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xffe5eadd),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  color: const Color(0xffd5deca),
                  child: Text('함께 보는 그림', style: sans(9, color: green)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.art.title,
                    style: sans(11, color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 12),
                const Eyebrow('A CONVERSATION WITH ART'),
                const SizedBox(height: 18),
                Text('그림 앞에서,\n무엇이 궁금한가요?', style: serif(26, color: green)),
                const SizedBox(height: 15),
                Text(
                  '작품의 작은 디테일부터 작가의 이야기까지.\n떠오르는 질문을 편하게 건네보세요.',
                  style: sans(13, color: muted, height: 1.9),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 14, color: sage),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        s.config.demo
                            ? '준비된 감상 안내와 원문 링크를 체험해요.'
                            : '답변에 사용된 자료의 출처를 함께 확인해요.',
                        style: sans(10, color: muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                for (final m in messages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Column(
                      crossAxisAlignment: m.role == 'user'
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.role == 'user' ? '나' : '✳  아트로그 도슨트',
                          style: sans(10, color: muted),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: m.role == 'user'
                                ? const Color(0xffe1e7d5)
                                : Colors.white.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            m.content,
                            style: sans(
                              13,
                              color: m.refused
                                  ? const Color(0xff858164)
                                  : const Color(0xff697b59),
                              height: 1.9,
                            ),
                          ),
                        ),
                        if (m.sources.isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              for (var i = 0; i < m.sources.length; i++)
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.article_outlined,
                                    size: 13,
                                  ),
                                  label: Text(
                                    '${i + 1} · ${m.sources[i].name.isEmpty ? m.sources[i].title : m.sources[i].name}',
                                    style: sans(10, color: muted),
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
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: LinearProgressIndicator(color: sage, minHeight: 2),
                  ),
                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xfff4eadc),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(error!, style: sans(12)),
                        TextButton(
                          onPressed: () {
                            final q = failedQuestion!;
                            setState(() => messages.removeLast());
                            ask(q);
                          },
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
              border: Border(top: BorderSide(color: Color(0xffdce3d1))),
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
                      ActionChip(
                        label: Text(q, style: sans(10, color: muted)),
                        onPressed: busy ? null : () => ask(q),
                        backgroundColor: Colors.transparent,
                        side: const BorderSide(color: Color(0xffd7dfcb)),
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
                        maxLength: 1000,
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
                      style: IconButton.styleFrom(backgroundColor: green),
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
    );
  }

  void _showSources(BuildContext context, List<Source> sources) => showDialog(
    context: context,
    builder: (c) => AlertDialog(
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
                        '${source.name} · ${source.type}',
                        style: sans(11, color: muted),
                      ),
                      if (source.url.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => openSource(context, source.url),
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('원문 확인하기'),
                        ),
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
