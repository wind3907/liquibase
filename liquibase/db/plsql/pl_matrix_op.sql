CREATE OR REPLACE PACKAGE swms.pl_matrix_op
AS
-----------------------------------------------------------------------------
-- Package Name:
--    pl_matrix_op   
--
-- Description:
--    Package for operations related to matrix order generation.
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    10/10/14 bben0556 Created.
--                      Symbotic project.
--                     
--    01/29/15 bben0556 Procedure "create_case_records()" not always creating
--                      records in MX_FLOAT_DETAIL_CASES for picks from the
--                      matrix when generating a route.  I found the picks
--                      came from inventory with a spur location.
--                      Changed the condition in cursor c_float_detail
--                      from
--              AND loc.slot_type IN ('MXC', 'MXF')
--                      to
--              AND loc.slot_type IN ('MXC', 'MXF')
--
--                      NOTE: We should add a flag column to the SLOT_TYPE
--                      table to control if we create or not create
--                      MX_FLOAT_DETAIL_CASES records instead of hardcoding
--                      the slot types.
--
--    10/10/14 bben0556 Symbotic project
--                      Add fd.seq_no to the order by in cursor c_float_detail
--                      in procedure "CREATE_CASE_RECORDS()".
--
--    06/04/15 bben0556 Symbotic project
--                      Assign matrix priority to normal selection batches.
--                      Created:
--                         - function num_batches_in_wave_sent_to_mx()
--                         - procedure assign_mx_priority()
--                         - procedure update_floats_mx_priority()
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
--
-- Description:
---------------------------------------------------------------------------
FUNCTION xxx
RETURN VARCHAR2;

---------------------------------------------------------------------------
-- Procedure:
--    create_case_records
--
-- Description:
--    The procedures creates a record for each case to pick on a route.
--
--    It is based on the FLOAT_DETAIL table qty allocated and the uom.
---------------------------------------------------------------------------
PROCEDURE create_case_records
         (i_route_batch_no  IN  route.route_batch_no%TYPE        DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE              DEFAULT NULL,
          i_create_what     IN  sys_config.config_flag_val%TYPE  DEFAULT NULL);

---------------------------------------------------------------------------
-- Function:
--    num_batches_in_wave_sent_to_mx
--
-- Description:
--    This functions counts the number of normal selection batches in a
--    wave that are sent/to be sent to the matrix.
---------------------------------------------------------------------------
FUNCTION num_batches_in_wave_sent_to_mx
             (i_route_batch_no      IN route.route_batch_no%TYPE)
RETURN PLS_INTEGER;

---------------------------------------------------------------------------
-- Procedure:
--    assign_mx_priority
--
-- Description:
--    This procedure assigns the matrix priority to the FLOATS record.
--    for each batch that is sent to the matrix.
--
--    The matrix priority is basically a sub-wave that Symbotic 
--    uses to process the batches within a wave.
--
--    Procedure "update_floats_mx_priority()" is called to do the update
--    of the floats table.
---------------------------------------------------------------------------
PROCEDURE assign_mx_priority
            (i_route_batch_no          IN route.route_batch_no%TYPE,
             i_num_of_priority_groups  IN PLS_INTEGER DEFAULT NULL);


END pl_matrix_op;
/


SHOW ERRORS


CREATE OR REPLACE PACKAGE BODY swms.pl_matrix_op
AS

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := $$PLSQL_UNIT;  -- Package name.
                                             -- Used in log messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.

--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function VARCHAR2(30) := 'ORDER GENERATION';


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
-- Procedure:
--    update_floats_mx_priority  (local procedure)
--
-- Description:
--    This procedure updates floats.mx_priority for a specified route batch
--    number(wave) and over a range of batches.
--
--    The matrix priority is basically a sub-wave that Symbotic 
--    uses to process the batches within a wave.
--
-- Parameters:
--    i_route_batch_no     - The route batch number to process.
--    i_starting_batch_row - The starting row number of the unique batches
--                           within FLOATS.
--                           Procedure "assign_mx_priority" determines
--                           this.
--    i_ending_batch_row   - The ending row number of the unique batches
--                           within FLOATS.
--                           Procedure "assign_mx_priority" determines
--                           this.
--    i_mx_priority        - The mx priority to set the FLOATS record to.
--                           All FLOATS record for the batch will be updated.
--
-- Called by:
--    assign_mx_priority
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/03/15 bben0556 Created.
---------------------------------------------------------------------------
PROCEDURE update_floats_mx_priority
             (i_route_batch_no      IN route.route_batch_no%TYPE,
              i_starting_batch_row  IN PLS_INTEGER,
              i_ending_batch_row    IN PLS_INTEGER,
              i_mx_priority         IN floats.mx_priority%TYPE)
