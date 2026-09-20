-- ADMIN: fresh corrected variant. No reset, no original schema changes.
whenever sqlerror exit sql.sqlcode rollback
set define off
set serveroutput on
alter session set current_schema=APP_DEMO_IDEM;
declare n number;
begin
 select count(*) into n from dba_objects where owner='APP_DEMO_IDEM' and object_name like 'BF\_%' escape '\';
 if n<>0 then raise_application_error(-20991,'Corrected schema is not empty'); end if;
end;
/
@@10_tables.sql
@@20_views.sql
@@30_bf_log_pkg.sql
@@61_bf_lab_pkg.sql
@@40_bf_order_pkg.sql
@@42_bf_cart_pkg.sql
@@50_bf_incident_pkg.sql
begin bf_lab_pkg.seed_reference_data; commit; end;
/
declare n number;
begin
 select count(*) into n from dba_objects where owner='APP_DEMO_IDEM' and status<>'VALID';
 if n<>0 then raise_application_error(-20992,'Invalid objects in corrected schema'); end if;
 select count(*) into n from bf_order;
 if n<>0 then raise_application_error(-20993,'Fresh install must have no orders'); end if;
 dbms_output.put_line('IDEMPOTENT_INSTALL_VERIFIED');
end;
/
-- Configure BF_APP_CONFIG with the allocated app ID before importing APEX.
