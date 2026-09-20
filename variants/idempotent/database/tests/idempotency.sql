-- Appends synthetic QA purchases only in APP_DEMO_IDEM. Restores lab mode.
whenever sqlerror exit sql.sqlcode rollback
set serveroutput on
alter session set current_schema=APP_DEMO_IDEM;
declare
 k varchar2(64); k2 varchar2(64); o number; replay number; o2 number;
 items clob; n number; code number; old_mode varchar2(30);
 procedure expect(ok boolean,msg varchar2) is
 begin if ok is null or not ok then raise_application_error(-20980,msg); end if; end;
 procedure counts(key_ varchar2,dispatches number) is
 begin
  select count(*) into n from bf_order where request_hash=key_;
  expect(n=1,'One order per intention');
  select count(*) into n from bf_integration_log where order_id in(select order_id from bf_order where request_hash=key_);
  expect(n=dispatches,'Dispatch count');
 end;
begin
 select selection_mode into old_mode from bf_lab_config where config_id=1;
 update bf_lab_config set selection_mode='CLEAN' where config_id=1; commit;
 select json_array(json_object('productId' value product_id,'quantity' value 2) returning clob)
  into items from bf_product where sku='NU-DOCK';
 bf_order_pkg.begin_checkout(items,'QA-IDEM','QA-SUPPORT',k,o);
 bf_order_pkg.receive_attempt(k,'QA-IDEM','QA-SUPPORT',replay);
 expect(o=replay,'Replay before processing must reuse order');
 bf_order_pkg.process_order(o,'QA-IDEM','QA-SUPPORT');
 for i in 1..3 loop
  bf_order_pkg.receive_attempt(k,'QA-IDEM','QA-SUPPORT',replay);
  expect(o=replay,'Completed replay must reuse order');
  bf_order_pkg.process_order(replay,'QA-IDEM','QA-SUPPORT');
 end loop;
 counts(k,1);
 select count(distinct correlation_id) into n from bf_submission_attempt where request_hash=k;
 expect(n=5,'Five distinct attempt correlations');
 select count(*) into n from bf_order where order_id=o and total_amount=1198 and status='COMPLETED';
 expect(n=1,'Completed commercial snapshot');
 dbms_output.put_line('PASS sequential replay and repeated processing: order='||o);
 bf_order_pkg.begin_checkout(items,'QA-IDEM','QA-SUPPORT',k2,o2);
 bf_order_pkg.process_order(o2,'QA-IDEM','QA-SUPPORT');
 expect(k<>k2 and o<>o2,'Equal payload, new intention means new purchase'); counts(k2,1);
 dbms_output.put_line('PASS equal payload with different keys: orders='||o||','||o2);
 for i in 1..3 loop
  code:=0;
  begin
   bf_order_pkg.receive_attempt(k,case when i=1 then 'OTHER-SESSION' when i=2 then null else 'QA-IDEM' end,
     case when i=3 then 'OTHER-USER' else 'QA-SUPPORT' end,replay);
  exception when others then code:=sqlcode; rollback; end;
  expect(code=-20080,'Unauthorized replay must fail');
 end loop;
 counts(k,1);
 select count(*) into n from bf_submission_attempt where request_hash=k;
 expect(n=5,'Unauthorized requests must not write attempt records');
 dbms_output.put_line('PASS user/session/null-session authorization');
 -- Database invariant, independent of package control flow.
 code:=0;
 begin
  insert /*+ disable_parallel_dml no_parallel */ into bf_order(order_number,customer_id,request_hash,attempt_no,status,created_by,apex_session_id,correlation_id)
   select /*+ no_parallel */ 'QA-'||rawtohex(sys_guid()),customer_id,request_hash,999,'RECEIVED',created_by,apex_session_id,rawtohex(sys_guid())
   from bf_order where order_id=o;
 exception when dup_val_on_index then code:=sqlcode; end;
 expect(code=-1,'Unique intention constraint must reject duplicate insertion'); rollback;
 dbms_output.put_line('PASS database unique constraint');
 for i in 1..2 loop
  update bf_lab_config set selection_mode=case i when 1 then 'OVERFLOW' else 'PRE_INTEGRATION' end where config_id=1; commit;
  bf_order_pkg.begin_checkout(items,'QA-IDEM','QA-SUPPORT',k,o);
  code:=0;
  begin bf_order_pkg.process_order(o,'QA-IDEM','QA-SUPPORT'); exception when others then code:=sqlcode; end;
  expect(code=case i when 1 then -6502 else -20071 end,'Original error must remain observable');
  bf_order_pkg.receive_attempt(k,'QA-IDEM','QA-SUPPORT',replay);
  expect(o=replay,'Failed replay must reuse order');
  code:=0;
  begin bf_order_pkg.process_order(replay,'QA-IDEM','QA-SUPPORT'); exception when others then code:=sqlcode; end;
  expect(code=-20084,'Failed order must not automatically dispatch again'); counts(k,0);
  select count(*) into n from bf_error_log where order_id=o and sql_code=case i when 1 then -6502 else -20071 end;
  expect(n=1,'Original error evidence retained without duplicate logging');
  dbms_output.put_line('PASS error retention/no redispatch: order='||o);
 end loop;
 update bf_lab_config set selection_mode=old_mode where config_id=1; commit;
 dbms_output.put_line('IDEMPOTENCY_REGRESSION_PASS');
exception when others then
 rollback; update bf_lab_config set selection_mode=old_mode where config_id=1; commit; raise;
end;
/
