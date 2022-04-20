
SET SCAN OFF

PROMPT Create package specification: pl_lm_sel

/**************************************************************************/
-- Package Specification
/**************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_lm_sel
AS

-- sccs_id=@(#) src/schema/plsql/pl_lm_sel.sql, swms, swms.9, 10.1.1 4/21/08 1.7

---------------------------------------------------------------------------
-- Package Name:
--    pl_lm_sel
--
-- Description:
--    Create selection labor mgmt batches.
--
--    6/15/05  This package calls objects in:
--                - pl_common
--                - pl_exc
--                - pl_lma
--                - pl_lmc
--                - pl_lm_time
--                - pl_log
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/15/05 prpbcb   Oracle 8 rs239b swms9 DN 11490
--                      Created for discrete selection.
--                      PL/SQL package version of the selection labor mgmt
--                      functions in PRO*C program crt_lbr_mgmt_bats.pc.
--                      Initially created to use with discrete selection.
--
--                      Changes made during development:
--                      Added clam bed data capture.
--                      Removed references to syspars:
--                         -  DS_AUDIT_DURING_ORDER_GEN
--                         - DS_DRY_MAX_WALKING_DISTANCE
--                         - DS_CLR_MAX_WALKING_DISTANCE
--                         - DS_FRZ_MAX_WALKING_DISTANCE
--                      After meeting with Distribution Services it was
--                      determined these syspars are not needed.
--
--                      Added cool track to the data capture.
--
--    04/20/06 prpbcb   DN 12080
--                      WAI defect but not a WAI change.
--                      Do not track clam bed data capture separately from
--                      from data capture as this time.
--
--    07/20/06 prpbcb   DN 12106
--                      This change will in the 9.6.1 cleanup URD.
--                      Fix parameters in function call that resulted
--                      in cool tracked item always no. 
--                      Changed
--     pl_common.f_is_cool_tracked_item(p.category, cp_syspar_clam_bed_tracked)
--                      to
--     pl_common.f_is_cool_tracked_item(p.prod_id, p.cust_pref_vendor)
--
--                      Changed cursors g_c_sel_batch and c_sel_merge
--                      to look at table SPL_RQST_CUSTOMER to determine
--                      it cool data is to be collected.  Before the cursors
--                      did not look at this table.
--     01/21/08 prpakp  D#12335 Corrected to calculate the cube correctly.
--     04/21/08 prppxx  D#12369 573188-Fix Stop Number Calculation.
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Public Cursors
---------------------------------------------------------------------------

-- This cursor selects the information used to create the selection
-- labor mgmt batches.  Records can be selected three ways;
--    - by route number         (route.route_no)
--    - by route batch number   (route.route_batch_no)
--    - by floats batch number  (floats.batch_no)
--
CURSOR g_c_sel_batch
           (cp_how_generated           IN VARCHAR2,
            cp_route_no                IN route.route_no%TYPE,
            cp_route_batch_no          IN route.route_batch_no%TYPE,
            cp_batch_no                IN floats.batch_no%TYPE,
            cp_syspar_clam_bed_tracked IN sys_config.config_flag_val%TYPE)
   IS
SELECT /*+ RULE +*/ sm.sel_lift_job_code job_code,
       'S' || RTRIM(LTRIM(TO_CHAR(f.batch_no))) lm_batch_no, -- LM batch#
       f.batch_no                        batch_no,  -- floats batch number
       f.equip_id,
       --COUNT(DISTINCT (fd.float_no||fd.stop_no))       num_stops,
       COUNT(DISTINCT fd.stop_no)                      num_stops,
       COUNT(DISTINCT (fd.float_no||fd.zone))          num_zones,
       COUNT(DISTINCT fd.float_no)                     num_floats,
       COUNT(DISTINCT fd.src_loc)                      num_locs,
       SUM(DECODE(fd.merge_alloc_flag,
                  'M', 0,
                  'S', 0,
                  DECODE(fd.uom, 1, fd.qty_alloc, 0))) num_splits,
       SUM(DECODE(fd.merge_alloc_flag,
                  'M', 0,
                  'S', 0,
                  DECODE(fd.uom,
                         2, fd.qty_alloc / NVL(p.spc,1),
                         NULL, fd.qty_alloc / NVL(p.spc, 1),
                         0)))                          num_cases,
       SUM(DECODE(fd.merge_alloc_flag,
                  'M', DECODE(fd.uom,
                              2, ROUND(fd.qty_alloc / NVL(p.spc, 1)),
                              1, fd.qty_alloc,
                              0),
                  'S', 0,
                   0))                                 num_merges,
       SUM(DECODE(p.catch_wt_trk,
                  'Y', DECODE(fd.uom,
                              1, fd.qty_alloc,
                              fd.qty_alloc / NVL(spc,1)),
                  0))                           num_catch_wt_data_captures,
       SUM(DECODE(sr.cool_trk,
                  'Y', DECODE(pl_common.f_is_cool_tracked_item(p.prod_id, p.cust_pref_vendor),
                              'Y', DECODE(fd.uom,
                                          1, fd.qty_alloc,
                                          fd.qty_alloc / NVL(spc,1)),
                              0),
                  0))                          num_cool_trk_data_captures,
       SUM(DECODE(pl_common.f_is_clam_bed_tracked_item(p.category, cp_syspar_clam_bed_tracked),
                  'Y', DECODE(fd.uom,
                              1, fd.qty_alloc,
                              fd.qty_alloc / NVL(spc,1)),
                  0))                          num_clam_bed_data_captures,
       SUM(DECODE(fd.merge_alloc_flag,
                  'M', 0,
                  'S', 0,
                  DECODE(fd.uom,
                         1, ROUND(fd.qty_alloc*(p.weight/NVL(p.spc,1))),
                         0)))                          split_wt,
       SUM(DECODE(fd.merge_alloc_flag,
                  'M', 0,
                  'S', 0,
                  DECODE(fd.uom,
                         1, fd.qty_alloc * p.split_cube,
                         0)))                          split_cube,
       SUM(DECODE(fd.merge_alloc_flag,
                  'M', 0,
                  'S', 0,
                  DECODE(fd.uom,
                         2, fd.qty_alloc * p.weight,
                         NULL, fd.qty_alloc * p.weight,
                         0)))                          case_wt,
       SUM(DECODE(fd.merge_alloc_flag,
                'M', 0,
                'S', 0,
                DECODE(fd.uom,
                       2, ((fd.qty_alloc / NVL(p.spc,1))*p.case_cube),
                       NULL, ((fd.qty_alloc/nvl(p.spc,1))*p.case_cube),
                       0)
		 ))                                 case_cube,
       COUNT(DISTINCT SUBSTR(fd.src_loc, 1, 2))           num_aisles,
       COUNT(DISTINCT fd.prod_id || fd.cust_pref_vendor)  num_items,
       DECODE(COUNT(DISTINCT f.route_no),
              1, MIN(r.truck_no),
              'MULTI')         reference,  -- MULTI designates more than one
                                           -- route on the batch.
       COUNT(DISTINCT f.route_no)                         num_routes
  FROM job_code j,
       sel_method sm,
       pm p,
       float_detail fd,
       floats f,
       ordm o,
       spl_rqst_customer sr,
       route r
 WHERE j.lfun_lbr_func        = 'SL' 
   AND j.jbcd_job_code    = sm.sel_lift_job_code
   AND sm.group_no        = f.group_no 
   AND sm.method_id       = r.method_id
   AND p.prod_id          = fd.prod_id
   AND p.cust_pref_vendor = fd.cust_pref_vendor
   AND fd.float_no        = f.float_no 
   AND f.pallet_pull NOT IN ('D','R')
   AND f.route_no         = r.route_no
   AND o.order_id         = fd.order_id
   AND sr.customer_id (+) = o.cust_id
   AND
         (    ('r' = cp_how_generated AND r.route_no       = cp_route_no)
           OR ('g' = cp_how_generated AND r.route_batch_no = cp_route_batch_no) 
           OR ('b' = cp_how_generated AND f.batch_no       = cp_batch_no) )
 GROUP BY sm.sel_lift_job_code, f.batch_no, f.equip_id;


