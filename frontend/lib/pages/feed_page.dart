import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../diary.dart';
import '../mypage.dart';
import '../social.dart';
import '../state.dart';
import '../ui/collection_workspace.dart';
import '../ui/design.dart';
import '../ui/feed_calendar.dart';

const feedTabs = [
  ('posts', '공개 감상'),
  ('collections', '내 컬렉션'),
  ('artists', '관심 작가'),
  ('calendar', '감상 캘린더'),
];

/// 내 피드: profile header, my impressions, collections, liked artists and calendar.
class MyFeedPage extends StatefulWidget {
  const MyFeedPage({
    super.key,
    this.initialTab = 'posts',
    this.artworkId,
    this.initialDate,
  });
  final String initialTab;
  final String? artworkId, initialDate;
  @override
  State<MyFeedPage> createState() => _MyFeedPageState();
}

class _MyFeedPageState extends State<MyFeedPage> {
  late String tab = feedTabs.any((t) => t.$1 == widget.initialTab)
      ? widget.initialTab
      : 'posts';
  String? calendarDate;

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (!s.authenticated) {
      return PageWidth(
        vertical: 40,
        child: EmptyView(
          '나의 감상과 취향을 모아두는 공간이에요.',
          action: ArtButton('로그인', onTap: () => ensureLogin(context)),
        ),
      );
    }
    return PageWidth(
      vertical: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: ValueKey('header/${s.userKey}/${s.socialRevision}'),
            child: const _MyHeader(),
          ),
          const SizedBox(height: 28),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final t in feedTabs)
                  TextButton(
                    key: ValueKey('profile-tab-${t.$1}'),
                    style: editorialButtonStyle(
                      quiet: tab != t.$1,
                      tinted: tab == t.$1,
                    ),
                    onPressed: () => setState(() => tab = t.$1),
                    child: Text(
                      t.$2,
                      style: sans(
                        13,
                        color: tab == t.$1 ? ink : muted,
                        weight: tab == t.$1 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: ValueKey('${s.userKey}/$tab/$calendarDate'),
            child: switch (tab) {
              'collections' => const CollectionWorkspace(),
              'artists' => const _LikedArtists(),
              'calendar' => FeedCalendar(
                artworkId: widget.artworkId,
                initialDate: calendarDate ?? widget.initialDate,
              ),
              _ => _ImpressionList(
                onOpen: (e) => setState(() {
                  calendarDate = e.date;
                  tab = 'calendar';
                }),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Nickname, AI one-line introduction and follow counts for the signed-in member.
class _MyHeader extends StatefulWidget {
  const _MyHeader();
  @override
  State<_MyHeader> createState() => _MyHeaderState();
}

class _MyHeaderState extends State<_MyHeader> {
  Future<PublicMember>? social;
  TasteIntro? taste;
  bool generating = false;
  String? tasteError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (social != null) return;
    final s = ArtlogScope.of(context);
    social = s.mySocial();
    s.taste().then(
      (t) {
        if (mounted) setState(() => taste = t);
      },
      onError: (Object e) {
        if (mounted) setState(() => tasteError = ArtlogState.message(e));
      },
    );
  }

  Future<void> generate() async {
    if (generating) return;
    final s = ArtlogScope.of(context), identity = s.userKey;
    setState(() {
      generating = true;
      tasteError = null;
    });
    try {
      final intro = await s.taste(generate: true);
      if (mounted && s.userKey == identity) setState(() => taste = intro);
    } catch (e) {
      if (mounted && s.userKey == identity) {
        setState(() => tasteError = ArtlogState.message(e));
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    final nickname = s.memberProfile?.nickname ?? '';
    return FutureBuilder<PublicMember>(
      future: social,
      builder: (context, snapshot) {
        final member = snapshot.data;
        final name = nickname.isNotEmpty
            ? nickname
            : member?.nickname ?? '나의 피드';
        final intro = taste?.summary;
        return MemberHeader(
          name: name,
          member: member,
          intro: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 15,
                    color: green,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      intro ??
                          (s.config.demo
                              ? '공개 감상을 남기면 AI가 나를 한 줄로 소개해 드려요.'
                              : '공개 감상과 좋아요를 바탕으로 AI가 나를 한 줄로 소개해요.'),
                      key: const ValueKey('feed-ai-intro'),
                      style: sans(13, color: intro == null ? muted : ink),
                    ),
                  ),
                  if (!s.config.demo)
                    IconButton(
                      tooltip: intro == null
                          ? 'AI 한 줄 소개 만들기'
                          : 'AI 한 줄 소개 업데이트',
                      onPressed: generating ? null : generate,
                      icon: generating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              intro == null ? Icons.add : Icons.refresh,
                              size: 16,
                              color: taste?.stale == true ? green : muted,
                            ),
                    ),
                ],
              ),
              if (tasteError != null)
                Text(tasteError!, style: sans(11, color: Colors.red.shade800)),
            ],
          ),
        );
      },
    );
  }
}

