
function saveCameraVideo()
% saveCameraVideo: Acquire and save video from FLIR Blackfly S camera.
%   Grabs N frames from the camera and saves to disk as MP4 or TIF.
%   Designed for "gentl" hardware interface (FLIR Blackfly S BFS-U3-16S2C).
%   See: https://www.mathworks.com/hardware-support/gentl.html
%   2024-09: Written for ESE 488, by Matthew Lew
%   2025-09: Code cleanup, combine MP4 and TIF saving into one script

% --- Reference Links ---
% https://www.mathworks.com/help/imaq/get-hardware-metadata-from-genicam-device.html
% https://www.mathworks.com/help/imaq/genicam-gentl-hardware.html
% https://www.mathworks.com/help/imaq/executecommand.html
% https://softwareservices.flir.com/BFS-U3-16S2/latest/Model/public/index.html

close all;

%% ===================== Constants and Acquisition Parameters =====================
% ---- Camera/Acquisition Constants ----
CAMERA_SENSOR_WIDTH  = 1440;
CAMERA_SENSOR_HEIGHT = 1080;
ROI_WIDTH            = 320;
ROI_HEIGHT           = 240;
BINNING              = 1;    % Combine pixels together (see FLIR docs)
EXPOSURE_TIME_US     = 1000; % μs
GAIN_DB              = 28;   % dB
FRAMES_PER_TRIGGER   = 1000; % Number of frames to collect after start()

% ---- Derived ROI ----
roiXOffset = (CAMERA_SENSOR_WIDTH  - ROI_WIDTH)  / 2;
roiYOffset = (CAMERA_SENSOR_HEIGHT - ROI_HEIGHT) / 2;
roiPosition = [roiXOffset roiYOffset ROI_WIDTH ROI_HEIGHT]; % [XOffset YOffset Width Height]

outfilePrefix = string(datetime, "yyyy-MM-dd HH.mm");
outFileFPS    = 20;    % set frame rate of saved video file (only affects playback)
status        = 0;     % 0 = stopped, 1 = preview, 2 = acquiring data

%% open camera
% formats supported by Blackfly camera:
% 'BGR8'	'BGRa8'	'BayerRG16'	'BayerRG8'	'Mono10Packed'	'Mono12Packed'	'Mono16'	'Mono8'	'RGB8Packed'	'YUV411Packed'	'YUV422Packed'	'YUV444Packed'
% 'BayerRG8' is an 8-bit color format (226 max fps w/ISP off, 76 max fps w/ISP on)
% 'BayerRG16' is a 16-bit color format (81 max fps w/ISP off, 76 max fps w/ISP on)
% See https://softwareservices.flir.com/BFS-U3-16S2/latest/Model/spec.html

vidDevice = videoinput("gentl", 1, "BayerRG8", "ROIPosition", roiPosition);
vidSrc = getselectedsource(vidDevice);

%% acquisition parameters

% ISPENABLE enum 
% Controls whether the image processing core is used for optional pixel format modes (i.e. mono).
% Camera can go to faster frame rates if ISP is off.
vidSrc.IspEnable = 'False';
% vidSrc.IspEnable = 'True';

% Sets the operation mode of the Exposure. Mode for shutter/exposure control.
% Possible choices are: Off, Timed, TriggerWidth, and TriggerControlled
% Off disables the exposure and leaves the shutter open, Timed uses the 
% ExposureTime property and is not compatible with ExposureTimeAuto turned 
% on, and TriggerWidth and TriggerControlled require ExposureActive hardware 
% triggering to be used.
vidSrc.ExposureMode = 'Timed';

% Sets the automatic exposure mode when the ExposureMode is 'Timed'.
% Possible choices are: Off, Once, and Continuous.
%Once is a convergence method, while continuous is a continuous readjustment
%of exposure during acquisition.
vidSrc.ExposureAuto = 'Off';

% EXPOSURETIME double       [12 30000000]     
% Exposure time in microseconds when Exposure Mode is Timed.
% Sets the exposure time in microseconds (us) when ExposureMode is set to Timed.
vidSrc.ExposureTime = EXPOSURE_TIME_US;

% Specify whether or not to use the automatic gain control (AGC).
% Possible choices are: Off, Once, and Continuous and possibly device specific values.
% Once is a convergence method, while continuous is a continuous readjustment
% of gain during acquisition.
vidSrc.GainAuto = 'Off';

% GAIN double       [0 47.9943]      
% Controls the amplification of the video signal in dB.
vidSrc.Gain = GAIN_DB;

% GAMMAENABLE enum         
% Enables/disables gamma correction.
% vidSrc.GammaEnable = "True";   
vidSrc.GammaEnable = "False";  

