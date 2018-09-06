# closed-loop-lfp
Closed-loop control that triggers DAQ output based on measured LFP bands.

The routine iteratively acquires LFP signals from the Intan RHD2000
amplifier and computes the discrete Fourier-Transform on data of given
blocksize. Furthermore, the routine generates an output waveform via a
connected data-acquisition device, if the power of a certain frequency
band in the measured signal is greater than the power of the band
recorded at baseline conditions.

The size of the data blocks that are used for the DFFT are bound by the
the lower band frequency, i.e. a band between 6 and 8 Hz will be
controlled in blocks on 1/6 seconds.

The routine has been used to control a 570nm laser for optogenetic inhibition 
of hippocampal OLM-cells in Mikulovic et.al., Nature Communications, 2018.

For acquisition of LFP signals the RHD2000 Intan amplifier is used. 
The routine requires the RHD2000 Matlab Toolbox from Intan Technologies.
Additional requirements are the Signal Processing and Data Acquisition toolboxes.

* Example: see example.m for an exemplary usage of the routine.

This script is heavily based on the my_real_time_analysis example from the 
RHD2000-Matlab Toolbox by Intan Technologies.

Author: Pavol Bauer, Uppsala University, Dep. Scientific Computing, 2017
E-mail: bauer.pa@gmail.com
