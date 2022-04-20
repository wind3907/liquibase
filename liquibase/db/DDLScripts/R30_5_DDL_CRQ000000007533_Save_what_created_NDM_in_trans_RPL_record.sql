
/****************************************************************************
**
** Description:
**    Project:
**       R30.5--WIB#663--CRQ000000007533_Save_what_created_NDM_in_trans_RPL_record
**
**    Create new index on USER_DOWNLOAD_TASKS.  Column TASK_ID
**    Average number of records about 5,000.
**
**    Create new columns in TRANS, OP_TRANS and MINILOAD_TRANS to record
**    additional info about the RPL transaction.
**    The columns and a brief description are below followed by a more
**    detail description:
**    - REPLEN_CREATION_TYPE - What created the non-demand replenishment.
**    - REPLEN_TYPE          - The "replen type" (DSP, NSP, etc) of the
**                             RPL transaction.  OpCo 007 wanted a easy
**                             way to identify the matrix replenishment
**                             type of the RPL transaction.
**    - TASK_PRIORITY - Forklift task priority of the NDM
**    - SUGGESTED_TASK_PRIORITY - The highest priority of the NDM
**                                list sent to the RF.
**
**    The columns will be added to view "V_TRANS" and the transaction
**    forms mt1sa and mt1sb.
**
**    Column REPLEN_CREATION_TYPE stores what created the non-demand
**    replenishment.
**    The values comes from column REPLENST.REPLEN_TYPE which for non-demand
**    replenishments will have one of these values:
**       'L' - Created from RF using "Replen By Location" option
**       'H' - Created from Screen using "Replen by Historical" option
**       'R' - Created from screen with options other than "Replen by Historical"
**       'O' - Created from cron job when a store-order is received that
**             requires a replenishment
**    The appropriate RF host programs will be changed to populate this new
**    column when a non-demand replenishment is dropped.
**
**
**    Column REPLEN_TYPE stores the replenishment type.  The value will come
**    from REPLENLST.TYPE.
**    It main purpose is to store the matrix replenishment type.  
**    Matrix replenishments have diffent types but we use RPL for the
**    transaction type.  The OpCo wants to know the matrix replenishment type
**    for the RPL transaction.
**    The matrix replenishment types are in table MX_REPLEN_TYPE which are
**    listed here.
**               TYPE DESCRIP
**               ---  ----------------------------------------
**               DSP  Demand: Matrix to Split Home 
**               DXL  Demand: Reserve to Matrix
**               MRL  Manual Release: Matrix to Reserve
**               MXL  Assign Item: Home Location to Matrix
**               NSP  Non-demand: Matrix to Split Home
**               NXL  Non-demand: Reserve to Matrix
**               UNA  Unassign Item: Matrix to Main Warehouse
**
**    =======================================================================
**    =======================================================================
**    README    README     README    README    README
**    README    README     README    README    README
**    README    README     README    README    README
**    There is potential confusion in the column naming of "replenlst.replen_type"
**    and the new column "trans.replen_type".  The existing column
**    "replenlst.replen_type" is not actually the type of replenishment but
**    what generated the replenishment so the column name is misleading.
**    I elected to call the column in the trans table "replen_type" since
**    it will be the actual type of replenishment.
**    =======================================================================
**    =======================================================================
**
**
**    TASK_PRIORITY stores the forklift task priority for the NDM.  I also
**    populated it for DMD's.  The value comes from USER_DOWNLOADED_TASKS.
**
**
**    SUGGESTED_TASK_PRIORITY stores the hightest forklift task priority from
**    the replenishment list sent to the RF.
**    The value comes from USER_DOWNLOADED_TASKS.
**    Distribution Services wants to know if the forklift operator is doing
**    lower priority drops before higher ones.
**
**
**
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    07/18/16 bben0556 Brian Bent
**                      Created.
**
****************************************************************************/

-------------------------------------------------------------
-- Table Modifications:
--
--    --------------------------------------------
--    TRANS
--    --------------------------------------------
--    Add columns:
--       - replen_creation_type
--       - replen_type
--       - task_priority
--       - suggested_task_priority
--
--    --------------------------------------------
--    OP_TRANS
--    --------------------------------------------
--    Add columns:
--       - replen_creation_type
--       - replen_type
--       - task_priority
--       - suggested_task_priority
--
--    --------------------------------------------
--    MINILOAD_TRANS
--    --------------------------------------------
--    Add columns:
--       - replen_creation_type
--       - replen_type
--       - task_priority
--       - suggested_task_priority
--
-------------------------------------------------------------


--------------------------------------------------------------------------
-- Add columns to TRANS table.
--------------------------------------------------------------------------
ALTER TABLE swms.trans ADD (replen_creation_type            VARCHAR2(1 CHAR));
ALTER TABLE swms.trans ADD (replen_type                     VARCHAR2(3 CHAR));
ALTER TABLE swms.trans ADD (task_priority                   NUMBER(2));
ALTER TABLE swms.trans ADD (suggested_task_priority         NUMBER(2));

--------------------------------------------------------------------------
-- Add columns to OP_TRANS table.
--------------------------------------------------------------------------
ALTER TABLE swms.op_trans  ADD (replen_creation_type           VARCHAR2(1 CHAR));
ALTER TABLE swms.op_trans  ADD (replen_type                    VARCHAR2(3 CHAR));
ALTER TABLE swms.op_trans  ADD (task_priority                  NUMBER(2));
ALTER TABLE swms.op_trans  ADD (suggested_task_priority        NUMBER(2));

--------------------------------------------------------------------------
-- Add columns to MINILOAD_TRANS table.
--------------------------------------------------------------------------
ALTER TABLE swms.miniload_trans ADD (replen_creation_type           VARCHAR2(1 CHAR));
ALTER TABLE swms.miniload_trans ADD (replen_type                    VARCHAR2(3 CHAR));
ALTER TABLE swms.miniload_trans ADD (task_priority                  NUMBER(2));
ALTER TABLE swms.miniload_trans ADD (suggested_task_priority        NUMBER(2));



--
-- Create index on USER_DOWNLOAD_TASKS.TASK_ID
-- Maximum number of records in the table is about 10,000.
-- The TASK_ID will never be updated.
--
CREATE INDEX user_downloaded_tasks_task_usr ON swms.user_downloaded_tasks(task_id, user_id)
   TABLESPACE SWMS_ITS1
   STORAGE (INITIAL 128K NEXT 64K PCTINCREASE 0)
   PCTFREE 1
/


