  CREATE OR REPLACE TRIGGER "SWMS"."TRG_INS_UPD_MQ_QUEUE_IN" 
   BEFORE INSERT OR
   UPDATE ON MQ_QUEUE_IN
   FOR EACH ROW
--------------------------------------------------------------------
   -- trg_ins_upd_mq_queue_in.sql
   --
   -- Description:
   --     This script contains a trigger which generates a sequence
   --     and record status for mq_queue_in table.
   --
   -- Modification History:
   --    Date      Designer            Comments
   --    --------- --------            -------------------------------------------
   --     1-aug-18 mcha1213      
   --              

--------------------------------------------------------------------
BEGIN

   IF INSERTING
   THEN
      SELECT MQ_QUEUE_IN_SEQ.NEXTVAL, 'N'
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

ALTER TRIGGER "SWMS"."TRG_INS_UPD_MQ_QUEUE_IN" ENABLE;
/ 

