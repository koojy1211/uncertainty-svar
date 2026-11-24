function [shocks] = get_shocks(Y,exog,A0,c,B,p)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here


[T, n] = size(Y);

if isempty(c)
    c = zeros(n,1);
end

%% Compute the Shaaacks

Ylag = mlag2(Y,p); % Y is [T x M]. ylag is [T x (Mp)]

if isempty(exog)

X = Ylag(p+1:T,:);
ALPHA = B';

else
    
X = [exog(p+1:T,:) Ylag(p+1:T,:)];
ALPHA = [c'; B'];

end

innovations = (Y(p+1:end,:) - X*ALPHA);
shocks = (innovations*(A0));





