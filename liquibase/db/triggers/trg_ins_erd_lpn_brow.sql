CREATE OR REPLACE TRIGGER "SWMS"."TRG_INS_ERD_LPN_BROW" BEFORE
INSERT ON SWMS.ERD_LPN FOR EACH ROW DECLARE
  orig_pallet_id ERD_LPN.PALLET_ID%TYPE;
  pallet_id_cnt  NUMBER;
  ascii_code     NUMBER;
  l_cnt          NUMBER;
  l_message      VARCHAR2(300); 
BEGIN
  orig_pallet_id := :NEW.PALLET_ID;
  pallet_id_cnt := 1;
  ascii_code := ASCII('A');
  WHILE pallet_id_cnt > 0 AND ascii_code <= ASCII('Z') LOOP
    SELECT COUNT(*)
      INTO pallet_id_cnt
      FROM ERD_LPN
     WHERE PALLET_ID = :NEW.PALLET_ID;
    IF pallet_id_cnt > 0 THEN
      :NEW.PALLET_ID := SUBSTR(:NEW.PALLET_ID,1,LENGTH(:NEW.PALLET_ID)-1) || CHR(ascii_code);
      ascii_code := ascii_code + 1;
    ELSE
      SELECT COUNT(*)
        INTO pallet_id_cnt
        FROM INV
       WHERE logi_loc = :NEW.PALLET_ID;
      IF pallet_id_cnt > 0 THEN
        :NEW.PALLET_ID := SUBSTR(:NEW.PALLET_ID,1,LENGTH(:NEW.PALLET_ID)-1) || CHR(ascii_code);
        ascii_code := ascii_code + 1;
      END IF;
    END IF;
  END LOOP;

  IF ascii_code > ASCII('A') THEN
    pl_log.ins_msg('W','TRG_INS_ERD_LPN_BROW',
                   'SN '||:NEW.SN_NO||' PALLET_ID '||orig_pallet_id||' changed to '||:NEW.PALLET_ID,
                   SQLCODE,SQLERRM,'RECEIVING','swmssnreader');
    SELECT COUNT(*)
      INTO l_cnt
      FROM swms_float_detail_in
     WHERE rdc_outbound_child_pallet_id = orig_pallet_id;

    IF l_cnt > 0 THEN
      UPDATE swms_float_detail_in
         SET rdc_outbound_child_pallet_id = :NEW.PALLET_ID
       WHERE rdc_outbound_child_pallet_id = orig_pallet_id;
      l_message := 'Found ' || l_cnt || ' row(s) in swms_float_detail_in where '
                   || 'rdc_outbound_child_pallet_id was [' || orig_pallet_id 
                   || ']. Changed to [' || :NEW.PALLET_ID || '].';
      pl_log.ins_msg('WARN', 'TRG_INS_ERD_LPN_BROW', l_message, NULL, NULL);
    ELSE
      l_message := 'No rows in swms_float_detail_in requiring LPN change.';
      pl_log.ins_msg('WARN', 'TRG_INS_ERD_LPN_BROW', l_message, NULL, NULL);
    END IF;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    PL_LOG.INS_MSG('E','TRG_INS_ERD_LPN_BROW',
                   'Error checking/changing ERD_LPN PALLET_ID '||orig_pallet_id,SQLCODE,SQLERRM,
                   'RECEIVING','swmssnreader');
END;
/

