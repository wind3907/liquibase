DECLARE
        n_count                                 PLS_INTEGER;
        SQL_stmt                                VARCHAR2(2000 CHAR);
        v_column_exists                 NUMBER := 0;

BEGIN
        SELECT COUNT(*)jd
                INTO n_count
                FROM all_objects						
                WHERE object_type       = 'SEQUENCE'
                        AND owner               = 'SWMS'                      
                        AND object_name = 'BARCODE_REFNO_SEQ';						

        IF N_COUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE('Sequence BARCODE_REFNO_SEQ found, skipping recreation...');
        ELSE
                DBMS_OUTPUT.PUT_LINE('Sequence SWMS.BARCODE_REFNO_SEQ not found, creating now...');

                SQL_stmt :=
                        'CREATE SEQUENCE  SWMS.BARCODE_REFNO_SEQ '
                          || 'MINVALUE 1000 MAXVALUE 9999999999 INCREMENT BY 1 START WITH 1001 CACHE 20 ORDER  CYCLE';			  

                EXECUTE IMMEDIATE SQL_stmt;

                SQL_stmt := 'GRANT all on BARCODE_REFNO_SEQ to swms_user';
                EXECUTE IMMEDIATE SQL_stmt;
				
				SQL_stmt := 'GRANT all on BARCODE_REFNO_SEQ to swms_jdbc';
                EXECUTE IMMEDIATE SQL_stmt;


                SQL_stmt := 'create or replace public synonym BARCODE_REF_SEQ for swms.BARCODE_REFNO_SEQ';
                EXECUTE IMMEDIATE SQL_stmt;
        end if;
end;
/

