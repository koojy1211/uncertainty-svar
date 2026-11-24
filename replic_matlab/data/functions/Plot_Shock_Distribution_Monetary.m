%% Shock Distribution at a Given Date

whichShock = 1;
dateShock = datenum(1979,10,1);
idx=find(ismember(dates,dateShock))-p;

shock_distribution = squeeze(Draws_Shocks(idx,whichShock,:));
shock_distribution_narrative = squeeze(Draws_Shocks_narrative(idx,whichShock,:));


f = figure;

clf
figSize = [6 5];
set(f, 'PaperUnits', 'inches');
set(f, 'Units','inches');
set(f, 'PaperSize', figSize);
set(f, 'PaperPositionMode', 'auto');
set(f, 'Position', [0 0 figSize(1) figSize(2)])
ti = get(gca,'TightInset');
set(gca,'Position',[1.1*ti(1) 1.1*ti(2) 0.99*(1-ti(3)-ti(1)) 0.99*(1-ti(4)-ti(2))]);

[f1,x1]=hist(shock_distribution,30);
dx = diff(x1(1:2));
bar(x1,f1/sum(f1*dx),'FaceColor',[0.7 0.7 0.7],'BarWidth',1,'FaceAlpha',0.4);
hold on
[f2,x2]=hist(shock_distribution_narrative,15);
dx = diff(x2(1:2));
bar(x2,f2/sum(f2*dx),'FaceColor',[1 0 0],'BarWidth',1,'FaceAlpha',0.3);
YLIM = ylim
% hist(shock_distribution,30);
plot([0, 0],YLIM,'--k')
xlim([-3,5])
ylim(YLIM)
box on

set(gca, 'FontName', 'Times New Roman');
set(gca, 'FontSize', 12); 
set(gca,'Layer','top')

tightfig
fname = strcat('Output\Monetary_Hist_of_Shock',num2str(year(dateShock)),'_combined');
print('-dpdf', f, fname); 