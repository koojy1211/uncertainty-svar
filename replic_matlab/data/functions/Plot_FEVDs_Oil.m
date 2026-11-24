%% Forecast Error Variance Decompositions With Bands
hmaxtoplot = 120;

draws_FEVDs = nan(n,n,hmaxtoplot+1,numSavedDraws); % variable,shock,horizon,draw
draws_FEVDs_narrative = nan(n,n,hmaxtoplot+1,numSavedNarrative); % variable,shock,horizon,draw

parfor draw = 1:numSavedDraws

IRFs = getIRFs(Beta_save(:,:,draw),A0_save(:,:,draw),exog,n,p,hmax);
draws_FEVDs(:,:,:,draw) = varianceDecompositionOfVAR(IRFs,hmaxtoplot);
    
end

parfor draw = 1:numSavedNarrative
    
IRFs = getIRFs(Beta_narrative(:,:,draw),A0_narrative(:,:,draw),exog,n,p,hmax); 
draws_FEVDs_narrative(:,:,:,draw) = varianceDecompositionOfVAR(IRFs,hmaxtoplot);
    
end


bands  = [16,50,84];

f = figure;
clf
figSize = [10 6];
set(f, 'PaperUnits', 'inches');
set(f, 'Units','inches');
set(f, 'PaperSize', figSize);
set(f, 'PaperPositionMode', 'auto');
set(f, 'Position', [0 0 figSize(1) figSize(2)])
ti = get(gca,'TightInset');
set(gca,'Position',[1.1*ti(1) 1.1*ti(2) 0.99*(1-ti(3)-ti(1)) 0.99*(1-ti(4)-ti(2))]);

C={[0.98 0.2 0.2],[0.8 0.8 0.8],[0.8 0.8 0.8] [0.8 0.8 0.8] [0.8 0.8 0.8] [0.8 0.8 0.8]}; % make a colors list 
varNames = varNames;
count = 1;
for jj = 1:n
    
    for ii = 1:n
     subplot(3,3,count)
       
    FEVD_percentiles_baseline = prctile(squeeze(draws_FEVDs(ii,jj,1:12:end,:)),bands,2);
    FEVD_percentiles_narrative = prctile(squeeze(draws_FEVDs_narrative(ii,jj,1:12:end,:)),bands,2);
    
    plotConfidenceBandsBlue([0:10],FEVD_percentiles_baseline,'b');
    hold on
    plotConfidenceBandsBlue([0:10],FEVD_percentiles_narrative,'r');
%     hold on    

%     xlim([0, 5])
    ylim([0, 1])   
    
    xlabel('Years')    
    ylabel(strcat(shockNames(jj),{' '},'Shock'))
    
    set(gca,'Layer','top')
    set(gca, 'FontName', 'Times New Roman');
    set(gca, 'FontSize', 8); 
    set(gca,'XTick',[0:10]')
%     set(gca,'YTick',[0:0.1:0.6]')    
    set(gca,'XTickLabel',num2str((1/12).*[0:12:hmaxtoplot]'))    
    box on
    title(strcat(varNames(ii)))  
   count = count +1;
    
    end
    
end

tightfig;
fname = strcat('Output\FEVD_oil_bands.pdf');
print('-dpdf', f, fname); 