IS
   l_object_name   VARCHAR2(30)   := 'update_floats_mx_priority';
   l_message       VARCHAR2(256);

   l_num_of_records_updated  PLS_INTEGER;  -- For log messages.
BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
         'Starting procedure'
         || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
         || 'i_starting_batch_row['    || TO_CHAR(i_starting_batch_row)  || '],'
         || 'i_ending_batch_row['      || TO_CHAR(i_ending_batch_row)    || '],'
         || 'i_mx_priority['           || TO_CHAR(i_mx_priority)         || '])'
         || '  This procedure updates the FLOATS.MX_PRIORITY.',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   --
   -- Check the parameters.  All need a value.
   --
/****
   IF (   i_route_batch_no     IS NULL
       OR i_starting_batch_row IS NULL
       OR i_ending_batch_row   IS NULL
       OR i_mx_priority        IS NULL)
   THEN
   END IF;
****/


   --
   -- Have to use inline views to get the desired results.
   --
   -- Uses the ROW_NUMBER function.  From Oracle documentation:
   -- ROW_NUMBER is an analytic function. It assigns a unique number to each
   -- row to which it is applied (either each row in the partition or each row
   -- returned by the query), in the ordered sequence of rows specified in the
   -- order_by_clause, beginning with 1.
   -- By nesting a subquery using ROW_NUMBER inside a query that retrieves the
   -- ROW_NUMBER values for a specified range, you can find a precise subset of
   -- rows from the results of the inner query. This use of the function lets
   -- you implement top-N, bottom-N, and inner-N reporting. For consistent
   -- results, the query must ensure a deterministic sort order.
   --
   -- 6/4/2015
   -- README   README   README   README   README
   -- The  "SELECT DISTINCT ..." query needs to return the same records as
   -- function "num_batches_in_wave_sent_to_mx()" otherwise we will not get the
   -- desired results.  
   --
   UPDATE floats f
      SET f.mx_priority = i_mx_priority
    WHERE f.batch_no IN
           (
           SELECT xx.batch_no
             FROM
           (  -- inline view of the distinct regular selection batches in a wave
             SELECT floats_1.batch_no,
                    ROW_NUMBER() OVER (PARTITION BY route_batch_no ORDER BY batch_no) rn
                FROM
           ( SELECT DISTINCT f.batch_no, r.route_batch_no
               FROM  floats f,
                     route r
               WHERE r.route_no       = f.route_no
                 AND r.route_batch_no = i_route_batch_no
                 AND f.pallet_pull    = 'N'
                 --
                 -- 6/3/2015  Only concerned about batches sent to the matrix.
                 -- A batch is sent to the matrix if it has any item picked from
                 -- an area that has a matrix zone setup for the area.
                 -- But getting a mutating table error for FLOATS table when using "sos_batch_to_matrix_yn". 
                 -- Not sure why.
                 -- So for now will not use "sos_batch_to_matrix_yn"  and will use the EXISTS sub query.
                 --
              -- AND pl_matrix_common.sos_batch_to_matrix_yn(f.batch_no) = 'Y' 
                 AND EXISTS
                       (SELECT 'x'
                          FROM float_detail fd,
                               loc,
                               aisle_info ai,
                               swms_sub_areas ssa,
                               zone z
                         WHERE fd.float_no              = f.float_no
                           AND loc.logi_loc             = fd.src_loc
                           AND SUBSTR(fd.src_loc, 1, 2) = ai.name
                           AND ssa.sub_area_code        = ai.sub_area_code
                           AND z.z_area_code            = ssa.area_code
                           AND z.rule_id                = 5)
            ORDER BY r.route_batch_no, f.batch_no) floats_1
           ) xx
           WHERE rn BETWEEN i_starting_batch_row AND i_ending_batch_row);

   --
   -- Log count.
   --
   l_num_of_records_updated  := SQL%ROWCOUNT;
   l_message := 'Number of FLOATS records updated: ' || TO_CHAR(l_num_of_records_updated);
   DBMS_OUTPUT.PUT_LINE(l_message);
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  l_message, NULL, NULL, ct_application_function, gl_pkg_name);

   --
   -- Log ending the procedure.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
         'Ending procedure', NULL, NULL, ct_application_function, gl_pkg_name);

