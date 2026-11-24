function [ roots ] = getRoots(B)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

n = size(B,1);
p = size(B,2)/n;

B_companion = [B; [eye(n*(p-1)) zeros(n*(p-1),n)]];
roots = eig(B_companion);

end

