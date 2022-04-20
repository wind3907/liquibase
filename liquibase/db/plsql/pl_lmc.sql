CREATE OR REPLACE PACKAGE      pl_lmc
AS

-- sccs_id=%Z% %W% %G% %I%

---------------------------------------------------------------------------
-- Package Name:
--    pl_lmc
--
-- Description:
--    Labor management common objects.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/15/03 prpbcb   Oracle 7 DN none.  Does not exist on oracle 7.
--                      Oracle 8 DN 11321
--                      Created on rs239b because pl_lmf.sql needs it.
--                      This file was copied from rs239a.  It was created
--                      on rs239a for dynamic selection which is not yet
--                      complete.  This file is needed now on rs239b because
--                      package pl_lmf is being modified to have objects to
--                      create forklift labor mgmt batches.  Specifically
--                      pl_lmf was modified to create the putaway batches
--                      for regular and RDC pallets.
--
--                      Following is the comments from the rs239a file.
--                      It is retained for informational purposes.
--             09/17/01 prpbcb   rs239a DN 10859  rs239b DN 10860  Created.  
--
--    07/15/03 prpbcb   rs239a DN none which is OK.
--                      rs239b DN 11261
--                      RDC LPN 18.
--
--    08/21/03 prpbcb   Oracle 7 rs239a DN none  Not dual maintainced.
--                      Oracle 8 rs239b dvlp8 DN none.  Not dual maintained.
--                      Oracle 8 rs239b dvlp9 DN 11416
--                      MSKU changes.  Implemented the following from
--                      lm_common.pc
--                         - merge_bath (lmc_merge_batch) but not quite
--                           the same needs more work.
--
--                      Added constant ct_forklift_msku_ret_to_res.
--
--    02/10/05          Oracle 8 rs239b swms8 DN None
--                      Oracle 8 rs239b swms9 DN 11873
--                      Add constants for batch status.
--
--    02/18/05          Oracle 8 rs239b swms9 DN 11879
--                      Added following constant for T batch:
--             ct_returns_putaway    CONSTANT VARCHAR2(1) := 'T'
--                      When the operator is ready to putaway the returns
--                      LP's and scans one of the LP's the T batch will
--                      become the active batch and the putaway batches
--                      will be child batches of the T batch.
--                     
--                      Changed procedure get_batch_type() to recognize
--                      a T batch.
--                     
--    08/02/05          Oracle 8 rs239b swms9 DN 11974
--                      Project: CRT-Carton Flow replenishments
--                      Added:
--           ct_forklift_dmd_rpl_hs_xfer CONSTANT VARCHAR2(2) := 'FE'
--                      Modified procedure get_batch_type to handle
--                      ct_forklift_dmd_rpl_hs_xfer.
--
--    05/10/10 prpbcb   DN 12580
--                      Project:
--                          CRQ16476-Complete Not Suspend Labor Mgmt Batch
--
--                      Added:
--                 ct_selection_short_runner    CONSTANT VARCHAR2(2) := 'SS'
--                 ct_forklift_break_away_haul  CONSTANT VARCHAR2(2) := 'HL';
--                      Changed procedure get_batch_type() to recognize
--                      SS and HL batches.
--
--                     Added functin f_boolean_text.  It is identical to
--                     the one in pl_commom.sql but will return null if
--                     the parameter is null.  pl_common.sql should have
--                     been changed but I chose not to since I am trying
--                     to keep the changes for the project only to
--                     forklift labor mgmt programs because of 11g.
--
--                     Added function is_three_part_move_active.
--
--    07/19/10 prpbcb  Activity: SWMS12.0.0_0000_QC11345
--                     Project:  QC11345
--                     Copy from rs239b.
--    11/27/15 aklu6632 Activity: Charm600003040_DML_IChange_Function
--                      Project:  Charm600003040
--                      add function for IChange batch.
--    01/28/16 jluo6971 Add new procedure p_get_loader_batch_info().
--    05/31/16 jluo6971 Charm 6000013343 Don't add IWASH to ICHJOB and 
--			fix IWASH/ISTOP w/ duration.

--    07/21/21 mcha1213 add signon_to_batch procedure and other procedure for LR batch
--
-- 08-Oct-2021 pkab6563 - Jira 3700: fixed issue where forklift batches were staying
--                        in active status after previous change related to LR.
--                        Mainly re-enabled forklift related logic in
--                        signon_to_batch() that had been disabled in previous
--                        LR change. Replaced call to RDC signoff function
--                        pl_libswmslm.lmf_signoff_from_fk_batch() with
--                        call to PL_LM_FORKLIFT.lm_signoff_from_forklift_batch().
--                        Package pl_libswmslm exists in OpCo SWMS but currently
--                        does not include function lmf_signoff_from_fk_batch()
--                        that RDC SWMS has. Copied function count_child_batches()
--                        from RDC SWMS. Added RDC code to a few other packages
--                        needed by this change.
--
--    10/11/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3714_OP_Site_2_floats_door_area_sometimes_incorrect
--
--                      Create function "does_batch_exist".  Copied from RDC version of pl_lmc.sql.
--
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Global Type Declarations
---------------------------------------------------------------------------

-- Equipment record.  The shorter field names match what is in
-- lmc.h and used in the PRO*C programs.
--
-- 04/15/02  Added accel_distance and decel_distance fields to
-- use for dynamic selection.  Could probably be used for forklift if
-- we get to the point of using PL/SQL for forklift.
TYPE t_equip_rec IS RECORD
   (equip_id             equip.equip_id%TYPE,
    trav_rate_loaded     equip.trav_rate_loaded%TYPE,
    decel_rate_loaded    equip.decel_rate_loaded%TYPE,
    accel_rate_loaded    equip.accel_rate_loaded%TYPE,
    ll                   equip.lower_loaded%TYPE,
    rl                   equip.raise_loaded%TYPE,
    trav_rate_empty      equip.trav_rate_empty%TYPE,
    decel_rate_empty     equip.decel_rate_empty%TYPE,
    accel_rate_empty     equip.accel_rate_empty%TYPE,
    le                   equip.lower_empty%TYPE,
    re                   equip.raise_empty%TYPE,
    ds                   equip.drop_skid%TYPE,
    apof                 equip.approach_on_floor%TYPE,
    mepof                equip.enter_on_floor%TYPE,
    ppof                 equip.position_on_floor%TYPE,
    apos                 equip.approach_on_stack%TYPE,
    mepos                equip.enter_on_stack%TYPE,
    ppos                 equip.position_on_stack%TYPE,
    apir                 equip.approach_in_rack%TYPE,
    mepir                equip.enter_in_rack%TYPE,
    ppir                 equip.position_in_rack%TYPE,
    bt90                 equip.backout_turn_90%TYPE,
    bp                   equip.backout_and_pos%TYPE,
    tid                  equip.turn_into_door%TYPE,
    tia                  equip.turn_into_aisle%TYPE,
    tir                  equip.turn_into_rack%TYPE,
    apidi                equip.approach_in_drivein%TYPE,
    mepidi               equip.enter_in_drivein%TYPE,
    ppidi                equip.position_in_drivein%TYPE,
    tidi                 equip.turn_into_drivein%TYPE,
    apipb                equip.approach_in_pushback%TYPE,
    mepipb               equip.enter_in_pushback%TYPE,
    ppipb                equip.position_in_pushback%TYPE,
    apidd                equip.approach_in_dbl_dp%TYPE,
    mepidd               equip.enter_in_dbl_dp%TYPE,
    ppidd                equip.position_in_dbl_dp%TYPE,
    accel_distance       NUMBER,
    decel_distance       NUMBER);


-- Distance information for the travel of a piece of equipment.
-- If the total distance traveled is less than the equipment accelerate
-- distance + equipment decelerate distance then the accelerate distance
-- and the decelerate distance is a percentage of the respective equipment
-- distance otherwise they will be equal.
TYPE t_distance_rec IS RECORD
        (equip_accel_distance   NUMBER := 0,    -- Accelerate distance defined
                                                -- for the equipment.
         equip_decel_distance   NUMBER := 0,    -- Decelerate distance defined
                                                -- for the equipment.
         accel_distance   NUMBER := 0,    -- Calculated accelerate distance.
         decel_distance   NUMBER := 0,    -- Calculated deccelerate distance.
         travel_distance  NUMBER := 0,    -- Travel distance.
         total_distance   NUMBER := 0,    -- Total distance.
         tia_time         NUMBER := 0,    -- Time given for turn into aisle.
         distance_time    NUMBER := 0);   -- Time in minutes to travel the
                                          -- accel, decel and travel distances.
                                          -- The equipment will be travelling
                                          -- either be empty or loaded which
                                          -- affects the time because the
                                          -- equipment has the time defined for
                                          -- travel empty and travel loaded.


SUBTYPE t_batch_type IS VARCHAR2(2);   -- Subtype for the batch type.
                                       -- Example batch types:  FP, FN, FR.

---------------------------------------------------------------------------
-- Global Variables
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Public Constants
---------------------------------------------------------------------------

------------------------------
-- Batch status.
------------------------------
ct_active_status    CONSTANT VARCHAR2(1) := 'A';  -- Active batch
ct_complete_status  CONSTANT VARCHAR2(1) := 'C';  -- Completed
ct_future_status    CONSTANT VARCHAR2(1) := 'F';  -- Future batch
ct_merge_status     CONSTANT VARCHAR2(1) := 'M';  -- Merged
ct_x_status         CONSTANT VARCHAR2(1) := 'X';  -- In process of being
                                                  -- created.  Not available
                                                  -- to be signed onto.

------------------------------
-- Log message types.
------------------------------
ct_debug_msg     CONSTANT VARCHAR2(1) := 'D';   -- Debug
ct_error_msg     CONSTANT VARCHAR2(1) := 'E';   -- User error
ct_fatal_msg     CONSTANT VARCHAR2(1) := 'F';   -- Fatal error
ct_info_msg      CONSTANT VARCHAR2(1) := 'I';   -- Informational
ct_warn_msg      CONSTANT VARCHAR2(1) := 'W';   -- Warning

------------------------------
-- Labor mgmt batch types.
------------------------------
ct_indirect                CONSTANT VARCHAR2(1) := 'I';
ct_loader                  CONSTANT VARCHAR2(1) := 'L';
ct_returns_putaway         CONSTANT VARCHAR2(1) := 'T'; -- T batch for
                                                        -- returns putaway.
ct_selection               CONSTANT VARCHAR2(1) := 'S';
ct_selection_short_runner  CONSTANT VARCHAR2(2) := 'SS';

ct_loader_case             CONSTANT VARCHAR2(2) := 'LC';
ct_loader_stop             CONSTANT VARCHAR2(2) := 'LS';
ct_loader_reload           CONSTANT VARCHAR2(2) := 'LR';
ct_loader_unload           CONSTANT VARCHAR2(2) := 'LU';
ct_loader_flt_exit	   CONSTANT VARCHAR2(3) := 'LFE';
ct_loader_batch_not_found  CONSTANT VARCHAR2(3) := 'LBN';
ct_loader_unload_truck	   CONSTANT VARCHAR2(3) := 'LUT';
ct_loader_cse_exit         CONSTANT VARCHAR2(3) := 'LCE';

-- The following correspond to whats in lmf.h. except here the complete
-- 2 character prefix is used.
ct_forklift_drop_to_home   CONSTANT VARCHAR2(2) := 'FD';
ct_forklift_home_slot_xfer CONSTANT VARCHAR2(2) := 'FH';
ct_forklift_inv_adj        CONSTANT VARCHAR2(2) := 'FI';
ct_forklift_putaway        CONSTANT VARCHAR2(2) := 'FP';
ct_forklift_nondemand_rpl  CONSTANT VARCHAR2(2) := 'FN';
ct_forklift_demand_rpl     CONSTANT VARCHAR2(2) := 'FR';
ct_forklift_swap           CONSTANT VARCHAR2(2) := 'FS';
ct_forklift_pallet_pull    CONSTANT VARCHAR2(2) := 'FU';
ct_forklift_combine_pull   CONSTANT VARCHAR2(2) := 'FB';
ct_forklift_transfer       CONSTANT VARCHAR2(2) := 'FX';
ct_forklift_cycle_count    CONSTANT VARCHAR2(2) := 'FC';
ct_forklift_haul           CONSTANT VARCHAR2(2) := 'HP';
ct_forklift_f1_haul        CONSTANT VARCHAR2(2) := 'HX';  -- Func1 out of
                                                          -- putaway.
