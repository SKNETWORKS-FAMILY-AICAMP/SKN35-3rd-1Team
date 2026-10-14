import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state.dart';
import '../models.dart';

import 'surfaces.dart';
import 'motion.dart';
import 'museum_artwork_images.dart';
export 'surfaces.dart';
export 'motion.dart';

TextStyle sans(
  double size, {
  Color color = ink,
  FontWeight weight = FontWeight.w400,
  double height = 1.7,
}) => TextStyle(
  fontFamily: 'ChironSungHK',
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
  // Even leading keeps Korean text vertically centred next to icons in buttons.
  leadingDistribution: TextLeadingDistribution.even,
);
TextStyle serif(double size, {Color color = ink, double height = 1.6}) =>
    TextStyle(
      fontFamily: 'ChironSungHK',
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color,
      height: height,
      letterSpacing: -0.6,
      leadingDistribution: TextLeadingDistribution.even,
    );
TextStyle english(double size, {Color color = ink}) => TextStyle(
  fontFamily: 'ChironSungHK',
  fontSize: size * .82,
  color: color,
  height: 1.3,
  leadingDistribution: TextLeadingDistribution.even,
);

/// Chiron Sung HK is shared by all text styles, including Korean.
TextStyle brandFont(double size, {Color color = ink}) => TextStyle(
  fontFamily: 'ChironSungHK',
  fontSize: size,
  color: color,
  height: 1.2,
);
const likeRed = Color(0xffe0393e);

