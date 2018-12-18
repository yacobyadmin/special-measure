function logsetfile(index, file)
% function logsetfile(index, file)
% initialise logging to 'file' and reset date
% index specifies which file to set and defaults to 1.
% file must be a string.

global loginfo;

if ~exist('file','var')
    file = index;
    index = 1;
end

if length(loginfo) < index || isempty(loginfo(index).logfile) || ~strcmp(loginfo(index).logfile, file)
    % larger list, new file or different file
    loginfo(index).logfile = file;
    loginfo(index).lastdate = [];
else
    error('Index does not exist, you will need to create a new file'); 
end