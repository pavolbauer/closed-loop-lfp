function [daqs,Wform]=setup_daq()
%% initialize recording parameters
% in which time should the laser be activated?
WaveTime=1:10000;

%Laser power
LaserPower=5; % 

% amplitude and frequency of laser signal
Amps=[ones(1,1)*LaserPower]; % all the time 5V
fr=[ones(1,1)*16]; % FREQUENCY: all the time 16 hz

%sigal type: sine or flat
type='sine';

%%
if (not(exist('daqs',1)))
daqs = daq.createSession('ni');
daqs.Rate = 1000;
daqs.addAnalogOutputChannel('Dev1','ao0','Voltage'); 
end

%% put together recording signal

Wform=zeros(1000,1);

if strcmp(type,'sine')
    Wform(WaveTime,1)=sin((WaveTime)*.001*fr(1)*2*pi);
    Wform(WaveTime,1)=(Wform(WaveTime,1)+1)/2;
    Wform(WaveTime,1)=Wform(WaveTime,1)*Amps(1);
    Wform(end,1)=0;
elseif strcmp(type,'flat')
    Wform(WaveTime,1)=Amps(1);
end  

plot(Wform)
  ylim([0 6])
  xlabel('time')
  ylabel('voltage')