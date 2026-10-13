import '../models.dart';
import 'package:flutter/material.dart';
import '../member_profile.dart';
import 'design.dart';

class ProfilePreferences extends StatefulWidget {
  const ProfilePreferences({
    super.key,
    required this.initial,
    required this.onChanged,
    this.enabled = true,
    this.section,
  });
  final MemberProfile initial;
  final ValueChanged<MemberProfile> onChanged;
  final bool enabled;
  final int? section;
  @override
  State<ProfilePreferences> createState() => _ProfilePreferencesState();
}

class _ProfilePreferencesState extends State<ProfilePreferences> {
  late final TextEditingController birth = TextEditingController(
    text: widget.initial.birthDate ?? '',
  );
  late List<String> priorities = List.of(widget.initial.priorities);
  late String style = widget.initial.conversationStyle;
  String? dateError;
  @override
  void dispose() {
    birth.dispose();
    super.dispose();
  }

  void changed() {
    widget.onChanged(
      MemberProfile(
        birthDate: birth.text.trim().isEmpty ? null : birth.text.trim(),
        priorities: List.of(priorities),
        explanationStyle: style == 'professional' ? 'deep' : 'easy',
        onboardingCompleted: true,
      ),
    );
  }

  bool validDate(String value) {
    if (value.isEmpty) return true;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final d = DateTime.tryParse(value);
    return d != null &&
        dateKey(d) == value &&
        d.year >= 1900 &&
        value.compareTo(seoulDate()) <= 0;
  }

  Future<void> pickDate() async {
    final now = DateTime.parse(seoulDate());
    final d = await showDatePicker(
      context: context,
      initialDate: validDate(birth.text) && birth.text.isNotEmpty
          ? DateTime.parse(birth.text)
          : DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: '생년월일 선택',
    );
    if (d != null && mounted) {
      setState(() {
        birth.text = dateKey(d);
        dateError = null;
      });
      changed();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.section == null || widget.section == 0) ...[
        Text('생년월일', style: sans(15, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          '선택 사항이에요. 정확한 생년월일은 다른 이용자에게 공개되지 않아요.',
          style: sans(12, color: muted),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('profile-birth-date'),
          controller: birth,
          enabled: widget.enabled,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            labelText: '생년월일 (선택)',
            hintText: 'YYYY-MM-DD',
            errorText: dateError,
            suffixIcon: IconButton(
              tooltip: '달력에서 선택',
              onPressed: widget.enabled ? pickDate : null,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ),
          onChanged: (v) {
            setState(
              () =>
                  dateError = validDate(v) ? null : '날짜를 YYYY-MM-DD로 확인해 주세요.',
            );
            changed();
          },
        ),
        const SizedBox(height: 26),
      ],
      if (widget.section == null || widget.section == 1) ...[
        Text('어떤 이야기부터 들을까요?', style: sans(15, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          '위에 있는 항목부터 우선해서 설명해요. 화살표로 순서를 바꿔 보세요.',
          style: sans(12, color: muted),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < priorities.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassSurface(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: green.withValues(alpha: .1),
                    child: Text('${i + 1}', style: sans(12, color: green)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      MemberProfile.priorityLabels[priorities[i]]!,
                      style: sans(13),
                    ),
                  ),
                  IconButton(
                    tooltip:
                        '${MemberProfile.priorityLabels[priorities[i]]} 우선순위 올리기',
                    onPressed: !widget.enabled || i == 0
                        ? null
                        : () {
                            setState(() {
                              final v = priorities.removeAt(i);
                              priorities.insert(i - 1, v);
                            });
                            changed();
                          },
                    icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                  ),
                  IconButton(
                    tooltip:
                        '${MemberProfile.priorityLabels[priorities[i]]} 우선순위 내리기',
                    onPressed: !widget.enabled || i == priorities.length - 1
                        ? null
                        : () {
                            setState(() {
                              final v = priorities.removeAt(i);
                              priorities.insert(i + 1, v);
                            });
                            changed();
                          },
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 26),
      ],
      if (widget.section == null || widget.section == 2) ...[
        Text('어떤 대화가 편한가요?', style: sans(15, weight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (final option in [
          (
            'easy',
            Icons.chat_bubble_outline,
            '편안하고 쉬운 대화',
            '일상적인 말과 짧은 예시로 함께 감상해요.',
          ),
          (
            'professional',
            Icons.auto_stories_outlined,
            '전문용어 적극 사용',
            '회화 용어와 분석을 더 깊이 살펴봐요.',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: widget.enabled
                  ? () {
                      setState(() => style = option.$1);
                      changed();
                    }
                  : null,
              style:
                  crystalButtonStyle(
                    tinted: style == option.$1,
                    radius: 22,
                    padding: const EdgeInsets.all(18),
                  ).copyWith(
                    side: WidgetStatePropertyAll(
                      BorderSide(
                        color: style == option.$1
                            ? green.withValues(alpha: .65)
                            : Colors.white,
                      ),
                    ),
                  ),
              child: Row(
                children: [
                  Icon(option.$2, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.$3,
                          style: sans(13, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(option.$4, style: sans(11, color: muted)),
                      ],
                    ),
                  ),
                  if (style == option.$1)
                    const Icon(Icons.check_circle, size: 20, color: green),
                ],
              ),
            ),
          ),
      ],
    ],
  );
}
