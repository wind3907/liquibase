CREATE OR REPLACE PACKAGE swms.pl_xdock_op
AS
-----------------------------------------------------------------------------
-- Package Name:
--    pl_xdock_op
--
-- Description:
--    This package has the procedure/functions, etc for R1 XDOCK order
--    generation.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    07/14/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--                     
--                      Created.
--    08/19/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--
--                      Modified procedure "update_floats".
--                      For Site 1 floats assign parent_pallet_id.
--                      The parent_pallet_id will be unique across all OpCos.
--                      
--    09/01/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--
--                      Populate floats.xdock_pallet_id
--
--                      README   README   README   README   README   README
--                      README   README   README   README   README   README
--                      Procedure "pl_replenishments.insert_Replenishment" was changed to populate
--                      replenlst:
--                          - site_from
--                          - site_to
--                          - xdock_pallet_id
--                      from floats site_from, site_to and xdock_pallet_id.
--                      The problem is these floats columns have yet to be assigned a value.
--                      So what I did is change procedure "pl_xdock_op.update_floats" to update replenlst.
--
--    09/15/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3663_OP_Site_2_Merge_float_ordcw_sent_from_Site_1
--
--                      Procedure "update_floats" was updating non cross dock floats.
--                      Fixed the where clause.
--
--    10/25/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3752_Site_1_put_site_2_truck_no_stop_no_on_RF_bulk_pull_label
--
--                      Columns site_to_route_no and site_to_truck_no were added to tables FLOATS and REPLENLST.
--                      Changed procedure "update_floats" to update these columns.
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
--    get_ordd_seq (public)
--
-- Description:
--    This function returns the value to use for ORDD.SEQ.
---------------------------------------------------------------------------
FUNCTION get_ordd_seq
   (
      i_cross_dock_type  IN ordm.cross_dock_type%TYPE  DEFAULT NULL,
      i_opco_no          IN VARCHAR2                   DEFAULT NULL
   )
RETURN PLS_INTEGER;


---------------------------------------------------------------------------
-- Procedure:
--    update_floats (public)
--
-- Description:
--    This procedure updates relevant columns for Xdock floats.
--    It is far less risky to have a separate update of FLOATS then try to populate
--    these columns when the float is created.
---------------------------------------------------------------------------
PROCEDURE update_floats
   (
      i_route_batch_no  IN  route.route_batch_no%TYPE    DEFAULT NULL,
      i_route_no        IN  route.route_no%TYPE          DEFAULT NULL
   );

END pl_xdock_op;
/



CREATE OR REPLACE PACKAGE BODY swms.pl_xdock_op
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