/// Space above every titled section on the main page.
const sectionGap = 88.0;

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
      fontFamily: 'ChironSungHK',
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
    style: editorialButtonStyle(
      dark: !outline && !light,
      minimumSize: const Size(44, 48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: sans(
              13,
              color: onTap == null
                  ? muted
                  : outline || light
                  ? ink
                  : Colors.white,
              weight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Icon(icon, size: 17),
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
    this.inverse = false,
  });
  final String eyebrow, title;
  final String? subtitle;
  final Widget? trailing;
  final bool inverse;
  @override
  Widget build(BuildContext context) => ScrollReveal(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(eyebrow, color: inverse ? museumMuted : muted),
              const SizedBox(height: 9),
              Text(
                title,
                style: serif(
                  compact(context) ? 22 : 26,
                  color: inverse ? museumText : ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: sans(12, color: inverse ? museumMuted : muted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    ),
  );
}

/// Avoid downloading multi-hundred-megabyte Wikimedia originals in artwork cards.
///
/// Wikimedia's redirect endpoint chooses an available thumbnail size close to the
/// requested width and returns a browser-friendly image even when the source is a
/// TIFF. Known museum originals use the verified local copies; other URLs stay unchanged.
String optimizedArtworkImageUrl(String image, {int thumbnailWidth = 800}) {
  final museumCopy = museumArtworkImages[image];
  if (museumCopy != null) return museumCopy;
  final uri = Uri.tryParse(image);
  if (uri == null || !uri.hasAuthority) return image;

  final host = uri.host.toLowerCase();
  final isCommonsSpecial =
      host == 'commons.wikimedia.org' &&
      (uri.path.startsWith('/wiki/Special:FilePath/') ||
          uri.path.startsWith('/wiki/Special:Redirect/file/'));
  final isCommonsUpload =
      host == 'upload.wikimedia.org' &&
      uri.path.startsWith('/wikipedia/commons/');

  if (isCommonsSpecial) {
    if (uri.queryParameters.containsKey('width')) return image;
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'width': thumbnailWidth.toString(),
          },
        )
        .toString();
  }

  if (isCommonsUpload) {
    final filename = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (filename.isEmpty) return image;
    return Uri.https(
      'commons.wikimedia.org',
      '/wiki/Special:Redirect/file/$filename',
      {'width': thumbnailWidth.toString()},
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
    this.onAspectRatio,
  });
  final String image;
  final BoxFit fit;
  final String? label;
  final double? width, height;
  final ValueChanged<double>? onAspectRatio;
  Widget failure() => LayoutBuilder(
    builder: (context, constraints) {
      final small = constraints.maxWidth < 90 || constraints.maxHeight < 80;
      final dark = Theme.of(context).brightness == Brightness.dark;
      return Semantics(
        label: image.isEmpty ? '제공되는 작품 이미지 없음' : '이미지를 불러오지 못했어요',
        child: ColoredBox(
          color: dark ? museumLine : soft,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_outlined,
                  color: dark ? museumMuted : sage,
                  size: small ? 18 : 30,
                ),
                if (!small) ...[
                  const SizedBox(height: 8),
                  Text(
                    image.isEmpty ? '제공되는 작품 이미지 없음' : '이미지를 불러오지 못했어요',
                    style: sans(11, color: dark ? museumMuted : muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
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
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logicalWidth = width?.isFinite == true
              ? width!
              : constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 400.0;
          final pixels =
              logicalWidth * MediaQuery.devicePixelRatioOf(context).clamp(1, 2);
          final size = pixels <= 160
              ? 160
              : pixels <= 320
              ? 320
              : pixels <= 640
              ? 640
              : pixels <= 960
              ? 960
              : 1600;
          final resolved = image.startsWith('/')
              ? Uri.base.resolve(image).toString()
              : optimizedArtworkImageUrl(image, thumbnailWidth: size);
          Widget frame(
            BuildContext context,
            Widget child,
            int? frame,
            bool sync,
          ) {
            // Read the already decoded image; no second request or decode.
            final raw = child is Semantics ? child.child : child;
            if (onAspectRatio != null && raw is RawImage && raw.image != null) {
              final ratio = raw.image!.width / raw.image!.height;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => onAspectRatio!(ratio),
              );
            }
            return sync || frame != null
                ? child
                : ColoredBox(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? museumLine
                        : soft,
                    child: Center(
                      child: Icon(Icons.image_outlined, color: sage, size: 22),
                    ),
                  );
          }

          return asset
              ? Image.asset(
                  image,
                  width: width,
                  height: height,
                  fit: fit,
                  cacheWidth: size,
                  semanticLabel: label,
                  frameBuilder: frame,
                  errorBuilder: (_, _, _) => failure(),
                )
              : Image.network(
                  resolved,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  width: width,
                  height: height,
                  fit: fit,
                  cacheWidth: size,
                  semanticLabel: label,
                  frameBuilder: frame,
                  errorBuilder: (_, _, _) => failure(),
                );
        },
      ),
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
    this.inverse = false,
  });
  final String title, description;
  final Widget? action;
  final IconData icon;
  final bool inverse;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 62, horizontal: 20),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: inverse ? museumMuted : sage),
          const SizedBox(height: 22),
          Text(
            title,
            style: serif(21, color: inverse ? museumText : ink),
            textAlign: TextAlign.center,
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: sans(12, color: inverse ? museumMuted : muted),
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
  state.setAuthUiOpen(true);
  try {
    return await showDialog<bool>(
          context: context,
          builder: (_) => LoginDialog(state: state),
        ) ??
        false;
  } finally {
    state.setAuthUiOpen(false);
  }
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

/// Artworks and artists share one like control and one word: 좋아요.
class LikeButton extends StatelessWidget {
  const LikeButton({
    super.key,
    required this.liked,
    required this.subject,
    required this.onPressed,
    this.light = false,
    this.compactIcon = false,
  });
  final bool liked, light, compactIcon;
  final String subject;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final color = light ? museumText : ink;
    final icon = Icon(
      liked ? Icons.favorite : Icons.favorite_border,
      size: 18,
      color: liked ? likeRed : color,
    );
    final tooltip = '$subject ${liked ? '좋아요 취소' : '좋아요'}';
    if (compactIcon) {
      return IconButton(
        tooltip: tooltip,
        isSelected: liked,
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        onPressed: onPressed,
        icon: icon,
      );
    }
    return Semantics(
      label: tooltip,
      selected: liked,
      button: true,
      excludeSemantics: true,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: light ? museumLine : line),
        ),
        icon: icon,
        label: Text('좋아요', style: sans(12, color: color)),
      ),
    );
  }
}

/// Gilded picture frame: a moulded gold border around a cream mat.
class GoldFrame extends StatelessWidget {
  const GoldFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final rail = compact(context) ? 14.0 : 20.0;
    return Container(
      key: const ValueKey('gold-frame'),
      padding: EdgeInsets.all(rail),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff8a6a2c),
            Color(0xffe8c874),
            Color(0xffb08a3e),
            Color(0xfff3dc94),
            Color(0xff7d5e24),
          ],
          stops: [0, .28, .52, .76, 1],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xff5f461a), width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xff6b5020), width: 2),
        ),
        child: Container(
          padding: EdgeInsets.all(rail * .9),
          color: const Color(0xfff4efe3),
          child: child,
        ),
      ),
    );
  }
}

