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

datafile = 'Uhlig_Data_Updated';
panelselect = [1:6];                % Choose subset and/or re-order variables (optional); Empty = use all;

startYear = 1965;                       % Choose start year
endYear = 2007;                           

% Model Specification

constant = 0;                           % Add constant in VAR
exog = [];                              % Specify Position of Exogenous Variables (optional);

p = 12;                                  % Maximum lag order of factor VAR
    
h = 0;                                  % Desired forecast horizon


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
        
        SR{1} = {'MP',{'FEDFUNDS'}                           ,0,  1};
        SR{2} = {'MP',{'GDPDEF','CPRINDEX','BOGNONBR'}       ,0, -1};       
        SR{3} = {'MP',{'FEDFUNDS'}                           ,1,  1};
        SR{4} = {'MP',{'GDPDEF','CPRINDEX','BOGNONBR'}       ,1, -1};
        SR{5} = {'MP',{'FEDFUNDS'}                           ,2,  1};
        SR{6} = {'MP',{'GDPDEF','CPRINDEX','BOGNONBR'}       ,2, -1}; 
        SR{7} = {'MP',{'FEDFUNDS'}                           ,3,  1};
        SR{8} = {'MP',{'GDPDEF','CPRINDEX','BOGNONBR'}       ,3, -1};   
        SR{9} = {'MP',{'FEDFUNDS'}                           ,4,  1};
        SR{10} = {'MP',{'GDPDEF','CPRINDEX','BOGNONBR'}      ,4, -1}; 
        SR{11} = {'MP',{'FEDFUNDS'}                          ,5,  1};
        SR{12} = {'MP',{'GDPDEF','CPRINDEX','BOGNONBR'}      ,5, -1}; 
        
    % Set up Elasticity Bound Restrictions
    
      % EBR{r} = {Shockname,{Variable Names}, Horizon, Maximum Bound};
    

    % Set up Narrative Sign Restrictions
        
      % NSR{r} = {'shockname',type of restriction ('sign of shock' or
      % 'contribution'), date, end date (for contributions only), variable 
      % (for contributions only), sign, 'strong' or 'weak' for
      % contributions.
            
        NSR{1} = {'MP','sign of shock',datenum(1979,10,01),1};
        NSR{2} = {'MP','contribution',datenum(1979,10,01),datenum(1979,10,1),'FEDFUNDS',1,'strong'};


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

Run_SVAR_v1

%% Some Results

Plot_IRFs_Monetary

Plot_HDs_Monetary

Plot_Shock_Distribution_Monetary

