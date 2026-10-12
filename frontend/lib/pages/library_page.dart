import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../state.dart';
import '../ui/design.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late DateTime month = DateTime.parse('${seoulDate().substring(0, 7)}-01');
  String selected = seoulDate(), tab = 'calendar';
  String? identity, calendarError, dayError;
  bool sample = false,
      loading = false,
      dayLoading = false,
      saving = false,
      saved = false;
  int monthRevision = 0, dayRevision = 0;
  Map<String, int> counts = {};
  List<Artwork> dayWorks = [];
  final note = TextEditingController();
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ArtlogScope.of(context),
        key = '${s.config.demo}/${s.email}/${s.authenticated}';
    if (identity != key) {
      identity = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) loadMonth();
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
    ++dayRevision;
    if (!s.authenticated) {
      setState(() {
        counts = {};
        dayWorks = [];
        calendarError = null;
        dayLoading = false;
        note.clear();
      });
      return;
    }
    setState(() {
      loading = true;
      calendarError = null;
      counts = {};
      dayWorks = [];
      dayLoading = false;
    });
    try {
      final result = s.config.demo
          ? demoRecords(s).map((k, v) => MapEntry(k, v.length))
          : await s.api.calendar(dateKey(month).substring(0, 7));
      if (!mounted || revision != monthRevision) return;
      setState(() => counts = result);
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
    final s = ArtlogScope.of(context), revision = ++dayRevision;
    setState(() {
      selected = date;
      dayLoading = true;
      dayError = null;
      saved = false;
      note.text = s.note(date);
      dayWorks = [];
    });
    try {
      final result = s.config.demo
          ? s.artworks
                .where((a) => (demoRecords(s)[date] ?? []).contains(a.id))
                .toList()
          : await s.api.day(date);
      if (mounted && revision == dayRevision) setState(() => dayWorks = result);
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

  void changeMonth(int delta) {
    setState(() {
      month = DateTime(month.year, month.month + delta);
      selected = dateKey(month);
    });
    loadMonth();
  }

  Future<void> save() async {
    final s = ArtlogScope.of(context);
    final date = selected;
    setState(() => saving = true);
    try {
      await s.saveNote(date, note.text);
      if (mounted && selected == date) setState(() => saved = true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
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
                  color: const Color(0xffe6eadc),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: green,
                    size: 30,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 30),
          if (!s.config.demo && s.authenticated)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(s.email, style: sans(11, color: muted)),
                  TextButton(onPressed: s.logout, child: const Text('로그아웃')),
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
            Container(
              padding: EdgeInsets.all(compact(context) ? 18 : 26),
              decoration: BoxDecoration(
                color: const Color(0xffeef0e7),
                borderRadius: BorderRadius.circular(4),
              ),
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
                  ('likes', '좋아요한 작품', Icons.favorite_border),
                  ('follows', '팔로우한 작가', Icons.people_outline),
                ])
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => tab = t.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: tab == t.$1 ? green : line,
                              width: tab == t.$1 ? 2 : 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!compact(context)) ...[
                              Icon(
                                t.$3,
                                size: 16,
                                color: tab == t.$1 ? green : muted,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              t.$2,
                              style: sans(
                                compact(context) ? 10 : 12,
                                color: tab == t.$1 ? green : muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (tab == 'calendar') ...[
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
                        '$visited일의 감상 · 그림을 만난 날을 눌러보세요.',
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
                        onPressed: () {
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
      final width = c.maxWidth / 7, height = compact(context) ? 78.0 : 112.0;
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(3),
        ),
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
                        return Container(
                          width: (c.maxWidth - 2) / 7,
                          height: height,
                          decoration: const BoxDecoration(
                            color: Color(0xfff0f1e9),
                            border: Border(
                              top: BorderSide(color: line),
                              right: BorderSide(color: line),
                            ),
                          ),
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
                        label: '${month.month}월 $d일, $count점 감상',
                        button: true,
                        selected: selected == date,
                        child: InkWell(
                          onTap: () => loadDay(date),
                          child: Container(
                            width: (c.maxWidth - 2) / 7,
                            height: height,
                            padding: EdgeInsets.all(width < 60 ? 4 : 8),
                            decoration: BoxDecoration(
                              color: selected == date
                                  ? const Color(0xffe6ecdc)
                                  : paper,
                              border: Border.all(
                                color: selected == date ? sage : line,
                                width: selected == date ? 1.3 : 0.3,
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
  Widget _journal(ArtlogState s) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(23),
    decoration: BoxDecoration(
      color: const Color(0xffeef2e4),
      borderRadius: BorderRadius.circular(3),
    ),
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
          for (final a in dayWorks)
            Padding(
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
                        ],
                      ),
                    ),
                    const Icon(Icons.north_east, size: 15),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        Text('마음에 남은 한 줄', style: sans(11, color: muted)),
        const SizedBox(height: 10),
        TextField(
          controller: note,
          maxLength: 500,
          maxLines: 4,
          style: sans(12),
          onChanged: (_) => setState(() => saved = false),
          decoration: InputDecoration(
            hintText: '그림을 보며 떠오른 생각을 남겨보세요.',
            hintStyle: sans(11, color: muted),
          ),
        ),
        Text('한 줄 기록은 이 브라우저에 저장돼요.', style: sans(9, color: muted)),
        const SizedBox(height: 12),
        ArtButton(
          saved
              ? '기록했어요'
              : saving
              ? '기록 중…'
              : '감상 기록하기',
          icon: saved ? Icons.check : Icons.edit_outlined,
          onTap: sample || saving ? null : save,
        ),
      ],
    ),
  );
}
