function ve = LogVolumeElement(f,x,h)
%
%  Returns the log of the volume element of f restricted to the set of points x
%  in R^n that satisfy h(x) = 0.
%
%  f is a function from R^n to R^m.
%  x is a point in R^n satisfying h(x)=0.
%  h is a function from R^n to R^(n-k).
%  
%  It is assumed that Dh(x) is of full row rank whenever h(x) = 0.  Under this
%  assumption h defines a k-dimensional manifold in R^n.  ve is the volume
%  element of f, restricted to the manifold, when evaluated at x.
%

Dfx=NumericalDerivative(f,x);          % m x n matrix
if nargin > 2
    Dhx=NumericalDerivative(h,x);      % (n-k) x n matrix
    N=Dfx*perp(Dhx');                  % perp(Dhx') - n x k matrix
    ve=0.5*LogAbsDet(N'*N);
else
    ve=0.5*LogAbsDet(Dfx'*Dfx);
end
