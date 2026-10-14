import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../state.dart';
import 'design.dart';

/// 감상 캘린더: each day shows the latest artwork viewed, and selecting a day
/// lists that day's artworks on the right (7:3 on wide screens).
class FeedCalendar extends StatefulWidget {
  const FeedCalendar({super.key, this.initialDate});
  final String? initialDate;
  @override
  State<FeedCalendar> createState() => _FeedCalendarState();
}

class _FeedCalendarState extends State<FeedCalendar> {
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
  String? identity, calendarError, dayError;
  bool sample = false, loading = false, dayLoading = false;
  int monthRevision = 0, dayRevision = 0;
  Map<String, CalendarDay> calendarDays = {};
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
      records[date] = [
        for (var i = 0; i < 1 + d % 3; i++)
          s.artworks[(d + i) % s.artworks.length].id,
      ];
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
      final result = s.config.demo
          ? demoRecords(s).map(
              (k, v) => MapEntry(
                k,
                CalendarDay(
                  date: k,
                  artworkCount: v.toSet().length,
                  totalViews: v.length,
                  // The last id recorded that day is the latest view.
                  artwork: v.isEmpty ? null : s.workFor(v.last),
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
      setState(() => calendarDays = result);
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
    final currentIdentity = identity;
    if (!s.authenticated) return;
    setState(() {
      selected = date;
      dayLoading = true;
      dayError = null;
      dayWorks = [];
    });
    try {
      final result = s.config.demo
          ? [
              for (final id
                  in (demoRecords(s)[date] ?? const <String>[]).reversed
                      .toSet())
                ?s.workFor(id),
            ]
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

  void changeMonth(int delta) {
    setState(() {
      month = DateTime(month.year, month.month + delta);
      selected = dateKey(month);
    });
    loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (!s.authenticated) {
      return EmptyView(
        '감상의 순간을 모아보세요.',
        description: '로그인하면 감상 캘린더를 볼 수 있어요.',
        action: ArtButton(
          '로그인',
          onTap: () async {
            await ensureLogin(context);
            if (mounted) loadMonth();
          },
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.libraryError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.libraryError!, style: sans(12, color: Colors.brown)),
                TextButton(
                  onPressed: s.reloadLibrary,
                  child: const Text('다시 불러오기'),
                ),
              ],
            ),
          ),
        if (sample)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '예시 캘린더를 보고 있어요. 실제 감상 기록과 구분되어 표시됩니다.',
              style: sans(11, color: muted),
            ),
          ),
        if (loading) const LinearProgressIndicator(color: sage, minHeight: 2),
        if (calendarError != null)
          EmptyView(
            calendarError!,
            action: ArtButton('다시 불러오기', onTap: loadMonth),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final calendar = _calendar(s);
              final day = _dayPanel(s);
              return c.maxWidth > 920
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: calendar),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: day),
                      ],
                    )
                  : Column(
                      children: [calendar, const SizedBox(height: 24), day],
                    );
            },
          ),
      ],
    );
  }

  Widget _smallArrow(String tooltip, IconData icon, VoidCallback onTap) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
          fixedSize: const Size(28, 28),
          minimumSize: const Size(28, 28),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: line),
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, size: 16),
      );

  Widget _calendar(ArtlogState s) {
    final monthPrefix = dateKey(month).substring(0, 7);
    final visited = calendarDays.values
        .where((d) => d.date.startsWith(monthPrefix) && d.artworkCount > 0)
        .length;
    final totalViews = calendarDays.values
        .where((d) => d.date.startsWith(monthPrefix))
        .fold<int>(0, (total, d) => total + d.totalViews);
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: surfaceDecoration(radius: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  key: const ValueKey('calendar-month-nav'),
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _smallArrow(
                            '이전 달',
                            Icons.chevron_left,
                            () => changeMonth(-1),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              '${month.year}년 ${month.month}월',
                              overflow: TextOverflow.ellipsis,
                              style: serif(18, height: 1.3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _smallArrow(
                            '다음 달',
                            Icons.chevron_right,
                            () => changeMonth(1),
                          ),
                        ],
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
                      child: Text('오늘', style: sans(12, height: 1.2)),
                    ),
                  ],
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      '$visited일의 감상 · 총 $totalViews회 감상',
                      style: sans(11, color: muted),
                    ),
                    if (s.config.demo)
                      TextButton(
                        onPressed: () {
                          setState(() => sample = !sample);
                          loadMonth();
                        },
                        child: Text(
                          sample ? '예시 끄기' : '예시 보기',
                          style: sans(11, color: green),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, c) {
              final days = DateTime(month.year, month.month + 1, 0).day,
                  start = month.weekday % 7;
              final width = c.maxWidth / 7,
                  height = compact(context) ? 78.0 : 112.0;
              return Column(
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
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              day,
                              textAlign: TextAlign.center,
                              style: sans(9, color: muted, height: 1.2),
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
                        _cell(s, index - start + 1, width, height, days),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _cell(ArtlogState s, int d, double width, double height, int days) {
    if (d < 1 || d > days) return SizedBox(width: width, height: height);
    final date = dateKey(DateTime(month.year, month.month, d));
    final info = calendarDays[date];
    final count = info?.artworkCount ?? 0;
    final art = info?.artwork;
    final today = date == seoulDate();
    return Semantics(
      label: '${month.month}월 $d일, $count점 감상',
      button: true,
      selected: selected == date,
      child: InkWell(
        key: ValueKey('calendar-day-$date'),
        onTap: () => loadDay(date),
        child: Container(
          width: width,
          height: height,
          padding: EdgeInsets.all(width < 60 ? 3 : 6),
          decoration: BoxDecoration(
            color: selected == date ? soft : pearl,
            border: Border.all(
              color: selected == date ? green : line,
              width: selected == date ? 1.2 : .4,
            ),
          ),
          child: Stack(
            children: [
              if (art != null)
                Positioned.fill(
                  top: 24,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: ArtImage(
                      art.image,
                      label: art.title,
                      width: double.infinity,
                    ),
                  ),
                ),
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: today ? green : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$d',
                  style: sans(
                    11,
                    height: 1.2,
                    color: today ? Colors.white : muted,
                  ),
                ),
              ),
              if (count > 1)
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Container(
                    key: ValueKey('calendar-more-$date'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xcc252823),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+${count - 1}',
                      style: sans(9, height: 1.3, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _dayPanel(ArtlogState s) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: surfaceDecoration(tinted: true),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${int.parse(selected.substring(5, 7))}월 ${int.parse(selected.substring(8))}일의 작품',
          style: serif(20),
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
          Text('이날 감상한 작품이 없어요.', style: sans(12, color: muted)),
          TextButton(
            onPressed: () => context.go('/artworks'),
            child: const Text('작품 둘러보기 ↗'),
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
          if (dayWorks.length > 3)
            TextButton.icon(
              onPressed: () => showDayWorks(s),
              icon: const Icon(Icons.grid_view_outlined, size: 16),
              label: Text('전체 ${dayWorks.length}점 보기'),
            ),
        ],
      ],
    ),
  );
}
