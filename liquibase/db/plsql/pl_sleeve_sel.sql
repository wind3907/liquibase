CREATE OR REPLACE PACKAGE swms.pl_sleeve_sel
AS
-----------------------------------------------------------------------------
-- Package Name:
--    pl_sleeve_sel
--
-- Description:
--    Package for sleeve selection operations.
--  
--    This package is not intended to interface directly wth the RF.
--    Package "pl_rf_sleeve_sel.sql" interfaces with the RF.
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    11/02/20 bben0556 Brian Bent
--                      Project: R44-Jira3222_Sleeve_selection
--
--                      Created
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

--
-- This record is used to hold the parameters from the RF.
-- The parameters from SOS RF are simple parameters and are used
-- to populate this record structure and the record will be passed to the
-- relevant procedures in pl_sleeve_sel.sql
--
TYPE t_sleeve_assignment_rec IS RECORD
(
   float_no           floats.float_no%TYPE,             -- Float number
   float_char         VARCHAR2(1 CHAR),                 -- Float character, example R, S, T
   zone               float_detail.zone%TYPE,           -- Float zone as will print on the label.  This is want is sent
                                                        -- to SOS RF.  It starts at 1 then increments by 1 though all zones on the batch.
                                                        -- Example:  Batch has 3 floats. R, S, T.  Each float has 2 zones.
                                                        --           All zones have product.  The zone will be 1, 2, 3, 4, 5, 6.
                                                        --           The float zone on the pick labels will be:  R-1, R-2, S-3, S-4, T-5, T-6
                                                        -- Be aware float_detail.zone starts over for each float so for the example above
                                                        -- float_detail.zone will be 1, 2 for the R float, 1, 2 for the S float and 1, 2 for the T float
   sleeve_id          selection_sleeve.sleeve_id%TYPE,  -- Sleeve id
   float_detail_zone  float_detail.zone%TYPE,           -- The float detail zone
   user_id            sos_batch.picked_by%TYPE          -- User performing the sleeve assignment.
                                                        -- This should be the sos_batch.picked_by.
);


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    assign_sleeve_to_float_zone
--
-- Description:
--    This procedure assigns the sleeve to the float-zone by updating
--    float_detail.sleeve_id.
--
--    Called by "pl_rf_sleeve_sel.sql".
--
---------------------------------------------------------------------------
PROCEDURE assign_sleeve_to_float_zone
            (i_sleeve_assignment_rec   IN OUT t_sleeve_assignment_rec,
             o_status                  OUT    PLS_INTEGER);


---------------------------------------------------------------------------
-- Function:
--    get_float_detail_zone (public)
--
-- Description:
--    This function returns the float detail zone using the floats batch
--    sequence, the float-zone as want sent to to SOS and the selection equipment
--    number of zones.
--
--    When the SOS
---------------------------------------------------------------------------
FUNCTION get_float_detail_zone(i_float_no    IN floats.float_no%TYPE,
                               i_float_zone  IN PLS_INTEGER)
RETURN PLS_INTEGER;


---------------------------------------------------------------------------
-- Function:
--    is_normal_selection_float (public)
--
-- Description:
--    This function returns TRUE if the float is a normal selection float
--    otherwise FALSE.
--    If the float is not found then FALSE is returned.
--
--    A normal selection float has floats.pallet_pull = 'N'.
---------------------------------------------------------------------------
FUNCTION is_normal_selection_float(i_float_no  IN  floats.float_no%TYPE)
RETURN BOOLEAN;


---------------------------------------------------------------------------
-- Function:
--    is_valid_sleeve (public)
--
-- Description:
--    This function returns TRUE if the sleeve is valid otherwise FALSE.
--
--    A sleeve is valid if it exist in the SELECTION_SLEEVE table.
---------------------------------------------------------------------------
FUNCTION is_valid_sleeve(i_sleeve_id  IN  selection_sleeve.sleeve_id%TYPE)
RETURN BOOLEAN;


