function [B_draw,SIGMA_draw] = BVAR_1draw(posteriors)


v2struct(posteriors);

%% ----------------------------- DRAW -------------------------------------

%             SIGMA_draw = inv2(wish(inv(S_post),v_post));
            SIGMA_draw = inv2(wish(invS_post,v_post));
            
            V_B_post = kron(SIGMA_draw,inv2(NT));
            
%             V_B_post = (V_B_post + V_B_post')./2;
     
%             tic
            COVARIANCE = chol(V_B_post,'lower');
%             toc
%             tic
            B_draw = b_post + COVARIANCE*randn(size(b_post,1),1);
%             toc
            
            B_draw = reshape(B_draw,K,n);
            
    
    

end

