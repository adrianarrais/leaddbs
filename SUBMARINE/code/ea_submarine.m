clear

% Patients folder directory
ptdir = '/Users/amygdala/Documents/SUBMARINE/exampledataset/derivatives/leaddbs/sub-PU';

% the following three paths should be generically created once Maike's
% adaptation of lead connectome is done:
% Diffusion Weighted Image 
dwi='/Users/amygdala/Documents/SUBMARINE/exampledataset/rawdata/sub-PU/ses-preop/dwi/sub-PU_ses-preop_acq-iso_dwi.nii';
synthdwiout='/Users/amygdala/Documents/SUBMARINE/exampledataset/rawdata/sub-PU/ses-preop/dwi/sub-PU_ses-preop_acq-iso_dwi_synth.nii.gz';

% Diffusion Specific parameters
bvec='/Users/amygdala/Documents/SUBMARINE/exampledataset/rawdata/sub-PU/ses-preop/dwi/sub-PU_ses-preop_acq-iso_dwi.bvec';
bval='/Users/amygdala/Documents/SUBMARINE/exampledataset/rawdata/sub-PU/ses-preop/dwi/sub-PU_ses-preop_acq-iso_dwi.bval';




%% Step 2: concatenate all fibers into a joint struct

atlasbase=fullfile(ea_space([],'atlases'),'FOCUS Atlas WM');
load(fullfile(atlasbase,'atlas_index.mat'))

rhfibs=dir(fullfile(atlasbase,'rh','*.mat'));
lhfibs=dir(fullfile(atlasbase,'lh','*.mat'));
for rh=1:length(rhfibs)
    if ~strcmp(rhfibs(rh).name(1),'.') % ignore macos backup hidden files starting with a .
    thisbundle=load(fullfile(atlasbase,'rh',rhfibs(rh).name));
    if ~exist('jointbundle','var')
        jointbundle=thisbundle;
    else
        thisbundle.fibers(:,4)=thisbundle.fibers(:,4)+fibcnt;
        jointbundle.fibers=[jointbundle.fibers;thisbundle.fibers];
        jointbundle.idx=[jointbundle.idx;thisbundle.idx];
    end
    fibcnt=length(jointbundle.idx);
    end
end

for lh=1:length(lhfibs)
    if ~strcmp(lhfibs(lh).name(1),'.') % ignore macos backup hidden files starting with a .
    thisbundle=load(fullfile(atlasbase,'lh',lhfibs(lh).name));
    thisbundle.fibers(:,4)=thisbundle.fibers(:,4)+fibcnt;
    jointbundle.fibers=[jointbundle.fibers;thisbundle.fibers];
    jointbundle.idx=[jointbundle.idx;thisbundle.idx];
    fibcnt=length(jointbundle.idx);
    end
end


%% Step 3: Warp fibers from MNI into T1 (coregistration) space:

fibers=jointbundle.fibers(:,1:3)';
mnit1_template=ea_open_vol([ea_space,'t1.nii']);

% first port mm coordinates to vox coordinates in MNI T1 space:
fibers=mnit1_template.mat\[fibers;ones(1,size(fibers,2))];

% now port them to mm coordinates in native (patient) T1 space:
options=ea_getptopts(ptdir);
fibers=ea_map_coords(fibers, [ea_space,'t1.nii'], ...
            [options.subj.subjDir,filesep,'forwardTransform'], '')'; % these will be in mm again

% port to vox coordinates in native (patient) T1 space:
t1native=ea_open_vol(options.subj.preopAnat.(options.subj.AnchorModality).coreg);
fibers=t1native.mat\[fibers';ones(1,size(fibers,1))];


%% Step 4: Map from T1 to b0 (DWI) space:
options.coregmr.method='spm';
transform = ea_coregimages(options,options.subj.preopAnat.(options.subj.AnchorModality).coreg,dwi,fullfile(ea_getleadtempdir,'t12b0.nii'),[],1);
T=load(transform{1});

switch options.coregmr.method
    case 'spm'
        T=T.spmaffine;
    case 'ants'
        T=ea_antsmat2mat(T.AffineTransform_float_3_3,T.fixed);
end

fibers=T*fibers;

fibers=fibers(1:3,:)'; % fibers should now be in mm space of the DWI image.

% put them back to the jointbundle struct:
jointbundle.fibers(:,1:3)=fibers;


%% Step 5: Run Marco's Code to create DWI phantoms from these:
% first convert fibers to cell format since Marco's code wants them like that:   
fibcell=ea_fibmat2cell(jointbundle);

bvec=load(bvec);
bval=load(bval);

ea_dwisim(fibcell,dwi,synthdwiout,bvec,bval);


%% Step 6: Create a nonlinear ANTs refinement warp 
