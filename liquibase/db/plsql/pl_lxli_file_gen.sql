CREATE OR REPLACE PACKAGE  SWMS.PL_LXLI_FILE_GEN
AS
  ---------------------------------------------------------------------------
  -- Package Name:
  --   PL_LXLI_FILE_GEN
  -- Description:
  --    This package generate files in /swms/data
  --    This package is called by trg_insupd_lxlisho_brow trigger.
  -- Modification History:
  --    Date     Designer Comments
  --    3/4/2016 aalb7675 Initial Version
  -- Procedure:
  --    lxli_generate_file
  --
  -- Description:
  --    This procedure process NEW status files
   -- Procedure:
  --    lxli_generate_fl_txt
  --
  -- Description:
  --    This procedure generate Forklift files in /swms/data/
  ---------------------------------------------------------------------------
  l_pkg_name varchar2(40):='PL_LXLI_FILE_GEN';
  l_path varchar2(20):='/swms/data/';
  PROCEDURE lxli_generate_fl_txt(
      p_seq LXLI_STAGING_FL_HEADER_OUT.SEQUENCE_NUMBER%type);

  PROCEDURE lxli_generate_ld_txt(
      p_seq LXLI_STAGING_LD_OUT.SEQUENCE_NUMBER%type);

  PROCEDURE lxli_generate_sl_txt(
      p_seq LXLI_STAGING_SL_OUT.SEQUENCE_NUMBER%type);

  PROCEDURE lxli_generate_file(i_seq_number in LXLI_STAGING_HDR_OUT.SEQUENCE_NUMBER%TYPE default null,i_lbr_func in LXLI_STAGING_HDR_OUT.LFUN_LBR_FUNC%TYPE default null);

  FUNCTION allow_to_reprocess(i_num_files IN NUMBER,  
                            i_user_session IN VARCHAR2,
                            o_error_msg OUT VARCHAR2) RETURN BOOLEAN;

  FUNCTION add_file(i_file IN VARCHAR2, i_file_content IN CLOB) RETURN PLS_INTEGER;

  ---------------------------------------------------------------------------
END PL_LXLI_FILE_GEN;
/
show errors
create or replace PACKAGE BODY PL_LXLI_FILE_GEN
IS
  ---------------------------------------------------------------------------
  -- Package Name:
  --   PL_LXLI_FILE_GEN
  -- Description:
  --    This package generate files in /swms/data
  --    This package is called by trg_insupd_lxlisho_brow.
  -- Modification History:
  --    Date     Designer Comments
  --   09/15/2016 aalb7675 Initial Version
  -- Procedure:
  --    lxli_generate_fl_txt
  --
  -- Description:
  --    This procedure generate Forklift files in /swms/data/
  ---------------------------------------------------------------------------
  l_object_name   VARCHAR2(150);
  l_error_code    VARCHAR2(200);
  l_error_msg     VARCHAR2(4000);
  l_message       VARCHAR2(4000);

PROCEDURE lxli_generate_file(
      i_seq_number IN LXLI_STAGING_HDR_OUT.SEQUENCE_NUMBER%TYPE DEFAULT NULL,
      i_lbr_func   IN LXLI_STAGING_HDR_OUT.LFUN_LBR_FUNC%TYPE DEFAULT NULL)
    IS
        l_seq LXLI_STAGING_HDR_OUT.SEQUENCE_NUMBER%type;
        CURSOR c_unprocessed_files
        IS
            SELECT SEQUENCE_NUMBER,
                LFUN_LBR_FUNC
            FROM LXLI_STAGING_HDR_OUT
            WHERE SEQUENCE_NUMBER = NVL(i_seq_number,SEQUENCE_NUMBER)
            AND LFUN_LBR_FUNC     = NVL(i_lbr_func,LFUN_LBR_FUNC);
    BEGIN
        l_object_name:= l_pkg_name ||'.'|| 'lxli_generate_file';
        FOR i IN c_unprocessed_files LOOP
            l_seq             :=nvl(i.SEQUENCE_NUMBER,0);
            IF i.LFUN_LBR_FUNC ='FL' THEN
                lxli_generate_fl_txt(i.SEQUENCE_NUMBER);
            elsif i.LFUN_LBR_FUNC ='LD' THEN
                lxli_generate_ld_txt(i.SEQUENCE_NUMBER);
            elsif i.LFUN_LBR_FUNC ='SL' THEN
                lxli_generate_sl_txt(i.SEQUENCE_NUMBER);
            END IF;
        END LOOP;
    EXCEPTION
    WHEN OTHERS THEN
        UPDATE LXLI_STAGING_HDR_OUT
        SET record_status    = 'F'
        WHERE sequence_number=l_seq;
        l_error_code:= SQLCODE;
        l_error_msg := SUBSTR(SQLERRM,1,4000);
        l_message := l_object_name || ':  Failed to generate file, sequence_number = '||l_seq;
        pl_log.ins_msg('FATAL', l_object_name, l_message, l_error_code, l_error_msg);
        COMMIT;
