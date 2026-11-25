%% Code for Structuctural VAR %%

clear; clc

addpath('data')
addpath('functions')

%% Reduced form Settings 

% Data Location and Adjustments

datafile = fullfile('data','KOR_SVAR.mat');   %%% [수정] 아래에서 DATA.xlsx로 만들어 저장하는 파일
panelselect = [];

startYear = 2000;
endYear   = 2026;

%%% [수정] Data: data\DATA.xlsx, VAR sheet
raw = readtable(fullfile('..','data','DATA.xlsx'),'Sheet','VAR');
srcNames = {'lusip','lchn','loil','us2y','ebp','lvix','lusepu','ldxy', ...    %%% global block
            'lip','lcpi','kr_call','spread','lfx','lkrepu'};                  %%% domestic block
varNames = {'dlusip','dlchn','dloil','us2y','ebp','lvix','lusepu','dldxy', ...
            'dlip','dlcpi','kr_call','spread','dlfx','lkrepu'};
isDiff = logical([1 1 1 0 0 0 0 1 1 1 0 0 1 0]);    %%% [수정] 단위근 기각 못한 7개만 차분, 금리는 수준
Ylev = raw{:, srcNames};
data = Ylev(2:end, :);
data(:, isDiff) = diff(Ylev(:, isDiff));
dates = datenum(raw.date(2:end));
dv = datevec(dates);
keep = dv(:,1) >= startYear & dv(:,1) <= endYear;
data = data(keep, :);
dates = dates(keep);
if any(isnan(data(:))), error('DATA.xlsx VAR 시트 결측. Excel 확인 필요.'); end
save(datafile, 'data', 'dates', 'varNames');


% Model Specification

constant = 1;           % Add constant in VAR
exog = [];              % Specify Position of Exogenous Variables (optional);

p = 6;                  % Maximum lag order of factor VAR, LMN(2021) lag 차용
                          % lag 12로 둘 시 한국 식 계수가 100개를 넘어서 LMN 따라 축소
q = 2;                  % [수정] 한국 식에 들어가는 글로벌 변수 시차 (0~q)

h = 0;                  % Desired forecast horizon

DUM = double(dates == datenum(2020,3:7,1));          %%% [수정] COVID 더미 2020M3~M7 (diff 기준)
GX = [];                                             %%% [수정] 한국 식 외생변수: 글로벌 8변수의 0~q시차
for l = 0:q
    GX = [GX, [nan(l,8); data(1:end-l,1:8)]];
end


%% Reduced Form Priors

prior_settings.prior_family = 'conjugate';
prior_settings.prior = 'flat';                % Select 'flat' or 'Minnesota'

% Additional Settings of the Minnesota Prior
% prior_settings.stationary = [];             % Select which variables are a priori stationary
% 
% prior_settings.hyperparameters.lambda = .2; % Tightness of the Minnesota Prior; 
% prior_settings.hyperparameters.alpha = 2;   % Decay of the Minnesota Prior; 
% prior_settings.hyperparameters.psi = psi;   % Scale of the Minnesota Prior; 
% 
% prior_settings.NoCointegration = 1;         % Also known as Sum of Coefficients (1=Yes,0=no)
% prior_settings.SingleUnitRoot = 1;          % Also  known as Dummy Initial Observation (1=Yes,0=no)
% 
% prior_settings.hyperparameters.mu = 1;      % Tightness of the No Cointegration / Sum of Coefficients Prior
% prior_settings.hyperparameters.theta = 1;   % Tightness of the Dummy Initial Observation Priors

%% Structural Identification Settings