---------------------------------------------------------------------------
-- Function: is_sleeve_available
--    get_float_detail_zone (public)
--
-- Description:
--    This function returns TRUE if the sleeve is available to assign to
--    a float-zone otherwise FALSE.
--
--    A sleeve is considered is considered available:
--       - If it is not assigned to a FLOAT_DETAIL record for routes opened
--         after the last DAY end.
--       - OR it is already assigned to the float detail record.
--         This is to handle the situation where the selector rescans the
--         same sleeve to the same float-zone.
--
--    11/11/20 Brian Bent  We will need to see how the accessory tracking
--             process comes into play.
---------------------------------------------------------------------------
FUNCTION is_sleeve_available(i_sleeve_assignment_rec  IN  t_sleeve_assignment_rec)
RETURN BOOLEAN;


---------------------------------------------------------------------------
-- Procedure:
--    validate_sleeve (public)
--
-- Description:
--    This procedure validates the sleeve.  Called when assigning a sleeve to
--    a float-zone.
--
--    Validation:
--       - It needs to a valid sleeve.
--         If not set return status to rf.status_invalid_sleeve (1020)
--       - The sleeve cannot currently be assigned to a float-zone.
--         But it is OK if the sleeve is already assigned to the specified float-zone.
--         If not set return status to rf.status_sleeve_in_use (1021)
--       - SOS_BATCH.PICKED_BY needs to be the same user during the sleeve
--         assignment.
--         If not set return status to SOS_E_BCH_ASSIGNED
--         If not then this would indicate the batch was
--         reassigned during the middle of the sleeve assignment.
--       - SOS_BATCH.STATUS needs to be 'A'.
--         If not set return status to SOS_E_BCH_ASSIGNED
---------------------------------------------------------------------------
PROCEDURE validate_sleeve
                 (i_sleeve_assignment_rec   IN OUT  t_sleeve_assignment_rec,
                  o_status                  OUT     PLS_INTEGER,
                  o_msg                     OUT     VARCHAR2);

END pl_sleeve_sel;
/

show errors


CREATE OR REPLACE PACKAGE BODY swms.pl_sleeve_sel
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

-- xxxxxxxxxxx
---------------------------------------------------------------------------
-- Function:
--    is_normal_selection_float (public)
--
-- Description:
--    This function returns TRUE if the float is a normal selection float
--    otherwise FALSE.
--    If the float is not found then FALSE is returned.
--
--    A normal selection float has floats.pallet_pull = 'N'.
--
-- Parameters:
--    i_float_no
--
-- Return Values:
--    TRUE   -  If i_floast_no is a normal selection float.
--    FALSE  -  If i_floast_no is a not normal selection float
--              OR the float not found.
---------------------------------------------------------------------------
FUNCTION is_normal_selection_float(i_float_no  IN  floats.float_no%TYPE)
RETURN BOOLEAN
IS
   l_object_name   VARCHAR2(30) := 'is_normal_selection_float';

   l_pallet_pull   floats.pallet_pull%TYPE;
   l_return_value  BOOLEAN;
BEGIN
   --
   -- Initialization
   --
   l_return_value := TRUE;

   SELECT f.pallet_pull
     INTO l_pallet_pull
     FROM floats f
    WHERE f.float_no = i_float_no;

   IF (l_pallet_pull <> 'N') THEN
      --
      -- float is not a normal selection.
      --
      l_return_value := FALSE;

      pl_log.ins_msg
  
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                      'TABLE=floats'
                   || '  KEY=[' || TO_CHAR(i_float_no) || ']'
                   || '(i_float_no)'
                   || ' ACTION=SELECT'
                   || '  MESSAGE="Float not found"',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
   END IF;

   RETURN(l_return_value);
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      --
      -- Did not find the float.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                      'TABLE=floats'
                   || '  KEY=[' || TO_CHAR(i_float_no) || ']'
                   || '(i_float_no)'
                   || ' ACTION=SELECT'
                   || '  MESSAGE="Float not found"',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
      RETURN(FALSE);
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => 'is_valid_sleeeve',
                i_msg_text         => 'Error occurred  i_float_no[' || TO_CHAR(i_float_no) || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
END is_normal_selection_float;


