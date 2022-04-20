REM set verify off
set serveroutput on size 100000
DECLARE 
  machine	VARCHAR2(30);
  dummy		VARCHAR2(1);
BEGIN
  SELECT SUBSTR (RTRIM ( SUBSTR (program, 8, (INSTR (program, '(') - 8))), 1, 30)
    INTO machine
    FROM v$process
   WHERE (username = 'oracle' or program like 'oracle%')
     AND ROWNUM = 1;

  delete from rf_client_version
         where application = 'STS';

  insert into rf_client_version
        values (machine, 'MC9060', 'STS', '4.0.1.0', sysdate,USER);

  insert into rf_client_version
        values (machine, 'MC9590', 'STS', '4.0.0.5', sysdate,USER);

  insert into rf_client_version
        values (machine, 'MC9090', 'STS', '4.0.0.7', sysdate,USER);

if substr(machine,length(machine),1) in ('a','e') then

  if substr(machine,length(machine),1) = 'a' then

    machine := substr(machine, 1, length(machine) - 1) || 'e';
  else
    machine := substr(machine, 1, length(machine) - 1) || 'a';
  end if;

  insert into rf_client_version
        values (machine, 'MC9060', 'STS', '4.0.1.0', sysdate,USER);
  insert into rf_client_version
        values (machine, 'MC9590', 'STS', '4.0.0.5', sysdate,USER);
  insert into rf_client_version
        values (machine, 'MC9090', 'STS', '4.0.0.7', sysdate,USER);
end if;

commit;

END;
/
select * from rf_client_version where application='STS';
exit

