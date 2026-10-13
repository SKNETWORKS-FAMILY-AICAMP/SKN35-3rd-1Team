import '../models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../state.dart';
import '../member_profile.dart';
import '../mypage.dart';
import '../diary.dart';
import '../ui/design.dart';
import '../ui/profile_preferences.dart';
import '../ui/collection_workspace.dart';
import '../ui/diary_feed.dart';
import '../ui/diary_editor.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String tab = 'posts';
  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (!s.authenticated) {
      return PageWidth(
        vertical: 40,
        child: EmptyView(
          '나의 취향을 모아두는 공간이에요.',
          action: ArtButton('로그인하고 시작하기', onTap: () => ensureLogin(context)),
        ),
      );
    }
    final nickname = s.memberProfile?.nickname;
    final name = nickname != null && nickname.isNotEmpty ? nickname : '나의 프로필';
    final profile = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: compact(context) ? 28 : 40,
          backgroundColor: soft,
          child: Text(
            nickname?.isNotEmpty == true ? nickname!.characters.first : 'D',
            style: english(compact(context) ? 30 : 42),
          ),
        ),
        SizedBox(width: compact(context) ? 18 : 28),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: serif(compact(context) ? 27 : 34)),
              const SizedBox(height: 8),
              Text('좋아하는 그림으로 나를 소개합니다.', style: sans(13, color: muted)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  Text(
                    '좋아요 ${s.likes.length}',
                    style: sans(13, weight: FontWeight.w600),
                  ),
                  Text(
                    '관심 작가 ${s.follows.length}',
                    style: sans(13, weight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    return PageWidth(
      vertical: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                profile,
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.go('/settings'),
                      icon: const Icon(Icons.tune, size: 17),
                      label: const Text('감상 설정'),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go('/library'),
                      icon: const Icon(Icons.book_outlined, size: 17),
                      label: const Text('개인 기록은 내 서재에서'),
                    ),
                    if (s.loginRequired)
                      TextButton(
                        onPressed: () => logoutUser(context),
                        child: const Text('로그아웃'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final t in [
                  ('posts', '공개 감상'),
                  ('collections', '내 컬렉션'),
                  ('likes', '좋아요한 그림'),
                  ('follows', '관심 작가'),
                  ('activity', '활동 기록'),
                ])
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
            key: ValueKey('${s.userKey}/${s.authenticated}/$tab'),
            child: switch (tab) {
              'posts' => Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: const _MyRecords(critiques: true),
                ),
              ),
              'collections' => const CollectionWorkspace(),
              'likes' =>
                s.likedWorks.isEmpty
                    ? EmptyView(
                        '좋아하는 그림을 모아보세요.',
                        action: ArtButton(
                          '그림 발견하기',
                          onTap: () => context.go('/gallery'),
                        ),
                      )
                    : _LikedGallery(
                        key: ValueKey(s.likes.join(',')),
                        works: s.likedWorks,
                      ),
              'follows' =>
                s.followedArtists.isEmpty
                    ? EmptyView(
                        '관심 있는 작가를 찾아보세요.',
                        action: ArtButton(
                          '작가 둘러보기',
                          onTap: () => context.go('/artists'),
                        ),
                      )
                    : Column(
                        children: [
                          for (final a in s.followedArtists)
                            ListTile(
                              leading: SizedBox(
                                width: 46,
                                height: 52,
                                child: ArtImage(s.representativeImage(a)),
                              ),
                              title: Text(a.name, style: sans(14)),
                              subtitle: Text(
                                a.english,
                                style: english(17, color: muted),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                size: 18,
                              ),
                              onTap: () => context.go('/artist/${a.id}'),
                            ),
                        ],
                      ),
              _ => const _MyRecords(critiques: false),
            },
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => PageWidth(
    vertical: 36,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/mypage'),
          icon: const Icon(Icons.arrow_back, size: 17),
          label: const Text('마이페이지'),
        ),
        const SizedBox(height: 20),
        if (ArtlogScope.of(context).authenticated)
          const _ProfileSettings()
        else
          EmptyView(
            '로그인 후 감상 설정을 관리할 수 있어요.',
            action: ArtButton('로그인', onTap: () => ensureLogin(context)),
          ),
      ],
    ),
  );
}

