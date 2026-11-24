function [shocks,innovations,dc,lr,HDshock] = Get_SVAR_results(Y,exog,A0,c,B,p,h)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here



[T, n] = size(Y);

if isempty(c)
    c = zeros(n,1);
end

B_companion = [B; [eye(n*(p-1)) zeros(n*(p-1),n)]];
c_companion = [c; zeros(n*(p-1),1)];

J = [eye(n); zeros(n*(p-1),n)];

%% Deterministic Components

unconditional_means = (eye(n*p) - B_companion)\c_companion;

yWithLags = [Y mlag2(Y,p-1)];
y0 = yWithLags(p,:);
deterministic_component = nan(T+h,n*p);
deterministic_component(p,:) = y0;

for t=p+1:T+h
    deterministic_component(t,:) = (c_companion + B_companion*(deterministic_component(t-1,:))')';
end

lr = repmat(unconditional_means(1:n)',T+h,1);
dc = deterministic_component(:,1:n);

%% Compute the Shaaacks

Ylag = mlag2(Y,p); % Y is [T x M]. ylag is [T x (Mp)]

if isempty(exog)
    
    X = Ylag(p+1:T,:);
    ALPHA = B';
    
else
    
    X = [exog(p+1:T,:) Ylag(p+1:T,:)];
    ALPHA = [c'; B'];
    
end

T = T-p+1;
k = n * p;            % number of lagged endogenous per equation

innovations = (Y(p+1:end,:) - X*ALPHA);
shocks = (innovations*(A0));



%% Contribution of each shock

% if nargout > 4

invA0_big = zeros(k,n);
invA0_big(1:n,:) = inv2(A0)';
Icomp = J';
HDshock_big = zeros(p*n,T+h,n);
HDshock = zeros(n,T+h,n);

invA0_big = sparse(invA0_big);
B_companion = sparse(B_companion);
% HDshock_big = sparse(HDshock_big);
Icomp = sparse(Icomp);

for shock = 1:n % Loop over shocks
    
    eps_big = zeros(n,T+h);
    eps_big(shock,2:T) = shocks(:,shock)';
    for t = 2:T+h
        HDshock_big(:,t,shock) = invA0_big*eps_big(:,t) + B_companion*HDshock_big(:,t-1,shock);
        HDshock(:,t,shock) = Icomp*HDshock_big(:,t,shock);
    end
end

% end
%
% HDshock = permute(HDshock,[2 1 3]);
% HDshock = HDshock(2:end,:,:);


