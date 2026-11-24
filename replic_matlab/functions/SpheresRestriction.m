function y = SpheresRestriction(x,Z_IRF,n)
%
%  Z(j) - z(j) x n matrix of full row rank
%
%  Dimension x=[x(1); ... x(n)] where the dimension of x(j) is n-(j-1+z(j)) > 0. 
%
%  y(i)=norm(x(i)) - 1
%

y=zeros(n,1);
k=0;
for j=1:n
    xj=x(k+1:k+n-(j-1+size(Z_IRF{j},1)));
    k=k+n-(j-1+size(Z_IRF{j},1));
    y(j)=norm(xj) - 1.0;
end