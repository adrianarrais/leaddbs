function flag = isBIDSFileName(filePath)
% Check if file name is BIDS-like
%
% regexp will match:
%     sub-XX_key1-value1_key2-value2.[ext]
%     sub-XX_key1-value1_key2-value2_[modality].nii
%     sub-XX_key1-value1_key2-value2_[modality].nii.gz

[~, fileName, fileExt] = fileparts(filePath);
fullFileName = [fileName, fileExt];

% Match BIDS-style filenames: 'sub-<id>' + ≥1 '_key-value' pair + optional '_suffix' tokens, ending with extension(s) (e.g. .nii, .nii.gz).
% Suffixes (e.g. '_dwi_b0') are parsed as separate tokens; underscores split tokens, hyphens define key-value pairs.
pattern = '^sub-[^\W_]+(_[^\W_]+-[^\W_]+){1,}(_[^\W_]+)*(\.[^\W_]+){1,}$';

if isempty(regexp(fullFileName, pattern, 'once'))
    flag = false;
else
    flag = true;
end
