import '../models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../state.dart';
import '../member_profile.dart';
import '../ui/design.dart';
import '../ui/profile_preferences.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => PageWidth(
    vertical: 36,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/library'),
          icon: const Icon(Icons.arrow_back, size: 17),
          label: const Text('내 피드'),
        ),
        const SizedBox(height: 20),
        if (ArtlogScope.of(context).authenticated)
          const _ProfileSettings()
        else
          EmptyView(
            '로그인 후 감상 설정을 관리할 수 있어요.',
            action: ArtButton('로그인', onTap: () => ensureLogin(context)),
          ),
      ],
    ),
  );
}

class _ProfileSettings extends StatefulWidget {
  const _ProfileSettings();
  @override
  State<_ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<_ProfileSettings> {
  MemberProfile? draft;
  bool busy = false;
  String? error;
  int formRevision = 0;
  Future<void> save() async {
    final s = ArtlogScope.of(context),
        identity = ArtlogScope.of(context).userKey;
    final p = draft ?? s.memberProfile ?? const MemberProfile();
    if (p.birthDate != null) {
      final d = DateTime.tryParse(p.birthDate!);
      if (d == null ||
          dateKey(d) != p.birthDate ||
          d.year < 1900 ||
          p.birthDate!.compareTo(seoulDate()) > 0) {
        setState(() => error = '생년월일을 YYYY-MM-DD로 확인해 주세요.');
        return;
      }
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await s.saveMemberProfile(p);
      if (mounted && identity == s.userKey) {
        setState(() => draft = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('감상 설정을 저장했어요.')));
      }
    } catch (e) {
      if (mounted) setState(() => error = ArtlogState.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ArtlogScope.of(context);
    if (!s.config.demo && !s.profileLoaded) {
      return EmptyView(
        s.profileError ?? '설정을 불러오고 있어요.',
        action: s.profileError == null
            ? null
            : ArtButton('다시 불러오기', onTap: s.loadProfile),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SurfacePanel(
          padding: EdgeInsets.all(compact(context) ? 18 : 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('나에게 맞는 감상', style: serif(25)),
              const SizedBox(height: 10),
              Text(
                s.config.demo
                    ? '미리보기 설정은 이 브라우저에 저장돼요.'
                    : '생년월일은 비공개이며 AI에 전달하지 않아요. 이야기 순서와 말투는 맞춤 안내에 사용해요.',
                style: sans(12, color: muted),
              ),
              const SizedBox(height: 28),
              ProfilePreferences(
                key: ValueKey(formRevision),
                initial: s.memberProfile ?? const MemberProfile(),
                enabled: !busy,
                onChanged: (p) => draft = p,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    error!,
                    style: sans(12, color: Colors.red.shade800),
                  ),
                ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ArtButton(
                    busy ? '저장 중…' : '설정 저장',
                    onTap: busy ? null : save,
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            draft = null;
                            error = null;
                            formRevision++;
                          }),
                    child: const Text('변경 취소'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
