import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../state.dart';
import 'design.dart';
import 'member_profile_dialog.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool onboardingOpen = false;
  final motion = PageMotionController();

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleOnboarding();
  }

  void _scheduleOnboarding() {
    final state = ArtlogScope.of(context);
    if (!state.needsOnboarding || state.authUiOpen || onboardingOpen) return;
    onboardingOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (mounted && state.needsOnboarding && !state.authUiOpen) {
          await showMemberProfile(context, state);
        }
      } finally {
        onboardingOpen = false;
        if (mounted && state.needsOnboarding && !state.authUiOpen) {
          _scheduleOnboarding();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ArtlogScope.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 850;
    return PageMotionScope(
      controller: motion,
      child: Scaffold(
        backgroundColor: paper,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  _Header(location: widget.location, motion: motion),
                  Expanded(
                    child: state.loading
                        ? const Center(
                            child: CircularProgressIndicator(color: green),
                          )
                        : state.error != null
                        ? EmptyView(
                            state.error!,
                            action: ArtButton('다시 불러오기', onTap: state.load),
                          )
                        : Semantics(
                            container: true,
                            child: SelectionArea(child: widget.child),
                          ),
                  ),
                ],
              ),
              Positioned(
                bottom: 20,
                right: mobile ? 16 : 28,
                child: _ReturnToTop(motion: motion),
              ),
            ],
          ),
        ),
        bottomNavigationBar: mobile
            ? _MobileNavigation(location: widget.location)
            : null,
      ),
    );
  }
}

// Each route owns its scroll view. Keeping the Navigator inside an unbounded
// scroll view constrains outgoing routes to the next page's content height.
class AppPage extends StatefulWidget {
  const AppPage({super.key, required this.child});
  final Widget child;
  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  final scroll = ScrollController(keepScrollOffset: false);
  PageMotionController? motion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PageMotionScope.maybeOf(context);
    if (motion != next) {
      motion?.unbind(scroll);
      motion = next;
      motion?.bind(scroll);
    }
  }

  @override
  void dispose() {
    motion?.unbind(scroll);
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) motion?.refresh();
            });
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: scroll,
          child: Column(children: [widget.child, const _Footer()]),
        ),
      );
}

class _ReturnToTop extends StatelessWidget {
  const _ReturnToTop({required this.motion});
  final PageMotionController motion;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: motion,
    builder: (context, _) {
      final visible = motion.offset > 600;
      final duration = reduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 220);
      return IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: AnimatedSlide(
            offset: Offset(0, visible ? 0 : .4),
            duration: duration,
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: duration,
              child: IconButton(
                tooltip: '맨 위로',
                style: editorialButtonStyle(dark: true).copyWith(
                  side: const WidgetStatePropertyAll(BorderSide(color: sage)),
                ),
                onPressed: () =>
                    motion.returnToTop(immediately: reduceMotion(context)),
                icon: const Icon(Icons.arrow_upward, size: 20),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.small = false, this.color = ink});
  final bool small;
  final Color color;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(small ? 22 : 28, small ? 27 : 32),
          painter: _BrandMark(color),
        ),
        const SizedBox(width: 10),
        Text(
          'Docentalk',
          style: english(
            small ? 30 : 36,
            color: color,
          ).copyWith(fontWeight: FontWeight.w600, letterSpacing: -1.2),
        ),
      ],
    ),
  );
}

class _BrandMark extends CustomPainter {
  _BrandMark(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.width / 28, size.height / 32);
    final path = Path()
      ..moveTo(4, 3)
      ..lineTo(12, 3)
      ..cubicTo(29, 3, 29, 25, 12, 25)
      ..lineTo(10, 25)
      ..lineTo(4, 30)
      ..close();
    canvas.drawPath(path, p);
    for (final x in [11.0, 17.0]) {
      canvas.drawCircle(Offset(x, 14), 1.4, Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandMark oldDelegate) =>
      oldDelegate.color != color;
}

String _activeRoute(String location) => location == '/settings'
    ? '/mypage'
    : location.startsWith('/artwork')
    ? '/gallery'
    : location.startsWith('/artist')
    ? '/artists'
    : location;

Future<void> _openAccount(BuildContext context) async {
  final state = ArtlogScope.of(context);
  if (!state.authenticated &&
      (!await ensureLogin(context) || !context.mounted)) {
    return;
  }
  if (context.mounted) context.go('/mypage');
}

class _Header extends StatelessWidget {
  const _Header({required this.location, required this.motion});
  final String location;
  final PageMotionController motion;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: motion,
    builder: (context, _) => content(context),
  );

