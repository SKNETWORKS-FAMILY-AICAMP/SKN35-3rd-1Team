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

class MyPage extends StatefulWidget {
  const MyPage({super.key});
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String tab = 'collections';
  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (!s.authenticated) {
      return PageWidth(
        child: EmptyView(
          '나의 취향을 모아두는 공간이에요.',
          action: ArtButton('로그인하고 시작하기', onTap: () => ensureLogin(context)),
        ),
      );
    }
    final name = s.memberProfile?.nickname;
    return PageWidth(
      vertical: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassSurface(
            tinted: true,
            padding: EdgeInsets.all(compact(context) ? 22 : 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MY GALLERY', style: english(11, color: green)),
                const SizedBox(height: 15),
                Text(
                  '${name != null && name.isNotEmpty ? name : '나'}의 작은 미술관',
                  style: serif(compact(context) ? 29 : 40),
                ),
                const SizedBox(height: 12),
                Text(
                  '좋아한 그림, 남겨둔 생각.\n나를 닮은 취향이 차곡차곡 쌓이는 곳.',
                  style: sans(13, color: muted, height: 1.7),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.favorite_border, size: 16),
                      label: Text('좋아한 그림 ${s.likes.length}점'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text('관심 작가 ${s.follows.length}명'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/library'),
                      icon: const Icon(Icons.calendar_month_outlined, size: 17),
                      label: const Text('감상 캘린더'),
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
          const SizedBox(height: 26),
          Wrap(
            spacing: 7,
            runSpacing: 8,
            children: [
              for (final t in [
                ('collections', '내 컬렉션', Icons.collections_bookmark_outlined),
                ('critiques', '내 감상·비평', Icons.edit_note),
                ('activity', '활동 기록', Icons.history),
                ('likes', '좋아요한 그림', Icons.favorite_border),
                ('settings', '설정', Icons.tune),
              ])
                GlassChoiceChip(
                  avatar: Icon(t.$3, size: 17),
                  label: Text(t.$2),
                  selected: tab == t.$1,
                  onSelected: (_) => setState(() => tab = t.$1),
                ),
            ],
          ),
          const SizedBox(height: 28),
          KeyedSubtree(
            key: ValueKey('${s.userKey}/${s.authenticated}/$tab'),
            child: switch (tab) {
              'collections' => const CollectionWorkspace(),
              'critiques' => const _MyRecords(critiques: true),
              'activity' => const _MyRecords(critiques: false),
              'likes' =>
                s.likedWorks.isEmpty
                    ? EmptyView(
                        '마음에 드는 그림에 좋아요를 눌러 보세요.',
                        action: ArtButton(
                          '그림 발견하기',
                          onTap: () => context.go('/gallery'),
                        ),
                      )
                    : _LikedGallery(
                        key: ValueKey(s.likes.join(",")),
                        works: s.likedWorks,
                      ),
              _ => const _ProfileSettings(),
            },
          ),
        ],
      ),
    );
  }
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
        child: GlassSurface(
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
              widget.critiques ? '그림 앞에서 남긴 나의 생각' : '취향이 쌓여온 순간들',
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
            ? '다이어리와 같은 기록이에요. 비공개 글은 나만 볼 수 있어요.'
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
            onTap: () => context.go(widget.critiques ? '/library' : '/gallery'),
          ),
        ),
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GlassSurface(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(e.date, style: english(12, color: muted)),
                    Chip(
                      avatar: Icon(
                        e.isPublic ? Icons.public : Icons.lock_outline,
                        size: 14,
                      ),
                      label: Text(e.isPublic ? '공개' : '나만 보기'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (e.artwork != null) Text(e.artwork!.title, style: serif(19)),
                const SizedBox(height: 8),
                Text(
                  e.content,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: sans(13, height: 1.8),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => context.go('/library?date=${e.date}'),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('다이어리에서 이어 쓰기'),
                ),
              ],
            ),
          ),
        ),
      for (final a in activities)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassSurface(
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
