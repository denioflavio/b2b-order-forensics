create or replace package bf_lab_pkg authid definer as
 procedure seed_reference_data;
 function pick_case(p_draw number) return varchar2;
 procedure assign_case(p_intention varchar2);
 function service_for(p_intention varchar2) return varchar2;
 function account_for(p_intention varchar2) return varchar2;
 function retry_required(p_intention varchar2) return boolean;
end bf_lab_pkg;
/
create or replace package body bf_lab_pkg as
 function pick_case(p_draw number) return varchar2 is
 begin
  if p_draw is null or p_draw<0 or p_draw>=1 then raise_application_error(-20090,'Invalid draw'); end if;
  return case when p_draw<0.5 then 'CLEAN' when p_draw<2/3 then 'OVERFLOW'
              when p_draw<5/6 then 'PRE_INTEGRATION' else 'RETRY' end;
 end;
 procedure assign_case(p_intention varchar2) is
  l_mode bf_lab_config.selection_mode%type;
 begin
  select selection_mode into l_mode from bf_lab_config where config_id=1;
  insert into bf_lab_assignment(request_hash,scenario) values(p_intention,
   case when l_mode='RANDOM' then pick_case(dbms_random.value) else l_mode end);
 end;
 function service_for(p_intention varchar2) return varchar2 is
  l_case bf_lab_assignment.scenario%type;
 begin
  select scenario into l_case from bf_lab_assignment where request_hash=p_intention;
  return case when l_case='OVERFLOW' then 'PRIORITY_INTERNATIONAL' else 'STANDARD' end;
 end;
 function account_for(p_intention varchar2) return varchar2 is
  l_case bf_lab_assignment.scenario%type;
 begin
  select scenario into l_case from bf_lab_assignment where request_hash=p_intention;
  return case when l_case='PRE_INTEGRATION' then null else 'ACME-DELIVERY-01' end;
 end;
 function retry_required(p_intention varchar2) return boolean is
  l_case bf_lab_assignment.scenario%type;
 begin
  select scenario into l_case from bf_lab_assignment where request_hash=p_intention;
  return l_case='RETRY';
 end;
 procedure seed_reference_data is
 begin
  merge into bf_customer d using (select 'ACME' code,'Acme Workspace' name from dual) s
  on(d.customer_code=s.code) when not matched then insert(customer_code,customer_name) values(s.code,s.name);
  merge into bf_lab_config d using(select 1 id from dual)s on(d.config_id=s.id)
   when not matched then insert(config_id,selection_mode) values(1,'RANDOM');
  merge into bf_product d using(select 'NU-AIR14' sku from dual)s on(d.sku=s.sku)
   when not matched then insert(sku,product_name,brand,category,description,artwork_key,unit_price)
   values('NU-AIR14','Airbook 14','Nuvyra','Computers','Lightweight 14-inch notebook. 16 GB memory and 512 GB SSD.','laptop',4299);
  merge into bf_product d using(select 'NU-MINI' sku from dual)s on(d.sku=s.sku)
   when not matched then insert(sku,product_name,brand,category,description,artwork_key,unit_price)
   values('NU-MINI','Desk Mini','Nuvyra','Computers','A compact desktop for a focused workspace. 16 GB memory.','desktop',2999);
  merge into bf_product d using(select 'OR-VIEW27' sku from dual)s on(d.sku=s.sku)
   when not matched then insert(sku,product_name,brand,category,description,artwork_key,unit_price)
   values('OR-VIEW27','View 27','Orvexa','Displays','27-inch QHD display with an adjustable stand.','monitor',1499);
  merge into bf_product d using(select 'AV-TYPE' sku from dual)s on(d.sku=s.sku)
   when not matched then insert(sku,product_name,brand,category,description,artwork_key,unit_price)
   values('AV-TYPE','Type Wireless','Aveniq','Peripherals','Quiet wireless keyboard for everyday work.','keyboard',249);
  merge into bf_product d using(select 'AV-POINT' sku from dual)s on(d.sku=s.sku)
   when not matched then insert(sku,product_name,brand,category,description,artwork_key,unit_price)
   values('AV-POINT','Point Wireless','Aveniq','Peripherals','Comfortable wireless mouse with precise tracking.','mouse',129);
  merge into bf_product d using(select 'AV-TALK' sku from dual)s on(d.sku=s.sku)
   when not matched then insert(sku,product_name,brand,category,description,artwork_key,unit_price)
   values('AV-TALK','Talk Pro','Aveniq','Audio & Video','Over-ear headset with a clear boom microphone.','headset',399);
  merge into bf_product d using(select 'OR-MEET' sku from dual)s on(d.sku=s.sku)
   when not matched then insert(sku,product_name,brand,category,description,artwork_key,unit_price)
   values('OR-MEET','Meet HD','Orvexa','Audio & Video','Full HD webcam with a built-in privacy cover.','webcam',299);
  merge into bf_product d using(select 'NU-DOCK' sku from dual)s on(d.sku=s.sku)
   when not matched then insert(sku,product_name,brand,category,description,artwork_key,unit_price)
   values('NU-DOCK','Connect Dock','Nuvyra','Accessories','USB-C dock with display, network and accessory ports.','dock',599);
 end;
end bf_lab_pkg;
/
