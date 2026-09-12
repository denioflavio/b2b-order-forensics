whenever sqlerror exit sql.sqlcode rollback
set pagesize 200 linesize 240 feedback on heading on verify off serveroutput on

prompt BF_MCP_RO account state
select username, account_status, default_tablespace, temporary_tablespace, profile
  from dba_users
 where username = 'BF_MCP_RO';

prompt Direct system privileges: exactly CREATE SESSION is expected
select grantee, privilege, admin_option
  from dba_sys_privs
 where grantee = 'BF_MCP_RO'
 order by privilege;

prompt Direct roles: exactly BF_MCP_EVIDENCE_ROLE is expected
select grantee, granted_role, admin_option, default_role
  from dba_role_privs
 where grantee = 'BF_MCP_RO'
 order by granted_role;

prompt Evidence role object privileges: three SELECT and one EXECUTE are expected
select grantee, owner, table_name, privilege, grantable
  from dba_tab_privs
 where grantee = 'BF_MCP_EVIDENCE_ROLE'
 order by owner, table_name, privilege;

prompt Blocking counts: every value must be zero
select
  (select count(*)
     from dba_sys_privs
    where grantee = 'BF_MCP_RO'
      and privilege <> 'CREATE SESSION') unexpected_system_privileges,
  (select count(*)
     from dba_role_privs
    where grantee = 'BF_MCP_RO'
      and granted_role <> 'BF_MCP_EVIDENCE_ROLE') unexpected_roles,
  (select count(*)
     from dba_tab_privs
    where grantee = 'BF_MCP_RO') direct_object_privileges,
  (select count(*)
     from dba_tab_privs
    where grantee = 'BF_MCP_EVIDENCE_ROLE'
      and owner = 'APP_DEMO'
      and table_name in (
        'BF_CUSTOMER', 'BF_PRODUCT', 'BF_ORDER', 'BF_ORDER_ITEM',
        'BF_INTEGRATION_LOG', 'BF_ACCESS_LOG',
        'BF_ERROR_LOG', 'BF_DEBUG_EVENT', 'BF_ORDER_PKG', 'BF_SEED_PKG'
      )) forbidden_business_object_grants
  from dual;

prompt Enforcing the privilege contract
declare
  l_count pls_integer;
begin
  select count(*) into l_count from dba_tab_privs where grantee='BF_MCP_RO';
  if l_count<>0 then raise_application_error(-20090,'BF_MCP_RO has direct object grants.'); end if;
  select count(*) into l_count from dba_sys_privs where grantee='BF_MCP_RO'
    and privilege='CREATE SESSION' and admin_option='NO';
  if l_count<>1 then raise_application_error(-20090,'Expected non-administrative CREATE SESSION.'); end if;
  select count(*) into l_count from dba_role_privs where grantee='BF_MCP_RO'
    and granted_role='BF_MCP_EVIDENCE_ROLE' and admin_option='NO' and default_role='YES';
  if l_count<>1 then raise_application_error(-20090,'Expected default evidence role without delegation.'); end if;
  select count(*)
    into l_count
    from dba_users
   where username = 'BF_MCP_RO'
     and account_status = 'OPEN';
  if l_count <> 1 then
    raise_application_error(-20091, 'BF_MCP_RO is missing or is not OPEN.');
  end if;

  select count(*)
    into l_count
    from dba_ts_quotas
   where username = 'BF_MCP_RO'
     and (max_bytes = -1 or max_bytes > 0);
  if l_count <> 0 then
    raise_application_error(-20092, 'BF_MCP_RO has a non-zero tablespace quota.');
  end if;

  select count(*)
    into l_count
    from dba_sys_privs
   where grantee = 'BF_MCP_RO'
     and privilege <> 'CREATE SESSION';
  if l_count <> 0 then
    raise_application_error(-20093, 'BF_MCP_RO has unexpected system privileges.');
  end if;

  select count(*)
    into l_count
    from dba_role_privs
   where grantee = 'BF_MCP_RO'
     and granted_role <> 'BF_MCP_EVIDENCE_ROLE';
  if l_count <> 0 then
    raise_application_error(-20094, 'BF_MCP_RO has unexpected roles.');
  end if;

  select count(*)
    into l_count
    from dba_role_privs
   where grantee = 'BF_MCP_EVIDENCE_ROLE';
  if l_count <> 0 then
    raise_application_error(-20095, 'BF_MCP_EVIDENCE_ROLE inherits another role.');
  end if;

  select count(*)
    into l_count
    from dba_sys_privs
   where grantee = 'BF_MCP_EVIDENCE_ROLE';
  if l_count <> 0 then
    raise_application_error(-20096, 'BF_MCP_EVIDENCE_ROLE has system privileges.');
  end if;

  select count(*)
    into l_count
    from dba_tab_privs
    where grantee = 'BF_MCP_EVIDENCE_ROLE'
     and (grantable<>'NO' or not (
       owner = 'APP_DEMO'
       and (
         (privilege = 'SELECT' and table_name in (
           'BF_V_INCIDENT_TIMELINE', 'BF_V_ORDER_HEALTH',
           'BF_V_ERROR_PATTERN_SUMMARY'
         ))
         or (privilege = 'EXECUTE' and table_name = 'BF_INCIDENT_PKG')
       )
     ));
  if l_count <> 0 then
    raise_application_error(-20097, 'BF_MCP_EVIDENCE_ROLE has unexpected object privileges.');
  end if;

  select count(*)
    into l_count
    from dba_tab_privs
   where grantee = 'BF_MCP_EVIDENCE_ROLE';
  if l_count <> 4 then
    raise_application_error(-20098, 'BF_MCP_EVIDENCE_ROLE does not have exactly four object grants.');
  end if;

  dbms_output.put_line('BF_MCP_RO privilege contract: PASS');
end;
/
