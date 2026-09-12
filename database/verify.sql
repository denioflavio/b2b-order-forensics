-- Clean-install verification. Run before test purchases; expected data is reference-only.
whenever sqlerror exit sql.sqlcode rollback
set serveroutput on
declare
 l_count number;
 procedure expect(p_actual number,p_expected number,p_label varchar2) is
 begin if p_actual<>p_expected then raise_application_error(-20994,p_label||': expected '||p_expected||', got '||p_actual); end if; end;
begin
 select count(*) into l_count from dba_objects where owner='APP_DEMO'
  and object_name in ('BF_V_INCIDENT_TIMELINE','BF_V_ORDER_HEALTH','BF_V_ERROR_PATTERN_SUMMARY','BF_CART_PKG','BF_SUBMISSION_PKG','BF_SEED_PKG','BF_INCIDENT_PKG','BF_ORDER_PKG','BF_LAB_PKG','BF_LOG_PKG','BF_ORDER_ITEM','BF_LAB_ASSIGNMENT','BF_ORDER','BF_ORDER_INTENT','BF_LAB_CONFIG','BF_ACCESS_LOG','BF_DEBUG_EVENT','BF_ERROR_LOG','BF_INTEGRATION_LOG','BF_PRODUCT','BF_CUSTOMER')
  and object_type in('TABLE','VIEW','PACKAGE','PACKAGE BODY');
 expect(l_count,24,'11 tables, 3 views, 5 package specifications and bodies');
 select count(*) into l_count from dba_objects where owner='APP_DEMO' and status<>'VALID'
  and object_name in ('BF_V_INCIDENT_TIMELINE','BF_V_ORDER_HEALTH','BF_V_ERROR_PATTERN_SUMMARY','BF_CART_PKG','BF_SUBMISSION_PKG','BF_SEED_PKG','BF_INCIDENT_PKG','BF_ORDER_PKG','BF_LAB_PKG','BF_LOG_PKG','BF_ORDER_ITEM','BF_LAB_ASSIGNMENT','BF_ORDER','BF_ORDER_INTENT','BF_LAB_CONFIG','BF_ACCESS_LOG','BF_DEBUG_EVENT','BF_ERROR_LOG','BF_INTEGRATION_LOG','BF_PRODUCT','BF_CUSTOMER');
 expect(l_count,0,'Invalid B2B objects');
 select count(*) into l_count from app_demo.bf_customer;
 expect(l_count,1,'Company');
 select count(*) into l_count from app_demo.bf_product where active_flag='Y'
  and brand in('Nuvyra','Orvexa','Aveniq');
 expect(l_count,8,'Active computer products');
 select count(*) into l_count from app_demo.bf_order;
 expect(l_count,0,'Initial purchases');
 select count(*) into l_count from app_demo.bf_order_intent;
 expect(l_count,0,'Initial intentions');
 select count(*) into l_count from app_demo.bf_lab_assignment;
 expect(l_count,0,'Initial assignments');
 select count(*) into l_count from app_demo.bf_lab_config where config_id=1 and selection_mode='RANDOM';
 expect(l_count,1,'Random configuration');
 select count(*) into l_count from dba_objects where owner='APP_DEMO'
  and object_name in('BF_SUBMISSION_PKG','BF_SEED_PKG','BF_ORDER_ATTACHMENT','BF_V_ATTACHMENT_DIAGNOSTIC');
 expect(l_count,0,'Legacy objects');
 select count(*) into l_count from dba_tab_columns where owner='APP_DEMO'
  and table_name in('BF_V_INCIDENT_TIMELINE','BF_V_ORDER_HEALTH','BF_V_ERROR_PATTERN_SUMMARY') and data_type='BLOB';
 expect(l_count,0,'BLOB columns exposed by evidence views');
 dbms_output.put_line('CLEAN_INSTALL_VERIFIED');
end;
/
