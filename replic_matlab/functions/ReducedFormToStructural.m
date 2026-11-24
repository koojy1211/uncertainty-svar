function y = ReducedFormToStructural(x,h,n,m)
%
%
%

B=reshape(x(1:m*n),m,n);
Sigma=reshape(x(m*n+1:(m+n)*n),n,n);
Q=reshape(x((m+n)*n+1:end),n,n);

A0=h(0.5*(Sigma + Sigma'))\Q;
Aplus=B*A0;

y=[reshape(A0,n*n,1); reshape(Aplus,m*n,1);];