/// Shared header for my feed and other members' profiles.
class MemberHeader extends StatelessWidget {
  const MemberHeader({
    super.key,
    required this.name,
    required this.member,
    required this.intro,
    this.action,
  });
  final String name;
  final PublicMember? member;
  final Widget intro;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final small = compact(context);
    final m = member;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: small ? 30 : 42,
          backgroundColor: soft,
          child: Text(
            name.isEmpty ? 'D' : name.characters.first,
            style: english(small ? 30 : 42),
          ),
        ),
        SizedBox(width: small ? 18 : 28),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(name, style: serif(small ? 26 : 32)),
                  ?action,
                ],
              ),
              const SizedBox(height: 6),
              intro,
              const SizedBox(height: 12),
              if (m != null)
                Wrap(
                  spacing: 18,
                  children: [
                    for (final followers in [false, true])
                      TextButton(
                        key: ValueKey(
                          'member-${followers ? 'followers' : 'following'}',
                        ),
                        style: editorialButtonStyle(
                          quiet: true,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed:
                            (followers ? m.followerCount : m.followingCount) ==
                                null
                            ? null
                            : () => showMemberList(
                                context,
                                m,
                                followers: followers,
                              ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: followers ? '팔로워 ' : '팔로잉 ',
                                style: sans(13, color: muted),
                              ),
                              TextSpan(
                                text:
                                    '${(followers ? m.followerCount : m.followingCount) ?? '비공개'}',
                                style: sans(13, weight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> showMemberList(
  BuildContext context,
  PublicMember member, {
  required bool followers,
}) => showDialog<void>(
  context: context,
  builder: (c) => SurfaceDialog(
    title: Text(followers ? '팔로워' : '팔로잉', style: serif(22)),
    content: SizedBox(
      width: 380,
      height: 420,
      child: FutureBuilder<List<MemberCard>>(
        future: ArtlogScope.of(
          context,
        ).memberList(member.id, followers: followers),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyView(ArtlogState.message(snapshot.error!));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return Center(
              child: Text(
                followers ? '아직 팔로워가 없어요.' : '아직 팔로우한 감상가가 없어요.',
                style: sans(13, color: muted),
              ),
            );
          }
          return ListView(
            children: [
              for (final r in rows)
                ListTile(
                  key: ValueKey('member-row-${r.id}'),
                  leading: CircleAvatar(
                    backgroundColor: soft,
                    child: Text(
                      r.nickname.isEmpty ? 'D' : r.nickname.characters.first,
                      style: sans(13, weight: FontWeight.w600),
                    ),
                  ),
                  title: Text(r.nickname, style: sans(14)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.pop(c);
                    context.go('/user/${Uri.encodeComponent(r.id)}');
                  },
                ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('닫기')),
    ],
  ),
);

/// My impressions as a list: artist, title and one line, private ones locked.
class _ImpressionList extends StatefulWidget {
  const _ImpressionList({required this.onOpen});
  final ValueChanged<DiaryEntry> onOpen;
  @override
  State<_ImpressionList> createState() => _ImpressionListState();
}

class _ImpressionListState extends State<_ImpressionList> {
  List<DiaryEntry> entries = [];
  String? cursor, error;
  bool loading = false, started = false, more = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  Future<void> load({bool reset = false}) async {
    if (loading) return;
    final s = ArtlogScope.of(context), identity = s.userKey;
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        entries = [];
        cursor = null;
        more = true;
      }
    });
    try {
      final page = await s.critiques(cursor: cursor);
      if (!mounted || s.userKey != identity) return;
      setState(() {
        entries.addAll(page.entries);
        cursor = page.cursor;
        more = cursor != null;
      });
    } catch (e) {
      if (mounted && s.userKey == identity) {
        setState(() => error = ArtlogState.message(e));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ImpressionRows(
    entries: entries,
    loading: loading,
    error: error,
    hasMore: more,
    onMore: load,
    onRefresh: () => load(reset: true),
    onOpen: widget.onOpen,
    emptyMessage: '아직 남긴 감상이 없어요. 작품을 보고 첫 감상을 남겨 보세요.',
  );
}

/// List rows without images. Used on my feed and other members' profiles.
class ImpressionRows extends StatelessWidget {
  const ImpressionRows({
    super.key,
    required this.entries,
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.onMore,
    required this.onRefresh,
    required this.emptyMessage,
    this.onOpen,
  });
  final List<DiaryEntry> entries;
  final bool loading, hasMore;
  final String? error;
  final VoidCallback onMore, onRefresh;
  final ValueChanged<DiaryEntry>? onOpen;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('감상 ${entries.length}', style: serif(22))),
            IconButton(
              tooltip: '감상 새로고침',
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!loading && error == null && entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(emptyMessage, style: sans(13, color: muted)),
          ),
        for (final e in entries)
          Container(
            key: ValueKey('impression-row-${e.id}'),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: line)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              onTap: onOpen == null
                  ? (e.artwork == null
                        ? null
                        : () => context.go('/artwork/${e.artwork!.id}'))
                  : () => onOpen!(e),
              title: Text(
                e.artwork == null
                    ? '작품 없이 남긴 감상'
                    : '${e.artwork!.artistName.isEmpty ? s.artistName(e.artwork!) : e.artwork!.artistName} · ${e.artwork!.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sans(12, color: muted),
              ),
              subtitle: Text(
                e.content.replaceAll('\n', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sans(14, color: ink),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!e.isPublic)
                    const Tooltip(
                      message: '비공개 감상',
                      child: Icon(Icons.lock_outline, size: 16, color: muted),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    e.date.replaceAll('-', '.'),
                    style: sans(11, color: muted),
                  ),
                ],
              ),
            ),
          ),
        if (error != null)
          EmptyView(error!, action: ArtButton('다시 시도', onTap: onMore)),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (hasMore && !loading && error == null && entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Center(
              child: ArtButton('감상 더 보기', outline: true, onTap: onMore),
            ),
          ),
      ],
    );
  }
}

class _LikedArtists extends StatelessWidget {
  const _LikedArtists();
  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    final artists = s.followedArtists;
    if (artists.isEmpty) {
      return EmptyView(
        '마음에 드는 작가에게 좋아요를 눌러 보세요.',
        action: ArtButton(
          '작가 둘러보기',
          onTap: () => context.go('/artworks?view=artists'),
        ),
      );
    }
    return Column(
      children: [
        for (final a in artists)
          ListTile(
            leading: SizedBox(
              width: 46,
              height: 52,
              child: ArtImage(s.representativeImage(a)),
            ),
            title: Text(a.name, style: sans(14)),
            subtitle: Text(a.english, style: english(17, color: muted)),
            trailing: LikeButton(
              compactIcon: true,
              liked: true,
              subject: a.name,
              onPressed: s.pendingFollows.contains(a.id)
                  ? null
                  : () => likeArtist(context, a),
            ),
            onTap: () => context.go('/artist/${a.id}'),
          ),
      ],
    );
  }
}

