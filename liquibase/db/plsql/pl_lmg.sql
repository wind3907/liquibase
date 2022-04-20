PROMPT Create package specification: pl_lmg

/*************************************************************************/
-- Package Specification
/*************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_lmg
AS

   -- sccs_id=@(#) src/schema/plsql/pl_lmg.sql, swms, swms.9, 10.1.1 9/7/06 1.3

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lmg
   --
   -- Description:
   --    This package contains functions and procedures necessary to calculate
   --    discreet Labor Tracking values.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/05/03 prpbcb   Oracle 7 rs239a DN none.  Does not exist on
   --                                                Oracle 7.
   --                      Oracle 8 rs239b DN 11338
   --                      Initial creation.
   --                      PL/SQL package version of PRO*C program
   --                      lm_goaltime.pc.  Initially created for dynamic
   --                      selection.  At this time only the functions needed
   --                      for dynamic selection converted to PL/SQL.
   --
   --                      This file was copied from rs239a.  It was created
   --                      on rs239a for dynamic selection which is not yet
   --                      complete.  This file is needed now on Oracle 8
   --                      rs239b because of changes made to forklift labor
   --                      mgmt for demand HST batches.  New packages were
   --                      created for the demand HST batches that need to
   --                      insert audit records and this package is required
   --                      to do this.
   --
   --                      Below is the history form oracle 7 rs239a.
   --=======================================================================
   --    10/09/01 prpbcb   rs239a DN 10859  rs239b DN 10860  Created.
   --                      PL/SQL package version of PRO*C program
   --                      lm_goaltime.pc.  Initially created for dynamic
   --                      selection.  At this time only the functions needed
   --                      for dynamic selection converted to PL/SQL.
   --=======================================================================
   --
   -------------------------------------------------------------------------

   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Type Declarations
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Variables
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_equip_values
   --
   -- Description:
   --    This procedure fetches the LM discreet values from the equipment
   --    table for the specified equip id found in the equipment record
   --    and populates the record with the values.  io_equip_rec.equip_id
   --    needs to be set first before calling this procedure.
   ---------------------------------------------------------------------------
   PROCEDURE get_equip_values(io_equip_rec  IN OUT pl_lmc.t_equip_rec);


END pl_lmg;  -- end package specification
/

SHOW ERRORS;

PROMPT Create package body: pl_lmg

/**************************************************************************/
-- Package Body
/**************************************************************************/
CREATE OR REPLACE PACKAGE BODY swms.pl_lmg
IS
   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lmg
   --
   -- Description:
   --    This package contains functions and procedures necessary to calculcate
   --    discreet Labor Tracking values.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/05/03 prpbcb   Oracle 7 rs239a DN none.  Does not exist on
   --                                                Oracle 7.
   --                      Oracle 8 rs239b DN 11338
   --                      Initial creation.
   --                      PL/SQL package version of PRO*C program
   --                      lm_goaltime.pc.  Initially created for dynamic
   --                      selection.  At this time only the functions needed
   --                      for dynamic selection converted to PL/SQL.
   --
   --                      This file was copied from rs239a.  It was created
   --                      on rs239a for dynamic selection which is not yet
   --                      complete.  This file is needed now on Oracle 8
   --                      rs239b because of changes made to forklift labor
   --                      mgmt for demand HST batches.  New packages were
   --                      created for the demand HST batches that need to
   --                      insert audit records and this package is required
   --                      to do this.
   --
   --                      Below is the history form oracle 7 rs239a.
   --=======================================================================
   --    10/09/01 prpbcb   rs239a DN 10859  rs239b DN 10860  Created.  
   --                      PL/SQL package version of PRO*C program
   --                      lm_goaltime.pc.  Initially created for dynamic
   --                      selection.  At this time only the functions needed
   --                      for dynamic selection converted to PL/SQL.
   --=======================================================================
   --
   ---------------------------------------------------------------------------


   ---------------------------------------------------------------------------
   -- Private Global Variables
   ---------------------------------------------------------------------------
   gl_pkg_name   VARCHAR2(20) := 'pl_lmg';   -- Package name.  Used in
                                             -- error messages.

   ---------------------------------------------------------------------------
   -- Private Constants
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Private Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_equip_values
   --
   -- Description:
   --    This procedure fetches the LM discreet values from the equipment
   --    table for the specified equip id found in the equipment record
   --    and populates the record with the values.  io_equip_rec.equip_id
   --    needs to be set first before calling this procedure.
   --
   -- Parameters:
   --    io_equip_rec    - Equipment record to populate.  The equip_id field
   --                      has already been populated with the equipment id.
   --
   -- Exceptions raised:
   --    pl_exc.e_wrong_equip          Could not find the equip id in the
   --                                  EQUIP table.
   --    pl_exc.e_database_error       Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/09/01 prpbcb   Created.  
   --
   ---------------------------------------------------------------------------
   PROCEDURE get_equip_values(io_equip_rec  IN OUT pl_lmc.t_equip_rec)
   IS
      l_message        VARCHAR2(128);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(60) := gl_pkg_name || '.get_equip_values';

      -- This cursor selects the equipment information.
      CURSOR c_equip(cp_equip_id IN equip.equip_id%TYPE) IS
         SELECT NVL(e.trav_rate_loaded,0),
                NVL(e.decel_rate_loaded,0),
                NVL(e.accel_rate_loaded,0),
                NVL(e.lower_loaded,0),
                NVL(e.raise_loaded,0),
                NVL(e.trav_rate_empty,0),
                NVL(e.decel_rate_empty,0),
                NVL(e.accel_rate_empty,0),
                NVL(e.lower_empty,0),
                NVL(e.raise_empty,0),
                NVL(e.drop_skid,0),
                NVL(e.approach_on_floor,0),
                NVL(e.enter_on_floor,0),
                NVL(e.position_on_floor,0),
                NVL(e.approach_on_stack,0),
                NVL(e.enter_on_stack,0), 
                NVL(e.position_on_stack,0),
                NVL(e.approach_in_rack,0),
                NVL(e.enter_in_rack,0),
                NVL(e.position_in_rack,0),
                NVL(e.backout_turn_90,0),
                NVL(e.backout_and_pos,0),
                NVL(e.turn_into_door,0),
                NVL(e.turn_into_aisle,0),
                NVL(e.turn_into_rack,0),
                NVL(e.turn_into_drivein,0),
                NVL(e.approach_in_drivein,0),
                NVL(e.enter_in_drivein,0),
                NVL(e.position_in_drivein,0),
                NVL(e.approach_in_pushback,0),
                NVL(e.enter_in_pushback,0),
                NVL(e.position_in_pushback,0),
                NVL(e.approach_in_dbl_dp,0),
                NVL(e.enter_in_dbl_dp,0), 
                NVL(e.position_in_dbl_dp,0)
           FROM equip e
          WHERE e.equip_id      = cp_equip_id;

   BEGIN

      l_message_param := l_object_name || '(io_equip_rec)' ||
         '  io_equip_rec.equip_id=' || io_equip_rec.equip_id;

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_equip(io_equip_rec.equip_id);
      FETCH c_equip
               INTO io_equip_rec.trav_rate_loaded,
                    io_equip_rec.decel_rate_loaded,
                    io_equip_rec.accel_rate_loaded,
                    io_equip_rec.ll,
                    io_equip_rec.rl,
                    io_equip_rec.trav_rate_empty,
                    io_equip_rec.decel_rate_empty,
                    io_equip_rec.accel_rate_empty,
                    io_equip_rec.le,
                    io_equip_rec.re,
                    io_equip_rec.ds,
                    io_equip_rec.apof,
                    io_equip_rec.mepof,
                    io_equip_rec.ppof,
                    io_equip_rec.apos,
                    io_equip_rec.mepos,
                    io_equip_rec.ppos,
                    io_equip_rec.apir,
                    io_equip_rec.mepir,
                    io_equip_rec.ppir,
                    io_equip_rec.bt90,
                    io_equip_rec.bp,
                    io_equip_rec.tid,
                    io_equip_rec.tia,
                    io_equip_rec.tir,
                    io_equip_rec.tidi,
                    io_equip_rec.apidi,
                    io_equip_rec.mepidi,
                    io_equip_rec.ppidi,
                    io_equip_rec.apipb,
                    io_equip_rec.mepipb,
                    io_equip_rec.ppipb,
                    io_equip_rec.apidd,
                    io_equip_rec.mepidd,
                    io_equip_rec.ppidd;

      IF (c_equip%NOTFOUND) THEN
         l_message := l_object_name || '  TABLE=equip  equip_id=[' ||
            io_equip_rec.equip_id || ']' ||
            '  ACTION=SELECT  MESSAGE="Equipment id not found in equip table."';
         RAISE pl_exc.e_wrong_equip;
      END IF;

      -- 04/15/02  The accelerate and decelerate distances are defined as
      -- syspars at the current time.
      io_equip_rec.accel_distance :=
             TO_NUMBER(pl_common.f_get_syspar('DS_ACCELERATE_DISTANCE', '0'));

      io_equip_rec.decel_distance :=
             TO_NUMBER(pl_common.f_get_syspar('DS_DECELERATE_DISTANCE', '0'));

   EXCEPTION
      WHEN pl_exc.e_wrong_equip THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_wrong_equip, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);
      WHEN OTHERS THEN
         l_message := l_object_name || '  TABLE=equip  equip_id=' ||
            io_equip_rec.equip_id ||
            '  ACTION=SELECT  MESSAGE="Error selecting equipment record."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END get_equip_values;

END pl_lmg;  -- end package body
/

SHOW ERRORS;