% BALANCEWHITEAUTO enum 
% White Balance compensates for color shifts caused by different lighting
% conditions and can be automatically or manually controlled.
% Specify the mode for the while balancing between the channels or taps.
% Possible choices are:
% Off, Once, and Continuous and possibly device specific values.
% Once is a convergence method, while continuous is a continuous readjustment 
% of white balance during acquisition.
%    See also PROPINFO, the various BalanceRatio, and the various BalanceRatioAbs properties.
vidSrc.BalanceWhiteAuto = "Off";

% BINNINGHORIZONTAL integer       [1 4]     
% Number of horizontal photo-sensitive cells to combine together.
% Sets the horizontal binning.  Changing this property will reset the 
% RegionOfInterest since the maximum image size changes.
%    See also PROPINFO, and BinningVertical.
vidSrc.BinningHorizontal = BINNING;
vidSrc.BinningVertical = BINNING;

% FRAMESPERTRIGGER          
% Specify the number of frames to acquire using the selected video source.
% By default, the object acquires 10 frames for each trigger.
% If FramesPerTrigger is set to Inf, the object keeps acquiring frames
% until an error occurs or you issue a STOP command. When FramesPerTrigger
% is set to Inf, the object ignores the value of the TriggerRepeat property.
% The value of FramesPerTrigger cannot be modified while the object is
% running. See also IMAQDEVICE/STOP.
vidDevice.FramesPerTrigger = FRAMES_PER_TRIGGER;

% ---- Enable Chunk Mode and Set Chunk Selectors ----
vidSrc.ChunkModeActive = "True";
chunkSelectors = {"FrameID", "ExposureTime", "Gain", "BlackLevel", "PixelFormat"};
for i = 1:length(chunkSelectors)
    vidSrc.ChunkSelector = chunkSelectors{i};
    vidSrc.ChunkEnable = "True";
end
vidSrc.ChunkSelector = "Height"; vidSrc.ChunkEnable = "False";
vidSrc.ChunkSelector = "Width";  vidSrc.ChunkEnable = "False";
chunkinfo = chunkDataInfo(vidSrc);

%% ===================== GUI and Preview Setup =====================

imWidth = roiPosition(3);
imHeight = roiPosition(4);
nColors = vidDevice.NumberOfBands;

hFig = figure('Toolbar', 'none', ...
    'Menubar', 'none', ...
    'NumberTitle', 'Off', ...
    'Name', 'Camera Preview and Acquisition', ...
    'Position', [50 50 imWidth imHeight]);


% ---- GUI Buttons (grouped for clarity) ----
buttonSpecs = {
    'Save as mp4',   [0    0.02 0.15 .08], @saveVideo;
    'Save as Tif',   [0.16 0.02 0.15 .08], @saveTif;
    'Stop Preview',  [0.32 0.02 0.15 .08], @togglePreview;
    'Close',         [0.48 0.02 0.15 .08], @(~,~) close(gcf)
};
for b = 1:size(buttonSpecs,1)
    c = uicontrol('String', buttonSpecs{b,1}, ...
        'Units', 'normalized', ...
        'FontSize', 11, ...
        'Position', buttonSpecs{b,2});
    c.Callback = buttonSpecs{b,3};
end

% ---- Timestamp Label ----
hTextLabel = uicontrol('style', 'text', 'String', 'Image Info', ...
    'Units', 'normalized', ...
    'FontSize', 11, ...
    'Position', [0.64 .02 .32 .08]);

% ---- Image Preview ----
hImage = image(zeros(imHeight, imWidth, nColors));
% figSize = get(hFig, 'Position');
% figWidth = figSize(3); figHeight = figSize(4);
% set(gca, 'Unit', 'pixels');
% set(gca, 'Position', [((figWidth - imWidth)/2), ((figHeight - imHeight)/2), imWidth, imHeight]);

setappdata(hImage, 'UpdatePreviewWindowFcn', @updateWindow);
setappdata(hImage, 'hTextLabel', hTextLabel);

%% ===================== Start Preview =====================
preview(vidDevice, hImage);
status = 1;

