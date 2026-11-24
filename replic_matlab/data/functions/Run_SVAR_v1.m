
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

Beta_mean = reshape(posteriors.b_post,K,n);
% Sigma_mean = posteriors.S_post;

%% Retrieve the S, Z, and Narrative matrices for identification

if ~exist('SR','var'),  SR = []; end
if ~exist('ZR','var'),  ZR = []; end
if ~exist('NSR','var'), NSR = []; end
if ~exist('EBR','var'), EBR = []; end

[S,Z,hirfs,Ns,Nc,shockNames] = getRestrictions(SR,ZR,NSR,varNames,dates);

%% Gibbs Sampler for Traditional Sign and Zero Restrictions

% Allocate Space for Saving Draws

Beta_save = nan(K,n,numDesiredDraws);
Sigma_save = nan(n,n,numDesiredDraws);
A0_save = nan(n,n,numDesiredDraws);
Q_save = nan(n,n,numDesiredDraws);
w_save = nan(1,numDesiredDraws);

numSavedDraws = 0;
numAttempts = 0;

while numSavedDraws < numDesiredDraws
    
    tic
    
    Beta_temp = nan(K,n,BetaSigmaTries,Qs_per_BetaSigma);
    Sigma_temp = nan(n,n,BetaSigmaTries,Qs_per_BetaSigma);
    A0_temp = nan(n,n,BetaSigmaTries,Qs_per_BetaSigma);
    Q_temp = nan(n,n,BetaSigmaTries,Qs_per_BetaSigma);
    w_temp = nan(1,BetaSigmaTries,Qs_per_BetaSigma);
    
    for worker = 1:BetaSigmaTries

        check = 0;
        [B_draw,SIGMA_draw] = BVAR_1draw(posteriors);
        
        maxRoot = max(abs(getRoots(B_draw(size(exog,2)+1:end,:)')));
        
        if maxRoot <= 1
        
            for Q_count = 1:Qs_per_BetaSigma
                
              if strcmp(StructuralIdentification,'Choleski')

                Beta_temp(:,:,worker,Q_count) = B_draw;
                Sigma_temp(:,:,worker,Q_count) = SIGMA_draw;                      
                A0_temp(:,:,worker,Q_count) = inv(chol(SIGMA_draw));
                Q_temp(:,:,worker,Q_count) = eye(n);
                w_temp(:,worker,Q_count) = 1;
                
              else
                  
              % Check Sign and Zero Restrictions

              [A0tilde_draw,Qdraw,uw] = SignAndZeroRestrictions(B_draw,SIGMA_draw,p,exog,hirfs,S,Z,agnostic);
              
                if isfinite(A0tilde_draw(1,1))
                    
                    % Check Elasticity Bound Restrictions if Present

                    [checkElasticity] = ElasticityBoundRestrictions(EBR,varNames,shockNames,B_draw,A0tilde_draw,exog,n,p);
               
                    if checkElasticity                       

                    Beta_temp(:,:,worker,Q_count) = B_draw;
                    Sigma_temp(:,:,worker,Q_count) = SIGMA_draw;
                    A0_temp(:,:,worker,Q_count) = A0tilde_draw;
                    Q_temp(:,:,worker,Q_count) = Qdraw;
                    w_temp(:,worker,Q_count) = uw;
                
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
      
    Beta_clean=Beta_clean(:,:,isfinite(squeeze(A0_clean(1,1,:))));
    Sigma_clean=Sigma_clean(:,:,isfinite(squeeze(A0_clean(1,1,:))));
    A0_clean=A0_clean(:,:,isfinite(squeeze(A0_clean(1,1,:))));  
    Q_clean=Q_clean(:,:,isfinite(squeeze(Q_clean(1,1,:))));  
    w_clean=w_clean(:,isfinite(w_clean));  

    numAcceptedDraws = size(Beta_clean,3);

    if numAcceptedDraws > 0
        Beta_save(:,:,numSavedDraws+1:numSavedDraws+numAcceptedDraws) = Beta_clean;
        Sigma_save(:,:,numSavedDraws+1:numSavedDraws+numAcceptedDraws) = Sigma_clean;
        A0_save(:,:,numSavedDraws+1:numSavedDraws+numAcceptedDraws) = A0_clean;
        Q_save(:,:,numSavedDraws+1:numSavedDraws+numAcceptedDraws) = Q_clean;
        w_save(:,numSavedDraws+1:numSavedDraws+numAcceptedDraws) = w_clean;
        
        numSavedDraws = numSavedDraws + numAcceptedDraws;
    end

    numAttempts = numAttempts + (BetaSigmaTries*Qs_per_BetaSigma);

    disp(strcat('Attempted Draws:',num2str(numAttempts)))
    disp(strcat('Successful Draws:',num2str(numSavedDraws)))
    toc    
    
end

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