END lxli_generate_file;

PROCEDURE lxli_generate_fl_txt(
    p_seq LXLI_STAGING_FL_HEADER_OUT.SEQUENCE_NUMBER%type)
    IS
        file_gen_exception EXCEPTION;
        p_file utl_file.file_type;
        L_FILE_NAME LXLI_STAGING_HDR_OUT.FILE_NAME%TYPE;
        l_RECORD_STATUS LXLI_STAGING_HDR_OUT.RECORD_STATUS%TYPE;
        l_seq LXLI_STAGING_HDR_OUT.SEQUENCE_NUMBER%type;
        $if swms.platform.SWMS_REMOTE_DB $then
            file_cache_id   NUMBER;
            v_clob          CLOB;
            v_result        VARCHAR2(4000);
        $end
        CURSOR c_lxli_fk
        IS
            SELECT DATA_STRING
            FROM
                (SELECT 'H' AS FLAG ,
                HDR_LINE_NUMBER,
                0 AS LINE_NUMBER,
                DATA_STRING
                FROM LXLI_STAGING_FL_HEADER_OUT
                WHERE SEQUENCE_NUMBER = p_seq
            UNION
            SELECT 'I' AS FLAG,
                D.HDR_LINE_NUMBER,
                D.LINE_NUMBER,
                D.DATA_STRING
            FROM LXLI_STAGING_FL_HEADER_OUT H ,
                LXLI_STAGING_FL_INV_OUT D
            WHERE H.SEQUENCE_NUMBER =p_seq
            AND H.SEQUENCE_NUMBER   = D.SEQUENCE_NUMBER
            AND H.HDR_LINE_NUMBER   =D.HDR_LINE_NUMBER
            UNION
            SELECT 'H',1,-1,'H' FROM DUAL
            UNION
            SELECT 'I',1,0,'I' FROM DUAL
                )
            ORDER BY FLAG,
                HDR_LINE_NUMBER,
                LINE_NUMBER;
    BEGIN
        l_seq:=nvl(p_seq,0);
        l_object_name:= l_pkg_name ||'.'|| 'lxli_generate_fl_txt';
        BEGIN
            SELECT FILE_NAME,
            RECORD_STATUS
            INTO L_FILE_NAME,
            l_RECORD_STATUS
            FROM LXLI_STAGING_HDR_OUT
            WHERE SEQUENCE_NUMBER= p_seq ;
        EXCEPTION
        WHEN OTHERS THEN
            l_error_code:= SQLCODE;
            l_error_msg := SUBSTR(SQLERRM,1,4000);
            raise file_gen_exception;
        END;
        BEGIN
        $if swms.platform.SWMS_REMOTE_DB $then
            FOR r_lxli_fk IN c_lxli_fk LOOP 
                v_clob := v_clob || TO_CLOB(r_lxli_fk.data_string || ','); 
            END LOOP;
            file_cache_id := PL_LXLI_FILE_GEN.add_file(L_FILE_NAME, v_clob);
            IF file_cache_id IS NULL THEN
                l_error_code:= 500;
                l_error_msg := 'Lxli file creation by SWMS_JAVA_TOOL via RUST API failed';
                RAISE file_gen_exception;
            END IF;
        $else
            p_file:= utl_file.fopen('LXLI_DIR', l_path || L_FILE_NAME, 'W');
            FOR r_lxli_fk IN c_lxli_fk LOOP
                UTL_FILE.PUT_LINE(p_file,r_lxli_fk.DATA_STRING);
            END LOOP;
            utl_file.fclose(p_file);
            EXCEPTION
            WHEN utl_file.invalid_path THEN
                l_error_code:= SQLCODE;
                l_error_msg := SUBSTR(SQLERRM,1,4000);
                raise file_gen_exception;
            WHEN OTHERS THEN
                l_error_code:= SQLCODE;
                l_error_msg := SUBSTR(SQLERRM,1,4000);
                raise file_gen_exception;
        $end
        END;
        UPDATE LXLI_STAGING_HDR_OUT
        SET record_status    = 'S'
        WHERE sequence_number=p_seq;
        COMMIT;
    EXCEPTION
    WHEN file_gen_exception THEN
        UPDATE LXLI_STAGING_HDR_OUT
        SET record_status    = 'F'
        WHERE sequence_number=l_seq;
        l_message := l_object_name || ':  Failed to generate file, sequence_number = '||l_seq;
        pl_log.ins_msg('FATAL', l_object_name, l_message, l_error_code, l_error_msg);
        COMMIT;
    WHEN OTHERS THEN
        UPDATE LXLI_STAGING_HDR_OUT
        SET record_status    = 'F'
        WHERE sequence_number=l_seq;
        l_error_code:= SQLCODE;
        l_error_msg := SUBSTR(SQLERRM,1,4000);
        l_message := l_object_name || ':  Failed to generate file, sequence_number = '||l_seq;
        pl_log.ins_msg('FATAL', l_object_name, l_message, l_error_code, l_error_msg);
        COMMIT;
