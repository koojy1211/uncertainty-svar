function y = IRFToStructural(x,n,p)
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
%  IRF parameterization - L(0), L(1), ... L(p), C
%
%    A(0) = inv(L(0))
%    A(i) = inv(L(0))*(L(i)*A(0) - L(i-1)*A(1) - ... - L(1)*A(i-1))  0 < i <= p
%
%    x = vec([vec(L(0)'); ... vec(L(p)'); vec(C)])
%
%
%  structural parameterization - A0, Aplus
%
%    A0 = A(0)
%    Aplus = [A(1); ... A(p); C]
%
%    y = [vec(A0); vec(Aplus)]
%

n2=n*n;
k=numel(x)/n - n*(p+1);
L=cell(p,1);
L0=reshape(x(1:n2),n,n)';

A=cell(p,1);

for i=1:p
    L{i}=reshape(x(i*n2+1:(i+1)*n2),n,n)';
    X = L{i}/L0;
    for j=1:i-1
        X = X - L{i-j}*A{j};
    end
    A{i}=L0\X;
end

Aplus=zeros(n*p+k,n);
for i=1:p
    Aplus((i-1)*n+1:i*n,:)=A{i};
end
Aplus(n*p+1:end,:)=reshape(x(n2*(p+1)+1:end),k,n);

y=[reshape(inv(L0),n2,1); reshape(Aplus,n2*p+n*k,1)];
