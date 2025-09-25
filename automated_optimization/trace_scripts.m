%% HTML report

profile on 
p = profile('info');
profsave(p, 'lead_dbs_trace')

%% 
outdir = fullfile(pwd,'lead_test_out'); mkdir(outdir);
assignin('base','lead_outdir',outdir);   % remember where to save later

profile clear; 
profile on -history

lead_dbs;   % <-- interact with the GUI; when you're done, close it

%% Do a certain pipeline in Lead-dbs
%% 
outdir = evalin('base','lead_outdir');
profile off
p = profile('info');

allFuncs = {p.FunctionTable.FunctionName}';
allFiles = {p.FunctionTable.FileName}';

T = table(allFuncs, allFiles);
writetable(T, 'called_functions.csv');

disp('Wrote called_functions.csv with one line per function.');