END lxli_generate_fl_txt;

PROCEDURE lxli_generate_ld_txt(
    p_seq LXLI_STAGING_LD_OUT.SEQUENCE_NUMBER%type)
    IS
        file_gen_exception EXCEPTION;
        p_file utl_file.file_type;
        L_FILE_NAME LXLI_STAGING_HDR_OUT.FILE_NAME%TYPE;
        l_RECORD_STATUS LXLI_STAGING_HDR_OUT.RECORD_STATUS%TYPE;
        l_seq LXLI_STAGING_HDR_OUT.SEQUENCE_NUMBER%type;
        $if swms.platform.SWMS_REMOTE_DB $then
            file_cache_id   NUMBER;
            v_clob          CLOB;
            v_result        VARCHAR2(4000);
        $end
        CURSOR c_lxli_ld
        IS
            SELECT DATA_STRING
            FROM LXLI_STAGING_LD_OUT
            WHERE SEQUENCE_NUMBER =p_seq
            ORDER BY ACTL_START_TIME;
        BEGIN
        l_seq:=nvl(p_seq,0);
        l_object_name:= l_pkg_name ||'.'|| 'lxli_generate_ld_txt';
            BEGIN
                SELECT FILE_NAME,
                RECORD_STATUS
                INTO L_FILE_NAME,
                l_RECORD_STATUS
                FROM LXLI_STAGING_HDR_OUT
                WHERE SEQUENCE_NUMBER= p_seq ;
            EXCEPTION
            WHEN OTHERS THEN
                l_error_code:= SQLCODE;
                l_error_msg := SUBSTR(SQLERRM,1,4000);
                raise file_gen_exception;
            END;
            BEGIN
                $if swms.platform.SWMS_REMOTE_DB $then
                    FOR r_lxli_ld IN c_lxli_ld LOOP 
                        v_clob := v_clob || TO_CLOB(r_lxli_ld.data_string || ','); 
                    END LOOP;
                    file_cache_id := PL_LXLI_FILE_GEN.add_file(L_FILE_NAME, v_clob);
                    IF file_cache_id IS NULL THEN
                        l_error_code:= 500;
                        l_error_msg := 'Lxli file creation by SWMS_JAVA_TOOL via RUST API failed';
                        RAISE file_gen_exception;
                    END IF;
                $else
                    p_file:= utl_file.fopen('LXLI_DIR', l_path || L_FILE_NAME, 'W');
                    FOR r_lxli_ld IN c_lxli_ld  LOOP
                        UTL_FILE.PUT_LINE(p_file,r_lxli_ld.DATA_STRING);
                    END LOOP;
                    utl_file.fclose(p_file);
                    EXCEPTION
                    WHEN utl_file.invalid_path THEN
                        l_error_code:= SQLCODE;
                        l_error_msg := SUBSTR(SQLERRM,1,4000);
                        raise file_gen_exception;
                    WHEN OTHERS THEN
                        l_error_code:= SQLCODE;
                        l_error_msg := SUBSTR(SQLERRM,1,4000);
                        raise file_gen_exception;
                $end
            END;
            UPDATE LXLI_STAGING_HDR_OUT
            SET record_status    = 'S'
            WHERE sequence_number=p_seq;
            COMMIT;
        EXCEPTION
            WHEN file_gen_exception THEN
                UPDATE LXLI_STAGING_HDR_OUT
                SET record_status    = 'F'
                WHERE sequence_number=l_seq;
                l_message := l_object_name || ':  Failed to generate file, sequence_number = '||l_seq;
                pl_log.ins_msg('FATAL', l_object_name, l_message, l_error_code, l_error_msg);
                COMMIT;
            WHEN OTHERS THEN
                UPDATE LXLI_STAGING_HDR_OUT
                SET record_status    = 'F'
                WHERE sequence_number=l_seq;
                l_error_code:= SQLCODE;
                l_error_msg := SUBSTR(SQLERRM,1,4000);
                l_message := l_object_name || ':  Failed to generate file, sequence_number = '||l_seq;
                pl_log.ins_msg('FATAL', l_object_name, l_message, l_error_code, l_error_msg);
                COMMIT;
