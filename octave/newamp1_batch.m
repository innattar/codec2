% newamp1_batch.m
%
% Copyright David Rowe 2016
% This program is distributed under the terms of the GNU General Public License 
% Version 2
%
% Octave script to batch process model parameters using the new
% amplitude model.  Used for generating samples we can listen to.
%
% Usage:
%   ~/codec2-dev/build_linux/src$ ./c2sim ../../raw/hts1a.raw --dump hts1a
%   $ cd ~/codec2-dev/octave
%   octave:14> newamp1_batch("../build_linux/src/hts1a")
%   ~/codec2-dev/build_linux/src$ ./c2sim ../../raw/hts1a.raw --amread hts1a_am.out -o - | play -t raw -r 8000 -s -2 -
% Or with a little more processing:
%   codec2-dev/build_linux/src$ ./c2sim ../../raw/hts2a.raw --amread hts2a_am.out --awread hts2a_aw.out --phase0 --postfilter --Woread hts2a_Wo.out -o - | play -q -t raw -r 8000 -s -2 -

% process a whole file and write results
% TODO: 
%   [ ] refactor decimate-in-time to avoid extra to/from model conversions
%   [ ] switches to turn on/off quantisation
%   [ ] rename mask_sample_freqs, do we need "mask" any more

function [fvec_log amps_log] = newamp1_batch(samname, optional_Am_out_name, optional_Aw_out_name)
  newamp;
  more off;

  max_amp = 80;
  decimate = 4;
  load vq;

  model_name = strcat(samname,"_model.txt");
  model = load(model_name);
  [frames nc] = size(model);

  if nargin == 2
    Am_out_name = optional_Am_out_name;
  else
    Am_out_name = sprintf("%s_am.out", samname);
  end

  fam  = fopen(Am_out_name,"wb"); 

  % encoder loop ------------------------------------------------------

  fvec_log = []; amps_log = [];

  % prime initial values so first pass iterpolator works.  TODO: improve this

  for f=1:frames
    Wo = model(f,1);
    L = min([model(f,2) max_amp-1]);
    Am = model(f,3:(L+2));
    AmdB = 20*log10(Am);
    e(f) = sum(AmdB)/L;

    % fit model

    [AmdB_ res fvec fvec_ amps] = piecewise_model(AmdB, Wo);
    fvec_log = [fvec_log; fvec];
    amps_log = [amps_log; amps];

    model_(f,1) = Wo; model_(f,2) = L; model_(f,3:(L+2)) = 10 .^ (AmdB_(1:L)/20);
  end

  for f=1:frames
    if (f > 1) && (e(f) > (e(f-1)+3))
        decimate = 2;
      else
        decimate = 4;
    end
    printf("%d ", decimate);   

    AmdB_ = decimate_frame_rate(model_, decimate, f, frames);
    L = length(AmdB_);

    Am_ = zeros(1,max_amp);
    Am_(2:L) = 10 .^ (AmdB_(1:L-1)/20);  % C array doesnt use A[0]
    fwrite(fam, Am_, "float32");
    Am_ = zeros(1,max_amp);
  end

  fclose(fam);
  printf("\n")

  figure(1); clf;
  plot(e,'+-');
endfunction
  