ct_forklift_break_away_haul  CONSTANT VARCHAR2(2) := 'HL';  -- Break away
                         -- from multi-pallet putaway to do a
                         -- home slot transfer or non-demand replenishment
                         -- or
                         -- break away from a multi-pallet
                         -- replenishment to do a home slot transfer.

ct_forklift_msku_ret_to_res  CONSTANT VARCHAR2(2) := 'FM';  -- Return to
                                                            -- reserve of a
                                                            -- MSKU after a
                                                            -- NDM/DMD.
ct_forklift_dmd_rpl_hs_xfer CONSTANT VARCHAR2(2) := 'FE';  -- Return to
                                          -- reserve of a partially
                                          -- completed demand replenishment.
----------------------------------------------------
-- Type of batch operation.
----------------------------------------------------
ct_ds         CONSTANT VARCHAR2(2)  := 'DS';     -- Dynamic selection
ct_forklift   CONSTANT VARCHAR2(2)  := 'FK';     -- Forklift

----------------------------------------------------
-- Logout options and more batch type
----------------------------------------------------
-- 11/27/2015 aklu6632, add for charm 6000003040
ct_po CONSTANT VARCHAR2(2) := 'PO';
ct_logout_option_L	CONSTANT VARCHAR2(1) := 'L'; -- Straight logout
ct_logout_option_S	CONSTANT VARCHAR2(1) := 'S'; -- Logout + IStop
ct_logout_option_C	CONSTANT VARCHAR2(1) := 'C'; -- Logout + IChJob
ct_logout_from_rf	CONSTANT NUMBER := 0;	     -- Logout from RF
ct_logout_from_sos	CONSTANT NUMBER := 1;	     -- Logout from SOS
ct_logout_from_sls	CONSTANT NUMBER := 2;	     -- Logout from SLS

---------------------------------------------------------------------------
-- Public Cursors 
---------------------------------------------------------------------------
CURSOR c_get_cur_batch (
	cs_batch_no	batch.batch_no%TYPE,
	cs_user_id	batch.user_id%TYPE,
	cs_status	VARCHAR2 DEFAULT 'N') IS
     SELECT batch_no, actl_start_time, actl_stop_time, jbcd_job_code, user_id,
	status, equip_id, parent_batch_no, ref_no, cmt
     FROM batch b
     WHERE  user_id = cs_user_id
     AND (((cs_batch_no IS NOT NULL) AND
	   (batch_no = cs_batch_no) AND
	   (cs_batch_no <> '?')) OR
	  ((((cs_batch_no IS NULL) OR (cs_batch_no = '?')) AND
	   (batch_no = (SELECT batch_no
			FROM batch b2
			WHERE user_id = b.user_id
			AND   (((cs_status = 'Y') AND
				(status = 'A') AND
			    	actl_start_time =
				       (SELECT MAX(actl_start_time)
					FROM batch b3
					WHERE user_id = b2.user_id
					AND status = b2.status)) OR
			       ((cs_status = 'N') AND
				(status IN ('C','M')) AND
			    	(rowidtochar(rowid), actl_stop_time) =
				       (SELECT MAX(rowidtochar(rowid)), MAX(actl_stop_time)
					FROM batch b3
					WHERE user_id = b2.user_id
					AND status = b2.status)))))))); 

---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

-- Output message for debugging.
PROCEDURE debug (i_message VARCHAR2);

------------------------------------------------------------------------
-- Procedure:
--    debug_on
--
-- Description:
--    This procedure turns debugging on.  Used during development.
------------------------------------------------------------------------
PROCEDURE debug_on;

------------------------------------------------------------------------
-- Procedure:
--    debug_off
--
-- Description:
--    This procedure turns debugging off.  Used during development.
------------------------------------------------------------------------
PROCEDURE debug_off;

------------------------------------------------------------------------
-- Function:
--    f_debugging
--
-- Description:
--    This function returns TRUE if debug is on otherwise FALSE.
--    Used during development.
------------------------------------------------------------------------
FUNCTION f_debugging
RETURN BOOLEAN;

---------------------------------------------------------------------------
-- Procedure:
--    merge_batch
--
-- Description:
--    This function merges the specified batch with the parent batch.
--    A parent batch can be designated if a parent does not exists.
---------------------------------------------------------------------------
PROCEDURE merge_batch(i_batch_no         IN arch_batch.batch_no%TYPE,
                      i_parent_batch_no  IN arch_batch.batch_no%TYPE);

---------------------------------------------------------------------------
-- Function:
--    f_get_destination_door_no
--
-- Description:
--    This function determines the 4 character labor mgmt destination door
--    number for an order selection float based on the door_area in the
--    floats table and the route freezer, cooler and dry door number.
--
--    Example:
--       float number is 123
--       float route_no is 1002
--       float.door_area is C
--       route.f_door is 3
--       route.c_door is 12
--       route.d_door is 20
--       Since the float.door_area is C we want the 4 character labor 
--       mgmt door number for route.c_door.  Package function
--       pl_lmf.f_get_fk_door_no is called to get this.
--
-- Parameters:
--    i_float_no              - Float number.
--  
-- Return Value:
--    Door number
--    Null if unable to find the door number.
--
-- Exceptions raised:
--    pl_exc.e_data_error                A called object returned an
--                                       user defined error.
--    pl_exc.e_database_error            Any other error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/07/02 prpbcb   Created.
---------------------------------------------------------------------------
FUNCTION f_get_destination_door_no (i_float_no   IN floats.float_no%TYPE)
RETURN VARCHAR2;

---------------------------------------------------------------------------
-- Procedure:
--    p_get_loader_batch_info
--
-- Description:
--    This procedure determines if the labor batch is type of loader batch.
--    If it is, return its ref_no value which has either truck# (loader
--    batch or truck unload), order_seq# (loader case batch or loader case
--    batch exit), loader batch# (loader float label exit or loader batch
--    not found) or stop# (load a stop). And also its cmt alue which has
--    either float_seq (loader batch), float# (loader case or loader stop),
--    or blank. If it's not loader batch related, both returned ref_no
--    and cmt should be blank. 
--    Returned batch_type is either blank if it's not loader batch related
--    or one of loader batch related constants.
--    If there is no input batch, the input user ID (need to be provided)
--    is used to determine the user's last batch. If there is no input
--    user also, return all no values.
---------------------------------------------------------------------------
PROCEDURE p_get_loader_batch_info (
	s_ref_no	OUT	batch.ref_no%TYPE,
	s_cmt		OUT	batch.cmt%TYPE,
	s_batch_type	OUT	VARCHAR2,
	s_batch_no	IN OUT	batch.batch_no%TYPE,
	s_user_id	IN	batch.user_id%TYPE DEFAULT NULL);

---------------------------------------------------------------------------
-- Procedure:
--    get_batch_type (overloaded)
--
-- Description:
--    This procedure determines the labor mgmt batch type and the key
--    value.  This is done by checking the first and if needed the second
--    character of the labor mgmt batch number.
--    If unable to determine the batch type then it will be set to null.
--    The calling object should check if the batch type is null after
--    calling this procedure.
---------------------------------------------------------------------------
PROCEDURE get_batch_type(i_batch_no    IN  arch_batch.batch_no%TYPE,
                         o_batch_type  OUT VARCHAR2,
                         o_key_value   OUT VARCHAR2);
---------------------------------------------------------------------------
-- Procedure:
--    p_get_last_batch()
--
-- Description:
--    This procedure is getting the last batch no for the given user.
---------------------------------------------------------------------------
PROCEDURE p_get_last_batch(i_user_id    IN  usr.user_id%TYPE,
                           o_batch_row   OUT c_get_cur_batch%rowtype,
                           o_status     OUT number,
			   i_batch_no	IN batch.batch_no%TYPE DEFAULT NULL);
---------------------------------------------------------------------------
-- Procedure:
--    pl_rf_logout()
--
-- Description:
--    This procedure is logout the user and do necessary updates.
---------------------------------------------------------------------------
PROCEDURE pl_rf_logout( l_user_id           IN VARCHAR2,
                        l_batch_row         IN batch%rowtype,
                        l_lm_logout_option  IN VARCHAR2,
                        l_logout_from       IN NUMBER,
                        o_status            OUT NUMBER,
                        o_msg               OUT VARCHAR2
);
---------------------------------------------------------------------------
-- FUNCTION:
--    get_batch_type (overloaded)
--
-- Description:
--    This function determines the labor mgmt batch type.
--    If unable to determine the batch type then it will be set to null.
--    The calling object should check if the batch type is null after
--    calling this function.
---------------------------------------------------------------------------
FUNCTION get_batch_type(i_batch_no    IN  arch_batch.batch_no%TYPE)
RETURN VARCHAR2;


---------------------------------------------------------------------------
-- Function:
--    f_boolean_text
--
-- Description:
--    This function returns the string 'TRUE' or 'FALSE' for a boolean.
--    If the boolean is null then NULL is returned.
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
--    07/10/08 prpbcb   Created.
--                      This was/is a private function in other packages.
--                      Added it here so it can be used by any package.
---------------------------------------------------------------------------
FUNCTION f_boolean_text(i_boolean IN BOOLEAN)
RETURN VARCHAR2;


---------------------------------------------------------------------------
-- Function:
--    is_three_part_move_active
--
-- Description:
--    This function returns TRUE if 3 part move is active for the pallet type
--    of a slot otherwise FALSE is returned.
---------------------------------------------------------------------------
FUNCTION is_three_part_move_active(i_logi_loc IN loc.logi_loc%TYPE)
RETURN BOOLEAN;

-- 7/21/21 mcha1213 adding new

PROCEDURE find_active_batch
             (i_user_id        IN  arch_batch.user_id%TYPE,
              o_batch_no       OUT arch_batch.batch_no%TYPE,
              o_is_parent_bln  OUT BOOLEAN,
              o_lbr_func       OUT job_code.lfun_lbr_func%type,
              o_status         OUT PLS_INTEGER);

PROCEDURE SignOn_To_Batch( i_user_id    IN  arch_batch.user_id%TYPE
                         , i_new_batch  IN  batch.batch_no%TYPE
                         , i_call_process_batch_bln IN BOOLEAN DEFAULT TRUE);


FUNCTION get_last_complete_batch
             (i_user_id    IN  arch_batch.user_id%TYPE)
RETURN VARCHAR2;

PROCEDURE signoff_forklift_labor_batch
               (i_batch_no              IN  VARCHAR2,
                i_equip_id              IN  VARCHAR2,
                i_user_id               IN  VARCHAR2,
                i_is_parent             IN  VARCHAR2,
                o_status                OUT NUMBER);

---------------------------------------------------------------------------
-- Function:
--    count_child_batches
--
-- Description:
--   This function which returns the number of child batches for a batch.
---------------------------------------------------------------------------
FUNCTION count_child_batches
                   (i_batch_no   IN  arch_batch.batch_no%TYPE)
RETURN PLS_INTEGER;


--
---------------------------------------------------------------------------
-- Function:
--    does_batch_exist
--
-- Description:
--    This function returns TRUE if a labor batch exists in the BATCH table
--    otherwise FALSE.
--    By default the BATCH_DATE is ignored.  The key on the BATCH table is
--    BATCH_NO and BATCH_DATE.
---------------------------------------------------------------------------
FUNCTION does_batch_exist
             (i_batch_no    IN  batch.batch_no%TYPE,
              i_batch_date  IN  DATE DEFAULT NULL)
RETURN BOOLEAN;


END pl_lmc;  -- end package specification
/


CREATE OR REPLACE PACKAGE BODY      pl_lmc
IS

-- sccs_id=%Z% %W% %G% %I%

---------------------------------------------------------------------------
-- Package Name:
--    pl_lmc
--
-- Description:
--    Labor management common objects.
--
--    Date     Designer Comments
--    -------- -------  ----------------------------------------------------
--    09/17/01 prpbcb   rs239a DN 10859  rs239b DN 10860  Created.  
--
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(20) := 'pl_lmc';   -- Package name.  Used in
                                          -- error messages.

gl_debug      BOOLEAN := FALSE;   -- Used for debugging during development.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.


---------------------------------------------------------------------------
-- Private Constants
---------------------------------------------------------------------------

