function [ftr, map_list, pathway_list] = ea_unifiedmapping_loadSubmarine(pt_folder)
% Merge the submarine atlas tracts that are FOCUS pathways (see
% ea_unifiedmapping_focusTracts) into one connectome.
% The tract order is always taken from the template atlas, so the template
% reference and every patient's personalised tracts share fiber indices.
%   pt_folder = ''  -> template atlas (reference for fiber indexing and drawing)
%   pt_folder given -> <pt_folder>/atlases/submarine atlas - Back in T1 Native
%                      (personalised tracts, already in native space, no warp)
% If personalised tracts are missing, a warning is printed and ftr is empty.

templateDir = fullfile(ea_space, 'atlases', 'submarine atlas');
nativeDir = fullfile(pt_folder, 'atlases', 'submarine atlas - Back in T1 Native');
hemis = {'rh', 'lh', 'midline'};

ftr = [];
map_list = []; % global indices of the first fibers in pathways
pathway_list = {}; % ordered list of pathways' names
if ~isempty(pt_folder) && ~isfolder(nativeDir)
    ea_cprintf('CmdWinWarnings', 'Personalised submarine atlas not found: %s\n', nativeDir);
    return
end

focusTracts = ea_unifiedmapping_focusTracts();
C = {};
C_idx = {};
glob_index = 1;

for h = 1:numel(hemis)
    tractFiles = dir(fullfile(templateDir, hemis{h}, '*.mat'));
    tractFiles = sort({tractFiles.name});
    for t = 1:numel(tractFiles)
        [~, tract] = fileparts(tractFiles{t});
        if ~ismember(tract, focusTracts)
            continue % not a FOCUS pathway
        end
        if isempty(pt_folder)
            tractFile = fullfile(templateDir, hemis{h}, tractFiles{t});
        else
            tractFile = fullfile(nativeDir, hemis{h}, [tract, '_back_t1native_', hemis{h}, '.mat']);
            if ~isfile(tractFile)
                ea_cprintf('CmdWinWarnings', 'Personalised submarine tract not found: %s\n', tractFile);
                map_list = [];
                pathway_list = {};
                return
            end
        end

        fiber_file = load(tractFile, 'fibers', 'idx');
        fiber_file.fibers(:,4) = fiber_file.fibers(:,4) + glob_index - 1;

        C{end+1} = fiber_file.fibers; %#ok<AGROW>
        C_idx{end+1} = fiber_file.idx(:); %#ok<AGROW>
        map_list(end+1) = glob_index; %#ok<AGROW>
        pathway_list{end+1} = [regexprep(tract, '_', ' '), ' ', hemis{h}]; %#ok<AGROW>

        glob_index = glob_index + numel(fiber_file.idx);
    end
end

ftr.fibers = cat(1, C{:});
ftr.idx = cat(1, C_idx{:});
ftr.ea_fibformat = '1.0';
ftr.fourindex = 1;
ftr.mirrored = 0;
