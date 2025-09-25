function ea_dwisim(fibs,reffn,outfn,bvec,bval)


%% ref nifti 
ref = ea_load_untouch_nii(reffn);
shape = size(ref.img);


%% diffusion protocol

for k = 1:length(bval),
    d = bvec(:,k);
    bTensor(:,:,k) = bval(k) * d*d' / 1000;
end
n = size(bTensor,3);

%% prepare streamlines 

M=1;
nc = cellfun(@(x) ip(x,ceil(M*3)),fibs,'UniformOutput',false); % upsample line
nd = cellfun(@(x) id(x,ceil(M*3)),fibs,'UniformOutput',false); % compute tangents

arclen={};
for k = 1:length(nc), 
    dir = nd{k};  
    arclen{k} = sqrt(sum(dir.^2,2));
    nd{k} = nd{k} ./ arclen{k};
end;

pts = cat(1,nc{:});      % these are the sample points
ndir = cat(1,nd{:});     % normalized tangents at these points
alen = cat(1,arclen{:}); % arclen at the points

pts = [pts ones(size(pts,1),1)] * inv(ref.mat)'; % transform point from world into vx
pts = pts(:,1:3);


%% create signal 
                
D1 = 1.0;  % D along fiber
D2 = 0.4;  % D perp to fiber

dwi = zeros([ shape length(bval)]);
d0 = AccumulateBilinWeighted(single(shape),single(pts'),single(alen));

for k = 1:size(bTensor,3);
    s = signal(ndir,D1,D2,bTensor(:,:,k));
    dwi(:,:,:,k) = AccumulateBilinWeighted(single(shape),single(pts'),single(s.*alen));
end
dwi = dwi ./ (d0+0.01);


%% save data
ref.img = single(dwi);
ref.hdr.dime.dim([1 5]) = [4 n];
ref.img = dwi;
ea_save_untouch_nii(ref,outfn);

end
%%

% simple diffusion model 
function s = signal(f,D1,D2,b)
    bt = trace(b);    
    s = exp(-D1*sum((f*b).*f,2)-bt*D2);
end

               
% helper for upsampling
function y = ip(x,N)
    dx = x(2:end,:) - x(1:end-1,:);
    x = x(1:end-1,:);
    y = ones(N,size(x,1),size(x,2));
    for k = 1:N,
        y(k,:,:) = x + k/N*dx ;
    end;
    y = reshape(y,[N*size(x,1) size(x,2)]);
end

% helper for tangents
function y = id(x,N)
    dx = x(2:end,:) - x(1:end-1,:);
    x = x(1:end-1,:);
    y = ones(N,size(x,1),size(x,2));
    for k = 1:N,
        y(k,:,:) = dx ;
    end;
    y = reshape(y,[N*size(x,1) size(x,2)]);
end

               
