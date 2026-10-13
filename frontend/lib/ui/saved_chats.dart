import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../state.dart';
import 'design.dart';

class SavedChats extends StatefulWidget {
  const SavedChats({super.key});
  @override
  State<SavedChats> createState() => _SavedChatsState();
}

class _SavedChatsState extends State<SavedChats> {
  String? identity;
  Future<List<ChatSummary>>? future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ArtlogScope.of(context);
    final next = '${s.userKey}/${s.authenticated}';
    if (identity != next) {
      identity = next;
      if (s.authenticated && !s.config.demo) future = s.api.chats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (s.config.demo) {
      return const EmptyView(
        '실제 도슨트와 나눈 대화가 이곳에 모여요.',
        description: '미리보기 대화는 서버에 저장되지 않아요.',
      );
    }
    if (!s.authenticated) return const SizedBox.shrink();
    return FutureBuilder<List<ChatSummary>>(
      key: ValueKey(identity),
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: green)),
          );
        }
        if (snapshot.hasError) {
          return EmptyView(
            ArtlogState.message(snapshot.error!),
            action: ArtButton(
              '대화 목록 다시 불러오기',
              onTap: () => setState(() => future = s.api.chats()),
            ),
          );
        }
        if (snapshot.data?.isEmpty ?? true) {
          return EmptyView(
            '그림과 나눈 이야기를 모아보세요.',
            description: '로그인한 상태로 도슨트와 대화하면 작품별로 다시 이어볼 수 있어요.',
            action: ArtButton('그림 만나러 가기', onTap: () => context.go('/gallery')),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => future = s.api.chats()),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('대화 목록 새로고침'),
              ),
            ),
            for (final chat in snapshot.data!)
              Card(
                elevation: 0,
                color: const Color(0xffeef0e7),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: SizedBox(
                    width: 48,
                    height: 64,
                    child: ArtImage(chat.artwork.image),
                  ),
                  title: Text(
                    chat.artwork.title,
                    style: sans(14, weight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.lastMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: sans(12, color: muted),
                      ),
                      const SizedBox(height: 5),
                      Text(chat.dateLabel, style: sans(10, color: muted)),
                    ],
                  ),
                  trailing: const Icon(Icons.north_east, size: 17),
                  onTap: () => context.go('/artwork/${chat.artwork.id}'),
                ),
              ),
          ],
        );
      },
    );
  }
}
