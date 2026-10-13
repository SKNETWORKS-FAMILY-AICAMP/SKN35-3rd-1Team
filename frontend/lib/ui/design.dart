import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state.dart';
import '../models.dart';

const paper = Color(0xfff7f6f2);
const ink = Color(0xff252d27);
const green = Color(0xff364e40);
const muted = Color(0xff747d6c);
const line = Color(0xffe1e2d9);
const sage = Color(0xff8c9c76);
TextStyle sans(
  double size, {
  Color color = ink,
  FontWeight weight = FontWeight.w400,
  double height = 1.7,
}) => TextStyle(
  fontFamily: 'NotoSansKR',
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
);
TextStyle serif(double size, {Color color = ink, double height = 1.6}) =>
    TextStyle(
      fontFamily: 'NotoSerifKR',
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color,
      height: height,
      letterSpacing: -0.8,
    );
TextStyle english(double size, {Color color = ink}) => TextStyle(
  fontFamily: 'Cormorant',
  fontSize: size,
  color: color,
  height: 1.2,
);
bool compact(BuildContext context) => MediaQuery.sizeOf(context).width < 680;

class ArtlogScope extends InheritedNotifier<ArtlogState> {
  const ArtlogScope({
    super.key,
    required ArtlogState state,
    required super.child,
  }) : super(notifier: state);
  static ArtlogState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ArtlogScope>()!.notifier!;
}

class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.vertical = 0});
  final Widget child;
  final double vertical;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact(context) ? 20 : 56,
        vertical: vertical,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.label, {super.key, this.color = muted});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontFamily: 'DMSans',
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.8,
      height: 1.5,
    ).copyWith(color: color),
  );
}

class ArtButton extends StatelessWidget {
  const ArtButton(
    this.label, {
    super.key,
    required this.onTap,
    this.icon = Icons.north_east,
    this.outline = false,
    this.light = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData icon;
  final bool outline, light;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onTap,
    style: FilledButton.styleFrom(
      backgroundColor: outline
          ? Colors.transparent
          : light
          ? paper
          : green,
      foregroundColor: outline || light ? green : Colors.white,
      minimumSize: const Size(0, 46),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: outline ? const BorderSide(color: line) : BorderSide.none,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: sans(
            12,
            color: outline || light ? green : Colors.white,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 22),
        Icon(icon, size: 18),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String eyebrow, title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(eyebrow),
            const SizedBox(height: 9),
            Text(title, style: serif(compact(context) ? 22 : 26)),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(subtitle!, style: sans(12, color: muted)),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 12), trailing!],
    ],
  );
}

const _wikimediaThumbnailWidth = '800';

/// Avoid downloading multi-hundred-megabyte Wikimedia originals in artwork cards.
///
/// Wikimedia's redirect endpoint chooses an available thumbnail size close to the
/// requested width and returns a browser-friendly image even when the source is a
/// TIFF. Non-Wikimedia URLs and local assets are intentionally left unchanged.
String optimizedArtworkImageUrl(String image) {
  final uri = Uri.tryParse(image);
  if (uri == null || !uri.hasAuthority) return image;

  final host = uri.host.toLowerCase();
  final isCommonsSpecial = host == 'commons.wikimedia.org' &&
      (uri.path.startsWith('/wiki/Special:FilePath/') ||
          uri.path.startsWith('/wiki/Special:Redirect/file/'));
  final isCommonsUpload = host == 'upload.wikimedia.org' &&
      uri.path.startsWith('/wikipedia/commons/');

  if (isCommonsSpecial) {
    if (uri.queryParameters.containsKey('width')) return image;
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'width': _wikimediaThumbnailWidth,
      },
    ).toString();
  }

  if (isCommonsUpload) {
    final filename = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (filename.isEmpty) return image;
    return Uri.https(
      'commons.wikimedia.org',
      '/wiki/Special:Redirect/file/$filename',
      const {'width': _wikimediaThumbnailWidth},
    ).toString();
  }

  return image;
}

