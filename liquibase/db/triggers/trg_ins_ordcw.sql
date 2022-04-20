CREATE OR REPLACE TRIGGER SWMS.trg_ins_ordcw
    AFTER INSERT OR UPDATE or DELETE
    ON SWMS.ORDCW
    FOR EACH ROW
--------------------------------------------------------------------
   -- TRG_INS_ORDCW.sql
   --                                                                              
   -- Description:                                                                 
   --     This trigger will insert record into audit table ORDCW_AUDIT 
   --     for DML operation on ORDCW table.
   --                                                                              
   -- Modification History:                                                        
   --    Date      Designer        Comments                                               
   --    --------- --------------- -----------------------------------------------------
   --    2-Mar-15  Abhishek Yadav  Copied from other release to maintain audit on ORDCW               
---------------------------------------------------------------------------------------   
BEGIN
    IF INSERTING THEN
        INSERT INTO SWMS.ORDCW_AUDIT (ORDER_ID, ORDER_LINE_ID, PROD_ID, CUST_PREF_VENDOR, CATCH_WEIGHT, 
                                      CW_TYPE, UOM, ORDCW_ADD_DATE, ADD_USER, UPD_DATE, 
                                      UPD_USER, CW_FLOAT_NO, CW_SCAN_METHOD,ADD_DATE,RECORD_TYPE)
                              VALUES (:NEW.ORDER_ID, :NEW.ORDER_LINE_ID, :NEW.PROD_ID, :NEW.CUST_PREF_VENDOR, :NEW.CATCH_WEIGHT, 
                                      :NEW.CW_TYPE, :NEW.UOM, :NEW.ADD_DATE, :NEW.ADD_USER, :NEW.UPD_DATE, 
                                      :NEW.UPD_USER, :NEW.CW_FLOAT_NO, :NEW.CW_SCAN_METHOD,SYSDATE,'INSERT');
    ELSIF UPDATING THEN
        INSERT INTO SWMS.ORDCW_AUDIT (ORDER_ID, ORDER_LINE_ID, PROD_ID, CUST_PREF_VENDOR, CATCH_WEIGHT, 
                                      CW_TYPE, UOM, ORDCW_ADD_DATE, ADD_USER, UPD_DATE, 
                                      UPD_USER, CW_FLOAT_NO, CW_SCAN_METHOD,ADD_DATE,RECORD_TYPE)
                              VALUES (:OLD.ORDER_ID, :OLD.ORDER_LINE_ID, :OLD.PROD_ID, :OLD.CUST_PREF_VENDOR, :NEW.CATCH_WEIGHT, 
                                      :NEW.CW_TYPE, :OLD.UOM, :OLD.ADD_DATE, :OLD.ADD_USER, :NEW.UPD_DATE, 
                                      :NEW.UPD_USER, :OLD.CW_FLOAT_NO, :OLD.CW_SCAN_METHOD,SYSDATE,'UPDATE');
    ELSE
        INSERT INTO SWMS.ORDCW_AUDIT (ORDER_ID, ORDER_LINE_ID, PROD_ID, CUST_PREF_VENDOR, CATCH_WEIGHT, 
                                      CW_TYPE, UOM, ORDCW_ADD_DATE, ADD_USER, UPD_DATE, 
                                      UPD_USER, CW_FLOAT_NO, CW_SCAN_METHOD,ADD_DATE,RECORD_TYPE)
                              VALUES (:OLD.ORDER_ID, :OLD.ORDER_LINE_ID, :OLD.PROD_ID, :OLD.CUST_PREF_VENDOR, :OLD.CATCH_WEIGHT, 
                                      :OLD.CW_TYPE, :OLD.UOM, :OLD.ADD_DATE, :OLD.ADD_USER, :OLD.UPD_DATE, 
                                      :OLD.UPD_USER, :OLD.CW_FLOAT_NO, :OLD.CW_SCAN_METHOD,SYSDATE,'DELETE');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;

/

