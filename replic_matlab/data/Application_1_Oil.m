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

datafile = 'Kilian_Data_Updated';
panelselect = [1:3];                % Choose subset and/or re-order variables (optional); Empty = use all;

startYear = 1971;                       % Choose start year
endYear = 2015;                           

% Model Specification

constant = 1;                           % Add constant in VAR
exog = [];                              % Specify Position of Exogenous Variables (optional);

p = 24;                                  % Maximum lag order of factor VAR
    
h = 0;                                  % Desired forecast horizon


%% Reduced Form Priors

prior_settings.prior_family = 'conjugate';
prior_settings.prior = 'flat';                % Select 'flat' or 'Minnesota'

% Additional Settings of the Minnesota Prior
% prior_settings.stationary = [1:3];
% 
% prior_settings.hyperparameters.lambda = .2; % Tightness of the Minnesota Prior; 
% prior_settings.hyperparameters.alpha = 2;   % Decay of the Minnesota Prior; 
% prior_settings.hyperparameters.psi = psi;   % Scale of the Minnesota Prior; 
% 
% prior_settings.NoCointegration = 1;         % Also known as Sum of Coefficients
% prior_settings.SingleUnitRoot = 1;          % Also  known as Dummy Initial Observation
% 
% prior_settings.hyperparameters.mu = 1;      % Tightness of the No Cointegration / Sum of Coefficients Prior
% prior_settings.hyperparameters.theta = 1;   % Tightness of the Dummy Initial Observation Priors

%% Structural Identification Settings

StructuralIdentification = 'Signs/Zeros';           % Chose 'None' or 'Signs/Zeros' or 'Choleski';
agnostic = 'irfs';  % select: 'structural' or 'irfs';
       
    % Set up Sign Restrictions
        
      % SR{r} = {Shockname,{Variable Names}, Horizon, Sign (1 or -1),};
        
        SR{1} = {'Oil Supply',{'Oil Production Growth','Economic Activity Index'}                           ,0,  -1};
        SR{2} = {'Oil Supply',{'Real Oil Price'}                                                            ,0,   1};
        SR{3} = {'Aggregate Demand',{'Oil Production Growth','Economic Activity Index','Real Oil Price'}    ,0,   1};
        SR{4} = {'Oil-specific Demand',{'Oil Production Growth','Real Oil Price'}                           ,0,   1};
        SR{5} = {'Oil-specific Demand',{'Economic Activity Index'}                                          ,0,  -1};
        
        
    % Set up Elasticity Bound Restrictions
    
      % EBR{r} = {Shockname,{Variable Names}, Horizon, Maximum Bound};
    
        EBR{1} = {'Aggregate Demand',{'Oil Production Growth','Real Oil Price'},    0,0.0258};
        EBR{2} = {'Oil-specific Demand',{'Oil Production Growth','Real Oil Price'}, 0,0.0258};

    % Set up Narrative Sign Restrictions
        
      % NSR{r} = {'shockname',type of restriction ('sign of shock' or
      % 'contribution'), date, end date (for contributions only), variable 
      % (for contributions only), sign, 'strong' or 'weak' for
      % contributions.
            
%         NSR{1} = {'Oil Supply','sign of shock',datenum(1990,08,31),1};
        
        NSR{1} = {'Aggregate Demand','contribution',datenum(1990,08,01),datenum(1990,08,01),'Real Oil Price',-1,'strong'};


cumulateWhich = [1]; % Compute Cumulated IRFs for Plots

    
%% Gibss Sampler Settings

numDesiredDraws = 1000;
BetaSigmaTries = 100;
Qs_per_BetaSigma = 100;

nRepsWeights = 1000;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% End of Code that is Edited Frequently %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    

rng(1)

Run_SVAR_v1

%% Some Results

% Impulse Responses

Plot_IRFs_Oil

% Forecast Error Variance Decompositions

Plot_FEVDs_Oil

% Historical Decompositions

startDate = [datenum(1990,07,01)];
endDate = [datenum(1990,12,01)];
numticks = 1;
ymin = -25;
ygap = 25;
ymax = 75;

PlotHDWithBands


startDate = [datenum(2004,01,01)];
endDate = [datenum(2008,07,01)];
numticks = 12;

ymin = -50;
ygap = 25;
ymax = 100;

PlotHDWithBands



startDate = [datenum(2014,07,01)];
endDate = [datenum(2015,12,01)];
numticks = 3;
ymin = -75;
ygap = 25;
ymax = 25;

PlotHDWithBands
