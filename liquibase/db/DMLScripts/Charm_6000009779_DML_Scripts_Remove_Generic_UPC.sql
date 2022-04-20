/****************************************************************************
** Date:       08-Dec-2015
** File:       Charm_6000009779_DML_Scripts_Remove_Generic_UPC.sql
**
** Insert runsql "del_invld_upc.sh" that deletes invalid UPCs
**
** Records are inserted into tables:
**    - SCRIPTS
**
** Modification History:
**    Date     Developer Comments
**    -------- --------  ---------------------------------------------------
**    12/08/15 skam7488  Initial version created.
**                       6000009779: Added del_invld_upc.sh into runsql
**                       to delete the invalid UPC in PM_UPC 
****************************************************************************/

/****************************************************************************
*  Insert runsql del_invld_upc.sh
****************************************************************************/

INSERT INTO SCRIPTS
   (script_name,
    application_func,
    restartable,
    run_count,
    last_run_date,
    last_run_user,
    update_function,
    option_no,
    display_help)
VALUES 
   ('del_invld_upc.sh',
    'ORDER PROCESSING',
    'Y',
    0,
    NULL,
    NULL,
    'Y',
    (SELECT MAX(option_no)+1 FROM SCRIPTS),
    'Clear generic UPC records for items in SWMS. The list of generic UPC that will be cleared are 10000000000007, 20000000000004, 70000000000009, 13400000000002, 33500000000003.');

COMMIT;
