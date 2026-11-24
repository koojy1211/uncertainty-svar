%% Code for Structuctural VAR %%

% Supports Sign, Zero and Narrative Sign Restrictions, as well as Conjugate
% Priors on the Reduced Form

% Revision History:
% 06/12/2016  - Juan Antolin-Diaz - Version 1

clear
clc

addpath('data')
addpath('functions')

%% Reduced form Settings

% Data Location and Adjustments

datafile = fullfile('data','KOR_SVAR.mat');   %%% [수정] 아래에서 DATA.xlsx로 만들어 저장하는 파일
panelselect = [];                   % Choose subset and/or re-order variables (optional); Empty = use all;   %%% [수정] 블록별로 아래에서 지정 (1:8 글로벌, 9:14 한국)

startYear = 2000;
endYear   = 2026;

%%% [수정] 데이터: 레포 data 폴더 DATA.xlsx의 VAR 시트 (svar_diff.do와 같은 파일)
raw = readtable(fullfile('..','data','DATA.xlsx'),'Sheet','VAR');      %%% [수정]
srcNames = {'lusip','lchn','loil','us2y','ebp','lvix','lusepu','ldxy', ...
            'lip','lcpi','kr_call','spread','lfx','lkrepu'};           %%% [수정] 1~8 글로벌, 9~14 한국
varNames = {'dlusip','dlchn','dloil','us2y','ebp','lvix','lusepu','dldxy', ...
            'dlip','dlcpi','kr_call','spread','dlfx','lkrepu'};        %%% [수정] d = 차분 변수
isDiff = logical([1 1 1 0 0 0 0 1 1 1 0 0 1 0]);                      %%% [수정] 단위근 기각 못한 7개만 차분, 금리는 수준
Ylev = raw{:, srcNames};                                               %%% [수정]
data = Ylev(2:end, :);                                                 %%% [수정] 차분으로 2000M1 삭제
data(:, isDiff) = diff(Ylev(:, isDiff));                               %%% [수정]
dates = datenum(raw.date(2:end));                                      %%% [수정] 매월 1일 datenum
dv = datevec(dates);                                                   %%% [수정]
keep = dv(:,1) >= startYear & dv(:,1) <= endYear;                      %%% [수정] 표본을 먼저 잘라 exog와 행 수를 맞춘다
data = data(keep, :);                                                  %%% [수정]
dates = dates(keep);                                                   %%% [수정]
if any(isnan(data(:))), error('DATA.xlsx VAR 시트에 결측이 있다. Excel에서 열어 저장했는지 확인할 것'); end   %%% [수정] svar_diff.do 1절과 같은 점검
save(datafile, 'data', 'dates', 'varNames');                          %%% [수정]

% Model Specification

constant = 1;                           % Add constant in VAR   %%% [수정] 0 → 1
exog = [];                              % Specify Position of Exogenous Variables (optional);

p = 6;                                  % Maximum lag order of factor VAR   %%% [수정] 12 → 6
q = 2;                                  %%% [수정] 한국 식에 들어가는 글로벌 변수 시차 (0~q)

h = 0;                                  % Desired forecast horizon

DUM = double(dates == datenum(2020,3:7,1));          %%% [수정] COVID 더미 2020M3~M7 (차분판 기준)
GX = [];                                             %%% [수정] 한국 식 외생변수: 글로벌 8변수의 0~q시차
for l = 0:q                                          %%% [수정]
    GX = [GX, [nan(l,8); data(1:end-l,1:8)]];        %%% [수정] 앞 l행은 결측이지만 p > q라 추정에 안 쓰인다
end                                                  %%% [수정]


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

        % NSR{1} = {'MP','sign of shock',datenum(1979,10,01),1};   %%% [수정] Volcker 제약은 표본 밖이라 끔. 서사제약은 다음 단계
        % NSR{2} = {'MP','contribution',datenum(1979,10,01),datenum(1979,10,1),'FEDFUNDS',1,'strong'};   %%% [수정]


cumulateWhich = []; % Compute Cumulated IRFs for Plots


%% Gibss Sampler Settings

numDesiredDraws = 5000;
BetaSigmaTries = 100;
Qs_per_BetaSigma = 100;

nRepsWeights = 1000;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% End of Code that is Edited Frequently %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

rng(1)

%%% [수정] 블록외생성: 두 블록을 따로 추정한다 (Zha 1999 블록 재귀, svar_diff.do와 같은 구조)
%%% [수정] 블록 1 글로벌 8변수: 우변에 한국 변수 없음 (시차 블록외생성)
panelselect = 1:8;                  %%% [수정]
exog = DUM;                         %%% [수정] 상수항은 Run_SVAR_v1이 앞에 붙인다
SR = SRG;                           %%% [수정]
cumulateWhich = [1 2 3 8];          %%% [수정] 차분 변수 IRF를 수준 반응으로 누적 (dlusip, dlchn, dloil, dldxy)

Run_SVAR_v1

save(fullfile('Output','KOR_block_global.mat'), 'Draws_IRFs','Draws_Shocks','Beta_save','Sigma_save','A0_save', ...
     'shockNames','varNames','dates','exog','p','-v7.3');   %%% [수정] 블록 2 실행 때 덮어써지므로 먼저 저장

%%% [수정] 블록 2 한국 6변수: 우변에 글로벌 변수 동시기 + 1~q시차 (동시기·시차 블록외생성)
panelselect = 9:14;                 %%% [수정]
exog = [DUM, GX];                   %%% [수정]
SR = SRK;                           %%% [수정]
cumulateWhich = [1 2 5];            %%% [수정] dlip, dlcpi, dlfx 누적

Run_SVAR_v1

save(fullfile('Output','KOR_block_korea.mat'), 'Draws_IRFs','Draws_Shocks','Beta_save','Sigma_save','A0_save', ...
     'shockNames','varNames','dates','exog','p','q','-v7.3');   %%% [수정]

%% Some Results

% Plot_IRFs_Monetary                 %%% [수정] Uhlig 데이터 전용(변수 번호, 1979 날짜 고정)이라 그대로 돌리면 오류. 일단 끔

% Plot_HDs_Monetary                  %%% [수정]

% Plot_Shock_Distribution_Monetary   %%% [수정]
