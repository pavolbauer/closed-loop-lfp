%% 1)a) setup daq device
[daqs,Wform]=setup_laser;

%% 1)b) setup camera (optional)
vid=setup_camera;

%% 2) record baseline signal (without DAQ output)
[bl_data,bl_timestamps] = real_time_lfp_trigger('num_seconds',60); 

%% 3) check the power spectrum of the baseline signal
ch=23; % <<< AMPLIFIER CHANNEL USED FOR REALTIME CONTROL >>>
SR=25000; %assuming default sample rate of 25k
window=2*SR;
overlap=1.8*SR;
[~,F,T,P] = spectrogram(bl_data(ch,:),window,overlap,2^18,SR);
imagesc(T,F,P);
colormap('jet');
cax=caxis;
caxis([0 cax(2)./5])
ylim([3 13])

%% 4) compute baseline PSD
MINFREQ=6; % lower band frequency
MAXFREQ=8; % upper band frequency

I= F>MINFREQ & F<MAXFREQ;
Pbase=mean(P(I,:),2);

%% 5) run the closed-loop control
threshold=10;
num_seconds=60; 

[data,timestamps] = real_time_lfp_trigger('daq',daq,'Pbase',Pbase,'Wform',Wform,...
    'num_seconds',num_seconds, 'signal_channel', ch, ...
    'minfreq',MINFREQ,'maxfreq',MAXFREQ,...
    'threshold',threshold,'vid',vid);

%% check the spectrogram of the recording
[~,F,T,P] = spectrogram(data(ch,:),window,overlap,2^18,SR);
imagesc(T,F,P);
colormap('jet');
cax=caxis;
caxis([0 cax(2)./5])
ylim([3 13])

figure
bar(0:1/SR:num_seconds-1/SR,data(33,:));
xlim([1 num_seconds-1])
box off

%% 4) save results for each experiments
save('Output/recording01.mat','data','timestamps','Pbase','Wform','bl_data', ...
    'bl_timestamps','ch','threshold','MINFREQ','MAXFREQ','SR','num_seconds');
