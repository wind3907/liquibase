DECLARE
  l_data_code data_codes.data_code%TYPE;
BEGIN
  BEGIN
    SELECT data_code INTO l_data_code
      FROM data_codes
     WHERE data_code = 'GPD';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      INSERT INTO data_codes (data_code, description, is_mandatory)
      VALUES ('GPD', 'GS1 Production Date', 'N');
  END;

  BEGIN
    SELECT data_code INTO l_data_code
      FROM data_codes
     WHERE data_code = 'GLT';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      INSERT INTO data_codes (data_code, description, is_mandatory)
      VALUES ('GLT', 'GS1 Lot ID', 'N');
  END;

  BEGIN
    SELECT data_code INTO l_data_code
      FROM data_codes
     WHERE data_code = 'G10';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      INSERT INTO data_codes (data_code, description, is_mandatory)
      VALUES ('G10', 'GS1 GTIN', 'N');
  END;
END;
/
