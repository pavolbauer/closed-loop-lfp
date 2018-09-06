function [data,timestamps] = closed_loop_lfp_control(varargin)
%CLOSED_LOOP_LFP_CONTROL triggers DAQ output based on measured LFP bands.
%
% The routine iteratively acquires LFP signals from the Intan RHD2000
% amplifier and computes the discrete Fourier-Transform on data of given
% blocksize. Furthermore, the routine generates an output waveform via a
% connected data-acquisition device, if the power of a certain frequency
% band in the measured signal is greater than the power of the band
% recorded at baseline conditions.
%
% The size of the data blocks that are used for the DFFT are bound by the
% the lower band frequency, i.e. a band between 6 and 8 Hz will be
% controlled in blocks on 1/6 seconds.
%
% The routine has been used to control a 570nm laser for optogenetic inhibition 
% of hippocampal OLM-cells in Mikulovic et.al., Nature Communications, 2018.
%
% For aqcuisition of LFP signals the RHD2000 Intan amplifier is used. 
% The routine requires the RHD2000 Matlab Toolbox from Intan Technologies.
% Additional requirements are the Signal Processing and Data Acquisition toolboxes.
%
% [data,timestamps] = real_time_lfp_trigger(name1, value1, name2, value2, ...) 
% runs the routine with the parameters provided. Valid values (and their defaults)
% are:
%       sampling_rate   Sampling rate for the board
%                       Default: rhd2000.SamplingRate.rate25000
%
%       min_freq        Lower band frequency in Hertz. Default: 6
%
%       max_freq        Upper band frequency in Hertz. Default: 8
%
%       Pbase           Power of the baseline recording, assuming the same
%                       frequencies have been used for DFFT. This parameter
%                       is required for the routine to function.
%
%       threshold       The DAQ output is generated if the recorded band-power 
%                       is above baseline times the threshold.
%                       Default: 10
%
%       Wform           The waveform of the analog output signal, which will be 
%                       generated each time the threshold is crossed. This parameter
%                       is required for the routine to function.
%
%       daqs            The data acquisition session used for the generation 
%                       of the waveform.
%
%       signal_datasource
%                       Amplifier channels to be used as signal.
%                       Channel is 1-16 for an RHD2216 chip, 1-32 for an 
%                       RHD2132, or 1-64 for an RHD2164 chip.
%                       Defaults: signal_datasource = 1, signal_channel = 2
%                       reference_datasource = 1, reference_channel = 1
%                       Default: 1
%
%       signal_channel  The channel where the band-power is estimated
%
%       num_seconds     Number of seconds to run main loop before stopping.
%                       Default: 60
%
%       blocksize       Size of the acquisition data block. Default: 60
%      
%       vid             Optional videoinput object used for video recording
%                       during the operation of the routine.
%
%       debug           Boolean flag enabling debug text in the console.
%                       Default: 0
%
% Output:
%
%       data            The acquired data for all 32 amplifier channels,
%                       with an additional boolean vector indicating when
%                       the DAQ output was generated
%
%       timestamps      Continuous timestamps for each sample 
%
% Example: see example.m for an exemplary usage of the routine.
%
% This script is heavily based on the my_real_time_analysis example from the 
% RHD2000-Matlab Toolbox by Intan Technologies.
% 
% Author: Pavol Bauer, Uppsala University, Dep. Scientific Computing, 2017
% E-mail: bauer.pa@gmail.com
% Github: github.com/pavolbauer
%
params = get_default_params();
for i = 1:2:nargin
    params = setfield(params, varargin{i}, varargin{i+1});
end

% Initialize the DAQ-device
if exist('params.daqs',1)
    params.daqs.queueOutputData([0 0]); % make sure to set initial voltage to 0
    params.daqs.startBackground()
    params.daqs.stop()
    params.daqs.queueOutputData(params.Wform); % queue actual trigger waveform
end

% Connecting to the Intan board
display 'Connecting to board. . .';

% Instantiate the rhd2000 driver.  
driver = rhd2000.Driver();

% Connect to a board. 
board = driver.create_board();
board.SamplingRate = params.sampling_rate;

display 'Connected.';

% Calculate num_data_blocks, which is the number of iterations to run
num_data_blocks = floor(params.num_seconds * params.sampling_rate.frequency / params.blocksize);

