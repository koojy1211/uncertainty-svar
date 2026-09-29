# 부호제약·서사제약 SVAR로 한국 불확실성 충격 식별 — 핵심 문헌 정리

작성일: 2026-09-28
폴더: `uncertainty-svar/docs/`

---

## 0. 먼저 짚을 것 두 가지

**(1) 방향 전환.** 9월 6일 설계안(`불확실성지수_충격식별_연구설계.md` §3.2)은 부호제약·서사제약을 명시적으로 배제했다. 이번에 그 방향을 되돌리는 것이므로, 아래 §3의 "사전분포 민감성"을 어떻게 처리할지를 처음부터 설계에 넣어야 한다. 빈도주의 성향을 유지하고 싶다면 Giacomini–Kitagawa–Read(robust Bayes)와 LMN(2021)식 shock-restricted SVAR가 가장 가까운 절충안이다.

**(2) "충격 시퀀스"는 하나로 나오지 않는다.** 부호·서사제약은 집합식별이다. 결과물은 $\varepsilon^U_t$ 한 줄이 아니라 제약을 만족하는 **충격 계열의 집합(또는 사후분포)**이다. 2단계 미시패널에 넣을 계열을 어떻게 고를지(중앙값 계열, Fry–Pagan median target, 추출별 반복 추정)는 §4에서 다룬다. 기존 `shock_signrestr.do`가 accept/reject만 하고 중요도 가중을 생략한 것도 새 폴더에서는 고쳐야 할 부분이다.

---

## 1. 핵심 문헌 선정 (우선순위)

| 등급 | 문헌 | 역할 |
|---|---|---|
| ★★★ 코어 | Antolín-Díaz & Rubio-Ramírez (2018, AER) | 서사 부호제약의 원전. 구현 알고리즘 그대로 따를 것 |
| ★★★ 코어 | Ludvigson, Ma & Ng (2021, AEJ:Macro) | 불확실성 충격에 사건·외부변수 제약을 건 직접 선례 |
| ★★★ 코어 | De Santis & Van der Veken (2026, OBES) | 금융충격 vs 불확실성충격 분리 — 부호제약만으로 안 되는 이유와 서사제약 해법 |
| ★★★ 코어 | Arias, Rubio-Ramírez & Waggoner (2018, ECMA) | 부호+영(0)제약 동시 부과 — 소규모개방경제 블록외생성 구현에 필수 |
| ★★ 기반 | Uhlig (2005, JME) / Rubio-Ramírez, Waggoner & Zha (2010, ReStud) | 부호제약과 회전행렬 추출의 기본 틀 |
| ★★ 비판 | Baumeister & Hamilton (2015, ECMA) / Fry & Pagan (2011, JEL) / Inoue & Kilian (2026, JAE) | 사전분포 민감성, 중앙값 IRF 문제 — 심사 방어용 |
| ★★ 추론 | Giacomini, Kitagawa & Read (2022, JBES; 2023 RBA RDP) | 서사제약 하 식별·추론 교정, robust Bayes |
| ★★ 적용 | Berthold (2023, EER) | 불확실성 vs 위험회피 충격 분리, LMN 방식 확장 |
| ★ 동기 | Kilian, Plante & Richter (2025, JAE) | "왜 recursive가 아닌가"의 근거 |
| ★ 대조 | Brianti (WP, Alberta) / Caldara et al. (2016, EER) / Furlanetto et al. (2019, EJ) | 금융·불확실성 분리의 대안 식별과 상충 결과 |
| ★ 최신 | Read (2026, RBA RDP 2026-01) shock-percentile restrictions | 서사제약의 임의 임계값 문제 해결 |

---

## 2. 문헌별 정리

### 2.1 Uhlig (2005), "What are the effects of monetary policy on output? Results from an agnostic identification procedure," *JME* 52(2), 381–419

