function [ checkElasticity ] = ElasticityBoundRestrictions(EBR,varNames,shockNames,B_draw,A0tilde_draw,exog,n,p)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

if ~isempty(EBR)

    IRFs = getIRFs(B_draw,A0tilde_draw,exog,n,p,0);
    
    E = zeros(size(EBR,2),1);
    
    for r = 1:size(EBR,2)
        
        dy = IRFs(find(strcmp(varNames,EBR{r}{2}{1})),find(strcmp(shockNames,EBR{r}{1})),EBR{r}{3}+1);
        dx = IRFs(find(strcmp(varNames,EBR{r}{2}{2})),find(strcmp(shockNames,EBR{r}{1})),EBR{r}{3}+1);
        elasticity = dy/dx;
        E(r) = (elasticity < EBR{r}{4});
        
    end

    checkElasticity = logical(prod(E)); 

else
    
    checkElasticity = 1;
    
end

end

