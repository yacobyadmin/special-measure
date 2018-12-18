function scan = smscanpar(scan, cntr, rng, npoints, loops)
% function  scan = smscanpar(scan, cntr, rng, npoints, loops)
% Set center, range and number of points for scan.loops(loops).
% loops defaults to 1:length(cntr).  Empty or omitted arguments are left unchanged.
% scan.configfn is executed at the end if present and not empty.
% if cntr is 'gca', copy the range of the current plot to the scan.

if ~exist('loops','var')
    loops = 1:length(cntr);
end

if ~isempty(cntr)
    if ischar(cntr) && strcmp(cntr,'gca')
        xrng=get(gca,'XLim');
        yrng=get(gca,'YLim');
        [~,loop1Dir] = sort(scan.loops(loops(1)).rng); 
        [~,loop2Dir] = sort(scan.loops(loops(2)).rng); 
        scan.loops(loops(1)).rng = xrng(loop1Dir);
        scan.loops(loops(2)).rng = yrng(loop2Dir);        
        fprintf('X range: [%g,%g]   Y range: [%g,%g]\n',xrng,yrng);
        return;
    end
    for i = 1:length(loops)
        scan.loops(loops(i)).rng =  scan.loops(loops(i)).rng - mean(scan.loops(loops(i)).rng) + cntr(i);
    end
end

if exist('rng','var') && ~isempty(rng)
    for i = 1:length(loops)
        scan.loops(loops(i)).rng =  mean(scan.loops(loops(i)).rng) + rng(i) * [-.5 .5];
    end
end

if exist('npoints','var') && ~isempty(npoints)
    for i = 1:length(loops)
        scan.loops(loops(i)).npoints =  npoints(i);
    end
end
