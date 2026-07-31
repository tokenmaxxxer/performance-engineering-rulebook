# Proposal: performance-engineering 도메인 방법론 채택 — 제안서/산출물 규범

Subject: issue-1
Status: phase 1 (survey + proposal) — no execution in this PR; phase 2
opens only after an approvers.md Approve per contract v3 s19.

See `docs/issue-1/reports/performance-engineering/current-state-survey.md`
(현재 directive.sh/gate 상태) and
`docs/issue-1/reports/performance-engineering/scout-brief.md`
(교과서·업계표준·SLO 실무 관행 조사, 3-angle 병렬 스윕)
for the evidence base this proposal draws on.

## (a) 제안서 규범 — phase 1 문서의 방법론·필수 섹션·근거 형식

**채택 방법론**: 제안서는 "진단 방법론을 명시적으로 선언"하는 절차를 따른다
— ad hoc 추측이 아니라 USE method(자원 중심: Utilization/Saturation/
Errors)와 RED method(요청 중심: Rate/Errors/Duration), 또는 그 둘을 합친
SRE의 Four Golden Signals 중 이 변경에 적합한 것을 골라 **이름을 명시**한다.

phase 1 제안서 필수 섹션:

1. **목표(SLO/성능 예산)** — 숫자로 표현된 목표(예: p99 latency < Xms,
   처리량 >= Y rps). "더 빠르게"처럼 비수치 목표는 불완전한 것으로 간주.
