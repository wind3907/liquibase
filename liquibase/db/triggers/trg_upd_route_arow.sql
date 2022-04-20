CREATE OR REPLACE TRIGGER SWMS.TRIG_UPD_ROUTE_AROW 
    AFTER UPDATE OF STATUS
    ON SWMS.ROUTE 
    FOR EACH ROW 
    WHEN (new.status = 'RCV')
DECLARE
-- local declarations
  l_check_SAP_OPCO     SYS_CONFIG.config_flag_val%TYPE;

  cursor ck_trans_cur is
  select trans_id
  from trans
  where trans_type='SHT'
  and route_no = :new.route_no
  and to_char(upload_time,'DD-MON-RRRR') = '01-JAN-1980'
  for update of upload_time; 

BEGIN

 BEGIN
   SELECT CONFIG_FLAG_VAL INTO l_check_SAP_OPCO 
   FROM SYS_CONFIG
   WHERE CONFIG_FLAG_NAME = 'HOST_TYPE';
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
      l_check_SAP_OPCO := 'SUS';
 END;
IF l_check_SAP_OPCO = 'SAP' then

   FOR e_trans IN ck_trans_cur LOOP
      UPDATE trans
	set upload_time = null
      WHERE trans_id = e_trans.trans_id;
   END LOOP;

   DELETE FROM SAP_OW_OUT 
   WHERE route_no = :new.route_no
   AND   trans_type = 'SHT'
   AND   record_status != 'S';
END IF;

END;
/

