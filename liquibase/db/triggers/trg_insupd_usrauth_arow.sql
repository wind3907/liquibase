CREATE OR REPLACE TRIGGER "SWMS"."TRG_INSUPD_USRAUTH_AROW" AFTER
INSERT
OR UPDATE OF "PRIV" ON SWMS.USRAUTH FOR EACH ROW DECLARE
 l_user_id     VARCHAR2 (30);
 l_old_priv    NUMBER;
 l_upd_type    VARCHAR2 (10);
BEGIN
  l_user_id := REPLACE(USER,'OPS$',NULL);

  IF UPDATING THEN
     l_old_priv := :old.priv;
     l_upd_type := 'UPDATE';
  ELSIF INSERTING THEN
     l_old_priv := NULL;
     l_upd_type := 'INSERT';
  END IF;
  INSERT INTO USRAUTH_HIST (USER_ID, AUTH_ID, OLD_PRIV, NEW_PRIV,
                            UPD_TYPE, UPD_USER, UPD_DATE)
  VALUES (:new.user_id, :new.auth_id, l_old_priv, :new.priv,
          l_upd_type, l_user_id, SYSDATE);
END;
/