StructuralIdentification = 'Signs/Zeros';           % Chose 'None' or 'Signs/Zeros' or 'Choleski';
agnostic = 'irfs';  % select: 'structural' or 'irfs';

    % Set up Sign Restrictions

      % SR{r} = {Shockname,{Variable Names}, Horizon, Sign (1 or -1),};

        %%% [수정] Volcker MP 제약을 svar_diff.do 부호제약으로 교체. 글로벌 SRG, 한국 SRK로 나누고 아래 블록별 실행에서 SR에 넣는다
        %%% [수정] 충격 번호는 처음 나온 순서: 글로벌 1 D*, 2 MP*, 3 F*, 4 UF*, 5 UP*, 6~8 잔여 / 한국 1 S, 2 D, 3 MP, 4 F, 5 U, 6 잔여
        SRG{1}  = {'D*', {'dlusip','dlchn','dloil','us2y'} ,0, -1};   %%% [수정] D*: 미·중 IP, 유가, 미 2년 ↓
        SRG{2}  = {'MP*',{'us2y'}                          ,0,  1};   %%% [수정] MP*: 미 2년 ↑
        SRG{3}  = {'F*', {'ebp'}                           ,0,  1};   %%% [수정] F*: EBP ↑
        SRG{4}  = {'UF*',{'lvix'}                          ,0,  1};   %%% [수정] UF*: VIX ↑
        SRG{5}  = {'UP*',{'lusepu'}                        ,0,  1};   %%% [수정] UP*: 미 EPU ↑

        SRK{1}  = {'S',  {'dlip'}                          ,0, -1};   %%% [수정] S: IP ↓
        SRK{2}  = {'S',  {'dlcpi'}                         ,0,  1};   %%% [수정] S: CPI ↑
        SRK{3}  = {'D',  {'dlip','dlcpi'}                  ,0, -1};   %%% [수정] D: IP·CPI ↓
        SRK{4}  = {'D',  {'kr_call'}                       ,1, -1};   %%% [수정] D: 콜금리 ↓ (1개월)
        SRK{5}  = {'D',  {'kr_call'}                       ,2, -1};   %%% [수정] D: 콜금리 ↓ (2개월)
        SRK{6}  = {'MP', {'kr_call'}                       ,0,  1};   %%% [수정] MP: 콜금리 ↑ (당월)
        SRK{7}  = {'MP', {'kr_call'}                       ,1,  1};   %%% [수정] MP: 콜금리 ↑ (1개월)
        SRK{8}  = {'MP', {'dlfx'}                          ,0, -1};   %%% [수정] MP: 원/달러 ↓ (절상)
        SRK{9}  = {'F',  {'spread'}                        ,0,  1};   %%% [수정] F: 스프레드 ↑
        SRK{10} = {'U',  {'lkrepu'}                        ,0,  1};   %%% [수정] U: KR EPU ↑

    % Set up Elasticity Bound Restrictions

      % EBR{r} = {Shockname,{Variable Names}, Horizon, Maximum Bound};


    % Set up Narrative Sign Restrictions

      % NSR{r} = {'shockname',type of restriction ('sign of shock' or
      % 'contribution'), date, end date (for contributions only), variable
      % (for contributions only), sign, 'strong' or 'weak' for
      % contributions.

        % NSR{1} = {'MP','sign of shock',datenum(1979,10,01),1};
        % NSR{2} = {'MP','contribution',datenum(1979,10,01),datenum(1979,10,1),'FEDFUNDS',1,'strong'};

        %%% [수정] 서사 부호제약 {날짜, 충격, 부호} / Type A {날짜, 충격, 변수, 글로벌 기여 비교 1·0}.
        NSG = { datenum(2001,9,1),  'UF*', 1;   %%% 9/11
                datenum(2007,7,1),  'F*',  1;   %%% 서브프라임
                datenum(2007,8,1),  'UF*', 1;   %%% BNP 펀드 환매 중단
                datenum(2008,9,1),  'F*',  1;   %%% 리먼
                datenum(2008,9,1),  'UF*', 1;
                datenum(2008,10,1), 'F*',  1;
                datenum(2008,10,1), 'UF*', 1;
                datenum(2011,8,1),  'UF*', 1;   %%% 미 신용등급 강등
                datenum(2011,8,1),  'UP*', 1;
                datenum(2025,4,1),  'UP*', 1 }; %%% 상호관세
        NTG = { datenum(2007,8,1),  'UF*', 'lvix',   0;     %%% VIX 변화의 최대 기여
                datenum(2025,4,1),  'UP*', 'lusepu', 0 };   %%% 미 EPU 변화의 최대 기여

        NSK = { datenum(2024,12,1), 'U', 1;     %%% 비상계엄
                datenum(2016,11,1), 'U', 1;     %%% 국정농단
                datenum(2004,3,1),  'U', 1;     %%% 탄핵소추
                datenum(2022,11,1), 'F', 1;     %%% 흥국생명 콜 미행사
                datenum(2003,3,1),  'F', 1;     %%% SK글로벌·카드채
                datenum(2022,10,1), 'F', 1 };   %%% 레고랜드
        NTK = { datenum(2024,12,1), 'U', 'lkrepu', 1 };     %%% KR EPU 변화의 최대 기여 (글로벌 기여 포함 비교)


cumulateWhich = []; % Compute Cumulated IRFs for Plots

    
%% Gibss Sampler Settings

numDesiredDraws = 5000;
BetaSigmaTries = 10;        %%% [수정] 100 → 10. 한 묶음에서 뽑는 축약형 수
                            %%%        임시 배열이 (묶음 축약형 수 × 회전 수) 크기로 잡힘. 원본은 회전 100이라 문제없었지만
                            %%%        여기는 글로벌 회전 2500이라 100이면 묶음마다 약 1.2GB, 10이면 약 130MB
                            %%%        묶음 크기만 바뀌고 결과는 같음. maxRFDraws는 이 값의 배수로 둘 것
%Qs_per_BetaSigma = 100;
maxRFDraws = 2000;          %%% [수정] 축약형 추출 상한 (svar_diff.do nd)

nRepsWeights = 1000;        %%% [수정] Type A 통과확률 시뮬레이션 횟수 (svar_diff.do M)
                            %%%        원본 코드에서는 서사 전체 동시 시뮬레이션 횟수였음
dfTk = 1;                   %%% [수정] Σ 자유도. 1: T-k (svar_diff.do), 0: T (og)
                            %%%        강건성 확인 용으로 1, 0 모두 돌려서 corr 확인해보기!!!
                            %%%        식별(통과 회전 집합)은 크게 영향 없으나 충격 크기 상이
dropExplosive = 0;          %%% [수정] 1: 최대근 > 1인 축약형 추출 버림 (og), 0: 안 버림 (svar_diff.do)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% End of Code that is Edited Frequently %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    

rng(1)

%%% [수정] Block exogeneity: 두 블록 따로 추정 (Zha, 1999)
%%% [수정] Global block 8 vars: 우변에 한국 변수 없음 (시차 블록외생성)
panelselect = 1:8;
exog = DUM;
SR = SRG;
NS = NSG;  NT = NTG;  glob = [];    %%% [수정] 서사제약. 글로벌 블록은 글로벌 기여 비교 없음
Qs_per_BetaSigma = 2500;            %%% [수정] 축약형 1개당 회전 수 (svar_diff.do Rg)
cumulateWhich = [1 2 3 8];          %%% [수정] 차분 변수 IRF를 수준 반응으로 누적 (dlusip, dlchn, dloil, dldxy)

Run_SVAR_koo    %%% [수정] `Run_SVAR_koo.m` 파일 참고

save(fullfile('Output','KOR_nsr_global.mat'), 'Draws_IRFs','Draws_Shocks','w_save','RF_save', ...
     'Beta_save','Sigma_save','A0_save','shockNames','varNames','tz','exog','p','-v7.3');   %%% [수정] 블록 2 실행 때 덮어써지므로 먼저 저장

glob.post  = posteriors;    %%% [수정] 한국 Type A에서 쓸 글로벌 축약형 사후분포
glob.U0    = Yp;            %%% [수정] 글로벌 변수 (유효표본)
glob.X     = X;             %%% [수정] 글로벌 식 우변 [상수, 더미, 시차]
glob.dates = tz;            %%% [수정] 글로벌 블록 유효표본 날짜

%%% [수정] Domestic block 6 vars: 우변에 글로벌 변수 동시기 + 1~q시차 (동시기·시차 블록외생성)
panelselect = 9:14;
exog = [DUM, GX];
SR = SRK;
NS = NSK;  NT = NTK;        %%% [수정] 서사제약 + 2024M12 Type A 글로벌 기여 비교
glob.idxC0 = constant + size(DUM,2) + (1:8);   %%% [수정] 한국 식 계수 중 글로벌 동시기 변수 행 (상수, 더미 다음)
Qs_per_BetaSigma = 500;     %%% [수정] svar_diff.do Rk
cumulateWhich = [1 2 5];    %%% [수정] dlip, dlcpi, dlfx 누적

Run_SVAR_koo    %%% [수정] `Run_SVAR_koo.m` 파일 참고

save(fullfile('Output','KOR_nsr_korea.mat'), 'Draws_IRFs','Draws_Shocks','w_save','RF_save', ...
     'Beta_save','Sigma_save','A0_save','shockNames','varNames','tz','exog','p','q','-v7.3');


%%% [수정] 결과 요약: 월별 가중 중앙값, Pr(>0). svar_diff.do 8절 summary 시트와 같은 형식
A = load(fullfile('Output','KOR_nsr_korea.mat'),  'Draws_Shocks','w_save','tz');
B = load(fullfile('Output','KOR_nsr_global.mat'), 'Draws_Shocks','w_save','tz');
wA = A.w_save(:);  wB = B.w_save(:);     %%% [수정] 가중치 (열벡터)
med = @(E,w) arrayfun(@(t) wquant(E(t,:)', w, 0.5), (1:size(E,1))');
EU  = squeeze(A.Draws_Shocks(:,5,:));    %%% [수정] 한국 5 U
EF  = squeeze(A.Draws_Shocks(:,4,:));    %%% [수정] 한국 4 F
EUP = squeeze(B.Draws_Shocks(:,5,:));    %%% [수정] 글로벌 5 UP*
EUF = squeeze(B.Draws_Shocks(:,4,:));    %%% [수정] 글로벌 4 UF*
EFg = squeeze(B.Draws_Shocks(:,3,:));    %%% [수정] 글로벌 3 F*
ym  = cellstr(datestr(A.tz,'yyyy-mm'));
tab = table(ym, med(EU,wA), (EU>0)*wA/sum(wA), med(EF,wA), med(EUP,wB), (EUP>0)*wB/sum(wB), med(EUF,wB), med(EFg,wB), ...
      'VariableNames', {'ym','epsU_med','prU_pos','epsF_med','epsUP_med','prUP_pos','epsUF_med','epsFg_med'});
writetable(tab, fullfile('Output','shocks_KOR_nsr.xlsx'), 'Sheet', 'summary');