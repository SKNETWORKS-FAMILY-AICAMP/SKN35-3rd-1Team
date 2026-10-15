import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../conversations/collection_conversation.dart';
import '../models.dart';
import '../mypage.dart';
import '../state.dart';
import 'account_guard.dart';
import 'design.dart';

Future<void> showCollectionAssistant(
  BuildContext context, {
  Artwork? artwork,
}) async {
  if (!await ensureLogin(context) || !context.mounted) return;
  final state = ArtlogScope.of(context);
  final identity = state.userKey;
  final id = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AccountGuard(
      state: state,
      child: CollectionAssistant(state: state, artwork: artwork),
    ),
  );
  if (id != null &&
      context.mounted &&
      state.authenticated &&
      state.userKey == identity) {
    unawaited(context.push<void>('/collection/$id'));
  }
}

class CollectionAssistant extends StatefulWidget {
  const CollectionAssistant({super.key, required this.state, this.artwork});
  final ArtlogState state;
  final Artwork? artwork;
  @override
  State<CollectionAssistant> createState() => _CollectionAssistantState();
}

class _CollectionAssistantState extends State<CollectionAssistant> {
  late final conversation = CollectionConversation(widget.state)
    ..addListener(changed);
  final input = TextEditingController(), scroll = ScrollController();
  List<ArtCollection> collections = [];
  bool loading = true;
  String? loadError, selected;

  @override
  void initState() {
    super.initState();
    // Initialize before a request can notify listeners.
    conversation;
    unawaited(load());
  }

  Future<void> load() async {
    final identity = widget.state.userKey;
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final rows = await widget.state.collections(force: true);
      if (mounted && widget.state.userKey == identity) {
        setState(() => collections = rows);
      }
    } catch (e) {
      if (mounted && widget.state.userKey == identity) {
        setState(() => loadError = ArtlogState.message(e));
      }
    } finally {
      if (mounted && widget.state.userKey == identity) {
        setState(() => loading = false);
      }
    }
  }

  void changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> ask(String raw) async {
    if (!conversation.canSend || loading) return;
    if (raw.trim().isNotEmpty && raw.trim().runes.length <= 500) input.clear();
    await conversation.ask(raw, collectionId: selected);
  }

  void example(String value) {
    input.text = value;
    input.selection = TextSelection.collapsed(offset: value.length);
  }

  @override
  void dispose() {
    conversation.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = conversation.canSend && !loading;
    final height =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom -
        64;
    return PopScope(
      canPop: !conversation.saving,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(
          width: 620,
          height: height.clamp(240.0, 740.0),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      color: green,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('AI 컬렉션 도우미', style: serif(22))),
                    IconButton(
                      tooltip: '컬렉션 도우미 닫기',
                      onPressed: conversation.saving
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                Text(
                  '원하는 모음을 말해 주세요. 내용을 확인하고 저장할 때만 반영돼요.',
                  style: sans(12, color: muted),
                ),
                const SizedBox(height: 12),
                if (loading) const LinearProgressIndicator(minHeight: 2),
                if (loadError != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '내 컬렉션을 불러오지 못했어요. $loadError',
                          style: sans(11),
                        ),
                      ),
                      TextButton(onPressed: load, child: const Text('다시 불러오기')),
                    ],
                  )
                else if (collections.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'collection-target-${collections.map((c) => c.id).join('-')}',
                    ),
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '작품을 담을 컬렉션 (선택)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('요청에 컬렉션 이름 직접 적기'),
                      ),
                      for (final c in collections)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: enabled
                        ? (id) =>
                              setState(() => selected = id == '' ? null : id)
                        : null,
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    children: [
                      if (conversation.messages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 8,
                            children: [
                              for (final q in [
                                '최근 본 작품으로 컬렉션 만들어줘',
                                '고요한 풍경 컬렉션 만들어줘',
                                if (widget.artwork != null &&
                                    collections.isNotEmpty)
                                  '‘${widget.artwork!.title}’을 ‘${collections.first.name}’에 담아줘',
                              ])
                                ActionChip(
                                  label: Text(q, style: sans(11)),
                                  onPressed: enabled ? () => example(q) : null,
                                ),
                            ],
                          ),
                        ),
                      for (var i = 0; i < conversation.messages.length; i++)
                        _turn(i),
                      if (conversation.busy)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '감상 기록과 컬렉션을 확인하고 있어요…',
                            style: sans(12, color: muted),
                          ),
                        ),
                    ],
                  ),
                ),
                if (conversation.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      conversation.error!,
                      style: sans(12, color: Colors.red.shade800),
                    ),
                  ),
                if (conversation.failedQuestion != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: enabled
                          ? () => ask(conversation.failedQuestion!)
                          : null,
                      child: const Text('요청 다시 보내기'),
                    ),
                  ),
                if (conversation.savedCollectionId case final id?)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, id),
                    icon: const Icon(Icons.arrow_outward, size: 16),
                    label: const Text('저장한 컬렉션 열기'),
                  ),
                const Divider(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('collection-assistant-input'),
                        controller: input,
                        enabled: enabled,
                        maxLength: 500,
                        minLines: 1,
                        maxLines: 3,
                        style: sans(13),
                        textInputAction: TextInputAction.send,
                        onSubmitted: ask,
                        decoration: const InputDecoration(
                          hintText: '컬렉션 만들기 또는 작품 담기를 요청해 보세요.',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: '컬렉션 요청 보내기',
                      onPressed: enabled ? () => ask(input.text) : null,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.state.config.demo
                      ? '미리보기에서는 실제 AI를 호출하지 않아요.'
                      : '요청은 각각 독립적으로 처리돼요. 이 도우미 대화는 창을 닫으면 사라져요.',
                  style: sans(10, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _turn(int index) {
    final turn = conversation.messages[index];
    final pending = conversation.pendingProposal == index;
    final proposal = turn.proposal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: turn.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: turn.isUser ? ink : soft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                turn.content,
                style: sans(13, color: turn.isUser ? Colors.white : ink),
              ),
              if (proposal != null) ...[
                const SizedBox(height: 8),
                Text(
                  proposal.action == 'create'
                      ? '새 컬렉션 · ${proposal.name ?? ''} · ${proposal.artworkIds.length}점'
                      : '${widget.state.workFor(proposal.artworkId ?? '')?.title ?? '작품 #${proposal.artworkId}'} → ${collections.where((c) => c.id == proposal.collectionId).firstOrNull?.name ?? '컬렉션 #${proposal.collectionId}'}',
                  style: sans(11, color: muted),
                ),
                if (proposal.action == 'create' &&
                    proposal.artworkIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      [
                        for (final id in proposal.artworkIds.take(6))
                          widget.state.workFor(id)?.title ?? '작품 #$id',
                        if (proposal.artworkIds.length > 6)
                          '외 ${proposal.artworkIds.length - 6}점',
                      ].join(' · '),
                      style: sans(11, color: muted),
                    ),
                  ),
                if (pending)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilledButton(
                        key: const ValueKey('collection-proposal-confirm'),
                        onPressed: conversation.canSend
                            ? () async {
                                final id = await conversation.confirm(index);
                                if (id != null && mounted) await load();
                              }
                            : null,
                        child: Text(conversation.saving ? '저장 중…' : '확인하고 저장'),
                      ),
                      TextButton(
                        onPressed: conversation.canSend
                            ? () => conversation.dismiss(index)
                            : null,
                        child: const Text('취소'),
                      ),
                    ],
                  )
                else
                  Text('종료된 제안', style: sans(10, color: muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
