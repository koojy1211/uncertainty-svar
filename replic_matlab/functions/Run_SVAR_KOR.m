%%% [수정] Run_SVAR_KOR: Run_SVAR_v1.m 복사본. 바꾼 줄에는 %%% [수정], 여러 줄은 [수정 시작]~[수정 끝]. 표시 없는 줄은 원본 그대로
%%% [수정] 바뀐 점 4가지
%%%   1. 서사제약을 추출 루프 안에서 바로 검사하고 통과한 모형만 저장 (원래는 부호 통과 모형을 다 모은 뒤 CheckNarrativeAndReWeight에서 검사)
%%%   2. 가중치 = 1/Pr(Type A). 부호 서사의 (1/2)^k는 상수라 뺀다 (CheckNarrative_KOR.m)
%%%   3. 회전 부호 뒤집기 (SignAndZeroRestrictions_flip.m)
%%%   4. 멈춤 규칙에 축약형 추출 상한(maxRFDraws), Σ 자유도(dfTk)·폭발 근(dropExplosive) 스위치
%%% [수정] 추가로 필요한 작업공간 변수: NS, NT, glob, maxRFDraws, dfTk, dropExplosive

%% Some Data Adjustments

load(datafile)

if isempty(panelselect)
    panelselect=1:size(data,2);
end

y = data(logical((year(dates) >= startYear).*(year(dates) <= endYear)),panelselect);
dates = dates(logical((year(dates) >= startYear).*(year(dates) <= endYear)),:);

varNames = varNames(panelselect);

[T,n] = size(y);

    if constant == 1
        exog = [ones(size(y,1),1) exog]; 
    end

disp('OK');

K = n*p+size(exog,2);

%% Compute the closed-form solutions for the means

[~,~,posteriors] = BVAR(y,exog,p,prior_settings,1);

if dfTk == 1                                          %%% [수정] Σ ~ IW(SSE, T) → IW(SSE, T-k) (svar_diff.do와 같은 자유도)
    posteriors.v_post = posteriors.v_post - K;        %%% [수정]
end                                                   %%% [수정]

Beta_mean = reshape(posteriors.b_post,K,n);
% Sigma_mean = posteriors.S_post;

%% Retrieve the S, Z, and Narrative matrices for identification

if ~exist('SR','var'),  SR = []; end
if ~exist('ZR','var'),  ZR = []; end
if ~exist('NSR','var'), NSR = []; end
if ~exist('EBR','var'), EBR = []; end

[S,Z,hirfs,Ns,Nc,shockNames] = getRestrictions(SR,ZR,NSR,varNames,dates);

%%% [수정 시작] 서사제약(NS, NT)을 충격 계열의 행·열 번호로 바꾼다
%%% 원래는 NSR을 getRestrictions가 Ns, Nc로 바꾸지만, 그 형식에는 글로벌 기여 비교가 없어서 따로 받는다
if ~isempty(NSR), error('Run_SVAR_KOR에서는 NSR 대신 NS, NT를 쓸 것'); end
tz = dates(p+1:end);                                  % 충격 계열 t행의 날짜
nsI = zeros(size(NS,1),3);                            % 서사 부호: [t, 충격, 부호]
for r = 1:size(NS,1)
    it = find(tz == NS{r,1}); js = find(strcmp(shockNames,NS{r,2}));
    if isempty(it) || isempty(js), error('서사 부호제약 %d행: 날짜가 표본 밖이거나 충격 이름이 틀림', r); end
    nsI(r,:) = [it, js, NS{r,3}];
end
ntI = zeros(size(NT,1),4);                            % Type A: [t, 충격, 변수, 글로벌 비교 여부]
for r = 1:size(NT,1)
    it = find(tz == NT{r,1}); js = find(strcmp(shockNames,NT{r,2})); iv = find(strcmp(varNames,NT{r,3}));
    if isempty(it) || isempty(js) || isempty(iv), error('Type A %d행: 날짜, 충격, 변수 이름 확인', r); end
    ntI(r,:) = [it, js, iv, NT{r,4}];
