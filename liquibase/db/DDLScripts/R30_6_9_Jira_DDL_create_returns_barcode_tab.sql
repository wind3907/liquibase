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
                        AND object_name = 'RETURNS_BARCODE';
						

        IF N_COUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE('Table SWMS.RETURNS_BARCODE found, skipping recreation...');
        ELSE
                DBMS_OUTPUT.PUT_LINE('Table SWMS.RETURNS_BARCODE not found, creating now...');

                SQL_stmt :=
				          'CREATE TABLE SWMS.RETURNS_BARCODE ('            
	                        || 'MANIFEST_NO NUMBER(7,0) NOT NULL ENABLE,  '
							|| 'ROUTE_NO VARCHAR2(10 CHAR), '
							|| 'STOP_NO NUMBER(7,2), '
							|| 'OBLIGATION_NO VARCHAR2(14 CHAR),'
							|| 'PROD_ID VARCHAR2(9 CHAR) NOT NULL ENABLE,'							
							|| 'RETURN_REASON_CD VARCHAR2(3 CHAR) NOT NULL ENABLE,'
							|| 'RETURNED_QTY NUMBER(4,0),'					
							|| 'CATCHWEIGHT NUMBER(9,3),'
							|| 'SHIPPED_QTY NUMBER(4,0),'
							|| 'BARCODE VARCHAR2(11 CHAR) NOT NULL ENABLE,'							
							|| 'BARCODE_REF_NO NUMBER(10,0) NOT NULL ENABLE,'
							|| 'STS_REC_TYPE VARCHAR2(2 CHAR) NOT NULL ENABLE,'	
							|| 'STATUS VARCHAR2(4 CHAR),'								
							|| 'MSG_TEXT VARCHAR2(100 CHAR),'								
							|| 'ADD_DATE DATE DEFAULT SYSDATE,'
                            || 'ADD_USER VARCHAR2(30 CHAR) DEFAULT USER,'
							|| 'ADD_SOURCE VARCHAR2(3 CHAR),'
							|| 'UPD_DATE DATE,'
							|| 'UPD_USER VARCHAR2(30 CHAR),'
							|| 'UPD_SOURCE VARCHAR2(3 CHAR)'						
							|| ')';

                EXECUTE IMMEDIATE SQL_stmt;
				

                SQL_stmt := 'GRANT all on swms.RETURNS_BARCODE to swms_user';
                EXECUTE IMMEDIATE SQL_stmt;
				
				SQL_stmt := 'GRANT all on swms.RETURNS_BARCODE to swms_jdbc';
                EXECUTE IMMEDIATE SQL_stmt;


                SQL_stmt := 'create or replace public synonym RETURNS_BARCODE for swms.RETURNS_BARCODE ';
                EXECUTE IMMEDIATE SQL_stmt;
				
				

        end if;
end;
/