---------------------------------------------------------------------------
-- Public Type Declarations
---------------------------------------------------------------------------

SUBTYPE t_sel_batch_rec  IS g_c_sel_batch%ROWTYPE;

-- Record to hold syspars that are used in the processing.
-- Each syspar is a field in the record.
TYPE t_syspars_rec IS RECORD
   (
    clam_bed_tracked         sys_config.config_flag_val%TYPE,
    ds_discrete_selection    sys_config.config_flag_val%TYPE
   );


---------------------------------------------------------------------------
-- Global Variables
---------------------------------------------------------------------------

-- Record to hold syspars.  Since the syspars can be looked at as being
-- constants a global record is used.
g_r_syspars t_syspars_rec;


---------------------------------------------------------------------------
-- Public Constants
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------


------------------------------------------------------------------------
-- Procedure:
--    create_selection_batches
--
-- Description:
--    This procedure creates the selection labor mgmt batches.
--    It is also used to audit the labor mgmt batch after the selection
--    batch has been created.
---------------------------------------------------------------------------
PROCEDURE create_selection_batches
             (i_how_generated      IN  VARCHAR2,
              i_generation_key     IN  VARCHAR2,
              i_audit_only_bln     IN  BOOLEAN DEFAULT FALSE,
              o_error_detected_bln OUT BOOLEAN);

END pl_lm_sel;  -- end package specification
/

SHOW ERRORS;


PROMPT Create package body: pl_lm_sel

/**************************************************************************/
-- Package Body
/**************************************************************************/
CREATE OR REPLACE PACKAGE BODY swms.pl_lm_sel
IS
---------------------------------------------------------------------------
-- Package Name:
--    pl_lm_sel
--
-- Description:
--    Create selection labor mgmt batches.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/17/02 prpbcb   rs239a DN 10859  rs239b DN 10860  Created.  
--                      PL/SQL package version of the selection labor mgmt
--                      functions in PRO*C program
--                      Initially created to use with discrete selection.
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(20) := 'pl_lm_sel';   -- Package name.  Used in
                                            -- error messages.


---------------------------------------------------------------------------
-- Private Constants
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------
--                        show_line
--
-- This procedure is used to output the value in a varchar2 variable
-- when the length of the variable is greater than 255 characters.
-- PUT_LINE has a limit of 255 characters.
--
-- Used for debugging.
---------------------------------------------------------------------
PROCEDURE show_line (p_line IN VARCHAR2)
IS
   l_position  INTEGER := 1;
   l_split     INTEGER := 70;
   l_line_len  INTEGER := LENGTH(p_line);
