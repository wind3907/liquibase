CREATE OR REPLACE TRIGGER "SWMS"."TRG_INSUPD_SAP_ML_IN_BROW"
------------------------------------------------------------------------------
--
-- Trigger Name:
--    trg_insupd_sap_ml_in_brow
--
-- File:
--    trg_insupd_sap_ml_in_brow.sql
--
-- Table:
--    SAP_ML_IN
--
-- Description:
--    Because of a bug in PI stripping leading '0' from the item number we
--    need to put them back.
--    The fix to PI is being worked on.
--
-- Exceptions raised:
--    None.  A message will be logged if an error occurs.  Proessing
--    will not stop.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/17/12 prpbcb   Created
--                      Project:
--                        CRQ39906-sap_ml_in_item_missing_leading_zeroes
--                      Activity:
--                        CRQ39906-sap_ml_in_item_missing_leading_zeroes
--
--    07/11/20 igoo9289 Created
--                      Project: UK Brakes
--                        SMOD-4176-[BRAKES] ML Reader - Prod ID incorrectly padded to 7 characters
--                      Activity:
--                        Added to host type flag check before adding leading zeros.
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON swms.sap_ml_in
FOR EACH ROW
DECLARE
   l_host_type_flag VARCHAR2(6)  := 'AS400';
BEGIN
   l_host_type_flag := pl_common.f_get_syspar('HOST_TYPE', 'x');
   IF (INSERTING OR UPDATING) THEN
      IF ( l_host_type_flag != 'SAP' ) THEN
          IF (:NEW.prod_id IS NOT NULL AND LENGTH(:NEW.prod_id) < 7) THEN
             :NEW.prod_id := LPAD(:NEW.prod_id, 7, '0');
          END IF;
      END IF;
   END IF;
EXCEPTION
   --
   -- Got some error.  Write a log message.
   -- Don't stop processing.
   --
   WHEN OTHERS THEN
      pl_log.ins_msg('WARN', 'trg_insupd_sap_ml_in_brow',
                   'ERROR in the trigger, do not stop processing.'
                   || '  OLD prod_id[' || :OLD.prod_id || ']'
                   || '  NEW prod_id[' || :NEW.prod_id || ']',
                     SQLERRM, SQLCODE,
                     'MAINTENANCE', 'trg_insupd_sap_ml_in_brow');
      DBMS_OUTPUT.PUT_LINE('trg_insupd_sap_ml_in_brow' || SQLERRM);
END trg_insupd_sap_ml_in_brow;
/
