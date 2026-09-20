#!/usr/bin/env python3
"""Two real SQLcl connections. Appends one intent; no APEX/browser claim."""
import argparse, concurrent.futures, datetime, json, pathlib, re, subprocess, time, uuid
p=argparse.ArgumentParser(); p.add_argument('--connection',required=True); p.add_argument('--output',required=True); a=p.parse_args()
out=pathlib.Path(a.output);out.mkdir(parents=True,exist_ok=True)
run='QA-CONCURRENT-'+uuid.uuid4().hex[:12]
def sql(script,label):
 start=datetime.datetime.now(datetime.timezone.utc).isoformat()
 r=subprocess.run(['sql','-s','-name',a.connection],input='set serveroutput on\nset define off\nwhenever sqlerror exit sql.sqlcode rollback\nalter session set current_schema=APP_DEMO_IDEM;\n'+script+'\nexit\n',text=True,capture_output=True,timeout=90)
 end=datetime.datetime.now(datetime.timezone.utc).isoformat();(out/(label+'.log')).write_text(r.stdout+r.stderr)
 if r.returncode or re.search(r'(?m)^ORA-|^SP2-',r.stdout):raise RuntimeError(label+' failed: see saved log')
 return {'start':start,'end':end,'output':r.stdout}
setup=sql("""declare k varchar2(64):=lower(rawtohex(sys_guid())); payload clob;
begin
 select json_object('items' value json_array(json_object('productId' value product_id,'quantity' value 1,'name' value brand||' '||product_name,'price' value unit_price)) returning clob)
 into payload from bf_product where sku='NU-DOCK';
 insert into bf_order_intent(request_hash,customer_id,request_json,app_user,apex_session_id)
 values(k,bf_order_pkg.customer_id,payload,'QA-SUPPORT','%s');
 insert into bf_lab_assignment(request_hash,scenario) values(k,'CLEAN'); commit;
 dbms_output.put_line('KEY='||k);
end;
/
"""%run,'setup')
key=re.search(r'KEY=([0-9a-f]{32})',setup['output']).group(1)
def worker(label,delay):
 return sql("""declare o number; locked_key varchar2(64);
begin
 dbms_output.put_line('ENTER='||to_char(systimestamp at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.FF6"Z"'));
 select request_hash into locked_key from bf_order_intent where request_hash='%s' for update;
 dbms_output.put_line('LOCKED='||to_char(systimestamp at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.FF6"Z"'));
 dbms_session.sleep(%d);
 bf_order_pkg.receive_attempt('%s','%s','QA-SUPPORT',o);
 bf_order_pkg.process_order(o,'%s','QA-SUPPORT');
 dbms_output.put_line('ORDER='||o);
 dbms_output.put_line('DONE='||to_char(systimestamp at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.FF6"Z"'));
end;
/
"""%(key,delay,key,run,run),label)
with concurrent.futures.ThreadPoolExecutor(2) as pool:
 fa=pool.submit(worker,'worker-a',5);time.sleep(.4);fb=pool.submit(worker,'worker-b',0)
 results=[fa.result(),fb.result()]
intervals=[]
for r in results:
 intervals.append({x:re.search(x+'=([^\\r\\n]+)',r['output']).group(1) for x in ['ENTER','LOCKED','DONE','ORDER']})
overlap=max(x['ENTER'] for x in intervals)<min(x['DONE'] for x in intervals)
if not overlap:raise RuntimeError('No observed overlap: do not claim concurrency')
if intervals[0]['ORDER']!=intervals[1]['ORDER']:raise RuntimeError('Different returned orders')
verify=sql("""declare n number;
begin
 select count(*) into n from bf_order where request_hash='%s';
 if n<>1 then raise_application_error(-20980,'Expected one order'); end if;
 select count(*) into n from bf_submission_attempt where request_hash='%s';
 if n<>2 then raise_application_error(-20980,'Expected two attempts'); end if;
 select count(*) into n from bf_integration_log where order_id in(select order_id from bf_order where request_hash='%s');
 if n<>1 then raise_application_error(-20980,'Expected one dispatch'); end if;
 dbms_output.put_line('CONCURRENCY_PASS: one order, two attempts, one simulated dispatch');
end;
/
"""%(key,key,key),'verify')
(out/'result.json').write_text(json.dumps({'mechanism':'two SQLcl database connections; same authorized logical identity','overlap':overlap,'intervals':intervals,'result':'PASS'},indent=2)+'\n')
print(verify['output'])
