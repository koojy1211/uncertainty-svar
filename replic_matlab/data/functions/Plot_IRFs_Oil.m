hmaxtoplot = 18;
bands  = [16,50,84];
f = figure;
clf
figSize = [12 6];
set(f, 'PaperUnits', 'inches');
set(f, 'Units','inches');
set(f, 'PaperSize', figSize);
set(f, 'PaperPositionMode', 'auto');
set(f, 'Position', [0 0 figSize(1) figSize(2)])

count  = 1;

for jj = 1:n
    
 for ii = 1:n;


    subplot(3,3,count)
    
    percentiles1 = prctile(squeeze(Draws_IRFs(ii,jj,1:hmaxtoplot+1,:)),bands,2);
    percentiles3 = prctile(squeeze(Draws_IRFs_narrative(ii,jj,1:hmaxtoplot+1,:)),bands,2);
        
    plotConfidenceBandsBlue(0:hmaxtoplot,percentiles1,'b');
    hold on
    plotConfidenceBandsBlue(0:hmaxtoplot,percentiles3,'r');
    hold on    
    plot(0:hmaxtoplot,zeros(hmaxtoplot+1,1),'--k')

%     plot(0:hmaxtoplot,),'color',[0.8 0.8 0.8 1]);  
    
%     plot(0:hmaxtoplot,squeeze(Draws_IRFs(ii,jj,1:hmaxtoplot+1,index2(1:z21))),'color',[0.8 0.8 0.8 1]);  
%     hold on
%     
%     plot(0:hmaxtoplot,squeeze(Draws_IRFs(ii,jj,1:hmaxtoplot+1,index3(1:z31))),'color',[1 0 0 1]);
%     
%     plot(0:hmaxtoplot,squeeze(Draws_IRFs(ii,jj,1:hmaxtoplot+1,modal_IRF_narrative_noElasticity)),'k','LineWidth',1.5)
% %     plot(0:hmaxtoplot,squeeze(Draws_IRFs(ii,jj,1:hmaxtoplot+1,index3(1:z31))),'color',[0 0 0 1]);

%     hold off
    
    xmin=0;
    xmax=hmaxtoplot;
    xlim([xmin,xmax])
    if ii == 1
    ylim([-2.5,1.5]) 
    ylabel('Percent')
    else
    ylim([-5,10])
    end

    set(gca, 'FontName', 'Times New Roman');
    set(gca, 'FontSize', 8); 
    set(gca,'XTick',[0:round(hmaxtoplot/4.33):hmaxtoplot]')
    set(gca,'XTickLabel',num2str([0:round(hmaxtoplot/4.33):hmaxtoplot]'))    
    box on
    title(strcat(varNames(ii),{' '},'to',{' '},shockNames(jj),' Shock'))
    set(gca,'Layer','top')

    if count > 6
            xlabel('Months')
    end
    count  = count+1;
    
 end
    
end
tightfig;
    fname = strcat('Output\All_IRFs_oil.pdf');

%     fname = strcat('All_IRFs_pointwise_1973.pdf');
%     fname = strcat('All_IRFs_R1-R3_noElasticity.pdf');
    
    print('-dpdf', f, fname);  