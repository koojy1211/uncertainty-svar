%%  Plot IRFS

nshocks = length(shockNames);

whatToPlot = 'Median-Bands';            % Choose either 'All' or 'Median-Bands'

hmaxtoplot = 52;                        % Maxmum Horizon of IRFs for plot

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

for ii = 1:n
    
    for jj = 1:nshocks;
        
        
        subplot(n,nshocks,count)
        
        relevantIRFs = squeeze(Draws_IRFs(ii,jj,1:hmaxtoplot+1,:));
        relevantIRFs_narrative = squeeze(Draws_IRFs_narrative(ii,jj,1:hmaxtoplot+1,:));
        
        switch whatToPlot
            case 'Median-Bands'
                
                percentiles1 = prctile(relevantIRFs,bands,2);                   % Compute percentiles
                percentiles3 = prctile(relevantIRFs_narrative,bands,2);                   % Compute percentiles
                
                plotConfidenceBandsBlue(0:hmaxtoplot,percentiles1,'b');         % Plot the percentiles
                hold on
                plotConfidenceBandsBlue(0:hmaxtoplot,percentiles3,'r');         % Plot the percentiles
                
            case 'All'
                
                plot(0:hmaxtoplot,relevantIRFs,'color',[0.0 0.0 1 0.1]);        % Plot the IRFs themselves
                hold on
                plot(0:hmaxtoplot,relevantIRFs_narrative,'color',[1 0 0 1]);        % Plot the IRFs themselves
                
                
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
            xlabel('Quarters')
        end
        count  = count+1;
        
    end
    
end