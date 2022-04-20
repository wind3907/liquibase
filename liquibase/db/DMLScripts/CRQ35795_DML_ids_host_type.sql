/**************************************************
*
* script to change the host_type in sys_config
* to IDS for IDS OpCos.
*
***************************************************/

DECLARE
   v_machine VARCHAR2(30);

BEGIN
   SELECT machine INTO v_machine
   FROM v$session 
   WHERE audsid = sys_context('userenv','SESSIONID');

   IF v_machine IN ('rs044a', 'rs077a', 'rs139a', 'rs162a', 'rs180a', 
                    'rs181a', 'rs256a', 'rs257a', 'rs258a', 'rs259a', 
                    'rs262a', 'rs264a', 'rs265a', 'rs268a', 'rs273a', 
                    'rs274a', 'rs309a', 'rs313a', 'rs338a', 'rs475a') THEN
      UPDATE sys_config
      SET config_flag_val = 'IDS'
      WHERE config_flag_name = 'HOST_TYPE';

      COMMIT;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      RAISE;

END;
/