- **내용**: 통화정책 충격을 금리·물가·비차입지준 반응의 부호로만 식별하고 산출 반응은 열어둠("agnostic"). 산출 효과가 모호하다는 결론.
- **방법**: 축약형 사후분포에서 $(B,\Sigma)$ 추출 → 단위벡터 $q$ 추출 → 임펄스 벡터 $a=\tilde P q$ ($\tilde P$=Cholesky)가 $h=0,\dots,K$에서 부호제약 만족하면 채택.
- **이 연구에 쓰는 것**: "관심 반응(생산·소비·투자)은 제약하지 않는다"는 원칙. 불확실성 충격의 실물효과를 결과로 보이려면 실물변수 부호를 걸면 안 된다.

### 2.2 Rubio-Ramírez, Waggoner & Zha (2010), "Structural vector autoregressions: Theory of identification and algorithms for inference," *ReStud* 77(2), 665–696

- **내용**: 전역 식별 조건 + 균등(Haar) 직교행렬 추출 알고리즘.
- **방법**: $X\sim N(0,I_n)$ → $X=QR$ (R 대각 양수로 정규화) → $Q$가 Haar 분포. $B_0^{-1}=\text{chol}(\Sigma)\,Q$.
- **쓰는 것**: 모든 후속 알고리즘의 기본 부품. R 대각 정규화를 빼먹으면 균등분포가 깨진다.

### 2.3 Arias, Rubio-Ramírez & Waggoner (2018), "Inference based on SVARs identified with sign and zero restrictions: Theory and applications," *ECMA* 86(2), 685–720

- **내용**: 부호제약과 영제약을 동시에 걸 때, 기존 Mountford–Uhlig penalty 방식은 암묵적으로 강한 사전분포를 부과함을 보이고 올바른 사후분포 추출법 제시.
- **방법**: uniform-normal-inverse-Wishart 사전분포. 영제약을 만족하는 $Q$를 열 단위로 null space에서 추출 → 부호제약 확인 → **중요도 가중**(영제약이 만드는 부피 변화 보정).
- **쓰는 것**: 한국 VAR에 **글로벌 블록 외생성**(한국 변수가 글로벌 변수에 동시기 영향 없음)을 영제약으로, 한국 블록 내부를 부호·서사제약으로 거는 구조의 이론적 근거. Matlab 코드 공개(BVAR_ toolbox 계열).

### 2.4 Antolín-Díaz & Rubio-Ramírez (2018), "Narrative sign restrictions for SVARs," *AER* 108(10), 2802–2829 ★

- **내용**: 역사적 사건에 대한 서사 정보를 **특정 시점의 구조충격/역사분해에 대한 부등식 제약**으로 부과. 적용: 통화정책(1979년 10월 Volcker), 원유시장(Kilian 2009 모형). 부호제약만으로 넓던 IRF 집합이 크게 좁아짐.
- **제약 유형**
  1. **충격 부호 제약**: $\varepsilon_{j,t^*}>0$ (예: 사건 월에 불확실성 충격이 양수).
  2. **역사분해 제약 Type A**: 시점 $t^*$에서 변수 $i$의 예상치 못한 변화에 충격 $j$의 기여가 **절댓값 기준 가장 큼**.
  3. **역사분해 제약 Type B**: 충격 $j$의 기여가 **나머지 충격 기여 절댓값 합보다 큼**(overwhelming).
- **방법(핵심)**: 서사제약은 우도를 절단한다. 따라서 accept/reject만 하면 사후분포가 틀리고, 각 $(B,\Sigma)$ 추출에 대해
  $$w\propto 1/\Pr\big(\text{서사제약 만족}\mid B,\Sigma,\ \text{부호제약}\big)$$
  로 중요도 가중해야 한다. $\Pr(\cdot)$는 $(B,\Sigma)$마다 회전 $Q$를 $M$개 추가로 뽑아 몬테카를로로 계산.
- **쓰는 것**: 알고리즘 그대로 구현. 기존 do-file이 생략한 가중이 이것이다. 제약 수는 적게(1~3개 사건), Type A 위주로.

