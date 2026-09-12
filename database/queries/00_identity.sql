-- Query-only diagnostic. No secrets or mutable calls.
select sys_context('USERENV','SESSION_USER') session_user,
       sys_context('USERENV','CURRENT_SCHEMA') current_schema,
       sys_context('USERENV','CLIENT_IDENTIFIER') client_identifier,
       sys_context('USERENV','MODULE') module,
       sys_context('USERENV','ACTION') action
  from dual;

select granted_role
  from user_role_privs
 order by granted_role
 fetch first 100 rows only;