/// Icon-only like whose label ("작품 좋아요", "작가 좋아요") appears on hover or
/// focus, so two likes side by side stay distinguishable without extra text.
class HoverLikeButton extends StatefulWidget {
  const HoverLikeButton({
    super.key,
    required this.liked,
    required this.label,
    required this.subject,
    required this.onPressed,
    this.icon = Icons.favorite,
    this.outlineIcon = Icons.favorite_border,
  });
  final bool liked;
  final String label, subject;
  final VoidCallback? onPressed;
  final IconData icon, outlineIcon;
  @override
  State<HoverLikeButton> createState() => _HoverLikeButtonState();
}

class _HoverLikeButtonState extends State<HoverLikeButton> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final show = open || widget.liked;
    return Semantics(
      button: true,
      selected: widget.liked,
      label: '${widget.subject} ${widget.label}${widget.liked ? ' 취소' : ''}',
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => open = true),
        onExit: (_) => setState(() => open = false),
        child: Focus(
          onFocusChange: (v) => setState(() => open = v),
          child: Material(
            color: Colors.transparent,
            shape: const StadiumBorder(side: BorderSide(color: line)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.liked ? widget.icon : widget.outlineIcon,
                      size: 18,
                      color: widget.liked ? likeRed : ink,
                    ),
                    AnimatedSize(
                      duration: reduceMotion(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: show
                          ? Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                widget.label,
                                style: sans(12, height: 1.2),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> likeArtist(BuildContext context, Artist artist) =>
    followArtist(context, artist);

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

  void changeMode(bool value) {
    if (busy || signup == value) return;
    setState(() {
      signup = value;
      error = notice = null;
      password.clear();
      form.currentState?.reset();
    });
  }

  Future<void> google() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = notice = null;
    });
    try {
      await widget.state.loginWithGoogle();
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
    child: SurfaceDialog(
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
                if (firebase) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('로그인')),
                      ButtonSegment(value: true, label: Text('회원가입')),
                    ],
                    selected: {signup},
                    onSelectionChanged: busy
                        ? null
                        : (value) => changeMode(value.single),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: busy || !widget.state.canAuthenticate
                        ? null
                        : google,
                    child: const Text('Google로 계속하기'),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Google로 처음 이용하면 새 계정이 만들어져요.',
                    style: sans(10, color: muted),
                  ),
                  const SizedBox(height: 15),
                  const Divider(),
                ],
                Text(
                  signup ? '이메일로 새 계정을 만들어요.' : '이미 가입한 이메일로 로그인해 주세요.',
                  style: sans(12, color: muted),
                ),
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
                if (firebase && !signup) ...[
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
                    onPressed: busy ? null : () => changeMode(!signup),
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
  const ArtworkCard(this.art, {super.key, this.museum = false});
  final Artwork art;
  final bool museum;
  @override
  State<ArtworkCard> createState() => _ArtworkCardState();
}

class _ArtworkCardState extends State<ArtworkCard> {
  bool hover = false;
  bool focused = false;
  double? resolvedRatio;

