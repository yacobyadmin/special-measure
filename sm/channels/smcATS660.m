function [val, rate] = smcATS660(ico, val, rate, varargin)
% Driver for Alazar 660 2 Channel DAQ, supports streaming 
% val = smcATS660(ico, val, rate, varargin)
% ico(3) args can be: 
% 3: sets/gets  HW sample rate.  negative sets to external fast ac.
% 4: arm before acquisition 
% 5: configures, with val = record length, rate 
% channels: 
% 1,2: DAQ channels
% 3 : clock
% 7 : new flag for number of pulses in group, used for groups with pulses of multiple lengths
%
% This driver requires that smdata inst be set up with data: see github
% wiki for more info. 
% For pulsed data, relies on smabufconfig2 for configuring. 
% Works with masks, so that only data from readout period is saved. 
% Averages multiple data points together before storing; set in
% inst.data.downsamp (usually set by program running scan, not manually)

%
% This is used in two main contexts: charge type scans and pulsed data. 
% For charge type scans, configuring means setting up averaging,
% creating buffers. As data comes in, it is averaged together. 
% For pulsing, need to do that, and set buffers to contain integer number
% of pulsegroups, and when data coming in to use mask to take in readout
% data. 
% Charge scans do not use a mask. Two types of masks for pulsed data. If all pulses have 
% same length (standard), mask is length of one pulse. If pulses have varying length, mask
% has length of all pulses. For now, use limited to cases where all pulses fit in one buffer . 
% For typical use, this is at least 10 ms of data, so should be sufficient.
% 