### 2.5 Ludvigson, Ma & Ng (2021), "Uncertainty and business cycles: Exogenous impulse or endogenous response?" *AEJ: Macro* 13(4), 369–410 ★

- **내용**: 거시 불확실성 $U_M$, 금융 불확실성 $U_F$, 산출 $Y$ 3변수 SVAR. **$U_F$는 외생적 충격으로 산출 하락을 일으키고, $U_M$은 주로 실물충격에 대한 내생적 반응**이면서 하강을 증폭.
- **방법 — shock-restricted SVAR**
  - 회전 $Q$를 대량 추출(균등) → 각 후보 $B$에 대해 충격계열 $e_t=B^{-1}u_t$를 계산 → 다음 제약을 만족하는 해만 남김.
  - **사건 제약(event constraints)**: 1987년 10월 주가폭락 월의 $U_F$ 충격이 일정 표준편차 이상, 2007–09 금융위기 중 $U_F$ 충격이 큰 달이 존재, 위기 기간 실물충격 누적합이 음수 등.
  - **외부변수 상관 제약(correlation constraints)**: 식별된 충격과 VAR 밖 변수(주식수익률, 금가격 변화 등)의 상관 부호를 제약.
  - 임계값은 원문 표를 확인해서 옮길 것 — 여기서는 구조만 정리.
- **베이지안인가**: 사전분포–사후분포 구조가 아니라 **점추정된 축약형 + 회전 집합**을 쓰고 추론은 부트스트랩. 9월 설계안의 "빈도주의 선호"와 가장 가깝다.
- **쓰는 것**: 한국판 템플릿으로 가장 적합. 사건 제약 = 한국 서사 이벤트, 외부변수 = 금(원화 환산) 수익률, KOSPI 수익률, CDS. $U_M$/$U_F$ 분리 구조도 그대로 가져올 수 있다.

### 2.6 De Santis & Van der Veken (2026), "Deflationary financial shocks and inflationary uncertainty shocks: An SVAR investigation," *Oxford Bulletin of Economics and Statistics* (ECB WP 2727, 2022) ★

- **내용**: 미국 월별 1984–2019, 5변수(보간 실질GDP, GDP디플레이터, 국채10년, GZ 스프레드, 불확실성 지표 5종 교체). **금융충격은 물가 하락, 불확실성충격은 물가 상승**(기업 마크업 상승·예비적 저축).
- **방법**: impact 부호제약으로 비용·금리·수요 충격을 식별하고, 금융충격과 불확실성충격은 각자 자기 변수(스프레드, 불확실성)만 양(+)으로 정규화. 두 충격은 부호제약으로 분리 불가(두 충격의 2차원 부분공간 안에서 회전해도 제약이 모두 유지)하므로 **서사제약(역사분해 기여 제약)**으로 분리 — 예: 1987년 10월·2007년 8월 불확실성 변화는 불확실성 충격이 주도, 2007년 7월 스프레드 변화는 금융충격이 주도, 2008년 9–10월 스프레드·불확실성 동반 상승.
- **쓰는 것**: 한국 설계에서 가장 까다로운 "금융 vs 불확실성" 분리 논리. 단, 물가 반응 결과는 Brianti(아래)와 **정반대**이므로 한국에서는 물가 부호를 제약하지 말고 결과로 볼 것. 이 자체가 논문 기여 포인트가 될 수 있다.

### 2.7 Berthold (2023), "The macroeconomic effects of uncertainty and risk aversion shocks," *EER* 154, 104442