END lxli_generate_ld_txt;

PROCEDURE lxli_generate_sl_txt(
      p_seq LXLI_STAGING_SL_OUT.SEQUENCE_NUMBER%type)
    IS
        file_gen_exception EXCEPTION;
        p_file utl_file.file_type;
        L_FILE_NAME LXLI_STAGING_HDR_OUT.FILE_NAME%TYPE;
        l_RECORD_STATUS LXLI_STAGING_HDR_OUT.RECORD_STATUS%TYPE;
        l_seq LXLI_STAGING_HDR_OUT.SEQUENCE_NUMBER%type;
        $if swms.platform.SWMS_REMOTE_DB $then
            file_cache_id   NUMBER;
            v_clob          CLOB;
            v_result        VARCHAR2(4000);
        $end
        CURSOR c_lxli_sl
            IS
            SELECT DATA_STRING
            FROM LXLI_STAGING_SL_OUT
            WHERE SEQUENCE_NUMBER = p_seq
            ORDER BY BATCH_NO, MULTI_HOME_SEQ, PIK_PATH;
    BEGIN
        l_seq:=nvl(p_seq,0);
        l_object_name:= l_pkg_name ||'.'|| 'lxli_generate_sl_txt';
        BEGIN
            SELECT FILE_NAME,
                RECORD_STATUS
            INTO L_FILE_NAME,
                l_RECORD_STATUS
            FROM LXLI_STAGING_HDR_OUT
            WHERE SEQUENCE_NUMBER = p_seq ;
        EXCEPTION
            WHEN OTHERS THEN
            l_error_code:= SQLCODE;
            l_error_msg := SUBSTR(SQLERRM,1,4000);
            raise file_gen_exception;
        END;
        BEGIN
        $if swms.platform.SWMS_REMOTE_DB $then
            FOR r_lxli_sl IN c_lxli_sl LOOP 
                v_clob := v_clob || TO_CLOB(r_lxli_sl.data_string || ','); 
            END LOOP;
            file_cache_id := PL_LXLI_FILE_GEN.add_file(L_FILE_NAME, v_clob);
            IF file_cache_id IS NULL THEN
                l_error_code:= 500;
                l_error_msg := 'Lxli file creation by SWMS_JAVA_TOOL via RUST API failed';
                RAISE file_gen_exception;
            END IF;
        $else
            p_file := utl_file.fopen('LXLI_DIR', l_path || L_FILE_NAME, 'W');
            FOR r_lxli_sl IN c_lxli_sl  LOOP
                UTL_FILE.PUT_LINE(p_file, r_lxli_sl.DATA_STRING);
            END LOOP;
            utl_file.fclose(p_file);
            EXCEPTION
            WHEN utl_file.invalid_path THEN
                l_error_code:= SQLCODE;
                l_error_msg := SUBSTR(SQLERRM,1,4000);
                raise file_gen_exception;
            WHEN OTHERS THEN
                l_error_code:= SQLCODE;
                l_error_msg := SUBSTR(SQLERRM,1,4000);
                raise file_gen_exception;
        $end
        END;
        UPDATE LXLI_STAGING_HDR_OUT
        SET record_status    = 'S'
        WHERE sequence_number=p_seq;
        COMMIT;
    EXCEPTION
    WHEN file_gen_exception THEN
        UPDATE LXLI_STAGING_HDR_OUT
        SET record_status    = 'F'
        WHERE sequence_number=l_seq;
        l_message := l_object_name || ':  Failed to generate file, sequence_number = '||l_seq;
        pl_log.ins_msg('FATAL', l_object_name, l_message, l_error_code, l_error_msg);
        COMMIT;
    WHEN OTHERS THEN
        UPDATE LXLI_STAGING_HDR_OUT
        SET record_status    = 'F'
        WHERE sequence_number=l_seq;
        l_error_code:= SQLCODE;
        l_error_msg := SUBSTR(SQLERRM,1,4000);
        l_message := l_object_name || ':  Failed to generate file, sequence_number = '||l_seq;
        pl_log.ins_msg('FATAL', l_object_name, l_message, l_error_code, l_error_msg);
        COMMIT;
