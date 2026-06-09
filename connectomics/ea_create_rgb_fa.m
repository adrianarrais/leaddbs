function outFile = ea_create_rgb_fa(dtiFile, bvalFile, bvecFile, outFile)
% Create a directionally encoded color (DEC / RGB) FA NIfTI image.
%
%   outFile = ea_create_rgb_fa(dtiFile)
%   outFile = ea_create_rgb_fa(dtiFile, bvalFile, bvecFile)
%   outFile = ea_create_rgb_fa(dtiFile, bvalFile, bvecFile, outFile)
%
% dtiFile  - path to 4-D DWI NIfTI (e.g. '/patient/dti.nii')
% bvalFile - b-value text file (default: same basename as dtiFile + '.bval')
% bvecFile - gradient directions file (default: same basename + '.bvec')
% outFile  - output path (default: same folder as dtiFile, 'rgb_fa.nii')
%
% The three output volumes encode the principal diffusion direction weighted
% by FA (standard DEC convention):
%   Vol 1 (R) = left-right
%   Vol 2 (G) = anterior-posterior
%   Vol 3 (B) = superior-inferior
% Values are float32 [0-1]. FSLeyes can display this as RGB with '-ot rgb'.

base = ea_stripext(dtiFile);

if nargin < 2 || isempty(bvalFile)
    bvalFile = [base, '.bval'];
end
if nargin < 3 || isempty(bvecFile)
    bvecFile = [base, '.bvec'];
end
if nargin < 4 || isempty(outFile)
    outFile = fullfile(fileparts(dtiFile),[options.patientname,'_ses-preop_rgb-fa.nii']);
end

% ---- load DWI volumes --------------------------------------------------
fprintf('ea_create_rgb_fa: loading %s\n', dtiFile);
Vdti  = spm_vol(dtiFile);
Xdti  = spm_read_vols(Vdti);

bval = load(bvalFile);
bvec = load(bvecFile);

if size(bvec, 1) ~= 3, bvec = bvec'; end
if size(bval, 1) ~= 1, bval = bval'; end

% ---- build DTIdata struct -----------------------------------------------
for i = 1:size(Xdti, 4)
    DTIdata(i).VoxelData = single(squeeze(Xdti(:,:,:,i))); %#ok<AGROW>
    DTIdata(i).Gradient  = bvec(:, i);
    DTIdata(i).Bvalue    = bval(i);
    if ~bval(i)
        DTIdata(i).Gradient = zeros(3, 1);
    end
end

% ---- run DTI calculation -----------------------------------------------
params.BackgroundThreshold          = 50;
params.WhiteMatterExtractionThreshold = 0.10;
params.textdisplay                  = true;

fprintf('ea_create_rgb_fa: fitting diffusion tensor...\n');
[~, FA, VectorF] = ea_DTI(DTIdata, params);

% ---- build RGB FA -------------------------------------------------------
% VectorF is the principal eigenvector scaled by the largest eigenvalue;
% normalise to unit length before encoding direction as colour.
mag  = sqrt(sum(VectorF .^ 2, 4));
V1   = VectorF ./ (mag + eps);          % unit principal eigenvector

% Standard DEC: |direction component| * FA, kept as float32 [0 1]
rgbFA = single(abs(V1) .* FA);   % [X Y Z 3]

% ---- write output as a normal 4D float32 NIfTI --------------------------
write_nii_float32_4d(outFile, rgbFA, Vdti(1));
stamp_rgb_vector_header(outFile);
fprintf('ea_create_rgb_fa: saved -> %s  (4D float32 RGB-FA NIfTI)\n', outFile);

% ---- reslice to match tract QC resolution -------------------------------
% 0 = nearest neighbor (binary masks/labels)
% 1 = trilinear (density/probability maps)
interp = 1;
verbose = 1;
bg = 0;
vox = [0.5, 0.5, 0.5];

ea_reslice_nii(outFile, outFile, vox, verbose, bg, interp);
stamp_rgb_vector_header(outFile);
fprintf('ea_create_rgb_fa: resliced -> %s  ([%.1f %.1f %.1f] mm)\n', ...
    outFile, vox(1), vox(2), vox(3));

% --------------------------------------------------------------------------
function write_nii_float32_4d(outFile, rgb_data, ref_vol)
% Write [H W D 3] single data as a FSL-style RGB vector NIfTI.
sz = size(rgb_data);
H = sz(1); W = sz(2); D = sz(3); T = sz(4);
mat = ref_vol.mat;
vx = sqrt(sum(mat(1:3, 1:3).^2, 1));
tr = 1;
try
    if isfield(ref_vol, 'private') && isfield(ref_vol.private, 'timing') && ...
            isfield(ref_vol.private.timing, 'tspace') && ref_vol.private.timing.tspace > 0
        tr = ref_vol.private.timing.tspace;
    end
catch
end
qfac = -1;

fid = fopen(outFile, 'w', 'l');
if fid < 0; error('ea_create_rgb_fa: cannot open %s for writing', outFile); end
oc = onCleanup(@() fclose(fid));

