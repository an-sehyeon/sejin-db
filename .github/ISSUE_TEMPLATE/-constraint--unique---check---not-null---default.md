---
name: "[CONSTRAINT] Unique / Check / Not Null / Default"
about: Describe this issue template's purpose here.
title: "[CONSTRAINT]"
labels: CONSTRAINT
assignees: an-sehyeon

---

---

**이 이슈에 올릴 것:**
- “데이터 품질”을 위해 어떤 규칙을 강제하는지
- 기존 데이터가 제약을 위반하는지 여부(있으면 정리 계획)

```md
## ✅ 배경 / 목적
- (중복 방지/유효값 제한/NULL 방지 등)

## 🧾 대상
- 테이블:
- 컬럼(들):
- 제약 종류: (UNIQUE / CHECK / NOT NULL / DEFAULT / PK)

## ⚠️ 기존 데이터 영향
- 기존 데이터 위반 가능성:
  - (예: 중복 존재 여부 / NULL 존재 여부)
- 필요 시 정리/마이그레이션 계획:

## 🛠️ 적용 SQL
```sql
-- ALTER TABLE ... ADD CONSTRAINT ...
