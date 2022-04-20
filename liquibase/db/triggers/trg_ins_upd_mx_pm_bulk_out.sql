CREATE OR REPLACE TRIGGER TRG_INS_UPD_MX_PM_BULK_OUT
   BEFORE INSERT OR
   UPDATE ON MATRIX_PM_BULK_OUT
   FOR EACH ROW
--------------------------------------------------------------------
   -- TRG_INS_UPD_MX_PM_BULK_OUT.sql
   --                                                                              
   -- Description:                                                                 
   --     This script contains a trigger which generates a sequence
   --     and record status for matrix_out table.
   --                                                                              
   -- Modification History:                                                        
   --    Date      Designer Comments                                               
   --    --------- -------- -------------------------------------------
   --    14-nov-14 Sunil Ontipalli Created as part of the Symbotic Integration                
--------------------------------------------------------------------
BEGIN
   IF INSERTING 
   THEN
      SELECT MATRIX_PM_BULK_OUT_SEQ.NEXTVAL
        INTO :NEW.SEQUENCE_NUMBER
        FROM DUAL;
   END IF;
   IF UPDATING 
   THEN
   SELECT SYSDATE, USER
        INTO :NEW.UPD_DATE, :NEW.UPD_USER
        FROM DUAL;
   END IF;
END;
/
