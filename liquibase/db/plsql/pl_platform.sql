declare
    $if not dbms_db_version.ver_le_11 $then
    -- Oracle 11 versions does not have an Edition column in v$instance view
        myEdition       v$instance.edition%type;
        CRLF            constant string(2) := utl_tcp.CRLF;
    $end
    port_string VARCHAR2(1000);
    temp_cc_flag VARCHAR2(100);
    temp_sql VARCHAR2(1000);
begin

    select dbms_utility.port_string into port_string from dual;
    if INSTR(port_string, 'IBM')>0 then
        temp_cc_flag :=  'is_linux:false';
    else
        temp_cc_flag :=  'is_linux:true';
    end if;


    $if dbms_db_version.ver_le_11 $then
        -- Oracle 11 versions does not have an Edition column in v$instance view
        temp_sql:= 'ALTER SESSION SET PLSQL_CCFLAGS =  "is_remote:false,' || temp_cc_flag || '"';
    $else
        select edition into myEdition from v$instance;
        if myEdition = 'EE' then
            temp_sql:=  'ALTER SESSION SET PLSQL_CCFLAGS =  "is_remote:false,' || temp_cc_flag || '"';
        else
            temp_sql:=  'ALTER SESSION SET PLSQL_CCFLAGS =  "is_remote:true,' || temp_cc_flag || '"';
        end if;
    $end

    EXECUTE IMMEDIATE temp_sql;
end;
/

create or replace package swms.platform as
    -- Note, we are assuming, for now, the AIX is running Oracle 11g or older,
    -- and Linux is running Oracle 12c or higher
    $if $$is_linux $then
        SWMS_PLATFORM_LINUX  constant boolean := true;
        SWMS_PLATFORM_AIX    constant boolean := false;
    $else
        SWMS_PLATFORM_LINUX  constant boolean := false;
        SWMS_PLATFORM_AIX    constant boolean := true;
    $end

    $IF $$is_remote $THEN 
        SWMS_REMOTE_DB constant boolean := true;
    $ELSE
        SWMS_REMOTE_DB constant boolean := false;
    $END

    function IsRemoteDB return number;
end platform;
/

CREATE OR REPLACE PACKAGE BODY SWMS.PLATFORM IS
    FUNCTION IsRemoteDB RETURN NUMBER IS
    BEGIN
        IF SWMS_REMOTE_DB THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    END;
END;
/

show errors;
grant execute on swms.platform to swms_user;
create or replace public synonym platform for swms.platform;