class _ProfileSettings extends StatefulWidget {
  const _ProfileSettings();
  @override
  State<_ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<_ProfileSettings> {
  MemberProfile? draft;
  bool busy = false;
  String? error;
  int formRevision = 0;
  Future<void> save() async {
    final s = ArtlogScope.of(context),
        identity = ArtlogScope.of(context).userKey;
    final p = draft ?? s.memberProfile ?? const MemberProfile();
    if (p.birthDate != null) {
      final d = DateTime.tryParse(p.birthDate!);
      if (d == null ||
          dateKey(d) != p.birthDate ||
          d.year < 1900 ||
          p.birthDate!.compareTo(seoulDate()) > 0) {
        setState(() => error = '생년월일을 YYYY-MM-DD로 확인해 주세요.');
        return;
      }
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await s.saveMemberProfile(p);
      if (mounted && identity == s.userKey) {
        setState(() => draft = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('감상 설정을 저장했어요.')));
      }
    } catch (e) {
      if (mounted) setState(() => error = ArtlogState.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (!s.config.demo && !s.profileLoaded) {
      return EmptyView(
        s.profileError ?? '설정을 불러오고 있어요.',
        action: s.profileError == null
            ? null
            : ArtButton('다시 불러오기', onTap: s.loadProfile),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SurfacePanel(
          padding: EdgeInsets.all(compact(context) ? 18 : 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('나에게 맞는 감상', style: serif(25)),
              const SizedBox(height: 10),
              Text(
                s.config.demo
                    ? '미리보기 설정은 이 브라우저에 저장돼요.'
                    : '생년월일은 비공개이며 AI에 전달하지 않아요. 이야기 순서와 말투는 맞춤 안내에 사용해요.',
                style: sans(12, color: muted),
              ),
              const SizedBox(height: 28),
              ProfilePreferences(
                key: ValueKey(formRevision),
                initial: s.memberProfile ?? const MemberProfile(),
                enabled: !busy,
                onChanged: (p) => draft = p,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    error!,
                    style: sans(12, color: Colors.red.shade800),
                  ),
                ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ArtButton(
                    busy ? '저장 중…' : '설정 저장',
                    onTap: busy ? null : save,
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            draft = null;
                            error = null;
                            formRevision++;
                          }),
                    child: const Text('변경 취소'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyRecords extends StatefulWidget {
  const _MyRecords({required this.critiques});
  final bool critiques;
  @override
  State<_MyRecords> createState() => _MyRecordsState();
}

class _MyRecordsState extends State<_MyRecords> {
  List<DiaryEntry> entries = [];
  List<MemberActivity> activities = [];
  String? cursor, error;
  bool loading = false, more = true, started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  Future<void> load({bool reset = false}) async {
    if (loading) return;
    final s = ArtlogScope.of(context),
        identity = ArtlogScope.of(context).userKey;
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        entries = [];
        activities = [];
        cursor = null;
        more = true;
      }
    });
    try {
      if (widget.critiques) {
        final p = await s.critiques(cursor: cursor);
        if (!mounted || s.userKey != identity) return;
        setState(() {
          entries.addAll(p.entries);
          cursor = p.cursor;
          more = cursor != null;
        });
      } else {
        final p = await s.activity(offset: activities.length);
        if (!mounted || s.userKey != identity) return;
        setState(() {
          activities.addAll(p);
          more = p.length == 20;
        });
      }
    } catch (e) {
      if (mounted && s.userKey == identity) {
        setState(() => error = ArtlogState.message(e));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              widget.critiques ? '공개한 감상' : '활동 기록',
              style: serif(24),
            ),
          ),
          IconButton(
            tooltip: '기록 새로고침',
            onPressed: loading ? null : () => load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        widget.critiques
            ? '피드에 공개한 글을 모았어요. 비공개 글은 내 서재에서 확인하세요.'
            : '최근 활동부터 보여드려요. 감상 기록을 눌러 그날의 다이어리를 열어 보세요.',
        style: sans(12, color: muted),
      ),
      const SizedBox(height: 22),
      if (!loading && error == null && entries.isEmpty && activities.isEmpty)
        EmptyView(
          widget.critiques
              ? '아직 남긴 글이 없어요. 오늘의 감상을 기록해 보세요.'
              : '아직 활동 기록이 없어요.',
          action: ArtButton(
            widget.critiques ? '감상·비평 쓰기' : '작품 둘러보기',
            onTap: () => widget.critiques
                ? showDiaryComposer(context)
                : context.go('/gallery'),
          ),
        ),
      if (widget.critiques &&
          !loading &&
          entries.isNotEmpty &&
          entries.every((e) => !e.isPublic))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Text(
            '공개한 감상이 없어요. 비공개 글은 내 서재에 보관되어 있어요.',
            style: sans(13, color: muted),
          ),
        ),
      for (final e in entries.where((e) => e.isPublic))
        DiaryPostCard(key: ValueKey(e.id), entry: e),
      for (final a in activities)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SurfacePanel(
            radius: 22,
            padding: const EdgeInsets.all(8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: green.withValues(alpha: .08),
                child: Icon(
                  switch (a.kind) {
                    'like' => Icons.favorite_border,
                    'diary' => Icons.edit_note,
                    'collection' => Icons.collections_bookmark_outlined,
                    _ => Icons.visibility_outlined,
                  },
                  color: green,
                  size: 20,
                ),
              ),
              title: Text(a.title, style: sans(13)),
              subtitle: Text(
                '${a.displayDate} · ${switch (a.kind) {
                  'like' => '좋아요',
                  'diary' => '감상·비평',
                  'collection' => '컬렉션',
                  _ => '작품 감상',
                }}',
                style: sans(11, color: muted),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 12),
              onTap: () => context.go(
                a.date != null
                    ? '/library?date=${a.date}'
                    : a.artworkId != null
                    ? '/artwork/${a.artworkId}'
                    : '/mypage',
              ),
            ),
          ),
        ),
      if (error != null)
        EmptyView(error!, action: ArtButton('다시 시도', onTap: load)),
      if (loading)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (more &&
          !loading &&
          error == null &&
          (entries.isNotEmpty || activities.isNotEmpty))
        Center(child: ArtButton('기록 더 보기', outline: true, onTap: load)),
    ],
  );
}

class _LikedGallery extends StatefulWidget {
  const _LikedGallery({super.key, required this.works});
  final List<Artwork> works;
  @override
  State<_LikedGallery> createState() => _LikedGalleryState();
}

class _LikedGalleryState extends State<_LikedGallery> {
  int visible = 12;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ArtworkGrid(widget.works.take(visible).toList()),
      if (visible < widget.works.length)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: ArtButton(
            '좋아한 그림 더 보기',
            outline: true,
            onTap: () => setState(() => visible += 12),
          ),
        ),
    ],
  );
}
