clc;
clear;
close all;

% Connected Component Labeling and Size Filtering
% ------------------------------------------------------------
% Manual MATLAB implementation for Digital Image Processing.
% Direct built-in connected-component labeling and size-filtering
% functions are intentionally not used.
%
% Run this script from MATLAB. It resolves project paths automatically,
% reads data/input_image.png, and writes generated images to results/.

scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
inputPath = fullfile(projectRoot, 'data', 'input_image.png');
resultsDir = fullfile(projectRoot, 'results');

if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

% Parameters used for the coursework image.
binaryThreshold = 240;
minIntensity = 0;
maxIntensity = 240;
minimumComponentSize = 15000;

if ~exist(inputPath, 'file')
    error('Input image not found: %s', inputPath);
end

img = imread(inputPath);

% ------------------------------------------------------------
% Manual grayscale conversion
% ------------------------------------------------------------
if ndims(img) == 3
    grayImg = uint8(0.2989 * double(img(:,:,1)) + ...
                    0.5870 * double(img(:,:,2)) + ...
                    0.1140 * double(img(:,:,3)));
else
    grayImg = img;
end

[rows, cols] = size(grayImg);

% ------------------------------------------------------------
% Manual binary thresholding
% Objects are darker than the light background.
% ------------------------------------------------------------
binaryImg = zeros(rows, cols, 'uint8');

for r = 1:rows
    for c = 1:cols
        if grayImg(r,c) < binaryThreshold
            binaryImg(r,c) = 1;
        end
    end
end

% ------------------------------------------------------------
% Task 1: 4-connectivity labeling
% ------------------------------------------------------------
[labels4, numComponents4, sizes4] = componentLabeling(binaryImg, 4);

% ------------------------------------------------------------
% Task 2: 8-connectivity labeling
% ------------------------------------------------------------
[labels8, numComponents8, sizes8] = componentLabeling(binaryImg, 8);

% ------------------------------------------------------------
% Task 3: intensity-range labeling
% ------------------------------------------------------------
[labelsRange, numComponentsRange, sizesRange, rangeMask] = ...
    componentLabelingRange(grayImg, minIntensity, maxIntensity, 4);

% ------------------------------------------------------------
% Task 4: component-size filtering
% ------------------------------------------------------------
filteredBinary = sizeFilter(binaryImg, minimumComponentSize, 4);
[~, numFiltered, sizesFiltered] = componentLabeling(filteredBinary, 4);

% ------------------------------------------------------------
% Console summary
% ------------------------------------------------------------
fprintf('\n========================================\n');
fprintf('Connected Component Analysis Results\n');
fprintf('========================================\n');
fprintf('Binary threshold: %d\n', binaryThreshold);
fprintf('Task 1 - 4-connectivity: %d components\n', numComponents4);
fprintf('Task 2 - 8-connectivity: %d components\n', numComponents8);
fprintf('Task 3 - range [%d, %d]: %d components\n', ...
        minIntensity, maxIntensity, numComponentsRange);
fprintf('Task 4 - min size %d: %d components remain\n', ...
        minimumComponentSize, numFiltered);

