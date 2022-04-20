CREATE OR REPLACE TRIGGER "SWMS"."TRG_UPD_DOD_DETAIL_BROW" BEFORE
UPDATE OF "END_SEQ", "EXP_DATE", "LOT_ID", "MAX_CASE_SEQ", "PACK_DATE", "START_SEQ" ON "DOD_LABEL_DETAIL"
FOR EACH ROW
BEGIN
  :NEW.UPD_DATE := SYSDATE;
  :NEW.UPD_USER := USER;
END;
/