---------------------------------------------------------------------------
-- Function:
--    is_valid_sleeve (public)
--
-- Description:
--    This function returns TRUE if the sleeve is valid otherwise FALSE.
--
--    A sleeve is valid if it exist in the SELECTION_SLEEVE table.
--
-- Parameters:
--    i_sleeve_id
--
-- Return Values:
--    TRUE   -  If i_sleeve_id  is a valid sleeve.
--    FALSE  -  If i_sleeve_id  is not a valid sleeve.
--
-- Called By:
--
-- Exceptions Raised:
--    pl_exc.e_database_error  - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/02/20 prpbcb   Created.
--
---------------------------------------------------------------------------
FUNCTION is_valid_sleeve(i_sleeve_id  IN  selection_sleeve.sleeve_id%TYPE)
RETURN BOOLEAN
IS
   l_count  number;
BEGIN
   SELECT count(*)
     INTO l_count
     FROM selection_sleeve where sleeve_id = i_sleeve_id;

   IF (l_count > 0) THEN
      RETURN(TRUE);
   ELSE
      RETURN(FALSE);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => 'is_valid_sleeeve',
                i_msg_text         => 'Error occurred  i_sleeve_id[' || i_sleeve_id || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 'is_valid_sleeve: ' || SQLERRM);

END is_valid_sleeve;


---------------------------------------------------------------------------
-- Function:
--    is_sleeve_available (public)
--
-- Description:
--    This function returns TRUE if the sleeve is available to assign to
--    a float-zone otherwise FALSE.
--
--    A sleeve is considered available:
--       - If it is not assigned to a FLOAT_DETAIL record for routes opened
--         after the last DAY end.
--       - OR it is already assigned to the float detail record.
--         This is to handle the situation where the selector rescans the
--         same sleeve to the same float-zone.
--
--    11/11/20 Brian Bent  We will need to see how the accessory tracking
--             process comes into play.
--
-- Parameters:
--    i_sleeve_assignment_rec
--
-- Return Values:
--    TRUE   -  Sleeve is in use.
--    FALSE  -  Sleeve not in use.
--
-- Called By:
--
-- Exceptions Raised:
--    pl_exc.e_database_error  - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/02/20 prpbcb   Created.
--
---------------------------------------------------------------------------
FUNCTION is_sleeve_available(i_sleeve_assignment_rec  IN  t_sleeve_assignment_rec)
RETURN BOOLEAN
IS
   l_object_name CONSTANT  VARCHAR2(30)     := 'is_sleeve_available';

   l_mismatch_count        PLS_INTEGER;

   --
   -- This cursor selects the float detail records (if any) assigned to the sleeve.
   -- Only look at float detail records after the last DAY close.
   --
   -- 11/11/20 Brian Bent  We will need to see how the accessory tracking
   --          process comes into play.
   --
   CURSOR c_fd(cp_sleeve_id  float_detail.sleeve_id%TYPE)
   IS
   SELECT f.batch_seq,
          fd.float_no,
          fd.zone,
          fd.sleeve_id
     FROM float_detail fd,
          floats f,
          trans t
    WHERE fd.sleeve_id   = cp_sleeve_id
      AND f.float_no     = fd.float_no
      AND t.route_no     = f.route_no
      AND t.trans_type   = 'RTG'
      AND t.trans_date   >
           (SELECT NVL(MAX(t2.trans_date), SYSDATE - 200) FROM trans t2 WHERE t2.trans_type = 'DAY');   -- NVL in the unlikly event there is no DAY close.
