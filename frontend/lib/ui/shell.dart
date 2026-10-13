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
    final immersive = widget.location == '/gallery';
    final headerHeight = MediaQuery.sizeOf(context).width < 850 ? 140.0 : 100.0;
    return Scaffold(
      body: AuroraBackdrop(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: immersive ? 0 : headerHeight),
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
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _Header(location: widget.location),
            ),
          ],
        ),
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
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: scroll,
    child: Column(children: [widget.child, const _Footer()]),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.small = false});
  final bool small;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CustomPaint(
        size: Size(small ? 22 : 28, small ? 27 : 32),
        painter: _BrandMark(),
      ),
      const SizedBox(width: 10),
      Text(
        'artlog',
        style: english(
          small ? 32 : 38,
        ).copyWith(fontWeight: FontWeight.w600, letterSpacing: -1.5),
      ),
      if (!compact(context)) ...[
        const SizedBox(width: 13),
        Text('아트로그', style: sans(10, color: muted)),
      ],
    ],
  );
}

class _BrandMark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final path = Path()
      ..moveTo(3, size.height)
      ..lineTo(3, size.width / 2)
      ..arcToPoint(
        Offset(size.width - 3, size.width / 2),
        radius: Radius.circular(size.width / 2),
      )
      ..lineTo(size.width - 3, size.height);
    canvas.drawPath(path, p);
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - 2.5, size.height - 12, 5, 12),
      Paint()..color = green,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Header extends StatelessWidget {
  const _Header({required this.location});
  final String location;
  void account(BuildContext context, ArtlogState state) async {
    if (!state.authenticated) {
      if (!await ensureLogin(context) || !context.mounted) return;
    }
    if (context.mounted) context.go('/mypage');
  }

  @override
  Widget build(BuildContext context) {
    final state = ArtlogScope.of(context),
        mobile = MediaQuery.sizeOf(context).width < 850;
    final active = location.startsWith('/artwork')
        ? '/gallery'
        : location.startsWith('/artist')
        ? '/artists'
        : location;
    final nav = Row(
      mainAxisSize: mobile ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final item in [
          ('/gallery', '발견하기'),
          ('/artists', mobile ? '작가' : '작가 이야기'),
          ('/community', '감상 피드'),
          ('/library', '내 서재'),
        ])
          Flexible(
            fit: mobile ? FlexFit.tight : FlexFit.loose,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TextButton(
                onPressed: () => context.go(item.$1),
                style:
                    crystalButtonStyle(
                      dark: active == item.$1,
                      quiet: active != item.$1,
                    ).copyWith(
                      minimumSize: WidgetStatePropertyAll(
                        Size(mobile ? 0 : 84, 44),
                      ),
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: mobile ? 8 : 14),
                      ),
                    ),
                child: Text(
                  item.$2,
                  style: sans(
                    mobile ? 11 : 12,
                    color: active == item.$1 ? Colors.white : muted,
                    weight: active == item.$1
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final tools = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.config.demo && !mobile)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('미리보기', style: sans(10, color: muted)),
          ),
        IconButton(
          tooltip: '작품 검색',
          onPressed: () =>
              showSearch(context: context, delegate: _ArtSearch(state)),
          icon: const Icon(Icons.search, size: 20),
        ),
        IconButton(
          style: crystalButtonStyle(
            dark: location == '/mypage',
            quiet: location != '/mypage',
          ),
          tooltip: !state.loginRequired
              ? '마이페이지'
              : state.authenticated
              ? '마이페이지'
              : '로그인',
          onPressed: () => account(context, state),
          icon: Icon(
            !state.loginRequired
                ? Icons.menu_book_outlined
                : Icons.person_outline,
            size: 20,
          ),
        ),
      ],
    );
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 12 : 24,
          vertical: 12,
        ),
        child: GlassSurface(
          blur: true,
          radius: mobile ? 28 : 100,
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 12 : 22,
            vertical: 8,
          ),
          child: mobile
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Semantics(
                                label: '아트로그 홈',
                                button: true,
                                child: InkWell(
                                  onTap: () => context.go('/gallery'),
                                  child: const Brand(small: true),
                                ),
                              ),
                            ),
                          ),
                        ),
                        tools,
                      ],
                    ),
                    const SizedBox(height: 4),
                    nav,
                  ],
                )
              : SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      Semantics(
                        label: '아트로그 홈',
                        button: true,
                        child: InkWell(
                          onTap: () => context.go('/gallery'),
                          child: const Brand(),
                        ),
                      ),
                      const Spacer(),
                      nav,
                      const Spacer(),
                      tools,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) => PageWidth(
    vertical: 30,
    child: Container(
      padding: const EdgeInsets.only(top: 26),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 35,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Brand(small: true),
              Text('한 점의 그림이, 당신의 하루에 머물기를.', style: sans(10, color: muted)),
              TextButton(
                onPressed: () => showAboutDialog(
                  context: context,
                  applicationName: '아트로그',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '작품 이미지의 출처와 이용 조건은 작품 상세에서 확인할 수 있습니다.',
                  children: [
                    Text(
                      ArtlogScope.of(context).config.demo
                          ? '미리보기의 좋아요·팔로우·감상 기록은 현재 브라우저에 저장됩니다. 도슨트는 준비된 감상 안내를 제공합니다.'
                          : '작품과 도슨트 답변의 출처를 함께 살펴보고 감상을 기록하세요.',
                      style: sans(12),
                    ),
                  ],
                ),
                child: Text('아트로그에 대하여 ↗', style: sans(11)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© 2026 ARTLOG. A LITTLE ART, EVERY DAY.',
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 9,
              letterSpacing: 1,
              color: muted,
            ),
          ),
        ],
      ),
    ),
  );
}
