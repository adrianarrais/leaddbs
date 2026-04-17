function options = ea_ensure_fa_and_fa2anat(options)
% Ensure FA map exists and FA coregistered to anatomical is in coregistration/anat.
%
% When running Lead Connectome (structural), this helper:
%  1. Creates FA from DWI if not present (preprocessing/dwi/*_fa.nii).
%  2. Coregisters FA to the anatomical (T1) and writes the result to
%     coregistration/anat (BIDS) or subject root fa2anat.nii (legacy).
%
% Called from ea_autocoord when any structural connectome option is enabled.

directory = [options.root, options.patientname, filesep];

% Need DWI data (options.prefs.dti set by ea_prepare_dti_bids or legacy)
if ~isfield(options.prefs, 'dti') || isempty(options.prefs.dti)
    return;
end
dtiPath = fullfile(directory, options.prefs.dti);
if ~isfile(dtiPath)
    return;
end

% 1) Create FA if missing
faPath = fullfile(directory, options.prefs.fa);
if ~isfile(faPath)
    fprintf('\nCreating FA map from DWI...\n');
    try
        ea_isolate_fa(options);
        fprintf('FA saved: %s\n', options.prefs.fa);
    catch ME
        warning('ea_ensure_fa_and_fa2anat: Could not create FA: %s', ME.message);
        return;
    end
end

% 2) FA-in-anat: output path
isBIDS = contains(directory, 'derivatives') || contains(directory, 'leaddbs');
if isBIDS
    coregAnatDir = fullfile(directory, 'coregistration', 'anat');
    if ~isfolder(coregAnatDir)
        mkdir(coregAnatDir);
    end
    % BIDS-style name: sub-XXX_space-anchorNative_dwi_fa.nii
    fa2anatName = [options.patientname, '_space-anchorNative_dwi_fa.nii'];
    fa2anatPath = fullfile(coregAnatDir, fa2anatName);
    fa2anatRel  = fullfile('coregistration', 'anat', fa2anatName);
else
    fa2anatPath = fullfile(directory, options.prefs.fa2anat);
    fa2anatRel  = options.prefs.fa2anat;
end

% If there is already a FA coregistration to anat
if isfile(fa2anatPath)
    if isBIDS
        options.prefs.fa2anat = fa2anatRel;
    end
    return;
end

% Anatomical reference
anatPath = fullfile(directory, options.prefs.prenii_unnormalized);
if ~isfile(anatPath)
    % Try preprocessing/anat or coregistration/anat
    for subdir = {'preprocessing/anat', 'coregistration/anat'}
        d = dir(fullfile(directory, subdir{1}, '*T1w.nii'));
        if isempty(d), d = dir(fullfile(directory, subdir{1}, '*T2w.nii')); end
        if ~isempty(d)
            anatPath = fullfile(d(1).folder, d(1).name);
            break;
        end
    end
end
if ~isfile(anatPath)
    warning('ea_ensure_fa_and_fa2anat: Anatomical reference not found. Skipping FA->anat coregistration.');
    return;
end

% ── 5. Find the B0->T1 forward transform ─────────────────────────────────
transform = find_b0_t1_forward_transform(directory, options.coregmr.method);
if isempty(transform)
    warning(['ea_ensure_fa: B0->T1 forward transform not found. ', ...
             'Ensure ea_ensure_b0_coreg ran successfully.']);
    return;
end
fprintf('ea_ensure_fa: Using B0->T1 transform: %s\n', transform);


 % ── 6. Apply transform to FA ─────────────────────────────────────────────
fprintf('ea_ensure_fa: Applying B0->T1 transform to FA...\n');
try
    ea_apply_coregistration(anatPath, faPath, fa2anatPath, transform);
    fprintf('ea_ensure_fa: FA in T1 space saved: %s\n', fa2anatPath);
catch ME
    warning('ea_ensure_fa: Failed to apply transform to FA: %s', ME.message);
end

function hit = find_b0_t1_forward_transform(directory, methodHint)
% Search common locations for a B0->T1 forward transform file.
% Returns the full path of the best candidate, or '' if none found.
%
% "Forward" means B0/DWI -> T1, not the inverse (T1 -> B0).

if nargin < 2 || isempty(methodHint), methodHint = ''; end
% Extract the first word of the method string (e.g. 'SPM' from 'SPM (Friston 2007)')
methodHint = lower(regexp(methodHint, '^[^\s\(]+', 'match', 'once'));

searchDir = fullfile(directory, 'coregistration', 'transformations');

exts = {'*.mat', '*.h5', '*.txt'};
cands = {};

if isfolder(searchDir)
    for e = 1:numel(exts)
        d = dir(fullfile(searchDir,'**',exts{e}));
        for k = 1:numel(d)
            cands{end+1} = fullfile(d(k).folder, d(k).name);
        end
    end
end

if isempty(cands), hit = ''; return; end

bestScore = -Inf;
hit = '';
for i = 1:numel(cands)
    [~, name, ext] = fileparts(cands{i});
    fname = lower([name, ext]);

    % Must reference both B0/DWI and T1/anat
    hasB0   = contains(fname, 'b0') || contains(fname, 'dwi');
    hasAnat = contains(fname, 't1') || contains(fname, 'anat');
    if ~hasB0 || ~hasAnat, continue; end

    % Forward direction: file should start with the B0/DWI side, not T1
    % (inverse would be e.g. "anat2b0_spm.mat" or "t12b0_spm.mat")
    isInverse = startsWith(fname, 'anat') || startsWith(fname, 't1');
    if isInverse, continue; end

    score = 4; % baseline for a plausible B0->T1 forward candidate

    if ~isempty(methodHint) && contains(fname, methodHint)
        score = score + 1;
    end

    % Validate .mat: must contain at least one 4x4 numeric matrix
    if strcmp(ext, '.mat')
        try
            S = load(cands{i});
            has4x4 = any(structfun(@(v) isnumeric(v) && isequal(size(v), [4 4]), S));
            if has4x4
                score = score + 1;
            else
                score = score - 2;
            end
        catch
            score = score - 3;
        end
    end

    if score > bestScore
        bestScore = score;
        hit = cands{i};
    end
end

if bestScore < 4
    hit = '';
end