BEGIN
   l_mismatch_count := 0;

   FOR r_fd IN c_fd(i_sleeve_assignment_rec.sleeve_id)
   LOOP
      DBMS_OUTPUT.PUT_LINE(l_object_name || ' in loop'
                 || '  r_fd.float_no:'                             || r_fd.float_no
                 || '  r_fd.zone:'                                 || r_fd.zone
                 || '  i_sleeve_assignment_rec.float_no:'          || i_sleeve_assignment_rec.float_no
                 || '  i_sleeve_assignment_rec.float_detail_zone:' || i_sleeve_assignment_rec.float_detail_zone);

      IF (   r_fd.float_no <> i_sleeve_assignment_rec.float_no
          OR r_fd.zone     <> i_sleeve_assignment_rec.float_detail_zone)
      THEN
         l_mismatch_count := l_mismatch_count + 1;

         DBMS_OUTPUT.PUT_LINE(l_object_name || ' sleeve not available');
      END IF;
   END LOOP;

   IF (l_mismatch_count > 0) THEN
      RETURN(FALSE);
   ELSE
      RETURN(TRUE);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred  i_sleeve_assignment_rec.sleeve_id[' || i_sleeve_assignment_rec.sleeve_id || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
END is_sleeve_available;


---------------------------------------------------------------------------
-- Function:
--    get_float_detail_zone (public)
--
-- Description:
--    This function returns the float detail zone using the floats batch
--    sequence, float-zone as want sent to to SOS and the selection equipment
--    number of zones.
--
--    The calculation is:
--       fd.zone = float-zone - ((f.batch_seq - 1) * se.no_of_zones)
--
--    For sleeve selection the sleeves are assigned to the float zone on SOS RF.
--    The RF sends the assignment to the host which updates float_detail.sleeve id.
--    The RF sends:
--       - float number
--       - float character   example R, S, T
--       - float-zone.   The zone will be what is printed on the SOS pick label.
--                       It starts at 1 then increments by 1 though all zones on the batch.
--                       The RF is not sent the float_detail.zone when the batch is downloaded.
--                       View v_sos_batch_info is doing this for the zone:  ((f.batch_seq - 1) * se.no_of_zones) + fd.zone   zone,
--                       Example of the float-zone:
--                          Batch has 3 floats. R, S, T.  Each float has 2 zones.
--                          All zones have product.  The float-zone sent to the RF will be 1, 2, 3, 4, 5, 6.
--                          The float zone on the pick labels will be:  R-1, R-2, S-3, S-4, T-5, T-6
--                          Be aware float_detail.zone starts over for each float so for the example above
--                          float_detail.zone will be 1, 2 for the R float, 1, 2 for the S float and 1, 2 for the T float
--
-- Parameters:
--    i_float_no
--    i_float_zone
--
-- Return Values:
--    Float detail zone
--
-- Called by:
--    xxx
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/02/20 bben0556 Brian Bent
--                      Created.
---------------------------------------------------------------------------
FUNCTION get_float_detail_zone(i_float_no    IN floats.float_no%TYPE,
                               i_float_zone  IN PLS_INTEGER)
RETURN PLS_INTEGER
IS
   l_object_name CONSTANT    VARCHAR2(30)     := 'get_float_detail_zone';
   l_message                 VARCHAR2(512);   -- Work area

   l_float_detail_zone       float_detail.zone%TYPE := 0;
   l_equip_id                sel_equip.equip_id%TYPE;      -- selection equipment id.  Used in log messages.
   l_no_of_zones             sel_equip.no_of_zones%TYPE;   -- selection equipment number of zones.  Used to validate the caclulated float_detail.zone

   e_no_data                 EXCEPTION;  -- Cursor c_determine_zone selected no record.
   e_bad_calculated_zone     EXCEPTION;


   CURSOR c_determine_zone
   IS
   SELECT i_float_zone - ((f.batch_seq - 1) * se.no_of_zones),
          se.equip_id,
          se.no_of_zones
     FROM floats f,
          sel_equip se
    WHERE f.float_no  = i_float_no
      AND se.equip_id = f.equip_id;
BEGIN
   OPEN c_determine_zone;
   FETCH c_determine_zone INTO l_float_detail_zone, l_equip_id, l_no_of_zones;

   IF (c_determine_zone%NOTFOUND) THEN
      RAISE e_no_data;
   END IF;

   CLOSE c_determine_zone;

   --
   -- The calculated float detail zone has to be between 1 and the selection
   -- equipment number of zones.
   --
   IF (l_float_detail_zone NOT BETWEEN 1 AND l_no_of_zones) THEN
   --
   -- The calculated float detail zone IS NOT between 1 and the selection equipment number of zones.
   -- There is some problem in the calculation.
   --
      RAISE e_bad_calculated_zone;
   END IF;
   
   RETURN l_float_detail_zone;
EXCEPTION
   WHEN e_no_data THEN
      --
      -- Cursor c_determine_zone selected no record.
      --
      IF (c_determine_zone%ISOPEN) THEN
         CLOSE c_determine_zone;
      END IF;

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                      'TABLE=floats,sel_equip'
                   || '  KEY=[' || TO_CHAR(i_float_no) || ']'
                   || '(i_float_no)'
                   || ' ACTION=SELECT'
                   || '  MESSAGE="No data found"',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);

   WHEN e_bad_calculated_zone THEN
      --
      -- The calculated float detail zone IS NOT between 1 and the selection equipment number of zones.
      -- There is some problem in the calculation.  Raise data error exception.
      --
      l_message := 'The calculated float detail zone[' || l_float_detail_zone || ']'
          || ' IS NOT between 1 and the selection equipment[' || l_equip_id || '] number of zones[' || TO_CHAR(l_no_of_zones) || ']';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      IF (c_determine_zone%ISOPEN) THEN
         CLOSE c_determine_zone;
      END IF;

      l_message := l_object_name
         || '(i_float_no, i_float_zone)'
         || '  i_float_no['   || TO_CHAR(i_float_no)    || ']'
         || '  i_float_zone[' || TO_CHAR(i_float_zone)  || ']';

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
END get_float_detail_zone;