BEGIN
DBMS_OUTPUT.PUT_LINE('---- show line ----');
   IF (l_line_len <= 255) THEN
      DBMS_OUTPUT.PUT_LINE(p_line);
   ELSE
      WHILE (l_position < l_line_len) LOOP
         DBMS_OUTPUT.PUT_LINE(SUBSTR(p_line, l_position, l_split));
         l_position := l_position + l_split;
      END LOOP;
   END IF;
END show_line;

-----------------------------------------------------------------------
-- Function:
--    f_get_company_no
--
-- Description:
--    This function returns the company number selected from the
--    MAINTENANCE table left trimmed of zeroes.  If not found then
--    NULL is returned.
--
-- Parameters:
--    None
--
-- Return Values:
--    The company number left trimmed of zeroes.  If not found then
--    NULL is returned.
--
-- Exceptions raised:
--    pl_exc.e_database_error     -  Oracle error occurred.
---------------------------------------------------------------------
FUNCTION f_get_company_no
RETURN VARCHAR2 IS
   l_object_name   VARCHAR2(30) := gl_pkg_name || '.f_get_company_no';

   l_company_no  maintenance.attribute_value%TYPE;

   CURSOR c_company_no IS
      SELECT LTRIM(SUBSTR(attribute_value,
                          1, INSTR(attribute_value, ':') -1) ,'0')
        FROM maintenance
       WHERE attribute = 'MACHINE';
BEGIN
   OPEN c_company_no;
   FETCH c_company_no INTO l_company_no;
   IF (c_company_no%NOTFOUND) THEN
      l_company_no := NULL;
   END IF;
   CLOSE c_company_no;

   RETURN (l_company_no);

EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, NULL,
                     SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END f_get_company_no;


------------------------------------------------------------------------
-- Procedure:
--    create_merge_selection_batches
--
-- Description:
--    This procedure creates the merge selection labor mgmt batches for
--    the selection batches that have more than one route.
--    Optimal pull can result in a float batch with more than one route.
--
-- Parameters:
--    i_batch_no      - Floats batch number
--    i_lm_batch_no   - Selection labor mgmt parent batch number.
--
-- Exceptions raised:
--    pl_exc.e_database_error  - Oracle error occurred.
--
-- Called by:
--    create_selection_batches
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/16/02 prpbcb   Created.
--                      PL/SQL version of load_merge_sel_batches() in
--                      crt_lbr_mgmt_bats.pc.
---------------------------------------------------------------------------
PROCEDURE create_merge_selection_batches
            (i_batch_no                 IN floats.batch_no%TYPE,
             i_lm_batch_no              IN arch_batch.batch_no%TYPE,
             cp_syspar_clam_bed_tracked IN sys_config.config_flag_val%TYPE)