- **내용**: 변동성 충격을 위험의 양(uncertainty)과 위험의 가격(risk aversion)으로 분리. 불확실성 충격은 산출을 크게 줄이고, 위험회피 충격은 주로 자산가격을 떨어뜨리며 디플레이션적. GFC는 두 충격 혼합, COVID는 주로 불확실성.
- **방법**: LMN식 shock-restricted SVAR 확장. 서사 제약(COVID 선언, 리먼, 1987·2011 주가폭락), "행동 차이" 제약(정책개입으로 불확실성은 높지만 위험회피는 완만했던 시점), 외부변수 제약(금가격 ↔ 불확실성, 중개기관 자본비율 ↔ 위험회피). 후보 모형 중 약 0.06%만 전 제약을 만족.
- **쓰는 것**: VKOSPI가 기대변동성 + 분산위험프리미엄을 섞는다는 문제(9월 설계안 §4.2 (b))를 식별 단계에서 직접 처리하는 방법. 채택률이 극히 낮아질 수 있다는 실무 경고도 여기서.

### 2.8 Giacomini, Kitagawa & Read — "Narrative restrictions and proxies" (2022, *JBES* 40(4), 1415–1425); "Identification and inference under narrative restrictions" (RBA RDP 2023-07, ReStud R&R)

- **내용**: 서사제약은 **특정 시점 관측치에 의존하는 제약**이라 식별 개념 자체가 표준 부호제약과 다르고, 우도가 평평한 영역이 생겨 사후분포가 사전분포에 민감하다.
- **방법**: (i) AR-R(2018)식 사후분포의 "조건부 우도" 해석을 교정, (ii) 회전 $Q$에 대한 사전분포를 하나로 고정하지 않고 **모든 사전분포 집합에 대한 사후 하·상한**(robust Bayes)을 보고, (iii) 이 구간이 점근적으로 빈도주의 타당성을 가짐을 보임.
- **쓰는 것**: "베이지안 사전분포 때문에 나온 결과 아니냐"는 비판에 대한 가장 직접적 방어. 메인은 AR-R, 강건성으로 GKR의 robust bound를 함께 보고하는 구성이 표준이 되어 가고 있다.

### 2.9 비판·방어 문헌

- **Fry & Pagan (2011), "Sign restrictions in structural vector autoregressions: A critical review," *JEL* 49(4), 938–960** — 각 $h$별 중앙값 IRF는 서로 다른 모형에서 온 것이라 **어떤 단일 모형에도 대응하지 않음**. 대안: 중앙값에 가장 가까운 단일 모형(median target). → **충격 시퀀스 추출에 직결**(§4).
- **Baumeister & Hamilton (2015), "Sign restrictions, structural vector autoregressions, and useful prior information," *ECMA* 83(5), 1963–1999** — Haar 균등 사전분포가 IRF에는 비균등(정보적) 사전분포를 유도, 집합식별 영역에서는 사후분포가 사실상 사전분포를 반영.
- **Inoue & Kilian (2026), "The conventional impulse response prior in VAR models with sign restrictions," *JAE* 41(3), 310–322** — 위 비판의 최신 재검토. 인용 전 원문 결론 확인할 것.
- **Kilian & Murphy (2012), "Why agnostic sign restrictions are not enough," *JEEA* 10(5), 1166–1188** — 부호만으로는 식별 집합이 너무 넓다 → 탄력성 상한 등 추가 제약. 서사제약 도입의 동기와 같은 논리.

### 2.10 Kilian, Plante & Richter (2025), "Macroeconomic responses to uncertainty shocks: The perils of recursive orderings," *JAE* 40(4), 395–410

- **내용**: 불확실성 VAR에서 흔한 "불확실성을 맨 앞/맨 뒤에 둔 두 recursive 순서로 결과를 bounding하고, 비슷하면 강건하다"는 관행이 **DGP가 SVAR이든 DSGE든 성립하지 않음**을 증명.
- **쓰는 것**: 논문 서론에서 "왜 Cholesky가 아니라 부호·서사제약인가"의 한 줄 근거.

### 2.11 대조 문헌 (금융 vs 불확실성 분리)

