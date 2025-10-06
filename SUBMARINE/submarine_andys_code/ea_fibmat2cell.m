function cellout=ea_fibmat2cell(fibmat)

cnt=1;% Fibers counter

% initialize cell: one fiber per cell
cellout=cell(length(fibmat.idx),1);

% Loop to add points of each fiber to cell
for fib = 1:length(fibmat.idx)
    
    % Get fiber points indicated in .idx (only xyz->1:3)
    cellout{fib}=fibmat.fibers(cnt:cnt+fibmat.idx(fib)-1,1:3);

    % Advance counter to next fiber
    cnt=cnt+fibmat.idx(fib);
end




