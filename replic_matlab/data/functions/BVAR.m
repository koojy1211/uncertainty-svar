function [B_draw,SIGMA_draw,posteriors] = BVAR(Yraw,exogenous,p,prior_settings,draws)
%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here

% Y_{t} = c + B_{1}*Y_{t-1} + ... + B_{p}*Y_{t-p} + u_{t}


%% --------------------------DATA HANDLING---------------------------------

% Get dimensions of dependent variable matrix
[Traw, n] = size(Yraw);

% Generate lagged Y matrix. This will be part of the X matrix
Ylags = mlag2(Yraw,p); % Y is [T x M]. ylag is [T x (Mp)]

if isempty(exogenous)
    X = Ylags(p+1:Traw,:);
else
    X = [exogenous(p+1:Traw,:) Ylags(p+1:Traw,:)];
end

if size(exogenous,2)==0;
    constant=0;
else constant = 1;
end

Y = Yraw(p+1:Traw,:);       % Delete first "p" rows accordingly
Z = kron(eye(n),X);         % Create the block diagonal matrix Z

Y0 = mean(Yraw(1:p,:),1);   % Save the average of the first "p" rows

[T, K] = size(X);           % Get size of final matrix X


%% ------------------------- RETRIEVE PRIOR SETTINGS ----------------------

hyperparameters = [];

v2struct(prior_settings);
if exist('hyperparameters', 'var'), v2struct(hyperparameters); end
if ~exist('stationary','var'), stationary = []; end

%% -------------------------DUMMY OBSERVATIONS FOR PRIOR ------------------

Td = 0;

if exist('Y0bar','var')
    Y0(~isnan(Y0bar)) = Y0bar(~isnan(Y0bar));
end

if ~exist('gbar','var')
    gbar = zeros(1,n);
end

if strcmp(prior,'Minnesota')
    
