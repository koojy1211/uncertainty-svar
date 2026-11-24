function [Beta_narrative,Sigma_narrative,A0_narrative,weights_narrative] = CheckNarrativeAndReWeight(y,p,Beta_save,Sigma_save,A0_save,exog,Ns,Nc,nDrawWeights)
%CheckNarrative This function takes as input the draws from Beta, Sigma,
%and A0, checks whether they satisfy the narrative sign restrictions and
%re-weights them using importance sampling.

%% Step 1. Check the narrative restrictions
    
    [T,n] = size(y);

    numSavedDraws = size(Beta_save,3);
    check_narrative = nan(numSavedDraws,1);
    weights = zeros(numSavedDraws,1);
    
    Ns = Ns(p+1:end,:);
    Nc = Nc(p+1:end,p+1:end,:,:);
    [startperiod,endperiod,shock,variable] = ind2sub(size(Nc),find(Nc~=0));
    findnarrativecontrib = find(Nc~=0);

    parfor draw = 1:numSavedDraws
                        
        BETA = Beta_save(:,:,draw);
        
        B = BETA(size(exog,2)+1:end,:)';
        c = BETA(1:size(exog,2),:)';
        A0 = A0_save(:,:,draw);
        
        [shocks] = get_shocks(y,exog,A0,c,B,p);
        
        [IRFs] = getIRFs(BETA,A0,exog,n,p,4);
        
        [check] = CheckNarrativeRestrictions_fast(IRFs,n,shocks,Ns,Nc,startperiod,endperiod,shock,variable,findnarrativecontrib);

        check_narrative(draw) = check;

        % Compute importance weights

        if check

        check_simulated = nan(nDrawWeights,1);
        for rep = 1:nDrawWeights
          fake_shocks = randn(T-p,n);
          check_simulated(rep) = CheckNarrativeRestrictions_fast(IRFs,n,fake_shocks,Ns,Nc,startperiod,endperiod,shock,variable,findnarrativecontrib);
        end
        weights(draw) = nDrawWeights/(sum(check_simulated));

        end

    end

disp(strcat('Number of Draws that Satisfy sign restriction on IRFs:',num2str(numSavedDraws)))
disp(strcat('Number of Draws that Satisfy L0 restrictions + Narrative:',num2str(sum(check_narrative)),...
    '(',num2str(100*sum(check_narrative)/numSavedDraws),'%)'))



%% Step 2. Re-sample draws that satisfy narrative restrictions

Beta_narrative    = Beta_save(:,:,logical(check_narrative));
Sigma_narrative   = Sigma_save(:,:,logical(check_narrative));
A0_narrative      = A0_save(:,:,logical(check_narrative));
weights_narrative = weights(logical(check_narrative));


if sum(isfinite(weights_narrative))~=length(weights_narrative)
    disp('Warning: Results not accurate, please increase numRepsWeights')
else
    disp('OK')
end

numSavedNarrative = sum(check_narrative);

resample = randsample(numSavedNarrative,numSavedNarrative,true,weights_narrative);

Beta_narrative   = Beta_narrative(:,:,resample);
Sigma_narrative  = Sigma_narrative(:,:,resample);
A0_narrative     = A0_narrative(:,:,resample);

uniqueNarrativeDraws = length(unique(squeeze(Beta_narrative(1,1,:))));

disp(strcat('Unique number of draws that satisfy the narrative sign restrictions:',num2str(uniqueNarrativeDraws)));
disp('If this number is low, consider increasing the total number of draws')


end

