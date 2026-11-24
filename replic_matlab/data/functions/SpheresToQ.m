function q = SpheresToQ(x, Z_IRF, nvar)
%
%  Z_IRF(j) - z(j) x n matrix of full row rank
%
%  x=[x(1); (2); ... x(n)] where the dimension of x(j) is n-(j-1+z(j)) > 0. 
%
%  Let the columns of N_perp(j) form an orthnormal basis for the null space of
%  [q(1)'; ... q'(j-1); Z{j}].  The number of columns in N_perp(i) is at least
%  n-(j-1+z(j)).  Define q(j) = N_perp(j)(:,1:n-(j-1+z(j)))*x(j).
%
%  Q = [q(1), q(2), ... q(n)]
%
%  norm(q(j)) == 1 if and only if norm(x(j)) == 1.
%

Q=zeros(nvar,nvar);
k=0;
for j=1:nvar
    
    s=nvar-(j-1+size(Z_IRF{j},1));
    xj=x(k+1:k+s);
    k=k+s;
    
    N=[Q(:,1:j-1), Z_IRF{j}'];
    Q(:,j)=perp(N)*(xj/norm(xj));
end

q=reshape(Q,nvar*nvar,1);
