function out = FA0Aplus_f2(x,m,n,p,hirfs)

% This file creates a sample of F(A0,A+) = [A_{0};L_{0};...;L_{hirfs-1}]
    
    A0  = reshape(x(1:n*n),n,n);
    out = A0;
    
    LIRF = IRF_horizons(x, n, p, m, hirfs);
    
    L = zeros(length(hirfs),n,n);
    for h=0:length(hirfs)-1
        L(h+1,:,:) =  LIRF(1+h*n:(h+1)*n,:);
        out = [out;squeeze(L(h+1,:,:))];
    end
    
end