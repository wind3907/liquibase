set serveroutput on size unlimited

  DECLARE
        n_count                                 PLS_INTEGER;
        SQL_stmt                                VARCHAR2(2000 CHAR);
        v_column_exists                 NUMBER := 0;

BEGIN
--dbms_output.enable (buffer_size => null);
        SELECT COUNT(*)
                INTO n_count
                FROM all_objects
                WHERE object_type       = 'TABLE'
                        AND owner               = 'SWMS'
                        AND object_name = 'MQ_INTERFACE_MAINT';

        IF N_COUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE('Table MQ_INTERFACE_MAINT found, skipping recreation...');
        ELSE
                DBMS_OUTPUT.PUT_LINE('Table MQ_INTERFACE_MAINT not found, creating now...');

                SQL_stmt :=
                     'CREATE TABLE SWMS.MQ_INTERFACE_MAINT ( '
                        || 'PROPAGATION_TYPE NUMBER, '
	                    || 'AQ_QUEUE_NAME VARCHAR2(50 CHAR), '
	                    || 'MQ_QUEUE_MANAGER VARCHAR2(50 CHAR), '
	                    || 'MQ_QUEUE_NAME VARCHAR2(50 CHAR), '
	                    || 'QUEUE_TABLE VARCHAR2(50 CHAR), '
	                    || 'HOSTNAME VARCHAR2(50 CHAR), '
	                    || 'PORT NUMBER, '
	                    || 'CHANNEL VARCHAR2(50 CHAR), '
	                    || 'OUTBOUND_LOG_QUEUE VARCHAR2(50 CHAR), '
	                    || 'INBOUND_LOG_QUEUE VARCHAR2(50 CHAR), '
	                    || 'LINKNAME VARCHAR2(50 CHAR), '
	                    || 'PROPOGATION_SUBSCRIBER_ID VARCHAR2(50 CHAR), '
	                    || 'QUEUE_OWNER VARCHAR2(50 CHAR), '
	                    || 'PROPOGATION_SCHEDULE_ID VARCHAR2(50 CHAR), '
	                    || 'ACTIVE_FLAG VARCHAR2(1 CHAR), '
	                    || 'ADD_DATE DATE DEFAULT SYSDATE NOT NULL ENABLE, '
	                    || 'ADD_USER VARCHAR2(30 CHAR) DEFAULT REPLACE(USER,''OPS$'') NOT NULL ENABLE, '
	                    || 'UPD_DATE DATE, '
	                    || 'UPD_USER VARCHAR2(30 CHAR), '
	                    || 'JOB_GROUP NUMBER '
						|| ')';				
				

                --dbms_output.put_line(sql_stmt);
                EXECUTE IMMEDIATE SQL_stmt;

                SQL_stmt := 'GRANT all on SWMS.MQ_INTERFACE_MAINT to swms_user';
                EXECUTE IMMEDIATE SQL_stmt;


                SQL_stmt := 'create or replace public synonym MQ_INTERFACE_MAINT for swms.MQ_INTERFACE_MAINT';
                EXECUTE IMMEDIATE SQL_stmt;
        end if;
end;
/




 

