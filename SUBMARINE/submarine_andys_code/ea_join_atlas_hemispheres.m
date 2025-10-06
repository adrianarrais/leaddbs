function joint_bundles = ea_join_atlas_hemispheres(atlas_base_dir)

% Get list of left and right hemispheres bundles files
rh_bundles=dir(fullfile(atlas_base_dir,'rh','*.mat'));
lh_bundles=dir(fullfile(atlas_base_dir,'lh','*.mat'));

% Initialize bundles struct
joint_bundles = [];

% Merge right side bundles
for rh = 1:length(rh_bundles)

    % Access Right Hemisphere bundles
    bundle_info_file = rh_bundles(rh);
    
    % Join all right hemisphere bundles´fibers
    joint_bundles = add_bundle(joint_bundles, bundle_info_file);

end

% Merge left side bundles
for lh = 1:length(lh_bundles)
    % Access Left Hemisphere bundles
    bundle_info_file = lh_bundles(lh);
    
    % Join left side to right side fibers
    joint_bundles = add_bundle(joint_bundles, bundle_info_file);

end
end

function joint_bundles = add_bundle(joint_bundles, bundle_to_add)
% Skip hidden/macOS metadata files
if bundle_to_add.name(1) ~= '.'

    % Load struct of bundle to merge
    bundle_to_add = load(fullfile(bundle_to_add.folder, bundle_to_add.name));
    
    % If first bundle, use as base
    if isempty(joint_bundles)
        joint_bundles = bundle_to_add;
    else
        % Compute offset: number of fibers already accumulated
        fib_cnt = length(joint_bundles.idx);

        % Update fibers numering in joint matrix
        bundle_to_add.fibers(:,4) = bundle_to_add.fibers(:,4) + fib_cnt;

        % Concatenate new fibers and idx onto the joint bundle
        joint_bundles.fibers = [joint_bundles.fibers; bundle_to_add.fibers];
        joint_bundles.idx = [joint_bundles.idx; bundle_to_add.idx];
    end

end
end