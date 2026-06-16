"""
generate_mrr_data.py — FINAL
10,000+ SaaS subscription events
2,000 customers | Jan 2019 – Feb 2025 | 74 months
"""
import random, csv
from datetime import date, timedelta
from faker import Faker
fake = Faker(); random.seed(42)

PLANS = {'starter':99,'pro':299,'growth':499,'enterprise':799,'enterprise_plus':999}
PO    = ['starter','pro','growth','enterprise','enterprise_plus']
S,E   = date(2019,1,1), date(2025,2,28)

CP   = {'starter':0.020,'pro':0.015,'growth':0.012,'enterprise':0.007,'enterprise_plus':0.004}
XP   = {'starter':0.10,'pro':0.09,'growth':0.07,'enterprise':0.05,'enterprise_plus':0.0}
DP   = {'starter':0.0,'pro':0.022,'growth':0.025,'enterprise':0.018,'enterprise_plus':0.022}
RP   = 0.016

months=[]
d=S
while d<=E:
    months.append((d.year,d.month))
    d=date(d.year+(d.month//12),(d.month%12)+1,1)

def rday(y,m):
    f=date(y,m,1); l=date(y+(m//12),(m%12)+1,1)-timedelta(1)
    return f+timedelta(random.randint(0,(l-f).days))

def npm(i): return max(10,int((18+i*0.35)*random.uniform(0.65,1.45)))

custs={}; churned=[]; evts=[]; sn=1; cn=1

def sid(): global sn; s=f'sub_{sn:05d}'; sn+=1; return s
def cid(): global cn; c=f'cus_{cn:04d}'; cn+=1; return c

for mi,(yr,mo) in enumerate(months):
    for _ in range(npm(mi)):
        c=cid(); p=random.choices(PO,weights=[26,26,20,18,10],k=1)[0]
        mrr=PLANS[p]; dt=rday(yr,mo)
        nm=fake.company().replace(',','').replace("'","")[:40]
        custs[c]=dict(n=nm,p=p,mrr=mrr,a=True)
        evts.append(dict(subscription_id=sid(),customer_id=c,customer_name=nm,
            plan_name=p,mrr_amount=mrr,previous_mrr=None,
            status='active',start_date=dt,end_date=None))

    active=[c for c,s in custs.items() if s['a']]
    random.shuffle(active)
    for c in active:
        s=custs[c]; p=s['p']; r=random.random()
        if r<CP[p]:
            dt=rday(yr,mo)
            evts.append(dict(subscription_id=sid(),customer_id=c,customer_name=s['n'],
                plan_name=p,mrr_amount=s['mrr'],previous_mrr=s['mrr'],
                status='cancelled',start_date=dt,end_date=dt))
            s['a']=False; churned.append(dict(c=c,s=dict(s),g=0))
        elif r<CP[p]+XP[p]:
            i=PO.index(p)
            if i<4:
                np=PO[i+1]; nm=PLANS[np]; dt=rday(yr,mo)
                evts.append(dict(subscription_id=sid(),customer_id=c,customer_name=s['n'],
                    plan_name=np,mrr_amount=nm,previous_mrr=s['mrr'],
                    status='active',start_date=dt,end_date=None))
                s['p']=np; s['mrr']=nm
        elif r<CP[p]+XP[p]+DP[p]:
            i=PO.index(p)
            if i>0:
                np=PO[i-1]; nm=PLANS[np]; dt=rday(yr,mo)
                evts.append(dict(subscription_id=sid(),customer_id=c,customer_name=s['n'],
                    plan_name=np,mrr_amount=nm,previous_mrr=s['mrr'],
                    status='active',start_date=dt,end_date=None))
                s['p']=np; s['mrr']=nm

    still=[]
    for e2 in churned:
        e2['g']+=1
        if e2['g']>=2 and random.random()<RP:
            c=e2['c']; os=e2['s']
            p=random.choice(['starter','pro']); mrr=PLANS[p]; dt=rday(yr,mo)
            evts.append(dict(subscription_id=sid(),customer_id=c,customer_name=os['n'],
                plan_name=p,mrr_amount=mrr,previous_mrr=None,
                status='reactivation',start_date=dt,end_date=None))
            custs[c].update(a=True,p=p,mrr=mrr)
        else: still.append(e2)
    churned[:]=still

total=len(evts)
by_t={}
for e in evts:
    t=e['status']
    if t=='active':
        if e['previous_mrr'] is None: t='new'
        elif e['mrr_amount']>e['previous_mrr']: t='expansion'
        elif e['mrr_amount']<e['previous_mrr']: t='contraction'
        else: t='unchanged'
    by_t[t]=by_t.get(t,0)+1

print(f"✅ Total events   : {total:,}")
for k,v in sorted(by_t.items()): print(f"   {k:<15}: {v:,}")
print(f"   Unique custs  : {len(set(e['customer_id'] for e in evts))}")
print(f"   Date range    : {min(e['start_date'] for e in evts)} → {max(e['start_date'] for e in evts)}")

fields=['subscription_id','customer_id','customer_name','plan_name',
        'mrr_amount','previous_mrr','status','start_date','end_date']

cp='/home/claude/saas-mrr-analytics/data/subscriptions_large.csv'
sp='/home/claude/saas-mrr-analytics/data/seed_data_large.sql'

with open(cp,'w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(evts)

with open(sp,'w') as f:
    f.write(f"-- Auto-generated: {total:,} SaaS subscription events\n")
    f.write(f"-- {len(set(e['customer_id'] for e in evts)):,} customers | Jan 2019 – Feb 2025 | 74 months\n")
    f.write("-- Event types: new, expansion, contraction, churn, reactivation\n")
    f.write("-- Run AFTER schema.sql\n\n")
    f.write("DELETE FROM subscriptions;\n\n")
    f.write("INSERT INTO subscriptions\n  (subscription_id,customer_id,customer_name,")
    f.write("plan_name,mrr_amount,previous_mrr,status,start_date,end_date)\nVALUES\n")
    rows=[]
    for e in evts:
        prev=f"{e['previous_mrr']:.2f}" if e['previous_mrr'] is not None else 'NULL'
        end=f"'{e['end_date']}'" if e['end_date'] else 'NULL'
        nm=e['customer_name'].replace("'","''")
        rows.append(f"  ('{e['subscription_id']}','{e['customer_id']}','{nm}',"
                    f"'{e['plan_name']}',{e['mrr_amount']:.2f},{prev},"
                    f"'{e['status']}','{e['start_date']}',{end})")
    f.write(',\n'.join(rows)+';\n')

import os
csv_mb = os.path.getsize(cp)/1024/1024
sql_mb = os.path.getsize(sp)/1024/1024
print(f"\n   CSV  → {cp} ({csv_mb:.1f} MB)")
print(f"   SQL  → {sp} ({sql_mb:.1f} MB)")
