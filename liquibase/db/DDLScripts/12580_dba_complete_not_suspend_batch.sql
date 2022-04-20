
SET ECHO ON

/****************************************************************************
** sccs_id=%Z% %W% %G% %I%
**
** Date:       14-APR-2010
** Programmer: Brian Bent
** File:       12580_dba_complete_not_suspend_batch.sql
** Defect#:    12580
** Project:    CRQ16476-Complete Not Suspend Labor Mgmt Batch
** Project Description:
**             Change the suspend batch processing.
**             Make HL hauls out of the batches where the task is not completed.
**             If the parent batch task is not done then find a new parent
**             batch from one of the completed tasks.  The haul batches will
**             start with HL.  Suspend the labor mgmt batch for the tasks not
**             yet completed.  Designate a new parent batch when necessary for
**             the suspended batch(s).
**
**             Before everything was suspended.  We are making these changes
**             because LXLI cannot handle a batch performed within the time
**             of another batch which the current suspend batch processing
**             will do.
** 
** This script performs the DDL for this project.
**
** This script needs to be run once when the changes are installed at
** the OpCo.  Inadvertently running this script again will not cause any
** problems.
**
** Table Changes:
**    ********************************************
**    ***** BATCH Table and ARCH_BATH Table  *****
**    ********************************************
**    Add columns to BATCH table and ARCH_BATCH table.
**    The new columns are:
**       - initial_pickup_scan_date          DATE
**            The date and time the pallets were scanned when picked up the
**            first time.  It will be populated only when the user breaks away
**            to another task.  This allows us to have a record of the scan
**            order when the pallets where first picked up.  It may get used
**            by lxli forklift labor to order the pallets in scan order.
**            If null then look at the actl_start_time to get the scan order.
**
**       - ref_batch_no                      VARCHAR2(13)
**            For a HL batch this will be the batch it was created from.
**            Could be useful for researching issues.
**
**       - dropped_for_a_break_away_flag   VARCHAR2(1)
**            Set to Y for batches where the task is not completed when the
**            forklift operator breaks away to another batch.
**            These batches will have hauls created from them and then will
**            be suspended.
**            The main reason for this column is to help in reseaching
**            issues and possible use by LXLI.
**            The valid values are NULL, N or Y.
**
**       - resumed_after_break_away_flag     VARCHAR2(1)
**            Set to Y if the batch was resumed after a break away.  If there
**            was an RF issue resulting in rebooting the RF and the user goes
**            back to pick up the pallets to finish then this will be starting
**            the batch from the beginning so this column will not be set
**            to Y.  The main reason for this column is to help in reseaching
**            issues and possibe use by LXLI.
**            The valid values are NULL, N or Y.
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    04/20/10 prpbcb   Created.
**
**    07/19/10 prpbcb   Activity: SWMS12.0.0_0000_QC11345
**                      Project:  QC11345
**                      Copy from rs239b.
**
****************************************************************************/

/********************************************************************
**    Add columns to the BATCH table
********************************************************************/
ALTER TABLE swms.batch ADD (ref_batch_no                  VARCHAR2(13));
ALTER TABLE swms.batch ADD (dropped_for_a_break_away_flag VARCHAR2(1));
ALTER TABLE swms.batch ADD (resumed_after_break_away_flag VARCHAR2(1));
ALTER TABLE swms.batch ADD (initial_pickup_scan_date      DATE);

-------------------------------------
-- Create check constraints.
-------------------------------------
ALTER TABLE swms.batch ADD CONSTRAINT batch_dropfor_a_brkawayflag
   CHECK (dropped_for_a_break_away_flag IN ('N', 'Y'))
/

ALTER TABLE swms.batch ADD CONSTRAINT batch_resume_afterbrkawayflag
   CHECK (resumed_after_break_away_flag IN ('N', 'Y'))
/



/********************************************************************
**    Add columns to the BATCH table
********************************************************************/
ALTER TABLE swms.arch_batch ADD (ref_batch_no                  VARCHAR2(13));
ALTER TABLE swms.arch_batch ADD (dropped_for_a_break_away_flag VARCHAR2(1));
ALTER TABLE swms.arch_batch ADD (resumed_after_break_away_flag VARCHAR2(1));
ALTER TABLE swms.arch_batch ADD (initial_pickup_scan_date      DATE);

-------------------------------------
-- Create check constraints.
-------------------------------------
ALTER TABLE swms.arch_batch ADD CONSTRAINT abatch_dropfor_a_brkawayflag
   CHECK (dropped_for_a_break_away_flag IN ('N', 'Y'))
/

ALTER TABLE swms.arch_batch ADD CONSTRAINT abatch_resume_afterbrkawayflag
   CHECK (resumed_after_break_away_flag IN ('N', 'Y'))
/


