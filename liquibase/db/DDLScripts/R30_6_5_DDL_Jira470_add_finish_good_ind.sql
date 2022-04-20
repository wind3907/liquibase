DECLARE
  v_column_exists NUMBER := 0;
BEGIN

        SELECT COUNT(*)
              INTO v_column_exists
              FROM all_tab_columns
              WHERE  table_name = 'PM'
              AND  column_name='FINISH_GOOD_IND'
              AND OWNER='SWMS';
              
         DBMS_OUTPUT.PUT_LINE('v_column_exists 1: '||v_column_exists);
             IF (v_column_exists = 0) THEN  
                                 
                EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PM ADD FINISH_GOOD_IND VARCHAR2(1 CHAR) NULL';
                
             END IF;
 END;
/

DECLARE
  v_column_exists NUMBER := 0;
  
BEGIN

        SELECT COUNT(*)
              INTO v_column_exists
              FROM all_tab_columns
              WHERE  table_name = 'SAP_IM_IN'
              AND  column_name='FINISH_GOOD_IND'
              AND OWNER='SWMS';
              DBMS_OUTPUT.PUT_LINE('v_column_exists 2: '||v_column_exists);

             IF (v_column_exists = 0) 
             THEN  
                                 
                EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_IM_IN ADD FINISH_GOOD_IND VARCHAR2(1 CHAR) NULL';
                
             END IF;
END;
/