%% ===================== Helper Functions =====================
    function updateWindow(~, event, hImageLocal)
        % updateWindow: Updates the preview window and info label.
        %   Updates the preview image and label based on acquisition status.
        hTextLabelLocal = getappdata(hImageLocal, 'hTextLabel');
        switch status
            case 1
                hTextLabelLocal.String = event.Timestamp + ": " + event.Status + ...
                    ", Resolution: " + event.Resolution + ", Frame rate: " + event.FrameRate;
            case 2
                hTextLabelLocal.String = vidDevice.FramesAvailable + " frames acquired";
        end
        hImageLocal.CData = event.Data;
    end

    function togglePreview(src, ~)
        % togglePreview: Starts or stops the live preview.
        %   Toggles between preview and stopped states, updating button label.
        switch status
            case 0
                preview(vidDevice, hImage);
                status = 1;
                src.String = "Stop Preview";
            case 1
                closepreview(vidDevice);
                status = 0;
                src.String = "Start Preview";
        end
    end

    function [imageStack, timestamp, exposureTimeData, frameRate, numFrames] = collectData()
        % collectData: Collects data from camera and saves metadata to disk.
        %   Stops preview, starts acquisition, waits for frames, saves metadata.
        closepreview(vidDevice);
        status = 0;
        hTextLabelLocal = getappdata(hImage, 'hTextLabel');

        start(vidDevice);
        status = 2;
        % Wait for image capture
        while vidDevice.FramesAvailable < FRAMES_PER_TRIGGER
            hTextLabelLocal.String = vidDevice.FramesAvailable + "/" + FRAMES_PER_TRIGGER + " frames acquired";
            drawnow limitrate nocallbacks
        end
        % Grab data from vidDevice object
        [imageStack, timestamp, metadata] = getdata(vidDevice);
        hTextLabelLocal.String = "Saving data " + outfilePrefix + "...";
        drawnow limitrate nocallbacks

        numFrames   = size(imageStack, 4);
        colorSpace  = vidDevice.ReturnedColorSpace;
        frameRate   = vidSrc.AcquisitionFrameRate;
        IspEnable   = vidSrc.IspEnable;
        roiPositionOut = vidDevice.ROIPosition;

        % Preallocate metadata arrays
        frameID          = zeros(numFrames, 1);
        exposureTimeData = zeros(numFrames, 1);
        cameraGain       = zeros(numFrames, 1);
        blackLevel       = zeros(numFrames, 1);
        pixelFormat      = strings(numFrames, 1);
        for a = 1:numFrames
            frameID(a)          = metadata(a).ChunkData.FrameID;
            exposureTimeData(a) = metadata(a).ChunkData.ExposureTime;
            cameraGain(a)       = metadata(a).ChunkData.Gain;
            blackLevel(a)       = metadata(a).ChunkData.BlackLevel;
            pixelFormat(a)      = string(metadata(a).ChunkData.PixelFormat);
        end

        % Save all data to MATLAB file (raw images are too big)
        save(outfilePrefix + "_videoMetadata.mat", "colorSpace", "numFrames", "frameRate", ...
            "frameID", "timestamp", "exposureTimeData", "cameraGain", "blackLevel", "pixelFormat", ...
            "IspEnable", "roiPositionOut");
    end

    function saveVideo(~, ~)
        % saveVideo: Save video as MP4 (8-bit only)
        %   Collects data and writes to MP4 for easy viewing.
        [imageStack, timestamp, exposureTimeData, frameRate, numFrames] = collectData();

        v = VideoWriter(outfilePrefix + " video", "MPEG-4"); % change to "archival" for lossless compression
        v.Quality   = 98;
        v.FrameRate = outFileFPS;
        open(v);
        writeVideo(v, imageStack);
        close(v);

        close(gcf); % Close GUI to signal end of data collection
        plotAcquisitionTiming(timestamp, exposureTimeData, frameRate, numFrames)
    end

    function saveTif(~, ~)
        % saveTif: Save video as TIF stack (for 16-bit acquisition)
        %   Collects data and writes to TIF for high bit-depth output.
        [imageStack, timestamp, exposureTimeData, frameRate, numFrames] = collectData();

        t = Tiff(outfilePrefix + "_video.tif", "w");
        tagstruct.Photometric = Tiff.Photometric.RGB;
        tagstruct.Compression = Tiff.Compression.AdobeDeflate;
        if contains(class(imageStack), "uint8")
            tagstruct.BitsPerSample = 8;
        else
            tagstruct.BitsPerSample = 16;
        end
        tagstruct.SamplesPerPixel      = 3;
        tagstruct.SampleFormat         = Tiff.SampleFormat.UInt;
        tagstruct.ImageLength          = imHeight;
        tagstruct.ImageWidth           = imWidth;
        tagstruct.PlanarConfiguration  = Tiff.PlanarConfiguration.Chunky;
        for a = 1:numFrames
            if a > 1
                writeDirectory(t);
            end
            setTag(t, tagstruct);
            write(t, imageStack(:, :, :, a));
        end
        close(t);

        close(gcf); % Close GUI to signal end of data collection
        plotAcquisitionTiming(timestamp, exposureTimeData, frameRate, numFrames)
    end

    function plotAcquisitionTiming(timestamp, exposureTimeData, frameRate, numFrames)
        % plotAcquisitionTiming: Plot timing interval between frames.
        %   Plots the interval between frames and overlays expected timing.
        figure;
        plot(diff(timestamp) * 1E3, '.'); hold on;   % convert s to ms
        plot([1 numFrames-1], exposureTimeData(1) * 1E-3 * [1 1], 'r');   % μs to ms
        plot([1 numFrames-1], 1E3 / frameRate * [1 1], 'r--');   % s to ms
        title("Frame rate: " + frameRate + " fps, exposure time: " + num2str(exposureTimeData(1) * 1E-3) + " ms");
        xlabel("Frame index");
        ylabel("Interval between exposures (ms)");
        legend('Interval from timestamp','Ideal interval','Avg interval from timestamps','location','best')
    end
end