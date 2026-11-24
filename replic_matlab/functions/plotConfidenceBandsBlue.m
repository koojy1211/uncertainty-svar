function [] = plotConfidenceBandsBlue(x,percentiles,colour)
%Plot Confidence Bands as fan charts from percentiles
%   Note: input must be odd number of percentiles where middle one is the
%   median

numberOfBands = (size(percentiles,2)-1)/2;
if isempty(x);
    x = (1:size(percentiles,1))';
end

for i = 1 : numberOfBands
    
    lowerbound = percentiles(:,numberOfBands+1) - percentiles(:,i);
    upperbound = percentiles(:,end-i+1) - percentiles(:,numberOfBands+1);
    %     boundedline(x, percentiles(:,numberOfBands+1), [lowerbound, upperbound],colour, 'alpha');
    
    if strcmp(colour,'b')
        switch i
            case 1
                colourBand = [0.9 0.9 0.9];
            case 2
                colourBand = [0.6 0.8 1];
            case 3
                colourBand = [0.5 0.75 1];
        end
        boundedlineBlue(x, percentiles(:,numberOfBands+1), [lowerbound, upperbound],colour,colourBand);
        
    else
        if strcmp(colour,'r')
    
        switch i
            case 1
                colourBand = [1 0.8 0.8];
            case 2
                colourBand = [0.6 0.8 1];
            case 3
                colourBand = [0.5 0.75 1];
        end
        boundedlineBlue(x, percentiles(:,numberOfBands+1), [lowerbound, upperbound],colour,colourBand,'alpha');

        else
        boundedlineBlue(x, percentiles(:,numberOfBands+1), [lowerbound, upperbound],colour,'alpha');

        
        end
                
    end
    
    hold on
    
end

hold off

end