ct_application_function VARCHAR2(10) := 'LABOR MGT';  -- For pl_log messages  -- 7/21/21 mcha1213 add

subtype STATUS is NATURALN; -- not null non-negative integer -- 7/21/21 mcha1213 add

STATUS_LM_LAST_IS_ISTOP         constant STATUS := 9999; -- User's last completed batch is an ISTOP -- 7/21/21 mcha1213 add

---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------



---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

-- Output message for debugging.
PROCEDURE debug (i_message VARCHAR2)
IS
BEGIN
   IF (pl_lmc.f_debugging) THEN
      DBMS_OUTPUT.PUT_LINE(i_message);
   END IF;
END debug;


---------------------------------------------------------------------------
-- Function:
--    f_get_destination_door_no
--
-- Description:
--    This function determines the 4 character labor mgmt destination door
--    number for an order selection float based on the door_area in the
--    floats table and the route freezer, cooler and dry door number.
--
--    Example:
--       float number is 123
--       float route_no is 1002
--       float.door_area is C
--       route.f_door is 3
--       route.c_door is 12
--       route.d_door is 20
--       Since the float.door_area is C we want the 4 character labor 
--       mgmt door number for route.c_door.  Package function
--       pl_lmf.f_get_fk_door_no is called to get this.
--
-- Parameters:
--    i_float_no              - Float number.
--  
-- Return Value:
--    Door number
--    Null if unable to find the door number.
--
-- Exceptions raised:
--    pl_exc.e_database_error    - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/07/02 prpbcb   Created.
---------------------------------------------------------------------------
FUNCTION f_get_destination_door_no (i_float_no   IN floats.float_no%TYPE)
RETURN VARCHAR2 IS
   l_message        VARCHAR2(256);    -- Message buffer
   l_message_param  VARCHAR2(256);    -- Message buffer
   l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                             '.f_get_destination_door_no';

   l_door_no     point_distance.point_a%TYPE := NULL;  -- Return value

   CURSOR c_doors IS
      SELECT f.door_area,
             LTRIM(TO_CHAR(r.d_door, '09')) d_door,
             LTRIM(TO_CHAR(r.c_door, '09')) c_door,
             LTRIM(TO_CHAR(r.f_door, '09')) f_door
        FROM route r, floats f
       WHERE r.route_no = f.route_no
         AND f.float_no = TO_NUMBER(i_float_no);

  r_doors   c_doors%ROWTYPE;

BEGIN

   l_message_param := l_object_name || '(' || TO_CHAR(i_float_no) ||
                ')   (i_float_no)';

   pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                  NULL, NULL);

   OPEN c_doors;
   FETCH c_doors INTO r_doors;
   IF (c_doors%NOTFOUND) THEN
      -- Found no record.  Write aplog message.
      CLOSE c_doors;
      l_message := 'Found no record for float || TO_CHAR(i_float_no) ||
          in table route and floats.';
      pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                     NULL, NULL);
      l_door_no := NULL;    -- Return null for the door number.
   ELSE
      CLOSE c_doors;

      -- Get the door number based on the door area.
      IF (r_doors.door_area = 'F') THEN
         l_door_no := pl_lmf.f_get_fk_door_no(r_doors.f_door);
      ELSIF (r_doors.door_area = 'C') THEN
         l_door_no := pl_lmf.f_get_fk_door_no(r_doors.c_door);
      ELSIF (r_doors.door_area = 'D') THEN
         l_door_no := pl_lmf.f_get_fk_door_no(r_doors.d_door);
      ELSE
         -- Unhandled door area.  Write aplog message.
         l_message := 'Float ' || TO_CHAR(i_float_no) ||
            ' has unhandled value of ' || r_doors.door_area || 
            ' for the door_area.';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                        NULL,  NULL);
         l_door_no := NULL;    -- Return null for the door number.
      END IF;
   END IF;

   RETURN(l_door_no);

EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                     SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END f_get_destination_door_no;


------------------------------------------------------------------------
-- Procedure:
--    debug_on
--
-- Description:
--    This procedure turns debugging on.  Used during development.
--
-- Parameters:
--    None
--  
-- Exceptions raised:
--    None
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/07/02 prpbcb   Created.
------------------------------------------------------------------------
PROCEDURE debug_on
IS
BEGIN
   gl_debug := TRUE;
END debug_on;


------------------------------------------------------------------------
-- Procedure:
--    debug_off
--
-- Description:
--    This procedure turns debugging off.  Used during development.
--
-- Parameters:
--    None
--  
-- Exceptions raised:
--    None
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/07/02 prpbcb   Created.
------------------------------------------------------------------------
PROCEDURE debug_off
IS
BEGIN
   gl_debug := FALSE;
END debug_off;


----------------------------------------------------------------------------
-- Function:
--    f_debugging
--
-- Description:
--    This function returns TRUE if debug is on otherwise FALSE.
--    Used during development.
--
-- Parameters:
--    None
--  
-- Return Value:
--    TRUE    debugging on
--    FALSE   debugging off
--
-- Exceptions raised:
--    None
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/07/02 prpbcb   Created.
----------------------------------------------------------------------------
FUNCTION f_debugging
RETURN BOOLEAN IS
BEGIN
   RETURN(gl_debug);
END f_debugging;


PROCEDURE p_get_loader_batch_info (
	s_ref_no	OUT	batch.ref_no%TYPE,
	s_cmt		OUT	batch.cmt%TYPE,
	s_batch_type	OUT	VARCHAR2,
	s_batch_no	IN OUT	batch.batch_no%TYPE,
	s_user_id	IN	batch.user_id%TYPE DEFAULT NULL) IS
  lrw_batch	c_get_cur_batch%ROWTYPE := NULL;
  li_status	NUMBER := 0;
  ls_batch_no	batch.batch_no%TYPE := s_batch_no;
  li_stop_no	float_detail.stop_no%TYPE := NULL;
  ls_funcname	VARCHAR2(50) := 'pl_lmc.p_get_loader_batch_info';
BEGIN
  s_ref_no := NULL;
  s_cmt := NULL;
  s_batch_type := NULL;

  IF s_batch_no IS NULL AND s_user_id IS NOT NULL THEN
    p_get_last_batch (s_user_id, lrw_batch, li_status);
    pl_text_log.ins_msg (pl_lmc.ct_warn_msg, ls_funcname,
	'No input batch but user [' || s_user_id || '] last batch status[' ||
	TO_CHAR(li_status) || '] batch[' || lrw_batch.batch_no || ']',
	NULL, NULL);
    IF li_status IN (0, -3)
    THEN
      ls_batch_no := lrw_batch.batch_no;
    END IF;
  ELSIF s_batch_no IS NOT NULL
  THEN
    p_get_last_batch (NULL, lrw_batch, li_status, s_batch_no);
    pl_text_log.ins_msg (pl_lmc.ct_warn_msg, ls_funcname,
	'Input batch [' || s_batch_no || '] last batch status[' ||
	TO_CHAR(li_status) || '] batch[' || lrw_batch.batch_no || ']',
	NULL, NULL);
    IF li_status IN (0, -3)
    THEN
      ls_batch_no := lrw_batch.batch_no;
    END IF;
  END IF;

  IF ls_batch_no IS NULL
  THEN
    RETURN;
  END IF;

  IF SUBSTR(ls_batch_no, 1, 2) = ct_loader_case OR
     SUBSTR(ls_batch_no, 1, 1) = ct_indirect OR
     SUBSTR(ls_batch_no, 1, 1) = ct_loader OR
     (SUBSTR(ls_batch_no, 1, 1) = ct_loader AND INSTR(ls_batch_no, 'R') <> 0) OR
     (SUBSTR(ls_batch_no, 1, 1) = ct_loader AND INSTR(ls_batch_no, 'U') <> 0)
  THEN
    s_ref_no := lrw_batch.ref_no;
    s_cmt := lrw_batch.cmt;

    IF SUBSTR(ls_batch_no, 1, 2) = ct_loader_case
    THEN
      s_batch_type := ct_loader_case;
      BEGIN
        SELECT DISTINCT stop_no INTO li_stop_no
        FROM floats f, float_detail d
        WHERE f.float_no = d.float_no
        AND   f.float_no = TO_NUMBER(lrw_batch.cmt);
      EXCEPTION
        WHEN OTHERS THEN
          li_stop_no := NULL;
      END;
      IF li_stop_no IS NOT NULL
      THEN
        s_batch_type := ct_loader_stop;
      END IF;

      IF SUBSTR(ls_batch_no, 1, 2) = ct_loader
      THEN
        s_batch_type := ct_loader;
        IF INSTR(ls_batch_no, 'R') <> 0
        THEN
          s_batch_type := ct_loader_reload;
        END IF;
        IF INSTR(ls_batch_no, 'U') <> 0
        THEN
          s_batch_type := ct_loader_unload;
        END IF;
      END IF;
    END IF;

    IF SUBSTR(ls_batch_no, 1, 1) = ct_indirect
    THEN
      IF lrw_batch.jbcd_job_code = 'ILFEXT'
      THEN
        s_batch_type := ct_loader_flt_exit;
      ELSIF lrw_batch.jbcd_job_code = 'ILBNFD'
      THEN
        s_batch_type := ct_loader_flt_exit;
      ELSIF lrw_batch.jbcd_job_code = 'ILUTK'
      THEN
        s_batch_type := ct_loader_unload_truck;
      ELSIF lrw_batch.jbcd_job_code = 'ILCEXT'
      THEN
        s_batch_type := ct_loader_cse_exit;
      END IF;
    END IF;
  END IF;

END p_get_loader_batch_info;

---------------------------------------------------------------------------
-- Procedure:
--    get_batch_type
--
-- Description:
--    This procedure determines the labor mgmt batch type and the key
--    value.  This is done by checking the first and if needed the second
--    character of the labor mgmt batch number.
--    If unable to determine the batch type then it will be set to null.
--    The calling object should check if the batch type is null after
--    calling this procedure.
--
-- Parameters:
--    i_batch_no    - Labor mgmt batch number.
--    o_batch_type  - The type of batch -- selection, loader,
--                    forklift putaway, ...   This will be set to NULL
--                    if unable to determine it.
--    o_key_value   - This is the value from the table(s)
--                    initially used to create the labor mgmt
--                    batch and is usually part of the labor
--                    mgmt batch number.
--                    Example:  Labor batch: S42344
--                              This is a selection batch with
--                              42344 being the floats.batch_no.
--                              The key value is 42344.
--                    Example:  Labor batch: FP5232332
--                              This is a forklift putaway with
--                              5232332 being the pallet id for non-RDC
--                              pallets and a sequence for RDC pallets.
--                              The key value is 5232332.
--                    Example:  Labor batch: FN22345
--                              This is a forklift non-demand with
--                              22345 being the replenlst task id.
--                              The key value is 22345.
--  
-- Exceptions raised:
--    pl_exc.e_database_error     - Got an oracle error.
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/11/02 prpbcb   Created.
--    02/18/05 prpbcb   Modified to recognize a T batch.
--    08/02/05 prpbcb   Modified to recognize a FE batch which is a return
--                      to reserve of a partially completed demand
--                      replenishment.
--    09/27/06 prpbcb   Modified to recognize a SS batch.
---------------------------------------------------------------------------
PROCEDURE get_batch_type(i_batch_no    IN  arch_batch.batch_no%TYPE,
                         o_batch_type  OUT VARCHAR2,
                         o_key_value   OUT VARCHAR2)
IS
   l_message_param  VARCHAR2(128);    -- Message buffer
   l_object_name    VARCHAR2(61) := gl_pkg_name || '.get_batch_type';

   l_first_char         VARCHAR2(1);      -- 1st character in i_batch_no
   l_first_second_char  VARCHAR2(2);      -- 1st, 2nd character in i_batch_no

   e_unknown_batch_type  EXCEPTION;

