# pip install matlabengine (run from MATLAB's "extern/engines/python" if needed)
import matlab.engine
import pandas as pd
from pathlib import Path

jobfile = r"/Users/amygdala/Documents/NetStim/Projects/LeadTutor"      # <-- your Lead-DBS job
workdir = r"/Users/amygdala/Documents/MATLAB/toolbox/leaddbs/automated_optimization"   # optional

eng = matlab.engine.start_matlab()
eng.cd(workdir, nargout=0)

# Start profiling
eng.profile('clear', nargout=0)
eng.eval("profile on -history", nargout=0)

# Run Lead-DBS programmatically (GUI-free)
eng.eval(f"opts = ea_getptopts('{jobfile}');", nargout=0)
eng.eval("ea_run(opts);", nargout=0)

# Stop profiling and fetch info
eng.eval("profile off", nargout=0)
p = eng.profile('info')   # MATLAB struct comes back as a Python-mappable struct

# Build a DataFrame of functions/files; filter out builtins/empty files
rows = []
for f in p['FunctionTable']:
    fname = f['FunctionName']
    fpath = f['FileName']
    is_builtin = bool(f['IsBuiltIn'] or f['IsRecursive'])
    if fpath and not is_builtin:
        rows.append({
            "Function": fname,
            "File": fpath,
            "NumCalls": int(f['NumCalls']),
            "TotalTime_sec": float(f['TotalTime']),
        })

df = pd.DataFrame(rows)
df.sort_values(["TotalTime_sec"], ascending=False, inplace=True)

out = Path(workdir) / "called_functions.csv"
df.to_csv(out, index=False)
print(f"Wrote {out}")