global smdata;
nbits = 16; 
bufferPost = uint32(13); % number of buffers to post. # your system can handle will vary. 
boardHandle = smdata.inst(ico(1)).data.handle;
switch ico(3)
    case 0
        switch ico(2)
            case {1, 2} % DAQ channels
                % configure data processing, default is mean.
                if ~isfield(smdata.inst(ico(1)).data,'combine') || isempty(smdata.inst(ico(1)).data.combine)
                    combine = @(x) nanmean(x,1);
                else
                    combine = smdata.inst(ico(1)).data.combine;
                end
                waitData = smdata.inst(ico(1)).data.waitData; downsamp = smdata.inst(ico(1)).data.downsamp;
                nBuffers = smdata.inst(ico(1)).data.nBuffers; npoints = smdata.inst(ico(1)).datadim(ico(2), 1);
                samplesPerBuffer = smdata.inst(ico(1)).data.samplesPerBuffer; npointsBuf = smdata.inst(ico(1)).data.npointsBuf;
                chanRng = smdata.inst(ico(1)).data.rng(ico(2));
                s.type = '()';
                if isfield(smdata.inst(ico(1)).data, 'mask') && ~isempty(smdata.inst(ico(1)).data.mask) % Set mask
                    if size(smdata.inst(ico(1)).data.mask,1) >= ico(2) % if mask has 2 rows, use 2nd for 2nd channel.
                        s.subs = {smdata.inst(ico(1)).data.mask(ico(2),:), ':'};
                    else
                        s.subs = {smdata.inst(ico(1)).data.mask(1,:), ':'};
                    end
                else
                    s.subs = {[], ':'}; % without a mask, grab all the data.
                end
                if nBuffers == 1 % Single buffer, no async readout / streaming.
                    buf = calllib('ATSApi', 'AlazarAllocBufferU16', boardHandle, npointsBuf*downsamp+16);
                    while calllib('ATSApi', 'AlazarBusy', boardHandle); end % Wait for data to come in.
                    daqfn('Read',  boardHandle, ico(2), buf, 2, 1, 0, npointsBuf*downsamp);
                    setdatatype(buf, 'uint16Ptr',npointsBuf*downsamp+16)
                    if ~isempty(s.subs{1})
                        if length(s.subs{1})==downsamp % Apply mask (s), reshape data into downsamp x npoints matrix, average across rows.
                            newDataAve = combine(subsref(reshape(buf.value, downsamp, npointsBuf), s), 1)';
                        else % Varying pulse lengths.
                            npls = length(s.subs{1})/downsamp; % subs has length # points in buffer, downsamp is average number of points per pulse.
                            % Take useful data, reshape into full pulse lines, apply mask.
                            % Assumes readout time constnat across pulses. 
                            newData=subsref(reshape(buf.value(1:downsamp*npointsBuf),npls*downsamp,npointsBuf/npls),s);
                            % Now all pulses have same length data, so separate and average.
                            newDataAve = reshape(combine(reshape(newData,size(newData,1)/npls,npls,npointsBuf/npls)),1,npointsBuf)';
                        end
                    else
                        newDataAve = combine(reshape(buf.Value(1:downsamp*npointsBuf),downsamp,npointsBuf))';
                    end
                    daqfn('FreeBufferU16', boardHandle, buf);
                    val = chanRng * (newDataAve/2^(nbits-1)-1);
                else
                    val = zeros(npoints, 1); % val is filled with incoming data.
                    waittime = 10*(1000*samplesPerBuffer/smdata.inst(ico(1)).data.samprate)+5000; % how long to wait for data to come in before timing out
                    for i = 1:nBuffers % read # records/readout
                        bufferIndex = mod(i-1, bufferPost) + 1; % since we recycle buffers, need to consider which buffer currently using
                        pbuffer = smdata.inst(ico(1)).data.buffers{bufferIndex}; % current buffer.
                        %try
                        daqfn('WaitAsyncBufferComplete', boardHandle, pbuffer, waittime);  % Add error handling. Runs until all data has come in.
                        setdatatype(pbuffer, 'uint16Ptr',samplesPerBuffer)
                        if ~isempty(s.subs{1}) % Average data, taking only mask.
                            if length(s.subs{1}) == downsamp %old style: each pulse the same length
                                newDataAve{i} = combine(subsref(reshape(pbuffer.value, downsamp, npointsBuf), s), 1);
                            else % FIXME
                                npls = length(s.subs{1})/downsamp;
                                newData=subsref(reshape(pbuffer.value,npls*downsamp,npointsBuf/npls),s); 
                                newDataAve{i} = reshape(combine(reshape(newData,size(newData,1)/npls,npls,npointsBuf/npls)),1,npointsBuf);
                            end
                        else
                            newDataAve{i} = combine(reshape(pbuffer.Value,downsamp,length(pbuffer.Value)/downsamp));
                        end
                        if ~waitData % Average data and insert into val as it comes in.
                            newInds = (i - 1)*npointsBuf+1:i*npointsBuf; % new sm points coming in.
                            val(newInds) = chanRng * (newDataAve{i}(1:length(newInds))/2^(nbits-1)-1); % is this even necessary anymore?
                        end            
                        daqfn('PostAsyncBuffer',boardHandle, pbuffer,samplesPerBuffer*2);                        
                    end
                    if waitData % If data comes in too fast to process on the run, average at the end. Does not work with masks at this time.
                        val = chanRng*(mean(cell2mat(newDataAve),2)/2^(nbits-1)-1);
                    else
                        val(npoints+1:length(val)) =[]; % If final buffer is not full, delete that data at the end.
                    end
                    daqfn('AbortAsyncRead', boardHandle);
                end
            case 3
                val = smdata.inst(ico(1)).data.samprate;
            case 7
                val = smdata.inst(ico(1)).data.num_pls_in_grp;
        end
    case 1
        switch ico(2)
            case 3
                setclock(ico, val);
            case 7
                smdata.inst(ico(1)).data.num_pls_in_grp = val;
        end
    case 3 % software trigger
        daqfn('ForceTrigger', boardHandle);
    case 4 % Arm
        nBuffers = smdata.inst(ico(1)).data.nBuffers;
        if nBuffers>1 %For async readout. Abort ongoing async readout, config,post buffers,
            chan = smdata.inst(ico(1)).data.chan; 
            daqfn('AbortAsyncRead', boardHandle);
            samplesPerBuffer = smdata.inst(ico(1)).data.samplesPerBuffer;
            daqfn('BeforeAsyncRead',  boardHandle, chan, 0, samplesPerBuffer, 1, nBuffers, 1024);% uses total # records
            for i=1:min(nBuffers,bufferPost) % Number of buffers to use in acquisiton;
                daqfn('PostAsyncBuffer', boardHandle, smdata.inst(ico(1)).data.buffers{i}, samplesPerBuffer*2);
            end
        end
        daqfn('StartCapture', boardHandle); % start readout (awaiting trigger)
    case 5 % Configure readout. Find best buffer size, number of buffers, then allocate. Save info in inst.data.
        % val passed by smabufconfig2 is npoints in the scan, usually npulses*nloop for pulsed data.
        % rate passed by smabufconfi2 is 1/pulselength
        % If pulsed data, also pass the number of pulses so that each buffer contains integer number of pulsegroups, making masking easier.
        if ~exist('val','var'),   return;     end
        nchans=2; chanInds = [1,2]; 
        if  ~isempty(varargin) && strcmp(varargin{2},'chans')
            smdata.inst(ico(1)).data.chan = sum(chanInds(varargin{1}));
        else
            smdata.inst(ico(1)).data.chan = chanInds(ico(2));
        end        
        
        % Check that instrument can be set to samprate in inst.data
        currRate = cell2mat(smget('samprate')); 
        if currRate ~= smdata.inst(ico(1)).data.samprate
            clockrate = setclock(ico,smdata.inst(ico(1)).data.samprate);
            if clockrate~=smdata.inst(ico(1)).data.samprate % ummmm
                smdata.inst(ico(1)).data.samprate=clockrate;
            end
        end
        samprate = smdata.inst(ico(1)).data.samprate;
        
        % Find downsamp value -- number of points averaged together. Uses samprate, # data
        % points input / time, divided by 'rate,' number of data points output / time
        if samprate > 0  
            if ~isempty(varargin) && strcmp(varargin{2},'pls')
                downsampBuff = floor(samprate/rate)*varargin{1}; % Multiply points / pulse by # of pulses so that pulsegroup fits in buffer.
            else
                % downsamp is the number of points acquired by the alazar per pulse. 
                % nominally (sampling rate)*(pulselength)
                downsampBuff = floor(samprate/rate); 
            end
            downsamp = floor(samprate/rate); % Number of points averaged together.
            if downsamp == 0 %
                error('Pulse/ramp rate too large. More points output than input. Increase samprate or decrease rate.');
            end
        else
            downsamp = 1;
        end
        rate=samprate/downsamp; % Set rate to the new ramprate (returned to smabufconfig2)
        
        % Select number of buffers. Make sure # points per buffer is divisible by sampInc
        % Tries to also make divisible by downsampling factor, but if both aren't possible adds extra points 
        % Try to get closest to maxBufferSize .
        npoints = val;
        sampInc = 16; % buffer size must be a multiple of this. Depends on model, check model.
        maxBufferSize = 1024000; % Depnds on model, check manual
        if downsampBuff > maxBufferSize
            error('Need to increase number of points / reduce ramptime. Too many points per buffer');
        end
        buffFactor = lcm(sampInc,downsampBuff); % Buffer wants to be be multiple of both sampInc and downsampBuff, so find lcm.        
        % If buffFactor > maxBufferSize, this is 0. Otherwise, gives number
        % of repeats we can fit in buffer. 
        samplesPerBuffer = floor(maxBufferSize / buffFactor)*buffFactor;         
        if samplesPerBuffer > npoints*downsamp+sampInc % Can fit multiple lines in buffer, reduce points.             
            %buffFactor = lcm(sampInc,val*downsamp); % Buffer must be multiple of both sampInc and downsamp, so find lcm.            
            %samplesPerBuffer = floor(val*downsamp / buffFactor)*buffFactor;
            samplesPerBuffer = ceil(npoints*downsamp/sampInc)*sampInc; 
        end
        if samplesPerBuffer == 0 % If maxBufferSize < buffFactor, need to redo.
            downsampBuff = round(downsampBuff/sampInc)*sampInc; 
            if downsampBuff ==0, downsampBuff = 1; end
            buffFactor = lcm(sampInc,downsampBuff); % Buffer must be multiple of both sampInc and downsamp, so find lcm.
            samplesPerBuffer = floor(maxBufferSize / buffFactor)*buffFactor;
            downsamp = downsampBuff;
            rate=samprate/downsampBuff;
        end
        N = downsamp * npoints; % N = total samples
        nBuffers = ceil(N / samplesPerBuffer);
        samplesPerBuffer = ceil(N/nBuffers/sampInc)*sampInc; 
        npointsBuf = round(samplesPerBuffer/downsamp);
        
        minSamps=128; % Depends on model, check manual
        if nBuffers > 1 % Configure Async read: abort current readout, free buffers, allocate new buffers.
            daqfn('AbortAsyncRead', boardHandle);
            if N < minSamps
                error('Record size must be larger than 128');
            end
            missedbuf = [];
            for j = 1:length(smdata.inst(ico(1)).data.buffers) % Free buffers
                try
                    daqfn('FreeBufferU16', boardHandle, smdata.inst(ico(1)).data.buffers{j});
                catch
                    missedbuf(end+1)=j; %#ok<AGROW>
                end
            end
            smdata.inst(ico(1)).data.buffers={}; %for future: cell(length(smdata.inst(ico(1)).data.rng),0);
            for i=1:bufferPost % Allocate buffers
                pbuffer = calllib('ATSApi', 'AlazarAllocBufferU16', boardHandle, samplesPerBuffer); % Use callib as this does not return a status byte.
                if pbuffer == 0
                    fprintf('Failed to allocate buffer %i\n',i)
                    error('Error: AlazarAllocBufferU16 %u samples failed\n', samplesPerBuffer);
                end
                smdata.inst(ico(1)).data.buffers{i} = pbuffer ;
            end
        else % Only one buffer, no async readout needed.            
            daqfn('SetRecordCount', boardHandle, 1)
            daqfn('SetRecordSize', boardHandle,0,samplesPerBuffer);
        end
        
        % If the same pulse is run repeatedly and want to average many
        % together, use mean. Need to pass the number of samples/pulse as
        % varargin{1}.
        % For this, set higher samprate, so data comes in so quickly can't
        % process until end.
        if ~isempty(varargin) && strcmp(varargin{2},'mean')
            smdata.inst(ico(1)).datadim(1:nchans) = varargin{1};
            smdata.inst(ico(1)).data.npointsBuf = round(samplesPerBuffer/varargin{1});
            smdata.inst(ico(1)).data.waitData = 1;
        else
            smdata.inst(ico(1)).datadim(1:nchans) = npoints;
            smdata.inst(ico(1)).data.npointsBuf = npointsBuf;
            smdata.inst(ico(1)).data.waitData = 0;
        end
        smdata.inst(ico(1)).data.downsamp = downsamp;
        smdata.inst(ico(1)).data.nBuffers = nBuffers;
        smdata.inst(ico(1)).data.samplesPerBuffer = samplesPerBuffer;
    case 6 % Set mask.
        smdata.inst(ico(1)).data.mask = val;
    otherwise
        error('Operation not supported.');
