function pr = pTypeA(Lrow, j, M, gr)
%%% [수정] 새 파일 (원본에 없음). 원본 CheckNarrativeAndReWeight.m의 가짜 충격 시뮬레이션을 Type A 한 달로 줄인 것
% Type A 통과확률: 해당 월 충격을 N(0,I)에서 M번 뽑아 계산 (svar_diff.do pA와 같음)
% Lrow: 해당 변수에 대한 각 충격의 impact (1×n)
% gr:   글로벌 혁신 경로 계수 C0*chol(Σ*) (1×ng). 글로벌 비교가 없으면 []

C = abs(randn(M, numel(Lrow)) .* Lrow);
a = C(:, j);
C(:, j) = -1;
ok = a >= max(C, [], 2);
if ~isempty(gr)
    ok = ok & (a >= abs(randn(M, numel(gr)) * gr'));
end
pr = mean(ok);

end
