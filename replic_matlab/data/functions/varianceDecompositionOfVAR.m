function [FEVD] = varianceDecompositionOfVAR(IRF,hmax)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

%% Check inputs
%===============================================

n = size(IRF,1);

%% Get the Structural IRFs
%===============================================]

MSE = nan(n,hmax+1);
FEVD = nan(n,n,hmax+1);

for h = 0:hmax
    MSE(:,h+1) = sum(sum(IRF(:,:,1:h+1).^2,3),2);
    FEVD(:,:,h+1) = sum(IRF(:,:,1:h+1).^2,3)./repmat(MSE(:,h+1),1,n);    
end

end

