
SET ECHO ON

/****************************************************************************
** Date:       MAY-24-2018
** File:       put_po_on_hold.sh
** 
** Insert runsql "Jira390_DML_put_po_on_hold.sql" 
**
** Records are inserted into tables:
**    - SCRIPTS
** Modification History:
**    Date         Designer           Comments
**    ----------   ---------------  ----------------------------------------
**    MAY-24-2018  Saraswathi. B 	Setup for Maintenance script
** 
****************************************************************************/

/****************************************************************************
*  put_po_on_hold.sh
****************************************************************************/

DECLARE
  v_script_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_script_exists
  FROM scripts
  WHERE APPLICATION_FUNC = 'MAINTENANCE'
   and SCRIPT_NAME like '%put_po_on_hold.sh';

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
    'put_po_on_hold.sh'   	 script_name,   
    'MAINTENANCE'       	 application_func,
    'Y'                      restartable,
    0                        run_count,
    NULL                     last_run_date,
    NULL                     last_run_user,
    'Y'                      update_function,
    '-z1 -p12'               print_options,
'===== Put PO Inventory on HOLD ===== 
This program will put the entire PO''s Pallets inventory on HOLD for a specific Purchase Order provided by User. 
SO THAT warehouse clerk will not have to manually put every pallet on hold and will help reduce labor costs. 
The script will also check for the inventory with QOH available (greater than 0) and 
Quantity allocated + quantity plan is equal to 0. The script gets LPs from the PO and change the Status 
to HLD and Reason Code to RC. A transaction is written to the SUS for each LP.  
This script does not search for float locations or extended POs.'
                                           display_help,
   162 option_no
  FROM DUAL;
COMMIT;
End If;
END;
/

