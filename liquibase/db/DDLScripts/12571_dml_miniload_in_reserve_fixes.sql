
SET ECHO ON

/****************************************************************************
** sccs_id=%Z% %W% %G% %I%
**
** Date:       06-APR-2010
** Programmer: Brian Bent
** File:       12571_dml_miniload_in_reserve_fixes.sql
** Defect#:    12571
** Project:    CRQ15757-Miniload In Reserve Fixes
** 
** This script performs the DML for this project.
**
** This script needs to be run once when the changes are installed at
** the OpCo.  Inadvertently running this script again will not cause any
** problems.
**
** Create a new trans type called MER which is for minloader expected receipt
** messages created by users in form mm3sa.  Form mm3sa was changed to
** create a MER transaction.   This gives the OpCo an easy way to identify
** the user creating expected receipts.
**
**
** Insert runsql ML_send_expected_receipt.sh into the SCRIPTS table.
** This runsql creates an expected receipt for all LP's of miniload items
** in a specified reserve/floating slot and the qoh is greater than 0.
** A prompt is made for the slot.
**
**
** Records are inserted into tables:
**    - TRANS_TYPE
**    - SCRIPTS
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    04/06/10 prpbcb   Created.
**
****************************************************************************/

/********************************************************************
**    Insert MER trans type. 
********************************************************************/

INSERT INTO trans_type(trans_type, descrip, retention_days, inv_affecting)
VALUES
   ('MER', 'Miniload User Created Expected Receipt', 55, 'N')
/


/****************************************************************************
*  Insert runsql ML_send_expected_receipt.sh.
****************************************************************************/

INSERT INTO scripts
   (script_name,
    application_func,
    restartable,
    run_count,
    last_run_date,
    last_run_user,
    update_function,
    print_options,
    display_help)
SELECT
    'ML_send_expected_receipt.sh'   script_name,
    'INVENTORY'          application_func,
    'Y'                  restartable,
    0                    run_count,
    NULL                 last_run_date,
    NULL                 last_run_user,
    'N'                  update_function,
    '-z1 -p12'           print_options,
'This runsql creates an expected receipt for all LP''s of
miniload items in a specified reserve/floating slot
and the qoh is greater than 0.
A prompt is made for the slot.'
                                  display_help
  FROM DUAL
/


