CREATE OR REPLACE TRIGGER TRG_UPD_MATRIX_MAINT
   BEFORE UPDATE ON MATRIX_INTERFACE_MAINT
   FOR EACH ROW
--------------------------------------------------------------------
   -- TRG_UPD_MATRIX_MAINT.sql
   --                                                                              
   -- Description:                                                                 
   --     This script contains a trigger which generates upd date and 
   --     upd user details.
   --                                                                              
   -- Modification History:                                                        
   --    Date      Designer Comments                                               
   --    --------- -------- -------------------------------------------
   --    5-feb-15 Sunil Ontipalli Created as part of the Symbotic Integration                
--------------------------------------------------------------------   
BEGIN
   IF UPDATING
   THEN
   SELECT SYSDATE, USER
        INTO :NEW.UPD_DATE, :NEW.UPD_USER
        FROM DUAL;
   END IF;
END;
/