/// Liked artworks shown as the default collection.
class LikedCollectionPage extends StatelessWidget {
  const LikedCollectionPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    return PageWidth(
      vertical: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/library?tab=collections'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('내 컬렉션'),
          ),
          const SizedBox(height: 18),
          const Eyebrow('DEFAULT COLLECTION'),
          const SizedBox(height: 8),
          Text('좋아요한 작품', style: serif(32)),
          const SizedBox(height: 6),
          Text('작품에 좋아요를 누르면 이곳에 자동으로 담겨요.', style: sans(13, color: muted)),
          const SizedBox(height: 28),
          if (!s.authenticated)
            EmptyView(
              '로그인 후 볼 수 있어요.',
              action: ArtButton('로그인', onTap: () => ensureLogin(context)),
            )
          else if (s.likedWorks.isEmpty)
            EmptyView(
              '아직 좋아요한 작품이 없어요.',
              action: ArtButton(
                '작품 둘러보기',
                onTap: () => context.go('/artworks'),
              ),
            )
          else
            ArtworkGrid(s.likedWorks),
        ],
      ),
    );
  }
}

/// Another member's public profile.
class MemberPage extends StatefulWidget {
  const MemberPage({super.key, required this.id});
  final String id;
  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  Future<PublicMember>? future;
  PublicMember? current;
  List<DiaryEntry> entries = [];
  String? cursor, error, identity;
  bool loading = false, more = true, following = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ArtlogScope.of(context);
    final next = '${s.userKey}/${s.authenticated}/${s.socialRevision}';
    if (identity == next) return;
    final first = identity == null;
    identity = next;
    future = s.member(widget.id).then((m) => current = m);
    if (first) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  Future<void> load({bool reset = false}) async {
    if (loading) return;
    final s = ArtlogScope.of(context);
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        entries = [];
        cursor = null;
      }
    });
    try {
      final page = await s.memberDiary(widget.id, cursor: cursor);
      if (!mounted) return;
      setState(() {
        entries.addAll(page.entries);
        cursor = page.nextCursor;
        more = cursor != null;
      });
    } catch (e) {
      if (mounted) setState(() => error = ArtlogState.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggleFollow(PublicMember m) async {
    if (!await ensureLogin(context) || !mounted) return;
    setState(() => following = true);
    try {
      await ArtlogScope.of(context).followMember(m.id, !m.isFollowing);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => following = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageWidth(
    vertical: 40,
    child: FutureBuilder<PublicMember>(
      future: future,
      builder: (context, snapshot) {
        final m = snapshot.data ?? current;
        if (snapshot.hasError && m == null) {
          return EmptyView(
            ArtlogState.message(snapshot.error!),
            action: ArtButton('감상 피드로', onTap: () => context.go('/community')),
          );
        }
        if (m == null) {
          return const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MemberHeader(
              name: m.nickname,
              member: m,
              intro: Text(
                m.intro ?? '아직 AI 한 줄 소개가 없어요.',
                key: const ValueKey('member-intro'),
                style: sans(13, color: m.intro == null ? muted : ink),
              ),
              action: m.isMe
                  ? OutlinedButton(
                      onPressed: () => context.go('/library'),
                      child: const Text('내 피드로'),
                    )
                  : ArtButton(
                      m.isFollowing ? '팔로잉' : '팔로우',
                      key: const ValueKey('member-follow'),
                      outline: m.isFollowing,
                      icon: m.isFollowing ? Icons.check : Icons.person_add_alt,
                      onTap: following ? null : () => toggleFollow(m),
                    ),
            ),
            const SizedBox(height: 28),
            const Divider(height: 1),
            const SizedBox(height: 20),
            ImpressionRows(
              entries: entries,
              loading: loading,
              error: error,
              hasMore: more,
              onMore: load,
              onRefresh: () => load(reset: true),
              emptyMessage: '아직 공개한 감상이 없어요.',
            ),
          ],
        );
      },
    ),
  );
}
