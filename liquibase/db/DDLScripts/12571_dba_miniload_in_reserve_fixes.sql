
SET ECHO ON

/****************************************************************************
** sccs_id=%Z% %W% %G% %I%
**
** Date:       09-APR-2010
** Programmer: Brian Bent
** File:       12571_dma_miniload_in_reserve_fixes.sql
** Defect#:    12571
** Project:    CRQ15757-Miniload In Reserve Fixes
** 
** This script performs the DDL for this project.
**
** This script needs to be run once when the changes are installed at
** the OpCo.  Inadvertently running this script again will not cause any
** problems.
**
** Table Changes:
**    ******************************
**    ***** PRIOITY_CODE Table *****
**    ******************************
**    Add columns to table PRIORITY_CODE.  These will be used to control
**    if the miniloader replenishments are deleted at the
**    "end of picking/start of day" processing.  Deleting the replenishments
**    consists of backing them out.  This "end of picking/start of day"
**    processing is started in form paovrv.fmb when the user does a
**    DAY close.
**    The new columns are:
**       - delete_at_start_of_day VARCHAR2(1) -- Delete the replenishments?
**                                               Valid values are Y, N or null.
**                                               If N or null then the
**                                               replenishments will not get
**                                               deleted.
**       - retention_days         NUMBER      -- How many days to keep the
**                                               replenishments before deleting
**                                               when delete_at_start_of_day is
**                                               Y.  A fraction of a day can be
**                                               entered so 1.5 is valid.
**
**    Package pl_ml_cleanup, which does the deleting, will be modified to look
**    at these new columns.
**
**    The table currently has these columns:
**    SQL> descr priority_code
**       Name                                      Null?    Type
**       ----------------------------------------- -------- -------------
**       PRIORITY_CODE                             NOT NULL VARCHAR2(3)
**       UNPACK_CODE                               NOT NULL VARCHAR2(1)
**       PRIORITY_VALUE                            NOT NULL NUMBER(2)
**       PRIO_DESIGNATOR                                    VARCHAR2(1)
**       UPDATE_INV                                         VARCHAR2(1)
**       DESCRIPTION                                        VARCHAR2(50)
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    04/09/10 prpbcb   DN 12571
**                      Project: CRQ15757-Miniload In Reserve Fixes
**                      Created.
**    05/07/10 prpbcb   DN 12571
**                      Project: CRQ15757-Miniload In Reserve Fixes
**                      Forget to put swms in front of the table name.
****************************************************************************/

/********************************************************************
**    Add columns to the PRIORITY_CODE table
********************************************************************/

ALTER TABLE swms.priority_code ADD (delete_at_start_of_day VARCHAR2(1));
ALTER TABLE swms.priority_code ADD (retention_days         NUMBER);

--
-- Create check constraints.
--
ALTER TABLE swms.priority_code ADD CONSTRAINT
   prio_delete_at_startofday_chk CHECK (delete_at_start_of_day IN ('Y', 'N'));

ALTER TABLE swms.priority_code ADD CONSTRAINT
   prio_retention_days_chk CHECK (retention_days BETWEEN 0 and 365);


