function [B_0,V_0] = SetMinnesotaPrior(n,p,constant,alpha,Vc,lambda,psi,stationary)
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

lag_1_prior = ones(1,n);           % Trending variables centered at one
lag_1_prior(stationary) = 0.9;     % Stationary variables centered instead at zero

B_0 = [zeros(1,n*constant); diag(lag_1_prior); zeros(n,(n)*(p-1))'];

V_0 = zeros(n*p+constant);

K=constant+n*p;
Omega=zeros(K,1);

if constant
    Omega(1)=Vc;
end

d = n+2;
for i=1:p
    Omega(constant+(i-1)*n+1:constant+i*n) = (d-n-1)*(lambda^2)*(1/(i^alpha))./psi;
end

PSI=diag(psi);
V_0 = diag(1./Omega);

end