  Widget content(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 850;
    final collapse = mobile || reduceMotion(context)
        ? 0.0
        : (motion.offset / 220).clamp(0.0, 1.0);
    final active = _activeRoute(location);
    final white = editorialButtonStyle(dark: true, quiet: true);
    return Stack(
      children: [
        ColoredBox(
          color: ink,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: const ValueKey('primary-header'),
                height: mobile ? 64 : 80 - 32 * collapse,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 40),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: SizedBox(
                          width: mobile ? 180 : 230,
                          child: Semantics(
                            label: 'Docentalk 홈',
                            button: true,
                            child: InkWell(
                              onTap: () => context.go('/gallery'),
                              child: Transform.scale(
                                scale: 1 - .12 * collapse,
                                child: Brand(
                                  small: mobile,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: '작품 검색',
                          style: white,
                          onPressed: () => showSearch(
                            context: context,
                            delegate: _ArtSearch(ArtlogScope.of(context)),
                          ),
                          icon: const Icon(Icons.search, size: 21),
                        ),
                      ),
                      if (!mobile)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: const ValueKey('navigation-/mypage'),
                            style: white,
                            onPressed: () => _openAccount(context),
                            icon: const Icon(Icons.person_outline, size: 18),
                            label: const Text('마이페이지'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!mobile)
                Container(
                  height: 48,
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xff3d403b))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final item in [
                        ('/gallery', '발견하기'),
                        ('/artists', '작가'),
                        ('/community', '감상 피드'),
                        ('/library', '내 서재'),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DecoratedBox(
                            position: DecorationPosition.foreground,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: active == item.$1
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: TextButton(
                              key: ValueKey('navigation-${item.$1}'),
                              style: white,
                              onPressed: () => context.go(item.$1),
                              child: Text(
                                item.$2,
                                style: sans(
                                  14,
                                  color: Colors.white,
                                  weight: active == item.$1
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            height: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                key: const ValueKey('page-reading-progress'),
                widthFactor: motion.progress,
                child: const ColoredBox(
                  color: sage,
                  child: SizedBox(height: 2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.location});
  final String location;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('mobile-navigation'),
    decoration: const BoxDecoration(
      color: pearl,
      border: Border(top: BorderSide(color: line)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (final item in [
              ('/gallery', '발견', Icons.grid_view_outlined),
              ('/community', '피드', Icons.dynamic_feed_outlined),
              ('/library', '내 서재', Icons.book_outlined),
              ('/mypage', '마이페이지', Icons.person_outline),
            ])
              Expanded(
                child: Semantics(
                  selected: _activeRoute(location) == item.$1,
                  child: TextButton(
                    key: ValueKey('navigation-${item.$1}'),
                    onPressed: () => item.$1 == '/mypage'
                        ? _openAccount(context)
                        : context.go(item.$1),
                    style: editorialButtonStyle(
                      quiet: true,
                      minimumSize: const Size(0, 64),
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.$3,
                          size: 21,
                          color: _activeRoute(location) == item.$1
                              ? ink
                              : muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$2,
                          style: sans(
                            10,
                            color: _activeRoute(location) == item.$1
                                ? ink
                                : muted,
                            weight: _activeRoute(location) == item.$1
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ArtSearch extends SearchDelegate<void> {
  _ArtSearch(this.state) : super(searchFieldLabel: '작품명이나 작가 이름으로 찾아보세요');
  final ArtlogState state;
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      tooltip: '검색어 지우기',
      onPressed: () => query = '',
      icon: const Icon(Icons.clear),
    ),
  ];
  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: '검색 닫기',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );
  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);
  @override
  Widget buildSuggestions(BuildContext context) {
    final result = state.artworks
        .where(
          (a) => '${a.title} ${a.titleEn} ${state.artistName(a)}'
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    return ListView(
      children: [
        for (final a in result)
          ListTile(
            leading: SizedBox(width: 46, height: 46, child: ArtImage(a.image)),
            title: Text(a.title),
            subtitle: Text(state.artistName(a)),
            onTap: () {
              close(context, null);
              context.go('/artwork/${a.id}');
            },
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 64),
    child: ColoredBox(
      color: ink,
      child: PageWidth(
        vertical: 40,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Brand(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              '그림을 만나고, 이야기를 나누고, 나의 시선을 기록합니다.',
              style: sans(13, color: const Color(0xffc1c5bc)),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final item in [
                  ('/gallery', '작품 발견하기'),
                  ('/artists', '작가'),
                  ('/community', '감상 피드'),
                  ('/library', '내 서재'),
                ])
                  TextButton(
                    style: editorialButtonStyle(dark: true, quiet: true),
                    onPressed: () => context.go(item.$1),
                    child: Text(item.$2),
                  ),
                TextButton(
                  style: editorialButtonStyle(dark: true, quiet: true),
                  onPressed: () => showAboutDialog(
                    context: context,
                    applicationName: 'Docentalk',
                    applicationVersion: '1.0.0',
                    applicationLegalese:
                        '작품 이미지의 출처와 이용 조건은 작품 상세에서 확인할 수 있습니다.',
                    children: [
                      Text(
                        ArtlogScope.of(context).config.demo
                            ? '미리보기의 좋아요·팔로우·감상 기록은 현재 브라우저에 저장됩니다.'
                            : 'AI 도슨트와 작품을 살펴보고 감상의 순간을 기록하세요.',
                        style: sans(13),
                      ),
                    ],
                  ),
                  child: const Text('Docentalk에 대하여 ↗'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Divider(color: Color(0xff4b4e47)),
            const SizedBox(height: 18),
            Text(
              '© 2026 DOCENTALK',
              style: sans(10, color: const Color(0xffb3b8ae)),
            ),
          ],
        ),
      ),
    ),
  );
}