END lxli_generate_sl_txt;

FUNCTION allow_to_reprocess(i_num_files IN NUMBER,
                            i_user_session IN VARCHAR2,
                            o_error_msg OUT VARCHAR2)
  RETURN BOOLEAN IS

     EARLIEST_ALLOWED_TIME CONSTANT VARCHAR2(20) := '06:00';
     EARLIEST_ALLOWED_TIME_DISPLAY CONSTANT VARCHAR2(20) := '6:00 AM';
     LATEST_ALLOWED_TIME CONSTANT VARCHAR2(20) := '18:00';
     LATEST_ALLOWED_TIME_DISPLAY CONSTANT VARCHAR2(20) := '6:00 PM';
     MIN_ELAPSED_MINUTES_ALLOWED CONSTANT NUMBER := 60;
     MAX_NUM_FILES CONSTANT NUMBER := 25;
     APPLICATION_FUNCTION CONSTANT swms_audit.application_func%type := 'LXLI REPROCESS';
     time_of_day VARCHAR2(20);
     --last_reprocess_time DATE;
     --minutes_elapsed NUMBER;
     --minutes_to_wait NUMBER;
     total_files_in_period NUMBER := 0;   -- total # of files reprocessed in a period of, for example, 60 minutes.
     addl_files_allowed NUMBER := 0;
     addl_msg VARCHAR2(100) := NULL;

     CURSOR c_swms_audit IS
        SELECT old_val_txt 
        FROM swms_audit
        WHERE APPLICATION_FUNC = APPLICATION_FUNCTION
           AND (sysdate - add_date) *24*60 <= MIN_ELAPSED_MINUTES_ALLOWED;

  BEGIN
     o_error_msg := NULL;
     IF i_num_files IS NULL OR TO_NUMBER(i_num_files) <= 0 THEN
        o_error_msg := 'Invalid number: The number of files was null or <= 0';
        RETURN FALSE;
     END IF;
     BEGIN
        SELECT TO_CHAR(sysdate, 'HH24:MI') INTO time_of_day from dual;
        IF time_of_day NOT BETWEEN EARLIEST_ALLOWED_TIME AND LATEST_ALLOWED_TIME THEN
           o_error_msg := 'You may reprocess batches only between ' || EARLIEST_ALLOWED_TIME_DISPLAY || ' and ' || LATEST_ALLOWED_TIME_DISPLAY;
           RETURN FALSE;
        END IF;

     EXCEPTION
        WHEN OTHERS THEN
           o_error_msg := 'Unexpected error while getting time from dual';
           RETURN FALSE;

     END;
     /*
     BEGIN
        SELECT NVL(MAX(add_date), sysdate-1) INTO last_reprocess_time FROM swms_audit WHERE application_func = APPLICATION_FUNCTION;

     EXCEPTION
        WHEN OTHERS THEN
           o_error_msg := 'Unexpected error while querying swms_audit';
           RETURN FALSE;
     END;   
     minutes_elapsed := (sysdate - last_reprocess_time) *24*60;
     */
     FOR sa_rec in c_swms_audit LOOP
        total_files_in_period := total_files_in_period + TO_NUMBER(NVL(sa_rec.old_val_txt, 0));
     END LOOP;

     IF total_files_in_period + i_num_files <= MAX_NUM_FILES THEN
        BEGIN
           INSERT INTO swms_audit(audit_seq_no, user_id, user_session, add_date, application_func, program_name, old_val_txt)
                VALUES(swms_audit_seq.nextval, replace(USER,'OPS$',null), i_user_session, sysdate, APPLICATION_FUNCTION, l_pkg_name, TO_CHAR(i_num_files));

           COMMIT;
           RETURN TRUE;

        EXCEPTION
           WHEN OTHERS THEN
              o_error_msg := 'Unexpected error while inserting into swms_audit';
              RETURN FALSE;
        END;
     ELSE
        --minutes_to_wait := MIN_ELAPSED_MINUTES_ALLOWED - minutes_elapsed;        
        o_error_msg := 'You have already reprocessed ' || total_files_in_period || ' files in the last ' || MIN_ELAPSED_MINUTES_ALLOWED || 
               ' minutes. Maximum (files) allowed is ' || MAX_NUM_FILES || '.';
        IF total_files_in_period < MAX_NUM_FILES THEN
           addl_files_allowed := MAX_NUM_FILES - total_files_in_period;
           addl_msg := ' You may reprocess only ' || addl_files_allowed || ' more files at this time.';
           o_error_msg :=  o_error_msg || addl_msg;        
        END IF;
        RETURN FALSE;
     END IF;

     RETURN TRUE;

