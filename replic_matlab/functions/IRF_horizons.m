function IRF = IRF_horizons(x, nvar, nlag, npredetermined, horizons)
%
%  x = [vec(A0); vec(Aplus)]
%  A0 = A(0)
%  Aplus = [A(1); ... A(p); c']
%
%  y(t)'*A(0) = c' + y(t-1)'*A(1) + ... + y(t-p)'*A(p) + epsilon(t)'
%
%  y(t), epsilon(t), c - n x 1
%  A(i) - n x n
%
%  R(0) = inv(A(0))
%  R(i) = (R(0)*A(i) + R(1)*A(i-1) + ... + R(i-1)*A(1))*R(0)      0 < i <= p
%  R(i) = (R(i-p)*A(p) R(i-p+1)*A(p-1) + ... + R(i-1)*A(1))*R(0)  p < i
%  R(infinity) = inv(A(0) - A(1) - ... - A(p))
%
%  IRF = [R(h(1))'; R(h(2))'; ... R(h(k))']
%

if numel(horizons) == 0
    IRF = zeros(0,nvar);
else
    
    maxh=max(horizons(horizons ~= inf));
    long_run = (max(horizons) == inf);
    if maxh < nlag
        if long_run
            maxh=nlag;
        end
        q=maxh;
    else
        q=nlag;
    end
    
    n2=nvar*nvar;
    A=cell(nlag,1);
    A0=reshape(x(1:n2),nvar,nvar);
    Aplus=reshape(x(n2+1:n2+nvar*npredetermined),npredetermined,nvar);
    
    R=cell(maxh,1);
    
    for i=1:q
        A{i}=Aplus((i-1)*nvar+1:i*nvar,:);
        X = A0\A{i};
        for j=1:i-1
            X = X + R{j}*A{i-j};
        end
        R{i}=X/A0;
    end
    
    for i=nlag+1:maxh
        if nlag > 0
            X = R{i-nlag}*A{nlag};
        else
            X = zeros(nvar,nvar);
        end
        for j=1:nlag-1
            X = X + R{i-j}*A{j};
        end
        R{i}=X/A0;
    end
    
    if long_run
        R_long_run=A0;
        for j=1:nlag
            R_long_run=R_long_run - A{j};
        end
        R_long_run=inv(R_long_run);
    end
    
    IRF=zeros(numel(horizons)*nvar,nvar);
    for i=1:numel(horizons)
        if horizons(i) == inf
            IRF((i-1)*nvar+1:i*nvar,:)=R_long_run';
        elseif horizons(i) == 0
            IRF((i-1)*nvar+1:i*nvar,:)=inv(A0)';
        else
            IRF((i-1)*nvar+1:i*nvar,:)=R{horizons(i)}';
        end
    end
    
end