---------------------------------------------------------------------------
-- Procedure:
--    validate_sleeve (public)
--
-- Description:
--    This procedure validates the sleeve.  Called when assigning a sleeve to
--    a float-zone.
--
--    Validation and the order it takes place:
--       - Check SOS table.
--            SOS_BATCH.PICKED_BY needs to be the same user performing the sleeve assignment.
--            SOS_BATCH.STATUS needs to be 'A'.
--         If one of these is not true then set the return status to SOS_E_BCH_ASSIGNED.
--         This would indicate the batch was most likely reassigned during the middle
--         of the sleeve assignment.
--       - It needs to be a valid sleeve.
--         A sleeve is valid if it is in the SELECTION_SLEEVE table.
--         If not set return status to rf.status_invalid_sleeve (1020).
--       - The sleeve cannot currently be assigned to a float-zone.
--         But it is OK if the sleeve is already assigned to the specified float-zone.
--         If not set return status to rf.status_sleeve_in_use (1021).
--
-- Parameters:
--    i_sleeve_assignment_rec - Sleeve assignment info
--    o_status                - rf.status_normal          if validation successful
--                              rf.status_invalid_sleeve  if sleeve does not exist (1020)
--                              rf.status_sleeve_in_use   if sleeve already in use (1021)
--                              rf.status_data_error      if oracle error
--    o_msg                   - Message why the validation failed.
--                              Valid when o_status is not rf.status_normal
--
-- Called By:  (list may not be omplete)
--    move_pallets_in_list
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/03/20 bben0556 Brian Bent
--                      Created.
---------------------------------------------------------------------------
PROCEDURE validate_sleeve
                 (i_sleeve_assignment_rec   IN OUT  t_sleeve_assignment_rec,
                  o_status                  OUT     PLS_INTEGER,
                  o_msg                     OUT     VARCHAR2)
IS
   l_object_name CONSTANT    VARCHAR2(30)     := 'validate_sleeve';

   l_batch_no     sos_batch.batch_no%TYPE;
   l_picked_by    sos_batch.picked_by%TYPE;
   l_status       sos_batch.status%TYPE;

   e_record_locked  EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_record_locked, -54);

   e_record_locked_after_waiting  EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_record_locked_after_waiting, -30006);
