function chanind = smchanlookup(channels)
% function chanind = smchanlookup(channels)
% convert channel names to indices

global smdata;

if isnumeric(channels)
    chanind = channels;
    if size(chanind, 2) > 1
        chanind = chanind';
    end
    return;
end

if ischar(channels)
    channels = cellstr(channels);
end

chanind = zeros(length(channels), 1);

for i = 1:length(channels)
    m = find(strcmp(channels{i}, cellstr(char(smdata.channels.name))));
    %replaces: 
    %m = strmatch(channels{i}, strvcat(smdata.channels.name) ,'exact'); 
    if(isempty(m))
        error('Unable to find sm channel "%s"\n',channels{i});
    else
        chanind(i) = m;
    end
end