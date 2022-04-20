CREATE OR REPLACE PACKAGE      pl_lmf
IS

   --  sccs_id=%Z% %W% %G% %I%

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lmf
   --
   -- Description:
   --    Forklift labor management package.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/15/00 prpbcb   DN 10514 Ticket 232712  Created.  This may one day
   --                      replace the PRO*C program lm_forklift.pc.  The
   --                      initial use is for function f_get_fk_door_no.
   --
   --    06/27/01 prpbcb   DN 10590  Project: appswms-FL-door
   --                      Added procedures/functions:
   --                         - update_erm_door_no
   --                         - f_valid_fk_door_no
   --                         - f_forklift_active
   --
   --    01/16/02 prpbcb   rs239a DN 10726   Ticket 291209
   --                      Fix bug in function f_get_fk_door_no
   --                      that would not handle door '0' correctly.
   --                      It ltrims leading '0's from i_door_no but if
   --                      i_door_no is one or more '0's then the ltrim
   --                      results in a null.
   --
   --    07/15/03 prpbcb   Oracle 7 DN none  Not dual maintained at this time
   --                               which is OK.
   --                      Oracle 8 DN 11321
   --                      Added objects to check if all the operations for a
   --                      batch are completed.  This includes merged batches.
   --                      Such as for a putaway batch all the pallets have
   --                      been putaway.  The approach taken to see if the
   --                      operation is complete varies by the task.  Some
   --                      check by looking at the task table such as
   --                      PUTAWAYLST or REPLENLST.  Others look at the TRANS
   --                      table.
   --                      Be aware that if the RF aborts abnormally in the
   --                      middle of a task the data will most likely be out
   --                      of sync so the functions may return an incorrect
   --                      value.
   --
   --                      A undo of DN 11261 was made to get DN 11321 before
   --                      DN 11261.  DN 11321 will include the changes made in
   --                      DN 11261 which is fine.
   --
   --                      These changes can be moved over to oracle 7 without
   --                      affecting anything.
   --
   --    07/15/03 prpbcb   rs239a DN none  Not dual maintained at this time
   --                             which is OK.
   --                      rs239b DN 11261
   --                      RDC LPN 18 modifications.  These changes can be
   --                      moved over to oracle 7 without affecting anything.
   --
   --                      Created objects to create the different types of
   --                      forklift labor mgmt batches.  This is the
   --                      implemention of function lmf_create_batch() in
   --                      lm_forklift.pc.  Did only the putaways at this time
   --                      as this is what is required for RDC LPN 18.
   --
   --                      Changed to call f_get_syspar in pl_common.  Deleted
   --                      f_get_syspar from pl_lmf.
   --
   --                      ***************************************************
   --                      This file may end up not being checked in under
   --                      DN 11261 because of other changes made whick we do
   --                      not want to tie in the the LPN 18 defect.  The LPN 18
   --                      changes will not affect non LPN 18 companies since
   --                      only new objects were added.  The only thing needed
   --                      is new sequence forklift_lm_batch_no_seq.NEXTVAL.
   --                      We may want to take this sequence out of DN 11261.
   --                      ***************************************************
   --
   --    07/15/03 prpbcb   rs239a DN none  Not dual maintained at this time
   --                             which is OK.
   --                      rs239b DN 11338
   --                      Demand HST changes.
   --                      Added procedure all_home_slot_xfer_completed.
   --
   --    08/21/03 prpbcb   rs239a DN none  Not dual maintained at this time
   --                             which is OK.
   --                      rs239b DN 11354
   --                      Changed function all_demand_rpl_completed
   --                      to look at the trans table for DFK transactions
   --                      in determining if the demand replenishments are
   --                      finished.
   --
   --    08/21/03 prpbcb   Oracle 7 rs239a DN none  Not dual maintainced
   --                                      which is OK.
   --                      Oracle 8 rs239b dvlp8 DN none.  Not dual maintained.
   --                      Oracle 8 rs239b dvlp9 DN 11416
   --                      MSKU changes.  Modified procedures and added new
   --                      procedures.
   --                      New procedures:
   --                         - create_normal_putaway_batches   
   --                         - create_msku_putaway_batches   
   --                         - create_transfer_batch
   --                         - update_xfr_batch
   --                         - create_home_slot_xfer_batch
   --                      Modified procedures:
   --                         - create_putaway_batches   
   --
   --                      Implemented the following from lm_forklift.pc:
   --                         - make_batch_parent (lmf_make_batch_parent)
   --                         - create_haul_batch_id (lmf_create_haul_batch_id)
   --
   --    12/05/03 prpbcb   Oracle 7 rs239a DN none
   --                      Oracle 8 rs239b dvlp8 DN none
   --                      Oracle 8 rs239b dvlp9 DN 11444
   --                      Changed cursor c_dmd_task in procedure 
   --                      all_demand_rpl_completed from
   --                            WHERE t.cmt = SUBSTR(b.batch_no, 3)
   --                      to
   --                            WHERE t.labor_batch_no = b.batch_no
   --
   --                      Implemented the following from lm_forklift.pc:
   --                         - reset_batch (lmf_reset_batch plus changes to
   --                                        account for a haul)
   --                      New procedures:
   --                         - create_nondemand_rpl_batch
   --
   --    02/04/04 prpbcb   Oracle 7 rs239a DN none  Not dual maintained.
   --                      Oracle 8 rs239b swms8 DN 11495
   --                      Oracle 8 rs239b swms9 DN 11496
   --                      Project:  00470843 SWMS-HST Frz Up
   --
   --                      Changed function all_tasks_completed to handle a
   --                      indirect batch.  The value returned will always be
   --                      true since indirect batches are not merged.  This
   --                      change was made because a scenario that had
   --                      function lmf_signon_to_forklift_batch in
   --                      lm_forklift.pc checking to see of all tasks were
   --                      completed when the users active batch was
   --                      an indirect batch.  lmf_signon_to_forklift_batch
   --                      is sent a flag to designate to complete, merge or
   --                      suspend the users active batch.  If the flag is
   --                      suspend then a check is made if all the tasks are
   --                      completed for the batch and if they are then the
   --                      batch is completed and not suspended because
   --                      it is not correct to suspend the batch.  The calling
   --                      function at times does not send the correct value
   --                      as to whether the batch should be completed or
   --                      suspended which traces back to what the RF has sent.
   --
   --                      The scenario that caused the problem is:
   --           Multi-pallet putaway of 2 pallets with two NDM's during
   --           putaway performed after the putaway of the first pallet
   --           with a DHST for each NDM.  The putaways will not prompt
   --           for DHST.  The NDM's are not merged.  Testing func1 at the
   --           destination location prompt for each DHST.
   --           PUT (m) (res)
   --              NDM (p)
   --                 DHST  Func1 at destination location prompt.
   --              NDM (p)   <- Got error when scanning the pallet at the
   --                           reserve slot.
   --                 DHST  Func1 at destination location prompt.
   --           PUT (m) (res)
   --
   --    05/13/04 prpbcb   Oracle 7 rs239a DN none
   --                      Oracle 8 rs239b swms8 DN 11581
   --                      Oracle 8 rs239b swms9 DN 11582
   --                      Ticket 519149
   --                      Change procedure update_erm_door_no to strip
   --                      leading alpha characters in the SUS door number.
   --                      This was done so that SUS does not have to redo
   --                      the inbound scheduling when going to forklift labor
   --                      mgmt and on SUS the door is prefixed with the area.
   --                      Example:  Door 01 in dry was entered in SUS
   --                                as D01.
   --
   --    05/24/04 prpbcb   Oracle 7 rs239a DN none
   --                      Oracle 8 rs239b swms8 DN none
   --                      Oracle 8 rs239b swms9 DN 11615
   --                      The putaway labor mgmt batch was not being created
   --                      when specifying to create the batch for a single LP.
   --                      The cursors in the following procedures where
   --                      modified to correct this:
   --                         - create_normal_putaway_batches;
   --                         - create_msku_putaway_batches
   --
   --    10/05/04 prpbcb   Oracle 7 rs239a DN None
   --    01/07/05          Oracle 8 rs239b swms8 DN None
   --                      Oracle 8 rs239b swms9 DN 11861
   --                      Returns putaway changes and bug fixes.
   --                      The program needs to be checked in before the returns
   --                      changes are completed.  The changes made for the
   --                      returns putaway will be left in because they will
   --                      not affect other processing.
   --                 
   --                      ----- Returns Changes -----
   --                      Initialize record t_create_putaway_stats_rec
   --                      to 0.
   --                      Added procedure create_returns_putaway_batches
   --                      for returns putaway labor mgmt.
   --                      Added parameter i_kvi_from_loc to procedure
   --                      create_msku_putaway_batches.
   --                      Added procedure f_is_returns_putaway_active.
   --
   --                      Removed check if forklift labor mgmt is active
   --                      in procedures:
   --                         - create_normal_putaway_batches
   --                         - create_msku_putaway_batches
   --                      These procedures are private to the package and
   --                      are called by other procedures.  These other
   --                      procedures will check if forklift labor mgmt is
   --                      active.
   --
   --                      ----- Bug Fix -----
   --                      A cursor in create_msku_putaway_batches was
   --                      joining to the PM table but there was no criteria
   --                      in the where clause thus all the records in the PM
   --                      table were selected.
   --
   --                      ----- Bug Fix -----
   --                      Procedure create_msku_putaway_batches was changed
   --                      to update the batch cube, weight, etc. when it was
   --                      called to create a batch for a child LP and the
   --                      child LP is going to a reserve slot and the batch
   --                      already exists.  For a MSKU going to a reserve slot
   --                      one batch is created for all the child LP's going
   --                      to the reserve slot.  When a PO/SN is opened and
   --                      the MSKU is going to a reserve slot and a reserve
   --                      slot is found then everything is fine.  If a reserve
   --                      slot is not found then all the child LP's going to
   --                      reserve will get a '*' location.  In the check-in
   --                      screen the user will need to enter a location over
   --                      the '*'.  For a slotted item the user can enter a
   --                      the home slot (even though the open PO/SN process
   --                      may not have direted the child LP to the home slot)
   --                      or a reserve slot.  If the home slot is entered then
   --                      things are OK as a separate batch will be created
   --                      for the child LP.  If a reserve location is entered
   --                      then this reserve location will be applied to each
   --                      child LP going to reserve.  When the form is
   --                      committing procedure create_putaway_batch_for_lp
   --                      is called for each child LP that had a location
   --                      keyed over a '*.  For the first child LP going to
   --                      reserve the batch will be created using the cube,
   --                      weight, etc for that LP.  For the remaining child
   --                      LP's going to to reserve the batch is not created
   --                      because it already exists.  This is fine except the
   --                      cube, weight, etc of the reserve batch is not
   --                      updated with the additional child LP's.  Now they
   --                      will be.
   --
   --    01/20/05          Oracle 8 rs239b swms8 DN None
   --                      Oracle 8 rs239b swms9 DN 11862
   --                      In procedure create_msku_putaway_batches() changed
   --                      the where clause in cursor c_putaway 
   --                      from
   --                          AND lz.logi_loc         = p.dest_loc
   --                      to
   --                          AND lz.logi_loc         = cp_dest_loc
   --                      for the select statement for a single LP.
   --                      The putawaylst does not have the dest_loc populated 
   --                      yet when the batch is created so the the join
   --                      needs to made to the cursor parameter dest_loc
   --                      and not the potawaylst.dest_loc.  Creating a batch
   --                      for a single LP occurs when a location is keyed
   --                      over a '*' in the check-in screen rp1sc.
   --
   --    02/10/05          Oracle 8 rs239b swms8 DN None
   --                      Oracle 8 rs239b swms9 DN 11873
   --                      Procedure create_msku_putaway_batches() was not
   --                      updating the putawaylst.pallet_batch_no when
   --                      it was creating a batch for a single LP going to a
   --                      reserve slot.
   --
   --                      Rewrote f_putaway_batch_exists() as a procedure
   --                      called find_existing_putaway_batch() because there
   --                      was a situation where the existing batch # was
   --                      needed.  The procedure will return the batch # in
   --                      a parameter.  If no batch is found then the
   --                      parameter is set to null.
   --
   --                      Added procedure delete_putaway_batch to
   --                      delete a putaway batch from the BATCH table.
   --                      The check-in form was modified to call it when
   --                      processing in the form requires the putaway batch
   --                      to be deleted which happens when the qty received
   --                      is changed to 0.
   --                      Before the form did the delete but for a MSKU
   --                      special processing is required because the child
   --                      LP's going to reserve are tied to one batch so the
   --                      putaway batch is deleted only when there are no
   --                      child LP's with qty > 0.
   --
   --    02/22/05          Oracle 8 rs239b swms9 DN 11879
   --                      In procedure create_msku_putaway_batches, added
   --             AND parent_pallet_id IS NOT NULL  -- Want only MSKU's
   --                      in the select stmt counting putawaylst records
   --                      with * location for a PO.  Before it would include
   --                      non-MSKU pallets.  This did not cause a problem
   --                      except for a bogus count in a log message.
   --
   --    03/10/05          Oracle 8 rs239b swms9 DN 11884
   --                      Returns changes.  Change batch.cmt when creating
   --                      the returns FP batch.
   --
   --    04/13/05          Oracle 8 rs239b swms9 DN 11903
   --                      Function all_tasks_completed() was not handling
   --                      batch type HP.  I came across this error in SWMS_LOG
   --                      while researching an issue at OpCo 22:
   --           pl_lmf.all_tasks_completed(i_batch_no[HP69693])  Batch type
   --           [HP] not handled in this function.                            
   --                      In happended in upd_rep_pk.  I also added handling
   --                      of the HX batch type.
   --
   --    08/02/05 prpbcb   Oracle 8 rs239b swms9 DN 11974
   --                      Project: CRT-Carton Flow replenishments
   --
   --                      Added procedure create_dmd_rpl_hs_xfer_batch()
   --                      (FE batch).  This procedure creates the demand
   --                      replenishment transfer batch.  This happens when
   --                      the forklift operator has performed a demand
   --                      replenishment and not all the cases fit in the slot.
   --                      Cases are being transferred back to reserve with the
   --                      transfer qty > qoh in the home slot.  The qty
   --                      transferred > qoh indicates the replenishment was
   --                      only partially completed.
   --
   --                      Changed function all_tasks_completed() to handle
   --                      the FE batch.
   --
   --    03/03/06 prpbcb   Oracle 8 rs239b swms9 DN 12072
   --                      WAI changes.
   --                      Modified procedure create_nondemand_rpl_batch()
   --                      to also look at repl type MNL.
   --                      Created an overloaded create_nondemand_rpl_batch()
   --                      procedure that takes only the task id.
   --
   --                      03/08/06 Handle rule id 3.
   --                      Modified:
   --                         - update_msku_batch_info()
   --                         - create_msku_putaway_batches()
   --                      End WAI changes.
   --
   --    03/12/06 prpbcb   Oracle 8 rs239b swms9 DN 12072
   --                      Returns T batch issue.
   --                      Modified procedure create_msku_putaway_batches()
   --                      to create a separate batch for each LP when
   --                      processing a return.  Before if the putawaylst
   --                      destination location of the return was a reserve
   --                      slot as indicated by the put zone of the destination
   --                      location having rule 0 then an attempt was made to
   --                      create one batch for all the the rule 0 putawaylst
   --                      destination locations.  This is what is needed for
   --                      receiving a MSKU on a SN but not for a return. 
   --
   --    03/16/06 prpbcb   Oracle 8 rs239b swms9 DN 12072
   --                      Noted that procedure create_rtn_msku_put_batches()
   --                      is not used.
   --
   --    04/20/10 prpbcb   DN 12571
   --                      Project: CRQ15757-Miniload In Reserve Fixes
   -- 
   --                      Created procedure:
   --                         - create_ml_rpl_batch().
   --                      It is called by upd_mnl_pk.pc to create the
   --                      miniloader replenishment labor batch from the
   --                      replenlst record.  create_ml_rpl_batch() calls
   --                      create_nondemand_rpl_batch to actually create the
   --                      batch.
   --
   --                      Modified procedure:
   --                         - create_nondemand_rpl_batch()
   --                      Overloaded it adding new parameter o_batch_no.
   --                      This is so that the calling object can know
   --                      labor batch number created.
   --                      Changed to look at the replenishment type and if it
   --                      is a miniloader replenishment to look at the
   --                      priority to create either a FN batch (non-demand) or
   --                      a FR batch (demand).  Changed the processing to
   --                      select the info for creating the labor batch into a 
   --                      record then insert into to the BATCH table so that
   --                      we can use the RETURNING clause to get the labor
   --                      batch number(this is one way to do this).  We want
   --                      the labor batch number so that it can be returned
   --                      to the calling program. (Oracle does not like using
   --                      the RETURNING clause in a INSERT INTO ... SELECT
   --                      FROM ...)
   --                      After creating the labor batch in the BATCH table
   --                      the replenlst.labor_batch_no is updated with the
   --                      labor batch number.
   --
   --                      (Changes that are part of the project for not
   --                      suspending batches that will be included in the
   --                      MLR fixes.  The changes do not depend on
   --                      anything so they can be included with the MLR fixes)
   --                      Changed the tasks completed functions to accept
   --                      a second parameter which desigates to check only
   --                      that the task is completed for the batch passed
   --                      as a parameter and not to check the tasks for child
   --                      batches.
   --                      Functions modified:
   --                         - all_demand_rpl_completed
   --                         - all_dmd_rpl_hs_xfer_completed
   --                         - all_home_slot_xfer_completed
   --                         - all_nondemand_rpl_completed
   --                         - all_putaway_completed
   --                         - all_tasks_completed
   --
   --    05/10/10 prpbcb   DN 12580
   --                      Project:
   --                          CRQ16476-Complete Not Suspend Labor Mgmt Batch
   --
   --                      Created procedure task_completed_for_batch().
   --                      It returns Y or N so it can be used in a SQL
   --                      statement. It calls all_tasks_completed to do 
   --                      all the work.
   --
   --                      Added procedures get_new_batch() and
   --                      get_suspended_batch().
   --
   --    07/19/10 prpbcb   Activity: SWMS12.0.0_0000_QC11345
   --                      Project:  QC11345
   --                      Copy from rs239b.
   --
   --                      Default value for i_dest_loc parameter in
   --                      specification for procedure create_putaway_batches()
   --                      did not batch that in the body.  Changed the
   --                      specification.
   --
   --    12/08/10 prppxx   Activity: SWMS12.0.0_0064_CRQ19462
   --                      Add procedure create_all_ndm_rpl_batch to create
   --                      labor batch for NDM repl.
   --                      It is called from form PN1SA for "commit all" task.
   --
   --    01/19/11 prpbcb   Activity: SWMS12.0.1_0195_CRQ20656
   --                      Clearcase View: SWMS_DEVELOPMENT_VIEW
   --
   --                      Activity: SWMS12.2_0195_CRQ20656
   --                      Clearcase View: SWMS_SAP_IF_DVLP_VIEW
   --
   --                      Project: CRQ20656-Duplicate forklift labor batch
   --                      Incident: 652458
   --
   --                      ----- Bug Fix -----
   --                      Procedure create_all_ndm_rpl_batch() would sometimes
   --                      duplicate a NDM labor batch.
   --                      If a non-demand replenishment and the associated
   --                      forklift labor batch are created using the RF
   --                      Replenishment By Location option and the
   --                      replenishment is not performed then the replenishment
   --                      task and forklift labor batch stays in SWMS.  If the
   --                      next day the user creates non-demand replenishments
   --                      using the CRT screen then the labor mgmt batch will
   --                      be re-created. They labor batches will be the
   --                      same except for the batch date.  Having duplicate
   --                      forklift labor batches is a problem.
   --
   --                      Modified the create_all_ndm_rpl_batch() to create
   --                      check if the batch already exists in the BATCH
   --                      table.
   --
   --    09/11/14 prpbcb   Symbotic changes.
   --                      The PUT zone for the matrix locations have a 
   --                      rule id of 5.  Changed appropriate programs to
   --                      handle rule id 5.
   --                      Programs changed:
   --                         - update_msku_batch_info
   --                         - create_msku_putaway_batches
   --                     Basically we are treating the matrix induction
   --                     location like the miniloader induction location.
   --
   --
   --   09/26/14 prpbcb   Symbotic changes.  Fix bug I introduced on 09/11/14.
   --                     I had put "INDUCTION" in a variable used to populate
   --                     BATCH.CMT.  This exceeded the 60 characters. the
   --                     variable can hold.  I removed "INDUCTION".
   -- 
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/26/16 bben0556 Brian Bent
   --                      Project:
   --             R30.6--WIE#669--CRQ000000008118_Live_receiving_story_33_find_dest_loc
   --
   --                      Handle PUTAWAYLST.DET_LOC of 'LR' same as '*'.
   --                      Added field "num_alive_receiving_location" to
   --                      record type "t_create_putaway_stats_rec"
   --
   --   08/31/20  mcha1213   add create_dci_batch
   --   02/01/21  mcha1213   add erm.erm_type='CM' to create_dci_putaway_batches
   --   02/05/21  mcha1213   add validation for Saleable validation for create_dci_putaway_batches
   --   29-Apr-21 pkab6563   Jira 3279 - Added procedures create_swap_batch() 
   --                        and delete_swap_batch()
   --
   -- 08-Oct-2021 pkab6563   Copied procedures reset_batch_for_tasks_not_done(),
   --                        reset_batch_if_task_not_compl(), and
   --                        create_dflt_fk_ind_batch() from RDC SWMS for Jira 3700
   --                        to allow to signoff from forklift batches.
   ---------------------------------------------------------------------------
   --
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--
--    09/10/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3663_OP_Site_2_Merge_float_ordcw_sent_from_Site_1
--
--                      Create procedure "create_xdk_pallet_pull_batch" to create
--                      forklift labor mgmt batch for XDK tasks.  These are cross dock
--                      pallet pulls at Site 2.
--                      Some info about XDK tasks.
--                           FLOATS.CROSS_DOCK_TYPE is 'X'
--                           FLOATS.PALLET_PULL is 'B'
--
--    10/11/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3714_OP_Site_2_floats_door_area_sometimes_incorrect
--
--                      Create function "does_batch_exist".  Copied from RDC version of pl_lmc.sql.
---------------------------------------------------------------------------


   ---------------------------------------------------------------------------
   -- Global Type Declarations
   ---------------------------------------------------------------------------

   -- This record is for recording statistics on the putaway batches created.
   TYPE t_create_putaway_stats_rec IS RECORD
      (no_records_processed         PLS_INTEGER := 0,
       no_batches_created           PLS_INTEGER := 0,
       no_batches_existing          PLS_INTEGER := 0,
       no_not_created_due_to_error  PLS_INTEGER := 0,
       no_with_no_location          PLS_INTEGER := 0,
       num_live_receiving_location  PLS_INTEGER := 0);

   -- Description:
   -- no_records_processed - Number of records processed.  If 0 then this
   --                        indicates the key value is not in the putawaylst
   --                        table or forklift labor mgmt is not active.  This
   --                        should equal the # of batches created +
   --                        # of batches existing + # of batches not
   --                        created because of an error + # of tasks
   --                        with no location + num_live_receiving_location
   -- no_batches_created   - Number of batches successfully created.
   -- no_batches_existing  - Number of batches that already exist.
   --                        (Got DUP_VAL_ON_INDEX exception)
   -- no_not_created_due_to_error - Number of batches not created because
   --                               of a data setup issue or an oracle error.
   -- no_with_no_location    - Number of batches not created because no putaway
   --                          location was found for the pallet which is
   --                          indicated by the putaway task dest loc = '*'.
   -- num_live_receiving_location  - Number of batches not created because
   --                                it is a Live Receiving pallet with the
   --                                location initially set to 'LR'.
   --

   ---------------------------------------------------------------------------
   -- Global Variables
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ------------------------------------------------------------------------
   -- Function:
   --    all_tasks_completed
   --
   -- Description:
   --    This function determines if all the tasks associated with a
   --    forklift labor mgmt batch are completed.
   --
   --    If i_check_batch_only_bln is FALSE then the parent and all child
   --    batches are checked and if the parent or any child taks is not done
   --    then FALSE is returned.
   --    If i_check_batch_only_bln is TRUE then only i_batch_no is checked.
   --
   --    Returns a BOOLEAN.
   ------------------------------------------------------------------------
   FUNCTION all_tasks_completed
                (i_batch_no              IN arch_batch.batch_no%TYPE,
                 i_check_batch_only_bln  IN BOOLEAN DEFAULT FALSE)
   RETURN BOOLEAN;

   ------------------------------------------------------------------------
   -- Function:
   --    task_completed_for_batch
   --
   -- Description:
   --    This function determines if the task associated with a
   --    specified forklift labor mgmt batch is completed.  Returns Y or N.
   --    It calls all_tasks_completed to do all the work.
   ------------------------------------------------------------------------
   FUNCTION task_completed_for_batch
                (i_batch_no              IN arch_batch.batch_no%TYPE)
   RETURN VARCHAR2;

   ------------------------------------------------------------------------
   -- Function:
   --    all_putaway_completed
   --
   -- Description:
   --    This function determines if all the putaway tasks associated with a
   --    forklift labor mgmt batch are completed.
   ------------------------------------------------------------------------
   FUNCTION all_putaway_completed
                (i_batch_no              IN arch_batch.batch_no%TYPE,
                 i_check_batch_only_bln  IN BOOLEAN DEFAULT FALSE)
   RETURN BOOLEAN;

   ------------------------------------------------------------------------
   -- Function:
   --    all_nondemand_rpl_completed
   --
   -- Description:
   --    This function determines if all the non-demand replenishments tasks
   --    associated with a forklift labor mgmt batch are completed.
   ------------------------------------------------------------------------
   FUNCTION all_nondemand_rpl_completed
                (i_batch_no              IN arch_batch.batch_no%TYPE,
                 i_check_batch_only_bln  IN BOOLEAN DEFAULT FALSE)
   RETURN BOOLEAN;

   ------------------------------------------------------------------------
   -- Function:
   --    all_demand_rpl_completed
   --
   -- Description:
   --    This function determines if all the demand replenishments tasks
   --    associated with a forklift labor mgmt batch are completed.
   ------------------------------------------------------------------------
   FUNCTION all_demand_rpl_completed
                (i_batch_no              IN arch_batch.batch_no%TYPE,
                 i_check_batch_only_bln  IN BOOLEAN DEFAULT FALSE)
   RETURN BOOLEAN;

   ------------------------------------------------------------------------
   -- Function:
   --    all_home_slot_xfer_completed
   --
   -- Description:
   --    This function determines if all the home slot transfers tasks
   --    associated with a forklift labor mgmt home slot transfer batch
   --    are completed.
   ------------------------------------------------------------------------
   FUNCTION all_home_slot_xfer_completed
                (i_batch_no              IN arch_batch.batch_no%TYPE,
                 i_check_batch_only_bln  IN BOOLEAN DEFAULT FALSE)
   RETURN BOOLEAN;

   ------------------------------------------------------------------------
   -- Function:
   --    all_dmd_rpl_hs_xfer_completed
   --
   -- Description:
   --    This function determines if all the demand replenishment home slot
   --    transfers tasks associated with the forklift labor mgmt batch
   --    are completed.
   ------------------------------------------------------------------------
   FUNCTION all_dmd_rpl_hs_xfer_completed
                (i_batch_no              IN arch_batch.batch_no%TYPE,
                 i_check_batch_only_bln  IN BOOLEAN DEFAULT FALSE)
   RETURN BOOLEAN;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_forklift_active
   --
   -- Description:
   --    This function determines if forklift labor mgmt is active.
   ---------------------------------------------------------------------------
   FUNCTION f_forklift_active
   RETURN BOOLEAN;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_is_returns_putaway_active
   --
   -- Description:
   --    This function determines if returns putaway labor mgmt is active.
   ---------------------------------------------------------------------------
   FUNCTION f_is_returns_putaway_active
   RETURN BOOLEAN;

   ---------------------------------------------------------------------------
   -- m.c.
   -- Function:
   --    f_is_dci_putaway_active
   --
   -- Description:
   --    This function determines if returns putaway fork lift labor mgmt is active.
   ---------------------------------------------------------------------------
   FUNCTION f_is_dci_putaway_active
   RETURN VARCHAR2;  -- RETURN BOOLEAN;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_fk_door_no
   --
   -- Description:
   --    This function returns the forklift labor management four digit door
   --    when given a two digit door number.  If unable to determine the
   --    forklift door number then null is returned.
   ---------------------------------------------------------------------------
   FUNCTION f_get_fk_door_no(i_door_no IN VARCHAR2)
   RETURN VARCHAR2;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_valid_fk_door_no
   --
   -- Description:
   --    This function determines if a door number is a valid forklift
   --    labor mgmt door number.
   ---------------------------------------------------------------------------
   FUNCTION f_valid_fk_door_no(i_door_no IN VARCHAR2)
   RETURN BOOLEAN;

   ------------------------------------------------------------------------
   -- Function:
   --    f_create_haul_batch_id
   --
   -- Description:
   --    This function creates the batch number if for a haul created from
   --    a func1 during putaway.  The format of the batch number is
   --    <HX><seq#>
   ------------------------------------------------------------------------
   FUNCTION f_create_haul_batch_id
   RETURN arch_batch.batch_no%TYPE;

   ------------------------------------------------------------------------
   -- Function:
   --    f_create_ret_to_res_batch_id
   --
   -- Description:
   --    This function creates the batch number for the return of the MSKU
   --    to reserve after a NDM or DMD.
   --    The format of the batch number is <FM><seq#>.
   ------------------------------------------------------------------------
   FUNCTION f_create_ret_to_res_batch_id
   RETURN arch_batch.batch_no%TYPE;

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_putaway_batches
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batches for putaway
   --   tasks if forklift labor management is active.  The batches can be
   --   created for a PO or for a single license plate.  A batch will not be
   --   created for putaway tasks with a destination location of '*' when
   --   creating for a PO or when creating for a single license plate
   --   and i_dest_loc is null.
   --
   --   After the batch is created the putawaylst.pallet_batch_no is updated
   --   with the batch number.
   ---------------------------------------------------------------------------
   PROCEDURE create_putaway_batches
         (i_create_for_what              IN  VARCHAR2,
          i_key_value                    IN  VARCHAR2,
          i_dest_loc                     IN  putawaylst.dest_loc%TYPE := NULL,
          o_no_records_processed         OUT PLS_INTEGER,
          o_no_batches_created           OUT PLS_INTEGER,
          o_no_batches_existing          OUT PLS_INTEGER,
          o_no_not_created_due_to_error  OUT PLS_INTEGER);

   ---------------------------------------------------------------------------
   -- m.c.
   -- Procedure:
   --    create_dci_batches
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batches for return 
   --   putaway
   --   tasks if forklift labor management is active.  The batches can be
   --   created for a CM or for a single license plate.  A batch will not be
   --   created for putaway tasks with a destination location of '*' when
   --   creating for a CM or when creating for a single license plate
   --   and i_dest_loc is null.
   --
   --   After the batch is created the putawaylst.pallet_batch_no is updated
   --   with the batch number.
   ---------------------------------------------------------------------------
   PROCEDURE create_dci_batches
         (i_create_for_what              IN  VARCHAR2,
          i_key_value                    IN  VARCHAR2,
          i_dest_loc                     IN  putawaylst.dest_loc%TYPE := NULL,
          o_no_records_processed         OUT PLS_INTEGER,
          o_no_batches_created           OUT PLS_INTEGER,
          o_no_batches_existing          OUT PLS_INTEGER,
          o_no_not_created_due_to_error  OUT PLS_INTEGER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_nondemand_rpl_batch  (overloaded)
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt non-demand
   --    replenishment batch from the task id.
   ---------------------------------------------------------------------------
   PROCEDURE create_nondemand_rpl_batch
                (i_task_id                      IN  replenlst.task_id%TYPE,
                 o_batch_no                     OUT arch_batch.batch_no%TYPE,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER);


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_nondemand_rpl_batch  (overloaded)
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt non-demand
   --    replenishment batch from the task id.
   ---------------------------------------------------------------------------
   PROCEDURE create_nondemand_rpl_batch
                (i_task_id                      IN  replenlst.task_id%TYPE,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER);


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_nondemand_rpl_batch  (overloaded)
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt non-demand
   --    replenishment batch from the task id.
   ---------------------------------------------------------------------------
   PROCEDURE create_nondemand_rpl_batch
                (i_task_id                      IN  replenlst.task_id%TYPE,
                 o_batch_no                     OUT arch_batch.batch_no%TYPE);


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_nondemand_rpl_batch  (overloaded)
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt non-demand
   --    replenishment batch from the task id.
   ---------------------------------------------------------------------------
   PROCEDURE create_nondemand_rpl_batch
                (i_task_id                      IN  replenlst.task_id%TYPE);


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_all_ndm_rpl_batch 
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt non-demand
   --    replenishment batch when selection "commit all" on pn1sa.
   ---------------------------------------------------------------------------
   PROCEDURE create_all_ndm_rpl_batch
                (o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_ml_rpl_batch  (overloaded)
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt replenishment batch
   --    for a miniloader replenishment.  The replenishment priority dictates
   --    if a non-demand or demand is created.
   ---------------------------------------------------------------------------
   PROCEDURE create_ml_rpl_batch
                (i_task_id                       IN  replenlst.task_id%TYPE,
                 o_batch_no                      OUT arch_batch.batch_no%TYPE,
                 o_num_records_processed         OUT PLS_INTEGER,
                 o_num_batches_created           OUT PLS_INTEGER,
                 o_num_batches_existing          OUT PLS_INTEGER,
                 o_num_not_created_due_to_error  OUT PLS_INTEGER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_ml_rpl_batch  (overloaded)
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt replenishment batch
   --    for a miniloader replenishment.  The replenishment priority dictates
   --    if a non-demand or demand is created.
   ---------------------------------------------------------------------------
   PROCEDURE create_ml_rpl_batch
                (i_task_id                      IN  replenlst.task_id%TYPE,
                 o_batch_no                     OUT arch_batch.batch_no%TYPE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_demand_rpl_batch
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt demand replenishment
   --    batch.
   --
   --    The batch can be for a DMD created by order processing or can be
   --    for a DMD created as a result of a partially completed DMD being
   --    put back in reserve--demand repl home slot transfer.  Parameter
   --    i_dmd_batch_type designates this.
   --    The valid values for i_dmd_batch_type are:
   --       - pl_lmc.ct_forklift_demand_rpl
   --       - pl_lmc.ct_forklift_dmd_rpl_hs_xfer
   ---------------------------------------------------------------------------
   PROCEDURE create_demand_rpl_batch
                (i_dmd_batch_type               IN  pl_lmc.t_batch_type,
                 i_key_value                    IN  NUMBER,
                 i_force_creation_bln           IN  BOOLEAN DEFAULT FALSE,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER);
   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_pallet_pull_batch
   -- Description:
   --    This procedure creates the forklift labor mgmt batches for pallet
   --    pulls. If the pallet pull has a drop quantity, it creates a batch
   --    for the drop-to-home as well.
   ---------------------------------------------------------------------------

    PROCEDURE create_pallet_pull_batch ( i_float_no IN  floats.float_no%TYPE,
                         o_error    OUT BOOLEAN);
   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_transfer_batch
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batch for a
   --   transfer if forklift labor management is active.  The batch is
   --   created using the trans PPT record which means the PPT record needs
   --   to be created first before calling this procedure.
   --
   --   After the batch is created the trans.labor_batch_no is updated
   --   with the batch number.
   ---------------------------------------------------------------------------
   PROCEDURE create_transfer_batch
                (i_trans_id                     IN  NUMBER,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_home_slot_xfer_batch
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batch for a home slot
   --   transfer if forklift labor management is active.  The batch is
   --   created using the trans PPH record which means the PPH record needs
   --   to be created first before calling this procedure.
   --
   --   After the batch is created the trans.labor_batch_no is updated
   --   with the batch number.
   ---------------------------------------------------------------------------
   PROCEDURE create_home_slot_xfer_batch
                (i_trans_id                     IN  NUMBER,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_dmd_rpl_hs_xfer_batch
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batch for a home slot
   --   transfer if forklift labor management is active.  The batch is
   --   created using the trans PPD record which means the PPD record needs
   --   to be created first before calling this procedure.
   --
   --   After the batch is created the trans.labor_batch_no is updated
   --   with the batch number.
   ---------------------------------------------------------------------------
   PROCEDURE create_dmd_rpl_hs_xfer_batch
                (i_trans_id                     IN  NUMBER,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_return_to_reserve_batch
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt batch for a
   --    MSKU that is being returned back to reserve after a non-demand
   --    or demand replenishment and if the operator aborts the operation.
   --    This batch will be merged with the parent batch of the drop.
   --
   --    For the abort processing the batch will be merged with any completed
   --    drops.  If there are not completed drops then the return to reserve
   --    batch will not be created.
   --
   --   The job code will be that for a transfer job code.
   ---------------------------------------------------------------------------
   PROCEDURE create_return_to_reserve_batch
                          (i_parent_batch_no      IN  arch_batch.batch_no%TYPE,
                           i_abort_processing_bln IN  BOOLEAN DEFAULT FALSE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_putaway_batch_for_lp
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batch for the putaway
   --   task for a single license plate if forklift labor management is active.
   ---------------------------------------------------------------------------
   PROCEDURE create_putaway_batch_for_lp
                (i_pallet_id                    IN  putawaylst.pallet_id%TYPE,
                 i_dest_loc                     IN  putawaylst.dest_loc%TYPE,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_putaway_batches_for_po
   --
   -- Description:
   --   This procedure create the forklift labor mgmt batches for the putaway
   --   tasks with a destination location for a PO if forklift labor
   --   management is active.
   ---------------------------------------------------------------------------
   PROCEDURE create_putaway_batches_for_po
                (i_po_no                        IN  erm.erm_id%TYPE,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    delete_putaway_batch
   --
   -- Description:
   --   This procedure deletes a putaway batch.
   --
   --   It was initially created to be called by the check-in screen when
   --   the qty received was changed to 0.  Usually when the qty is changed to
   --   0 the batch needs to be deleted but for a MSKU special processing is
   --   required because the child LP's going to reserve are tied to one batch
   --   so the the putaway batch is deleted only when there are no child LP's
   --   with qty > 0.
   ---------------------------------------------------------------------------
   PROCEDURE delete_putaway_batch
                      (i_batch_no                IN arch_batch.batch_no%TYPE,
                       i_delete_future_only_bln  IN BOOLEAN DEFAULT FALSE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    make_batch_parent
   --
   -- Description:
   --   This procedure changes a normal batch to a parent batch.
   ---------------------------------------------------------------------------
   PROCEDURE make_batch_parent(i_batch_no    IN arch_batch.batch_no%TYPE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    reset_batch
   --
   -- Description:
   --   This procedure resets a labor mgmt batch.
   ---------------------------------------------------------------------------
   PROCEDURE reset_batch
               (i_batch_no      IN arch_batch.batch_no%TYPE,
                i_drop_location IN arch_batch.kvi_from_loc%TYPE DEFAULT NULL);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    update_xfr_batch
   --
   -- Description:
   --   This procedure updates the kvi_to_loc of a transfer batch using
   --   the dest loc in the trans table.  This happens when the transfer
   --   is completed.  At the start of the transfer the dest loc is unknown
   --   so the batch kvi_to_loc needs to get updated when the transfer is
   --   complete.
   ---------------------------------------------------------------------------
   PROCEDURE update_xfr_batch(i_trans_id   IN  NUMBER,
                              i_dest_loc   IN  loc.logi_loc%TYPE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    update_erm_door_no
   --
   -- Description:
   --   This function updates the erm door number to the corresponding
   --   forklift labor mgmt door number.
   ---------------------------------------------------------------------------
   PROCEDURE update_erm_door_no(i_erm_id             IN  erm.erm_id%TYPE,
                                o_update_success_bln OUT BOOLEAN);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_returns_putaway_batches
   --
   -- Description:
   --    This procedure creates the returns putaway labor mgmt batches.
   --
   --    Returns putaway is very similar to a RDC MSKU.  Returns are
   --    accumulated on a physical pallet until the pallet reaches a
   --    designated cube limit.  A LP is created for each item returned and
   --    the LP can have more than one case.  The returns processing will tie
   --    the putaway task together by the parent pallet id.  The difference
   --    for a return is the putaway labor mgmt batches are not created
   --    until the operator starts the putaway process and a LP can have
   --    more than one case.
   --
   --    One scan is made to initiate the returns putaway.  The returns labor
   --    mgmt batches will be created then merged at this time.
   ---------------------------------------------------------------------------
   PROCEDURE create_returns_putaway_batches
             (i_pallet_id          IN  putawaylst.pallet_id%TYPE,
              i_force_creation_bln IN  BOOLEAN DEFAULT FALSE,
              o_batch_no           OUT arch_batch.batch_no%TYPE);


---------------------------------------------------------------------------
-- Procedure:
--    get_new_batch
--
-- Description:
--    This procedure finds the 'N' status batch for a user.  This is the
--    batch the user is in the process of signing onto.  If no batch is
--    found then o_batch_no is set to null.  The procedure is used in the
--    batch completion processing.
---------------------------------------------------------------------------
PROCEDURE get_new_batch
                (i_user_id        IN  arch_batch.user_id%TYPE,
                 o_batch_no       OUT arch_batch.batch_no%TYPE,
                 o_kvi_from_loc   OUT arch_batch.kvi_from_loc%TYPE,
                 o_kvi_to_loc     OUT arch_batch.kvi_to_loc%TYPE);

---------------------------------------------------------------------------
-- Procedure:
--    get_suspended_batch
--
-- Description:
--    This procedure finds the last suspended batch for a user.
--    If no batch is found then o_batch_no is set to null.
---------------------------------------------------------------------------
PROCEDURE get_suspended_batch
                (i_user_id        IN  arch_batch.user_id%TYPE,
                 o_batch_no       OUT arch_batch.batch_no%TYPE,
                 o_kvi_from_loc   OUT arch_batch.kvi_from_loc%TYPE,
                 o_kvi_to_loc     OUT arch_batch.kvi_to_loc%TYPE);

PROCEDURE create_swap_batch
                (i_task_id                      IN  replenlst.task_id%TYPE,
                 i_src_loc                      IN  replenlst.src_loc%TYPE, 
                 i_dest_loc                     IN  replenlst.dest_loc%TYPE,
                 o_no_batches_created           OUT PLS_INTEGER);

PROCEDURE delete_swap_batch
                (i_batch_no            IN   batch.batch_no%TYPE,
                 o_no_batches_deleted  OUT  PLS_INTEGER);

---------------------------------------------------------------------------
-- Function:
--    get_xdk_job_code (public)  Made public so it can be tested by itself.
--
-- Description:
--    This function determines the job code for the XDK bulk pull forkift labor batch.
--
--    A XDK bulk pull differs from a regular bulk pull in that the XDK task source
--    location can be a door number and the pallet can have multiple items on it.
--
--    If unable to detrmine the job code thenn NULL is returned.   The calling program
--    needs to decie what to do it NULL returned.
---------------------------------------------------------------------------
FUNCTION get_xdk_job_code(i_location IN loc.logi_loc%TYPE)
RETURN VARCHAR2;

---------------------------------------------------------------------------
-- Procedure:
--    create_xdk_pallet_pull_batch (public)
--
-- Description:
--    This procedure creates the forklift labor mgmt batch for a
--    R1 XDK pallet pull. This is the main procedure to call.
--
--    For a XDK pallet pull these columns are set as follows.
--        FLOATS.PALLET_PULL      is 'B'
--        FLOATS.CROSS_DOCK_TYPE  is 'X'   <- This is key in identifying the float
---------------------------------------------------------------------------
PROCEDURE create_xdk_pallet_pull_batch
   (
      i_float_no                 IN  floats.float_no%TYPE,
      o_r_create_batch_stats     OUT t_create_putaway_stats_rec
   );

---------------------------------------------------------------------------
-- Procedure:
--    reset_batch_for_tasks_not_done
--
-- Description:
--    This procedure checks if the task corresponding to a forklift labor batch
--    and any child batches are completed.
--    If a task is not completed then the labor batch is reset which consists
--    of unassigning the user from the labor batch and setting the labor batch
--    status to future.  If all the tasks are not completed then the user
--    user is made active on the forklift default indirect batch.
--
--    Procedure "pl_lmf.reset_batch_if_task_not_compl" is called to do the work.
--    It is passed the user's active labor batch to process.
--    "reset_batch_for_tasks_not_done" is passed the user id and finds
--    the users active labor batch and if a forklift batch calls
--    "pl_lmf.reset_batch_if_task_not_compl".
---------------------------------------------------------------------------
PROCEDURE reset_batch_for_tasks_not_done
                  (i_user_id IN  arch_batch.user_id%TYPE);

---------------------------------------------------------------------------
-- Procedure:
--    reset_batch_if_task_not_compl
--
-- Description:
--    This procedure checks if the task corresponding to a forklift labor batch
--    and any child batches are completed.
--    If a task is not completed then the labor batch is reset which consists
--    of unassigning the user from the labor batch and setting the labor batch
--    status to future.  If not all the tasks are completed then the user
--    user is made actie on the forklift default indirect batch.
---------------------------------------------------------------------------
PROCEDURE reset_batch_if_task_not_compl
                  (i_batch_no  IN  arch_batch.batch_no%TYPE);

---------------------------------------------------------------------------
-- Procedure:
--    create_dflt_fk_ind_batch
--
-- Description:
--    This procedure creates the default forklift indirect batch and makes
--    the user active on it.
---------------------------------------------------------------------------
PROCEDURE create_dflt_fk_ind_batch
                        (i_batch_no    IN   arch_batch.batch_no%TYPE,
                         i_user_id     IN   arch_batch.user_id%TYPE,
                         i_ref_no      IN   arch_batch.ref_no%TYPE,
                         i_start_time  IN   arch_batch.actl_start_time%TYPE,
                         o_status      OUT  PLS_INTEGER);


END pl_lmf;

/


CREATE OR REPLACE PACKAGE BODY      pl_lmf
IS

   --  sccs_id=%Z% %W% %G% %I%

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lmf
   --
   -- Description:
   --    Forklift labor management package.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------  ----------------------------------------------------
   --    08/15/00 prpbcb   DN 10514 Ticket 232712  Created.  This may one day
   --                      replace the PRO*C program lm_forklift.pc.  The
   --                      initial use is for function f_get_fk_door_no.
   --
   --    07/15/03 prpbcb   rs239a DN none  Not dual maintained at this time
   --                             which is OK.
   --                      rs239b DN 11338
   --                      Demand HST changes.
   --                      Added procedure all_home_slot_xfer_completed.
   --
   --    08/21/03 prpbcb   rs239a DN none  Not dual maintained at this time
   --                             which is OK.
   --                      rs239b DN _____
   --                      Changed function all_demand_rpl_completed.  See
   --                      package spec for details.
   --
   --   08/31/20  mcha1213   add create_dci_batch
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Private Global Variables
   ---------------------------------------------------------------------------
   gl_pkg_name   VARCHAR2(30) := $$PLSQL_UNIT;   -- Package name.
                                                 -- Used in error messages.

   gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                    -- function is null.


   ---------------------------------------------------------------------------
   -- Private Constants
   ---------------------------------------------------------------------------

   -- Pallet id's with a length > than this will have the batch number format
   -- of FP<forklift_lm_batch_no_seq.NEXTVAL> otherwise the format will
   -- be FP<pallet id>.  Function create_putaway_batches uses this constant.
   -- This is to handle the 18 character RDC pallet id.   We do not want to
   -- use FP<pallet id> for the putaway batch number because of the number of
   -- changes required on the swms.
   ct_putaway_task_lp_length      CONSTANT PLS_INTEGER := 10;


   ct_application_function VARCHAR2(10) := 'LABOR MGT';  -- For pl_log message


   ---------------------------------------------------------------------------
   -- Private Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Function:
   --    f_boolean_text
   --
   -- Description:
   --    This function returns the string TRUE or FALSE for a boolean.
   --
   -- Parameters:
   --    i_boolean - Boolean value
   --  
   -- Return Values:
   --    'TRUE'  - When boolean is TRUE.
   --    'FALSE' - When boolean is FALSE.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Got an oracle error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/20/04 prpbcb   Created.
   --  
   ---------------------------------------------------------------------------
   FUNCTION f_boolean_text(i_boolean IN BOOLEAN)
   RETURN VARCHAR2
   IS
      l_message       VARCHAR2(256);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'f_boolean_text';
   BEGIN
      IF (i_boolean) THEN
         RETURN('TRUE');
      ELSE
         RETURN('FALSE');
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name || '(i_boolean)';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END f_boolean_text;


   ---------------------------------------------------------------------------
   -- Procedur:
   --    find_existing_putaway_batch
   --
   -- Description:
   --    This function determines if a putaway batch exists for a pallet.
   --
   -- Parameters:
   --    i_pallet_id   - Pallet id to check for a putaway batch.
   --    o_batch_no    - The existing putaway batch for the pallet.  If one
   --                    is not found then this will be set to null.
   --  
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Got an oracle error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    06/09/03 prpbcb   Created.
   --  
   ---------------------------------------------------------------------------
   PROCEDURE find_existing_putaway_batch
                        (i_pallet_id IN  putawaylst.pallet_id%TYPE,
                         o_batch_no  OUT arch_batch.batch_no%TYPE)
   IS
      l_message       VARCHAR2(256);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'find_existing_putaway_batch';

      l_return_value_bln BOOLEAN;       -- Return value.

      -- This cursor determines if a pallet has a putaway labor mgmt batch.
      -- The pallet id is in the ref_no column in the BATCH table.
      -- In the BATCH table only one putaway labor mgmt record should exist
      -- for a pallet.  This is how the system is setup to work.
      -- In the ARCH_BATCH table it is possible there is the same pallet id
      -- for different putaway batches because the pallet id sequence wraps
      -- around but at a minimum should not do so within 100 days.
      CURSOR c_find_batch(cp_pallet_id arch_batch.ref_no%TYPE) IS
         -- Check the BATCH table.
         SELECT 1,                     -- Select the BATCH record first
                batch_date, batch_no 
           FROM batch b
          WHERE b.ref_no = cp_pallet_id
            AND b.batch_no LIKE pl_lmc.ct_forklift_putaway || '%'
         UNION
         -- Check the ARCH_BATCH table.
         SELECT 2,                     -- Select the ARCH_BATCH record second
                batch_date, batch_no  
           FROM arch_batch ab
          WHERE ab.ref_no = cp_pallet_id
            AND ab.batch_no LIKE pl_lmc.ct_forklift_putaway || '%'
            AND ab.batch_date > (SYSDATE - 100)
          ORDER BY 1, 2 DESC;

      r_batch  c_find_batch%ROWTYPE;    -- A place to put the record.
   BEGIN
      OPEN c_find_batch(i_pallet_id);
      FETCH c_find_batch INTO r_batch;

      IF (c_find_batch%FOUND) THEN
         o_batch_no := r_batch.batch_no;
      ELSE
         o_batch_no := NULL;
      END IF;

      CLOSE c_find_batch;

   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name ||
                      '(i_pallet_id[' || i_pallet_id || ']' ||
                      ',o_batch_no)';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END find_existing_putaway_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    update_msku_batch_info
   --
   -- Description:
   --    This procedure re-calculates the batch cube, weight, etc. for the
   --    items on a MSKU going to a reserve slot.  It is called when creating
   --    a batch for a child LP that is going to reserve and the batch already
   --    exists.  The situation where the batch already exists will happen when
   --    the user has keyed in a reserve slot over a "*" for a MSKU in the
   --    check-in screen and when changing the qty received from 1 to 0 or
   --    0 to 1 in the check-in screen for a child pallet going to a reserve
   --    slot.
   --    See the comments dated 12/29/04 for procedure
   --    create_msku_putaway_batches() for more info.
   --
   --    The destination location needs to be a reserve slot in order for the
   --    batch to be updated.  The calling program may already be making this
   --    check before calling this procedure.
   --
   --    The processing uses the fact that for a MSKU going to reserve the
   --    batch.ref_no is the parent pallet id.
   --
   -- Parameters:
   --    i_batch_no         - The batch being processed.
   --
   -- Called by:
   --    - create_msku_putaway_batches
   --
   -- Exceptions Raised:
   --    pl_exc.e_database_error     - Any error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    12/15/04 prpbcb   Created.
   --    01/31/05 prpbcb   Add "AND p.qty_received      > 0" to the
   --                      update stmt to handle the situation where the user
   --                      is changing the qty received in the check-in screen.
   --
   --    03/10/05 prpbcb   Handle rule id 3 for miniloader.  Treat like a
   --                      floating location.
   ---------------------------------------------------------------------------
   PROCEDURE update_msku_batch_info
       (i_batch_no          IN arch_batch.batch_no%TYPE)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'update_msku_batch_info';

   BEGIN
      l_message := l_object_name ||
           '(i_batch_no[' || i_batch_no || '])' ||
          ' MESSAGE="Updating batch cube, weight, ..."';

      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                     NULL, NULL,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);


      -- Update the putaway to reserve batch for the MSKU.
      -- The destination location needs to be a reserve slot in order for the
      -- batch to be updated.
      UPDATE batch b
         SET (kvi_no_item,
              kvi_no_po,
              kvi_cube,
              kvi_wt,
              cmt) =
            (SELECT COUNT(DISTINCT p.prod_id || p.cust_pref_vendor) kvi_no_item,
                    COUNT(DISTINCT p.rec_id)                        kvi_no_po,
                    SUM(TRUNC((p.qty / pm.spc) * pm.case_cube))     kvi_cube,
                    SUM(TRUNC(p.qty * NVL(pm.g_weight, 0)))         kvi_wt,
                    'PUT OF MSKU PLT TO RSRV.' ||
                       ' CHILD LPs: ' || TO_CHAR(COUNT(*)) || '.' ||
                       ' REF# IS PARENT LP.'
               FROM zone       z,
                    lzone      lz,
                    pm         pm,
                    loc        l,
                    putawaylst p
              WHERE p.parent_pallet_id  = b.ref_no
                AND p.qty_received      > 0  -- There needs to be something to
                                             -- receive.
                AND l.logi_loc          = p.dest_loc
                AND pm.prod_id          = p.prod_id
                AND pm.cust_pref_vendor = p.cust_pref_vendor
                AND l.perm              = 'N'
                AND lz.logi_loc         = l.logi_loc
                AND z.zone_id           = lz.zone_id
                AND z.rule_id           NOT IN (1, 3, 5, 14))  -- Do not update
                                             -- floating or induction loc
                                             -- because floating and induction
                                             -- are equivalent to a home slot
                                             -- for MSKU labor mgmt.
                                             -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
      WHERE b.batch_no = i_batch_no;

      IF (SQL%FOUND) THEN
         l_message := 'TABLE=batch  ACTION=UPDATE' ||
             ' KEY=' || i_batch_no || '(i_batch_no)' ||
             ' MESSAGE="Update of batch cube, weight, ... successful."';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

      ELSE
         l_message := 'TABLE=batch  ACTION=UPDATE' ||
             ' KEY=' || i_batch_no || '(i_batch_no)' ||
             ' MESSAGE="No record updated when updating batch cube, weight,' ||
             ' ....  SQL%FOUND is false."';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         l_message := 'TABLE=batch  ACTION=UPDATE' ||
             ' KEY=' || i_batch_no || '(i_batch_no)' ||
             ' MESSAGE="Error attempting to update batch cube, weight, ..."';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
   END update_msku_batch_info;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_normal_putaway_batches
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batches for normal
   --   (non MSKU) putaway tasks if forklift labor management is active.
   --   The batches can be created for a PO or for a single license plate.
   --   A batch will not be created for putaway tasks with a destination
   --   location of '*' when creating for a PO or when creating for a single
   --   license plate and i_dest_loc is null.  After the batch is created the
   --   putawaylst.pallet_batch_no is updated with the batch number.
   --
   --   There is a separate procedure to create the batches for MSKU pallets.
   --
   --   06/04/03 Prior to RDC the batch number format was FP<pallet id>.
   --      Example:  FP3458561
   --   A change was made in the batch number format for RDC because the RDC
   --   pallet id is 18 characters which if using the original format would
   --   make the batch number 20 characters which in turn would require the
   --   batch_no column in the BATCH and ARCH_BATCH table to be lengthed and
   --   many forms and reports to change.  The format of the batch number will
   --   be:
   --      - If the length of the pallet id > ct_putaway_task_lp_length then
   --        the batch number will be
   --           FP<forklift_lm_batch_no_seq.NEXTVAL>.
   --        This is a new sequence that will always be a number 9 digits long.
   --        This makes the batch number 11 characters in length which is
   --        within the current size of the batch number in the database and
   --        in the screens.  The sequence is 9 digits so there is no
   --        possibilty of getting a duplicate batch number with a
   --        FP<pallet id> batch--AS LONG AS THE MAX VALUE FOR THE
   --        PALLET_ID_SEQ IS NOT CHANGED.  Building the batch number from a
   --        sequence does have an impact wnen checking if a batch already
   --        exists.  Since the batch number is composed of a value(the
   --        sequence) not stored in the putawaylst record a check
   --        for a duplicate needs to be made by looking for the pallet id
   --        in the ref_no column and a batch starting with 'FP'.
   --
   --      - If the length of the pallet id < ct_putaway_task_lp_length then
   --        the batch will be
   --           FP<pallet id>  (like is currently is)
   --
   -- Parameters:
   --    i_create_for_what      - Designates what to create the batches for.
   --                             The valid values are:
   --                                - LP    for a license plate
   --                                - PO    for a PO
   --                             The value will be converted to upper case by 
   --                             this procedure.
   --    i_key_value            - Pallet id if i_create_for_what is 'LP'.
   --                           - PO # if i_create_for_what is 'PO'.
   --    i_dest_loc             - The destination location when creating a
   --                             batch for a single license plate.  This is
   --                             optional but is required when form rp1sc
   --                             calls this procedure.  In form rp1sc the
   --                             batch is created when a destination
   --                             location is keyed over a '*' or the qty
   --                             received is changed from 0 to > 0.  Because
   --                             of when the form calls this procedure
   --                             the putawaylst records does not yet have
   --                             the dest_loc updated so it needs to be passed
   --                             in (except when the qty is changed from 0
   --                             to > 0 in which case the putawaylst.dest_loc
   --                             could have a value but the dest loc still
   --                             needs to be passed in).  If i_dest_loc is
   --                             null and i_create_for_what is 'LP' then this
   --                             is considered a bad combination of parameters
   --                             and an exception is raised.
   --    o_r_create_putaway_stats - Statistics about batches created.
   --
   -- Called by:
   --    - create_putaway_batches
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null or an unhandled value
   --                               for a parameter or a bad combination
   --                               of parameters.
   --    pl_exe.e_putawaylst_update_fail - No rows updated when updating the
   --                                      putawaylst.pallet_batch_no with the
   --                                      batch number.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/29/03 prpbcb   Created.
   --    09/29/03 prpbcb   MSKU changes.
   --    10/13/04 prpbcb   Removed check if forklift labor mgmt is active
   --                      before creating the batch(s).  The calling object
   --                      will make the check.
   --    05/29/03 bben0556 Brian Bent
   --                      Live Receiving changes.
   --                      Added exception "e_live_receiving_location" and
   --                      checking for dest_loc of 'LR'.  A labor batch
   --                      is not created for the putaway task if the dest_loc
   --                      is 'LR'.  Like is done with the '*'.
   ---------------------------------------------------------------------------
   PROCEDURE create_normal_putaway_batches
              (i_create_for_what          IN  VARCHAR2,
               i_key_value                IN  VARCHAR2,
               i_dest_loc                 IN  putawaylst.dest_loc%TYPE := NULL,
               o_r_create_putaway_stats   OUT t_create_putaway_stats_rec)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_normal_putaway_batches';

      l_batch_no                arch_batch.batch_no%TYPE;
      l_create_for_what         VARCHAR2(20);   -- Populated from
                                                -- i_create_for_what.
      l_existing_batch_no       arch_batch.batch_no%TYPE; -- Existing batch
                                    -- number if it exists for the pallet.
      l_temp_no                 NUMBER;         -- Work area.

      e_bad_create_for_what        EXCEPTION;  -- Bad value in i_bad_create_for_what
      e_batch_already_exists       EXCEPTION;  -- Putaway batch already exists.
      e_has_no_location            EXCEPTION;  -- Destination location is '*'.
      e_live_receiving_location    EXCEPTION;  -- Destination location is 'LR'
      e_parameter_bad_combination  EXCEPTION;  -- Bad combination of
                                               -- parameters.

      -- This cursor selects the non MSKU pallets to create batches for.
      -- It would be possible to have a "insert ... select from ..." statement
      -- that does everything in one statement but using a cursor and looping
      -- through the records allows for more control and better error
      -- handling to find out why a batch was not created in case a job code
      -- is not setup or some other setup issue.
      CURSOR c_putaway(cp_create_for_what VARCHAR2,
                       cp_key_value       VARCHAR2,
                       cp_dest_loc        putawaylst.dest_loc%TYPE) IS
         SELECT p.pallet_id  pallet_id,         -- Select records for a PO.
                p.dest_loc   dest_loc
          FROM putawaylst p
         WHERE cp_create_for_what = 'PO'
           AND p.rec_id           = cp_key_value
           AND p.parent_pallet_id IS NULL   -- No MSKU
           -- Story 3577 Added not exist clause so Labor batches are not created for XN POs
           -- that have a DOOR put locaton. Those POs are dealt with using the Replen screen.
           AND NOT EXISTS (SELECT 'Checking if XN PO with valid locaation'
                             FROM erm e
                            WHERE e.erm_id = p.rec_id
                              AND (e.erm_type = 'XN' or (e.erm_type = 'CM' and e.erm_id like 'X%'))
                              AND NOT EXISTS (SELECT 'Checking location'
                                                FROM loc l
                                               WHERE l.logi_loc = p.dest_loc))
         UNION                 -- Select record for a single LP with the
         SELECT p.pallet_id  pallet_id,
                cp_dest_loc  dest_loc    -- Destination loc passed in.
          FROM putawaylst p
         WHERE cp_dest_loc        IS NOT NULL
           AND cp_create_for_what = 'LP'
           AND p.pallet_id        = cp_key_value
           AND p.parent_pallet_id IS NULL;    -- No MSKU
   BEGIN
      -- Initialize the statistics count.
      o_r_create_putaway_stats.no_records_processed := 0;
      o_r_create_putaway_stats.no_batches_created  := 0;
      o_r_create_putaway_stats.no_batches_existing := 0;
      o_r_create_putaway_stats.no_not_created_due_to_error := 0;
      o_r_create_putaway_stats.no_with_no_location := 0;
      o_r_create_putaway_stats.num_live_receiving_location := 0;

      -- Check for null parameters.
      IF (i_create_for_what IS NULL OR i_key_value IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      l_create_for_what := UPPER(i_create_for_what);
      IF (l_create_for_what NOT IN ('LP', 'PO')) THEN
         RAISE e_bad_create_for_what;
      END IF;

      -- Check for bad combination of parameters.
      IF (   (l_create_for_what != 'LP' AND i_dest_loc IS NOT NULL)
          OR (l_create_for_what = 'LP' AND i_dest_loc IS NULL) ) THEN
         -- i_dest_loc should only have a value if creating a batch for
         -- a single license plate.
         RAISE e_parameter_bad_combination;
      END IF;

      -- Create the putaway labor mgmt batches.

      FOR r_putaway IN c_putaway(l_create_for_what, i_key_value,
                                 i_dest_loc) LOOP

         o_r_create_putaway_stats.no_records_processed :=
                  o_r_create_putaway_stats.no_records_processed + 1;

         BEGIN  -- Start new block so errors can be trapped.

            IF (r_putaway.dest_loc = '*') THEN
               RAISE e_has_no_location;
            ELSIF (r_putaway.dest_loc = pl_rcv_open_po_types.ct_lr_dest_loc)
            THEN
               -- The putaway task has the 'LR' live receiving location.
               RAISE e_live_receiving_location;
            END IF;

            -- Check if a batch already exists for the pallet.
            find_existing_putaway_batch(r_putaway.pallet_id,
                                        l_existing_batch_no);
            IF (l_existing_batch_no IS NOT NULL) THEN
               RAISE e_batch_already_exists;
            END IF;

            -- Build the batch number.  If the pallet id is greater then
            -- ct_putaway_task_lp_length characters then the batch number
            -- is built from a sequence otherwise the pallet id is used.
            -- It is done this way because RDC has a 18 character LP and
            -- we do not want to have to expand the batch number.

            IF (LENGTH(r_putaway.pallet_id) >
                                        ct_putaway_task_lp_length) THEN

               SELECT forklift_lm_batch_no_seq.NEXTVAL
                                        INTO l_temp_no FROM DUAL;
               l_batch_no := pl_lmc.ct_forklift_putaway ||
                                                TO_CHAR(l_temp_no);
            ELSE
               l_batch_no := pl_lmc.ct_forklift_putaway ||
                                                   r_putaway.pallet_id;
            END IF;

            INSERT INTO batch(batch_no,
                              jbcd_job_code,
                              status,
                              batch_date,
                              kvi_from_loc,
                              kvi_to_loc,
                              kvi_no_case,
                              kvi_no_split,
                              kvi_no_pallet,
                              kvi_no_item,
                              kvi_no_po,
                              kvi_cube,
                              kvi_wt,
                              kvi_no_loc,
                              total_count,
                              total_piece,
                              total_pallet,
                              ref_no,
                              kvi_distance,
                              goal_time,
                              target_time,
                              no_breaks,
                              no_lunches,
                              kvi_doc_time,
                              kvi_no_piece, 
                              kvi_no_data_capture)
            SELECT l_batch_no          batch_no,
                   fk.putaway_jobcode  job_code,
                   'F'                 status,
                   TRUNC(SYSDATE)      batch_date,
                   e.door_no           kvi_from_loc,
                   NVL(i_dest_loc, p.dest_loc)   kvi_to_loc,
                   0.0                 kvi_no_case,
                   0.0                 kvi_no_split, 
                   1.0                 kvi_no_pallet,
                   1.0                 kvi_no_item,
                   1.0                 kvi_no_po,
                   TRUNC((p.qty / pm.spc) * pm.case_cube)  kvi_cube,
                   TRUNC(p.qty * NVL(pm.g_weight, 0))      kvi_wt,
                   1.0                 kvi_no_loc,
                   1                   total_count,
                   0                   total_piece,
                   1                   total_pallet,
                   p.pallet_id         ref_no,
                   0.0                 kvi_distance,
                   0.0                 goal_time,
                   0.0                 target_time,
                   0.0                 no_breaks,
                   0.0                 no_lunches,
                   1.0                 kvi_doc_time,
                   0.0                 kvi_no_piece,
                   2.0                 kvi_no_data_capture
              FROM job_code j,
                   fk_area_jobcodes fk,
                   swms_sub_areas ssa,
                   aisle_info ai,
                   pm,
                   erm e,
                   putawaylst p
             WHERE j.jbcd_job_code     = fk.putaway_jobcode
               AND fk.sub_area_code    = ssa.sub_area_code
               AND ssa.sub_area_code   = ai.sub_area_code
               AND ai.name     = SUBSTR(NVL(i_dest_loc, p.dest_loc), 1, 2)
               AND pm.prod_id          = p.prod_id
               AND pm.cust_pref_vendor = p.cust_pref_vendor
               AND e.erm_id            = p.rec_id
               AND p.pallet_id         = r_putaway.pallet_id;

            IF (SQL%FOUND) THEN
               -- Record inserted successfully.
               o_r_create_putaway_stats.no_batches_created :=
                          o_r_create_putaway_stats.no_batches_created + 1;

               -- Update the putaway task with the batch number.
               UPDATE putawaylst
                  SET pallet_batch_no = l_batch_no
                WHERE pallet_id = r_putaway.pallet_id;

               IF (SQL%NOTFOUND) THEN
                  -- No row updated.  This is a fatal error.
                  l_message := 'TABLE=putawaylst  ACTION=UPDATE' ||
                     ' KEY=' ||  r_putaway.pallet_id || '(pallet id)' ||
                     ' MESSAGE="Failed to update the pallet_batch_no' ||
                     ' to [' || l_batch_no || ']"';

                  pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                           l_message,
                           pl_exc.ct_putawaylst_update_fail, NULL,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

                  RAISE pl_exc.e_putawaylst_update_fail;
               END IF;

            ELSE
               -- Inserted 0 records into the batch table.  Most likely
               -- because of a data setup issue.  Write log record and
               -- continue processing.
               o_r_create_putaway_stats.no_not_created_due_to_error := 
                   o_r_create_putaway_stats.no_not_created_due_to_error + 1;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                     '  KEY=[' ||  r_putaway.pallet_id ||
                     '](pallet id)' ||
                     '  JOIN TABLES=job_code,fk_area_jobcodes,' ||
                     'swms_sub_areas,aisle_info,pm,erm,putawaylst' ||
                     '  MESSAGE="Forklift putaway batch not created. No' ||
                     ' record selected to insert into batch table. ' ||
                     '  Could be a data setup issue."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                              l_message,
                              pl_exc.ct_lm_batch_upd_fail, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

            END IF;

         EXCEPTION
            WHEN e_has_no_location THEN
               -- No location was found for the pallet.
               o_r_create_putaway_stats.no_with_no_location := 
                        o_r_create_putaway_stats.no_with_no_location + 1;

            WHEN e_live_receiving_location THEN
               -- The putaway task has the 'LR' live receiving location.
               -- The labor mgmt batch is not created for it at this time.
               -- It will be created when the putaway location is found.
               o_r_create_putaway_stats.num_live_receiving_location := 
                        o_r_create_putaway_stats.num_live_receiving_location + 1;

            WHEN e_batch_already_exists OR DUP_VAL_ON_INDEX THEN
               -- Batch already exists.  This is OK because this procedure
               -- could have been run again for the same data.
               o_r_create_putaway_stats.no_batches_existing := 
                        o_r_create_putaway_stats.no_batches_existing + 1;

            WHEN OTHERS THEN
               -- Got some kind of oracle error.  Log the error then
               -- continue processing.
               o_r_create_putaway_stats.no_not_created_due_to_error :=
                   o_r_create_putaway_stats.no_not_created_due_to_error + 1;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                     '  KEY=[' ||  r_putaway.pallet_id ||
                     '](pallet id)' ||
                     '  JOIN TABLES=job_code,fk_area_jobcodes,' ||
                     'swms_sub_areas,aisle_info,pm,erm,putawaylst' ||
                     '  i_create_for_what[' || i_create_for_what || '],' ||
                     '  i_key_value[' || i_key_value || '],' ||
                     '  i_dest_loc[' || i_dest_loc || '],' ||
                     '  MESSAGE="Forklift putaway batch not created."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                              SQLCODE, SQLERRM,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

         END;   -- end of block

      END LOOP;

      l_message := 
          'Created putaway forklift labor mgmt batches for[' ||
          i_create_for_what || '],' ||
          ' key value[' || i_key_value || '],' ||
          ' dest loc[' || i_dest_loc || '](applies when creating batch' ||
          ' for a LP),' ||
          '  #records processed[' ||
          TO_CHAR(o_r_create_putaway_stats.no_records_processed) || ']' ||
          '  #batches created[' ||
           TO_CHAR(o_r_create_putaway_stats.no_batches_created) || ']' ||
          '  #batches already existing[' ||
           TO_CHAR(o_r_create_putaway_stats.no_batches_existing) || ']' ||
          '  #batches not created because of error[' ||
    TO_CHAR(o_r_create_putaway_stats.no_not_created_due_to_error) || ']' ||
          '  #tasks with no location[' ||
           TO_CHAR(o_r_create_putaway_stats.no_with_no_location) || ']';

      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                     NULL, NULL,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_create_for_what[' ||
            i_create_for_what || ']  or i_key_value[' || i_key_value || ']' ||
            ' is null';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_bad_create_for_what THEN
         l_message := l_object_name || ': Bad value in i_create_for_what[' ||
            i_create_for_what || '].  Value values are LP or PO.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_parameter_bad_combination THEN
         -- i_dest_loc should only have a value if creating a batch for
         -- a single license plate.
         l_message := l_object_name ||
             '(i_create_for_what[' || i_create_for_what || '],' ||
             ' i_key_value[' || i_key_value || '],' ||
             ' i_dest_loc[' || i_dest_loc || '],' ||
             'o_no_records_processed,o_no_batches_created,' ||
             'o_no_batches_existing,o_no_not_created_due_to_error)'  ||
             ' i_dest_loc can only have a value when i_create_for_what is LP';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name ||
             '(i_create_for_what[' || i_create_for_what || '],' ||
             ' i_key_value[' || i_key_value || '],' ||
             ' i_dest_loc[' || i_dest_loc || '],' ||
             'o_no_records_processed,o_no_batches_created,' ||
             'o_no_batches_existing,o_no_not_created_due_to_error)';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         IF (SQLCODE <= -20000) THEN
            RAISE;
         ELSE
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END create_normal_putaway_batches;

  ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
   -- Procedure:
   --    create_dci_putaway_batches
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batches for return
   --   putaway tasks if return labor management is active.
   --   The batches can be created for a CRM or for a single license plate.
   --   A batch will not be created for putaway tasks with a destination
   --   location of '*' when creating for a CRM or when creating for a single
   --   license plate and i_dest_loc is null.  After the batch is created the
   --   putawaylst.pallet_batch_no is updated with the batch number.
   --
   --
   --
   -- Parameters:
   --    i_create_for_what      - Designates what to create the batches for.
   --                             The valid values are:
   --                                - LP    for a license plate
   --                                - CRM    for a CRM
   --                             The value will be converted to upper case by 
   --                             this procedure.
   --    i_key_value            - Pallet id if i_create_for_what is 'LP'.
   --                           - CRM # if i_create_for_what is 'CRM'.
   --    i_dest_loc             - The destination location when creating a
   --                             batch for a single license plate.  This is
   --                             optional but is required when form rp1sc
   --                             calls this procedure.  In form rp1sc the
   --                             batch is created when a destination
   --                             location is keyed over a '*' or the qty
   --                             received is changed from 0 to > 0.  Because
   --                             of when the form calls this procedure
   --                             the putawaylst records does not yet have
   --                             the dest_loc updated so it needs to be passed
   --                             in (except when the qty is changed from 0
   --                             to > 0 in which case the putawaylst.dest_loc
   --                             could have a value but the dest loc still
   --                             needs to be passed in).  If i_dest_loc is
   --                             null and i_create_for_what is 'LP' then this
   --                             is considered a bad combination of parameters
   --                             and an exception is raised.
   --    o_r_create_putaway_stats - Statistics about batches created.
   --
   -- Called by:
   --    - create_dci_batches
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null or an unhandled value
   --                               for a parameter or a bad combination
   --                               of parameters.
   --    pl_exe.e_putawaylst_update_fail - No rows updated when updating the
   --                                      putawaylst.pallet_batch_no with the
   --                                      batch number.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --
   ---------------------------------------------------------------------------
   PROCEDURE create_dci_putaway_batches
              (i_create_for_what          IN  VARCHAR2,
               i_key_value                IN  VARCHAR2,
               i_dest_loc                 IN  putawaylst.dest_loc%TYPE := NULL,
               o_r_create_putaway_stats   OUT t_create_putaway_stats_rec)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_dci_putaway_batches';

      l_batch_no                arch_batch.batch_no%TYPE;
      l_create_for_what         VARCHAR2(20);   -- Populated from
                                                -- i_create_for_what.
      l_existing_batch_no       arch_batch.batch_no%TYPE; -- Existing batch
                                    -- number if it exists for the pallet.
      l_temp_no                 NUMBER;         -- Work area.

      e_bad_create_for_what        EXCEPTION;  -- Bad value in i_bad_create_for_what
      e_batch_already_exists       EXCEPTION;  -- Putaway batch already exists.
      e_has_no_location            EXCEPTION;  -- Destination location is '*'.
      e_live_receiving_location    EXCEPTION;  -- Destination location is 'LR'
      e_parameter_bad_combination  EXCEPTION;  -- Bad combination of
                                               -- parameters.

      CURSOR c_putaway(cp_create_for_what VARCHAR2,
                       cp_key_value       VARCHAR2,
                       cp_dest_loc        putawaylst.dest_loc%TYPE) IS
         SELECT distinct p.pallet_id  pallet_id,         -- Select records for a PO.
                p.dest_loc   dest_loc
          FROM putawaylst p, erm e
         WHERE cp_create_for_what = 'CM'
           AND p.rec_id           = cp_key_value
		   and e.erm_type = 'CM'
		   AND substr(p.rec_id,1,1) = 'S'
           AND p.parent_pallet_id IS NULL   -- No MSKU
         UNION                 -- Select record for a single LP with the
         SELECT p.pallet_id  pallet_id,
                cp_dest_loc  dest_loc    -- Destination loc passed in.
          FROM putawaylst p, erm e
         WHERE cp_dest_loc        IS NOT NULL
           AND cp_create_for_what = 'LP'
           AND p.pallet_id        = cp_key_value
		   and e.erm_id =  p.rec_id
		   and e.erm_type = 'CM'
		   AND substr(p.rec_id,1,1) = 'S'
           AND p.parent_pallet_id IS NULL;    -- No MSKU 

	  /*
      CURSOR c_putaway(cp_create_for_what VARCHAR2,
                       cp_key_value       VARCHAR2,
                       cp_dest_loc        putawaylst.dest_loc%TYPE) IS
         SELECT p.pallet_id  pallet_id,         -- Select records for a PO.
                p.dest_loc   dest_loc
          FROM putawaylst p
         WHERE cp_create_for_what = 'CM'
           AND p.rec_id           = cp_key_value
           AND p.parent_pallet_id IS NULL   -- No MSKU
         UNION                 -- Select record for a single LP with the
         SELECT p.pallet_id  pallet_id,
                cp_dest_loc  dest_loc    -- Destination loc passed in.
          FROM putawaylst p
         WHERE cp_dest_loc        IS NOT NULL
           AND cp_create_for_what = 'LP'
           AND p.pallet_id        = cp_key_value
           AND p.parent_pallet_id IS NULL;    -- No MSKU
		*/   
   BEGIN
      -- Initialize the statistics count.
      o_r_create_putaway_stats.no_records_processed := 0;
      o_r_create_putaway_stats.no_batches_created  := 0;
      o_r_create_putaway_stats.no_batches_existing := 0;
      o_r_create_putaway_stats.no_not_created_due_to_error := 0;
      o_r_create_putaway_stats.no_with_no_location := 0;
      o_r_create_putaway_stats.num_live_receiving_location := 0;

      -- Check for null parameters.
      IF (i_create_for_what IS NULL OR i_key_value IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      l_create_for_what := UPPER(i_create_for_what);
      IF (l_create_for_what NOT IN ('LP', 'CM')) THEN
         RAISE e_bad_create_for_what;
      END IF;

      -- Check for bad combination of parameters.
      IF (   (l_create_for_what != 'LP' AND i_dest_loc IS NOT NULL)
          OR (l_create_for_what = 'LP' AND i_dest_loc IS NULL) ) THEN
         -- i_dest_loc should only have a value if creating a batch for
         -- a single license plate.
         RAISE e_parameter_bad_combination;
      END IF;

      -- Create the putaway labor mgmt batches.

      FOR r_putaway IN c_putaway(l_create_for_what, i_key_value,
                                 i_dest_loc) LOOP

         o_r_create_putaway_stats.no_records_processed :=
                  o_r_create_putaway_stats.no_records_processed + 1;

         BEGIN  -- Start new block so errors can be trapped.

            IF (r_putaway.dest_loc = '*') THEN
               RAISE e_has_no_location;
            ELSIF (r_putaway.dest_loc = pl_rcv_open_po_types.ct_lr_dest_loc)
            THEN
               -- The putaway task has the 'LR' live receiving location.
               RAISE e_live_receiving_location;
            END IF;

            -- Check if a batch already exists for the pallet.
            find_existing_putaway_batch(r_putaway.pallet_id,
                                        l_existing_batch_no);
            IF (l_existing_batch_no IS NOT NULL) THEN
               RAISE e_batch_already_exists;
            END IF;

            -- Build the batch number.  If the pallet id is greater then
            -- ct_putaway_task_lp_length characters then the batch number
            -- is built from a sequence otherwise the pallet id is used.
            -- It is done this way because RDC has a 18 character LP and
            -- we do not want to have to expand the batch number.

            IF (LENGTH(r_putaway.pallet_id) >
                                        ct_putaway_task_lp_length) THEN

               SELECT forklift_lm_batch_no_seq.NEXTVAL
                                        INTO l_temp_no FROM DUAL;
               l_batch_no := pl_lmc.ct_forklift_putaway ||
                                                TO_CHAR(l_temp_no);
            ELSE
               l_batch_no := pl_lmc.ct_forklift_putaway ||
                                                   r_putaway.pallet_id;
            END IF;

            INSERT INTO batch(batch_no,
                              jbcd_job_code,
                              status,
                              batch_date,
                              kvi_from_loc,
                              kvi_to_loc,
                              kvi_no_case,
                              kvi_no_split,
                              kvi_no_pallet,
                              kvi_no_item,
                              kvi_no_po,
                              kvi_cube,
                              kvi_wt,
                              kvi_no_loc,
                              total_count,
                              total_piece,
                              total_pallet,
                              ref_no,
                              kvi_distance,
                              goal_time,
                              target_time,
                              no_breaks,
                              no_lunches,
                              kvi_doc_time,
                              kvi_no_piece, 
                              kvi_no_data_capture)
            SELECT l_batch_no          batch_no,
                   fk.rtn_jobcode  job_code,  --fk.putaway_jobcode  job_code,
                   'F'                 status,
                   TRUNC(SYSDATE)      batch_date,
                   dfs.door_no         kvi_from_loc,
               --    e.door_no           kvi_from_loc, 
                   NVL(i_dest_loc, p.dest_loc)   kvi_to_loc,
                   0.0                 kvi_no_case,
                   0.0                 kvi_no_split, 
                   1.0                 kvi_no_pallet,
                   1.0                 kvi_no_item,
                   1.0                 kvi_no_po,
                   TRUNC((p.qty / pm.spc) * pm.case_cube)  kvi_cube,
                   TRUNC(p.qty * NVL(pm.g_weight, 0))      kvi_wt,
                   1.0                 kvi_no_loc,
                   1                   total_count,
                   0                   total_piece,
                   1                   total_pallet,
                   p.pallet_id         ref_no,
                   0.0                 kvi_distance,
                   0.0                 goal_time,
                   0.0                 target_time,
                  0.0                 no_breaks,
                   0.0                 no_lunches,
                   1.0                 kvi_doc_time,
                   0.0                 kvi_no_piece,
                   2.0                 kvi_no_data_capture
              FROM job_code j,
                   fk_area_jobcodes fk,
                   swms_sub_areas ssa,
                   aisle_info ai,
                   pm,
                   --erm e,
                   putawaylst p,
                   dci_forklift_setup dfs
             WHERE j.jbcd_job_code     = fk.rtn_jobcode --  fk.putaway_jobcode
               AND fk.sub_area_code    = ssa.sub_area_code
               AND ssa.sub_area_code   = ai.sub_area_code
               and ssa.area_code   = dfs.area_code
               AND ai.name     = SUBSTR(NVL(i_dest_loc, p.dest_loc), 1, 2)
               AND pm.prod_id          = p.prod_id
               AND pm.cust_pref_vendor = p.cust_pref_vendor
               --AND e.erm_id            = p.rec_id
               AND p.pallet_id         = r_putaway.pallet_id;


            /*
            INSERT INTO batch(batch_no,
                              jbcd_job_code,
                              status,
                              batch_date,
                              kvi_from_loc,
                              kvi_to_loc,
                              kvi_no_case,
                              kvi_no_split,
                              kvi_no_pallet,
                              kvi_no_item,
                              kvi_no_po,
                              kvi_cube,
                              kvi_wt,
                              kvi_no_loc,
                              total_count,
                              total_piece,
                              total_pallet,
                              ref_no,
                              kvi_distance,
                              goal_time,
                              target_time,
                              no_breaks,
                              no_lunches,
                              kvi_doc_time,
                              kvi_no_piece, 
                              kvi_no_data_capture)
            SELECT l_batch_no          batch_no,
                   fk.rtn_jobcode  job_code,  --fk.putaway_jobcode  job_code,
                   'F'                 status,
                   TRUNC(SYSDATE)      batch_date,
                   e.door_no           kvi_from_loc,   -- ? do I have to get door_no from dci_forklift_setup table?
                   NVL(i_dest_loc, p.dest_loc)   kvi_to_loc,
                   0.0                 kvi_no_case,
                   0.0                 kvi_no_split, 
                   1.0                 kvi_no_pallet,
                   1.0                 kvi_no_item,
                   1.0                 kvi_no_po,
                   TRUNC((p.qty / pm.spc) * pm.case_cube)  kvi_cube,
                   TRUNC(p.qty * NVL(pm.g_weight, 0))      kvi_wt,
                   1.0                 kvi_no_loc,
                   1                   total_count,
                   0                   total_piece,
                   1                   total_pallet,
                   p.pallet_id         ref_no,
                   0.0                 kvi_distance,
                   0.0                 goal_time,
                   0.0                 target_time,
                   0.0                 no_breaks,
                   0.0                 no_lunches,
                   1.0                 kvi_doc_time,
                   0.0                 kvi_no_piece,
                   2.0                 kvi_no_data_capture
              FROM job_code j,
                   fk_area_jobcodes fk,
                   swms_sub_areas ssa,
                   aisle_info ai,
                   pm,
                   erm e,
                   putawaylst p
             WHERE j.jbcd_job_code     = fk.rtn_jobcode --  ? fk.putaway_jobcode
               AND fk.sub_area_code    = ssa.sub_area_code
               AND ssa.sub_area_code   = ai.sub_area_code
               AND ai.name     = SUBSTR(NVL(i_dest_loc, p.dest_loc), 1, 2)
               AND pm.prod_id          = p.prod_id
               AND pm.cust_pref_vendor = p.cust_pref_vendor
               AND e.erm_id            = p.rec_id
               AND p.pallet_id         = r_putaway.pallet_id;

            */   

            IF (SQL%FOUND) THEN
               -- Record inserted successfully.
               o_r_create_putaway_stats.no_batches_created :=
                          o_r_create_putaway_stats.no_batches_created + 1;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                     ' KEY=' ||  r_putaway.pallet_id || '(pallet id)' ||
                     ' MESSAGE= DCI batch ' || l_batch_no ||' created';	

			   pl_log.ins_msg('INFO', l_object_name,
                        l_message,
                         SQLCODE, SQLERRM, null, 'pl_lmf', 'N');						 

               -- Update the putaway task with the batch number.
               UPDATE putawaylst
                  SET pallet_batch_no = l_batch_no
                WHERE pallet_id = r_putaway.pallet_id;

               IF (SQL%NOTFOUND) THEN
                  -- No row updated.  This is a fatal error.
                  l_message := 'TABLE=putawaylst  ACTION=UPDATE' ||
                     ' KEY=' ||  r_putaway.pallet_id || '(pallet id)' ||
                     ' MESSAGE="Failed to update the pallet_batch_no' ||
                     ' to [' || l_batch_no || ']"';

                  pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                           l_message,
                           pl_exc.ct_putawaylst_update_fail, NULL,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

                  RAISE pl_exc.e_putawaylst_update_fail;
               END IF;

            ELSE
               -- Inserted 0 records into the batch table.  Most likely
               -- because of a data setup issue.  Write log record and
               -- continue processing.
               o_r_create_putaway_stats.no_not_created_due_to_error := 
                   o_r_create_putaway_stats.no_not_created_due_to_error + 1;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                     '  KEY=[' ||  r_putaway.pallet_id ||
                     '](pallet id)' ||
                     '  JOIN TABLES=erm, putawaylst' ||
                     '  MESSAGE="DCI batch not created. No' ||
                     ' record selected to insert into batch table. ' ||
                     '  Could be a data setup issue."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                              l_message,
                              pl_exc.ct_lm_batch_upd_fail, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

            END IF;

         EXCEPTION
            WHEN e_has_no_location THEN
               -- No location was found for the pallet.
               o_r_create_putaway_stats.no_with_no_location := 
                        o_r_create_putaway_stats.no_with_no_location + 1;

            WHEN e_live_receiving_location THEN
               -- The putaway task has the 'LR' live receiving location.
               -- The labor mgmt batch is not created for it at this time.
               -- It will be created when the putaway location is found.
               o_r_create_putaway_stats.num_live_receiving_location := 
                        o_r_create_putaway_stats.num_live_receiving_location + 1;

            WHEN e_batch_already_exists OR DUP_VAL_ON_INDEX THEN
               -- Batch already exists.  This is OK because this procedure
               -- could have been run again for the same data.
               o_r_create_putaway_stats.no_batches_existing := 
                        o_r_create_putaway_stats.no_batches_existing + 1;

            WHEN OTHERS THEN
               -- Got some kind of oracle error.  Log the error then
               -- continue processing.
               o_r_create_putaway_stats.no_not_created_due_to_error :=
                   o_r_create_putaway_stats.no_not_created_due_to_error + 1;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                     '  KEY=[' ||  r_putaway.pallet_id ||
                     '](pallet id)' ||
                     '  JOIN TABLES=erm, putawaylst' ||
                     '  i_create_for_what[' || i_create_for_what || '],' ||
                     '  i_key_value[' || i_key_value || '],' ||
                     '  i_dest_loc[' || i_dest_loc || '],' ||
                     '  MESSAGE="DCI batch not created."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                              SQLCODE, SQLERRM,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

         END;   -- end of block

      END LOOP;

	  -- 02/05/21 add validation
	  if (o_r_create_putaway_stats.no_records_processed = 0) then

            l_message := 'DCI batch not created for ' || i_key_value ||
                     ' It is not a Saleable item nor it is a CM ';	

			pl_log.ins_msg('INFO', l_object_name,
                        l_message,
                         SQLCODE, SQLERRM, null, 'pl_lmf', 'N');

			RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);						 

	  end if;

      /* 02/05/21 take it out */
      l_message := 
          'Created dci labor mgmt batches for[' ||
          i_create_for_what || '],' ||
          ' key value[' || i_key_value || '],' ||
          ' dest loc[' || i_dest_loc || '](applies when creating batch' ||
          ' for a LP),' ||
          '  #records processed[' ||
          TO_CHAR(o_r_create_putaway_stats.no_records_processed) || ']' ||
          '  #batches created[' ||
           TO_CHAR(o_r_create_putaway_stats.no_batches_created) || ']' ||
          '  #batches already existing[' ||
           TO_CHAR(o_r_create_putaway_stats.no_batches_existing) || ']' ||
          '  #batches not created because of error[' ||
    TO_CHAR(o_r_create_putaway_stats.no_not_created_due_to_error) || ']' ||
          '  #tasks with no location[' ||
           TO_CHAR(o_r_create_putaway_stats.no_with_no_location) || ']';

      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                     NULL, NULL,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
                    

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_create_for_what[' ||
            i_create_for_what || ']  or i_key_value[' || i_key_value || ']' ||
            ' is null';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_bad_create_for_what THEN
         l_message := l_object_name || ': Bad value in i_create_for_what[' ||
            i_create_for_what || '].  Value values are LP or PO.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_parameter_bad_combination THEN
         -- i_dest_loc should only have a value if creating a batch for
         -- a single license plate.
         l_message := l_object_name ||
             '(i_create_for_what[' || i_create_for_what || '],' ||
             ' i_key_value[' || i_key_value || '],' ||
             ' i_dest_loc[' || i_dest_loc || '],' ||
             'o_no_records_processed,o_no_batches_created,' ||
             'o_no_batches_existing,o_no_not_created_due_to_error)'  ||
             ' i_dest_loc can only have a value when i_create_for_what is LP';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name ||
             '(i_create_for_what[' || i_create_for_what || '],' ||
             ' i_key_value[' || i_key_value || '],' ||
             ' i_dest_loc[' || i_dest_loc || '],' ||
             'o_no_records_processed,o_no_batches_created,' ||
             'o_no_batches_existing,o_no_not_created_due_to_error)';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         IF (SQLCODE <= -20000) THEN
            RAISE;
         ELSE
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END create_dci_putaway_batches;



   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_msku_putaway_batches
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batches for MSKU putaway
   --   tasks if forklift labor management is active.  The batches can be
   --   created for a PO or for a single license plate.  A batch will not be
   --   created for putaway tasks with a destination location of '*' when
   --   creating for a PO or when creating for a single license plate
   --   and i_dest_loc is null.
   --
   --   *********************************************************************
   --   ** 09/30/03 prpbcb                                                 **
   --   ** This function is very similiar to create_putaway_batches but    **
   --   ** there is enough differences I think to warrant a new procedure. **
   --   *********************************************************************
   --
   --   After the batch is created the putawaylst.pallet_batch_no is updated
   --   with the batch number.  For the putaway tasks going to a reserve slot
   --   all the putawaylst records are updated to the same batch number because
   --   there is only one batch for a MSKU putaway to a reserve slot.
   --
   --   Be aware that if this procedure is creating a batch
   --   for a single LP then it is most likely being called
   --   from the check-in screen after a location is keyed
   --   over a '*.  It is called in the PRE-UPDATE trigger
   --   so the putawaylst.dest_loc has not been updated yet
   --   which is why the dest loc is passed as a parameter.
   --   For returns this procedure is called for each LP on the T batch.
   --   The putawaylst.dest_loc will have a valid location.
   --
   --   06/04/03 Prior to RDC the batch number format was FP<pallet id>.
   --      Example:  FP3458561
   --   A change was made in the batch number format for RDC because the RDC
   --   pallet id is 18 characters which if using the original format would
   --   make the batch number 20 characters which in turn would require the
   --   batch_no column in the BATCH and ARCH_BATCH table to be lengthed and
   --   many forms and reports to change.  The format of the batch number will
   --   be:
   --      - If the length of the pallet id > ct_putaway_task_lp_length then
   --        the batch number will be
   --           FP<forklift_lm_batch_no_seq.NEXTVAL>.
   --        This is a new sequence that will always be a number 9 digits long.
   --        This makes the batch number 11 characters in length which is
   --        within the current size of the batch number in the database and
   --        in the screens.  The sequence is 9 digits so there is no
   --        possibilty of getting a duplicate batch number with a
   --        FP<pallet id> batch--AS LONG AS THE MAX VALUE FOR THE
   --        PALLET_ID_SEQ IS NOT CHANGED.  Building the batch number from a
   --        sequence does have an impact wnen checking if a batch already
   --        exists.  Since the batch number is composed of a value(the
   --        sequence) not stored in the putawaylst record a check
   --        for a duplicate needs to be made by looking for the pallet id
   --        in the ref_no column and a batch starting with 'FP'.
   --
   --      - If the length of the pallet id < ct_putaway_task_lp_length then
   --        the batch will be
   --           FP<pallet id>  (like is currently is)
   --
   --   The values for kvi_no_data_capture will be as follows:
   --      2 for the first batch going to a home slot.  This is for the scan
   --        of the home slot and then the pallet id.
   --      1 for subsequent batches to the same home slot.  This is for the
   --        scan of the pallet id.
   --      2 for the first batch going to a reserve slot.  This is for the
   --        scan of the pallet at the dock and the scan of the reserve slot.
   --   If this logic changes then also look at
   --   pl_lm_msku.calculate_kvi_values.
   --
   --   For kvi_no_po the number of distinct PO's is used.  A SN could have
   --   different PO's on a MSKU.
   --
   --   For a SN MSKU:
   --   Each putaway to a home slot will have a batch.
   --   Each putaway to a floating slot will have a batch.
   --   The LP's going to a reserve slot will have one batch.
   --   Example:
   --                                               Create Batch   kvi_no_data_
   --      LP       Parent LP  Dest Loc  Home Slot  for LP         capture
   --      -------  ---------  --------  ---------  -------------  -----------
   --      123        555      DA01A1       Yes        Yes            2
   --      124        555      DA01A1       Yes        Yes            1
   --      125        555      DA01A1       Yes        Yes            1
   --      126        555      DA05B1       Yes        Yes            2
   --      127        555      DA05B1       Yes        Yes            1
   --      200        555      DA10A2       Floating   Yes            2
   --      201        555      DA10A2       Floating   Yes            1
   --      128        555      DA12A5       No         No   -+
   --      129        555      DA12A5       No         No    |        2
   --      130        555      DA12A5       No         No    | 
   --      131        555      DA12A5       No         No    | One batch created
   --      132        555      DA12A5       No         No    | for the pallets
   --      133        555      DA12A5       No         No    | going to a
   --      135        555      DA12A5       No         No   -+ reserve slot.
   --
   --   For a returns MSKU:
   --   Each putaway task will have a batch.
   --
   -- Parameters:
   --    i_create_for_what      - Designates what to create the batches for.
   --                             The valid values are:
   --                                - LP    for a license plate
   --                                - PO    for a PO
   --                             The value will be converted to upper case by 
   --                             this procedure.
   --    i_key_value            - Pallet id if i_create_for_what is 'LP'.
   --                           - PO # if i_create_for_what is 'PO'.
   --    i_dest_loc             - The destination location when creating a
   --                             batch for a single license plate.  This is
   --                             mandatory when i_create_for_what is 'LP'.
   --                             In form rp1sc the batch is created when a
   --                             destination location is keyed over a '*' or
   --                             the qty received is changed from 0 to > 0.
   --                             Because of when the form calls this procedure
   --                             the putawaylst records does not yet have
   --                             the dest_loc updated so it needs to be passed
   --                             in (except when the qty is changed from 0
   --                             to > 0 in which case the putawaylst.dest_loc
   --                             could have a value but the dest loc still
   --                             needs to be passed in).  If i_dest_loc is
   --                             null and i_create_for_what is 'LP' then this
   --                             is considered a bad combination of paremeters
   --                             and an exception is raised.
   --    i_kvi_from_loc         - The value to use for the batch kvi_from_loc
   --                             for returns.  Mandatory for returns putaway
   --                             batches.  Returns are treated like a RDC
   --                             MSKU.  Leave null for everything else.
   --    o_r_create_putaway_stats - Statistics about batches created.
   --
   -- Called by:
   --    - create_putaway_batches
   --    - create_returns_putaway_batches  (Returns are treated like a MSKU)
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null or an unhandled value
   --                               for a parameter or a bad combination
   --                               of parameters.
   --    pl_exe.e_putawaylst_update_fail - No rows updated when updating the
   --                                      putawaylst.pallet_batch_no with the
   --                                      batch number.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/29/03 prpbcb   Created.
   --    09/29/03 prpbcb   MSKU changes.
   --    10/13/04 prpbcb   Removed check if forklift labor mgmt is active
   --                      before creating the batch(s).  The calling object
   --                      will make the check.
   --    12/29/04 prpbcb   Cursor c_putaway was missing the prod id and cpv
   --                      in the where clause for the join to the PM table.
   --
   --                      Modified to re-calculate the batch cube, weight, etc
   --                      for a batch when creating a batch for a child LP
   --                      and the batch already exists and the destination
   --                      location of the batch is a reserve slot.  Created
   --                      procedure update_msku_batch_info to do the update.
   --                      This is to handle the situation where the user has
   --                      entered a reserve location over a '*' for a child LP
   --                      in the receiving check-in screen.  When this occurs
   --                      the reserve location will be applied to all other
   --                      child LP's that have a '*' location and have a 
   --                      home slot (all slotted items not going to a home
   --                      slot will go to the same reserve slot).  The screen
   --                      will call this procedure for each child LP where the
   --                      '*' was replaced with the reserve location.  For the
   --                      first child LP going to the reserve slot the batch
   --                      is created.  For the subsequent child LP's going to
   --                      the reserve slot the batch cube, weight, etc will be
   --                      updated to reflect all the LP's that are going to
   --                      the reserve slot.
   --                      Note: There is only one batch for all the child LP's
   --                            going to a reserve slot.  Each child LP going
   --                            to a home slot a floating slot will have
   --                            its own batch.
   --
   --                      Modified to treat items going to a floating slot
   --                      the same as items going to a home slot.  This means
   --                      each child LP going to a floating slot will have
   --                      a batch.
   --
   --    01/20/05 prpbcb   Fix join in the where clause for the select stmt
   --                      for a LP that joined lz.logi_loc to p.putawaylst
   --                      instead of cp_dest_loc.
   --
   --    01/27/05 prpbcb   The putawaylst.pallet_batch_no column was not
   --                      being updated when creating a batch for a single LP
   --                      when a reserve slot was keyed over a '*' in the
   --                      check-in screen.  This was because a join was
   --                      made to the putawaylst.dest_loc but the column has
   --                      not been updated yet due to this package being
   --                      called in the PRE-UPDATE trigger.
   --                      Added updating the putawaylst.dest_loc to
   --                      i_dest_loc for the pallet when creating a batch
   --                      for a single LP.  There are more notes about this
   --                      at the place where the update is made.
   --
   --    03/10/05 prpbcb   Changed cursor c_putaway to look at the rule id
   --                      of the zone for the select a single LP.
   --
   --    03/10/05 prpbcb   Handle rule id 3 for miniloader.  Treat like a
   --                      floating location.
   --
   --    03/12/05 prpbcb   Modified to create a separate batch for each LP
   --                      when processing a return.  Before if the putawaylst
   --                      destination location of the return was a reserve
   --                      slot as indicated by the put zone of the location
   --                      being a rule 0 zone then an attempt was made to
   --                      create one batch for all the the rule 0 putawaylst
   --                      destination locations.  This is what is need for
   --                      receiving a MSKU on a SN but not for a return.
   --                      Cursor c_putaway was changed.
   ---------------------------------------------------------------------------
   PROCEDURE create_msku_putaway_batches
              (i_create_for_what         IN  VARCHAR2,
               i_key_value               IN  VARCHAR2,
               i_dest_loc                IN  putawaylst.dest_loc%TYPE
                                                            DEFAULT NULL,
               i_kvi_from_loc            IN  arch_batch.kvi_from_loc%TYPE
                                                            DEFAULT NULL,
               o_r_create_putaway_stats  OUT t_create_putaway_stats_rec)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_msku_putaway_batches';

      l_cmt                 arch_batch.cmt%TYPE;  -- Batch comment
      l_batch_no            arch_batch.batch_no%TYPE;
      l_create_for_what     VARCHAR2(20);   -- Populated from i_create_for_what.
      l_existing_batch_no   arch_batch.batch_no%TYPE; -- Existing batch
                                    -- number if it exists for the pallet.
      l_kvi_no_data_capture arch_batch.kvi_no_data_capture%TYPE;
      l_ref_no              arch_batch.ref_no%TYPE;  -- Value for batch.ref_no
      l_temp_no             NUMBER;                  -- Work area.

      -- Previous values. 
      l_previous_parent_pallet_id putawaylst.pallet_id%TYPE := NULL;
      l_previous_dest_loc         putawaylst.dest_loc%TYPE  := NULL;

      e_bad_create_for_what   EXCEPTION;  -- Bad value in i_bad_create_for_what
      e_batch_already_exists  EXCEPTION;  -- Putaway batch already exists.
      e_has_no_location       EXCEPTION;  -- Destination location is '*'.
      e_parameter_bad_combination    EXCEPTION;  -- Bad combination of
                                                 -- parameters.

      --
      -- This cursor selects the MSKU pallets to create batches for.
      -- For each cursor record a batch will be created.  (Another way to have
      -- done this is by removing the grouping and keeping track of when to
      -- create a batch in the cursor for loop.)
      -- Floating items and the miniloader induction location are treated like
      -- items with home slots.
      --
      CURSOR c_putaway(cp_create_for_what     VARCHAR2,
                       cp_key_value           VARCHAR2,
                       cp_dest_loc            putawaylst.dest_loc%TYPE) IS
        SELECT DECODE(erm.erm_type,
                      'CM', p.pallet_id,
                      DECODE(l.perm,
                             'Y', p.pallet_id,
                             DECODE(TO_CHAR(NVL(z.rule_id, 0)),
                                    '1', p.pallet_id,
                                    '3', p.pallet_id,
                                    '5', p.pallet_id,
                                    -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
                                    '14', p.pallet_id,
                                    p.parent_pallet_id)))    pallet_id,
                p.parent_pallet_id                           parent_pallet_id,
                DECODE(l.perm,
                       'Y', '0',
                       DECODE(TO_CHAR(NVL(z.rule_id, 0)),
                              '1', '0',
                              '3', '0',
                              '5', '0',
                              -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
                              '14','0',
                              '1'))                          primary_sort,
                l.perm                                       perm,
                p.dest_loc                                   dest_loc,
                p.rec_id                                     rec_id,
                NVL(z.rule_id, 0)                            rule_id,
                COUNT(DISTINCT p.prod_id || p.cust_pref_vendor) kvi_no_item,
                COUNT(DISTINCT p.po_no)                      kvi_no_po,
                SUM(TRUNC((p.qty / nvl(pm.spc, 1)) * nvl(pm.case_cube, 1)))  kvi_cube,
                SUM(TRUNC(p.qty * NVL(pm.g_weight, 0)))      kvi_wt,
                COUNT(1)                                     record_count
           FROM zone       z,
                erm        erm,
                lzone      lz,
                pm         pm,
                loc        l,
                putawaylst p
          WHERE cp_create_for_what  = 'PO'
            AND p.rec_id            = cp_key_value
            AND p.parent_pallet_id  IS NOT NULL   -- Select MSKU pallets
            AND l.logi_loc          = p.dest_loc
            AND pm.prod_id(+)          = p.prod_id
            AND pm.cust_pref_vendor(+) = p.cust_pref_vendor
            AND z.zone_id           = lz.zone_id
            AND z.zone_type         = 'PUT'
            AND lz.logi_loc         = p.dest_loc
            AND erm.erm_id          = p.rec_id
          GROUP BY
                DECODE(erm.erm_type,
                       'CM', p.pallet_id,
                       DECODE(l.perm,
                              'Y', p.pallet_id,
                              DECODE(TO_CHAR(NVL(z.rule_id, 0)),
                                     '1', p.pallet_id,
                                     '3', p.pallet_id,
                                     '5', p.pallet_id,
                                     -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
                                     '14', p.pallet_id,
                                     p.parent_pallet_id))),
                p.parent_pallet_id,
                DECODE(l.perm, 'Y', '0',
                               DECODE(TO_CHAR(NVL(z.rule_id, 0)),
                                      '1', '0',
                                      '3', '0',
                                      '5', '0',
                                      -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
                                      '14','0',
                                      '1')),
                l.perm,
                p.dest_loc,
                p.rec_id,
                NVL(z.rule_id, 0)
          UNION                   -- Select record for a single LP.
                                  -- The primary_sort is not significant
                                  -- since selecting only one record.
                                  -- NOTE: If the putaway is going to a
                                  --       reserve slot then the cursor
                                  --       pallet_id is the parent pallet id.
         SELECT DECODE(erm.erm_type,
                       'CM', p.pallet_id,
                       DECODE(l.perm,
                              'Y', p.pallet_id,
                              DECODE(TO_CHAR(NVL(z.rule_id, 0)),
                                     '1', p.pallet_id,
                                     '3', p.pallet_id,
                                     '5', p.pallet_id,
                                     -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
                                     '14', p.pallet_id,
                                     p.parent_pallet_id)))   pallet_id,
                p.parent_pallet_id                           parent_pallet_id,
                DECODE(l.perm, 'Y', '0', '1')                primary_sort,
                l.perm                                       perm,
                cp_dest_loc                                  dest_loc,
                p.rec_id                                     rec_id,
                NVL(z.rule_id, 0)                            rule_id,
                COUNT(DISTINCT p.prod_id || p.cust_pref_vendor) kvi_no_item,
                COUNT(DISTINCT p.rec_id)                     kvi_no_po,
                SUM(TRUNC((p.qty / pm.spc) * pm.case_cube))  kvi_cube,
                SUM(TRUNC(p.qty * NVL(pm.g_weight, 0)))      kvi_wt,
                COUNT(1)                                     record_count
           FROM zone  z,
                erm   erm,
                lzone lz,
                pm    pm,
                loc   l,
                putawaylst p
          WHERE cp_dest_loc         IS NOT NULL
            AND l.logi_loc          = cp_dest_loc
            AND cp_create_for_what  = 'LP'
            AND p.pallet_id         = cp_key_value
            AND p.parent_pallet_id  IS NOT NULL    -- Select MSKU pallets
            AND pm.prod_id          = p.prod_id
            AND pm.cust_pref_vendor = p.cust_pref_vendor
            AND z.zone_id           = lz.zone_id
            AND z.zone_type         = 'PUT'
            AND lz.logi_loc         = cp_dest_loc
            AND erm.erm_id          = p.rec_id
          GROUP BY
                DECODE(erm.erm_type,
                       'CM', p.pallet_id,
                       DECODE(l.perm,
                              'Y', p.pallet_id,
                              DECODE(TO_CHAR(NVL(z.rule_id, 0)),
                                     '1', p.pallet_id,
                                     '3', p.pallet_id,
                                     '5', p.pallet_id,
                                     -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
                                     '14', p.pallet_id,
                                     p.parent_pallet_id))),
                p.parent_pallet_id,
                DECODE(l.perm, 'Y', '0', '1'),
                l.perm,
                cp_dest_loc,
                p.rec_id,
                NVL(z.rule_id, 0)
          ORDER BY 2, 3, 5, 1;
   BEGIN
      -- Initialize the statistics count.
      o_r_create_putaway_stats.no_records_processed := 0;
      o_r_create_putaway_stats.no_batches_created  := 0;
      o_r_create_putaway_stats.no_batches_existing := 0;
      o_r_create_putaway_stats.no_not_created_due_to_error := 0;
      o_r_create_putaway_stats.no_with_no_location := 0;
      o_r_create_putaway_stats.num_live_receiving_location := 0;

      -- Check for null parameters.
      IF (i_create_for_what IS NULL OR i_key_value IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      l_create_for_what := UPPER(i_create_for_what);
      IF (l_create_for_what NOT IN ('LP', 'PO')) THEN
         RAISE e_bad_create_for_what;
      END IF;

      -- Check for bad combination of parameters.
      IF (   (l_create_for_what != 'LP' AND i_dest_loc IS NOT NULL)
          OR (l_create_for_what = 'LP' AND i_dest_loc IS NULL) ) THEN
         -- i_dest_loc should only have a value if creating a batch for
         -- a single license plate.
         RAISE e_parameter_bad_combination;
      END IF;

      -- 01/28/05 prpbcb Added the update of the putawaylst.dest_loc to
      --                 i_dest_loc for the pallet when creating a batch
      --                 for a single LP.  This was done because of
      --                 how only one batch is created for for all the
      --                 child LP's going to reserve.  As has been
      --                 noted when creating a batch for a single LP
      --                 after a location has been keyed over a '*' in the
      --                 check-in screen this procedure gets called by the
      --                 PRE-UPDATE trigger to create the putaway batch.
      --                 Since the form has not yet updated the putawaylst
      --                 record the destination location is passed to this
      --                 procedure in i_dest_loc.  There is no problem when
      --                 the child pallet is going to a home slot or floating
      --                 slot but there are issues when the child LP is going
      --                 to reserve.  To keep from having to jump through
      --                 too many hoops the best thing to do is update the
      --                 putawaylst.dest_loc with i_dest_loc.
      --                 As a final word the best approach would be to call
      --                 this procedure from the form after the form has
      --                 updated the putawaylst.dest_loc and do away with
      --                 i_dest_loc.
      -- 03/10/05 prpbcb For returns putawaylst.dest_loc should
      --                 already have dest_loc set to i_dest_loc.
      --                 
      IF (l_create_for_what = 'LP') THEN
         UPDATE putawaylst
            SET dest_loc = i_dest_loc
          WHERE pallet_id = i_key_value
            AND dest_loc = '*';

         IF (SQL%FOUND) THEN
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
               'Updated putawaylst pallet ' || i_key_value ||
               ' dest_loc from "*" to ' || i_dest_loc || '.', NULL, NULL,
               pl_rcv_open_po_types.ct_application_function,
               gl_pkg_name);

         ELSE
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
               'Did not update putawaylst pallet ' || i_key_value ||
                ' dest_loc ' || i_dest_loc || ' because the dest_loc' ||
                ' was not "*".', NULL, NULL,
                pl_rcv_open_po_types.ct_application_function,
                gl_pkg_name);

         END IF;
      END IF;

      -- Create the putaway labor mgmt batches.

      FOR r_putaway IN c_putaway(l_create_for_what, i_key_value,
                                 i_dest_loc) LOOP

         l_existing_batch_no := NULL;   -- We want to start this with null.
         o_r_create_putaway_stats.no_records_processed :=
                  o_r_create_putaway_stats.no_records_processed + 1;

         BEGIN  -- Start a new block so errors can be trapped.

            IF (r_putaway.dest_loc = '*') THEN
               RAISE e_has_no_location;
            END IF;

            -- Check if a batch already exists for the pallet.
            -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
            IF (r_putaway.perm = 'Y' OR r_putaway.rule_id IN (1, 3, 5, 14)) THEN
               --
               -- Pallet going to a home slot or floating slot
               -- or miniloader/matrix induction location.
               --
               find_existing_putaway_batch(r_putaway.pallet_id, 
                                           l_existing_batch_no);

               IF (l_existing_batch_no IS NOT NULL) THEN
                  RAISE e_batch_already_exists;
               END IF;
            ELSE
               -- Pallet going to reserve.  The batch ref# will be the
               -- parent pallet id.
               find_existing_putaway_batch(r_putaway.parent_pallet_id,
                                           l_existing_batch_no);

               IF (l_existing_batch_no IS NOT NULL) THEN
                  RAISE e_batch_already_exists;
               END IF;
            END IF;

            -- Build the batch number.  If the pallet id is greater then
            -- ct_putaway_task_lp_length characters then the batch number
            -- is built from a sequence otherwise the pallet id is used.
            -- It is done this way because RDC has a 18 character LP and
            -- we do not want to have to expand the batch number.
            IF (LENGTH(r_putaway.pallet_id) >
                                        ct_putaway_task_lp_length) THEN

               SELECT forklift_lm_batch_no_seq.NEXTVAL
                 INTO l_temp_no FROM DUAL;
               l_batch_no := pl_lmc.ct_forklift_putaway ||
                                                TO_CHAR(l_temp_no);
            ELSE
               l_batch_no := pl_lmc.ct_forklift_putaway ||
                                                   r_putaway.pallet_id;
            END IF;

            -- Set the kvi_no_data_capture.
            -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
            IF (r_putaway.perm = 'N' AND r_putaway.rule_id NOT IN (1, 3, 5, 14)) THEN
               l_kvi_no_data_capture := 2;
            ELSIF (   l_previous_parent_pallet_id IS NULL
                   OR r_putaway.parent_pallet_id !=
                                     l_previous_parent_pallet_id
                   OR r_putaway.dest_loc != l_previous_dest_loc) THEN
               l_kvi_no_data_capture := 2;
            ELSE
               l_kvi_no_data_capture := 1;
            END IF;

            -- A putaway to a home slot or floating slot or induction slot
            -- will use the pallet id for the batch ref_no.
            -- A putaway to a reserve slot will use
            -- the parent pallet id for the batch ref_no.
            -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
            IF (r_putaway.perm = 'Y' OR r_putaway.rule_id IN (1, 3, 5, 14)) THEN
               l_ref_no := r_putaway.pallet_id;
            ELSE
               l_ref_no := r_putaway.parent_pallet_id;
            END IF;

            -- Build the comment for the batch.
            IF (r_putaway.perm = 'Y') THEN
               l_cmt := 'PUT OF MSKU PLT TO HOME.  PARENT LP ' ||
                        r_putaway.parent_pallet_id || '.';
            -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
            ELSIF (r_putaway.rule_id IN (1, 3, 5, 14)) THEN
               l_cmt := 'PUT OF MSKU PLT TO FLOATING.  PARENT LP ' ||
                        r_putaway.parent_pallet_id || '.';
            ELSE
               l_cmt :=
                 'PUT OF MSKU PLT TO RSRV.' ||
                 ' CHILD LPs: ' || TO_CHAR(r_putaway.record_count) || '.' ||
                 ' REF# IS PARENT LP.';
            END IF;

            INSERT INTO batch(batch_no,
                              jbcd_job_code,
                              status,
                              batch_date,
                              kvi_from_loc,
                              kvi_to_loc,
                              kvi_no_case,
                              kvi_no_split,
                              kvi_no_pallet,
                              kvi_no_item,
                              kvi_no_po,
                              kvi_cube,
                              kvi_wt,
                              kvi_no_loc,
                              total_count,
                              total_piece,
                              total_pallet,
                              ref_no,
                              kvi_distance,
                              goal_time,
                              target_time,
                              no_breaks,
                              no_lunches,
                              kvi_doc_time,
                              kvi_no_piece, 
                              kvi_no_data_capture,
                              msku_batch_flag,
                              cmt)
            SELECT l_batch_no             batch_no,
                   fk.putaway_jobcode     job_code,
                   'F'                    status,
                   TRUNC(SYSDATE)         batch_date,
                   NVL(i_kvi_from_loc, e.door_no)       kvi_from_loc,
                   NVL(i_dest_loc, r_putaway.dest_loc)  kvi_to_loc,
                   0.0                    kvi_no_case,
                   0.0                    kvi_no_split, 
                   1.0                    kvi_no_pallet,
                   r_putaway.kvi_no_item  kvi_no_item,
                   r_putaway.kvi_no_po    kvi_no_po,
                   r_putaway.kvi_cube     kvi_cube,
                   r_putaway.kvi_wt       kvi_wt,
                   1.0                    kvi_no_loc,
                   1                      total_count,
                   0                      total_piece,
                   1                      total_pallet,
                   l_ref_no               ref_no,
                   0.0                    kvi_distance,
                   0.0                    goal_time,
                   0.0                    target_time,
                   0.0                    no_breaks,
                   0.0                    no_lunches,
                   1.0                    kvi_doc_time,
                   0.0                    kvi_no_piece,
                   l_kvi_no_data_capture  kvi_no_data_capture,
                   'Y'                    msku_batch_flag,
                   l_cmt
              FROM job_code          j,
                   fk_area_jobcodes  fk,
                   swms_sub_areas    ssa,
                   aisle_info        ai,
                   erm               e
             WHERE j.jbcd_job_code     = fk.putaway_jobcode
               AND fk.sub_area_code    = ssa.sub_area_code
               AND ssa.sub_area_code   = ai.sub_area_code
               AND ai.name 
                        = SUBSTR(NVL(i_dest_loc, r_putaway.dest_loc), 1, 2)
               AND e.erm_id            = r_putaway.rec_id;

            IF (SQL%FOUND) THEN
               -- Record inserted successfully.
               o_r_create_putaway_stats.no_batches_created :=
                          o_r_create_putaway_stats.no_batches_created + 1;

               --
               -- Update the putaway task with the labor batch number.
               -- All of the putaway tasks going to a reserve slot will
               -- have the same labor batch number.
               -- Each putaway task going to a home slot or floating slot or
               -- induction location will have a separate batch number.
               --
               -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
               IF (r_putaway.perm = 'Y' OR r_putaway.rule_id IN (1, 3, 5, 14)) THEN
                  -- The record being processed is a putaway task going to
                  -- a home slot or floating slot or miniloader induction
                  -- location.
                  UPDATE putawaylst
                     SET pallet_batch_no = l_batch_no
                   WHERE pallet_id = r_putaway.pallet_id;
               ELSE
                  -- The record being processed is for all the putaway tasks
                  -- going to a reserve slot for a PO or could be for a single
                  -- LP going to reserve.  If processing a PO then update all
                  -- the putaway tasks going to the reserve slot.  If processing
                  -- a single LP then update only that LP.

                  -- OPCOF-3577 Parent pallet id has only a space so rule 14 is used to get pallet id
                  IF (l_create_for_what = 'PO' AND r_putaway.rule_id <> 14 ) THEN
                     UPDATE putawaylst p
                        SET p.pallet_batch_no = l_batch_no
                      WHERE p.parent_pallet_id = r_putaway.parent_pallet_id
                        AND NOT EXISTS
                                 (SELECT 'x'
                                    FROM loc l
                                   WHERE l.logi_loc = p.dest_loc
                                     AND l.perm = 'Y')
                        AND NOT EXISTS
                                 (SELECT 'x'
                                    FROM zone z, lzone lz, loc l
                                   WHERE l.logi_loc  = p.dest_loc
                                     AND lz.logi_loc = l.logi_loc
                                     AND z.zone_id   = lz.zone_id
                                     AND z.zone_type = 'PUT'
                                     AND z.rule_id   IN (1, 3, 5));
                  ELSE
                     UPDATE putawaylst p
                        SET p.pallet_batch_no = l_batch_no
                      WHERE p.pallet_id = i_key_value;
                  END IF;
               END IF;

               IF (SQL%NOTFOUND) THEN
                  -- No row(s) updated.  This is a fatal error.
                  l_message := 'TABLE=putawaylst  ACTION=UPDATE' ||
                     ' KEY=' ||  r_putaway.pallet_id || '(pallet id)' ||
                     ' MESSAGE="SQL%NOTFOUND true.  Failed to update' ||
                     ' the pallet_batch_no to [' || l_batch_no || ']"';

                  pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                                 l_message, pl_exc.ct_putawaylst_update_fail,
                                 NULL,
                                 pl_rcv_open_po_types.ct_application_function,
                                 gl_pkg_name);

                  RAISE pl_exc.e_putawaylst_update_fail;
               END IF;

            ELSE
               -- Inserted 0 records into the batch table.  Most likely
               -- because of a data setup issue.  Write log record and
               -- continue processing.
               o_r_create_putaway_stats.no_not_created_due_to_error :=
                   o_r_create_putaway_stats.no_not_created_due_to_error + 1;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                     '  KEY=[' ||  r_putaway.pallet_id ||
                     '](pallet id)' ||
                     '  JOIN TABLES=job_code,fk_area_jobcodes,' ||
                     'swms_sub_areas,aisle_info,erm' ||
                     '  MESSAGE="Forklift putaway batch not created. No' ||
                     ' record selected to insert into batch table. ' ||
                     '  Could be a data setup issue."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                              l_message,
                              pl_exc.ct_lm_batch_upd_fail, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);
            END IF;

         EXCEPTION
            WHEN e_has_no_location THEN
               -- 01/27/05 prpbcb This point will never be reached because of
               --                 changes made to the cursor to get the rule id
               --                 of the zone for the destination location
               --                 thus a putawaylst record with '*' as the
               --                 location will never be selected.  A select
               --                 stmt was added at the end of the procedure
               --                 to get the count.
               --
               -- The putaway task has a '*' location for the pallet.
               -- No batch will be created.
               o_r_create_putaway_stats.no_with_no_location :=
                        o_r_create_putaway_stats.no_with_no_location + 1;

            WHEN e_batch_already_exists OR DUP_VAL_ON_INDEX THEN
               -- Batch already exists.  This is OK because this procedure
               -- could have been run again for the same data.
               --
               -- If this procedure was called to create a batch for a single
               -- LP going to a reserve slot then re-calculate the batches
               -- cube, weight etc.  See the comments for this procedure dated
               -- 12/29/04 for more info.  Also update the putaway task
               -- pallet batch number.
               IF (l_create_for_what = 'LP') THEN
                  IF (r_putaway.perm = 'N' AND r_putaway.rule_id NOT IN (1, 3, 5))
                  THEN
                      update_msku_batch_info(l_existing_batch_no);
                  END IF;

                  UPDATE putawaylst p
                     SET p.pallet_batch_no = l_existing_batch_no
                   WHERE p.pallet_id = i_key_value;

                  IF (SQL%NOTFOUND) THEN
                     -- No row(s) updated.  This is a fatal error.
                     l_message := 'TABLE=putawaylst  ACTION=UPDATE' ||
                     ' KEY=' ||  r_putaway.pallet_id || '(pallet id)' ||
                     ' MESSAGE="SQL%NOTFOUND true.  Failed to update' ||
                     ' the pallet_batch_no to [' || l_batch_no || ']"';

                     pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                                    l_message,
                                    pl_exc.ct_putawaylst_update_fail, NULL,
                                    pl_rcv_open_po_types.ct_application_function,
                                    gl_pkg_name);

                     RAISE pl_exc.e_putawaylst_update_fail;
                  END IF;
               END IF;             

               o_r_create_putaway_stats.no_batches_existing :=
                        o_r_create_putaway_stats.no_batches_existing + 1;

            WHEN OTHERS THEN
               -- Got some kind of oracle error.  Log the error then
               -- continue processing.
               o_r_create_putaway_stats.no_not_created_due_to_error :=
                   o_r_create_putaway_stats.no_not_created_due_to_error + 1;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                     '  KEY=[' ||  r_putaway.pallet_id ||
                     '](pallet id)' ||
                     '  JOIN TABLES=job_code,fk_area_jobcodes,' ||
                     'swms_sub_areas,aisle_info,pm,erm,putawaylst' ||
                     '  i_create_for_what[' || i_create_for_what || '],' ||
                     '  i_key_value[' || i_key_value || '],' ||
                     '  i_dest_loc[' || i_dest_loc || '],' ||
                     '  MESSAGE="Forklift putaway batch not created."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                              SQLCODE, SQLERRM,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

         END;   -- end of block

         l_previous_parent_pallet_id := r_putaway.parent_pallet_id;
         l_previous_dest_loc         := r_putaway.dest_loc;

      END LOOP;


      -- 01/27/05 prpbcb Get the count of putawaylst record with '*' as the
      --                 location because the cursor will never select these.
      --                 Only do this when creating the batches for a PO.
      --                 When creating a batch for a LP the putawaylst record
      --                 should have a dest loc.
      IF (l_create_for_what = 'PO') THEN
         SELECT COUNT(*)
           INTO o_r_create_putaway_stats.no_with_no_location
           FROM putawaylst
          WHERE rec_id   = i_key_value
            AND parent_pallet_id IS NOT NULL  -- Want only MSKU's
            AND dest_loc = '*';
      END IF;

      l_message := 
          'Created putaway forklift labor mgmt batches for[' ||
          i_create_for_what || '],' ||
          ' key value[' || i_key_value || '],' ||
          ' dest loc[' || i_dest_loc || '](applies when creating batch' ||
          ' for a LP),' ||
          '  #records processed[' ||
          TO_CHAR(o_r_create_putaway_stats.no_records_processed) || ']' ||
          '  #batches created[' ||
           TO_CHAR(o_r_create_putaway_stats.no_batches_created) || ']' ||
          '  #batches already existing[' ||
           TO_CHAR(o_r_create_putaway_stats.no_batches_existing) || ']' ||
          '  #batches not created because of error[' ||
    TO_CHAR(o_r_create_putaway_stats.no_not_created_due_to_error) || ']' ||
          '  #tasks with no location[' ||
           TO_CHAR(o_r_create_putaway_stats.no_with_no_location) || ']';

      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                     NULL, NULL,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_create_for_what[' ||
            i_create_for_what || ']  or i_key_value[' || i_key_value || ']' ||
            ' is null';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_bad_create_for_what THEN
         l_message := l_object_name || ': Bad value in i_create_for_what[' ||
            i_create_for_what || '].  Value values are LP or PO.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_parameter_bad_combination THEN
         -- i_dest_loc should only have a value if creating a batch for
         -- a single license plate.
         l_message := l_object_name ||
             '(i_create_for_what[' || i_create_for_what || '],' ||
             ' i_key_value[' || i_key_value || '],' ||
             ' i_dest_loc[' || i_dest_loc || '],' ||
             'o_no_records_processed,o_no_batches_created,' ||
             'o_no_batches_existing,o_no_not_created_due_to_error)'  ||
             ' i_dest_loc can only have a value when i_create_for_what is LP';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name ||
             '(i_create_for_what[' || i_create_for_what || '],' ||
             ' i_key_value[' || i_key_value || '],' ||
             ' i_dest_loc[' || i_dest_loc || '],' ||
             'o_no_records_processed,o_no_batches_created,' ||
             'o_no_batches_existing,o_no_not_created_due_to_error)';

         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END create_msku_putaway_batches;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_rtn_msku_put_batches
   --
   --    NOT USED     NOT USED     NOT USED     NOT USED     NOT USED
   --    NOT USED     NOT USED     NOT USED     NOT USED     NOT USED
   --    NOT USED     NOT USED     NOT USED     NOT USED     NOT USED
   --    NOT USED     NOT USED     NOT USED     NOT USED     NOT USED
   --    NOT USED     NOT USED     NOT USED     NOT USED     NOT USED
   --    03/22/06 prpbcb  But do not remove this procedure.  Currently
   --    procedure create_returns_putaway_batches() calls procedure
   --    create_msku_putaway_batches() to create the returns batches.
   --    The main cursor in create_msku_putaway_batches does special processing
   --    for erm type = 'CM'.  If it gets to the point that
   --    create_msku_putaway_batches() has to be hacked up to much to handle
   --    any returns issues/changes then maybe
   --    create_returns_putaway_batches() should be changed to call this
   --    procedure (verifying this procedure does the right thing).
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batches for MSKU putaway
   --   tasks if forklift labor management is active.  The batches can be
   --   created for a PO or for a single license plate.  A batch will not be
   --   created for putaway tasks with a destination location of '*' when
   --   creating for a PO or when creating for a single license plate
   --   and i_dest_loc is null.
   --
   --   *********************************************************************
   --   ** 09/30/03 prpbcb                                                 **
   --   ** This function is very similiar to create_putaway_batches but    **
   --   ** there is enough differences I think to warrant a new procedure. **
   --   *********************************************************************
   --
   --   After the batch is created the putawaylst.pallet_batch_no is updated
   --   with the batch number.  For the putaway tasks going to a reserve slot
   --   or floating slot a MSKU all the putawaylst records are updated to the
   --   same batch number because there is only one batch for a putaway to a
   --   reserve or floating slot.
   --
   --   06/04/03 Prior to RDC the batch number format was FP<pallet id>.
   --      Example:  FP3458561
   --   A change was made in the batch number format for RDC because the RDC
   --   pallet id is 18 characters which if using the original format would
   --   make the batch number 20 characters which in turn would require the
   --   batch_no column in the BATCH and ARCH_BATCH table to be lengthed and
   --   many forms and reports to change.  The format of the batch number will
   --   be:
   --      - If the length of the pallet id > ct_putaway_task_lp_length then
   --        the batch number will be
   --           FP<forklift_lm_batch_no_seq.NEXTVAL>.
   --        This is a new sequence that will always be a number 9 digits long.
   --        This makes the batch number 11 characters in length which is
   --        within the current size of the batch number in the database and
   --        in the screens.  The sequence is 9 digits so there is no
   --        possibilty of getting a duplicate batch number with a
   --        FP<pallet id> batch--AS LONG AS THE MAX VALUE FOR THE
   --        PALLET_ID_SEQ IS NOT CHANGED.  Building the batch number from a
   --        sequence does have an impact wnen checking if a batch already
   --        exists.  Since the batch number is composed of a value(the
   --        sequence) not stored in the putawaylst record a check
   --        for a duplicate needs to be made by looking for the pallet id
   --        in the ref_no column and a batch starting with 'FP'.
   --
   --      - If the length of the pallet id < ct_putaway_task_lp_length then
   --        the batch will be
   --           FP<pallet id>  (like is currently is)
   --
   --   The values for kvi_no_data_capture will be as follows:
   --      2 for the first batch going to a home slot.  This is for the scan
   --        of the home slot and then the pallet id.
   --      1 for subsequent batches to the same home slot.  This is for the
   --        scan of the pallet id.
   --      2 for the first batch going to a reserve slot.  This is for the
   --        scan of the pallet at the dock and the scan of the reserve slot.
   --   If this logic changes then also look at
   --   pl_lm_msku.calculate_kvi_values.
   --
   --   For kvi_no_po the number of distinct PO's is used.  A SN could have
   --   different PO's on a MSKU.
   --
   --   Each putaway to a home slot will have a batch.
   --   The LP's going to a reserve or floating slot will have one batch.
   --   Example:
   --                                               Create Batch   kvi_no_data_
   --      LP       Parent LP  Dest Loc  Home Slot  for LP         capture
   --      -------  ---------  --------  ---------  -------------  -----------
   --      123        555      DA01A1       Yes        Yes            2
   --      124        555      DA01A1       Yes        Yes            1
   --      125        555      DA01A1       Yes        Yes            1
   --      126        555      DA05B1       Yes        Yes            2
   --      127        555      DA05B1       Yes        Yes            1
   --      128        555      DA12A5       No         No   -+
   --      129        555      DA12A5       No         No    |        2
   --      130        555      DA12A5       No         No    | 
   --      131        555      DA12A5       No         No    | One batch created
   --      132        555      DA12A5       No         No    | for the pallets
   --      133        555      DA12A5       No         No    | going to a
   --      135        555      DA12A5       No         No   -+ reserve slot.
   --
   -- Parameters:
   --    i_create_for_what      - Designates what to create the batches for.
   --                             The valid values are:
   --                                - LP    for a license plate
   --                                - PO    for a PO
   --                             The value will be converted to upper case by 
   --                             this procedure.
   --    i_key_value            - Pallet id if i_create_for_what is 'LP'.
   --                           - PO # if i_create_for_what is 'PO'.
   --    i_dest_loc             - The destination location when creating a
   --                             batch for a single license plate.  This is
   --                             optional but is required when form rp1sc
   --                             calls this procedure.  In form rp1sc the
   --                             batch is created when a destination
   --                             location is keyed over a '*' or the qty
   --                             received is changed from 0 to > 0.  Because
   --                             of when the form calls this procedure
   --                             the putawaylst records does not yet have
   --                             the dest_loc updated so it needs to be passed
   --                             in.  If this is null then a valid destination
   --                             location will need to exist in the putawaylst
   --                             table in for order for the batch to be
   --                             created since the cursor in this procedure
   --                             will only look at putawaylst records with
   --                             dest_loc != '*'.
   --    i_kvi_from_loc         - The value to use for the batch kvi_from_loc
   --                             for returns.  Mandatory for returns putaway
   --                             batches.  Returns are treated like a RDC
   --                             MSKU.  Leave null for everything else.
   --    o_r_create_putaway_stats - Statistics about batches created.
   --
   -- Called by:
   --    - create_returns_putaway_batches  (Returns are treated like a MSKU)
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null or an unhandled value
   --                               for a parameter or a bad combination
   --                               of parameters.
   --    pl_exe.e_putawaylst_update_fail - No rows updated when updating the
   --                                      putawaylst.pallet_batch_no with the
   --                                      batch number.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/28/04 prpbcb   Created.
   --                      Copied create_msku_putaway_batches and modified for
   --                      returns.
   ---------------------------------------------------------------------------

   PROCEDURE create_rtn_msku_put_batches
              (i_create_for_what         IN  VARCHAR2,
               i_key_value               IN  VARCHAR2,
               i_dest_loc                IN  putawaylst.dest_loc%TYPE
                                                            DEFAULT NULL,
               i_kvi_from_loc            IN  arch_batch.kvi_from_loc%TYPE
                                                            DEFAULT NULL,
               o_r_create_putaway_stats  OUT t_create_putaway_stats_rec)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_msku_putaway_batches';

      l_batch_no            arch_batch.batch_no%TYPE;
      l_create_for_what     VARCHAR2(20);   -- Populated from i_create_for_what.
      l_existing_batch_no   arch_batch.batch_no%TYPE; -- Existing batch
                                    -- number if it exists for the pallet.
      l_kvi_no_data_capture arch_batch.kvi_no_data_capture%TYPE;
      l_ref_no              arch_batch.ref_no%TYPE;  -- Value for batch.ref_no
      l_temp_no             NUMBER;                  -- Work area.

      -- Previous values. 
      l_previous_parent_pallet_id putawaylst.pallet_id%TYPE := NULL;
      l_previous_dest_loc         putawaylst.dest_loc%TYPE  := NULL;

      e_bad_create_for_what   EXCEPTION;  -- Bad value in i_bad_create_for_what
      e_batch_already_exists  EXCEPTION;  -- Putaway batch already exists.
      e_has_no_location       EXCEPTION;  -- Destination location is '*'.
      e_parameter_bad_combination    EXCEPTION;  -- Bad combination of
                                                 -- parameters.

      -- This cursor selects the MSKU pallets to create batches for.
      -- For each cursor record a batch will be created.  Another way to have
      -- done this is by removing the grouping and keeping track of when to
      -- create a batch in the cursor for loop.

      CURSOR c_putaway(cp_create_for_what     VARCHAR2,
                       cp_key_value           VARCHAR2,
                       cp_dest_loc            putawaylst.dest_loc%TYPE) IS
         SELECT DECODE(l.perm, 'Y', p.pallet_id, p.parent_pallet_id) pallet_id,
                p.parent_pallet_id                           parent_pallet_id,
                DECODE(l.perm, 'Y', '0', '1')                perm_sort,
                l.perm                                       perm,
                p.dest_loc                                   dest_loc,
                p.rec_id                                     rec_id,
                COUNT(DISTINCT p.prod_id || p.cust_pref_vendor) kvi_no_item,
                COUNT(DISTINCT p.po_no)                      kvi_no_po,
                SUM(TRUNC((p.qty / pm.spc) * pm.case_cube))  kvi_cube,
                SUM(TRUNC(p.qty * NVL(pm.g_weight, 0)))      kvi_wt,
                COUNT(1)                                     record_count
           FROM pm pm,
                loc l,
                putawaylst p
          WHERE cp_create_for_what  = 'PO'
            AND p.rec_id            = cp_key_value
            AND p.parent_pallet_id  IS NOT NULL   -- Select MSKU pallets
            AND l.logi_loc          = p.dest_loc
            AND pm.prod_id          = p.prod_id
            AND pm.cust_pref_vendor = p.cust_pref_vendor
          GROUP BY
                DECODE(l.perm, 'Y', p.pallet_id, p.parent_pallet_id),
                p.parent_pallet_id,
                DECODE(l.perm, 'Y', '0', '1'),
                l.perm,
                p.dest_loc,
                p.rec_id
          UNION                       -- Select record for a single LP
         SELECT DECODE(l.perm, 'Y', p.pallet_id, p.parent_pallet_id) pallet_id,
                p.parent_pallet_id                           parent_pallet_id,
                DECODE(l.perm, 'Y', '0', '1')                perm_sort,
                l.perm                                       perm,
                cp_dest_loc                                  dest_loc,
                p.rec_id                                     rec_id,
                COUNT(DISTINCT p.prod_id || p.cust_pref_vendor) kvi_no_item,
                COUNT(DISTINCT p.rec_id)                     kvi_no_po,
                SUM(TRUNC((p.qty / pm.spc) * pm.case_cube))  kvi_cube,
                SUM(TRUNC(p.qty * NVL(pm.g_weight, 0)))      kvi_wt,
                COUNT(1)                                     record_count
           FROM pm pm,
                loc l,
                putawaylst p
          WHERE cp_dest_loc        IS NOT NULL
            AND l.logi_loc         = cp_dest_loc
            AND cp_create_for_what = 'LP'
            AND p.pallet_id        = cp_key_value
            AND p.parent_pallet_id IS NOT NULL    -- Select MSKU pallets
            AND pm.prod_id          = p.prod_id
            AND pm.cust_pref_vendor = p.cust_pref_vendor
          GROUP BY
                DECODE(l.perm, 'Y', p.pallet_id, p.parent_pallet_id),
                p.parent_pallet_id,
                DECODE(l.perm, 'Y', '0', '1'),
                l.perm,
                cp_dest_loc,
                p.rec_id
          ORDER BY 2, 3, 5, 1;

   BEGIN
      -- Initialize the statistics count.
      o_r_create_putaway_stats.no_records_processed := 0;
      o_r_create_putaway_stats.no_batches_created  := 0;
      o_r_create_putaway_stats.no_batches_existing := 0;
      o_r_create_putaway_stats.no_not_created_due_to_error := 0;
      o_r_create_putaway_stats.no_with_no_location := 0;
      o_r_create_putaway_stats.num_live_receiving_location := 0;

      -- Check for null parameters.
      IF (i_create_for_what IS NULL OR i_key_value IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      l_create_for_what := UPPER(i_create_for_what);
      IF (l_create_for_what NOT IN ('LP', 'PO')) THEN
         RAISE e_bad_create_for_what;
      END IF;

      -- Check for bad combination of parameters.
      IF (   (i_create_for_what != 'LP' AND i_dest_loc IS NOT NULL)
          OR (l_create_for_what = 'LP' AND i_dest_loc IS NULL) ) THEN
         -- i_dest_loc should only have a value if creating a batch for
         -- a single license plate.
         RAISE e_parameter_bad_combination;
      END IF;

      -- Create the putaway labor mgmt batches.

      FOR r_putaway IN c_putaway(l_create_for_what, i_key_value,
                                 i_dest_loc) LOOP

         o_r_create_putaway_stats.no_records_processed :=
                  o_r_create_putaway_stats.no_records_processed + 1;

         BEGIN  -- Start new block so errors can be trapped.

            IF (r_putaway.dest_loc = '*') THEN
               RAISE e_has_no_location;
            END IF;

            -- Check if a batch already exists for the pallet.
            IF (r_putaway.perm = 'Y') THEN
               -- Pallet going to a home slot.
               find_existing_putaway_batch(r_putaway.pallet_id,
                                           l_existing_batch_no);

               IF (l_existing_batch_no IS NOT NULL) THEN
                  RAISE e_batch_already_exists;
               END IF;
            ELSE
               -- Pallet going to reserve.  The batch ref# will be the
               -- parent pallet id.
               find_existing_putaway_batch(r_putaway.parent_pallet_id,
                                           l_existing_batch_no);

               IF (l_existing_batch_no IS NOT NULL) THEN
                  RAISE e_batch_already_exists;
               END IF;
            END IF;

            -- Build the batch number.  If the pallet id is greater then
            -- ct_putaway_task_lp_length characters then the batch number
            -- is built from a sequence otherwise the pallet id is used.
            -- It is done this way because RDC has a 18 character LP and
            -- we do not want to have to expand the batch number.
            IF (LENGTH(r_putaway.pallet_id) >
                                        ct_putaway_task_lp_length) THEN

               SELECT forklift_lm_batch_no_seq.NEXTVAL
                 INTO l_temp_no FROM DUAL;
               l_batch_no := pl_lmc.ct_forklift_putaway ||
                                                TO_CHAR(l_temp_no);
            ELSE
               l_batch_no := pl_lmc.ct_forklift_putaway ||
                                                   r_putaway.pallet_id;
            END IF;

            -- Set the kvi_no_data_capture.
            IF (r_putaway.perm = 'N') THEN
               l_kvi_no_data_capture := 2;
            ELSIF (   l_previous_parent_pallet_id IS NULL
                   OR r_putaway.parent_pallet_id !=
                                     l_previous_parent_pallet_id
                   OR r_putaway.dest_loc != l_previous_dest_loc) THEN
               l_kvi_no_data_capture := 2;
            ELSE
               l_kvi_no_data_capture := 1;
            END IF;

            -- A putaway to a home slot will use the pallet id for the
            -- batch ref_no.  A putaway to a reserve slot will use the
            -- parent pallet id for the batch ref_no.
            IF (r_putaway.perm = 'Y') THEN
               l_ref_no := r_putaway.pallet_id;
            ELSE
               l_ref_no := r_putaway.parent_pallet_id;
            END IF;

            INSERT INTO batch(batch_no,
                              jbcd_job_code,
                              status,
                              batch_date,
                              kvi_from_loc,
                              kvi_to_loc,
                              kvi_no_case,
                              kvi_no_split,
                              kvi_no_pallet,
                              kvi_no_item,
                              kvi_no_po,
                              kvi_cube,
                              kvi_wt,
                              kvi_no_loc,
                              total_count,
                              total_piece,
                              total_pallet,
                              ref_no,
                              kvi_distance,
                              goal_time,
                              target_time,
                              no_breaks,
                              no_lunches,
                              kvi_doc_time,
                              kvi_no_piece, 
                              kvi_no_data_capture,
                              msku_batch_flag,
                              cmt)
            SELECT l_batch_no          batch_no,
                   fk.putaway_jobcode  job_code,
                   'F'                 status,
                   TRUNC(SYSDATE)      batch_date,
                   NVL(i_kvi_from_loc, e.door_no)        kvi_from_loc,
                   NVL(i_dest_loc, r_putaway.dest_loc)   kvi_to_loc,
                   0.0                 kvi_no_case,
                   0.0                 kvi_no_split, 
                   1.0                 kvi_no_pallet,
                   r_putaway.kvi_no_item  kvi_no_item,
                   r_putaway.kvi_no_po    kvi_no_po,
                   r_putaway.kvi_cube     kvi_cube,
                   r_putaway.kvi_wt       kvi_wt,
                   1.0                 kvi_no_loc,
                   1                   total_count,
                   0                   total_piece,
                   1                   total_pallet,
                   l_ref_no            ref_no,
                   0.0                 kvi_distance,
                   0.0                 goal_time,
                   0.0                 target_time,
                   0.0                 no_breaks,
                   0.0                 no_lunches,
                   1.0                 kvi_doc_time,
                   0.0                 kvi_no_piece,
                   l_kvi_no_data_capture  kvi_no_data_capture,
                   'Y'                 msku_batch_flag,
                   DECODE(r_putaway.perm,
               'Y', 'PUTAWAY OF RETURN MSKU PLT TO HOME.  PARENT LP ' ||
                                     r_putaway.parent_pallet_id,
               'PUTAWAY OF RETURN MSKU PALLET TO RESERVE.  REF# IS THE PARENT LP.')
              FROM job_code j,
                   fk_area_jobcodes fk,
                   swms_sub_areas ssa,
                   aisle_info ai,
                   erm e
             WHERE j.jbcd_job_code     = fk.putaway_jobcode
               AND fk.sub_area_code    = ssa.sub_area_code
               AND ssa.sub_area_code   = ai.sub_area_code
               AND ai.name 
                        = SUBSTR(NVL(i_dest_loc, r_putaway.dest_loc), 1, 2)
               AND e.erm_id            = r_putaway.rec_id;

            IF (SQL%FOUND) THEN
               -- Record inserted successfully.
               o_r_create_putaway_stats.no_batches_created :=
                          o_r_create_putaway_stats.no_batches_created + 1;

               -- Update the putaway task with the batch number.
               -- All of the tasks going to reserve on a MSKU will have the
               -- same labor batch number.
               IF (r_putaway.perm = 'Y') THEN
                  UPDATE putawaylst
                     SET pallet_batch_no = l_batch_no
                   WHERE pallet_id = r_putaway.pallet_id;
               ELSE
                  UPDATE putawaylst p
                     SET p.pallet_batch_no = l_batch_no
                   WHERE p.parent_pallet_id = r_putaway.parent_pallet_id
                     AND NOT EXISTS
                              (SELECT 'x'
                                 FROM loc l
                                WHERE l.logi_loc = p.dest_loc
                                  AND l.perm = 'Y');
               END IF;

               IF (SQL%NOTFOUND) THEN
                  -- No row updated.  This is a fatal error.
                  l_message := 'TABLE=putawaylst  ACTION=UPDATE' ||
                     ' KEY=' ||  r_putaway.pallet_id || '(pallet id)' ||
                     ' MESSAGE="SQL%NOTFOUND true.  Failed to update' ||
                     ' the pallet_batch_no to [' || l_batch_no || ']"';

                  pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                                 l_message,
                                 pl_exc.ct_putawaylst_update_fail, NULL,
                                 pl_rcv_open_po_types.ct_application_function,
                                 gl_pkg_name);

                  RAISE pl_exc.e_putawaylst_update_fail;
               END IF;

            ELSE
               -- Inserted 0 records into the batch table.  Most likely
               -- because of a data setup issue.  Write log record and
               -- continue processing.
               o_r_create_putaway_stats.no_not_created_due_to_error :=
                   o_r_create_putaway_stats.no_not_created_due_to_error + 1;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                     '  KEY=[' ||  r_putaway.pallet_id ||
                     '](pallet id)' ||
                     '  JOIN TABLES=job_code,fk_area_jobcodes,' ||
                     'swms_sub_areas,aisle_info,erm' ||
                     '  MESSAGE="Forklift putaway batch not created. No' ||
                     ' record selected to insert into batch table. ' ||
                     '  Could be a data setup issue."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                              l_message,
                              pl_exc.ct_lm_batch_upd_fail, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);
            END IF;

         EXCEPTION
            WHEN e_has_no_location THEN
               -- No location was found for the pallet.
               o_r_create_putaway_stats.no_with_no_location :=
                        o_r_create_putaway_stats.no_with_no_location + 1;

            WHEN e_batch_already_exists OR DUP_VAL_ON_INDEX THEN
               -- Batch already exists.  This is OK because this procedure
               -- could have been run again for the same data.
               o_r_create_putaway_stats.no_batches_existing :=
                        o_r_create_putaway_stats.no_batches_existing + 1;

            WHEN OTHERS THEN
               -- Got some kind of oracle error.  Log the error then
               -- continue processing.
               o_r_create_putaway_stats.no_not_created_due_to_error :=
                   o_r_create_putaway_stats.no_not_created_due_to_error + 1;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                     '  KEY=[' ||  r_putaway.pallet_id ||
                     '](pallet id)' ||
                     '  JOIN TABLES=job_code,fk_area_jobcodes,' ||
                     'swms_sub_areas,aisle_info,pm,erm,putawaylst' ||
                     '  i_create_for_what[' || i_create_for_what || '],' ||
                     '  i_key_value[' || i_key_value || '],' ||
                     '  i_dest_loc[' || i_dest_loc || '],' ||
                     '  MESSAGE="Forklift putaway batch not created."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                              SQLCODE, SQLERRM,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

         END;   -- end of block

         l_previous_parent_pallet_id := r_putaway.parent_pallet_id;
         l_previous_dest_loc         := r_putaway.dest_loc;

      END LOOP;

      l_message := 
          'Created putaway forklift labor mgmt batches for[' ||
          i_create_for_what || '],' ||
          ' key value[' || i_key_value || '],' ||
          ' dest loc[' || i_dest_loc || '](applies when creating batch' ||
          ' for a LP),' ||
          '  #records processed[' ||
          TO_CHAR(o_r_create_putaway_stats.no_records_processed) || ']' ||
          '  #batches created[' ||
           TO_CHAR(o_r_create_putaway_stats.no_batches_created) || ']' ||
          '  #batches already existing[' ||
           TO_CHAR(o_r_create_putaway_stats.no_batches_existing) || ']' ||
          '  #batches not created because of error[' ||
    TO_CHAR(o_r_create_putaway_stats.no_not_created_due_to_error) || ']' ||
          '  #tasks with no location[' ||
           TO_CHAR(o_r_create_putaway_stats.no_with_no_location) || ']';

      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                     NULL, NULL,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_create_for_what[' ||
            i_create_for_what || ']  or i_key_value[' || i_key_value || ']' ||
            ' is null';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_bad_create_for_what THEN
         l_message := l_object_name || ': Bad value in i_create_for_what[' ||
            i_create_for_what || '].  Value values are LP or PO.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_parameter_bad_combination THEN
         -- i_dest_loc should only have a value if creating a batch for
         -- a single license plate.
         l_message := l_object_name ||
             '(i_create_for_what[' || i_create_for_what || '],' ||
             ' i_key_value[' || i_key_value || '],' ||
             ' i_dest_loc[' || i_dest_loc || '],' ||
             'o_no_records_processed,o_no_batches_created,' ||
             'o_no_batches_existing,o_no_not_created_due_to_error)'  ||
             ' i_dest_loc can only have a value when i_create_for_what is LP';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name ||
             '(i_create_for_what[' || i_create_for_what || '],' ||
             ' i_key_value[' || i_key_value || '],' ||
             ' i_dest_loc[' || i_dest_loc || '],' ||
             'o_no_records_processed,o_no_batches_created,' ||
             'o_no_batches_existing,o_no_not_created_due_to_error)';

         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END create_rtn_msku_put_batches;




   -- end of private modules

   ---------------------------------------------------------------------------
   ---------------------------------------------------------------------------
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Function:
   --    f_forklift_active
   --
   -- Description:
   --    This function determines if forklift labor mgmt is active.
   --    Forklift is active when syspar LBR_MGMT_FLAG is 'Y' and
   --    column create_batch_flag is 'Y' in table lbr_func where
   --    lfun_lbr_func = 'FL'.
   --
   -- Parameters:
   --    none
   --  
   -- Return Values:
   --    TRUE  - forklift is active.
   --    FALSE - forklift is not active.
   --
   -- Exceptions raised:
   --    -20001  An oracle error occurred.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    06/21/01 prpbcb   Created.
   --  
   ---------------------------------------------------------------------------
   FUNCTION f_forklift_active
   RETURN BOOLEAN IS
      l_create_batch_flag  lbr_func.create_batch_flag%TYPE := NULL;
      l_forklift_active    BOOLEAN;        -- Designates if forklift is active.
      l_lbr_mgmt_flag      sys_config.config_flag_val%TYPE := NULL;
      l_object_name        VARCHAR2(30) := 'f_forklift_active';
      l_sqlerrm            VARCHAR2(500);  -- SQLERRM

      -- This cursor selects the create batch flag for forklift labor mgmt.
      CURSOR c_lbr_func_forklift IS
         SELECT create_batch_flag
           FROM lbr_func
          WHERE lfun_lbr_func = 'FL';

   BEGIN
      l_lbr_mgmt_flag := pl_common.f_get_syspar('LBR_MGMT_FLAG', 'N');

      IF (l_lbr_mgmt_flag = 'Y') THEN
         -- Labor mgmt is on.
         -- See if forklift labor function is turned on.
         OPEN c_lbr_func_forklift;
         FETCH c_lbr_func_forklift INTO l_create_batch_flag;

         IF (c_lbr_func_forklift%NOTFOUND) THEN
            l_create_batch_flag := 'N';
         END IF;

         CLOSE c_lbr_func_forklift;

         IF  (l_create_batch_flag = 'Y') THEN
            l_forklift_active := TRUE;
         ELSE
            l_forklift_active := FALSE;
         END IF;
      ELSE
         l_forklift_active := FALSE;
      END IF;

      RETURN(l_forklift_active);

   EXCEPTION
      WHEN OTHERS THEN
         l_sqlerrm := SQLERRM;  -- Save mesg in case cursor cleanup fails.

         IF (c_lbr_func_forklift%ISOPEN) THEN   -- Cursor cleanup.
            CLOSE c_lbr_func_forklift;
         END IF;

         RAISE_APPLICATION_ERROR(-20001, l_object_name||' Error: ' ||
                                 l_sqlerrm);
   END f_forklift_active;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_is_returns_putaway_active
   --
   -- Description:
   --    This function determines if returns putaway labor mgmt is active.
   --    It is active when syspar LBR_MGMT_FLAG is 'Y' and
   --    column create_batch_flag is 'Y' in table lbr_func for
   --    lfun_lbr_func = 'RP'.
   --
   -- Parameters:
   --    none
   --  
   -- Return Values:
   --    TRUE  - forklift is active.
   --    FALSE - forklift is not active.
   --
   -- Exceptions raised:
   --    -20001  An oracle error occurred.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    06/21/01 prpbcb   Created.
   --  
   ---------------------------------------------------------------------------
   FUNCTION f_is_returns_putaway_active
   RETURN BOOLEAN
   IS
      l_create_batch_flag  lbr_func.create_batch_flag%TYPE := NULL;
      l_returns_putaway_active    BOOLEAN;  -- Designates if returns putaway
                                            -- labor mgmt is active.
      l_lbr_mgmt_flag      sys_config.config_flag_val%TYPE := NULL;
      l_object_name        VARCHAR2(30) := 'f_is_returns_putaway_active';
      l_sqlerrm            VARCHAR2(500);  -- SQLERRM

      -- This cursor selects the create batch flag for returns labor mgmt.
      CURSOR c_lbr_func_returns IS
         SELECT create_batch_flag
           FROM lbr_func
          WHERE lfun_lbr_func = 'RP';

   BEGIN
      l_lbr_mgmt_flag := pl_common.f_get_syspar('LBR_MGMT_FLAG', 'N');

      IF (l_lbr_mgmt_flag = 'Y') THEN
         -- Labor mgmt is on.
         -- See if returns putaway labor function is turned on.
         OPEN c_lbr_func_returns;
         FETCH c_lbr_func_returns INTO l_create_batch_flag;

         IF (c_lbr_func_returns%NOTFOUND) THEN
            l_create_batch_flag := 'N';
         END IF;

         CLOSE c_lbr_func_returns;

         IF  (l_create_batch_flag = 'Y') THEN
            l_returns_putaway_active := TRUE;
         ELSE
            l_returns_putaway_active := FALSE;
         END IF;
      ELSE
         l_returns_putaway_active := FALSE;
      END IF;

      RETURN(l_returns_putaway_active);

   EXCEPTION
      WHEN OTHERS THEN
         l_sqlerrm := SQLERRM;  -- Save mesg in case cursor cleanup fails.

         IF (c_lbr_func_returns%ISOPEN) THEN   -- Cursor cleanup.
            CLOSE c_lbr_func_returns;
         END IF;

         RAISE_APPLICATION_ERROR(-20001, l_object_name||' Error: ' ||
                                 l_sqlerrm);
   END f_is_returns_putaway_active;

  ---------------------------------------------------------------------------
  -- m.c.
   FUNCTION f_is_dci_putaway_active
   RETURN VARCHAR2    --BOOLEAN
   IS
      l_create_batch_flag  lbr_func.create_batch_flag%TYPE := NULL;
      l_dci_putaway_active    BOOLEAN;  -- Designates if returns putaway
                                            -- labor mgmt is active.
      l_lbr_mgmt_flag      sys_config.config_flag_val%TYPE := NULL;
      l_object_name        VARCHAR2(30) := 'f_is_returns_putaway_active';
      l_sqlerrm            VARCHAR2(500);  -- SQLERRM

      l_return_value VARCHAR2(1);

      -- This cursor selects the create batch flag for returns labor mgmt.
      CURSOR c_lbr_func_returns IS
         SELECT create_batch_flag
           FROM lbr_func
          WHERE lfun_lbr_func = 'DC'; --'RP';

   BEGIN
      l_lbr_mgmt_flag := pl_common.f_get_syspar('LBR_MGMT_FLAG', 'N');

      IF (l_lbr_mgmt_flag = 'Y') THEN
         -- Labor mgmt is on.
         -- See if returns putaway labor function is turned on.
         OPEN c_lbr_func_returns;
         FETCH c_lbr_func_returns INTO l_create_batch_flag;

         IF (c_lbr_func_returns%NOTFOUND) THEN
            --l_create_batch_flag := 'N';

            l_return_value := 'N';
         END IF;

         CLOSE c_lbr_func_returns;

         IF  (l_create_batch_flag = 'Y') THEN
            --l_dci_putaway_active := TRUE;
            l_return_value := 'Y';
         ELSE
            --l_dci_putaway_active := FALSE;
            l_return_value := 'N';
         END IF;
      ELSE
         --l_dci_putaway_active := FALSE;
         l_return_value := 'N';
      END IF;

      --RETURN(l_dci_putaway_active);
      RETURN(l_return_value);

   EXCEPTION
      WHEN OTHERS THEN
         l_sqlerrm := SQLERRM;  -- Save mesg in case cursor cleanup fails.

         IF (c_lbr_func_returns%ISOPEN) THEN   -- Cursor cleanup.
            CLOSE c_lbr_func_returns;
         END IF;

         RAISE_APPLICATION_ERROR(-20001, l_object_name||' Error: ' ||
                                 l_sqlerrm);
   END f_is_dci_putaway_active;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_fk_door_no
   --
   -- Description:
   --    This function returns the forklift labor management four digit door
   --    when given a two digit door number.  Its primary use is to validate
   --    the door number in the Order Generation, Door Assigment and
   --    Route Default Data screens and to convert the two digit door number
   --    to the four digit forklift door number when PO's are opened by
   --    swms oper daily.
   --
   -- Parameters:
   --    i_door_no   - Two digit door number.  Example: 15
   --                  Leading spaces and zeros are ignored.
   --  
   -- Return Value:
   --    Forklift four digit door number.  Example: D115
   --    If no data found then null is returned.
   --
   -- Exceptions raised:
   --    -20001  An oracle error occurred.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    01/16/02 prpbcb   DN _____  Fix bug in function f_get_fk_door_no
   --                      that would not handle door '0' correctly.
   --                      It ltrims leading '0's from i_door_no but if
   --                      i_door_no is one or more '0's then the ltrim
   --                      results in a null.
   ---------------------------------------------------------------------------
   FUNCTION f_get_fk_door_no(i_door_no IN VARCHAR2)
   RETURN VARCHAR2 IS
      l_object_name    VARCHAR2(30) := 'f_get_fk_door_no';

      l_door_no        point_distance.point_a%TYPE := NULL;  -- Forklift door#
      l_tmp_door_no    VARCHAR2(30);  -- Work area.

      -- Ignore leading spaces and zeros in cp_door_no.
      CURSOR c_door_no(cp_door_no VARCHAR2) IS
         SELECT point_a
           FROM point_distance
          WHERE point_type = 'DA'
            AND point_a LIKE '__' || LPAD(cp_door_no, 2,'0')
            AND LENGTH(cp_door_no) <= 2;
   BEGIN

      -- Ignore leading spaces and zeros in i_door_no but if all zeroes then
      -- use '0' as the value.

      IF (i_door_no IS NULL) THEN
         l_door_no := NULL;    -- Nothing to search for if parameter is null
      ELSE
         l_tmp_door_no := LTRIM(RTRIM(i_door_no));   -- Trim spaces

         IF (REPLACE(l_tmp_door_no, '0') IS NULL) THEN
            l_tmp_door_no := '0';  -- Door all zeroes.
         ELSE
            l_tmp_door_no := LTRIM(l_tmp_door_no,'0');
         END IF;

         OPEN c_door_no(l_tmp_door_no);
         FETCH c_door_no INTO l_door_no;
         IF (c_door_no%NOTFOUND) THEN
            l_door_no := NULL;
         END IF;
         CLOSE c_door_no;

      END IF;

      RETURN(l_door_no);

   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, l_object_name ||
            'i_door_no[' || i_door_no || '] Error: ' || SQLERRM);
   END f_get_fk_door_no;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_valid_fk_door_no
   --
   -- Description:
   --    This function determines if a door number is a valid forklift
   --    labor mgmt door number.  The door number is valid if it is setup
   --    as a door to aisle distance in the point distance table. 
   --
   -- Parameters:
   --    i_door_no   -  Door number to validate.
   --  
   -- Return Value:
   --    TRUE   - The door number is a valid forklift labor mgmt door number.
   --    FALSE  - The door number is not a valid forklift labor mgmt door
   --             number.
   --
   -- Exceptions raised:
   --    -20001  An oracle error occurred.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    06/21/01 prpbcb   Created.
   --  
   ---------------------------------------------------------------------------
   FUNCTION f_valid_fk_door_no(i_door_no IN VARCHAR2)
   RETURN BOOLEAN IS
      l_door_no      point_distance.point_a%TYPE; -- Work area
      l_object_name  VARCHAR2(30) := 'f_valid_fk_door_no';
      l_valid_door   BOOLEAN;                  -- Designates if door is valid.

      CURSOR c_door_no IS
         SELECT point_a
           FROM point_distance
          WHERE point_type = 'DA'
            AND point_a = i_door_no;
   BEGIN
      OPEN c_door_no;
      FETCH c_door_no INTO l_door_no;

      IF (c_door_no%FOUND) THEN
         l_valid_door := TRUE;
      ELSE
         l_valid_door := FALSE;
      END IF;

      CLOSE c_door_no;

      RETURN(l_valid_door);

   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, l_object_name ||
            'i_door_no['|| i_door_no || '] Error: ' || SQLERRM);
   END f_valid_fk_door_no;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_putaway_batches
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batches for putaway
   --   tasks.  Procedure create_normal_putaway_batches is called to create
   --   the batches for non-MSKU pallets then procedure
   --   create_msku_putaway_batches is called to create the batches for MSKU
   --   pallets.
   --
   -- Parameters:
   --    i_create_for_what      - Designates what to create the batches for.
   --                             The valid values are:
   --                                - LP    for a license plate
   --                                - PO    for a PO
   --                             The value will be converted to upper case by 
   --                             this procedure.
   --    i_key_value            - Pallet id if i_create_for_what is 'LP'.
   --                           - PO # if i_create_for_what is 'PO'.
   --    i_dest_loc             - The destination location when creating a
   --                             batch for a single license plate.  This is
   --                             optional but is required when form rp1sc
   --                             calls this procedure.  In form rp1sc the
   --                             batch is created when a destination
   --                             location is keyed over a '*' or the qty
   --                             received is changed from 0 to > 0.  Because
   --                             of when the form calls this procedure
   --                             the putawaylst records does not yet have
   --                             the dest_loc updated so it needs to be passed
   --                             in.  If this is null then a valid destination
   --                             location will need to exist in the putawaylst
   --                             table in for order for the batch to be
   --                             created since the cursor in this procedure
   --                             will only look at putawaylst records with
   --                             dest_loc != '*'.
   --    o_no_records_processed - Number of records processed.  If 0 then this
   --                             indicates the key value is not in the
   --                             putawaylst table or all the destination
   --                             locations are '*' or forklift labor mgmt
   --                             is not active.
   --                             This should equal the # of batches created +
   --                             # of batches existing + # of batches not
   --                             created.  
   --    o_no_batches_created   - Number of batches successfully created.
   --    o_no_batches_existing  - Number of batches that already exist.
   --    o_no_not_created_due_to_error - Number of batches not created.  This
   --                                    could be due to a data setup issue or
   --                                    an oracle error.  A message is logged
   --                                    to the log table for each batch not
   --                                    created.  Duplicates not logged since
   --                                    this procedure could be run multiple
   --                                    times for the same data.
   --
   -- Called by: (list may not be complete)
   --    - create_putaway_batch_for_lp
   --    - create_putaway_batches_for_po
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null or an unhandled value
   --                               for a parameter or a bad combination
   --                               of parameters.
   --    pl_exe.e_putawaylst_update_fail - No rows updated when updating the
   --                                      putawaylst.pallet_batch_no with the
   --                                      batch number.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/29/03 prpbcb   Created.
   --    09/29/03 prpbcb   MSKU changes.
   --
   ---------------------------------------------------------------------------
   PROCEDURE create_putaway_batches
         (i_create_for_what              IN  VARCHAR2,
          i_key_value                    IN  VARCHAR2,
          i_dest_loc                     IN  putawaylst.dest_loc%TYPE := NULL,
          o_no_records_processed         OUT PLS_INTEGER,
          o_no_batches_created           OUT PLS_INTEGER,
          o_no_batches_existing          OUT PLS_INTEGER,
          o_no_not_created_due_to_error  OUT PLS_INTEGER)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_putaway_batches';

      l_batch_no                arch_batch.batch_no%TYPE;
      l_create_for_what         VARCHAR2(20);   -- Populated from
                                                -- i_create_for_what.

      l_no_records_processed    PLS_INTEGER; -- # of putaway tasks processed
      l_no_batches_created      PLS_INTEGER; -- # of batches created
      l_no_batches_existing     PLS_INTEGER; -- # of batches alreay existing
      l_no_not_created_due_to_error  PLS_INTEGER; -- # of batches failed
                                                     -- to create
      l_no_with_no_location     PLS_INTEGER; -- # of batches not created 
                                                -- because putaway task has
                                                -- '*' location.

      l_r_create_putaway_stats  t_create_putaway_stats_rec; -- Non NSKU batch
                                                        -- creation statistics.
      l_r_create_putaway_stats_msku  t_create_putaway_stats_rec; -- MSKU Batch
                                                        -- creation statistics.
      l_temp_no                 NUMBER;         -- Work area

      e_bad_create_for_what   EXCEPTION;  -- Bad value in i_bad_create_for_what
      e_batch_already_exists  EXCEPTION;  -- Putaway batch already exists.
      e_parameter_bad_combination    EXCEPTION;  -- Bad combination of
                                                 -- parameters.

   BEGIN
      -- Initialize the out batch counts.
      o_no_records_processed := 0;
      o_no_batches_created  := 0;
      o_no_batches_existing := 0;
      o_no_not_created_due_to_error := 0;

      -- Forklift labor mgmt needs to be active.
      IF (f_forklift_active = TRUE) THEN

         -- Check for null parameters.
         IF (i_create_for_what IS NULL OR i_key_value IS NULL) THEN
            RAISE gl_e_parameter_null;
         END IF;

         l_create_for_what := UPPER(i_create_for_what);
         IF (l_create_for_what NOT IN ('LP', 'PO')) THEN
            RAISE e_bad_create_for_what;
         END IF;

         -- Check for bad combination of parameters.
         IF (i_create_for_what != 'LP' AND i_dest_loc IS NOT NULL) THEN
            -- i_dest_loc should only have a value if creating a batch for
            -- a single license plate.
            RAISE e_parameter_bad_combination;
         END IF;

         -- Create the putaway batches for non-MSKU pallets.
         create_normal_putaway_batches
                   (i_create_for_what        => i_create_for_what,
                    i_key_value              => i_key_value,
                    i_dest_loc               => i_dest_loc,
                    o_r_create_putaway_stats => l_r_create_putaway_stats);

         -- Create the putaway batches for MSKU pallets.
         create_msku_putaway_batches
                   (i_create_for_what        => i_create_for_what,
                    i_key_value              => i_key_value,
                    i_dest_loc               => i_dest_loc,
                    o_r_create_putaway_stats => l_r_create_putaway_stats_msku);

         l_no_records_processed :=
                  l_r_create_putaway_stats.no_records_processed +
                  l_r_create_putaway_stats_msku.no_records_processed;
         l_no_batches_created :=
                  l_r_create_putaway_stats.no_batches_created +
                  l_r_create_putaway_stats_msku.no_batches_created;
         l_no_batches_existing :=
                  l_r_create_putaway_stats.no_batches_existing +
                  l_r_create_putaway_stats_msku.no_batches_existing;
         l_no_not_created_due_to_error :=
                  l_r_create_putaway_stats.no_not_created_due_to_error +
                  l_r_create_putaway_stats_msku.no_not_created_due_to_error;
         l_no_with_no_location :=
                  l_r_create_putaway_stats.no_with_no_location +
                  l_r_create_putaway_stats_msku.no_with_no_location;

         l_message :=
             'Created putaway forklift labor mgmt batches for[' ||
             i_create_for_what || '],' ||
             ' key value[' || i_key_value || '],' ||
             ' dest loc[' || i_dest_loc || '](applies when creating batch' ||
             ' for a LP),' ||
     '  #records processed[' || TO_CHAR(l_no_records_processed) || ']' ||
     '  #batches created[' || TO_CHAR(l_no_batches_created) || ']' ||
     '  #batches already existing[' || TO_CHAR(l_no_batches_existing) || ']' ||
     '  #error creating batch[' || TO_CHAR(l_no_not_created_due_to_error) || ']' ||
     '  #tasks with no location[' || TO_CHAR(l_no_with_no_location) || ']';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         o_no_records_processed   := l_no_records_processed;
         o_no_batches_created     := l_no_batches_created;
         o_no_batches_existing    := l_no_batches_existing;
         o_no_not_created_due_to_error := l_no_not_created_due_to_error;
      ELSE
         -- Forklift labor mgmt is not active.
         l_message := 
             'Create putaway forklift labor mgmt batches for[' ||
             i_create_for_what || '],' ||
             ' key value[' || i_key_value || '],' ||
             ' dest loc[' || i_dest_loc || '](applies when creating batch' ||
             ' for a LP).  Batches not created because forklift labor' ||
             ' management is not active.';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

      END IF;  -- end is forklift active.

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_create_for_what[' ||
            i_create_for_what || ']  or i_key_value[' || i_key_value || ']' ||
            ' is null';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_bad_create_for_what THEN
         l_message := l_object_name || ': Bad value in i_create_for_what[' ||
            i_create_for_what || '].  Value values are LP or PO.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_parameter_bad_combination THEN
         -- i_dest_loc should only have a value if creating a batch for
         -- a single license plate.
         l_message := l_object_name ||
             '(i_create_for_what[' || i_create_for_what || '],' ||
             ' i_key_value[' || i_key_value || '],' ||
             ' i_dest_loc[' || i_dest_loc || '],' ||
             'o_no_records_processed,o_no_batches_created,' ||
             'o_no_batches_existing,o_no_not_created_due_to_error)'  ||
             ' i_dest_loc can only have a value when i_create_for_what is LP';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name ||
             '(i_create_for_what[' || i_create_for_what || '],' ||
             ' i_key_value[' || i_key_value || '],' ||
             ' i_dest_loc[' || i_dest_loc || '],' ||
             'o_no_records_processed,o_no_batches_created,' ||
             'o_no_batches_existing,o_no_not_created_due_to_error)';

         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END create_putaway_batches;

------------------------------------------------------------------------------
-- m.c.

   PROCEDURE create_dci_batches
         (i_create_for_what              IN  VARCHAR2,
          i_key_value                    IN  VARCHAR2,
          i_dest_loc                     IN  putawaylst.dest_loc%TYPE := NULL,
          o_no_records_processed         OUT PLS_INTEGER,
          o_no_batches_created           OUT PLS_INTEGER,
          o_no_batches_existing          OUT PLS_INTEGER,
          o_no_not_created_due_to_error  OUT PLS_INTEGER)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_dci_batches';

      l_batch_no                arch_batch.batch_no%TYPE;
      l_create_for_what         VARCHAR2(20);   -- Populated from
                                                -- i_create_for_what.

      l_no_records_processed    PLS_INTEGER; -- # of putaway tasks processed
      l_no_batches_created      PLS_INTEGER; -- # of batches created
      l_no_batches_existing     PLS_INTEGER; -- # of batches alreay existing
      l_no_not_created_due_to_error  PLS_INTEGER; -- # of batches failed
                                                     -- to create
      l_no_with_no_location     PLS_INTEGER; -- # of batches not created 
                                                -- because putaway task has
                                                -- '*' location.

      l_r_create_putaway_stats  t_create_putaway_stats_rec; -- Non NSKU batch
                                                        -- creation statistics.
      l_r_create_putaway_stats_msku  t_create_putaway_stats_rec; -- MSKU Batch
                                                        -- creation statistics.
      l_temp_no                 NUMBER;         -- Work area

      e_bad_create_for_what   EXCEPTION;  -- Bad value in i_bad_create_for_what
      e_batch_already_exists  EXCEPTION;  -- Putaway batch already exists.
      e_parameter_bad_combination    EXCEPTION;  -- Bad combination of
                                                 -- parameters.

   BEGIN
      -- Initialize the out batch counts.
      o_no_records_processed := 0;
      o_no_batches_created  := 0;
      o_no_batches_existing := 0;
      o_no_not_created_due_to_error := 0;

      -- Forklift labor mgmt needs to be active.
      --IF (f_is_dci_putaway_active = TRUE) THEN

      IF (f_is_dci_putaway_active = 'Y') THEN

         -- Check for null parameters.
         IF (i_create_for_what IS NULL OR i_key_value IS NULL) THEN
            RAISE gl_e_parameter_null;
         END IF;

         l_create_for_what := UPPER(i_create_for_what);
         IF (l_create_for_what NOT IN ('LP', 'CM')) THEN
            RAISE e_bad_create_for_what;
         END IF;
         


         -- Check for bad combination of parameters.
         IF (i_create_for_what != 'LP' AND i_dest_loc IS NOT NULL) THEN
            -- i_dest_loc should only have a value if creating a batch for
            -- a single license plate.
            RAISE e_parameter_bad_combination;
         END IF;

         /* Create the putaway batches for non-MSKU pallets.
         create_normal_putaway_batches
                   (i_create_for_what        => i_create_for_what,
                    i_key_value              => i_key_value,
                    i_dest_loc               => i_dest_loc,
                    o_r_create_putaway_stats => l_r_create_putaway_stats);
         */           

         -- m.c. Create the putaway batches for return putaway.
         create_dci_putaway_batches
                   (i_create_for_what        => i_create_for_what,
                    i_key_value              => i_key_value,
                    i_dest_loc               => i_dest_loc,
                    o_r_create_putaway_stats => l_r_create_putaway_stats);                    

         /* Create the putaway batches for MSKU pallets.
         create_msku_putaway_batches
                   (i_create_for_what        => i_create_for_what,
                    i_key_value              => i_key_value,
                    i_dest_loc               => i_dest_loc,
                    o_r_create_putaway_stats => l_r_create_putaway_stats_msku);
          */          

         l_no_records_processed :=
                  l_r_create_putaway_stats.no_records_processed +
                  l_r_create_putaway_stats_msku.no_records_processed;
         l_no_batches_created :=
                  l_r_create_putaway_stats.no_batches_created +
                  l_r_create_putaway_stats_msku.no_batches_created;
         l_no_batches_existing :=
                  l_r_create_putaway_stats.no_batches_existing +
                  l_r_create_putaway_stats_msku.no_batches_existing;
         l_no_not_created_due_to_error :=
                  l_r_create_putaway_stats.no_not_created_due_to_error +
                  l_r_create_putaway_stats_msku.no_not_created_due_to_error;
         l_no_with_no_location :=
                  l_r_create_putaway_stats.no_with_no_location +
                  l_r_create_putaway_stats_msku.no_with_no_location;

         l_message :=
             'Created dci labor mgmt batches for[' ||
             i_create_for_what || '],' ||
             ' key value[' || i_key_value || '],' ||
             ' dest loc[' || i_dest_loc || '](applies when creating batch' ||
             ' for a LP),' ||
     '  #records processed[' || TO_CHAR(l_no_records_processed) || ']' ||
     '  #batches created[' || TO_CHAR(l_no_batches_created) || ']' ||
     '  #batches already existing[' || TO_CHAR(l_no_batches_existing) || ']' ||
     '  #error creating batch[' || TO_CHAR(l_no_not_created_due_to_error) || ']' ||
     '  #tasks with no location[' || TO_CHAR(l_no_with_no_location) || ']';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         o_no_records_processed   := l_no_records_processed;
         o_no_batches_created     := l_no_batches_created;
         o_no_batches_existing    := l_no_batches_existing;
         o_no_not_created_due_to_error := l_no_not_created_due_to_error;
      ELSE
         -- Forklift labor mgmt is not active.
         l_message := 
             'Create dci labor mgmt batches for[' ||
             i_create_for_what || '],' ||
             ' key value[' || i_key_value || '],' ||
             ' dest loc[' || i_dest_loc || '](applies when creating batch' ||
             ' for a LP).  Batches not created because dci labor' ||
             ' management is not active.';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

      END IF;  -- end is forklift active.

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_create_for_what[' ||
            i_create_for_what || ']  or i_key_value[' || i_key_value || ']' ||
            ' is null';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_bad_create_for_what THEN
         l_message := l_object_name || ': Bad value in i_create_for_what[' ||
            i_create_for_what || '].  Value values are LP or CM.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_parameter_bad_combination THEN
         -- i_dest_loc should only have a value if creating a batch for
         -- a single license plate.
         l_message := l_object_name ||
             '(i_create_for_what[' || i_create_for_what || '],' ||
             ' i_key_value[' || i_key_value || '],' ||
             ' i_dest_loc[' || i_dest_loc || '],' ||
             'o_no_records_processed,o_no_batches_created,' ||
             'o_no_batches_existing,o_no_not_created_due_to_error)'  ||
             ' i_dest_loc can only have a value when i_create_for_what is LP';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name ||
             '(i_create_for_what[' || i_create_for_what || '],' ||
             ' i_key_value[' || i_key_value || '],' ||
             ' i_dest_loc[' || i_dest_loc || '],' ||
             'o_no_records_processed,o_no_batches_created,' ||
             'o_no_batches_existing,o_no_not_created_due_to_error)';

         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END create_dci_batches;

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_nondemand_rpl_batch  (overloaded)
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt non-demand
   --    replenishment batch from the task id.
   --
   --    *******************************************************************
   --    This is the main procedure.  It creates the labor mgmt batch.
   --    The other create_nondemand_rpl_batch() procedures call this.
   --    *******************************************************************
   --
   -- Parameters:
   --    i_task_id              - Task id of the NDM.
   --    o_batch_no             - The labor batch number created.
   --    o_no_records_processed - Number of records processed.
   --                             Will be 0 or 1.
   --    o_no_batches_created   - Number of batches successfully created.
   --                             Will be 0 or 1.
   --    o_no_batches_existing  - Number of batches that already exist.
   --                             Will be 0 or 1.
   --    o_no_not_created_due_to_error - Number of batches not created.  This
   --                                    could be due to a data setup issue or
   --                                    an oracle error.  A message is logged
   --                                    to the log table for each batch not
   --                                    created.  Duplicates not logged since
   --                                    this procedure could be run multiple
   --                                    times for the same data.
   --                             Will be 0 or 1.
   --
   -- Called by:  (list may not be complete)
   --    - form pn1sa.fmb
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error         - Parameter is null.
   --    pl_exc.e_database_error     - Got an oracle error.
   --    pl_exc.e_lm_batch_upd_fail  - Failed to create the batch.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    12/10/03 prpbcb   Created.
   --    03/01/06 prpbcb   Changed to also look at repl type MNL.
   --    04/21/10 prpbcb   Added parameter o_batch_no.
   --                      Select for update to lock the replenlst record.
   --                      The
   --    09/15/14 ayad5195 Added matrix replenishment types in cursor query 
   ---------------------------------------------------------------------------
   PROCEDURE create_nondemand_rpl_batch
                (i_task_id                      IN  replenlst.task_id%TYPE,
                 o_batch_no                     OUT arch_batch.batch_no%TYPE,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_nondemand_rpl_batch';

      e_no_batch_info  EXCEPTION;  -- Raised when we do not have the records
                                   --  used in creating the batch.

      e_record_locked  EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_record_locked, -54);
      l_dummy           NUMBER := 0;

      --
      -- This cursor gathers the info used in creating the labor batch.
      --
      CURSOR c_batch_info IS
            SELECT -- Build the labor batch number.  Miniloader priority
                   -- 12 or 15 will be FR batches (demand replenishments).
                   -- Anything else will be FN batches (non-demand).
                   DECODE(r.type,
                          'MNL', DECODE(r.priority,
                                        12, 'FR',
                                        15, 'FR',
                                        'FN'),
                          'FN')  ||  TRIM(TO_CHAR(r.task_id))   batch_no,
                   ----------------------------------------------------------
                   -- Get the job code.  Miniloader priority
                   -- 12 or 15 will use the demand replenishment job code.
                   -- Anything else will use non-demand replenishment job code.
                   DECODE(r.type,
                          'MNL', DECODE(r.priority,
                                        12, fk.dmdrpl_jobcode,
                                        15, fk.dmdrpl_jobcode,
                                        fk.ndrpl_jobcode),
                          fk.ndrpl_jobcode)    jbcd_job_code,
                   ----------------------------------------------------------
                   'F'            status,
                   TRUNC(SYSDATE) batch_date,
                   r.src_loc      kvi_from_loc,
                   r.dest_loc     kvi_to_loc,
                   0              kvi_no_case,
                   0              kvi_no_split,
                   1              kvi_no_pallet,
                   1              kvi_no_item,
                   0              kvi_no_po,
                   --
                   -- For miniloader replenishments the qty is in splits if
                   -- the uom is 1 otherwise the qty is in cases.  Account for
                   -- this in calculating the kvi_cube and kvi_wt.
                   -- For non-miniloader replenishments the qty is always a
                   -- split qty.
                   --
                   DECODE(r.type,
                          'MNL', DECODE(r.uom, 1, r.qty / pm.spc,
                                               r.qty),
                          r.qty / pm.spc) * pm.case_cube       kvi_cube,
                   --
                   -- pm.g_weight is the weight of 1 split.
                   DECODE(r.type,
                          'MNL', DECODE(r.uom, 1, r.qty,
                                               r.qty * pm.spc),
                          r.qty) * NVL(pm.g_weight, 0)         kvi_wt,
                   --
                   1              kvi_no_loc,
                   1              total_count,
                   0              total_piece,
                   1              total_pallet,
                   r.pallet_id    ref_no,
                   0              kvi_distance,
                   0              goal_time,
                   0              target_time, 
                   0              no_breaks,
                   0              no_lunches,
                   1              kvi_doc_time,
                   0              kvi_no_piece,
                   2              kvi_no_data_capture,
                   DECODE(r.parent_pallet_id,
                          NULL, NULL,
                          'Y')    msku_batch_flag,
                   'TYPE[' || r.type || ']'
                      || DECODE(r.type, 'MNL', ' MINILOAD REPLENISHMENT', NULL)
                      ||  ' PRIORITY[' || TRIM(TO_CHAR(r.priority)) || ']' cmt
              FROM job_code j,
                   fk_area_jobcodes fk,
                   swms_sub_areas ssa,
                   aisle_info ai,
                   pm,
                   replenlst r
             WHERE j.jbcd_job_code     = fk.ndrpl_jobcode
               AND fk.sub_area_code    = ssa.sub_area_code
               AND ssa.sub_area_code   = ai.sub_area_code
               AND ai.name             = SUBSTR(r.dest_loc, 1, 2)
               AND pm.prod_id          = r.prod_id
               AND pm.cust_pref_vendor = r.cust_pref_vendor
               AND r.type              IN ('NDM', 'MNL', 'MXL', 'NXL', 'NSP', 'MRL', 'UNA')   --Matrix Changes
               AND r.task_id           = i_task_id
               FOR UPDATE OF r.labor_batch_no NOWAIT;

      r_batch_info  c_batch_info%ROWTYPE;

   BEGIN
      -- Initialize
      o_batch_no                    := NULL;
      o_no_records_processed        := 0;
      o_no_batches_created          := 0;
      o_no_batches_existing         := 0;
      o_no_not_created_due_to_error := 0;

      -- Forklift labor mgmt needs to be active.
      IF (f_forklift_active = TRUE) THEN

         -- Check for null parameters.
         IF (i_task_id IS NULL) THEN
            RAISE gl_e_parameter_null;
         END IF;

         -- Create the non-demand replenishment labor mgmt batch.

         o_no_records_processed := o_no_records_processed + 1;

         -- Start a new block to use in trapping errors.
         BEGIN
            OPEN c_batch_info;
            FETCH c_batch_info INTO r_batch_info;

            --
            -- Verify we have the info to create the batch.
            --
            IF (c_batch_info%FOUND) THEN
               NULL;
            ELSE
               CLOSE c_batch_info;
               RAISE e_no_batch_info;
            END IF;

            -- SMOD-8402 - check if batch_no already exists. 
            -- batch_no, batch_date is the primary key. This cause issues when NDM tasks commited twice on seperate days.
            SELECT COUNT(BATCH_NO) 
            INTO l_dummy
            FROM BATCH
            WHERE BATCH_NO = r_batch_info.batch_no;

            IF (l_dummy > 0) THEN
               RAISE DUP_VAL_ON_INDEX;
            END IF;

            CLOSE c_batch_info;

            -- Insert the batch.
            INSERT INTO batch(batch_no,
                              jbcd_job_code,
                              status,
                              batch_date,
                              kvi_from_loc,
                              kvi_to_loc,
                              kvi_no_case,
                              kvi_no_split,
                              kvi_no_pallet,
                              kvi_no_item,
                              kvi_no_po,
                              kvi_cube,
                              kvi_wt,
                              kvi_no_loc,
                              total_count,
                              total_piece,
                              total_pallet,
                              ref_no,
                              kvi_distance, 
                              goal_time,
                              target_time,
                              no_breaks,
                              no_lunches,
                              kvi_doc_time,
                              kvi_no_piece,
                              kvi_no_data_capture,
                              msku_batch_flag,
                              cmt)
            VALUES
                             (r_batch_info.batch_no,
                              r_batch_info.jbcd_job_code,
                              r_batch_info.status,
                              r_batch_info.batch_date,
                              r_batch_info.kvi_from_loc,
                              r_batch_info.kvi_to_loc,
                              r_batch_info.kvi_no_case,
                              r_batch_info.kvi_no_split,
                              r_batch_info.kvi_no_pallet,
                              r_batch_info.kvi_no_item,
                              r_batch_info.kvi_no_po,
                              r_batch_info.kvi_cube,
                              r_batch_info.kvi_wt,
                              r_batch_info.kvi_no_loc,
                              r_batch_info.total_count,
                              r_batch_info.total_piece,
                              r_batch_info.total_pallet,
                              r_batch_info.ref_no,
                              r_batch_info.kvi_distance, 
                              r_batch_info.goal_time,
                              r_batch_info.target_time,
                              r_batch_info.no_breaks,
                              r_batch_info.no_lunches,
                              r_batch_info.kvi_doc_time,
                              r_batch_info.kvi_no_piece,
                              r_batch_info.kvi_no_data_capture,
                              r_batch_info.msku_batch_flag,
                              r_batch_info.cmt)
            RETURNING batch_no INTO o_batch_no;

           pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
               'INSERTED RECORD INTO BATCH TABLE.'
               || '  i_task_id[' || TRIM(TO_CHAR(i_task_id)) || ']'
               || '  o_batch_no[' || o_batch_no || ']',
               NULL, NULL,
               pl_rcv_open_po_types.ct_application_function,
               gl_pkg_name);

            --
            -- If this point reached then the labor batch was created.
            --
            o_no_batches_created := 1;

            --
            -- Update the replenishment record with the labor batch number.
            --
            UPDATE replenlst
               SET labor_batch_no = o_batch_no
             WHERE task_id = i_task_id;

            IF (SQL%NOTFOUND) THEN
               l_message := 'TABLE=replenlst  ACTION=UPDATE'
                     || '  KEY=[' || TO_CHAR(i_task_id) || '](i_task_id)'
                     || '  MESSAGE="Failed to update the record with the'
                     || ' labor batch[' || o_batch_no || '].'
                     || '  This will not stop processing'
                     || ' but will cause an issue when attempting to do'
                     || ' the replenishment."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                              l_message, pl_exc.ct_lm_batch_upd_fail, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);
            END IF;

         EXCEPTION
            WHEN e_record_locked THEN
               --
               -- The REPLENLST record is lcoked by someone else
               -- so the batch will not be created.
               -- Write a log message but do not stop processing.
               --
               o_no_not_created_due_to_error := 1;

               l_message := 'TABLE=replenlst  ACTION=SELECT'
                  || '  i_task_id[' || TO_CHAR(i_task_id) || ']'
                  || '  JOIN TABLES=job_code,fk_area_jobcodes,'
                  || 'swms_sub_areas,aisle_info,pm,replenlst'
                  || '  MESSAGE="The REPLENLST record is locked by someone else.'
                  || '  The forklift labor batch will not be created.';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                              l_message, pl_exc.ct_lm_batch_upd_fail, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

            WHEN e_no_batch_info THEN

               --
               -- Did not find the records to create the batch from.
               -- Write a log message but do not stop processing.
               --
               o_no_not_created_due_to_error := 1;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                     '  i_task_id[' || TO_CHAR(i_task_id) || ']' ||
                     '  JOIN TABLES=job_code,fk_area_jobcodes,' ||
                     'swms_sub_areas,aisle_info,pm,replenlst' ||
                     '  MESSAGE="NDM forklift labor batch not created. No' ||
                     ' record selected to insert into batch table. ' ||
                     '  Could be a data setup issue."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                              l_message, pl_exc.ct_lm_batch_upd_fail, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

            WHEN DUP_VAL_ON_INDEX THEN
               -- The batch already exists.  This is OK because this
               -- procedure could have been run again for the same data.
               o_no_batches_existing := o_no_batches_existing + 1;

            WHEN OTHERS THEN
               -- Got some kind of oracle error.  Log the error then
               -- continue processing.
               o_no_not_created_due_to_error :=
                                   o_no_not_created_due_to_error + 1;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                     '  i_task_id[' || TO_CHAR(i_task_id) || ']' ||
                     '  JOIN TABLES=job_code,fk_area_jobcodes,' ||
                     'swms_sub_areas,aisle_info,pm,replenlst' ||
                     '  MESSAGE="NDM forklift labor batch not created."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                              SQLCODE, SQLERRM,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

         END;  -- end of block

      END IF;  -- is forklift active

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_task_id)' ||
                      '  Parameter is null.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name
               || '(i_task_id[' || TO_CHAR(i_task_id) || ']'
               || ',o_batch_no,o_no_records_processed,o_no_batches_created'
               || ',o_no_batches_existing,o_no_not_created_due_to_error)';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);

   END create_nondemand_rpl_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_nondemand_rpl_batch  (overloaded)
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt non-demand
   --    replenishment batch from the task id.  
   --
   -- Parameters:
   --    i_task_id              - Task id of the NDM.
   --    o_no_records_processed - Number of records processed.
   --                             Will be 0 or 1.
   --    o_no_batches_created   - Number of batches successfully created.
   --                             Will be 0 or 1.
   --    o_no_batches_existing  - Number of batches that already exist.
   --                             Will be 0 or 1.
   --    o_no_not_created_due_to_error - Number of batches not created.  This
   --                                    could be due to a data setup issue or
   --                                    an oracle error.  A message is logged
   --                                    to the log table for each batch not
   --                                    created.  Duplicates not logged since
   --                                    this procedure could be run multiple
   --                                    times for the same data.
   --                             Will be 0 or 1.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    Exceptions are passed through using whatever procedure
   --    create_nondemand_rpl_batch() raised.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/01/06 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE create_nondemand_rpl_batch
                (i_task_id                      IN  replenlst.task_id%TYPE,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_nondemand_rpl_batch';

      l_batch_no    arch_batch.batch_no%TYPE;  -- A place to hold batch number
                                               -- created.

   BEGIN
      create_nondemand_rpl_batch(i_task_id,
                                 l_batch_no,
                                 o_no_records_processed,
                                 o_no_batches_created,
                                 o_no_batches_existing,
                                 o_no_not_created_due_to_error);
   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name
               || '(i_task_id[' || TO_CHAR(i_task_id) || ']'
               || ',o_no_records_processed,o_no_batches_created'
               || ',o_no_batches_existing,o_no_not_created_due_to_error)';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
         RAISE;

   END create_nondemand_rpl_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_nondemand_rpl_batch  (overloaded)
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt non-demand
   --    replenishment batch from the task id.  
   --
   -- Parameters:
   --    i_task_id              - Task id of the NDM.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    Exceptions are passed through using whatever procedure
   --    create_nondemand_rpl_batch() raised.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/01/06 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE create_nondemand_rpl_batch(i_task_id  IN  replenlst.task_id%TYPE)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_nondemand_rpl_batch';

      l_batch_no                     arch_batch.batch_no%TYPE;
      l_no_records_processed         PLS_INTEGER;
      l_no_batches_created           PLS_INTEGER;
      l_no_batches_existing          PLS_INTEGER;
      l_no_not_created_due_to_error  PLS_INTEGER;
   BEGIN
      create_nondemand_rpl_batch(i_task_id,
                                 l_batch_no,
                                 l_no_records_processed,
                                 l_no_batches_created,
                                 l_no_batches_existing,
                                 l_no_not_created_due_to_error);
   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name
                      || '(i_task_id[' || TO_CHAR(i_task_id) || '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
         RAISE;

   END create_nondemand_rpl_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_nondemand_rpl_batch  (overloaded)
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt non-demand
   --    replenishment batch from the task id.  
   --
   -- Parameters:
   --    i_task_id              - Task id of the NDM.
   --    o_batch_no             - The labor batch number created.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    Exceptions are passed through using whatever procedure
   --    create_nondemand_rpl_batch() raised.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/01/06 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE create_nondemand_rpl_batch
                (i_task_id       IN  replenlst.task_id%TYPE,
                 o_batch_no      OUT arch_batch.batch_no%TYPE)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_nondemand_rpl_batch';

      l_batch_no                     arch_batch.batch_no%TYPE;
      l_no_records_processed         PLS_INTEGER;
      l_no_batches_created           PLS_INTEGER;
      l_no_batches_existing          PLS_INTEGER;
      l_no_not_created_due_to_error  PLS_INTEGER;
   BEGIN
      create_nondemand_rpl_batch(i_task_id,
                                 o_batch_no,
                                 l_no_records_processed,
                                 l_no_batches_created,
                                 l_no_batches_existing,
                                 l_no_not_created_due_to_error);
   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name
              || '(i_task_id[' || TO_CHAR(i_task_id) || '],o_batch_no)';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
         RAISE;

   END create_nondemand_rpl_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_all_ndm_rpl_batch 
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt non-demand
   --    replenishment batch for all the committed tasks on pn1sa.
   --
   -- Parameters:
   --    o_no_records_processed - Number of records processed.
   --    o_no_batches_created   - Number of batches successfully created.
   --    o_no_batches_existing  - Number of batches that already exist.
   --    o_no_not_created_due_to_error - Number of batches not created.  This
   --                                    could be due to a data setup issue or
   --                                    an oracle error.  A message is logged
   --                                    to the log table for each batch not
   --                                    created.  Duplicates not logged since
   --                                    this procedure could be run multiple
   --                                    times for the same data.
   --
   -- Called by:  pn1sa (form)
   --
   -- Exceptions raised:
   --    Exceptions are passed through using whatever procedure
   --    create_nondemand_rpl_batch() raised.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    12/08/10 prppxx   Created.
   --    01/19/10 prbcb000 Changed the select in the FOR loop statement to only
   --                      select replenishment tasks where there is not a
   --                      labor batch for the task.
   --                      Changed
   --                         FOR rec IN (SELECT task_id
   --                                       FROM replenlst
   --                                      WHERE type = 'NDM'
   --                                        AND labor_batch_no IS NULL)
   --                      to
   -- FOR rec IN
   --    (SELECT r.task_id
   --      FROM replenlst r
   --     WHERE r.type = 'NDM'
   --       AND NOT EXISTS
   --           (SELECT 'x'
   --              FROM batch b
   --             WHERE b.batch_no =
   --            pl_lmc.ct_forklift_nondemand_rpl || TRIM(TO_CHAR(r.task_id))))
   --
   --                      Added getting the count of the existing labor
   --                      batches so we can put a valid value in
   --                      o_no_batches_existing.
   ---------------------------------------------------------------------------
   PROCEDURE create_all_ndm_rpl_batch
                (o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_all_ndm_rpl_batch';

      l_no_records_processed         PLS_INTEGER;
      l_no_batches_created           PLS_INTEGER;
      l_no_batches_existing          PLS_INTEGER;
      l_no_not_created_due_to_error  PLS_INTEGER;
      l_task_id                      replenlst.task_id%TYPE;  -- Used in
                                                       -- error messages.

   BEGIN
      --
      -- Initialization.
      --
      o_no_records_processed         := 0;
      o_no_batches_created           := 0;
      o_no_batches_existing          := 0;
      o_no_not_created_due_to_error  := 0;

      --
      -- Get count of existing NDM labor batches.
      -- Start a new block to trap errors.   We will continue processing
      -- even if the count fails.
      --
      BEGIN
         SELECT COUNT(*) INTO o_no_batches_existing
           FROM replenlst r, batch b
           WHERE b.batch_no =
                 pl_lmc.ct_forklift_nondemand_rpl || TRIM(TO_CHAR(r.task_id))
             AND r.type = 'NDM';
      EXCEPTION
         WHEN OTHERS THEN
            l_message := 'TABLE=replenlst,batch  ACTION=SELECT'
                 || '  KEY=[NDM]'
                 || '  MESSAGE="Error selecting count of existing NDM labor'
                 || ' batches.  This will not stop processing."';

            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                              SQLCODE, SQLERRM, ct_application_function,
                              gl_pkg_name);
      END;

      --
      -- Create NDM labor batches that do not exist.
      --
      FOR rec IN
         (SELECT r.task_id
           FROM replenlst r
          WHERE r.type = 'NDM'
            AND NOT EXISTS
                (SELECT 'x'
                   FROM batch b
                  WHERE b.batch_no =
                 pl_lmc.ct_forklift_nondemand_rpl || TRIM(TO_CHAR(r.task_id))))
      LOOP
         l_task_id := rec.task_id;  -- Save to display in case of error.

         --
         -- Craete the labor batch for the NDM replenishment task.
         --
         pl_lmf.create_nondemand_rpl_batch
            (rec.task_id,
             l_no_records_processed,
             l_no_batches_created,
             l_no_batches_existing,
             l_no_not_created_due_to_error);

             o_no_records_processed := o_no_records_processed +
                                       l_no_records_processed;

             o_no_batches_created := o_no_batches_created +
                                     l_no_batches_created;

             o_no_batches_existing := o_no_batches_existing +
                                      l_no_batches_existing;

             o_no_not_created_due_to_error := o_no_not_created_due_to_error +
                                              l_no_not_created_due_to_error;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name
              || '(task_id[' || TO_CHAR(l_task_id) || '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE;

   END create_all_ndm_rpl_batch;

   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_ml_rpl_batch  (overloaded)
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt batch for a miniloader
   --    replenishment using the task id.   The priority determines if a
   --    FN (non-demand) batch is created or a FR (demand) batch is created.
   --
   --    Procedure create_nondemand_rpl_batch() is called to actually create
   --    the batch and has the logic to look at the priority.
   --
   -- Parameters:
   --    i_task_id    - Task id of the miniloader replenishment.
   --    o_batch_no   - The labor batch number created.
   --
   -- Called by:  (list may not be complete)
   --    - upd_mnl_pk.pc
   --
   -- Exceptions raised:
   --    Exceptions are passed through using whatever procedure
   --    create_nondemand_rpl_batch() raised.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    04/21/10 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE create_ml_rpl_batch
                (i_task_id                      IN  replenlst.task_id%TYPE,
                 o_batch_no                     OUT arch_batch.batch_no%TYPE)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_ml_rpl_batch';

      l_no_records_processed         PLS_INTEGER;
      l_no_batches_created           PLS_INTEGER;
      l_no_batches_existing          PLS_INTEGER;
      l_no_not_created_due_to_error  PLS_INTEGER;
   BEGIN
      create_nondemand_rpl_batch(i_task_id,
                                 o_batch_no,
                                 l_no_records_processed,
                                 l_no_batches_created,
                                 l_no_batches_existing,
                                 l_no_not_created_due_to_error);
   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name
                      || '(i_task_id[' || TO_CHAR(i_task_id) || '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
         RAISE;

   END create_ml_rpl_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_ml_rpl_batch  (overloaded)
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt batch for a miniloader
   --    replenishment using the task id.  The priority determines if a
   --    FN (non-demand) batch is created or a FR (demand) batch is created.
   --
   --    Procedure create_nondemand_rpl_batch() is called to actually create
   --    the batch and has the logic to look at the priority.
   --
   -- Parameters:
   --    i_task_id               - Task id of the miniloader replenishment.
   --    o_batch_no              - The labor batch number created.
   --    o_num_records_processed - Number of records processed.
   --                              Will be 0 or 1.
   --    o_num_batches_created   - Number of batches successfully created.
   --                              Will be 0 or 1.
   --    o_num_batches_existing  - Number of batches that already exist.
   --                              Will be 0 or 1.
   --    o_num_not_created_due_to_error - Number of batches not created.  This
   --                                     could be due to a data setup issue or
   --                                     an oracle error.  A message is logged
   --                                     to the log table for each batch not
   --                                     created.  Duplicates not logged since
   --                                     this procedure could be run multiple
   --                                     times for the same data.
   --                              Will be 0 or 1.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    Exceptions are passed through using whatever procedure
   --    create_nondemand_rpl_batch() raised.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    04/21/10 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE create_ml_rpl_batch
                (i_task_id                       IN  replenlst.task_id%TYPE,
                 o_batch_no                      OUT arch_batch.batch_no%TYPE,
                 o_num_records_processed         OUT PLS_INTEGER,
                 o_num_batches_created           OUT PLS_INTEGER,
                 o_num_batches_existing          OUT PLS_INTEGER,
                 o_num_not_created_due_to_error  OUT PLS_INTEGER)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_ml_rpl_batch';
   BEGIN
      create_nondemand_rpl_batch(i_task_id,
                                 o_batch_no,
                                 o_num_records_processed,
                                 o_num_batches_created,
                                 o_num_batches_existing,
                                 o_num_not_created_due_to_error);
   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name
                      || '(i_task_id[' || TO_CHAR(i_task_id) || '])';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
         RAISE;

   END create_ml_rpl_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_demand_rpl_batch
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt demand replenishment
   --    batch.
   --
   --    The batch can be for a DMD created by order processing or can be
   --    for a DMD created as a result of a partially completed DMD being
   --    put back in reserve--demand repl home slot transfer.  Parameter
   --    i_dmd_batch_type designates this.
   --    The valid values for i_dmd_batch_type are:
   --       - pl_lmc.ct_forklift_demand_rpl       i_key_value needs to be the
   --                                             float number of the DMD.
   --       - pl_lmc.ct_forklift_dmd_rpl_hs_xfer  i_key_value needs to be
   --                                             the task id of the DMD
   --                                             replenlst record.
   --
   --    Batch Number Format:
   --       For a regular demand replenishment the batch number format will
   --       be:
   --          FR<float #>
   --
   --       For a partially completed demand replenishment the batch number
   --       format will be:
   --          FR<forklift_lm_batch_no_seq.nextval>
   --       The float # cannot be used because it will cause a duplicate
   --       batch number.  Ths forklift_lm_batch_no_seq sequence, also used
   --       for putaway batches for RDC pallets, has a starting and ending
   --       number greater than the float number sequence so duplicate batch
   --       numbers will not occur.  This means we have to be careful about
   --       increasing the max value of a sequuences if the value may be used
   --       in building a batch number.
   --
   -- Parameters:
   --    i_dmd_batch_type       - Type of DMD batch to create.  This affects
   --                             what tables are used to create the batch
   --                             and the format of the batch number
   --    i_key_value            - Value to use to select the record from the
   --                             main table.  For a DMD created by order
   --                             processing this will be the float number.
   --                             For a DMD home slot transfer this will be
   --                             the replenishment task id.
   --    i_force_creation_bln   - Designates if to create the batch even if
   --                             forklift labor mgmt is off.  Useful for
   --                             testing/debugging or if the calling object
   --                             has checked if forklift labor mgmt is on
   --                             or off.
   --    o_no_records_processed - Number of records processed.
   --                             Will be 0 or 1.
   --    o_no_batches_created   - Number of batches successfully created.
   --                             Will be 0 or 1.
   --    o_no_batches_existing  - Number of batches that already exist.
   --                             Will be 0 or 1.
   --    o_no_not_created_due_to_error - Number of batches not created.  This
   --                                    could be due to a data setup issue or
   --                                    an oracle error.  A message is logged
   --                                    to the log table for each batch not
   --                                    created.  Duplicates not logged since
   --                                    this procedure could be run multiple
   --                                    times for the same data.
   --                             Will be 0 or 1.
   --
   -- Called by:  (list may not be complete)
   --    - 
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error         - Parameter is null.
   --    pl_exc.e_database_error     - Got an oracle error.
   --    pl_exc.e_lm_batch_upd_fail  - Failed to create the batch.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/02/05 prpbcb   Created.
   --
   ---------------------------------------------------------------------------
   PROCEDURE create_demand_rpl_batch
                (i_dmd_batch_type               IN  pl_lmc.t_batch_type,
                 i_key_value                    IN  NUMBER,
                 i_force_creation_bln           IN  BOOLEAN DEFAULT FALSE,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_demand_rpl_batch';

      l_batch_no      arch_batch.batch_no%TYPE; -- Batch number for the
                                                -- labor batch.
      l_create_batch_bln       BOOLEAN;         -- Designates if to create
                                                -- the batch or not.  Populated
                                                -- based on if forlift is active
                                                -- and what i_force_creation_bln
                                                -- is set to.
      l_insert_successful_bln  BOOLEAN;         -- Flags if the insert into the
                                                -- batch table was successful.
                                                -- Populated from SQL%FOUND.
                                                -- The check is not made
                                                -- immediately after the insert
                                                -- stmt so saving SQL%FOUND was
                                                -- necessary because calls to
                                                -- pl_log could be made before
                                                -- the check.
      l_join_tables  VARCHAR2(120) := NULL;     -- Tables in join.  Used in
                                                -- aplog messages.
      l_no_batches_created PLS_INTEGER;         -- Number of batch records
                                                -- created by the insert stmt.
                                                -- Populated from SQL%ROWCOUNT.
                                                -- Should always be 1.
      l_seq_value  NUMBER;                      -- nextval of sequence to use
                                                -- in building the batch #.

      e_unhandled_dmd_batch_type EXCEPTION;     -- i_dmd_batch_type has a
                                                -- unhandled value.

   BEGIN
      --
      -- Initialize the statistics count.
      --
      o_no_records_processed        := 0;
      o_no_batches_created          := 0;
      o_no_batches_existing         := 0;
      o_no_not_created_due_to_error := 0;

      --
      -- Flag to create the batch if force batch creation is set or forklift
      -- labor is active.  The check is done in this manner because the calling
      -- object could have checked if forklift is active and set
      -- i_force_creation_bln to TRUE.  Checking a boolean value is much
      -- quicker then the call to function f_forklift_active.
      --
      IF (i_force_creation_bln = FALSE) THEN
         IF (pl_lmf.f_forklift_active = TRUE) THEN
            l_create_batch_bln := TRUE;
         ELSE
            l_create_batch_bln := FALSE;
         END IF;
      ELSE
         l_create_batch_bln := TRUE;
      END IF;

      IF (l_create_batch_bln = TRUE) THEN

         --
         -- Check for null parameters.
         --
         IF (i_dmd_batch_type IS NULL OR i_key_value IS NULL) THEN
            RAISE gl_e_parameter_null;
         END IF;

         -- Create the demand replenishment labor mgmt batch.

         -- For our purposes one record will be processed.
         o_no_records_processed := 1;

         --
         -- Start a new block to use in trapping errors.
         --
         BEGIN
            IF (i_dmd_batch_type = pl_lmc.ct_forklift_demand_rpl) THEN
               --
               -- Order generation demand replenishment.
               -- Create the batch from the float record.
               --

               -- Build the batch number.  i_key_value will be the float
               -- number.
               l_batch_no := pl_lmc.ct_forklift_demand_rpl ||
                                         TO_CHAR(i_key_value);

               -- Insert the batch.
               INSERT INTO batch
                             (batch_no,
                              jbcd_job_code,
                              status,
                              batch_date,
                              kvi_from_loc,
                              kvi_to_loc,
                              kvi_no_case,
                              kvi_no_split,
                              kvi_no_pallet,
                              kvi_no_item,
                              kvi_no_po,
                              kvi_cube,
                              kvi_wt,
                              kvi_no_loc,
                              total_count,
                              total_piece,
                              total_pallet,
                              ref_no,
                              kvi_distance, 
                              goal_time,
                              target_time,
                              no_breaks,
                              no_lunches,
                              kvi_doc_time,
                              kvi_no_piece,
                              kvi_no_data_capture,
                              msku_batch_flag,
                              cmt)
               SELECT l_batch_no,
                      fk.dmdrpl_jobcode jbcd_job_code,
                      'F'            status,
                      TRUNC(SYSDATE) batch_date,
                      fd.src_loc     kvi_from_loc,
                      f.home_slot    kvi_to_loc,
                      0              kvi_no_case,
                      0              kvi_no_split,
                      1              kvi_no_pallet,
                      1              kvi_no_item,
                      0              kvi_no_po,
                      (fd.qty_alloc / pm.spc) * pm.case_cube  kvi_cube,
                      fd.qty_alloc * NVL(pm.g_weight, 0)      kvi_wt,
                      1              kvi_no_loc,
                      1              total_count,
                      0              total_piece,
                      1              total_pallet,
                      f.pallet_id    ref_no,
                      0              kvi_distance,
                      0              goal_time,
                      0              target_time, 
                      0              no_breaks,
                      0              no_lunches,
                      1              kvi_doc_time,
                      0              kvi_no_piece,
                      2              kvi_no_data_capture,
                      DECODE(f.parent_pallet_id,
                             NULL, NULL,
                             'Y')    msku_batch_flag,
                      'DEMAND REPL BATCH CREATED FROM FLOAT INFO'  cmt
                 FROM job_code j,
                      fk_area_jobcodes fk,
                      swms_sub_areas ssa,
                      aisle_info ai,
                      pm,
                      float_detail fd,
                      floats f
                WHERE j.jbcd_job_code     = fk.dmdrpl_jobcode
                  AND fk.sub_area_code    = ssa.sub_area_code
                  AND ssa.sub_area_code   = ai.sub_area_code
                  AND ai.name             = SUBSTR(f.home_slot, 1, 2)
                  AND pm.prod_id          = fd.prod_id
                  AND pm.cust_pref_vendor = fd.cust_pref_vendor
                  AND fd.float_no         = f.float_no
                  AND f.pallet_pull       = 'R'
                  AND f.float_no          = i_key_value;

               l_insert_successful_bln := SQL%FOUND;
               l_no_batches_created := SQL%ROWCOUNT;

            ELSIF (i_dmd_batch_type = pl_lmc.ct_forklift_dmd_rpl_hs_xfer) THEN
               --
               -- Demand replenishment created as a result of a partially
               -- completed DMD being put back in reserve.
               --i_key_value is replenishment task id.

               --
               -- Build the batch number.
               -- The batch number format will be:   (prpbcb 08/09/05)
               --    FR<forklift_lm_batch_no_seq.nextval>
               -- (pl_lmc.ct_forklift_demand_rpl is set to FR)
               --
               SELECT forklift_lm_batch_no_seq.NEXTVAL INTO l_seq_value
                 FROM DUAL;

               l_batch_no := pl_lmc.ct_forklift_demand_rpl ||
                                TO_CHAR(l_seq_value);

               -- Insert the batch.
               INSERT INTO batch
                             (batch_no,
                              jbcd_job_code,
                              status,
                              batch_date,
                              kvi_from_loc,
                              kvi_to_loc,
                              kvi_no_case,
                              kvi_no_split,
                              kvi_no_pallet,
                              kvi_no_item,
                              kvi_no_po,
                              kvi_cube,
                              kvi_wt,
                              kvi_no_loc,
                              total_count,
                              total_piece,
                              total_pallet,
                              ref_no,
                              kvi_distance, 
                              goal_time,
                              target_time,
                              no_breaks,
                              no_lunches,
                              kvi_doc_time,
                              kvi_no_piece,
                              kvi_no_data_capture,
                              msku_batch_flag,
                              cmt)
               SELECT l_batch_no,
                      fk.dmdrpl_jobcode jbcd_job_code,
                      'F'            status,
                      TRUNC(SYSDATE) batch_date,
                      r.src_loc      kvi_from_loc,
                      r.dest_loc     kvi_to_loc,
                      0              kvi_no_case,
                      0              kvi_no_split,
                      1              kvi_no_pallet,
                      1              kvi_no_item,
                      0              kvi_no_po,
                      (r.qty / pm.spc) * pm.case_cube  kvi_cube,
                      r.qty * NVL(pm.g_weight, 0)      kvi_wt,
                      1              kvi_no_loc,
                      1              total_count,
                      0              total_piece,
                      1              total_pallet,
                      r.pallet_id    ref_no,
                      0              kvi_distance,
                      0              goal_time,
                      0              target_time, 
                      0              no_breaks,
                      0              no_lunches,
                      1              kvi_doc_time,
                      0              kvi_no_piece,
                      2              kvi_no_data_capture,
                      DECODE(r.parent_pallet_id,
                             NULL, NULL,
                             'Y')    msku_batch_flag,
                      'DEMAND REPL BATCH FOR PARTIALLY COMPLETED DMD'  cmt
                 FROM job_code j,
                      fk_area_jobcodes fk,
                      swms_sub_areas ssa,
                      aisle_info ai,
                      pm,
                      replenlst r
                WHERE j.jbcd_job_code     = fk.dmdrpl_jobcode
                  AND fk.sub_area_code    = ssa.sub_area_code
                  AND ssa.sub_area_code   = ai.sub_area_code
                  AND ai.name             = SUBSTR(r.dest_loc, 1, 2)
                  AND pm.prod_id          = r.prod_id
                  AND pm.cust_pref_vendor = r.cust_pref_vendor
                  AND r.type              = 'DMD'
                  AND r.task_id           = i_key_value;

               l_insert_successful_bln := SQL%FOUND;
               l_no_batches_created := SQL%ROWCOUNT;

            ELSE
               --
               -- i_dmd_batch_type has an unhandled value.
               --
               RAISE e_unhandled_dmd_batch_type;
            END IF;

            --
            -- Verify the batch was created.
            --
            IF (l_insert_successful_bln) THEN
               --
               -- Batch created.
               --
               o_no_batches_created := l_no_batches_created;

               -- Write aplog message stating the batch was created.
               l_message := 'i_dmd_batch_type[' || i_dmd_batch_type ||
                  ']' ||
                  '  i_key_value[' || TO_CHAR(i_key_value) || ']' ||
                  '  i_force_creation_bln[' ||
                  f_boolean_text(i_force_creation_bln) ||
                  ']  Created demand repl forklift labor mgmt batch.' ||
                  '  Batch#[' || l_batch_no || ']';

               pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                              l_message,  NULL, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

               --
               -- Update the replenlst task with the batch # if we have
               -- the task id.  This is required for a partially completed
               -- demand replenishment.  Because the batch number is not
               -- FR<float #> but FR<seq #> the batch # needs to be stored
               -- in the replenlst table so when the partially completed
               -- demand replenishment is started the system knows the
               -- batch for it.
               --
               IF (i_dmd_batch_type = pl_lmc.ct_forklift_dmd_rpl_hs_xfer) THEN
                  --
                  -- Update the replenlst labor batch #.
                  -- i_key_value is the replenishment task id.
                  --
                  UPDATE replenlst
                     SET labor_batch_no = l_batch_no
                  WHERE task_id = i_key_value;

                  IF (SQL%NOTFOUND) THEN
                     l_message := 'TABLE=replenlst  ACTION=UPDATE' ||
                        '  KEY=[' || TO_CHAR(i_key_value) ||
                        '](i_key_value--task id)' ||
                        '  i_dmd_batch_type[' || i_dmd_batch_type || ']' ||
                        '  i_force_creation_bln[' ||
                        f_boolean_text(i_force_creation_bln) || ']' ||
                        '  l_batch_no[' || l_batch_no || ']' ||
                        '  MESSAGE="Failed to update the record with the' ||
                        ' labor batch.  This will not stop processing now' ||
                        ' but will cause an issue when attempting to do' ||
                        ' the DMD."';

                     pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                                    l_message, pl_exc.ct_lm_batch_upd_fail, NULL,
                                    pl_rcv_open_po_types.ct_application_function,
                                    gl_pkg_name);

                  END IF;
               END IF;

            ELSE
               --
               -- Batch not created because nothing was selected.
               -- Write log message and continue processing.  This will
               -- not cause a problem now but will cause a problem
               -- when the operator attempts to do the DMD.
               --
               o_no_not_created_due_to_error := 1;

               IF (i_dmd_batch_type = pl_lmc.ct_forklift_demand_rpl) THEN
                  l_join_tables := 'ob_code,fk_area_jobcodes,' ||
                                'swms_sub_areas,aisle_info,pm,replenlst';
               ELSE
                  l_join_tables := 'job_code,fk_area_jobcodes,' ||
                        'swms_sub_areas,aisle_info,pm,flaat_detai,floats';
               END IF;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                  '  KEY=[' || TO_CHAR(i_key_value) || '](i_key_value)' ||
                  '  i_dmd_batch_type[' || i_dmd_batch_type || ']' ||
                  '  i_force_creation_bln[' ||
                  f_boolean_text(i_force_creation_bln) ||
                  ']' ||
                  '  l_batch_no[' || l_batch_no || ']' ||
                  '  JOIN TABLES=' || l_join_tables ||
                  'swms_sub_areas,aisle_info,pm,float_detail,floats' ||
                  '  MESSAGE="DMD forklift labor batch not created.  No' ||
                  ' record selected to insert into batch table.' ||
                  '  Could be a data setup issue.  This will not stop' ||
                  ' processing."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                              l_message, pl_exc.ct_lm_batch_upd_fail, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

            END IF;

         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               -- The batch already exists.  This is OK because this
               -- procedure could have been run again for the same data.
               o_no_batches_existing := o_no_batches_existing + 1;

            WHEN e_unhandled_dmd_batch_type THEN
               RAISE;  -- Propagate the exception.

            WHEN OTHERS THEN
               -- Got some kind of oracle error.  Log the error then
               -- continue processing.
               o_no_not_created_due_to_error := 1;

               IF (i_dmd_batch_type = pl_lmc.ct_forklift_demand_rpl) THEN
                  l_join_tables := 'job_code,fk_area_jobcodes,' ||
                                'swms_sub_areas,aisle_info,pm,replenlst';
               ELSE
                  l_join_tables := 'job_code,fk_area_jobcodes,' ||
                        'swms_sub_areas,aisle_info,pm,flaat_detai,floats';
               END IF;

               l_message := 'TABLE=batch  ACTION=INSERT' ||
                     '  KEY=[' || TO_CHAR(i_key_value) || '](i_key_value)' ||
                     '  i_dmd_batch_type[' || i_dmd_batch_type ||
                     ']' ||
                     '  JOIN TABLES=' || l_join_tables ||
                     '  MESSAGE="Error creating forklift labor mgmt batch.' ||
                     '  This will not stop processing."';

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                              SQLCODE, SQLERRM,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

         END;  -- end of block

      END IF;  -- is forklift active

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name ||
           '(i_dmd_batch_type[' || i_dmd_batch_type || ']' ||
           ',i_key_value[' || TO_CHAR(i_key_value) || ']' ||
           ',i_force_creation_bln[' ||
           f_boolean_text(i_force_creation_bln) || ']' ||
           ',"out parameters")  Parameter is null.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN e_unhandled_dmd_batch_type THEN
         l_message := l_object_name ||
             '(i_dmd_batch_type[' || i_dmd_batch_type || ']' ||
             ',i_key_value[' || TO_CHAR(i_key_value) || ']' ||
             ',i_force_creation_bln[' ||
             f_boolean_text(i_force_creation_bln) || ']' ||
             ',"out parameters")  i_dmd_batch_type has an unhandled value.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN OTHERS THEN
         l_message := l_object_name ||
             '(i_dmd_batch_type[' || i_dmd_batch_type || ']' ||
             ',i_key_value[' || TO_CHAR(i_key_value) || ']' ||
             ',i_force_creation_bln[' ||
             f_boolean_text(i_force_creation_bln) || ']' ||
             ',"out parameters")  ORACLE error.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_database_error, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
   END create_demand_rpl_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_transfer_batch
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batch for a
   --   reserve to reserve transfer if forklift labor management is active.
   --   The batch is created using the trans PPT record which means the PPT
   --   record needs to be created first before calling this procedure.
   --   Only one batch should be created regardless if the pallet is a
   --   non MSKU or MSKU pallet.
   --
   --   The batch kvi_to_loc is set to the source location since the
   --   destination location is not known until the pallet is scanned
   --   to the destination slot.  The kvi_to_loc will be updated when
   --   the pallet is scanned to the destination location.  It is not
   --   desirable to leave kvi_to_loc null.
   --
   --   After the batch is created the trans.labor_batch_no is updated
   --   with the batch number.
   --
   -- Parameters:
   --    i_trans_id             - Trans id of the trans PPT record.  The
   --                             transfer batch is created using the PPT
   --                             record.  For a MSKU pallet this needs to be
   --                             the trans id of the PPT record for one of the
   --                             child LP's.  Which child LP does not matter.
   --                             A check is not made to verify this is a 
   --                             PPT transaction so if things seem to not
   --                             be working correctly check what type of
   --                             transaction this if for.
   --    o_no_records_processed - Number of records processed.  If 0 then this
   --                             indicates the PPT transaction was not found
   --                             in the trans table.
   --                             Possible value are 0 or 1
   --    o_no_batches_created   - Number of batches successfully created.
   --                             Possible value are 0 or 1.
   --    o_no_batches_existing  - Number of batches that already exist.
   --                             Possible value are 0 or 1.
   --    o_no_not_created_due_to_error - Number of batches not created.  This
   --                                    could be due to a data setup issue or
   --                                    an oracle error.  A message is logged
   --                                    to the log table for each batch not
   --                                    created.  Duplicates not logged since
   --                                    this procedure could be run multiple
   --                                    times for the same data.
   --                                    Possible value are 0 or 1.
   --                                    This will always be 0.  If some error
   --                                    occurs then an exception is raised so
   --                                    this value never gets changed from 0.  
   --
   -- Called by: (list may not be complete)
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error         - Parameter is null.
   --    pl_exc.e_database_error     - Got an oracle error.
   --    pl_exc.e_lm_batch_upd_fail  - Failed to create the batch.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    11/10/03 prpbcb   Created.
   --
   ---------------------------------------------------------------------------
   PROCEDURE create_transfer_batch
                (i_trans_id                     IN  NUMBER,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_transfer_batch';

      l_batch_no      arch_batch.batch_no%TYPE;    -- The transfer batch #
      l_parent_pallet_id  trans.parent_pallet_id%TYPE; -- Work area
      l_msku_pallet_bln BOOLEAN;                   -- Is this for a MSKU.  This
                                                   -- affects what update stmt
                                                   -- is used to update
                                                   -- trans.labor_batch_no.

   BEGIN
      -- Initialize the statistics count.
      o_no_records_processed        := 0;
      o_no_batches_created          := 0;
      o_no_batches_existing         := 0;
      o_no_not_created_due_to_error := 0;

      -- Forklift labor mgmt needs to be active.
      IF (f_forklift_active = TRUE) THEN

         -- Check for null parameters.
         IF (i_trans_id IS NULL) THEN
            RAISE gl_e_parameter_null;
         END IF;

         -- Create the transfer batch number.
         l_batch_no := pl_lmc.ct_forklift_transfer ||
                                 LTRIM(RTRIM(TO_CHAR(i_trans_id)));

         -- Determine if the transaction is for a MSKU pallet.  This
         -- affect the update stmt used to update trans.labor_batch_no.
         SELECT parent_pallet_id INTO l_parent_pallet_id
           FROM trans
          WHERE trans_id = i_trans_id;
         IF (l_parent_pallet_id IS NULL) THEN
            l_msku_pallet_bln := FALSE;
         ELSE
            l_msku_pallet_bln := TRUE;
         END IF;

         -- Start a new block to use in trapping errors.
         BEGIN
            -- Insert the transfer batch.  The stmt handles non MSKU and MSKU
            -- pallets.  A MSKU pallet has one batch created.
            INSERT INTO batch(batch_no,
                              jbcd_job_code,
                              status,
                              batch_date,
                              kvi_from_loc,
                              kvi_to_loc,
                              kvi_no_case,
                              kvi_no_split,
                              kvi_no_pallet,
                              kvi_no_item,
                              kvi_no_po,
                              kvi_cube,
                              kvi_wt,
                              kvi_no_loc,
                              total_count,
                              total_piece,
                              total_pallet,
                              ref_no,
                              kvi_distance, 
                              goal_time,
                              target_time,
                              no_breaks,
                              no_lunches,
                              kvi_doc_time,
                              kvi_no_piece,
                              kvi_no_data_capture,
                              msku_batch_flag,
                              cmt)
            SELECT l_batch_no,         -- Non MSKU pallet
                   fk.xfer_jobcode jbcd_job_code,
                   'F'             status,
                   TRUNC(SYSDATE)  batch_date,
                   t.src_loc       kvi_from_loc,
                   t.src_loc       kvi_to_loc,
                   0.0             kvi_no_case,
                   0.0             kvi_no_split,
                   1.0             kvi_no_pallet,
                   1.0             kvi_no_item,
                   0.0             kvi_no_po,
                   (t.qty / pm.spc) * pm.case_cube kvi_cube,
                   t.qty * NVL(pm.g_weight, 0)     kvi_wt,
                   1.0             kvi_no_loc,
                   1.0             total_count,
                   0.0             total_piece,
                   1.0             total_pallet,
                   NVL(t.parent_pallet_id, t.pallet_id) ref_no,
                   0.0             kvi_distance,
                   0.0             goal_time,
                   0.0             target_time, 
                   0.0             no_breaks,
                   0.0             no_lunches,
                   1.0             kvi_doc_time,
                   0.0             kvi_no_piece,
                   2.0             kvi_no_data_capture,
                   NULL            msku_batch_flag,
                   NULL            cmt
              FROM job_code j,
                   fk_area_jobcodes fk,
                   swms_sub_areas ssa,
                   aisle_info ai,
                   pm,
                   trans t
             WHERE j.jbcd_job_code     = fk.xfer_jobcode
               AND fk.sub_area_code    = ssa.sub_area_code
               AND ssa.sub_area_code   = ai.sub_area_code
               AND ai.name             = SUBSTR(t.src_loc, 1, 2)
               AND pm.prod_id          = t.prod_id
               AND pm.cust_pref_vendor = t.cust_pref_vendor
               AND t.trans_id          = i_trans_id
               AND t.trans_type ||''   = 'PPT'
               AND t.parent_pallet_id IS NULL
         UNION                   -- MSKU pallet.  Only one batch is created.
            SELECT l_batch_no, 
                   fk.xfer_jobcode jbcd_job_code,
                   'F' status,
                   TRUNC(SYSDATE) batch_date,
                   t.src_loc kvi_from_loc,
                   t.src_loc kvi_to_loc,
                   0.0 kvi_no_case,
                   0.0 kvi_no_split,
                   1.0 kvi_no_pallet,
                COUNT(DISTINCT inv.prod_id || inv.cust_pref_vendor) kvi_no_item,
                   0.0 kvi_no_po,
                   TRUNC(SUM((inv.qoh / pm.spc) * pm.case_cube)) kvi_cube,
                   TRUNC(SUM(inv.qoh * NVL(pm.g_weight, 0))) kvi_wt,
                   1.0 kvi_no_loc,
                   1.0 total_count,
                   0.0 total_piece,
                   1.0 total_pallet,
                   t.parent_pallet_id ref_no,
                   0.0 kvi_distance,
                   0.0 goal_time,
                   0.0 target_time, 
                   0.0 no_breaks,
                   0.0 no_lunches,
                   1.0 kvi_doc_time,
                   0.0 kvi_no_piece,
                   2.0 kvi_no_data_capture,
                   'Y' msku_batch_flag,
             'TRANSFER OF MSKU PALLET.  PARENT LP ' || t.parent_pallet_id cmt
              FROM job_code j,
                   fk_area_jobcodes fk,
                   swms_sub_areas ssa,
                   aisle_info ai,
                   pm,
                   inv inv,
                   trans t
             WHERE j.jbcd_job_code = fk.xfer_jobcode
               AND fk.sub_area_code = ssa.sub_area_code
               AND ssa.sub_area_code = ai.sub_area_code
               AND ai.name = SUBSTR(t.src_loc, 1, 2)
               AND pm.prod_id = t.prod_id
               AND pm.cust_pref_vendor = t.cust_pref_vendor
               AND inv.parent_pallet_id = t.parent_pallet_id
               AND t.trans_id = i_trans_id
               AND t.parent_pallet_id IS NOT NULL
             GROUP BY l_batch_no,
                      fk.xfer_jobcode,
                      t.src_loc,
                      t.src_loc,
                      t.parent_pallet_id;

            -- Verify the batch was created.
            IF (SQL%NOTFOUND) THEN
               RAISE pl_exc.e_lm_batch_upd_fail;
            END IF;

            o_no_records_processed  := SQL%ROWCOUNT;
            o_no_batches_created    := SQL%ROWCOUNT;

            -- Non MSKU and MSKU pallets use different update statements.
            IF (l_msku_pallet_bln = FALSE) THEN
               UPDATE trans SET labor_batch_no = l_batch_no
                WHERE trans_id = i_trans_id;
            ELSE
               UPDATE trans t1
                  SET t1.labor_batch_no = l_batch_no
                WHERE t1.trans_type = 'PPT'
                  AND t1.labor_batch_no IS NULL
                   AND (   t1.trans_id = i_trans_id
                        OR ((t1.src_loc, t1.parent_pallet_id) IN
                             (SELECT t2.src_loc, t2.parent_pallet_id
                                FROM trans t2
                               WHERE t2.trans_id = i_trans_id)) );
            END IF;
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               -- The batch already exists.  This may or may not be an error.
               -- We will let it go as not an error but write a log message.
               o_no_batches_existing := 1;

               l_message := 'Attempting to create transfer batch [' ||
                   l_batch_no || '] from transaction id [' ||
                   TO_CHAR(i_trans_id) ||'] (should be a PPT)' ||
                   '  but the batch already exists.';

               pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                              NULL, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);
         END;  -- end of block

      END IF;  -- is forklift active

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_trans_id[' || TO_CHAR(i_trans_id) ||
                      '])  Parameter is null.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN pl_exc.e_lm_batch_upd_fail THEN
         l_message := l_object_name || '(i_trans_id[' || TO_CHAR(i_trans_id) ||
            '])  ACTION=INSERT  MESSAGE="Failed to create transfer batch' ||
            ' using PPT trans record."';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_batch_upd_fail, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_batch_upd_fail,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_trans_id[' || TO_CHAR(i_trans_id) ||
                      '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);

   END create_transfer_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_home_slot_xfer_batch
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batch for a home slot
   --   transfer if forklift labor management is active.
   --   The batch is created using the trans PPH record which means the PPH
   --   record needs to be created first before calling this procedure.
   --
   --   Concerning MSKU pallets a MSKU will never be a home slot transfer.
   --
   --   The batch kvi_to_loc is set to the source location since the
   --   destination location is not known until the pallet is scanned
   --   to the destination slot.  The kvi_to_loc will be updated when
   --   the pallet is scanned to the destination location.  It is not
   --   desirable to leave kvi_to_loc null.
   --
   --   After the batch is created the trans.labor_batch_no is updated
   --   with the batch number.
   --
   -- Parameters:
   --    i_trans_id             - Trans id of the trans PPH record.  The
   --                             transfer batch is created using the PPH
   --                             record.
   --                             A check is not made to verify this is a 
   --                             PPH transaction so if things seem to not
   --                             be working correctly check what type of
   --                             transaction this if for.
   --    o_no_records_processed - Number of records processed.  If 0 then this
   --                             indicates the PPH transaction was not found
   --                             in the trans table.
   --                             Possible value are 0 or 1
   --    o_no_batches_created   - Number of batches successfully created.
   --                             Possible value are 0 or 1.
   --    o_no_batches_existing  - Number of batches that already exist.
   --                             Possible value are 0 or 1.
   --    o_no_not_created_due_to_error - Number of batches not created.  This
   --                                    could be due to a data setup issue or
   --                                    an oracle error.  A message is logged
   --                                    to the log table for each batch not
   --                                    created.  Duplicates not logged since
   --                                    this procedure could be run multiple
   --                                    times for the same data.
   --                                    Possible value are 0 or 1.
   --                                    This will always be 0.  If some error
   --                                    occurs then an exception is raised so
   --                                    this value never gets changed from 0.  
   --
   -- Called by:  (list may not be complete)
   --    - lmc_create_batch in lm_forklift.pc
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error         - Parameter is null.
   --    pl_exc.e_database_error     - Got an oracle error.
   --    pl_exc.e_lm_batch_upd_fail  - Failed to create the batch.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    11/10/03 prpbcb   Created.
   --
   ---------------------------------------------------------------------------
   PROCEDURE create_home_slot_xfer_batch
                (i_trans_id                     IN  NUMBER,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_home_slot_xfer_batch';

      l_batch_no      arch_batch.batch_no%TYPE;    -- The home slot transfer
                                                   -- batch #.

   BEGIN
      -- Initialize the statistics count.
      o_no_records_processed        := 0;
      o_no_batches_created          := 0;
      o_no_batches_existing         := 0;
      o_no_not_created_due_to_error := 0;

      -- Forklift labor mgmt needs to be active.
      IF (f_forklift_active = TRUE) THEN

         -- Check for null parameters.
         IF (i_trans_id IS NULL) THEN
            RAISE gl_e_parameter_null;
         END IF;

         -- Create the transfer batch number.
         l_batch_no := pl_lmc.ct_forklift_home_slot_xfer ||
                                 LTRIM(RTRIM(TO_CHAR(i_trans_id)));

         -- Start a new block to use in trapping errors.
         BEGIN
            -- Insert the transfer batch.  The stmt handles non MSKU and MSKU
            -- pallets.  A MSKU pallet has one batch created.
            INSERT INTO batch(batch_no,
                              jbcd_job_code,
                              status,
                              batch_date,
                              kvi_from_loc,
                              kvi_to_loc,
                              kvi_no_case,
                              kvi_no_split,
                              kvi_no_pallet,
                              kvi_no_item,
                              kvi_no_po,
                              kvi_cube,
                              kvi_wt,
                              kvi_no_loc,
                              total_count,
                              total_piece,
                              total_pallet,
                              ref_no,
                              kvi_distance, 
                              goal_time,
                              target_time,
                              no_breaks,
                              no_lunches,
                              kvi_doc_time,
                              kvi_no_piece,
                              kvi_no_data_capture,
                              msku_batch_flag,
                              cmt)
            SELECT l_batch_no,
                   fk.hst_jobcode jbcd_job_code,
                   'F'            status,
                   TRUNC(SYSDATE) batch_date,
                   t.src_loc      kvi_from_loc,
                   t.src_loc      kvi_to_loc,
                   0              kvi_no_case,
                   0              kvi_no_split,
                   1              kvi_no_pallet,
                   1              kvi_no_item,
                   0              kvi_no_po,
                   (t.qty / pm.spc) * pm.case_cube kvi_cube,
                   t.qty * NVL(pm.g_weight, 0)     kvi_wt,
                   1              kvi_no_loc,
                   1              total_count,
                   0              total_piece,
                   1              total_pallet,
                   t.pallet_id    ref_no,
                   0              kvi_distance,
                   0              goal_time,
                   0              target_time, 
                   0              no_breaks,
                   0              no_lunches,
                   1              kvi_doc_time,
                   0              kvi_no_piece,
                   2              kvi_no_data_capture,
                   NULL           msku_batch_flag,
                   NULL           cmt
              FROM job_code j,
                   fk_area_jobcodes fk,
                   swms_sub_areas ssa,
                   aisle_info ai,
                   pm,
                   trans t
             WHERE j.jbcd_job_code     = fk.hst_jobcode
               AND fk.sub_area_code    = ssa.sub_area_code
               AND ssa.sub_area_code   = ai.sub_area_code
               AND ai.name             = SUBSTR(t.src_loc, 1, 2)
               AND pm.prod_id          = t.prod_id
               AND pm.cust_pref_vendor = t.cust_pref_vendor
               AND t.trans_type ||''   = 'PPH'
               AND t.trans_id          = i_trans_id;

            -- Verify the batch was created.
            IF (SQL%NOTFOUND) THEN
               RAISE pl_exc.e_lm_batch_upd_fail;
            END IF;

            l_message := l_object_name || '  TABLE=batch   l_batch_no[' ||
               l_batch_no || ']  trans id[' || TO_CHAR(i_trans_id) || ']' ||
               '  ACTION=INSERT  MESSAGE="Created batch from trans record."';

            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                           NULL, NULL,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            o_no_records_processed  := SQL%ROWCOUNT;
            o_no_batches_created    := SQL%ROWCOUNT;

            -- Update the trans record with the batch number.
            UPDATE trans SET labor_batch_no = l_batch_no
                WHERE trans_id = i_trans_id;

         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               -- The batch already exists.  This may or may not be an error.
               -- We will let it go as not an error but write a log message.
               o_no_batches_existing := 1;
               l_message := 'Attempting to create home slot batch [' ||
                   l_batch_no || '] from transaction id [' ||
                   TO_CHAR(i_trans_id) ||'] (should be a PPH)' ||
                   '  but the batch already exists.';

               pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                              NULL, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);
         END;  -- end of block

      END IF;  -- is forklift active

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_trans_id[' || TO_CHAR(i_trans_id) ||
                      '])  Parameter is null.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN pl_exc.e_lm_batch_upd_fail THEN
         l_message := l_object_name || '(i_trans_id[' || TO_CHAR(i_trans_id) ||
            '])  ACTION=INSERT  MESSAGE="Failed to create home slot' ||
            ' transfer batch using PPH trans record."';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_batch_upd_fail, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_batch_upd_fail,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_trans_id[' || TO_CHAR(i_trans_id) ||
                      '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);

   END create_home_slot_xfer_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_dmd_rpl_hs_xfer_batch
   --
   -- Description:
   --    This procedure creates the demand replenishment transfer batch.
   --    This happens when the forklift operator has performed a demand
   --    replenishment and not all the cases fit in the slot.  Cases are
   --    being transferred back to reserve with the transfer qty > qoh in
   --    the home slot.  The qty transferred > qoh indicates the replenishment
   --    was only partially completed.
   --
   --    The batch is created only if forklift labor management is active.
   --    The batch is created using the trans PPD record which means the PPD
   --    record needs to be created first before calling this procedure.
   --
   --    Concerning MSKU pallets, a MSKU will never have a DMD only
   --    partially completed so this procedure should never be called for
   --    a MSKU.
   --
   --    The batch kvi_to_loc is set to the source location since the
   --    destination location is not known until the pallet is scanned
   --    to the destination slot.  The kvi_to_loc will be updated when
   --    the pallet is scanned to the destination location.  It is not
   --    desirable to leave kvi_to_loc null.
   --
   --    After the batch is created the trans.labor_batch_no is updated
   --    with the batch number.
   --
   -- Parameters:
   --    i_trans_id             - Trans id of the trans PPD record.  The
   --                             transfer batch is created using the PPD
   --                             record.
   --                             A check is not made to verify this is a 
   --                             PPD transaction so if things seem to not
   --                             be working correctly check what type of
   --                             transaction this if for.
   --    o_no_records_processed - Number of records processed.  If 0 then this
   --                             indicates the PPD transaction was not found
   --                             in the trans table.
   --                             Possible value are 0 or 1
   --    o_no_batches_created   - Number of batches successfully created.
   --                             Possible value are 0 or 1.
   --    o_no_batches_existing  - Number of batches that already exist.
   --                             Possible value are 0 or 1.
   --    o_no_not_created_due_to_error - Number of batches not created.  This
   --                                    could be due to a data setup issue or
   --                                    an oracle error.  A message is logged
   --                                    to the log table for each batch not
   --                                    created.  Duplicates not logged since
   --                                    this procedure could be run multiple
   --                                    times for the same data.
   --                                    Possible value are 0 or 1.
   --                                    This will always be 0.  If some error
   --                                    occurs then an exception is raised so
   --                                    this value never gets changed from 0.  
   --
   -- Called by:  (list may not be complete)
   --    - lmc_create_batch in lm_forklift.pc
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error         - Parameter is null.
   --    pl_exc.e_database_error     - Got an oracle error.
   --    pl_exc.e_lm_batch_upd_fail  - Failed to create the batch.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    11/10/03 prpbcb   Created.
   --
   ---------------------------------------------------------------------------
   PROCEDURE create_dmd_rpl_hs_xfer_batch
                (i_trans_id                     IN  NUMBER,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_dmd_rpl_hs_xfer_batch';

      l_batch_no      arch_batch.batch_no%TYPE;    -- The home slot transfer
                                                   -- batch #.
      l_trans_type    trans.trans_type%TYPE := 'PPD';  -- The trans type of
                                                       -- the trans record
                                                       -- used to create the
                                                       -- batch.

   BEGIN
      -- Initialize the statistics count.
      o_no_records_processed        := 0;
      o_no_batches_created          := 0;
      o_no_batches_existing         := 0;
      o_no_not_created_due_to_error := 0;

      -- Forklift labor mgmt needs to be active.
      IF (f_forklift_active = TRUE) THEN

         -- Check for null parameters.
         IF (i_trans_id IS NULL) THEN
            RAISE gl_e_parameter_null;
         END IF;

         -- Create the transfer batch number.
         l_batch_no := pl_lmc.ct_forklift_dmd_rpl_hs_xfer ||
                                 LTRIM(RTRIM(TO_CHAR(i_trans_id)));

         -- Start a new block to use in trapping errors.
         BEGIN
            -- Insert the DMD home slot transfer batch.
            INSERT INTO batch(batch_no,
                              jbcd_job_code,
                              status,
                              batch_date,
                              kvi_from_loc,
                              kvi_to_loc,
                              kvi_no_case,
                              kvi_no_split,
                              kvi_no_pallet,
                              kvi_no_item,
                              kvi_no_po,
                              kvi_cube,
                              kvi_wt,
                              kvi_no_loc,
                              total_count,
                              total_piece,
                              total_pallet,
                              ref_no,
                              kvi_distance, 
                              goal_time,
                              target_time,
                              no_breaks,
                              no_lunches,
                              kvi_doc_time,
                              kvi_no_piece,
                              kvi_no_data_capture,
                              msku_batch_flag,
                              cmt)
            SELECT l_batch_no,
                   fk.hst_jobcode jbcd_job_code,
                   'F'            status,
                   TRUNC(SYSDATE) batch_date,
                   t.src_loc      kvi_from_loc,
                   t.src_loc      kvi_to_loc,
                   0              kvi_no_case,
                   0              kvi_no_split,
                   1              kvi_no_pallet,
                   1              kvi_no_item,
                   0              kvi_no_po,
                   (t.qty / pm.spc) * pm.case_cube kvi_cube,
                   t.qty * NVL(pm.g_weight, 0)     kvi_wt,
                   1              kvi_no_loc,
                   1              total_count,
                   0              total_piece,
                   1              total_pallet,
                   t.pallet_id    ref_no,
                   0              kvi_distance,
                   0              goal_time,
                   0              target_time, 
                   0              no_breaks,
                   0              no_lunches,
                   1              kvi_doc_time,
                   0              kvi_no_piece,
                   2              kvi_no_data_capture,
                   NULL           msku_batch_flag,
                   NULL           cmt
              FROM job_code j,
                   fk_area_jobcodes fk,
                   swms_sub_areas ssa,
                   aisle_info ai,
                   pm,
                   trans t
             WHERE j.jbcd_job_code     = fk.hst_jobcode
               AND fk.sub_area_code    = ssa.sub_area_code
               AND ssa.sub_area_code   = ai.sub_area_code
               AND ai.name             = SUBSTR(t.src_loc, 1, 2)
               AND pm.prod_id          = t.prod_id
               AND pm.cust_pref_vendor = t.cust_pref_vendor
               AND t.trans_type ||''   = l_trans_type
               AND t.trans_id          = i_trans_id;

            -- Verify the batch was created.
            IF (SQL%NOTFOUND) THEN
               RAISE pl_exc.e_lm_batch_upd_fail;
            END IF;

            l_message := l_object_name || '  TABLE=batch   l_batch_no[' ||
               l_batch_no || ']  trans id[' || TO_CHAR(i_trans_id) || ']' ||
               '  ACTION=INSERT  MESSAGE="Created batch from trans record."';

            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                           NULL, NULL,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            o_no_records_processed  := SQL%ROWCOUNT;
            o_no_batches_created    := SQL%ROWCOUNT;

            -- Update the trans record with the batch number.
            UPDATE trans SET labor_batch_no = l_batch_no
                WHERE trans_id = i_trans_id;

         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               -- The batch already exists.  This may or may not be an error.
               -- We will let it go as not an error but write a log message.
               o_no_batches_existing := 1;
               l_message := 'Attempting to create DMD home slot batch [' ||
                   l_batch_no || '] from transaction id [' ||
                   TO_CHAR(i_trans_id) ||'] (should be a ' ||
                   l_trans_type || ')' ||
                   ' but the batch already exists.';

               pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                              NULL, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);
         END;  -- end of block

      END IF;  -- is forklift active

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_trans_id[' || TO_CHAR(i_trans_id) ||
                      '])  Parameter is null.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN pl_exc.e_lm_batch_upd_fail THEN
         l_message := l_object_name || '(i_trans_id[' || TO_CHAR(i_trans_id) ||
            '])  ACTION=INSERT  MESSAGE="Failed to create home slot' ||
            ' transfer batch using ' || l_trans_type || ' trans record."';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_batch_upd_fail, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_batch_upd_fail,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_trans_id[' || TO_CHAR(i_trans_id) ||
                      '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);

   END create_dmd_rpl_hs_xfer_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_return_to_reserve_batch
   --
   -- Description:
   --    This procedure creates the forklift labor mgmt batch for a
   --    MSKU that is being returned back to reserve after a non-demand
   --    or demand replenishment and if the operator aborts the operation.
   --    This batch will be merged with the parent batch of the drop.
   --
   --    For the abort processing the batch will be merged with any completed
   --    drops.  If there are not completed drops then the return to reserve
   --    batch will not be created.
   --
   --    For an abort of a DMD the kvi cube, kvi no items, and kvi wt will not
   --    be the true values because the child LP's have been deleted from
   --    inventory by order processing.
   --
   --   The job code will be that for a transfer job code.
   --
   --    The approach to handle the different batch types is using different
   --    cursors instead of separate functions.
   --
   -- Parameters:
   --    i_parent_batch_no      - The parent batch number to merge the
   --                             return to reserve batch to.  If this batch
   --                             is not a NDM or DMD then this procedure does
   --                             nothing.
   --    i_abort_processing_bln - Designates if processing a func1 on the RF.
   --                             The kvi values are calculated differently
   --                             in this situation.  A func1 will always
   --                             prompt the operator to put the MSKU back
   --                             to reserve.
   --
   -- Called by: (list may not be complete)
   --    - pl_lm_msku.merge_nondemand_rpl_batches
   --    - pl_lm_msku.merge_demand_rpl_batches
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error         - Parameter is null.
   --    pl_exc.e_database_error     - Got an oracle error.
   --    pl_exc.e_lm_batch_upd_fail  - Failed to create the batch.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    11/10/03 prpbcb   Created for MSKU.
   ---------------------------------------------------------------------------
   PROCEDURE create_return_to_reserve_batch
                         (i_parent_batch_no      IN  arch_batch.batch_no%TYPE,
                          i_abort_processing_bln IN  BOOLEAN DEFAULT FALSE)
   IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_return_to_reserve_batch';

      l_abort_processing_flag  VARCHAR2(1);  -- i_abort_processing_bln as
                                             -- Y or N.
      l_already_a_parent_flag  VARCHAR2(1);  -- Y or N.  Designates if 
                       -- i_parent_batch_no is already marked as a parent.

      l_batch_no      arch_batch.batch_no%TYPE;  -- The return to reserve
                                                 -- batch #
      l_batch_type    VARCHAR2(10);   -- The batch type of i_parent_batch_no
      l_counter       PLS_INTEGER;    -- Work area
      l_create_batch_bln  BOOLEAN;    -- Work area
      l_dest_loc      loc.logi_loc%TYPE;  -- Replenishment destination location.
      l_kvi_cube      arch_batch.kvi_cube%TYPE; -- Cube of the return to
                                                -- reserve batch.
      l_kvi_no_item   arch_batch.kvi_no_item%TYPE;  -- # of unique items on
                                                -- the return to reserve batch.
      l_kvi_wt        arch_batch.kvi_wt%TYPE;   -- Weight of the return to
                                                -- reserve batch.
      l_parent_pallet_id inv.parent_pallet_id%TYPE;
      l_src_loc      loc.logi_loc%TYPE;  -- Replenishment source location.

      -- This cursor selects the child LP data on a MSKU that are not being
      -- replenished for a non-demand replenishment and the child LP data
      -- for abort processing.
      CURSOR c_ndm(cp_parent_batch_no   arch_batch.batch_no%TYPE,
                   cp_abort_processing  VARCHAR2) IS
         SELECT i.parent_pallet_id,
                COUNT(DISTINCT i.prod_id || i.cust_pref_vendor) kvi_no_item,
                TRUNC(SUM((i.qoh / pm.spc) * pm.case_cube))     kvi_cube,
                TRUNC(SUM(i.qoh * NVL(pm.g_weight, 0)))         kvi_wt,
                COUNT(1)        -- Used to check if records found
           FROM pm,
                inv i
          WHERE cp_abort_processing = 'N'
            AND pm.prod_id          = i.prod_id
            AND pm.cust_pref_vendor = i.cust_pref_vendor
            AND i.parent_pallet_id =
                 (SELECT parent_pallet_id
                    FROM replenlst r1
                   WHERE r1.task_id = SUBSTR(cp_parent_batch_no, 3)
                     AND r1.type    = 'NDM')
           AND NOT EXISTS
                    (SELECT 'x'
                       FROM replenlst r2
                      WHERE r2.pallet_id = i.logi_loc
                        AND r2.type      = 'NDM')
          GROUP BY i.parent_pallet_id
         UNION
         SELECT i.parent_pallet_id,
                COUNT(DISTINCT i.prod_id || i.cust_pref_vendor) kvi_no_item,
                TRUNC(SUM((i.qoh / pm.spc) * pm.case_cube))     kvi_cube,
                TRUNC(SUM(i.qoh * NVL(pm.g_weight, 0)))         kvi_wt,
                COUNT(1)        -- Used to check if records found
           FROM pm,
                inv i
          WHERE cp_abort_processing = 'Y'
            AND pm.prod_id          = i.prod_id
            AND pm.cust_pref_vendor = i.cust_pref_vendor
            AND i.parent_pallet_id =
                 (SELECT parent_pallet_id
                    FROM replenlst r1
                   WHERE r1.task_id = SUBSTR(cp_parent_batch_no, 3)
                     AND r1.type    = 'NDM')
          GROUP BY i.parent_pallet_id;

      -- This cursor selects the child LP data on a MSKU that are not being
      -- replenished for a demand replenishment and for abort processing.
      -- The floats table is used for the check so that it works for both
      -- using labels for the DMD's or sending the DMD's to the RF.
      -- Keep in mind that order processing has deleted the inventory for the
      -- child LP's being replenished.
      CURSOR c_dmd(cp_parent_batch_no   arch_batch.batch_no%TYPE,
                   cp_abort_processing  VARCHAR2) IS
         SELECT i.parent_pallet_id,
                COUNT(DISTINCT i.prod_id || i.cust_pref_vendor) kvi_no_item,
                TRUNC(SUM((i.qoh / pm.spc) * pm.case_cube))     kvi_cube,
                TRUNC(SUM(i.qoh * NVL(pm.g_weight, 0)))         kvi_wt,
                COUNT(1)       -- Used to check if records found
           FROM pm,
                inv i
          WHERE cp_abort_processing = 'N'
            AND pm.prod_id          = i.prod_id
            AND pm.cust_pref_vendor = i.cust_pref_vendor
            AND i.parent_pallet_id =
                 (SELECT parent_pallet_id
                    FROM floats f
                   WHERE f.float_no = SUBSTR(cp_parent_batch_no, 3))
          GROUP BY i.parent_pallet_id
         UNION
         SELECT i.parent_pallet_id,
                COUNT(DISTINCT i.prod_id || i.cust_pref_vendor) kvi_no_item,
                TRUNC(SUM((i.qoh / pm.spc) * pm.case_cube))     kvi_cube,
                TRUNC(SUM(i.qoh * NVL(pm.g_weight, 0)))         kvi_wt,
                COUNT(1)       -- Used to check if records found
           FROM pm,
                inv i
          WHERE cp_abort_processing = 'Y'
            AND pm.prod_id          = i.prod_id
            AND pm.cust_pref_vendor = i.cust_pref_vendor
            AND i.parent_pallet_id =
                 (SELECT parent_pallet_id
                    FROM floats f
                   WHERE f.float_no = SUBSTR(cp_parent_batch_no, 3))
          GROUP BY i.parent_pallet_id;

      -- This cursor is used for abort processing for a DMD.
      -- This cursor selects the kvi values for items on the MSKU that have
      -- a DMD but where not dropped before the user aborted the process.
      -- These will be added to the kvi values for the items not being
      -- replenished.  It is necessary to look at the float tables since
      -- orcer processing has deleted the child LP's being replenished.
      CURSOR c_dmd_not_done(cp_parent_batch_no   arch_batch.batch_no%TYPE) IS
         SELECT f.parent_pallet_id,
                COUNT(DISTINCT fd.prod_id || fd.cust_pref_vendor) kvi_no_item,
                TRUNC(SUM((fd.qty_alloc / pm.spc) * pm.case_cube)) kvi_cube,
                TRUNC(SUM(fd.qty_alloc * NVL(pm.g_weight, 0))) kvi_wt
           FROM pm,
                float_detail fd,
                floats f,
                batch b
          WHERE fd.float_no         = f.float_no
            AND pm.prod_id          = fd.prod_id
            AND pm.cust_pref_vendor = fd.cust_pref_vendor
            AND f.float_no          = SUBSTR(b.batch_no, 3)
            AND b.parent_batch_no   = cp_parent_batch_no
            AND NOT EXISTS
                     (SELECT 'x'
                        FROM trans t
                       WHERE t.labor_batch_no  = b.batch_no
                         AND t.pallet_id       = b.ref_no
                         AND t.trans_type      = 'DFK')
          GROUP BY f.parent_pallet_id;

      r_dmd_not_done          c_dmd_not_done%ROWTYPE;

      e_no_batch_type         EXCEPTION;  -- Could not determine what type of
                                          -- batch i_parent_batch_no is.

   BEGIN
      -- Check for null parameters.
      IF (i_parent_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- Find out what type of batch it is.
      l_batch_type := pl_lmc.get_batch_type(i_parent_batch_no);

      IF (l_batch_type IS NULL) THEN
         RAISE e_no_batch_type;  -- Do not know the type of batch.
      END IF;

      IF (i_abort_processing_bln) THEN
         l_abort_processing_flag := 'Y';
      ELSE
         l_abort_processing_flag := 'N';
      END IF;

      IF (l_batch_type = pl_lmc.ct_forklift_nondemand_rpl) THEN
         -- Non-demand replenishment
         OPEN c_ndm(i_parent_batch_no, l_abort_processing_flag);
         FETCH c_ndm INTO l_parent_pallet_id, l_kvi_no_item, l_kvi_cube,
                          l_kvi_wt, l_counter;

         IF (l_counter > 0) THEN
            l_create_batch_bln := TRUE;
         ELSE
            l_create_batch_bln := FALSE;
         END IF;

         CLOSE c_ndm;
      ELSIF (l_batch_type = pl_lmc.ct_forklift_demand_rpl) THEN
         -- Demand replenishment
         OPEN c_dmd(i_parent_batch_no, l_abort_processing_flag);
         FETCH c_dmd INTO l_parent_pallet_id, l_kvi_no_item, l_kvi_cube,
                          l_kvi_wt, l_counter;

         -- For abort processing always create the return to reserve batch.
         -- If all the child LP's were being replenished then the count would
         -- be 0 because non of the child LP's would be in inventory but we
         -- still want to create the batch even though the selected
         -- kvi values will be 0.
         IF (l_counter > 0 OR i_abort_processing_bln) THEN

            -- Add the kvi values for the DMD's not done if abort processing.
            IF (i_abort_processing_bln) THEN
               OPEN c_dmd_not_done(i_parent_batch_no);
               FETCH c_dmd_not_done INTO r_dmd_not_done;
               IF (c_dmd_not_done%FOUND) THEN
                  l_kvi_no_item := l_kvi_no_item + r_dmd_not_done.kvi_no_item;
                  l_kvi_cube := l_kvi_cube + r_dmd_not_done.kvi_cube;
                  l_kvi_wt := l_kvi_wt + r_dmd_not_done.kvi_wt;

                  -- If at this point l_parent_pallet_id is null which it
                  -- will be if all the child LP's were to be replenished then
                  -- assign the parent LP from the child LP's being replenished.
                  IF (l_parent_pallet_id IS NULL) THEN
                     l_parent_pallet_id := r_dmd_not_done.parent_pallet_id;
                  END IF;

               END IF;
               CLOSE c_dmd_not_done;
            END IF;

            l_create_batch_bln := TRUE;
         ELSE
            l_create_batch_bln := FALSE;
         END IF;

         CLOSE c_dmd;
      ELSE
            -- Only concerned with MSKU batches for non-demand repls
            -- and demand repls.
            l_create_batch_bln := FALSE;
      END IF;

      IF (l_create_batch_bln = TRUE) THEN
         -- Not all the child LP's on the NDM/DMD replenishment are being
         -- replenished or abort processing.  Create the return to reserve
         -- batch and merge it with the parent batch.

         l_message := l_object_name || '(i_parent_batch_no[' ||
              i_parent_batch_no || '])  l_abort_processing_flag=[' ||
              l_abort_processing_flag || ']' ||
              '  Not all of the child LP''s are' ||
              ' being replenished or abort processing.  It is necessary' ||
              ' to create a return' ||
              ' to reserve batch for the MSKU.';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         -- Info about the parent batch (or soon to be parent) is needed.
         -- Get the source and destination locations of the replenishment
         -- batch to use for the return to reserve batch.
         SELECT b.kvi_from_loc, b.kvi_to_loc,
               DECODE(b.parent_batch_no, NULL, 'N', 'Y')
           INTO l_src_loc, l_dest_loc, l_already_a_parent_flag
           FROM batch b
          WHERE batch_no = i_parent_batch_no;

         l_batch_no := f_create_ret_to_res_batch_id;

         -- Insert the return to reserve batch.  The job code will be that
         -- of a transfer.
         INSERT INTO batch(batch_no,
                           jbcd_job_code,
                           status,
                           batch_date,
                           kvi_from_loc,
                           kvi_to_loc,
                           kvi_no_case,
                           kvi_no_split,
                           kvi_no_pallet,
                           kvi_no_item,
                           kvi_no_po,
                           kvi_cube,
                           kvi_wt,
                           kvi_no_loc,
                           total_count,
                           total_piece,
                           total_pallet,
                           ref_no,
                           kvi_distance, 
                           goal_time,
                           target_time,
                           no_breaks,
                           no_lunches,
                           kvi_doc_time,
                           kvi_no_piece,
                           kvi_no_data_capture,
                           msku_batch_flag,
                           cmt)
         SELECT l_batch_no, 
                fk.xfer_jobcode     jbcd_job_code,
                'F'                 status,
                TRUNC(SYSDATE)      batch_date,
                l_dest_loc          kvi_from_loc,
                l_src_loc           kvi_to_loc,
                0                   kvi_no_case,
                0                   kvi_no_split,
                1                   kvi_no_pallet,
                l_kvi_no_item       kvi_no_item,
                0                   kvi_no_no,
                l_kvi_cube          kvi_cube,
                l_kvi_wt            kvi_wt,
                1                   kvi_no_loc,
                1                   total_count,
                0                   total_piece,
                1                   total_pallet,
                l_parent_pallet_id  ref_no,
                0                   kvi_distance,
                0                   goal_time,
                0                   target_time, 
                0                   no_breaks,
                0                   no_lunches,
                1                   kvi_doc_time,
                0                   kvi_no_piece,
                1                   kvi_no_data_capture,  -- Scan reserve slot
                'Y' msku_batch_flag,
          'RETURN OF MSKU PLT TO RESERVE. PARENT LP ' ||
                                                 l_parent_pallet_id cmt
           FROM job_code j,
                fk_area_jobcodes fk,
                swms_sub_areas ssa,
                aisle_info ai
          WHERE j.jbcd_job_code = fk.xfer_jobcode
            AND fk.sub_area_code = ssa.sub_area_code
            AND ssa.sub_area_code = ai.sub_area_code
            AND ai.name = SUBSTR(l_dest_loc, 1, 2);

         -- Verify the batch was created.
         IF (SQL%NOTFOUND) THEN
            RAISE pl_exc.e_lm_batch_upd_fail;
         END IF;

         l_message := l_object_name || '(i_parent_batch_no[' ||
              i_parent_batch_no || '])  Created return to reserve[' ||
                 l_batch_no || ']';
         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         -- Make the batch a parent batch if not already a parent.  The batch
         -- at this point may or may not be parent batch depending on if there
         -- is more that one child LP being replenished.
         IF (l_already_a_parent_flag = 'N') THEN
            pl_lmf.make_batch_parent(i_parent_batch_no);
         END IF;

         l_message := l_object_name || '(i_parent_batch_no[' ||
              i_parent_batch_no || '])  Merging batch[' || l_batch_no ||
              '] to parent batch[' || i_parent_batch_no || ']';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         pl_lmc.merge_batch(l_batch_no, i_parent_batch_no);

      END IF;  -- end IF (l_create_batch_bln = TRUE)

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_parent_batch_no[' ||
                      i_parent_batch_no || '])  Parameter is null.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN pl_exc.e_lm_batch_upd_fail THEN
         l_message := l_object_name || '(i_parent_batch_no[' ||
            i_parent_batch_no || '])' ||
            '  ACTION=INSERT  MESSAGE="Failed to create return to' ||
            ' reserve batch."';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_batch_upd_fail, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_batch_upd_fail,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_parent_batch_no[' ||
                      i_parent_batch_no || '])';

         IF (SQLCODE <= -20000) THEN
            l_message := l_message ||
                         '  Called object raised an user defined exception.';

            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            IF (c_ndm%ISOPEN) THEN CLOSE c_ndm; END IF;
            IF (c_dmd%ISOPEN) THEN CLOSE c_dmd; END IF;
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            IF (c_ndm%ISOPEN) THEN CLOSE c_ndm; END IF;
            IF (c_dmd%ISOPEN) THEN CLOSE c_dmd; END IF;
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END create_return_to_reserve_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_putaway_batch_for_lp
   --
   -- Description:
   --   This procedure creates the forklift labor mgmt batch for the putaway
   --   task for a single license plate if forklift labor management is active.
   --
   -- Parameters:
   --    i_pallet_id            - The pallet id to create the batch for.
   --    i_dest_loc             - The destination location to use for the
   --                             batch.  Set this to null if the destination
   --                             location is in the putawaylst record
   --                             otherwise provide a destination location.
   --                             In form rp1sc the batch is created when a
   --                             destination location is keyed over a '*' or
   --                             the qty received is changed from 0 to > 0.
   --                             Because of when the form calls this procedure
   --                             the putawaylst records does not yet have
   --                             the dest_loc updated so it needs to be passed
   --                             in. 
   --    o_no_records_processed - Number of records processed.
   --                             Should be 0 or 1.  If 0 then this indicates
   --                             the pallet is not in the putawaylst table or
   --                             i_dest_loc is null and the putawaylst
   --                             dest_loc is '*' or forklift labor management
   --                             is not active.
   --    o_no_batches_created   - Number of batches successfully created.
   --                             Should be 0 or 1.
   --    o_no_batches_existing  - Number of batches that already exist.
   --                             (Got DUP_VAL_ON_INDEX exception)
   --                             Should be 0 or 1.
   --    o_no_not_created_due_to_error - Number of batches not created.  This
   --                                    could be due to a data setup issue or
   --                                    an oracle error.  A message is logged
   --                                    to the log table for each batch not
   --                                    created.  Duplicates not logged since
   --                                    this procedure could be run multiple
   --                                    times for the same data.
   --                                    Should be 0 or 1.
   --
   -- Called by: (list may not be complete)
   --    - form rp1sc
   --
   -- Exceptions raised:
   --    User defined exception   - A called object returned an user
   --                               defined error.
   --    pl_exc.e_data_error      - Bad parameter.
   --    pl_exc.e_database_error  - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/29/03 prpbcb   Created.
   --
   ---------------------------------------------------------------------------
   PROCEDURE create_putaway_batch_for_lp
               (i_pallet_id                    IN  putawaylst.pallet_id%TYPE,
                i_dest_loc                     IN  putawaylst.dest_loc%TYPE,
                o_no_records_processed         OUT PLS_INTEGER,
                o_no_batches_created           OUT PLS_INTEGER,
                o_no_batches_existing          OUT PLS_INTEGER,
                o_no_not_created_due_to_error  OUT PLS_INTEGER)
   IS
      l_message       VARCHAR2(256);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_putaway_batch_for_lp';

   BEGIN
      IF (i_pallet_id IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      create_putaway_batches
             (i_create_for_what             => 'LP',
              i_key_value                   => i_pallet_id,
              i_dest_loc                    => i_dest_loc,
              o_no_records_processed        => o_no_records_processed,
              o_no_batches_created          => o_no_batches_created,
              o_no_batches_existing         => o_no_batches_existing,
              o_no_not_created_due_to_error => o_no_not_created_due_to_error);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_pallet_id is null';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(' || i_pallet_id || ')';
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END create_putaway_batch_for_lp;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_putaway_batches_for_po
   --
   -- Description:
   --   This procedure create the forklift labor mgmt batches for the putaway
   --   tasks with a destination location for a PO if forklift labor
   --   management is active.
   --
   -- Parameters:
   --    i_po_no                - The PO/SN number to create the batches for.
   --    o_no_records_processed - Number of records processed.  If 0 then this
   --                             indicates the PO is not in the
   --                             putawaylst table or all the destination
   --                             locations are '*' or forklift labor
   --                             management is not active.
   --    o_no_batches_created   - Number of batches successfully created.
   --    o_no_batches_existing  - Number of batches that already exist.
   --    o_no_not_created_due_to_error - Number of batches not created.  This
   --                                    could be due to a data setup issue or
   --                                    an oracle error.  A message is logged
   --                                    to the log table for each batch not
   --                                    created.  Duplicates not logged since
   --                                    this procedure could be run multiple
   --                                    times for the same data.
   --
   -- Called by: (list may not be complete)
   --    - pallet_label2.pc
   --  
   -- Exceptions raised:
   --    User defined exception   - A called object returned an user
   --                               defined error.
   --    pl_exc.e_data_error      - Bad parameter.
   --    pl_exc.e_database_error  - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/29/03 prpbcb   Created.
   --
   ---------------------------------------------------------------------------
   PROCEDURE create_putaway_batches_for_po
                (i_po_no                        IN  erm.erm_id%TYPE,
                 o_no_records_processed         OUT PLS_INTEGER,
                 o_no_batches_created           OUT PLS_INTEGER,
                 o_no_batches_existing          OUT PLS_INTEGER,
                 o_no_not_created_due_to_error  OUT PLS_INTEGER)
   IS
      l_message       VARCHAR2(256);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'create_putaway_batches_for_po';

   BEGIN
      IF (i_po_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      create_putaway_batches
             (i_create_for_what             => 'PO',
              i_key_value                   => i_po_no,
              i_dest_loc                    => NULL,
              o_no_records_processed        => o_no_records_processed,
              o_no_batches_created          => o_no_batches_created,
              o_no_batches_existing         => o_no_batches_existing,
              o_no_not_created_due_to_error => o_no_not_created_due_to_error);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_po_no is null';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(' || i_po_no || ')';
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END create_putaway_batches_for_po;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    delete_putaway_batch
   --
   -- Description:
   --   This procedure deletes a putaway batch.
   --
   --   It was initially created to be called by the check-in screen when
   --   the qty received was changed to 0.  Usually when the qty is changed to
   --   0 the batch needs to be deleted but for a MSKU special processing is
   --   required because the child LP's going to reserve are tied to one batch
   --   so the the putaway batch is deleted only when there are no child LP's
   --   left with qty > 0.  The screen needs to call this procedure after the
   --   form has updated the database (POST-UPDATE trigger?).
   --
   -- Parameters:
   --    i_batch_no                - The putaway batch to delete.
   --    i_delete_future_only_bln  - Designates to delete the batch only when
   --                                it is in future status.
   --
   -- Called by: (list may not be complete)
   --    - rp1sc.fmb
   --  
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null.
   --    pl_exc.e_database_error  - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    01/31/05 prpbcb   Created.
   --
   ---------------------------------------------------------------------------
   PROCEDURE delete_putaway_batch
                        (i_batch_no                IN arch_batch.batch_no%TYPE,
                         i_delete_future_only_bln  IN BOOLEAN DEFAULT FALSE)
   IS
      l_message      VARCHAR2(512);    -- Message buffer
      l_object_name  VARCHAR2(30) := 'delete_putaway_batch';

      l_batch_status VARCHAR2(1);     -- The status of the batch to delete.
                                      -- Depends on value of i_future_only_bln.

      e_not_putaway_batch EXCEPTION;  -- The batch is not a putaway batch
   BEGIN
      -- Check for null parameters.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- The batch has to be a putaway batch.
      IF (NVL(pl_lmc.get_batch_type(i_batch_no), 'x') !=
                                          pl_lmc.ct_forklift_putaway) THEN
         RAISE e_not_putaway_batch;
      END IF;

      IF (i_delete_future_only_bln) THEN
         -- Delete the batch only if it is in future status.
         l_batch_status := pl_lmc.ct_future_status;
      ELSE
         -- Delete the batch regardless of the status.
         l_batch_status := '%';
      END IF;

      -- There is special processing for a batch for a MSKU pallet.
      IF (pl_lm_msku.f_is_msku_batch(i_batch_no)) THEN
         -- The batch is for a MSKU pallet.  Delete the batch only when there
         -- are no putaway tasks for it with the qty received > 0.
         DELETE 
           FROM batch b
          WHERE batch_no = i_batch_no
            AND status LIKE l_batch_status
            AND NOT EXISTS
                      (SELECT 'x'
                         FROM putawaylst p
                        WHERE p.pallet_batch_no = b.batch_no
                          AND p.qty_received > 0);

         IF (SQL%NOTFOUND) THEN
            -- The batch was not deleted so there are still child LP's on
            -- the batch.  Re-calculate the batches cube, weight etc.
            update_msku_batch_info(i_batch_no);
         END IF;

      ELSE
         -- The batch is not for a MSKU.  Delete the batch.
         DELETE 
           FROM batch b
          WHERE batch_no = i_batch_no
            AND status LIKE l_batch_status;
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
                      '  Parameter i_batch_no is null.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

      WHEN e_not_putaway_batch THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || ']' ||
                            '  The batch is not a putaway batch.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END delete_putaway_batch;


   ---------------------------------------------------------------------------
   -- Procedure;
   --    update_erm_door_no
   --
   -- Description:
   --    This function updates the erm door number to the corresponding
   --    forklift labor mgmt door number if it is not already a forklift
   --    door number.  The erm door number that comes down from the SUS
   --    is a two char door number.  It needs to be set to the forklift
   --    four character door number before opening the PO.
   --    This procedure should only be used when forklift labor mgmt
   --    is on.
   --
   --    Example: SUS door number:  03
   --             The forklift door number is D103 so the erm.door_no
   --             needs to be updated to D103.  Note that the D1 is the dock.
   --
   --    No commit is made in this procedure.  It is up to the call program
   --    to perform the commit.
   --
   -- Parameters:
   --    i_erm_id             - PO number to update.
   --    o_update_success_bln - Designates if the erm door number updated
   --                           successfully.  If already a forklift door
   --                           number then this is set to TRUE.  If unable
   --                           to find the forklift door number then this
   --                           is set to FALSE.
   --  
   -- Exceptions raised:
   --    -20001  An oracle error occurred.
   --    -20002  Door number parameter is null.
   --    -20003  Erm id not found in erm table.
   --    -20054  PO locked by another user.  06/27/01 prpbcb  TP_wk_sheet.pc
   --                                        calls this procedure and checks
   --                                        for error number 20054.
   -- 
   -- Called by:
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    06/25/01 prpbcb   Created.
   --    05/13/04 prpbcb   Modified to strip leading alpha characters in the
   --                      SUS door number.
   ---------------------------------------------------------------------------
   PROCEDURE update_erm_door_no(i_erm_id             IN  erm.erm_id%TYPE,
                                o_update_success_bln OUT BOOLEAN)
   IS

      l_door_no      erm.door_no%TYPE := NULL;     -- ERM door number
      l_fk_door_no   point_distance.point_a%TYPE;  -- Forklift door number
      l_object_name  VARCHAR2(30)     := 'update_erm_door_no';
      l_sqlerrm      VARCHAR2(500);                -- SQLERRM

      e_erm_id_not_found  EXCEPTION;
      e_po_locked         EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_po_locked, -54);

      CURSOR c_erm_door_no IS
         SELECT door_no
           FROM erm
          WHERE erm_id = i_erm_id
            FOR UPDATE NOWAIT;
   BEGIN
      -- Check that the parameter is not null.
      IF (i_erm_id IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- Get the erm door number.
      OPEN c_erm_door_no;
      FETCH c_erm_door_no INTO l_door_no;

      IF (c_erm_door_no%NOTFOUND) THEN
         -- Did not find i_erm_id in the erm table.
         CLOSE c_erm_door_no;
         RAISE e_erm_id_not_found;
      END IF;

      CLOSE c_erm_door_no;

      IF (l_door_no IS NOT NULL) THEN
         IF (pl_lmf.f_valid_fk_door_no(l_door_no)) THEN
            -- The erm.door_no is already a forklift door number.
            o_update_success_bln := TRUE;
         ELSE
            -- Get the forklift door number.
            -- Strip leading alpha characters in the SUS door number.
            l_fk_door_no :=
       pl_lmf.f_get_fk_door_no(LTRIM(l_door_no, 'ABCDEFGHIJKLMNOPQRZTUVWXYZ'));

            IF (l_fk_door_no IS NULL) THEN
              -- There is no corresponding forklift door number for the
              -- erm door number.
               o_update_success_bln := FALSE;
             ELSE
                 -- Update the erm.door_no to the forklift door number.
                 UPDATE erm
                    SET door_no = l_fk_door_no
                  WHERE erm_id = i_erm_id;

                  IF (SQL%FOUND) THEN
                     o_update_success_bln := TRUE;
                  ELSE
                     o_update_success_bln := FALSE;
                  END IF;
             END IF;
          END IF;
      ELSE 
         -- erm.door_no is null so it cannot be updated.
         o_update_success_bln := FALSE;
      END IF;     

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         RAISE_APPLICATION_ERROR(-20002, l_object_name ||
            ' i_erm_id is null.');

      WHEN e_erm_id_not_found THEN
         RAISE_APPLICATION_ERROR(-20003, l_object_name ||
            ' i_erm_id[' || i_erm_id || '] not found in ERM table.');

      WHEN e_po_locked THEN
         RAISE_APPLICATION_ERROR(-20054, l_object_name ||
            ' i_erm_id[' || i_erm_id || '] locked by another user.');

      WHEN OTHERS THEN
         l_sqlerrm := SQLERRM;          -- Save sqlerrm
         IF (c_erm_door_no%ISOPEN) THEN   -- Cursor cleanup
            CLOSE c_erm_door_no;
         END IF;
         RAISE_APPLICATION_ERROR(-20001, l_object_name ||
            ' i_erm_id['|| i_erm_id || '] Error: ' || l_sqlerrm);
   END update_erm_door_no;


   ------------------------------------------------------------------------
   -- Function:
   --    all_tasks_completed
   --
   -- Description:
   --    This function determines if all the tasks associated with a
   --    forklift labor mgmt batch are completed.  Returns a BOOLEAN.
   --
   --    If i_check_batch_only_bln is FALSE then the parent and all child
   --    batches are checked and if the parent or any child task is not done
   --    then FALSE is returned.
   --    If i_check_batch_only_bln is TRUE then only i_batch_no is checked.
   --
   --    Returns a BOOLEAN.
   --
   -- Parameters:
   --    i_batch_no - The forklift labor mgmt batch to check.
   --
   -- Return Value:
   --    TRUE   - All tasks for the batch are completed.
   --    FALSE  - All tasks for the batch are not completed.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    User defined exception   - A called object returned an user
   --                               defined error.
   --    pl_exc.e_data_error      - Parameter null, could not determine batch
   --                               type, unhandled batch type.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/15/03 prpbcb   Created.
   --                      It was created initially to determine if a demand
   --                      HST should suspend or complete the current batch.
   --                      This way the RF does not have to send a flag to
   --                      signify what to do which the RF is currently not
   --                      doing except for NDM's during putaway.
   --
   --    01/30/04 prpbcb   Changed function to handle a indirect batch.
   --                      The value returned will always be TRUE since
   --                      indirect batches are not merged.
   --
   --    04/13/05 prpbcb   Batch type HP was not being handled.
   --                      Also added handling of HX batch type.
   --
   --    08/02/05 prpbcb   Changed function to handle a DMD home slot
   --                      transfer batch.
   ------------------------------------------------------------------------
   FUNCTION all_tasks_completed
                (i_batch_no              IN arch_batch.batch_no%TYPE,
                 i_check_batch_only_bln  IN BOOLEAN DEFAULT FALSE)
   RETURN BOOLEAN
   IS
      l_message      VARCHAR2(256);    -- Message buffer
      l_object_name  VARCHAR2(30) := 'all_tasks_completed';

      l_batch_type   VARCHAR2(10);  -- The type of forklift labor
                                    -- batch.  Example:  FP, FN, etc.

      l_return_value_bln    BOOLEAN := FALSE;

      e_no_batch_type   EXCEPTION;   -- Could not determine what type of batch
                                     -- i_batch_no is.

      e_unhandled_batch_type  EXCEPTION;  -- The type of batch is not
                                          -- handled in this function.
   BEGIN
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      l_batch_type := pl_lmc.get_batch_type(i_batch_no);

      IF (l_batch_type IS NULL) THEN
         RAISE e_no_batch_type;  -- Do not know the type of batch.
      END IF;

      IF (l_batch_type = pl_lmc.ct_forklift_putaway) THEN
         l_return_value_bln := pl_lmf.all_putaway_completed
                                              (i_batch_no,
                                               i_check_batch_only_bln);

      ELSIF (l_batch_type = pl_lmc.ct_forklift_nondemand_rpl) THEN
         l_return_value_bln := pl_lmf.all_nondemand_rpl_completed
                                              (i_batch_no,
                                               i_check_batch_only_bln);

      ELSIF (l_batch_type = pl_lmc.ct_forklift_demand_rpl) THEN
         l_return_value_bln := pl_lmf.all_demand_rpl_completed
                                              (i_batch_no,
                                               i_check_batch_only_bln);

      ELSIF (l_batch_type = pl_lmc.ct_indirect) THEN
         l_return_value_bln := TRUE;

--    ELSIF (l_batch_type = pl_lmc.ct_forklift_transfer) THEN
--       l_return_value_bln := pl_lmf.all_transfer_completed(i_batch_no);
--
--    ELSIF (l_batch_type = pl_lmc.ct_forklift_pallet_pull) THEN
--       l_return_value_bln := pl_lmf.all_pallet_pull_completed(i_batch_no);
--
      ELSIF (l_batch_type = pl_lmc.ct_forklift_home_slot_xfer) THEN
         l_return_value_bln := pl_lmf.all_home_slot_xfer_completed(i_batch_no);

      ELSIF (l_batch_type = pl_lmc.ct_forklift_dmd_rpl_hs_xfer) THEN
        l_return_value_bln := pl_lmf.all_dmd_rpl_hs_xfer_completed
                                              (i_batch_no,
                                               i_check_batch_only_bln);
--
--
--    ELSIF (l_batch_type = pl_lmc.ct_forklift_drop_to_home) THEN
--       l_return_value_bln := pl_lmf.all_drop_to_home_completed(i_batch_no);
--
--    ELSIF (l_batch_type = pl_lmc.ct_forklift_inv_adj) THEN
--       l_return_value_bln := pl_lmf.all_inv_adj_completed(i_batch_no);
--
--    ELSIF (l_batch_type = pl_lmc.ct_forklift_swap) THEN
--       l_return_value_bln := pl_lmf.all_swap_completed(i_batch_no);
--
--    ELSIF (l_batch_type = pl_lmc.ct_forklift_combine_pull) THEN
--       l_return_value_bln := pl_lmf.all_combine_pull_completed(i_batch_no);
--
--    ELSIF (l_batch_type = pl_lmc.ct_forklift_cycle_count) THEN
--       l_return_value_bln := pl_lmf.all_cycle_count_completed(i_batch_no);
--
      ELSIF (l_batch_type = pl_lmc.ct_forklift_haul) THEN
         -- All the batches for a haul had to have been completed.
         l_return_value_bln := TRUE;

      ELSIF (l_batch_type = pl_lmc.ct_forklift_f1_haul) THEN
         -- All the batches for a func1 haul had to have been completed.
         l_return_value_bln := TRUE;

      ELSE
         -- Have an unhandled batch type.
         RAISE e_unhandled_batch_type;
      END IF;

      RETURN(l_return_value_bln);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_batch_no is null';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_no_batch_type THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
             '  Could not determine what type of batch it is.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_unhandled_batch_type THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
             '  Batch type[' || l_batch_type || ']' ||
             ' not handled in this function.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END all_tasks_completed;


   ------------------------------------------------------------------------
   -- Function:
   --    task_completed_for_batch
   --
   -- Description:
   --    This function determines if all the tasks associated with a
   --    forklift labor mgmt batch are completed.  Returns Y or N.
   --    It calls procedure all_tasks_completed() to do the work.
   --
   -- Parameters:
   --    i_batch_no - The forklift labor mgmt batch to check.
   --
   -- Return Value:
   --    Y   - The task for the batch is completed.
   --    N   - The task for the batch is not completed.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    User defined exception   - A called object returned an user
   --                               defined error.
   --    pl_exc.e_data_error      - Parameter null, could not determine batch
   --                               type, unhandled batch type.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/17/10 prpbcb   Created.
   ------------------------------------------------------------------------
   FUNCTION task_completed_for_batch
                (i_batch_no              IN arch_batch.batch_no%TYPE)
   RETURN VARCHAR2
   IS
      l_message      VARCHAR2(256);    -- Message buffer
      l_object_name  VARCHAR2(30) := 'task_completed_for_batch';

      l_return_value VARCHAR2(1);
   BEGIN
      IF (all_tasks_completed(i_batch_no, TRUE) = TRUE) THEN
         l_return_value := 'Y';
      ELSE
         l_return_value := 'N';
      END IF;

      RETURN(l_return_value);

   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
         RAISE;

   END task_completed_for_batch;


   ------------------------------------------------------------------------
   -- Function:
   --    all_putaway_completed
   --
   -- Description:
   --    This function determines if all the putaway tasks associated with a
   --    forklift labor mgmt batch are completed.
   --
   --    A pallet is considered putaway if there is not a putawaylst record
   --    with putaway put = N.
   --
   -- Parameters:
   --    i_batch_no - The forklift labor mgmt batch to check.
   --    i_check_batch_only_bln - If TRUE then check only the task for
   --                             i_batch_no.
   --                             If FALSE then check child batches too.
   --
   -- Return Value:
   --    TRUE   - All tasks for the batch are completed.
   --    FALSE  - All tasks for the batch are not completed.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter null, batch not a putaway batch.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/15/03 prpbcb   Created.
   ------------------------------------------------------------------------
   FUNCTION all_putaway_completed
                (i_batch_no              IN arch_batch.batch_no%TYPE,
                 i_check_batch_only_bln  IN BOOLEAN DEFAULT FALSE)
   RETURN BOOLEAN
   IS
      l_message      VARCHAR2(256);    -- Message buffer
      l_object_name  VARCHAR2(30) := 'all_putaway_completed';

      l_check_batch_only_flag  VARCHAR2(1);  -- Check only the task for
                                             -- i_batch_no or check child
                                             -- batches too.  Populated using
                                             -- i_check_batch_only_bln

      l_dummy             VARCHAR2(1);   -- Holding place.
      l_return_value_bln  BOOLEAN := FALSE;

      -- This cursor is used to determine if all the putaways for
      -- a batch are complete.
      CURSOR c_putaway_task(cp_batch_no               arch_batch.batch_no%TYPE,
                            cp_check_batch_only_flag  VARCHAR2) IS
         SELECT 'x'
           FROM putawaylst p, batch b
          WHERE (b.batch_no = cp_batch_no
                OR (cp_check_batch_only_flag = 'N' AND
                    b.parent_batch_no = cp_batch_no))
            AND p.pallet_id = b.ref_no
            AND putaway_put = 'N';

      e_not_putaway_batch EXCEPTION;  -- The batch is not a putaway batch.

   BEGIN
      --
      -- Check if parameter is null.
      --
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;


      --
      -- The batch has to be a putaway batch.
      --
      IF (pl_lmc.get_batch_type(i_batch_no) != pl_lmc.ct_forklift_putaway) THEN
         RAISE e_not_putaway_batch;
      END IF;

      --
      -- We need i_check_batch_only_bln represented as a character value
      -- so that it can be used in the cursor.
      --
      IF (i_check_batch_only_bln = TRUE) THEN
         l_check_batch_only_flag  := 'Y';
      ELSE
         l_check_batch_only_flag  := 'N';
      END IF;

      OPEN c_putaway_task(i_batch_no, l_check_batch_only_flag);
      FETCH c_putaway_task INTO l_dummy;
      IF (c_putaway_task%NOTFOUND) then
         l_return_value_bln := TRUE;
      ELSE
         l_return_value_bln := FALSE;
      END IF;
      CLOSE c_putaway_task;

      RETURN(l_return_value_bln);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_batch_no is null';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_not_putaway_batch THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
             '  The batch is not a putaway batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         IF (c_putaway_task%ISOPEN) THEN
            CLOSE c_putaway_task;
         END IF;

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END all_putaway_completed;


   ------------------------------------------------------------------------
   -- Function:
   --    all_nondemand_rpl_completed
   --
   -- Description:
   --    This function determines if all the non-demand replenishments tasks
   --    associated with a forklift labor mgmt batch are completed.
   --
   --    A task is considered completed if there is a RPL transaction
   --    for the pallet.
   --
   -- Parameters:
   --    i_batch_no - The forklift labor mgmt batch to check.
   --    i_check_batch_only_bln - If TRUE then check only the task for
   --                             i_batch_no.
   --                             If FALSE then check child batches too.
   --
   -- Return Value:
   --    TRUE   - All tasks for the batch are completed.
   --    FALSE  - All tasks for the batch are not completed.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter null, batch not a non-demand
   --                               batch.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/15/03 prpbcb   Created.
   ------------------------------------------------------------------------
   FUNCTION all_nondemand_rpl_completed
                (i_batch_no              IN arch_batch.batch_no%TYPE,
                 i_check_batch_only_bln  IN BOOLEAN DEFAULT FALSE)
   RETURN BOOLEAN
   IS
      l_message      VARCHAR2(256);    -- Message buffer
      l_object_name  VARCHAR2(30) := 'all_nondemand_rpl_completed';

      l_check_batch_only_flag  VARCHAR2(1);  -- Check only the task for
                                             -- i_batch_no or check child
                                             -- batches too.  Populated using
                                             -- i_check_batch_only_bln

      l_dummy             VARCHAR2(1);   -- Holding place.
      l_return_value_bln  BOOLEAN := FALSE;

      --
      -- This cursor is used to determine if all the non-demand replenishments
      -- for a batch are complete.
      -- If a record is found then all the tasks are not completed.
      --
      CURSOR c_ndm_task(cp_batch_no               arch_batch.batch_no%TYPE,
                        cp_check_batch_only_flag  VARCHAR2) IS
         SELECT 'x'
           FROM  batch b
          WHERE (   b.batch_no        = cp_batch_no
                 OR (cp_check_batch_only_flag = 'N' AND
                     b.parent_batch_no = cp_batch_no))
            AND NOT EXISTS
                   (SELECT 'x'
                      FROM trans t
                     WHERE t.labor_batch_no = b.batch_no
                       AND t.pallet_id = b.ref_no
                       AND t.trans_type = 'RPL');

      e_not_ndm_batch   EXCEPTION;  -- The batch is not a non-demand
                                    -- replenishment batch.

   BEGIN
      -- Check if parameter is null.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- The batch has to be a non-demand replenishment batch.
      IF (pl_lmc.get_batch_type(i_batch_no) !=
                                     pl_lmc.ct_forklift_nondemand_rpl) THEN
         RAISE e_not_ndm_batch;
      END IF;

      --
      -- We need i_check_batch_only_bln represented as a character value
      -- so that it can be used in the cursor.
      --
      IF (i_check_batch_only_bln = TRUE) THEN
         l_check_batch_only_flag  := 'Y';
      ELSE
         l_check_batch_only_flag  := 'N';
      END IF;

      OPEN c_ndm_task(i_batch_no, l_check_batch_only_flag );
      FETCH c_ndm_task INTO l_dummy;
      IF (c_ndm_task%NOTFOUND) then
         l_return_value_bln := TRUE;
      ELSE
         l_return_value_bln := FALSE;
      END IF;
      CLOSE c_ndm_task;

      RETURN(l_return_value_bln);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_batch_no is null';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_not_ndm_batch THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||

             '  The batch is not a non-demand replenishment batch.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         IF (c_ndm_task%ISOPEN) THEN
            CLOSE c_ndm_task;
         END IF;

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END all_nondemand_rpl_completed;


   ------------------------------------------------------------------------
   -- Function:
   --    all_demand_rpl_completed
   --
   -- Description:
   --    This function determines if all the demand replenishments tasks
   --    associated with a forklift labor mgmt batch are completed.
   --
   --    A task is considered complete if the DFK transaction exists.
   --
   -- Parameters:
   --    i_batch_no - The forklift labor mgmt batch to check.
   --    i_check_batch_only_bln - If TRUE then check only the task for
   --                             i_batch_no.
   --                             If FALSE then check child batches too.
   --
   -- Return Value:
   --    TRUE   - All tasks for the batch are completed.
   --    FALSE  - All tasks for the batch are not completed.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter null, batch not a non-demand
   --                               batch.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/15/03 prpbcb   Created.
   --    08/21/03 prpbcb   Changed to look for floats status = OPN instead
   --                      of floats status != DRP in determining if the
   --                      demand replenishments are finished.
   --                      When sending demand replenishments to RF the
   --                      status remains at PIK after the DMD is finished.
   --                      When using labels the status is set to DRP.
   ------------------------------------------------------------------------
   FUNCTION all_demand_rpl_completed
                (i_batch_no              IN arch_batch.batch_no%TYPE,
                 i_check_batch_only_bln  IN BOOLEAN DEFAULT FALSE)
   RETURN BOOLEAN
   IS
      l_message      VARCHAR2(256);    -- Message buffer
      l_object_name  VARCHAR2(30) := 'all_demand_rpl_completed';

      l_check_batch_only_flag  VARCHAR2(1);  -- Check only the task for
                                             -- i_batch_no or check child
                                             -- batches too.  Populated using
                                             -- i_check_batch_only_bln

      l_dummy             VARCHAR2(1);   -- Holding place.
      l_return_value_bln  BOOLEAN := FALSE;

      -- This cursor is used to determine if all the demand replenishments for
      -- a batch are complete.
      -- If a record is found then all the tasks are not completed.
      --
      CURSOR c_dmd_task(cp_batch_no               arch_batch.batch_no%TYPE,
                        cp_check_batch_only_flag  VARCHAR2) IS
         SELECT 'x'
           FROM  batch b
          WHERE (   b.batch_no        = cp_batch_no
                 OR (cp_check_batch_only_flag = 'N' AND
                     b.parent_batch_no = cp_batch_no))
            AND NOT EXISTS
                   (SELECT 'x'
                      FROM trans t
                     WHERE t.labor_batch_no = b.batch_no
                       AND t.pallet_id      = b.ref_no
                       AND t.trans_type     = 'DFK');

      e_not_dmd_batch   EXCEPTION;  -- The batch is not a demand
                                    -- replenishment batch.
   BEGIN
      -- Check if parameter is null.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- The batch has to be a demand replenishment batch.
      IF (pl_lmc.get_batch_type(i_batch_no) !=
                                     pl_lmc.ct_forklift_demand_rpl) THEN
         RAISE e_not_dmd_batch;
      END IF;

      --
      -- We need i_check_batch_only_bln represented as a character value
      -- so that it can be used in the cursor.
      --
      IF (i_check_batch_only_bln = TRUE) THEN
         l_check_batch_only_flag  := 'Y';
      ELSE
         l_check_batch_only_flag  := 'N';
      END IF;

      OPEN c_dmd_task(i_batch_no, l_check_batch_only_flag);
      FETCH c_dmd_task INTO l_dummy;
      IF (c_dmd_task%NOTFOUND) then
         l_return_value_bln := TRUE;
      ELSE
         l_return_value_bln := FALSE;
      END IF;
      CLOSE c_dmd_task;

      RETURN(l_return_value_bln);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_batch_no is null';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_not_dmd_batch THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
             '  The batch is not a demand replenishment batch.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);


         IF (c_dmd_task%ISOPEN) THEN
            CLOSE c_dmd_task;
         END IF;

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END all_demand_rpl_completed;


   ------------------------------------------------------------------------
   -- Function:
   --    all_home_slot_xfer_completed
   --
   -- Description:
   --    This function determines if all the home slot transfers tasks
   --    associated with a forklift labor mgmt home slot transfer batch
   --    are completed.
   --
   --    A task is considered completed if there is an HST transaction.
   --
   --    A home slot transfer cannot be a merged batch.
   --
   -- Parameters:
   --    i_batch_no - The forklift labor mgmt batch to check.
   --
   -- Return Value:
   --    TRUE   - All tasks for the batch are completed.
   --    FALSE  - All tasks for the batch are not completed.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter null, batch not a home slot
   --                               transfer batch.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/11/03 prpbcb   Created.
   --                      A home slot transfer cannot be a merged batch
   --                      so TRUE is always returned.
   ------------------------------------------------------------------------
   FUNCTION all_home_slot_xfer_completed
                (i_batch_no              IN arch_batch.batch_no%TYPE,
                 i_check_batch_only_bln  IN BOOLEAN DEFAULT FALSE)
   RETURN BOOLEAN
   IS
      l_message      VARCHAR2(256);    -- Message buffer
      l_object_name  VARCHAR2(30) := 'all_home_slot_xfer_completed';

      l_dummy             VARCHAR2(1);   -- Holding place.
      l_return_value_bln  BOOLEAN := FALSE;


      -- This cursor is used to determine if all the home slot tranfers for
      -- a batch are complete.
      CURSOR c_hst_task(cp_batch_no arch_batch.batch_no%TYPE) IS
         SELECT 'x'
           FROM trans t, batch b
          WHERE (b.batch_no = cp_batch_no
                OR b.parent_batch_no = cp_batch_no)
            AND t.trans_id = TO_NUMBER(SUBSTR(b.batch_no, 3));

      e_not_hst_batch   EXCEPTION;  -- The batch is not a home slot transfer
                                    -- batch.
   BEGIN
      -- Check if parameter is null.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- The batch has to be a home slot transfer batch.
      IF (pl_lmc.get_batch_type(i_batch_no) !=
                                     pl_lmc.ct_forklift_home_slot_xfer) THEN
         RAISE e_not_hst_batch;
      END IF;

      OPEN c_hst_task(i_batch_no);
      FETCH c_hst_task INTO l_dummy;
      IF (c_hst_task%FOUND) then
         l_return_value_bln := TRUE;
      ELSE
         l_return_value_bln := FALSE;
      END IF;
      CLOSE c_hst_task;

      RETURN(l_return_value_bln);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_batch_no is null';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_not_hst_batch THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
             '  The batch is not a home slot transfer batch.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);


         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END all_home_slot_xfer_completed;


   ------------------------------------------------------------------------
   -- Function:
   --    all_dmd_rpl_hs_xfer_completed
   --
   -- Description:
   --    This function determines if all the demand replenishment home slot
   --    transfers tasks associated with the forklift labor mgmt batch
   --    are completed.
   --
   --    A task is considered completed if there is an DHT transaction.
   --
   --    A home slot transfer cannot be a merged batch therefore there should
   --    only be one task.
   --
   -- Parameters:
   --    i_batch_no - The forklift labor mgmt batch to check.
   --
   -- Return Value:
   --    TRUE   - All tasks for the batch are completed.
   --    FALSE  - All tasks for the batch are not completed.
   --
   -- Called by:  (list may not be complete)
   --    - pl_lmf_all_tasks_completed
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter null, batch not a home slot
   --                               transfer batch.
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/02/05 prpbcb   Created.
   --                      A home slot transfer cannot be a merged batch
   --                      so TRUE is always returned.
   ------------------------------------------------------------------------
   FUNCTION all_dmd_rpl_hs_xfer_completed
                (i_batch_no              IN arch_batch.batch_no%TYPE,
                 i_check_batch_only_bln  IN BOOLEAN DEFAULT FALSE)
   RETURN BOOLEAN
   IS
      l_message      VARCHAR2(256);    -- Message buffer
      l_object_name  VARCHAR2(30) := 'all_dmd_rpl_hs_xfer_completed';

      l_dummy             VARCHAR2(1);   -- Holding place.
      l_return_value_bln  BOOLEAN := FALSE;

      -- This cursor is used to determine if all the demand replenishments
      -- home slot transfer for a batch are complete.
      -- If the cursor finds a record then all the tasks are not completed.
      CURSOR c_dmd_hst_task(cp_batch_no arch_batch.batch_no%TYPE) IS
         SELECT 'x'
           FROM batch b
          WHERE (   b.batch_no        = cp_batch_no
                 OR b.parent_batch_no = cp_batch_no)
            AND NOT EXISTS
                   (SELECT 'x'
                      FROM trans t
                     WHERE t.labor_batch_no = b.batch_no
                       AND t.trans_type     = 'DHT');

      e_not_dmd_hst_batch   EXCEPTION;  -- The batch is not a home slot transfer
                                    -- batch.
   BEGIN
      -- Check if parameter is null.
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- The batch has to be a demand replenishment home slot transfer batch.
      IF (pl_lmc.get_batch_type(i_batch_no) !=
                                     pl_lmc.ct_forklift_dmd_rpl_hs_xfer) THEN
         RAISE e_not_dmd_hst_batch;
      END IF;

      OPEN c_dmd_hst_task(i_batch_no);
      FETCH c_dmd_hst_task INTO l_dummy;
      IF (c_dmd_hst_task%FOUND) then
         l_return_value_bln := TRUE;
      ELSE
         l_return_value_bln := FALSE;
      END IF;
      CLOSE c_dmd_hst_task;

      RETURN(l_return_value_bln);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_batch_no is null';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_not_dmd_hst_batch THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
            '  The batch is not a demand replenishment home slot' ||                        ' transfer batch.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END all_dmd_rpl_hs_xfer_completed;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    update_xfr_batch
   --
   -- Description:
   --   This procedure updates the kvi_to_loc of a transfer batch using
   --   the dest loc in the trans table.  This happens when the transfer
   --   is completed.  At the start of the transfer the dest loc is unknown
   --   so the batch kvi_to_loc needs to get updated when the transfer is
   --   complete.
   --
   -- Parameters:
   --    i_trans      - The transaction id to used in getting the
   --                   labor mgmt batch in column labor_batch_no to update.
   --                   This should be for a XFR transaction.
   --    i_dest_loc   - The destination location to update the batch with.
   --
   -- Called by: (list may not be complete)
   --    - 
   --
   -- Exceptions raised:
   --    pl_exc.lm_batch_upd_fail  - Failed to update the batch.
   --    pl_exc.e_data_error       - Parameter is null.
   --    pl_exc.e_database_error   - Oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    11/10/03 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE update_xfr_batch(i_trans_id   IN  NUMBER,
                              i_dest_loc   IN  loc.logi_loc%TYPE)
   IS
      l_message         VARCHAR2(256);    -- Message buffer
      l_object_name     VARCHAR2(30) := 'update_xfr_batch';
      e_nothing_updated EXCEPTION;        -- No record was updated.
   BEGIN
      IF (i_trans_id IS NULL OR i_dest_loc IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      UPDATE batch
         SET kvi_to_loc = i_dest_loc
      WHERE batch_no = (SELECT labor_batch_no
                          FROM trans
                         WHERE trans_id = i_trans_id);

      IF (SQL%NOTFOUND) THEN
         RAISE e_nothing_updated;
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_trans_id[' || TO_CHAR(i_trans_id) ||
             '],i_dest_loc[' || i_dest_loc || ']) || A parameter is null.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN e_nothing_updated THEN
         l_message := l_object_name || '(i_trans_id[' || TO_CHAR(i_trans_id) ||
            '  ACTION=UPDATE  MESSAGE="No batch record updated.  Check' ||
            ' that the transaction exists, trans.labor_batch_no is not' ||
            ' null and the batch exists in the batch table."';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_batch_upd_fail, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_batch_upd_fail,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_trans_id[' || TO_CHAR(i_trans_id) ||
                      '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);

   END update_xfr_batch;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    make_batch_parent
   --
   -- Description:
   --   This function changes a normal batch to a parent batch.
   --
   -- Parameters:
   --    i_batch_no           - The batch to make a parent batch.
   --
   -- Called by: (list may not be complete)
   --    - 
   --
   -- Exceptions raised:
   --    pl_exc.lm_batch_upd_fail  - Failed to change the batch to a parent.
   --    pl_exc.e_data_error       - Parameter is null.
   --    pl_exc.e_database_error   - Oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    11/03/03 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE make_batch_parent(i_batch_no    IN arch_batch.batch_no%TYPE)
   IS
      l_message       VARCHAR2(256);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'make_batch_parent';

   BEGIN
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      UPDATE batch
         SET parent_batch_no = i_batch_no,
             parent_batch_date = TRUNC(SYSDATE)
       WHERE batch_no = i_batch_no;

      IF (SQL%NOTFOUND) THEN
         RAISE pl_exc.e_lm_batch_upd_fail;
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
                      '  Parameter i_batch_no is null.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN pl_exc.e_lm_batch_upd_fail THEN
         l_message := l_object_name || '  TABLE=batch KEY=[' || i_batch_no ||
           ']  ACTION=UPDATE  MESSAGE="Failed to make the batch a parent."';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_batch_upd_fail, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_batch_upd_fail,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END make_batch_parent;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    reset_batch
   --
   -- Description:
   --   This procedure resets a labor mgmt batch.
   --
   -- Parameters:
   --    i_batch_no      - The batch to reset.
   --    i_drop_location - Drop location if the batch being reset is a putaway
   --                      batch where the pallet was hauled.
   --
   -- Called by: (list may not be complete)
   --    - 
   --
   -- Exceptions raised:
   --    pl_exc.lm_batch_upd_fail  - Failed to change the batch to a parent.
   --    pl_exc.e_data_error       - Parameter is null.
   --    pl_exc.e_database_error   - Oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    11/03/03 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE reset_batch
               (i_batch_no      IN arch_batch.batch_no%TYPE,
                i_drop_location IN arch_batch.kvi_from_loc%TYPE DEFAULT NULL)
   IS
      l_message       VARCHAR2(256);    -- Message buffer
      l_object_name   VARCHAR2(30) := 'reset_batch';

   BEGIN
      IF (i_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      UPDATE batch
         SET status = 'F',
             user_id = NULL,
             user_supervsr_id = NULL,
             actl_start_time = NULL,
             actl_stop_time = NULL,
             actl_time_spent = NULL,
             parent_batch_no = NULL,
             parent_batch_date = NULL,
             equip_id = NULL,
             kvi_from_loc = NVL(i_drop_location, kvi_from_loc),
             total_count = 1,
             total_piece = 0,
             total_pallet = 1
       WHERE batch_no = i_batch_no;

      IF (SQL%NOTFOUND) THEN
         RAISE pl_exc.e_lm_batch_upd_fail;
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])' ||
                      '  Parameter i_batch_no is null.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN pl_exc.e_lm_batch_upd_fail THEN
         l_message := l_object_name || '  TABLE=batch KEY=[' || i_batch_no ||
           ']  ACTION=UPDATE  MESSAGE="Failed to reset the batch.  Verify' ||
           ' it is a valid batch."';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_batch_upd_fail, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_batch_upd_fail,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END reset_batch;

   ------------------------------------------------------------------------
   -- Function:
   --    f_create_haul_batch_id
   --
   -- Description:
   --    This function creates the batch number if for a haul created from
   --    a func1 during putaway.  The format of the batch number is
   --    <HX><seq#>
   --
   -- Parameters:
   --    None
   --
   -- Return Value:
   --    The HX haul batch number.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    11/12/03 prpbcb   Created for MSKU.
   --                      This is the package version of function
   --                      lmf_create_haul_batch_id in lm_forklift.pc
   ------------------------------------------------------------------------
   FUNCTION f_create_haul_batch_id
   RETURN arch_batch.batch_no%TYPE
   IS
      l_message      VARCHAR2(256);    -- Message buffer
      l_object_name  VARCHAR2(30) := 'f_create_haul_batch_id';

      l_return_value arch_batch.batch_no%TYPE;
   BEGIN
      SELECT pl_lmc.ct_forklift_f1_haul ||
                       LTRIM(RTRIM(TO_CHAR(pallet_batch_no_seq.NEXTVAL)))
       INTO l_return_value
       FROM DUAL;

      RETURN(l_return_value);

   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name;

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_create_haul_batch_id;


   ------------------------------------------------------------------------
   -- Function:
   --    f_create_ret_to_res_batch_id
   --
   -- Description:
   --    This function creates the batch number for the return of the MSKU
   --    to reserve after a NDM or DMD.
   --    The format of the batch number is <FM><seq#>.
   --
   -- Parameters:
   --    None
   --
   -- Return Value:
   --    The HX haul batch number.
   --
   -- Called by:  (list may not be complete)
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - A database error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    11/12/03 prpbcb   Created for MSKU.
   --                      This is the package version of function
   --                      lmf_create_haul_batch_id in lm_forklift.pc
   ------------------------------------------------------------------------
   FUNCTION f_create_ret_to_res_batch_id
   RETURN arch_batch.batch_no%TYPE
   IS
      l_message      VARCHAR2(256);    -- Message buffer
      l_object_name  VARCHAR2(30) := 'f_create_ret_to_res_batch_id';

      l_return_value arch_batch.batch_no%TYPE;
   BEGIN
      SELECT pl_lmc.ct_forklift_msku_ret_to_res ||
                       LTRIM(RTRIM(TO_CHAR(pallet_batch_no_seq.NEXTVAL)))
       INTO l_return_value
       FROM DUAL;

      RETURN(l_return_value);

   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name;

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_create_ret_to_res_batch_id;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    create_returns_putaway_batches
   --
   -- Description:
   --    This procedure creates the returns putaway labor mgmt batches.
   --
   --    Returns putaway is very similar to a RDC MSKU.  Returns are
   --    accumulated on a physical pallet until the pallet reaches a
   --    designated cube limit.  A LP is created for each item returned and
   --    the LP can have more than one case.  The returns processing will tie
   --    the putaway tasks together by the parent pallet id which will be
   --    the "T" batch number.
   --
   --    One scan is made to initiate the returns putaway.  The returns putaway
   --    labor mgmt batches will be created then merged at this time.
   --
   --    Returns will be considered a MSKU even if there is only one case.
   --
   --    The batch.kvi_from_loc is populated from the "T" batch kvi_from_loc.
   --    The returns processing will populate the "T" batch kvi_from_loc
   --    with the staging location setup in the Palletized Returns Control
   --    LR1SA screen.  The "T" batch number is in the
   --    putawaylst.parent_pallet_id column.
   --
   -- Parameters:
   --    i_pallet_id          - The pallet id of the return.
   --    i_force_creation_bln - Designates if to ignore the labor mgmt active
   --                           flags.  Usually this should be FALSE.  Can be
   --                           useful in testing.
   --    o_batch_no           - Batch number created for i_pallet_id.  The
   --                           calling object may need to know this so it is
   --                           passed back.
   --                           Many batch records will be created but only one
   --                           batch number needs to be returned.
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null.
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Called by:
   --    - pre_putaway.pc
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/05/04 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE create_returns_putaway_batches
            (i_pallet_id          IN  putawaylst.pallet_id%TYPE,
             i_force_creation_bln IN  BOOLEAN DEFAULT FALSE,
             o_batch_no           OUT arch_batch.batch_no%TYPE)
   IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_object_name    VARCHAR2(30) := 'create_returns_putaway_batches';

      l_r_stats       pl_lmf.t_create_putaway_stats_rec;  -- Batch count
                                                          -- statistics.
      l_r_total_stats pl_lmf.t_create_putaway_stats_rec;  -- Total batch count
                                                          -- statistics.

      -- This cursor selects all pallets on the parent pallet for the
      -- designated child pallet.
      --
      -- The batch.kvi_from_loc is selected for the "T" batch to use for the
      -- kvi_from_loc for the putaway batches.  The putawaylst.parent_pallet_id
      -- has the "T" batch number.
      CURSOR c_putaway(cp_pallet_id  putawaylst.pallet_id%TYPE) IS
         SELECT p.pallet_id, p.dest_loc, b.kvi_from_loc
           FROM batch b, putawaylst p
          WHERE b.batch_no = p.parent_pallet_id
            AND p.parent_pallet_id IN
                    (SELECT p2.parent_pallet_id
                       FROM putawaylst p2
                      WHERE p2.pallet_id = cp_pallet_id);

      e_pallet_batch_no_null EXCEPTION;  -- The putawaylst.pallet_batch_no is
                                         -- null for pallet i_pallet_id.
                                         -- It should have been updated to the
                                         -- returns putaway labor mgmt batch#
                                         -- when the batches were created.
   BEGIN
      IF (i_pallet_id IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

     -- Returns labor mgmt needs to be active to create the batches.
     IF (   f_is_returns_putaway_active = TRUE
         OR i_force_creation_bln = TRUE) THEN
         -- Created a returns putaway labor mgmt batch for each child LP on the
         -- parent LP.

         -- Log a message.
         l_message := l_object_name ||
                      '(i_pallet_id[' || i_pallet_id || ']' ||
                      ',i_force_creation_bln[' ||
                      f_boolean_text(i_force_creation_bln) || ']' ||
                      ',o_batch_no)';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         FOR r_putaway IN c_putaway(i_pallet_id) LOOP
            create_msku_putaway_batches
                        (i_create_for_what        => 'LP',
                         i_key_value              => r_putaway.pallet_id,
                         i_dest_loc               => r_putaway.dest_loc,
                         i_kvi_from_loc           => r_putaway.kvi_from_loc,
                         o_r_create_putaway_stats => l_r_stats);

            l_r_total_stats.no_records_processed :=
                                         l_r_total_stats.no_records_processed +
                                         l_r_stats.no_records_processed;

            l_r_total_stats.no_batches_created :=
                                          l_r_total_stats.no_batches_created +
                                          l_r_stats.no_batches_created;

            l_r_total_stats.no_batches_existing :=
                                          l_r_total_stats.no_batches_existing +
                                          l_r_stats.no_batches_existing;

            l_r_total_stats.no_not_created_due_to_error :=
                                   l_r_total_stats.no_not_created_due_to_error +
                                   l_r_stats.no_not_created_due_to_error;
         END LOOP;

         l_message :=
            'Created returns putaway labor mgmt batches for child pallet [' ||
            i_pallet_id || '].' ||
            '  #records processed[' ||
            TO_CHAR(l_r_total_stats.no_records_processed) || ']' ||
            '  #batches created[' ||
            TO_CHAR(l_r_total_stats.no_batches_created) || ']' ||
            '  #batches already existing[' ||
            TO_CHAR(l_r_total_stats.no_batches_existing) || ']' ||
            '  #batches not created because of error[' ||
            TO_CHAR(l_r_total_stats.no_not_created_due_to_error) || ']' ||
            '  #tasks with no location[' ||
            TO_CHAR(l_r_total_stats.no_with_no_location) || ']';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);


         -- Get the batch number created for i_pallet_id and return it back.
         -- The putawaylst record gets updated with the batch number so get it
         -- from there.
         -- Start a new block.
         BEGIN
            SELECT pallet_batch_no INTO o_batch_no
              FROM putawaylst
             WHERE pallet_id = i_pallet_id;

            IF (o_batch_no IS NULL) THEN
               l_message := 'TABLE=putawaylst  ACTION=SELECT' ||
                  '  KEY=[' || i_pallet_id || '](i_pallet_id)' ||
                  '  MESSAGE=pallet_batch_no selected is null.';

               pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                              l_message, pl_exc.ct_data_error, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

               RAISE e_pallet_batch_no_null;
            END IF;

            -- Log a message.
            l_message :=  'o_batch_no[' || o_batch_no || ']';
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                           NULL, NULL,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               l_message := 'TABLE=putawaylst  ACTION=SELECT' ||
                            '  KEY=[' || i_pallet_id || '](i_pallet_id)' ||
                            '  MESSAGE=Did not find the pallet.';
               pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                              l_message, pl_exc.ct_data_error, NULL,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

               RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
         END;

      END IF; -- End is returns putaway labor mgmt active.

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_pallet_id[' || i_pallet_id || '])' ||
                      '  Parameter i_pallet_id is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN e_pallet_batch_no_null THEN
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            l_message := l_object_name ||
                         '(i_pallet_id[' || i_pallet_id || '])'||
                         '  Called object raised an user defined exception.';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            RAISE;
         ELSE
            l_message := l_object_name || '(i_pallet_id[' || i_pallet_id || ']';

            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END create_returns_putaway_batches;

    PROCEDURE create_pallet_pull_batch (
            i_float_no  IN  floats.float_no%TYPE,
            o_error     OUT BOOLEAN)
    IS
    /*
            o_no_records_processed      OUT PLS_INTEGER,
            o_no_batches_created        OUT PLS_INTEGER,
            o_no_batches_existing       OUT PLS_INTEGER,
            o_no_not_created_due_to_error   OUT PLS_INTEGER)
    */
        CURSOR  c_tot (p_float_no   NUMBER) IS
            SELECT  (SUM(fd.qty_alloc) / pm.spc) * pm.case_cube l_case_cube,
                SUM(fd.qty_alloc) * NVL(pm.g_weight, 0) l_weight,
                fd.src_loc l_src_loc,
                COUNT(fd.float_no) l_count
              FROM  pm, float_detail fd, floats f
             WHERE  pm.prod_id = fd.prod_id
               AND  pm.cust_pref_vendor = fd.cust_pref_vendor
               AND  fd.float_no = f.float_no
               AND  f.float_no = TO_NUMBER(p_float_no)
              GROUP BY pm.spc, pm.case_cube, pm.g_weight, fd.src_loc;

        r_tot   c_tot%ROWTYPE;
    BEGIN
        o_error := FALSE;
        OPEN    c_tot (i_float_no);
        FETCH   c_tot INTO r_tot;
        IF (c_tot%FOUND) THEN
        BEGIN
            BEGIN
                INSERT INTO batch(batch_no,
                    jbcd_job_code,
                    status,
                    batch_date,
                    kvi_from_loc,
                    kvi_to_loc,
                    kvi_no_case,
                    kvi_no_split,
                    kvi_no_pallet,
                    kvi_no_item,
                    kvi_no_po,
                    kvi_cube,
                    kvi_wt,
                    kvi_no_loc,
                    total_count, 
                    total_piece,
                    total_pallet,
                    ref_no,
                    kvi_distance,
                    goal_time,
                    target_time,
                    no_breaks,
                    no_lunches,
                    kvi_doc_time,
                    kvi_no_piece,
                    kvi_no_data_capture)
                SELECT  pl_lmc.ct_forklift_drop_to_home || i_float_no,
                    fk.drophome_jobcode,
                    'F', TRUNC(SYSDATE),
                    fd.src_loc,
                    f.home_slot,
                    0.0,
                    0.0,
                    1.0,
                    1.0,
                    0.0,
                    (f.drop_qty/NVL(pm.spc,1))*pm.case_cube,
                    (f.drop_qty * NVL(pm.g_weight, 0)),
                    1.0,
                    1.0, 
                    (f.drop_qty / NVL(pm.spc,1)), 
                    1.0,
                    f.pallet_id,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    1.0,
                    0.0,
                    2.0
                  FROM  job_code j, fk_area_jobcodes fk,
                    swms_sub_areas ssa, aisle_info ai,
                    pm, float_detail fd, floats f
                 WHERE  j.jbcd_job_code = fk.drophome_jobcode
                   AND  fk.sub_area_code = ssa.sub_area_code
                   AND  ssa.sub_area_code = ai.sub_area_code
                   AND  ai.name = SUBSTR(f.home_slot, 1, 2)
                   AND  pm.prod_id = fd.prod_id
                   AND  pm.cust_pref_vendor = fd.cust_pref_vendor
                   AND  fd.float_no = f.float_no
                   AND  f.pallet_pull IN ('D', 'B', 'Y')
                   AND  f.float_no = TO_NUMBER (i_float_no)
                   AND  NVL(f.drop_qty, 0) > 0
                   AND  ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN NULL;
            END;

            INSERT INTO batch
                (batch_no,
                jbcd_job_code,
                status,
                batch_date,
                kvi_from_loc,
                kvi_to_loc,
                kvi_no_case,
                kvi_no_split,
                kvi_no_pallet,
                kvi_no_item,
                kvi_no_po,
                kvi_cube,
                kvi_wt,
                kvi_no_loc,
                total_count,
                total_piece,
                total_pallet,
                ref_no,
                kvi_distance,
                goal_time,
                target_time,
                no_breaks,
                no_lunches,
                kvi_doc_time,
                kvi_no_piece,
                kvi_no_data_capture)
            SELECT  DECODE (f.pallet_pull, 'Y', pl_lmc.ct_forklift_combine_pull,
                    pl_lmc.ct_forklift_pallet_pull) || i_float_no,
                fk.palpull_jobcode,
                'F',
                TRUNC(SYSDATE),
                f.home_slot,
                pl_lmc.f_get_destination_door_no (i_float_no),
                0.0,
                0.0, 
                1.0,
                1.0,
                0.0,
                r_tot.l_case_cube,
                r_tot.l_weight,
                1.0,
                1.0,
                0.0,
                1.0,
                f.pallet_id,
                1.0,
                0.0,
                0.0,
                0.0,
                0.0,
                1.0,
                0.0,
                2.0
              FROM  job_code j, fk_area_jobcodes fk,
                swms_sub_areas ssa, aisle_info ai,
                route r, floats f
             WHERE  j.jbcd_job_code = fk.palpull_jobcode
               AND  fk.sub_area_code = ssa.sub_area_code
               AND  ssa.sub_area_code = ai.sub_area_code
               AND  ai.name = SUBSTR (r_tot.l_src_loc, 1, 2)
               AND  r.route_no = f.route_no
               AND  f.pallet_pull IN ('D', 'B', 'Y')
               AND  f.float_no = TO_NUMBER (i_float_no);
        END;
        ELSE
            o_error := TRUE;
        END IF;
        CLOSE c_tot;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
            WHEN OTHERS THEN
                o_error := TRUE;
    END;

---------------------------------------------------------------------------
-- Procedure:
--    get_new_batch
--
-- Description:
--    This procedure finds the 'N' status batch for a user.  This is the
--    batch the user is in the process of signing onto.  If no batch is
--    found then o_batch_no is set to null.  The procedure is used in the
--    batch completion processing.
--
--    When the user goes to his next task the labor batch he is currently
--    active on is completed.  Part of this completion process is to set the
--    status of the batch the using is signing onto to N to temporarily flag
--    the batch.  At the end of the batch completion process the status will
--    be changed from N to A.
--
--    A user should have only one 'N' status batch and the N status only
--    exists during a batch completion process.  You should never see a
--    N status batch in the current batches screen.  If there is a failure
--    in the batch completion process a rollback is made so the N status
--    is never committed.
--
-- Parameters:
--    i_user_id
--    o_batch_no      - The labor batch with 'N' status.
--    o_kvi_from_loc  - The kvi_from_loc for o_batch_no.
--    o_kvi_to_loc    - The kvi_to_loc for o_batch_no.
--
-- Called By:
--    pl_lmd.get_next_point
--  
-- Exceptions raised:
--    pl_exc.e_dataerror       - A parameter is null.
--    pl_exc.e_database_error  - Got an oracle error.
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/01/10 prpbcb   Created.
--                      Called by procedure pl_lmd.get_next_point() to get
--                      the N status batch its kvi_from_loc and kvi_to_loc.
--                      If in the future we need to return more info about
--                      the batch then we can return a record.
---------------------------------------------------------------------------
PROCEDURE get_new_batch
                (i_user_id        IN  arch_batch.user_id%TYPE,
                 o_batch_no       OUT arch_batch.batch_no%TYPE,
                 o_kvi_from_loc   OUT arch_batch.kvi_from_loc%TYPE,
                 o_kvi_to_loc     OUT arch_batch.kvi_to_loc%TYPE)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30)  := 'get_new_batch';
BEGIN
   --
   -- Check for null parameters.
   --
   IF (i_user_id IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   BEGIN
      SELECT batch_no,
             kvi_from_loc,
             kvi_to_loc
        INTO o_batch_no,
             o_kvi_from_loc,
             o_kvi_to_loc
        FROM batch
       WHERE status = 'N'
         AND user_id = i_user_id;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        o_batch_no := NULL;
   END;

EXCEPTION
   WHEN gl_e_parameter_null THEN
      l_message := gl_pkg_name || '.' || l_object_name
             || '(i_user_id[' || i_user_id || '],'
             || 'o_batch_no,o_kvi_from_loc,o_kvi_to_loc)'
             || '  An input parameter is null.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     l_message, pl_exc.ct_data_error,
                     NULL, ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

   WHEN OTHERS THEN
      l_message := gl_pkg_name || '.' || l_object_name
             || '(i_user_id[' || i_user_id || '],'
             || 'o_batch_no,o_kvi_from_loc,o_kvi_to_loc)';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     l_message, SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END get_new_batch;


---------------------------------------------------------------------------
-- Procedure:
--    get_suspended_batch
--
-- Description:
--    This procedure finds the last suspended batch for a user.
--    If no batch is found then o_batch_no is set to null.
--
--    When the user goes to his next task the labor batch he is currently
--    active on is completed.  Part of this completion process is to set the
--    status of the batch the using is signing onto to N to temporarily flag
--    the batch.  At the end of the batch completion process the status will
--    be changed from N to A.
--
--    A user should have only one 'N' status batch and the N status only
--    exists during a batch completion process.  You should never see a
--    N status batch in the current batches screen.  If there is a failure
--    in the batch completion process a rollback is made so the N status
--    is never committed.
--
-- Parameters:
--    i_user_id
--    o_batch_no      - The last suspended batch for the user.
--    o_kvi_from_loc  - The kvi_from_loc for o_batch_no.
--    o_kvi_to_loc    - The kvi_to_loc for o_batch_no.
--
-- Called By:
--    pl_lmd.get_next_point
--  
-- Exceptions raised:
--    pl_exc.e_dataerror       - A parameter is null.
--    pl_exc.e_database_error  - Got an oracle error.
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/01/10 prpbcb   Created.
--                      Called by procedure pl_lmd.get_next_point() to get
--                      the N status batch its kvi_from_loc and kvi_to_loc.
--                      If in the future we need to return more info about
--                      the batch then we can return a record.
--                      This is a PL/SQL version of function
--                      lmf_find_suspended_batch() in lm_forklift.pc
---------------------------------------------------------------------------
PROCEDURE get_suspended_batch
                (i_user_id        IN  arch_batch.user_id%TYPE,
                 o_batch_no       OUT arch_batch.batch_no%TYPE,
                 o_kvi_from_loc   OUT arch_batch.kvi_from_loc%TYPE,
                 o_kvi_to_loc     OUT arch_batch.kvi_to_loc%TYPE)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30)  := 'get_suspended_batch';

   CURSOR c_suspended_batch(cp_user_id  arch_batch.user_id%TYPE) IS
       SELECT batch_no, kvi_from_loc, kvi_to_loc
            FROM batch
           WHERE status = 'W'
             AND user_id = cp_user_id
           ORDER BY actl_start_time DESC;  -- Get the latest suspended batch
BEGIN
   --
   -- Check for null parameters.
   --
   IF (i_user_id IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   OPEN c_suspended_batch(i_user_id);
   FETCH c_suspended_batch INTO o_batch_no,
                                o_kvi_from_loc,
                                o_kvi_to_loc;

   IF (c_suspended_batch%NOTFOUND) THEN
      o_batch_no := NULL;
   END IF;

   CLOSE c_suspended_batch;

EXCEPTION
   WHEN gl_e_parameter_null THEN
      l_message := gl_pkg_name || '.' || l_object_name
             || '(i_user_id[' || i_user_id || '],'
             || 'o_batch_no,o_kvi_from_loc,o_kvi_to_loc)'
             || '  An input parameter is null.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     l_message, pl_exc.ct_data_error,
                     NULL, ct_application_function,  gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

   WHEN OTHERS THEN
      l_message := gl_pkg_name || '.' || l_object_name
             || '(i_user_id[' || i_user_id || '],'
             || 'o_batch_no,o_kvi_from_loc,o_kvi_to_loc)';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     l_message, SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END get_suspended_batch;

/*------------------------------------------------------------------------------------------
-- create_swap_batch()
--
-- Description: Creates a LM batch for a given swap task in replenlst. The batch is 
--              inserted into the batch table and the labor_batch_no in replenlst
--              is updated with the created batch#. Batch# = 'FS' + task ID.
--
-- Parameters: i_task_id: task id in replenlst for the swap.
--             i_src_loc: src loc (for verification purposes).
--             i_dest_loc: dest loc (for verification purposes).
--             o_no_batches_created: ouput to caller; 1 if batch created. 0 otherwise.
--
-- Modification History:
--
--   Date          Developer     Comment
--   --------------------------------------------------------------------------------------
--   28-Apr-2021   pkab6563      Created
--
--------------------------------------------------------------------------------------------*/
PROCEDURE create_swap_batch
                (i_task_id                      IN  replenlst.task_id%TYPE,
                 i_src_loc                      IN  replenlst.src_loc%TYPE,
                 i_dest_loc                     IN  replenlst.dest_loc%TYPE,
                 o_no_batches_created           OUT PLS_INTEGER)
IS

    l_object_name CONSTANT         swms_log.procedure_name%TYPE := 'create_swap_batch';
    l_msg                          swms_log.msg_text%TYPE;
    e_bad_parameter_data           EXCEPTION; -- passed in parameter data is inconsistent
    e_invalid_task_id              EXCEPTION; -- task ID not found
    e_batch_already_exists         EXCEPTION; -- batch already exists
    l_rows_inserted                PLS_INTEGER;
    l_rows_updated                 PLS_INTEGER;
    l_batch_cnt                    PLS_INTEGER;
    l_src_loc                      replenlst.src_loc%TYPE;
    l_dest_loc                     replenlst.dest_loc%TYPE;
    l_type                         replenlst.type%TYPE;
    l_seq_no                       NUMBER;
    l_batch_no                     batch.batch_no%TYPE;
    l_qty                          replenlst.qty%TYPE;
    l_ref_no                       batch.ref_no%TYPE;

BEGIN

    l_msg := 'Starting create_swap_batch(). i_task_id ['
          || i_task_id
          || '] i_src_loc ['
          || i_src_loc
          || '] i_dest_loc ['
          || i_dest_loc
          || ']';
    pl_log.ins_msg('INFO', l_object_name, l_msg, null, null, ct_application_function, gl_pkg_name); 

    -- Initialize the out param

    o_no_batches_created := 0;

    -- Validate passed in data
    BEGIN
        SELECT nvl(src_loc, 'X'), nvl(dest_loc, 'X'), type, nvl(qty, 0)
        INTO   l_src_loc, l_dest_loc, l_type, l_qty
        FROM   replenlst
        WHERE  task_id = i_task_id;
    
        IF l_type != 'SWP' THEN
            raise e_invalid_task_id;
        END IF;
        
        IF l_src_loc = 'X' OR l_dest_loc = 'X' OR l_src_loc != i_src_loc OR l_dest_loc != i_dest_loc THEN
            raise e_bad_parameter_data;
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN            
            raise e_invalid_task_id;
        
        WHEN OTHERS THEN             
            raise;
          
    END; -- validate passed in data

    -- ref_no
    l_ref_no := i_src_loc || '->' || i_dest_loc;

    -- Build the batch#
    -- batch# = concatenation of FS + task_id.

    l_batch_no := pl_lmc.ct_forklift_swap || TO_CHAR(i_task_id);  

    -- Does the batch already exist?

    SELECT COUNT(*) INTO l_batch_cnt
    FROM   batch
    WHERE  batch_no = l_batch_no;
        
    IF l_batch_cnt > 0 THEN
        raise e_batch_already_exists;
    END IF; -- does the batch already exist?

    BEGIN  -- insert the batch record
        INSERT INTO batch(batch_no,
                          jbcd_job_code,
                          status,
                          batch_date,
                          kvi_from_loc,
                          kvi_to_loc,
                          kvi_no_case,
                          kvi_no_split,
                          kvi_no_pallet,
                          kvi_no_item,
                          kvi_no_po,
                          kvi_cube,
                          kvi_wt,
                          kvi_no_loc,
                          total_count,
                          total_piece,
                          total_pallet,
                          ref_no,
                          kvi_distance,
                          goal_time,
                          target_time,
                          no_breaks,
                          no_lunches,
                          kvi_doc_time,
                          kvi_no_piece, 
                          kvi_no_data_capture)
        SELECT l_batch_no          batch_no,
               fk.swap_jobcode     jbcd_job_code,
               'F'                 status,
               TRUNC(SYSDATE)      batch_date,
               i_src_loc           kvi_from_loc,
               i_dest_loc          kvi_to_loc,
               0.0                 kvi_no_case,
               0.0                 kvi_no_split, 
               1.0                 kvi_no_pallet,
               1.0                 kvi_no_item,
               1.0                 kvi_no_po,
               TRUNC((l_qty / pm.spc) * pm.case_cube)  kvi_cube,
               TRUNC(l_qty * NVL(pm.g_weight, 0))      kvi_wt,
               1.0                 kvi_no_loc,
               1                   total_count,
               0                   total_piece,
               1                   total_pallet,
               l_ref_no            ref_no,
               0.0                 kvi_distance,
               0.0                 goal_time,
               0.0                 target_time,
               0.0                 no_breaks,
               0.0                 no_lunches,
               1.0                 kvi_doc_time,
               0.0                 kvi_no_piece,
               2.0                 kvi_no_data_capture
          FROM job_code j,
               fk_area_jobcodes fk,
               swms_sub_areas ssa,
               aisle_info ai,
               pm,                   
               replenlst rp
         WHERE j.jbcd_job_code     = fk.swap_jobcode
           AND fk.sub_area_code    = ssa.sub_area_code
           AND ssa.sub_area_code   = ai.sub_area_code
           AND ai.name             = SUBSTR(i_src_loc, 1, 2)
           AND pm.prod_id          = rp.prod_id
           AND pm.cust_pref_vendor = rp.cust_pref_vendor               
           AND rp.task_id          = i_task_id;

        l_rows_inserted := sql%rowcount;
        IF l_rows_inserted = 1 THEN
            BEGIN -- update replenlst record with batch#

                UPDATE replenlst
                SET    labor_batch_no = l_batch_no
                WHERE  task_id = i_task_id;

                l_rows_updated := sql%rowcount;
                IF l_rows_updated = 1 THEN
                    -- all successful. set out param.

                    o_no_batches_created := 1;

                    l_msg := 'Batch successfully created and replenlst updated for task ID ['
                          || i_task_id
                          || '] l_batch_no ['
                          || l_batch_no
                          || ']';
                    pl_log.ins_msg('INFO', l_object_name, l_msg, null, null, ct_application_function, gl_pkg_name);
                ELSE
                    ROLLBACK;
                    l_msg := 'Batch successfully created but NO replenlst row was updated for task ID ['
                          || i_task_id
                          || '] l_batch_no ['
                          || l_batch_no
                          || ']. Batch creation has been rolled back.';
                    pl_log.ins_msg('INFO', l_object_name, l_msg, null, null, ct_application_function, gl_pkg_name);
                END IF;
     
            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK;
                    l_msg := 'Update of replenlst.labor_batch_no FAILED for task ID ['
                          || i_task_id
                          || '] l_batch_no ['
                          || l_batch_no
                          || ']. Batch creation has been rolled back.';
                    pl_log.ins_msg('INFO', l_object_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), ct_application_function, gl_pkg_name);
                    raise;

            END; -- update replenlst record with batch#
        END IF; -- if l_rows_inserted = 1      
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            l_msg := 'Insert into batch table FAILED for task ID ['
                  || i_task_id
                  || '] l_batch_no ['
                  || l_batch_no
                  || ']';
            pl_log.ins_msg('INFO', l_object_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), ct_application_function, gl_pkg_name);
            raise;

    END; -- insert batch record

    pl_log.ins_msg('INFO', l_object_name, 'Ending create_swap_batch()', null, null, ct_application_function, gl_pkg_name); 

EXCEPTION
    WHEN e_bad_parameter_data THEN
        l_msg := 'Data passed in for task ID ['
              || i_task_id
              || '] does not match data in replenlst.';
        pl_log.ins_msg('INFO', l_object_name, l_msg, null, null, ct_application_function, gl_pkg_name);

    WHEN e_invalid_task_id THEN
        l_msg := 'No data found in replenlst for task ID ['
              || i_task_id
              || ']; or found data is not for swap (i.e. type SWP).';
        pl_log.ins_msg('INFO', l_object_name, l_msg, null, null, ct_application_function, gl_pkg_name);
    
    WHEN e_batch_already_exists THEN
        l_msg := 'Batch already exists in batch table for task ID ['
              || i_task_id
              || ']. l_batch_no ['
              || l_batch_no
              || ']';
        pl_log.ins_msg('INFO', l_object_name, l_msg, null, null, ct_application_function, gl_pkg_name);

    WHEN OTHERS THEN
        l_msg := 'Unexpected ERROR while trying to create the SWAP LM batch for task ID ['
              || i_task_id
              || ']';
        pl_log.ins_msg('INFO', l_object_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), ct_application_function, gl_pkg_name);

END create_swap_batch;

/*--------------------------------------------------------------------------------------------
-- delete_swap_batch()
--
-- Description: Deletes a given swap batch. Intended caller is the form that creates the
--              swaps. User of the form can create and delete swaps. When a swap is deleted
--              from the form, the corresponding LM batch is deleted through a call to this
--              procedure.
--
-- Parameters: i_batch_no: batch to delete.
--             o_no_batches_deleted: output to caller; 1 if the batch was deleted; 
--                                   0 otherwise.
--
-- Modification History:
--
--   Date          Developer     Comment
--   ----------------------------------------------------------------------------------------
--   29-Apr-2021   pkab6563      Created
--
----------------------------------------------------------------------------------------------*/
PROCEDURE delete_swap_batch
                (i_batch_no            IN   batch.batch_no%TYPE,
                 o_no_batches_deleted  OUT  PLS_INTEGER)
IS

    l_object_name CONSTANT  swms_log.procedure_name%TYPE := 'delete_swap_batch';
    l_msg                   swms_log.msg_text%TYPE;
    l_status                batch.status%TYPE;
    e_invalid_batch_no      EXCEPTION;
    replenlst_cnt           PLS_INTEGER;

BEGIN
    l_msg := 'Starting delete_swap_batch(). i_batch_no ['
          || i_batch_no
          || ']';
    pl_log.ins_msg('INFO', l_object_name, l_msg, null, null, ct_application_function, gl_pkg_name); 

    -- Initialize out param
    o_no_batches_deleted := 0;

    -- ensure batch is for swap
    IF i_batch_no IS NULL OR SUBSTR(i_batch_no, 1, 2) != pl_lmc.ct_forklift_swap THEN
        raise e_invalid_batch_no;
    END IF;

    -- delete the batch if it is in F status
    DELETE 
    FROM batch
    WHERE batch_no = i_batch_no
      AND status = 'F';
    
    IF sql%rowcount > 0 THEN
        o_no_batches_deleted := 1;
        l_msg := 'Batch ['
              || i_batch_no
              || '] successfully deleted.';
        pl_log.ins_msg('INFO', l_object_name, l_msg, null, null, ct_application_function, gl_pkg_name);                
    ELSE
        BEGIN
            SELECT status INTO l_status
            FROM   batch
            WHERE  batch_no = i_batch_no;
        
            l_msg := 'Batch NOT DELETED because its status is ['
                  || l_status
                  || ']';
            pl_log.ins_msg('INFO', l_object_name, l_msg, null, null, ct_application_function, gl_pkg_name);
        
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_msg := 'Batch ['
                      || i_batch_no
                      || '] NOT FOUND.';
                pl_log.ins_msg('INFO', l_object_name, l_msg, null, null, ct_application_function, gl_pkg_name);                
                
            WHEN OTHERS THEN
                l_msg := 'Unexpected ERROR during query for batch# ['
                      || i_batch_no
                      || ']';
                pl_log.ins_msg('INFO', l_object_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), ct_application_function, gl_pkg_name);
                
        END; -- check batch status
    END IF;  -- was batch deleted?

    IF o_no_batches_deleted > 0 THEN
        SELECT COUNT(*) INTO replenlst_cnt
        FROM   replenlst
        WHERE  labor_batch_no = i_batch_no;
        
        IF replenlst_cnt > 0 THEN
            UPDATE replenlst
            SET    labor_batch_no = NULL
            WHERE  labor_batch_no = i_batch_no;
        END IF;
    END IF;  -- potentially update replenlst 

    pl_log.ins_msg('INFO', l_object_name, 'Ending delete_swap_batch()', null, null, ct_application_function, gl_pkg_name); 

EXCEPTION
    WHEN e_invalid_batch_no THEN
        l_msg := 'Batch ['
              || i_batch_no
              || '] is NOT a SWAP batch.';
        pl_log.ins_msg('INFO', l_object_name, l_msg, null, null, ct_application_function, gl_pkg_name);
        
    WHEN OTHERS THEN
        l_msg := 'Unexpected ERROR while trying to delete SWAP LM batch ['
              || i_batch_no
              || ']';
        pl_log.ins_msg('INFO', l_object_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), ct_application_function, gl_pkg_name);

END delete_swap_batch;


---------------------------------------------------------------------------
-- Procedure:
--    reset_batch_for_tasks_not_done
--
-- Description:
--    This procedure checks if the task corresponding to a forklift labor batch
--    and any child batches are completed.
--    If a task is not completed then the labor batch is reset which consists
--    of unassigning the user from the labor batch and setting the labor batch
--    status to future.  If all the tasks are not completed then the user
--    user is made active on the forklift default indirect batch.
--
--    Procedure "pl_lmf.reset_batch_if_task_not_compl" is called to do the work.
--    It is passed the user's active labor batch to process.
--    "reset_batch_for_tasks_not_done" is passed the user id and finds
--    the users active labor batch and if a forklift batch calls
--    "pl_lmf.reset_batch_if_task_not_compl".
--
-- Parameters:
--    i_user_id    - The user signing onto a labor batch.
--
-- Called by:
--    pl_lmc.logon_to_forklift_labor_batch
--
-- Exceptions raised:
--    None.  Any error is logged.  We do not want to stop procssing if an
--    error occurs.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/01/19 bben0556 Brian Bent
--                      Project:
--         S4R-Jira-Story_1735_When_completing_forklift_batch_future_batch_if_task_not_completed.
--
--                      Created.
---------------------------------------------------------------------------
PROCEDURE reset_batch_for_tasks_not_done
                  (i_user_id IN  arch_batch.user_id%TYPE)
IS
   l_message      VARCHAR2(256);    -- Message buffer
   l_object_name  VARCHAR2(320) := 'reset_batch_for_tasks_not_done';  -- Used in log messages

   --
   -- Info about the users current active batch.
   --
   l_active_batch_no             arch_batch.batch_no%TYPE;
   l_active_batch_is_parent_bln  BOOLEAN;
   l_active_batch_lbr_func       job_code.lfun_lbr_func%TYPE;
   l_active_batch_status         PLS_INTEGER;
BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                  || ' (i_user_id[' || i_user_id || '])',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Before signing onto the labor batch check the current active batch
   -- and if it is a forklift labor batch reset the labor batch and child batch
   -- if the task is not completed.
   --
   pl_lmc.find_active_batch
                 (i_user_id        => i_user_id,
                  o_batch_no       => l_active_batch_no,
                  o_is_parent_bln  => l_active_batch_is_parent_bln,
                  o_lbr_func       => l_active_batch_lbr_func,
                  o_status         => l_active_batch_status);

   IF (    l_active_batch_status = rf.status_normal
       AND l_active_batch_lbr_func = 'FL')
   THEN
      --
      -- "pl_lmf.logon_to_forklift_labor_batch" sets a savepoint and rolls back if there
      -- is any error.
      --
      pl_lmf.reset_batch_if_task_not_compl(i_batch_no => l_active_batch_no);

   END IF;

   --
   -- Log ending the procedure.
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                  || ' (i_user_id[' || i_user_id || '])',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

EXCEPTION
   WHEN OTHERS THEN
      l_message := '(i_user_id[' || i_user_id || '])'
                   || '  Had some issue in the process.  Do not raise an error.'
                   || '  The result is this procedure ends up doing nothing.';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END reset_batch_for_tasks_not_done;


---------------------------------------------------------------------------
-- Procedure:
--    reset_batch_if_task_not_compl
--
-- Description:
--    This procedure checks if the task corresponding to a forklift labor batch
--    and any child batches are completed.
--    If a task is not completed then the labor batch is reset which consists
--    of unassigning the user from the labor batch and setting the labor batch
--    status to future.  If all the tasks are not completed then the user
--    user is made active on the forklift default indirect batch.
--
-- Parameters:
--    i_batch_no     - The forklift labor batch being completed.
--                     Status needs to be 'A'.
--                     Note that this can be a parent batch.
--
-- Called by:
--
-- Exceptions raised:
--    None.  Any error is logged.  We do not want to stop procssing if an
--    error occurs.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/25/19 bben0556 Brian Bent
--                      Project:
--         S4R-Jira-Story_1735_When_completing_forklift_batch_future_batch_if_task_not_completed.
--
--                      Created.
---------------------------------------------------------------------------
PROCEDURE reset_batch_if_task_not_compl
                  (i_batch_no  IN  arch_batch.batch_no%TYPE)
IS
   l_message      VARCHAR2(256);    -- Message buffer
   l_object_name  VARCHAR2(320) := 'reset_batch_if_task_not_compl';  -- Used in log messages

   l_last_complete_batch         arch_batch.batch_no%TYPE;
   l_num_batches_processed       PLS_INTEGER;  -- Count of batches
   l_needs_new_parent            BOOLEAN;
   l_new_parent_batch_no         arch_batch.batch_no%TYPE;
   l_num_batches_reset           PLS_INTEGER;
   l_num_batches_task_completed  PLS_INTEGER;
   l_actl_start_time             DATE;        -- Actual start time for the active batch when one or more labor
                                              -- batches does not have the task completed.
                                              -- This has to get populated when we find batch(s) with tasks not completed.
   l_status                      PLS_INTEGER;
   l_user_id                     arch_batch.user_id%TYPE;
   l_num_child_batches           PLS_INTEGER; -- Number of child batches for i_batch_no.  Used in log message.

   CURSOR c_batch(cp_batch_no arch_batch.batch_no%TYPE)
   IS
   SELECT b.batch_no,
          b.status,
          b.parent_batch_no,
          b.user_id,
          b.actl_start_time,
          b.ref_no,
          DECODE(b.batch_no, b.parent_batch_no, 'Y', 'N') is_parent
     FROM batch b, job_code jc
    WHERE jc.jbcd_job_code = b.jbcd_job_code
      AND jc.lfun_lbr_func  = 'FL'                -- Only process forklift batches.
      AND (   b.batch_no        = cp_batch_no
           OR b.parent_batch_no = cp_batch_no)
      AND b.status IN ('A', 'M')
    ORDER BY b.actl_start_time, b.batch_no;    -- The ordering is important.

BEGIN
   --
   -- Get the number of child batches to use in log messages.
   --
   l_num_child_batches := pl_lmc.count_child_batches(i_batch_no => i_batch_no);

   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                  || ' (i_batch_no[' || i_batch_no || '])'
                  || '  This procedure checks if the task corresponding to labor batch ' || i_batch_no
                  || ' and any child batches are completed.  This labor batch has ' || TO_CHAR(l_num_child_batches) || ' child batches.'
                  || '  If a task is not completed then the labor batch is reset which consists of unassigning'
                  || ' the user from the labor batch and setting the labor batch status to future.'
                  || '  ----- THIS APPLIES FOR FORKLIFT LABOR ONLY ----',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- If there are any errors rollback to the save point.
   --
   SAVEPOINT sp_reset_batch;

   DBMS_OUTPUT.PUT_LINE('=================================================================');
   DBMS_OUTPUT.PUT_LINE('i_batch_no[' || i_batch_no || ']');

   --
   -- Initialization
   --
   l_num_batches_processed       := 0;
   l_needs_new_parent            := FALSE;
   l_new_parent_batch_no         := NULL;
   l_num_batches_reset           := 0;
   l_num_batches_task_completed  := 0;

   --
   -- Check if all the tasks are completed for the labor batch and any child batches.
   --
   IF (pl_lmf.all_tasks_completed
                 (i_batch_no             => i_batch_no,
                  i_check_batch_only_bln => FALSE) = FALSE)
   THEN
      --
      -- Not all the tasks completed.  Reset the labor batch for the uncompleted task(s).
      --
      DBMS_OUTPUT.PUT_LINE('==== not all tasks completed, future the labor batch for the uncompleted task');

      pl_log.ins_msg
            (i_msg_type         => pl_log.ct_info_msg,
             i_procedure_name   => l_object_name,
             i_msg_text         => 'Not all tasks completed for labor batch '  || i_batch_no || '.'
                  || '  For the task(s) not completed reset the labor batch.',
             i_msg_no           => NULL,
             i_sql_err_msg      => NULL,
             i_application_func => ct_application_function,
             i_program_name     => gl_pkg_name,
             i_msg_alert        => 'N');

      --
      -- Loop though the batch and any child batches resetting the labor batch if the task is not done.
      --
      FOR r_batch IN c_batch(i_batch_no)
      LOOP
         l_num_batches_processed := l_num_batches_processed + 1;
         l_user_id               := r_batch.user_id;     -- Necessary to save the user for use later.

         DBMS_OUTPUT.PUT_LINE(r_batch.batch_no
                       || ' ' ||  r_batch.status
                       || ' ' ||  r_batch.parent_batch_no
                       || ' ' ||  r_batch.user_id
                       || ' ' ||  TO_CHAR(r_batch.actl_start_time,'DD-MON-YYYY HH24:MI:SS')
                       || ' ' ||  r_batch.is_parent);

         --
         -- Check if the task is completed for the specific labor batch.
         --
         IF (pl_lmf.all_tasks_completed
                         (i_batch_no             => r_batch.batch_no,
                          i_check_batch_only_bln => TRUE) = FALSE)
         THEN
            --
            -- Task not completed.  Reset the labor batch.
            --
            DBMS_OUTPUT.PUT_LINE(r_batch.batch_no || ' task not done');

            pl_log.ins_msg
                     (i_msg_type         => pl_log.ct_info_msg,
                      i_procedure_name   => l_object_name,
                      i_msg_text         => 'Task for labor batch ' || r_batch.batch_no
                           || ' not completed.  Reset the labor batch.'
                           || '  status['          || r_batch.status          || ']'
                           || '  current parent_batch_no[' || r_batch.parent_batch_no || ']'
                           || '  user['            || r_batch.user_id         || ']'
                           || '  ref_no['          || r_batch.ref_no          || ']'
                           || '  i_batch_no['      || i_batch_no             || ']',
                      i_msg_no           => NULL,
                      i_sql_err_msg      => NULL,
                      i_application_func => ct_application_function,
                      i_program_name     => gl_pkg_name,
                      i_msg_alert        => 'N');

            --
            -- If resetting the parent batch then we need to save some info about it to use with the new parent.
            --
            IF (r_batch.is_parent = 'Y') THEN
               l_needs_new_parent := TRUE;
               l_actl_start_time :=  r_batch.actl_start_time;   -- Save the start time of the original parent to use for the new parent.
            END IF;

            /*
            ** Reset the labor batch.
            */
            --pl_lmf.reset_batch(i_batch_no => r_batch.batch_no, i_cmt => 'RESET-TASK NOT DONE');
            pl_lmf.reset_batch(i_batch_no => r_batch.batch_no);
            l_num_batches_reset := l_num_batches_reset + 1;

         ELSE
            --
            -- Task was completed.
            --
            IF (l_actl_start_time IS NULL) THEN  -- If we don't yet have a start time then use the batch's start time
               l_actl_start_time := r_batch.actl_start_time;
            END IF;

            DBMS_OUTPUT.PUT_LINE(r_batch.batch_no || ' task done');

            pl_log.ins_msg
                     (i_msg_type         => pl_log.ct_info_msg,
                      i_procedure_name   => l_object_name,
                      i_msg_text         => 'Task for batch ' || r_batch.batch_no || ' completed.'
                           || '  status['          || r_batch.status          || ']'
                           || '  parent_batch_no[' || r_batch.parent_batch_no || ']'
                           || '  user['            || r_batch.user_id         || ']'
                           || '  ref_no['          || r_batch.ref_no          || ']'
                           || '  i_batch_no['       || i_batch_no             || ']',
                      i_msg_no           => NULL,
                      i_sql_err_msg      => NULL,
                      i_application_func => ct_application_function,
                      i_program_name     => gl_pkg_name,
                      i_msg_alert        => 'N');

            IF (l_needs_new_parent = TRUE AND l_new_parent_batch_no IS NULL)
            THEN
               --
               -- If this point reached then the parent batch was reset and we are choosing a new parent batch.
               --
               l_new_parent_batch_no := r_batch.batch_no;   -- The batch will be the new parent batch.
            END IF;
         END IF;
      END LOOP;

      pl_log.ins_msg
              (i_msg_type         => pl_log.ct_info_msg,
               i_procedure_name   => l_object_name,
               i_msg_text         => 'Number of labor batches processed: ' || TO_CHAR(l_num_batches_processed)
                           || '  Number of labor batches reset: ' || TO_CHAR(l_num_batches_reset)
                           || '  i_batch_no['       || i_batch_no             || ']',
               i_msg_no           => NULL,
               i_sql_err_msg      => NULL,
               i_application_func => ct_application_function,
               i_program_name     => gl_pkg_name,
               i_msg_alert        => 'N');

      IF (l_num_batches_processed > 0
          AND l_num_batches_processed = l_num_batches_reset) THEN
         --
         -- All batches reset so put the user on the forklift default batch.
         --
         DBMS_OUTPUT.PUT_LINE('All batches reset so put user on the forklift default indirect batch.');

      pl_log.ins_msg
              (i_msg_type         => pl_log.ct_info_msg,
               i_procedure_name   => l_object_name,
               i_msg_text         => 'All batches reset so put user on the forklift default indirect batch.',
               i_msg_no           => NULL,
               i_sql_err_msg      => NULL,
               i_application_func => ct_application_function,
               i_program_name     => gl_pkg_name,
               i_msg_alert        => 'N');

         l_last_complete_batch := pl_lmc.get_last_complete_batch(l_user_id);

         create_dflt_fk_ind_batch
                        (i_batch_no    => l_last_complete_batch,
                         i_user_id     => l_user_id,
                         i_ref_no      => i_batch_no || '-NO TASKS COMPLETED',
                         i_start_time  => NULL,
                         o_status      => l_status);

         IF (l_status <> rf.status_normal) THEN
            --
            -- Had some issue creating the default indirect.  Rollback.
            -- The result is this procedure ends up doing nothing.
            --
            ROLLBACK TO SAVEPOINT sp_reset_batch;

            pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Had some issue creating the default indirect.  Rollback.'
                       || ' i_batch_no[' || i_batch_no || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
         END IF;
      ELSIF (l_num_batches_processed > 0)
      THEN
         --
         -- One or more labor batches had the task completed.  Set the status and parent batch.
         --
         IF ((l_num_batches_processed - l_num_batches_reset) = 1) THEN

      pl_log.ins_msg
              (i_msg_type         => pl_log.ct_info_msg,
               i_procedure_name   => l_object_name,
               i_msg_text         => 'Updating parent',
               i_msg_no           => NULL,
               i_sql_err_msg      => NULL,
               i_application_func => ct_application_function,
               i_program_name     => gl_pkg_name,
               i_msg_alert        => 'N');

            --
            -- We had parent-child batches and only one batch had the task completed.
            -- This leaves us with a single batch.  We no longer have parent-child.
            -- The batches for tasks not done have been reset at this point.
            --
            UPDATE batch b
               SET b.status = 'A',
                   b.parent_batch_no   = NULL,              -- Not a parent
                   b.actl_start_time   = l_actl_start_time,
                   b.actl_stop_time    = NULL,
                   b.parent_batch_date = NULL,
                   b.total_count       = 1,
                   b.total_pallet      = 1
             WHERE b.parent_batch_no = i_batch_no;
         ELSE

      pl_log.ins_msg
              (i_msg_type         => pl_log.ct_info_msg,
               i_procedure_name   => l_object_name,
               i_msg_text         => 'Still have parent-child',
               i_msg_no           => NULL,
               i_sql_err_msg      => NULL,
               i_application_func => ct_application_function,
               i_program_name     => gl_pkg_name,
               i_msg_alert        => 'N');

            --
            -- Still have parent-child.
            -- If we have a new parent then update the parent_batch_no and status
            -- for the parent batch and the child batch(s).
            --
            IF (l_new_parent_batch_no IS NOT NULL) THEN
               UPDATE batch b
                  SET b.status = 'A',
                      b.parent_batch_no = l_new_parent_batch_no,
                      b.actl_start_time = l_actl_start_time,
                      b.actl_stop_time  = NULL
                WHERE b.batch_no = l_new_parent_batch_no;

               UPDATE batch b
                  SET b.status = 'M',
                      b.parent_batch_no = l_new_parent_batch_no
                WHERE b.parent_batch_no = i_batch_no
                  AND b.batch_no        <> b.parent_batch_no;

               pl_log.ins_msg
                  (i_msg_type         => pl_log.ct_info_msg,
                   i_procedure_name   => l_object_name,
                   i_msg_text         => 'New parent batch is ' || l_new_parent_batch_no || '.'
                          || ' i_batch_no[' || i_batch_no || ']',
                   i_msg_no           => NULL,
                   i_sql_err_msg      => NULL,
                   i_application_func => ct_application_function,
                   i_program_name     => gl_pkg_name,
                   i_msg_alert        => 'N');
            END IF;

      pl_log.ins_msg
              (i_msg_type         => pl_log.ct_info_msg,
               i_procedure_name   => l_object_name,
               i_msg_text         => 'Update the total_count and the total_pallet for the parent batch',
               i_msg_no           => NULL,
               i_sql_err_msg      => NULL,
               i_application_func => ct_application_function,
               i_program_name     => gl_pkg_name,
               i_msg_alert        => 'N');

            --
            -- Update the total_count and the total_pallet for the parent batch keeping in
            -- mind we could have a new parent batch.
            --
            UPDATE batch b
               SET (total_count, total_pallet) =
                    (SELECT COUNT(*), COUNT(*)
                       FROM batch b2
                      WHERE b2.parent_batch_no = DECODE(l_new_parent_batch_no, NULL, i_batch_no, l_new_parent_batch_no))
             WHERE b.batch_no = DECODE(l_new_parent_batch_no, NULL, i_batch_no, l_new_parent_batch_no)
               AND status = 'A';
         END IF;
      ELSE
         NULL;   -- l_num_batches_processed is 0 so the cursor did not select any records.
      END IF;
   ELSE
      --
      -- All tasks are completed.
      --
      DBMS_OUTPUT.PUT_LINE('==== completed');

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'All task(s) are completed for labor batch ' || i_batch_no || ' and any child batches.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
   END IF;

   --
   -- Log ending the procedure.
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                  || ' (i_batch_no[' || i_batch_no || '])',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK TO SAVEPOINT sp_reset_batch;

      l_message := '(i_batch_no[' || i_batch_no || '])'
                   || '  Had some issue in the process.  ROLLBACK.  Do not raise an error.'
                   || '  The result is this procedure ends up doing nothing.';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END reset_batch_if_task_not_compl;


---------------------------------------------------------------------------
-- Procedure:
--    create_dflt_fk_ind_batch
--
-- Description:
--    This procedure creates the default forklift indirect batch and makes
--    the user active on it.
--
-- Parameters:
--    i_batch_no     - The users last completed batch.  It is used in
--                     creating the default indirect batch.
--    i_user_id      - User performing operation.
--    i_ref_no       - Reference # for the default indirect batch.
--    i_start_time   - The start time to use for the default indirect
--                     batch if it has a value.
--                     If the user has a
--                     suspended batch then the start time of the default
--                     indirect batch will be the start time of the batch
--                     being reset which will be in this parameter.  This
--                     determination has already taken place.  If i_start_time
--                     has no value then the start time of the default
--                     indirect batch is the stop time of the last completed
--                     batch for the user.
--    o_status       - Success or failure.
--
-- Called by:
--    xxx
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, ...)
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/25/19 bben0556 Brian Bent
--                      Project:
--         S4R-Jira-Story_1735_When_completing_forklift_batch_future_batch_if_task_not_completed.
--
--                      Created.
--                      PL/SQL version of function lm_forklift.pc
--    10/24/19  kchi7065  Kiran Chimata
--                        Project: S4R-Jira-Story_958_Yard_move_labor_batches
--                        Modified function "create_dflt_fk_ind_batch" to determine default job
--                        code based on completed batch or last batch to be reset.
---------------------------------------------------------------------------
PROCEDURE create_dflt_fk_ind_batch
                        (i_batch_no    IN   arch_batch.batch_no%TYPE,
                         i_user_id     IN   arch_batch.user_id%TYPE,
                         i_ref_no      IN   arch_batch.ref_no%TYPE,
                         i_start_time  IN   arch_batch.actl_start_time%TYPE,
                         o_status      OUT  PLS_INTEGER)
IS
   l_message      VARCHAR2(256);    -- Message buffer
   l_object_name  VARCHAR2(320) := 'create_dflt_fk_ind_batch';  -- Used in log messages

   l_batch_no     arch_batch.batch_no%TYPE;  -- Indirect batch number to create.
--   l_default      varchar2(100);

BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                     || ' (i_batch_no['  || i_batch_no     || '],'
                     || ' i_user_id['     || i_user_id     || '],'
                     || ' i_ref_no['      || i_ref_no      || '],'
                     || ' i_start_time['  || TO_CHAR(i_start_time, 'DD-MON-YYYY HH24:MI:SS') || ']),'
                     || '  This procedure puts the user on the default forklift indirect batch.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   o_status := rf.STATUS_NORMAL;

   --
   -- Build the batch number.
   --
   l_batch_no := 'I' || TRIM(TO_CHAR(seq1.NEXTVAL));


   --
   -- Insert the labor batch.  Status will be active.
   --
   INSERT INTO batch
         (batch_no,
          jbcd_job_code,
          status,
          actl_start_time,
          user_id,
          user_supervsr_id,
          ref_no,
          batch_date)
   SELECT
          l_batch_no             batch_no,
          sc.config_flag_val     jbcd_job_code,
          'A'                    status,
          DECODE(i_start_time, NULL, b.actl_stop_time, i_start_time)   actl_start_time,
          b.user_id              user_id,
          b.user_supervsr_id     user_supervsr_id,
          i_ref_no               ref_no,
          TRUNC(SYSDATE)         batch_date
     FROM sys_config sc,
          batch b
    WHERE sc.config_flag_name = (SELECT CASE
                                          WHEN  b.jbcd_job_code = 'IYEXT' THEN
                                            'LM_YD_DFLT_IND_JOBCODE'
                                          WHEN  SUBSTR( i_batch_no, 1, 2) = 'YD' THEN
                                            'LM_YD_DFLT_IND_JOBCODE'
                                          WHEN  SUBSTR( i_ref_no, 1, 2) = 'YD' THEN
                                            'LM_YD_DFLT_IND_JOBCODE'
                                          ELSE
                                            'LM_FK_DFLT_IND_JOBCODE'
                                          END config_flag_val
                                     FROM dual)
      AND b.user_id           = i_user_id
      AND b.status            = 'C'
      AND b.batch_no          = i_batch_no;

   --
   -- Check if record inserted.
   --
   IF (SQL%ROWCOUNT = 1) THEN
      l_message := 'TABLE=batch  ACTION=INSERT'
                   || '  KEY=[' || i_user_id || '],[' || i_batch_no || '] (i_user_id,i_batch_no,)'
                   || '  MESSAGE="Created default indirect forklift batch for user."';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
   ELSE
      o_status := rf.STATUS_LM_INS_FL_DFLT_FAIL;

      l_message := 'TABLE=batch  ACTION=INSERT'
                   || '  KEY=[' || i_user_id || '],[' || i_batch_no || '] (i_user_id,i_batch_no,)'
                   || '  MESSAGE="Unable to create default indirect forklift batch."';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
   END IF;

   --
   -- Log ending the procedure.
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                     || ' i_batch_no['  || i_batch_no        || '],'
                     || ' o_status['    || TO_CHAR(o_status) || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred  i_batch_no[' || i_batch_no || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
END create_dflt_fk_ind_batch;



---------------------------------------------------------------------------
-- Function:
--    get_xdk_job_code (public)  Made public so it can be tested by itself.
--
-- Description:
--    This function determines the job code for the XDK bulk pull forkift labor batch.
--
--    A XDK bulk pull differs from a regular bulk pull in that the XDK task source
--    location can be a door number and the pallet can have multiple items on it.
--
--    If unable to detrmine the job code thenn NULL is returned.   The calling program
--    needs to decie what to do it NULL returned.
--
--
-- Parameters:
--    i_location  - The source location of the XDK task.
--                  If a door then it needs to be the physical door number and not
--                  the forklift labor door number.
--
-- Return Values:
--    job code for the XDK forklift labor batch.
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Message logged and null returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/14/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3663_OP_Site_2_Merge_float_ordcw_sent_from_Site_1
--                      Created.
--
---------------------------------------------------------------------------
FUNCTION get_xdk_job_code(i_location IN loc.logi_loc%TYPE)
RETURN VARCHAR2
IS
   l_rec_count                 PLS_INTEGER;                     -- Work area
   l_job_code                  job_code.jbcd_job_code%TYPE;     -- The job code for the  XDK forklist labor batch.
   l_forklift_labor_door_no    VARCHAR2(30);                    -- The forklift labor door number for i_location if i_loactio is a door.
BEGIN
   l_job_code    := NULL;

   SELECT COUNT(*)
     INTO l_rec_count
     FROM loc
    WHERE logi_loc = i_location;

   IF (l_rec_count > 0) THEN
      --
      -- i_location is a warehouse location.
      --
      BEGIN
         SELECT fk.palpull_jobcode
           INTO l_job_code
           FROM
                job_code j,
                fk_area_jobcodes fk,
                swms_sub_areas ssa,
                aisle_info ai
          WHERE
                j.jbcd_job_code    = fk.palpull_jobcode
            AND fk.sub_area_code   = ssa.sub_area_code
            AND ssa.sub_area_code  = ai.sub_area_code
            AND ai.name            = SUBSTR(i_location, 1, 2);
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            null; -- xxxxxx add log message
      END;
   ELSE
      --
      -- Location is not LOC table so it must be door.
      -- Use the first character of the forklift labor dock as the area.
      -- Though we probably should add the swms sub area column to the door table ???
      --
      l_forklift_labor_door_no := NVL(pl_lmf.f_get_fk_door_no(i_location), i_location);

      IF (l_forklift_labor_door_no IS NOT NULL) THEN
         --
         -- i_location is a door. We do not know the sub area the door is in.
         -- Using the 1st character of the forklift door number as the area pick the min job code.
         --
         SELECT MIN(fk.palpull_jobcode)
           INTO l_job_code
           FROM
                job_code j,
                fk_area_jobcodes fk,
                swms_sub_areas ssa
          WHERE
                j.jbcd_job_code    = fk.palpull_jobcode
            AND fk.sub_area_code   = ssa.sub_area_code
            AND ssa.sub_area_code  = SUBSTR(l_forklift_labor_door_no, 1, 1);
      ELSE
         --
         -- i_location not a door.  Null will be retutrned.
         -- xxxxx add log mesage
         --
         l_job_code := NULL;
      END IF;

   END IF;

   RETURN l_job_code;             -- Calling program needs to handle null job code returned
EXCEPTION
   WHEN OTHERS THEN
      null; -- xxxxxx add log message
   RETURN NULL;                       -- Calling program needs to handle null job code returned
END get_xdk_job_code;


---------------------------------------------------------------------------
-- Procedure:
--    create_xdk_pallet_pull_batch (public)
--
-- Description:
--    This procedure creates the forklift labor mgmt batch for a
--    R1 XDK pallet pull. This is the main procedure to call.
--
--    ***** If the xdock pallet is not received then the labor batch is not created *****
--
--    For a XDK pallet pull these columns are set as follows.
--        FLOATS.PALLET_PULL      is 'B'
--        FLOATS.CROSS_DOCK_TYPE  is 'X'   <- This is key in identifying the float
--                                            as a XDK cross dock pallet.
--
-- Parameters:
--    i_float_no              - Float number of the XDK bulk pull.
--    o_r_create_batch_stats  - Statistics about batches created.
--       no_records_processed - Number of records processed.
--                               Will be 0 or 1.
--       no_batches_created   - Number of batches successfully created.
--                               Will be 0 or 1.
--       no_batches_existing  - Number of batches that already exist.
--                               Will be 0 or 1.
--       no_not_created_due_to_error - Number of batches not created.  This
--                                      could be due to a data setup issue or
--                                      an oracle error.  A message is logged
--                                      to the log table for each batch not
--                                      created.  Duplicates not logged since
--                                      this procedure could be run multiple
--                                      times for the same data.
--                                      Will be 0 or 1.
--
-- Called by: (list may not be complete)
--
-- Exceptions raised:
--    pl_exc.e_data_error         - Parameter is null.
--    pl_exc.e_database_error     - Got an oracle error.
--    pl_exc.e_lm_batch_upd_fail  - Failed to create the batch.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/14/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3663_OP_Site_2_Merge_float_ordcw_sent_from_Site_1
--                      Created.
---------------------------------------------------------------------------
PROCEDURE create_xdk_pallet_pull_batch
   (
      i_float_no                 IN  floats.float_no%TYPE,
      o_r_create_batch_stats     OUT t_create_putaway_stats_rec
   )
IS
   l_message     VARCHAR2(512);    -- Message buffer
   l_object_name VARCHAR2(30) := 'create_xdk_pallet_pull_batch';

   l_job_code                    job_code.jbcd_job_code%TYPE;     -- Forklift labor batch job code for the XDK task.
   l_xdk_pallet_pull_batch_no    batch.batch_no%TYPE;             -- Forklift labor batch number for the XDK task.

   e_float_record_not_found      EXCEPTION;   -- Could not find the float.
   e_batch_already_exists        EXCEPTION;   -- Labor batch already exists
   e_no_job_code                 EXCEPTION;   -- Could not determine the job code for the labor batch.
   e_xdock_pallet_not_received   EXCEPTION;   -- The cross dock pallet not received.

   --
   -- This cursor gets info about the float to use in validating
   -- if the float is a pallet pull.
   --
   CURSOR c_float_info(cp_float_no  floats.float_no%TYPE)
   IS
   SELECT f.float_no                                     float_no,
          f.route_no                                     route_no,
          f.pallet_pull                                  pallet_pull,
          f.pallet_id                                    pallet_id,
          f.cross_dock_type                              cross_dock_type,
          f.xdock_pallet_id                              xdock_pallet_id,
          f.home_slot                                    home_slot,
          f.door_no                                      door_no,
          f.door_area                                    door_area,
          f.comp_code                                    comp_code,
          f.add_date                                     add_date,
          put.dest_loc                                   put_dest_loc,
          (SUM(fd.qty_alloc) / pm.spc) * pm.case_cube    pallet_cube,
          SUM(fd.qty_alloc) * pm.g_weight                pallet_weight,
          MIN(fd.src_loc)                                min_fd_src_loc,           -- Though the float_detail.src_loc should be the same for all float detail records.
                                                                                   -- When the pallet is received at Site 2 the float_detail.src_loc is updated to
                                                                                   -- the putwaylst.dest_loc.  If it is a door the th float_detail.src_loc is always
                                                                                   -- the physical door.  It does not include the dock number.
          COUNT(DISTINCT fd.src_loc)                     count_distinct_fd_src_loc
     FROM floats f,
          float_detail fd,
          pm,
          putawaylst put              -- Used to determine if the cross dock pallet hss been received.  If not then the labor batch is not created.
    WHERE
          f.float_no              = cp_float_no
      AND fd.float_no         (+) = f.float_no
      AND pm.prod_id          (+) = fd.prod_id
      AND pm.cust_pref_vendor (+) = fd.cust_pref_vendor
      AND f.cross_dock_type       = 'X'                  -- It needs to be 'X' cross dock pallet.
      AND put.pallet_id       (+) = f.xdock_pallet_id
    GROUP BY
          f.float_no,
          f.route_no,
          f.pallet_pull,
          f.pallet_id,
          f.cross_dock_type,
          f.xdock_pallet_id,
          f.home_slot,
          f.door_no,
          f.door_area,
          f.comp_code,
          f.add_date,
          pm.spc,
          pm.case_cube,
          pm.g_weight,
          put.dest_loc;

   l_r_float_info  c_float_info%ROWTYPE;

BEGIN
   --
   -- Log starting
   --
   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Starting procedure'
                   || ' (i_float_no,o_r_create_batch_stats)'
                   || ' i_float_no[' || TO_CHAR(i_float_no) || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   --
   -- The parameters need a value.
   --
   IF (i_float_no IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   --
   -- Initialize the statistics count.
   --
   o_r_create_batch_stats.no_records_processed        := 0;
   o_r_create_batch_stats.no_batches_created          := 0;
   o_r_create_batch_stats.no_batches_existing         := 0;
   o_r_create_batch_stats.no_not_created_due_to_error := 0;

   --
   -- Get info about the float.
   --
   OPEN c_float_info(i_float_no);
   FETCH c_float_info INTO l_r_float_info;

   IF (c_float_info%NOTFOUND) THEN
      --
      -- Did not find the float.
      --
      CLOSE c_float_info;
      RAISE e_float_record_not_found;
   END IF;

   CLOSE c_float_info;

   --
   -- Build the labor abatch number.
   l_xdk_pallet_pull_batch_no := pl_lmc.ct_forklift_pallet_pull || TO_CHAR(i_float_no);

   o_r_create_batch_stats.no_records_processed := 1;

   --
   -- Log info about the float.
   --
   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Float info:'
                     || '  i_float_no['                  || TO_CHAR(i_float_no)                 || ']'
                     || '  route_no['                    || l_r_float_info.route_no             || ']'
                     || '  pallet_pull['                 || l_r_float_info.pallet_pull          || ']'
                     || '  pallet_id['                   || l_r_float_info.pallet_id            || ']'
                     || '  cross_dock_type['             || l_r_float_info.cross_dock_type      || ']'
                     || '  xdock_pallet_id['             || l_r_float_info.xdock_pallet_id      || ']'
                     || '  home_slot['                   || l_r_float_info.home_slot            || ']'
                     || '  door_no['                     || l_r_float_info.door_no              || ']'
                     || '  door_area['                   || l_r_float_info.door_area            || ']'
                     || '  comp_code['                   || l_r_float_info.comp_code            || ']'
                     || '  put_dest_loc['                || l_r_float_info.put_dest_loc         || ']'
                     || '  min_fd_src_loc['              || l_r_float_info.min_fd_src_loc       || ']'
                     || '  count_distinct_fd_src_loc['   || l_r_float_info.count_distinct_fd_src_loc       || ']'
                     || '  add_date['                    || TO_CHAR(l_r_float_info.add_date, 'YYYY-MM-DD HH24:MI:SS') || ']'
                     || '  pallet_cube['                 || TO_CHAR(l_r_float_info.pallet_cube)     || ']'
                     || '  pallet_weight['               || TO_CHAR(l_r_float_info.pallet_weight)   || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Labor batch number is:'
                     || '  l_xdk_pallet_pull_batch_no['   || l_xdk_pallet_pull_batch_no   || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   --
   -- If the cross dock pallet not received then do not create the labor batch.
   -- Log a message.
   --
   IF (l_r_float_info.put_dest_loc IS NULL) THEN
      RAISE e_xdock_pallet_not_received;
   END IF;

   --
   -- Get the job code for the labor batch.
   -- If unable to determine it then log a message.  The labor batch is not created.
   --
   l_job_code := get_xdk_job_code(l_r_float_info.min_fd_src_loc);
   IF (l_job_code IS NULL) THEN
      RAISE e_no_job_code;
   END IF;

   --
   -- Create the labor batch.
   --
   BEGIN
      SAVEPOINT sp_forklift_batch;  -- rollback to here if there was an error creating the batch

      --
      --  Check if the labor batch already exists.
      --
      IF (pl_lmc.does_batch_exist(l_xdk_pallet_pull_batch_no) = TRUE) THEN
         RAISE e_batch_already_exists;
      END IF;

      INSERT INTO batch
               (batch_no,
                jbcd_job_code,
                status,
                batch_date,
                kvi_from_loc,
                kvi_to_loc,
                kvi_no_case,
                kvi_no_split,
                kvi_no_pallet,
                kvi_no_item,
                kvi_no_po,
                kvi_cube,
                kvi_wt,
                kvi_no_loc,
                total_count,
                total_piece,
                total_pallet,
                ref_no,
                kvi_distance,
                goal_time,
                target_time,
                no_breaks,
                no_lunches,
                kvi_doc_time,
                kvi_no_piece,
                kvi_no_data_capture,
                cmt)
      SELECT
             l_xdk_pallet_pull_batch_no                            batch_no,
             l_job_code                                            jbcd_job_code,
             'F'                                                   status,
             TRUNC(SYSDATE)                                        batch_date,
             NVL(pl_lmf.f_get_fk_door_no(fd.src_loc), fd.src_loc)  kvi_from_loc,   -- if the src_loc is a door then use the forklift labor door--it includes the dock
             pl_lmc.f_get_destination_door_no(i_float_no)          kvi_to_loc,
             0.0                                                   kvi_no_case,
             0.0                                                   kvi_no_split,
             1.0                                                   kvi_no_pallet,
             1.0                                                   kvi_no_item,
             0.0                                                   kvi_no_po,
             l_r_float_info.pallet_cube                            kvi_cube,
             l_r_float_info.pallet_weight                          kvi_wt,
             1.0                                                   kvi_no_loc,
             1.0                                                   total_count,
             0.0                                                   total_piece,
             1.0                                                   total_pallet,
             f.xdock_pallet_id                                     ref_no,
             0.0                                                   kvi_distance,
             0.0                                                   goal_time,
             0.0                                                   target_time ,
             0.0                                                   no_breaks,
             0.0                                                   no_lunches,
             1.0                                                   kvi_doc_time,
             0.0                                                   kvi_no_piece,
             2.0                                                   kvi_no_data_capture,
             'XDK CDT:' || f.cross_dock_type
                || ' STE1:' || f.site_from
                || ' STE2:' || f.site_to
                || ' STE1_PPULL:' || f.site_from_pallet_pull
                || ' STE1_SEL_TYP:' || f.site_from_fl_sel_type   cmt
        FROM
             route r,
             floats f,
             float_detail fd
       WHERE
             r.route_no         = f.route_no
         AND f.cross_dock_type  = 'X'               -- has to be a XDK floats
         AND f.float_no         = i_float_no
         AND fd.float_no        = f.float_No
         AND ROWNUM             = 1;                  -- Needed since a X cross dock pallet pull can have multiple float_detail records.

      IF (SQL%FOUND)THEN
         --
         -- XDK Pallet pull batch created succesfully.
         --
         o_r_create_batch_stats.no_batches_created := o_r_create_batch_stats.no_batches_created + 1;

         pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'XDK pallet pull labor batch[' || l_xdk_pallet_pull_batch_no || '] created.',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

         --
         -- Update the replenlst with the pallet pull labor batch number.  Update based on the float #
         -- as REPLENLST.FLOAT_NO should be populated.
         --
         UPDATE replenlst
            SET labor_batch_no = l_xdk_pallet_pull_batch_no
          WHERE float_no = i_float_no;

         --
         -- Was a REPLENLST updated ???
         --
         IF (SQL%NOTFOUND) THEN
            l_message := 'TABLE=replenlst  ACTION=UPDATE'
                     || ' KEY=' ||  TO_CHAR(i_float_no) || '(i_float_no)'
                     || ' MESSAGE="Failed to update REPLNELST.LABOR_BATCH_NO'
                     || ' to [' || l_xdk_pallet_pull_batch_no || '] because no record found.'
                     || '  This will not stop processing but needs to be a fixed."';

            pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
         END IF;

         --
         -- 09/14/21  Brian Bent OpCo SWMS does not have labor_batch_no column
         --           in FLOATS or FLOAT_DETAIL.  (RDC does)
         --
         -- Update the FLOATS and FLOAT_DETAIL LABOR_BATCH_NO
         -- xxxxxxxx 08/07/18 need logging added
         --
         -- UPDATE floats f
         --   SET f.labor_batch_no = l_xdk_pallet_pull_batch_no
         -- WHERE f.float_no = i_float_no;

         -- UPDATE float_detail fd
         --   SET fd.labor_batch_no = l_xdk_pallet_pull_batch_no
         -- WHERE fd.float_no = i_float_no;
      END IF;

   EXCEPTION

      WHEN DUP_VAL_ON_INDEX OR e_batch_already_exists THEN
         --
         -- Batch already exists.  This is OK because this procedure
         -- could have been run again for the same data.
         --
         o_r_create_batch_stats.no_batches_existing := o_r_create_batch_stats.no_batches_existing + 1;

         pl_log.ins_msg
               (i_msg_type         => pl_log.ct_error_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Pallet pull labor batch[' || l_xdk_pallet_pull_batch_no || '] already exists.'
                      || '  This will not stop processing.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      WHEN OTHERS THEN
         --
         -- Got an oracle error.  Rollback to save point, log the error and continue processing.
         --
         ROLLBACK TO sp_forklift_batch;

         o_r_create_batch_stats.no_not_created_due_to_error := o_r_create_batch_stats.no_not_created_due_to_error + 1;

         pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                     'TABLE=job_code,fk_area_jobcodes,swms_sub_areas,aisle_info,pm,float_detail,floats  ACTION=SELECT'
                     || ' KEY=[' ||TO_CHAR(i_float_no) || '](i_float_no)'
                     || ' MESSAGE="Error creating XDK pallet pull batch[' || l_xdk_pallet_pull_batch_no || '].'
                     || '  Rollback to save point.'
                     || '  This will not stop processing"',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
   END; -- End block creating xdk pallet pull batch

   --
   -- Log ending.
   -- This message can be bypassed if an exception raised.
   --
   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Ending procedure'
                   || ' (i_float_no,o_r_create_batch_stats)'
                   || ' i_float_no[' || TO_CHAR(i_float_no) || ']'
                   || ' no_records_processed['        || TO_CHAR(o_r_create_batch_stats.no_records_processed)        || ']'
                   || ' no_batches_created['          || TO_CHAR(o_r_create_batch_stats.no_batches_created)          || ']'
                   || ' no_batches_existing['         || TO_CHAR(o_r_create_batch_stats.no_batches_existing)         || ']'
                   || ' no_not_created_due_to_error[' || TO_CHAR(o_r_create_batch_stats.no_not_created_due_to_error) || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
EXCEPTION
   WHEN gl_e_parameter_null THEN
      l_message := '(i_float_no[' || TO_CHAR(i_float_no) ||
                   '])  Parameter is null.';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_object_name || ':' || l_message);

   WHEN e_float_record_not_found THEN
      --
      -- Either there is missing information or this procedure was called for a float
      -- that is not a 'X' cross dock pallet
      -- Log a message.
      --
      l_message := l_object_name || '(i_float_no[' || TO_CHAR(i_float_no) || '])'
            || '  Could not find float.  Either there is missing information or this procedure was called for a float'
            || ' that is not a ''X'' cross dock pallet.';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   WHEN e_xdock_pallet_not_received THEN
      --
      -- The cross dock pallet not yet received.  No labor batch created.
      -- Log a message.
      --
      o_r_create_batch_stats.no_not_created_due_to_error := o_r_create_batch_stats.no_not_created_due_to_error + 1;  -- Though not really an error.

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                           'i_float_no[' || TO_CHAR(i_float_no) || ']'
                           || ' The cross dock pallet not received yet.  Labor batch not created.',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   WHEN e_no_job_code THEN
      --
      -- Could not determine the job code for the labor batch.
      -- Log a message.
      --
      o_r_create_batch_stats.no_not_created_due_to_error := o_r_create_batch_stats.no_not_created_due_to_error + 1;

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                           'i_float_no[' || TO_CHAR(i_float_no) || ']'
                           || '  Unable to determine the job code for the labor batch.  The labor batch will not be created.'
                           || '  Rollback to save point.'
                          || '  This will not stop processing',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   WHEN OTHERS THEN
      l_message := l_object_name || '(i_float_no[' || TO_CHAR(i_float_no) || '])';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_error_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ':' || SQLERRM);
END create_xdk_pallet_pull_batch;


END pl_lmf;
/

