function [IRF] = getIRFs(BETA,A0,exog,n,p,hmax)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
B = BETA(size(exog,2)+1:end,:);

F = [B';  [eye(n*(p-1)) zeros(n*(p-1),n)]]';
J = [eye(n); zeros(n*(p-1),n)];

IRF = nan(n,n,hmax+1);

    A0inv = inv2(A0);
    for h = 0:hmax
    IRF(:,:,h+1) = (A0inv*J'*(F^h)*J)';
    end

end