% NIfTI1 header (348 bytes, little-endian)
fwrite(fid, int32(348),                    'int32' );  % sizeof_hdr
fwrite(fid, zeros(1,28,'uint8'),           'uint8' );  % data_type[10] + db_name[18]
fwrite(fid, int32(0),                      'int32' );  % extents
fwrite(fid, int16(0),                      'int16' );  % session_error
fwrite(fid, uint8([0 0]),                  'uint8' );  % regular + dim_info
fwrite(fid, int16([4 H W D T 1 1 1]),      'int16' );  % dim[8]
fwrite(fid, single(zeros(1,3)),            'float32'); % intent_p1/p2/p3
fwrite(fid, int16(2003),                   'int16' );  % intent_code = NIFTI_INTENT_RGB_VECTOR
fwrite(fid, int16(16),                     'int16' );  % datatype = DT_FLOAT32
fwrite(fid, int16(32),                     'int16' );  % bitpix
fwrite(fid, int16(0),                      'int16' );  % slice_start
fwrite(fid, single([qfac vx(1) vx(2) vx(3) tr 0 0 0]), 'float32'); % pixdim[8]
fwrite(fid, single(352),                   'float32'); % vox_offset
fwrite(fid, single([1 0]),                 'float32'); % scl_slope + scl_inter
fwrite(fid, int16(0),                      'int16' );  % slice_end
fwrite(fid, uint8([0 10]),                 'uint8' );  % slice_code + xyzt_units (mm)
fwrite(fid, single([0 0 0 0]),             'float32'); % cal_max/min/slice_dur/toffset
fwrite(fid, int32([0 0]),                  'int32' );  % glmax + glmin
descrip = uint8('ea_create_rgb_fa float32 rgb-fa');
fwrite(fid, [descrip zeros(1, 80-numel(descrip), 'uint8')], 'uint8'); % descrip[80]
fwrite(fid, zeros(1,24,'uint8'),           'uint8' );  % aux_file[24]
fwrite(fid, int16([2 2]),                  'int16' );  % qform_code + sform_code
fwrite(fid, single(qform_from_mat(mat, qfac)), 'float32'); % quatern_b/c/d + qoffset_x/y/z
fwrite(fid, single(mat(1,:)),              'float32'); % srow_x[4]
fwrite(fid, single(mat(2,:)),              'float32'); % srow_y[4]
fwrite(fid, single(mat(3,:)),              'float32'); % srow_z[4]
fwrite(fid, zeros(1,16,'uint8'),           'uint8' );  % intent_name[16]
fwrite(fid, uint8(['n+1' 0]),              'uint8' );  % magic[4]

% 4-byte extension block (no extensions)
fwrite(fid, zeros(1,4,'uint8'), 'uint8');

% MATLAB column-major order writes volumes as X/Y/Z/volume, matching NIfTI.
fwrite(fid, single(rgb_data(:)), 'float32');

% --------------------------------------------------------------------------
function q = qform_from_mat(mat, qfac)
%QFORM_FROM_MAT Convert an affine into NIfTI quaternion fields.
R = mat(1:3, 1:3);
scales = sqrt(sum(R .^ 2, 1));
scales(scales == 0) = 1;
R = R ./ scales;
R(:, 3) = R(:, 3) / qfac;

% Orthogonalise gently to avoid invalid quaternions from small shears.
[U, ~, V] = svd(R);
R = U * V';
if det(R) < 0
    U(:, 3) = -U(:, 3);
    R = U * V';
end

tr = trace(R);
if tr > 0
    S = sqrt(tr + 1.0) * 2;
    qb = (R(3, 2) - R(2, 3)) / S;
    qc = (R(1, 3) - R(3, 1)) / S;
    qd = (R(2, 1) - R(1, 2)) / S;
elseif R(1, 1) > R(2, 2) && R(1, 1) > R(3, 3)
    S = sqrt(1.0 + R(1, 1) - R(2, 2) - R(3, 3)) * 2;
    qb = 0.25 * S;
    qc = (R(1, 2) + R(2, 1)) / S;
    qd = (R(1, 3) + R(3, 1)) / S;
elseif R(2, 2) > R(3, 3)
    S = sqrt(1.0 + R(2, 2) - R(1, 1) - R(3, 3)) * 2;
    qb = (R(1, 2) + R(2, 1)) / S;
    qc = 0.25 * S;
    qd = (R(2, 3) + R(3, 2)) / S;
else
    S = sqrt(1.0 + R(3, 3) - R(1, 1) - R(2, 2)) * 2;
    qb = (R(1, 3) + R(3, 1)) / S;
    qc = (R(2, 3) + R(3, 2)) / S;
    qd = 0.25 * S;
end
q = [qb qc qd mat(1, 4) mat(2, 4) mat(3, 4)];

% --------------------------------------------------------------------------
function stamp_rgb_vector_header(niiFile)
%STAMP_RGB_VECTOR_HEADER Restore FSL-style RGB vector metadata after reslicing.
fid = fopen(niiFile, 'r+', 'l');
if fid < 0
    error('ea_create_rgb_fa: cannot open %s for RGB-vector header update', niiFile);
end
oc = onCleanup(@() fclose(fid));

fseek(fid, 40, 'bof');
dims = fread(fid, 8, 'int16')';
if numel(dims) >= 5
    dims(1) = 4;
    dims(5) = 3;
    fseek(fid, 40, 'bof');
    fwrite(fid, int16(dims), 'int16');
end

fseek(fid, 68, 'bof');
fwrite(fid, int16(2003), 'int16'); % NIFTI_INTENT_RGB_VECTOR

fseek(fid, 70, 'bof');
fwrite(fid, int16(16), 'int16');   % DT_FLOAT32
fwrite(fid, int16(32), 'int16');   % bitpix

fseek(fid, 76, 'bof');
pixdim = fread(fid, 8, 'float32')';
if numel(pixdim) == 8
    pixdim(1) = -1;
    pixdim(6:8) = 0;
    fseek(fid, 76, 'bof');
    fwrite(fid, single(pixdim), 'float32');
end

fseek(fid, 124, 'bof');
fwrite(fid, single([0 0 0 0]), 'float32'); % cal_max/min/slice_dur/toffset

fseek(fid, 140, 'bof');
fwrite(fid, int32([0 0]), 'int32');        % glmax/glmin
