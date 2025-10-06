
% % Get all files in atlas folder
% fprintf('Please select the Atlas folder.');
% atlas_path = uigetdir(pwd);
% 
% % Get transform file
% clc;
% fprintf('Please select transform from MNI to native.')
% [transform_file, transform_path] = uigetfile({'*.nii.gz'},'NIfTI zipped transform file (*.nii.gz)', 'Select transform file.');
% clc;
% 
% %

%% Test to visualize dwi
% Open a dialog to select the DWI NIfTI file
[dwifile, dwipath] = uigetfile({'*.nii;*.nii.gz','NIfTI files (*.nii, *.nii.gz)'}, ...
                               'Select DWI image');
if isequal(dwifile,0)
    disp('No file selected.');
    return;
end
dwiFileFull = fullfile(dwipath, dwifile);

% Do exactly what you had before
niftiInfo = niftiinfo(dwiFileFull);
dwi = niftiread(dwiFileFull);

volumeViewer(dwi(:,:,:,1));   % 3D volume app