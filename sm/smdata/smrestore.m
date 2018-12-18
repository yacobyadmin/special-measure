function smrestore(file, channels, ramprate)
% function smrestore(file, channels, ramprate) 
% restore channel values from a datafile. 
% can only restore channels saved in configch. 
% channels can be strings or indices and specifies which values to set, default is all.
% ramprate is optional ramptime that will be applied to all channels.
global smdata
if ~exist('file','var') || isempty(file)
    [file,fpath]=uigetfile('');
end
load(fullfile(fpath,file), 'configvals', 'configch');
configch = smchanlookup(configch); %#ok<*NODEF>
if exist('channels','var') && ~isempty(channels)
    channels = smchanlookup(channels);
    if ~all(ismember(channels, configch))
        fprintf('WARNING: some channel values not found.\n');
    end
    mask = ismember(configch, channels);    
    configch = configch(mask);
    configvals = configvals(mask);
end

if isfield(smdata,'nr') && ~isempty(smdata.nr)
    notRestore = configch==chl(smdata.nr);
    configch(notRestore)=[];
    configvals(notRestore) = [];
end
if exist('ramprate','var')
    smset(configch, configvals,ramprate);
else
    smset(configch, configvals);
end
    fprintf('Restored to file %s \n',file); 

end
