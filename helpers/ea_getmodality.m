function modality = ea_getmodality(BIDSFilePath, opts)
% Extract image modality from BIDS file path
arguments
    BIDSFilePath {mustBeText}
    opts.acq {mustBeNumericOrLogical} = true % Keep acq label by default
end

if ~iscell(BIDSFilePath)
    wasChar = 1;
    BIDSFilePath = {BIDSFilePath};
else
    wasChar = 0;
end

modality = cell(size(BIDSFilePath));

for i=1:length(BIDSFilePath)
    try
        parsedStruct = parseBIDSFilePath(BIDSFilePath{i});
        hasAcq = isfield(parsedStruct, 'acq')    && ~isempty(parsedStruct.acq);
        hasSuf = isfield(parsedStruct, 'suffix') && ~isempty(parsedStruct.suffix);

        if hasAcq && hasSuf
            modality{i} = [parsedStruct.acq '_' parsedStruct.suffix];
        elseif hasSuf
            modality{i} = parsedStruct.suffix;
        elseif hasAcq
            modality{i} = parsedStruct.acq;
        end
    catch
        % Fallback for filenames that don't strictly conform to BIDS:
        % strip all key-value entities (e.g. 'sub-XX_', 'ses-preop_',
        % 'desc-preproc_') and use whatever remains as the modality token.
        % Example: 'sub-XX_ses-preop_desc-preproc_dwi_b0' -> 'dwi_b0'
        [~, fname] = fileparts(BIDSFilePath{i});
        modality{i} = regexprep(fname, '[a-zA-Z]+-[^\W_]+_', '');
    end

    % code older version
    % if ~opts.acq || ~isempty(regexp(BIDSFilePath{i}, '_CT\.nii(.gz)?$', 'once')) % Skip plane label
    %     modality{i} = regexp(BIDSFilePath{i}, '(?<=_)([^\W_]+)(?=\.nii(\.gz)?$)', 'match', 'once');
    % else % Keep plane label
    %     modality{i} = regexp(BIDSFilePath{i}, '(?<=_acq-)((ax|sag|cor|iso)\d*_[^\W_]+)(?=\.nii(\.gz)?$)', 'match', 'once');
    % end
end

if wasChar
    modality = modality{1};
end