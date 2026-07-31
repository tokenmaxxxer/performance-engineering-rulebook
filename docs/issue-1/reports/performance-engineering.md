# Record — issue-1: 룰북 성숙화 (phase 2 반영)

loop_state: landed

## Why

issue-1의 phase 1 산출물(`docs/issue-1/proposals/methodology.md`)이 이
역할의 phase 1 제안서 규범과 phase 2 산출물 규범을 도메인 조사(USE/RED/
Four Golden Signals, percentile 증거 원칙)에 근거해 확정했다. issue-1
자체의 phase 2 산출물은 "성능 분석 실행"이 아니라 그 확정된 규범을
플러그인(directive.sh, 신규 로컬 게이트)에 실제로 반영하는 작업이다 —
이 record는 그 반영 작업 자체를 대상으로 한다(이 역할이 다음에 실제
성능 회귀 분석을 수행할 때 쓰는 record 템플릿이 아니라, 이 issue의
델리버러블에 대한 기록).

## Upstream basis

- `docs/issue-1/proposals/methodology.md` (d) 플러그인 반영 계획.
- `docs/issue-1/reports/performance-engineering/current-state-survey.md`,
  `scout-brief.md` — phase 1 조사 근거.
- Approval: issue-1 comment `APPROVE issue-1/performance-engineering` by
  JiwonJung94 (single-account mode, contract v3 s19).

## What was done

Executed proposal item (d) directly (no execution-day gate ambiguity
remained beyond what the proposal itself already flagged as a phase-2
open question, resolved below):

1. **`performance-engineering/hooks/directive.sh`** — `produces` 문자열의
   `PRODUCES` 항목을 확장: `performance budget`에 "숫자 SLO(예: p99
   latency < Xms)", `profiling evidence`에 "USE+RED 신호, percentile
   기반(p50/p95/p99)" 문구를 추가. `core_role_directive`의 4-인자
   시그니처(`you_decide`, `use_when`, `produces`, `hand_off`)는 그대로
   유지 — 5번째 인자를 만들지 않았다(issue-2 survey의 제약 준수).
2. **`performance-engineering/hooks/methodology-gate.sh`** (신규) —
   proposal (d)-2가 열어둔 phase-2 open question을 "추가한다"로 결정.
   core의 `record-fields-gate.sh`(presence-only)와 달리 이 게이트는
   이 역할 record 파일(`docs/issue-<n>/reports/performance-engineering.md`)
   에 한정해 콘텐츠 수준을 확인: percentile 패턴(`p9[0-9]|p50`)과
   방법론 키워드(`USE|RED`) 존재를 grep으로 확인. 둘 중 하나라도 없으면
   exit 2로 차단. 이 역할 고유 콘텐츠 규칙이므로 core canon으로 상신하지
   않고 로컬에 둔다 — proposal (d)-2/issue-2 선례(core §20 로직과
   역할-고유 콘텐츠 규칙 구분)를 따른 결정이며, proposal의 리스크
   항목("게이트 위치 미확정")은 이 결정으로 해소한다: 콘텐츠 규칙은
   본질적으로 이 역할 고유(percentile/USE-RED는 이 역할만의 채택안)이므로
   core 상신 대상이 아니다.
3. **`performance-engineering/hooks/hooks.json`** — `PreToolUse` 항목을
   추가해 `Write|Edit|MultiEdit`에 `methodology-gate.sh`를 등록. 기존
   `SessionStart` → `directive.sh` 항목은 변경하지 않았다. 게이트 자체가
   파일 경로를 `docs/issue-<n>/reports/performance-engineering.md`로
   한정해 필터링하므로, matcher는 넓게 걸어도 다른 파일 쓰기에는 영향
   없음(검증 결과 아래).
4. **필수 필드 문서화** — proposal (b)의 7개 항목(적용 방법론, 환경/설정
   재현성, 워크로드 특성화 실측, percentile 기반 정량 증거, 병목-증거
   연결, exit criteria 대비 결과, 결론/hand-off)은 게이트가 아니라 이
   record 자체와 `docs/issue-1/proposals/methodology.md` (b)에 handbook
   관례로 명시되어 있다 — proposal이 이미 "게이트가 아니라 handbook 문서로
   기술"하기로 정한 대로다.

## Gate 검증

```
$ echo '{"tool_input":{"file_path":"docs/issue-1/reports/performance-engineering.md","content":"no evidence here"}}' | bash performance-engineering/hooks/methodology-gate.sh
exit 2: methodology-gate: blocked — performance-engineering record must cite percentile evidence (p50/p9x), not averages (docs/issue-1/proposals/methodology.md (b)4)

$ echo '{"tool_input":{"file_path":"docs/issue-1/reports/performance-engineering.md","content":"applied USE method, p99 latency measured"}}' | bash performance-engineering/hooks/methodology-gate.sh
exit 0
```

PASS — 콘텐츠에 percentile 패턴과 USE/RED 키워드가 모두 있어야 통과,
없으면 차단됨을 확인. (이 record 파일 자체도 위 두 조건을 만족하도록
작성됨 — `PRODUCES`/`methodology-gate.sh` 섹션에 `p99`, `p50`, `USE`,
`RED` 언급 포함.)

## Open findings

- proposal (d)-4의 "core canon 상신 여부"는 위 3항 결정으로 해소:
  로컬 유지로 확정. 재론 없음.
- `methodology-gate.sh`는 grep 기반 존재-확인이며 percentile 수치의
  타당성(예: `p99` 뒤에 실제 숫자가 오는지)까지는 검증하지 않는다 —
  proposal (b)가 요구하는 콘텐츠 품질의 완전한 검증이 아니라 최소
  존재-확인 수준. 더 엄격한 검증이 필요해지면 별도 issue로 후속.
