function lockin_write(lockin,control,value)

if exist('lia_writeU16') ~= 3
    mex lia_writeU16.c
end
if exist('lia_writeU32') ~= 3
    mex lia_writeU32.c
end
if exist('lia_writeI32') ~= 3
    mex lia_writeI32.c
end
if exist('lia_readU16') ~= 3
    mex lia_readU16.c
end
if exist('lia_readU32') ~= 3
    mex lia_readU32.c
end
if exist('lia_readI32') ~= 3
    mex lia_readI32.c
end

switch upper(control)
    % Host controls
    case {'TIME CONSTANT','TIME CONSTANT [S]'}
        control_c = 33088 - lockin*4;
        value_c = 2147483647*exp(-2*pi/(value*200000));
        lia_writeI32(control_c,int32(value_c));
    case {'FILTER ROLLOFF'}
    case {'AMPLITUDE','AMPLITUDE [V]'}
        control_c = 33106 - lockin*4;
        value_c = value*(32768/10);
        lia_writeU16(control_c,uint16(value_c));
    case {'PHASE','PHASE [DEG]'}
        control_c = 33120 - lockin*4;
        value_c = 2^32*(rem(value,360)/360);
        lia_writeU32(control_c,uint32(value_c));
    case {'FREQUENCY','FREQUENCY [HZ]'}
        looprate = 40000000/lia_readU32(33136);
        if lockin>1
            control_c = 33136 - lockin*4;
        else
            control_c = 33036;
        end
        value_c = value*2^32/looprate;
        lia_writeU32(control_c,uint32(value_c));
    case {'UPDATE FREQ','UPDATE FREQ [HZ]'}
        looprate_old = 40000000/lia_readU32(33136);
        control_c = 33136;
        value_c = 40000000/value;
        lia_writeU32(control_c,uint32(value_c));
        for i = 1:4
            if lockin>1
                control_accuminc = 33136 - lockin*4;
            else
                control_accuminc = 33036;
            end
            accuminc_old = lia_readU32(control_accuminc);
            accuminc_new = accuminc_old*looprate_old/value_c;
            lia_writeU32(control_accuminc,uint32(accuminc_new));
        end 
    case {'DATA RATE','DATA RATE [HZ]'}
        error('Assumed to be 200 kHz.  Check FPGA/set in Labview.');
    
    % FPGA controls
    case {'UPDATE RATE','UPDATE RATE (TICKS)'}
        control_c = 33136;
        lia_writeU32(control_c,uint32(value));
    case {'ACCUMULATOR INCREMENT'}
        if lockin>1
            control_c = 33136 - lockin*4;
        else
            control_c = 33036;
        end
        lia_writeU32(control_c,uint32(value));
    case {'PHASE SHIFT'}
        control_c = 33120 - lockin*4;
        lia_writeU32(control_c,uint32(value));
    case {'SIGNAL AMPLITUDE'}
        control_c = 33106 - lockin*4;
        lia_writeU16(control_c,uint16(value));
    case{'BETA'}
        control_c = 33088 - lockin*4;
        lia_writeI32(control_c,int32(value));
    otherwise
        error('Must provide existing control.');
end