- **Brianti (WP, Univ. of Alberta), "Financial shocks, uncertainty shocks, and monetary policy trade-offs"** — 기업 현금보유 반응 차이로 식별: 금융충격 → 현금 감소(외부자금 단절), 불확실성충격 → 현금 증가(예비적 동기). 결과는 **금융충격 인플레이션적, 불확실성충격 디플레이션적** — De Santis–Van der Veken과 반대. 한국에서 기업 현금비율(KisValue 총량)을 추가 부호제약 변수로 쓸 수 있는 아이디어.
- **Caldara, Fuentes-Albero, Gilchrist & Zakrajšek (2016), *EER* 88, 185–207** — penalty function으로 금융·불확실성 충격을 순차 식별. 순서에 따라 결과가 바뀐다는 점이 서사제약 도입의 동기가 됨.
- **Furlanetto, Ravazzolo & Sarferaz (2019), "Identification of financial factors in economic fluctuations," *EJ* 129(617), 311–337** — 부호제약으로 금융충격을 수요·공급·통화·투자 충격과 분리. 한국 VAR의 "나머지 충격" 부호표 설계 참고용.

### 2.12 최신·추론 보완 (선택)

- **Read (2026), "Shock-percentile restrictions for SVARs," RBA RDP 2026-01** — "사건 월 충격이 $k$ 표준편차 이상" 같은 임의 임계값 대신 "표본 내 충격의 상위 X% 안에 든다"는 **순위 제약**. 1987 Black Monday 불확실성 사례로 예시. LMN식 사건 제약의 임계값 자의성 비판을 피하는 방법.
- **Read & Zhu (근간, *QE*), "Fast posterior sampling in tightly identified SVARs using 'soft' sign restrictions"** — 채택률이 극히 낮을 때(Berthold 0.06%) 계산 문제 해결.
- **Granziera, Moon & Schorfheide (2018, *QE* 9(3))**, **Gafarov, Meier & Montiel Olea (2018, *JoE* 203(2))** — 부호제약 SVAR의 빈도주의 신뢰집합. 빈도주의 보고를 원할 때.
- **Giacomini & Kitagawa (2021), *ECMA* 89(4)** — robust Bayes의 일반 이론.

---

## 3. 방법론 공통 틀

축약형: $y_t=c+\sum_{l=1}^p A_l y_{t-l}+u_t,\ u_t\sim N(0,\Sigma)$
구조형: $u_t=B_0^{-1}\varepsilon_t,\quad B_0^{-1}=\text{chol}(\Sigma)\,Q,\quad Q\in\mathcal O(n)$

| 단계 | 부호제약만 (Uhlig/RWZ) | + 영제약 (ARW) | + 서사제약 (AR-R) | shock-restricted (LMN) |
|---|---|---|---|---|
| 축약형 | $(A,\Sigma)$ 사후 추출 | 동일 | 동일 | OLS 점추정 (+부트스트랩) |
| 회전 | Haar $Q$ | 영제약 null space에서 열별 추출 | Haar $Q$ | Haar $Q$ 대량 |
| 제약 | $h$별 IRF 부호 | 부호 + 0 | 부호 + $\varepsilon_{t^*}$ 부호 / 역사분해 순위 | 사건 크기 + 외부변수 상관 |
| 가중 | 없음 | 부피 보정 가중 | $1/\Pr(\text{서사}\mid A,\Sigma)$ | 없음 |
| 산출물 | IRF 사후분포 | IRF 사후분포 | IRF 사후분포 | 식별 집합 |

충격 계열은 채택된 각 $(A,\Sigma,Q)$마다 $\hat\varepsilon_t=Q'\,\text{chol}(\Sigma)^{-1}\hat u_t$ 로 얻는다.

---

## 4. 한국 설계에 주는 시사점 (다음 단계 논의용)

