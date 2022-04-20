CREATE OR REPLACE  PACKAGE "SWMS"."PL_UTILITY"  as

  cursor create_synonym_cur is
  select 'CREATE PUBLIC SYNONYM ' || o.object_name || ' FOR SWMS.' || o.object_name
         sql_stmt
    from all_synonyms s, all_objects o
   where s.table_name(+) = o.object_name
     and s.owner(+) = 'PUBLIC'
     and s.table_name is null
     and o.owner = 'SWMS'
     and o.object_type in ('PACKAGE','TABLE','VIEW','SEQUENCE',
                           'FUNCTION','PROCEDURE','LIBRARY');
  cursor grant_user_cur_1 is
  select 'GRANT SELECT, INSERT, UPDATE, DELETE ON ' || o.object_name || ' TO SWMS_USER'
         sql_stmt
    from all_tab_privs p, all_objects o
   where p.table_name(+) = o.object_name
     and p.grantee(+) = 'SWMS_USER'
     and p.table_schema(+) = 'SWMS'
     and p.table_name is null
     and o.owner = 'SWMS'
     and o.object_type in ('TABLE','VIEW');

  cursor grant_user_cur_2 is
  select 'GRANT EXECUTE ON ' || o.object_name || ' TO SWMS_USER'
         sql_stmt
    from all_tab_privs p, all_objects o
   where p.table_name(+) = o.object_name
     and p.grantee(+) = 'SWMS_USER'
     and p.table_schema(+) = 'SWMS'
     and p.table_name is null
     and o.owner = 'SWMS'
     and o.object_name <> 'PL_UTILITY'
     and o.object_type in ('PACKAGE','FUNCTION','PROCEDURE','LIBRARY');

  cursor grant_user_cur_3 is
  select 'GRANT SELECT ON ' || o.object_name || ' TO SWMS_USER' sql_stmt
    from all_tab_privs p, all_objects o
   where p.table_name(+) = o.object_name
     and p.grantee(+) = 'SWMS_USER'
     and p.table_schema(+) = 'SWMS'
     and p.table_name is null
     and o.owner = 'SWMS'
     and o.object_type = 'SEQUENCE';

  cursor grant_viewer_cur_1 is
  select 'GRANT SELECT ON ' || o.object_name || ' TO SWMS_VIEWER' sql_stmt
    from all_tab_privs p, all_objects o
   where p.table_name(+) = o.object_name
     and p.grantee(+) = 'SWMS_VIEWER'
     and p.table_schema(+) = 'SWMS'
     and p.table_name is null
     and o.owner = 'SWMS'
     and o.object_type in ('TABLE','VIEW');

  cursor revoke_pub_cur is
  select 'REVOKE ' || p.privilege || ' ON ' || o.object_name || ' FROM PUBLIC'
         sql_stmt
    from all_tab_privs p, all_objects o
   where p.table_name = o.object_name
     and p.grantee = 'PUBLIC'
     and p.table_schema = 'SWMS'
     and o.owner = 'SWMS'
     and o.object_name <> 'PL_UTILITY'
     and o.object_type in ('PACKAGE','TABLE','VIEW','SEQUENCE','FUNCTION','PROCEDURE','LIBRARY');

  cursor revoke_user_cur_1 is
  select 'REVOKE ' || p.privilege || ' ON ' || o.object_name || ' FROM SWMS_USER'
         sql_stmt
    from all_tab_privs p, all_objects o
   where p.table_name = o.object_name
     and p.grantee = 'SWMS_USER'
     and p.table_schema = 'SWMS'
     and o.owner = 'SWMS'
     and o.object_type = 'SEQUENCE'
     and p.privilege = 'ALTER';

  cursor revoke_user_cur_2 is
  select 'REVOKE ' || p.privilege || ' ON ' || o.object_name || ' FROM SWMS_USER'
         sql_stmt
    from all_tab_privs p, all_objects o
   where p.table_name = o.object_name
     and p.grantee = 'SWMS_USER'
     and p.table_schema = 'SWMS'
     and o.owner = 'SWMS'
     and o.object_type = 'TABLE'
     and p.privilege IN ('ALTER','INDEX','REFERENCES');

  cursor revoke_viewer_cur_1 is
  select 'REVOKE ' || p.privilege || ' ON ' || o.object_name || ' FROM SWMS_VIEWER'
         sql_stmt
    from all_tab_privs p, all_objects o
   where p.table_name = o.object_name
     and p.grantee = 'SWMS_VIEWER'
     and p.table_schema = 'SWMS'
     and o.owner = 'SWMS'
     and o.object_type = 'SEQUENCE';

  cursor revoke_viewer_cur_2 is
  select 'REVOKE ' || p.privilege || ' ON ' || o.object_name || ' FROM SWMS_VIEWER'
         sql_stmt
    from all_tab_privs p, all_objects o
   where p.table_name = o.object_name
     and p.grantee = 'SWMS_VIEWER'
     and p.table_schema = 'SWMS'
     and o.owner = 'SWMS'
     and o.object_name <> 'PL_COMMON'
     and o.object_name <> 'PL_UTILITY'
     and o.object_type IN ('PACKAGE','FUNCTION','PROCEDURE','LIBRARY')
     and p.privilege = 'EXECUTE';

  success_cnt NUMBER;
  error_cnt NUMBER;

  function execute_ddl(i_sql_stmt VARCHAR2) return NUMBER;

  procedure verify_access;

  procedure kill_session(i_sid NUMBER);

