
function ROItimeSeries = videoROIs2timeSeries(varargin)
% videoROIs2timeSeries: Extracts time-series amplitude data from video ROIs
%   ROItimeSeries = videoROIs2timeSeries(filepathname) queries the user for specific
%   pixel(s) in a video to extract time-series amplitude data from. It
%   saves these data to a file and into
%   ROItimeSeries(pixelIdx,frameNum,colorChannel), an NxMx3 array
% 2024-09: Written for ESE 488, by Matthew Lew
% 2025-09: Code cleanup

close all;

%% ===================== Parameter Initialization =====================
debug = true;
roiRadius = 0;  % ROI includes center pixel +/- roiRadius

%% ===================== File Selection and Setup =====================
if nargin == 1
    [infilepath, infilename, infileext] = fileparts(varargin{1});
else
    [file, location] = uigetfile({'*.mp4';'*.mj2';'*.tif;*.tiff';'*.*'}, 'Open video file for analysis');
    if isequal(file,0)
        error('No file selected. Exiting.');
    end
    [infilepath, infilename, infileext] = fileparts([location file]);
end

% Open video or TIFF file
if contains(infileext, 'tif')    % are we opening video or tif file?
    v = Tiff([infilepath filesep infilename infileext], "r");
    imgWidth = getTag(v, 'ImageWidth');
    imgHeight = getTag(v, 'ImageLength');
else
    v = VideoReader([infilepath filesep infilename infileext]);
    imgWidth = v.Width;
    imgHeight = v.Height;
end

% Try to load metadata (if available)
metadataFilename = [infilepath filesep infilename(1:end-6) '_videoMetadata.mat']; % Assumes last 6 chars are timestamp
if isfile(metadataFilename)
    metadata = load(metadataFilename);
    t = metadata.timestamp - min(metadata.timestamp);
end
outfilePrefix = infilename + "_ROItimeSeries";

%% ===================== ROI Selection =====================

% Create figure window that matches video size
figure('Position', [50 50 imgWidth imgHeight], "Color", "black", "DefaultAxesFontSize", 20, "DefaultAxesXColor", "white", "DefaultAxesYColor", "white", "DefaultAxesColor", "black");
axVideo = axes('position', [0 0 1 1]);
hImage = image(zeros(imgHeight, imgWidth, 3), "Parent", axVideo);
axis(axVideo, "image", "off");
hText = text(0, 0, "Frame #", 'color', 'g', 'FontSize', 12, 'VerticalAlignment', 'top', 'parent', axVideo);

% Read initial frame
if contains(infileext, 'tif')
    img = read(v);
else
    img = readFrame(v);
end

hImage.CData = img;
hText.String = "Click the center of each ROI, then press 'Return'.";
[roiX, roiY] = ginput;
roiX = round(roiX);       % round to the nearest pixel
roiY = round(roiY);

if isempty(roiX) || isempty(roiY)
    error('No ROIs selected. Exiting.');
end

% Mark ROI locations
hold on;
plot(roiX, roiY, 'o');

%% ===================== Frame Reading and ROI Extraction =====================
frameNum = 1;
% We don't know how many frames are in tiff file without reading entire file, so just set array to have 1 frame for now
ROItimeSeries = zeros(length(roiX), 1, 3);    % ROIs x frames x 3 colors

while true
    % Calculate ROI mean values for each ROI
    for a = 1:length(roiX)
        xRange = roiX(a) + (-roiRadius:roiRadius);
        yRange = roiY(a) + (-roiRadius:roiRadius);
        % Ensure indices are within image bounds
        xRange = xRange(xRange >= 1 & xRange <= imgWidth);
        yRange = yRange(yRange >= 1 & yRange <= imgHeight);
        ROItimeSeries(a, frameNum, :) = mean(img(yRange, xRange, :), [1 2], "double");
    end

    % Read next frame or break if done
    if contains(infileext, 'tif')
        if ~lastDirectory(v)
            nextDirectory(v);
            img = read(v);
            frameNum = frameNum + 1;
            % Expand array if needed
            if size(ROItimeSeries,2) < frameNum
                ROItimeSeries(:,frameNum,:) = 0;
            end
        else
            break;
        end
    else
        if v.hasFrame
            img = readFrame(v);
            frameNum = frameNum + 1;
            if size(ROItimeSeries,2) < frameNum
                ROItimeSeries(:,frameNum,:) = 0;
            end
        else
            break;
        end
    end
    % Debug: show video being read
    if debug
        hImage.CData = img;
        hText.String = "Frame " + num2str(frameNum);
        drawnow limitrate nocallbacks;
    end
end

if ~exist('t', 'var')
    t = 1:frameNum;
end

%% ===================== Save Data =====================
save(outfilePrefix + ".mat", "ROItimeSeries", "roiX", "roiY", "t", "infilepath", "infilename", "infileext");

%% ===================== Plot ROI Intensities =====================
legendText = "(" + string(roiX) + "," + string(roiY) + ")";
channelNames = {'R', 'G', 'B'};

for c = 1:3
    figure;
    if exist("metadata", "var")
        plot(t*1E3, squeeze(ROItimeSeries(:,:,c))');
        xlabel("time (ms)");
    else
        plot(squeeze(ROItimeSeries(:,:,c))');
        xlabel("Frame number");
    end
    legend(legendText, "Location", "best");
    ylabel(channelNames{c} + " values");
    axis tight;
    title([channelNames{c} ' Channel ROI Time Series']);
end

end