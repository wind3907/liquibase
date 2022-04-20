CREATE OR REPLACE PACKAGE swms.pl_rf_sleeve_sel
AS
-----------------------------------------------------------------------------
-- Package Name:
--    pl_rf_sleeve_sel
--
-- Description:
--    Package for sleeve selections operations on the RF.
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    10/29/20 bben0556 Brian Bent
--                      Project: R44-Jira3222_Sleeve_selection
--
--                     
-----------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Constants
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Type Declarations
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    assign_sleeve_to_float_zone
--
-- Description:
--    This function assigns the sleeve to the float-zone by updating
--    float_detail.sleeve_id.
--
--    Called by SOS RF.
--
---------------------------------------------------------------------------
FUNCTION assign_sleeve_to_float_zone
            (i_RF_Log_Init_Record        IN RF_Log_Init_Record,
             i_float_no                  IN floats.float_no%TYPE,
             i_float_char                IN VARCHAR2,
             i_zone                      IN float_detail.zone%TYPE,
             i_sleeve_id                 IN VARCHAR2)
RETURN rf.status;

END pl_rf_sleeve_sel;
/


CREATE OR REPLACE PACKAGE BODY swms.pl_rf_sleeve_sel
AS

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------

gl_pkg_name   VARCHAR2(30) := $$PLSQL_UNIT;   -- Package name.
                                              -- Used in error messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.


--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function CONSTANT  VARCHAR2(10) := 'SELECTION';


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Function:
--    assign_sleeve_to_float_zone  (public)
--
-- Description:
--    This function assigns the sleeve to the float-zone by updating
--    float_detail.sleeve_id.
--
--    This function is called directly from an RF client via SOAP web service.
--
-- Parameters:
--    i_RF_Log_Init_Record     - RF device initialization record
--    i_float_no               - float number
--    i_float_char             - float character, example R, S, T
--    i_zone                   - float zone as will print on the label.  It starts at 1 then
--                               increments by 1 though all zones on the batch.
--                               Example:  Batch has 3 floats. R, S, T.  Each float has 2 zones.
--                                          All zones have product.  The zone will be 1, 2, 3, 4, 5, 6.
--                                          The float zone on the pick labels will be:  R-1, R-2, S-3, S-4, T-5, T-6
--                               Be aware float_detail.zone starts over for each float so for the example above
--                               float_detail.zone will be 1, 2 for the R float, 1, 2 for the S float and 1, 2 for the T float
--    i_sleeve_id              - Sleeve to assign to the float-zone
--
-- Return Values:
--    rf.status_normal          - Sleeve assigned successfully.
--    rf.status_invalid_sleeve  - Invalid sleeve id (1020)
--    rf.status_sleeve_in_use   - Sleeve already assigned. (1021)
--    80 (data error) - some oracle error occurred
--    
--
-- Called by:
--    SOS RF client via SOAP web service
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/12/19 bben0556 Brian Bent
--                      Created.
---------------------------------------------------------------------------
FUNCTION assign_sleeve_to_float_zone
            (i_RF_Log_Init_Record        IN RF_Log_Init_Record,
             i_float_no                  IN floats.float_no%TYPE,
             i_float_char                IN VARCHAR2,
             i_zone                      IN float_detail.zone%TYPE,
             i_sleeve_id                 IN VARCHAR2)
RETURN rf.status
IS
   l_object_name CONSTANT   VARCHAR2(30)     := 'assign_sleeve_to_float_zone';
   l_message                VARCHAR2(256);         -- Work area
   l_rf_status              rf.status        := rf.status_normal;

   --
   -- This record is used to hold the parameters from the RF.
   -- The parameters from SOS RF are simple parameters.  They will be used
   -- to populate this record structure and the record will be passed to the
   -- relevant procedures in pl_sleeve_sel.sql
   --
   l_sleeve_assignment_rec    pl_sleeve_sel.t_sleeve_assignment_rec;
BEGIN

   --
   -- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).   
   -- This must be done before calling rf.Initialize().
   --

   --
   -- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.
   --
   l_rf_status := RF.Initialize( i_RF_Log_Init_Record );

   --
   -- If the initialization was successful then do the work.
   --
   IF (l_rf_status = swms.rf.STATUS_NORMAL) THEN
      l_sleeve_assignment_rec.float_no   := i_float_no;
      l_sleeve_assignment_rec.float_char := i_float_char;
      l_sleeve_assignment_rec.zone       := i_zone;
      l_sleeve_assignment_rec.sleeve_id  := i_sleeve_id;
      l_sleeve_assignment_rec.user_id    := REPLACE(USER, 'OPS$', NULL);

      --
      -- Assign the sleeve to the float-zone.
      -- Procedure "pl_sleeve_sel.assign_sleeve_to_float_zone" does this.
      --
      pl_sleeve_sel.assign_sleeve_to_float_zone
            (i_sleeve_assignment_rec  => l_sleeve_assignment_rec,
             o_status                 => l_rf_status);
   END IF;

   COMMIT;  -- Commit made here.  "pl_sleeve_sl.assign_sleeve_to_float_zone" does not commit.

   rf.complete(l_rf_status);
   RETURN l_rf_status;
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      --
      -- Got some oracle message.  Log it then re-raise the exception.
      --
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Error assigning sleeve to float-zone.',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      RF.LogException();
      RAISE;
END assign_sleeve_to_float_zone;

END pl_rf_sleeve_sel;
/


show errors


CREATE OR REPLACE PUBLIC SYNONYM pl_rf_sleeve_sel FOR swms.pl_rf_sleeve_sel;
GRANT EXECUTE ON swms.pl_rf_sleeve_sel TO swms_user;


