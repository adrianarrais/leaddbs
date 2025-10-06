function ea_dwisim(fibs,reffn,outfn,bvec,bval)


%% Ref nifti 

ref = ea_load_untouch_nii(reffn); % Load ref image without rescaling

%% Diffusion protocol

for k = 1:length(bval)
    d = bvec(:,k); % gradient direction vector
    bTensor(:,:,k) = bval(k) * d*d' / 1000; % Build a b-tensor for each gradient:Bk​=bk.​d.d⊤/1000 
end

%% Prepare streamlines

M=1; % Upsampling factor
nc = cellfun(@(x) interpolate_positions(x,ceil(M*3)),fibs,'UniformOutput',false); % upsample fiber points
nd = cellfun(@(x) interpolate_directions(x,ceil(M*3)),fibs,'UniformOutput',false); % compute tangents for new points % segment vectors (not yet unit)

arclen={};
for k = 1:length(nc) 
    dir = nd{k};  
    arclen{k} = sqrt(sum(dir.^2,2)); % computes the length of each new segment
    nd{k} = nd{k} ./ arclen{k};      % normalize to unit tangents
end

% Concatenate across all streamlines
pts = cat(1,nc{:});      % these are the sample points
ndir = cat(1,nd{:});     % normalized tangents at these points
alen = cat(1,arclen{:}); % arclen at the points

% transform point from world mm into vx
pts = [pts ones(size(pts,1),1)] * inv(ref.mat)'; 
pts = pts(:,1:3);


%% create signal 
                
D1 = 1.0;  % diffusivity along fiber direction
D2 = 0.4;  % diffusivity perpendicular to fiber

shape = size(ref.img); % 4D: 3D+dif_grad

% dwi = zeros([shape length(bval)]); % 5D - commented bc doesnt make sense to work w/ 5D
dwi = zeros(shape);

d0 = AccumulateBilinWeighted(single(shape),single(pts'),single(alen)); % 3D map w/out diffusion

for k = 1:size(bTensor,3)
    s = signal(ndir,D1,D2,bTensor(:,:,k)); % apply model to each diffusion gradient (?not sure?)
    dwi(:,:,:,k) = AccumulateBilinWeighted(single(shape),single(pts'),single(s.*alen)); % Added s to each voxel
end

% Normalize by baseline density (?)
dwi = dwi ./ (d0+0.01);

%% save data
ref.img = single(dwi);              % store synthesized 4D DWI into NIfTI struct      
% ref.hdr.dime.dim([1 5]) = [4 n];    % no variable n
ref.img = dwi;                      % (why rewrite?)
ea_save_untouch_nii(ref,outfn);

end
%%

% simple diffusion model 
function s = signal(f,D1,D2,b)
    bt = trace(b);    
    s = exp(-D1*sum((f*b).*f,2)-bt*D2);
end
      
% helper for upsampling
function y = interpolate_positions(x,N)
    % x: fiber coordinates
    % N: number of upsampled points per segment
    dx = x(2:end,:) - x(1:end-1,:);  % calculate distance btw points - segments size
    x = x(1:end-1,:);                % segments starting points
    y = ones(N,size(x,1),size(x,2)); % matrix to store upsampled fiber points
    for k = 1:N                      
        y(k,:,:) = x + k/N*dx ;      % create 3 points within segment                        
    end
    y = reshape(y,[N*size(x,1) size(x,2)]);
end

% helper for tangents
function y = interpolate_directions(x,N)
    % x: fiber
    % N: number of upsampled points per segment
    dx = x(2:end,:) - x(1:end-1,:);  % calculate distance btw points - segments size
    x = x(1:end-1,:);                % segments starting points
    y = ones(N,size(x,1),size(x,2)); % matrix to store upsampled tangent/directions
    for k = 1:N
        y(k,:,:) = dx;                  % replicate each segment vector N times
    end
    y = reshape(y,[N*size(x,1) size(x,2)]);
end

               
