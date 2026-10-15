# 목업 도슨트

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

`DocentChat.tsx`는 준비된 답변과 출처를 보여주는 초기 React 목업입니다. 실제 서버 생성·Firebase 사용자 대화 저장 검증에 사용하지 않습니다.

현재 Flutter 도슨트는 POST SSE 스트리밍, Easy/Standard/Deep, 최근 12개 메시지, 출처·라이선스, 로그인 사용자 대화 저장·복원·초기화를 지원합니다. “대화는 서버에 저장되지 않는다”는 이전 안내는 현재 실제 모드에 적용되지 않습니다.

생성 중 중복 요청을 막고 SSE 미지원에만 JSON으로 전환합니다. 중간 실패는 자동 재전송하지 않습니다. 프론트의 실제 API 모드에는 주제별 1차 차단이 없습니다.

## 현재 Flutter 구현

- [현재 도슨트 UI](../../../lib/ui/docent_chat.dart)
- [대화 상태](../../../lib/docent_conversation.dart)
- [SSE·API](../../../lib/api/artlog_api.dart)
