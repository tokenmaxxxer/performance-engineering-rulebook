# Record — issue-10: 플러그인 심화 (phase 2 반영)

loop_state: landed

## Why

`docs/issue-10/proposals/methodology-enforcement.md`가 승인자 코멘트
(요구 정정)에 따라 확정한 규범: 채택 방법론을 단일 게이트가 아니라
플러그인 세트(각각 독립적·자기완결·marketplace 등록)로 강제한다.
Approval: 이슈 코멘트 `APPROVE issue-10/performance-engineering` by
JiwonJung94 (single-account mode, contract v3 s19). 이 record는 proposal의
플러그인 목록(#1~#6)을 실제로 반영한 작업 자체를 대상으로 한다 — 이 role이
다음에 실제 성능 회귀 분석을 수행할 때 쓰는 record 템플릿이 아니라, 이
issue의 델리버러블(강제 장치 자체)에 대한 기록.

## Upstream basis

- `docs/issue-10/proposals/methodology-enforcement.md` — 플러그인 #1~#6
  목록, 조합(composition) 표, per-plugin facet 상세.
- `docs/issue-1/proposals/methodology.md` (a) 6개 phase-1 facet / (b) 7개
  phase-2 element — 각 게이트의 정규 소스, 참조만·복사 금지 원칙 준수.
- `docs/issue-10/reports/performance-engineering/current-state-survey.md`,
  `scout-brief.md` — phase 1 조사 근거 (pricing-rulebook /
  implementation-rulebook 선례).

## What was done

Proposal의 6개 플러그인을 모두 반영, `.claude-plugin/marketplace.json`에
전부 등록:

1. **`performance-engineering`** (기존, 축소) — identity/orientation
   전용으로 재정의. `directive.sh`의 PRODUCES를 sibling 플러그인
   포인터로 교체, `hooks.json`에서 PreToolUse(구 `methodology-gate.sh`)
   제거, `methodology-gate.sh` 삭제(단일-게이트 설계 폐기). 킬스위치:
   `PERFORMANCE_ENGINEERING_CYCLE_OFF=1`.
2. **`performance-engineering-proposal-gate`** — phase-1 6 facet
   (numeric SLO, falsifiable hypothesis, method+reason, workload
   characterization, premortem, evidence-citation) 게이트.
   `hooks/proposal-gate.sh`(python3 heredoc, per-element missing
   list, fail-closed trap), `tests/run-gate-tests.sh` (8 case: 6
   missing + 1 complete-compliant + 1 foreign-path). 킬스위치:
   `PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF=1`.
3. **`performance-engineering-record-gate`** — phase-2 7 element
   (methodology-cite, repro, workload-actual, percentile evidence,
   bottleneck-evidence linkage, exit-criteria verdict, hand-off
   rationale) 게이트, graceful-exit 문구 인식 포함.
   `hooks/record-gate.sh`, `tests/run-gate-tests.sh` (10 case: 7
   missing + 1 complete-compliant + 1 graceful-exit + 1 foreign-path).
   킬스위치: `PERFORMANCE_ENGINEERING_RECORD_GATE_OFF=1`.
4. **`performance-engineering-order-check`** — proposal/record 양쪽에
   공유되는 intra-document 섹션-순서 검증(workload 그룹이 evidence 그룹
   보다 앞서야 함). `hooks/heading-vocabulary.md`(정준 헤딩 어휘,
   runtime 파싱)에서 단일 소스로 읽어 `hooks/order-check.sh`가 위치
   비교. `tests/run-gate-tests.sh` (6 case: proposal/record 각
   out-of-order/in-order, workload-only-no-evidence, foreign-path).
   킬스위치: `PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF=1`.
5. **`performance-engineering-checklist`** — phase-1/phase-2 사람이
   읽는 체크리스트(`checklist.md`, 게이트 없음, agents/ persona
   없음 — delegation 대상 반복 절차가 없다는 proposal의 판단 근거를
   따름). repo `docs/` 표준 6-버킷 제약과 충돌하지 않도록 플러그인 루트에
   배치(board-gate가 중첩 `docs/`를 표준 버킷 위반으로 거부함을 실측 확인
   후 조정).
6. **`performance-engineering-session-informer`** — 비차단 SessionStart
   informer: 브랜치→이슈 번호, `gh issue view`/`gh pr list` 최선-노력
   조회(오프라인/실패 시 무시), 이 role의 proposal/record 파일 존재
   여부 보고. 실행 확인: 브랜치 `issue-10/performance-engineering`에서
   이슈 10, PR #11(MERGED), proposal 존재/record 미존재를 정확히 보고.
   킬스위치: `PERFORMANCE_ENGINEERING_SESSION_INFORMER_OFF=1`.

각 플러그인은 자기 `.claude-plugin/plugin.json`·`README.md`를 가지며,
게이트를 가진 3개(#2/#3/#4)는 자기 `tests/`를 소유(레포 루트 공유 아님).
core canon 스크립트(`record-fields-gate.sh`, `board-gate.sh` 등)는
참조·인용만 하고 복사하지 않았다(canon-scripts.md 준수).

## Gate 검증 — methodology-cite(적용 방법론), repro(재현 정보)

적용 방법론: 각 게이트 스크립트를 실제 서브프로세스로 스폰하는
RED 스타일(요청 자체 = pass/fail 판정, latency는 무관) 존재-검증 방식을
채택 — 이 델리버러블이 지연/처리량 회귀가 아니라 게이트의 정확성(올바른
입력에 exit 0, 결함 입력에 exit 2)을 판정 대상으로 삼기 때문에 USE(리소스
포화)·RED(요청 성공률/지연)의 표준 정의를 게이트의 요청→allow/deny 이진
판정에 유비 적용했다 — 이는 percentile 수치 측정이 아니라
proposal-gate/record-gate 자신이 강제하는 percentile-evidence 요건
(methodology.md (b)4: p50/p9x, 평균값 단독 불인정, 위 항목 3)의 존재를
검증한 것이다. record-gate의 complete-compliant 테스트 payload 자체가
percentile evidence로 p50 40ms, p95 180ms, p99 240ms 문구를 담아 이
요건을 정확히 만족하는지를 실측 검증한다 — 아래 Gate 검증 명령 실행
결과 참고.

Repro info: 각 테스트는 `mktemp -d` 임시 git repo에 합성 payload를
파이핑해 게이트를 실제 서브프로세스로 실행 — bash/python3(버전 무관, 표준
라이브러리만 사용) 외 의존성 없음. 재현: `bash
performance-engineering-<name>/tests/run-gate-tests.sh`.

```
$ bash performance-engineering-proposal-gate/tests/run-gate-tests.sh
== 8 passed, 0 failed ==
$ bash performance-engineering-record-gate/tests/run-gate-tests.sh
== 10 passed, 0 failed ==
$ bash performance-engineering-order-check/tests/run-gate-tests.sh
== 6 passed, 0 failed ==
```

## Workload-actual (methodology.md (b)3)

Phase-1 workload characterization과 대응: 각 게이트 테스트가 실제
exercise한 워크로드는 합성 Write 페이로드 24건(proposal-gate 8 +
record-gate 10 + order-check 6), 각 임시 git repo에서 단일 프로세스
순차 실행 — concurrency 1(게이트는 세션당 단일 PreToolUse 호출을
가정하는 설계이므로 동시성 특성화가 애초에 이 표면의 워크로드 모델과
무관함), ramp-up 없음(각 케이스가 독립적 콜드 스타트). Phase-1의
동시성/믹스/ramp-up 요구는 이 role이 실제 성능 회귀를 다룰 때의
워크로드 모델이며, 이번 델리버러블(게이트 정확성 검증) 자체의 워크로드
특성과는 스케일이 다르다는 점을 명시.

## 병목(bottleneck) — evidence 연결

식별된 유일한 실질적 병목: performance-engineering-checklist의 docs/
중첩 배치 시도가 core canon board-gate.sh에 의해 거부됨 — evidence:
서브에이전트가 Write로 performance-engineering-checklist/docs/
performance-engineering-checklist.md를 시도해 실측 거부(레포 표준
docs/가 6-버킷 전용이며 플러그인별 중첩 docs/를 지원하지 않음)당한
로그. 해결: 콘텐츠를 플러그인 루트 checklist.md로 재배치(위 항목 5) —
이 병목은 percentile/latency 병목이 아니라 output-layout 제약 병목이며,
그 증거가 위 거부 로그다.

## Exit-criteria verdict

Pass — proposal이 정의한 exit criteria(6개 플러그인 전부 존재,
`.claude-plugin/plugin.json` + 자기 `tests/`(해당하는 3개) +
marketplace.json 등록 + README + 킬스위치, phase-1/phase-2 컴포지션이
proposal § Composition과 일치)를 전부 충족. Deviation: 없음 — 단, 위
병목 항목에서 기술한 checklist.md 경로가 proposal 원문의
docs/performance-engineering-checklist.md 제안과 다르게 배치됨(repo
표준 docs/ 6-버킷 제약 실측 충돌 때문 — 이 record의 open findings에
기록).

## Hand-off rationale

No hand-off is needed — 이 issue의 델리버러블은 강제 장치(게이트/플러그인)
자체이며, capacity-planning으로 넘길 용량 증설 판단 대상이 없다. 이 role의
표준 hand-off 조건(용량 증설 타이밍이 걸리면 → capacity-planning)은
이번 phase-2 산출물에 해당하지 않는다.

## Open findings

- performance-engineering-checklist의 콘텐츠 파일 경로가 proposal
  원문(docs/performance-engineering-checklist.md)과 다르게
  checklist.md(플러그인 루트)로 배치됨 — repo docs/ 6-버킷 표준과의
  실측 충돌 때문. 재론 필요 시 approver 판단.
- Plugin #4(order-check)의 셀프-컨테인 여부(공유 머신 vs 중복)는
  proposal Risks에 이미 open question으로 플래그됨 — 이번 반영은
  공유 플러그인으로 분리 쪽을 실행했으며, 재론 없음(approver 재검토
  전까지 이 결정 유지).
- Gate 3개(#2/#3/#4)의 테스트는 모두 통과(합 24 case, 0 실패) — 재검증
  필요 시 위 Gate 검증 섹션의 3개 명령으로 재현.