2. **가설** — 병목에 대한 반증 가능한 가설 (예: "DB connection pool이
   X rps에서 포화된다"), 기존 텔레메트리에 근거.
3. **방법론** — 가설을 검증할 기법과 그 선택 이유 (USE/RED/워크로드
   특성화 중 무엇을, 왜 이 시스템·변경에 적합한지).
4. **워크로드 특성화** — 동시성/트랜잭션 믹스/ramp-up 등, 결론이 워크로드에
   의존함을 전제로 어떤 부하 조건을 검증 대상으로 삼는지 명시.
5. **위험/롤백(premortem)** — 회귀·장애를 가정하고 blast-radius 제한,
   킬스위치, 롤백 절차를 사전 서술.
6. **근거 형식** — 모든 외부 근거는 출처(문헌/표준/URL)를 명시. 근거 없는
   "업계 관행"류 주장은 가정으로 명시하거나 제외한다(이 제안서 자체가
   이 규칙을 스스로 지켜 작성됨).

## (b) 산출물 규범 — phase 2 딜리버리의 방법론·필수 구성요소

phase 2 record (`docs/issue-<n>/reports/performance-engineering.md`)는
아래를 필수 구성요소로 포함해야 한다:

1. **적용한 방법론 명시** — USE/RED/Four Golden Signals 중 실제 사용한
   것과 각 신호의 측정값.
2. **환경/설정 재현성** — 하드웨어·설정·도구·버전 등, 재현에 필요한 정보.
3. **워크로드 특성화(실측)** — 제안서의 가정과 실측 워크로드의 일치 여부.
4. **정량적 증거 — percentile 기반** — 평균이 아니라 p50/p95/p99 등
   백분위수 기반 측정치와 그래프/원자료. 서술형 주장만으로는 불충분.
5. **병목 목록과 증거 연결** — 각 병목 항목은 위 정량적 증거로 뒷받침.
6. **exit criteria 대비 실제 결과** — 제안서의 SLO/성능 예산 대비 pass/
   fail 판정과 편차.
7. **결론/hand-off** — 목표 충족 여부, 용량 증설 필요 시 capacity-planning
   으로 hand-off 근거.

이는 directive.sh의 기존 PRODUCES 필드(`performance budget, profiling
evidence, bottleneck list`)를 대체하지 않고 **내용 기준을 부여**한다 —
`performance budget`은 (1)의 숫자 목표, `profiling evidence`는 (1)(4)의
방법론+percentile 증거, `bottleneck list`는 (5)의 증거-연결 목록에 각각
대응.

## (c) 채택 근거 — 왜 이 방법론들이 이 역할의 의도된 가치와 맞아떨어질 수밖에 없는가

이 역할의 directive.sh `YOU DECIDE`는 "부하/지연 목표를 만족하는가"다 —
이는 정의상 (i) 목표가 숫자로 존재해야 판정 가능하고, (ii) 부하 조건을
특정해야 "어떤 부하에서"의 답이 성립하며, (iii) 목표 대비 실측을
비교해야 "만족하는가"를 판정할 수 있다. 이 세 가지 논리적 필요조건이 곧
scout-brief의 category must-be 세 가지(숫자 SLO, 워크로드 특성화,
exit-criteria 비교)와 정확히 대응한다 — 즉 채택안은 이 역할의 존재
이유(YOU DECIDE 문구)를 만족시키기 위한 논리적 필요조건이지, 임의의
업계 유행 선택이 아니다.

USE/RED는 채택안이 아니라 "그 판정에 필요한 원인 규명 방법"이다 —
`WRITE_SCOPE: []`(report-only)이자 `HAND-OFF: 용량 증설 타이밍이 걸리면
→ capacity-planning`인 이 역할은 자원 포화(USE, capacity-planning으로
넘길 신호)와 요청 실패/지연(RED, 이 역할 자체의 판정 대상)을 모두 봐야
정확한 hand-off 판단이 선다 — 자원 신호만 보면 하드웨어 증설로 오인하고,
요청 신호만 보면 애플리케이션 버그로 오인하는 실패 모드를 각각 막는다
(scout-brief "axis 1: 자원-중심 vs 요청-중심" 참고).

percentile 근거를 필수화하는 이유는 평균이 SLO 위반의 tail을 은폐하기
때문이다 — "p99 latency < Xms"라는 목표 자체가 percentile 언어로 쓰이므로,
증거도 같은 언어(percentile)여야 목표-증거 정합성이 성립한다. 평균 기반
증거로 percentile 목표를 판정하는 것은 논리적으로 부정합하다.

premortem/위험 절을 phase 1에 넣는 이유: 이 역할은 회귀 판정 역할이며
hand-off가 있는 report-only 역할이다 — 실행 전에 "회귀가 발생했다"를
가정하고 rollback/blast-radius를 정해두지 않으면, phase 2 실행 중 회귀가
실제로 발생했을 때 이 역할의 `write_scope: []` 제약상 스스로 코드를
고칠 권한이 없어 hand-off 경로가 사전에 정의돼 있어야만 대응 가능하다 —
즉 이 역할의 권한 제약(WRITE_SCOPE 없음) 자체가 premortem을 사후가 아닌
사전 필수 항목으로 만드는 논리적 근거다.

## (d) 플러그인 반영 계획 (phase 2, 이 PR에서 실행하지 않음)

1. **directive.sh**: `PRODUCES` 4번째 인자 텍스트를 확장하여 방법론 이름
   (USE/RED)과 percentile 기준을 명시적으로 포함하도록 갱신. 예:
   `"PRODUCES (required record fields): performance budget (numeric SLO,
   e.g. p99 latency), profiling evidence (USE+RED signals, percentile-
   based), bottleneck list (evidence-linked)"`. `core_role_directive`의
   4-인자 시그니처는 유지 — 5번째 인자를 새로 만들지 않는다
   (issue-2 survey가 확인한 제약).
2. **record-fields-gate.sh (core canon)**: 현재 presence-only 체크이며
   이 레포에 로컬 복사본이 없다(issue-2 phase 2에서 core 등록으로 전환
   완료) — 이 제안은 core 쪽 게이트 로직을 바꾸지 않는다. 대신 이
   레포 로컬에 **내용 검증용 보조 게이트**(신규 파일, 예:
   `performance-engineering/hooks/methodology-gate.sh`)를 추가할지 여부를
   phase 2에서 결정: record 파일에 percentile 패턴(`p9[0-9]|p50`)과
   방법론 키워드(`USE|RED`) 존재를 grep 수준으로 확인하는 경량 게이트.
   이 게이트는 이 역할 고유 콘텐츠 규칙이므로 core canon 대상이 아니다
   (core의 §20 로직과 역할-고유 콘텐츠 규칙은 issue-2 proposal이 이미
   구분한 선례를 따름).
3. **필수 필드(레코드)**: 위 (b)의 7개 항목을
   `docs/issue-<n>/reports/performance-engineering.md` 작성 시 필수
   섹션 헤더로 강제(문서 관례 — 게이트가 아니라 handbook 문서로 기술).
4. **게이트**: (2)의 신규 로컬 게이트를 `hooks.json`의 Write/Edit/
   MultiEdit matcher에 등록할지, 또는 core canon에 먼저 상신해 core 쪽에
   일반화할지는 phase 2 open question — 이 레포 단독으로 결정하기보다
   승인자 확인 필요(아래 리스크 참고).

## 리스크

- **게이트 위치 미확정**: (d)-2/4의 신규 게이트를 이 레포 로컬에 둘지
  core canon으로 상신할지 phase 1에서 결정하지 않음 — core canon 우선
  원칙(issue-5 선례)과 상충하지 않도록 phase 2 착수 전 확인 필요.
- **percentile 값 부재 시 회귀**: 기존 phase 2 record가 이미 작성된
  적 없음(이 역할은 아직 phase 2 산출물이 없음)이므로 하위호환 문제는
  없음 — 이번이 첫 산출물이 되어 규범을 처음부터 준수 가능.
- **자가 승인 금지**: contract v3에 따라 phase 2는 approvers.md의
  Approve(또는 단일 계정 모드의 `APPROVE issue-1/performance-engineering`
  이슈 댓글) 없이 시작하지 않는다.

## 범위 밖

- warrant-hunter 및 3종 게이트의 core canon 참조 전환은 issue-2/issue-5가
  이미 완료 — 본 제안은 재론하지 않는다.
- record 규율/문서화 의무(§20 등 core canon 기존 강화 조항)는 유지하며
  본 제안은 그 위에 이 역할 고유의 방법론 내용만 추가한다.