ct_application_function CONSTANT  VARCHAR2(30) := 'ORDER PROCESSING';


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
--    get_ordd_seq (public)
--
-- Description:
--    This function returns the value to use for ORDD.SEQ.
--
--    The XDOCK functionality affects the value used for ORDD.SEQ.
--    For 'S' cross dock orders the ORDD.SEQ needs to be unique across all OpCos
--    because the ORDD info is sent from Site 1 to Site 2.
--    To get a unique ORDD.SEQ for the 'S' cross dock orders a new sequence named "xdock_ordd_seq" created
--    with a starting value of 10000, minvalue of 10000 and maxvalue of 99999.
--    This new sequence is used in the bulding of the ordd.seq fo the 'S' cross dock orders.
--    The format fo the 'S' cross dock orders ordd.seq will be:
--       XDOCK_ORDD_SEQ.NEXTVAL || TO_NUMBER(LPAD(TRIM(opco#), 3, '0'))  -- opco# is the site 1 opco number
--
--    At Site 2 we have to be sure the ORDD.SEQ for regular orders does not duplicate
--    with one sent or could be sent from a Site 1 Opco.  This means at Site 2 we cannot have a ORDD.SEQ that
--    ends in an OpCo#.
--
--    Also at Site 2 we have to be sure the OORD.SEQ does not duplicate with a regular
--    order and a cross dock order Site 2 is sending to Site 1 (remember Site 2 can also be a Site 1).
--    Basically this means at Site 2 we cannot have a ORDD.SEQ that ends in an OpCo#
--    that is active on Xdock.
--
--    Example of a assuring a unique ordd.seq
--       Site 1 OpCos are 002 and 037
--       Site 2 OpCo is 016
--       Site 2 is going to get two cross dock orders from 002 and 037.
--       Site 2 is sending one cross dock to some OpCo (Site 2 can also be a Site 1)
--          ordd.seq from Site 1 Opco 002    ordd.seq from Site 1 Opco 027     ordd.seq Site 2 is sending out
--          ----------------------------     ------------------------------    --------------------------------
--          80001002                         80001027                          80001016
--          80002002                         80002027
--          80003002
--          80004002
--
--      So for regulars orders at Site 2 these values are not available to use for the ordd.seq
--      as they are used by the above cross dock orders.
--          80001002, 80001027, 80001016
--          80002002, 80002027
--          80003002
--          80004002
--
--    Running a test calling "get_ordd_seq" with no parameters getting 500,000 numbers starting
--    at 10000000 resulted in a range of:
--       10,000,000 -> 10,557,471
--    So we skipped over 57,471 values which is 11.5 percent.  Skipping this many values should not
--    cause any issues.
--
--    Changes made to the following programs to call this function instead of
--    selecting directly from sequence "ordd_seq".
--       - OP reader program - swmsorreader.pc
--       - pl_crt_order_proc.sql
--       - pl_cross_dock_order_processing.sql   package not used, did not change
--       - pl_matrix_repl.sql                   matrix-not used anymore, did not change
--       - pl_miniload_processing.sql
--       - mx1iir.txt                           matrix-not used anymore, did not change
--
--    FYI - Check of the execution time to get the ord.seq.
--    Selecting 2000 values in a pl/sql loop
--       Command                                               Time in Seconds
--       --------------------------------------------------------------------
--       Selecting directly from sequence ordd_.seq               .06
--       pl_xdock_op.get_ordd_seq                                 .17
--       pl_xdock_op.get_ordd_seq(i_cross_dock_type => 'S')       .19
--    So performance looks fine when calling the function.
--
--
-- Parameters:
--    i_cross_dock_type - The order cross dock type.  Optional but needs to be populated
--                        for the 'S' cross dock orders.
--    i_opco_no         - Current Opco.
--                        Optional but if populated then it is used instead of
--                        calling function pl_common.get_company_no() to get the
--                        current opco nmber.  The intent of the parameter
--                        is if the calling program is caling this function multiple times
--                        the calling program would call pl_common.get_company_no() once
--                        and pass the opco number to this function to save a
--                        little execution time.
--
-- Return Values:
--    ordd seq
--
-- Called By:
--
-- Exceptions Raised:
--    pl_exc.e_database_error  - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/14/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--                      Created.
--
---------------------------------------------------------------------------
FUNCTION get_ordd_seq
   (
      i_cross_dock_type  IN ordm.cross_dock_type%TYPE  DEFAULT NULL,
      i_opco_no          IN VARCHAR2                   DEFAULT NULL
   )
RETURN PLS_INTEGER
IS
   l_object_name   VARCHAR2(30) := 'get_ordd_seq';

   l_ordd_seq    PLS_INTEGER;           -- value to use for ordd.seq
   l_opco_no     VARCHAR2(10 CHAR);
   l_count       PLS_INTEGER;

   --
   -- See if XDOCK is active at the OpCo.
   --
   l_syspar_enable_xdock      sys_config.config_flag_val%TYPE  := pl_common.f_get_syspar('ENABLE_OPCO_TO_OPCO_XDOCK', 'N');
BEGIN
   IF (l_syspar_enable_xdock = 'N') THEN
      --
      -- XDOCK is not active at the OpCo.  Use the ORDD_SEQ as is.
      --
      l_ordd_seq := ordd_seq.NEXTVAL;
   ELSE
      --
      -- ***************************************
      -- ***** XDOCK is active at the OpCo *****
      -- ***************************************
      --
      -- The value for ordd.seq depends on the cross dock type of the order
      -- and the other OpCos active on XDOCK.
      --
      -- If the order cross dock type is 'S' (the fulfillment site) then the ordd.seq needs to be
      -- unique across all SWMS OpCos.
      --
      -- Get the current opco number.
      --
      IF (i_opco_no IS NOT NULL) THEN
         l_opco_no := i_opco_no;                     -- The current opco number is passed as a parameter.  Use it.
      ELSE
         l_opco_no := pl_common.get_company_no();    -- Get the current opco number.
      END IF;

      l_opco_no := LPAD(l_opco_no, 3, '0');

      IF (i_cross_dock_type = 'S') THEN
         --
         -- 'S' cross dock order.
         -- Build the value for ordd.seq for the 'S' cross dock order.  Format is 99999<current opco number>
         --
         --

         l_ordd_seq := TO_NUMBER(TO_CHAR(XDOCK_ORDD_SEQ.NEXTVAL) || LPAD(TRIM(l_opco_no), 3, '0'));
      ELSE
         --
         -- Not a 'S' cross dock order.
         --
         -- At Site 2 we have to be sure the ORDD.SEQ for regular orders does not duplicate
         -- with one sent or could be sent from a Site 1 OpCo.
         -- At Site 2 we have to be sure the OORD.SEQ does not duplicate with a regular
         -- order and a cross dock order Site 2 is sending to Site 1 (remember Site 2 can also be a Site 1).
         -- Basically this means at Site 2 we cannot have a ORDD.SEQ that ends in an OpCo#.
         -- View V_OPCOS is a view of table STS_OPCO_DCID which has all the OpCo numbers.
         -- This function use view V_OPCOS.
         -- In this new table the OpCo number should be left padded with zeros to 3 places
         -- but the sql stmt will do it.
         --
         WHILE TRUE LOOP
            l_ordd_seq := ordd_seq.NEXTVAL;

            SELECT COUNT(*) INTO l_count
              FROM v_opcos o
             WHERE LPAD(o.opco_no, 3, '0') = (TRIM(TO_CHAR(SUBSTR(l_ordd_seq, -3, 3))));

            IF (l_count = 0)
               THEN EXIT;
            END IF;
         END LOOP;
      END IF;
   END IF;  -- end IF (l_syspar_enable_xdock = 'N') THEN

   RETURN l_ordd_seq;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it and raise an error.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => 'l_object_name',
                i_msg_text         => 'Error occurred  i_cross_dock_type[' || i_cross_dock_type || ']'
                                          || '  i_opco_no[' || i_opco_no || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
END get_ordd_seq;


---------------------------------------------------------------------------
-- Procedure:
--    update_floats (public)
--
-- Description:
--    This procedure updates relevant columns for Xdock floats.
--    It is far less risky to have a separate of FLOATS then try do populate
--    these columns when the float is created.
--
--    Columms udated:
--       - FLOATS.SITE_FROM
--       - FLOATS.SITE_TO
--       - FLOATS.CROSS_DOCK_TYPE
--       - FLOATS.PARENT_PALLET_ID
--       - FLOATS.XDOCK_PALLET_ID
--       - FLOATS.SITE_TO_ROUTE_NO
--       - FLOATS.SITE_TO_TRUCK_NO
--       - FLOATS.XDOCK_PALLET_ID
--       - REPLENLST.SITE_FROM
--       - REPLENLST.SITE_TO
--       - REPLENLST.XDOCK_PALLET_ID
--       - REPLENLST.SITE_TO_ROUTE_NO
--       - REPLENLST.SITE_TO_TRUCK_NO
--
-- Parameters:
--    NOTE: One and only one parameter i_route_batch_no and i_route_no can
--          be populated.
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--
-- Called by:
--    pl_order_processing.post_float_processing
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/20/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--                      Created.
--
--    09/01/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--
--                      Assign floats.parent_pallet and  floats.xdock_pallet_id for 'S' cross dock ordes.
--
--                      README   README   README   README   README   README
--                      README   README   README   README   README   README
--                      Procedure "pl_replenishments.insert_Replenishment" was changed to populate
--                      replenlst site_from, site_to and xdock_pallet_id from
--                      floats site_from, site_to and xdock_pallet_id.
--                      The problem is these floats columns have yet to be assigned a value.
--                      So what I did is change this procedure to update replenlst.
--
--    09/15/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3663_OP_Site_2_Merge_float_ordcw_sent_from_Site_1
--
--                      Procedure updating non cross dock floats.
--                      Fixed the where clause.
--
--    10/25/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3752_Site_1_put_site_2_truck_no_stop_no_on_RF_bulk_pull_label
--
--                      Columns site_to_route_no and site_to_truck_no were added to tables FLOATS and REPLENLST.
--                      Changed procedure to update these columns.
---------------------------------------------------------------------------
PROCEDURE update_floats
   (
      i_route_batch_no  IN  route.route_batch_no%TYPE    DEFAULT NULL,
      i_route_no        IN  route.route_no%TYPE          DEFAULT NULL
   )
IS
   l_object_name   VARCHAR2(30)   := 'update_floats';
   l_message       VARCHAR2(512);                     -- Work area

   l_xdock_pallet_id   floats.pallet_id%TYPE;      -- Unique pallet id assigned to the cross dock pallet.
                                                   -- It is unique across all OpCos.
   l_update_count      PLS_INTEGER;                -- Work area


   e_parameter_bad_combination    EXCEPTION;  -- Bad combination of parameters.

BEGIN
   --
   -- Log starting procedure
   --
   l_message := 'Starting procedure' || ' (i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
         || 'i_route_no[' || i_route_no || '])'
         || '  This procedure updates relevant columns in FLOATS table for Xdock floats including floats.cross_dock_type,'
         || ' site_from,site_to,parent_pallet_id,xdock_pallet_id,site_to_route_no,site_to_truck_no';

   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Check the parameters.
   -- One and only one of i_route_batch_no and i_route_no should be populated.
   --
   IF (   i_route_batch_no IS NULL     AND i_route_no IS NOT NULL
       OR i_route_batch_no IS NOT NULL AND i_route_no IS NULL)
   THEN
      NULL;  -- Parameter check OK.
   ELSE
      RAISE e_parameter_bad_combination;
   END IF;

   --
   -- Update floats cross_dock_type, site_from, site_to for floats on aroute with a xdock order.
   --
   UPDATE floats f
      SET (f.cross_dock_type, f.site_from, f.site_to, f.site_to_route_no, f.site_to_truck_no) =
             (SELECT
                     m.cross_dock_type,
                     m.site_from,
                     m.site_to,
                     m.site_to_route_no,
                     m.site_to_truck_no
                FROM ordm m, float_detail fd
               WHERE m.route_no        = f.route_no
                 AND fd.float_no       = f.float_no
                 AND fd.order_id       = m.order_id
                 AND m.cross_dock_type IN ('S', 'X')
                 AND ROWNUM = 1)    -- ordm can have multiple records that match.  They all should
                                    -- have the same cross_dock_type, site_from and site_to.
    WHERE f.route_no IN
          (SELECT r.route_no
             FROM route r
            WHERE (r.route_no      = i_route_no
               OR r.route_batch_no = i_route_batch_no))
      AND EXISTS
           (SELECT 'x'
              FROM ordm m2, float_detail fd2
             WHERE m2.route_no        = f.route_no
               AND fd2.float_no       = f.float_no
               AND fd2.order_id       = m2.order_id
               AND m2.cross_dock_type IN ('S', 'X'))
      --
      AND f.pallet_pull <> 'R'     -- Exclude demand replenishments as they are not applicable 
      --
      AND (   f.cross_dock_type  IS NULL    -- Not already updated
           OR f.site_from        IS NULL    -- Not already updated
           OR f.site_to          IS NULL);  -- Not already updated

   --
   -- Log update count.
   --
   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'After update of floats cdt, site_from, site_no.  Number of records updated: ' || SQL%ROWCOUNT,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   --
   -- At Site 1.
   -- Update FLOATS parent_pallet_id and xdock_pallet_id for floats that have a 'S' xdock order on it.
   -- Note that a float should have all 'S' xdock orders or no 'S' xdock orders.
   -- Also udpate REPLENLST site_from, site_to and xdock_pallet_id.
   -- 08/20/21 xxxxxxx  Need to change to call function in pl_xdock_common to get the parent LP.
   --
   l_update_count := 0;

   FOR r_floats IN (SELECT f.float_no,
                           f.site_from,
                           f.site_to,
                           f.site_to_route_no,
                           f.site_to_truck_no
                      FROM floats f
                     WHERE f.route_no IN
                                (SELECT r.route_no
                                   FROM route r
                                  WHERE (r.route_no      = i_route_no
                                     OR r.route_batch_no = i_route_batch_no))
                       AND EXISTS
                                 (SELECT 'x'
                                    FROM ordm m2
                                   WHERE m2.route_no        = f.route_no
                                     AND m2.cross_dock_type = 'S')
                       --
                       AND f.pallet_pull <> 'R'     -- Exclude demand replenishments as they are not applicable 
                       --
                       AND parent_pallet_id IS NULL              -- Not already assigned a value
                     ORDER BY
                           f.float_no)
   LOOP
      --
      -- Get unique LP to assign to the cross dock pallet.
      --
      l_xdock_pallet_id := LPAD(pl_common.get_company_no, 3, '0') || LPAD(pl_common.f_get_new_pallet_id, 15, '0');

      UPDATE floats f
         SET parent_pallet_id = l_xdock_pallet_id,
             xdock_pallet_id  = l_xdock_pallet_id
       WHERE f.float_no = r_floats.float_no;

      l_update_count := l_update_count + SQL%ROWCOUNT;

      --
      -- Update REPLENLST
      --
      UPDATE replenlst r
         SET r.site_from         = r_floats.site_from,
             r.site_to           = r_floats.site_to,
             r.xdock_pallet_id   = l_xdock_pallet_id,
             r.site_to_route_no  = r_floats.site_to_route_no,
             r.site_to_truck_no  = r_floats.site_to_truck_no
       WHERE r.float_no = r_floats.float_no
         AND r.type     = 'BLK';
   END LOOP;

   --
   -- Log update count.
   --  xxxxxxxx add to log messages to show tables updated.
   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'After update of floats parent_pallet_id, xdock_pallet_id for ''S'' cross dock pallets.'
                            || '  Number of records updated: ' || TO_CHAR(l_update_count),
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   --
   -- Log ending procedure
   --
   l_message := 'Ending procedure' || ' (i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
         || 'i_route_no[' || i_route_no || '])';

   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

EXCEPTION
   WHEN e_parameter_bad_combination THEN
      --
      -- One and only one of i_route_batch_no and i_route_no can be populated.
      --
      l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
                   || 'i_route_no[' || i_route_no || '])'
                   || '  One and only one of these two parameters can have a value.';

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);
   WHEN OTHERS THEN
      --
      -- Got an oracle error.
      --
      l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
                   || 'i_route_no[' || i_route_no || '])';

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
END update_floats;

END pl_xdock_op;
/

show errors


CREATE OR REPLACE PUBLIC SYNONYM pl_xdock_op FOR swms.pl_xdock_op;
GRANT EXECUTE ON swms.pl_xdock_op TO SWMS_USER;