1. **골격**: 글로벌 블록(영제약, ARW) + 한국 블록 [생산, 물가, 콜금리, 신용스프레드, $U^{KR}$] 부호제약 + 서사제약(AR-R). 강건성으로 LMN식 shock-restricted, GKR robust bound.
2. **분리 대상**: 불확실성 vs 금융충격이 핵심. 두 충격은 부호제약으로 구분 불가하므로 **서사제약이 유일한 분리 수단** — 여기에 가장 공을 들일 것.
3. **제약하지 말 것**: 생산·소비·투자(결과변수), 그리고 **물가**(DSV vs Brianti 상충).
4. **한국 서사 후보** (9월 설계안 목록 재활용): 2024M12 비상계엄(정치 불확실성, 금융충격과 분리가 가장 깨끗), 2010M11 연평도, 2016M11 탄핵 정국, 2019M7 일본 수출규제 → 불확실성 쪽 / 2022M10 레고랜드 → **금융충격** 쪽(Type A: 스프레드 변화의 최대 기여) / 2008M10, 2020M3 → 둘 다 상승(부호만). 사건은 적게, 확실한 것만.
5. **충격 시퀀스 추출 방식**: (a) 추출별 충격계열의 시점별 중앙값 — 단일 모형 아님(Fry–Pagan 비판 해당), (b) median-target 단일 모형의 충격계열, (c) **추출별 충격계열 전체를 2단계 패널에 넣고 계수 분포 통합** — generated regressor 문제까지 동시에 해결하므로 (c)를 메인으로 권고.
6. **표본**: 9월 설계안의 표본 확장 문제는 그대로 유효. 서사제약은 표본 안의 사건에만 걸 수 있으므로 1997M11 외환위기를 쓰려면 표본이 1990년대부터 있어야 한다.

---

## 5. 권장 읽기 순서

1. Antolín-Díaz & Rubio-Ramírez (2018) — 알고리즘 부록까지
2. Ludvigson, Ma & Ng (2021) — 사건·외부변수 제약 표
3. De Santis & Van der Veken (ECB WP 2727) — 제약표와 서사 시점
4. Arias, Rubio-Ramírez & Waggoner (2018) — 영제약 부분
5. Giacomini, Kitagawa & Read (2022, 2023)
6. Baumeister & Hamilton (2015), Fry & Pagan (2011) — 방어 논리
7. Berthold (2023), Brianti, Kilian–Plante–Richter (2025), Read (2026)

---

## 확인 필요

- LMN(2021)의 사건 제약 임계값·외부변수 목록 정확한 수치 (원문 표에서 옮길 것)
- De Santis & Van der Veken OBES 게재본의 권·호·쪽 (ECB WP 2727 기준으로 정리함)
- Brianti 논문의 게재 여부
- Inoue & Kilian (2026)의 구체적 결론

## 출처 (서지 확인에 사용)

- [Giacomini, Kitagawa & Read — arXiv 2102.06456](https://arxiv.org/abs/2102.06456), [RBA RDP 2023-07](https://ideas.repec.org/p/rba/rbardp/rdp2023-07.html), [Matthew Read research page](https://sites.google.com/view/matthewread/research)
- [Kilian, Plante & Richter — Dallas Fed WP](https://ideas.repec.org/p/fip/feddwp/95180.html), [Lutz Kilian publications](https://sites.google.com/site/lkilian2019/research/publications)
- [De Santis & Van der Veken — ECB WP 2727](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2727~a82f405ead.en.pdf), [OBES](https://onlinelibrary.wiley.com/doi/10.1111/obes.70010)
- [Ludvigson, Ma & Ng — NBER w21803](https://www.nber.org/papers/w21803)
- [Berthold (2023) EER](https://www.sciencedirect.com/science/article/pii/S0014292123000715)
- [Brianti — Alberta WP](https://ideas.repec.org/p/ris/albaec/2021_005.html)
- [Furlanetto, Ravazzolo & Sarferaz (2019) EJ](https://academic.oup.com/ej/article-abstract/129/617/311/5231983)
- [Read (2026) RBA RDP 2026-01](https://www.rba.gov.au/publications/rdp/2026/pdf/rdp2026-01.pdf)
