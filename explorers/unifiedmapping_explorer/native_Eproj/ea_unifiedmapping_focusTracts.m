function keep = ea_unifiedmapping_focusTracts()
% Tract base names (without _left/_right) of the FOCUS connectome. Used to
% restrict the personalised submarine atlas to the FOCUS pathways.

focusDir = fullfile(ea_getconnectomebase('dMRI_MultiTract'), 'FOCUS Atlas WM (08072026)');
focusFiles = dir(fullfile(focusDir, '*.mat'));
focusFiles = {focusFiles(~endsWith({focusFiles.name}, '_ADJ.mat')).name};
keep = unique(regexprep(focusFiles, '_(left|right)\.mat$', ''));

if isempty(keep)
    ea_error(['No FOCUS tracts found in ', focusDir]);
end
