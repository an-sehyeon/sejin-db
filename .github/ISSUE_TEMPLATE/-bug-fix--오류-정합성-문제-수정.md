---
name: "[BUG/FIX] 오류/정합성 문제 수정"
about: Describe this issue template's purpose here.
title: "[BUG/FIX]"
labels: BUG / FIX
assignees: an-sehyeon

---

---

**이 이슈에 올릴 것:**
- “무슨 문제가 있었는지(현상/재현)”가 제일 중요
- 원인(추정 가능하면)과 해결 방향
- 수정 SQL + 재발 방지 체크(테스트/검증)

```md
## 🐞 문제 현상
- 어떤 문제가 발생했나요?
- 에러 메시지/로그:
  - `...`

## 🔁 재현 방법
1)
2)
3)

## 🧠 원인 분석(가능하면)
- (예: 잘못된 타입/제약 누락/인덱스 부재/트리거 로직 오류)

## 🛠️ 해결 내용
- 변경 요약:
- 수정 SQL:
```sql
-- fix SQL
