CREATE OR REPLACE TRIGGER TRG_INS_UPD_MX_IN
   BEFORE INSERT OR
   UPDATE ON MATRIX_IN
   FOR EACH ROW
--------------------------------------------------------------------
   -- trg_ins_upd_mx_in.sql
   --                                                                              
   -- Description:                                                                 
   --     This script contains a trigger which generates a sequence
   --     and record status for matrix_in table.
   --                                                                              
   -- Modification History:                                                        
   --    Date      Designer Comments                                               
   --    --------- -------- -------------------------------------------
   --     3-sep-14 Sunil Ontipalli Created as part of the Symbotic Integration.  
   --    26-mar-14 Sunil Ontipalli Added the Alert Mechanism, Any failures result in creation of a ticket.     
--------------------------------------------------------------------
DECLARE
l_interface_ref_doc    VARCHAR2(10);
l_mx_msg_id            VARCHAR2(30);
l_error_msg            VARCHAR2(400);
l_batch_id             VARCHAR2(30);

BEGIN
   
   IF INSERTING 
   THEN
      SELECT MATRIX_IN_SEQ.NEXTVAL, 'N'
        INTO :NEW.SEQUENCE_NUMBER, :NEW.RECORD_STATUS
        FROM DUAL;
   END IF;
   
   IF UPDATING 
   THEN
   SELECT SYSDATE, USER
        INTO :NEW.UPD_DATE, :NEW.UPD_USER
        FROM DUAL;

        IF :NEW.RECORD_STATUS = 'F' AND (:NEW.REC_IND = 'H' OR :NEW.REC_IND = 'S') THEN
           
           l_interface_ref_doc   := :NEW.interface_ref_doc;
           l_mx_msg_id           := :NEW.mx_msg_id;
           l_error_msg           :=  SUBSTR(:NEW.error_msg, 1, 400);
           l_batch_id            := :NEW.batch_id;

           pl_symbotic_alerts.raise_alert(i_interface_ref_doc  =>   l_interface_ref_doc,
                                          i_msg_id             =>   l_mx_msg_id,
                                          i_batch_id           =>   l_batch_id,
                                          i_error_msg          =>   l_error_msg);
        
        END IF;
        
   END IF;
END;
/
