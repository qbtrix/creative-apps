# check_c4.py: checks docs/blueprints/library/c4-planned.json. Run from the repo root:
# python3 docs/blueprints/library/check_c4.py. Prints four lists that must all be empty.
import json,os,sys
d=json.load(open("docs/blueprints/library/c4-planned.json"))
comps=[c for s in d["model"]["systems"] for k in s["containers"] for c in k["components"]]
ids={c["id"] for c in comps}|{k["id"] for s in d["model"]["systems"] for k in s["containers"]}|{p["id"] for p in d["model"]["people"]}
bad=[r for r in d["model"]["relationships"] if r["source"] not in ids or r["target"] not in ids]
paths=[(p,c["id"]) for c in comps for p in c["paths"]]
over=[(a,b) for a in paths for b in paths if a!=b and a[1]!=b[1] and (a[0].startswith(b[0]) or b[0].startswith(a[0])) and "suiteui" not in a[1]+b[1]]
missing=[c["id"] for c in comps if not all(k in c for k in ("status","authored","paths","description","name"))]
files=[os.path.join(r,f) for top in ("Sources/LibraryModel","Sources/LibraryApp") for r,_,fs in os.walk(top) for f in fs]
unowned=[f for f in files if sum(1 for p,_ in paths if f.startswith(p))!=1]
print("relationships with unknown ends:",bad); print("overlapping paths:",over); print("components missing fields:",missing); print("existing files not owned exactly once:",unowned)