end
useG = any(ntI(:,4) == 1);
tg = ones(size(ntI,1),1);                             % 글로벌 블록 충격 계열에서 같은 날짜의 행
for r = 1:size(ntI,1)
    if ntI(r,4) == 1, tg(r) = find(glob.dates == tz(ntI(r,1))); end
end
Ylag = mlag2(y,p);                                    % 서사 검사용 축약형 혁신의 우변 (get_shocks와 같은 계산)
X  = [exog(p+1:T,:) Ylag(p+1:T,:)];
Yp = y(p+1:T,:);
%%% [수정 끝]

%% Gibbs Sampler for Traditional Sign and Zero Restrictions

% Allocate Space for Saving Draws

Beta_save = nan(K,n,numDesiredDraws);
Sigma_save = nan(n,n,numDesiredDraws);
A0_save = nan(n,n,numDesiredDraws);
Q_save = nan(n,n,numDesiredDraws);
w_save = nan(1,numDesiredDraws);
RF_save = nan(1,numDesiredDraws);                     %%% [수정] 채택 모형의 축약형 추출 번호

numSavedDraws = 0;
numAttempts = 0;
numRF = 0; numSign = 0; numExpl = 0;                 %%% [수정] 축약형 추출 수, 부호 통과 수, 최대근 > 1 수

