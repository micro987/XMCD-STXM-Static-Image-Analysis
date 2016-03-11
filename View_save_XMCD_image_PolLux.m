% This script will read two .hdf5 images of opposite helicities generated
% by the STXM contorl software. Matlab R2006a or newer required (bug tested
% in R2015a).
% 
% The script, after loading the images, will save each helicity and the
% calculated XMCD image in 8-bit .tiff format in a folder named "Analyzed",
% which will be created in the same folder as the one in which the image 
% will be loaded from.
%
% The script also has implemented an automatic drift correction algorithm,
% which calculates the cross correlation between the two images (after
% passing through a prewitt edge filter). This gives the user a suggestion
% on which drift correction they should use (results may vary a lot!)
%
% For bugs/improvements, please contact S. Finizio (simone.finizio@psi.ch)
% Feel free to edit/improve the script as it best fits you
%
% VERSION 1.0 / 11.03.2016
%

close all
clear all
clc

%% USER INPUT

% Here start editing

% Location of the image to load
experimentPath = 'Z:\Data1\'; % Here insert the path to the experimental folder
date = '2016-02-01'; % Here insert the date of the image (in yyyy-mm-dd format)
firstImageNumber = '045'; % Here insert the number of the image (3 digits)
secondImageNumber = '046'; % Here insert the number of the image (3 digits)
entryNumber = 'entry1'; % In case of regional scans, here insert the entry number

% Detector to use
detector = 2; % 1 = "Analog 0"; 2 = "Counter 0"; 3 = "PHC"

% Matrix enlargement (uses interpolation between points, allows for
% effective sub-pixel drift corrections

magnification = 1; % Magnification factor for the images

% Drift correction
driftX = 0;
driftY = 0;
suggestDrift = 0; % Set to 0 if you do not want the computer to suggest you a value for the drift correction

% User choices
saveImage = 1; % Set to 0 if you simply want to see the image without saving it (will re-scale the image between 0 and 1)
showImage = 1; % Set to 0 if you don't want to see the image (just saving it)
autoContrast = 1; % Set to 1 if you want the computer to automatically adjust the contrast for you

% Here end editing (leave the rest of the code as-is)

%% INPUT CONTROL
% Here we control that the input is correct

firstImagePathComplete = strcat(experimentPath,date,'\Sample_Image_',date,'_',firstImageNumber,'.hdf5'); % Generating the final path to the image
secondImagePathComplete = strcat(experimentPath,date,'\Sample_Image_',date,'_',secondImageNumber,'.hdf5'); % Generating the final path to the image

% Checks if both files are there
if exist(firstImagePathComplete,'file') == 0 
    error(strcat('The image ',firstImagePathComplete,' does NOT exist. Did you synchronize?'));
end
if exist(secondImagePathComplete,'file') == 0
    error(strcat('The image ',secondImagePathComplete,' does NOT exist. Did you synchronize?'));
end

% Here we get the version of Matlab (the command changes between versions)
currVersion = version('-release');

if str2double(currVersion(1:4)) >= 2009
    command = 'h5';
else
    command = 'hdf5';
end

% Checks that the helicities are correctly selected
% First we try with the orbit bumps

dataset = strcat('/',entryNumber,'/collection/ring_y_asym/value'); % This looks at the asymmetry of the y position of the beam
firstHelicity = eval(strcat(command,'read(firstImagePathComplete,dataset)'));
secondHelicity = eval(strcat(command,'read(secondImagePathComplete,dataset)'));

% Here we look at which image has the positive/negative helicity
if firstHelicity > secondHelicity
    xmcdOrder = [1, -1];
elseif secondHelicity > firstHelicity
    xmcdOrder = [-1, 1];
else % if both helicities are the same
    error('Both helicities are the same');
end

% Here we look if one of the two images has linear light
if firstHelicity == 0 | secondHelicity == 0
    fprintf('Warning: One of the two images was done at linear polarization\n');
end

if saveImage == 0 & showImage == 0
    fprintf('Warning: The image will neither be shown nor be saved\n');
end

%% READ IMAGE

% Here we define the dataset
for i=1:1 % Horrible trick to make the break function work in the switch
    switch detector
        case 1
            detectorPath = '/analog0/';
            break;
        case 2
            detectorPath = '/counter0/';
            break;
        case 3
            detectorPath = '/PHC/';
            break;
        otherwise
            error('Not a suitable detector selected');
    end
end

dataset = strcat('/',entryNumber,detectorPath,'data');

try % Checks that everything is working fine
    temp = eval(strcat(command,'info(firstImagePathComplete,dataset)')); 
    temp = eval(strcat(command,'info(secondImagePathComplete,dataset)')); 
catch
    error('Not a suitable detector selected');
end

clear temp

% Reads the images
I_1 = eval(strcat(command,'read(firstImagePathComplete,dataset)'));
I_2 = eval(strcat(command,'read(secondImagePathComplete,dataset)'));

%% CALCULATE XMCD

% Enlargement of images (if needed -- uses CUBIC interpolation)
if magnification >= 2
    I_1 = interp2(I_1,floor(magnification),'cubic'); 
    I_2 = interp2(I_2,floor(magnification),'cubic');
end

% Automatic drift correction - suggestion of values
if suggestDrift
    if magnification >= 2
        fprintf('Warning: Suggested drift can be erroneous (set magnification to 1 if better results are wished)\n');
    end
    edge_I_1 = edge(I_1,'canny');
    edge_I_2 = edge(I_2,'canny');
    crossCorr = xcorr2(double(edge_I_1),double(edge_I_2));
    [suggestedY,suggestedX] = find(crossCorr == max(max(crossCorr)));
    
    fprintf('Suggested drift >>>> x: %d | y: %d\n',suggestedX-floor(size(edge_I_1,2)),-(suggestedY-floor(size(edge_I_1,1))));
    clear edge_I_1 edge_I_2 crossCorr suggestedX suggestedY
end

% Drift correction (corrects the drift of the SECOND image)
I_2 = circshift(I_2,[-driftY,driftX]);

% Calculation of XMCD image
I_XMCD = (I_1*xmcdOrder(1)+I_2*xmcdOrder(2))./(I_1+I_2); % xmcd = difference/sum

%% SHOW AND SAVE IMAGE

% Contrast correction
I_1 = double(I_1);
I_2 = double(I_2);
% I_XMCD is already in double format from the division

if autoContrast & showImage
    I_1 = I_1-min(min(I_1));
    I_1 = I_1/max(max(I_1));
    I_2 = I_2-min(min(I_2));
    I_2 = I_2/max(max(I_2));
    I_XMCD = I_XMCD-min(min(I_XMCD));
    I_XMCD = I_XMCD/max(max(I_XMCD));
end

if showImage
    figure(1)
    imshow(I_1);
    figure(2)
    imshow(I_2);
    figure(3)
    imshow(I_XMCD);
end

if saveImage
    savePath = strcat(experimentPath,date,'\Analysed\');
    % Creates the save folder if it does not exist
    if ~exist(savePath,'dir')
        mkdir(savePath);
        fprintf('Warning: Save folder did not exist - it was now created for you\n');
    end
    % Normalization of the image between 0 and 1

    I_XMCD = I_XMCD-min(min(I_XMCD));
    I_XMCD = I_XMCD/max(max(I_XMCD));
    % Saving the image
    imwrite(I_XMCD,strcat(savePath,'XMCD_Image_',date,'_',firstImageNumber,'.tif'));
end


% end
