import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../state.dart';
import 'design.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final scroll = ScrollController();
  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location && scroll.hasClients) {
      scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ArtlogScope.of(context);
    return Scaffold(
      body: Column(
        children: [
          _Header(location: widget.location),
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator(color: green))
                : state.error != null
                ? EmptyView(
                    state.error!,
                    action: ArtButton('다시 불러오기', onTap: state.load),
                  )
                : SelectionArea(
                    child: SingleChildScrollView(
                      controller: scroll,
                      child: Column(children: [widget.child, const _Footer()]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
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
  @override
  Widget build(BuildContext context) {
    final state = ArtlogScope.of(context),
        mobile = MediaQuery.sizeOf(context).width < 980;
    final active = location.startsWith('/artwork')
        ? '/gallery'
        : location.startsWith('/artist')
        ? '/artists'
        : location;
    return Container(
      decoration: const BoxDecoration(
        color: paper,
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: PageWidth(
        child: SizedBox(
          height: mobile ? 70 : 86,
          child: Row(
            children: [
              Semantics(
                label: '아트로그 홈',
                button: true,
                child: InkWell(
                  onTap: () => context.go('/gallery'),
                  child: Brand(small: mobile),
                ),
              ),
              const Spacer(),
              for (final item in [
                ('/gallery', '발견하기'),
                ('/artists', '작가 이야기'),
                ('/library', '내 서재'),
              ])
                Padding(
                  padding: EdgeInsets.only(left: mobile ? 12 : 34),
                  child: SizedBox(
                    height: mobile ? 70 : 86,
                    child: InkWell(
                      onTap: () => context.go(item.$1),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: active == item.$1
                                  ? green
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          item.$2,
                          style: sans(
                            mobile ? 10 : 14,
                            color: active == item.$1 ? green : muted,
                            weight: active == item.$1
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (!mobile) ...[
                const Spacer(),
                if (state.config.demo)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: line,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('미리보기', style: sans(10, color: green)),
                  )
                else
                  Text('일상에 한 점.', style: serif(11, color: muted)),
                const SizedBox(width: 16),
              ],
              if (!mobile)
                IconButton(
                  tooltip: '작품 검색',
                  icon: const Icon(Icons.search, size: 21),
                  onPressed: () =>
                      showSearch(context: context, delegate: _ArtSearch(state)),
                ),
              if (!mobile)
                IconButton(
                  tooltip: !state.loginRequired
                      ? '나의 감상 기록'
                      : state.authenticated
                      ? '계정'
                      : '로그인',
                  icon: Icon(
                    !state.loginRequired
                        ? Icons.menu_book_outlined
                        : Icons.person_outline,
                    size: 21,
                  ),
                  onPressed: () async {
                    if (!state.loginRequired) {
                      context.go('/library');
                      return;
                    }
                    if (!state.authenticated) {
                      await ensureLogin(context);
                      return;
                    }
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text('나의 미술관', style: serif(22)),
                        content: Text(state.email, style: sans(13)),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              await logoutUser(context);
                              if (c.mounted) Navigator.pop(c);
                            },
                            child: const Text('로그아웃'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('닫기'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
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
