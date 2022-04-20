
SET ECHO ON

/****************************************************************************
** Date:       06/08/21
** File:       asset_tracking.sh
** 
** Insert runsql "Jira_opcof3484.sql" 
**
** Records are inserted into tables:
**    - SCRIPTS
** Modification History:
**    Date         Designer           Comments
**    ----------   ---------------  ----------------------------------------
**    06/08/2021    sban3548	    Setup for asset tracking Runsql script
** 
****************************************************************************/

/****************************************************************************
*  asset_tracking.sh
****************************************************************************/

DECLARE
  v_script_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_script_exists
  FROM scripts
  WHERE APPLICATION_FUNC = 'RETURNS'
   and SCRIPT_NAME = 'asset_tracking.sh';

IF (v_script_exists = 0)  THEN
INSERT INTO scripts
   (script_name,
    application_func,
    restartable,
    run_count,
    last_run_date,
    last_run_user,
    update_function,
    print_options,
    display_help,
    option_no)
SELECT
    'asset_tracking.sh'	     script_name,   
    'RETURNS'       	     application_func,
    'Y'                      restartable,
    0                        run_count,
    NULL                     last_run_date,
    NULL                     last_run_user,
    'N'                      update_function,
    '-z1 -p12'               print_options,
'===== Accessory Tracking Report ===== 
This program print the list of accesories used for each manifest during inbound returns and outbound loading, for a specific ship date range provided by User.' 
                             display_help,
   165 			     option_no
  FROM DUAL;
COMMIT;
End If;
END;
/

