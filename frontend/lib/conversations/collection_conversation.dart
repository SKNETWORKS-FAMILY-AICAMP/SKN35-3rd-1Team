import 'package:flutter/foundation.dart';
import '../mypage.dart';
import '../state.dart';

class CollectionTurn {
  const CollectionTurn(this.content, {this.isUser = false, this.proposal});
  final String content;
  final bool isUser;
  final CollectionProposal? proposal;
}

/// Proposals are read-only until the member confirms the latest one.
class CollectionConversation extends ChangeNotifier {
  CollectionConversation(this.state) {
    state.addListener(_identityChanged);
    _identityChanged();
  }
  final ArtlogState state;
  final List<CollectionTurn> messages = [];
  bool busy = false, saving = false, _disposed = false;
  String? error, failedQuestion, savedCollectionId;
  int? pendingProposal;
  String _identity = '';
  int _revision = 0;
  bool get canSend => state.authenticated && !busy && !saving;
  bool _current(int revision) => !_disposed && revision == _revision;

  void _identityChanged() {
    final next = '${state.userKey}/${state.authenticated}/${state.config.demo}';
    if (next == _identity) return;
    _identity = next;
    ++_revision;
    messages.clear();
    pendingProposal = null;
    error = failedQuestion = savedCollectionId = null;
    busy = saving = false;
    notifyListeners();
  }

  Future<void> ask(String raw, {String? collectionId}) async {
    final question = raw.trim();
    if (!canSend || question.isEmpty) return;
    if (question.runes.length > 500) {
      error = '요청은 500자까지 적어 주세요.';
      notifyListeners();
      return;
    }
    final revision = _revision;
    if (failedQuestion == question &&
        messages.isNotEmpty &&
        messages.last.isUser) {
      messages.removeLast();
    }
    messages.add(CollectionTurn(question, isUser: true));
    // A new request supersedes the old proposal; never apply an obsolete action.
    pendingProposal = null;
    error = failedQuestion = savedCollectionId = null;
    busy = true;
    notifyListeners();
    try {
      final reply = await state.collectionChat(
        question,
        collectionId: collectionId,
      );
      if (!_current(revision)) return;
      messages.add(CollectionTurn(reply.answer, proposal: reply.proposal));
      if (reply.proposal != null) pendingProposal = messages.length - 1;
    } catch (e) {
      if (_current(revision)) {
        error = ArtlogState.message(e);
        failedQuestion = question;
      }
    } finally {
      if (_current(revision)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<String?> confirm(int index) async {
    if (!canSend || pendingProposal != index) return null;
    final proposal = messages[index].proposal;
    if (proposal == null) return null;
    final revision = _revision;
    saving = true;
    error = null;
    notifyListeners();
    try {
      final id = await state.applyCollectionProposal(proposal);
      if (!_current(revision)) return null;
      pendingProposal = null;
      savedCollectionId = id;
      messages.add(const CollectionTurn('컬렉션에 저장했어요. 내 컬렉션에서 이어서 편집할 수 있어요.'));
      return id;
    } catch (e) {
      if (_current(revision)) error = ArtlogState.message(e);
      return null;
    } finally {
      if (_current(revision)) {
        saving = false;
        notifyListeners();
      }
    }
  }

  void dismiss(int index) {
    if (busy || saving || pendingProposal != index) return;
    pendingProposal = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_revision;
    state.removeListener(_identityChanged);
    super.dispose();
  }
}