  @override
  void didUpdateWidget(ArtworkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.art.image != widget.art.image) resolvedRatio = null;
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context), a = widget.art;
    final liked = s.likes.contains(a.id);
    final museum = widget.museum;
    final foreground = museum ? museumText : ink;
    final secondary = museum ? museumMuted : muted;
    final ratio = (resolvedRatio ?? a.imageAspectRatio ?? 1.2).clamp(.55, 2.1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: museum ? ratio : 1.10,
            child: MouseRegion(
              onEnter: (_) => setState(() => hover = true),
              onExit: (_) => setState(() => hover = false),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(museum ? 0 : 4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Semantics(
                      label: '${a.title} 작품 보기',
                      button: true,
                      child: InkWell(
                        onFocusChange: (value) =>
                            setState(() => focused = value),
                        onTap: () => context.go('/artwork/${a.id}'),
                        child: AnimatedScale(
                          scale: hover && !reduceMotion(context) ? 1.035 : 1,
                          duration: reduceMotion(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          child: ArtImage(
                            a.image,
                            label: '${s.artistName(a)}, ${a.title}',
                            fit: museum ? BoxFit.contain : BoxFit.cover,
                            onAspectRatio: museum
                                ? (value) {
                                    if (!mounted ||
                                        widget.art.image != a.image ||
                                        (value -
                                                    (resolvedRatio ??
                                                        a.imageAspectRatio ??
                                                        1.2))
                                                .abs() <
                                            .01) {
                                      return;
                                    }
                                    setState(() => resolvedRatio = value);
                                  }
                                : null,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: IconButton(
                        key: ValueKey('artwork-like-${a.id}'),
                        tooltip: '${a.title} ${liked ? '좋아요 취소' : '좋아요'}',
                        isSelected: liked,
                        iconSize: 22,
                        style: const ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                          overlayColor: WidgetStatePropertyAll(
                            Color(0x22000000),
                          ),
                          side: WidgetStatePropertyAll(BorderSide.none),
                        ),
                        constraints: const BoxConstraints(
                          minHeight: 44,
                          minWidth: 44,
                        ),
                        onPressed: s.pendingLikes.contains(a.id)
                            ? null
                            : () => likeArtwork(context, a),
                        icon: Icon(
                          liked ? Icons.favorite : Icons.favorite_border,
                          color: liked ? likeRed : Colors.white,
                          shadows: const [
                            Shadow(color: Color(0x99000000), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                    if (museum)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: AnimatedOpacity(
                              opacity: hover || focused ? 1 : 0,
                              duration: reduceMotion(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              child: ColoredBox(
                                color: museumBlack,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    '작품 보기 ↗',
                                    style: sans(11, color: museumText),
                                  ),
                                ),
                              ),
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
                  child: Text(
                    a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: sans(14, color: foreground, weight: FontWeight.w500),
                  ),
                ),
              ),
              if (!museum || !compact(context)) ...[
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      a.year,
                      style: sans(10, color: secondary),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(s.artistName(a), style: sans(12, color: secondary)),
          const SizedBox(height: 2),
          Text(
            s.artistEnglish(a),
            style: english(
              15,
              color: museum ? museumMuted : const Color(0xff929b85),
            ),
          ),
          if (museum && compact(context))
            Text(
              a.year,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sans(10, color: secondary),
            ),
          if (a.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              a.reason,
              style: sans(11, color: museum ? museumMuted : green),
            ),
          ],
        ],
      ),
    );
  }
}

class ArtworkGrid extends StatelessWidget {
  const ArtworkGrid(
    this.works, {
    super.key,
    this.maxColumns = 4,
    this.museum = false,
  });
  final List<Artwork> works;
  final int maxColumns;
  final bool museum;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth <= 0) return const SizedBox.shrink();
      if (museum) {
        final columns =
            (c.maxWidth >= 1000
                    ? 3
                    : c.maxWidth >= 340
                    ? 2
                    : 1)
                .clamp(1, maxColumns);
        final gap = columns == 1
            ? 0.0
            : c.maxWidth >= 1000
            ? 32.0
            : compact(context)
            ? 16.0
            : 24.0;
        final width = (c.maxWidth - gap * (columns - 1)) / columns;
        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: columns > 1 ? 24 : 0),
            child: Row(
              key: const ValueKey('museum-artwork-wall'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) SizedBox(width: gap),
                  SizedBox(
                    width: width,
                    child: MuseumColumnMotion(
                      column: col,
                      enabled: columns >= 3,
                      child: Column(
                        children: [
                          if (columns > 1 && works.length >= columns)
                            SizedBox(
                              height: col == 1
                                  ? (columns == 3 ? 72 : 32)
                                  : col == 2
                                  ? 24
                                  : 0,
                            ),
                          for (var i = col; i < works.length; i += columns)
                            FocusTraversalOrder(
                              order: NumericFocusOrder(i.toDouble()),
                              child: Semantics(
                                sortKey: OrdinalSortKey(i.toDouble()),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: columns == 1 ? 28 : 36,
                                  ),
                                  child: ScrollReveal(
                                    key: ValueKey(works[i].id),
                                    order: col,
                                    child: RepaintBoundary(
                                      child: ArtworkCard(
                                        works[i],
                                        museum: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
      final columns =
          (c.maxWidth > 1000
                  ? 4
                  : c.maxWidth > 680
                  ? 3
                  : c.maxWidth >= 280
                  ? 2
                  : 1)
              .clamp(1, maxColumns);
      final gap = compact(context) ? 15.0 : 25.0;
      final width = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: 32,
        children: works.indexed
            .map(
              (item) => SizedBox(
                key: ValueKey(item.$2.id),
                width: width,
                child: ScrollReveal(
                  order: item.$1 % columns,
                  child: RepaintBoundary(child: ArtworkCard(item.$2)),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}
