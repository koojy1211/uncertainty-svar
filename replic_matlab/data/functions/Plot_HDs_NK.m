%% HD with Bands PointWise

% Compute HD's
bands  = [16,50,84];                    % Percentiles for bands

whichVariable = 3;
cumulate = 0;

startDate = dates(1+p);
endDate = dates(end);
idxStart=find(ismember(dates,startDate));
idxEnd=find(ismember(dates,endDate));

numticks = 104;
ymin = -1;
ygap = .5;
ymax = 1;

Ytemp = y(idxStart-p:idxEnd,:);
Ta = length(Ytemp);
exoga = ones(Ta,constant);

draws_HDs = nan(Ta-p+1,n,numSavedDraws); % variable, time, shock

parfor draw = 1:numSavedDraws
    A0 = A0_save(:,:,draw);
    phi = Beta_save(constant+1:end,:,draw)';
    delta = Beta_save(1:size(exog,2),:,draw)';
    
    [~,~,dc,~,stochasticComponents] = Get_SVAR_results(Ytemp,exoga,A0,delta(1:n),phi,p,h);
    if cumulate == 1
    draws_HDs(:,:,draw) = cumsum(squeeze(stochasticComponents(whichVariable,1:end,:)),1);
    else
    draws_HDs(:,:,draw) = squeeze(stochasticComponents(whichVariable,1:end,:));
    end
end

total = mean(squeeze(sum(draws_HDs,2)),2);

draws_HDs_narrative = nan(Ta-p+1,n,numSavedNarrative); % variable, time, shock

parfor draw = 1:numSavedNarrative
    A0 = A0_narrative(:,:,draw);
    phi = Beta_narrative(constant+1:end,:,draw)';
    delta = Beta_narrative(1:size(exog,2),:,draw)';
    
    [~,~,dc,~,stochasticComponents] = Get_SVAR_results(Ytemp,exoga,A0,delta(1:n),phi,p,h);
    if cumulate == 1
    draws_HDs_narrative(:,:,draw) = cumsum(squeeze(stochasticComponents(whichVariable,1:end,:)),1);
    else
    draws_HDs_narrative(:,:,draw) = squeeze(stochasticComponents(whichVariable,1:end,:));
    end
end

total = mean(squeeze(sum(draws_HDs_narrative,2)),2);


f = figure(3);
clf
figSize = [15 7];
set(f, 'PaperUnits', 'inches');
set(f, 'Units','inches');
set(f, 'PaperSize', figSize);
set(f, 'PaperPositionMode', 'auto');
set(f, 'Position', [0 0 figSize(1) figSize(2)])


for jj = 1:nshocks
    subplot(3,2,jj)
    
    percentiles1 = prctile(squeeze(draws_HDs(1:end,jj,:)),bands,2);
    percentiles2 = prctile(squeeze(draws_HDs_narrative(1:end,jj,:)),bands,2);

    plot(dates(idxStart-1:idxEnd),total(1:end),'k','linewidth',1);
    hold on    
    plotConfidenceBandsBlue(dates(idxStart-1:idxEnd),percentiles1,'b');
    hold on
    plotConfidenceBandsBlue(dates(idxStart-1:idxEnd),percentiles2,'r');
    hold on
    plot(dates(idxStart-1:idxEnd),total(1:end),'k','linewidth',1);    
    plot(dates(idxStart-1:idxEnd),zeros(Ta-p+1,1),'--k')
    plot([datenum(1979,10,6), datenum(1979,10,6)],ylim,'r')
    hold off
    
    title(strcat(shockNames(jj),{' '},'Shock'))
    
    ax = gca;
    set(ax,'XTick',dates(idxStart-1:numticks:end))
    ax.XTickLabel = {datestr(dates(idxStart-1:numticks:end),'mmm-yy')};
    xlim([dates(idxStart-1), dates(idxEnd)])    
    
    %     set(ax,'YTick',ymin:ygap:ymax)  ;
    %     ax.YTickLabel = {ymin:ygap:ymax};
    %     ylim([ymin, ymax]);
    
    box on
    
    set(gca, 'FontName', 'Times New Roman');
    set(gca, 'FontSize', 8);
    set(gca,'Layer','top')
end
