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
                        AND object_name = 'XML_TAB2';

        IF N_COUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE('Table SWMS.XML_TAB2 found, skipping recreation...');
        ELSE
                DBMS_OUTPUT.PUT_LINE('Table SWMS.XML_TAB2 not found, creating now...');
				
                SQL_stmt :=
				          'CREATE TABLE SWMS.XML_TAB2 ('
                         	|| 'ID NUMBER NOT NULL ENABLE, '
	                        || 'XML_DATA  XMLTYPE NOT NULL ENABLE,  '
                        	|| 'CONSTRAINT XML_TAB2_PK PRIMARY KEY (ID) '
							|| ')';

                EXECUTE IMMEDIATE SQL_stmt;

                SQL_stmt := 'GRANT all on swms.XML_TAB2 to swms_user';
                EXECUTE IMMEDIATE SQL_stmt;
				
				SQL_stmt := 'GRANT all on swms.XML_TAB2 to swms_jdbc';
                EXECUTE IMMEDIATE SQL_stmt;


                SQL_stmt := 'create or replace public synonym XML_TAB2 for swms.XML_TAB2';
                EXECUTE IMMEDIATE SQL_stmt;				
				

        end if;
end;
/

 