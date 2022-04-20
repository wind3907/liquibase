CREATE OR REPLACE TRIGGER TRG_INS_UPD_MX_INV_BULK_IN
   BEFORE INSERT OR
   UPDATE ON MATRIX_INV_BULK_IN
   FOR EACH ROW
--------------------------------------------------------------------
   -- trg_ins_upd_mx_inv_bulk_in.sql
   --                                                                              
   -- Description:                                                                 
   --     This script contains a trigger which generates a sequence
   --     and record status for matrix_inv_bulk_in table.
   --                                                                              
   -- Modification History:                                                        
   --    Date      Designer Comments                                               
   --    --------- -------- -------------------------------------------
   --    17-dec-14 Sunil Ontipalli Created as part of the Symbotic Integration                
--------------------------------------------------------------------
BEGIN
   IF INSERTING 
   THEN
      SELECT MATRIX_INV_BULK_IN_SEQ.NEXTVAL, 'N'
        INTO :NEW.SEQUENCE_NUMBER, :NEW.RECORD_STATUS
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