BEGIN
   --
   -- Log starting
   --
   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Starting procedure'
                   || ' (i_sleeve_assignment_rec,o_status,o_msg)'
                   || ' i_sleeve_assignment_rec.float_no['           ||  TO_CHAR(i_sleeve_assignment_rec.float_no) || ']'
                   || ' i_sleeve_assignment_rec.float_char['         ||  i_sleeve_assignment_rec.float_char        || ']'
                   || ' i_sleeve_assignment_rec.zone['               ||  TO_CHAR(i_sleeve_assignment_rec.zone)     || ']'
                   || ' i_sleeve_assignment_rec.sleeve_id['          ||  i_sleeve_assignment_rec.sleeve_id         || ']'
                   || ' i_sleeve_assignment_rec.float_detail_zone['  ||  i_sleeve_assignment_rec.float_detail_zone || ']'
                   || ' i_sleeve_assignment_rec.user_id['            ||  i_sleeve_assignment_rec.user_id           || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');


   --
   -- Initialization
   --
   o_status := rf.status_normal;
   o_msg    := NULL;

   --
   -- First verify SOS_BATCH status and picked by.
   -- We want to lock the sos_batch record in case of the outside chance it is being edited.
   -- The sos batch status needs to be 'A' and the picked by needs to be i_current user.
   -- Look up the SOS_BATCH using the float number.
   --
   IF (o_status = rf.status_normal)
   THEN
      BEGIN
         SELECT sb.batch_no,
                sb.status,
                sb.picked_by
           INTO l_batch_no,
                l_status,
                l_picked_by 
           FROM sos_batch sb
          WHERE sb.batch_no IN
                  (SELECT TRIM(TO_CHAR(f.batch_no))
                     FROM floats f
                    WHERE f.float_no = i_sleeve_assignment_rec.float_no)
            FOR UPDATE WAIT 3;

         IF (l_status <> 'A' OR (NVL(l_picked_by, 'x') <> i_sleeve_assignment_rec.user_id))
         THEN
            --
            -- The sos batch status is not active or the picked by
            -- or is not the user performing the sleeve assignment.
            -- Return status_sos_e_bch_assigned;
            --
            o_status := rf.status_sos_e_bch_assigned;

            pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'SOS_BATCH batch#[' || l_batch_no || ']'
                           || ' status[' || l_status || ']'
                           || ' picked_by[' || l_picked_by || ']'
                           || '  SOS batch status not A or the sos batch picked by'
                           || ' does not match the user performing the sleeve'
                           || ' assignment[' || i_sleeve_assignment_rec.user_id || '].'
                           || '  This could be a result of the batch reassigned'
                           || ' in the middle of the user performing the sleeve assignment.'
                           || '  Return rf.status_sos_e_bch_assigned[' || TO_CHAR(rf.status_sos_e_bch_assigned) || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
         END IF;
      EXCEPTION
         WHEN e_record_locked_after_waiting THEN
            --
            -- Unable to lock the SOS_BATCH for float i_sleeve_assignment_rec.float_no
            --
            o_status := rf.status_sos_e_bch_assigned;

            pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'SOS_BATCH status[' || l_status || ']'
                           || ' picked_by[' || l_picked_by || ']'
                           || '  Batch status not A or the sos batch picked by'
                           || ' does not match the user performing the sleeve'
                           || ' assignment[' || i_sleeve_assignment_rec.user_id || '].'
                           || ' This could be a result of the batch reassigned'
                           || ' in the middle of the user performing the sleeve assignment.'
                           || ' Return rf.status_sos_e_bch_assigned',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
         WHEN NO_DATA_FOUND THEN
            --
            -- For some reason the sos_batch is not there.
            -- Return STATUS_SOS_E_UNEXPECTED
            --
            o_status := rf.status_sos_e_unexpected;

            pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                      'TABLE=sos_batch'
                   || '  KEY=[' || TO_CHAR(i_sleeve_assignment_rec.float_no) || ']'
                   || '(i_sleeve_assignment_rec.float_no)'
                   || ' ACTION=SELECT'
                   || '  MESSAGE="Batch not found"',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
      END;
   END IF;
   
   --
   -- Is it a valid sleeve ?
   -- Validate the sleeve id but only when the sleeve id is populated.
   -- We can be clearing the float_detail.sleeve_id in which case the sleeve id will be null.
   --
   IF (    o_status = rf.status_normal
       AND i_sleeve_assignment_rec.sleeve_id IS NOT NULL)
   THEN
      IF (is_valid_sleeve(i_sleeve_id => i_sleeve_assignment_rec.sleeve_id) = FALSE)
      THEN
         o_status  := rf.status_invalid_sleeve;
         o_msg := 'Sleeve[' || i_sleeve_assignment_rec.sleeve_id || '] is not a valid sleeve.';
      END IF;
   END IF;

   --
   -- Is the sleeve already used ?
   -- Check only when the sleeve id is populated.
   -- We can be clearing the float_detail.sleeve_id in which case the sleeve id will be null.
   --
   IF (    o_status = rf.status_normal
       AND i_sleeve_assignment_rec.sleeve_id IS NOT NULL)
   THEN
      IF (is_sleeve_available(i_sleeve_assignment_rec => i_sleeve_assignment_rec) = FALSE)
      THEN
         o_status  := rf.status_sleeve_in_use;
         o_msg := 'Sleeve[' || i_sleeve_assignment_rec.sleeve_id || '] already in use.';
      END IF;
   END IF;

   --
   -- Log ending
   --
   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Ending procedure'
                   || ' (i_sleeve_assignment_rec,o_status,o_msg)'
                   || ' i_sleeve_assignment_rec.float_no[' ||  TO_CHAR(i_sleeve_assignment_rec.float_no) || ']'
                   || ' o_status['                         ||  TO_CHAR(o_status)                         || ']'
                   || ' o_msg['                            ||  TO_CHAR(o_msg)                            || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle message.  Log it and set return status.
      --
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Error assigning sleeve to float_detail.',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      o_status := rf.status_data_error;
      o_msg := 'Oracle error validating the sleeve';
