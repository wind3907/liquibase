DECLARE
        n_count                                 PLS_INTEGER;
        SQL_stmt                                VARCHAR2(2000 CHAR);
        v_column_exists                 NUMBER := 0;

BEGIN
        SELECT COUNT(*)
                INTO n_count
                FROM all_objects
                WHERE object_type       = 'TABLE'
                        AND owner               = 'SWMS'
                        AND object_name = 'MQ_QUEUE_OUT';

        IF N_COUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE('Table SWMS.MQ_QUEUE_OUT found, skipping recreation...');
        ELSE
                DBMS_OUTPUT.PUT_LINE('Table SWMS.MQ_QUEUE_OUT not found, creating now...');

                SQL_stmt :=
                    'CREATE TABLE SWMS.MQ_QUEUE_OUT ('
                    	|| 'SEQUENCE_NUMBER NUMBER(10,0) NOT NULL ENABLE, '
                    	|| 'QUEUE_NAME VARCHAR2(50 CHAR) NOT NULL ENABLE, '
	                    || 'RECORD_STATUS VARCHAR2(1 CHAR) NOT NULL ENABLE, ' 
	                    || 'QUEUE_DATA CLOB NOT NULL ENABLE, '
	                    || 'ERROR_CODE VARCHAR2(100 CHAR), '
	                    || 'ERROR_MSG VARCHAR2(100 CHAR), '
	                    || 'ADD_DATE DATE DEFAULT SYSDATE NOT NULL ENABLE, '
	                    || 'ADD_USER VARCHAR2(30 CHAR) DEFAULT REPLACE(USER,''OPS$'') NOT NULL ENABLE, '
	                    || 'UPD_DATE DATE, '
	                    || 'UPD_USER VARCHAR2(30 CHAR), '
	                    || 'PRIM_SEQ_NO NUMBER(10,0) NOT NULL ENABLE, '
	                    || 'CONSTRAINT MQ_QUEUE_OUT_PK PRIMARY KEY (PRIM_SEQ_NO)'
                        || ')';						
				

                EXECUTE IMMEDIATE SQL_stmt;

                SQL_stmt := 'GRANT all on swms.MQ_QUEUE_OUT to swms_user';
                EXECUTE IMMEDIATE SQL_stmt;


                SQL_stmt := 'create or replace public synonym MQ_QUEUE_OUT for swms.MQ_QUEUE_OUT';
                EXECUTE IMMEDIATE SQL_stmt;
        end if;
end;
/
