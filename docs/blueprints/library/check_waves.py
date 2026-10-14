# check_waves.py: checks docs/blueprints/library/waves.json, the Library
# features and their owned files. Run from the repo root:
# python3 docs/blueprints/library/check_waves.py
# Fails (exit 1) when two features in one wave own the same file (or one
# owns a prefix of the other's), when a feature depends on one in the same
# or a later wave, when an open line:library issue listed below is in no
# feature, or when a Sources file is owned but not in c4-planned.json or the
# reverse. Prints one line per problem, else "waves: OK".
import json, sys
OPEN_ISSUES = [31, 32, 33, 156, 185, 210, 211, 212, 235, 291, 423, 424, 425, 426, 427, 724, 744]
d = json.load(open("docs/blueprints/library/waves.json"))
features = {f["id"]: f for f in d["features"]}
problems = []
def clash(a, b):
    return a == b or ((a.endswith("/") or a.endswith("+")) and b.startswith(a)) or ((b.endswith("/") or b.endswith("+")) and a.startswith(b))
for f in d["features"]:
    for g in d["features"]:
        if f["id"] < g["id"] and f["wave"] == g["wave"]:
            for a in f["owned"]:
                for b in g["owned"]:
                    if clash(a, b):
                        problems.append(f"wave {f['wave']}: {f['id']} and {g['id']} both own {a} / {b}")
    for dep in f["depends"]:
        if dep not in features:
            problems.append(f"{f['id']} depends on unknown {dep}")
        elif features[dep]["wave"] >= f["wave"]:
            problems.append(f"{f['id']} (wave {f['wave']}) depends on {dep} (wave {features[dep]['wave']})")
c4 = json.load(open("docs/blueprints/library/c4-planned.json"))
c4paths = [p for sy in c4["model"]["systems"] for k in sy["containers"] for c in k["components"] for p in c["paths"]
           if p.startswith("Sources/Library")]
owned = [p for f in d["features"] for p in f["owned"]]
for p in owned:
    if p.startswith("Sources/Library") and not any(p.startswith(c) or c.startswith(p) for c in c4paths):
        problems.append(f"{p} is owned by a feature but in no C4 component")
for c in c4paths:
    if not c.endswith("/") and not any(c == p or (p.endswith(("/", "+")) and c.startswith(p)) for p in owned):
        problems.append(f"{c} is in c4-planned.json but no feature owns it")
covered = {i for f in d["features"] for i in f["issues"]}
for i in OPEN_ISSUES:
    if i not in covered:
        problems.append(f"open issue #{i} is in no feature")
print("\n".join(problems) if problems else "waves: OK")
sys.exit(1 if problems else 0)
