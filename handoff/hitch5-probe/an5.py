import csv, sys, statistics as st
rows=[r for r in csv.DictReader(open(sys.argv[1])) if r['phase']!='warm']
num=lambda r,k: float(r[k])
def q(v,p):
    v=sorted(v); return v[min(len(v)-1,int(p*len(v)))]
cols=['setup_ms','rcpu_ms','rgpu_ms','obj','draws','sobj','sdraws','pc_draw','pc_spec','pc_surf','dtex_kb','dbuf_kb','vi_add','vi_rem','mat_chg','mesh_chg','vis_chg','emit','emit_amt','lights','shadow_lights','steps']
print('| col | follow med/p90/max | wide med/p90/max | sum |')
for c in cols:
    out=[]
    for ph in ['follow','wide']:
        v=[num(r,c) for r in rows if r['phase']==ph]
        out.append('%g / %g / %g'%(st.median(v),q(v,.9),max(v)))
    print('|',c,'|',' | '.join(out),'|',sum(num(r,c) for r in rows),'|')
# correlate: top 10 frames by rcpu
print('top rcpu frames:')
for r in sorted(rows,key=lambda r:-num(r,'rcpu_ms'))[:12]:
    print({k:r[k] for k in ['f','phase','setup_ms','rcpu_ms','rgpu_ms','steps','pc_draw','pc_spec','vi_add','vi_rem','mat_chg','mesh_chg','vis_chg','emit','dbuf_kb','dtex_kb']})
