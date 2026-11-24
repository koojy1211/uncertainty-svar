
%% HD with Bands PointWise

% Compute HD's

idxStart=find(ismember(dates,startDate));
idxEnd=find(ismember(dates,endDate));



Ytemp = y(idxStart-p:idxEnd,:);
Ta = length(Ytemp);
exoga = ones(Ta,1);

draws_HDs = nan(Ta-p+1,n,numSavedDraws); % variable, time, shock

parfor draw = 1:numSavedDraws
 
disp(draw)
A0 = A0_save(:,:,draw);
phi = Beta_save(constant+1:end,:,draw)';
delta = Beta_save(1,:,draw)';    

[~,~,dc,~,stochasticComponents] = Get_SVAR_results(Ytemp,exoga,A0,delta(1:n),phi,p,h);
draws_HDs(:,:,draw) = squeeze(stochasticComponents(3,1:end,:));
end

total = mean(squeeze(sum(draws_HDs,2)),2);

% Narrative
draws_HDs_narrative = nan(Ta-p+1,n,numSavedNarrative); % variable, time, shock

parfor draw = 1:numSavedNarrative
 
disp(draw)
A0 = A0_narrative(:,:,draw);
phi = Beta_narrative(constant+1:end,:,draw)';
delta = Beta_narrative(1,:,draw)';    

[~,~,dc,~,stochasticComponents] = Get_SVAR_results(Ytemp,exoga,A0,delta(1:n),phi,p,h);
draws_HDs_narrative(:,:,draw) = squeeze(stochasticComponents(3,1:end,:));
end


f = figure;
clf
figSize = [5 7];
set(f, 'PaperUnits', 'inches');
set(f, 'Units','inches');
set(f, 'PaperSize', figSize);
set(f, 'PaperPositionMode', 'auto');
set(f, 'Position', [0 0 figSize(1) figSize(2)])
ti = get(gca,'TightInset');
set(gca,'Position',[1.1*ti(1) 1.1*ti(2) 0.99*(1-ti(3)-ti(1)) 0.99*(1-ti(4)-ti(2))]);

for jj = 1:n
subplot(3,1,jj)

percentiles1 = prctile(squeeze(draws_HDs(1:end,jj,:)),bands,2);
percentiles3 = prctile(squeeze(draws_HDs_narrative(1:end,jj,:)),bands,2);
        
plotConfidenceBandsBlue(dates(idxStart-1:idxEnd),percentiles1,'b');
hold on
plotConfidenceBandsBlue(dates(idxStart-1:idxEnd),percentiles3,'r');
hold on    
plot(dates(idxStart-1:idxEnd),total(1:end),'k','linewidth',2);
plot(dates(idxStart-1:idxEnd),zeros(Ta-p+1,1),'--k')

hold off

title(strcat(shockNames(jj),{' '},'Shock'))

ax = gca;
set(ax,'XTick',dates(idxStart-1:numticks:end))       
ax.XTickLabel = {datestr(dates(idxStart-1:numticks:end),'mmm-yy')};

set(ax,'YTick',ymin:ygap:ymax)  ;     
ax.YTickLabel = {ymin:ygap:ymax};

xlim([dates(idxStart-1), dates(idxEnd)])
ylim([ymin, ymax]);
box on

set(gca, 'FontName', 'Times New Roman');
set(gca, 'FontSize', 8); 
set(gca,'Layer','top')
end

tightfig
fname = strcat('Output\HDs_oil_',num2str(year(dates(idxStart))),'.pdf');
print('-dpdf', f, fname);   