class ArtImage extends StatelessWidget {
  const ArtImage(
    this.image, {
    super.key,
    this.fit = BoxFit.cover,
    this.label,
    this.width,
    this.height,
  });
  final String image;
  final BoxFit fit;
  final String? label;
  final double? width, height;
  Widget failure() => ColoredBox(
    color: const Color(0xffe8e7df),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, color: sage, size: 30),
          const SizedBox(height: 8),
          Text('이미지 준비 중', style: sans(11, color: muted)),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (image.isEmpty) {
      return SizedBox(width: width, height: height, child: failure());
    }
    final uri = Uri.tryParse(image);
    final asset = !image.startsWith('http') && image.startsWith('public/');
    if (!asset &&
        uri?.scheme != 'http' &&
        uri?.scheme != 'https' &&
        !image.startsWith('/')) {
      return failure();
    }
    final resolved = image.startsWith('/')
        ? Uri.base.resolve(image).toString()
        : optimizedArtworkImageUrl(image);
    return asset
        ? Image.asset(
            image,
            width: width,
            height: height,
            fit: fit,
            semanticLabel: label,
            errorBuilder: (_, _, _) => failure(),
          )
        : Image.network(
            resolved,
            // Museum URLs can redirect without CORS headers. Let the browser
            // display the same public image when CanvasKit cannot fetch bytes.
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            width: width,
            height: height,
            fit: fit,
            semanticLabel: label,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: sage,
                    ),
                  ),
            errorBuilder: (_, _, _) => failure(),
          );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView(
    this.title, {
    super.key,
    this.description = '',
    this.action,
    this.icon = Icons.local_florist_outlined,
  });
  final String title, description;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 62, horizontal: 20),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: sage),
          const SizedBox(height: 22),
          Text(title, style: serif(21), textAlign: TextAlign.center),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: sans(12, color: muted),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    ),
  );
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ArtlogState.message(e)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> openSource(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    showError(context, const FormatException());
    return;
  }
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      showError(context, const FormatException());
    }
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Future<bool> ensureLogin(BuildContext context) async {
  final state = ArtlogScope.of(context);
  if (state.authenticated) return true;
  return await showDialog<bool>(
        context: context,
        builder: (_) => LoginDialog(state: state),
      ) ??
      false;
}

Future<void> likeArtwork(BuildContext context, Artwork art) async {
  final state = ArtlogScope.of(context);
  if (!await ensureLogin(context)) return;
  try {
    await state.toggleLike(art.id);
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Future<void> followArtist(BuildContext context, Artist artist) async {
  final state = ArtlogScope.of(context);
  if (!await ensureLogin(context)) return;
  try {
    await state.toggleFollow(artist.id);
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key, required this.state});
  final ArtlogState state;
  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, signup = false, obscure = true;
  String? error, notice;
  bool get firebase => widget.state.config.firebaseAuth;
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      if (signup) {
        await widget.state.register(email.text.trim(), password.text);
      } else {
        await widget.state.login(email.text.trim(), password.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = ArtlogState.message(e);
          busy = false;
        });
      }
    }
  }

  Future<void> reset() async {
    if (busy) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      setState(() => error = '비밀번호를 재설정할 이메일을 먼저 입력해 주세요.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await widget.state.resetPassword(email.text.trim());
      if (mounted) {
        setState(() => notice = '가입된 이메일이라면 재설정 안내를 보냈어요. 받은 편지함을 확인해 주세요.');
      }
    } catch (e) {
      if (mounted) setState(() => error = ArtlogState.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      backgroundColor: paper,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(signup ? '나만의 미술관 시작하기' : '나만의 미술관에 로그인', style: serif(21)),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('마음에 든 그림과 감상을 모아보세요.', style: sans(12, color: muted)),
                if (firebase && widget.state.config.demo) ...[
                  const SizedBox(height: 10),
                  Text(
                    '작품 미리보기의 감상 기록은 이 브라우저에 저장돼요.',
                    style: sans(10, color: muted),
                  ),
                ],
                const SizedBox(height: 20),
                TextFormField(
                  controller: email,
                  autofocus: true,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: '이메일'),
                  validator: (v) =>
                      RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(v?.trim() ?? '')
                      ? null
                      : '이메일 주소를 확인해 주세요.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  enabled: !busy,
                  obscureText: obscure,
                  autofillHints: [
                    signup ? AutofillHints.newPassword : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    helperText: signup ? '8자 이상 입력해 주세요.' : null,
                    suffixIcon: IconButton(
                      tooltip: obscure ? '비밀번호 표시' : '비밀번호 숨기기',
                      onPressed: busy
                          ? null
                          : () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                      ),
                    ),
                  ),
                  validator: (v) => (v ?? '').isEmpty
                      ? '비밀번호를 입력해 주세요.'
                      : signup && v!.length < 8
                      ? '비밀번호를 8자 이상 입력해 주세요.'
                      : null,
                  onFieldSubmitted: (_) => submit(),
                ),
                if (firebase) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: busy || !widget.state.canAuthenticate
                          ? null
                          : reset,
                      child: const Text('비밀번호를 잊었어요'),
                    ),
                  ),
                ],
                if (!widget.state.canAuthenticate)
                  Text(
                    widget.state.authError ?? '로그인 서비스를 준비하고 있어요.',
                    style: sans(12, color: Colors.brown),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!, style: sans(12, color: Colors.brown)),
                  ),
                if (notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(notice!, style: sans(12, color: green)),
                  ),
                if (firebase)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            signup = !signup;
                            error = null;
                            notice = null;
                            form.currentState?.reset();
                          }),
                    child: Text(signup ? '이미 계정이 있어요 · 로그인' : '처음 오셨나요? 회원가입'),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('닫기'),
        ),
        ArtButton(
          busy
              ? '잠시만 기다려 주세요…'
              : signup
              ? '회원가입'
              : '로그인',
          onTap: busy || !widget.state.canAuthenticate ? null : submit,
        ),
      ],
    ),
  );
}

