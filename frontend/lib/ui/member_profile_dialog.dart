import 'package:flutter/material.dart';
import '../member_profile.dart';
import '../state.dart';
import 'design.dart';

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
  late final bool editing;
  String? ageRange, gender, error;
  String explanationStyle = 'standard';
  bool busy = false, closing = false;
  @override
  void initState() {
    super.initState();
    identity = widget.state.userKey;
    final profile = widget.state.memberProfile;
    editing = profile != null;
    ageRange = profile?.ageRange;
    gender = profile?.gender;
    explanationStyle = profile?.explanationStyle ?? 'standard';
    widget.state.addListener(_identityChanged);
  }

  void _identityChanged() {
    if (!mounted || closing || widget.state.userKey == identity) return;
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    widget.state.removeListener(_identityChanged);
    super.dispose();
  }

  Future<void> save({bool skip = false}) async {
    if (busy || closing || widget.state.userKey != identity) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.state.saveMemberProfile(
        skip
            ? const MemberProfile()
            : MemberProfile(
                ageRange: ageRange,
                gender: gender,
                explanationStyle: explanationStyle,
              ),
      );
      if (mounted && widget.state.userKey == identity) {
        closing = true;
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted && widget.state.userKey == identity) {
        setState(() => error = ArtlogState.message(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: closing,
    child: AlertDialog(
      backgroundColor: paper,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text('나만의 감상 취향을 알려주세요', style: serif(21)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '모두 선택 사항이에요. 나중에 감상 프로필에서 수정할 수 있어요.',
                style: sans(12, color: muted),
              ),
              const SizedBox(height: 18),
              _label('나이대 (선택)'),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  for (final entry in MemberProfile.ages.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: ageRange == entry.key,
                      onSelected: busy
                          ? null
                          : (selected) => setState(
                              () => ageRange = selected ? entry.key : null,
                            ),
                    ),
                  ChoiceChip(
                    label: const Text('응답하지 않음'),
                    selected: ageRange == null,
                    onSelected: busy
                        ? null
                        : (_) => setState(() => ageRange = null),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _label('성별 (선택)'),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  for (final entry in MemberProfile.genders.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: gender == entry.key,
                      onSelected: busy
                          ? null
                          : (selected) => setState(
                              () => gender = selected ? entry.key : null,
                            ),
                    ),
                  ChoiceChip(
                    label: const Text('응답하지 않음'),
                    selected: gender == null,
                    onSelected: busy
                        ? null
                        : (_) => setState(() => gender = null),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _label('어떤 설명이 편한가요?'),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  for (final entry in MemberProfile.styles.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: explanationStyle == entry.key,
                      onSelected: busy
                          ? null
                          : (_) => setState(() => explanationStyle = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                '프로필은 이 브라우저에만 저장돼요. 설명 스타일은 맞춤 도슨트 안내가 연결되면 적용돼요.',
                style: sans(11, color: muted),
              ),
              if (error != null)
                Text(error!, style: sans(12, color: Colors.brown)),
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
        ArtButton(
          busy ? '저장 중…' : '저장하고 시작하기',
          onTap: busy ? null : () => save(),
        ),
      ],
    ),
  );
  Widget _label(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(value, style: sans(13, weight: FontWeight.w600)),
  );
}
