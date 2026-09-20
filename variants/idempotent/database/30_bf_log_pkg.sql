prompt Creating BF_LOG_PKG

create or replace package bf_log_pkg authid definer as
  function new_correlation_id return varchar2;

  procedure log_access(
    p_application_id  in number,
    p_page_id         in number,
    p_session_id      in varchar2,
    p_request         in varchar2,
    p_app_user        in varchar2,
    p_request_url     in varchar2,
    p_correlation_id  in varchar2,
    p_order_id        in number default null
  );

  procedure log_debug(
    p_level           in varchar2,
    p_component       in varchar2,
    p_message         in varchar2,
    p_context_json    in clob default null,
    p_session_id      in varchar2 default null,
    p_correlation_id  in varchar2 default null,
    p_order_id        in number default null
  );

  procedure log_error(
    p_sql_code        in number,
    p_sql_error       in varchar2,
    p_error_stack     in clob,
    p_error_backtrace in clob,
    p_page_id         in number default null,
    p_action_name     in varchar2 default null,
    p_session_id      in varchar2 default null,
    p_order_id        in number default null,
    p_correlation_id  in varchar2 default null
  );

  procedure log_integration(
    p_endpoint         in varchar2,
    p_http_status      in number,
    p_business_code    in varchar2,
    p_business_message in varchar2,
    p_payload_hash     in varchar2,
    p_response_excerpt in varchar2,
    p_correlation_id   in varchar2,
    p_order_id         in number default null,
    p_session_id       in varchar2 default null
  );
end bf_log_pkg;
/

create or replace package body bf_log_pkg as
  function has_apex_session return boolean is
  begin
    return sys_context('APEX$SESSION', 'APP_SESSION') is not null;
  exception
    when others then
      return false;
  end has_apex_session;

  function new_correlation_id return varchar2 is
  begin
    return lower(rawtohex(sys_guid()));
  end new_correlation_id;

  procedure log_access(
    p_application_id  in number,
    p_page_id         in number,
    p_session_id      in varchar2,
    p_request         in varchar2,
    p_app_user        in varchar2,
    p_request_url     in varchar2,
    p_correlation_id  in varchar2,
    p_order_id        in number default null
  ) is
    pragma autonomous_transaction;
  begin
    insert into bf_access_log (
      application_id, page_id, apex_session_id, request_value, app_user,
      request_url, correlation_id, order_id
    ) values (
      p_application_id, p_page_id, p_session_id, substr(p_request, 1, 255),
      substr(p_app_user, 1, 255), substr(p_request_url, 1, 2000),
      substr(p_correlation_id, 1, 64), p_order_id
    );
    commit;
  exception
    when others then
      rollback;
  end log_access;

  procedure log_debug(
    p_level           in varchar2,
    p_component       in varchar2,
    p_message         in varchar2,
    p_context_json    in clob default null,
    p_session_id      in varchar2 default null,
    p_correlation_id  in varchar2 default null,
    p_order_id        in number default null
  ) is
    pragma autonomous_transaction;
    l_level varchar2(10 char) := upper(coalesce(p_level, 'INFO'));
  begin
    if l_level not in ('TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR') then
      l_level := 'INFO';
    end if;

    insert into bf_debug_event (
      log_level, component_name, message_text, context_json,
      apex_session_id, correlation_id, order_id
    ) values (
      l_level, substr(p_component, 1, 255), substr(p_message, 1, 4000),
      p_context_json, substr(p_session_id, 1, 64),
      substr(p_correlation_id, 1, 64), p_order_id
    );

    -- The optional APEX debug sink must not roll back the factual evidence.
    commit;
    if has_apex_session then
      if l_level = 'ERROR' then
        apex_debug.error('%s', substr(p_message, 1, 4000));
      else
        apex_debug.message('%s', substr(p_message, 1, 4000));
      end if;
    end if;
    commit;
  exception
    when others then
      rollback;
  end log_debug;

  procedure log_error(
    p_sql_code        in number,
    p_sql_error       in varchar2,
    p_error_stack     in clob,
    p_error_backtrace in clob,
    p_page_id         in number default null,
    p_action_name     in varchar2 default null,
    p_session_id      in varchar2 default null,
    p_order_id        in number default null,
    p_correlation_id  in varchar2 default null
  ) is
    pragma autonomous_transaction;
  begin
    insert into bf_error_log (
      sql_code, sql_error_message, error_stack, error_backtrace,
      page_id, action_name, apex_session_id, order_id, correlation_id
    ) values (
      p_sql_code, substr(p_sql_error, 1, 4000), p_error_stack, p_error_backtrace,
      p_page_id, substr(p_action_name, 1, 255), substr(p_session_id, 1, 64),
      p_order_id, substr(p_correlation_id, 1, 64)
    );

    commit;
    if has_apex_session then
      apex_debug.error('%s', substr(p_sql_error, 1, 4000));
    end if;
    commit;
  exception
    when others then
      rollback;
  end log_error;

  procedure log_integration(
    p_endpoint         in varchar2,
    p_http_status      in number,
    p_business_code    in varchar2,
    p_business_message in varchar2,
    p_payload_hash     in varchar2,
    p_response_excerpt in varchar2,
    p_correlation_id   in varchar2,
    p_order_id         in number default null,
    p_session_id       in varchar2 default null
  ) is
    pragma autonomous_transaction;
  begin
    insert into bf_integration_log (
      endpoint, http_status, business_code, business_message, payload_hash,
      response_excerpt, correlation_id, order_id, apex_session_id
    ) values (
      substr(p_endpoint, 1, 500), p_http_status, substr(p_business_code, 1, 60),
      substr(p_business_message, 1, 2000), substr(p_payload_hash, 1, 64),
      substr(p_response_excerpt, 1, 4000), substr(p_correlation_id, 1, 64),
      p_order_id, substr(p_session_id, 1, 64)
    );
    commit;
  exception
    when others then
      rollback;
  end log_integration;
end bf_log_pkg;
/