END allow_to_reprocess;

-- FOR RDS MIGRATION
FUNCTION add_file (
        i_file           IN   VARCHAR2,
        i_file_content   IN   CLOB
    ) RETURN PLS_INTEGER AS
    $if swms.platform.SWMS_REMOTE_DB $then
        id NUMBER;
        endpoint VARCHAR2 (20);
        json_in VARCHAR2 (500);
        outvar  VARCHAR2 (500);
        result  VARCHAR2 (500);
        jo      JSON_OBJECT_T;
        rc      NUMBER;
        LXLI_FILE_CREATION_FAILED  EXCEPTION;
        POST_REQUEST_FAILED EXCEPTION;
        INSERT_FAIL EXCEPTION;
    $end
    BEGIN
    $if swms.platform.SWMS_REMOTE_DB $then
        BEGIN
            INSERT INTO file_cache (
                file_path,
                file_data,
                add_date
            ) VALUES ('/swms/data/' || i_file, i_file_content, CURRENT_DATE) 
            RETURNING id INTO id;
            IF id IS NULL THEN
                RAISE INSERT_FAIL;
            END IF;
            COMMIT;
        END;
        
        -- call the rest API
      json_in := '{'
        || '"command":"source /swms/base/bin/java_tool_profile;' 
        || 'java -Djava.security.egd=file:/dev/./urandom -Dsecurerandom.source=file:/dev/./urandom -jar /swms/base/bin/swms-java-tools-1.0-SNAPSHOT.jar CREATE_FILE ' || id || '"' 
        || '}';
      
      endpoint:='execute';
      rc:=PL_CALL_REST.call_rest_post(json_in, endpoint, outvar);
      
      IF rc != 0 THEN
        RAISE POST_REQUEST_FAILED;
      END IF;

      
      jo := JSON_OBJECT_T.parse(outvar);
      result:=jo.get_string('result');
      
      
      IF REPLACE(result, CHR(10), '') != 'success' THEN
        RAISE LXLI_FILE_CREATION_FAILED;
      END IF;
      pl_text_log.ins_msg('INFO', 'PL_LXLI_FILE_GEN', 'ADD_FILE success', NULL, NULL);
      return id;
    EXCEPTION
      WHEN POST_REQUEST_FAILED THEN
        pl_text_log.ins_msg('FATAL', 'PL_LXLI_FILE_GEN', 'ADD_FILE POST Request Failed. rc=[' || rc || ']', NULL, NULL);
        RETURN NULL;
      WHEN LXLI_FILE_CREATION_FAILED THEN
        pl_text_log.ins_msg('FATAL', 'PL_LXLI_FILE_GEN', 'Failed creating lxli file: ' || i_file || ' at /swms/data. return=[' || result || ']', NULL, NULL);
        RETURN NULL;
      WHEN OTHERS THEN
        pl_text_log.ins_msg('FATAL', 'PL_LXLI_FILE_GEN', 'Funtion add_file within pl_lxli_file_gen failed. failed lxli file=[' || i_file || ']', NULL, NULL);
        RETURN NULL;
    $else
      DBMS_OUTPUT.PUT_LINE('add file function is only required when DB is remote');  
    $end
    END add_file;
END PL_LXLI_FILE_GEN;
/
Show Errors

CREATE OR REPLACE PUBLIC SYNONYM PL_LXLI_FILE_GEN FOR swms.PL_LXLI_FILE_GEN;
GRANT EXECUTE ON swms.PL_LXLI_FILE_GEN TO swms_user;
begin
$if swms.platform.SWMS_REMOTE_DB $then
    dbms_output.put_line  ('No Directry creation within RDS is needed'); 
$else
    EXECUTE IMMEDIATE 'CREATE or REPLACE DIRECTORY lxli_dir AS ''/swms/data''';
    EXECUTE IMMEDIATE 'GRANT READ ON DIRECTORY lxli_dir TO PUBLIC';
$end
end;
/
show errors;

