create or replace procedure swms.plsql_chk_put 
  ( i_rec_id in swms.putawaylst.rec_id%type,
    i_pallet_id in swms.putawaylst.pallet_id%type,
    o_putaway_exist out boolean) as

  l_cursorid  integer;
  l_selectstmt  varchar2(600);
  l_putaway_put  putawaylst.putaway_put%type := 'Y';
  l_return_rec     integer;

  begin
    -- Open the cursor for processing.
    l_cursorid := DBMS_SQL.OPEN_CURSOR;
     
    -- Create strings.
    l_SelectStmt := 'Select putaway_put from whmove.putawaylst
		     where rec_id = :h_rec_id
		     and   pallet_id = :h_pallet_id' ;

    -- Parse the query.
    DBMS_SQL.PARSE(l_cursorid, l_SelectStmt, DBMS_SQL.V7);

    -- Bind the input variables.
    DBMS_SQL.BIND_VARIABLE(l_cursorid,':h_rec_id',i_rec_id);
    DBMS_SQL.BIND_VARIABLE(l_cursorid,':h_pallet_id',i_pallet_id);

    -- Define the output variables.
    DBMS_SQL.DEFINE_COLUMN(l_cursorid, 1 ,l_putaway_put, 1);

    -- Execute the statment
    l_return_rec := DBMS_SQL.EXECUTE_AND_FETCH(l_cursorid);
     DBMS_SQL.COLUMN_VALUE(l_cursorid, 1, l_putaway_put);

     /*
     insert into process_error
     (process_id,user_id,value_1,error_msg,process_date)
     values
     ('PLSQL',USER,'plsql_move_put_chk',
     'l_return_rec is '|| to_char(l_return_rec)
	      || ' l_putaway_put is '|| l_putaway_put, sysdate);
     */

     if l_return_rec = 0 then
	o_putaway_exist := FALSE;
     else
	o_putaway_exist := TRUE;
     end if;
    -- 
    DBMS_SQL.CLOSE_CURSOR(l_cursorid);
    commit;

    Exception when others then
       dbms_sql.close_cursor(l_cursorid);
       raise;
end plsql_chk_put;
/