IS
   l_message        VARCHAR2(256);    -- Message buffer
   l_message_param  VARCHAR2(256);    -- Message buffer
   l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                     '.create_merge_selection_batches';

   l_insert_ok_bln BOOLEAN;   -- Designates if insert to batch successful.
   l_merge_lm_batch_no  arch_batch.batch_no%TYPE;  -- Merge batch number
   l_num_pieces     PLS_INTEGER;
   l_num_merges     PLS_INTEGER;
   l_num_s_merges   PLS_INTEGER;
   l_sub_batch_no   PLS_INTEGER;  -- Used in building the child batch number.
   l_total_wt       NUMBER;
   l_total_cube     NUMBER;

   -- This cursor selects the merge batch information by route on the
   -- parent selection batch.
   CURSOR c_sel_merge(cp_batch_no IN floats.batch_no%TYPE) IS
      SELECT
          sm.sel_lift_job_code job_code,
          --COUNT(DISTINCT (fd.float_no||fd.stop_no)) num_stops,
          COUNT(DISTINCT fd.stop_no) num_stops,
          COUNT(DISTINCT (fd.float_no||fd.zone)) num_zones,
          COUNT(DISTINCT fd.float_no) num_floats,
          COUNT(DISTINCT fd.src_loc) num_locs,
          SUM(DECODE(fd.merge_alloc_flag,
                     'M', 0,
                     'S', 0,
                     DECODE(fd.uom, 1, fd.qty_alloc, 0))) num_splits,
          SUM(DECODE(fd.merge_alloc_flag,
                     'M', 0,
                     'S', 0,
                     DECODE(fd.uom,
                            2, fd.qty_alloc / NVL(p.spc,1),
                            NULL, fd.qty_alloc / NVL(p.spc, 1),
                            0))) num_cases,
          SUM(DECODE(fd.merge_alloc_flag,
                     'M', DECODE(fd.uom,
                                 2, ROUND(fd.qty_alloc / NVL(p.spc, 1)),
                                 1, fd.qty_alloc,
                                 0),
                     'S', 0,
                      0)) num_merges,
          SUM(DECODE(p.catch_wt_trk,
                     'Y', DECODE(fd.uom,
                                 1, fd.qty_alloc,
                                 fd.qty_alloc / NVL(spc,1)),
                     0)) num_catch_wt_data_captures,
          SUM(DECODE(sr.cool_trk,
                  'Y', DECODE(pl_common.f_is_cool_tracked_item(p.prod_id, p.cust_pref_vendor),
                              'Y', DECODE(fd.uom,
                                          1, fd.qty_alloc,
                                          fd.qty_alloc / NVL(spc,1)),
                              0),
                  0))                          num_cool_trk_data_captures,
    SUM(DECODE(pl_common.f_is_clam_bed_tracked_item(p.category, cp_syspar_clam_bed_tracked),
                     'Y', DECODE(fd.uom,
                                 1, fd.qty_alloc,
                                 fd.qty_alloc / NVL(spc,1)),
                     0)) num_clam_bed_data_captures,
          SUM(DECODE(fd.merge_alloc_flag,
                     'M', 0,
                     'S', 0,
                     DECODE(fd.uom,
                            1, ROUND(fd.qty_alloc*(p.weight/NVL(p.spc,1))),
                            0))) split_wt,
          SUM(DECODE(fd.merge_alloc_flag,
                     'M', 0,
                     'S', 0,
                     DECODE(fd.uom,
                            1, fd.qty_alloc * p.split_cube,
                            0))) split_cube,
          SUM(DECODE(fd.merge_alloc_flag,
                     'M', 0,
                     'S', 0,
                     DECODE(fd.uom,
                            2, fd.qty_alloc * p.weight,
                            NULL, fd.qty_alloc * p.weight,
                            0))) case_wt,
          SUM(DECODE(fd.merge_alloc_flag,
                'M', 0,
                'S', 0,
                DECODE(fd.uom,
                       2, ((fd.qty_alloc / NVL(p.spc,1))*p.case_cube),
                       NULL, ((fd.qty_alloc/nvl(p.spc,1))*p.case_cube),
                       0))) case_cube,
          COUNT(DISTINCT SUBSTR(fd.src_loc, 1, 2)) num_aisles,
          COUNT(DISTINCT fd.prod_id || fd.cust_pref_vendor) num_items,
          f.route_no route_no
        FROM job_code j,
             sel_method sm,
             pm p,
             float_detail fd,
             floats f,
             ordm o,
             spl_rqst_customer sr,
             route r
       WHERE j.lfun_lbr_func     = 'SL' 
         AND j.jbcd_job_code     = sm.sel_lift_job_code
         AND sm.group_no         = f.group_no 
         AND sm.method_id        = r.method_id
         AND p.prod_id           = fd.prod_id
         AND p.cust_pref_vendor  = fd.cust_pref_vendor
         AND fd.float_no         = f.float_no 
         AND f.route_no          = r.route_no
         AND o.order_id          = fd.order_id
         AND sr.customer_id (+)  = o.cust_id
         AND f.batch_no          = cp_batch_no
       GROUP BY sm.sel_lift_job_code, f.route_no
       ORDER BY sm.sel_lift_job_code, f.route_no;

   -- This cursor counts the number of 'S' merges on the selection batch
   -- for a particular route.
   CURSOR c_route_s_merges(cp_batch_no IN floats.batch_no%TYPE,
                           cp_route_no IN route.route_no%TYPE) IS
      SELECT COUNT(DISTINCT f.merge_loc)
        FROM job_code j,
             sel_method sm,
             float_detail d, 
             floats f,
             route r
       WHERE j.lfun_lbr_func    = 'SL'
         AND j.jbcd_job_code    = sm.sel_lift_job_code
         AND sm.group_no        = f.group_no
         AND sm.method_id       = r.method_id
         AND d.merge_alloc_flag = 'S' 
         AND d.float_no         = f.float_no
         AND f.route_no         = r.route_no
         AND f.route_no         = cp_route_no
         AND f.batch_no         = cp_batch_no;