end
end

function rate=setclock(ico, val)
% 3 clocks can be used, set in inst.data.extclk: 0: PLL, 1: external clock,
% 2: internal clock.
% Frequencies that can be set using PLL varies by DAQ model.
global smdata;
boardHandle = smdata.inst(ico(1)).data.handle;
if smdata.inst(ico(1)).data.extclk == 0 % Use 10 MHz PLL
    smdata.inst(ico(1)).data.samprate = max(min(val, 130e6), 0); % Set within range
    rate = val/1e6;
    dec = floor(130/rate);
    rate = max(min(130, round(rate * dec)),110)*1e6;
    daqfn('SetCaptureClock', boardHandle, 7, rate, 0, dec-1); % external
    smdata.inst(ico(1)).data.samprate=rate/dec;
    rate=rate/dec;
elseif smdata.inst(ico(1)).data.extclk == 1 % Fast external clock
    smdata.inst(ico(1)).data.samprate=val;
    daqfn('SetCaptureClock', boardHandle, 2, 64, 0, 0);
    rate=val;
elseif smdata.inst(ico(1)).data.extclk == 2 %internal clock
    smdata.inst(ico(1)).data.samprate=val;
    intclkrts.hexval={'1','2','4','8','A','C','E','10','12','14','18','1A','1C','1E','22','24','25'};
    intclkrts.val=[1e3,2e3,5e3,1e4,2e4,5e4,1e5,2e5,5e5,1e6,2e6,5e6,10e6,20e6,50e6,100e6,125e6];
    [~,ind]=min(abs(val-intclkrts.val));
    clkrt=hex2dec(intclkrts.hexval(ind));
    daqfn('SetCaptureClock', boardHandle, 1 , clkrt, 0, 0); %changed from 2,65
    rate=intclkrts.val(ind);
    smdata.inst(ico(1)).data.samprate=rate;
end
end