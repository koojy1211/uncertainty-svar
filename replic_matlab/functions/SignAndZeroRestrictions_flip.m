% 원본: function [A0tilde,Qdraw,uw] = SignAndZeroRestrictions(Bdraw,Sigmadraw,p,exog,hirfs,S,Z,agnostic)
function [A0tilde,Qdraw,uw] = SignAndZeroRestrictions_flip(Bdraw,Sigmadraw,p,exog,hirfs,S,Z,agnostic)   %%% [수정] 이름만 바꿈
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

n = size(Sigmadraw,1);
m = n*p+size(exog,2);

%%% [수정] 부호를 뒤집으면 영제약 중요도 가중치(아래 uw) 계산과 맞지 않아서, 영제약이 있으면 멈춘다
if any(~cellfun(@isempty,Z)), error('영제약이 있으면 원래 SignAndZeroRestrictions.m을 쓸 것'); end


% Some functions
hh       = @(x)chol(x);
fh_inv   = @(x)ReducedFormToStructural(x,hh,n,m);
fh_S_restrictions      = @(y)StructuralRestrictions(y,S,m,p,hirfs);
g        = @(y)StructuralToIRF(y,n,p);
fh_g_inv = @(y)IRFToReducedForm(y,hh,n,m,p);
g_inv_Z_restrictions   = @(z)IRFRestrictions(z,Z,m,p,hirfs);%@(z)fh_Z_restrictions(g_inv(z));


% definitions related to mapping from spheres to orthogonal matrices
% computes the dimension of space in which the spheres live that map into the
% orthogonal matrices satisfying the restriction.
dim=0;
for i=1:n
    dim=dim+n-(i-1+size(Z{i},1));
end

% Ensure constant terms are at the bottom of Bdraw
Bdraw = [Bdraw(size(exog,2)+1:end,:); Bdraw(1:size(exog,2),:)];



%% draw Q | B and Sigma

    Q0 = eye(n);

    structpara   = fh_inv([reshape(Bdraw,m*n,1); reshape(Sigmadraw,n*n,1); reshape(Q0,n*n,1)]);
    FA0Aplus     = FA0Aplus_f2(structpara,m,n,p,hirfs);
    
    Z_FA0Aplus  = cell(n,1);
    for j=1:n
        Z_FA0Aplus{j} = Z{j}*FA0Aplus;
    end
    f = @(x)SpheresToQ(x,Z_FA0Aplus,n);
    
    q_tilde=randn(dim,1);
    
    k=0;
    for i=1:n
       s  = n-(i-1+size(Z{i},1));
       qi = q_tilde(k+1:k+s);
       q_tilde(k+1:k+s) = qi/norm(qi);
       k  = k+s;
    end
    
    Qdraw=Q0*reshape(f(q_tilde),n,n);

%% check if sign restrictions hold    
    x=[reshape(Bdraw,m*n,1); reshape(Sigmadraw,n*n,1); reshape(Qdraw,n*n,1)];
    structpara = fh_inv(x);
    % 원본: signs=fh_S_restrictions(structpara);
    %%% [수정 시작] 부호 뒤집기: 충격 j의 제약이 전부 반대 부호면 Q의 j열을 뒤집어 통과시킨다
    %%% Q의 j열을 뒤집으면 충격 j의 반응만 부호가 바뀐다. Haar 분포는 열 부호 반전에 불변이라 사후분포는 같고 통과율만 높아진다 (svar_diff.do signR과 같음)
    FA0Aplus_draw = FA0Aplus_f2(structpara,m,n,p,hirfs);     % fh_S_restrictions 안에서 계산하던 [A0; 지평별 IRF]
    signOK = true;
    for j = 1:n
        if isempty(S{j}), continue; end                       % 제약 없는 충격은 건너뜀
        v = S{j}*FA0Aplus_draw(:,j);
        if all(v < 0)
            Qdraw(:,j) = -Qdraw(:,j);                         % 전부 반대면 열 j 뒤집기
        elseif ~all(v > 0)
            signOK = false;                                   % 섞여 있으면 탈락
            break
        end
    end
    %%% [수정 끝]
    
    % 원본: if (sum(signs>0))~=size(signs,1)
    if ~signOK                                                %%% [수정]
        Qdraw = nan*Qdraw;
        uw = 0;
        A0tilde = nan;
    else
        
        A0 = chol(Sigmadraw)\eye(n);
        A0tilde = A0*Qdraw;

        
        %% compute importance sampling weights
        
        if ~isempty(Z{1,:})
        
        switch agnostic
            case 'structural'
                
                % volume element of f_h:  LogVolumeElement(fh,structpara);
                storevefh =  log(2)*n*(n+1)/2 + LogAbsDet(Sigmadraw)*(m+2*n +1)/2;
                
                % volume element g_B_S
                f_restrictions=@(x)SpheresRestriction(x,Z_FA0Aplus,n);
                storevegBS = LogVolumeElement(f,q_tilde,f_restrictions);
                
                % volume element of fh_Z
                storevefhZ = LogVolumeElement(fh,structpara,fh_Z_restrictions);
                
                % Unnormalized weights
                uw = exp(storevefh + storevegBS - storevefhZ);
                
                
            case 'irfs'
                
                % volume element of phi: f_h o g^{-1}
                storevephi =  log(2)*n*(n+1)/2 - LogAbsDet(Sigmadraw)*(2*n*p-m-1)/2;
                
                % volume element g_B_S
                f_restrictions=@(x)SpheresRestriction(x,Z_FA0Aplus,n);
                storevegBS = LogVolumeElement(f,q_tilde,f_restrictions);
                
                % volume element of phi | Z 
                irfpara = g(structpara);
                %storevephiZ(record,1) = LogVolumeElement(fh,structpara,fh_Z_restrictions)+ LogVolumeElement(g_inv,irfpara,g_inv_Z_restrictions);
                storevephiZ = LogVolumeElement(fh_g_inv,irfpara,g_inv_Z_restrictions);
                
    
                % Unnormalized weights
                uw = exp( storevephi + storevegBS - storevephiZ);
        end    
        
        else
            
            uw = 1;
        end
        
    end
    
end

