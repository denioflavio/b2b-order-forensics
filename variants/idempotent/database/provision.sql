-- ADMIN: isolated schema only. No password, no login, no existing schema reuse.
whenever sqlerror exit sql.sqlcode rollback
set define off
declare n number;
begin
 select count(*) into n from dba_users where username='APP_DEMO_IDEM';
 if n<>0 then raise_application_error(-20990,'APP_DEMO_IDEM already exists; inspect before proceeding'); end if;
end;
/
create user APP_DEMO_IDEM no authentication default tablespace DATA quota 100M on DATA;
grant create table, create view, create procedure, create sequence to APP_DEMO_IDEM;
begin apex_instance_admin.add_schema(p_workspace=>'APEXFROMTHEFIELD',p_schema=>'APP_DEMO_IDEM'); end;
/
