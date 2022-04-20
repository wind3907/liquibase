CREATE OR REPLACE PACKAGE  SWMS.PL_RF_PRINT_REPORT
AS
  ---------------------------------------------------------------------------
  -- Package Name:
  --   PL_RF_PRINT_REPORT
  -- Description:
  --    This package generates report content into a file from file cache table and triggers report printing functionalities
  ---------------------------------------------------------------------------
  l_pkg_name varchar2(40):='PL_RF_PRINT_REPORT';
  

  FUNCTION create_file(file_id IN NUMBER) RETURN NUMBER;

  FUNCTION create_file_11g(file_name IN VARCHAR2,
                       file_content IN CLOB
  ) RETURN NUMBER;

  FUNCTION execute_command (command IN VARCHAR2) RETURN VARCHAR2;

  ---------------------------------------------------------------------------
END PL_RF_PRINT_REPORT;
/
show errors
create or replace PACKAGE BODY PL_RF_PRINT_REPORT
IS

    FUNCTION create_file (
            file_id IN NUMBER
        ) RETURN NUMBER AS
        $if swms.platform.SWMS_REMOTE_DB $then
            command VARCHAR2(500);
            endpoint VARCHAR2 (20);
            json_in VARCHAR2 (500);
            outvar  VARCHAR2 (500);
            result  VARCHAR2 (500);
            jo      JSON_OBJECT_T;
            rc      NUMBER;
            REPORT_FILE_CREATION_FAILED  EXCEPTION;
            POST_REQUEST_FAILED EXCEPTION;
            INSERT_FAIL EXCEPTION;
        $end
        BEGIN
        $if swms.platform.SWMS_REMOTE_DB $then
                
            command := 'source /swms/base/bin/java_tool_profile;'
                || 'java -Djava.security.egd=file:/dev/./urandom -Dsecurerandom.source=file:/dev/./urandom -jar /swms/base/bin/swms-java-tools-1.0-SNAPSHOT.jar CREATE_FILE ' || file_id ;

            result:=PL_RF_PRINT_REPORT.execute_command(command);
            IF result is not null THEN
                RAISE REPORT_FILE_CREATION_FAILED;
            END IF;
            pl_text_log.ins_msg('INFO', l_pkg_name, 'create_file success',sqlcode,sqlerrm);
            return 0;
            EXCEPTION
            WHEN POST_REQUEST_FAILED THEN
                pl_text_log.ins_msg('FATAL', l_pkg_name, 'create_file POST Request Failed. rc=[' || rc || ']',sqlcode,sqlerrm);
                return -1;
            WHEN REPORT_FILE_CREATION_FAILED THEN
                pl_text_log.ins_msg('FATAL', l_pkg_name, 'Failed creating report file id: ' || file_id || '. return=[' || result || ']',sqlcode,sqlerrm);
                return -1;
            WHEN OTHERS THEN
                pl_text_log.ins_msg('FATAL', l_pkg_name, 'Funtion create_file within PL_RF_PRINT_REPORT failed. failed report file_id=[' || file_id || ']',sqlcode,sqlerrm);
                return -1;
        $else
            DBMS_OUTPUT.PUT_LINE('create file function is only required when DB is remote');  
        $end
    END create_file;

    FUNCTION create_file_11g (file_name IN VARCHAR2,
                              file_content IN CLOB
    ) RETURN NUMBER AS
       l_file    UTL_FILE.FILE_TYPE;
       l_buffer  VARCHAR2(32767);
       l_amount  BINARY_INTEGER := 32767;
       l_pos     INTEGER := 1;
    BEGIN
       l_file := UTL_FILE.fopen('REPORTS_DIR',file_name , 'w', 32767);

       LOOP
         DBMS_LOB.read (file_content, l_amount, l_pos, l_buffer);
         UTL_FILE.put(l_file, l_buffer);
         l_pos := l_pos + l_amount;
       END LOOP;
       RETURN 0;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
             pl_text_log.ins_msg('DEBUG', l_pkg_name, 'End of Loop for file writing=[' || file_name || ']',sqlcode,sqlerrm);
             UTL_FILE.fclose(l_file);
             RETURN 0;
         WHEN OTHERS THEN
             pl_text_log.ins_msg('FATAL', l_pkg_name, 'Funtion create_file within PL_RF_PRINT_REPORT failed. failed report file_name=[' || file_name || ']',sqlcode,sqlerrm);
             UTL_FILE.fclose(l_file);
             RETURN -1;
    END create_file_11g;


    FUNCTION execute_command (
            command in VARCHAR2
        ) RETURN VARCHAR2 AS
        $if swms.platform.SWMS_REMOTE_DB $then
            endpoint VARCHAR2 (20);
            json_in VARCHAR2 (500);
            outvar  VARCHAR2 (500);
            result  VARCHAR2 (500);
            jo      JSON_OBJECT_T;
            rc      NUMBER;
            REPORT_FILE_CREATION_FAILED  EXCEPTION;
            POST_REQUEST_FAILED EXCEPTION;
            INSERT_FAIL EXCEPTION;
        $end
        BEGIN
        $if swms.platform.SWMS_REMOTE_DB $then
                
            -- call the rest API
            json_in := '{'
                || '"command":"'||command|| '"'
                || '}';

            endpoint:='execute';
            rc:=PL_CALL_REST.call_rest_post(json_in, endpoint, outvar);

            IF rc != 0 THEN
                RAISE POST_REQUEST_FAILED;
            END IF;

            jo := JSON_OBJECT_T.parse(outvar);
            result:=jo.get_string('result');
            result:=REPLACE(result, CHR(10), '');
            pl_text_log.ins_msg('INFO', l_pkg_name, 'command execution success ['||result||']',sqlcode,sqlerrm);
            return result;
            EXCEPTION
            WHEN POST_REQUEST_FAILED THEN
                pl_text_log.ins_msg('FATAL', l_pkg_name, 'POST Request Failed. rc=[' || rc || ']',sqlcode,sqlerrm);
                RETURN 'error';
            WHEN OTHERS THEN
                pl_text_log.ins_msg('FATAL', l_pkg_name, 'Funtion execute_command within PL_RF_PRINT_REPORT failed.',sqlcode,sqlerrm);
                RETURN 'error';
        $else
            DBMS_OUTPUT.PUT_LINE('execute command function is only required when DB is remote');  
        $end
    END execute_command;

END PL_RF_PRINT_REPORT;
/
Show Errors

CREATE OR REPLACE PUBLIC SYNONYM PL_RF_PRINT_REPORT FOR swms.PL_RF_PRINT_REPORT;
GRANT EXECUTE ON swms.PL_RF_PRINT_REPORT TO swms_user;
begin
$if swms.platform.SWMS_REMOTE_DB $then
    dbms_output.put_line('No Directry creation within RDS is needed');
$else
    -- todo need higher user privileges to execute below
    EXECUTE IMMEDIATE 'CREATE or REPLACE DIRECTORY reports_dir AS ''/tmp/swms/reports/''';
    EXECUTE IMMEDIATE 'GRANT READ ON DIRECTORY reports_dir TO PUBLIC';
$end
end;
/
show errors;

