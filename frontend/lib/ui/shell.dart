import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../social.dart';
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
  final motion = PageMotionController();

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ArtlogScope.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 850;
    final exhibition = widget.location == '/gallery';
    return PageMotionScope(
      controller: motion,
      child: Scaffold(
        backgroundColor: exhibition ? museumBlack : paper,
        endDrawer: const AccountDrawer(),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  _Header(location: widget.location, motion: motion),
                  Expanded(
                    child: state.loading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: exhibition ? museumText : green,
                            ),
                          )
                        : state.error != null
                        ? EmptyView(
                            state.error!,
                            inverse: exhibition,
                            action: ArtButton(
                              '다시 불러오기',
                              light: exhibition,
                              onTap: state.load,
                            ),
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
// Short pages stretch to the viewport so the footer always sits at the bottom.
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
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            controller: scroll,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: box.maxHeight.isFinite ? box.maxHeight : 0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [widget.child, const _Footer()],
              ),
            ),
          ),
        ),
      );
}

/// One return-to-top control for every page: a green circle with a white arrow.
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
                key: const ValueKey('return-to-top'),
                tooltip: '맨 위로',
                style: IconButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(48, 48),
                  shape: const CircleBorder(),
                  side: const BorderSide(color: Color(0x33ffffff)),
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
  Widget build(BuildContext context) => Semantics(
    label: 'Docentalk',
    image: true,
    child: SizedBox(
      key: const ValueKey('docentalk-brand-image'),
      width: small ? 170 : 220,
      height: small ? 44 : 60,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: small ? 320 : 420,
          maxHeight: small ? 320 : 420,
          child: Image.asset(
            'assets/branding/docentalk-logo.png',
            width: small ? 320 : 420,
            height: small ? 320 : 420,
            cacheWidth: 960,
            excludeFromSemantics: true,
          ),
        ),
      ),
    ),
  );
}

String _activeRoute(String location) => location.startsWith('/collection/')
    ? '/library'
    : location.startsWith('/artworks') ||
          location.startsWith('/artwork/') ||
          location.startsWith('/artist')
    ? '/artworks'
    : location.startsWith('/user/')
    ? '/community'
    : location;

const _menu = [
  ('/gallery', '발견하기', Icons.home_outlined),
  ('/artworks', '작품 리스트', Icons.grid_view_outlined),
  ('/community', '감상 피드', Icons.dynamic_feed_outlined),
  ('/library', '내 피드', Icons.person_outline),
];

/// One row: logo on the left, menu and the settings icon on the right.
class _Header extends StatelessWidget {
  const _Header({required this.location, required this.motion});
  final String location;
  final PageMotionController motion;
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 850;
    final active = _activeRoute(location);
    final white = editorialButtonStyle(dark: true, quiet: true).copyWith(
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    );
    return Stack(
      children: [
        Container(
          key: const ValueKey('primary-header'),
          height: mobile ? 60 : 72,
          color: museumBlack,
          padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 40),
          child: Row(
            children: [
              // The logo takes the remaining width and scales down if needed.
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    label: 'Docentalk 홈',
                    button: true,
                    child: InkWell(
                      onTap: () => context.go('/gallery'),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Brand(small: true, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              if (!mobile)
                for (final item in _menu)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
                            height: 1.2,
                            color: Colors.white,
                            weight: active == item.$1
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(width: 8),
              Builder(
                builder: (context) => IconButton(
                  key: const ValueKey('navigation-/mypage'),
                  tooltip: '설정',
                  style: white,
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedBuilder(
            animation: motion,
            builder: (context, _) => SizedBox(
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
            for (final item in _menu)
              Expanded(
                child: Semantics(
                  selected: _activeRoute(location) == item.$1,
                  child: TextButton(
                    key: ValueKey('mobile-navigation-${item.$1}'),
                    onPressed: () => context.go(item.$1),
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
                            height: 1.2,
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

class AccountDrawer extends StatefulWidget {
  const AccountDrawer({super.key});
  @override
  State<AccountDrawer> createState() => _AccountDrawerState();
}

class _AccountDrawerState extends State<AccountDrawer> {
  Future<PublicMember>? social;
  String? identity;
  bool saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ArtlogScope.of(context);
    final next = '${s.userKey}/${s.authenticated}/${s.socialRevision}';
    if (identity == next) return;
    identity = next;
    social = s.authenticated ? s.mySocial() : null;
  }

  Future<void> setVisibility(bool value) async {
    setState(() => saving = true);
    try {
      await ArtlogScope.of(context).setFollowListPublic(value);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void go(String path) {
    Navigator.of(context).pop();
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    final name = s.memberProfile?.nickname ?? '';
    return Drawer(
      key: const ValueKey('account-drawer'),
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('설정', style: serif(24))),
                      IconButton(
                        tooltip: '설정 닫기',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!s.authenticated) ...[
                    Text(
                      '로그인하고 감상과 컬렉션을 모아 보세요.',
                      style: sans(13, color: muted),
                    ),
                    const SizedBox(height: 18),
                    ArtButton(
                      '로그인',
                      key: const ValueKey('drawer-login'),
                      onTap: () async {
                        if (await ensureLogin(context) && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ] else ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: soft,
                          child: Text(
                            name.isEmpty ? '나' : name.characters.first,
                            style: english(22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? '나' : name,
                                style: sans(15, weight: FontWeight.w600),
                              ),
                              if (s.email.isNotEmpty)
                                Text(
                                  s.email,
                                  overflow: TextOverflow.ellipsis,
                                  style: sans(11, color: muted),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: const Text('내 피드'),
                      onTap: () => go('/library'),
                    ),
                    const Divider(),
                    FutureBuilder<PublicMember>(
                      future: social,
                      builder: (context, snapshot) => SwitchListTile(
                        key: const ValueKey('drawer-follow-visibility'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('팔로잉/팔로워 공개'),
                        subtitle: Text(
                          snapshot.hasError
                              ? ArtlogState.message(snapshot.error!)
                              : '끄면 다른 감상가에게 팔로우 목록과 수가 보이지 않아요.',
                          style: sans(11, color: muted),
                        ),
                        value: snapshot.data?.followListPublic ?? true,
                        onChanged: snapshot.hasData && !saving
                            ? setVisibility
                            : null,
                      ),
                    ),
                    const Divider(),
                  ],
                ],
              ),
            ),
            if (s.authenticated && s.loginRequired)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: ListTile(
                  key: const ValueKey('drawer-logout'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout),
                  title: const Text('로그아웃'),
                  onTap: () async {
                    final router = GoRouter.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(context).pop();
                    try {
                      await s.logout();
                      router.go('/gallery');
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(ArtlogState.message(e))),
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 64),
    child: ColoredBox(
      color: museumBlack,
      child: PageWidth(
        vertical: 28,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 24,
          runSpacing: 12,
          children: [
            const Brand(small: true, color: Colors.white),
            Text(
              '© 2026 DOCENTALK · 그림을 만나고, 나의 시선을 기록합니다.',
              style: sans(11, color: const Color(0xffb3b8ae)),
            ),
          ],
        ),
      ),
    ),
  );
}
