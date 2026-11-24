function [S,Z,hirfs,Ns,Nc,shockNames] = getRestrictions(SR,ZR,NSR,varNames,dates)

AllRestrictions = [SR,ZR,NSR];
TraditionalRestrictions = [SR,ZR];

T = length(dates);
n = length(varNames);

shockNames = (unique(cellfun(@(v) v(1), AllRestrictions(1,:)),'stable'));
nShocks = length(shockNames);
hirfs = (unique(cell2mat(cellfun(@(v) v(3), TraditionalRestrictions(1,:))),'stable'));
NS = 1 + length(hirfs);             % number of objects in F(THETA) to which we impose sign and zero restrictions


%% Allocate Space for Sign, Zero and Narrative Sign Restrictions

% Sign Restrictions  
S =cell(n,1); % In principle you can impose restrictions to identify up to n shocks
for j=1:n
S{j}=zeros(0,n*NS); % n*NS is the number of rows in f(A0,A+)
end

% Zero Restrictions
Z =cell(n,1);
for j=1:n
Z{j}=zeros(0,n*NS);
end

% Narrative Sign Restrictions

Ns = zeros(T,n);
Nc = zeros(T,T,n,n);

%% Set up Sign Restrictions
for j = 1:nShocks
    
    r = 1;

for rest = 1:size(SR,2)
    
    if strcmp(SR{rest}{1},shockNames(j))
    for rr = 1:size(SR{rest}{2},2)
        
        position = n*(find((hirfs==SR{rest}{3})))+find(strcmp(varNames,SR{rest}{2}{rr}));
        S{j}(r,position) = SR{rest}{4};
        r = r+1;
    end
    end
    
end

end

%% Set up Zero Restrictions

for j = 1:nShocks
    
    r = 1;

for rest = 1:size(ZR,2)
    
    if strcmp(ZR{rest}{1},shockNames(j))
    for rr = 1:size(ZR{rest}{2},2)
        
        position = n*(find((hirfs==ZR{rest}{3})))+find(strcmp(varNames,ZR{rest}{2}{rr}));
        Z{j}(r,position) = 1;
    end
    r = r+1;
    end
    
end

end

%% Set up Narrative Sign Restrictions

for rest = 1:size(NSR,2)
    
    switch NSR{rest}{2}
        case 'sign of shock'
            Ns(ismember(dates,NSR{rest}{3}),strcmp(shockNames,NSR{rest}{1})) = NSR{rest}{4};
        case 'contribution'
            switch NSR{rest}{7}
                case 'strong'
                    if sign(NSR{rest}{6})==1
                       Nc(ismember(dates,NSR{rest}{3}),ismember(dates,NSR{rest}{4}),strcmp(shockNames,NSR{rest}{1}),strcmp(varNames,NSR{rest}{5})) = 2;
                    else
                       Nc(ismember(dates,NSR{rest}{3}),ismember(dates,NSR{rest}{4}),strcmp(shockNames,NSR{rest}{1}),strcmp(varNames,NSR{rest}{5})) = -1;
                    end
                case 'weak'
                    if sign(NSR{rest}{6})==1
                       Nc(ismember(dates,NSR{rest}{3}),ismember(dates,NSR{rest}{4}),strcmp(shockNames,NSR{rest}{1}),strcmp(varNames,NSR{rest}{5})) = 1;
                    else
                       Nc(ismember(dates,NSR{rest}{3}),ismember(dates,NSR{rest}{4}),strcmp(shockNames,NSR{rest}{1}),strcmp(varNames,NSR{rest}{5})) = -2;                        
                    end
            end
    end
    
end

end