BEGIN

   l_message_param := l_object_name ||
      '(i_batch_no[' || i_batch_no || '],o_batch_type,o_key_value)';

   pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                  NULL, NULL);

   l_first_char := SUBSTR(i_batch_no, 1, 1);
   l_first_second_char := SUBSTR(i_batch_no, 1, 2);

   -- Initialization
   o_batch_type := NULL;
   o_key_value := NULL;

   IF( l_first_second_char = ct_selection_short_runner) THEN
      o_batch_type := ct_selection_short_runner;
      o_key_value := SUBSTR(i_batch_no, 2);
   ELSIF (l_first_char = ct_selection) THEN
      o_batch_type := ct_selection;
      o_key_value := SUBSTR(i_batch_no, 2);
   ELSIF (l_first_char = ct_indirect) THEN
      o_batch_type := ct_indirect;
      o_key_value := SUBSTR(i_batch_no, 2);
   ELSIF (l_first_char = ct_loader) THEN
      o_batch_type := ct_loader;
   ELSIF (l_first_second_char = ct_forklift_putaway) THEN
      o_batch_type := ct_forklift_putaway;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF(l_first_second_char = ct_forklift_nondemand_rpl) THEN
      o_batch_type := ct_forklift_nondemand_rpl;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF(l_first_second_char = ct_forklift_demand_rpl) THEN
      o_batch_type := ct_forklift_demand_rpl;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF(l_first_second_char = ct_forklift_transfer) THEN
      o_batch_type := ct_forklift_transfer;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF(l_first_second_char = ct_forklift_pallet_pull) THEN
      o_batch_type := ct_forklift_pallet_pull;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF(l_first_second_char =  ct_forklift_home_slot_xfer) THEN
      o_batch_type := ct_forklift_home_slot_xfer;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF (l_first_second_char = ct_forklift_drop_to_home) THEN
      o_batch_type := ct_forklift_drop_to_home;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF (l_first_second_char = ct_forklift_dmd_rpl_hs_xfer) THEN
      o_batch_type := ct_forklift_dmd_rpl_hs_xfer;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF(l_first_second_char = ct_forklift_inv_adj) THEN
      o_batch_type := ct_forklift_inv_adj;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF(l_first_second_char = ct_forklift_swap) THEN
      o_batch_type := ct_forklift_swap;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF(l_first_second_char = ct_forklift_combine_pull) THEN
      o_batch_type := ct_forklift_combine_pull;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF(l_first_second_char = ct_forklift_cycle_count) THEN
      o_batch_type := ct_forklift_cycle_count;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF(l_first_second_char = ct_forklift_haul) THEN
      o_batch_type := ct_forklift_haul;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF(l_first_second_char = ct_forklift_f1_haul) THEN
      o_batch_type := ct_forklift_f1_haul;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF(l_first_second_char = ct_forklift_break_away_haul) THEN
      o_batch_type := ct_forklift_break_away_haul;
      o_key_value := SUBSTR(i_batch_no, 3);
   ELSIF (l_first_char = ct_returns_putaway) THEN
      o_batch_type := ct_returns_putaway;
      o_key_value := SUBSTR(i_batch_no, 2);
-- 11/27/2015 aklu6632, add for charm 6000003040
   ELSIF (l_first_second_char = ct_po) THEN
      o_batch_type := ct_po;
      o_key_value := SUBSTR (i_batch_no, 3);
   ELSE
      -- Unable to determine the batch type.  Write aplog message.
      pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
         l_message_param || '  Could not determine the batch type.' ||
         '  Using NULL.',
         NULL, NULL);
   END IF;

EXCEPTION     
   WHEN OTHERS THEN
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                     SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_message_param);

END get_batch_type;

---------------------------------------------------------------------------
-- Procedure:
--    p_get_last_batch
--
-- Description:
--    This procedure is get the last batch no for the given user.
--
-- Parameters:
--    i_user_id     - User id.
--    o_batch_row    - The active batch row in the table batch for given user.
--    o_status      - Status of lookup for batch_no
--                  -1, If no user ID is input or invalid user or database error
--                  -2, If user has no last batch
--                  0, If user has active last batch or specific batch is found
--		    -3, If batch exists for user and it's status is C or M
--		    -4, other database error
--    i_batch_no    - If batch# is provided, get its info
--
-- Exceptions raised:
--    pl_exc.e_database_error     - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/27/15 aklu6632 Created.
---------------------------------------------------------------------------
   PROCEDURE p_get_last_batch (
      i_user_id    IN       usr.user_id%TYPE,
      o_batch_row  OUT      c_get_cur_batch%ROWTYPE,
      o_status     OUT      NUMBER,
      i_batch_no   IN	    batch.batch_no%TYPE DEFAULT NULL
   )
   IS
      l_message_param     VARCHAR2 (500);                   -- Message buffer
      l_object_name       VARCHAR2 (61) := gl_pkg_name || '.p_get_last_batch';
      l_user_exists       VARCHAR2 (1);                -- check user existing
      e_unknown_user_id   EXCEPTION;
      i_found		  NUMBER := 0;
      l_cur_row		  c_get_cur_batch%ROWTYPE := NULL;
   BEGIN
      o_status := 0;
      o_batch_row := NULL;
/*
      l_message_param := l_object_name || '- USER_ID[' || i_user_id ||
	'] batch[' || i_batch_no || ']';
      pl_log.ins_msg (pl_lmc.ct_debug_msg,
                      l_object_name,
                      l_message_param,
                      NULL,
                      NULL
                     );
      pl_text_log.ins_msg (pl_lmc.ct_warn_msg,
                      l_object_name,
                      l_message_param,
                      NULL,
                      NULL
                     );
*/
      BEGIN
         SELECT 'Y'
           INTO l_user_exists
           FROM usr
          WHERE user_id LIKE '%' || i_user_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            o_status := -1;
            RAISE e_unknown_user_id;
      END;

  i_found := 0;
  IF i_batch_no IS NOT NULL THEN
    -- Get batch info for specific batch
    OPEN c_get_cur_batch(i_batch_no, i_user_id);
    FETCH c_get_cur_batch INTO l_cur_row;
    IF c_get_cur_batch%NOTFOUND THEN
      i_found := 1;
    END IF;
    CLOSE c_get_cur_batch;
  END IF;
  IF i_found = 1 OR i_batch_no IS NULL THEN
    i_found := 0;
    -- Get batch info for user if exists active batch
    OPEN c_get_cur_batch(i_batch_no, i_user_id, 'Y');
    FETCH c_get_cur_batch INTO l_cur_row;
    IF c_get_cur_batch%NOTFOUND THEN
      IF c_get_cur_batch%NOTFOUND THEN
        i_found := 1;
      END IF;
    END IF;
    CLOSE c_get_cur_batch;
  END IF;
  IF i_found = 1 THEN
    i_found := 0;
    -- Get batch info for user if no active batch
    OPEN c_get_cur_batch(i_batch_no, i_user_id, 'N');
    FETCH c_get_cur_batch INTO l_cur_row;
    IF c_get_cur_batch%NOTFOUND THEN
      IF c_get_cur_batch%NOTFOUND THEN
        i_found := 1;
      END IF;
    END IF;
    CLOSE c_get_cur_batch;
  END IF;

  IF i_found = 1 THEN
	-- Cannot find the specified batch or no batch is found for user
	-- or user has no batch yet
	l_cur_row.batch_no := '?';
	l_cur_row.status := '?';
	l_cur_row.jbcd_job_code := '?';
	o_status := -2;
  ELSE
	IF l_cur_row.status IN ('C', 'M') THEN
		-- At least one/last user batch is completed
		o_status := -3;
	END IF;
  END IF;

  o_batch_row := l_cur_row;

   EXCEPTION
      WHEN e_unknown_user_id
      THEN
         NULL;
      WHEN OTHERS
      THEN
         o_status := -4;
	 l_message_param := 
         	l_object_name || '- USER_ID[' || i_user_id ||
	         '] bat[' || i_batch_no || '] rtn status[' ||
		to_char(o_status) || '] error [' ||
		to_char(sqlcode) || ']';
         pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                         l_object_name,
                         l_message_param,
                         SQLCODE,
                         SQLERRM
                        );
         pl_text_log.ins_msg (pl_lmc.ct_fatal_msg,
                         l_object_name,
                         l_message_param,
                         SQLCODE,
                         SQLERRM
                        );
         raise_application_error (pl_exc.ct_database_error, l_message_param);
   END p_get_last_batch;

---------------------------------------------------------------------------
-- Procedure:
--    insert_logout_ind_batch 
--
-- Description:
--    This procedure is to add the requested indirect batch according to
--    input criteria. The batch will includ duration if it's set up.
--
-- Parameters:
--    l_user_id     - User id.
--    l_batch_no - The batch used to get the stop duration value.
--    l_job_code - The indirect batch job code to be used.
--    l_stop_time - The latest stop time if any to be give back to caller after
--	the last indirect batch was completed.
--    l_status - Status of the indirect batch to be set, default C(ompleted).
--    l_start_time - Start time of the indirect batch to be used.
--    l_iwash_added - If IWASH w/ duraction has been added before (TRUE) or not.
--
-- Exceptions raised:
--    pl_exc.e_database_error     - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/27/16 jluo6971 Created.
---------------------------------------------------------------------------

FUNCTION insert_logout_ind_batch (
	l_user_id	IN	batch.user_id%TYPE,
	l_batch_no	IN	batch.batch_no%TYPE,
	l_job_code	IN	batch.jbcd_job_code%TYPE,
	l_stop_time	OUT	batch.actl_stop_time%TYPE,
	l_status	IN	batch.status%TYPE DEFAULT 'C',
	l_start_time	IN	batch.actl_start_time%TYPE DEFAULT SYSDATE,
	l_iwash_added	IN	BOOLEAN DEFAULT FALSE)
RETURN NUMBER IS
	l_durstop	NUMBER := 0;
	l_superid	batch.user_supervsr_id%TYPE := NULL;
  l_func_status NUMBER := 0;
  l_object_name	VARCHAR2(61) := gl_pkg_name || '.insert_logout_ind_batch';
  l_in_stop_time DATE := l_start_time;
BEGIN
  l_stop_time := NULL;

  BEGIN
      SELECT suprvsr_user_id
      INTO l_superid
      FROM usr
      WHERE user_id LIKE '%' || l_user_id;
   EXCEPTION
	WHEN OTHERS THEN
		l_superid := 'NO_USER';
  END;
  BEGIN
      SELECT NVL (st.stop_dur, 0)
        INTO l_durstop
        FROM sched_type st,
             sched s,
             usr u,
             batch b,
             job_code jc
       WHERE st.sctp_sched_type = s.sched_type
         AND s.sched_lgrp_lbr_grp = u.lgrp_lbr_grp
         AND s.sched_jbcl_job_class = jc.jbcl_job_class
         AND s.sched_actv_flag = 'Y'
         AND u.user_id LIKE '%' || l_user_id
         AND jc.jbcd_job_code = b.jbcd_job_code
         AND b.batch_no = RTRIM (l_batch_no);
  EXCEPTION
	WHEN OTHERS THEN
		l_durstop := 0;
  END;
  pl_text_log.ins_msg (pl_lmc.ct_warn_msg,
			l_object_name,
			'Cur batch[' || l_batch_no || '] indirect to add [' || 
			l_job_code || '] user[' || l_user_id || '] dur[' ||	
			TO_CHAR(l_durstop) || '] start[' ||
			TO_CHAR(l_start_time, 'mm/dd/yyyy hh24:mi:ss') || ']',
			NULL, NULL);
  IF l_job_code = 'ICHJOB'
  THEN
	-- Don't use duration for job change
	l_durstop := 0;
  ELSIF l_job_code = 'IWASH' 
  THEN 
	IF l_durstop = 0
	THEN
		-- If IWASH and no duration, don't create IWASH.
		-- The stop time can be used for the next ISTOP's start time
		l_stop_time := NVL(l_start_time, SYSDATE);
		RETURN -3;
	ELSE
		l_func_status := -4;
	END IF;
  END IF;

  IF l_iwash_added AND l_job_code = 'ISTOP' THEN
	-- There was IWASH before ISTOP. The ISTOP shouldn't have any duration
	l_in_stop_time := NVL(l_start_time, SYSDATE);
  ELSE
	l_in_stop_time := NVL(l_start_time, SYSDATE) + l_durstop / 1440;
  END IF;

  BEGIN
      INSERT INTO batch
        (batch_no, batch_date, jbcd_job_code, status,
         actl_start_time, actl_stop_time, actl_time_spent,
         user_id, user_supervsr_id, kvi_doc_time, kvi_cube,
         kvi_wt, kvi_no_piece, kvi_no_pallet, kvi_no_item,
         kvi_no_data_capture, kvi_no_po, kvi_no_stop,
         kvi_no_zone, kvi_no_loc, kvi_no_case, kvi_no_split,
         kvi_no_merge, kvi_no_aisle, kvi_no_drop,
         kvi_order_time, no_lunches, no_breaks, damage)
        VALUES ('I' || TO_CHAR (seq1.NEXTVAL), TRUNC (SYSDATE),
         l_job_code, l_status,
	 l_start_time,
	 CASE l_status
		WHEN 'A' THEN NULL
		ELSE l_in_stop_time
	 END,
	 0, l_user_id,
	 l_superid, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	 0, 0, 0, 0, 0);
      l_stop_time := l_in_stop_time;
      IF SQL%ROWCOUNT = 0
      THEN
	l_func_status := -2;
      END IF;
      -- Return 0 for good insert
  EXCEPTION
	WHEN OTHERS THEN
		l_func_status := -1;
		pl_text_log.ins_msg (pl_lmc.ct_warn_msg,
			l_object_name,
			'Error ins ' || l_job_code || ' for user ' ||
			l_user_id,
			SQLCODE,
			SQLERRM);	
  END;

  RETURN l_func_status;