% 원본: while numSavedDraws < numDesiredDraws
while numSavedDraws < numDesiredDraws && numRF < maxRFDraws     %%% [수정] 축약형 추출 상한 추가
    
    tic
    
    Beta_temp = nan(K,n,BetaSigmaTries,Qs_per_BetaSigma);
    Sigma_temp = nan(n,n,BetaSigmaTries,Qs_per_BetaSigma);
    A0_temp = nan(n,n,BetaSigmaTries,Qs_per_BetaSigma);
    Q_temp = nan(n,n,BetaSigmaTries,Qs_per_BetaSigma);
    w_temp = nan(1,BetaSigmaTries,Qs_per_BetaSigma);
    RF_temp = nan(1,BetaSigmaTries,Qs_per_BetaSigma);                 %%% [수정]
    
    for worker = 1:BetaSigmaTries

        check = 0;
        [B_draw,SIGMA_draw] = BVAR_1draw(posteriors);
        numRF = numRF + 1;                                            %%% [수정]
        
        maxRoot = max(abs(getRoots(B_draw(size(exog,2)+1:end,:)')));
        if maxRoot > 1, numExpl = numExpl + 1; end                    %%% [수정]
        
        % 원본: if maxRoot <= 1
        if maxRoot <= 1 || dropExplosive == 0                         %%% [수정] dropExplosive = 0이면 최대근 > 1인 추출도 쓴다 (svar_diff.do)

            %%% [수정 시작] 서사 검사용 축약형 혁신, 한국 블록이면 글로벌 축약형도 하나 추출 (회전과 무관해서 회전 루프 밖에서 한 번)
            innov = Yp - X*B_draw;
            gN = [];
            if useG
                [BG,SG] = BVAR_1draw(glob.post);
                UG = glob.U0 - glob.X*BG;
                gN.ug = UG(tg,:);
                gN.PG = chol(SG,'lower');
                gN.idxC0 = glob.idxC0;
            end
            %%% [수정 끝]
        
            for Q_count = 1:Qs_per_BetaSigma
                
              if strcmp(StructuralIdentification,'Choleski')

                Beta_temp(:,:,worker,Q_count) = B_draw;
                Sigma_temp(:,:,worker,Q_count) = SIGMA_draw;                      
                A0_temp(:,:,worker,Q_count) = inv(chol(SIGMA_draw));
                Q_temp(:,:,worker,Q_count) = eye(n);
                w_temp(:,worker,Q_count) = 1;
                
              else
                  
              % Check Sign and Zero Restrictions

              % 원본: [A0tilde_draw,Qdraw,uw] = SignAndZeroRestrictions(B_draw,SIGMA_draw,p,exog,hirfs,S,Z,agnostic);
              [A0tilde_draw,Qdraw,uw] = SignAndZeroRestrictions_flip(B_draw,SIGMA_draw,p,exog,hirfs,S,Z,agnostic);   %%% [수정] 부호 뒤집기
              
                if isfinite(A0tilde_draw(1,1))
                    
                    % Check Elasticity Bound Restrictions if Present

                    [checkElasticity] = ElasticityBoundRestrictions(EBR,varNames,shockNames,B_draw,A0tilde_draw,exog,n,p);
               
                    if checkElasticity                       

                    %%% [수정 시작] 서사제약 검사와 가중치 (원래는 루프가 끝난 뒤 CheckNarrativeAndReWeight에서 함)
                    numSign = numSign + 1;
                    [passN, wN] = CheckNarrative_KOR(innov*A0tilde_draw, A0tilde_draw, B_draw, nsI, ntI, gN, nRepsWeights);
                    if passN
                    %%% [수정 끝]

                    Beta_temp(:,:,worker,Q_count) = B_draw;
                    Sigma_temp(:,:,worker,Q_count) = SIGMA_draw;
                    A0_temp(:,:,worker,Q_count) = A0tilde_draw;
                    Q_temp(:,:,worker,Q_count) = Qdraw;
                    % 원본: w_temp(:,worker,Q_count) = uw;
                    w_temp(:,worker,Q_count) = wN;                %%% [수정] 영제약 가중치 uw(영제약이 없으면 1) 대신 서사 가중치
                    RF_temp(:,worker,Q_count) = numRF;            %%% [수정]

                    end                                           %%% [수정] if passN 닫기
                
                    end
               end

             end                

            end
            
        end
    end

    Beta_clean = reshape(Beta_temp,K,n,BetaSigmaTries*Qs_per_BetaSigma);
    Sigma_clean = reshape(Sigma_temp,n,n,BetaSigmaTries*Qs_per_BetaSigma);
    A0_clean = reshape(A0_temp,n,n,BetaSigmaTries*Qs_per_BetaSigma);
    Q_clean = reshape(Q_temp,n,n,BetaSigmaTries*Qs_per_BetaSigma);
    w_clean = reshape(w_temp,1,BetaSigmaTries*Qs_per_BetaSigma);
    RF_clean = reshape(RF_temp,1,BetaSigmaTries*Qs_per_BetaSigma);   %%% [수정]
      
    Beta_clean=Beta_clean(:,:,isfinite(squeeze(A0_clean(1,1,:))));
    Sigma_clean=Sigma_clean(:,:,isfinite(squeeze(A0_clean(1,1,:))));
    A0_clean=A0_clean(:,:,isfinite(squeeze(A0_clean(1,1,:))));  
    Q_clean=Q_clean(:,:,isfinite(squeeze(Q_clean(1,1,:))));  
    w_clean=w_clean(:,isfinite(w_clean));  
    RF_clean=RF_clean(:,isfinite(RF_clean));                         %%% [수정]

    numAcceptedDraws = size(Beta_clean,3);

    if numAcceptedDraws > 0
        Beta_save(:,:,numSavedDraws+1:numSavedDraws+numAcceptedDraws) = Beta_clean;
        Sigma_save(:,:,numSavedDraws+1:numSavedDraws+numAcceptedDraws) = Sigma_clean;
        A0_save(:,:,numSavedDraws+1:numSavedDraws+numAcceptedDraws) = A0_clean;
        Q_save(:,:,numSavedDraws+1:numSavedDraws+numAcceptedDraws) = Q_clean;
        w_save(:,numSavedDraws+1:numSavedDraws+numAcceptedDraws) = w_clean;
        RF_save(:,numSavedDraws+1:numSavedDraws+numAcceptedDraws) = RF_clean;   %%% [수정]
        
        numSavedDraws = numSavedDraws + numAcceptedDraws;
    end

    numAttempts = numAttempts + (BetaSigmaTries*Qs_per_BetaSigma);

    disp(strcat('Attempted Draws:',num2str(numAttempts)))
    disp(strcat('Successful Draws:',num2str(numSavedDraws)))
    fprintf('축약형 %d / %d, 부호 통과 %d\n', numRF, maxRFDraws, numSign);   %%% [수정] Successful = 서사까지 통과
    toc    
    
end

%%% [수정 시작] 미리 잡아둔 칸 중 빈 칸 제거 (원래는 목표 수를 채울 때까지 돌아서 빈 칸이 없음), 채택 수·ESS 출력
Beta_save  = Beta_save(:,:,1:numSavedDraws);
Sigma_save = Sigma_save(:,:,1:numSavedDraws);
A0_save    = A0_save(:,:,1:numSavedDraws);
Q_save     = Q_save(:,:,1:numSavedDraws);
w_save     = w_save(1:numSavedDraws);
RF_save    = RF_save(1:numSavedDraws);
fprintf('\n축약형 %d (최대근 > 1: %d개), 회전 %d, 부호 통과 %d, 서사까지 통과 %d\n', numRF, numExpl, numAttempts, numSign, numSavedDraws);
if numSavedDraws < 2, error('통과 모형이 너무 적다. maxRFDraws, Qs_per_BetaSigma를 늘리거나 서사제약 점검'); end
fprintf('중요도가중 ESS %.1f / %d, 서로 다른 축약형 추출 %d개\n', sum(w_save)^2/sum(w_save.^2), numSavedDraws, numel(unique(RF_save)));
%%% [수정 끝]

%% Re-Weight Draws due to Zero Restrictions

if ~isempty(ZR)

resample = randsample(numSavedDraws,numSavedDraws,true,w_save);

Beta_save   = Beta_save(:,:,resample);
Sigma_save  = Sigma_save(:,:,resample);
A0_save     = A0_save(:,:,resample);
Q_save      = Q_save(:,:,resample);

end

%% Check Narrative Restrictions and Reweight

if ~isempty(NSR)
    
disp('Checking Narrative Sign Restrictions')

[Beta_narrative,Sigma_narrative,A0_narrative,weights_narrative] = CheckNarrativeAndReWeight(y,p,Beta_save,Sigma_save,A0_save,exog,Ns,Nc,nRepsWeights);

numSavedNarrative = size(Beta_narrative,3);

end

%% Compute IRFs and Structural Shocks for Traditional Sign Restrictions

disp('Computing IRFs for traditional sign restrictions')
disp('(Run_SVAR_KOR: 여기 Beta_save 등은 서사까지 통과한 모형, 가중치는 w_save)')   %%% [수정]

hmax = 120;

Draws_IRFs = nan(n,n,hmax+1,numSavedDraws);
Draws_Shocks = nan(T-p,n,numSavedDraws);
    
    parfor draw = 1:numSavedDraws
        
        IRFs = getIRFs(Beta_save(:,:,draw),A0_save(:,:,draw),exog,n,p,hmax);
        IRFs(cumulateWhich,:,:) = cumsum(IRFs(cumulateWhich,:,:), 3);        
        Draws_IRFs(:,:,:,draw) = IRFs;

        BETA = Beta_save(:,:,draw);
        
        B = BETA(size(exog,2)+1:end,:)';
        c = BETA(1:size(exog,2),:)';
        A0 = A0_save(:,:,draw);
        
        shocks = get_shocks(y,exog,A0,c,B,p);
        Draws_Shocks(:,:,draw) = shocks;
  
    end
   
%% Compute IRFs and Structural Shocks that satisfy narrative restrictions

if ~isempty(NSR)
    
disp('Computing IRFs for narrative sign restrictions')

    numSavedNarrative = size(Beta_narrative,3);
    Draws_IRFs_narrative = nan(n,n,hmax+1,numSavedNarrative);
    Draws_Shocks_narrative = nan(T-p,n,numSavedNarrative);
    
    parfor draw = 1:numSavedNarrative
        
        IRFs = getIRFs(Beta_narrative(:,:,draw),A0_narrative(:,:,draw),exog,n,p,hmax); 
        IRFs(cumulateWhich,:,:) = cumsum(IRFs(cumulateWhich,:,:), 3);        
        
        Draws_IRFs_narrative(:,:,:,draw) = IRFs;

        BETA = Beta_narrative(:,:,draw);
        
        B = BETA(size(exog,2)+1:end,:)';
        c = BETA(1:size(exog,2),:)';
        A0 = A0_narrative(:,:,draw);
        
        shocks = get_shocks(y,exog,A0,c,B,p);
        Draws_Shocks_narrative(:,:,draw) = shocks;
  
    end

end