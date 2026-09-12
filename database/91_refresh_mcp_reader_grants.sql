whenever sqlerror exit sql.sqlcode rollback
set serveroutput on

prompt Refreshing BF_MCP_EVIDENCE_ROLE object grants when the role exists

declare
  l_count pls_integer;
begin
  select count(*)
    into l_count
    from dba_roles
   where role = 'BF_MCP_EVIDENCE_ROLE';

  if l_count = 1 then
    execute immediate 'grant select on app_demo.bf_v_incident_timeline to bf_mcp_evidence_role';
    execute immediate 'grant select on app_demo.bf_v_order_health to bf_mcp_evidence_role';
    execute immediate 'grant select on app_demo.bf_v_error_pattern_summary to bf_mcp_evidence_role';
    execute immediate 'grant execute on app_demo.bf_incident_pkg to bf_mcp_evidence_role';
    dbms_output.put_line('BF_MCP_EVIDENCE_ROLE grants refreshed.');
  else
    raise_application_error(-20995, 'Expected existing BF_MCP_EVIDENCE_ROLE; refusing to recreate identity or silently skip grants.');
  end if;
end;
/
