
SET ECHO ON

/****************************************************************************
** Date:       09-AUG-2011
** Programmer: Brian Bent
** File:       CRQ27160_ins_script_run_sos_sls_clean.sql
** 
** Insert runsql "run_sos_sls_clean.sh" that runs the SOS/SLS clean.
**
** Records are inserted into tables:
**    - SCRIPTS
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    10/01/10 prpbcb   DN 12601
**                      Incident 550764
**                      Project: CRQ19279-Manually run SOS and LAS clean
**                      Initial creation for OpCo 134 IFG.
##
**    08/09/10 prpbcb   Copied from rs239b and modifed for 11g.
**                      Project:
**                         CRQ27160-Manually run SOS and LAS clean
**                      Clearcase Activity:
**                         SWMS12.3_Stage2_Testing_Fixes
**
**                      Assigned 161 for the scripts as the option number
**                      as this is the one based on the max(option_no)
**                      looking at all the 11g Opcos.
**
****************************************************************************/

/****************************************************************************
*  Insert runsql run_sos_sls_clean.sh
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
    display_help,
    option_no)
SELECT
    'run_sos_sls_clean.sh'   script_name,   
    'ORDER PROCESSING'       application_func,
    'Y'                      restartable,
    0                        run_count,
    NULL                     last_run_date,
    NULL                     last_run_user,
    'N'                      update_function,
    '-z1 -p12'               print_options,
'===== Run SOS/SLS clean ===== 
Only run this after picking and loading is complete and the
order purge has run and no routes are generated.
There can be no open routes.
The last time the order purge was run is displayed, the time
of the last DAY close is display, a list of the open routes
is displayed then a count of any future labor management
selection batches is displayed.  You will then be
prompted to confirm running the SOS/SLS clean.'   
                                           display_help,
   161 option_no
  FROM DUAL
/

