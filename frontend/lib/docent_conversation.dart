import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'state.dart';

/// One artwork conversation, scoped to the current authentication session.
class DocentConversation extends ChangeNotifier {
  DocentConversation(this.state, this.art) {
    state.addListener(_identityChanged);
    _identityChanged();
  }
  final ArtlogState state;
  final Artwork art;
  final List<ChatTurn> messages = [];
  // easy / standard / deep, chosen with the tabs above the chat.
  String style = 'standard';
  void setStyle(String value) {
    if (style == value) return;
    style = value;
    notifyListeners();
  }

  String? error, historyError, failedQuestion;
  bool busy = false, loading = false, resetting = false, _disposed = false;
  // The collection offer appears at most once per conversation, so ignoring
  // it never brings it back on the next answer.
  bool offered = false;
  int _revision = 0;
  String identity = '';
  bool get canSend => !busy && !loading && !resetting && historyError == null;
  bool _current(int revision) => !_disposed && revision == _revision;

  void _identityChanged() {
    final next = '${state.config.demo}/${state.userKey}/${state.authenticated}';
    if (identity == next) return;
    identity = next;
    ++_revision;
    messages.clear();
    error = historyError = failedQuestion = null;
    busy = resetting = loading = offered = false;
    notifyListeners();
    unawaited(restore());
  }

  Future<void> restore() async {
    if (state.config.demo ||
        !state.authenticated ||
        busy ||
        resetting ||
        loading) {
      return;
    }
    final revision = ++_revision;
    loading = true;
    historyError = null;
    notifyListeners();
    try {
      final saved = await state.api.chatMessages(art.id);
      if (!_current(revision)) return;
      messages
        ..clear()
        ..addAll(saved);
    } catch (e) {
      if (_current(revision)) historyError = ArtlogState.message(e);
    } finally {
      if (_current(revision)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> ask(String raw) async {
    final question = raw.trim();
    if (question.isEmpty || !canSend) return;
    if (question.runes.length > 500) {
      error = '질문은 500자까지 보낼 수 있어요.';
      notifyListeners();
      return;
    }
    final revision = _revision;
    // An unanswered failed question must not become successful conversation
    // context or be duplicated when it is retried.
    if (failedQuestion != null &&
        messages.isNotEmpty &&
        messages.last.role == 'user' &&
        messages.last.content == failedQuestion) {
      messages.removeLast();
    }
    final history = List<ChatTurn>.from(messages);
    messages.add(ChatTurn('user', question));
    var hasPendingAnswer = false;
    busy = true;
    error = failedQuestion = null;
    notifyListeners();

    Future<void> reveal(String text, {bool replace = false}) async {
      if (!_current(revision)) return;
      if (replace) {
        if (hasPendingAnswer) messages.removeLast();
        messages.add(ChatTurn('assistant', text));
        hasPendingAnswer = true;
        notifyListeners();
        return;
      }
      // Render each server delta once; artificial per-character waits delayed
      // final citations and rebuilt the whole chat dozens of times per second.
      final current = hasPendingAnswer ? messages.removeLast().content : '';
      messages.add(ChatTurn('assistant', current + text));
      hasPendingAnswer = true;
      notifyListeners();
    }

    try {
      final reply = state.config.demo
          ? await state.ask(art, question, history, style: style)
          : await state.api.chatStream(
              art.id,
              question,
              history,
              style: style,
              onToken: (token) => reveal(token),
              onReplace: (text) => reveal(text, replace: true),
            );
      if (!_current(revision)) return;
      if (hasPendingAnswer) messages.removeLast();
      final offer = offered ? null : reply.suggestion;
      if (offer != null) offered = true;
      messages.add(
        ChatTurn(
          'assistant',
          reply.answer,
          sources: reply.sources,
          refused: reply.refused,
          suggestion: offer,
        ),
      );
    } catch (e) {
      if (_current(revision)) {
        if (hasPendingAnswer) messages.removeLast();
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

  /// Hide the offer under an answer (after it was accepted or declined).
  void closeSuggestion(ChatTurn turn) {
    final i = messages.indexOf(turn);
    if (i < 0) return;
    messages[i] = ChatTurn(
      turn.role,
      turn.content,
      sources: turn.sources,
      refused: turn.refused,
    );
    notifyListeners();
  }

  Future<void> retry() async {
    final question = failedQuestion;
    if (question != null) await ask(question);
  }

  Future<void> reset() async {
    if (!canSend) return;
    final revision = _revision;
    resetting = true;
    notifyListeners();
    try {
      if (!state.config.demo && state.authenticated) {
        await state.api.resetChat(art.id);
      }
      if (!_current(revision)) return;
      messages.clear();
      error = historyError = failedQuestion = null;
    } finally {
      if (_current(revision)) {
        resetting = false;
        notifyListeners();
      }
    }
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