END update_floats_mx_priority;


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    xxxxx
--
-- Description:
--    
-- Parameters:
--    None
--
-- Return Values:
--    xxx
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
--   
---------------------------------------------------------------------------
FUNCTION xxx
RETURN varchar2
IS
   l_object_name VARCHAR2(30) := 'xxx';
BEGIN
   null;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, 'Error',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END xxx;


---------------------------------------------------------------------------
-- Procedure:
--    create_case_records
--
-- Description:
--    This procedure creates a record for each case to pick on a route.
--
--    It is based on the FLOAT_DETAIL table qty allocated and the uom.
--
--    It is similar to how records are created in the ORDCW, ORCCB and
--    ORD_COOL tables.
--
--    Syspar MX_FLOAT_DETAIL_CASES controls what to create.  Symbotic stores only cases.
--    So each case picked from Symbotic needs a record.  The syspar
--    can be set to:
--       S - Create records for cases coming from Symbotic.
--       C - Create records for all cases.
--       P - Create records for all pieces.
--    If the syspar does not exist then the default is S.
--
--    It is expected that FLOAT_DETAIL.BC_ST_PIECE_SEQ is set correctly.
--    Below is an example of ORDD and FLOAT_DETAIL for a ORDD_SEQ broken
--    across zones on a float and how FLOAT_DETAIL.BC_ST_PIECE_SEQ is populated.
--
--   select fd.seq, fd.zone_id, fd.prod_id, fd.order_id,
--          fd.order_line_id,
--          fd.status,
--          fd.uom,
--          fd.qty_ordered,
--          fd.qty_alloc,
--          fd.qty_ordered / pm.spc,
--          fd.qty_alloc / pm.spc
--     from ordd fd, pm
--   where fd.seq =  94078869
--     and pm.prod_id = fd.prod_id
--
--       SEQ ZONE_ PROD_ID   ORDER_ID       ORDER_LINE_ID STA        UOM QTY_ORDERED  QTY_ALLOC FD.QTY_ORDERED/PM.SPC FD.QTY_ALLOC/PM.SPC
-- ---------- ----- --------- -------------- ------------- --- ---------- ----------- ---------- --------------------- -------------------
--  94078869 CLR   3630720   311131793                 30 OPN          2          56         56                    14                  14
--
--   select fd.float_no, fd.seq_no, fd.zone, fd.prod_id, fd.order_id,
--          fd.order_line_id, fd.order_seq, fd.st_piece_seq, fd.bc_st_piece_seq,
--          fd.status,
--          fd.uom,
--          fd.qty_order,
--          fd.qty_alloc,
--          fd.qty_order / pm.spc,
--          fd.qty_alloc / pm.spc
--     from float_detail fd, pm
--   where fd.order_seq =  94078869
--     and pm.prod_id = fd.prod_id
--
--   FLOAT_NO     SEQ_NO       ZONE PROD_ID   ORDER_ID       ORDER_LINE_ID  ORDER_SEQ ST_PIECE_SEQ BC_ST_PIECE_SEQ STA        UOM  QTY_ORDER  QTY_ALLOC FD.QTY_ORDER/PM.SPC FD.QTY_ALLOC/PM.SPC
-- ---------- ---------- ---------- --------- -------------- ------------- ---------- ------------ --------------- --- ---------- ---------- ---------- ------------------- -------------------
--    4012825          4          2 3630720   311131793                 30   94078869            7               7 ALC          2         32         32                   8                   8
--    4012825          5          1 3630720   311131793                 30   94078869            1               1 ALC          2         24         24                   6                   6
--
-- Parameters:
--    NOTE: One and only one parameters i_route_batch_no and i_route_no can
--          be populated.
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--    i_create_what      - What to create  This is an optonal syspar
--                         and usually should not be specified.
--                         Main purpose is for testing.
--                         If this is set then syspar MX_FLOAT_DETAIL_CASES
--                         is ignored.
--                         Valid values are:
--                            S - Create records for cases coming from Symbotic.
--                            C - Create records for all cases.
--                            P - Create records for all pieces.
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
--    10/10/12 bben0556 Created.   
---------------------------------------------------------------------------
PROCEDURE create_case_records
         (i_route_batch_no  IN  route.route_batch_no%TYPE        DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE              DEFAULT NULL,
          i_create_what     IN  sys_config.config_flag_val%TYPE  DEFAULT NULL)
