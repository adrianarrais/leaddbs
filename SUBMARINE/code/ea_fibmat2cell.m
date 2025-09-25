function cellout=ea_fibmat2cell(fibmat)

cnt=1;
cellout=cell(length(fibmat.idx),1);
for fib=1:length(fibmat.idx)

    cellout{fib}=fibmat.fibers(cnt:cnt+fibmat.idx(fib)-1,1:3);
    cnt=cnt+fibmat.idx(fib);
end




