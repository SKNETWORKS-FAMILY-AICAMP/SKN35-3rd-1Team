import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../state.dart';
import '../ui/design.dart';
import '../ui/saved_chats.dart';
import '../ui/member_profile_dialog.dart';
import '../diary.dart';
import '../ui/diary_editor.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, this.artworkId, this.initialDate});
  final String? artworkId, initialDate;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String get initialDay {
    final d = DateTime.tryParse(widget.initialDate ?? '');
    return d != null &&
            dateKey(d) == widget.initialDate &&
            d.year >= 1900 &&
            d.year < 9999
        ? widget.initialDate!
        : seoulDate();
  }

  late DateTime month = DateTime.parse('${initialDay.substring(0, 7)}-01');
  late String selected = initialDay;
  String tab = 'calendar';
  String? identity, calendarError, dayError, diaryError;
  Map<String, DiaryEntry> diaryEntries = {};
  GlobalKey<DiaryEditorState> editorKey = GlobalKey<DiaryEditorState>();
  bool sample = false, loading = false, dayLoading = false;
  int monthRevision = 0, dayRevision = 0;
  Map<String, CalendarDay> calendarDays = {};
  Map<String, int> get counts => {
    for (final day in calendarDays.values) day.date: day.artworkCount,
  };
  List<Artwork> dayWorks = [];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ArtlogScope.of(context),
        key = '${s.config.demo}/${s.userKey}/${s.authenticated}';
    if (identity != key) {
      identity = key;
      ++monthRevision;
      ++dayRevision;
      calendarDays = {};
      dayWorks = [];
      calendarError = dayError = null;
      loading = dayLoading = false;
      diaryEntries = {};
      diaryError = null;
      editorKey = GlobalKey<DiaryEditorState>();
      sample = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identity == key) loadMonth();
      });
    }
  }

  Map<String, List<String>> demoRecords(ArtlogState s) {
    if (!sample) return s.views;
    if (s.artworks.isEmpty) return {};
    final records = <String, List<String>>{};
    for (final d in [2, 4, 7, 9, 12, 15, 18, 21, 24, 27]) {
      final date = dateKey(DateTime(month.year, month.month, d));
      records[date] = [s.artworks[d % s.artworks.length].id];
    }
    return records;
  }

  Future<void> loadMonth() async {
    final s = ArtlogScope.of(context), revision = ++monthRevision;
    final currentIdentity = identity;
    ++dayRevision;
    if (!s.authenticated) {
      setState(() {
        calendarDays = {};
        dayWorks = [];
        calendarError = null;
        dayLoading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      calendarError = null;
      calendarDays = {};
      dayWorks = [];
      dayLoading = false;
    });
    try {
      String? nextDiaryError;
      final diaryRequest = s
          .diaryMonth(dateKey(month).substring(0, 7))
          .catchError((Object e) {
            nextDiaryError = ArtlogState.message(e);
            return <DiaryEntry>[];
          });
      final result = s.config.demo
          ? demoRecords(s).map(
              (k, v) => MapEntry(
                k,
                CalendarDay(
                  date: k,
                  artworkCount: v.length,
                  totalViews: v.length,
                ),
              ),
            )
          : {
              for (final day in await s.api.calendarDays(
                dateKey(month).substring(0, 7),
              ))
                day.date: day,
            };
      if (!mounted ||
          revision != monthRevision ||
          identity != currentIdentity) {
        return;
      }
      final entries = await diaryRequest;
      if (!mounted ||
          revision != monthRevision ||
          identity != currentIdentity) {
        return;
      }
      setState(() {
        calendarDays = result;
        diaryEntries = {for (final e in entries) e.date: e};
        diaryError = nextDiaryError;
      });
      await loadDay(selected);
    } catch (e) {
      if (mounted && revision == monthRevision) {
        setState(() => calendarError = ArtlogState.message(e));
      }
    } finally {
      if (mounted && revision == monthRevision) setState(() => loading = false);
    }
  }

  Future<void> loadDay(String date) async {
    if (date != selected &&
        !(await editorKey.currentState?.confirmDiscard() ?? true)) {
      return;
    }
    if (!mounted) return;
    final s = ArtlogScope.of(context), revision = ++dayRevision;
    final currentIdentity = identity;
    if (!s.authenticated) return;
    setState(() {
      selected = date;
      dayLoading = true;
      dayError = null;
      editorKey = GlobalKey<DiaryEditorState>();
      dayWorks = [];
    });
    try {
      final result = s.config.demo
          ? s.artworks
                .where((a) => (demoRecords(s)[date] ?? []).contains(a.id))
                .toList()
          : await s.api.day(date);
      if (mounted && revision == dayRevision && identity == currentIdentity) {
        setState(() => dayWorks = result);
      }
    } catch (e) {
      if (mounted && revision == dayRevision) {
        setState(() => dayError = ArtlogState.message(e));
      }
    } finally {
      if (mounted && revision == dayRevision) {
        setState(() => dayLoading = false);
      }
    }
  }

  Future<void> changeMonth(int delta) async {
    if (!(await editorKey.currentState?.confirmDiscard() ?? true) || !mounted) {
      return;
    }
    setState(() {
      month = DateTime(month.year, month.month + delta);
      selected = dateKey(month);
    });
    loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    final monthPrefix = dateKey(month).substring(0, 7),
        visited = counts.entries
            .where((e) => e.key.startsWith(monthPrefix) && e.value > 0)
            .length;
    final demoUnique = s.config.demo
        ? demoRecords(s).entries
              .where((e) => e.key.startsWith(monthPrefix))
              .expand((e) => e.value)
              .toSet()
              .length
        : null;
    final totalViews = calendarDays.values
        .where((day) => day.date.startsWith(monthPrefix))
        .fold<int>(0, (total, day) => total + day.totalViews);
    return PageWidth(
      vertical: 42,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('MY LITTLE MUSEUM'),
                    const SizedBox(height: 15),
                    Text(
                      '마음에 남은 그림들.',
                      style: serif(compact(context) ? 30 : 39),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '한 점씩 쌓이는 감상, 조금씩 넓어지는 나의 세계.',
                      style: sans(13, color: muted),
                    ),
                  ],
                ),
              ),
              if (!compact(context))
                Container(
                  width: 65,
                  height: 85,
                  decoration: glassDecoration(radius: 22, tinted: true),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: green,
                    size: 30,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 30),
          if (s.loginRequired && s.authenticated)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(s.email, style: sans(11, color: muted)),
                  if (s.config.firebaseAuth)
                    TextButton(
                      onPressed: () => showMemberProfile(context, s),
                      child: const Text('감상 프로필'),
                    ),
                  TextButton(
                    onPressed: () => logoutUser(context),
                    child: const Text('로그아웃'),
                  ),
                ],
              ),
            ),
          if (!s.authenticated)
            EmptyView(
              '감상의 순간을 모아보세요.',
              description: '로그인하면 마음에 든 작품과 감상 기록을 볼 수 있어요.',
              action: ArtButton(
                '로그인',
                onTap: () async {
                  await ensureLogin(context);
                  if (mounted) loadMonth();
                },
              ),
            )
          else ...[
            if (s.libraryError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.libraryError!, style: sans(12, color: Colors.brown)),
                    TextButton(
                      onPressed: s.reloadLibrary,
                      child: const Text('서재 다시 불러오기'),
                    ),
                  ],
                ),
              ),
            Container(
              padding: EdgeInsets.all(compact(context) ? 18 : 26),
              decoration: glassDecoration(),
              child: Row(
                children: [
                  for (final stat in [
                    (
                      demoUnique?.toString() ?? visited.toString(),
                      demoUnique == null ? '이번 달 감상한 날' : '이번 달 감상한 작품',
                      demoUnique == null ? '일' : '점',
                    ),
                    (s.likes.length.toString(), '마음에 담은 작품', '점'),
                    (s.follows.length.toString(), '팔로우한 작가', '명'),
                  ])
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.$2,
                            style: sans(
                              compact(context) ? 9 : 11,
                              color: muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: stat.$1,
                                  style: english(34, color: green),
                                ),
                                TextSpan(
                                  text: ' ${stat.$3}',
                                  style: sans(10, color: muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                for (final t in [
                  ('calendar', '감상 캘린더', Icons.calendar_today_outlined),
                  ('diary', '다이어리', Icons.menu_book_outlined),
                  ('likes', '좋아요한 작품', Icons.favorite_border),
                  ('follows', '팔로우한 작가', Icons.people_outline),
                  ('chats', '대화 내역', Icons.forum_outlined),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: TextButton(
                        style: crystalButtonStyle(
                          dark: tab == t.$1,
                          quiet: tab != t.$1,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () async {
                          if (!(await editorKey.currentState
                                      ?.confirmDiscard() ??
                                  true) ||
                              !mounted) {
                            return;
                          }
                          setState(() => tab = t.$1);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!compact(context)) ...[
                              Icon(
                                t.$3,
                                size: 16,
                                color: tab == t.$1 ? Colors.white : muted,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                compact(context)
                                    ? switch (t.$1) {
                                        'calendar' => '캘린더',
                                        'likes' => '좋아요',
                                        'follows' => '팔로우',
                                        _ => t.$2,
                                      }
                                    : t.$2,
                                style: sans(
                                  compact(context) ? 10 : 12,
                                  color: tab == t.$1 ? Colors.white : muted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (tab == 'calendar' || tab == 'diary') ...[
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 15,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${month.year}년 ${month.month}월', style: serif(26)),
                      Text(
                        '$visited일의 감상 · 총 $totalViews회 감상',
                        style: sans(11, color: muted),
                      ),
                      Text(
                        '감상평 ${diaryEntries.length}편',
                        style: sans(11, color: muted),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.config.demo)
                        TextButton(
                          onPressed: () {
                            setState(() => sample = !sample);
                            loadMonth();
                          },
                          child: Text(
                            sample ? '예시 기록 끄기' : '예시 기록 보기',
                            style: sans(10, color: green),
                          ),
                        ),
                      TextButton(
                        onPressed: () async {
                          if (!(await editorKey.currentState
                                      ?.confirmDiscard() ??
                                  true) ||
                              !mounted) {
                            return;
                          }
                          setState(() {
                            selected = seoulDate();
                            month = DateTime.parse(
                              '${selected.substring(0, 7)}-01',
                            );
                          });
                          loadMonth();
                        },
                        child: const Text('오늘'),
                      ),
                      IconButton(
                        tooltip: '이전 달',
                        onPressed: () => changeMonth(-1),
                        icon: const Icon(Icons.chevron_left, size: 20),
                      ),
                      IconButton(
                        tooltip: '다음 달',
                        onPressed: () => changeMonth(1),
                        icon: const Icon(Icons.chevron_right, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (sample)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Text(
                    '예시 캘린더를 보고 있어요. 실제 감상 기록과 구분되어 표시됩니다.',
                    style: sans(11, color: muted),
                  ),
                ),
              if (loading)
                const LinearProgressIndicator(color: sage, minHeight: 2),
              if (calendarError != null)
                EmptyView(
                  calendarError!,
                  action: ArtButton('다시 불러오기', onTap: loadMonth),
                )
              else if (tab == 'diary')
                _diaryList(s)
              else
                LayoutBuilder(
                  builder: (context, c) {
                    final calendar = _calendar(s);
                    final journal = _journal(s);
                    return c.maxWidth > 920
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: calendar),
                              const SizedBox(width: 28),
                              Expanded(flex: 3, child: journal),
                            ],
                          )
                        : Column(
                            children: [
                              calendar,
                              const SizedBox(height: 24),
                              journal,
                            ],
                          );
                  },
                ),
            ],
            if (tab == 'chats')
              const Padding(
                padding: EdgeInsets.only(top: 25),
                child: SavedChats(),
              ),
            if (tab == 'likes')
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: s.likes.isEmpty
                    ? EmptyView(
                        '어떤 그림을 담아볼까요?',
                        description: '작품의 하트를 누르면 이곳에 모아둘게요.',
                        action: ArtButton(
                          '마음에 드는 그림 찾기',
                          onTap: () => context.go('/gallery'),
                        ),
                      )
                    : ArtworkGrid(s.likedWorks),
              ),
            if (tab == 'follows')
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: s.follows.isEmpty
                    ? EmptyView(
                        '다음 이야기가 궁금한 작가를 만나보세요.',
                        action: ArtButton(
                          '작가 만나러 가기',
                          onTap: () => context.go('/artists'),
                        ),
                      )
                    : Wrap(
                        spacing: 25,
                        runSpacing: 20,
                        children: s.followedArtists
                            .map(
                              (a) => SizedBox(
                                width: compact(context) ? double.infinity : 280,
                                child: ListTile(
                                  leading: SizedBox(
                                    width: 45,
                                    height: 55,
                                    child: ArtImage(s.representativeImage(a)),
                                  ),
                                  title: Text(a.name, style: sans(13)),
                                  subtitle: Text(
                                    a.english,
                                    style: english(16, color: muted),
                                  ),
                                  trailing: const Icon(
                                    Icons.north_east,
                                    size: 17,
                                  ),
                                  onTap: () => context.go('/artist/${a.id}'),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _calendar(ArtlogState s) => LayoutBuilder(
    builder: (context, c) {
      final days = DateTime(month.year, month.month + 1, 0).day,
          start = month.weekday % 7;
      final width = (c.maxWidth - 12) / 7,
          height = compact(context) ? 78.0 : 112.0;
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: glassDecoration(radius: 28),
        child: Column(
          children: [
            Row(
              children: [
                for (final day in [
                  'SUN',
                  'MON',
                  'TUE',
                  'WED',
                  'THU',
                  'FRI',
                  'SAT',
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 9,
                          color: muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Wrap(
              children: [
                for (
                  var index = 0;
                  index < ((start + days) / 7).ceil() * 7;
                  index++
                )
                  Builder(
                    builder: (context) {
                      final d = index - start + 1;
                      if (d < 1 || d > days) {
                        return SizedBox(
                          width: (c.maxWidth - 14) / 7,
                          height: height,
                        );
                      }
                      final date = dateKey(
                            DateTime(month.year, month.month, d),
                          ),
                          count = counts[date] ?? 0;
                      final ids = s.config.demo
                          ? demoRecords(s)[date] ?? []
                          : <String>[];
                      final art = ids.isEmpty ? null : s.workFor(ids.first);
                      return Semantics(
                        label:
                            '${month.month}월 $d일, $count점 감상${diaryEntries.containsKey(date) ? ', 감상평 있음' : ''}',
                        button: true,
                        selected: selected == date,
                        child: InkWell(
                          onTap: () => loadDay(date),
                          child: Container(
                            width: (c.maxWidth - 14) / 7 - 4,
                            height: height - 4,
                            margin: const EdgeInsets.all(2),
                            padding: EdgeInsets.all(width < 60 ? 4 : 8),
                            decoration:
                                glassDecoration(
                                  radius: 14,
                                  tinted: selected == date,
                                ).copyWith(
                                  border: Border.all(
                                    color: selected == date
                                        ? green.withValues(alpha: .65)
                                        : Colors.white,
                                    width: selected == date ? 1.3 : 1,
                                  ),
                                ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: date == seoulDate()
                                        ? green
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$d',
                                    style: sans(
                                      11,
                                      color: date == seoulDate()
                                          ? Colors.white
                                          : muted,
                                    ),
                                  ),
                                ),
                                if (diaryEntries[date] case final entry?)
                                  Icon(
                                    entry.isPublic
                                        ? Icons.public
                                        : Icons.lock_outline,
                                    size: 13,
                                    color: green,
                                  ),
                                if (art != null)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: ArtImage(
                                        art.image,
                                        label: art.title,
                                        width: double.infinity,
                                      ),
                                    ),
                                  )
                                else if (count > 0)
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        '$count점',
                                        style: sans(10, color: green),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
  void showDayWorks(ArtlogState s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (c) => SizedBox(
        key: const ValueKey('day-works-sheet'),
        height: MediaQuery.sizeOf(c).height * .75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text('이날 감상한 ${dayWorks.length}점', style: serif(23)),
                  ),
                  IconButton(
                    tooltip: '감상 작품 목록 닫기',
                    onPressed: () => Navigator.pop(c),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: dayWorks.length,
                itemBuilder: (c, i) {
                  final a = dayWorks[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ArtImage(a.image, width: 48, height: 56),
                    ),
                    title: Text(a.title, style: sans(13)),
                    subtitle: Text(
                      s.artistName(a),
                      style: sans(11, color: muted),
                    ),
                    trailing: const Icon(Icons.north_east, size: 18),
                    onTap: () {
                      Navigator.pop(c);
                      context.go('/artwork/${a.id}');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _journal(ArtlogState s) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(23),
    decoration: glassDecoration(tinted: true),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('A DAY WITH ART'),
        const SizedBox(height: 12),
        Text(
          '${int.parse(selected.substring(5, 7))}월 ${int.parse(selected.substring(8))}일의 그림',
          style: serif(23),
        ),
        const SizedBox(height: 14),
        if (dayLoading)
          const LinearProgressIndicator(color: sage, minHeight: 2)
        else if (dayError != null) ...[
          Text(dayError!, style: sans(12)),
          TextButton(
            onPressed: () => loadDay(selected),
            child: const Text('다시 불러오기'),
          ),
        ] else if (dayWorks.isEmpty) ...[
          const SizedBox(height: 20),
          const Icon(Icons.menu_book_outlined, color: sage),
          const SizedBox(height: 14),
          Text(
            '아직 꺼내볼 그림이 없어요.\n오늘의 한 점을 만나러 가볼까요?',
            style: sans(12, color: muted),
          ),
          TextButton(
            onPressed: () => context.go('/gallery'),
            child: const Text('작품 발견하기 ↗'),
          ),
        ] else ...[
          for (final a in dayWorks.take(3))
            Padding(
              key: ValueKey('journal-preview-${a.id}'),
              padding: const EdgeInsets.only(bottom: 13),
              child: InkWell(
                onTap: () => context.go('/artwork/${a.id}'),
                child: Row(
                  children: [
                    ArtImage(a.image, width: 52, height: 65),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title, style: sans(12)),
                          Text(s.artistName(a), style: sans(10, color: muted)),
                          if (!s.config.demo && a.viewCount > 0)
                            Text(
                              '이날 ${a.viewCount}회 감상',
                              style: sans(10, color: muted),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.north_east, size: 15),
                  ],
                ),
              ),
            ),
        ],
        if (dayWorks.length > 3)
          TextButton.icon(
            onPressed: () => showDayWorks(s),
            icon: const Icon(Icons.grid_view_outlined, size: 16),
            label: Text('전체 ${dayWorks.length}점 보기'),
          ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        if (sample)
          Text(
            '예시 기록을 보고 있어요. 실제 날짜를 선택해 감상평을 작성해 주세요.',
            style: sans(11, color: muted),
          )
        else if (loading || dayLoading)
          Text('다이어리를 불러오고 있어요.', style: sans(11, color: muted))
        else if (diaryError != null)
          EmptyView(
            '다이어리를 불러오지 못했어요.',
            description: diaryError!,
            action: ArtButton('다이어리 다시 불러오기', onTap: loadMonth),
          )
        else
          DiaryEditor(
            key: editorKey,
            date: selected,
            entry: diaryEntries[selected],
            works: [...dayWorks, ?s.workFor(widget.artworkId ?? '')],
            initialArtworkId: widget.artworkId,
            legacyNote: s.note(selected),
            onSaved: (entry) =>
                setState(() => diaryEntries[entry.date] = entry),
            onDeleted: () => setState(() => diaryEntries.remove(selected)),
          ),
      ],
    ),
  );
  Widget _diaryList(ArtlogState s) {
    if (loading) return const SizedBox.shrink();
    if (diaryError != null) {
      return EmptyView(
        diaryError!,
        action: ArtButton('다시 불러오기', onTap: loadMonth),
      );
    }
    if (diaryEntries.isEmpty) {
      return EmptyView(
        '이달의 첫 감상평을 남겨보세요.',
        description: '그림을 보지 않은 날에도 나만의 다이어리를 쓸 수 있어요.',
        action: ArtButton(
          '감상평 쓰기',
          onTap: () => setState(() => tab = 'calendar'),
        ),
      );
    }
    final entries = diaryEntries.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Card(
              elevation: 0,
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: Icon(
                  entry.isPublic ? Icons.public : Icons.lock_outline,
                  color: green,
                ),
                title: Text(
                  entry.date,
                  style: sans(12, weight: FontWeight.w600),
                ),
                subtitle: Text(
                  entry.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: sans(12, color: muted),
                ),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () {
                  setState(() => tab = 'calendar');
                  loadDay(entry.date);
                },
              ),
            ),
          ),
      ],
    );
  }
}