END;

---------------------------------------------------------------------------
-- Procedure:
--    pl_rf_logout
--
-- Description:
--    This procedure is to perform logout process for forklift/RF/SOS/SLS.
--    Depending on the input logout option, specific indirect batch(es)
--    are created.
--
-- Parameters:
--    i_user_id     - User id.
--    l_batch_row   - The row of table batch
--    l_batch_type  - batch type,
--    l_lm_logout_option  -S, stop
--                        -C, change
--                        -L, straightly log out 
--    l_logout_from       -1, selector logout
--                        -2, LoaderLogout
--    l_status            --output status
--    l_msg               --output message, optional parm
--
-- Exceptions raised:
--    pl_exc.e_database_error     - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/27/15 aklu6632 Created.
---------------------------------------------------------------------------

PROCEDURE pl_rf_logout (
   l_user_id            IN       VARCHAR2,
   l_batch_row          IN       batch%ROWTYPE,
   l_lm_logout_option   IN       VARCHAR2,
   l_logout_from        IN       NUMBER,
   o_status             OUT      NUMBER,
   o_msg                OUT      VARCHAR2
)
IS
   l_message_param   VARCHAR2 (128);                        -- Message buffer
   l_object_name     VARCHAR2 (61)          := gl_pkg_name || '.pl_rf_logout';
   l_timespent       arch_batch.actl_time_spent%TYPE;
   s_batch_type      VARCHAR2 (10);
   l_stop_time	     DATE := NULL;
   excp_efl_status   EXCEPTION;
   l_cur_batch	     c_get_cur_batch%ROWTYPE := NULL;
   l_status	     NUMBER := 0;
   l_job_code1	     job_code.jbcd_job_code%TYPE := NULL;
   l_job_code2	     job_code.jbcd_job_code%TYPE := NULL;
   l_batch_status    batch.status%TYPE := NULL;
   l_ins_status1     NUMBER := 0;
   l_ins_status2     NUMBER := 0;
   l_iwash_done	     BOOLEAN :=FALSE;
BEGIN
/*
   l_message_param :=
         l_object_name
      || '(USER_ID[' || l_user_id
      || '],l_lm_logout_option[' || l_lm_logout_option
      || '],l_logout_from[' || l_logout_from
      || '] batch[' || l_batch_row.batch_no || '] start['
      || TO_CHAR(l_batch_row.actl_start_time, 'mm/dd/yyyy hh24:mi:ss')
      || '] stop[' ||
	TO_CHAR(l_batch_row.actl_stop_time, 'mm/dd/yyyy hh24:mi:ss') || ']';
   pl_text_log.ins_msg (pl_lmc.ct_warn_msg,
                   l_object_name,
                   l_message_param,
                   NULL,
                   NULL
                  );
*/
   -- Initialization
   o_status := 0;
   o_msg := '';

   IF l_lm_logout_option = ct_logout_option_L
   THEN
	-- Don't go on if straight logout
	RETURN;
   END IF;

   -- Retrieve the user's last batch if any
   BEGIN
	p_get_last_batch (l_user_id, l_cur_batch,
		l_status, l_batch_row.batch_no);
	pl_text_log.ins_msg (pl_lmc.ct_warn_msg,
		l_object_name,
		'User[' || l_user_id || '] bat[' || l_batch_row.batch_no ||
		'] after p_get_last_batch status[' || TO_CHAR(l_status) ||
		'] found bat[' || l_cur_batch.batch_no || '] sta[' ||
		l_cur_batch.status || '] logoutOpt[' || l_lm_logout_option ||
		'] logoutFrom[' || TO_CHAR(l_logout_from) || ']',
		NULL, NULL);   
   EXCEPTION
	WHEN OTHERS THEN
		pl_text_log.ins_msg (pl_lmc.ct_fatal_msg,
                   l_object_name,
                   'User[' || l_user_id || '] bat[' || l_batch_row.batch_no ||
		   ' ' || 'after p_get_last_batch: Other DB error',
                   SQLCODE,
                   SQLERRM 
                  );
   END;

   IF l_status IN (0, -3)
   THEN
	-- Active batch is found or last completed/merged batch is found

	-- Complete the last batch if still active
	IF l_status = 0
	THEN
		pl_text_log.ins_msg (pl_lmc.ct_warn_msg,
			l_object_name,
			'User[' || l_user_id || '] bat[' ||
			l_batch_row.batch_no || '] Want to complete batch[' ||
			l_cur_batch.batch_no || ']',
			NULL, NULL);   
		pl_lm1.create_schedule (l_cur_batch.batch_no,
			SYSDATE, l_timespent);
	END IF;

	-- Retrieve user's last batch again. It should have been completed
	-- if it's previously active
	p_get_last_batch (l_user_id, l_cur_batch,
		l_status, l_cur_batch.batch_no);
	IF l_status IN (0, -3)
	THEN
		-- Get batch type for the found last batch
		s_batch_type := get_batch_type (l_cur_batch.batch_no);
		l_batch_status := 'C';
		IF l_lm_logout_option = 'C'
		THEN
			l_batch_status := 'A';
		END IF;

		IF s_batch_type IN (pl_lmc.ct_selection,
			pl_lmc.ct_selection_short_runner,
			pl_lmc.ct_loader, pl_lmc.ct_indirect) THEN
			l_job_code2 := 'IWASH';
		END IF;

		SELECT CASE l_lm_logout_option
			WHEN ct_logout_option_S THEN 'ISTOP'
			WHEN ct_logout_option_L THEN 'ISTOP'
			WHEN ct_logout_option_C THEN 'ICHJOB'
		       END
		INTO l_job_code1
		FROM DUAL;

		IF l_job_code2 = 'IWASH' AND
		   ((l_lm_logout_option = ct_logout_option_C) OR
		    (l_lm_logout_option IN (ct_logout_option_L,
			ct_logout_option_S) AND
		     (l_logout_from = ct_logout_from_rf))) THEN
			-- ICHJOB an ISTOP from RF not to do IWASH
			l_job_code2 := NULL;
		END IF;

		l_stop_time := l_cur_batch.actl_stop_time;

		pl_text_log.ins_msg (pl_lmc.ct_warn_msg,
			l_object_name,
			'User[' || l_user_id || '] bat[' ||
			l_cur_batch.batch_no || '] jc1[' || l_job_code1 ||
			'] jc2[' || l_job_code2 || '] typ[' ||
			s_batch_type|| '] batchsta[' || l_batch_status || ']',
			NULL, NULL);   

		IF l_job_code2 IS NOT NULL
		THEN
			-- Give and complete IWASH for selection/loader batches
			l_ins_status1 := insert_logout_ind_batch (l_user_id,
				l_cur_batch.batch_no, l_job_code2,
				l_stop_time,
				'C', l_cur_batch.actl_stop_time);
/*
			pl_text_log.ins_msg (pl_lmc.ct_warn_msg,
				l_object_name,
				'User[' || l_user_id || '] bat[' ||
				l_cur_batch.batch_no ||
				'] Added [' || l_job_code2 || '] status[' ||
				TO_CHAR(l_ins_status) || '] newstop[' ||
				TO_CHAR(l_stop_time, 'MM/DD/YYYY HH24:MI:SS') ||
				']',
				NULL, NULL);   
*/
		END IF;

		IF l_job_code1 IS NOT NULL
		THEN
			IF l_ins_status1 = -4
			THEN
				l_iwash_done := TRUE;
			END IF;
			-- Give ISTOP/ICHJOB for logout 
			l_ins_status2 := insert_logout_ind_batch (l_user_id,
				l_cur_batch.batch_no, l_job_code1,
				l_stop_time,
				l_batch_status, l_stop_time,
				l_iwash_done);
/*
			pl_text_log.ins_msg (pl_lmc.ct_warn_msg,
				l_object_name,
				'User[' || l_user_id || '] bat[' ||
				l_cur_batch.batch_no ||
				'] Added [' || l_job_code1 || '] status[' ||
				TO_CHAR(l_ins_status) || '] newstop[' ||
				TO_CHAR(l_stop_time, 'MM/DD/YYYY HH24:MI:SS') ||
				']',
				NULL, NULL);   
*/
		END IF;
	END IF;
   END IF;

   pl_text_log.ins_msg (pl_lmc.ct_warn_msg,
	l_object_name,
	'User[' || l_user_id || '] bat[' ||
	l_batch_row.batch_no ||
	'] Done pl_lmc.pl_rf_logout',
	NULL, NULL);   

EXCEPTION
   WHEN OTHERS
   THEN
	l_message_param := 'pl_lmc.pl_rf_logout failed';
      pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                      l_object_name,
                      l_message_param,
                      SQLCODE,
                      SQLERRM
                     );
      pl_text_log.ins_msg (pl_lmc.ct_fatal_msg,
                      l_object_name,
                      l_message_param,
                      SQLCODE,
                      SQLERRM
                     );
      raise_application_error (pl_exc.ct_database_error, l_message_param);
END pl_rf_logout;
---------------------------------------------------------------------------
-- Function:
--    get_batch_type
--
-- Description:
--    This function determines the labor mgmt batch type.
--    If unable to determine the batch type then it will be set to null.
--    The calling object should check if the batch type is null after
--    calling this function.
--
-- Parameters:
--    i_batch_no    - Labor mgmt batch number.
--
-- Return Value:
--    The type of batch -- selection, loader, forklift putaway, ...
--    If unable to determine the batch type then NULL is returned.
--  
-- Exceptions raised:
--    User defined exception   - A called object returned an user
--                               defined error.
--    pl_exc.e_database_error  - Got an oracle error.
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/11/02 prpbcb   Created.
---------------------------------------------------------------------------
FUNCTION get_batch_type(i_batch_no    IN  arch_batch.batch_no%TYPE)
RETURN VARCHAR2
IS
   l_message_param   VARCHAR2(128);    -- Message buffer
   l_object_name     VARCHAR2(61) := gl_pkg_name || '.get_batch_type';

   l_batch_type      VARCHAR2(10);  -- The type of batch.

   l_hold_key_value  VARCHAR2(50);  -- Holding place for the key value.
BEGIN

   l_message_param := l_object_name || '(i_batch_no[' || i_batch_no || '])';

   -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
   --             NULL, NULL);

   get_batch_type(i_batch_no, l_batch_type, l_hold_key_value);

   RETURN(l_batch_type);

EXCEPTION     
   WHEN OTHERS THEN
      IF (SQLCODE <= -20000) THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE;
      ELSE
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_message_param);
      END IF;

END get_batch_type;


---------------------------------------------------------------------------
-- Procedure:
--    merge_batch
--
-- Description:
--    This function merges the specified batch with the parent batch.
--    A parent batch can be designated if a parent does not exists.
--
-- Parameters:
--    i_batch_no         - Batch to be merged.
--    i_parent_batch_no  - Parent batch.
--
-- Exceptions raised:
--    pl_exc.e_no_lm_batch_found   - Could not find batch.
--    pl_exc.e_no_lm_parent_found  - Could not find parent batch.
--    pl_exc.e_lm_batch_upd_fail   - Could not modify batch.
--    pl_exc.e_lm_parent_upd_fail  - Could not modify parent batch.
--    pl_exc.e_data_error          - Parameter is null.
--    pl_exc.e_database_error      - Got an oracle error.
--
-- Called by:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/13/03 prpbcb   Created for MSKU.
--                      Package version of lmc_merge_batch in lm_common.pc.
--                      but not quite the same.  Needs more work.
---------------------------------------------------------------------------
PROCEDURE merge_batch(i_batch_no         IN arch_batch.batch_no%TYPE,
                      i_parent_batch_no  IN arch_batch.batch_no%TYPE)