IS
   l_object_name   VARCHAR2(30)   := 'create_case_records';
   l_message       VARCHAR2(256);

   -- value of Syspar MX_FLOAT_DETAIL_CASES
   l_create_what    sys_config.config_flag_val%TYPE;

   l_seq_no  PLS_INTEGER; -- The case sequence in the case number, 1, 2, 3...
                          -- Similar to what is in ORDCW, ORD_COOL, ORDCB.

   --
   -- These variables are used in error messages since we cannot reference
   -- a cursor for loop record outside the loop.
   --
   l_float_no              float_detail.float_no%TYPE;
   l_float_detail_seq_no   float_detail.seq_no%TYPE;

   --
   -- Variables to count the exceptions and log at the end of the processing.
   --
   l_num_records_processed         PLS_INTEGER := 0;
   l_num_records_created           PLS_INTEGER := 0;
   l_num_records_existing          PLS_INTEGER := 0;

   e_unhandled_create_what        EXCEPTION;  -- What to create has an unhandled value.
                                              -- The value comes from a syspar or can
                                              -- be passed as an arugment.
   e_parameter_bad_combination    EXCEPTION;  -- Bad combination of
                                              -- parameters.

   --
   -- This cursor selects the items to create the case records for.
   --
   CURSOR c_float_detail(cp_route_batch_no  route.route_batch_no%TYPE,
                         cp_route_no        route.route_no%TYPE,
                         cp_create_what     sys_config.config_flag_val%TYPE)
   IS
   SELECT f.route_no,
          f.batch_no,
          fd.order_seq,
          fd.order_id,
          fd.order_line_id,
          DECODE(fd.uom, 1, 1, 2) uom,  -- Though the float_detail.uom should be only 1 or 2.
          fd.prod_id,
          fd.cust_pref_vendor,
          fd.float_no,      -- FYI FLOAT_DETAIL PK
          fd.seq_no,        -- FYI FLOAT_DETAIL PK
          fd.qty_alloc,
          fd.zone,
          DECODE(fd.uom, 1, fd.qty_alloc, fd.qty_alloc / pm.spc)  piece_count,
          --
          fd.st_piece_seq,        -- Poor naming of this column.
                                  -- Starting piece sequence for the order-item combination.
          fd.bc_st_piece_seq,     -- Poor naming of this column.
          --
          -- CARRIER_ID should be populated when picking from a non-home slot.
          -- CARRIER_ID will be null if picked from a home slot.
          NVL(fd.carrier_id, fd.src_loc) swms_pallet_id,
          --
          'N'                     case_short_flag,
          'NEW'                   status,
          SYSDATE                 add_date,
          USER                    add_user
     FROM pm,
          floats f,
          float_detail fd,
          route r,
          loc              -- to get the slot type
    WHERE (   r.route_batch_no    = cp_route_batch_no
           OR f.route_no          = cp_route_no)
      --
      AND loc.logi_loc            = fd.src_loc
      AND r.route_no              = f.route_no
      AND pm.prod_id              = fd.prod_id
      AND pm.cust_pref_vendor     = fd.cust_pref_vendor
      AND f.float_no              = fd.float_no
      AND f.pallet_pull           = 'N'          -- Only regular selection batches.
      --
      -- cp_create_what specifies what to create.
      --
      AND (    (    cp_create_what = 'S'
                AND NVL(fd.uom, 2) <> 1
                AND loc.slot_type IN ('MXC', 'MXF'))  -- 10/24/2014 Brian Bent  We should not hardcode
           OR
               (    cp_create_what = 'C'
                AND NVL(fd.uom, 2) <> 1)
           OR
               (    cp_create_what = 'P'
                AND 1=1)
          )
      --
    ORDER BY r.route_batch_no,
             f.route_no,
             fd.order_seq,
             fd.seq_no,
             f.batch_no,
             fd.float_no,
             fd.zone;
BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
         'Starting procedure'
         || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
         || 'i_route_no['              || i_route_no                     || '],'
         || 'i_create_what['           || i_create_what                  || '])'
         || '  This procedure creates a record for each case to pick on a wave'
         || ' of routes or a specified route.'
         || '  It is based on the FLOAT_DETAIL table qty allocated and the uom.'
         || '  Records are inserted into table MX_FLOAT_DETAIL_CASES.'
         || '  Syspar MX_FLOAT_DETAIL_CASES controls what to create.  Symbotic stores only cases.'
         || '  So each case picked from a Symbotic inventory location needs a record.  The syspar'
         || ' can be set to:'
         || '  S - Create records for cases coming from Symbotic.'
         || '  C - Create records for all cases.'
         || '  P - Create records for all pieces.'
         || '  If the syspar does not exist then the default is S.'
         || '  If i_create_what is specified then it overrides the syspar.',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   --
   -- Check the parameters.
   -- One and only one of i_route_batch_no and i_route_batch_no should
   -- be populated.
   --
   IF (   i_route_batch_no IS NULL     AND i_route_no IS NOT NULL
       OR i_route_batch_no IS NOT NULL AND i_route_no IS NULL)
   THEN
      NULL;  -- Parameter check OK.
   ELSE
      RAISE e_parameter_bad_combination;
   END IF;


   --
   -- See what needs to be created.  Use the parameter if specified otherwise
   -- check the syspar.
   --
   IF (i_create_what IS NOT NULL) THEN
      l_create_what := i_create_what;    -- What to create passed as a parameter.
   ELSE
      l_create_what := pl_common.f_get_syspar('MX_FLOAT_DETAIL_CASES', 'S');
   END IF;

   --
   -- Validate l_create_what.  At this point it should be not null and
   -- have a valid value.
   --
   IF (    l_create_what IS NULL
        OR l_create_what NOT IN ('S', 'C', 'P'))
   THEN
      RAISE e_unhandled_create_what;
   END IF;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        'l_create_what['  || l_create_what  || ']'
                     || '  If l_create_what is S then only Symbotic cases,'
                     || ' if C then all cases,'
                     || ' if P then all pieces.'
                     || '  l_create_what is set to i_create_what if i_create_what is specified'
                     || ' otherwise l_create_what is set to syspar MX_FLOAT_DETAIL_CASES',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);


   FOR r_float_detail IN c_float_detail(i_route_batch_no, i_route_no, l_create_what)
   LOOP

      l_seq_no := r_float_detail.bc_st_piece_seq;

      --
      -- For error messages.
      --
      l_float_no             := r_float_detail.float_no;
      l_float_detail_seq_no  := r_float_detail.seq_no;

      FOR i IN 1..r_float_detail.piece_count LOOP

         l_num_records_processed := l_num_records_processed + 1;

         dbms_output.put_line(
                         'route_no:'         || r_float_detail.route_no
                      || ' batch_no:'        || r_float_detail.batch_no
                      || ' float_no:'        || r_float_detail.float_no
                      || ' zone:'            || r_float_detail.zone
                      || ' order_seq:'       || r_float_detail.order_seq
                      || ' order_id:'        || r_float_detail.order_id
                      || ' order_line_id:'   || r_float_detail.order_line_id
                      || ' prod_id:'         || r_float_detail.prod_id
                      || ' uom:'             || r_float_detail.uom
                      || ' qty_alloc:'       || r_float_detail.qty_alloc
                      || ' piece_count:'     || r_float_detail.piece_count
                      || ' swms_pallet_id '  || r_float_detail.swms_pallet_id
                      || '   l_seq_no '      || l_seq_no);

         --
         -- Start a new block to trap exceptions.
         --
         BEGIN
            INSERT INTO mx_float_detail_cases
            (   
               order_seq,
               seq_no,
               order_id,
               order_line_id,
               uom,
               prod_id,
               cust_pref_vendor,
               float_no,
               float_detail_seq_no,
               batch_no,
               float_detail_zone,
               swms_pallet_id,
               case_short_flag,
               status,
               add_date,
               add_user
            )
            VALUES
            (
               r_float_detail.order_seq,
               l_seq_no,
               r_float_detail.order_id,
               r_float_detail.order_line_id,
               r_float_detail.uom,
               r_float_detail.prod_id,
               r_float_detail.cust_pref_vendor,
               r_float_detail.float_no,
               r_float_detail.seq_no,
               r_float_detail.batch_no,
               r_float_detail.zone,
               r_float_detail.swms_pallet_id,
               r_float_detail.case_short_flag,
               r_float_detail.status,
               r_float_detail.add_date,
               r_float_detail.add_user
            );

            l_seq_no := l_seq_no + 1;
            l_num_records_created := l_num_records_created + 1;
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               l_num_records_existing := l_num_records_existing + 1;
         END;
      END LOOP;  -- end the piece count loop
   END LOOP;     -- end the route number loop

   --
   -- Log the counts.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        '(i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
                     || 'i_route_no['              || i_route_no                     || '],'
                     || 'i_create_what['           || i_create_what                  || '])'
                     || '  l_num_records_processed['  || TO_CHAR(l_num_records_processed)  || ']'
                     || '  l_num_records_created['    || TO_CHAR(l_num_records_created)    || ']'
                     || '  l_num_records_existing['   || TO_CHAR(l_num_records_existing)   || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   --
   -- Log when done.  Note that if there is an exception this message can be bypassed.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        'Ending procedure'
                     || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
                     || 'i_route_no['              || i_route_no                     || '],'
                     || 'i_create_what['           || i_create_what                  || '])',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
