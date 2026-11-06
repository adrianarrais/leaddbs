function [cfile, map_list, pathway_list] = ea_unifiedmapping_mergeSubmarine(obj)
% Build the template reference for the personalised submarine atlas and
% store it where the multi-pathway code expects merged pathways
% (LeadGroup/UnifiedMappingExplorer/<connectome>/merged_pathways.mat).
% The reference only defines fiber indices and drawing coordinates; the
% E-field is sampled on each patient's native tracts
% (see ea_get_E_field_along_fibers).

[ftr, map_list, pathway_list] = ea_unifiedmapping_loadSubmarine('');

filepath = fileparts(obj.leadgroup);
ea_mkdir([filepath, filesep, 'UnifiedMappingExplorer', filesep, obj.calcsettings.fibfilt_connectome]);
cfile = [filepath, filesep, 'UnifiedMappingExplorer', filesep, obj.calcsettings.fibfilt_connectome, filesep, 'merged_pathways.mat'];
save(cfile, '-struct', 'ftr');
