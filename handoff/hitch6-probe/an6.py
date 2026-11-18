import csv, sys, statistics as S
# usage: an6.py trace1.csv [trace2.csv ...]  -> per run: slow frames split; recurring slow times across runs
runs=[list(csv.DictReader(open(p))) for p in sys.argv[1:]]
def f(r,k): return float(r[k])
slows=[]
for p,rows in zip(sys.argv[1:],runs):
    slow=[r for r in rows if f(r,'frame_ms')>25]
    work=[r for r in slow if f(r,'physics_ms')+f(r,'process_ms')+f(r,'draw_ms')>16.7]
    print(f"{p}: frames={len(rows)} over25={len(slow)} of which work>16.7ms={len(work)} idle-held={len(slow)-len(work)}")
    for k in ['frame_ms','physics_ms','process_ms','draw_ms','idle_ms','gpu_ms']:
        a=[f(r,k) for r in rows]; s=[f(r,k) for r in slow] or [0]
        a.sort()
        print(f"   {k:11s} all med {S.median(a):6.2f} p99 {a[int(len(a)*.99)]:6.2f} | slow med {S.median(s):6.2f}")
    print("   by seg over25:", {sg:sum(1 for r in slow if r['seg']==sg) for sg in ('follow','wide')})
    slows.append([(round(f(r,'t'),1), r) for r in slow])
if len(slows)>1:
    ts=[set(t for t,_ in s) for s in slows]
    rec=set.intersection(*ts)
    near=[t for t in ts[0] if all(any(abs(t-u)<=0.15 for u in o) for o in ts[1:])]
    print("slow frames at the same route time (+-0.15 s) in every run:", sorted(near))