EXCEPTION
   WHEN e_unhandled_create_what THEN
      --
      -- l_create_what has an invalid value.
      --
       l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
             || 'i_route_no['            || i_route_no                || '],'
             || 'i_create_what['         || i_create_what             || '])'
             || '  i_create_what has an unhandled value.';

       pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                      l_message, pl_exc.ct_data_error, NULL,
                      ct_application_function, gl_pkg_name);

         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

   WHEN e_parameter_bad_combination THEN
      --
      -- One and only one of i_route_batch_no and i_route_n can be populated.
      --
      l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
                   || 'i_route_no[' || i_route_no || '])'
                   || '  One and only one of these two parameters can have a value.';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     l_message, pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                         '(i_route_batch_no['       || TO_CHAR(i_route_batch_no)      || '],'
                      || 'i_route_no['             || i_route_no                      || '],'
                      || 'i_create_what['          || i_create_what                   || '])'
                      || '  l_float_no['            || TO_CHAR(l_float_no)            || ']'
                      || '  l_float_detail_seq_no[' || TO_CHAR(l_float_detail_seq_no) || ']'
                      || '  l_seq_no['              || TO_CHAR(l_seq_no)              || ']',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END create_case_records;


--------------------------------------------------------------------------
-- Not used yet      Not used yet      Not used yet
-- Local function
-- Return TRUE if the selection batch has pick from the matrix otherwise
-- return FALSE.
--------------------------------------------------------------------------
FUNCTION batch_has_pick_from_matrix(i_batch_no IN floats.batch_no%TYPE)
RETURN BOOLEAN
IS
   l_count         NUMBER;  -- work area
   l_return_value  BOOLEAN;
BEGIN
   SELECT COUNT(*) INTO l_count
     FROM floats f,
          float_detail fd,
          loc
    WHERE f.batch_no    = i_batch_no
      AND f.pallet_pull = 'N'
      AND fd.float_no   = f.float_no
      AND loc.logi_loc  = fd.src_loc
      AND loc.slot_type IN ('MXC', 'MXF');

   IF (l_count > 0) THEN
      l_return_value := TRUE;
   ELSE
      l_return_value := FALSE;
   END IF;

   RETURN l_return_value;

 -- need exception handling here

END batch_has_pick_from_matrix;


---------------------------------------------------------------------------
-- Function:
--    num_batches_in_wave_sent_to_mx
--
-- Description:
--    This functions counts the number of normal selection batches in a
--    wave that are sent/to be sent to the matrix.
--
-- Parameters:
--    i_route_batch_no - The wave to process.
--
-- Return Value:
--    Number of normal selection batches in a wave sent to the matrix
--
-- Called by:
--    assign_mx_priority
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/03/15 bben0556 Created.
---------------------------------------------------------------------------
FUNCTION num_batches_in_wave_sent_to_mx
             (i_route_batch_no      IN route.route_batch_no%TYPE)
