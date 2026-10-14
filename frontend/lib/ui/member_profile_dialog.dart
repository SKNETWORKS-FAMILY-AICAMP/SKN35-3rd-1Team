import '../models.dart';
import 'package:flutter/material.dart';
import '../member_profile.dart';
import '../state.dart';
import 'design.dart';
import 'profile_preferences.dart';

Future<void> showMemberProfile(BuildContext context, ArtlogState state) async {
  if (!state.authenticated) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => MemberProfileDialog(state: state),
  );
}

class MemberProfileDialog extends StatefulWidget {
  const MemberProfileDialog({super.key, required this.state});
  final ArtlogState state;
  @override
  State<MemberProfileDialog> createState() => _MemberProfileDialogState();
}

class _MemberProfileDialogState extends State<MemberProfileDialog> {
  late final String identity;
  late final bool editing =
      widget.state.memberProfile?.onboardingCompleted == true;
  late MemberProfile draft =
      widget.state.memberProfile ?? const MemberProfile();
  int step = 0;
  bool busy = false, closing = false;
  String? error;
  @override
  void initState() {
    super.initState();
    identity = widget.state.userKey;
    widget.state.addListener(identityChanged);
  }

  void identityChanged() {
    if (!mounted || closing || identity == widget.state.userKey) return;
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    widget.state.removeListener(identityChanged);
    super.dispose();
  }

  Future<void> save({bool skip = false}) async {
    if (busy || closing || identity != widget.state.userKey) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!skip && draft.birthDate != null) {
        final d = DateTime.tryParse(draft.birthDate!);
        if (d == null ||
            dateKey(d) != draft.birthDate ||
            d.year < 1900 ||
            draft.birthDate!.compareTo(seoulDate()) > 0) {
          throw const FormatException('생년월일을 확인해 주세요.');
        }
      }
      await widget.state.saveMemberProfile(
        skip ? const MemberProfile() : draft,
      );
      if (mounted && identity == widget.state.userKey) {
        closing = true;
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = ArtlogState.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: closing,
    child: SurfaceDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: Text(editing ? '감상 프로필' : '나만의 감상 취향을 알려주세요', style: serif(22)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!editing) ...[
                Text('취향을 알면, 그림과 조금 더 가까워져요.', style: sans(13, color: muted)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: i <= step ? green : line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${step + 1} / 3 · ${['나에 대해', '이야기 순서', '대화 스타일'][step]}',
                  style: sans(11, color: muted),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                '모두 선택 사항이에요. 나중에 마이페이지 설정에서 바꿀 수 있어요.',
                style: sans(11, color: muted),
              ),
              const SizedBox(height: 18),
              ProfilePreferences(
                key: ValueKey(step),
                initial: draft,
                enabled: !busy,
                section: editing ? null : step,
                onChanged: (p) => draft = p,
              ),
              Text(
                widget.state.config.demo
                    ? '미리보기에서는 이 브라우저에만 저장돼요.'
                    : '설정은 로그인한 계정에 저장돼요. 생년월일은 AI에 전달하지 않아요.',
                style: sans(11, color: muted),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: sans(12, color: Colors.red.shade800),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy
              ? null
              : () {
                  if (editing) {
                    closing = true;
                    Navigator.pop(context);
                  } else {
                    save(skip: true);
                  }
                },
          child: Text(editing ? '취소' : '건너뛰기'),
        ),
        if (!editing && step > 0)
          TextButton(
            onPressed: busy ? null : () => setState(() => step--),
            child: const Text('이전'),
          ),
        ArtButton(
          busy
              ? '저장 중…'
              : editing
              ? '설정 저장'
              : step == 2
              ? '저장하고 시작하기'
              : '다음',
          onTap: busy
              ? null
              : () {
                  if (!editing && step < 2) {
                    setState(() => step++);
                  } else {
                    save();
                  }
                },
        ),
      ],
    ),
  );
}
