%%  Plot IRFS

nshocks = length(shockNames);

whatToPlot = 'Median-Bands';            % Choose either 'All' or 'Median-Bands'

hmaxtoplot = 12*5;                        % Maxmum Horizon of IRFs for plot

bands  = [16,50,84];                    % Percentiles for bands

f = figure(2);
clf
figSize = [12 6];
set(f, 'PaperUnits', 'inches');
set(f, 'Units','inches');
set(f, 'PaperSize', figSize);
set(f, 'PaperPositionMode', 'auto');
set(f, 'Position', [0 0 figSize(1) figSize(2)])

count = 1;

scaling1 = 0.25/median(squeeze(Draws_IRFs(6,1,1,:)));

for jj = 1:nshocks
    
    for ii = 1:n;
        
        
        subplot(2,3,count)
        
        relevantIRFs = squeeze(Draws_IRFs(ii,jj,1:hmaxtoplot+1,:));
        if ~isempty(NSR)
        relevantIRFs_narrative = squeeze(Draws_IRFs_narrative(ii,jj,1:hmaxtoplot+1,:));
        end
        
        switch whatToPlot
            case 'Median-Bands'
                
                percentiles1 = scaling1*100.*prctile(relevantIRFs,bands,2);                   % Compute percentiles
                
                plotConfidenceBandsBlue(0:hmaxtoplot,percentiles1,'b');         % Plot the percentiles
                hold on
                
                if ~isempty(NSR)
                scaling2 = 0.25/median(squeeze(Draws_IRFs_narrative(6,1,1,:)));
                percentiles3 = scaling2*100.*prctile(relevantIRFs_narrative,bands,2);                   % Compute percentiles
                plotConfidenceBandsBlue(0:hmaxtoplot,percentiles3,'r');         % Plot the percentiles
                end
                
            case 'All'
                
                plot(0:hmaxtoplot,relevantIRFs,'color',[0.0 0.0 1 0.1]);        % Plot the IRFs themselves
                hold on
                
                if ~isempty(NSR)
                plot(0:hmaxtoplot,relevantIRFs_narrative,'color',[1 0 0 1]);        % Plot the IRFs themselves
                end
                
        end
        
        % Plot the zero line
        hold on
        
        plot(0:hmaxtoplot,zeros(hmaxtoplot+1,1),'--k')
        
        % Axes.
        
        xmin=0;
        xmax=hmaxtoplot;
        xlim([xmin,xmax])

        set(gca,'Layer','top');
        set(gca, 'FontName', 'Times New Roman');
        set(gca, 'FontSize', 8);
        set(gca,'XTick',[0:round(hmaxtoplot/4.33):hmaxtoplot]')
        set(gca,'XTickLabel',num2str([0:round(hmaxtoplot/4.33):hmaxtoplot]'))
        box on
        
        % Titles and labels
        title(strcat({' '},varNames(ii),{' '},'to',{' '},shockNames(jj)))
        
        if count > n^2 - n
            xlabel('Months')
        end
        count  = count+1;
        
    end
    
end

tightfig
fname = strcat('Output\IRFs_monetary_combined.pdf');%
print('-dpdf', f, fname);  