IS
   l_message        VARCHAR2(512);    -- Message buffer
   l_object_name    VARCHAR2(61) := gl_pkg_name || '.merge_batch';

   -- This cursor selects info about the batch to be merged.
   CURSOR c_batch(cp_batch_no arch_batch.batch_no%TYPE) IS
      SELECT NVL(target_time, 0) target_time,
             NVL(goal_time, 0)   goal_time
        FROM batch
       WHERE batch_no = cp_batch_no;

   -- This cursor selects info about the parent batch.
   CURSOR c_parent_batch(cp_parent_batch_no arch_batch.batch_no%TYPE) IS
      SELECT parent_batch_date,
             user_id,
             user_supervsr_id,
             equip_id
        FROM batch
       WHERE batch_no = cp_parent_batch_no;

   r_batch         c_batch%ROWTYPE;
   r_parent_batch  c_parent_batch%ROWTYPE;
BEGIN

   IF (i_batch_no IS NULL OR i_parent_batch_no IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   OPEN c_batch(i_batch_no);
   FETCH c_batch INTO r_batch;
   IF (c_batch%NOTFOUND) THEN
      CLOSE c_batch;
      RAISE pl_exc.e_no_lm_batch_found;
   ELSE
      CLOSE c_batch;
   END IF;

   OPEN c_parent_batch(i_parent_batch_no);
   FETCH c_parent_batch INTO r_parent_batch;
   IF (c_parent_batch%NOTFOUND) THEN
      CLOSE c_parent_batch;
      RAISE pl_exc.e_no_lm_parent_found;
   ELSE
      CLOSE c_parent_batch;
   END IF;

   UPDATE batch b
      SET b.status          = 'M',
          actl_start_time   = SYSDATE,
          actl_stop_time    = SYSDATE,
          parent_batch_no   = i_parent_batch_no,
          parent_batch_date = r_parent_batch.parent_batch_date,
          user_id           = r_parent_batch.user_id,
          user_supervsr_id  = r_parent_batch.user_supervsr_id,
          equip_id          = r_parent_batch.equip_id,
          goal_time         = 0,
          target_time       = 0,
          total_count       = 0,
          total_pallet      = 0,
          total_piece       = 0
    WHERE batch_no = i_batch_no;

   IF (SQL%NOTFOUND) THEN
      RAISE pl_exc.e_lm_batch_upd_fail;
   END IF;

   UPDATE batch
      SET target_time  = target_time + r_batch.target_time,
          goal_time    = goal_time + r_batch.goal_time,
          total_count  = total_count + 1,
          total_pallet = total_pallet + 1
    WHERE batch_no = i_parent_batch_no;

   IF (SQL%NOTFOUND) THEN
      RAISE pl_exc.e_lm_parent_upd_fail;
   END IF;

EXCEPTION
   WHEN gl_e_parameter_null THEN
      l_message := l_object_name || '(i_batch_no[' || i_batch_no || '],' ||
          ',i_parent_batch_no[' || i_parent_batch_no || '])' ||
          '  Parameter is null.';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

   WHEN pl_exc.e_no_lm_batch_found THEN
      l_message := l_object_name || '(i_batch_no[' || i_batch_no || '],' ||
          ',i_parent_batch_no[' || i_parent_batch_no || '])' ||
          '  TABLE=BATCH Batch#=[' || i_batch_no || ']  ACTION=SELECT' ||
          '  MESSAGE="Did not find the batch number."';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_no_lm_batch_found, NULL);
      RAISE_APPLICATION_ERROR(pl_exc.ct_no_lm_batch_found, l_message);

   WHEN pl_exc.e_no_lm_parent_found THEN
      l_message := l_object_name || '(i_batch_no[' || i_batch_no || '],' ||
          ',i_parent_batch_no[' || i_parent_batch_no || '])' ||
          '  TABLE=BATCH Batch#=[' || i_batch_no || ']  ACTION=SELECT' ||
          '  MESSAGE="Did not find the parent batch number."';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_no_lm_batch_found, NULL);
      RAISE_APPLICATION_ERROR(pl_exc.ct_no_lm_parent_found, l_message);

   WHEN pl_exc.e_lm_batch_upd_fail THEN
      l_message := l_object_name || '(i_batch_no[' || i_batch_no || '],' ||
          ',i_parent_batch_no[' || i_parent_batch_no || '])' ||
          '  TABLE=BATCH Batch#=[' || i_batch_no || ']  ACTION=UPDATE' ||
          '  MESSAGE="Did not find the batch number."';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_no_lm_batch_found, NULL);
      RAISE_APPLICATION_ERROR(pl_exc.ct_no_lm_batch_found, l_message);

   WHEN pl_exc.e_lm_parent_upd_fail THEN
      l_message := l_object_name || '(i_batch_no[' || i_batch_no || '],' ||
          ',i_parent_batch_no[' || i_parent_batch_no || '])' ||
          '  TABLE=BATCH Batch#=[' || i_batch_no || ']  ACTION=UPDATE' ||
          '  MESSAGE="Did not find the parent batch number."';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_no_lm_batch_found, NULL);
      RAISE_APPLICATION_ERROR(pl_exc.ct_no_lm_parent_found, l_message);

END merge_batch;


---------------------------------------------------------------------------
-- Function:
--    f_boolean_text
--
-- Description:
--    This function returns the string 'TRUE' or 'FALSE' for a boolean.
--    If the boolean is null then NULL is returned.
--
-- Parameters:
--    i_boolean - Boolean value
--  
-- Return Values:
--    'TRUE'  - When i_boolean is TRUE.
--    'FALSE' - When i_boolean is FALSE.
--    NULL    - When i_boolean is NULL.
--
-- Exceptions raised:
--    pl_exc.e_database_error  - Got an oracle error.
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/01/10 prpbcb   Created.
--                      This was/is a private function in other packages.
--                      Added it here so it can be used by any package.
---------------------------------------------------------------------------
FUNCTION f_boolean_text(i_boolean IN BOOLEAN)
RETURN VARCHAR2
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61);
BEGIN
   IF (i_boolean) THEN
      RETURN('TRUE');
   ELSIF i_boolean = FALSE THEN
      RETURN('FALSE');
   ELSE
      RETURN(NULL);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      l_object_name := gl_pkg_name || '.f_boolean_text';
      l_message :=  l_object_name || '(i_boolean)';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM, 'LABOR', gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END f_boolean_text;


---------------------------------------------------------------------------
-- Function:
--    is_three_part_move_active
--
-- Description:
--    This function returns TRUE if 3 part move is active for the pallet type
--    of a slot otherwise FALSE is returned.
--
--    Three part move applies only to forklift labor demand replenishments
--    batches.
--
-- Parameters:
--    i_logi_loc  - The slot to check.
--
-- Return Values:
--    TRUE   -  3 part move is active
--    FALSE  -  3 part move is not active
--
-- Exceptions raised:
--    pl_exc.ct_data_error     - Parameter is null.
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list not complete)
--    - pl_lmd.get_next_point
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/02/10 prpbcb   Created
---------------------------------------------------------------------------
FUNCTION is_three_part_move_active(i_logi_loc IN loc.logi_loc%TYPE)
RETURN BOOLEAN
IS
   l_message                  VARCHAR2(256);    -- Message buffer
   l_object_name              VARCHAR2(30) := 'is_three_part_move_active';

   l_return_value             BOOLEAN;
   l_three_part_move_active   pallet_type.three_part_move_for_demand_rpl%TYPE;

BEGIN
   --
   -- Check for null parameter.
   --
   IF (i_logi_loc IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   --
   -- See if three part move is active.
   --
   SELECT three_part_move_for_demand_rpl
     INTO l_three_part_move_active
     FROM pallet_type pt,
          loc l
    WHERE l.logi_loc     = i_logi_loc
      AND pt.pallet_type = l.pallet_type;

   IF (l_three_part_move_active = 'Y') THEN
      l_return_value := TRUE;
   ELSE
      l_return_value := FALSE;
   END IF;

   RETURN l_return_value;
EXCEPTION
   WHEN gl_e_parameter_null THEN
      l_message := gl_pkg_name || '.' || l_object_name
             || '(i_logi_loc[' || i_logi_loc || '])'
             || '  Input parameter is null.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     l_message, pl_exc.ct_data_error,
                     NULL, 'LABOR', gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

   WHEN NO_DATA_FOUND THEN
      l_message := 'TABLE=pallet_type,loc'
             || '  KEY=[' || i_logi_loc || '(i_logi_loc)]'
             || '  ACTION=SELECT  MESSAGE="Did not find the location"';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     l_message, SQLCODE, SQLERRM,
                     'LABOR', gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

   WHEN OTHERS THEN
      l_message := gl_pkg_name || '.' || l_object_name
             || '(i_logi_loc[' || i_logi_loc || '])';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     l_message, SQLCODE, SQLERRM,
                     'LABOR', gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_message);

END is_three_part_move_active;

-- 7/21/21 mcha1213 add