RETURN PLS_INTEGER
IS
   l_batch_count  PLS_INTEGER;
BEGIN
   --
   -- 6/4/2015
   -- README   README   README   README   README
   -- This query needs to select the same batches as the
   -- "SELECT DISTINCT ..." query in procedure "update_floats_mx_priority()"
   -- otherwise we will not get the desired results.  
   --


   /*******
   6/4/2015 Brian Bent  Won't use this method.
   SELECT COUNT(DISTINCT f.batch_no)
     INTO l_batch_count
     FROM floats f,
          route r
    WHERE r.route_batch_no = i_route_batch_no
      AND r.route_no       = f.route_no
      AND f.pallet_pull    = 'N'
      AND pl_matrix_common.sos_batch_to_matrix_yn(f.batch_no) = 'Y';  -- 6/3/2015 Only want batches sent to symbotic
   *******/

   SELECT COUNT(DISTINCT f.batch_no)
     INTO l_batch_count
     FROM floats f,
          route r
    WHERE r.route_no       = f.route_no
      AND r.route_batch_no = i_route_batch_no
      AND f.pallet_pull    = 'N'
      AND EXISTS
             (SELECT 'x'
                FROM float_detail fd,
                     loc,
                     aisle_info ai,
                     swms_sub_areas ssa,
                     zone z
               WHERE fd.float_no              = f.float_no
                     AND loc.logi_loc             = fd.src_loc
                     AND SUBSTR(fd.src_loc, 1, 2) = ai.name
                     AND ssa.sub_area_code        = ai.sub_area_code
                     AND z.z_area_code            = ssa.area_code
                     AND z.rule_id                = 5);

   RETURN(l_batch_count);

   -- add error handling
END num_batches_in_wave_sent_to_mx;


---------------------------------------------------------------------------
-- Procedure:
--    assign_mx_priority
--
-- Description:
--    This procedure assigns the matrix priority to the FLOATS record.
--    for each batch that is sent to the matrix.
--
--    The matrix priority is basically a sub-wave that Symbotic 
--    uses to process the batches within a wave.
--
--    Procedure "update_floats_mx_priority()" is called to do the update
--    of the floats table.
--
-- Parameters:
--    i_route_batch_no         - The route batch number to process.
--    i_num_of_priority_groups - The number of priority groups.
--                               The matrix priority starts at 1
--                               and ends at i_num_of_priority_groups.
--                               If null or <= 0 then the value is taken
--                               from syspar MX_NUMBER_OF_PRIORITY_GROUPS.
--                               If the syspar does not exist then 3 is used.
--
-- Called by:
--    assign_mx_priority
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/03/15 bben0556 Created.
---------------------------------------------------------------------------
PROCEDURE assign_mx_priority
            (i_route_batch_no          IN route.route_batch_no%TYPE,
             i_num_of_priority_groups  IN PLS_INTEGER DEFAULT NULL)
IS
   l_object_name   VARCHAR2(30) := 'assign_mx_priority';
   l_message       VARCHAR2(256);

   l_num_of_priority_groups  PLS_INTEGER;
   l_num_mx_batches_in_wave  PLS_INTEGER;
   l_trunc             number;
   l_mod               number;
   l_mod_modify        number;
   l_one               number;
   l_total_in_group    number;

   l_starting_batch_row  PLS_INTEGER;
   l_ending_batch_row    PLS_INTEGER;
BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
         'Starting procedure'
         || '  (i_route_batch_no['       || TO_CHAR(i_route_batch_no)         || '],'
         || 'i_num_of_priority_groups['  || TO_CHAR(i_num_of_priority_groups) || '])'
         || '  This procedure assigns the matrix priority for the normal'
         || ' selection batches that are going to be sent to the matrix'
         || ' for the specified wave(route batch number).',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   --
   -- Check the parameters.
   --