% Refresh cycle for fft analysis - enough to resolve the low frequency
refresh_cycle = floor(1 / params.minfreq * params.sampling_rate.frequency / params.blocksize)+1;

% Allocate a datablock; we'll reuse it
datablock = rhd2000.datablock.DataBlock(board);

% Allocate the output data-structures
timestamps=zeros(1,params.sampling_rate.frequency*params.num_seconds);
data=zeros(33,params.sampling_rate.frequency*params.num_seconds);

% Start video acquisition, if enabled
if exist('params.vid',1)
   start(params.vid); 
end

% Run the board continuously; necessary for real-time analysis
detected=0;
tic
board.run_continuously();

% Main loop
for i=1:num_data_blocks
    % Get the next data block
    datablock.read_next(board);
    
    % Store the data block in the output vector
    range=params.blocksize*(i-1) + 1:blocksize*i;
    timestamps(range) = datablock.Timestamps;
    data(1:32,range) = datablock.Chips{params.signal_datasource}.Amplifiers.*1000; %data in mV
    data(33, range) = detected;
    
    % If enough new packages arrived, run the DFFT on them
    if (mod(i, refresh_cycle) == 0)        
        fftrange=params.blocksize*(i-refresh_cycle) + 1:params.blocksize*i;
        signal=data(params.signal_channel,fftrange);
        detected = process_theta(signal,params);
        
        % Check for buffer status on the board
        if (board.FIFOPercentageFull > 1)
            display(sprintf('WARNING: board FIFO is %g%% full', ...
                        board.FIFOPercentageFull));
        end
        
        % Trigger video aquisiton, if enabled
        if exist('params.vid',1)
            trigger(params.vid);
        end    
    end
end

% Stop video, if enabled
if exist('params.vid',1)
   stop(params.vid); 
end

% Stop and flush the board, clear the data 
board.stop();
board.flush();
clear datablock;

% Set final output voltage to 0
if exist('params.daqs',1)
    params.daqs.stop()
    params.daqs.queueOutputData([0 0]);
    params.daqs.startBackground()
    params.daqs.stop()
end

disp('Done.')

end

%-----------------------------------------------------------------------

function params = get_default_params()
% Gets default parameters

    % Sampling rate for the board
    params.sampling_rate = rhd2000.SamplingRate.rate25000;
    
    params.threshold = 10;
    params.minfreq=6;
    params.maxfreq=8;
    params.video=0;
    params.debug=0;
    params.blocksize=60;

    % Signal and reference datasources:
    params.signal_datasource = 1;
    params.signal_channel = 2;

    % Run for this number of seconds before stopping.  Note that this
    % refers to the main loop; attaching to the board takes several seconds
    % and is not counted in this number
    params.num_seconds = 60;
    
end

%-----------------------------------------------------------------------

function detected = process_theta(signal, params)
% Run DFFT on one datablock, turn on/off DAQ device.

    % DFFT
    p=nextpow2(length(signal));
    [Pxx,F] = periodogram(signal,rectwin(length(signal)),2^p,params.sampling_rate.frequency);
    Pt=Pxx(F>params.minfreq & F<params.maxfreq);
    
    % Check if the band-power is greater than baseline times threshold 
    if(mean(Pt)>mean(Pbase)*params.threshold)
           if exist('params.daqs',1)
               if ~params.daqs.IsRunning
                   params.daqs.startBackground;
               end
           end
           detected=1;
           if params.debug
               disp(['Band DETECTED (T: ' num2str(toc) ' Base: ' num2str(mean(Pbase)) ' Recorded:  ' num2str(mean(Pt)) ')'])
           end
    else
           if exist('params.daqs',1)
               if params.daqs.IsRunning
                  params.daqs.stop;
                  params.daqs.queueOutputData([0 0]);
                  params.daqs.startBackground()
                  params.daqs.stop; 
                  params.daqs.queueOutputData(Wform);
               end
           end
           detected=0;
           if params.debug
                disp(['Band NOT DETECTED (T: ' num2str(toc) ' Base: ' num2str(mean(Pbase)) ' Recorded:  ' num2str(mean(Pt)) ')'])
           end
    end 
end
