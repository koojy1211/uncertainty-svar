function X_perp = perp(X)
%
% Computes a n x (n-m) perpendicular component of the n x m matrix X in a
% differentiable manner.  Assumes that m <= n. The function defines Householder
% matrices M(1), ... M(n) such that
%
%    M(n)*...*M(1)*X = R
%
% where R is an upper triangular matrix.  X_perp can then be defined as the last
% n-m columns of M(1)'*...*M(n)'.  Note that X' * X_perp = 0.
%
% Defining X_perp in this manner means that the function is not defined on a set
% of measure zero.
%
% The Householder defined by a unit vector z is
%
%   H(z) = I - 2*z*z'
%
% Householder matrices have the property that H(z)*z=-z and H(z)*x=x if x'*z=0.
% Thus, H(x)' = H(z).
%
% If x and y are unit vectors and z=(x-y)/norm(x-y), then H(z)*x=y and H(z)*y=x.
%
% It is quicker to evaluate H(z)*x as x-2*z*dot(z,x) than to form the
% Householder matrix and multiply.
%
% If e = [1; 0; ... 0] any z is any vector not equal to e, then (z-e)/norm(z-e)
% is equal to [z(1)-norm(z); z(2); ... z(k)]/sqrt(abs(2*norm(z)*z(1))).

[n,m]=size(X);
if n < m
    error('perp(X): number of rows must be greater than or equal to number of columns');
else
    Z=cell(m,1);
    for j=1:m
        z=X(j:end,j);
        nn=norm(z);
        z(1)=z(1)-nn;
        nn=sqrt(abs(2.0*nn*z(1)));
        if nn == 0
        %    warning('perp(X): cannot form Householder matrix, using identity');           
        else
            z=(1.0/nn)*z;
            for k=j+1:m
                x=X(j:end,k);
                X(j:end,k)=x-(2*dot(z,x))*z;
            end
            Z{j}=z;
        end
    end
    
    I=eye(n);
    X_perp=I(:,m+1:end);
    for j=m:-1:1
        if ~isempty(Z{j})
            for k=1:n-m
                x=X_perp(j:end,k);
                X_perp(j:end,k)=x-(2*dot(Z{j},x))*Z{j};
            end
        end
    end
end