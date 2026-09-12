-- Non-destructive installation into an EMPTY, explicitly cleared B2B namespace.
-- Never calls 00_drop_objects.sql and never compiles unrelated APP_DEMO objects.
whenever sqlerror exit sql.sqlcode rollback
set define off
set serveroutput on
alter session set current_schema=APP_DEMO;
declare l_count number;
begin
 select count(*) into l_count from dba_objects where owner='APP_DEMO'
  and object_name in ('BF_V_INCIDENT_TIMELINE','BF_V_ORDER_HEALTH','BF_V_ERROR_PATTERN_SUMMARY','BF_CART_PKG','BF_SUBMISSION_PKG','BF_SEED_PKG','BF_INCIDENT_PKG','BF_ORDER_PKG','BF_LAB_PKG','BF_LOG_PKG','BF_ORDER_ITEM','BF_LAB_ASSIGNMENT','BF_ORDER','BF_ORDER_INTENT','BF_LAB_CONFIG','BF_ACCESS_LOG','BF_DEBUG_EVENT','BF_ERROR_LOG','BF_INTEGRATION_LOG','BF_PRODUCT','BF_CUSTOMER');
 if l_count<>0 then raise_application_error(-20993,'Existing B2B objects: run the reviewed reconstruction workflow first'); end if;
end;
/
@@10_tables.sql
@@20_views.sql
@@30_bf_log_pkg.sql
@@61_bf_lab_pkg.sql
@@40_bf_order_pkg.sql
@@42_bf_cart_pkg.sql
@@50_bf_incident_pkg.sql
@@91_refresh_mcp_reader_grants.sql
begin bf_lab_pkg.seed_reference_data; commit; end;
/
@@verify.sql
@@92_verify_mcp_reader_security.sql
prompt New catalog installed. No purchases seeded. Application remains unavailable until approved import.