---------------------------------------------------------------------------
-- Procedure:
--    find_active_batch
--
-- Description:
--    This procedure finds the user's current active labor batch.
--      It also sets a flag denoting whether or not the active batch is
--      a parent batch or not.
--
-- Parameters:
--    i_user_id        - User to find the active batch for.
--    o_batch_no       - Current active batch returned to calling function.
--    o_is_parent_bln  - Flag returned to calling function denoting whether
--                       the current active batch is a parent batch.
--    o_lbr_func       - The active batch's labor function--SL, FL, etc.
--    o_status         - How things went.  The calling program needs to check it.
--                       Values:
--                          rf.STATUS_NORMAL                 - Found the active batch.
--                          rf.STATUS_LM_NO_ACTIVE_BATCH     - Unable to find an active batch for user.
--                          rf.STATUS_LM_LAST_IS_ISTOP       - Denotes the last batch for the user is an ISTOP
--                                                             and it is okay to sign onto another batch.
--                          rf.STATUS_LM_MULTI_ACTIVE_BATCH  - User is active on more than one batch.
--
-- Exceptions Raised:
--    RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, ...
--    RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, ...
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/28/19 bben0556 Brian Bent
--                      Created.
--                      This is a PL/SQL version of function
--                      "lmc_find_active_batch" in "lm_common.pc".
--
---------------------------------------------------------------------------
PROCEDURE find_active_batch
             (i_user_id        IN  arch_batch.user_id%TYPE,
              o_batch_no       OUT arch_batch.batch_no%TYPE,
              o_is_parent_bln  OUT BOOLEAN,
              o_lbr_func       OUT job_code.lfun_lbr_func%type,
              o_status         OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'find_active_batch';

   l_batch_count          PLS_INTEGER;
   l_count                PLS_INTEGER;                  -- Work area
   l_last_complete_batch  arch_batch.batch_no%TYPE;     -- The last completed batch for the user.
   l_is_parent            VARCHAR2(1);

   --
   -- This cursor is used to find the active batch for the user.
   -- "MIN" used so we can do a count to check if the user is active
   -- on more than on batch.
   --
   CURSOR c_active_batch(cp_user_id  arch_batch.user_id%TYPE)
   IS
   SELECT MIN(b.batch_no)         batch_no,
          MIN(DECODE(b.parent_batch_no, NULL, 'N', 'Y')) is_parent,
          MIN(jc.lfun_lbr_func)   lbr_func,
          COUNT(*)                batch_count
     FROM batch b, job_code jc
    WHERE jc.jbcd_job_code = b.jbcd_job_code
      AND b.status         = 'A'
      AND b.user_id        = cp_user_id;
BEGIN
   --
   -- i_user_id is required.
   --
   IF (i_user_id IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   --
   -- Initialization
   --
   o_batch_no       := NULL;
   o_is_parent_bln  := FALSE;
   o_lbr_func       := NULL;
   o_status         := rf.STATUS_NORMAL;

   OPEN c_active_batch(i_user_id);
   FETCH c_active_batch INTO o_batch_no,
                             l_is_parent,
                             o_lbr_func,
                             l_batch_count;
   CLOSE c_active_batch;

   IF (l_batch_count = 1) THEN
      --
      -- The user has one active batch.
      --
      IF (l_is_parent = 'Y') THEN
         o_is_parent_bln := TRUE;
      ELSE
         o_is_parent_bln := FALSE;
      END IF;
   ELSIF (l_batch_count = 0)
   THEN
      --
      -- The user does not have an active batch.
      -- Check the last completed batch for an ISTOP.  If it is, then pass
      -- a flag to the calling routine to allow the user to signon to a
      -- batch.
      --
      l_last_complete_batch := pl_lmc.get_last_complete_batch(i_user_id);

      IF (l_last_complete_batch IS NULL)
      THEN
         --
         -- User does not have a completed batch.
         --
         o_status := rf.STATUS_LM_NO_ACTIVE_BATCH;
      ELSE
         --
         -- User has a completed batch.  See if it is an ISTOP.
         --
         SELECT COUNT(*)
           INTO l_count
           FROM batch b
          WHERE b.batch_no    = l_last_complete_batch
            AND jbcd_job_code = 'ISTOP';

         IF (l_count = 1) THEN
            --7/21/21 mcha1213 replace by next line o_status := rf.STATUS_LM_LAST_IS_ISTOP;    -- The last completed batch for the user is an ISTOP
            o_status := STATUS_LM_LAST_IS_ISTOP;    -- The last completed batch for the user is an ISTOP
         ELSE
            o_status := rf.STATUS_LM_NO_ACTIVE_BATCH;
         END IF;
      END IF;
   ELSE
      --
      -- User is active on more than one batch.
      --
      o_status := rf.STATUS_LM_MULTI_ACTIVE_BATCH;
   END IF;

   pl_log.ins_msg
-- S4R_Story_2876_Changing_info_messages_to_debug
--               (i_msg_type         => pl_log.ct_info_msg,
               (i_msg_type         => pl_log.ct_debug_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Ending procedure'
                   || ' i_user_id['       || i_user_id         || ']'
                   || ' o_batch_no['      || o_batch_no        || ']'
                   || ' o_is_parent_bln[' || pl_common.f_boolean_text(o_is_parent_bln) || ']'
                   || ' o_lbr_func['      || o_lbr_func        || ']'
                   || ' o_status['        || TO_CHAR(o_status) || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
EXCEPTION
   WHEN gl_e_parameter_null THEN
      l_message := '(i_user_id[' || i_user_id || '],o_batch_no,o_is_parent_bln,o_lbr_func,o_status)'
                  ||  '  Parameter is null';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_object_name || ': ' ||  l_message);

   WHEN OTHERS THEN
      l_message := '(i_user_id[' || i_user_id || '],o_batch_no,o_is_parent_bln,o_lbr_func,o_status)'
                   || '  MESSAGE="Failed looking for the active batch for the user"';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
END find_active_batch;


PROCEDURE SignOn_To_Batch( i_user_id    IN  arch_batch.user_id%TYPE
                         , i_new_batch  IN  batch.batch_no%TYPE
                         , i_call_process_batch_bln IN BOOLEAN DEFAULT TRUE)
IS
  This_Function       CONSTANT  all_source.name%TYPE  := 'SignOn_To_Batch';

  l_active_batch_no             arch_batch.batch_no%TYPE;
  l_active_batch_is_parent_bln  BOOLEAN;
  l_active_batch_lbr_func       job_code.lfun_lbr_func%TYPE;
  l_active_batch_status         PLS_INTEGER;
  l_forklift_point              loc.logi_loc%TYPE;
  l_timespent                   arch_batch.actl_time_spent%TYPE;
  l_equip_id                    equip.equip_id%TYPE;
  l_is_parent                   VARCHAR2(1 CHAR);
  l_status                      NUMBER;
  l_ref_no                      arch_batch.ref_no%TYPE;
  l_new_batch                   batch.batch_no%TYPE;
  l_wash_batch_no               arch_batch.batch_no%TYPE;  -- Needed in procedure call.  Not used.
  l_istop_batch_no              arch_batch.batch_no%TYPE;  -- Needed in procedure call.  Not used.
  l_lot_batch_yn                VARCHAR2(1);               -- Needed in procedure call.  Not used.
  l_success                     VARCHAR2(1);               -- "pl_task_regular.process_batch" processed OK or not.

  v_This_Message                VARCHAR2(1000 CHAR);
BEGIN
---------------------------------------------------
-- First, complete the active batch and sign-off --
---------------------------------------------------
  v_This_Message := '1. Starting '
                 || '( i_user_id='   || NVL( i_user_id  , 'NULL' )
                 || ', i_new_batch=' || NVL( i_new_batch, 'NULL' )
                 || ' )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--  PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
  PL_Log.Ins_Msg( PL_Log.CT_debug_Msg, This_Function, v_This_Message
                , NULL, NULL, ct_application_function, gl_pkg_name );

  l_new_batch := i_new_batch;

  -- Find the active batch for this user
  v_This_Message := '2. PL_LMC.Find_Active_Batch'
                 || '( i_user_id=' || NVL( i_user_id, 'NULL' )
                 || ', ... )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--  PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
  PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                , NULL, NULL, ct_application_function, gl_pkg_name );


  PL_LMC.Find_Active_Batch( i_user_id       => i_user_id
                          , o_batch_no      => l_active_batch_no
                          , o_is_parent_bln => l_active_batch_is_parent_bln
                          , o_lbr_func      => l_active_batch_lbr_func
                          , o_status        => l_active_batch_status );

  v_This_Message := '2. PL_LMC.Find_Active_Batch'
                 || '( i_user_id='       || NVL( i_user_id              , 'NULL' )
                 || ', o_batch_no='      || NVL( l_active_batch_no      , 'NULL' )
                 || ', o_is_parent_bln=' || CASE l_active_batch_is_parent_bln WHEN TRUE THEN 'TRUE' ELSE 'FALSE' END
                 || ', o_lbr_func='      || NVL( l_active_batch_lbr_func, 'NULL' )
                 || ', o_status='        || NVL( TO_CHAR( l_active_batch_status ), 'NULL' )
                 || ' )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--  PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
  PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                , NULL, NULL, ct_application_function, gl_pkg_name );

  IF l_active_batch_status = RF.STATUS_NORMAL THEN
    l_is_parent := CASE l_active_batch_is_parent_bln WHEN TRUE THEN 'Y' ELSE 'N' END;


    -- If current batch is for a forklift...
    IF ( l_active_batch_lbr_func = 'FL' ) THEN
      -- Get the last drop point for this batch
      v_This_Message := '3. l_forklift_point := PL_LMD_Drop_Point.Get_Last_Drop_Point'
                     || '( i_batch_no=' || NVL( l_active_batch_no, 'NULL' )
                     || ' )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--      PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
      PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                    , NULL, NULL, ct_application_function, gl_pkg_name );

      l_forklift_point := PL_LMD_Drop_Point.Get_Last_Drop_Point( l_active_batch_no );

      v_This_Message := '3. l_forklift_point[=' || NVL( l_forklift_point, 'NULL' )
                     || '] := PL_LMD_Drop_Point.Get_Last_Drop_Point'
                     || '( i_batch_no=' || NVL( l_active_batch_no, 'NULL' )
                     || ' )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--       PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
       PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                    , NULL, NULL, ct_application_function, gl_pkg_name );

      -- Use the last drop point to close the prior forklift batch
      BEGIN
        v_This_Message := '4. SQL: '
                       || 'UPDATE batch'
                       ||   ' SET KVI_From_Loc = ''' || NVL( l_forklift_point, 'NULL' ) || ''''
                       || ' WHERE batch_no = '''     || NVL( i_new_batch     , 'NULL' )
                       || ' )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--        PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
        PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                      , NULL, NULL, ct_application_function, gl_pkg_name );

        UPDATE batch b
           SET b.KVI_From_Loc = l_forklift_point
         WHERE batch_no = i_new_batch;

        v_This_Message := '4. SQL: Status=ORA-Normal';
-- S4R_Story_2876_Changing_info_messages_to_debug
--        PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
        PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                      , NULL, NULL, ct_application_function, gl_pkg_name );
      EXCEPTION
        WHEN OTHERS THEN
          v_This_Message := 'Unexpected error while saving last drop point for forklift LM batch['
                         || NVL( l_active_batch_no, 'NULL' ) || '].' ;
          PL_Log.Ins_Msg( PL_Log.CT_Error_Msg, This_Function, v_This_Message
                        , SQLCODE, SQLERRM, ct_application_function, gl_pkg_name );
      END;

      -- In case the forklift driver only partially completed his/her putaway...
      v_This_Message := '5. PL_LMF.Reset_Batch_For_Tasks_Not_Done'
                     || '( i_user_id=' || NVL( i_user_id, 'NULL' )
                     || ' )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--      PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
      PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                    , NULL, NULL, ct_application_function, gl_pkg_name );
      PL_LMF.Reset_Batch_For_Tasks_Not_Done( i_user_id );
    END IF;


  END IF;



  -- Find the active batch for this user
  v_This_Message := '6. PL_LMC.Find_Active_Batch'
                 || '( i_user_id=' || NVL( i_user_id, 'NULL' )
                 || ', ... )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--  PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
  PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                , NULL, NULL, ct_application_function, gl_pkg_name );

  PL_LMC.Find_Active_Batch( i_user_id       => i_user_id
                          , o_batch_no      => l_active_batch_no
                          , o_is_parent_bln => l_active_batch_is_parent_bln
                          , o_lbr_func      => l_active_batch_lbr_func
                          , o_status        => l_active_batch_status );

  v_This_Message := '6. PL_LMC.Find_Active_Batch'
                 || '( i_user_id='       || NVL( i_user_id              , 'NULL' )
                 || ', o_batch_no='      || NVL( l_active_batch_no      , 'NULL' )
                 || ', o_is_parent_bln=' || CASE l_active_batch_is_parent_bln WHEN TRUE THEN 'TRUE' ELSE 'FALSE' END
                 || ', o_lbr_func='      || NVL( l_active_batch_lbr_func, 'NULL' )
                 || ', o_status='        || NVL( TO_CHAR( l_active_batch_status ), 'NULL' )
                 || ' )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--  PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
  PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                , NULL, NULL, ct_application_function, gl_pkg_name );

  IF l_active_batch_status = RF.STATUS_NORMAL THEN
    l_is_parent := CASE l_active_batch_is_parent_bln WHEN TRUE THEN 'Y' ELSE 'N' END;

    -- If current batch is for a forklift...
    IF ( l_active_batch_lbr_func = 'FL' ) THEN

      --
      -- The users active batch is forklift batch.
      --
      -- Fetch current equipment id linked to user
      v_This_Message := '7. l_equip_id := PL_Common.Get_User_Equip_Id'
                     || '( i_user_id=' || NVL( i_user_id, 'NULL' )
                     || ' )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--      PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
      PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                    , NULL, NULL, ct_application_function, gl_pkg_name );

      l_equip_id := PL_Common.Get_User_Equip_Id( i_user_id );

      v_This_Message := '7. l_equip_id[=' || NVL( l_equip_id, 'NULL' )
                     || '] := PL_Common.Get_User_Equip_Id'
                     || '( i_user_id=' || NVL( i_user_id, 'NULL' )
                     || ' )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--      PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
      PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                    , NULL, NULL, ct_application_function, gl_pkg_name );

      -- Now close the prior forklift batch
      v_This_Message := '8. PL_LMC.Signoff_Forklift_Labor_Batch'
                     || '( i_batch_no='   || NVL( l_active_batch_no, 'NULL' )
                     || ', i_equip_id='   || NVL( l_equip_id       , 'NULL' )
                     || ', i_user_id='    || NVL( i_user_id        , 'NULL' )
                     || ', i_is_parent='  || NVL( l_is_parent      , 'NULL' )
                     || ', ... )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--      PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
      PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                    , NULL, NULL, ct_application_function, gl_pkg_name );

      Signoff_Forklift_Labor_Batch( i_batch_no  => l_active_batch_no
                                  , i_equip_id  => l_equip_id
                                  , i_user_id   => i_user_id
                                  , i_is_parent => l_is_parent
                                  , o_status    => l_status );

      v_This_Message := '8. PL_LMC.Signoff_Forklift_Labor_Batch'
                     || '( i_batch_no='   || NVL(          l_active_batch_no  , 'NULL' )
                     || ', i_equip_id='   || NVL(          l_equip_id         , 'NULL' )
                     || ', i_user_id='    || NVL(          i_user_id          , 'NULL' )
                     || ', i_is_parent='  || NVL(          l_is_parent        , 'NULL' )
                     || ', o_status='     || NVL( TO_CHAR( l_status          ), 'NULL' )
                     || ' )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--      PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
      PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                    , NULL, NULL, ct_application_function, gl_pkg_name );

    ELSE
      --
      -- The users active batch is not forklift batch.
      --
      v_This_Message := '9. PL_LM1.Create_Schedule'
                     || '( i_batch_no='   || NVL( l_active_batch_no, 'NULL' )
                     || ', i_stop_time='  || TO_CHAR( SYSDATE, 'YYYY/MM/DD HH24:MI:SS' )
                     || ', ... )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--      PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
      PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                    , NULL, NULL, ct_application_function, gl_pkg_name );

      PL_LM1.Create_Schedule( l_active_batch_no, SYSDATE, l_timespent );

      v_This_Message := '9. PL_LM1.Create_Schedule'
                     || '( i_batch_no='   || NVL( l_active_batch_no, 'NULL' )
                     || ', i_stop_time='  || TO_CHAR( SYSDATE, 'YYYY/MM/DD HH24:MI:SS' )
                     || ', p_time_spend=' || NVL( TO_CHAR( l_timespent, '999,999,990.99' ), 'NULL' )
                     || ' )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--      PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
      PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                    , NULL, NULL, ct_application_function, gl_pkg_name );

    END IF;
  END IF;

