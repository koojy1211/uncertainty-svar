function y = StructuralToIRF(x,n,p)
%
%  model:
%
%    y(t)'*A(0) = z(t)'*C + y(t-1)'*A(1) + ... + y(t-p)'*A(p) + epsilon(t)
%
%    y(t) - n x 1 endogenous variables
%    epsilon(t) - n x 1 exogenous shocks
%    z(t) - k x 1 exogenous or deterministic variables
%    A(i) - n x n
%    C - k x n   
%
%
%  structural parameterization - A0, Aplus
%
%    A0 = A(0)
%    Aplus = [A(1); ... A(p); C]
%    x = [vec(A0); vec(Aplus)]
%
% 
%  IRF parameterization - L(0), L(1), ... L(p), c
%
%    L(0) = inv(A(0))
%    L(i) = (L(i-1)*A(1) + ... + L(0)*A(i))*inv(A(0))  1 <= i <= p
%
%    y = [vec(L(0)'); ... vec(L(p)'); vec(C)] 
%

n2=n*n;
nk=numel(x) - n2*(p+1);
A=cell(p,1);
A0=reshape(x(1:n2),n,n);
Aplus=reshape(x(n2+1:end),numel(x)/n-n,n);

L=cell(p,1);

for i=1:p
    A{i}=Aplus((i-1)*n+1:i*n,:);
    X = A0\A{i};
    for j=1:i-1
        X = X + L{j}*A{i-j};
    end
    L{i}=X/A0;
end

y=zeros(size(x,1),1);

y(1:n2)=reshape(inv(A0)',n2,1);
for i=1:p
    y(i*n2+1:(i+1)*n2)=reshape(L{i}',n2,1);
end
y((p+1)*n2+1:(p+1)*n2+nk)=reshape(Aplus(p*n+1:end,:),nk,1);