END validate_sleeve;


---------------------------------------------------------------------------
-- Procedure:
--    assign_sleeve_to_float_zone  (public)
--
-- Description:
--    This procedure assigns the sleeve to the float-zone by updating
--    float_detail.sleeve_id.
--
--    Process to assign the sleeve to the float-zone.
--       - Validate the sleeve.  This consists of:
--            - The sleeve must exist in the SELECTION_SLEEVE table.
--            - The sleeve cannot already be in use.
--       - Select status and picked_by for update from SOS_BATCH, wait 3
--         If unable to lock record then return data error.
--         or record lock error--see what existing error codes are available.
--       - Log status and picked_by.
--       - If picked_by is not the same as the current user or the sos batch status
--         is not 'A' then return SOS_E_BCH_ASSIGNED
--
-- Parameters:
--    i_sleeve_assignment_rec - Info needed to assign the sleeve to the float-zone
--    o_status                - Status of the assigment.
--
-- Return Values:
--    xxx
--
-- Called by:
--    pl_rf_sleeve_sel.assign_sleeve_to_float_zone
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/03/20 bben0556 Brian Bent
--                      Created.
---------------------------------------------------------------------------
PROCEDURE assign_sleeve_to_float_zone
            (i_sleeve_assignment_rec   IN OUT t_sleeve_assignment_rec,
             o_status                  OUT    PLS_INTEGER)
IS
   l_object_name CONSTANT  VARCHAR2(30)     := 'assign_sleeve_to_float_zone';
   l_message               VARCHAR2(512);   -- Work area

   l_record_count          PLS_INTEGER;           -- Work area
   l_status                PLS_INTEGER;
   l_msg                   VARCHAR2(512);  -- If validate fails then why.
