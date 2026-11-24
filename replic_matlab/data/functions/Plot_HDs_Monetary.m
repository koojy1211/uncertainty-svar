%% HD with Bands PointWise

whichVariable = 6;


% Compute HD's
startDate = [datenum(1979,09,01)];
endDate = [datenum(1980,2,01)];
idxStart=find(ismember(dates,startDate));
idxEnd=find(ismember(dates,endDate));

bands  = [16,50,84];

Ytemp = y(idxStart-p:idxEnd,:);
Ta = length(Ytemp);
exoga = ones(Ta,constant);

draws_HDs = nan(Ta-p+1,n,numSavedDraws);
draws_DCs = nan(Ta-p+1,1,numSavedDraws);

count = 1;
parfor draw = 1:numSavedDraws
 
A0 = A0_save(:,:,draw);
phi = Beta_save(constant+1:end,:,draw)';
delta = constant.*Beta_save(1,:,draw)';    

[~,~,dc,~,stochasticComponents] = Get_SVAR_results(Ytemp,exoga,A0,delta(1:n),phi,p,0);
draws_HDs(:,:,draw) = squeeze(stochasticComponents(whichVariable,1:end,:));
draws_DCs(:,:,draw) = dc(p:end,whichVariable);

% count = count+1;  
end


parfor draw = 1:numSavedNarrative
 
A0 = A0_narrative(:,:,draw);
phi = Beta_narrative(constant+1:end,:,draw)';
delta = constant.*Beta_narrative(1,:,draw)';    

[~,~,dc,~,stochasticComponents] = Get_SVAR_results(Ytemp,exoga,A0,delta(1:n),phi,p,0);
draws_HDs_narrative(:,:,draw) = squeeze(stochasticComponents(whichVariable,1:end,:));
draws_DCs_narrative(:,:,draw) = dc(p:end,whichVariable);

% count = count+1;  
end

total = mean(squeeze(sum(draws_HDs,2)),2)+mean(squeeze(draws_DCs),2);
DC = mean(squeeze(draws_DCs),2);

total_narrative = mean(squeeze(sum(draws_HDs_narrative,2)),2)+mean(squeeze(draws_DCs_narrative),2);
DC_narrative = mean(squeeze(draws_DCs_narrative),2);


f = figure;

numticks = 1;
ymin = -25;
ygap = 25;
ymax = 100;


clf
figSize = [6 5];
set(f, 'PaperUnits', 'inches');
set(f, 'Units','inches');
set(f, 'PaperSize', figSize);
set(f, 'PaperPositionMode', 'auto');
set(f, 'Position', [0 0 figSize(1) figSize(2)])
ti = get(gca,'TightInset');
set(gca,'Position',[1.1*ti(1) 1.1*ti(2) 0.99*(1-ti(3)-ti(1)) 0.99*(1-ti(4)-ti(2))]);

for jj = 1

    SCs_1 = squeeze(sum(draws_HDs(1:end,1,:),2)); % SC of only MP shock
    DCs_1 = squeeze(draws_DCs(1:end,1,:)); % DC of variable of interest

    SCs_2 = squeeze(sum(draws_HDs_narrative(1:end,1,:),2)); % SC of only MP shock
    DCs_2 = squeeze(draws_DCs_narrative(1:end,1,:)); % DC of variable of interest
    
    percentiles1 = prctile(SCs_1+DCs_1,bands,2);
    percentiles2 = prctile(SCs_2+DCs_2,bands,2);


    plotConfidenceBandsBlue(dates(idxStart-1:idxEnd),percentiles1,'b');
    hold on
    plotConfidenceBandsBlue(dates(idxStart-1:idxEnd),percentiles2,'r');
    hold on    
    plot(dates(idxStart-1:idxEnd),total(1:end),'k','linewidth',2);
%     plot(dates(idxStart-1:idxEnd),mean(DCs_1,2),'r')
plot([datenum(1979,10,1), datenum(1979,10,1)],ylim,'--k')
text(datenum(1979,10,6),14,{'Volcker', 'reform'},'HorizontalAlignment','left')
    
%     plot(dates(idxStart-1:idxEnd),zeros(Ta-p+1,1),'--k')

% hold off

% title(strcat(shocknames(jj),{' '},'Shock'))

ax = gca;
set(ax,'XTick',dates(idxStart-1:numticks:end))       
ax.XTickLabel = {datestr(dates(idxStart-1:numticks:end),'mmm-yy')};

% set(ax,'YTick',ymin:ygap:ymax)  ;     
% ax.YTickLabel = {ymin:ygap:ymax};

xlim([dates(idxStart-1), dates(idxEnd)])
% ylim([ymin, ymax]);
box on

set(gca, 'FontName', 'Times New Roman');
set(gca, 'FontSize', 12); 
set(gca,'Layer','top')
end

tightfig
fname = strcat('Output\HDs_monetary_',num2str(year(dates(idxStart))),'_combined.pdf');%
print('-dpdf', f, fname);  