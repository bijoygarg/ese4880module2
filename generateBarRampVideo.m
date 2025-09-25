function generateBarRampVideo()
% generateBarRampVideo
%   Write video containing a series of colored bars with decreasing brightness over time.
%   Output size, frames per second, and bit depth of the ramp are adjustable.
%   2024-09: Written for ESE 488, by Matthew Lew
%   2025-09: Code cleanup

clearvars;
close all;

%% ===================== Parameters =====================
debug = true;

% ---- Video Output Parameters ----
vidWidth = 1440;
vidHeight = 1080;
vidFPS = 20;        % Frame rate for video
bitDepth = 6;       % Bit depth for ramp
maxBrightness = 255; % Maximum brightness value (8-bit)

outfile = "bars_ramp_bitDepth" + num2str(bitDepth) + "_" + num2str(vidFPS) + "fps";

%% ===================== Video Initialization =====================
v = VideoWriter(outfile, "MPEG-4");
v.Quality = 98;
v.FrameRate = vidFPS;
open(v);

%% ===================== Debug Display Setup =====================
if debug
    figure('Position', [50 50 vidWidth vidHeight], "Color", "black", "DefaultAxesFontSize", 20, "DefaultAxesXColor", "white", "DefaultAxesYColor", "white", "DefaultAxesColor", "black");
    axVideo = axes('position', [0 0 1 1]);
    hImage = image(zeros(vidHeight, vidWidth, 3), "Parent", axVideo);
    axis(axVideo, "image", "off");
    hText = text(0, 0, "Frame #", 'color', 'g', 'FontSize', 14, 'VerticalAlignment', 'top', 'parent', axVideo);
end

%% ===================== Color Definitions =====================
green   = [0; 1; 0];
red     = [1; 0; 0];
blue    = [0; 0; 1];
black   = [0; 0; 0];
magenta = red + blue;
yellow  = red + green;
cyan    = green + blue;
white   = red + green + blue;

% Join color bars together; colors need to be in dimension 3
colorbars = permute([white yellow cyan green magenta red blue black], [3 2 1]);

%% ===================== Frame Generation Loop =====================
numFrames = 2^bitDepth;
frameBrightnessVals = linspace(maxBrightness, 0, numFrames);
for frameIdx = 1:numFrames
    frameBrightness = frameBrightnessVals(frameIdx);
    % Expand colorbars to size of video and scale by brightness
    testImg = uint8(round(frameBrightness) * imresize(colorbars, [vidHeight vidWidth], "nearest"));
    % Write individual frames as 8 bits * 3 color channels
    v.writeVideo(testImg);

    % Debug: show video being written
    if debug
        hImage.CData = testImg;
        hText.String = "Frame " + num2str(frameIdx) + " / " + num2str(numFrames);
        drawnow limitrate nocallbacks;
    end
end

%% ===================== Close Video File =====================
close(v);

end