BEGIN
   --
   -- Log starting
   --
   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Starting procedure'
                   || ' (i_sleeve_assignment_rec,o_status)'
                   || ' i_sleeve_assignment_rec.float_no['           ||  TO_CHAR(i_sleeve_assignment_rec.float_no) || ']'
                   || ' i_sleeve_assignment_rec.float_char['         ||  i_sleeve_assignment_rec.float_char        || ']'         
                   || ' i_sleeve_assignment_rec.zone['               ||  TO_CHAR(i_sleeve_assignment_rec.zone)     || ']'
                   || ' i_sleeve_assignment_rec.sleeve_id['          ||  i_sleeve_assignment_rec.sleeve_id         || ']'
                   || ' i_sleeve_assignment_rec.float_detail_zone['  ||  i_sleeve_assignment_rec.float_detail_zone || ']'
                   || ' i_sleeve_assignment_rec.user_id['            ||  i_sleeve_assignment_rec.user_id           || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   --
   -- Initialization
   --
   l_status := rf.status_normal;

   --
   -- Check for null parameters.
   -- i_sleeve_assignment_rec.float_no and i_sleeve_assignment_rec.zone need a value.
   --
   IF (   i_sleeve_assignment_rec.float_no IS NULL
       OR i_sleeve_assignment_rec.zone     IS NULL)
   THEN
      RAISE gl_e_parameter_null;
   END IF;

   --
   -- Validate the float
   --
   IF (is_normal_selection_float(i_float_no => i_sleeve_assignment_rec.float_no) = FALSE)
   THEN
      --
      -- Not a normal selection float or the float does not exist.
      --
      l_status := rf.status_bad_float_no;
   END IF;

   --
   -- Determine the float_detail.zone because "i_sleeve_assignment_rec.zone" is the
   -- float zone as will print on the label.  It starts at 1 then
   -- increments by 1 though all zones on the batch.
   -- Example:  Batch has 3 floats. R, S, T.  Each float has 2 zones.
   --           All zones have product.  The zone will be 1, 2, 3, 4, 5, 6.
   --           The float zone on the pick labels will be:  R-1, R-2, S-3, S-4, T-5, T-6
   -- float_detail.zone starts over for each float so for the example above
   -- float_detail.zone will be 1, 2 for the R float, 1, 2 for the S float and 1, 2 for the T float
   --
   IF (l_status = rf.status_normal) THEN
      i_sleeve_assignment_rec.float_detail_zone := get_float_detail_zone(i_float_no   => i_sleeve_assignment_rec.float_no,
                                                                         i_float_zone => i_sleeve_assignment_rec.zone);
   END IF;

   --
   -- Validate the sleeve.
   --
   IF (l_status = rf.status_normal)
   THEN
      validate_sleeve(i_sleeve_assignment_rec => i_sleeve_assignment_rec,
                   o_status                => l_status,
                   o_msg                   => l_msg);
   END IF;

   dbms_output.put_line(l_object_name || ' l_status: ' || l_status);
  
   IF (l_status = rf.status_normal) THEN
      --
      -- Sleeve validation passed.
      --
      -- Update the float detail sleeve id.
      --
      UPDATE float_detail fd
         SET fd.sleeve_id = i_sleeve_assignment_rec.sleeve_id
       WHERE fd.float_no = i_sleeve_assignment_rec.float_no
         AND fd.zone     = i_sleeve_assignment_rec.float_detail_zone;

      l_record_count := SQL%ROWCOUNT;    -- Save # records updated

      --
      -- Log number of records updated.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                      'TABLE=float_detail'
                   || '  KEY=[' || TO_CHAR(i_sleeve_assignment_rec.float_no) || ',' || TO_CHAR(i_sleeve_assignment_rec.float_detail_zone) || ']'
                   || '(float#, float detail zone)'
                   || ' ACTION=UPDATE'
                   || '  MESSAGE="Updated the sleeve id to[' || i_sleeve_assignment_rec.sleeve_id || '].  Number of records updated: ' || TO_CHAR(l_record_count),
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      --
      -- If no float detail records updated then return error status.
      --
      IF (l_record_count = 0) THEN
         l_status := rf.status_sos_e_fd_update;
      END IF;
   END IF;

   o_status := l_status;

   --
   -- Log ending
   --
   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Ending procedure'
                   || ' (i_sleeve_assignment_rec,o_status)'
                   || ' i_sleeve_assignment_rec.float_no['    ||  TO_CHAR(i_sleeve_assignment_rec.float_no) || ']'
                   || ' o_status['                            ||  TO_CHAR(o_status)                         || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

EXCEPTION
   WHEN gl_e_parameter_null THEN
      --
      -- A parameter is null.  Log it and set return status.
      -- i_sleeve_assignment_rec.float_no and i_sleeve_assignment_rec.zone need a value.
      --
      l_message :=    'i_sleeve_assignment_rec.float_no[' ||  TO_CHAR(i_sleeve_assignment_rec.float_no) || ']'
                   || ' i_sleeve_assignment_rec.zone['    ||  TO_CHAR(i_sleeve_assignment_rec.zone)     || ']'
                   || '  These two parameters need a value.';

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      o_status := rf.status_data_error;

   WHEN OTHERS THEN
      --
      -- Got some oracle message.  Log it and set return status.
      --
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Error assigning sleeve to float_detail.',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      o_status := rf.status_data_error;
END assign_sleeve_to_float_zone;


END pl_sleeve_sel;
/


show errors


CREATE OR REPLACE PUBLIC SYNONYM pl_sleeve_sel FOR swms.pl_sleeve_sel;
GRANT EXECUTE ON swms.pl_sleeve_sel TO SWMS_USER;


