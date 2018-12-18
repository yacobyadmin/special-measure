function chanList = findChans(chan,num,inst)
% Find all channels in rack associated with instrument / channel.
% function chanList = findChans(chan,num,inst)
% Can give channel name and number (associated with inst channel you want) to get back a smdata channel number
% can give inst to get back list of smdata channels on that instrument 
% ADD ME: can give num, inst to get back channel 
global smdata

if isempty(chan) && isempty(num) 
    ic = inst; 
else
    ic = smchaninst(chan); 
end

chanList = [];
if ~isempty(num)
    for i = 1:length(smdata.channels)
        if all(smdata.channels(i).instchan == [ic(1) num]) % find the channel with the correct instchan 
            chanList = [chanList, i]; % add to chanList 
        end
    end
else % otherwise, just create a list of channels that are on that instrument. 
    for i = 1:length(smdata.channels)
        if smdata.channels(i).instchan(1) == ic(1)
            chanList = [chanList, i];
        end
    end
end
if isempty(chanList) 
    fprintf('Channel not found \n'); 
end
end