fprintf('\n4-connectivity component sizes:\n');
disp(sizes4');

fprintf('8-connectivity component sizes:\n');
disp(sizes8');

fprintf('Range-labeling component sizes:\n');
disp(sizesRange');

fprintf('Remaining component sizes after filtering:\n');
disp(sizesFiltered');

% ------------------------------------------------------------
% Visualize results
% ------------------------------------------------------------
fig = figure('Name', 'Connected Component Analysis', ...
             'NumberTitle', 'off');

subplot(2,3,1);
imshow(grayImg, []);
title('Original Grayscale Image');

subplot(2,3,2);
imshow(binaryImg, []);
title(sprintf('Binary Image, T = %d', binaryThreshold));

subplot(2,3,3);
imagesc(labels4);
axis image off;
colorbar;
title(sprintf('4-Connectivity, N = %d', numComponents4));

subplot(2,3,4);
imagesc(labels8);
axis image off;
colorbar;
title(sprintf('8-Connectivity, N = %d', numComponents8));

subplot(2,3,5);
imagesc(labelsRange);
axis image off;
colorbar;
title(sprintf('Range Labeling, N = %d', numComponentsRange));

subplot(2,3,6);
imshow(filteredBinary, []);
title(sprintf('Size Filtered, N = %d', numFiltered));

% ------------------------------------------------------------
% Save outputs
% ------------------------------------------------------------
imwrite(grayImg, fullfile(resultsDir, 'input_grayscale.png'));
imwrite(binaryImg * 255, fullfile(resultsDir, 'binary_image.png'));
imwrite(rangeMask * 255, fullfile(resultsDir, 'range_mask.png'));
imwrite(uint8(normalizeLabels(labels4)), ...
        fullfile(resultsDir, 'labels_4_connectivity.png'));
imwrite(uint8(normalizeLabels(labels8)), ...
        fullfile(resultsDir, 'labels_8_connectivity.png'));
imwrite(uint8(normalizeLabels(labelsRange)), ...
        fullfile(resultsDir, 'labels_intensity_range.png'));
imwrite(filteredBinary * 255, ...
        fullfile(resultsDir, 'filtered_binary.png'));

saveas(fig, fullfile(resultsDir, 'assignment_results.png'));

fprintf('\nOutput images saved to:\n%s\n', resultsDir);

% ============================================================
% Local functions
% ============================================================

function [labels, numComponents, componentSizes] = componentLabeling(binaryImg, connectivity)
    if connectivity ~= 4 && connectivity ~= 8
        error('Connectivity must be 4 or 8.');
    end

    [rows, cols] = size(binaryImg);
    labels = zeros(rows, cols);
    componentSizes = [];
    currentLabel = 0;

    for r = 1:rows
        for c = 1:cols
            if binaryImg(r,c) == 1 && labels(r,c) == 0
                currentLabel = currentLabel + 1;
                [labels, componentSize] = floodFill( ...
                    binaryImg, labels, r, c, currentLabel, connectivity);
                componentSizes(currentLabel) = componentSize; %#ok<AGROW>
            end
        end
    end

    numComponents = currentLabel;
    componentSizes = componentSizes(:);
end

function [labels, componentSize] = floodFill( ...
    binaryImg, labels, startRow, startCol, labelValue, connectivity)

    [rows, cols] = size(binaryImg);

    % Each pixel can be queued at most once.
    queueRows = zeros(rows * cols, 1);
    queueCols = zeros(rows * cols, 1);

    front = 1;
    rear = 1;

    queueRows(rear) = startRow;
    queueCols(rear) = startCol;
    labels(startRow, startCol) = labelValue;

    componentSize = 0;

    while front <= rear
        r = queueRows(front);
        c = queueCols(front);
        front = front + 1;
        componentSize = componentSize + 1;

        neighbors = getNeighbors(r, c, connectivity);

        for k = 1:size(neighbors, 1)
            nr = neighbors(k, 1);
            nc = neighbors(k, 2);

            if nr >= 1 && nr <= rows && nc >= 1 && nc <= cols
                if binaryImg(nr,nc) == 1 && labels(nr,nc) == 0
                    rear = rear + 1;
                    queueRows(rear) = nr;
                    queueCols(rear) = nc;
                    labels(nr,nc) = labelValue;
                end
            end
        end
    end
end

function neighbors = getNeighbors(r, c, connectivity)
    if connectivity == 4
        neighbors = [
            r-1, c;
            r+1, c;
            r, c-1;
            r, c+1
        ];
    else
        neighbors = [
            r-1, c;
            r+1, c;
            r, c-1;
            r, c+1;
            r-1, c-1;
            r-1, c+1;
            r+1, c-1;
            r+1, c+1
        ];
    end
end

function [labels, numComponents, componentSizes, rangeMask] = ...
    componentLabelingRange(img, minVal, maxVal, connectivity)

    if minVal > maxVal
        error('Minimum intensity cannot be greater than maximum intensity.');
    end

    [rows, cols] = size(img);
    rangeMask = zeros(rows, cols, 'uint8');

    for r = 1:rows
        for c = 1:cols
            if img(r,c) >= minVal && img(r,c) <= maxVal
                rangeMask(r,c) = 1;
            end
        end
    end

    [labels, numComponents, componentSizes] = ...
        componentLabeling(rangeMask, connectivity);
end

function filteredImg = sizeFilter(binaryImg, minimumSize, connectivity)
    if minimumSize < 0
        error('Minimum component size must be non-negative.');
    end

    [labels, ~, componentSizes] = componentLabeling(binaryImg, connectivity);
    [rows, cols] = size(binaryImg);

    filteredImg = zeros(rows, cols, 'uint8');

    for r = 1:rows
        for c = 1:cols
            currentLabel = labels(r,c);

            if currentLabel > 0 && componentSizes(currentLabel) >= minimumSize
                filteredImg(r,c) = 1;
            end
        end
    end
end

function out = normalizeLabels(labels)
    maxLabel = max(labels(:));

    if maxLabel == 0
        out = zeros(size(labels));
        return;
    end

    out = (double(labels) / double(maxLabel)) * 255;
end
