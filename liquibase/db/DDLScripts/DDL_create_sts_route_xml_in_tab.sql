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
                        AND object_name = 'STS_ROUTE_XML_IN';

        IF N_COUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE('Table SWMS.STS_ROUTE_XML_IN found, skipping recreation...');
        ELSE
                DBMS_OUTPUT.PUT_LINE('Table SWMS.STS_ROUTE_XML_IN not found, creating now...');

                SQL_stmt :=
				          'CREATE TABLE SWMS.STS_ROUTE_XML_IN ('
                         	|| 'SEQUENCE_NUMBER NUMBER(10,0) NOT NULL ENABLE, '	                  
	                        || 'RECORD_STATUS VARCHAR2(1 CHAR) NOT NULL ENABLE,  '
							|| 'MSG_ID VARCHAR2(36 CHAR) NOT NULL ENABLE, '
                         	|| 'XML_DATA XMLTYPE,  '
	                        || 'ERROR_CODE VARCHAR2(100 CHAR),  '
                        	|| 'ERROR_MSG VARCHAR2(100 CHAR),  '
                         	|| 'ADD_DATE DATE DEFAULT SYSDATE NOT NULL ENABLE,  '
                         	|| 'ADD_USER VARCHAR2(30 CHAR) DEFAULT REPLACE(USER,''OPS$'') NOT NULL ENABLE,  '
                         	|| 'UPD_DATE DATE,  '
	                        || 'UPD_USER VARCHAR2(30 CHAR),  '
                        	|| 'CONSTRAINT STS_ROUTE_XML_IN_IN_PK PRIMARY KEY (SEQUENCE_NUMBER) '
							|| ')';

                EXECUTE IMMEDIATE SQL_stmt;

                SQL_stmt := 'GRANT all on swms.STS_ROUTE_XML_IN to swms_user';
                EXECUTE IMMEDIATE SQL_stmt;
				
				SQL_stmt := 'GRANT all on swms.STS_ROUTE_XML_IN to swms_jdbc';
                EXECUTE IMMEDIATE SQL_stmt;


                SQL_stmt := 'create or replace public synonym STS_ROUTE_XML_IN for swms.STS_ROUTE_XML_IN';
                EXECUTE IMMEDIATE SQL_stmt;
        end if;
end;
/
