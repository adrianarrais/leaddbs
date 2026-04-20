function ea_exportb0(options)

% Add here function to detect b0 automatically
b0threshold = 200;

disp('Export b0...');
bvals=load([options.root,options.patientname,filesep,options.prefs.bval]);
idx=find(bvals<b0threshold);

if isempty(idx)
    matlab.desktop.editor.openAndGoToLine(which('ea_exportb0'), 3);
    error(sprintf(['Exporting b0 image failed: b0 threshold is too small!\n' ...
           'Please check your dti.bval and _temporarily_ set ''b0threshold''', ...
           ' in function ''ea_exportb0'' to a proper higher value.']));
end

cnt=1;

if size(idx,1)<size(idx,2)
    idx=idx';
end
for fi=idx'
   fis{cnt}=[options.root,options.patientname,filesep,options.prefs.dti,',',num2str(fi)];
   cnt=cnt+1;
end

% Determine output directory (handle BIDS paths with subdirectories)
[~, b0Name] = fileparts(options.prefs.b0);
if contains(options.prefs.b0, filesep)
    % BIDS: path includes subdirectory (e.g., 'preprocessing/dwi/sub-..._b0.nii')
    outdir = fileparts(fullfile(options.root, options.patientname, options.prefs.b0));
else
    % Classic: just filename
    outdir = fullfile(options.root, options.patientname);
end

if length(fis)==1
    expr='i1';

    matlabbatch{1}.spm.util.imcalc.input = fis';
    matlabbatch{1}.spm.util.imcalc.output = [b0Name, '.nii'];
    matlabbatch{1}.spm.util.imcalc.outdir = {outdir};
    matlabbatch{1}.spm.util.imcalc.expression = expr;
    matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
    matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
    matlabbatch{1}.spm.util.imcalc.options.mask = 0;
    matlabbatch{1}.spm.util.imcalc.options.interp = 1;
    matlabbatch{1}.spm.util.imcalc.options.dtype = 4;
    spm_jobman('run',{matlabbatch}); clear matlabbatch
else
    expr='mean(X)';

    matlabbatch{1}.spm.util.imcalc.input = fis';
    matlabbatch{1}.spm.util.imcalc.output = [b0Name, '.nii'];
    matlabbatch{1}.spm.util.imcalc.outdir = {outdir};
    matlabbatch{1}.spm.util.imcalc.expression = expr;
    matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
    matlabbatch{1}.spm.util.imcalc.options.dmtx = 1;
    matlabbatch{1}.spm.util.imcalc.options.mask = 0;
    matlabbatch{1}.spm.util.imcalc.options.interp = 1;
    matlabbatch{1}.spm.util.imcalc.options.dtype = 4;
    spm_jobman('run',{matlabbatch}); clear matlabbatch
end