BEGIN

   l_message_param := l_object_name || '(i_lm_batch_no[' || i_lm_batch_no ||
                '], i_batch_no[' || TO_CHAR(i_batch_no) || '])';

   pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                  NULL, NULL);

   l_sub_batch_no := 0;

   FOR r_sel_merge IN c_sel_merge(i_batch_no) LOOP

      l_sub_batch_no := l_sub_batch_no + 1;
      l_insert_ok_bln := TRUE;

      l_merge_lm_batch_no := i_lm_batch_no || TO_CHAR(l_sub_batch_no);

      -- Get the number of S merges on the batch for a route.
      OPEN c_route_s_merges(i_batch_no, r_sel_merge.route_no);
      FETCH c_route_s_merges INTO l_num_s_merges;
      IF (c_route_s_merges%NOTFOUND) THEN
         l_num_s_merges := 0;
      END IF;
      CLOSE c_route_s_merges;

      l_num_pieces := r_sel_merge.num_cases + r_sel_merge.num_splits +
                      r_sel_merge.num_merges + l_num_s_merges;

      l_total_wt   := TRUNC(r_sel_merge.case_wt + r_sel_merge.split_wt);
      l_total_cube := ROUND(r_sel_merge.case_cube + r_sel_merge.split_cube);

      -- Create the batch.  The batch number will be the parent batch
      -- number || seq number.  The status will be 'M' since it is a child
      -- batch.
      BEGIN
         INSERT INTO batch
                    (batch_no,
                     batch_date,
                     status,
                     parent_batch_no,
                     jbcd_job_code,
                     user_id,
                     ref_no,
                     kvi_cube,
                     kvi_wt,
                     kvi_no_piece,
                     kvi_no_case,
                     kvi_no_split,
                     kvi_no_merge,
                     kvi_no_item,
                     kvi_no_stop,
                     kvi_no_zone,
                     kvi_no_loc,
                     kvi_no_aisle,
                     kvi_no_data_capture,
                     kvi_no_clam_bed_data_capture,
                     kvi_no_pallet)
             VALUES
                    (l_merge_lm_batch_no,
                     TRUNC(SYSDATE),
                     'M',
                     i_lm_batch_no,
                     r_sel_merge.job_code,
                     NULL,
                     r_sel_merge.route_no,
                     l_total_cube,
                     l_total_wt,
                     l_num_pieces,
                     r_sel_merge.num_cases,
                     r_sel_merge.num_splits,
                     r_sel_merge.num_merges,
                     r_sel_merge.num_items,
                     r_sel_merge.num_stops,
                     r_sel_merge.num_zones,
                     r_sel_merge.num_locs,
                     r_sel_merge.num_aisles,
                     r_sel_merge.num_catch_wt_data_captures +
                     r_sel_merge.num_cool_trk_data_captures +
                     r_sel_merge.num_clam_bed_data_captures,
                     NULL,    -- 04/20/06 prpbcb clam bed data capture
                     r_sel_merge.num_floats);
      EXCEPTION
         WHEN OTHERS THEN
            l_insert_ok_bln := FALSE;
            l_message := 'TABLE=batch  ACTION=INSERT' ||
                         '  batch_no=' || l_merge_lm_batch_no ||
                         '  MESSAGE="Insert of merge batch failed"';

            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
      END;

      IF (l_insert_ok_bln) THEN
         BEGIN
            -- Update the KVIs in the parent batch to store the difference
            -- between the grand totals and the actual total(discounted KVIs 
            -- for optimal pull) 
            UPDATE batch 
               SET kvi_cube     = 0.0, 
                   kvi_wt       = 0.0, 
                   kvi_no_piece = kvi_no_piece - l_num_pieces,
                   kvi_no_case  = kvi_no_case - r_sel_merge.num_cases, 
                   kvi_no_split = kvi_no_split - r_sel_merge.num_splits,  
                   kvi_no_merge = kvi_no_merge - r_sel_merge.num_merges, 
                   kvi_no_aisle = kvi_no_aisle - r_sel_merge.num_aisles,
                   kvi_no_loc   = kvi_no_loc - r_sel_merge.num_locs,
                   kvi_no_stop  = kvi_no_stop - r_sel_merge.num_stops, 
                   kvi_no_zone  = kvi_no_zone - r_sel_merge.num_zones, 
                   kvi_no_item  = kvi_no_item - r_sel_merge.num_items,
                   kvi_no_data_capture = kvi_no_data_capture -
                                    (r_sel_merge.num_catch_wt_data_captures +
                                     r_sel_merge.num_cool_trk_data_captures +
                                     r_sel_merge.num_clam_bed_data_captures), 
       /*** 04/20/06 prpbcb No separate clam bed data capture at this time
          kvi_no_clam_bed_data_capture = kvi_no_clam_bed_data_capture -
                                   r_sel_merge.num_clam_bed_data_captures, 
       ***/
                   kvi_no_pallet = kvi_no_pallet - r_sel_merge.num_floats 
             WHERE batch_no = i_lm_batch_no;

         EXCEPTION
            WHEN OTHERS THEN
               l_message := 'TABLE=batch  ACTION=UPDATE' ||
                            '  batch_no=' || l_merge_lm_batch_no ||
                            '  MESSAGE="Update of KVIs failed.' ||
                            '  Will continue processing."';

               pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                              SQLCODE, SQLERRM);
         END;
      END IF;

   END LOOP;

EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                              l_object_name || ': ' || SQLERRM);

