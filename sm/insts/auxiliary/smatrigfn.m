function smatrigfn(inst,inst2,  op)
% Software trigger instrument
% smatrigfn(inst, inst2, op)
% inst is a n x 2 matrix containing an instrument and channel index for a channel to be triggered in each row.
% If inst2 is specified, inst is ignored.  (WHY? WTF Hendrik!)
% If op is not specified, it defaults to 3 (trigger)

global smdata;

if ~exist('op','var') || isempty(op), op = 3; end
if exist('inst2','var') && ~isempty(inst2), inst = inst2; end
if ischar(inst) || iscell(inst), inst = sminstlookup(inst); end

for i = 1:size(inst, 1)
    smdata.inst(inst(i, 1)).cntrlfn([inst(i, :), op]);
end