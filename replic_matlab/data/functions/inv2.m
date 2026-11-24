function [ InvA ] = inv2(A)

temp=eye(size(A,2));
InvA=A\temp;

end

