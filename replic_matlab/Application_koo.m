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

constant = 0;           % Add constant in VAR
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

%%% [수정] Block exogeneity: 두 블록 따로 추정 (Zha, 1999)
%%% [수정] Global block 8 vars: 우변에 한국 변수 없음 (시차 블록외생성)
panelselect = 1:8;
exog = DUM;
SR = SRG;
cumulateWhich = [1 2 3 8];          %%% [수정] 차분 변수 IRF를 수준 반응으로 누적 (dlusip, dlchn, dloil, dldxy)

Run_SVAR_v1

save(fullfile('Output','KOR_block_global.mat'), 'Draws_IRFs','Draws_Shocks','Beta_save','Sigma_save','A0_save', ...
     'shockNames','varNames','dates','exog','p','-v7.3');   %%% [수정] 블록 2 실행 때 덮어써지므로 먼저 저장

%%% [수정] Domestic block 6 vars: 우변에 글로벌 변수 동시기 + 1~q시차 (동시기·시차 블록외생성)
panelselect = 9:14;
exog = [DUM, GX];
SR = SRK;
cumulateWhich = [1 2 5];            %%% [수정] dlip, dlcpi, dlfx 누적

Run_SVAR_v1

save(fullfile('Output','KOR_block_korea.mat'), 'Draws_IRFs','Draws_Shocks','Beta_save','Sigma_save','A0_save', ...
     'shockNames','varNames','dates','exog','p','q','-v7.3');