%     if GrowthRatePrior == 1;
%         
%         if ~exist('gamma','var'), gamma = 1; end
%         
%         
%         YdummyGrowthRatePrior = (1/gamma).*(gbar);
%         XdummyGrowthRatePrior = [ones(1,constant)./gamma repmat((0*Y0),1,p)];
%             
%         Y = [YdummyGrowthRatePrior; Y];
%         X = [XdummyGrowthRatePrior; X];
%         
%         Td = Td+n;      
%     end
    
    if NoCointegration == 1; % Also known as Sum of Coefficients Prior
        
        if ~exist('mu','var'), mu = 1; end
        
            if length(mu)>1
            YdummyNoCointegration = zeros(n);
            for i = 1:n
                YdummyNoCointegration(i,i) = (1/mu(i))*Y0(i);
            end
            XdummyNoCointegration = [zeros(n,constant) repmat(YdummyNoCointegration,1,p)];
        
            else
        
            YdummyNoCointegration = (1/mu)*diag(Y0);
            YdummyNoCointegration(stationary,stationary)=0;
            XdummyNoCointegration = [zeros(n,constant) (1/mu)*repmat(diag(Y0),1,p)];
            
            end
        
        Y = [YdummyNoCointegration; Y];
        X = [XdummyNoCointegration; X];
        
        Td = Td+n;
        
    end
    
    if SingleUnitRoot == 1;    % Also known as Dummy Initial Observation
        
        if ~exist('theta','var'), theta = 1; end
        if ~exist('H','var'), H = eye(n); end
  
        YdummySUR=(1/theta)*Y0;
        XdummySUR=[ones(1,constant)/theta (1/theta)*repmat(Y0,1,p)];
        Y = [YdummySUR; Y];
        X = [XdummySUR; X];
        Td = Td + 1;
        
    end
    
    if LongRunPrior == 1;
        
        if ~exist('phi1','var'), phi1 = ones(1,n); end
        if ~exist('H','var'), H = eye(n); end
        
        invH = inv(H);
        
        YdummyLongRunPrior = nan(n);
        
        for i = 1:n
            YdummyLongRunPrior(i,:) = ((1/phi1(i)) * H(i,:) * Y0' * invH(:,i))';
        end
        
        XdummyLongRunPrior = [zeros(n,1) repmat(YdummyLongRunPrior,1,p)];
        
        Y = [YdummyLongRunPrior; Y];
        X = [XdummyLongRunPrior; X];
        
        Td = Td+n;
        
    end
        
    if LongRunPrior2 == 1;
        
        r = hyperparameters.Hr;
       
        if ~exist('phi2','var'), phi2 = ones(1,n-r+1); end
        if ~exist('H','var'), H = eye(n); end
        
        invH = inv(H);
        
        YdummyLongRunPrior = nan(n-r+1,n);
        
        for i = 1:n-r
            YdummyLongRunPrior(i,:) = ((1/phi2(i)) * (H(i,:) * Y0' * invH(:,i)))';
        end
        
        YdummyLongRunPrior(n-r+1,:) = (invH(:,n-r+1:n) * (1/phi2(n-r+1)) * H(n-r+1:n,:) * (Y0'))';
        
        priorConstant = [zeros(n-r,1); 1/phi2(end)];
        XdummyLongRunPrior = [priorConstant repmat(YdummyLongRunPrior,1,p)];
                
%         YdummyLongRunPrior(n-r+1,:) = YdummyLongRunPrior(n-r+1,:) + (1/phi2(n-r+1)) * ((gbar)/H');
        
        Y = [YdummyLongRunPrior; Y];
        X = [XdummyLongRunPrior; X];
        
        Td = Td+n-r+1;        
        
        
    end
        
   
    T = T + Td;
    
end
%% --------------------------OLS QUANTITIES--------------------------------

B_OLS = (X'*X)\(X'*Y); % OLS matrix of coefficients
b_OLS = B_OLS(:);

U_OLS = Y-X*B_OLS;     % OLS residuals
SSE = U_OLS'*U_OLS;    % Residual Sum of Squares

SIGMA_OLS = SSE/T;     % OLS covariance matrix of residuals


%% ----------------------------- PRIOR ------------------------------------

switch prior_family
    
    case 'conjugate'
        
        switch prior
            
            case 'flat'      % Flat (Jefferys)
                
                B_0 = B_OLS;
                N0 = zeros(K);
                
                S_0 = SIGMA_OLS;
                v0 = 0;
                
            case 1      % Normal/Inverse Wishart, Informative
                
                B_0 = prior_settings.hyperparameters.B_0;
                N0 = prior_settings.hyperparameters.N0;
                
                S_0 = prior_settings.hyperparameters.S_0;
                v0 = prior_settings.hyperparameters.v0;
                
            case 'Minnesota'      % Minnesota (Litterman)
                
                % Default Values
                if ~exist('alpha','var'), alpha = 2; end       % lag-decaying parameter of the MN prior
                if ~exist('lambda','var'), lambda = .2; end     % std of MN prior
                if ~exist('Vc','var'), Vc = 1E6; end
                
                if ~exist('psi','var')                        % residual variance of AR(1) for each variable
                    psi = nan(n,1);
                    for i=1:n
                        ar1=ols1(Yraw(2:end,i),[ones(Traw-1,1),Yraw(1:end-1,i)]);
                        psi(i)=ar1.sig2hatols;
                    end
                end
                
                [B_0,N0] = SetMinnesotaPrior(n,p,constant,alpha,Vc,lambda,psi,stationary);
                
                S_0 = diag(psi);
                v0 = n+2;
                
                
            case 'gibbs'
                
                
        end
        
        %% ----------------------------- POSTERIOR ------------------------------------
        
        switch prior_settings.prior_family
            
            case 'conjugate'
                
                NT = N0 + X'*X;
                BbarT = inv2(NT)*(N0*B_0 + (X'*X)*B_OLS);
                
                b_post = BbarT(:);
                
                vT = T + v0;
                ST = (v0/vT)*S_0 + (T/vT)*SIGMA_OLS + (1/vT)*((B_OLS-B_0)')*N0*inv2(NT)*(X'*X)*(B_OLS-B_0);
                
                S_post = ST*vT;
                v_post = vT;
                
                
            case 'gibbs'
                
        end
        
        
        %% ----------------------------- DRAW -------------------------------------
        invS_post = inv(S_post);
        
        
        SIGMA_draw = inv2(wish(invS_post,v_post));
        %             SIGMA_draw = iwishrnd(S_post,v_post);
        V_B_post = kron(SIGMA_draw,inv2(NT));
        
        V_B_post = (V_B_post + V_B_post')./2;
        
        B_draw = mvnrnd(b_post,V_B_post);
        
        B_draw = reshape(B_draw,K,n);
        
        posteriors = v2struct(invS_post,v_post,NT,vT,ST,b_post,K,n,S_post);
        %     posteriors = v2struct(S_post,v_post,NT,b_post,K,n);
        
        
end

