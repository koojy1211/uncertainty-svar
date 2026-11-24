function y = StructuralRestrictions(x,Z,m,p,hirfs)
%
%  Z - n x 1 cell of z_j x k matrices
%  f(x) - stacked A0 and impulse responses
%  
%  restrictions:
%
%     Z{j}*f(x)*e_j = 0
%

n=size(Z,1);
total_zeros=0;
for j=1:n
    total_zeros=total_zeros+size(Z{j},1);
end

% f    = FA0Aplus_f(x,m,n,p,hirfs);
f    = FA0Aplus_f2(x,m,n,p,hirfs);

y=zeros(total_zeros,1);
ib=1;
for j=1:n
    ie=ib+size(Z{j},1);  
    y(ib:ie-1)=Z{j}*f(:,j);
    ib=ie;
end