function q = wquant(x, w, pr)
%%% [수정] 새 파일 (원본에 없음). 원본은 가중치대로 복원 재표본추출을 하지만, 여기서는 가중 분위수로 요약한다
% 가중 분위수 (svar_diff.do wq와 같음)

[xs, o] = sort(x);
cw = cumsum(w(o)) / sum(w);
q = xs(find(cw >= pr, 1));

end
