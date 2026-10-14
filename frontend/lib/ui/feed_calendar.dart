import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../state.dart';
import 'design.dart';
import '../diary.dart';
import 'diary_editor.dart';

/// 감상 캘린더: monthly views with the day's impressions and an editor.
/// A day may hold any number of impressions, one per artwork.
class FeedCalendar extends StatefulWidget {
  const FeedCalendar({
    super.key,
    this.artworkId,
    this.initialDate,
    this.initialEntryId,
  });
  final String? artworkId, initialDate, initialEntryId;
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
  String? identity, calendarError, dayError, diaryError;
  Map<String, List<DiaryEntry>> diaryEntries = {};
  // The entry open in the editor; null means writing a new one.
  late String? editingId = widget.initialEntryId;
  int get diaryCount => diaryEntries.values.fold(0, (n, l) => n + l.length);
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
        diaryEntries = {};
        for (final e in entries) {
          (diaryEntries[e.date] ??= []).add(e);
        }
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
      if (date != selected) editingId = null;
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

  DiaryEntry? get editingEntry => editingId == null
      ? null
      : diaryEntries[selected]?.where((e) => e.id == editingId).firstOrNull;

  Future<void> edit(String? id) async {
    if (id == editingId ||
        !(await editorKey.currentState?.confirmDiscard() ?? true) ||
        !mounted) {
      return;
    }
    setState(() {
      editingId = id;
      editorKey = GlobalKey<DiaryEditorState>();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    final monthPrefix = dateKey(month).substring(0, 7),
        visited = counts.entries
            .where((e) => e.key.startsWith(monthPrefix) && e.value > 0)
            .length;
    final totalViews = calendarDays.values
        .where((day) => day.date.startsWith(monthPrefix))
        .fold<int>(0, (total, day) => total + day.totalViews);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!s.authenticated)
          EmptyView(
            '감상의 순간을 모아보세요.',
            description: '로그인하면 감상 캘린더와 다이어리를 볼 수 있어요.',
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
                    child: const Text('다시 불러오기'),
                  ),
                ],
              ),
            ),
          ...[
            const SizedBox(height: 4),
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
                      '감상평 $diaryCount편',
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
                        if (!(await editorKey.currentState?.confirmDiscard() ??
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
            else
              LayoutBuilder(
                builder: (context, c) {
                  final calendar = _calendar(s);
                  final journal = _journal(s);
                  return c.maxWidth > 920
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: calendar),
                            const SizedBox(width: 28),
                            Expanded(flex: 5, child: journal),
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
        ],
      ],
    );
  }

  Widget _calendar(ArtlogState s) => LayoutBuilder(
    builder: (context, c) {
      final days = DateTime(month.year, month.month + 1, 0).day,
          start = month.weekday % 7;
      final width = (c.maxWidth - 2) / 7,
          height = compact(context) ? 78.0 : 112.0;
      return Container(
        padding: const EdgeInsets.all(1),
        decoration: surfaceDecoration(radius: 8),
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
                        return SizedBox(width: width, height: height);
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
                            '${month.month}월 $d일, $count점 감상${diaryEntries.containsKey(date) ? ', 감상평 ${diaryEntries[date]!.length}편' : ''}',
                        button: true,
                        selected: selected == date,
                        child: InkWell(
                          onTap: () => loadDay(date),
                          child: Container(
                            width: width,
                            height: height,
                            padding: EdgeInsets.all(width < 60 ? 4 : 8),
                            decoration: BoxDecoration(
                              color: selected == date ? soft : pearl,
                              border: Border.all(
                                color: selected == date ? green : line,
                                width: selected == date ? 1.2 : .4,
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
                                if (diaryEntries[date] case final entries?)
                                  Icon(
                                    entries.any((e) => e.isPublic)
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
    decoration: surfaceDecoration(tinted: true),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('DAILY NOTE'),
        const SizedBox(height: 12),
        Text(
          '${int.parse(selected.substring(5, 7))}월 ${int.parse(selected.substring(8))}일의 기록',
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
            '이날 감상한 작품이 없어요.\n작품 없이도 생각을 기록할 수 있어요.',
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
        else ...[
          for (final entry in diaryEntries[selected] ?? const <DiaryEntry>[])
            _DayEntryTile(
              entry: entry,
              editing: entry.id == editingId,
              onEdit: () => edit(entry.id),
            ),
          if (editingId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => edit(null),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('새 감상평 쓰기'),
              ),
            ),
          const SizedBox(height: 12),
          DiaryEditor(
            key: editorKey,
            date: selected,
            entry: editingEntry,
            works: [...dayWorks, ?s.workFor(widget.artworkId ?? '')],
            initialArtworkId: editingId == null ? widget.artworkId : null,
            legacyNote: diaryEntries.containsKey(selected)
                ? ''
                : s.note(selected),
            onSaved: (entry) => setState(() {
              final day = diaryEntries[entry.date] ??= [];
              final i = day.indexWhere((e) => e.id == entry.id);
              if (i < 0) {
                day.insert(0, entry);
              } else {
                day[i] = entry;
              }
              editingId = null;
              editorKey = GlobalKey<DiaryEditorState>();
            }),
            onDeleted: () => setState(() {
              diaryEntries[selected]?.removeWhere((e) => e.id == editingId);
              if (diaryEntries[selected]?.isEmpty ?? false) {
                diaryEntries.remove(selected);
              }
              editingId = null;
              editorKey = GlobalKey<DiaryEditorState>();
            }),
          ),
        ],
      ],
    ),
  );
}

/// One saved impression of the selected day, with a button to edit it.
class _DayEntryTile extends StatelessWidget {
  const _DayEntryTile({
    required this.entry,
    required this.editing,
    required this.onEdit,
  });
  final DiaryEntry entry;
  final bool editing;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
    decoration: BoxDecoration(
      color: editing ? soft : pearl,
      border: Border.all(color: editing ? green : line, width: .6),
    ),
    child: Row(
      children: [
        Icon(
          entry.isPublic ? Icons.public : Icons.lock_outline,
          size: 15,
          color: green,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.artwork?.title ?? '작품 없이 남긴 기록',
                style: sans(12, weight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                entry.content,
                style: sans(12, color: muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: editing ? null : onEdit,
          child: Text(editing ? '수정 중' : '수정'),
        ),
      ],
    ),
  );
}
