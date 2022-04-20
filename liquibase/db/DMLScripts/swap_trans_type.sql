DECLARE
    v_exists   NUMBER := 0;
BEGIN
  BEGIN
    SELECT COUNT(*)
    INTO v_exists
    FROM trans_type
    WHERE trans_type = 'INS';
  EXCEPTION
    WHEN OTHERS THEN
      v_exists := 1;
  END;

  IF ( v_exists = 0 ) THEN
    INSERT INTO trans_type(trans_type, descrip, retention_days, inv_affecting)
    VALUES ('INS', 'In progress swap', '55', 'Y');
  END IF;
END;
/

