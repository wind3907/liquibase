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
                        AND object_name = 'UPS_FLOAT_DETAIL';

        IF N_COUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE('Table SWMS.UPS_FLOAT_DETAIL found, skipping recreation...');
        ELSE
                DBMS_OUTPUT.PUT_LINE('Table SWMS.UPS_FLOAT_DETAIL not found, creating now...');

                SQL_stmt :=
				          'CREATE TABLE SWMS.UPS_FLOAT_DETAIL ('
                         	|| 'SEQUENCE_NUMBER NUMBER(10,0) NOT NULL ENABLE, '	                  
	                        || 'RECORD_STATUS VARCHAR2(1 CHAR) NOT NULL ENABLE,  '
							|| 'FLOAT_NO NUMBER(9), '
							|| 'SEQ_NO NUMBER(3), '
							|| 'PROD_ID VARCHAR2(9 CHAR),'
							|| 'QTY_ALLOC NUMBER(9),'
							|| 'UOM NUMBER(2),'
							|| 'ORDER_SEQ NUMBER(8),'
							|| 'ORDER_ID VARCHAR2(14 CHAR),'
							|| 'ROUTE_NO VARCHAR2(10 CHAR),'
							|| 'ALLOC_TIME DATE,'
							|| 'SRC_LOC VARCHAR2(10 CHAR),'
							|| 'DESCRIP VARCHAR2(30 CHAR),'
							|| 'SPC NUMBER(4),'
							|| 'PACK VARCHAR2(4 CHAR),'
							|| 'PROD_SIZE VARCHAR2(6 CHAR),'
							|| 'SEQ NUMBER(8),'
							|| 'D_PIECES NUMBER(9),'
							|| 'C_PIECES NUMBER(9),'
							|| 'F_PIECES NUMBER(9),'
							|| 'CUST_PO VARCHAR2(15 CHAR),'
							|| 'CUST_ID VARCHAR2(10 CHAR),'
							|| 'CUST_NAME VARCHAR2(30 CHAR),'
							|| 'CUST_CONTACT VARCHAR2(30 CHAR),'
							|| 'CUST_ADDR1 VARCHAR2(40 CHAR),'
							|| 'CUST_ADDR2 VARCHAR2(40 CHAR),'
							|| 'CUST_CITY VARCHAR2(20 CHAR),'
							|| 'CUST_STATE VARCHAR2(2 CHAR),'
							|| 'CUST_ZIP VARCHAR2(10 CHAR),'
							|| 'CUST_CNTRY VARCHAR2(10 CHAR),'
							|| 'CASE_LENGTH NUMBER,'
							|| 'CASE_WIDTH NUMBER,'
							|| 'CASE_HEIGHT NUMBER,'
							|| 'CASE_CUBE NUMBER(12,4),'
							|| 'SPLIT_CUBE NUMBER(7,4),'
							|| 'G_WEIGHT NUMBER(8,4),'
							|| 'WEIGHT NUMBER(8,4),'
							|| 'CASES NUMBER,'
							|| 'SPLITS NUMBER,'
							|| 'COUNTRY_NAME VARCHAR2(50 CHAR),'
							|| 'COUNTRY_OF_ORIGIN VARCHAR2(2 CHAR),'							
	                        || 'ERROR_CODE VARCHAR2(100 CHAR),  '
                        	|| 'ERROR_MSG VARCHAR2(100 CHAR),  '
                         	|| 'ADD_DATE DATE DEFAULT SYSDATE NOT NULL ENABLE,  '
                         	|| 'ADD_USER VARCHAR2(30 CHAR) DEFAULT REPLACE(USER,''OPS$'') NOT NULL ENABLE,  '
                         	|| 'UPD_DATE DATE,  '
	                        || 'UPD_USER VARCHAR2(30 CHAR),  '
                        	|| 'CONSTRAINT UPS_FLOAT_DETAIL_PK PRIMARY KEY (SEQUENCE_NUMBER) '
							|| ')';

                EXECUTE IMMEDIATE SQL_stmt;

				SQL_stmt := 'CREATE INDEX SWMS.UPS_FLOAT_DETAIL_IDX1 ON SWMS.UPS_FLOAT_DETAIL(FLOAT_NO, SEQ_NO)';
                EXECUTE IMMEDIATE SQL_stmt;				
				

                SQL_stmt := 'GRANT all on swms.UPS_FLOAT_DETAIL to swms_user';
                EXECUTE IMMEDIATE SQL_stmt;
				
				SQL_stmt := 'GRANT all on swms.UPS_FLOAT_DETAIL to swms_jdbc';
                EXECUTE IMMEDIATE SQL_stmt;


                SQL_stmt := 'create or replace public synonym UPS_FLOAT_DETAIL for swms.UPS_FLOAT_DETAIL ';
                EXECUTE IMMEDIATE SQL_stmt;
				
				

        end if;
end;
/
