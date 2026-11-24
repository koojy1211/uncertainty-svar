function [ year ] = day(DateNumber)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

tmp=datevec(DateNumber);
year=tmp(:,3);

end