---------------------------------------------------
-- Now we can activate the requested labor batch --
---------------------------------------------------
IF (i_call_process_batch_bln = TRUE) THEN    -- 06/03/2019  Brian Bent
  v_This_Message := '10. PL_Task_Regular.Process_Batch'
                 || '( i_user_id='        || NVL( i_user_id       , 'NULL' )
                 || ', io_batch_no='      || NVL( i_new_batch     , 'NULL' )
                 || ', i_forklift_point=' || NVL( l_forklift_point, 'NULL' )
                 || ', i_ref_no='         || NVL( l_ref_no        , 'NULL' )
                 || ', ... )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--  PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
  PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                , NULL, NULL, ct_application_function, gl_pkg_name );

  l_forklift_point := NULL;
  l_ref_no         := NULL;
  PL_Task_Regular.Process_Batch( i_user_id        => i_user_id
                               , io_batch_no      => l_new_batch
                               , i_forklift_point => l_forklift_point
                               , i_ref_no         => l_ref_no
                               , o_iwash_batch_no => l_wash_batch_no
                               , o_istop_batch_no => l_istop_batch_no
                               , o_lot_batch_yn   => l_lot_batch_yn
                               , o_success        => l_success
                               );

  v_This_Message := '10. PL_Task_Regular.Process_Batch'
                 || '( i_user_id='        || NVL( i_user_id       , 'NULL' )
                 || ', io_batch_no='      || NVL( i_new_batch     , 'NULL' )
                 || ', i_forklift_point=' || NVL( l_forklift_point, 'NULL' )
                 || ', i_ref_no='         || NVL( l_ref_no        , 'NULL' )
                 || ', o_iwash_batch_no=' || NVL( l_wash_batch_no , 'NULL' )
                 || ', o_istop_batch_no=' || NVL( l_istop_batch_no, 'NULL' )
                 || ', o_lot_batch_yn='   || NVL( l_lot_batch_yn  , 'NULL' )
                 || ', o_success='        || NVL( l_success       , 'NULL' )
                 || ' )';
-- S4R_Story_2876_Changing_info_messages_to_debug
--  PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
  PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                , NULL, NULL, ct_application_function, gl_pkg_name );
END IF;   -- 06/03/2019  Brian Bent


   --
   -- 06/08/2019 Brian Bent
   -- If the users active batch was a unloading batch then the batch KVI's need
   -- to be updated and the goal/target time recalculated for all the unloading
   -- batches for the load as the actual time spent affects the values.
   -- Note at this point in processing l_active_batch_no should have gotten completed.
   --

   -- 7/21/21 mcha123 take this out IF (l_active_batch_lbr_func = 'UL') THEN
   --   update_batch_kvi_for_inb_load(i_batch_no  => l_active_batch_no);
   --END IF;


  v_This_Message := '11. Ending';
-- S4R_Story_2876_Changing_info_messages_to_debug
--  PL_Log.Ins_Msg( PL_Log.CT_Info_Msg, This_Function, v_This_Message
  PL_Log.Ins_Msg( PL_Log.CT_Debug_Msg, This_Function, v_This_Message
                , NULL, NULL, ct_application_function, gl_pkg_name );
  RETURN;
END SignOn_To_Batch;

FUNCTION get_last_complete_batch
             (i_user_id    IN  arch_batch.user_id%TYPE)
RETURN VARCHAR2
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'get_last_complete_batch';

   l_last_completed_batch  arch_batch.batch_no%TYPE;

   --
   -- This cursor is used to get last completed batch for a user.
   -- An ISTART can have the same actl_start_time as the following
   -- batch so we need to be sure it does not get selected first.
   -- If there is an IWASH and ISTOP with the same actl_start_time
   -- then select the ISTOP first.
   --
   CURSOR c_last_complete_batch(cp_user_id  arch_batch.user_id%TYPE)
   IS
   SELECT batch_no
     FROM batch
    WHERE status = 'C'
      AND user_id = cp_user_id
    ORDER BY actl_stop_time  DESC,
             actl_start_time DESC,
             DECODE(jbcd_job_code, 'ISTART', 1,
                                   'IWASH', 1,
                                   0);
BEGIN
   --
   -- i_user_id is required.
   --
   IF (i_user_id IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;


   OPEN c_last_complete_batch(i_user_id);
   FETCH c_last_complete_batch INTO l_last_completed_batch;

   IF (c_last_complete_batch%NOTFOUND) THEN
      l_last_completed_batch := NULL;
   END IF;

   CLOSE c_last_complete_batch;

   RETURN l_last_completed_batch;
EXCEPTION
   WHEN gl_e_parameter_null THEN
      l_message := '(i_user_id[' || i_user_id || '] Parameter is null';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_object_name || ': ' ||  l_message);

   WHEN OTHERS THEN
      l_message := 'TABLE=batch  ACTION=SELECT'
                   || '  KEY=[' || i_user_id || '] (i_user_id,)'
                   || '  MESSAGE="Failed looking for the last completed batch for the user"';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
END get_last_complete_batch;

PROCEDURE signoff_forklift_labor_batch
               (i_batch_no              IN  VARCHAR2,
                i_equip_id              IN  VARCHAR2,
                i_user_id               IN  VARCHAR2,
                i_is_parent             IN  VARCHAR2,
                o_status                OUT NUMBER)
IS
   l_message        VARCHAR2(256);    -- Message buffer
   l_object_name    VARCHAR2(30) := 'signoff_forklift_labor_batch';

   l_batch_no       VARCHAR2(30);  -- Cannot user %TYPE because we end up calling a PRO*C program
   l_equip_id       VARCHAR2(30);  -- Cannot user %TYPE because we end up calling a PRO*C program
   l_user_id        VARCHAR2(30);  -- Cannot user %TYPE because we end up calling a PRO*C program
   l_is_parent      VARCHAR2(1);   -- Cannot user %TYPE because we end up calling a PRO*C program

   e_fail           EXCEPTION;
BEGIN
   --
   -- Log starting
   --
-- S4R_Story_2876_Changing_info_messages_to_debug
--   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
   pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name,
            'Starting function'
            || ' (i_batch_no['    || i_batch_no       || ']'
            || ',i_equip_id['     || i_equip_id       || ']'
            || ',i_user_id['      || i_user_id        || ']'
            || ',i_is_parent['    || i_is_parent      || ']'
            || ',o_status)',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   o_status := swms.rf.STATUS_NORMAL;

   --
   -- All parameters need a value.
   --
   IF (   i_batch_no  IS NULL
       OR i_equip_id  IS NULL
       OR i_user_id   IS NULL
       OR i_is_parent IS NULL )
   THEN
      RAISE gl_e_parameter_null;
   END IF;

   l_batch_no    := i_batch_no;
   l_equip_id    := i_equip_id;
   l_user_id     := i_user_id;
   l_is_parent   := i_is_parent;

   o_status := pl_lm_forklift.lm_signoff_from_forklift_batch
                                   (l_batch_no,
                                    l_equip_id,
                                    l_user_id,
                                    l_is_parent);
EXCEPTION
   WHEN e_fail THEN
      NULL;   -- o_status should have been set to the appropiate status.
   WHEN gl_e_parameter_null THEN
      l_message :=
               ' (i_batch_no['    || i_batch_no     || ']'
            || ',i_equip_id['     || i_equip_id     || ']'
            || ',i_user_id['      || i_user_id      || ']'
            || ',i_is_parent['    || i_is_parent    || ']'
            || ',o_status)  All IN parameters need a value';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
   WHEN OTHERS THEN
      l_message :=
               ' (i_batch_no['    || i_batch_no     || ']'
            || ',i_equip_id['     || i_equip_id     || ']'
            || ',i_user_id['      || i_user_id      || ']'
            || ',i_is_parent['    || i_is_parent    || ']'
            || ',o_status) Error occurred';
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END signoff_forklift_labor_batch;


---------------------------------------------------------------------------
-- Function:
--    count_child_batches
--
-- Description:
--   This function which returns the number of child batches for a batch.
--
-- Parameters:
--    i_batch_no   - Labor batch number.
--
-- Return Values:
--    Count of child batches.
--
-- Exceptions raised:
--    pl_exc.e_database_error  - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/27/19 bben0556 Brian Bent
--                      Created.
--
---------------------------------------------------------------------------
FUNCTION count_child_batches
                   (i_batch_no   IN  arch_batch.batch_no%TYPE)
RETURN PLS_INTEGER
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'count_child_batches';

   l_count         PLS_INTEGER;
BEGIN
   SELECT COUNT(*)
     INTO l_count
     FROM batch b
    WHERE b.parent_batch_no = i_batch_no
      AND b.batch_no <> NVL(b.parent_batch_no, 'x');

   RETURN l_count;
EXCEPTION
   WHEN OTHERS THEN
      l_message := 'TABLE=batch  ACTION=SELECT'
                   || '  KEY=[' || i_batch_no || '] (i_batch_no,)'
                   || '  MESSAGE="Failed counting child batches"';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
END count_child_batches;


---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Function:
--    does_batch_exist
--
-- Description:
--    This function returns TRUE if a labor batch exists in the BATCH table
--    otherwise FALSE.
--    By default the BATCH_DATE is ignored.  The key on the BATCH table is
--    BATCH_NO and BATCH_DATE.
--
-- Parameters:
--    i_batch_no    - Labor batch number.
--    i_batch_date  - Check if created on this date.  Default value is NULL
--                    which signifies to check if the batch exists regardless
--                    of the batch date.
--                    The key on the BATCH table is BATCH_NO and BATCH_DATE.
--
-- Return Values:
--    TRUE  -  Batch exists.
--    FALSE -  Batch does not exist.
--
-- Exceptions Raised:
--    pl_exc.e_database_error  - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/11/18 bben0556 Brian Bent
--                      Created to use for forklift labor.  For forklift labor
--                      the BATCH.BATCH_NO needs to be unique.
--                      Copied from RDC version of pl_lmc.sql.
--
---------------------------------------------------------------------------
FUNCTION does_batch_exist
             (i_batch_no    IN  batch.batch_no%TYPE,
              i_batch_date  IN  DATE DEFAULT NULL)
RETURN BOOLEAN
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'does_batch_exist';
   l_dummy         VARCHAR2(1);

BEGIN
   BEGIN
      --
      -- Note: BATCH.BATCH_DATE is stored without the time.
      --
      SELECT DISTINCT 'x' INTO l_dummy
        FROM batch
       WHERE batch.batch_no   = i_batch_no
         AND batch.batch_date = NVL(TRUNC(i_batch_date), batch.batch_date);
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
         RETURN FALSE;
   END;

   RETURN TRUE;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name || '(i_batch_no[' || i_batch_no || '])';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END does_batch_exist;

END pl_lmc;   -- end package body
/
