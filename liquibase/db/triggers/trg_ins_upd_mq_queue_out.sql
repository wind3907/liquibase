  CREATE OR REPLACE TRIGGER "SWMS"."TRG_INS_UPD_MQ_QUEUE_OUT" 
   BEFORE INSERT OR
   UPDATE ON MQ_QUEUE_OUT
   FOR EACH ROW
--------------------------------------------------------------------------------
   -- trg_ins_upd_mq_queue_out.sql
   --
   -- Description:
   --     This script contains a trigger which generates a sequence
   --     and record status for mq_queue_in table.
   --
   -- Modification History:
   --    Date      Designer            Comments
   --    --------- --------            ------------------------------------------
   --     1-aug-17 Adi Al Bataineh     Created as part of the RDC.
   --              and Sunil Ontipalli
   --     1-SEP-17 Adi Al Bataineh     Changed MQ_INTERFACE_MAINT structure
   --     20-JUNE-18 mcha213           add not null for queue_data and prim_seq_no
---------------------------------------------------------------------------------
BEGIN

   IF INSERTING
   THEN
      /*
      SELECT 'N'
        INTO :NEW.RECORD_STATUS
        FROM DUAL;
      */  

      SELECT MQ_QUEUE_OUT_SEQ.NEXTVAL, 'N'
        INTO :NEW.PRIM_SEQ_NO, :NEW.RECORD_STATUS
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

ALTER TRIGGER "SWMS"."TRG_INS_UPD_MQ_QUEUE_OUT" ENABLE;
/