Future<void> logoutUser(BuildContext context) async {
  final state = ArtlogScope.of(context);
  try {
    await state.logout();
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

class ArtworkCard extends StatefulWidget {
  const ArtworkCard(this.art, {super.key});
  final Artwork art;
  @override
  State<ArtworkCard> createState() => _ArtworkCardState();
}

class _ArtworkCardState extends State<ArtworkCard> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context), a = widget.art;
    final liked = s.likes.contains(a.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.10,
          child: MouseRegion(
            onEnter: (_) => setState(() => hover = true),
            onExit: (_) => setState(() => hover = false),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Semantics(
                    label: '${a.title} 작품 보기',
                    button: true,
                    child: InkWell(
                      onTap: () => context.go('/artwork/${a.id}'),
                      child: AnimatedScale(
                        scale: hover ? 1.035 : 1,
                        duration: const Duration(milliseconds: 450),
                        child: ArtImage(
                          a.image,
                          label: '${s.artistName(a)}, ${a.title}',
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: paper.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          s.movementName(a),
                          style: sans(10, color: green),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 9,
                    top: 9,
                    child: Material(
                      color: paper.withValues(alpha: 0.94),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: '${a.title} ${liked ? '좋아요 취소' : '좋아요'}',
                        isSelected: liked,
                        iconSize: 17,
                        constraints: const BoxConstraints(
                          minHeight: 36,
                          minWidth: 36,
                        ),
                        onPressed: s.pendingLikes.contains(a.id)
                            ? null
                            : () => likeArtwork(context, a),
                        icon: Icon(
                          liked ? Icons.favorite : Icons.favorite_border,
                          color: green,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: () => context.go('/artwork/${a.id}'),
                child: Text(a.title, style: sans(14, weight: FontWeight.w500)),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 80),
                child: Text(
                  a.year,
                  style: sans(10, color: muted),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(s.artistName(a), style: sans(11, color: muted)),
        const SizedBox(height: 2),
        Text(
          s.artistEnglish(a),
          style: english(15, color: const Color(0xff929b85)),
        ),
      ],
    );
  }
}

class ArtworkGrid extends StatelessWidget {
  const ArtworkGrid(this.works, {super.key, this.maxColumns = 4});
  final List<Artwork> works;
  final int maxColumns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns =
          (c.maxWidth > 1000
                  ? 4
                  : c.maxWidth > 680
                  ? 3
                  : 2)
              .clamp(1, maxColumns);
      final gap = compact(context) ? 15.0 : 25.0;
      final width = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: 32,
        children: works
            .map(
              (a) => SizedBox(
                width: width,
                child: ArtworkCard(a, key: ValueKey(a.id)),
              ),
            )
            .toList(),
      );
    },
  );
}
