function [HD] = getHDs_fast(IRFs,n,shocks,whichVariable)

hmax = size(shocks,1)-1;
EYE = eye(n);
HD = nan(n,hmax+1);

for h = 0:hmax
   for j = 1:n
   HD(j,h+1) = EYE(:,whichVariable)'*IRFs(:,:,h+1)*EYE(:,j)*EYE(:,j)'*shocks(end-h,:)'; 
   end    
end

HD = sum(HD,2);


end