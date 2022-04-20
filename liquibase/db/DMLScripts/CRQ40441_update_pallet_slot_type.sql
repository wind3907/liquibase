
SET ECHO ON

/****************************************************************************
** Date:       02-Nov-2017
** Programmer: Elaine Zheng
** File:       CRQ40441_update_pallet_slot_type.sql
** 
** Insert runsql "CRQ40441_update_pallet_slot_type.sql" that runs the SOS/SLS clean.
**
** Records are inserted into tables:
**    - SCRIPTS
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**
****************************************************************************/

/****************************************************************************
*  Insert runsql run_update_pallet_slot_type.sh
****************************************************************************/
DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_exists
  FROM scripts
  WHERE script_name = 'update_pallet_slot_type.sh';
 

  IF (v_exists = 0)
  THEN

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
    'update_pallet_slot_type.sh'   script_name,   
    'Maintanance'       application_func,
    'Y'                      restartable,
    0                        run_count,
    NULL                     last_run_date,
    NULL                     last_run_user,
    'N'                      update_function,
    '-z1 -p12'               print_options,
'===== Run SOS/SLS clean ===== 
Only run this after developers create tmp table for loading and backed up touched
tables:pm and loc.
This program will standardize pallet type and slot type.'   
                                           display_help,
   161 option_no
  FROM DUAL;

 END IF;
 END;
/

