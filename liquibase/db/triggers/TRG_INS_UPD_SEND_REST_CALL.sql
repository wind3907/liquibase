create or replace TRIGGER swms.TRG_INS_UPD_SEND_REST_CALL 
BEFORE INSERT ON XDOCK_META_HEADER  FOR EACH ROW
DECLARE 
    result integer;
    result_str VARCHAR2(2000);
BEGIN
    BEGIN
        result := SWMS.pl_send_meta_messages.send_meta_messages(
                    :NEW.BATCH_ID,
                    :NEW.ENTITY_NAME,
                    :NEW.HUB_SOURCE_SITE,
                    :NEW.HUB_DESTINATION_SITE,
                    result_str
                );
        IF result = 0 THEN
            :NEW.SENT_DATE := SYSDATE();
            :NEW.BATCH_STATUS := 'SENT';
        ELSE
            :NEW.ERROR := result_str;
            :NEW.BATCH_STATUS := 'ERROR';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
           :NEW.ERROR := sqlerrm;
           :NEW.BATCH_STATUS := 'ERROR';
    END;
END;
/