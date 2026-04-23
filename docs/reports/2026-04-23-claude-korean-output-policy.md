# 2026-04-23 — 한국어 산출물 정책 추가 + CLAUDE.md 슬림화

- **Date**: 2026-04-23
- **Worktree (수행)**: claude
- **Worktree (영향)**: all (AIDLC 를 사용하는 모든 세션)
- **Role**: claude

## Request

사용자 지시 2건 (2026-04-23, AIDLC migration 직후):

1. > 다만 나는 명령은 한국어로 할거고, 그 작업결과 산출물 문서도 한국어로 작성되어야 해. 중간에 너가 작업할때만 영어로 진행해.

2. > 그런데 claude.md 가 너무 큰거 아냐? 원래 ai-dlc 는 크기가 얼마야?

   → 선택지 제시 후 사용자 선택: "슬림화 (권장)" — CLAUDE.md 를 ~150줄 수준으로 감축.

## Root cause / Context

AIDLC 워크플로우는 원본이 영어로 작성되어 있고, core-workflow / common / inception / construction / operations / extensions 의 rule 파일이 전부 영어다. 별도 지시가 없으면 AI 가 stage 완료 메시지·requirements·user-stories 등을 영어로 그대로 작성할 가능성이 높다. 사용자는 한국어권 팀·병원 파일럿 이해관계자와 직접 공유 가능한 한국어 산출물을 요구하므로, AIDLC 파이프라인이 생성하는 문서류를 **기본 한국어**로 강제해야 한다.

동시에 upstream rule 파일·코드 식별자·에러 코드는 영어로 유지해야 기술적 정합성과 upstream drift 방지가 된다.

## Actions

### 1. 메모리 저장
- `~/.claude/projects/-Users-yumunsang-haeda/memory/feedback_korean_output.md` 신규. 산출물별 언어 테이블·예외 규칙 포함.
- `MEMORY.md` 인덱스에 한 줄 추가.

### 2. CLAUDE.md Haeda Addendum 에 "언어 정책" 섹션 추가 (1차 편집)
- 위치: `## Project Context` 직후, `## Code Paths` 앞.
- 내용:
  - 한국어로 작성해야 하는 산출물 목록 (aidlc-docs/inception/**, construction/**, audit.md, docs/reports/**, stage 완료 메시지, 질문 파일, commit 메시지, PR)
  - 영어로 유지해야 하는 것 (`.aidlc-rule-details/**` upstream, CLAUDE.md upstream-embed 섹션, 코드 식별자, 에러 코드, 섹션 헤더)
  - 내부 작업은 영어 허용 (shell 명령, 경로, 디버그 로그, reasoning)
  - `haeda-domain-context` DOMAIN-01 과의 관계 설명 (코드 레벨 vs 문서 레벨, 상보적)
  - 위반 시 blocking finding 처리 방식
- 1차 편집 후 파일 크기: 619 → 661 lines (+42)

### 3. CLAUDE.md 슬림화 (2차 편집)
사용자 질문 "CLAUDE.md 가 너무 큰 거 아냐?" 에 대한 대응. 선택지 제시 → "슬림화 (권장)" 선택.

**원리**: AIDLC upstream 의 core-workflow.md 539 lines 를 CLAUDE.md 에 inline 하는 대신, 별도 파일 (`.aidlc-rule-details/core-workflow.md`) 로 참조. CLAUDE.md 는 entry point + 요약 + Haeda addendum 만 유지.

**제거**:
- Inception Phase / Construction Phase / Operations Phase 전체 stage 상세 설명 (core-workflow.md 로 이관된 내용)
- Audit Log Format / Plan-Level Checkbox Enforcement 상세 (요약만 유지)
- Directory Structure ASCII 박스 상세 (간결 버전으로 압축)

**유지·강화**:
- Entry point 의무 (core-workflow.md 를 읽으라는 명시적 지시)
- Phase Overview 표 (한눈에 보는 stage 순서)
- Extensions loading 원칙 + always-enforced 4개 테이블
- Plan checkbox / content validation / audit append-only 요약
- Haeda addendum 전체 (언어 정책, retained utilities, deprecated infra, worktree, git, rollback)

**결과 크기**: 661 → **162 lines** (-75.5%, migration 전 43 lines 의 3.8배 규모).

### 4. Commit + PR + Merge
- Commit message: 한국어 (본 정책의 첫 적용)
- PR 제목·본문: 한국어

## Verification

### 변경 사항 확인

```bash
$ wc -l CLAUDE.md
162 CLAUDE.md

$ grep -n "언어 정책\|Language Policy" CLAUDE.md
111:## 언어 정책 (Language Policy) — MANDATORY
# (섹션이 Haeda Addendum 안에 유지되어 있음)

$ grep -n "core-workflow.md" CLAUDE.md
14:1. Read `.aidlc-rule-details/core-workflow.md` — the full workflow specification
```

### 크기 비교

| 버전 | Lines | 비고 |
|-----|-------|------|
| pre-AIDLC | 43 | Haeda 규칙 인덱스 |
| AIDLC migration 직후 | 619 | upstream core-workflow 전체 embed |
| 언어 정책 추가 후 | 661 | +42 |
| 슬림화 후 (현재) | **162** | core-workflow.md 참조로 전환, Haeda addendum 유지 |

### 적용 시점

이번 커밋 자체부터 정책 적용:
- 이 보고서 (`2026-04-23-claude-korean-output-policy.md`) — 한국어 ✅
- 커밋 메시지 — 한국어 예정 ✅
- PR 제목·본문 — 한국어 예정 ✅

다음 세션부터 AIDLC 워크플로우가 생성하는 모든 산출물에 적용.

## Follow-ups

1. **Phase 6 reverse-engineering 실행 시점** — 한국어로 요구사항·애플리케이션 설계가 생성되는지 관찰. 영어로 기본 출력하려 하면 stage 재실행.
2. **haeda-domain-context extension 업데이트 고려** — 본 정책을 extension 에 녹일지, CLAUDE.md 만 유지할지는 1-2주 운영 후 결정. 현재는 CLAUDE.md 가 더 먼저 로드되므로 중복 불필요.
3. **스테이지 완료 메시지 템플릿** — 필요 시 upstream 파일 일부를 오버라이드하는 별도 extension (`haeda-language-policy`) 신설 가능. 마찰이 관찰되면 그 때 작업.

## Related

- **선행 작업**: `docs/reports/2026-04-23-claude-aidlc-migration.md` — AIDLC 전면 도입
- **관련 extension**: `.aidlc-rule-details/extensions/haeda-domain-context/haeda-domain-context.md` (DOMAIN-01)
- **메모리**: `~/.claude/projects/-Users-yumunsang-haeda/memory/feedback_korean_output.md`
