
PROMPT Create package specification: pl_lma

/*************************************************************************/
-- Package Specification
/*************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_lma
IS

   -- sccs_id=@(#) src/schema/plsql/pl_lma.sql, swms, swms.9, 10.1.1 9/7/06 1.5

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lma
   --
   -- Description:
   --    Labor management auditing.
   --    This package has objects used in auditing a labor mgmt batch.
   --    This audit has details on how the goal/target time was calculated.
   --
   --    It is a pl/sql version of the audit functions in lm_goaltime.c.
   --    Because auditing requires a great deal of audit records to be created
   --    we will not be replacing the functions in lm_goaltime.pc anytime soon
   --    because that would require many changes to the lm*.pc files.  This
   --    package will be used by labor mgmt packages that need to create audit
   --    records.
   --
   --    Audit records are inserted into an audit table.  These records
   --    can be comments or an operation used in the calculation of the
   --    goal/target time.  The time inserted into the audit table will always
   --    be in minutes.  This is the time to perform one of the designated
   --    operation.  The total time to perform the operation is:
   --       time * frequency
   --    The unit for the frequency depends on the operation.
   --    Examples:
   --    Operation                                 Frequency Unit
   --    ---------------------------------------   -----------------------
   --    Forklift travel                           Feet
   --
   --    Fork movement (raising, lowering forks)   Inches
   --    The time given to raise and lower the
   --    forks is for one foot so the total time
   --    is time * (frequency / 12)
   --
   --    Picking cases                             Number of Cases
   --
   --    Picking splits                            Number of Splits
   --    -------------------------------------------------------------------
   --
   --    Audit records can be at different levels of detail.  The available
   --    detail levels are:
   --       ct_detail_level_1  -- Least detail
   --       ct_detail_level_2
   --       ct_detail_level_3
   --       ct_detail_level_4
   --       ct_detail_level_5
   --       ct_detail_level_6
   --       ct_detail_level_7
   --       ct_detail_level_8
   --       ct_detail_level_9  -- Most detail
   --    The detail level is specified by the calling application.  The
   --    rule for ct_detail_level_1 is that it have the actual entries that
   --    were used to calculate the goal/target time.  The detail level
   --    was implemented for dynamic selection because traveling between
   --    points can generate many audit messages which the user may not
   --    always want to see when running a audit report.
   --
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/04/03 prpbcb   Oracle 7 rs239a DN none.  Does not exist on
   --                                                oracle 7.
   --                      Oracle 8 rs239b DN 11338
   --                      Initial creation.
   --                      This file was copied from rs239a.  It was created
   --                      on rs239a for dynamic selection which is not yet
   --                      complete.  There are comments in the package
   --                      description that are for dynamic selection.  I left
   --                      them alone.  This file is needed now on Oracle 8
   --                      rs239b because of changes made to forklift labor
   --                      mgmt for demand HST batches.  New packages were
   --                      created for the demand HST batches that need to
   --                      insert audit records.
   --
   --                      There are new objects created in this package and
   --                      in other packages and tables for discrete selection.
   --                      Objects in this package that prevented this package
   --                      from compiling and running have been commented out.
   --                      When dynamic selection is implemented they need to
   --                      be uncommented.
   --                      They include:
   --                         - Package pl_lm_sel.  Does not exist yet.
   --                         - Procedure ds_audit_manual_time was commented
   --                           out because it uses a dynamic selection view
   --                           that does not exist yet.
   --                         - Function f_get_audit_batch_time was commented
   --                           out because it uses a view that does not
   --                           exist yet.
   --                         - Procedure audit_labor_batch was commented out
   --                           because it calls package pl_lm_sel which does
   --                           not exist yet.
   --
   --                      Most of the functions had statements at the
   --                      beginning creating swms log debug messages.
   --                      These have been commented out for the
   --                      functions that get called many times because
   --                      of the concern it would slow processing.  This is
   --                      at the expense of debugging if a problem occurs.
   --
   --                      Below is the history form oracle 7 rs239a.
   --=======================================================================
   --    08/30/01 prpbcb   rs239a DN 10859  rs239b DN 10860  Created.
   --                      PL/SQL package version of audit functions in
   --                      PRO*C program lm_goaltime.pc.  Initially created
   --                      to use for dynamic selection.  There is still
   --                      "forklift" used in some of the procedure names.
   --                      Maybe in the future this can be changed since
   --                      dynamic selection uses the same function
   --
   --    01/18/02 prpbcb   Added "detail level" and  "audit function".
   --                      The "detail level" controls the detail level
   --                      of the audit information.  The "audit function"
   --                      designates the function being audited.
   --                      Some of the "audit functions" are:
   --                         - DS - dynamic selection
   --                         - FK - forklift labor
   --=======================================================================
   --
   --    10/05/04 prpbcb   Oracle 8 rs239b swms8 DN None
   --                      Oracle 8 rs239b swms9 DN 11861
   --                      Changed BINARY_INTEGER to PLS_INTEGER.
   --
   --    05/15/05 prpbcb   Oracle 9 rs239b swms8 DN 11490
   --                      Discrete selection changes.
   --                      Uncomment the discrete selection objects which are:
   --                         - ds_audit_manual_time
   --                         - f_get_audit_batch_time
   --                         - audit_labor_batch
   --                      Add procedure ds_audit_pickup_object.
   --                      Renamed procedure audit_pick_time to
   --                      ds_audit_pick_time.
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Type Declarations
   ---------------------------------------------------------------------------

   -- Audit record.  Not all fields apply to every operation.
   -- tmu, time and frequency are initialized to -1 which has a meaning
   -- when the audit record is inserted into the audit table.
   TYPE t_audit_rec IS RECORD
       (batch_no    forklift_audit.batch_no%TYPE,  -- Labor mgmt batch number
        operation   forklift_audit.operation%TYPE, -- Operation, ex:TRVLD,RE,LL
        tmu         PLS_INTEGER := -1,     -- Time mgmt unit for the operation
        time        NUMBER := -1,          -- Time in minutes to complete one
                                           -- unit of the operation.
        from_loc    loc.logi_loc%TYPE,     -- From location
        to_loc      loc.logi_loc%TYPE,     -- To location
        frequency   NUMBER := -1,          -- Number of units of the operation.
        pallet_id   inv.logi_loc%TYPE,     -- Pallet id
        cmt         forklift_audit.cmt%TYPE,  -- Comment or description
        user_id     forklift_audit.user_id%TYPE,  -- User performing operation
        equip_id    forklift_audit.equip_id%TYPE, -- Equipment id
        audit_func  forklift_audit.audit_func%TYPE,  -- Function being audited
                                                     -- examples: DS, FK
        detail_level forklift_audit.detail_level%TYPE -- Detail lavel
       );


   -- This record is used for the audit values that are common to all
   -- audit records for a batch being auditing.  The values will be used
   -- to populate the global variables for the audit record.
   -- To use it the application initiating the audit should declare a record
   -- of this type, populate the fields then call procedure set_audit_on
   -- passing the record as a parameter.
   TYPE t_audit_values_rec IS RECORD
       (batch_no    forklift_audit.batch_no%TYPE,  -- Labor mgmt batch number
        user_id     forklift_audit.user_id%TYPE,   -- User performing operation
        r_equip     pl_lmc.t_equip_rec,            -- Equipment record
        audit_func  forklift_audit.audit_func%TYPE -- Function being audited
                                                   -- examples: DS, FK
       );


   ---------------------------------------------------------------------------
   -- Global Variables
   ---------------------------------------------------------------------------

   g_audit_bln  BOOLEAN := FALSE;  -- Designates if auditing is on or off.
                                   -- There are procedures to turn auditing on
                                   -- and off but they may not be of much use
                                   -- in hiding the details of how auditing
                                   -- is activated because in 99.9% of the
                                   -- places that check if auditing is on
                                   -- this global variable is checked
                                   -- directly.  A function could be used
                                   -- but I felt it would slow processing
                                   -- down too much because the function
                                   -- would be called many many times.

   -- Global variables are used for the audit record information because
   -- many of the functions and procedures the write audit messages are not
   -- passed this information since it is not needed.
   -- These global variables are to be populated when the batch processing
   -- starts.
   g_batch_no    arch_batch.batch_no%TYPE := NULL;  -- Batch number being
                                                    -- processed.
   g_equip_rec   pl_lmc.t_equip_rec;                -- Equipment in use.
   g_user_id     arch_batch.user_id%TYPE := NULL;   -- Current user.
   g_audit_func  audit_detail_level.audit_func%TYPE := NULL;  -- Function being
                                             -- audited.
                                             -- Examples:
                                             --   DS - dynamic selection
                                             --   FK - forklift labor

   g_suppress_audit_message_bln BOOLEAN := FALSE;  -- Designates whether to
                                                   -- suppress audit messages.


   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------

   ct_na         NUMBER := -1;  -- If the audit record time or distance fields
                                -- has this value then NULL is inserted for the
                                -- value.  It means not applicable if you
                                -- were wondering.

   ------------------------------
   -- Audit functions.
   ------------------------------
   ct_audit_func_ds    CONSTANT VARCHAR2(2) := 'DS';  -- Dynamic selection
   ct_audit_func_fk    CONSTANT VARCHAR2(2) := 'FK';  -- Forklift

   ------------------------------
   -- Audit levels.
   ------------------------------
   ct_detail_level_1   CONSTANT PLS_INTEGER := 1;   -- Least detail
   ct_detail_level_2   CONSTANT PLS_INTEGER := 2;
   ct_detail_level_3   CONSTANT PLS_INTEGER := 3;
   ct_detail_level_4   CONSTANT PLS_INTEGER := 4;
   ct_detail_level_5   CONSTANT PLS_INTEGER := 5;
   ct_detail_level_6   CONSTANT PLS_INTEGER := 6;
   ct_detail_level_7   CONSTANT PLS_INTEGER := 7;
   ct_detail_level_8   CONSTANT PLS_INTEGER := 8;
   ct_detail_level_9   CONSTANT PLS_INTEGER := 9;   -- Most detail


   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------


   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_audit_on (overloaded)
   --
   -- Description:
   --    This procedure turns on auditing.
   ---------------------------------------------------------------------------
   PROCEDURE set_audit_on;

   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_audit_on (overloaded)
   --
   -- Description:
   --    This procedure sets the values required for auditing and turns on
   --    auditing.  These values include the user id, batch #, equipment
   --    and the function (such as forklift or dynamic selection)
   --    being audited.
   --
   --   To use it the application initiating the audit should declare a
   --   record of the designated type, populate the fields then call this
   --   procedure passing the record as a parameter.
   ---------------------------------------------------------------------------
   PROCEDURE set_audit_on(i_r_audit_values IN pl_lma.t_audit_values_rec);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_audit_off
   --
   -- Description:
   --    This procedure turns off auditing.
   ---------------------------------------------------------------------------
   PROCEDURE set_audit_off;

   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_audit_func
   --
   -- Description:
   --    This procedure sets g_audit_func to the specified value.
   ---------------------------------------------------------------------------
   PROCEDURE set_audit_func
                (i_audit_func IN audit_detail_level.audit_func%TYPE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_batch_no
   --
   -- Description:
   --    This procedure sets g_batch_no to the specified value.
   ---------------------------------------------------------------------------
   PROCEDURE set_batch_no(i_batch_no IN arch_batch.batch_no%TYPE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_equip_rec
   --
   -- Description:
   --    This procedure sets g_equip_rec to the specified value.
   ---------------------------------------------------------------------------
   PROCEDURE set_equip_rec(i_equip_rec IN pl_lmc.t_equip_rec);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_user_id
   --
   -- Description:
   --    This procedure sets g_user_id to the specified value.
   ---------------------------------------------------------------------------
   PROCEDURE set_user_id(i_user_id IN arch_batch.user_id%TYPE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    audit_cmt
   --
   -- Description:
   --    Overloaded procedure.
   --    This procedure writes a comment to the audit table.
   --    Used when no detail level is specified.  The detail level
   --    used is ct_detail_level_1.  Ideally audit_cmt should be called
   --    specifying the detail level.
   ---------------------------------------------------------------------------
   PROCEDURE audit_cmt(i_comment  IN VARCHAR2,
                       i_distance IN NUMBER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    audit_cmt
   --
   -- Description:
   --    Overloaded procedure.
   --    This procedure writes a comment to the audit table.  The detail
   --    level is included.
   ---------------------------------------------------------------------------
   PROCEDURE audit_cmt(i_comment      IN VARCHAR2,
                       i_distance     IN NUMBER,
                       i_detail_level IN NUMBER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    audit_movement
   --
   -- Description:
   --    This procedure writes a movement by the equipment to the audit table.
   ---------------------------------------------------------------------------
   PROCEDURE audit_movement(i_movement       IN VARCHAR2,
                            i_fork_movement  IN PLS_INTEGER,
                            i_cmt            IN VARCHAR2,
                            i_detail_level   IN NUMBER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    audit_travel_distance
   --
   -- Description:
   --    This procedure writes the travel distance to the audit table.
   --    After assigning values from global variables procedure
   --    audit_forklift_movement is called to continue the processing.
   ---------------------------------------------------------------------------
   PROCEDURE audit_travel_distance
                          (i_src_loc           IN loc.logi_loc%TYPE,
                           i_dest_loc          IN loc.logi_loc%TYPE,
                           i_dist_rec          IN pl_lmc.t_distance_rec,
                           i_travel_loaded_bln IN BOOLEAN);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    ds_audit_manual_time
   --
   -- Description:
   --    This procedure records the time for the manual operations for
   --    dynamic_selection.
   ---------------------------------------------------------------------------
   PROCEDURE ds_audit_manual_time(i_batch_no  IN arch_batch.batch_no%TYPE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    ds_audit_pick_time
   --
   -- Description:
   --    This procedure writes the time to pick and item from a slot to the
   --    audit table.
   ---------------------------------------------------------------------------
   PROCEDURE ds_audit_pick_time(i_prod_id           IN pm.prod_id%TYPE,
                                i_pick_loc          IN loc.logi_loc%TYPE,
                                i_no_cases          IN NUMBER,
                                i_no_splits         IN NUMBER,
                                i_tmu_no_case       IN NUMBER,
                                i_tmu_no_split      IN NUMBER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    ds_audit_pickup_object
   --
   -- Description:
   --    This procedure writes the time to pickup a pickup object to the
   --    audit table.  Used to audit discrete selection.
   ---------------------------------------------------------------------------
   PROCEDURE ds_audit_pickup_object
                    (i_pickup_object IN ds_pickup_object.pickup_object%TYPE,
                     i_pickup_point  IN ds_pickup_point.pickup_point%TYPE,
                     i_tmu           IN PLS_INTEGER,
                     i_qty           IN PLS_INTEGER);

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_audit_batch_time
   --
   -- Description:
   --    This function calculates the time in minutes to complete a batch
   --    as determined from the audit information.
   ---------------------------------------------------------------------------
   FUNCTION f_get_audit_batch_time(i_batch_no IN arch_batch.batch_no%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_audit_func
   --
   -- Description:
   --    This function determines what audit function a labor mgmt batch
   --    belongs to.  This is useful to know because table AUDIT_DETAIL_LEVEL
   --    specifies audit levels by audit function.
   ---------------------------------------------------------------------------
   FUNCTION f_get_audit_func(i_batch_no IN arch_batch.batch_no%TYPE)
   RETURN VARCHAR2;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_is_batch_audited
   --
   -- Description:
   --    This function determines if a batch has been audited which is
   --    determined by checking the labor audit table for any records for
   --    the batch.  If at least one record found then the batch has
   --    been audited.
   ---------------------------------------------------------------------------
   FUNCTION f_is_batch_audited(i_batch_no IN arch_batch.batch_no%TYPE)
   RETURN BOOLEAN;

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_audit_data
   --
   -- Description:
   --    This procedure determines if a batch has the information available
   --    to allow it to be audited and if so retrieves the information
   --    necessary to audit the batch.
   ---------------------------------------------------------------------------
   PROCEDURE get_audit_data
                   (i_batch_no                  IN  arch_batch.batch_no%TYPE,
                    o_batch_can_be_audited_bln  OUT BOOLEAN,
                    o_batch_type                OUT VARCHAR2,
                    o_key_value                 OUT VARCHAR2,
                    o_user_id                   OUT VARCHAR2,
                    o_msg                       OUT VARCHAR2);

   ----------------------------------------------------------------------------
   -- Procedure:
   --    audit_labor_batch
   --
   -- Description:
   --    This procedure audits a labor mgmt batch.  Auditing a batch consists
   --    of creating audit records that detail how the goal/target time
   --    was calculated.
   --
   --    Not all batches can be audited in this manner and the information
   --    still needs to be in swms to create the audit records.  Forklift
   --    batches can only be audited when the batch is completed because it
   --    depends on the existing pallets in the source and destination
   --    locations and the destination location is not known until the
   --    batch is completed.  For dynamic selection batches the order
   --    processing information needs to exist.  If the orders have been
   --    purged then a dynamic selection batch cannot be audited.
   --
   --    Be aware that values can be changed so that later if a audit is
   --    run on a batch the goal/target time of the audit does not batch
   --    the batch's goal/target time.  This can happen for a normal selection
   --    batch if the pickup points are changed or if the case or split tmu
   --    for a slot is changed.
   ----------------------------------------------------------------------------
   PROCEDURE audit_labor_batch
                   (i_batch_no              IN  arch_batch.batch_no%TYPE,
                    o_audit_successful_bln  OUT BOOLEAN,
                    o_msg                   OUT VARCHAR2);

END pl_lma;  -- end package specification
/


PROMPT Create package body: pl_lma

/*************************************************************************/
-- Package Body
/*************************************************************************/
CREATE OR REPLACE PACKAGE BODY swms.pl_lma
IS

   -- sccs_id=@(#) src/schema/plsql/pl_lma.sql, swms, swms.9, 10.1.1 9/7/06 1.5

   ----------------------------------------------------------------------------
   -- Package Name:
   --    pl_lma
   --
   -- Description:
   --    Labor management audit package.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/04/03 prpbcb   Oracle 7 rs239a DN none.  Does not exist on
   --                                                oracle 7.
   --                      Oracle 8 rs239b DN 11338
   --                      Initial creation.
   --                      This file was copied from rs239a.  It was created
   --                      on rs239a for dynamic selection which is not yet
   --                      complete.  There are comments in the package
   --                      description that are for dynamic selection.  I left
   --                      them alone.  This file is needed now on Oracle 8
   --                      rs239b because of changes made to forklift labor
   --                      mgmt for demand HST batches.  New packages were
   --                      created for the demand HST batches that need to
   --                      insert audit records.
   --
   --                      Below is the history form oracle 7 rs239a.
   --=======================================================================
   --    08/30/01 prpbcb   rs239a DN 10859  rs239b DN 10860  Created.
   --=======================================================================
   --
   ----------------------------------------------------------------------------


   ----------------------------------------------------------------------------
   -- Private Global Variables
   ----------------------------------------------------------------------------
   gl_pkg_name   VARCHAR2(20) := 'pl_lma';   -- Package name.  Used in
                                             -- error messages.

   gl_insert_failed_bln  BOOLEAN := FALSE;   -- Keeps track if inserting an
                                    -- audit message failed in order to reduce
                                    -- the number of log messages down to a
                                    -- reasonable number in the event the
                                    -- insert fails for every record.


   ----------------------------------------------------------------------------
   -- Private Constants
   ----------------------------------------------------------------------------

   ct_audit_cmt_len   CONSTANT PLS_INTEGER := 2000;  -- Size of
                               -- forklift_audit.cmt column.  Used to truncate
                               -- comments longer than the column size.

   -- Reasons why a batch cannot be audited.  These are used in
   -- f_build_cannot_be_audited_msg and get_audit_data to build a message
   -- for the user.
   ct_bad_status         CONSTANT PLS_INTEGER := 1;
   ct_bad_pallet_pull    CONSTANT PLS_INTEGER := 2;
   ct_route_purged       CONSTANT PLS_INTEGER := 3;
   ct_ds_not_active      CONSTANT PLS_INTEGER := 4;
   ct_forklift_batch     CONSTANT PLS_INTEGER := 6;
   ct_indirect_batch     CONSTANT PLS_INTEGER := 7;
   ct_loader_batch       CONSTANT PLS_INTEGER := 8;

   ----------------------------------------------------------------------------
   -- Private Modules
   ----------------------------------------------------------------------------

   ----------------------------------------------------------------------------
   -- Function:
   --    f_build_cannot_be_audited_msg
   --
   -- Description:
   --    This procedure build the message stating why a batch cannot be
   --    audited.
   --
   -- Parameters:
   --    i_what_happened     - Designates what happened.
   --    i_batch_no          - Labor mgmt batch number.
   --    i_pallet_pull       - float.pallet_pull if a selection batch
   --    i_status            - Batch status
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error     - Got an oracle error.
   --
   -- Called by:
   --    get_audit_data
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ----------------------------------------------------
   --    05/16/02 prpbcb   Created.
   --
   ----------------------------------------------------------------------------
   FUNCTION f_build_cannot_be_audited_msg
      (i_what_happened             IN  PLS_INTEGER,
       i_batch_no                  IN  arch_batch.batch_no%TYPE,
       i_pallet_pull               floats.pallet_pull%TYPE DEFAULT NULL,
       i_status                    arch_batch.status%TYPE DEFAULT NULL)
   RETURN VARCHAR2 IS
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) :=
                             gl_pkg_name || '.f_build_cannot_be_audited_msg';

      l_msg            VARCHAR2(256);  -- Reason why batch cannot be audited.
   BEGIN
      l_message_param := l_object_name ||
         '(i_batch_no[' || i_batch_no || ']' ||
         ',i_what_happented[' || TO_CHAR(i_what_happened) || '])';

   IF (i_what_happened = ct_bad_status) THEN
      -- The batch has to have a certain status in order for it to be audited.
      l_msg := 'Batch ' || i_batch_no || ' has status of ' ||
            i_status || '.  Allowable status''s for auditing are F, A or C.';
   ELSIF (i_what_happened = ct_bad_pallet_pull) THEN
      -- The batch has to be a normal selection batch.
      IF (i_pallet_pull = 'B') THEN
         l_msg := 'Batch ' || i_batch_no || ' is a bulk pull.' ||
                  '  Only normal selection batches can be audited.';
      ELSE
         -- Have unhandled value for l_pallet_pull.  Use a generic message.
         l_msg := 'Batch ' || i_batch_no || ' has pallet pull of ' ||
                  i_pallet_pull || '.' ||
                  '  Only normal selection batches can be audited.';
      END IF;
   ELSIF (i_what_happened = ct_route_purged) THEN
      -- Route info purged.
      l_msg := 'Batch ' || i_batch_no || ' has no selection' ||
               ' information associated with it probably because the' ||
               ' route has been purged.  It cannot be audited.';
   ELSIF (i_what_happened = ct_ds_not_active) THEN
      -- Dynamic selection not active.
      l_msg := 'Batch ' || i_batch_no || ' cannot be audited' ||
               ' because Dynamic Selection is not active.';
   ELSIF (i_what_happened = ct_forklift_batch) THEN
      l_msg := 'Batch ' || i_batch_no || ' has to be audited when' ||
               ' the batch is completed by having the FORKLIFT AUDIT' ||
               ' syspar set to Y.';
   ELSIF (i_what_happened = ct_indirect_batch) THEN
      l_msg := 'Batch ' || i_batch_no || ' is an indirect batch which' ||
               ' cannot be audited.';
   ELSIF (i_what_happened = ct_loader_batch) THEN
      l_msg := 'Batch ' || i_batch_no || ' is a loader batch which is' ||
               ' not setup to be audited.';
   ELSE
      -- i_what_happened has an unhandled value.  This will not be a fatal
      -- error.
      pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                  l_message_param || '  Unhandled value for i_what_happened',
                  pl_exc.ct_data_error, NULL);
      l_msg := 'Batch ' || i_batch_no || ' cannot be audited.';
   END IF;

   RETURN(l_msg);

   EXCEPTION
      WHEN OTHERS THEN
         -- This is a fatal error.
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END f_build_cannot_be_audited_msg;

   ----------------------------------------------------------------------------
   -- Procedure:
   --    insert_audit_rec
   --
   -- Description:
   --    This procedure inserts the audit record into the database.
   --    If the audit record time or distance fields have a value of
   --    pl_lma.ct_na then NULL is inserted for the value.
   --
   --    If the insert fails then an aplog message is written.  Only
   --    one message is written per batch to keep swms.log from growing
   --    extremely large.  The most likely reason for the insert to fail
   --    is reaching the maximum number of extents on the table or an index.
   --    A size limit was placed on the table and indexes to keep database space
   --    from being comsumed if the forklift audit syspar was inadvertently
   --    left on for an extended period of time.
   --
   -- Parameters:
   --    i_r_audit    - Audit information record.
   --
   -- Exceptions raised:
   --    None.  An error will not stop processing but an aplog message will
   --    be written.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ----------------------------------------------------
   --    10/05/01 prpbcb   Created.
   ----------------------------------------------------------------------------
   PROCEDURE insert_audit_rec(i_r_audit  IN t_audit_rec)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.insert_audit_rec';

   BEGIN

      -- l_message_param := l_object_name || '(i_r_audit)  batch#=' ||
      -- i_r_audit.batch_no || ' operation=' || i_r_audit.operation;

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
      --                NULL, NULL);

      INSERT INTO forklift_audit
                     (batch_no,
                      operation,
                      tmu,
                      time,
                      from_loc,
                      to_loc,
                      frequency,
                      pallet_id,
                      cmt,
                      user_id,
                      equip_id,
                      add_date,
                      seq_no,
                      audit_func,
                      detail_level)
           VALUES
                     (i_r_audit.batch_no,
                      i_r_audit.operation,
                      DECODE(i_r_audit.tmu, pl_lma.ct_na, NULL,
                                            i_r_audit.tmu),
                      DECODE(i_r_audit.time, pl_lma.ct_na, NULL,
                                             i_r_audit.time),
                      i_r_audit.from_loc,
                      i_r_audit.to_loc,
                      DECODE(i_r_audit.frequency, pl_lma.ct_na, NULL,
                                                  i_r_audit.frequency),
                      i_r_audit.pallet_id,
                      i_r_audit.cmt,
                      i_r_audit.user_id,
                      i_r_audit.equip_id,
                      SYSDATE,
                      forklift_audit_seq.NEXTVAL,
                      i_r_audit.audit_func,
                      i_r_audit.detail_level);

   -- Errors won't stop processing.
   EXCEPTION
      WHEN OTHERS THEN
         -- Insert failed.  Only one aplog message is written per session
         -- to keep the messages written from growing extremely large.
         --
         -- 01/31/02 prpbcb  Changed to keep writing messages.  Users on a
         -- termimal will have the same session session until they logout.
         -- We want to continue logging messages.
         -- This ideal was first put in place for forklift labor mgmt which
         -- calls host programs which logon, do their thing then logoff.
         IF (gl_insert_failed_bln = FALSE) THEN
            l_message := 'TABLE=forklift_audit  ACTION=INSERT' ||
               '  batch_no=' || i_r_audit.batch_no ||
               '  operation=' || i_r_audit.operation ||
               '  cmt=' || SUBSTR(i_r_audit.cmt,1,40) ||
               '  MESSAGE="Insert failed"';

            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            -- gl_insert_failed_bln := TRUE;   -- Keep logging.
         END IF;

   END insert_audit_rec;


   ----------------------------------------------------------------------------
   -- Procedure:
   --    audit_forklift_movement
   --
   -- Description:
   --    This procedure continues the processing of auditing an equipment
   --    movement.
   --
   -- Parameters:
   --    i_movement    - Type of movement.  Examples:  TIA (turn into aisle)
   --    i_r_equip     - Equipment tmu values.
   --    i_r_audit     - Audit record.
   --
   -- Exceptions raised:
   --    None.  An error will not stop processing but an aplog message will
   --    be written.
   --
   -- Called by:
   --    audit_movement   10/07/01  prpbcb  A thought--We may be able to move
   --                               the processing in this procedure to
   --                               audit_movement and do away with
   --                               audit_forklift_movement.  This would
   --                               require changes to audit_travel_distance.
   --                               Something to think about to improve
   --                               performance by removing a procedure call.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ----------------------------------------------------
   --    10/07/01 prpbcb   Created.
   ----------------------------------------------------------------------------
   PROCEDURE audit_forklift_movement(i_movement  IN VARCHAR2,
                                     i_r_equip   IN pl_lmc.t_equip_rec,
                                     i_r_audit   IN t_audit_rec)
   IS
      l_message        VARCHAR2(128);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                                '.audit_forklift_movement';

      l_r_audit     t_audit_rec;

      e_bad_movement EXCEPTION;   -- Unrecognized i_movement

   BEGIN

      l_message_param := l_object_name || '(' || i_movement ||
         ',i_r_equip, i_r_audit)  batch#=' || i_r_audit.batch_no;

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
      --             NULL, NULL);

      -- Copy the audit record to the local variable.  Under oracle 8 it may
      -- be best (to improve performance) to declare i_r_audit as IN OUT and
      -- use the NOCOPY option.
      l_r_audit := i_r_audit;

      IF (i_movement = 'TRVLD') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.trav_rate_loaded;
      ELSIF (i_movement = 'DECLD') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.decel_rate_loaded;
      ELSIF (i_movement = 'ACCLD') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.accel_rate_loaded;
      ELSIF (i_movement = 'LL') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.ll;
      ELSIF (i_movement = 'RL') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.rl;
      ELSIF (i_movement = 'TRVEMP') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.trav_rate_empty;
      ELSIF (i_movement = 'DECEMP') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.decel_rate_empty;
      ELSIF (i_movement = 'ACCEMP') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.accel_rate_empty;
      ELSIF (i_movement = 'LE') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.le;
      ELSIF (i_movement = 'RE') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.re;
      ELSIF (i_movement = 'DS') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.ds;
      ELSIF (i_movement = 'APOF') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.apof;
      ELSIF (i_movement = 'MEPOF') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.mepof;
      ELSIF (i_movement = 'PPOF') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.ppof;
      ELSIF (i_movement = 'APOS') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.apos;
      ELSIF (i_movement = 'MEPOS') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.mepos;
      ELSIF (i_movement = 'PPOS') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.ppos;
      ELSIF (i_movement = 'APIR') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.apir;
      ELSIF (i_movement = 'MEPIR') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.mepir;
      ELSIF (i_movement = 'PPIR') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.ppir;
      ELSIF (i_movement = 'BT90') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.bt90;
      ELSIF (i_movement = 'BP') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.bp;
      ELSIF (i_movement = 'TID') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.tid;
      ELSIF (i_movement = 'TIA') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.tia;
      ELSIF (i_movement = 'TIR') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.tir;
      ELSIF (i_movement = 'APIDI') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.apidi;
      ELSIF (i_movement = 'MEPIDI') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.mepidi;
      ELSIF (i_movement = 'PPIDI') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.ppidi;
      ELSIF (i_movement = 'TIDI') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.tidi;
      ELSIF (i_movement = 'APIPB') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.apipb;
      ELSIF (i_movement = 'MEPIPB') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.mepipb;
      ELSIF (i_movement = 'PPIPB') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.ppipb;
      ELSIF (i_movement = 'APIDD') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.apidd;
      ELSIF (i_movement = 'MEPIDD') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.mepidd;
      ELSIF (i_movement = 'PPIDD') THEN
         l_r_audit.operation := i_movement;
         l_r_audit.time := i_r_equip.ppidd;
      ELSE
         -- Unrecognized movement.
         RAISE e_bad_movement;
      END IF;

      l_r_audit.detail_level := pl_lma.ct_detail_level_1;
      insert_audit_rec(l_r_audit);

   -- Errors won't stop processing.
   EXCEPTION
      WHEN e_bad_movement THEN
         l_message := l_object_name || '  Unrecognized forklift' ||
            ' movement[' || i_movement || '] in parameter i_movement.' ||
            '  Movement not recorded.  This will not stop processing.';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message, NULL,
                        NULL);
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
            l_message_param || '  This will not stop processing.',
                        SQLCODE, SQLERRM);

   END audit_forklift_movement;


   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_audit_on (overloaded)
   --
   -- Description:
   --    This procedure turns on auditing.  This is done by setting
   --    pl_lma.g_audit_bln to TRUE.
   --
   -- Parameters:
   --    None
   --
   -- Exceptions raised:
   --    None.  An error here will not stop processing but an aplog message
   --    will be written.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/18/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE set_audit_on
   IS
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.set_audit_on';

   BEGIN

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, NULL, NULL, NULL);

      pl_lma.g_audit_bln := TRUE;

   -- Errors won't stop processing.
   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                        'Failed to turn on auditing.', SQLCODE, SQLERRM);

   END set_audit_on;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_audit_on (overloaded)
   --
   -- Description:
   --    This procedure sets the values required for auditing and turns on
   --    auditing.  These values include the user id, batch #, equip id
   --    and the function (such as forklift or dynamic selection)
   --    being audited.
   --
   --    To use it the application initiating the audit should declare a
   --    record of the designated type, populate the fields including
   --    populating the equipment record then call this procedure passing
   --    the record as a parameter.
   --
   -- Parameters:
   --    i_r_audit_values - Record of tthe batch number and related values
   --                       to audit.  The fields in this record need to
   --                       be populated before calling this procedure.
   --
   -- Exceptions raised:
   --    None.  An error here will not stop processing but an aplog message
   --    will be written.
   --
   -- Called by:
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/05/03 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE set_audit_on(i_r_audit_values IN pl_lma.t_audit_values_rec)
   IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.set_audit_on';

      l_equip        pl_lmc.t_equip_rec;  -- Equipment record.
   BEGIN

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, NULL, NULL, NULL);

      set_batch_no(i_r_audit_values.batch_no);
      set_user_id(i_r_audit_values.user_id);
      set_equip_rec(i_r_audit_values.r_equip);
      set_audit_func(i_r_audit_values.audit_func);
      set_audit_on;

   -- Errors won't stop processing.
   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name ||
      '(i_r_audit_values.batch_no[' || i_r_audit_values.batch_no || ']' ||
      ',i_r_audit_values.user_id[' || i_r_audit_values.user_id || ']' ||
      ',i_r_audit_values.r_equip.equip_id[' ||
                         i_r_audit_values.r_equip.equip_id || ']' ||
      ',i_r_audit_values.audit_func[' || i_r_audit_values.audit_func || '])' ||
      '  Processing will continue but the audit will be incorrect.';

         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);

   END set_audit_on;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_audit_off
   --
   -- Description:
   --    This procedure turns on auditing.  This is done by setting
   --    pl_lma.g_audit_bln to FALSE.
   --
   -- Parameters:
   --    None
   --
   -- Exceptions raised:
   --    None.  An error here will not stop processing but an aplog message
   --    will be written.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/18/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE set_audit_off
   IS
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.set_audit_off';

   BEGIN

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, NULL, NULL, NULL);

      pl_lma.g_audit_bln := FALSE;

   -- Errors won't stop processing.
   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                        'Failed to turn off auditing.', SQLCODE, SQLERRM);

   END set_audit_off;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_audit_func
   --
   -- Description:
   --    This procedure sets g_audit_func to the specified value.  This global
   --    variable is used when inserting audit records.
   --
   -- Parameters:
   --    i_audit_func  - The audit function to assign to pl_lma.g_audit_func.
   --
   -- Exceptions raised:
   --    None.  An error here will not stop processing but an aplog message
   --    will be written.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/18/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE set_audit_func
                (i_audit_func IN audit_detail_level.audit_func%TYPE)
   IS
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.set_audit_func';

      e_parameter_null  EXCEPTION;

   BEGIN
      l_message_param := l_object_name || '(i_audit_func[' ||
                         i_audit_func || '])';

      IF (i_audit_func IS NULL) THEN
         RAISE e_parameter_null;
      END IF;

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
      --                NULL, NULL);

      pl_lma.g_audit_func := i_audit_func;

   -- Errors won't stop processing.
   EXCEPTION
      WHEN e_parameter_null THEN
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
    l_message_param || '  Parameter is null.  This will not stop processing.',
                        pl_exc.ct_data_error, NULL);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                        l_message_param || '  This will not stop processing.',
                        SQLCODE, SQLERRM);

   END set_audit_func;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_batch_no
   --
   -- Description:
   --    This procedure sets g_batch_no to the specified value.  This global
   --    variable is used when inserting audit records.
   --
   -- Parameters:
   --    i_batch_no  - The labor mgmt batch number to assign to
   --                  pl_lma.g_batch_no.
   --
   -- Exceptions raised:
   --    None.  An error here will not stop processing but an aplog message
   --    will be written.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/18/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE set_batch_no(i_batch_no IN arch_batch.batch_no%TYPE)
   IS
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.set_batch_no';

      e_parameter_null  EXCEPTION;

   BEGIN
      l_message_param := l_object_name || '(i_batch_no[' ||
                         i_batch_no || '])';

      IF (i_batch_no IS NULL) THEN
         RAISE e_parameter_null;
      END IF;

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
      --                NULL, NULL);

      pl_lma.g_batch_no := i_batch_no;

   -- Errors won't stop processing.
   EXCEPTION
      WHEN e_parameter_null THEN
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
   l_message_param || '  Parameter is null.  This will not stop processing.',
                        pl_exc.ct_data_error, NULL);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
               l_message_param || '  This will not stop processing.',
                        SQLCODE, SQLERRM);

   END set_batch_no;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_equip_rec
   --
   -- Description:
   --    This procedure sets g_equip_rec to the specified value.  This global
   --    variable is used when inserting audit records.
   --
   -- Parameters:
   --    i_equip_rec  - The equipment record to assign to pl_lma.g_equip_rec.
   --                   The fields need to be populated with all the values
   --                   before calling this procedure.
   --
   -- Exceptions raised:
   --    None.  An error here will not stop processing but an aplog message
   --    will be written.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/18/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE set_equip_rec(i_equip_rec IN pl_lmc.t_equip_rec)
   IS
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.set_equip_rec';

      e_parameter_null  EXCEPTION;

   BEGIN
      l_message_param := l_object_name || '(i_equip_rec[' ||
                         i_equip_rec.equip_id || '])';

      -- Check if equip id is null.  Don't check the whole record.
      IF (i_equip_rec.equip_id IS NULL) THEN
         RAISE e_parameter_null;
      END IF;

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      pl_lma.g_equip_rec := i_equip_rec;

   -- Errors won't stop processing.
   EXCEPTION
      WHEN e_parameter_null THEN
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
    l_message_param || '  Parameter is null.  This will not stop processing',
                        pl_exc.ct_data_error, NULL);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                        l_message_param || '  This will not stop processing',
                        SQLCODE, SQLERRM);

   END set_equip_rec;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_user_id
   --
   -- Description:
   --    This procedure sets g_user_id to the specified value.  This global
   --    variable is used when inserting audit records.
   --
   -- Parameters:
   --    i_user_id  - The user id to assign to pl_lma.g_user_id.  If the
   --                 batch being audited is a future batch then i_user_id
   --                 will be null which is allowable.
   --
   -- Exceptions raised:
   --    None.  An error here will not stop processing but an aplog message
   --    will be written.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/18/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE set_user_id(i_user_id IN arch_batch.user_id%TYPE)
   IS
      l_message_param   VARCHAR2(128);    -- Message buffer
      l_object_name     VARCHAR2(61) := gl_pkg_name || '.set_user_id';

   BEGIN
      l_message_param := l_object_name || '(i_user_id[' ||
                         i_user_id || '])';

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
      --                NULL, NULL);

      pl_lma.g_user_id := i_user_id;

   -- Errors won't stop processing.
   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                        l_message_param || '  This will not stop processing.',
                        SQLCODE, SQLERRM);

   END set_user_id;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    audit_cmt
   --
   -- Description:
   --    Overloaded procedure.
   --    This procedure writes a comment to the audit table.
   --    Used when no detail level is specified.  The detail level
   --    used is ct_detail_level_1.  Ideally audit_cmt should be called
   --    specifying the detail level.
   --
   -- Parameters:
   --    i_comment      - Comment.  It will be truncated if its length
   --                     is greater than ct_audit_cmt_len.
   --    i_distance     - Distance which will be inserted in the audit
   --                     table in the distance column.  If value is
   --                     pl_lma.ct_na then null is inserted into
   --                     the audit table.  Used mainly to record a segment
   --                     distance between a source location and a destination
   --                     location.  The audit shows the total distance but we
   --                     also want to show the distances between the segments.
   --
   -- Exceptions raised:
   --    None.  An error here will not stop processing but an aplog message
   --    will be written.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    01/18/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE audit_cmt(i_comment      IN VARCHAR2,
                       i_distance     IN NUMBER)
   IS
      l_message_param  VARCHAR2(512);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.audit_cmt';

   BEGIN

      -- l_message_param := l_object_name || '(' || i_comment || ',' ||
      --     TO_CHAR(i_distance) || ')';

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
      --                NULL, NULL);

      audit_cmt(i_comment, i_distance, ct_detail_level_1);

   -- Errors won't stop processing.
   EXCEPTION
      WHEN OTHERS THEN
         l_message_param := l_object_name || '(' || i_comment || ',' ||
             TO_CHAR(i_distance) || ')';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);

   END audit_cmt;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    audit_cmt
   --
   -- Description:
   --    Overloaded procedure.
   --    This procedure writes a comment to the audit table.
   --
   -- Parameters:
   --    i_comment      - Comment.  It will be truncated if its length
   --                     is greater than ct_audit_cmt_len.
   --    i_distance     - Distance which will be inserted in the audit
   --                     table in the distance column.  If value is
   --                     pl_lma.ct_na then null is inserted into
   --                     the audit table.  Used mainly to record a segment
   --                     distance between a source location and a destination
   --                     location.  The audit shows the total distance but we
   --                     also want to show the distances between the segments.
   --    i_detail_level - Detail level.
   --
   -- Globals accessed:
   --    - pl_lma.g_batch_no
   --    - pl_lma.g_user_id
   --    - pl_lma.g_equip_rec.equip_id
   --    - pl_lma.g_audit_func
   --
   -- Exceptions raised:
   --    None.  An error here will not stop processing but an aplog message
   --    will be written.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/04/01 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE audit_cmt(i_comment      IN VARCHAR2,
                       i_distance     IN NUMBER,
                       i_detail_level IN NUMBER)
   IS
      l_message_param  VARCHAR2(512);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.audit_cmt';

      l_r_audit     t_audit_rec;

   BEGIN

      -- l_message_param := l_object_name || '(' || i_comment || ',' ||
      --    TO_CHAR(i_distance) || ',' || TO_CHAR(i_detail_level) || ')';

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
      --                NULL, NULL);

      -- Assign values from globals.
      l_r_audit.batch_no := pl_lma.g_batch_no;
      l_r_audit.user_id := pl_lma.g_user_id;
      l_r_audit.equip_id := pl_lma.g_equip_rec.equip_id;
      l_r_audit.audit_func := pl_lma.g_audit_func;

      l_r_audit.operation := 'CMT';     -- CMT denotes a comment
      l_r_audit.frequency := i_distance;
      -- The comment gets truncated if its longer than ct_audit_cmt_len.
      l_r_audit.cmt := SUBSTR(i_comment, 1, ct_audit_cmt_len);
      l_r_audit.detail_level := i_detail_level;

      pl_lma.insert_audit_rec(l_r_audit);  -- Insert the record into the
                                             -- audit table.

   -- Errors won't stop processing.
   EXCEPTION
      WHEN OTHERS THEN
         l_message_param := l_object_name || '(' || i_comment || ',' ||
             TO_CHAR(i_distance) || ',' || TO_CHAR(i_detail_level) || ')';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                        l_message_param || '  This will not stop processing.',
                        SQLCODE, SQLERRM);

   END audit_cmt;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    audit_movement
   --
   -- Description:
   --    This procedure writes a movement by the equipment to the audit table.
   --    After assigning values from global variables procedure
   --    audit_forklift_movement is called to continue the processing.
   --
   -- Parameters:
   --    i_movement       - Type of movement.  Examples:  TIA (turn into aisle)
   --                                                     RL (raise loaded)
   --    i_fork_movement  - Frequency.  Either 1 or a distance.  The distance
   --                       can be either feet or inches.
   --    i_cmt            - Comment.  It will be truncated if its length
   --                       is greater than ct_audit_cmt_len.
   --    i_detail_level   - Detail level.
   --
   -- Exceptions raised:
   --    None.  An error here should will not stop processing but an
   --           aplog message will be written.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/05/01 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE audit_movement(i_movement       IN VARCHAR2,
                            i_fork_movement  IN PLS_INTEGER,
                            i_cmt            IN VARCHAR2,
                            i_detail_level   IN NUMBER)
   IS
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.audit_movement';

      l_r_audit        t_audit_rec;

   BEGIN

      -- l_message_param := l_object_name || '(' || i_movement ||
      --    ',i_r_equip,' || TO_CHAR(i_fork_movement) || ',' || i_cmt || ',' ||
      --    TO_CHAR(i_detail_level) || ')';

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
      --                NULL, NULL);

      -- Assign values from globals.
      l_r_audit.batch_no := pl_lma.g_batch_no;
      l_r_audit.user_id := pl_lma.g_user_id;
      l_r_audit.equip_id := pl_lma.g_equip_rec.equip_id;
      l_r_audit.audit_func := pl_lma.g_audit_func;

      l_r_audit.frequency := i_fork_movement;
      -- The comment gets truncated if its longer than ct_audit_cmt_len.
      l_r_audit.cmt := SUBSTR(i_cmt, 1, ct_audit_cmt_len);
      l_r_audit.detail_level := i_detail_level;

      audit_forklift_movement(i_movement, pl_lma.g_equip_rec, l_r_audit);

   -- Errors won't stop processing.
   EXCEPTION
      WHEN OTHERS THEN
         l_message_param := l_object_name || '(' || i_movement ||
            ',i_r_equip,' || TO_CHAR(i_fork_movement) || ',' || i_cmt || ',' ||
            TO_CHAR(i_detail_level) || ')' ||
            '  This will not stop processing.';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);

   END audit_movement;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    audit_travel_distance
   --
   -- Description:
   --    This procedure writes the travel distance to the audit table.
   --    After assigning values from global variables procedure
   --    audit_forklift_movement is called to continue the processing.
   --
   -- Parameters:
   --    i_src_loc            - Source location.
   --    i_dest_loc           - Destination location.
   --    i_dist_rec           - Distance traveled.  Stored in a record.
   --    i_travel_loaded_bln  - Designates if carrying a load or no load.
   --                           If TRUE then traveling with a load.
   --                           If FALSE then traveling empty.
   --
   -- Exceptions raised:
   --    None.  An error here will not stop processing but an
   --           aplog message will be written.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    01/13/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE audit_travel_distance(i_src_loc           IN loc.logi_loc%TYPE,
                                   i_dest_loc          IN loc.logi_loc%TYPE,
                                   i_dist_rec          IN pl_lmc.t_distance_rec,
                                   i_travel_loaded_bln IN BOOLEAN)
   IS
      l_message        VARCHAR2(128);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.audit_travel_distance';

      l_r_audit        t_audit_rec;

   BEGIN

      IF (i_travel_loaded_bln) THEN
         l_message := 'TRUE';
      ELSE
         l_message := 'FALSE';
      END IF;

      -- l_message_param := l_object_name ||
      --                    '(i_src_loc[' || i_src_loc || ']' ||
      --                    ',i_dest_loc[' || i_dest_loc || ']' ||
      --                    ',i_dist_rec' ||
      --                    ',i_travel_loaded_bln[' || l_message || '])';

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
      --                NULL, NULL);

      -- Assign values from globals.
      l_r_audit.batch_no := pl_lma.g_batch_no;
      l_r_audit.user_id := pl_lma.g_user_id;
      l_r_audit.equip_id := pl_lma.g_equip_rec.equip_id;
      l_r_audit.audit_func := pl_lma.g_audit_func;

      l_r_audit.from_loc := i_src_loc;
      l_r_audit.to_loc := i_dest_loc;

      IF (i_travel_loaded_bln) THEN
         l_r_audit.cmt := 'Travel from ' || i_src_loc || ' to ' ||
                            i_dest_loc || '.';
         l_r_audit.frequency := i_dist_rec.accel_distance;
         audit_forklift_movement('ACCLD', g_equip_rec, l_r_audit);

         l_r_audit.cmt := NULL;
         l_r_audit.frequency := i_dist_rec.travel_distance;
         audit_forklift_movement('TRVLD', g_equip_rec, l_r_audit);

         l_r_audit.frequency := i_dist_rec.decel_distance;
         audit_forklift_movement('DECLD', g_equip_rec, l_r_audit);
      ELSE
         l_r_audit.cmt := 'Travel from ' || i_src_loc || ' to ' ||
                            i_dest_loc || '.';
         l_r_audit.frequency := i_dist_rec.accel_distance;
         audit_forklift_movement('ACCEMP', g_equip_rec, l_r_audit);

         l_r_audit.cmt := NULL;
         l_r_audit.frequency := i_dist_rec.travel_distance;
         audit_forklift_movement('TRVEMP', g_equip_rec, l_r_audit);

         l_r_audit.frequency := i_dist_rec.decel_distance;
         audit_forklift_movement('DECEMP', g_equip_rec, l_r_audit);
      END IF;

   -- Errors won't stop processing.
   EXCEPTION
      WHEN OTHERS THEN
         l_message_param := l_object_name ||
                         '(i_src_loc[' || i_src_loc || ']' ||
                         ',i_dest_loc[' || i_dest_loc || ']' ||
                         ',i_dist_rec' ||
                         ',i_travel_loaded_bln[' || l_message || '])';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                        l_message_param || '  This will not stop processing.',
                        SQLCODE, SQLERRM);

   END audit_travel_distance;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    ds_audit_manual_time
   --
   -- Description:
   --    This procedure records the time for the manual operations for
   --    dynamic_selection.
   --
   -- Parameters:
   --    i_batch_no      - Labor mgmt selection batch number.
   --
   -- Exceptions raised:
   --    None.  An error will not stop processing but an aplog message will
   --    be written.
   --
   -- Called by:
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    01/27/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE ds_audit_manual_time(i_batch_no  IN arch_batch.batch_no%TYPE)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.ds_audit_manual_time';

      l_found_bln   BOOLEAN := FALSE;
      l_r_audit     t_audit_rec;

      e_batch_not_found  EXCEPTION;  -- Could not find the batch.

      -- This cursor selects the batch and job code information used
      -- in creating the audit records.
      CURSOR c_batch(cp_batch_no  IN arch_batch.batch_no%TYPE) IS
         SELECT *
           FROM v_ds_audit_manual_operation aud
          WHERE aud.batch_no = cp_batch_no
          ORDER BY aud.seq;

   BEGIN

      -- l_message_param := l_object_name || '(' || i_batch_no || ')';

      -- pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
      --                NULL, NULL);

      -- Assign values from globals.
      l_r_audit.batch_no   := pl_lma.g_batch_no;
      l_r_audit.user_id    := pl_lma.g_user_id;
      l_r_audit.equip_id   := pl_lma.g_equip_rec.equip_id;
      l_r_audit.audit_func := pl_lma.g_audit_func;

      pl_lma.audit_cmt('', ct_na, ct_detail_level_1);  -- Blank line

      -- Create the audit records for each operation.  The operations
      -- not used in calculating the goal/target time for a batch have the
      -- time set to 0.  The audit reports calculates the time for a batch
      -- by looking at the time and frequency fields.
      -- NOTE:  The audit time is in minutes.
      FOR r_batch IN c_batch(i_batch_no) LOOP

         l_found_bln := TRUE;

         l_r_audit.operation    := r_batch.operation;
         l_r_audit.tmu          := r_batch.tmu;
         l_r_audit.time         := r_batch.tmu_min;
         l_r_audit.frequency    := r_batch.kvi;
         l_r_audit.detail_level := ct_detail_level_1;
         insert_audit_rec(l_r_audit);

      END LOOP;

      IF (NOT l_found_bln) THEN
         RAISE e_batch_not_found;
      END IF;

   -- Errors won't stop processing.
   EXCEPTION
      WHEN e_batch_not_found THEN
         l_message := l_object_name || ' TABLE=batch,job_code  ACTION=SELECT'||
            '  MESSAGE="Batch ' || i_batch_no || ' not found.  This will ' ||
            ' not stop processing"';
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_1);
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);

      WHEN OTHERS THEN
         l_message_param := l_object_name || '(' || i_batch_no || ')';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
             l_message_param || '  This will not stop processing.',
                        SQLCODE, SQLERRM);

   END ds_audit_manual_time;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    ds_audit_pick_time
   --
   -- Description:
   --    This procedure writes the time to pick and item from a slot to the
   --    audit table.  Used to audit dynamic selection.
   --
   -- Parameters:
   --    i_prod_id        - Item being picked.
   --    i_pick_loc       - Pick location.
   --    i_no_cases       - Number cases picked.
   --    i_no_splits      - Number of splits picked.
   --    i_tmu_no_case    - TMU for a case.
   --    i_tmu_no_split   - TMU for a split.
   --
   -- Exceptions raised:
   --    None.  An error will not stop processing but an aplog message will
   --    be written.
   --
   -- Called by:
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    01/29/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE ds_audit_pick_time(i_prod_id           IN pm.prod_id%TYPE,
                                i_pick_loc          IN loc.logi_loc%TYPE,
                                i_no_cases          IN NUMBER,
                                i_no_splits         IN NUMBER,
                                i_tmu_no_case       IN NUMBER,
                                i_tmu_no_split      IN NUMBER)
   IS
      l_message       VARCHAR2(256);   -- Message buffer
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.ds_audit_pick_time';

      l_buf           VARCHAR2(40);    -- Work area
      l_r_audit       t_audit_rec;

   BEGIN

      -- Assign values from globals.
      l_r_audit.batch_no   := pl_lma.g_batch_no;
      l_r_audit.user_id    := pl_lma.g_user_id;
      l_r_audit.equip_id   := pl_lma.g_equip_rec.equip_id;
      l_r_audit.audit_func := pl_lma.g_audit_func;

      IF (i_no_cases > 0) THEN
         l_r_audit.operation    := 'PIK';
         l_r_audit.tmu          := i_tmu_no_case;
         l_r_audit.time         := i_tmu_no_case / 1667;  -- Time in minutes
         l_r_audit.frequency    := i_no_cases;

         IF (i_no_cases = 1) THEN
            l_buf := ' case.';
         ELSE
            l_buf := ' cases.';
         END IF;

         l_r_audit.cmt := 'Slot: ' || i_pick_loc ||
            '  Item: ' || i_prod_id ||
            '  Pick ' || TO_CHAR(i_no_cases) || l_buf;
         l_r_audit.detail_level := ct_detail_level_1;
         insert_audit_rec(l_r_audit);
      END IF;

      IF (i_no_splits > 0) THEN
         l_r_audit.operation    := 'PIK';
         l_r_audit.tmu          := i_tmu_no_split;
         l_r_audit.time         := i_tmu_no_split / 1667;  -- Time in minutes
         l_r_audit.frequency    := i_no_splits;

         IF (i_no_splits = 1) THEN
            l_buf := ' split.';
         ELSE
            l_buf := ' splits.';
         END IF;

         l_r_audit.cmt := 'Slot: ' || i_pick_loc ||
            '  Item: ' || i_prod_id ||
            '  Pick ' || TO_CHAR(i_no_splits) || l_buf;
         l_r_audit.detail_level := ct_detail_level_1;
         insert_audit_rec(l_r_audit);
      END IF;

   -- Errors won't stop processing.
   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name || 'i_pick_loc[' || i_pick_loc || ']' ||
            '  i_no_cases[' || TO_CHAR(i_no_cases) || ']' ||
            '  i_no_splits[' || TO_CHAR(i_no_splits) || ']' ||
            '  i_tmu_no_case[' || TO_CHAR(i_tmu_no_case) || ']' ||
            '  i_tmu_no_split[' || TO_CHAR(i_tmu_no_split) || ']';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                        l_message || '  This will not stop processing.',
                        SQLCODE, SQLERRM);
   END ds_audit_pick_time;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    ds_audit_pickup_object
   --
   -- Description:
   --    This procedure writes the time to pickup a pickup object to the
   --    audit table.  Used to audit discrete selection.
   --
   -- Parameters:
   --    i_pickup_object      - The object to pickup.
   --    i_pickup_point       - Where to pickup the object.
   --    i_tmu                - The TMU assiged to the pickup object.
   --    i_qty                - The qty to apply.
   --
   -- Exceptions raised:
   --    None.  An error will not stop processing but an aplog message will
   --    be written.
   --
   -- Called by:
   --    pl_lm_ds.get_pickup_time
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    06/28/04 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE ds_audit_pickup_object
                    (i_pickup_object IN ds_pickup_object.pickup_object%TYPE,
                     i_pickup_point  IN ds_pickup_point.pickup_point%TYPE,
                     i_tmu           IN PLS_INTEGER,
                     i_qty           IN PLS_INTEGER)
   IS
      l_message       VARCHAR2(256);   -- Message buffer
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.ds_audit_pickup_object';

      l_buf           VARCHAR2(40);    -- Work area
      l_r_audit       t_audit_rec;

   BEGIN

      -- Assign values from globals.
      l_r_audit.batch_no   := pl_lma.g_batch_no;
      l_r_audit.user_id    := pl_lma.g_user_id;
      l_r_audit.equip_id   := pl_lma.g_equip_rec.equip_id;
      l_r_audit.audit_func := pl_lma.g_audit_func;

      l_r_audit.operation    := 'PIK';
      l_r_audit.tmu          := i_tmu;
      l_r_audit.time         := i_tmu / 1667;  -- Time in minutes
      l_r_audit.frequency    := i_qty;

      l_r_audit.cmt := 'Pickup ' || i_pickup_object || ' at ' ||
            i_pickup_point || '.';
      l_r_audit.detail_level := ct_detail_level_1;
      insert_audit_rec(l_r_audit);

   -- Errors won't stop processing.
   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name ||
            '  i_pickup_object[' || i_pickup_object || ']' ||
            '  i_pickup_point[' || i_pickup_point || ']' ||
            '  i_tmu[' || TO_CHAR(i_tmu) || ']' ||
            '  i_qty[' || TO_CHAR(i_qty) || ']';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                        l_message || '  This will not stop processing.',
                        SQLCODE, SQLERRM);

   END ds_audit_pickup_object;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_audit_batch_time
   --
   -- Description:
   --    This function calculates the time in minutes to complete a batch
   --    as determined from the audit information.
   --
   -- Parameters:
   --    i_batch_no     - Labor mgmt batch number.
   --
   -- Return Value:
   --    Batch time in minutes.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error     - Got an oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/13/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   FUNCTION f_get_audit_batch_time(i_batch_no IN arch_batch.batch_no%TYPE)
   RETURN NUMBER IS
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.get_audit_batch_time';

      l_batch_time     NUMBER;

      CURSOR c_batch_time(cp_batch_no IN arch_batch.batch_no%TYPE) IS
         SELECT SUM(total_time)
           FROM v_la1ra
          WHERE batch_no = cp_batch_no;

   BEGIN

      l_message_param := l_object_name || '(i_batch_no[' || i_batch_no || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_batch_time(i_batch_no);
      FETCH c_batch_time into l_batch_time;
      CLOSE c_batch_time;

      RETURN(l_batch_time);

   EXCEPTION
      WHEN OTHERS THEN
         -- This stops processing.
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_message_param);

   END f_get_audit_batch_time;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_audit_func
   --
   -- Description:
   --    This function determines what audit function a labor mgmt batch
   --    belongs to.  This is useful to know because table AUDIT_DETAIL_LEVEL
   --    specifies audit levels by audit function.
   --
   --    03/22/02 prpbcb
   --    What could be done in the future to keep from hardcoding values
   --    is to create a table that has the batch prefix, batch type and
   --    audit function.
   --    The pl_lmc.get_batch_type procedure could use the table too.
   --    Records could look like this:
   --       Prefix     Batch Type    Audit Function
   --       ------     ----------    --------------
   --         I            I
   --         S            S             DS
   --         FP           FP            FK
   --         FR           FR            FK
   --   The prefix and batch type could always be the same ???
   --
   -- Parameters:
   --    i_batch_no     - Labor mgmt batch number.
   --
   -- Return Value:
   --    The audit function for the batch.
   --    If unable to determine the audit function then an aplog
   --    message is written and NULL is returned.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Got an oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/22/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   FUNCTION f_get_audit_func(i_batch_no IN arch_batch.batch_no%TYPE)
   RETURN VARCHAR2 IS
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.get_audit_func';

      l_audit_func  audit_detail_level.audit_func%TYPE;
      l_batch_type  VARCHAR2(10);  -- Batch type--selection, loader, ...
      l_key_value   VARCHAR2(30);  -- This is the value from the table(s)
                                   -- initially used to create the labor mgmt
                                   -- batch and is usually part of the labor
                                   -- mgmt batch number.
   BEGIN

      l_message_param := l_object_name || '(i_batch_no[' || i_batch_no || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Find out the type of batch and the key value.  The key value is
      -- not used.
      pl_lmc.get_batch_type(i_batch_no, l_batch_type, l_key_value);

      IF (l_batch_type = pl_lmc.ct_selection) THEN
         -- Have a selection batch.
         l_audit_func := pl_lma.ct_audit_func_ds;
      ELSIF (SUBSTR(l_batch_type, 1, 1) IN ('F', 'H')) THEN
         -- Have a forklift batch.
         l_audit_func := pl_lma.ct_audit_func_fk;
      ELSE
         l_audit_func := NULL;
      END IF;

      IF (l_audit_func = NULL) THEN
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
             l_message_param || ' Unable to determine the audit function' ||
             ' for this batch.  Using NULL.',
             pl_exc.ct_data_error, NULL);
      END IF;

      RETURN(l_audit_func);

   EXCEPTION
      WHEN OTHERS THEN
         -- This stops processing.
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_message_param);

   END f_get_audit_func;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_is_batch_audited
   --
   -- Description:
   --    This function determines if a batch has been audited which is
   --    determined by checking the labor audit table for any records for
   --    the batch.  If at least one record found then the batch has
   --    been audited.
   --
   -- Parameters:
   --    i_batch_no     - Labor mgmt batch number.
   --
   -- Return Value:
   --    TRUE   - The batch has been audited.
   --    FALSE  - The batch has not been audited.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error     - Got an oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/07/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   FUNCTION f_is_batch_audited(i_batch_no IN arch_batch.batch_no%TYPE)
   RETURN BOOLEAN IS
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_is_batch_audited';

      l_dummy          VARCHAR2(1);      -- Work area
      l_return_value   BOOLEAN;

      CURSOR c_audit IS
         SELECT 'x'
           FROM forklift_audit
          WHERE batch_no = i_batch_no;

   BEGIN

      l_message_param := l_object_name || '(i_batch_no[' || i_batch_no || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_audit;
      FETCH c_audit INTO l_dummy;

      IF (c_audit%FOUND) THEN
         l_return_value := TRUE;
      ELSE
         l_return_value := FALSE;
      END IF;

      CLOSE c_audit;

      RETURN(l_return_value);

   EXCEPTION
      WHEN OTHERS THEN
         -- This stops processing.
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_message_param);

   END f_is_batch_audited;


   ----------------------------------------------------------------------------
   -- Procedure:
   --    get_audit_data
   --
   -- Description:
   --    This procedure determines:
   --       - If a labor mgmt batch is available to be audited.  The batch
   --         must exist and have a status of F, A or C.
   --       - If the information required to audit the batch still exists.
   --       - Retrieves the information necessary to audit the batch.
   --
   --    (This procedure turned into a multiple operation procedure.  It
   --     may be possible to break the functionality into separate
   --     procedures/functions but then the same data may end up being
   --     selected multiple times.)
   --
   --    Some types of batches have to be audited when the batch is
   --    completed such as forklift and haul batches since the batch time
   --    depends on the current inventory and the source location which
   --    are not known until the batch is completed.  Other batches such as
   --    normal selection batches can be audited at batch creation time or
   --    after the batch is completed since all information is known when
   --    the batch is created and does not change.
   --
   --    Be aware that values can be changed so that later if a audit is
   --    run on a batch the goal/target time of the audit does not batch
   --    the batch's goal/target time.  This can happen for a normal selection
   --    batch if the pickup points are changed or if the case or split tmu
   --    for a slot is changed.
   --
   -- Parameters:
   --    i_batch_no                  - Labor mgmt batch number.
   --    o_batch_can_be_audited_bln  - Designates if the batch can be audited.
   --    o_key_value                 - This is the value from the table(s)
   --                                  initially used to create the labor mgmt
   --                                  batch and is usually part of the labor
   --                                  mgmt batch number.
   --                                  Example:  Labor batch: S42344
   --                                     This is a selection batch with
   --                                     42344 being the floats.batch_no.
   --    o_user_id                   - User assigned to the batch.  If the
   --                                  batch status is F then the user id will
   --                                  be null.
   --    o_msg                       - Message stating why the batch cannot
   --                                  be audited if o_batch_can_be_audited_bln
   --                                  is FALSE.
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error         - Have a batch type not handled by
   --                                  this procedure.
   --    pl_exc.e_database_error     - Got an oracle error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ----------------------------------------------------
   --    03/11/02 prpbcb   Created.
   --
   ----------------------------------------------------------------------------
   PROCEDURE get_audit_data
                   (i_batch_no                  IN  arch_batch.batch_no%TYPE,
                    o_batch_can_be_audited_bln  OUT BOOLEAN,
                    o_batch_type                OUT VARCHAR2,
                    o_key_value                 OUT VARCHAR2,
                    o_user_id                   OUT VARCHAR2,
                    o_msg                       OUT VARCHAR2)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_audit_data';

      l_batch_type     VARCHAR2(10);  -- Batch type--selection,
                                                 -- loader, ...

      l_key_value      VARCHAR2(30); -- This is the value from the table(s)
                                     -- initially used to create the labor mgmt
                                     -- batch and is usually part of the labor
                                     -- mgmt batch number.

      l_pallet_pull    floats.pallet_pull%TYPE;  -- Pull type for a selection
                                                 -- batch.
      l_status         arch_batch.status%TYPE;   -- Batch status
      l_user_id        arch_batch.user_id%TYPE;  -- Batch user id

      e_bad_status            EXCEPTION;  -- Batch has a status not allowed
                                          -- for auditing.
      e_unhandled_batch_type  EXCEPTION;  -- Have a batch type not
                                          -- handled in this procedure.

      -- This cursor gets batch information.
      CURSOR c_batch(cp_batch_no  IN arch_batch.batch_no%TYPE) IS
         SELECT user_id, status
           FROM batch
          WHERE batch_no = cp_batch_no;

      -- This cursor selects the pallet pull type and is used when the
      -- labor batch is a selection batch.
      CURSOR c_selection(cp_floats_batch_no IN floats.batch_no%TYPE) IS
         SELECT pallet_pull
           FROM floats
          WHERE batch_no = cp_floats_batch_no;

   BEGIN

      l_message_param := l_object_name ||
         '(i_batch_no[' || i_batch_no || ']' ||
         ',o_batch_can_be_audited_bln,o_batch_type,o_key_value,o_user_id' ||
         ',o_msg)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Initialization
      l_key_value := NULL;
      o_msg := NULL;

      -- Check the batch status.
      OPEN c_batch(i_batch_no);
      FETCH c_batch INTO o_user_id, l_status;
      IF (c_batch%NOTFOUND) THEN
         -- Can't find the batch.
         CLOSE c_batch;
         RAISE pl_exc.e_no_lm_batch_found;
      END IF;
      CLOSE c_batch;

      -- The batch has to have a certain status in order for it to be audited.
      IF (l_status NOT IN ('F', 'A', 'C')) THEN
         RAISE e_bad_status;
      END IF;

      -- Find out the type of batch and the key value.
      pl_lmc.get_batch_type(i_batch_no, l_batch_type, l_key_value);

      IF (l_batch_type = pl_lmc.ct_selection) THEN
         -- Have a selection batch.
         BEGIN

            -- Dynamic selection needs to be active.
            --
            -- 05/15/02 prpbcb  Removed the restriction that dynamic
            -- selection needs to be active.  This allows companies to run the
            -- batch audit report in preparing for dynamic selection.
            -- I put 1=1 in the if statement to remove the restriction.
            --
            IF (1=1 OR
                pl_common.f_get_syspar('DS_DYNAMIC_SELECTION', 'N') = 'Y') THEN
               -- The order needs to exist.  If the route has been purged
               -- then the batch cannot be audited.
               -- The key value for a selection batch should always
               -- be a number because it is the floats batch_no.
               OPEN c_selection(TO_NUMBER(l_key_value));
               FETCH c_selection INTO l_pallet_pull;

               IF (c_selection%FOUND) THEN
                  -- Route information exist.  Verify the batch is a normal
                  -- selection batch.
                  IF (l_pallet_pull = 'N') THEN
                     o_batch_can_be_audited_bln := TRUE;
                  ELSE
                     o_batch_can_be_audited_bln := FALSE;
                     o_msg := f_build_cannot_be_audited_msg
                                 (i_what_happened => ct_bad_pallet_pull,
                                  i_batch_no => i_batch_no,
                                  i_pallet_pull => l_pallet_pull);
                  END IF;
               ELSE
                  -- Route purged.  The batch cannot be audited.
                  o_batch_can_be_audited_bln := FALSE;
                  o_msg := f_build_cannot_be_audited_msg
                                 (i_what_happened => ct_route_purged,
                                  i_batch_no => i_batch_no);
               END IF;

               CLOSE c_selection;
            ELSE
              o_batch_can_be_audited_bln := FALSE;
              o_msg := f_build_cannot_be_audited_msg
                                 (i_what_happened => ct_ds_not_active,
                                  i_batch_no => i_batch_no);
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                  l_message_param || '  Error when processing' ||
                  ' selection batch.',
                  SQLCODE, SQLERRM);
              RAISE;
         END;

      ELSIF (SUBSTR(l_batch_type, 1, 1) IN ('F', 'H')) THEN
         -- Have a forklift batch(hardcoded the F and H; I know, I know).
         -- It has to be audited when the batch is completed which is
         -- controlled by the FORKLIFT_AUDIT syspar.
         o_batch_can_be_audited_bln := FALSE;
         o_msg := f_build_cannot_be_audited_msg
                                 (i_what_happened => ct_forklift_batch,
                                  i_batch_no => i_batch_no);

      ELSIF (l_batch_type = pl_lmc.ct_indirect) THEN
         o_batch_can_be_audited_bln := FALSE;
         o_msg := f_build_cannot_be_audited_msg
                                 (i_what_happened => ct_indirect_batch,
                                  i_batch_no => i_batch_no);

      ELSIF (l_batch_type = pl_lmc.ct_loader) THEN
         o_batch_can_be_audited_bln := FALSE;
         o_msg := f_build_cannot_be_audited_msg
                                 (i_what_happened => ct_loader_batch,
                                  i_batch_no => i_batch_no);

      ELSE
         -- Have an unhandled batch type.
         RAISE e_unhandled_batch_type;
      END IF;

      o_key_value := l_key_value;
      o_batch_type := l_batch_type;

   EXCEPTION
      WHEN pl_exc.e_no_lm_batch_found THEN
         o_batch_can_be_audited_bln := FALSE;
         o_msg := 'Batch ' || i_batch_no || ' not found.' ||
                  '  It is not a current batch.';

      WHEN e_bad_status THEN
         o_batch_can_be_audited_bln := FALSE;
         o_msg := f_build_cannot_be_audited_msg
                                 (i_what_happened => ct_bad_status,
                                  i_batch_no => i_batch_no,
                                  i_status => l_status);

      WHEN e_unhandled_batch_type THEN
         l_message := l_message_param ||
            '  Unhandled batch type[' || l_batch_type || ']';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(SQLCODE, l_object_name || ': ' || SQLERRM);
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END get_audit_data;


   ----------------------------------------------------------------------------
   -- Procedure:
   --    audit_labor_batch
   --
   -- Description:
   --    This procedure audits a labor mgmt batch.  Auditing a batch consists
   --    of creating audit records that detail how the goal/target time
   --    was calculated.
   --
   --    Not all batches can be audited in this manner and the information
   --    still needs to be in swms to create the audit records.  Forklift
   --    batches can only be audited when the batch is completed because it
   --    depends on the existing pallets in the source and destination
   --    locations and the destination location is not known until the
   --    batch is completed.  For dynamic selection batches the order
   --    processing information needs to exist.  If the orders have been
   --    purged then a dynamic selection batch cannot be audited.
   --
   --    Be aware that values can be changed so that later if a audit is
   --    run on a batch the goal/target time of the audit does not batch
   --    the batch's goal/target time.  This can happen for a normal selection
   --    batch if the pickup points are changed or if the case or split tmu
   --    for a slot is changed.
   --
   -- Parameters:
   --    i_batch_no               - Labor management batch number to audit.
   --    o_audit_successful_bln   - Designates if the batch was audited
   --                               successful.  The calling program needs
   --                               to check this.
   --    o_msg                    - If the batch could not be audited then
   --                               the message stating why the batch was
   --                               not audited.  The calling program
   --                               needs to set the length to at
   --                               least 512 characters ??.  Depending
   --                               on what happens this procedure could
   --                               put SQLERRM in o_msg.
   --
   -- Called by:
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error     - Got an oracle error.
   --    (Unless something strange happens any error will be trapped,
   --    o_audit_successful_bln set to FALSE and a message put in o_msg.)
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ----------------------------------------------------
   --    03/13/02 prpbcb   Created.
   ----------------------------------------------------------------------------
   PROCEDURE audit_labor_batch
                   (i_batch_no              IN  arch_batch.batch_no%TYPE,
                    o_audit_successful_bln  OUT BOOLEAN,
                    o_msg                   OUT VARCHAR2)
   IS
      l_message        VARCHAR2(128);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.audit_labor_batch';

      l_batch_can_be_audited_bln BOOLEAN; -- Designates if the batch can be
                                          -- audited.
      l_batch_type     VARCHAR2(10); -- Batch type--selection, loader,...
      l_error_detected_bln  BOOLEAN;
      l_key_value      VARCHAR2(30); -- This is the value from the table(s)
                                     -- initially used to create the labor mgmt
                                     -- batch and is usually part of the labor
                                     -- mgmt batch number.
      l_msg            VARCHAR2(256);    -- Message buffer
      l_user_id        arch_batch.user_id%TYPE;  -- Batch user id

   BEGIN

      l_message_param := l_object_name ||
         '(i_batch_no[' || i_batch_no || '],o_audit_successful_bln,o_msg)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Start a new block so errors can be trapped.
      BEGIN
         IF (NOT f_is_batch_audited(i_batch_no)) THEN
            -- Determine if the batch can be audited and get the information
            -- necessary to audit the batch.
            get_audit_data(i_batch_no, l_batch_can_be_audited_bln,
                           l_batch_type, l_key_value, l_user_id, l_msg);

            -- Audit the batch if allowed.
            IF (l_batch_can_be_audited_bln) THEN

               pl_lma.set_audit_on;  -- Turn on auditing.

               -- Populate the globals used by the audit routines.
               -- l_user_id will be the person assigned to the batch or
               -- null if a future batch.
               pl_lma.set_user_id(l_user_id);

               IF (l_batch_type = pl_lmc.ct_selection) THEN

                  -- pl_lma.g_audit_func := ct_audit_func_ds;
                  pl_lma.set_audit_func(ct_audit_func_ds);

                  pl_lm_sel.create_selection_batches
                                (i_how_generated => 'b',
                                 i_generation_key => l_key_value,
                                 i_audit_only_bln => TRUE,
                                 o_error_detected_bln => l_error_detected_bln);

                  IF (l_error_detected_bln) THEN
                     o_audit_successful_bln := FALSE;
                     o_msg := 'An error occurred while auditing batch ' ||
                               i_batch_no || '.  Check the log.';
                  ELSE
                     o_audit_successful_bln := TRUE;
                  END IF;
               ELSE
                  l_message := l_message_param || '  Unhandled batch type[' ||
                               l_batch_type || ']';
                  pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                                 pl_exc.ct_data_error, NULL);
                  o_audit_successful_bln := FALSE;
                  o_msg := l_message;
               END IF;
            ELSE
               -- The batch cannot be audited.
               o_audit_successful_bln := FALSE;
               o_msg := l_msg;
            END IF;
         ELSE
            o_audit_successful_bln := FALSE;
            o_msg := 'Batch ' || i_batch_no || ' has already been audited.';
         END IF;

      EXCEPTION
         WHEN OTHERS THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
         o_audit_successful_bln := FALSE;
         o_msg := l_object_name || ': ' || SQLERRM;
      END;

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END audit_labor_batch;

END pl_lma;   -- end package body
/

