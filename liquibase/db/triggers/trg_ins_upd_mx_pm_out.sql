CREATE OR REPLACE TRIGGER TRG_INS_UPD_MX_PM_OUT
   BEFORE INSERT OR
   UPDATE ON MATRIX_PM_OUT
   FOR EACH ROW
--------------------------------------------------------------------
      -- trg_ins_upd_mx_pm_out.sql
      --                                                                              
      -- Description:                                                                 
      --     This script contains a trigger which generates a sequence
      --     and record status for matrix_pm_out table.
      --                                                                              
      -- Modification History:                                                        
      --    Date      Designer Comments                                               
      --    --------- -------- -------------------------------------------
      --     3-sep-14 Sunil Ontipalli Created as part of the Symbotic Integration.
      --    26-mar-14 Sunil Ontipalli Added the Alert Mechanism, Any failures result in creation of a ticket.       
--------------------------------------------------------------------
DECLARE
l_interface_ref_doc    VARCHAR2(10);
l_sys_msg_id           VARCHAR2(30);
l_error_msg            VARCHAR2(400);
l_batch_id             VARCHAR2(30);

BEGIN

   IF INSERTING 
   THEN
      SELECT MATRIX_PM_OUT_SEQ.NEXTVAL, 'N'
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
           l_sys_msg_id          := :NEW.sys_msg_id;
           l_error_msg           :=  SUBSTR(:NEW.error_msg, 1, 400);
           l_batch_id            :=  NULL;

           pl_symbotic_alerts.raise_alert(i_interface_ref_doc  =>   l_interface_ref_doc,
                                          i_msg_id             =>   l_sys_msg_id,
                                          i_batch_id           =>   l_batch_id,
                                          i_error_msg          =>   l_error_msg);
        
        END IF;
        
   END IF;
END;
/
