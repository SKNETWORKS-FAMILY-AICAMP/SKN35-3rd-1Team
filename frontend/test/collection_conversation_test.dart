import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/conversations/collection_conversation.dart';
import 'package:artlog_web/state.dart';

http.Response utf8Response(
  String body,
  int status, {
  Map<String, String>? headers,
}) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
);

Future<ArtlogState> member(
  Future<http.Response> Function(http.Request) handler,
) async {
  SharedPreferences.setMockInitialValues({});
  final api = ArtlogApi(
    baseUrl: 'https://example.test',
    client: MockClient(handler),
  )..token = 'test-token';
  return ArtlogState(
    const AppConfig(demo: false, authProvider: 'api'),
    api,
    await SharedPreferences.getInstance(),
  )..email = 'test@example.test';
}

http.Response proposal({String action = 'create'}) => utf8Response(
  jsonEncode({
    'answer': '저장할 내용을 확인해 주세요.',
    'proposal': action == 'create'
        ? {
            'action': 'create',
            'name': '고요한 풍경',
            'artwork_ids': [1, 2],
          }
        : {'action': 'add', 'collection_id': 9, 'artwork_id': 1},
  }),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'request is read-only; confirmation creates once with all selected works',
    () async {
      final calls = <http.Request>[];
      final save = Completer<http.Response>();
      final state = await member((r) async {
        calls.add(r);
        return r.url.path.endsWith('/chat') ? proposal() : save.future;
      });
      final chat = CollectionConversation(state);
      addTearDown(() {
        chat.dispose();
        state.dispose();
      });
      await chat.ask('최근 본 작품으로 모아줘');
      expect(calls.map((r) => r.url.path), ['/api/me/collections/chat']);
      final index = chat.pendingProposal!;
      final first = chat.confirm(index);
      expect(await chat.confirm(index), isNull);
      save.complete(
        utf8Response(
          '{"id":9,"name":"고요한 풍경","artwork_count":2,"previews":[]}',
          201,
        ),
      );
      expect(await first, '9');
      expect(calls.length, 2);
      expect(jsonDecode(calls.last.body)['artwork_ids'], [1, 2]);
      expect(chat.pendingProposal, isNull);
      expect(await chat.confirm(index), isNull);
    },
  );

  test('existing collection uses item PUT only after confirmation', () async {
    final calls = <http.Request>[];
    final state = await member((r) async {
      calls.add(r);
      return r.method == 'PUT'
          ? utf8Response('{}', 200)
          : proposal(action: 'add');
    });
    final chat = CollectionConversation(state);
    addTearDown(() {
      chat.dispose();
      state.dispose();
    });
    await chat.ask('씨름을 담아줘', collectionId: '9');
    expect(jsonDecode(calls.single.body)['collection_id'], 9);
    await chat.confirm(chat.pendingProposal!);
    expect(calls.last.method, 'PUT');
    expect(calls.last.url.path, '/api/me/collections/9/items/1');
  });

  test('new requests and dismiss invalidate earlier proposals', () async {
    final calls = <http.Request>[];
    final state = await member((r) async {
      calls.add(r);
      return proposal();
    });
    final chat = CollectionConversation(state);
    addTearDown(() {
      chat.dispose();
      state.dispose();
    });
    await chat.ask('첫 요청');
    final old = chat.pendingProposal!;
    await chat.ask('다른 요청');
    expect(await chat.confirm(old), isNull);
    chat.dismiss(chat.pendingProposal!);
    expect(chat.pendingProposal, isNull);
    expect(calls.every((r) => r.url.path.endsWith('/chat')), isTrue);
  });

  test(
    'save failure keeps proposal available and displays collection limit error',
    () async {
      final state = await member(
        (r) async => r.url.path.endsWith('/chat')
            ? proposal()
            : utf8Response(jsonEncode({'detail': '컬렉션은 10개까지 만들 수 있어요.'}), 409),
      );
      final chat = CollectionConversation(state);
      addTearDown(() {
        chat.dispose();
        state.dispose();
      });
      await chat.ask('컬렉션 만들어줘');
      final index = chat.pendingProposal!;
      expect(await chat.confirm(index), isNull);
      expect(chat.pendingProposal, index);
      expect(chat.error, contains('10개'));
      expect(chat.saving, isFalse);
    },
  );

  test(
    'logout discards a pending reply and does not expose previous proposal',
    () async {
      final reply = Completer<http.Response>();
      final started = Completer<void>();
      final state = await member((r) {
        started.complete();
        return reply.future;
      });
      final chat = CollectionConversation(state);
      addTearDown(() {
        chat.dispose();
        state.dispose();
      });
      final ask = chat.ask('최근 본 그림 모아줘');
      await started.future;
      await state.logout();
      reply.complete(proposal());
      await ask;
      expect(chat.messages, isEmpty);
      expect(chat.pendingProposal, isNull);
      expect(chat.canSend, isFalse);
    },
  );

  test(
    'duplicate sends are blocked; failed request retries without duplicate question',
    () async {
      var requests = 0;
      final reply = Completer<http.Response>();
      final state = await member((r) async {
        requests++;
        return requests == 1 ? reply.future : proposal();
      });
      final chat = CollectionConversation(state);
      addTearDown(() {
        chat.dispose();
        state.dispose();
      });
      final first = chat.ask('최근 본 그림 모아줘');
      await chat.ask('중복 요청');
      reply.complete(utf8Response('{}', 503));
      await first;
      expect(requests, 1);
      expect(chat.failedQuestion, '최근 본 그림 모아줘');
      await chat.ask(chat.failedQuestion!);
      expect(chat.messages.where((m) => m.isUser).length, 1);
      expect(chat.pendingProposal, isNotNull);
    },
  );
}
