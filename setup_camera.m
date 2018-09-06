function vid=setup_camera()
vid = videoinput('winvideo',1,'RGB8_1280x960');
vid.LoggingMode = 'disk';
set(vid,'TriggerRepeat',Inf);
aviobj = VideoWriter('video.avi', 'Motion JPEG AVI');
vid.DiskLogger = aviobj;
triggerconfig(vid,'manual')
set(vid, 'FramesPerTrigger', 1);