END create_merge_selection_batches;


   ------------------------------------------------------------------------
   -- Procedure:
   --    get_syspars
   --
   -- Description:
   --    This procedure selects syspars required for processing.
   --    The values are stored in global record g_r_syspars.  The syspars
   --    are treated like constants so a global record structure is used to
   --    hold the values.
   --
   -- Parameters:
   --    None
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Oracle error occurred.
   --
   -- Called by:
   --    
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    06/22/04 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE get_syspars
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.get_syspars';
   BEGIN
      g_r_syspars.clam_bed_tracked :=
                          pl_common.f_get_syspar('CLAM_BED_TRACKED', 'N');
      g_r_syspars.ds_discrete_selection :=
                          pl_common.f_get_syspar('DS_DISCRETE_SELECTION', 'N');
   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                 l_object_name || ': ' || SQLERRM);
   END get_syspars;


   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ------------------------------------------------------------------------
   -- Procedure:
   --    create_selection_batches
   --
   -- Description:
   --    This procedure creates the selection labor mgmt batches.
   --    It is also used to audit the labor mgmt batch after the selection
   --    batch has been created.  Discrete selection has to be active in
   --    order for batches to be audited.  The auditing logic is in
   --    procedure pl_lm_ds.calculate_ds_time which is only called when
   --    discrete selection is active.
   --
   -- Process flow for creating the selection labor mgmt batch:
   --    1.  If the batch already exists write log message and continue
   --        with the next batch.
   --    2.  Set save point.
   --    3.  If batch created successfully then commit else rollback to
   --        the save point and write log message.
   --    4.  Continue with the next batch.
   --
   -- Parameters:
   --    i_how_generated   - How the routes were generated or how
   --                        to select the batch information.
   --                        The valid values are:
   --                           'r' if a single route generated.
   --                           'g' if group of routes generated.
   --                           'b' for a single batch.
   --                        'b' would usually be used when auditing a batch
   --                        or testing or debugging.
   --    i_generation_key  - Route number if i_how_generated is 'r'.
   --                        Route batch number if i_how_generated is 'g'.
   --                        Floats batch number if i_how_generated is 'b'.
   --    i_audit_only_bln  - Designates to only audit the batch.  The
   --                        processing is the same but only audit records
   --                        are created.  The labor mgmt batch must exist.
   --                        No labor management batches are created or updated.
   --                        or updated.  This parameter is optional.
   --                        The default value is FALSE.
   --                        If this is set to TRUE then this implies discrete
   --                        selection.  Doing this allows a company first
   --                        going on discrete selection to have the selection
   --                        batches created the old way and later to audit
   --                        the same batch using discrete selection.
   --    o_error_detected_bln - Designates if one or more errors occurred
   --                           while processing the batches.  The calling
   --                           program can check the value and if TRUE
   --                           then perform any appropriate processing.
   --                           The error should have been recorded in the
   --                           SWMS_LOG table.  The error could be a warning
   --                           or a fatal error.
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error        - A parameter had a bad value.
   --    User defined exception     - A called object returned an
   --                                 user defined error.
   --    pl_exc.e_database_error    - Any other error.
   --
   -- Called by:
   --    pl_lma.audit_labor_batch
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    02/10/02 prpbcb   Created.
   --                      PL/SQL version of create_selection_batches() in
   --                      crt_lbr_mgmt_bats.pc.  Parameters show_batch_flag
   --                      and print_goal_flag in the PRO*C version were not
   --                      included in this PL/SQL version because they were
   --                      not used in the PRO*C version.
   ---------------------------------------------------------------------------
   PROCEDURE create_selection_batches
                (i_how_generated      IN  VARCHAR2,
                 i_generation_key     IN  VARCHAR2,
                 i_audit_only_bln     IN  BOOLEAN DEFAULT FALSE,
                 o_error_detected_bln OUT BOOLEAN)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                             '.create_selection_batches';

      l_add_merges_bln BOOLEAN;      -- Designates if to include the merges when
                                     -- calculating the number of pieces.
      l_batch_no       floats.batch_no%TYPE;

      l_counter        PLS_INTEGER := 0;  -- Count of batches processed.
      l_dummy          VARCHAR2(1);  -- Work area
      l_errors_detected_count PLS_INTEGER := 0;  -- Count of errors detected
                                            -- when processing the batches. 
      l_how_generated  VARCHAR2(10); -- Populated from i_how_generated
      l_num_pieces     PLS_INTEGER;
      l_num_merges     PLS_INTEGER;
      l_num_s_merges   PLS_INTEGER;
      l_route_no       route.route_no%TYPE;
      l_route_batch_no route.route_batch_no%TYPE;
      l_total_wt       NUMBER;
      l_total_cube     NUMBER;

      e_audit_only_no_lm_batch  EXCEPTION;  -- Only auditing the batches
                                            -- but the batch does not exist.
      e_audit_records_exist     EXCEPTION;  -- Audit records exist for the
                                            -- batch when they should not.
      e_bad_how_generated       EXCEPTION;  -- Raised when i_how_generated has
                                            -- a bad value.
      e_batch_exists            EXCEPTION;  -- Creating batch but the batch
                                            -- already exists.
      e_batch_already_audited   EXCEPTION;  -- Auditing the batch but the
                                            -- batch is already audited.

      -- This cursor counts the number of 'S' merges on a selection batch.
      CURSOR c_s_merges(cp_batch_no IN floats.batch_no%TYPE) IS
         SELECT COUNT(DISTINCT f.merge_loc)
           FROM job_code j,
                sel_method sm,
                float_detail d, 
                floats f,
                route r
          WHERE j.lfun_lbr_func    = 'SL'
            AND j.jbcd_job_code    = sm.sel_lift_job_code
            AND sm.group_no        = f.group_no
            AND sm.method_id       = r.method_id
            AND d.merge_alloc_flag = 'S' 
            AND d.float_no         = f.float_no
            AND f.route_no         = r.route_no
            AND f.batch_no         = cp_batch_no;

      -- This cursor checks if a labor mgmt batch exists
      -- in the batch table.
      CURSOR c_valid_batch(cp_batch_no arch_batch.batch_no%TYPE) IS
         SELECT 'x'
           FROM batch
          WHERE batch_no = cp_batch_no;

   BEGIN

      o_error_detected_bln := FALSE;

      -- Build message to use in debug message.
      IF (i_audit_only_bln) THEN
         l_message := 'TRUE';
      ELSE
         l_message := 'FALSE';
      END IF;

      l_message_param := l_object_name ||
         '(i_how_generated[' || i_how_generated || ']' ||
         ' i_generation_key[' || i_generation_key || ']' ||
         ' i_audit_only_bln[' || l_message || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- i_how_generated can be upper or lower case.
      l_how_generated := LOWER(i_how_generated);

      IF (l_how_generated = 'g') THEN
         l_route_batch_no := i_generation_key;
         l_route_no := NULL;
         l_batch_no := NULL;
      ELSIF (l_how_generated = 'r') THEN
         l_route_no := i_generation_key;
         l_route_batch_no := NULL;
         l_batch_no := NULL;
      ELSIF (l_how_generated = 'b') THEN
         l_batch_no := i_generation_key;
         l_route_batch_no := NULL;
         l_route_no := NULL;
      ELSE
         RAISE e_bad_how_generated;
      END IF;

      -- If not printing pick labels and the company is Central Warehouse(42)
      -- then do not include the merges in the piece count.
      IF (pl_common.f_get_syspar('PRINT_PICK_LABELS', 'Y') = 'N') THEN
         -- IF (pl_common.f_get_company_no = '42') THEN
         IF (f_get_company_no = '42') THEN
            l_add_merges_bln := FALSE;
         ELSE
            l_add_merges_bln := TRUE;
         END IF;
      ELSE
         l_add_merges_bln := TRUE;
      END IF;

      -- Get syspars.
      get_syspars;

      -- Set auditing.
      IF (i_audit_only_bln) THEN
         pl_lma.set_audit_on;    -- Turn on auditing.
      ELSE
         pl_lma.set_audit_off;   -- Turn off auditing.
      END IF;


      -- Create the batch or audit the batch depending on the parameters.
      -- A commit or rollback is made after each batch processed.
      FOR r_sel_batch IN g_c_sel_batch(l_how_generated,
                                       l_route_no,
                                       l_route_batch_no,
                                       l_batch_no, 
                                       g_r_syspars.clam_bed_tracked) LOOP
         BEGIN
            l_counter := l_counter + 1;

            OPEN c_valid_batch(r_sel_batch.lm_batch_no);
            FETCH c_valid_batch INTO l_dummy;

            -- Check for the existence of the batch and if audit records
            -- exist.  Some combinations are not valid.
            IF (c_valid_batch%FOUND) THEN
               -- Labor mgmt batch exists.
               CLOSE c_valid_batch;

               IF (i_audit_only_bln) THEN
                   IF (pl_lma.f_is_batch_audited(r_sel_batch.lm_batch_no)) THEN
                      RAISE e_batch_already_audited;
                   END IF;
               ELSE
                  -- Batch exists and not only auditing so go on to next batch.
                  RAISE e_batch_exists;
               END IF;
            ELSE
               -- Labor mgmt batch does not exist.
               CLOSE c_valid_batch;

               -- If only auditing the batch then the labor mgmt batch must
               -- exist.  Ideally the calling object should have checked this.
               IF (i_audit_only_bln) THEN
                  RAISE e_audit_only_no_lm_batch;
               ELSE
                   -- The batch cannot be audited at this point.  This would
                   -- happen if the batch was deleted but the audit records
                   -- were not.
                   IF (pl_lma.f_is_batch_audited(r_sel_batch.lm_batch_no)) THEN
                      RAISE e_audit_records_exist;
                   END IF;
               END IF;
            END IF;

            SAVEPOINT sp_batch;

            -- Get the number of S merges on the batch.
            OPEN c_s_merges(r_sel_batch.batch_no);
            FETCH c_s_merges INTO l_num_s_merges;
            IF (c_s_merges%NOTFOUND) THEN
               l_num_s_merges := 0;
            END IF;
            CLOSE c_s_merges;

            IF (l_add_merges_bln) THEN
               l_num_pieces := r_sel_batch.num_cases + r_sel_batch.num_splits +
                               r_sel_batch.num_merges;
            ELSE
               l_num_pieces := r_sel_batch.num_cases + r_sel_batch.num_splits;
            END IF;

            l_num_merges := r_sel_batch.num_merges + l_num_s_merges;
            l_total_wt   := TRUNC(r_sel_batch.case_wt + r_sel_batch.split_wt);
            l_total_cube := ROUND(r_sel_batch.case_cube +
                                              r_sel_batch.split_cube);

            -- Create the selection batch if not auditing.
            -- The batches are initially given a status of 'X' which indicates
            -- they are not yet available to sign onto.  The goal/target time
            -- has yet to be calculated.  When the goal/target time is 
            -- calculated the status will be set to 'F'.
            IF (NOT i_audit_only_bln) THEN
               INSERT INTO batch
                       (batch_no,
                        batch_date,
                        status,
                        jbcd_job_code,
                        user_id,
                        ref_no,
                        kvi_cube,
                        kvi_wt,
                        kvi_no_piece,
                        kvi_no_case,
                        kvi_no_split,
                        kvi_no_merge,
                        kvi_no_item,
                        kvi_no_stop,
                        kvi_no_zone,
                        kvi_no_loc,
                        kvi_no_aisle,
                        kvi_no_data_capture,
                        kvi_no_clam_bed_data_capture,
                        kvi_no_pallet,
                        equip_id)
                   VALUES
                       (r_sel_batch.lm_batch_no,
                        TRUNC(SYSDATE),
                        'X',
                        r_sel_batch.job_code,
                        NULL,
                        r_sel_batch.reference,
                        l_total_cube,
                        l_total_wt,
                        l_num_pieces,
                        r_sel_batch.num_cases,
                        r_sel_batch.num_splits,
                        l_num_merges,
                        r_sel_batch.num_items,
                        r_sel_batch.num_stops,
                        r_sel_batch.num_zones,
                        r_sel_batch.num_locs,
                        r_sel_batch.num_aisles,
                        r_sel_batch.num_catch_wt_data_captures +
                        r_sel_batch.num_cool_trk_data_captures +
                        r_sel_batch.num_clam_bed_data_captures,
                NULL,    -- 04/20/06 prpbcb No separate clam bed data capture
                        r_sel_batch.num_floats,
                        r_sel_batch.equip_id);

               -- Create child labor mgmt batches for selection batches that
               -- have more than one route.
               IF (r_sel_batch.num_routes > 1) THEN
                  create_merge_selection_batches(r_sel_batch.batch_no,
                                                 r_sel_batch.lm_batch_no,
                                                 g_r_syspars.clam_bed_tracked);
               END IF;

            END IF;

            -- If discrete selection is active then calculate the values
            -- associated with discrete selection otherwise calculate the
            -- goal/target time using the non-discrete method.
            --
            -- Only auditing the batch implies discrete selection.  Doing this
            -- allows a company first going on discrete selection to have
            -- the selection batches created the old way and later to audit
            -- the same batch using discrete selection.
            IF (   g_r_syspars.ds_discrete_selection = 'Y'
                OR i_audit_only_bln) THEN
               -- Discrete selection will calculate and update(if not only
               -- auditing) the batch with the:
               --    - Case handling time (total time in minutes).
               --    - Split handling time (total time in minutes).
               --    - Travel time (in minutes).

               pl_lm_ds.calc_ds_time(r_sel_batch, i_audit_only_bln);

               IF (NOT i_audit_only_bln) THEN
                  -- Set the goal/target time for the batch.
                  pl_lm_time.load_goaltime(r_sel_batch.lm_batch_no, FALSE,
                                          pl_lmc.ct_ds);
               END IF;
            ELSE
               -- Set the goal/target time for the batch.
               IF (NOT i_audit_only_bln) THEN
                  pl_lm_time.load_goaltime(r_sel_batch.lm_batch_no, FALSE);
               END IF;
            END IF;

            COMMIT;

         EXCEPTION
            WHEN e_batch_exists THEN
               -- Creating batches but the batch exists.
               -- Skip batch and continue with the next batch.
               -- This is not an error.
               pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                  l_message_param || '  Batch ' || r_sel_batch.lm_batch_no ||
                      ' already exists.  Skip batch and continue with the' ||
                      ' next batch.',
                  NULL, NULL);
               l_errors_detected_count := l_errors_detected_count + 1;

            WHEN e_audit_only_no_lm_batch THEN
               -- Only auditing the batch but the labor mgmt batch does not 
               -- exist.  Skip batch and continue with the next batch.
               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                  l_message_param || '  Only auditing batches but labor mgmt' ||
                     ' batch ' || r_sel_batch.lm_batch_no ||
                     ' does not exist.  Skip batch and continue with the' ||
                     ' next batch.',
                  pl_exc.ct_no_lm_batch_found, NULL);

               l_errors_detected_count := l_errors_detected_count + 1;

            WHEN e_audit_records_exist THEN
               -- Creating the batch but audit records exist.  The audit
               -- records will need to be deleted.  Skip batch and continue
               -- with the next batch.
               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                  l_message_param || '  Creating batch ' ||
                      r_sel_batch.lm_batch_no ||
                      ' but audit records exist.  These audit records need' ||
                      ' to be deleted.  Skip batch and continue with the' ||
                      ' next batch.',
                  NULL, NULL);
               l_errors_detected_count := l_errors_detected_count + 1;

            WHEN e_batch_already_audited THEN
               -- Only auditing the batch but the labor mgmt batch already
               -- audited.  Skip batch and continue with the next batch.
               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                  l_message_param || '  Only auditing batches but labor mgmt' ||
                     ' batch ' || r_sel_batch.lm_batch_no ||
                     ' already audited.  Skip batch and continue with the' ||
                     ' next batch.',
                  NULL, NULL);
               l_errors_detected_count := l_errors_detected_count + 1;

            WHEN OTHERS THEN
               ROLLBACK TO SAVEPOINT sp_batch;
               pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                  l_message_param || '  Error processing batch ' ||
                  r_sel_batch.lm_batch_no || '.  Continuing with next batch.',
                  SQLCODE, SQLERRM);
               l_errors_detected_count := l_errors_detected_count + 1;
         END;
      END LOOP;

      IF (l_errors_detected_count > 0) THEN
         o_error_detected_bln := TRUE;
      END IF;

      IF (i_audit_only_bln) THEN
         l_message := l_message_param ||
            '  Auditing batches.  Number of labor mgmt batches processed: ' ||
            TO_CHAR(l_counter) || '.  Number of exceptions/errors: ' ||
            TO_CHAR(l_errors_detected_count) || '.';
      ELSE
         l_message := l_message_param ||
            ' Number of batches processed: ' || TO_CHAR(l_counter) ||
            '.  Number of exceptions/errors: ' ||
            TO_CHAR(l_errors_detected_count) || '.';
      END IF;

      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message, NULL,
                     NULL);

   -- Make sure l_message is set to the desired value.
   EXCEPTION
      WHEN e_bad_how_generated THEN
         -- Parameter i_how_generated has a bad value.
         l_message := l_object_name || ': Bad value in i_how_generated[' ||
                      i_how_generated || ']';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);
      
      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
            -- RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
            --                         l_object_name || ': ' || SQLERRM);
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END create_selection_batches;

END pl_lm_sel;   -- end package body
/

SHOW ERRORS;

SET SCAN ON