/*
  procedure lock_allocate_unique(
    lockname IN VARCHAR2,
    lockhandle OUT VARCHAR2,
    expiration_secs IN INTEGER);

  function lock_request(
    id IN INTEGER,
    lockmode IN INTEGER,
    timeout IN INTEGER,
    release_on_commit IN BOOLEAN)
  return INTEGER;

  function lock_request(
    lockhandle IN VARCHAR2,
    lockmode IN INTEGER,
    timeout IN INTEGER,
    release_on_commit IN BOOLEAN)
  return INTEGER;

  function lock_convert(
    id IN INTEGER,
    lockmode IN INTEGER,
    timeout IN NUMBER)
  return INTEGER;

  function lock_convert(
    lockhandle IN VARCHAR2,
    lockmode IN INTEGER,
    timeout IN NUMBER)
  return INTEGER;

  function lock_release(
    id IN INTEGER)
  return INTEGER;

  function lock_release(
    lockhandle IN VARCHAR2)
  return INTEGER;

  procedure lock_sleep(
    seconds IN NUMBER);
*/
end pl_utility;
/

CREATE OR REPLACE  PACKAGE BODY "SWMS"."PL_UTILITY"  as

function execute_ddl(i_sql_stmt VARCHAR2) return NUMBER is
  errno NUMBER;
begin
  dbms_output.enable(1000000);
  dbms_output.put_line(CHR(10) || i_sql_stmt);
  execute immediate i_sql_stmt;
  dbms_output.put_line('Success');
  success_cnt := success_cnt + 1;
  return 0;
exception
  when others then
    errno := sqlcode;
    dbms_output.put_line('Error: ' || sqlerrm);
    error_cnt := error_cnt + 1;
    return (sqlcode);
end execute_ddl;

procedure verifY_access as
  retval NUMBER;
begin
  success_cnt := 0;
  error_cnt := 0;

  for sql_rec in create_synonym_cur loop
    retval := pl_utility.execute_ddl(sql_rec.sql_stmt);
  end loop;

  for sql_rec in grant_user_cur_1 loop
    retval := pl_utility.execute_ddl(sql_rec.sql_stmt);
  end loop;

  for sql_rec in grant_user_cur_2 loop
    retval := pl_utility.execute_ddl(sql_rec.sql_stmt);
  end loop;

  for sql_rec in grant_user_cur_3 loop
    retval := pl_utility.execute_ddl(sql_rec.sql_stmt);
  end loop;

  for sql_rec in grant_viewer_cur_1 loop
    retval := pl_utility.execute_ddl(sql_rec.sql_stmt);
  end loop;

  for sql_rec in revoke_pub_cur loop
    retval := pl_utility.execute_ddl(sql_rec.sql_stmt);
  end loop;

  for sql_rec in revoke_user_cur_1 loop
    retval := pl_utility.execute_ddl(sql_rec.sql_stmt);
  end loop;

  for sql_rec in revoke_user_cur_2 loop
    retval := pl_utility.execute_ddl(sql_rec.sql_stmt);
  end loop;

  for sql_rec in revoke_viewer_cur_1 loop
    retval := pl_utility.execute_ddl(sql_rec.sql_stmt);
  end loop;

  for sql_rec in revoke_viewer_cur_2 loop
    retval := pl_utility.execute_ddl(sql_rec.sql_stmt);
  end loop;

  dbms_output.put_line(CHR(10) || 'Success Count: ' || TO_CHAR(success_cnt));
  dbms_output.put_line('Error Count: ' || TO_CHAR(error_cnt));

end verify_access;

procedure kill_session(i_sid NUMBER) is
  retval NUMBER;
  user_name VARCHAR2(30);
  serial_no NUMBER;
begin
  SELECT USERNAME, SERIAL#
    INTO user_name, serial_no
    FROM V$SESSION
   WHERE SID = i_sid;
   
  if user_name is not null then
  	retval := pl_utility.execute_ddl('ALTER SYSTEM KILL SESSION ''' ||
  	          TO_CHAR(i_sid) || ',' || TO_CHAR(serial_no) || '''');
  	if retval = 0 then
	    dbms_output.put_line('SID ' || TO_CHAR(i_sid) || ' has been killed.');
    end if;
  else
	  dbms_output.put_line('SID cannot be killed.');
  end if;
exception
	when no_data_found then
	  dbms_output.put_line('SID does not exist.');
	when others then
	  dbms_output.put_line('SID=[' || TO_CHAR(i_sid) || ']  Error encountered: ' || SQLERRM);
end kill_session;

/*
procedure lock_allocate_unique(
  lockname VARCHAR2,
  lockhandle VARCHAR2,
  expiration_secs INTEGER) as
begin
  dbms_lock.allocate_unique(lockname, lockhandle, expiration_secs);
end lock_allocate_unique;

function lock_release(
  id INTEGER,
  lockmode INTEGER,
  timeout INTEGER,
  release_on_commit BOOLEAN) return INTEGER as
begin
  return(dbms_lock.release(id, lockmode, timeout, release_on_commit));
end lock_release;

function lock_release(
  lockhandle VARCHAR2,
  lockmode INTEGER,
  timeout INTEGER,
  release_on_commit BOOLEAN) return INTEGER as
begin
  return(dbms_lock.release(id, lockmode, timeout, release_on_commit));
end lock_release;
*/
end pl_utility;
/

