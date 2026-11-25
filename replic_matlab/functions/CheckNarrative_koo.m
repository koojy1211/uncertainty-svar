function [pass, w] = CheckNarrative_KOR(shocks, A0tilde, B_draw, nsI, ntI, g, M)
%%% [수정] 새 파일 (원본에 없음). CheckNarrativeAndReWeight.m + CheckNarrativeRestrictions_fast.m을 대신한다
%%% [수정] 원본과 다른 점
%%%   1. 모형 하나씩 루프 안에서 검사한다 (원본은 부호 통과 모형을 다 모은 뒤 한꺼번에)
%%%   2. 가중치 계산에서 부호 서사의 (1/2)^k는 상수라 빼고 Type A만 시뮬레이션한다
%%%      원본처럼 서사 전체를 동시에 시뮬레이션하면 우리 제약 수에서는 1000번 중 성공이 거의 0번이라 가중치가 터진다
%%%   3. Type A 비교 대상에 글로벌 혁신 기여를 넣을 수 있다 (g가 있을 때, svar_diff.do typeA와 같음)
%%% 입력
%%%   shocks: 구조충격 (T-p × n), A0tilde: 구조행렬 (shocks = 축약형 혁신 × A0tilde), B_draw: 축약형 계수
%%%   nsI: 서사 부호 [t, 충격, 부호], ntI: Type A [t, 충격, 변수, 글로벌 비교 1·0]
%%%   g: 글로벌 비교 정보 (ug: Type A 행별 그 달 글로벌 혁신, PG: chol(Σ*,'lower'), idxC0: 글로벌 동시기 계수 행). 없으면 []
%%%   M: Type A 통과확률 시뮬레이션 횟수 (nRepsWeights)

w = nan;

% 서사 부호: 그 달 그 충격의 부호
pass = all(shocks(sub2ind(size(shocks), nsI(:,1), nsI(:,2))) .* nsI(:,3) > 0);
if ~pass, return; end

% Type A: |충격 j의 기여| ≥ 다른 충격 각각의 기여, (글로벌 비교 시) ≥ |글로벌 혁신 기여|
L0 = inv(A0tilde)';                                % impact 행렬: 행 = 변수, 열 = 충격
om = 1;
for r = 1:size(ntI,1)
    t = ntI(r,1); j = ntI(r,2); iv = ntI(r,3);
    c = abs(L0(iv,:) .* shocks(t,:));
    a = c(j);
    c(j) = -1;
    gc = 0; gr = [];
    if ntI(r,4) == 1
        C0 = B_draw(g.idxC0, iv)';                 % 한국 식 iv의 글로벌 동시기 계수 (1×ng)
        gc = g.ug(r,:) * C0';                      % 그 달 글로벌 혁신의 기여
        gr = C0 * g.PG;
    end
    if ~(a >= max(c) && a >= abs(gc)), pass = false; return; end
    om = om * pTypeA(L0(iv,:), j, M, gr);
end

% 가중치 1/ω, 하한 1/M (svar_diff.do와 같음)
w = 1/max(om, 1/M);

end