/****
   IF (i_route_batch_no IS NULL)
   THEN
   END IF;
****/

   --
   -- Get the number of batches on the wave what are sent to the matrix.
   -- These are the ones that are assigned a priority.
   --
   l_num_mx_batches_in_wave := num_batches_in_wave_sent_to_mx(i_route_batch_no);

   --
   -- Get the number of priority groups.  It will be:
   --    - i_num_of_priority_groups if > 0.
   --    - syspar MX_NUMBER_OF_PRIORITY_GROUPS if the syspar exists.
   --    - 3
   --
   IF (i_num_of_priority_groups > 0) THEN
     
      l_num_of_priority_groups := i_num_of_priority_groups;

      pl_log.ins_msg (pl_log.ct_info_msg, l_object_name,
            'i_num_of_priority_groups is >= 1.  Using it for the number of priority groups.',
            NULL, NULL, ct_application_function, gl_pkg_name);
   ELSE
      IF (i_num_of_priority_groups <= 0) THEN
         pl_log.ins_msg (pl_log.ct_warn_msg, l_object_name,
                   'i_num_of_priority_groups is <= 1. Ignoring it.',
                   NULL, NULL, ct_application_function, gl_pkg_name);
      END IF;

      l_num_of_priority_groups := pl_common.f_get_syspar('MX_NUMBER_OF_PRIORITY_GROUPS', NULL);

      IF (l_num_of_priority_groups IS NULL) THEN
         pl_log.ins_msg (pl_log.ct_warn_msg, l_object_name,
                   'Syspar MX_NUMBER_OF_PRIORITY_GROUPS does not exist.  Using 3 for'
                   || ' the number of priority groups.',
                   NULL, NULL, ct_application_function, gl_pkg_name);

         l_num_of_priority_groups := 3;
      END IF;
   END IF;

   l_trunc := TRUNC(l_num_mx_batches_in_wave / l_num_of_priority_groups);
   l_mod  := MOD(l_num_mx_batches_in_wave, l_num_of_priority_groups);
   l_mod_modify  := l_mod;

   DBMS_OUTPUT.PUT_LINE('==========================================');

   DBMS_OUTPUT.PUT_LINE('l_num_mx_batches_in_wave: ' || to_char(l_num_mx_batches_in_wave)
                     || '  l_num_of_priority_groups: ' || to_char(l_num_of_priority_groups)
                     || '  l_trunc: ' || to_char(l_trunc)
                     || '  l_mod: ' || to_char(l_mod));

   --
   -- Adjusts the number of priority groups to the total matrix batches if
   -- more than total matrix batches.  Othersize we will not get the desired
   -- results.
   --
   IF (l_num_of_priority_groups > l_num_mx_batches_in_wave) THEN
      l_num_of_priority_groups := l_num_mx_batches_in_wave;
   END IF;

   FOR i in 1..l_num_of_priority_groups LOOP
      DBMS_OUTPUT.PUT_LINE('++++++++++++++++++++++++++++++++++++++++++');
      IF (l_mod_modify > 0) THEN
         l_one := 1;
      ELSe
         l_one := 0;
      END IF;

      l_total_in_group := l_trunc + (l_one);

      DBMS_OUTPUT.PUT_LINE('priority: ' || to_char(i)
             || '    total in group: ' || to_char(l_total_in_group));

      IF (i = 1) THEN
         l_starting_batch_row := 1;
         l_ending_batch_row   := to_char(l_trunc + (l_one));
      ELSE
         l_starting_batch_row := l_ending_batch_row + 1;
         l_ending_batch_row := (l_starting_batch_row + l_total_in_group) - 1;
      END IF;

      DBMS_OUTPUT.PUT_LINE('l_starting_batch_row: ' || to_char(l_starting_batch_row)
           || '    l_ending_batch_row: ' || to_char(l_ending_batch_row));

      update_floats_mx_priority
                (i_route_batch_no,
                 l_starting_batch_row,
                 l_ending_batch_row,
                 i);

      IF (l_mod_modify > 0) THEN
         l_mod_modify := l_mod_modify - 1;
      END IF;
   END LOOP;

   --
   -- Log ending the procedure.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
         'Ending procedure', NULL, NULL, ct_application_function, gl_pkg_name);
END assign_mx_priority;

END pl_matrix_op;
/

SHOW ERRORS


/****
CREATE OR REPLACE PUBLIC SYNONYM pl_matrix_op FOR swms.pl_matrix_op
/

GRANT EXECUTE ON swms.pl_matrix_op TO SWMS_USER
/
***/

