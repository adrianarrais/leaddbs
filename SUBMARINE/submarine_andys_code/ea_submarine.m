
% Patients folder directory
ptdir = '/Users/amygdala/Documents/SUBMARINE/exampledataset/derivatives/leaddbs/sub-PU';

% the following three paths should be generically created once Maike's
% adaptation of lead connectome is done:
% Diffusion Weighted Image 
dwi='/Users/amygdala/Documents/SUBMARINE/exampledataset/rawdata/sub-PU/ses-preop/dwi/sub-PU_ses-preop_acq-iso_dwi.nii';
synthdwiout='/Users/amygdala/Documents/SUBMARINE/exampledataset/rawdata/sub-PU/ses-preop/dwi/sub-PU_ses-preop_acq-iso_dwi_synth.nii.gz';

% Diffusion Specific parameters
% bvec='/Users/amygdala/Documents/SUBMARINE/exampledataset/rawdata/sub-PU/ses-preop/dwi/sub-PU_ses-preop_acq-iso_dwi.bvec';
% bval='/Users/amygdala/Documents/SUBMARINE/exampledataset/rawdata/sub-PU/ses-preop/dwi/sub-PU_ses-preop_acq-iso_dwi.bval';

%% Step 1: Concatenate all fibers into a joint struct

atlasbase=fullfile(ptdir,'atlases','FOCUS Atlas WM');
atlas_index_struct = load(fullfile(atlasbase,'atlas_index.mat'));

jointbundle = ea_join_atlas_hemispheres(atlasbase);

%% Step 2: Warp fibers into T1 (coregistration) space:

% Get only xyz corrdinates
fibers=jointbundle.fibers(:,1:3)'; % 3xN mm

% Get MNI space t1 template
mnit1_template=ea_load_nii([ea_space,'t1.nii']);

% Transform mm->vox coordinates in MNI T1 space
fibers=mnit1_template.mat\[fibers;ones(1,size(fibers,2))]; % 4xN vox

% Now port them to native (patient) T1 space - to mm coordinates:
% Nx3 mm native fibers output
options=ea_getptopts(ptdir);
fibers=ea_map_coords(fibers, ...                                        % 4xN, MNI vox
    [ea_space,'t1.nii'], ...                                            % MNI T1 template mm
            [options.subj.subjDir,filesep,'forwardTransform'], ...      % Normalization Transform
            '')';                                                       % interpolation ('' = default)

% Transform mm->vox coordinates in native (patient) T1 space:
V=ea_open_vol(options.subj.preopAnat.(options.subj.AnchorModality).coreg); % Open the patient’s coreg pre-op T1 header to get its affine
fibers=V.mat\[fibers';ones(1,size(fibers,1))]; % 4xN vox

%% Step 3: Map from T1 to b0 (DWI) space:

% Add coregistration to options
options.coregmr.method='spm';

% Run coregistration: align the patient’s pre-op T1 (coregistered) with DWI
% Transform written locally - maps T1 coordinates into DWI space
transform = ea_coregimages(options, ...                             
    options.subj.preopAnat.(options.subj.AnchorModality).coreg, ... % source: patient T1 (coreg)
    dwi, ...                                                        % target: DWI 
    fullfile(ea_getleadtempdir,'t12b0.nii'), ...                    % output filename for resliced T1
    [], ...
    1);                                                             % write transform only (don’t overwrite)

% Load the T1->DWI transform 
T=load(transform{1});

% Get the affine matrix
switch options.coregmr.method
    case 'spm'
        T=T.spmaffine;
    case 'ants'
        T=ea_antsmat2mat(T.AffineTransform_float_3_3,T.fixed);
end

% 4xN vox (input for transforms should always be in vox)
fibers=T*fibers; %4xN mm output

fibers=fibers(1:3,:)'; % fibers should now be in mm space of the DWI image. % 

% Update the jointbundle struct:
jointbundle.fibers(:,1:3)=fibers;


%% Step 4: Run Marco's Code to create DWI phantoms from these:
% first convert fibers to cell format since Marco's code wants them like that:   
fibcell=ea_fibmat2cell(jointbundle);

% Diffusion Specific parameters
bvec='/Users/amygdala/Documents/SUBMARINE/exampledataset/rawdata/sub-PU/ses-preop/dwi/sub-PU_ses-preop_acq-iso_dwi.bvec';
bval='/Users/amygdala/Documents/SUBMARINE/exampledataset/rawdata/sub-PU/ses-preop/dwi/sub-PU_ses-preop_acq-iso_dwi.bval';

bvec=load(bvec);
bval=load(bval);
ea_dwisim(fibcell,dwi,synthdwiout,bvec,bval);


%% Step 5: Create a nonlinear ANTs refinement warp 
