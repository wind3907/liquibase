SET SCAN OFF

PROMPT Create package specification: pl_sos

CREATE OR REPLACE PACKAGE swms.pl_sos
AUTHID CURRENT_USER IS
/*****************************************************************/
/* sccs_id=@(#) src/schema/plsql/pl_sos.sql, swms, swms.9, 11.2 2/11/10 1.38 */
/*****************************************************************/
-----------------------------------------------------------------------------
-- Package Name:
--    pl_sos
--
-- Description:
--    Package for SOS processing on RF
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    06/05/15 bben0556 Symbotic project
--                      Populate SOS_BATCH.PRIORITY from FLOATS.MX_PRIORITY
--                      Modifed cursor "g_c_sel_batch" to selext mx_priority
--                      from the FLOATS table.
--
--                      In the SOS_BATCH insert statement changed
--              pl_matrix_common.get_batch_priority('NORMAL'));
--                     to
--                        r_sel_batch.mx_priority
--
--    10/14/20 bben0556 Brian bent
--                      Project: R44-Jira3222_Sleeve_selection
--
--                      Assign value to "sos_batch.is_sleeve_selection".
--
-----------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Public Cursors
---------------------------------------------------------------------------

CURSOR g_c_sel_batch
           (cp_how_generated           VARCHAR2,
            cp_route_no                VARCHAR2,
            cp_route_batch_no          VARCHAR2,
            cp_batch_no                VARCHAR2,
        cp_chk_status       VARCHAR2)
   IS
SELECT  sm.sel_lift_job_code job_code,
    f.batch_no,
    COUNT (DISTINCT (fd.float_no || fd.stop_no))    num_stops,
    COUNT (DISTINCT (fd.float_no || fd.zone))       num_zones,
    COUNT (DISTINCT fd.float_no)                    num_floats,
    COUNT (DISTINCT fd.src_loc)                     num_locns,
    COUNT (fd.float_no || fd.seq_no ||
        fd.order_Seq || fd.zone || fd.uom)  num_fdqty,
    COUNT (DISTINCT fd.float_no || fd.order_seq ||
        fd.stop_no || fd.order_id ||
        fd.order_line_id)           num_fdtls,
    SUM (DISTINCT f.float_cube)         batch_cube,
    SUM (
        DECODE (fd.merge_alloc_flag,
            'M', 0,
            'S', 0,
            DECODE (fd.uom, 1, fd.qty_alloc, 0)
        )
    )                       num_splits,
       SUM (
        DECODE  (fd.merge_alloc_flag,
            'M', 0,
            'S', 0,
            DECODE (fd.uom,
                2, fd.qty_alloc / NVL(p.spc,1),
                NULL, fd.qty_alloc / NVL(p.spc, 1),
            0)
        )
    )                       num_cases,
    SUM (
        DECODE  (fd.merge_alloc_flag,
            'S', 0,
            'M',
            DECODE (fd.uom,
                2, ROUND(fd.qty_alloc / NVL(p.spc, 1)),
                1, fd.qty_alloc,
                0),
        0)
    )                       num_merges,
    SUM (
        DECODE (fd.merge_alloc_flag,
            'M', 0,
            'S', 0,
            DECODE (fd.uom,
                1, ROUND (fd.qty_alloc * (p.weight / NVL (p.spc,1))),
                         0)
        )
    )                       split_wt,
    SUM (
        DECODE (fd.merge_alloc_flag,
            'M', 0,
            'S', 0,
            DECODE (fd.uom,
                1, fd.qty_alloc * p.split_cube,
            0)
        )
    )                       split_cube,
    SUM (
        DECODE (fd.merge_alloc_flag,
            'M', 0,
            'S', 0,
            DECODE (fd.uom,
                2, fd.qty_alloc * p.weight,
                NULL, fd.qty_alloc * p.weight,
            0)
        )
    )                       case_wt,
    SUM (
        DECODE (fd.merge_alloc_flag,
            'M', 0,
            'S', 0,
            DECODE (fd.uom,
                2, ROUND ((fd.qty_alloc / NVL(p.spc,1)) * p.case_cube),
                NULL, ROUND ((fd.qty_alloc/nvl(p.spc,1))*p.case_cube),
                       0)
        )
    )                       case_cube,
    COUNT (DISTINCT SUBSTR (fd.src_loc, 1, 2)) num_aisles,
    COUNT (DISTINCT fd.prod_id || fd.cust_pref_vendor)  num_items,
    DECODE (COUNT (DISTINCT f.route_no),
        1, MIN (r.route_no),
        'MULTI')                route_no, 
    DECODE (COUNT (DISTINCT f.route_no),
        1, MIN (r.truck_no),
        'MULTI')                truck_no, 
    DECODE (COUNT (DISTINCT f.route_no),
        1, 'N', 'Y')                IsOptimum,
    DECODE (MAX (sm.sel_type), 'UNI', 'Y', 'N') IsUnitized,
    DECODE (MAX (sm.single_stop_flag), 'N', 'N',
        DECODE (MAX (vos.print_box_contents), 'Y', 'Y', 'N')) prt_box_conts,
    NVL (MIN (o.ship_date), MIN (TRUNC (SYSDATE)))  ShipDate, j.whar_area,
    DECODE (COUNT (DISTINCT f.door_no), 1, TO_CHAR (MAX (f.door_no)), MAX ('MUL')) f_door_no,
    r.route_batch_no,
    --
    -- 06/05/2015 Brian Bent  Select the matrix priority from FLOATS.  Used
    -- MIN instead of adding f.mx_priority to the GROUP BY just in case there
    -- was an issue in populating floats.mx_priority and there are inconsistent
    -- values for mx_priority for a batch.
    MIN(f.mx_priority)  mx_priority,
    --
    -- 10/14/2020 Brian Bent  Add selecting f.is_sleeve_selection.
    -- Used MAX instead of adding f.is_sleeve_selection to the GROUP BY just in case there
    -- was an issue in populating floats.is_sleeve_selection and there are inconsistent
    -- values for floats.is_sleeve_selection for a batch.  All the floats for a batch should
    -- have the same value for is_sleeve_selection--Y or N.
    MAX(NVL(f.is_sleeve_selection, 'N')) is_sleeve_selection
    --
  FROM  v_order_proc_syspars vos, job_code j, sel_method sm, pm p, float_detail fd,
    floats f, ordm o, spl_rqst_customer sr, route r
 WHERE  j.lfun_lbr_func    = 'SL' 
   AND  j.jbcd_job_code    = sm.sel_lift_job_code
   AND  sm.group_no        = f.group_no 
   AND  sm.method_id       = r.method_id
   AND  p.prod_id          = fd.prod_id
   AND  p.cust_pref_vendor = fd.cust_pref_vendor
   AND  fd.float_no        = f.float_no 
   AND  f.pallet_pull NOT IN ('D','R', 'Y', 'B')
   AND  f.route_no         = r.route_no
   AND  o.order_id         = fd.order_id
   AND  sr.customer_id (+) = o.cust_id
   AND  ((NVL (fd.sos_status, 'N') = 'N' AND cp_chk_status = 'NEW') OR
     (NVL (fd.sos_status, 'N') != 'N' AND cp_chk_status != 'NEW'))
   AND  fd.qty_alloc > 0
   AND  ( ((('r' = cp_how_generated AND r.route_no       = cp_route_no)
           OR ('g' = cp_how_generated AND r.route_batch_no = cp_route_batch_no)) AND
          (sm.label_queue IN (SELECT user_queue FROM print_queues
                  WHERE directory LIKE '%/sae/%')))
           OR ('b' = cp_how_generated AND to_char (f.batch_no)  = cp_batch_no)
    )
 GROUP BY sm.sel_lift_job_code, f.batch_no, j.whar_area, r.route_batch_no;

CURSOR c_get_multi_trk(sRoute route.route_no%TYPE) IS
    SELECT r.truck_no
    FROM route r
    WHERE route_no = sRoute;

CURSOR c_get_multi_float_rte(sBatch batch.batch_no%TYPE) IS
    SELECT DISTINCT route_no
    FROM floats
    WHERE batch_no = sBatch
    AND   truck_no = 'MULTI';
--  FOR UPDATE OF truck_no NOWAIT;

---------------------------------------------------------------------------
-- Public Type Declarations
---------------------------------------------------------------------------

TYPE tabBatches IS TABLE OF batch.batch_no%TYPE INDEX BY BINARY_INTEGER;

SUBTYPE t_sel_batch_rec  IS g_c_sel_batch%ROWTYPE;

    FUNCTION  F_GetCustSplInstruction (chrOrderId   IN  ordm.order_id%TYPE,
                      intFloatNo    IN  floats.float_no%TYPE)
    RETURN  VARCHAR2;

    PROCEDURE CreateSOSBatches
            (i_how_generated    IN  VARCHAR2,
            i_generation_key    IN  VARCHAR2,
            o_error_detected_bln    OUT BOOLEAN,
            ptbBatches      OUT tabBatches,
            i_chk_status        IN  VARCHAR2 DEFAULT 'NEW');

    PROCEDURE UpdateSOSFloatColumns (intRouteBatchNo        route.route_batch_no%TYPE);

    PROCEDURE UpdateBatchSOSFloatColumns (psBatchNo batch.batch_no%TYPE);

    FUNCTION  F_HighAisle ( chrAisle    IN  VARCHAR2,
                chrArea     IN  VARCHAR2,
                intClrHigh  IN  INTEGER,
                intDryHigh  IN  INTEGER,
                intFrzHigh  IN  INTEGER,
                                chrBatchNo      IN      VARCHAR2)
    RETURN  VARCHAR2;

    FUNCTION  F_HighLoc (   chrSrcLoc   IN  float_Detail.src_loc%TYPE,
                intFloatNo  IN  float_Detail.float_no%TYPE,
                intUOM      IN  float_Detail.UOM%TYPE,
                chrArea     IN  VARCHAR2,
                intClrHigh  IN  INTEGER,
                intDryHigh  IN  INTEGER,
                intFrzHigh  IN  INTEGER,
                                chrBatchNo      IN      VARCHAR2)
    RETURN  VARCHAR2;

    FUNCTION get_uom_order(
        psBatch IN batch.batch_no%TYPE,
        psSeq   IN float_detail.order_seq%TYPE,
        psLoc   IN float_detail.src_loc%TYPE)
    RETURN NUMBER;

    PROCEDURE UpdateSOSFDColumns (intRouteBatchNo IN route.route_batch_no%TYPE);

    PROCEDURE UpdateBatchSOSFDColumns (psBatchNo IN batch.batch_no%TYPE);

    PROCEDURE PopulateLASTruck (intRouteBatchNo        route.route_batch_no%TYPE);

    PROCEDURE PopulateLASPallet (intRouteBatchNo        route.route_batch_no%TYPE,
                    psRoute     route.route_no%TYPE,
                    psTruck     route.truck_no%TYPE);

    PROCEDURE SetupSOSData (intRouteBatchNo IN route.route_batch_no%TYPE);

    PROCEDURE SetupBatchSOSData (psBatchNo  IN batch.batch_no%TYPE);

    PROCEDURE SetupSLSData (intRouteBatchNo IN route.route_batch_no%TYPE);

    PROCEDURE Create_ISTART (pUserId    batch.user_id%TYPE,
                 pBatchNo   batch.batch_no%TYPE,
                 pError     OUT INTEGER);

    FUNCTION UseCrossAisle (PrevDir     INTEGER,
                PrevAisle   INTEGER,
                PrevSlot    INTEGER,
                curDir      INTEGER,
                curAisle    INTEGER,
                curSlot     INTEGER)
    RETURN VARCHAR2;

    FUNCTION F_GetShortBatchStatus (pShortBatchNo  IN sos_batch.batch_no%TYPE)
    RETURN  VARCHAR2;

    FUNCTION get_picked_pieces(psBatch  IN sos_batch.batch_no%TYPE)
    RETURN NUMBER;

    FUNCTION get_batch_cube(psBatch IN batch.batch_no%TYPE)
    RETURN NUMBER;

    FUNCTION get_batch_wt(psBatch IN batch.batch_no%TYPE)
    RETURN NUMBER;

    FUNCTION get_route_info(
        psBatch IN batch.batch_no%TYPE,
        psType  IN VARCHAR2 DEFAULT 'B')
    RETURN VARCHAR2;

    PROCEDURE create_SYS04_addorder (i_batch_no  IN  VARCHAR2,
                                     o_status    OUT  NUMBER); 

    PROCEDURE create_SYS15_wave_status (i_batch_no      IN     VARCHAR2,
                                        i_wave_status   IN     VARCHAR2,
                                        io_wave_number  IN OUT NUMBER,
                                        o_status        OUT    NUMBER); 
    
    PROCEDURE process_finish_good_shorts (i_batch_no IN sos_short.batch_no%TYPE);
    
    PROCEDURE create_sos_short (
        i_qty_short IN sos_short.qty_short%TYPE,
        i_batch_no IN sos_short.batch_no%TYPE,
        i_orderseq IN sos_short.orderseq%TYPE,
        i_location IN sos_short.location%TYPE,
        i_picktype IN sos_short.picktype%TYPE,
        i_float_no IN sos_short.float_no%TYPE,
        i_float_detail_seq_no IN sos_short.float_detail_seq_no%TYPE);

END pl_sos;
/
CREATE OR REPLACE
PACKAGE BODY swms.pl_sos
IS
    ---------------------------------------------------------------------------
    -- Private Global Variables
    ---------------------------------------------------------------------------
    gl_pkg_name   VARCHAR2(20) := 'pl_sos';   -- Package name.  Used in
    C_SUCCESS           CONSTANT NUMBER       := 0;
    C_FAILURE           CONSTANT NUMBER       := 1; 
                          -- error messages.
    FUNCTION  F_GetCustSplInstruction (chrOrderId   IN  ordm.order_id%TYPE,
                      intFloatNo    IN  floats.float_no%TYPE)
    RETURN  VARCHAR2 IS
        lDescription    cust_pallet_types.Description%TYPE;
    BEGIN
        SELECT  DECODE (f.comp_code,
                'C', cp_clr.description,
                'D', cp_dry.description,
                'F', cp_frz.description)
          INTO  lDescription
          FROM  ordm om,
            floats f,
            cust_pallet_types cp_clr,
            cust_pallet_types cp_dry,
            cust_pallet_types cp_frz
         WHERE  om.order_id = chrOrderId
           AND  f.float_no = intFloatNo
           AND  cp_clr.pallet_code (+) = om.clr_special
           AND  cp_dry.pallet_code (+) = om.dry_special
           AND  cp_frz.pallet_code (+) = om.frz_special;
        RETURN lDescription;
    END;

    FUNCTION  F_HighAisle ( chrAisle    IN  VARCHAR2,
                chrArea     IN  VARCHAR2,
                intClrHigh  IN  INTEGER,
                intDryHigh  IN  INTEGER,
                intFrzHigh  IN  INTEGER,
                                chrBatchNo      IN      VARCHAR2)
    RETURN  VARCHAR2 IS
        lHighAisle VARCHAR2 (3) := chrAisle;
        lTotCases NUMBER (5) := 0;
        lDone   BOOLEAN := FALSE;
        CURSOR c_get_indv_loc_short IS
            SELECT  src_loc,
                NVL(SUM(NVL(fd_qty_short, 0)), 0) q
            FROM    t_curr_batch_short v
            WHERE   batch_no = chrBatchNo
            AND SUBSTR(src_loc, 1, 2) = chrAisle
            AND uom <> 1
            GROUP BY  src_loc, prod_id;
        CURSOR c_get_indv_loc IS
            SELECT  src_loc,
                NVL(SUM(NVL(qty_alloc/spc, 0)), 0) q
            FROM    t_curr_batch v
            WHERE   batch_no = chrBatchNo
            AND SUBSTR(src_loc, 1, 2) = chrAisle
            AND uom <> 1
            GROUP BY  src_loc, prod_id;
    BEGIN
        IF SUBSTR(chrBatchNo, 1, 1) = 'S' THEN
            SELECT  NVL(SUM(NVL(fd_qty_short, 0)), 0)
              INTO  lTotCases
              FROM  t_curr_batch_short
             WHERE  batch_no = chrBatchNo
               AND  substr(src_loc,1,2) = chrAisle
               AND  uom <> 1
              GROUP BY  substr(src_loc,1,2);
        ELSE
            SELECT  NVL(SUM(NVL(qty_alloc/spc, 0)), 0)
              INTO  lTotCases
              FROM  t_curr_batch
             WHERE  batch_no = chrBatchNo
               AND  substr(src_loc,1,2) = chrAisle
               AND  uom <> 1
              GROUP BY  substr(src_loc,1,2);
        END IF;

        IF (chrArea = 'C' AND
            lTotCases >= intClrHigh AND
            intClrHigh != -1) OR
           (chrArea = 'D' AND
            lTotCases >= intDryHigh AND
            intDryHigh != -1) OR
           (chrArea = 'F' AND
            lTotCases >= intFrzHigh AND
            intFrzHigh != -1) THEN
          IF SUBSTR(chrBatchNo, 1, 1) = 'S' THEN
            FOR cgils IN c_get_indv_loc_short LOOP
              IF (chrArea = 'C' AND
              cgils.q >= intClrHigh AND
              intClrHigh != -1) OR
             (chrArea = 'D' AND
              cgils.q >= intDryHigh AND
              intDryHigh != -1) OR
             (chrArea = 'F' AND
              cgils.q >= intFrzHigh AND
              intFrzHigh != -1) THEN
            lHighAisle := lHighAisle || '*';
            lDone := TRUE;
              END IF;
              EXIT WHEN lDone = TRUE;
            END LOOP;
          ELSE
            FOR cgis IN c_get_indv_loc LOOP
              IF (chrArea = 'C' AND
              cgis.q >= intClrHigh AND
              intClrHigh != -1) OR
             (chrArea = 'D' AND
              cgis.q >= intDryHigh AND
              intDryHigh != -1) OR
             (chrArea = 'F' AND
              cgis.q >= intFrzHigh AND
              intFrzHigh != -1) THEN
            lHighAisle := lHighAisle || '*';
            lDone := TRUE;
              END IF;
              EXIT WHEN lDone = TRUE;
            END LOOP;
          END IF;
        END IF;
        RETURN lHighAisle;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN chrAisle;
    END F_HighAisle;

    FUNCTION  F_HighLoc (   chrSrcLoc   IN  float_Detail.src_loc%TYPE,
                intFloatNo  IN  float_Detail.float_no%TYPE,
                intUOM      IN  float_Detail.UOM%TYPE,
                chrArea     IN  VARCHAR2,
                intClrHigh  IN  INTEGER,
                intDryHigh  IN  INTEGER,
                intFrzHigh  IN  INTEGER,
                                chrBatchNo      IN      VARCHAR2)
    RETURN  VARCHAR2 IS
        lHighLoc VARCHAR2 (11) := chrSrcLoc;
        lTotCases NUMBER (5) := 0;
    BEGIN
        IF (intUOM != 1) THEN
        BEGIN
            IF SUBSTR(chrBatchNo, 1, 1) = 'S' THEN
                SELECT  NVL(SUM(NVL(fd_qty_short, 0)), 0)
                  INTO  lTotCases
                  FROM  t_curr_batch_short
                 WHERE  batch_no = chrBatchNo
                   AND  src_loc = chrSrcLoc
                   AND  uom <> 1
                  GROUP BY  prod_id;
            ELSE
                SELECT  NVL(SUM(NVL(qty_alloc/spc,0)), 0)
                  INTO  lTotCases
                  FROM  t_curr_batch
                 WHERE  batch_no = chrBatchNo
                   AND  src_loc = chrSrcLoc
                   AND  uom <> 1
                  GROUP BY  prod_id;
            END IF;

            IF (chrArea = 'C' AND lTotCases >= intClrHigh AND intClrHigh != -1)
            OR (chrArea = 'D' AND lTotCases >= intDryHigh AND intDryHigh != -1)
            OR (chrArea = 'F' AND lTotCases >= intFrzHigh AND intFrzHigh != -1)
            THEN
                lHighLoc := lHighLoc || '*';
            END IF;
        END;
        END IF;
        RETURN lHighLoc;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN chrSrcLoc;
    END F_HighLoc;

    FUNCTION get_uom_order(
        psBatch IN batch.batch_no%TYPE,
        psSeq   IN float_detail.order_seq%TYPE,
        psLoc   IN float_detail.src_loc%TYPE)
    RETURN NUMBER IS
        iUom        float_detail.uom%TYPE := NULL;
        iSeqCnt     NUMBER := 0;
        iPrevSeq    float_detail.order_seq%TYPE := NULL;
        iNewUomOrd  NUMBER := 0;
        blnFound    BOOLEAN := FALSE;
        CURSOR c_get_info_short IS
            SELECT DISTINCT fh_order_seq order_seq, uom
            FROM float_hist
            WHERE short_batch_no = psBatch
            AND   src_loc = psLoc
            ORDER BY fh_order_seq, uom;
        CURSOR c_get_uom_rec_short IS
            SELECT uom, COUNT(fh_order_seq) seqcnt
            FROM float_hist
            WHERE short_batch_no = psBatch
            AND   src_loc = psLoc
            GROUP BY uom
            ORDER BY uom;
        CURSOR c_get_info IS
            SELECT DISTINCT d.order_seq, d.uom
            FROM floats f, float_detail d
            WHERE f.float_no = d.float_no
            AND   TO_CHAR(f.batch_no) = psBatch
            AND   d.src_loc = psLoc
            ORDER BY d.uom desc, d.order_seq;
        CURSOR c_get_uom_rec IS
            SELECT d.uom, COUNT(d.order_seq) seqcnt
            FROM floats f, float_detail d
            WHERE f.float_no = d.float_no
            AND   TO_CHAR(f.batch_no) = psBatch
            AND   d.src_loc = psLoc
            GROUP BY d.uom
            ORDER BY d.uom;
    BEGIN
        IF SUBSTR(psBatch, 1, 1) = 'S' THEN
            FOR cgurs IN c_get_uom_rec_short LOOP
                iUom := cgurs.uom;
                iSeqCnt := iSeqCnt + cgurs.seqcnt;
            END LOOP;
            IF iSeqCnt = 1 THEN
                RETURN iUom;
            END IF;
            FOR cgi IN c_get_info_short LOOP
                IF cgi.order_seq = psSeq THEN
                    iNewUomOrd := iNewUomOrd + 1;
                    blnFound := TRUE;
                    EXIT;
                ELSE
                    IF cgi.order_seq <> NVL(iPrevSeq, 0)
                    THEN
                        iNewUomOrd := iNewUomOrd + 1;
                    END IF;
                END IF;
                IF cgi.order_seq <> NVL(iPrevSeq, 0) THEN
                    iPrevSeq := cgi.order_seq;
                END IF;
            END LOOP;
        ELSE
            FOR cgur IN c_get_uom_rec LOOP
                iUom := cgur.uom;
                iSeqCnt := iSeqCnt + cgur.seqcnt;
            END LOOP;
            IF iSeqCnt = 1 THEN
                RETURN iUom;
            END IF;
            FOR cgi IN c_get_info LOOP
                IF cgi.order_seq = psSeq THEN
                    iNewUomOrd := iNewUomOrd + 1;
                    blnFound := TRUE;
                    EXIT;
                ELSE
                    IF cgi.order_seq <> NVL(iPrevSeq, 0) THEN
                        iNewUomOrd := iNewUomOrd + 1;
                    END IF;
                END IF;
                IF cgi.order_seq <> NVL(iPrevSeq, 0) THEN
                    iPrevSeq := cgi.order_seq;
                END IF;
            END LOOP;
        END IF;
        IF blnFound THEN
            RETURN iNewUomOrd;
        ELSE
            RETURN TO_NUMBER(NVL(iPrevSeq, 999));
        END IF;
    END;

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

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ------------------------------------------------------------------------
   -- Procedure:
   --    CreateSOSBatches
   --
   -- Description:
   --    This procedure creates Batch Information for SOS.
   --    Labor management batches are not reliable in the sense that they
   --    can be deleted from the system independent of order processing.
   --    This procedure populates a new table called sos_batch with
   --    information relevant to SOS.
   --
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
   --    o_error_detected_bln - Designates if one or more errors occurred
   --                           while processing the batches.  The calling
   --                           program can check the value and if TRUE
   --                           then perform any appropriate processing.
   --                           The error should have been recorded in the
   --                           SWMS_LOG table.  The error could be a warning
   --                           or a fatal error.
   --
   PROCEDURE CreateSOSBatches
            (i_how_generated    IN  VARCHAR2,
            i_generation_key    IN  VARCHAR2,
            o_error_detected_bln    OUT BOOLEAN,
            ptbBatches      OUT tabBatches,
            i_chk_status        IN  VARCHAR2 DEFAULT 'NEW')
   IS
      TYPE tabBatches IS TABLE OF batch.batch_no%TYPE INDEX BY BINARY_INTEGER;
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                             '.CreateSOSBatches';

      l_add_merges_bln BOOLEAN;      -- Designates if to include the merges when
                                     -- calculating the number of pieces.
      l_batch_no       sos_batch.batch_no%TYPE;

      l_counter        PLS_INTEGER := 0;  -- Count of batches processed.
      l_errors_detected_count PLS_INTEGER := 0;  -- Count of errors detected
                                            -- when processing the batches. 
      l_how_generated  VARCHAR2(10); -- Populated from i_how_generated
      l_num_pieces     PLS_INTEGER;
      l_num_merges     PLS_INTEGER;
      l_num_s_merges   PLS_INTEGER;
      l_route_no       route.route_no%TYPE;
      l_route_batch_no route.route_batch_no%TYPE;
    lCount      PLS_INTEGER := 0;
    lBatchCount VARCHAR2 (12) := NULL;
    lPooledBy   VARCHAR2 (10) := NULL;
    lReservedBy VARCHAR2 (10) := NULL;
    sBatchNo    sos_batch.batch_no%TYPE;
    sTruck      route.truck_no%TYPE := NULL;
    iTrkCnt     NUMBER := 0;
    sTmp        batch.batch_no%TYPE := NULL;
    tbBatches   tabBatches;
    itbBatchesCnt   NUMBER := 0;
    iMergeCseQty    NUMBER := 0;
    iMergeSplQty    NUMBER := 0;
    e_bad_how_generated EXCEPTION;
    iCube       NUMBER := 0;
    l_sos_batch_to_matrix  VARCHAR2(1);       --Matrix Changes
    l_mx_batch_present  BOOLEAN;           --Matrix changes
    l_matrix_enable     BOOLEAN;           --Matrix Changes
    io_wave_number      NUMBER;            --Matrix Changes
    o_status            NUMBER;            --Matrix Changes
      -- This cursor counts the number of 'S' merges on a selection batch.
      CURSOR c_s_merges(cp_batch_no VARCHAR2) IS
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
            AND to_char (f.batch_no) = cp_batch_no;

      -- This cursor checks if a labor mgmt batch exists
      -- in the batch table.
      CURSOR c_valid_batch(cp_batch_no arch_batch.batch_no%TYPE) IS
         SELECT 'x'
           FROM batch
          WHERE batch_no = cp_batch_no;

      CURSOR c_get_trk(sValue   batch.batch_no%TYPE, sType VARCHAR2) IS
    SELECT DISTINCT r.route_no, r.truck_no
    FROM route r, floats f
    WHERE r.route_no = f.route_no
    AND   (((sType = 'b') AND (f.batch_no = sValue)) OR
           ((sType = 'g') AND (r.route_batch_no = TO_NUMBER(sValue))));
      CURSOR c_get_merge_qty(cp_batch arch_batch.batch_no%TYPE,
                 cp_uom   float_detail.uom%TYPE) IS
    SELECT NVL(SUM(NVL(fd.qty_alloc, 0) /
            DECODE(cp_uom, 1, 1, p.spc)), 0)
    FROM floats f, float_detail fd, pm p
    WHERE f.float_no = fd.float_no
    AND   TO_CHAR(f.batch_no) = cp_batch
    AND   fd.merge_alloc_flag = 'M'
    AND   fd.uom = cp_uom
    AND   fd.qty_alloc > 0
    AND   fd.prod_id = p.prod_id
    AND   fd.cust_pref_vendor = p.cust_pref_vendor;
      CURSOR c_get_door_info(cp_batch arch_batch.batch_no%TYPE) IS
    SELECT fl_method_id, fl_sel_type, door_no
    FROM floats
    WHERE TO_CHAR(batch_no) = cp_batch
    AND   pallet_pull = 'N';
      CURSOR c_get_route_info(cp_batch arch_batch.batch_no%TYPE,
        cp_truck route.truck_no%TYPE) IS
    SELECT DISTINCT s.sel_type, r.method_id, 
           DECODE (f.door_area, 'C', r.c_door,
            'D', r.d_door, 'F', r.f_door) door_no
    FROM sel_method s, route r, floats f
    WHERE   TO_CHAR(f.batch_no) = cp_batch
    AND f.truck_no = cp_truck
    AND s.method_id = r.method_id
    AND s.group_no = f.group_no
    AND r.route_no = f.route_no
    AND r.truck_no = f.truck_no;
   BEGIN

    o_error_detected_bln := FALSE;
    l_mx_batch_present := FALSE;
    
    -- i_how_generated can be upper or lower case.
dbms_output.put_line ('Entered 1');
    l_how_generated := LOWER(i_how_generated);

    pl_log.ins_msg('INFO', l_object_name, 'How to generated [' ||
        l_how_generated || '] key[' || i_generation_key || ']',
        NULL, NULL);
    pl_text_log.ins_msg('I', l_object_name,
        'how_generated [' || l_how_generated ||
        l_how_generated || '] key[' || i_generation_key || ']',
        NULL, NULL);
    IF (l_how_generated = 'g') THEN
        l_route_batch_no := i_generation_key;
        l_route_no := NULL;
        l_batch_no := NULL;
    ELSIF (l_how_generated = 'r') THEN
        l_route_no := i_generation_key;
        l_route_batch_no := NULL;
        l_batch_no := NULL;
    ELSIF (l_how_generated = 'b') THEN
    BEGIN
dbms_output.put_line ('Entered 1');
        l_batch_no := i_generation_key;
        l_route_batch_no := NULL;
        l_route_no := NULL;
dbms_output.put_line ('before Select Max');
        sBatchNo := i_generation_key;
        SELECT  REPLACE (MAX (batch_no), sBatchNo, NULL),
            MAX (pooled_by), MAX (reserved_by),
            COUNT (0)
          INTO  lBatchCount, lPooledBy, lReservedBy,
            lCount
          FROM  sos_batch
         WHERE  batch_no LIKE sBatchNo || '%';
        pl_log.ins_msg('INFO', l_object_name, 'Gen by batch batch[' ||
            sBatchNo || '] count[' || lBatchCount ||
            '] pooledby[' || lPooledBy || '] rsrvby[' ||
            lReservedBy || '] total[' || TO_CHAR(lCount) || ']',
            NULL, NULL);
        IF (lBatchCount IS NOT NULL) THEN
        BEGIN
dbms_output.put_line ('before Update sos_batch, Batch Count = ' || lBatchCount);
            UPDATE  sos_batch
               SET  status = 'C',
                batch_no = batch_no || lBatchCount
             WHERE  batch_no = sBatchNo;
            pl_log.ins_msg('INFO', l_object_name,
                'Complete batch[' || sBatchNo || '] to [' ||
                sBatchNo || lBatchCount ||
                '] #rows[' || TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL);
            
        END;
        END IF;

    END;
    ELSE
        RAISE e_bad_how_generated;
    END IF;
dbms_output.put_line ('before use loop g_c_sel_batch: ' || sBatchNo);
    
    
    FOR r_sel_batch
    IN g_c_sel_batch
        (l_how_generated, l_route_no,
         l_route_batch_no, l_batch_no, i_chk_status)
    LOOP
dbms_output.put_line ('inside use loop g_c_sel_batch: ' || sBatchNo || '*'||
    to_char(lCount));
    BEGIN
        pl_log.ins_msg('WARN',
            l_object_name,
            'g_c_sel_batch how_generated [' ||
            l_how_generated || '] key[' || i_generation_key ||
            '] batch [' || r_sel_batch.batch_no || ']',
            NULL, NULL);
        pl_text_log.ins_msg('W',
            l_object_name,
            'g_c_sel_batch how_generated [' ||
            l_how_generated || '] key[' || i_generation_key ||
            '] batch [' || r_sel_batch.batch_no || ']',
            NULL, NULL);

        SAVEPOINT sp_batch;

        -- Get the number of S merges on the batch.
        OPEN c_s_merges(r_sel_batch.batch_no);
        FETCH c_s_merges INTO l_num_s_merges;
        IF (c_s_merges%NOTFOUND) THEN
            l_num_s_merges := 0;
        END IF;
        CLOSE c_s_merges;

        l_num_merges := r_sel_batch.num_merges + l_num_s_merges;

        iMergeSplQty := 0;
        OPEN c_get_merge_qty(r_sel_batch.batch_no, 1);
        FETCH c_get_merge_qty INTO iMergeSplQty;
        CLOSE c_get_merge_qty;

        iMergeCseQty := 0;
        OPEN c_get_merge_qty(r_sel_batch.batch_no, 2);
        FETCH c_get_merge_qty INTO iMergeCseQty;
        CLOSE c_get_merge_qty;

        IF ((l_how_generated != 'b')
        OR ((l_how_generated = 'b') AND (lBatchCount IS NOT NULL OR lCount = 0)))
        THEN
            iCube := r_sel_batch.batch_cube;
            BEGIN
                SELECT NVL(SUM(NVL(float_cube, 0)), 0)
                INTO iCube
                FROM floats f
                WHERE   batch_no = r_sel_batch.batch_no
                AND pallet_pull NOT IN ('D','R', 'Y', 'B')
                AND float_no IN (SELECT DISTINCT float_no
                        FROM float_detail
                        WHERE   float_no = f.float_no
                        AND NVL (sos_status, 'N') =
                                'N');
            EXCEPTION
                WHEN OTHERS THEN
                    iCube := r_sel_batch.batch_cube;
            END;
            
            ------------Matrix Changes Start-------------   
            l_sos_batch_to_matrix := pl_matrix_common.sos_batch_to_matrix_yn(r_sel_batch.batch_no);  
            ------------Matrix Changes End-------------
    
dbms_output.put_line ('before Insert sos_batch');
            INSERT INTO sos_batch
                (batch_no,
                batch_date,
                job_code,
                status,
                route_no,
                truck_no,
                no_of_floats,
                no_of_stops,
                no_of_cases,
                no_of_splits,
                no_of_merges,
                no_of_fdtls,
                no_of_fdqty,
                no_of_items,
                no_of_aisles,
                no_of_zones,
                no_of_locns,
                is_unitized,
                is_optimum,
                ship_date,
                batch_cube,
                prt_box_conts,
                area,
                pooled_by,
                reserved_by,
                door_no,
                route_batch_no,
                priority,                                    /*Matrix Change- Added Priority*/
                is_sleeve_selection)                         /* 01/15/2020 Brian Bent Added */
            VALUES
                (r_sel_batch.batch_no,
                SYSDATE,
                r_sel_batch.job_code,
                DECODE (lBatchCount, NULL, DECODE(l_sos_batch_to_matrix, 'Y', 'X', 'F'),
                    DECODE (lPooledBy, NULL, DECODE(l_sos_batch_to_matrix, 'Y', 'X', 'F'), 'P')),    /*Matrix Changes - Status F to X*/
                r_sel_batch.route_no,
                r_sel_batch.truck_no,
                r_sel_batch.num_floats,
                r_sel_batch.num_stops,
                r_sel_batch.num_cases + iMergeCseQty,
                r_sel_batch.num_splits + iMergeSplQty,
                l_num_merges,
                r_sel_batch.num_fdtls,
                r_sel_batch.num_fdqty,
                r_sel_batch.num_items,
                r_sel_batch.num_aisles,
                r_sel_batch.num_zones,
                r_sel_batch.num_locns,
                r_sel_batch.IsUnitized,
                r_sel_batch.IsOptimum,
                r_sel_batch.ShipDate,
                iCube,
                r_sel_batch.prt_box_conts,
                r_sel_batch.whar_area,
                lPooledBy,
                lReservedBy,
                r_sel_batch.f_door_no,
                r_sel_batch.route_batch_no,
                r_sel_batch.mx_priority,
                r_sel_batch.is_sleeve_selection);                        /* 01/15/2020 Brian Bent Added */
                
            pl_log.ins_msg('INFO', l_object_name,
                'Add to SOS_BATCH gen[' ||
                l_how_generated || '] batch[' ||
                r_sel_batch.batch_no || '] jobcode[' ||
                r_sel_batch.job_code || '] route[' ||
                r_sel_batch.route_no || '] routeB[' ||
                TO_CHAR(r_sel_batch.route_batch_no) ||
                '] truck[' ||
                r_sel_batch.truck_no || '] #merges[' ||
                TO_CHAR(l_num_merges) || '] #floats[' ||
                TO_CHAR(r_sel_batch.num_floats) || '] ship[' ||
                r_sel_batch.ShipDate || '] area[' ||
                r_sel_batch.whar_area || '] counter[' ||
                TO_CHAR(l_counter) ||
                '] #rows[' || TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL);

            pl_text_log.ins_msg('W',
                l_object_name,
                'Add to SOS_BATCH gen[' ||
                l_how_generated || '] batch[' ||
                r_sel_batch.batch_no || '] jobcode[' ||
                r_sel_batch.job_code || '] route[' ||
                r_sel_batch.route_no || '] routeB[' ||
                TO_CHAR(r_sel_batch.route_batch_no) ||
                '] truck[' ||
                r_sel_batch.truck_no || '] #merges[' ||
                TO_CHAR(l_num_merges) || '] #floats[' ||
                TO_CHAR(r_sel_batch.num_floats) || '] ship[' ||
                r_sel_batch.ShipDate || '] area[' ||
                r_sel_batch.whar_area || '] counter[' ||
                TO_CHAR(l_counter) ||
                '] #rows[' || TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL);
                
                --------------Matrix Changes Start ------------------------

                Pl_Text_Log.Ins_Msg('I', l_object_name, 'After Insert into SOS_BATCH l_sos_batch_to_matrix ['||l_sos_batch_to_matrix||']  batch_no ['||r_sel_batch.batch_no||']', NULL, NULL);
                
                IF l_sos_batch_to_matrix = 'Y' THEN
                    -- Added SYS15 Started message to Symbotic

                    l_mx_batch_present := TRUE;
                    Pl_Text_Log.Ins_Msg('I', l_object_name, 'Before calling  create_SYS15_wave_status l_sos_batch_to_matrix ['||l_sos_batch_to_matrix||']  batch_no ['||r_sel_batch.batch_no||']', NULL, NULL);

                    create_SYS15_wave_status (r_sel_batch.batch_no, 'STARTED', io_wave_number, o_status);

                    Pl_Text_Log.Ins_Msg('I', l_object_name, 'After calling  create_SYS15_wave_status O_Status ['||o_status||']  batch_no ['||r_sel_batch.batch_no||']', Null, Null);
                    IF o_status = C_FAILURE THEN
                        pl_log.ins_msg ('FATAL', l_object_name,
                                        l_message_param || '  Error Sending SYS15 to Symbotic batch for batch_no ' ||
                                        r_sel_batch.batch_no || '.  Continuing with next batch.',
                                        SQLCODE, SQLERRM);

                    END IF;             

                    -- End: Added SYS15 Started message to Symbotic

                    Pl_Text_Log.Ins_Msg('I', l_object_name, 'Before calling  create_SYS04_addorder l_sos_batch_to_matrix ['||l_sos_batch_to_matrix||']  batch_no ['||r_sel_batch.batch_no||']', NULL, NULL);

                    create_SYS04_addorder (r_sel_batch.batch_no, o_status);

                    Pl_Text_Log.Ins_Msg('I', l_object_name, 'After calling  create_SYS04_addorder O_Status ['||o_status||']  batch_no ['||r_sel_batch.batch_no||']', Null, Null);
                    IF o_status = C_FAILURE THEN
                        pl_log.ins_msg ('FATAL', l_object_name,
                                        l_message_param || '  Error Sending SYS04 to Symbotic batch for batch_no ' ||
                                        r_sel_batch.batch_no || '.  Continuing with next batch.',
                                        SQLCODE, SQLERRM);

                    END IF;             
                END IF;
                --------------Matrix Changes End -------------------------
        ELSE
            UPDATE  sos_batch
               SET  status = 'F',
                picked_by = NULL,
                reserved_by = NULL,
                pooled_by = NULL
             WHERE  batch_no = sBatchNo;
            pl_log.ins_msg('INFO', l_object_name,
                'Update SOS_BATCH gen[' ||
                l_how_generated || '] batch[' ||
                sBatchNo || '] to Future, counter[' ||
                TO_CHAR(l_counter) ||
                '] #rows[' || TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL);
            pl_text_log.ins_msg('W',
                l_object_name,
                'Update SOS_BATCH gen[' ||
                l_how_generated || '] batch[' ||
                sBatchNo || '] to Future, counter[' ||
                TO_CHAR(l_counter) ||
                '] #rows[' || TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL);
        END IF;
        l_counter := l_counter + 1;
        
        ptbBatches(l_counter):= r_sel_batch.batch_no;

        iTrkCnt := 0;
        sTruck := NULL;
        IF l_how_generated = 'r' THEN
        BEGIN
            SELECT truck_no INTO sTruck
            FROM route
            WHERE route_no = l_route_no;
        EXCEPTION
            WHEN OTHERS THEN
                sTruck := r_sel_batch.truck_no;
        END;
        ELSE
            IF l_how_generated = 'g' THEN
                sTmp := TO_CHAR(l_route_batch_no);
            ELSE
                sTmp := l_batch_no;
            END IF;
            FOR cgt IN c_get_trk(sTmp, l_how_generated) LOOP
                iTrkCnt := iTrkCnt + 1;
                sTruck := cgt.truck_no;
            END LOOP;
            IF iTrkCnt > 1 THEN
                sTruck := r_sel_batch.truck_no;
            END IF;
        END IF;
        pl_log.ins_msg('INFO', l_object_name,
            'Gen [' || l_how_generated || '] truck[' ||
            sTruck || '] cnt[' || TO_CHAR(iTrkCnt) || ']',
            NULL, NULL);

        BEGIN
            UPDATE floats
               SET  ship_date = r_sel_batch.ShipDate,
                truck_no = sTruck
             WHERE  batch_no = r_sel_batch.batch_no;
            pl_log.ins_msg('INFO', l_object_name,
                'Update FLOATS gen [' || l_how_generated ||
                '] batch[' || r_sel_batch.batch_no ||
                '] truck[' || sTruck || '] ship[' ||
                r_sel_batch.ShipDate || '] #rows[' ||
                TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL);
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        IF sTruck IS NOT NULL THEN
          FOR cgdi IN c_get_door_info(r_sel_batch.batch_no) LOOP
            IF cgdi.fl_method_id IS NULL OR
               cgdi.fl_sel_type IS NULL OR
               cgdi.door_no IS NULL THEN
              FOR cgri IN c_get_route_info(
                r_sel_batch.batch_no, sTruck) LOOP
            BEGIN
              UPDATE floats
              SET fl_method_id = cgri.method_id,
                  fl_sel_type = cgri.sel_type,
                  door_no = cgri.door_no
              WHERE TO_CHAR(batch_no) = r_sel_batch.batch_no
              AND   pallet_pull = 'N';
              pl_log.ins_msg('INFO', l_object_name,
                'CreateSOSBatches Update FLOATS gen [' ||
                l_how_generated ||
                '] batch[' || r_sel_batch.batch_no ||
                '] truck[' || sTruck || '] met[' ||
                cgdi.fl_method_id || '/' || cgri.method_id ||
                ']' || cgdi.fl_sel_type || '/' ||
                cgri.sel_type || ']' ||
                cgdi.door_no || '/' || cgri.door_no || ']' ||
                ' #rows[' ||
                TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL);
              pl_text_log.ins_msg('I', l_object_name,
                'CreateSOSBatches Update FLOATS gen [' ||
                l_how_generated ||
                '] batch[' || r_sel_batch.batch_no ||
                '] truck[' || sTruck || '] met[' ||
                cgdi.fl_method_id || '/' || cgri.method_id ||
                ']' || cgdi.fl_sel_type || '/' ||
                cgri.sel_type || ']' ||
                cgdi.door_no || '/' || cgri.door_no || ']' ||
                ' #rows[' ||
                TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL);
            EXCEPTION
              WHEN OTHERS THEN
                pl_log.ins_msg('WARN', l_object_name,
                'CreateSOSBatches Fail to upd FLOATS gen [' ||
                l_how_generated ||
                '] batch[' || r_sel_batch.batch_no ||
                '] truck[' || sTruck || '] met[' ||
                cgdi.fl_method_id || '/' || cgri.method_id ||
                ']' || cgdi.fl_sel_type || '/' ||
                cgri.sel_type || ']' ||
                cgdi.door_no || '/' || cgri.door_no || ']' ||
                ' error[' || TO_CHAR(SQLCODE) || ']',
                NULL, NULL);
                pl_text_log.ins_msg('W', l_object_name,
                'CreateSOSBatches Fail to upd FLOATS gen [' ||
                l_how_generated ||
                '] batch[' || r_sel_batch.batch_no ||
                '] truck[' || sTruck || '] met[' ||
                cgdi.fl_method_id || '/' || cgri.method_id ||
                ']' || cgdi.fl_sel_type || '/' ||
                cgri.sel_type || ']' ||
                cgdi.door_no || '/' || cgri.door_no || ']' ||
                ' error[' ||
                TO_CHAR(SQLCODE) || ']', NULL, NULL);
            END;
              END LOOP;
            END IF;
          END LOOP;
        END IF;

        -- COMMIT;

        EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO SAVEPOINT sp_batch;
            pl_log.ins_msg ('FATAL', l_object_name,
                l_message_param || '  Error processing batch ' ||
                r_sel_batch.batch_no || '.  Continuing with next batch.',
                SQLCODE, SQLERRM);
            pl_text_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name,
                l_message_param || '  Error processing batch ' ||
                r_sel_batch.batch_no || '.  Continuing with next batch.',
                SQLCODE, SQLERRM);
            l_errors_detected_count := l_errors_detected_count + 1;
            commit;
    END;
    END LOOP;

    -- Added SYS15 Completed message to Symbotic

    IF l_mx_batch_present THEN
        Pl_Text_Log.Ins_Msg('I', l_object_name, 'Before calling create_SYS15_wave_status l_sos_batch_to_matrix ['||
                            l_sos_batch_to_matrix||']  wave_number ['||TO_CHAR(io_wave_number)||']', NULL, NULL);

        create_SYS15_wave_status (0, 'COMPLETED', io_wave_number, o_status);

        Pl_Text_Log.Ins_Msg('I', l_object_name, 'After calling create_SYS15_wave_status O_Status ['||o_status||
                            ']  wave_number ['||TO_CHAR(io_wave_number)||']', Null, Null);
        IF o_status = C_FAILURE THEN
            pl_log.ins_msg ('FATAL', l_object_name,
                            l_message_param || '  Error sending SYS15 to Symbotic batch for wave number ' ||
                            TO_CHAR(io_wave_number) || '.',
                            SQLCODE, SQLERRM);
        END IF;
    END IF;

    -- End: Added SYS15 Complete message to Symbotic

    -- Start the process that feeds the orders to Symbotic in the correct order.

    IF l_mx_batch_present THEN
        Pl_Text_Log.Ins_Msg('I', l_object_name, 'Before calling send_orders_to_matrix', NULL, NULL);

        o_status := pl_matrix_common.send_orders_to_matrix(io_wave_number);

        Pl_Text_Log.Ins_Msg('I', l_object_name, 'After calling send_orders_to_matrix', Null, Null);
        IF o_status = C_FAILURE THEN
            pl_log.ins_msg ('FATAL', l_object_name, l_message_param || '  Error sending orders to matrix',
                            SQLCODE, SQLERRM);
        END IF;
    END IF;             

    IF (l_errors_detected_count > 0) THEN
        o_error_detected_bln := TRUE;
    END IF;

    l_message := l_message_param ||
            ' Number of batches processed: ' || TO_CHAR(l_counter) ||
            '.  Number of exceptions/errors: ' ||
            TO_CHAR(l_errors_detected_count) || '.';
    pl_log.ins_msg ('INFO', l_object_name, l_message, NULL, NULL);
    pl_text_log.ins_msg (pl_lmc.ct_info_msg, l_object_name, l_message, NULL, NULL);

    EXCEPTION
        WHEN e_bad_how_generated THEN
            -- Parameter i_how_generated has a bad value.
            l_message := l_object_name || ': Bad value in i_how_generated[' ||
                    i_how_generated || ']';
            pl_log.ins_msg ('FATAL', l_object_name, l_message,
                    pl_exc.ct_data_error, NULL);
            pl_text_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, l_message,
                    pl_exc.ct_data_error, NULL);
    RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);
      
    WHEN OTHERS THEN
        IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg ('FATAL', l_object_name, l_message_param,
                    SQLCODE, SQLERRM);
            pl_text_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                    SQLCODE, SQLERRM);
            RAISE;
        ELSE
            pl_log.ins_msg ('FATAL', l_object_name, l_message_param,
                    SQLCODE, SQLERRM);
            pl_text_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                    SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR (pl_exc.ct_database_error,
                l_object_name || ': ' || SQLERRM);
        END IF;

    END CreateSOSBatches;

    PROCEDURE UpdateSOSFloatColumns (intRouteBatchNo    route.route_batch_no%TYPE)
    IS
        iRowCnt     NUMBER := 0;
        CURSOR curFloats (pRouteBatchNo NUMBER) IS
        SELECT  s.sel_type, r.method_id, r.truck_no, f.float_no, f.group_no,
            DECODE (f.door_area, 'C', r.c_door,
                'D', r.d_door, 'F', r.f_door) door_no,
            f.batch_no
          FROM  sel_method s, route r, floats f
         WHERE  r.route_batch_no = pRouteBatchNo
           AND  f.route_no = r.route_no
           AND  s.method_id = r.method_id
           AND  s.group_no = f.group_no
           FOR  UPDATE OF f.fl_sel_type NOWAIT;
    BEGIN
        DBMS_OUTPUT.PUT_LINE(
            'Before UpdateSOSFloatColumns ' ||
            'rFloats routebatch: ' ||
            TO_CHAR(intRouteBatchNo));
        pl_log.ins_msg('WARN',
            gl_pkg_name || '.UpdateSOSFloatColumns',
            'Before UpdateSOSFloatColumns ' ||
            'rFloats routebatch: ' ||
            TO_CHAR(intRouteBatchNo),
            NULL, NULL);
        pl_text_log.ins_msg('W',
            gl_pkg_name || '.UpdateSOSFloatColumns',
            'Before UpdateSOSFloatColumns ' ||
            'rFloats routebatch: ' ||
            TO_CHAR(intRouteBatchNo),
            NULL, NULL);
        BEGIN
            FOR rFloats IN curFloats (intRouteBatchNo)
            LOOP
                iRowCnt := 0;
                BEGIN
                    UPDATE  floats
                       SET  FL_METHOD_ID =
                            rFloats.method_id,
                        FL_SEL_TYPE = rFloats.sel_type,
                        TRUCK_NO = rFloats.truck_no,
                        DOOR_NO = rFloats.door_no
                     WHERE  CURRENT OF curFloats;
                    iRowCnt := SQL%ROWCOUNT;
                    pl_log.ins_msg('WARN',
                        gl_pkg_name || '.UpdateSOSFloatColumns',
                        'Update FLOATS in rFloats for ' ||
                        'routebatch: ' || TO_CHAR(intRouteBatchNo) ||
                        ' float: ' || TO_CHAR(rFloats.float_no) ||
                        ' batch: ' || TO_CHAR(rFloats.batch_no) ||
                        ' truck: ' || rFloats.truck_no ||
                        ' method: ' || rFloats.method_id ||
                        ' seltype: ' || rFloats.sel_type ||
                        ' door: ' || TO_CHAR(rFloats.door_no) ||
                        ' group: ' || TO_CHAR(rFloats.Group_no) ||
                        ' #rows: ' || TO_CHAR(iRowCnt),
                        NULL, NULL);
                    pl_text_log.ins_msg('W',
                        gl_pkg_name || '.UpdateSOSFloatColumns',
                        'Update FLOATS in rFloats for ' ||
                        'routebatch: ' || TO_CHAR(intRouteBatchNo) ||
                        ' float: ' || TO_CHAR(rFloats.float_no) ||
                        ' batch: ' || TO_CHAR(rFloats.batch_no) ||
                        ' truck: ' || rFloats.truck_no ||
                        ' method: ' || rFloats.method_id ||
                        ' seltype: ' || rFloats.sel_type ||
                        ' door: ' || TO_CHAR(rFloats.door_no) ||
                        ' group: ' || TO_CHAR(rFloats.Group_no) ||
                        ' #rows: ' || TO_CHAR(iRowCnt),
                        NULL, NULL);
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_log.ins_msg('WARN',
                            gl_pkg_name || '.UpdateSOSFloatColumns',
                            'Failed to upd FLOATS in rFloats for ' ||
                            'routebatch: ' ||
                            TO_CHAR(intRouteBatchNo) ||
                            ' float: ' ||
                            TO_CHAR(rFloats.float_no) ||
                            ' batch: ' ||
                            TO_CHAR(rFloats.batch_no) ||
                            ' truck: ' || rFloats.truck_no ||
                            ' method: ' || rFloats.method_id ||
                            ' seltype: ' || rFloats.sel_type ||
                            ' door: ' || TO_CHAR(rFloats.door_no) ||
                            ' group: ' ||
                            TO_CHAR(rFloats.Group_no) ||
                            ' error: ' || TO_CHAR(SQLCODE),
                            NULL, NULL);
                        pl_text_log.ins_msg('W',
                            gl_pkg_name || '.UpdateSOSFloatColumns',
                            'Failed to upd FLOATS in rFloats for ' ||
                            'routebatch: ' ||
                            TO_CHAR(intRouteBatchNo) ||
                            ' float: ' ||
                            TO_CHAR(rFloats.float_no) ||
                            ' batch: ' ||
                            TO_CHAR(rFloats.batch_no) ||
                            ' truck: ' || rFloats.truck_no ||
                            ' method: ' || rFloats.method_id ||
                            ' seltype: ' || rFloats.sel_type ||
                            ' door: ' || TO_CHAR(rFloats.door_no) ||
                            ' group: ' ||
                            TO_CHAR(rFloats.Group_no) ||
                            ' error: ' || TO_CHAR(SQLCODE),
                            NULL, NULL);
                END;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                pl_log.ins_msg('WARN',
                    gl_pkg_name || '.UpdateSOSFloatColumns',
                    'UpdateSOSFloatColumns loop exception for ' ||
                    'routebatch: ' || TO_CHAR(intRouteBatchNo) ||
                    ' e[' || TO_CHAR(SQLCODE) || ']',
                    NULL, NULL);
                pl_text_log.ins_msg('W',
                    gl_pkg_name || '.UpdateSOSFloatColumns',
                    'UpdateSOSFloatColumns loop exception for ' ||
                    'routebatch: ' || TO_CHAR(intRouteBatchNo) ||
                    ' e[' || TO_CHAR(SQLCODE) || ']',
                    NULL, NULL);
        END;
        DBMS_OUTPUT.PUT_LINE(
            'After UpdateSOSFloatColumns ' ||
            'rFloats routebatch: ' ||
            TO_CHAR(intRouteBatchNo) || ' #rows[' ||
            TO_CHAR(iRowCnt) || ']');
        pl_log.ins_msg('WARN',
            gl_pkg_name || '.UpdateSOSFloatColumns',
            'After UpdateSOSFloatColumns ' ||
            'rFloats routebatch: ' ||
            TO_CHAR(intRouteBatchNo) || ' #rows[' ||
            TO_CHAR(iRowCnt) || ']',
            NULL, NULL);
        pl_text_log.ins_msg('W',
            gl_pkg_name || '.UpdateSOSFloatColumns',
            'After UpdateSOSFloatColumns ' ||
            'rFloats routebatch: ' ||
            TO_CHAR(intRouteBatchNo) || ' #rows[' ||
            TO_CHAR(iRowCnt) || ']',
            NULL, NULL);
        iRowCnt := 0;
        BEGIN
            UPDATE  floats f1
               SET  fl_opt_pull = (
                    SELECT  DECODE (COUNT (DISTINCT route_no), 1, 'N', 'Y')
                      FROM  floats f2
                     WHERE  f2.batch_no = f1.batch_no)
             WHERE  f1.route_no IN (
                    SELECT  route_no
                      FROM  route
                     WHERE  route_batch_no = intRouteBatchNo)
               AND  f1.pallet_pull = 'N';
            iRowCnt := SQL%ROWCOUNT;
            pl_log.ins_msg('WARN',
                gl_pkg_name || '.UpdateSOSFloatColumns',
                'Update FLOATS.fl_opt_pull for ' ||
                'routebatch: ' || TO_CHAR(intRouteBatchNo) ||
                ' #rows: ' || TO_CHAR(iRowCnt),
                NULL, NULL);
            pl_text_log.ins_msg('W',
                gl_pkg_name || '.UpdateSOSFloatColumns',
                'Update FLOATS.fl_opt_pull for ' ||
                'routebatch: ' || TO_CHAR(intRouteBatchNo) ||
                ' #rows: ' || TO_CHAR(iRowCnt),
                NULL, NULL);
        EXCEPTION
            WHEN OTHERS THEN
                pl_log.ins_msg('WARN',
                    gl_pkg_name || '.UpdateSOSFloatColumns',
                    'Failed to upd FLOATS.fl_opt_pull for ' ||
                    'routebatch: ' ||
                    TO_CHAR(intRouteBatchNo) ||
                    ' error: ' || TO_CHAR(SQLCODE),
                    NULL, NULL);
                pl_text_log.ins_msg('W',
                    gl_pkg_name || '.UpdateSOSFloatColumns',
                    'Failed to upd FLOATS.fl_opt_pull for ' ||
                    'routebatch: ' ||
                    TO_CHAR(intRouteBatchNo) || 
                    ' error: ' || TO_CHAR(SQLCODE),
                    NULL, NULL);
        END;
        DBMS_OUTPUT.PUT_LINE(
            'After UpdateSOSFloatColumns fl_opt_pull rtebatch: ' ||
            TO_CHAR(intRouteBatchNo) || ' #rows[' ||
            TO_CHAR(SQL%ROWCOUNT) || ']');
        pl_log.ins_msg('WARN',
            gl_pkg_name || '.UpdateSOSFloatColumns',
            'After UpdateSOSFloatColumns fl_opt_pull rtebatch: ' ||
            TO_CHAR(intRouteBatchNo) || ' #rows[' ||
            TO_CHAR(SQL%ROWCOUNT) || ']',
            NULL, NULL);
        pl_text_log.ins_msg('W',
            gl_pkg_name || '.UpdateSOSFloatColumns',
            'After UpdateSOSFloatColumns fl_opt_pull rtebatch: ' ||
            TO_CHAR(intRouteBatchNo) || ' #rows[' ||
            TO_CHAR(SQL%ROWCOUNT) || ']',
            NULL, NULL);
    END UpdateSOSFloatColumns;

    PROCEDURE UpdateBatchSOSFloatColumns (psBatchNo batch.batch_no%TYPE)
    IS
        iRowCnt     NUMBER := 0;
        CURSOR curFloats (pBatchNo NUMBER) IS
        SELECT  s.sel_type, r.method_id, r.truck_no, f.float_no, f.group_no,
            DECODE (f.door_area, 'C', r.c_door,
                'D', r.d_door, 'F', r.f_door) door_no,
            f.batch_no
          FROM  sel_method s, route r, floats f
         WHERE  f.batch_no = pBatchNo
           AND  f.route_no = r.route_no
           AND  s.method_id = r.method_id
           AND  s.group_no = f.group_no
           FOR  UPDATE OF f.fl_sel_type NOWAIT;
    BEGIN
        BEGIN
            FOR rFloats IN curFloats (TO_NUMBER(psBatchNo))
            LOOP
                iRowCnt := 0;
                BEGIN
                    UPDATE  floats
                       SET  FL_METHOD_ID = rFloats.method_id,
                        FL_SEL_TYPE = rFloats.sel_type,
                        TRUCK_NO = rFloats.truck_no,
                        DOOR_NO = rFloats.door_no
                     WHERE  CURRENT OF curFloats;
                    iRowCnt := SQL%ROWCOUNT;
                    pl_log.ins_msg('WARN',
                        gl_pkg_name || '.UpdateBatchSOSFloatColumns',
                        'Update FLOATS in rFloats for ' ||
                        'batch: ' || psBatchNo ||
                        ' float: ' || TO_CHAR(rFloats.float_no) ||
                        ' truck: ' || rFloats.truck_no ||
                        ' method: ' || rFloats.method_id ||
                        ' seltype: ' || rFloats.sel_type ||
                        ' door: ' || TO_CHAR(rFloats.door_no) ||
                        ' group: ' || TO_CHAR(rFloats.Group_no) ||
                        ' #rows: ' || TO_CHAR(SQL%ROWCOUNT),
                        NULL, NULL);
                    pl_text_log.ins_msg('W',
                        gl_pkg_name || '.UpdateBatchSOSFloatColumns',
                        'Update FLOATS in rFloats for ' ||
                        'batch: ' || psBatchNo ||
                        ' float: ' || TO_CHAR(rFloats.float_no) ||
                        ' batch: ' || TO_CHAR(rFloats.batch_no) ||
                        ' truck: ' || rFloats.truck_no ||
                        ' method: ' || rFloats.method_id ||
                        ' seltype: ' || rFloats.sel_type ||
                        ' door: ' || TO_CHAR(rFloats.door_no) ||
                        ' group: ' || TO_CHAR(rFloats.Group_no) ||
                        ' #rows: ' || TO_CHAR(SQL%ROWCOUNT),
                        NULL, NULL);
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_log.ins_msg('WARN',
                            gl_pkg_name || '.UpdateBatchSOSFloatColumns',
                            'Failed to upd FLOATS in rFloats for ' ||
                            'batch: ' || psBatchNo ||
                            ' float: ' ||
                            TO_CHAR(rFloats.float_no) ||
                            ' truck: ' || rFloats.truck_no ||
                            ' method: ' || rFloats.method_id ||
                            ' seltype: ' || rFloats.sel_type ||
                            ' door: ' || TO_CHAR(rFloats.door_no) ||
                            ' group: ' ||
                            TO_CHAR(rFloats.Group_no) ||
                            ' error: ' || TO_CHAR(SQLCODE),
                            NULL, NULL);
                        pl_text_log.ins_msg('W',
                            gl_pkg_name || '.UpdateBatchSOSFloatColumns',
                            'Failed to upd FLOATS in rFloats for ' ||
                            'batch: ' || psBatchNo ||
                            ' float: ' ||
                            TO_CHAR(rFloats.float_no) ||
                            ' truck: ' || rFloats.truck_no ||
                            ' method: ' || rFloats.method_id ||
                            ' seltype: ' || rFloats.sel_type ||
                            ' door: ' || TO_CHAR(rFloats.door_no) ||
                            ' group: ' ||
                            TO_CHAR(rFloats.Group_no) ||
                            ' error: ' || TO_CHAR(SQLCODE),
                            NULL, NULL);
                END;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                pl_log.ins_msg('WARN',
                    gl_pkg_name || '.UpdateBatchSOSFloatColumns',
                    'UpdateBatchSOSFloatColumns loop exception for ' ||
                    'batch: ' || psBatchNo ||
                    ' e[' || TO_CHAR(SQLCODE) || ']',
                    NULL, NULL);
                pl_text_log.ins_msg('W',
                    gl_pkg_name || '.UpdateBatchSOSFloatColumns',
                    'UpdateBatchSOSFloatColumns loop exception for ' ||
                    'batch: ' || psBatchNo ||
                    ' e[' || TO_CHAR(SQLCODE) || ']',
                    NULL, NULL);
        END;
        BEGIN
            UPDATE  floats f1
               SET  fl_opt_pull = (
                    SELECT  DECODE (COUNT (DISTINCT route_no), 1, 'N', 'Y')
                      FROM  floats f2
                     WHERE  f2.batch_no = f1.batch_no)
             WHERE  f1.route_no IN (
                    SELECT  r.route_no
                      FROM  route r, floats f3
                     WHERE  r.route_no = f3.route_no
                       AND  f3.batch_no = TO_NUMBER(psBatchNo))
               AND  f1.pallet_pull = 'N';
            iRowCnt := SQL%ROWCOUNT;
            pl_log.ins_msg('WARN',
                gl_pkg_name || '.UpdateBatchSOSFloatColumns',
                'Update FLOATS.fl_opt_pull for ' ||
                'batch: ' || psBatchNo ||
                ' #rows: ' || TO_CHAR(SQL%ROWCOUNT),
                NULL, NULL);
            pl_text_log.ins_msg('W',
                gl_pkg_name || '.UpdateBatchSOSFloatColumns',
                'Update FLOATS.fl_opt_pull for ' ||
                'batch: ' || psBatchNo  ||
                ' #rows: ' || TO_CHAR(SQL%ROWCOUNT),
                NULL, NULL);
        EXCEPTION
            WHEN OTHERS THEN
                pl_log.ins_msg('WARN',
                    gl_pkg_name || '.UpdateBatchSOSFloatColumns',
                    'Failed to upd FLOATS.fl_opt_pull for ' ||
                    'batch: ' || psBatchNo ||
                    ' error: ' || TO_CHAR(SQLCODE),
                    NULL, NULL);
                pl_text_log.ins_msg('W',
                    gl_pkg_name || '.UpdateBatchSOSFloatColumns',
                    'Failed to upd FLOATS.fl_opt_pull for ' ||
                    'batch: ' || psBatchNo ||
                    ' error: ' || TO_CHAR(SQLCODE),
                    NULL, NULL);
        END;
    END UpdateBatchSOSFloatColumns;

    PROCEDURE UpdateSOSFDColumns (intRouteBatchNo IN route.route_batch_no%TYPE) IS
        CURSOR cFloats (pRouteBatchNo NUMBER) IS
        SELECT  DISTINCT f.batch_no
          FROM  route r, floats f
         WHERE  r.route_batch_no = pRouteBatchNo
           AND  f.route_no = r.route_no
           AND  f.batch_no != 0
         ORDER  BY batch_no;
        CURSOR cFloatDetail (pBatchNo NUMBER) IS
        SELECT  DISTINCT fd.prod_id, fd.cust_pref_vendor, fd.uom
          FROM  floats f, float_detail fd
         WHERE  f.batch_no = pBatchNo
           AND  fd.float_no = f.float_no
         ORDER  BY fd.prod_id, fd.cust_pref_vendor, fd.uom ;
        CURSOR  cFloatForFD (pBatchNo NUMBER) IS
        SELECT  DISTINCT float_no
          FROM  floats
         WHERE  batch_no = pBatchNo;         
        CURSOR  cFDPieceSeq (pBatchNo NUMBER) is
        SELECT  fd.order_seq, fd.seq_no, fd.src_loc,
            DECODE (fd.uom, 1, fd.qty_alloc, fd.qty_alloc / p.spc) NumPieces,
                        fd.uom,fd.float_no
          FROM  pm p, floats f, float_detail fd
         WHERE  f.batch_no = pBatchNo
           AND  fd.float_no = f.float_no
           AND  p.prod_id = fd.prod_id
           AND  p.cust_pref_vendor = fd.cust_pref_vendor
           AND  fd.qty_alloc > 0
           AND  f.pallet_pull ='N'
                 ORDER   BY fd.float_no, fd.order_seq, fd.src_loc, fd.zone,
            fd.uom
           FOR  UPDATE OF fd.st_piece_seq NOWAIT;

        CURSOR  cFDBCPieceSeq (pRouteBatchNo NUMBER) is
        SELECT  fd.order_seq, fd.seq_no, fd.src_loc,
            DECODE (fd.uom, 1, fd.qty_alloc,
                fd.qty_alloc / p.spc) NumPieces,
            f.batch_no,f.pallet_pull
          FROM  pm p, floats f, float_detail fd, route r
         WHERE  r.route_batch_no = pRouteBatchNo
           AND  f.route_no = r.route_no
           AND  f.batch_no != 0
           AND  fd.float_no = f.float_no
           AND  p.prod_id = fd.prod_id
           AND  p.cust_pref_vendor = fd.cust_pref_vendor
           AND  fd.qty_Alloc > 0
           AND  f.pallet_pull ='N'
                 ORDER  BY fd.order_seq, f.pallet_pull, fd.seq_no, fd.float_no,
            fd.src_loc, fd.zone,
            fd.uom
           FOR  UPDATE OF fd.bc_st_piece_seq NOWAIT;

        CURSOR cFDCW (pRouteBatchNo NUMBER) IS
        SELECT  f.float_no, o.order_id, o.order_line_id
          FROM  floats f, ordd od, route r, ordcw o
         WHERE  r.route_batch_no = pRouteBatchNo
           AND  f.route_no = r.route_no
           AND  od.route_no = r.route_no
           AND  o.order_id = od.order_id
           AND  o.order_line_id = od.order_line_id
--         AND  f.float_no = fd.float_no
           AND  f.pallet_pull IN ('B', 'N');
        CURSOR cFDCOOL (pRouteBatchNo NUMBER) IS
        SELECT  f.float_no, o.order_id, o.order_line_id
          FROM  floats f, ordd od, route r, ord_cool o
         WHERE  r.route_batch_no = pRouteBatchNo
           AND  f.route_no = r.route_no
           AND  od.route_no = r.route_no
           AND  o.order_id = od.order_id
           AND  o.order_line_id = od.order_line_id
--         AND  f.float_no = fd.float_no
           AND  f.pallet_pull IN ('B', 'N');
        lSeq        NUMBER;
        lbcSeq      NUMBER;
        lpSeqNo     NUMBER;
        lpNumPieces NUMBER;
                lpUom           NUMBER;
        lpSrcLoc    float_detail.src_loc%TYPE := NULL;
        lpPalletPull    floats.pallet_pull%TYPE := NULL;
        lRowCnt     NUMBER := 0;
        lFloatNo    NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('UpdateSOSFDColumns ' ||
            'routeBatch[' || TO_CHAR(intRouteBatchNo) ||
            ']'); 
        pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
            'UpdateSOSFDColumns ' ||
            'routeBatch[' || TO_CHAR(intRouteBatchNo) || ']',
            NULL, NULL); 
        pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
            'UpdateSOSFDColumns ' ||
            'routeBatch[' || TO_CHAR(intRouteBatchNo) || ']',
            NULL, NULL);
        lRowCnt := 0;
        BEGIN
            UPDATE  float_detail fd
               SET  order_seq = (SELECT seq
                           FROM ordd
                          WHERE order_id = fd.order_id
                            AND order_line_id = fd.order_line_id)
             WHERE  float_no IN
                (SELECT f.float_no
                   FROM floats f, route r
                  WHERE r.route_batch_no = intRouteBatchNo
                    AND f.route_no = r.route_no);
            lRowCnt := SQL%ROWCOUNT;
            pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
                'UpdateSOSFDColumns Update FLOAT_DETAIL ' ||
                'routeBatch[' || TO_CHAR(intRouteBatchNo) ||
                '] #rows[' || TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL); 
            pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
                'UpdateSOSFDColumns Update FLOAT_DETAIL ' ||
                'routeBatch[' || TO_CHAR(intRouteBatchNo) ||
                '] #rows[' || TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL);
        EXCEPTION
            WHEN OTHERS THEN
                pl_log.ins_msg('WARN',
                    gl_pkg_name || '.UpdateSOSFDColumns',
                    'UpdateSOSFDColumns Fail to update FLOAT_DETAIL ' ||
                    'routeBatch[' ||
                    TO_CHAR(intRouteBatchNo) || '] ' ||
                    'error [' || TO_CHAR(SQLCODE) || ']',
                    NULL, NULL); 
                pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
                    'UpdateSOSFDColumns Fail to update FLOAT_DETAIL ' ||
                    'routeBatch[' ||
                    TO_CHAR(intRouteBatchNo) || ']' ||
                    'error [' || TO_CHAR(SQLCODE) || ']',
                    NULL, NULL);
        END;
        DBMS_OUTPUT.PUT_LINE('UpdateSOSFDColumns ' ||
            'after upd fd.order_seq routeBatch[' ||
            TO_CHAR(intRouteBatchNo) || ' #rows[' ||
            TO_CHAR(SQL%ROWCOUNT) || ']');
        pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
            'UpdateSOSFDColumns ' ||
            'after upd fd.order_seq routeBatch[' ||
            TO_CHAR(intRouteBatchNo) || ' #rows[' ||
            TO_CHAR(SQL%ROWCOUNT) || ']',
            NULL, NULL);
        pl_text_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
            'UpdateSOSFDColumns ' ||
            'after upd fd.order_seq routeBatch[' ||
            TO_CHAR(intRouteBatchNo) || ' #rows[' ||
            TO_CHAR(SQL%ROWCOUNT) || ']',
            NULL, NULL);
        
        --
        -- Update Item Sequence column on Float Detail Table
        --
        FOR rFloats IN cFloats (intRouteBatchNo)
        LOOP
            lSeq := 0;
            lRowCnt := 0;           
            FOR rFloatDetail IN cFloatDetail (rFloats.batch_no)
            LOOP
            BEGIN
                lSeq := lSeq + 1;
                FOR rFloatForFD IN cFloatForFD(rFloats.batch_no)
                LOOP
                BEGIN               
                UPDATE  float_detail
                   SET  item_seq = lSeq,
                    sos_status = 'N'
                 WHERE  prod_id = rFloatDetail.prod_id
                   AND  cust_pref_vendor = rFloatDetail.cust_pref_vendor
                   AND  float_no = rFloatForFD.float_no;
                IF SQL%ROWCOUNT > 0 THEN
                    lRowCnt := lRowCnt + 1;
                END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
                        'UpdateSOSFDColumns ' ||
                        'Fail to update fd.item_seq routeBatch[' ||
                        TO_CHAR(intRouteBatchNo) || ' error[' ||
                        TO_CHAR(SQLCODE) || ']',
                        NULL, NULL);
                        pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
                        'UpdateSOSFDColumns ' ||
                        'Fail to update fd.item_seq routeBatch[' ||
                        TO_CHAR(intRouteBatchNo) || ' error[' ||
                        TO_CHAR(SQLCODE) || ']',
                        NULL, NULL);
                END;
                END LOOP;               
            END;
            END LOOP;
            DBMS_OUTPUT.PUT_LINE(
                'UpdateSOSFDColumns ' ||
                'after rFloats/rFloatDetail routeBatch[' ||
                TO_CHAR(intRouteBatchNo) || ' #rows[' ||
                TO_CHAR(lRowCnt) || ']');
            pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
                'UpdateSOSFDColumns ' ||
                'after rFloats/rFloatDetail routeBatch[' ||
                TO_CHAR(intRouteBatchNo) || ' #rows[' ||
                TO_CHAR(lRowCnt) || ']',
                NULL, NULL);
            pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
                'UpdateSOSFDColumns ' ||
                'after rFloats/rFloatDetail routeBatch[' ||
                TO_CHAR(intRouteBatchNo) || ' #rows[' ||
                TO_CHAR(lRowCnt) || ']',
                NULL, NULL);            
            lSeq := 1;
            lpSeqNo := 0;
            lpSrcLoc := NULL;
                        lpUom := 0;
            lRowCnt := 0;
            lFloatNo := 0;
            BEGIN
                FOR rFDPieceSeq IN cFDPieceSeq (rFloats.batch_no)
                LOOP
                BEGIN
                    /*
                    Added the new column bc_st_piece_seq
                    to have the start pice count for
                    barcode which is different from
                    st_piece_seq for selection from
                    multiple locations
                    */
                    IF (lpSeqNo = rFDPieceSeq.order_seq AND lpSrcLoc = rFDPieceSeq.src_loc AND
                                        lpUom   = rFDPieceSeq.uom  and lFloatNo = rFDPieceSeq.float_no) THEN
                        lSeq := lSeq + lpNumPieces;
                    ELSE
                        lSeq := 1;
                    END IF;

                    if lSeq > 999 then
                        lSeq := 1;
                    end if;

       DBMS_OUTPUT.PUT_LINE ('Order Seq = ' || rFDPieceSeq.order_seq || ', Start Sequence = ' || lSeq);
                    BEGIN
                        --Commented by Abhishek to avoid update of PL_ORDER_PORCESSING values
                        /*UPDATE  float_detail
                           SET  st_piece_seq = lSeq
                         WHERE  CURRENT OF cFDPieceSeq;
                        IF SQL%ROWCOUNT > 0 THEN
                            lRowCnt := lRowCnt + 1;
                         END IF;*/
                         NULL;
                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
                                'UpdateSOSFDColumns ' ||
                                'Fail to upd FD st_piece_seq routeBatch[' ||
                                TO_CHAR(intRouteBatchNo) || ' error[' ||
                                TO_CHAR(SQLCODE) || ']',
                                NULL, NULL);
                            pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
                                'UpdateSOSFDColumns ' ||
                                'Fail to upd FD st_piece_seq routeBatch[' ||
                                TO_CHAR(intRouteBatchNo) || ' error[' ||
                                TO_CHAR(SQLCODE) || ']',
                                NULL, NULL);            
                    END;
                    lpSeqNo := rFDPieceSeq.order_seq;
                    lpNumPieces := rFDPieceSeq.NumPieces;
                    lpSrcLoc := rFDPieceSeq.src_loc;
                                    lpUom    := rFDPieceSeq.uom;
                                    lFloatNo    := rFDPieceSeq.float_no;
                END;
                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
                        'UpdateSOSFDColumns ' ||
                        'Fail to upd loop rFloats/rFDPieceSeq routeBatch[' ||
                        TO_CHAR(intRouteBatchNo) || ' error[' ||
                        TO_CHAR(SQLCODE) || ']',
                        NULL, NULL);
                    pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
                        'UpdateSOSFDColumns ' ||
                        'Fail to upd loop rFloats/rFDPieceSeq routeBatch[' ||
                        TO_CHAR(intRouteBatchNo) || ' error[' ||
                        TO_CHAR(SQLCODE) || ']',
                        NULL, NULL);            
            END;
            DBMS_OUTPUT.PUT_LINE(
                'UpdateSOSFDColumns ' ||
                'after rFloats/rFDPieceSeq routeBatch[' ||
                TO_CHAR(intRouteBatchNo) || ' #rows[' ||
                TO_CHAR(lRowCnt) || ']');
            pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
                'UpdateSOSFDColumns ' ||
                'after rFloats/rFDPieceSeq routeBatch[' ||
                TO_CHAR(intRouteBatchNo) || ' #rows[' ||
                TO_CHAR(lRowCnt) || ']',
                NULL, NULL);
            pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
                'UpdateSOSFDColumns ' ||
                'after rFloats/rFDPieceSeq routeBatch[' ||
                TO_CHAR(intRouteBatchNo) || ' #rows[' ||
                TO_CHAR(lRowCnt) || ']',
                NULL, NULL);            
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(
            'UpdateSOSFDColumns ' ||
            'after rFloats routeBatch[' ||
            TO_CHAR(intRouteBatchNo) || ']');
        pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
            'UpdateSOSFDColumns ' ||
            'after rFloats routeBatch[' ||
            TO_CHAR(intRouteBatchNo) || ']',
            NULL, NULL);
        pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
            'UpdateSOSFDColumns ' ||
            'after rFloats routeBatch[' ||
            TO_CHAR(intRouteBatchNo) || ']',
            NULL, NULL);        
        
        /*
            Added the new column bc_st_piece_seq to have 
            the start piece count for barcode which 
            is different from st_piece_seq 
            for selection from multiple locations
        */
        lbcSeq := 1;
        lpSeqNo := 0;
        lpSrcLoc := NULL;
        lRowCnt := 0;
        lpPalletPull := 'Z';
        FOR rFDBCPieceSeq IN cFDBCPieceSeq (intRouteBatchNo)
        LOOP
        BEGIN
            IF (lpSeqNo = rFDBCPieceSeq.order_seq and lpPalletPull = rFDBCPieceSeq.pallet_pull) THEN
                lbcSeq := lbcSeq + lpNumPieces;
            ELSE
                lbcSeq := 1;
            END IF;

            if lbcSeq > 999 then
                lbcSeq := 1;
            end if;

            BEGIN
                --Commented by Abhishek to avoid update of PL_ORDER_PORCESSING values
                /*UPDATE  float_detail
                   SET  bc_st_piece_seq = lbcSeq
                 WHERE  CURRENT OF cFDBCPieceSeq;

                IF SQL%ROWCOUNT > 0 THEN
                    lRowCnt := lRowCnt + 1;
                END IF;*/
                NULL;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
                        'UpdateSOSFDColumns ' ||
                        'Fail to upd FD bc_st_piece_seq routeBatch[' ||
                        TO_CHAR(intRouteBatchNo) || ' error[' ||
                        TO_CHAR(SQLCODE) || ']',
                        NULL, NULL);
                    pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
                        'UpdateSOSFDColumns ' ||
                        'Fail to upd FD bc_st_piece_seq routeBatch[' ||
                        TO_CHAR(intRouteBatchNo) || ' error[' ||
                        TO_CHAR(SQLCODE) || ']',
                        NULL, NULL);            
            END;

            lpSeqNo := rFDBCPieceSeq.order_seq;
            lpPalletPull := rFDBCPieceSeq.pallet_pull;
            lpNumPieces := rFDBCPieceSeq.NumPieces;
        END;
        END LOOP;

        --
        -- Update Catch Weight Track column on Float Detail Table
        --
        lRowCnt := 0;
        FOR rFDCW IN cFDCW(intRouteBatchNo) LOOP        
        UPDATE  float_detail fd
           SET  catch_wt_trk = 'Y'
             WHERE  float_no = rFDCW.float_no
               AND  order_id = rFDCW.order_id
               AND  order_line_id = rFDCW.order_line_id        
           AND  NVL (fd.merge_alloc_flag, 'N') != 'M'
           AND  fd.qty_alloc > 0
           AND  fd.src_loc IS NOT NULL;
            IF SQL%ROWCOUNT > 0 THEN
                lRowCnt := lRowCnt + 1;        
        END IF;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(
            'UpdateSOSFDColumns ' ||
            'after rFDCW routeBatch[' ||
            TO_CHAR(intRouteBatchNo) || '] #rows[' ||
            TO_CHAR(lRowCnt) || ']'); 
        pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
            'UpdateSOSFDColumns ' ||
            'after rFDCW routeBatch[' ||
            TO_CHAR(intRouteBatchNo) || '] #rows[' ||
            TO_CHAR(lRowCnt) || ']',
            NULL, NULL);
        pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
            'UpdateSOSFDColumns ' ||
            'after rFDCW routeBatch[' ||
            TO_CHAR(intRouteBatchNo) || '] #rows[' ||
            TO_CHAR(lRowCnt) || ']',
            NULL, NULL);        
        --
        -- Update COOL Track column on Float Detail Table
        --
        lRowCnt := 0;
        FOR rFDCOOL IN cFDCOOL(intRouteBatchNo) LOOP        
        UPDATE  float_detail fd
           SET  cool_trk = 'Y'
             WHERE  float_no = rFDCOOL.float_no
               AND  order_id = rFDCOOL.order_id
               AND  order_line_id = rFDCOOL.order_line_id          
           AND  NVL (fd.merge_alloc_flag, 'N') != 'M'
           AND  fd.qty_alloc > 0
           AND  fd.src_loc IS NOT NULL;
            IF SQL%ROWCOUNT > 0 THEN
                lRowCnt := lRowCnt + 1;        
        END IF;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(
            'UpdateSOSFDColumns ' ||
            'after rFDCOOL routeBatch[' ||
            TO_CHAR(intRouteBatchNo) || '] #rows[' ||
            TO_CHAR(lRowCnt) || ']');
        pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
            'UpdateSOSFDColumns ' ||
            'after rFDCOOL routeBatch[' ||
            TO_CHAR(intRouteBatchNo) || '] #rows[' ||
            TO_CHAR(lRowCnt) || ']',
            NULL, NULL);
        pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
            'UpdateSOSFDColumns ' ||
            'after rFDCOOL routeBatch[' ||
            TO_CHAR(intRouteBatchNo) || '] #rows[' ||
            TO_CHAR(lRowCnt) || ']',
            NULL, NULL);
    EXCEPTION
        WHEN OTHERS THEN
            pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateSOSFDColumns',
                'UpdateSOSFDColumns ' ||
                'global exception routeBatch[' ||
                TO_CHAR(intRouteBatchNo) || '] error[' ||
                TO_CHAR(SQLCODE) || ']',
                NULL, NULL);
            pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateSOSFDColumns',
                'UpdateSOSFDColumns ' ||
                'global exception routeBatch[' ||
                TO_CHAR(intRouteBatchNo) || '] error[' ||
                TO_CHAR(SQLCODE) || ']',
                NULL, NULL);
    END UpdateSOSFDColumns;

    PROCEDURE UpdateBatchSOSFDColumns (psBatchNo IN batch.batch_no%TYPE) IS
        CURSOR cFloats (pBatchNo NUMBER) IS
        SELECT  DISTINCT f.batch_no
          FROM  route r, floats f
         WHERE  f.route_no = r.route_no
           AND  f.batch_no = pBatchNo
           AND  f.batch_no != 0
         ORDER  BY batch_no;
        CURSOR cFloatDetail (pBatchNo NUMBER) IS
        SELECT  DISTINCT fd.prod_id, fd.cust_pref_vendor, fd.uom
          FROM  floats f, float_detail fd
         WHERE  f.batch_no = pBatchNo
           AND  fd.float_no = f.float_no
         ORDER  BY fd.prod_id, fd.cust_pref_vendor, fd.uom;
        CURSOR  cFloatForFD (pBatchNo NUMBER) IS
        SELECT  DISTINCT float_no
          FROM  floats
         WHERE  batch_no = pBatchNo;         

        CURSOR  cFDPieceSeq (pBatchNo NUMBER) is
        SELECT  fd.order_seq, fd.seq_no, fd.src_loc,
            DECODE (fd.uom, 1, fd.qty_alloc,
                    fd.qty_alloc / p.spc) NumPieces,
            fd.float_no,
            fd.uom
          FROM  pm p, floats f, float_detail fd
         WHERE  f.batch_no = pBatchNo
           AND  fd.float_no = f.float_no
           AND  p.prod_id = fd.prod_id
           AND  p.cust_pref_vendor = fd.cust_pref_vendor
           AND  fd.qty_alloc > 0
           AND  f.pallet_pull = 'N'
                 ORDER  BY  fd.order_seq, fd.seq_no, fd.float_no, fd.src_loc, fd.zone,
            fd.uom
           FOR  UPDATE OF fd.st_piece_seq NOWAIT;

        CURSOR cFDCW (pBatchNo NUMBER) IS
        SELECT  f.float_no, o.order_id, o.order_line_id
          FROM  floats f, ordd od, route r, ordcw o
         WHERE  f.batch_no = TO_NUMBER(pBatchNo)
           AND  f.route_no = r.route_no
           AND  od.route_no = r.route_no
           AND  o.order_id = od.order_id
           AND  o.order_line_id = od.order_line_id
--         AND  f.float_no = fd.float_no
           AND  f.pallet_pull IN ('B', 'N');
        CURSOR cFDCOOL (pBatchNo NUMBER) IS
        SELECT f.float_no, o.order_id, o.order_line_id
          FROM  floats f, ordd od, route r, ord_cool o
         WHERE  f.route_no = r.route_no
           AND  od.route_no = r.route_no
           AND  o.order_id = od.order_id
           AND  o.order_line_id = od.order_line_id
--         AND  f.float_no = fd.float_no
           AND  f.batch_no = TO_NUMBER(pBatchNo)
           AND  f.pallet_pull IN ('B', 'N');           

        CURSOR cFDBCPieceSeq (pBatchNo NUMBER, pOrderSeq float_detail.order_seq%TYPE, pFloatNo float_detail.float_no%TYPE) is
        SELECT  DECODE (fd.uom, 1, fd.qty_alloc,
                    fd.qty_alloc / p.spc) NumPieces
          FROM  pm p, floats f, float_detail fd, route r
         WHERE  r.route_batch_no = (SELECT DISTINCT r.route_batch_no
                          FROM  route r1, floats f
                         WHERE  f.route_no = r1.route_no
                           AND  f.batch_no = pBatchNo
                           AND  f.batch_no != 0)
           AND  fd.order_seq = pOrderSeq
           AND  f.batch_no <> pBatchNo
           AND  fd.float_no < pFloatNo
           AND  f.route_no = r.route_no
           AND  fd.float_no = f.float_no
           AND  p.prod_id = fd.prod_id
           AND  p.cust_pref_vendor = fd.cust_pref_vendor
           AND  fd.qty_alloc > 0
           AND  f.pallet_pull='N'
                 ORDER  BY fd.float_no, fd.order_seq, fd.seq_no,fd.zone, fd.src_loc,
            fd.uom ;

        lSeq        NUMBER;
        lbcSeq      NUMBER;
        lpSeqNo     NUMBER;
        lpUom       NUMBER;
        lpFloatNo   NUMBER;
        lpNumPieces NUMBER;
        lpSrcLoc    float_detail.src_loc%TYPE := NULL;
        lRowCnt     NUMBER := 0;        
        blnFirstTime    BOOLEAN;

    BEGIN
        BEGIN
            UPDATE  float_detail fd
               SET  order_seq = (SELECT seq
                           FROM ordd
                          WHERE order_id = fd.order_id
                            AND order_line_id = fd.order_line_id)
             WHERE  float_no IN
                (SELECT f.float_no
                   FROM floats f, route r
                  WHERE f.batch_no = TO_NUMBER(psBatchNo)
                    AND f.route_no = r.route_no);
            pl_log.ins_msg('WARN',gl_pkg_name || '.UpdateBatchSOSFDColumns',
                'UpdateBatchSOSFDColumns ' ||
                'upd FD.order_seq batch[' ||
                psBatchNo || '] #rows[' ||
                TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL);
            pl_text_log.ins_msg('W',
                gl_pkg_name || '.UpdateBatchSOSFDColumns',
                'UpdateBatchSOSFDColumns ' ||
                'upd FD.order_seq batch[' ||
                psBatchNo || '] #rows[' ||
                TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL);        
        EXCEPTION
            WHEN OTHERS THEN
                pl_log.ins_msg('WARN',gl_pkg_name || '.UpdateBatchSOSFDColumns',
                    'UpdateBatchSOSFDColumns ' ||
                    'Fail to upd FD.order_seq batch[' ||
                    psBatchNo || '] error[' ||
                    TO_CHAR(SQLCODE) || ']',
                    NULL, NULL);
                pl_text_log.ins_msg('W', gl_pkg_name || '.UpdateBatchSOSFDColumns',
                    'UpdateBatchSOSFDColumns ' ||
                    'Fail to upd FD.order_seq batch[' ||
                    psBatchNo || '] error[' ||
                    TO_CHAR(SQLCODE) || ']',
                    NULL, NULL);        
        END;
                
        --
        -- Update Item Sequence column on Float Detail Table
        --
        FOR rFloats IN cFloats (TO_NUMBER(psBatchNo))
        LOOP
            pl_log.ins_msg('WARN', 'UpdateBatchSOSFDColumns',
                'Batch: ' || rFloats.batch_no,
                NULL, NULL);
            lSeq := 0;
            FOR rFloatDetail IN cFloatDetail (rFloats.batch_no)
            LOOP
            BEGIN
                lSeq := lSeq + 1;
                lRowCnt := 0;
                FOR rFloatForFD IN cFloatForFD(rFloats.batch_no)
                LOOP
                BEGIN
                    UPDATE  float_detail
                       SET  item_seq = lSeq,
                            sos_status = DECODE(sos_status,
                                'C', sos_status,
                                'S', sos_status,
                                'N')
                     WHERE  prod_id = rFloatDetail.prod_id
                       AND  cust_pref_vendor = rFloatDetail.cust_pref_vendor
                       AND  float_no = rFloatForFD.float_no;
                    pl_log.ins_msg('WARN',
                        'UpdateBatchSOSFDColumns',
                        ' upd FD.item_seq Batch[' || rFloats.batch_no ||
                        '] sq[' || TO_CHAR(lSeq) ||
                        '] #rows[' ||
                        TO_CHAR(SQL%ROWCOUNT) || ']',
                        NULL, NULL);
                    pl_text_log.ins_msg('W',
                        'UpdateBatchSOSFDColumns',
                        ' upd FD.item_seq Batch[' || rFloats.batch_no ||
                        '] sq[' || TO_CHAR(lSeq) ||
                        '] #rows[' ||
                        TO_CHAR(SQL%ROWCOUNT) || ']',
                        NULL, NULL);
                    lRowCnt := lRowCnt + SQL%ROWCOUNT;
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_log.ins_msg('WARN',
                            'UpdateBatchSOSFDColumns',
                            'Fail to upd FD.item_seq Batch[' || rFloats.batch_no ||
                            '] sq[' || TO_CHAR(lSeq) ||
                            '] error[' ||
                            TO_CHAR(SQLCODE) || ']',
                            NULL, NULL);
                        pl_text_log.ins_msg('W',
                            'UpdateBatchSOSFDColumns',
                            'Fail to upd FD.item_seq Batch[' || rFloats.batch_no ||
                            '] sq[' || TO_CHAR(lSeq) ||
                            '] error[' ||
                            TO_CHAR(SQLCODE) || ']',
                            NULL, NULL);
                END;
                END LOOP;
                DBMS_OUTPUT.PUT_LINE('UpdateBatchSOSFDColumns finish cursor cFloatForFD ' ||
                    TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS') ||
                    ' batch[' || psBatchNo || 
                    '] #row[' || TO_CHAR(lRowCnt) || ']');              
            END;
            END LOOP;
            DBMS_OUTPUT.PUT_LINE('UpdateBatchSOSFDColumns finish cursor cFloatDetail ' ||
                TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS') ||
                ' batch[' || psBatchNo || ']');
            lSeq := 1;
            lbcSeq := 1;
            lpSeqNo := 0;
            lpUom := 0;
            lpFloatNo := 0;
            lpSrcLoc := NULL;
            blnFirstTime := TRUE;
            FOR rFDPieceSeq IN cFDPieceSeq (rFloats.batch_no)
            LOOP
            BEGIN
                /*
                    Added the new column bc_st_piece_seq
                    to have the start piece count for
                    barcode which is different from
                    st_piece_seq for selection from
                    multiple locations
                */
                IF (blnFirstTime = TRUE) THEN
                    lbcSeq := 1;
                    FOR rFDBCPieceSeq IN cFDBCPieceSeq(rFloats.batch_no, rFDPieceSeq.order_seq, rFDPieceSeq.float_no)
                    LOOP
                    BEGIN
                         DBMS_OUTPUT.PUT_LINE ('First Order Seq = ' || rFDPieceSeq.float_no || ', Start BCSequence = ' || lbcSeq);
                        lbcSeq := lbcSeq + rFDBCPieceSeq.NumPieces;
                    END;
                    END LOOP;
                    blnFirstTime := FALSE;
                     DBMS_OUTPUT.PUT_LINE ('First Order Seq = ' || rFDPieceSeq.order_seq || ', Start BCSequence = ' || lbcSeq);
                ELSE
                    IF (lpSeqNo = rFDPieceSeq.order_seq) THEN
                        lbcSeq := lbcSeq + lpNumPieces;
                    ELSE
                        lbcSeq := 1;
                     DBMS_OUTPUT.PUT_LINE ('Second Order Seq = ' || rFDPieceSeq.order_seq || ', Start BCSequence = ' || lbcSeq);
                    END IF;
                END IF;
                if lbcSeq > 999 then
                    lbcSeq := 1;
                end if;

                 DBMS_OUTPUT.PUT_LINE ('Order Seq = ' || rFDPieceSeq.order_seq || ', Start BCSequence = ' || lbcSeq);
                                IF (lpSeqNo = rFDPieceSeq.order_seq AND lpSrcLoc = rFDPieceSeq.src_loc 
                                    AND lpUom = rFDPieceSeq.uom AND lpFloatNo = rFDPieceSeq.float_no) THEN
                    lSeq := lSeq + lpNumPieces;
                ELSE
                    lSeq := 1;
                END IF;
                if lSeq > 999 then
                    lSeq := 1;
                end if;

                 DBMS_OUTPUT.PUT_LINE ('Order Seq = ' || rFDPieceSeq.order_seq || ', Start Sequence = ' || lSeq);
                 
                 --Commented by Abhishek to avoid update of PL_ORDER_PORCESSING values
                /*BEGIN
                    UPDATE  float_detail
                       SET  st_piece_seq = lSeq,
                        bc_st_piece_seq = lbcSeq
                     WHERE  CURRENT OF cFDPieceSeq;
                EXCEPTION
                    WHEN OTHERS THEN
                        NULL;
                END;*/
                lpSeqNo := rFDPieceSeq.order_seq;
                lpNumPieces := rFDPieceSeq.NumPieces;
                lpSrcLoc := rFDPieceSeq.src_loc;
                    lpUom   := rFDPieceSeq.uom;
                lpFloatNo := rFDPieceSeq.float_no;
            END;
            END LOOP;
            DBMS_OUTPUT.PUT_LINE('UpdateBatchSOSFDColumns finish cursor cFDPieceSeq ' ||
                TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS') ||
                ' batch[' || psBatchNo || ']');
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('UpdateBatchSOSFDColumns finish ' ||
            'cursor cFloats ' ||
            TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS') ||
            ' batch[' || psBatchNo || ']');
        --
        -- Update Catch Weight Track column on Float Detail Table
        --
        lRowCnt := 0;
        FOR rFDCW IN cFDCW(psBatchNo) LOOP      
        UPDATE  float_detail fd
           SET  catch_wt_trk = 'Y'
             WHERE  float_no = rFDCW.float_no
               AND  order_id = rFDCW.order_id
               AND  order_line_id = rFDCW.order_line_id        
           AND  NVL (fd.merge_alloc_flag, 'N') != 'M'
           AND  fd.qty_alloc > 0
           AND  fd.src_loc IS NOT NULL;
        IF SQL%ROWCOUNT = 0 THEN
                pl_log.ins_msg('WARN',
                    gl_pkg_name || '.UpdateBatchSOSFDColumns',
                    'Failed to upd FLOAT_DETAIL.catch_wt_trk=Y for ' ||
                'batch: ' || psBatchNo, NULL, NULL);
                pl_text_log.ins_msg('W',
                gl_pkg_name || '.UpdateBatchSOSFDColumns',
                'Failed to upd FLOAT_DETAIL.catch_wt_trk=Y for ' ||
            'batch: ' || psBatchNo, NULL, NULL);
            ELSE
                lRowCnt := lRowCnt + 1;         
        END IF;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('UpdateBatchSOSFDColumns finish ' ||
            'cursor cFDCW ' ||
            TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS') ||
            ' batch[' || psBatchNo || '] #row[' ||
            TO_CHAR(lRowCnt) || ']');       
        --
        -- Update COOL Track column on Float Detail Table
        --
        lRowCnt := 0;
        FOR rFDCOOL IN cFDCOOL(psBatchNo) LOOP      
        UPDATE  float_detail fd
           SET  cool_trk = 'Y'
             WHERE  float_no = rFDCOOL.float_no
               AND  order_id = rFDCOOL.order_id
               AND  order_line_id = rFDCOOL.order_line_id
           AND  NVL (fd.merge_alloc_flag, 'N') != 'M'
           AND  fd.qty_alloc > 0
           AND  fd.src_loc IS NOT NULL;
        IF SQL%ROWCOUNT = 0 THEN
                pl_log.ins_msg('WARN',
                    gl_pkg_name || '.UpdateSOSFDColumns',
                    'Failed to upd FLOAT_DETAIL.cool_trk=Y for ' ||
                    'batch: ' || psBatchNo, NULL, NULL);
                pl_text_log.ins_msg('W',
                gl_pkg_name || '.UpdateSOSFDColumns',
                'Failed to upd FLOAT_DETAIL.cool_trk=Y for ' ||
                'batch: ' || psBatchNo, NULL, NULL);
            ELSE
                lRowCnt := lRowCnt + 1;             
        END IF;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('UpdateBatchSOSFDColumns finish ' ||
            'cursor cFDCOOL ' ||
            TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS') ||
            ' batch[' || psBatchNo || '] #row[' ||
            TO_CHAR(lRowCnt) || ']');       
    EXCEPTION
        WHEN OTHERS THEN
            pl_log.ins_msg('WARN', gl_pkg_name || '.UpdateBatchSOSFDColumns',
                'UpdateBatchSOSFDColumns ' ||
                'global exception routeBatch[' ||
                psBatchNo || '] error[' ||
                TO_CHAR(SQLCODE) || ']',
                NULL, NULL);
            pl_text_log.ins_msg('W',
                gl_pkg_name || '.UpdateBatchSOSFDColumns',
                'UpdateBatchSOSFDColumns ' ||
                'global exception routeBatch[' ||
                psBatchNo || '] error[' ||
                TO_CHAR(SQLCODE) || ']',
                NULL, NULL);
    END UpdateBatchSOSFDColumns;

    PROCEDURE SetupSOSData (intRouteBatchNo IN route.route_batch_no%TYPE)
    IS
        blnError    BOOLEAN := FALSE;
        tbBatches   tabBatches;
    BEGIN
        DBMS_OUTPUT.PUT_LINE ('Before UpdateSOSFDColumns');
        pl_log.ins_msg('WARN', 'SetupSOSData',
            'SetupSOSData Before UpdateSOSFDColumns ' ||
            'routebatch: ' ||
            TO_CHAR(intRouteBatchNo), NULL, NULL);
        pl_text_log.ins_msg('W', 'SetupSOSData',
            'SetupSOSData Before UpdateSOSFDColumns ' ||
            'routebatch: ' ||
            TO_CHAR(intRouteBatchNo), NULL, NULL);
        UpdateSOSFDColumns (intRouteBatchNo);
        DBMS_OUTPUT.PUT_LINE ('Before UpdateSOSFloatColumns');
        pl_log.ins_msg('WARN', 'SetupSOSData',
            'SetupSOSData Before UpdateSOSFloatColumns ' ||
            'routebatch: ' ||
            TO_CHAR(intRouteBatchNo), NULL, NULL);
        pl_text_log.ins_msg('W', 'SetupSOSData',
            'SetupSOSData Before UpdateSOSFloatColumns ' ||
            'routebatch: ' ||
            TO_CHAR(intRouteBatchNo), NULL, NULL);
        UpdateSOSFloatColumns (intRouteBatchNo);
        DBMS_OUTPUT.PUT_LINE ('Before CreateSOSBatches');
        pl_log.ins_msg('WARN', 'SetupSOSData',
            'SetupSOSData Before CreateSOSBatches ' ||
            'how_generated=g routebatch: ' ||
            TO_CHAR(intRouteBatchNo), NULL, NULL);
        pl_text_log.ins_msg('W', 'SetupSOSData',
            'SetupSOSData Before CreateSOSBatches ' ||
            'how_generated=g routebatch: ' ||
            TO_CHAR(intRouteBatchNo), NULL, NULL);
		--
	    -- Update catch weight for each case in ordcw from INV_CASES 
	    -- 
	    pl_log.ins_msg
			('WARN', 'SetupBatchSOSData',
				'SetupBatchSOSData: Before pl_order_processing.p_update_meat_ord_cw RouteBatchNo['|| 
						intRouteBatchNo||'])',
			 NULL, NULL);
	    pl_order_processing.p_update_meat_ord_cw(intRouteBatchNo);

        CreateSOSBatches ('g', TO_CHAR (intRouteBatchNo),
            blnError, tbBatches);
        FOR i IN 1 .. tbBatches.COUNT LOOP
            FOR cgmfr IN c_get_multi_float_rte(tbBatches(i)) LOOP
                FOR cgmr IN c_get_multi_trk(cgmfr.route_no) LOOP
                    BEGIN
                        UPDATE floats
                           SET truck_no = cgmr.truck_no
                         WHERE batch_no = tbBatches(i)
                           AND route_no = cgmfr.route_no
                           AND truck_no = 'MULTI';

                        pl_log.ins_msg('WARN',
                           'SetupSOSData',
                           'SetupSOSData Update ' ||
                           'FLOATS.truck for MULTI ' ||
                           'routebatch[' ||
                           TO_CHAR(intRouteBatchNo) ||
                           '] bat[' || tbBatches(i) ||
                           '] route[' ||
                           cgmfr.route_no || '] to ' ||
                           'truck[' || cgmr.truck_no ||
                           '] #upd[' ||
                           TO_CHAR(SQL%ROWCOUNT) || ']',
                           NULL, NULL);
                        pl_text_log.ins_msg('W',
                           'SetupSOSData',
                           'SetupSOSData Update ' ||
                           'FLOATS.truck for MULTI ' ||
                           'routebatch[' ||
                           TO_CHAR(intRouteBatchNo) ||
                           '] bat[' || tbBatches(i) ||
                           '] route[' ||
                           cgmfr.route_no || '] to ' ||
                           'truck[' || cgmr.truck_no ||
                           '] #upd[' ||
                           TO_CHAR(SQL%ROWCOUNT) || ']',
                           NULL, NULL);
                    EXCEPTION
                        WHEN OTHERS THEN
                          pl_log.ins_msg('WARN',
                           'SetupSOSData',
                           'SetupSOSData Update ' ||
                           'FLOATS.truck for MULTI ' ||
                           'routebatch[' ||
                           TO_CHAR(intRouteBatchNo) ||
                           '] bat[' || tbBatches(i) ||
                           '] route[' ||
                           cgmfr.route_no || '] to ' ||
                           'truck[' || cgmr.truck_no ||
                           '] Err[' ||
                           TO_CHAR(SQLCODE) || ']',
                           NULL, NULL);
                          pl_text_log.ins_msg('W',
                           'SetupSOSData',
                           'SetupSOSData Update ' ||
                           'FLOATS.truck for MULTI ' ||
                           'routebatch[' ||
                           TO_CHAR(intRouteBatchNo) ||
                           '] bat[' || tbBatches(i) ||
                           '] route[' ||
                           cgmfr.route_no || '] to ' ||
                           'truck[' || cgmr.truck_no ||
                           '] #upd[' ||
                           TO_CHAR(SQLCODE) || ']',
                           NULL, NULL);
                    END;
                END LOOP;
            END LOOP;
        END LOOP;
    END SetupSOSData;

    PROCEDURE SetupBatchSOSData (psBatchNo IN batch.batch_no%TYPE)
    IS
        blnError    BOOLEAN := FALSE;
        tbBatches   tabBatches;
    BEGIN
        DBMS_OUTPUT.PUT_LINE ('Before UpdateBatchSOSFDColumns');
        pl_log.ins_msg('WARN',
            'SetupBatchSOSData',
            'SetupBatchSOSData Before UpdateSOSFDColumns ' ||
            'batch : ' || psBatchNo, NULL, NULL);
        pl_text_log.ins_msg('W',
            'SetupBatchSOSData',
            'SetupBatchSOSData Before UpdateSOSFDColumns ' ||
            'batch : ' || psBatchNo, NULL, NULL);
        UpdateBatchSOSFDColumns (psBatchNo);
		
        DBMS_OUTPUT.PUT_LINE ('Before UpdateBatchSOSFloatColumns');
        pl_log.ins_msg('WARN',
            'SetupBatchSOSData',
            'SetupBatchSOSData Before UpdateSOSFloatColumns ' ||
            'batch : ' || psBatchNo, NULL, NULL);
        pl_text_log.ins_msg('W',
            'SetupBatchSOSData',
            'SetupBatchSOSData Before UpdateSOSFloatColumns ' ||
            'batch : ' || psBatchNo, NULL, NULL);
        UpdateBatchSOSFloatColumns (psBatchNo);
        DBMS_OUTPUT.PUT_LINE ('Before CreateSOSBatches');
        pl_log.ins_msg('WARN',
            'SetupBatchSOSData',
            'SetupBatchSOSData Before UpdateSOSBatches ' ||
            'how_generated=b batch : ' || psBatchNo, NULL, NULL);
        pl_text_log.ins_msg('W',
            'SetupBatchSOSData',
            'SetupBatchSOSData Before UpdateSOSBatches ' ||
            'how_generated=b batch : ' || psBatchNo, NULL, NULL);
		
        CreateSOSBatches ('b', psBatchNo,
            blnError, tbBatches);
        FOR i IN 1 .. tbBatches.COUNT LOOP
            FOR cgmfr IN c_get_multi_float_rte(tbBatches(i)) LOOP
                FOR cgmr IN c_get_multi_trk(cgmfr.route_no) LOOP
                    BEGIN
                        UPDATE floats
                           SET truck_no = cgmr.truck_no
                         WHERE batch_no = tbBatches(i)
                           AND route_no = cgmfr.route_no
                           AND truck_no = 'MULTI';

                        pl_log.ins_msg('WARN',
                           'SetupBatchSOSData',
                           'SetupBatchSOSData Update '||
                           'FLOATS.truck for MULTI ' ||
                           'bat[' || tbBatches(i) ||
                           '] route[' ||
                           cgmfr.route_no || '] to ' ||
                           'truck[' || cgmr.truck_no ||
                           '] #upd[' ||
                           TO_CHAR(SQL%ROWCOUNT) || ']',
                           NULL, NULL);
                        pl_text_log.ins_msg('W',
                           'SetupBatchSOSData',
                           'SetupBatchSOSData Update '||
                           'FLOATS.truck for MULTI ' ||
                           'bat[' || tbBatches(i) ||
                           '] route[' ||
                           cgmfr.route_no || '] to ' ||
                           'truck[' || cgmr.truck_no ||
                           '] #upd[' ||
                           TO_CHAR(SQL%ROWCOUNT) || ']',
                           NULL, NULL);
                    EXCEPTION
                        WHEN OTHERS THEN
                          pl_log.ins_msg('WARN',
                           'SetupBatchSOSData',
                           'SetupBatchSOSData Update '||
                           'FLOATS.truck for MULTI ' ||
                           'bat[' || tbBatches(i) ||
                           '] route[' ||
                           cgmfr.route_no || '] to ' ||
                           'truck[' || cgmr.truck_no ||
                           '] Err[' ||
                           TO_CHAR(SQLCODE) || ']',
                           NULL, NULL);
                          pl_text_log.ins_msg('W',
                           'SetupBatchSOSData',
                           'SetupBatchSOSData Update '||
                           'FLOATS.truck for MULTI ' ||
                           'bat[' || tbBatches(i) ||
                           '] route[' ||
                           cgmfr.route_no || '] to ' ||
                           'truck[' || cgmr.truck_no ||
                           '] #upd[' ||
                           TO_CHAR(SQLCODE) || ']',
                           NULL, NULL);
                    END;
                END LOOP;
            END LOOP;
        END LOOP;
    END SetupBatchSOSData;

    PROCEDURE SetupSLSData (intRouteBatchNo IN route.route_batch_no%TYPE)
    IS
        blnError    BOOLEAN := FALSE;
        CURSOR c_lastruck IS
           SELECT t.truck, t.route_no troute, r.route_no rroute
           FROM las_truck t, route r
           WHERE t.truck = r.truck_no
           AND   r.route_batch_no = intRouteBatchNo
           ORDER BY t.truck;
    BEGIN
        PopulateLASTruck (intRouteBatchNo);
        FOR cl IN c_lastruck LOOP
            pl_log.ins_msg('WARN',
                'SetupSLSData',
                'SetupSLSData: Before back CRT_order_proc ' ||
                'rb[' || TO_CHAR(intRouteBatchNo) || '] ' ||
                'rte[' || cl.troute|| '/' || cl.rroute ||
                '] trk[' || cl.truck || ']',
                NULL, NULL);
            pl_text_log.ins_msg('W',
                'SetupSLSData',
                'SetupSLSData: Before back CRT_order_proc ' ||
                'rb[' || TO_CHAR(intRouteBatchNo) || '] ' ||
                'rte[' || cl.troute|| '/' || cl.rroute ||
                '] trk[' || cl.truck || ']',
                NULL, NULL);
        END LOOP;
    END SetupSLSData;

    PROCEDURE PopulateLASTruck (
        intRouteBatchNo route.route_batch_no%TYPE) IS
      iCubeLength   NUMBER := 6;
      iCubeDry  NUMBER := 0;
      iCubeCooler   NUMBER := 0;
      iCubeFreezer  NUMBER := 0;
      sRoute    route.route_no%TYPE := NULL;
      sStatus   route.status%TYPE := NULL;
      iRouteBatch   route.route_batch_no%TYPE := NULL;
      iCode     NUMBER := 0;
      /*  01/25/10  - 12554 - gsaj0457 - Added for 212 Enh - SCE018 - Begin  */  
      /* Variable Declarations*/
      iAddOnRoute    route.add_on_route_seq%TYPE := NULL;
      iRouteNo route.route_no%TYPE := NULL;
      iCurrentCubeDry    NUMBER := 0;
      iCurrentCubeCooler    NUMBER := 0;
      iCurrentCubeFreezer    NUMBER := 0;
     /*  01/25/10  - 12554 - gsaj0457 - Added for 212 Enh - SCE018 - End  */  
      CURSOR c_get_truckinfo IS
        SELECT v.truck_no,
        COUNT (DISTINCT (DECODE (v.comp_code,
                'D', v.float_no, NULL))) dry_pallets,
        SUM (DECODE (v.comp_code, 'D', v.cases, 0)) dry_cases,
        COUNT (DISTINCT (DECODE (v.comp_code,
                'D', v.stop_no, null))) dry_stops,
        SUM (DECODE (v.comp_code, 'D', v.cube, 0)) dry_cube,
        COUNT (DISTINCT (DECODE (v.comp_code,
                'D', v.float_no, NULL))) dry_remaining,
        COUNT (DISTINCT (DECODE (v.comp_code,
                'C', v.float_no, NULL))) cooler_pallets,
        SUM (DECODE (v.comp_code,
            'C', v.cases, 0)) cooler_cases,
        COUNT (DISTINCT (DECODE (v.comp_code,
            'C', v.stop_no, null))) cooler_stops,
        SUM (DECODE (v.comp_code, 'C', v.cube, 0)) cooler_cube,
        COUNT (DISTINCT (DECODE (v.comp_code,
            'C', v.float_no, NULL))) cooler_remaining,
        COUNT (DISTINCT (DECODE (v.comp_code,
            'F', v.float_no, NULL))) freezer_pallets,
        SUM (DECODE (v.comp_code,
            'F', v.cases, 0)) freezer_cases,
        COUNT (DISTINCT (DECODE (v.comp_code,
                'F', v.stop_no, null))) freezer_stops,
        SUM (DECODE (v.comp_code, 'F', v.cube, 0)) freezer_cube,
        COUNT (DISTINCT (DECODE (v.comp_code,
            'F', v.float_no, NULL))) freezer_remaining,
        v.route_no
        FROM v_ob1rb v
        WHERE v.route_batch_no = intRouteBatchNo
        AND   v.status <> 'CLS'
        GROUP BY v.truck_no, v.route_no;
      CURSOR c_get_truck_info (
        csTruck route.truck_no%TYPE,
        csRoute route.route_no%TYPE) IS
        SELECT status, route_no, route_batch_no
        FROM route
        WHERE truck_no = csTruck
            AND   route_batch_no <> intRouteBatchNo
        AND   INSTR(route_no, ' ') = 0
        AND   route_no <> csRoute;
    /*  01/25/10  - 12554 - gsaj0457 - Added for 212 Enh - SCE018 - Begin  */  
    /* Declare a cursor to fetch the cube values from the las_truck table*/
      CURSOR c_get_las_truck_info (
        csTruck las_truck.truck%TYPE) IS
        SELECT dry_cube, cooler_cube, freezer_cube
        FROM las_truck
        WHERE truck = csTruck;
    /*  01/25/10  - 12554 - gsaj0457 - Added for 212 Enh - SCE018 - End  */  
    BEGIN
      pl_text_log.ins_msg('W',
        gl_pkg_name || '.PopulateLASTruck',
        'PopulateLASTruck ' ||
        'Route batch[' || TO_CHAR(intRouteBatchNo) || ']',
        NULL, NULL);
/*    pl_nos.insert_slt_action_log('POPULATELASTRUCK',
        'Route batch[' || TO_CHAR(intRouteBatchNo) || ']',
        'INFO', 'Y');*/

      DELETE las_truck
       WHERE truck IN (SELECT truck_no
               FROM route
               WHERE route_batch_no = intRouteBatchNo
                    /*  03/18/10  - 12554 - gsaj0457 - Added for 212 Enh - SCE018 - Begin */  
                   AND add_on_route_seq is NULL)
                    /*  03/18/10  - 12554 - gsaj0457 - Added for 212 Enh - SCE018 - End  */  
         AND route_no NOT IN (SELECT route_no
                  FROM route
                  WHERE route_batch_no = intRouteBatchNo
                  AND   status = 'OPN')
         AND route_no NOT IN (SELECT route_no
                  FROM route
                  WHERE route_batch_no <> intRouteBatchNo
                  AND   status = 'OPN');

      pl_text_log.ins_msg('W',
        gl_pkg_name || '.PopulateLASTruck',
        'PopulateLASTruck ' ||
        'Route batch[' || TO_CHAR(intRouteBatchNo) || ']' ||
        ' Delete LAS_TRUCK #rows[' || TO_CHAR(SQL%ROWCOUNT) || ']',
        NULL, NULL);

      DELETE las_pallet lp
       WHERE NOT EXISTS (SELECT 0
                 FROM las_truck lt
                 WHERE lt.truck = lp.truck);

      pl_text_log.ins_msg('W',
        gl_pkg_name || '.PopulateLASTruck',
        'PopulateLASTruck ' ||
        'Route batch[' || TO_CHAR(intRouteBatchNo) || '] ' ||
        'Delete LAS_PALLET #rows[' || TO_CHAR(SQL%ROWCOUNT) || ']',
        NULL, NULL);

      FOR cgt IN c_get_truckinfo LOOP
      /*  01/25/10  - 12554 - gsaj0457 - Added for 212 Enh - SCE018 - Begin  */  
        BEGIN
            
            /* Get the Add On Route from Route Table */
             SELECT NVL(ADD_ON_ROUTE_SEQ,0),ROUTE_NO
             INTO iAddOnRoute, iRouteNo
             FROM ROUTE
             WHERE ROUTE_NO = cgt.ROUTE_NO;
         
         pl_text_log.ins_msg('W',
        gl_pkg_name || '.PopulateLASTruck',
        'PopulateLASTruck ' || 'Add-On Route :' || iAddOnRoute ||
        'Route batch[' || TO_CHAR(intRouteBatchNo) || ']',
        NULL, NULL);  
        
         /* If Add on Route is not null, delete from add las_pallet */ 
        IF iAddOnRoute IS NOT NULL AND iAddOnRoute > 0 THEN       
            DELETE las_pallet
            WHERE TRUCK IN (SELECT TRUCK_NO 
                  FROM ROUTE 
                  WHERE ROUTE_BATCH_NO = intRouteBatchNo)
            AND BATCH IN (SELECT BATCH_NO
            FROM FLOATS 
            WHERE ROUTE_NO = iRouteNo);           
    
         /*If the Add On Route is null, then fetch the cube vales from the cursor*/
            OPEN c_get_las_truck_info(cgt.truck_no);
            FETCH c_get_las_truck_info INTO iCurrentCubeDry, iCurrentCubeCooler, iCurrentCubeFreezer;
                    
            /* Calculate the iCubeDry with the value from las_truck*/        
             iCubeDry := iCurrentCubeDry + cgt.dry_cube;
            IF LENGTH(TO_CHAR(iCubeDry)) > iCubeLength THEN
             iCubeDry := ROUND(iCubeDry);
              IF LENGTH(TO_CHAR(iCubeDry)) > iCubeLength THEN
            iCubeDry := TO_NUMBER(RPAD('9', iCubeLength, '9'));
              END IF;
            END IF;

            /* Calculate the iCubeCooler with the value from las_truck*/    
            iCubeCooler := iCurrentCubeCooler + cgt.cooler_cube;
            IF LENGTH(TO_CHAR(iCubeCooler)) > iCubeLength THEN
              iCubeCooler := ROUND(iCubeCooler);
              IF LENGTH(TO_CHAR(iCubeCooler)) > iCubeLength THEN
            iCubeCooler := TO_NUMBER(RPAD('9', iCubeLength, '9'));
              END IF;
            END IF;

            /* Calculate the iCubeFreezer with the value from las_truck*/    
            iCubeFreezer := iCurrentCubeFreezer + cgt.freezer_cube;
            IF LENGTH(TO_CHAR(iCubeFreezer)) > iCubeLength THEN
              iCubeFreezer := ROUND(iCubeFreezer);
              IF LENGTH(TO_CHAR(iCubeFreezer)) > iCubeLength THEN
            iCubeFreezer := TO_NUMBER(RPAD('9', iCubeLength, '9'));
              END IF;
           END IF;

           /* Update the las_truck table*/
            UPDATE LAS_TRUCK
                SET TRUCK = cgt.truck_no, 
                    DRY_PALLETS = TO_CHAR(TO_NUMBER(DRY_PALLETS)  + cgt.dry_pallets),
                    DRY_CASES = TO_CHAR(TO_NUMBER(DRY_CASES)  + cgt.dry_cases), 
                    DRY_STOPS = TO_CHAR(TO_NUMBER(DRY_STOPS) + cgt.dry_stops),
                    DRY_CUBE = TO_CHAR(iCubeDry), 
                    DRY_REMAINING = TO_CHAR(TO_NUMBER(DRY_REMAINING) + cgt.dry_remaining),
                    COOLER_PALLETS = TO_CHAR(TO_NUMBER(COOLER_PALLETS) + cgt.cooler_pallets),   
                    COOLER_CASES = TO_CHAR(TO_NUMBER(COOLER_CASES) + cgt.cooler_cases), 
                    COOLER_STOPS = TO_CHAR(TO_NUMBER(COOLER_STOPS) + cgt.cooler_stops),
                    COOLER_CUBE = TO_CHAR(iCubeCooler),
                    COOLER_REMAINING = TO_CHAR(TO_NUMBER(COOLER_REMAINING) + cgt.cooler_remaining),
                    FREEZER_PALLETS = TO_CHAR(TO_NUMBER(FREEZER_PALLETS) + cgt.freezer_pallets), 
                    FREEZER_CASES = TO_CHAR(TO_NUMBER(FREEZER_CASES) + cgt.freezer_cases),
                    FREEZER_STOPS = TO_CHAR(TO_NUMBER(FREEZER_STOPS) + cgt.freezer_stops),
                    FREEZER_CUBE = TO_CHAR(iCubeFreezer),
                    FREEZER_REMAINING = TO_CHAR(TO_NUMBER(FREEZER_REMAINING) + cgt.freezer_remaining),
                    DRY_STATUS  = DECODE(DRY_STATUS,'C',DECODE(cgt.dry_remaining,0,'C',''),DRY_STATUS),                 
                    COOLER_STATUS  = DECODE(COOLER_STATUS,'C',DECODE(cgt.cooler_remaining,0,'C',''),COOLER_STATUS), 
                    FREEZER_STATUS  = DECODE(FREEZER_STATUS,'C',DECODE(cgt.freezer_remaining,0,'C',''),FREEZER_STATUS)
              WHERE TRUCK = cgt.truck_no;
        
            pl_log.ins_msg('W',gl_pkg_name || '.PopulateLASTruck',
            'PopulateLASTruck and Updated the LAS_TRUCK' 
             || ' error[' ||
                    TO_CHAR(SQLCODE) || ']',
            NULL, NULL); 
        ELSE
         /*  01/25/10  - 12554 - gsaj0457 - Added for 212 Enh - SCE018 - End  */  

            iCubeDry := cgt.dry_cube;
            IF LENGTH(TO_CHAR(iCubeDry)) > iCubeLength THEN
              iCubeDry := ROUND(iCubeDry);
              IF LENGTH(TO_CHAR(iCubeDry)) > iCubeLength THEN
            iCubeDry := TO_NUMBER(RPAD('9', iCubeLength, '9'));
              END IF;
            END IF;

            iCubeCooler := cgt.cooler_cube;
            IF LENGTH(TO_CHAR(iCubeCooler)) > iCubeLength THEN
              iCubeCooler := ROUND(iCubeCooler);
              IF LENGTH(TO_CHAR(iCubeCooler)) > iCubeLength THEN
            iCubeCooler := TO_NUMBER(RPAD('9', iCubeLength, '9'));
              END IF;
            END IF;

            iCubeFreezer := cgt.freezer_cube;
            IF LENGTH(TO_CHAR(iCubeFreezer)) > iCubeLength THEN
              iCubeFreezer := ROUND(iCubeFreezer);
              IF LENGTH(TO_CHAR(iCubeFreezer)) > iCubeLength THEN
            iCubeFreezer := TO_NUMBER(RPAD('9', iCubeLength, '9'));
              END IF;
            END IF;

            pl_text_log.ins_msg('W',
            gl_pkg_name || '.PopulateLASTruck',
            'PopulateLASTruck ' ||
            'Route batch[' || TO_CHAR(intRouteBatchNo) || '] ' ||
            'truck[' || cgt.truck_no || '] route[' || cgt.route_no||
            '] select sqlcode[' || TO_CHAR(iCode) || ']',
            NULL, NULL);
/*      pl_nos.insert_slt_action_log('POPULATELASTRUCK',
            'Route batch[' || TO_CHAR(intRouteBatchNo) || '] ' ||
            'truck[' || cgt.truck_no || '] route[' || cgt.route_no||
            '] select sqlcode[' || TO_CHAR(iCode) || ']',
            'INFO', 'Y');*/
              INSERT INTO las_truck
            (TRUCK, ROUTE_NO,
             DRY_PALLETS, DRY_CASES, DRY_STOPS, DRY_CUBE, DRY_REMAINING,
             COOLER_PALLETS, COOLER_CASES, COOLER_STOPS,
             COOLER_CUBE, COOLER_REMAINING,
             FREEZER_PALLETS, FREEZER_CASES, FREEZER_STOPS,
             FREEZER_CUBE, FREEZER_REMAINING)
            VALUES (
             cgt.truck_no, cgt.route_no,
             cgt.dry_pallets, cgt.dry_cases, cgt.dry_stops,
             TO_CHAR(iCubeDry), cgt.dry_remaining,
             cgt.cooler_pallets, cgt.cooler_cases, cgt.cooler_stops,
             TO_CHAR(iCubeCooler), cgt.cooler_remaining,
             cgt.freezer_pallets, cgt.freezer_cases, cgt.freezer_stops,
             TO_CHAR(iCubeFreezer), cgt.freezer_remaining);

              pl_text_log.ins_msg('W',
            gl_pkg_name || '.PopulateLASTruck',
            'PopulateLASTruck ' ||
            'Route batch[' || TO_CHAR(intRouteBatchNo) || '] ' ||
            'truck[' || cgt.truck_no || '] route[' || cgt.route_no ||
            '] insert #rows[' || TO_CHAR(SQL%ROWCOUNT) || ']',
            NULL, NULL);
         /*  01/25/10  - 12554 - gsaj0457 - Added for 212 Enh - SCE018 - Begin */  
        END IF;
         /*  01/25/10  - 12554 - gsaj0457 - Added for 212 Enh - SCE018 - End  */  

          PopulateLASPallet(intRouteBatchNo, cgt.route_no, cgt.truck_no);

        EXCEPTION
          WHEN OTHERS THEN
        pl_text_log.ins_msg('W',
            gl_pkg_name || '.PopulateLASTruck',
            'PopulateLASTruck In Loop When Others error[' ||
            TO_CHAR(SQLCODE) || '] ' ||
            'Route batch[' || TO_CHAR(intRouteBatchNo) ||
            '] truck[' || cgt.truck_no || '] ' ||
            'route[' || cgt.route_no || '] ' ||
            'dry[' || TO_CHAR(cgt.dry_pallets) || '/' ||
            TO_CHAR(cgt.dry_cases) || '/' ||
            TO_CHAR(cgt.dry_stops) || '/' ||
            TO_CHAR(cgt.dry_remaining) || '/' ||
            TO_CHAR(iCubeDry) || '] ' ||
            'cooler[' || TO_CHAR(cgt.cooler_pallets) || '/' ||
            TO_CHAR(cgt.cooler_cases) || '/' ||
            TO_CHAR(cgt.cooler_stops) || '/' ||
            TO_CHAR(cgt.cooler_remaining) || '/' ||
            TO_CHAR(iCubeCooler) || '] ' ||
            'frz[' || TO_CHAR(cgt.freezer_pallets) || '/' ||
            TO_CHAR(cgt.freezer_cases) || '/' ||
            TO_CHAR(cgt.freezer_stops) || '/' ||
            TO_CHAR(cgt.freezer_remaining) || '/' ||
            TO_CHAR(iCubeFreezer) || ']',
            NULL, NULL);

        -- Since the truck exists, we will see if we can replace the
        -- truck data with the information from the latest generated
        -- truck or not.
        sRoute := NULL;
        sStatus := NULL;
        iRouteBatch := NULL;
        iCode := 0;
        OPEN c_get_truck_info(cgt.truck_no, cgt.route_no);
        FETCH c_get_truck_info INTO sStatus, sRoute, iRouteBatch;
        IF c_get_truck_info%NOTFOUND THEN
          -- No parent route has the same truck in the system
          sRoute := NULL;
          sStatus := NULL;
          iRouteBatch := NULL;
          iCode := 1;
        END IF;

        -- If current route is a cling-on, no truck info should be
        -- updated.
        -- Otherwise, if there is an existing route (other than this
        -- one) which is OPN or SHT, no truck info should be updated.
        BEGIN
              UPDATE las_truck
             SET route_no = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, route_no, cgt.route_no),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, route_no,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.route_no,
                        'NEW', cgt.route_no,
                        'RCV', cgt.route_no,
                        'WAT', cgt.route_no,
                        route_no))),
             dry_pallets = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_pallets, cgt.dry_pallets),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_pallets,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.dry_pallets,
                        'NEW', cgt.dry_pallets,
                        'RCV', cgt.dry_pallets,
                        'WAT', cgt.dry_pallets,
                        dry_pallets))),
             dry_cases = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_cases, cgt.dry_cases),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_cases,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.dry_cases,
                        'NEW', cgt.dry_cases,
                        'RCV', cgt.dry_cases,
                        'WAT', cgt.dry_cases,
                        dry_cases))),
             dry_stops = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_stops, cgt.dry_stops),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_stops,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.dry_stops,
                        'NEW', cgt.dry_stops,
                        'RCV', cgt.dry_stops,
                        'WAT', cgt.dry_stops,
                        dry_stops))),
             dry_cube = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_cube, TO_CHAR(iCubeDry)),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_cube,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', TO_CHAR(iCubeDry),
                        'NEW', TO_CHAR(iCubeDry),
                        'RCV', TO_CHAR(iCubeDry),
                        'WAT', TO_CHAR(iCubeDry),
                        dry_cube))),
             dry_remaining = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_remaining, cgt.dry_remaining),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_remaining,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.dry_remaining,
                        'NEW', cgt.dry_remaining,
                        'RCV', cgt.dry_remaining,
                        'WAT', cgt.dry_remaining,
                        dry_remaining))),
             dry_status = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_status, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_status,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        dry_status))),
             cooler_pallets = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_pallets, cgt.cooler_pallets),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_pallets,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.cooler_pallets,
                        'NEW', cgt.cooler_pallets,
                        'RCV', cgt.cooler_pallets,
                        'WAT', cgt.cooler_pallets,
                        cooler_pallets))),
             cooler_cases = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_cases, cgt.cooler_cases),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_cases,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.cooler_cases,
                        'NEW', cgt.cooler_cases,
                        'RCV', cgt.cooler_cases,
                        'WAT', cgt.cooler_cases,
                        cooler_cases))),
             cooler_stops = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_stops, cgt.cooler_stops),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_stops,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.cooler_stops,
                        'NEW', cgt.cooler_stops,
                        'RCV', cgt.cooler_stops,
                        'WAT', cgt.cooler_stops,
                        cooler_stops))),
             cooler_cube = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_cube, TO_CHAR(iCubeCooler)),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_cube,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', TO_CHAR(iCubeCooler),
                        'NEW', TO_CHAR(iCubeCooler),
                        'RCV', TO_CHAR(iCubeCooler),
                        'WAT', TO_CHAR(iCubeCooler),
                        cooler_cube))),
             cooler_remaining = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_remaining,
                    cgt.cooler_remaining),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_remaining,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.cooler_remaining,
                        'NEW', cgt.cooler_remaining,
                        'RCV', cgt.cooler_remaining,
                        'WAT', cgt.cooler_remaining,
                        cooler_remaining))),
             cooler_status = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_status, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_status,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        cooler_status))),
             freezer_pallets = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_pallets,
                    cgt.freezer_pallets),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_pallets,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.freezer_pallets,
                        'NEW', cgt.freezer_pallets,
                        'RCV', cgt.freezer_pallets,
                        'WAT', cgt.freezer_pallets,
                        freezer_pallets))),
             freezer_cases = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_cases, cgt.freezer_cases),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_cases,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.freezer_cases,
                        'NEW', cgt.freezer_cases,
                        'RCV', cgt.freezer_cases,
                        'WAT', cgt.freezer_cases,
                        freezer_cases))),
             freezer_stops = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_stops, cgt.freezer_stops),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_stops,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.freezer_stops,
                        'NEW', cgt.freezer_stops,
                        'RCV', cgt.freezer_stops,
                        'WAT', cgt.freezer_stops,
                        freezer_stops))),
             freezer_cube = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_cube, TO_CHAR(iCubeFreezer)),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_cube,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', TO_CHAR(iCubeFreezer),
                        'NEW', TO_CHAR(iCubeFreezer),
                        'RCV', TO_CHAR(iCubeFreezer),
                        'WAT', TO_CHAR(iCubeFreezer),
                        freezer_cube))),
             freezer_remaining = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_remaining,
                    cgt.freezer_remaining),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_remaining,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', cgt.freezer_remaining,
                        'NEW', cgt.freezer_remaining,
                        'RCV', cgt.freezer_remaining,
                        'WAT', cgt.freezer_remaining,
                        freezer_remaining))),
             freezer_status = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_status, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_status,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        freezer_status))),
             trailer = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, trailer, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, trailer,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        trailer))),
             trailer_type = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, trailer_type, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, trailer_type,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        trailer_type))),
             loader = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, loader, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, loader,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        loader))),
             start_time = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, start_time, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, start_time,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        start_time))),
             complete_time = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, complete_time, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, complete_time,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        complete_time))),
             complete_user = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, complete_user, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, complete_user,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        complete_user))),
             last_pallet = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, last_pallet, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, last_pallet,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        last_pallet))),
             truck_status = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, truck_status, 'N'),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, truck_status,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', 'N',
                        'NEW', 'N',
                        'RCV', 'N',
                        'WAT', 'N',
                        truck_status))),
             note1 = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, note1, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, note1,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        note1))),
             note2 = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, note2, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, note2,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        note2))),
             note3 = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, note3, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, note3,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        note3))),
             dry_complete_time = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_complete_time, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_complete_time,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        dry_complete_time))),
             dry_complete_user = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_complete_user, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, dry_complete_user,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        dry_complete_user))),
             cooler_complete_time = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_complete_time, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_complete_time,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        cooler_complete_time))),
             cooler_complete_user = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_complete_user, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, cooler_complete_user,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        cooler_complete_user))),
             freezer_complete_time = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_complete_time, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_complete_time,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        freezer_complete_time))),
             freezer_complete_user = DECODE(iCode,
                1, DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_complete_user, NULL),
                DECODE(SIGN(INSTR(cgt.route_no, ' ')),
                    1, freezer_complete_user,
                    DECODE(NVL(sStatus, ' '),
                        'CLS', NULL,
                        'NEW', NULL,
                        'RCV', NULL,
                        'WAT', NULL,
                        freezer_complete_user)))
             WHERE truck = cgt.truck_no
               AND truck = (SELECT truck_no
                    FROM route
                    WHERE route_no = cgt.route_no
                    AND   route_batch_no = intRouteBatchNo);
          pl_text_log.ins_msg('W',
            gl_pkg_name || '.PopulateLASTruck',
            'PopulateLASTruck In Loop When Others Update ' ||
            'Route batch[' || TO_CHAR(intRouteBatchNo) ||
            '] truck[' || cgt.truck_no || '] ' ||
            'route[' || cgt.route_no || '] ' ||
            '#row[' || TO_CHAR(SQL%ROWCOUNT) || '] ' ||
            'existing route[' || sRoute || '] rb[' ||
            TO_CHAR(iRouteBatch) || '] status[' || sStatus || ']',
            NULL, NULL);

          -- Truck information is updated with >= 0 record w/o problem
          -- for the existing truck record
          IF INSTR(cgt.route_no, ' ') = 0 THEN
            -- Current truck is a regular truck.
            -- If only one truck (of the current route) exists in the
            -- system currently or another route with same truck exists
            -- but it's not generated yet or in the process of being
            -- generated, we should clear LAS_PALLET for the truck and
            -- readd the floats for the current truck.
            IF iCode <> 0 OR
               ((iCode = 0) AND
            (NVL(sStatus, ' ') NOT IN ('OPN', 'SHT'))) THEN
              BEGIN
            DELETE las_pallet
             WHERE truck = cgt.truck_no;
            pl_text_log.ins_msg('W',
                gl_pkg_name || '.PopulateLASTruck',
                'PopulateLASTruck In Loop When Others Delete' ||
                ' LAS_PALLET Route batch[' ||
                TO_CHAR(intRouteBatchNo) ||
                '] truck[' || cgt.truck_no || '] ' ||
                'route[' || cgt.route_no || '] ' ||
                '#row[' || TO_CHAR(SQL%ROWCOUNT) || ']',
                NULL, NULL);
              EXCEPTION
            WHEN OTHERS THEN
              pl_text_log.ins_msg('W',
                gl_pkg_name || '.PopulateLASTruck',
                'PopulateLASTruck In Loop When Others Delete' ||
                ' LAS_PALLET Fail Route batch[' ||
                TO_CHAR(intRouteBatchNo) ||
                '] truck[' || cgt.truck_no || '] ' ||
                'route[' || cgt.route_no || '] ' ||
                'status[' || TO_CHAR(SQLCODE) || ']',
                NULL, NULL);
              END;
              PopulateLASPallet(intRouteBatchNo,
            cgt.route_no, cgt.truck_no);
            END IF;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            pl_text_log.ins_msg('W',
            gl_pkg_name || '.PopulateLASTruck',
            'PopulateLASTruck In Loop When Others Update Fail ' ||
            'Route batch[' || TO_CHAR(intRouteBatchNo) ||
            '] truck[' || cgt.truck_no || '] ' ||
            'route[' || cgt.route_no || '] ' ||
            'status[' || TO_CHAR(SQLCODE) || '] ' ||
            'existing route[' || sRoute || '] rb[' ||
            TO_CHAR(iRouteBatch) || '] status[' || sStatus || ']',
            NULL, NULL);
        END;
        END;
      END LOOP;

    EXCEPTION
      WHEN OTHERS THEN
        pl_text_log.ins_msg('W',
        gl_pkg_name || '.PopulateLASTruck',
        'PopulateLASTruck ' ||
        'Route batch[' || TO_CHAR(intRouteBatchNo) ||
        '] In When others error[' || TO_CHAR(SQLCODE) || ']',
        NULL, NULL);
    END PopulateLASTruck;

    PROCEDURE PopulateLASPallet (intRouteBatchNo        route.route_batch_no%TYPE,
                psRoute         route.route_no%TYPE,
                psTruck         route.truck_no%TYPE) IS
    BEGIN
        INSERT INTO las_pallet
            (Truck, selection_status,
             PalletNo, batch, max_stop, min_stop)
        SELECT  v.truck_no, 'S', v.float_seq,
            floats_batch_no,
            MAX (stop_no), MIN (stop_no)
          FROM  v_ob1rb v
         WHERE  v.route_batch_no = intRouteBatchNo
         AND    v.route_no = psRoute
         AND    v.truck_no = psTruck
         GROUP  BY v.truck_no, floats_batch_no, 'S', v.float_seq;
        pl_text_log.ins_msg('W',
            gl_pkg_name || '.PopulateLASPallet',
            'PopulateLASPallet ' ||
            'Route batch[' || TO_CHAR(intRouteBatchNo) || '] ' ||
            'route[' || psRoute || '] truck[' || psTruck || '] ' ||
            'insert #rows[' || TO_CHAR(SQL%ROWCOUNT) || ']',
            NULL, NULL);
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg('W',
                gl_pkg_name || '.PopulateLASPallet',
                'PopulateLASPallet ' ||
                'Route batch[' || TO_CHAR(intRouteBatchNo) ||
                '] In When others error[' ||
                TO_CHAR(SQLCODE) || '] ' ||
                'route[' || psRoute || '] truck[' || psTruck || ']',
                NULL, NULL);
    END PopulateLASPallet;

    FUNCTION UseCrossAisle (PrevDir     INTEGER,
                PrevAisle   INTEGER,
                PrevSlot    INTEGER,
                curDir      INTEGER,
                curAisle    INTEGER,
                curSlot     INTEGER)
    RETURN VARCHAR2
    IS
        lCrossAisle VARCHAR2 (1);
    BEGIN
        BEGIN
            SELECT  DECODE (PrevDir, CurDir,
                    DECODE (SIGN (PrevSlot - oldc.to_cross), -1, 'Y', 'N'),
                    DECODE (SIGN (PrevSlot - oldc.to_cross), -1,
                        DECODE (SIGN (CurSlot - newc.from_cross), 1, 'Y', 'N'),
                        'N'))
              INTO  lCrossAisle
              FROM  cross_aisle oldc, cross_aisle newc
             WHERE  oldc.pick_aisle = PrevAisle
               AND  newc.pick_aisle = CurAisle;
            EXCEPTION
                WHEN OTHERS THEN
                    lCrossAisle := 'N';
        END;
        RETURN lCrossAisle;
    END;
    PROCEDURE Create_ISTART (pUserId    batch.user_id%TYPE,
                 pBatchNo   batch.batch_no%TYPE,
                 pError     OUT INTEGER) IS
        lSuperId    usr.suprvsr_user_id%TYPE;
        lDuration   NUMBER;
        SKIP_REST   EXCEPTION;
        lTemp       batch.batch_no%TYPE;
    BEGIN
        pError := 0;
        BEGIN
            SELECT  batch_no
              INTO  lTemp
              FROM  batch b1
             WHERE  user_id = pUserId
               AND  jbcd_job_code = 'ISTART'
               AND  actl_start_time = 
                    (SELECT MAX(actl_start_time)
                     FROM batch
                     WHERE jbcd_job_code = b1.jbcd_job_code
                     AND   user_id = b1.user_id);
/*          pl_log.ins_msg('WARN', 'Create_ISTART',
                'U:' || pUserId || ', b: ' || lTemp ||
                ', D: ' ||
                TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
                NULL, NULL);*/
            DBMS_OUTPUT.PUT_LINE('Get previous ISTART: ' || lTemp);
            RAISE SKIP_REST;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
/*                  pl_log.ins_msg('WARN', 'Create_ISTART',
                    '1403- U:' || pUserId || ', D: ' ||
                    TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
                    NULL, NULL);*/
                    DBMS_OUTPUT.PUT_LINE('No ISTART found');
                WHEN SKIP_REST THEN
/*                  pl_log.ins_msg('WARN', 'Create_ISTART',
                    'SKIP_REST- U:' || pUserId || ', D: ' ||
                    TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
                    NULL, NULL);*/
                    lTemp := -1;
                    DBMS_OUTPUT.PUT_LINE('Get previous ISTART SKIP_REST');
                WHEN TOO_MANY_ROWS THEN
/*                  pl_log.ins_msg('WARN', 'Create_ISTART',
                    'TOO_MANY_ROWS- U:' || pUserId ||
                    ', D: ' ||
                    TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
                    NULL, NULL);*/
                    DBMS_OUTPUT.PUT_LINE('Get previous ISTART TOO_MANY_ROWS');
                    RAISE SKIP_REST;
                WHEN OTHERS THEN
/*                  pl_log.ins_msg('WARN', 'Create_ISTART',
                    'OTHERS- U:' || pUserId ||
                    ', E: ' || TO_CHAR(SQLCODE) ||
                    ', D: ' ||
                    TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
                    NULL, NULL);*/
                    pError := SQLCODE;
                    DBMS_OUTPUT.PUT_LINE('Get previous ISTART Error: ' || TO_CHAR(SQLCODE));
                    RAISE SKIP_REST;
        END;
        IF (lTemp = -1) THEN
            RAISE SKIP_REST;
        END IF;
        BEGIN
            SELECT  suprvsr_user_id
              INTO  lSuperId
              FROM  usr
             WHERE  user_id = 'OPS$' || pUserId;
            EXCEPTION
                WHEN OTHERS THEN NULL;
        END;
        DBMS_OUTPUT.PUT_LINE('Supervisor ' || lSuperId ||
            ' for user ' || pUserId || ' bat[' || pBatchNo || ']');
        BEGIN
            SELECT  NVL ( st.start_dur, 0 )
              INTO  lDuration
              FROM  sched_type st, sched s, usr u, batch b, job_code jc
             WHERE  st.sctp_sched_type = s.sched_type
               AND  s.sched_lgrp_lbr_grp = u.lgrp_lbr_grp
               AND  s.sched_jbcl_job_class = jc.jbcl_job_class
               AND  s.sched_actv_flag = 'Y'
               AND  u.user_id = 'OPS$' || pUserId
               AND  jc.jbcd_job_code = b.jbcd_job_code
               AND  b.batch_no = 'S' || pBatchNo;
            EXCEPTION
                WHEN OTHERS THEN
                    lDuration := 0;
        END;
        DBMS_OUTPUT.PUT_LINE('Duration ' || TO_CHAR(lDuration) ||
            ' for user ' || pUserId);
        INSERT INTO batch (batch_no, batch_date, jbcd_job_code,
            status, actl_start_time, actl_stop_time, user_id,
            user_supervsr_id,actl_time_spent,kvi_doc_time,
            kvi_cube, kvi_wt, kvi_no_piece,
            kvi_no_pallet, kvi_no_item,
            kvi_no_data_capture, kvi_no_po,
            kvi_no_stop, kvi_no_zone, kvi_no_loc,
            kvi_no_case, kvi_no_split,
            kvi_no_merge, kvi_no_aisle,
            kvi_no_drop, kvi_order_time,
            no_lunches, no_breaks, damage)
        VALUES
            ('I' || TO_CHAR (seq1.NEXTVAL ), TRUNC (SYSDATE), 'ISTART',
            'C', (SYSDATE - (NVL (lDuration, 0) / 1440)), SYSDATE,
            pUserId, lSuperId, lDuration, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        EXCEPTION
            WHEN SKIP_REST THEN
                DBMS_OUTPUT.PUT_LINE('Insert BATCH SKIP_REST');
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Insert BATCH Error: ' ||
                    TO_CHAR(SQLCODE));
                pError := SQLCODE;
    
    END Create_ISTART;

    ------------------------------------------------------------------------
    -- Procedure:
    --    get_picked_pieces
    --
    -- Description:
    --    The function retrieves accumulated total # of pieces (cases + splits)
    --   that have been picked so far for the input batch psBatch. The
    --    search is from FLOAT_HIST with picktime <> NULL.
    --
    -- Parameters:
    --    psBatch - Batch # to be searched. The value should only include all
    --              digits.
    --
    FUNCTION get_picked_pieces(psBatch  IN sos_batch.batch_no%TYPE)
    RETURN NUMBER IS
        iSum        NUMBER := 0;
        sBatchType  VARCHAR2(1) := SUBSTR(psBatch, 1, 1);
    BEGIN
        SELECT  
            SUM(DECODE(sBatchType,
                'S', NVL(qty_short, 0), NVL(qty_alloc, 0)) /
                DECODE(h.uom, 1, 1, p.spc))
          INTO  iSum
          FROM  float_hist h, pm p
         WHERE  ((h.batch_no = psBatch) OR (h.short_batch_no = psBatch))
           AND  h.prod_id = p.prod_id
           AND  h.cust_pref_vendor = p.cust_pref_vendor
           AND  DECODE(sBatchType,
                'S', h.short_picktime, h.picktime) IS NOT NULL;
        RETURN iSum;
    END get_picked_pieces;
    FUNCTION F_GetShortBatchStatus (pShortBatchNo  IN sos_batch.batch_no%TYPE)
    RETURN VARCHAR2 IS
        lStatus sos_batch.status%TYPE;
    BEGIN
        BEGIN
            SELECT  status
              INTO  lStatus
              FROM  sos_batch
             WHERE  batch_no = pShortBatchNo;
            EXCEPTION
                WHEN OTHERS THEN
                    lStatus := 'X';
        END;
        RETURN lStatus;
    END F_GetShortBatchStatus;
    
    FUNCTION get_batch_cube(psBatch IN batch.batch_no%TYPE)
    RETURN NUMBER IS
        iCube   batch.kvi_cube%TYPE := NULL;
    BEGIN
        SELECT NVL(SUM(kvi_cube), 0) INTO iCube
        FROM v_sos_training
        WHERE batch_no = 'S' || psBatch;
        RETURN iCube;
        IF NVL(iCube, 0) = 0 THEN
            pl_log.ins_msg('WARN', gl_pkg_name || '.get_batch_cube',
                'In get_batch_cube batch [' ||
                psBatch || '] Cube is zero', NULL, NULL);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            pl_log.ins_msg('WARN', gl_pkg_name || '.get_batch_cube',
                'In get_batch_cube batch [' ||
                psBatch || '] status [' ||
                TO_CHAR(SQLCODE), NULL, NULL);
            RETURN 0;
    END;

    FUNCTION get_batch_wt(psBatch IN batch.batch_no%TYPE)
    RETURN NUMBER IS
        iWt batch.kvi_wt%TYPE := NULL;
    BEGIN
        SELECT NVL(kvi_wt, 0) INTO iWt
        FROM v_sos_training
        WHERE batch_no = 'S' || psBatch;
        RETURN iWt;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END;

    FUNCTION get_route_info(
        psBatch IN batch.batch_no%TYPE,
        psType  IN VARCHAR2 DEFAULT 'B')
    RETURN VARCHAR2 IS
        sRouteBatch route.route_batch_no%TYPE := NULL;
        sRoute      route.route_no%TYPE := NULL;
        sTruck      route.truck_no%TYPE := NULL;
        blnExists   BOOLEAN := TRUE;
        sData       VARCHAR2(100) := NULL;
        CURSOR c_get_r_info IS
            SELECT DISTINCT f.route_no, f.truck_no
            FROM floats f
            WHERE f.batch_no = TO_NUMBER(psBatch);
        CURSOR c_get_br_info(
            r route.route_no%TYPE, t route.truck_no%TYPE) IS
            SELECT DISTINCT TO_CHAR(route_batch_no) route_batch_no
            FROM route
            WHERE route_no = r
            AND   truck_no = t;
    BEGIN
        IF SUBSTR(psBatch, 1, 1) = 'S' THEN
            -- This is a short batch
            RETURN '-1';
        END IF;
        FOR cgri IN c_get_r_info LOOP
            blnExists := TRUE;
            sRoute := cgri.route_no;
            sTruck := cgri.truck_no;
            FOR cgrbi IN c_get_br_info(cgri.route_no, cgri.truck_no)
            LOOP
                sRouteBatch := cgrbi.route_batch_no;
            END LOOP;
        END LOOP;
        IF NOT blnExists THEN
            RETURN '-1';
        ELSE
            FOR i IN 1 .. LENGTH(psType) LOOP
                IF SUBSTR(psType, i, 1) = 'B' THEN
                    IF sData IS NOT NULL THEN
                        sData := sData || '|';
                    END IF;
                    sData := sData || sRouteBatch;
                END IF; 
                IF SUBSTR(psType, i, 1) = 'R' THEN
                    IF sData IS NOT NULL THEN
                        sData := sData || '|';
                    END IF;
                    sData := sData || sRoute;
                END IF; 
                IF SUBSTR(psType, i, 1) = 'T' THEN
                    IF sData IS NOT NULL THEN
                        sData := sData || '|';
                    END IF;
                    sData := sData || sTruck;
                END IF; 
            END LOOP;
            IF LENGTH(psType) > 1 AND sData IS NOT NULL THEN
                sData := sData || '|';
            END IF;
        END IF;
        RETURN sData;
    END;

    
    ------------------------------------------------------------------------
    -- Procedure:
    --    create_SYS04_addorder
    --
    -- Description:
    --    This procedure send SYS04 transaction to Symbotic for a batch.
    --    This transaction contain details of order generation of the item  
    --    for which inventory is in Symbotic.
    --
    -- Parameters:
    --    i_batch_no   - Batch no for which messageneed to be send.
    --
    --  Modification Log
    --  Date        Developer       Comments
    -- -----------  ------------    ---------------------------------------------
    -- 17-OCT-2014   AYAD5195       Inittial Creation
    ----------------------------------------------------------------------------
   
    PROCEDURE create_SYS04_addorder (i_batch_no  IN  VARCHAR2,
                                     o_status    OUT  NUMBER)
    IS        
        l_fname             VARCHAR2 (50)       := 'create_SYS04_addorder';
        
        CURSOR c_sos_batch IS
            SELECT sb.priority  
              FROM SOS_BATCH sb
             WHERE sb.batch_no = i_batch_no;
      
        CURSOR c_sos_batch_info IS
            SELECT vs.order_id, vs.route_no, vs.stop_no, vs.order_seq, vs.prod_id, TRUNC(vs.qty_alloc/vs.spc) case_qty, vs.batch_seq, 
                   vs.float_char, vs.zone, vs.cust_name, vs.cust_id, vs.item_descrip, vs.pack, vs.float_seq, vs.door_no,
                   vs.src_loc, vs.bc_st_piece_seq, vs.qty_alloc, vs.batch_no, vs.truck_no, vs.price, vs.cust_po, vs.ship_date,  vs.fd_qty_short,       
                   vs.carrier_id, vs.order_type, vs.no_of_floats, vs.fd_seq_no, 
                   DECODE (vs.uom, 1, vs.label_max_seq, vs.label_max_seq / vs.spc) label_max_seq, vs.immediate_ind, vs.float_no
              FROM v_sos_batch_info vs, loc l
             WHERE vs.batch_no = i_batch_no
               AND vs.src_loc = l.logi_loc
               AND l.slot_type IN ('MXF', 'MXC')
             ORDER BY vs.order_seq ;
                
        e_fail              EXCEPTION;   
        l_sys_msg_id        NUMBER;
        l_sys15_msg_id      NUMBER;
        l_sys15_cnt         NUMBER;
        l_ret_val           NUMBER;
        l_pallet_id         VARCHAR2(18);
        l_rec_cnt           NUMBER := 0;
        l_print_stream      CLOB;
        l_case_barcode      VARCHAR2(20);
        l_sequence_number   NUMBER;
        l_exact_palle_imp   VARCHAR2(4);
        l_is_short          BOOLEAN;  
        l_print_logo        BOOLEAN; 
        l_print_logo_yn     VARCHAR2(1); 
        l_msg_text          VARCHAR2(512);     
        l_first_time        NUMBER;
        l_order_seq         NUMBER;     
        l_prev_order_id     v_sos_batch_info.order_id%TYPE;
        l_encode_print_stream    RAW(32767);        
        l_prev_order_seq    float_detail.order_seq%TYPE;    
        l_heavy_case_count  NUMBER;
        l_light_case_count  NUMBER;
        l_min_pik_path      loc.pik_path%TYPE;
        l_case_seq          NUMBER;
        l_priority          NUMBER;
        l_rbn               route.route_batch_no%TYPE;        
        l_wave_in_progress  NUMBER;
        l_cust_rotation_rules matrix_out.customer_rotation_rules%TYPE;

    BEGIN
        o_status := C_SUCCESS;
        l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;
        l_sys15_msg_id := NULL;

        BEGIN
            SELECT DISTINCT NVL(r.mx_wave_number, r.route_batch_no) rbn
              INTO l_rbn
              FROM route r
             WHERE r.route_no IN (SELECT route_no 
                                    FROM floats 
                                   WHERE batch_no = i_batch_no)
               AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS THEN
                Pl_Text_Log.ins_msg ('FATAL', l_fname, 'Failed to find route_batch_no from route for batch_no '||i_batch_no, SQLCODE, SQLERRM);
                l_rbn := 0; 
        END;
            
        FOR rec IN c_sos_batch
        LOOP            
            l_rec_cnt := 0;    
            l_first_time := 1;
            l_order_seq := 1;
            FOR rc IN c_sos_batch_info
            LOOP   
                IF l_first_time = 1 THEN            
                    l_prev_order_id := rc.order_id;
                    l_prev_order_seq := rc.order_seq;
                    l_first_time := 0;
                END IF;
                
                IF l_prev_order_id != rc.order_id THEN
                    l_order_seq := l_order_seq + 1;
                END IF;
                
                BEGIN
                    SELECT DISTINCT mx_priority
                      INTO l_priority
                      FROM floats
                     WHERE batch_no = i_batch_no
                       AND ROWNUM = 1;
                    
                    SELECT mx_exact_pallet_imp 
                      INTO l_exact_palle_imp
                      FROM auto_orders
                     WHERE order_type = rc.order_type
                       AND immediate_ind = rc.immediate_ind
                       AND rownum = 1;
                EXCEPTION
                    WHEN OTHERS THEN
                        Pl_Text_Log.ins_msg ('FATAL', l_fname, 'Not able to find mx_exact_pallet_imp from table auto_orders for order_type ['||
                                             rc.order_type||'] and immediate_ind ['||rc.immediate_ind||']', SQLCODE, SQLERRM);
                        l_exact_palle_imp := 'LOW';
                        l_priority := 3;
                END;

                -- Determining the customer rotation rules 
                -- Sont5129 10/14/2015

                BEGIN

                    SELECT nvl(mx_rotation_rules, 'NONE')
                      INTO l_cust_rotation_rules 
                      FROM pm
                     WHERE prod_id = rc.prod_id;

                EXCEPTION
                   WHEN OTHERS THEN
                    Pl_Text_Log.ins_msg ('I', l_fname, 'Not able to determine customer rotation rules for prod_id [' ||rc.prod_id||']', SQLCODE, SQLERRM);
                    l_cust_rotation_rules := 'NONE';
                END;

                l_rec_cnt := l_rec_cnt + 1;
                l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                                  i_interface_ref_doc => 'SYS04',
                                                                  i_rec_ind => 'D',
                                                                  i_order_id => rc.order_id,
                                                                  i_route => rc.route_no,
                                                                  i_stop => rc.stop_no,
                                                                  i_order_type => rc.order_type,
                                                                  i_order_sequence => rc.order_seq,
                                                                  i_priority_identifier => NVL(l_priority, 2),
                                                                  i_cust_rotation_rules => l_cust_rotation_rules, --taking from pm table --sont5129
                                                                  i_prod_id => rc.prod_id,
                                                                  i_case_qty => rc.case_qty,
                                                                  i_float_id => rc.batch_seq,
                                                                  i_pallet_id => rc.carrier_id,
                                                                  i_exact_pallet_imp => l_exact_palle_imp,
                                                                  i_wave_number => l_rbn,
                                                                  i_batch_id => i_batch_no           --Inserting the batch Id for debugging   --sont5129                                                  
                                                                 );
            
                BEGIN
                    SELECT sequence_number 
                      INTO  l_sequence_number
                      FROM (  SELECT sequence_number
                                FROM matrix_out 
                               WHERE prod_id = rc.prod_id
                                 AND float_id = rc.batch_seq
                                 AND case_qty = rc.case_qty
                                 AND sys_msg_id = l_sys_msg_id
                                 AND interface_ref_doc = 'SYS04'                                    
                                 ORDER BY sequence_number DESC)
                     WHERE rownum = 1;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN             
                        l_msg_text := 'Prog Code: ' || l_fname
                                || ' Unable to find sequence number of detail record (SYS04) record for prod_id '||rc.prod_id || ' and sys_msg_id '||l_sys_msg_id;
                        RAISE e_fail;
                END;
            
                IF l_prev_order_seq != rc.order_seq THEN
                    l_prev_order_seq := rc.order_seq;
                END IF;
                
                --Populate case number and Label in table matrix_out_label 
                BEGIN
                    FOR rc_case IN (SELECT case_id
                                      FROM mx_float_detail_cases
                                     WHERE order_id = rc.order_id
                                       AND order_seq = rc.order_seq
                                       AND float_detail_seq_no = rc.fd_seq_no
                                       AND batch_no = i_batch_no
                                       AND float_no = rc.float_no) 
                    LOOP                       
                        
                        l_case_barcode := rc_case.case_id;
                        l_case_seq := TO_NUMBER(SUBSTR(l_case_barcode, length(l_case_barcode) - 2, 3));
                        IF rc.fd_qty_short > 0 THEN
                            l_is_short := TRUE;
                        ELSE
                            l_is_short := FALSE;
                        END IF;
                        
                        l_print_logo_yn := pl_matrix_common.get_sys_config_val('PRINT_LOGO_ON_SOS_LABEL');
                        
                        IF l_print_logo_yn = 'Y' THEN
                            l_print_logo := TRUE;
                        ELSE
                            l_print_logo := FALSE;
                        END IF; 
                
                        l_print_stream := pl_mx_gen_label.ZplPickLabel(printLogo => l_print_logo,
                                                                       doFloatShading => FALSE ,
                                                                       isShort => l_is_short,
                                                                       isMulti => FALSE,
                                                                       floatChar => rc.float_char,
                                                                       floatZone => rc.zone,
                                                                       numFloats => rc.no_of_floats,
                                                                       custName => rc.cust_name,
                                                                       custNumber => rc.cust_id,
                                                                       itemDesc => rc.item_descrip,
                                                                       pack => rc.pack,
                                                                       floatNum => rc.float_seq,
                                                                       dockDoor => rc.door_no,
                                                                       slotNo => rc.src_loc,
                                                                       userId => 'SYMBOTIC',
                                                                       qtySec => l_case_seq,
                                                                       totQty => rc.label_max_seq,
                                                                       invoice => rc.order_id,
                                                                       batch => rc.batch_no,
                                                                       truck => rc.truck_no,
                                                                       stop => rc.stop_no,
                                                                       caseBarCode => l_case_barcode,
                                                                       item => rc.prod_id,
                                                                       price => rc.price,
                                                                       custPo => rc.cust_po,
                                                                       invoiceDate => rc.ship_date
                                                                      );
                        
                        l_encode_print_stream := utl_encode.base64_encode(utl_raw.cast_to_raw(l_print_stream));                        
                        
                        INSERT INTO matrix_out_label (sequence_number, 
                                                      barcode, 
                                                      print_stream,
                                                      encoded_print_stream)
                                              VALUES (l_sequence_number, 
                                                      l_case_barcode ,
                                                      l_print_stream,
                                                      utl_raw.cast_to_varchar2(l_encode_print_stream)
                                                     );
                
                    END LOOP;                
                END;
          
            END LOOP;                                          
            
            BEGIN
                SELECT MIN(pik_path) 
                  INTO l_min_pik_path   
                  FROM loc WHERE slot_type  IN ('MXF','MXC','MXS');
              
                SELECT SUM(DECODE(SIGN(l_min_pik_path - l.pik_path), 1, DECODE(fd.uom, 1,fd.qty_alloc, fd.qty_alloc/p.spc), 0)) heavy_case_count, 
                       SUM(DECODE(SIGN(l_min_pik_path - L.Pik_Path), -1, DECODE(Fd.Uom, 1,Fd.Qty_Alloc, Fd.Qty_Alloc/P.Spc), 0)) light_case_count
                  INTO l_heavy_case_count,
                       l_light_case_count                 
                  FROM float_detail fd, loc l, pm p
                 WHERE fd.src_loc = l.logi_loc
                   AND fd.prod_id = p.prod_id
                   AND fd.cust_pref_vendor = p.cust_pref_vendor
                   AND fd.float_no IN (SELECT float_no FROM floats WHERE batch_no = i_batch_no)
                   AND l.slot_type Not In ('MXF','MXC') ;
            EXCEPTION
                WHEN OTHERS THEN
                    Pl_Text_Log.ins_msg ('FATAL', l_fname, 'Failed to find heavy and light case count', SQLCODE, SQLERRM);
                    l_heavy_case_count := 0;
                    l_light_case_count := 0;
            END;           
          
            
            l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                              i_interface_ref_doc => 'SYS04',
                                                              i_rec_ind => 'H',
                                                              i_batch_id => i_batch_no,
                                                              i_wave_number => l_rbn,
                                                              i_order_gen_time => TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS'),
                                                              i_priority => rec.priority,
                                                              i_ns_heavy_case_cnt => l_heavy_case_count,
                                                              i_ns_light_case_cnt => l_light_case_count,
                                                              i_rec_count => l_rec_cnt);
            
            IF l_ret_val = 1 THEN
                l_msg_text := 'Prog Code: ' || l_fname
                                || ' Unable to insert header record (SYS04) into matrix_out for batch_no ' || i_batch_no;
                RAISE e_fail;
            END IF;
        END LOOP;

    EXCEPTION
        WHEN e_fail THEN
           Pl_Text_Log.ins_msg ('FATAL', l_fname, l_msg_text, NULL, NULL);
            o_status := C_FAILURE; 
        WHEN OTHERS THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Error in executing create_unassign_matrix_rpl.';
            Pl_Text_Log.ins_msg('FATAL', gl_pkg_name, l_msg_text, SQLCODE, SQLERRM);
            o_status := C_FAILURE;          
    END create_SYS04_addorder;


    ------------------------------------------------------------------------
    -- Procedure:
    --    create_SYS15_wave_status
    --
    -- Description:
    --    This procedure send SYS15 transaction to Symbotic for a batch.
    --    This transaction contain details of order generation of the item  
    --    for which inventory is in Symbotic.
    --
    -- Parameters:
    --    i_batch_no   - Batch no for which messageneed to be send.
    --
    --  Modification Log
    --  Date        Developer       Comments
    -- -----------  ------------    ---------------------------------------------
    -- 01-MAR-2016  SPIN4795        Initial Creation
    ----------------------------------------------------------------------------
   
    PROCEDURE create_SYS15_wave_status (i_batch_no     IN     VARCHAR2,
                                        i_wave_status  IN     VARCHAR2,
                                        io_wave_number IN OUT NUMBER,
                                        o_status       OUT    NUMBER)
    IS        
        l_fname             VARCHAR2 (50)       := 'create_SYS15_addorder';
                       
        e_fail              EXCEPTION;   
        l_sys_msg_id        NUMBER;
        l_ret_val           NUMBER;
        l_rec_cnt           NUMBER := 0;
        l_msg_text          VARCHAR2(512);     
        l_wave_in_progress  NUMBER;

    BEGIN
        o_status := C_SUCCESS;        

        IF i_wave_status = 'STARTED' THEN
            BEGIN
                SELECT DISTINCT NVL(r.mx_wave_number, r.route_batch_no) rbn
                  INTO io_wave_number
                  FROM route r
                 WHERE r.route_no IN (SELECT route_no 
                                        FROM floats 
                                   WHERE batch_no = i_batch_no)
                   AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS THEN
                    Pl_Text_Log.ins_msg ('FATAL', l_fname, 'Failed to find wave number from route for batch_no '||i_batch_no, SQLCODE, SQLERRM);
                    io_wave_number := 0; 
            END;

            SELECT COUNT(*) INTO l_rec_cnt
              FROM v_mx_out_sys15
             WHERE wave_number = io_wave_number
               AND batch_status = 'STARTED'
               AND record_status in ('N','Q');

            IF l_rec_cnt = 0 THEN       
                l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;

                l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                                  i_interface_ref_doc => 'SYS15',
                                                                  i_rec_ind => 'S',
                                                                  i_wave_number => io_wave_number,
                                                                  i_batch_status => 'STARTED'
                                                                 );
            END IF;

        ELSIF i_wave_status = 'COMPLETED' THEN

            SELECT COUNT(*) INTO l_rec_cnt
              FROM v_mx_out_sys15
             WHERE wave_number = io_wave_number
               AND batch_status = 'COMPLETED'
               AND record_status in ('N','Q');

            IF l_rec_cnt = 0 THEN       
                l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;

                l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                                  i_interface_ref_doc => 'SYS15',
                                                                  i_rec_ind => 'S',
                                                                  i_wave_number => io_wave_number,
                                                                  i_batch_status => 'COMPLETED'
                                                                 );
            END IF;
        END IF;

    EXCEPTION
        WHEN e_fail THEN
           Pl_Text_Log.ins_msg ('FATAL', l_fname, l_msg_text, NULL, NULL);
            o_status := C_FAILURE; 
        WHEN OTHERS THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Error creating SYS15 message.';
            Pl_Text_Log.ins_msg('FATAL', gl_pkg_name, l_msg_text, SQLCODE, SQLERRM);
            o_status := C_FAILURE;          
    END create_SYS15_wave_status;

    ----------------------------------------------------------------------------
    --  Procedure:
    --      process_finish_good_shorts
    --
    --  Description:
    --      This procedure will calculate the finish good shorts on a particular
    --      batch.
    --    
    --
    --  Parameters:
    --      i_batch_no   - Batch no to calculate the finish good shorts
    --
    --  Modification Log
    --  Date        Developer  Comments
    --  ----------- ---------  -------------------------------------------------
    --  01-AUG-2018 mpha8134   Initial Creation
    ----------------------------------------------------------------------------
    PROCEDURE process_finish_good_shorts (i_batch_no IN sos_short.batch_no%TYPE)
    IS
        CURSOR c_get_finish_good_shorts IS
            SELECT qty_short, float_no, float_detail_seq_no, 
                orderseq, location, picktype, 
                weight, prod_id, order_id,
                uom
            FROM sos_finish_good_short
            WHERE batch_no = i_batch_no
              AND qty_short > 0;

        CURSOR c_get_ordcw (cp_order_id ordcw.order_id%TYPE, cp_prod_id ordcw.prod_id%TYPE) IS -- need order_id, prod_id, float_no(?) 
            SELECT catch_weight, case_id
            FROM ordcw
            WHERE order_id = cp_order_id
              AND prod_id = cp_prod_id
              AND catch_weight is not NULL
              AND pkg_short_used is NULL
            ORDER BY catch_weight desc;

        l_object_name VARCHAR2(30) := 'process_finish_good_shorts';
        l_message VARCHAR(2000);
        
        l_counter NUMBER;
        l_tmp_qty_short NUMBER;
        l_qty_short NUMBER := 0;  

        l_expected_weight ordcw.catch_weight%TYPE;
        l_expected_lower ordcw.catch_weight%TYPE; -- Lower bound for the expected weight range
                                                  -- 
        l_extra_weight ordcw.catch_weight%TYPE;
        l_split_weight inv.weight%TYPE;
        l_spc pm.spc%TYPE;

    BEGIN
        pl_log.ins_msg ('INFO', l_object_name, utl_lms.format_message('Starting procedure %s batch:%s', l_object_name, i_batch_no), SQLCODE, SQLERRM);

        FOR r_short IN c_get_finish_good_shorts LOOP
            pl_log.ins_msg ('INFO', l_object_name, 'inside c_get_finish_good_shorts loop ', SQLCODE, SQLERRM);
            --l_tmp_qty_short := r_short.qty_short; -- This variable may change as the the procedure progresses.
            l_qty_short := r_short.qty_short;

            BEGIN
                SELECT spc
                INTO l_spc
                FROM pm
                WHERE prod_id = r_short.prod_id;

            EXCEPTION WHEN OTHERS THEN
                pl_log.ins_msg (
                    'FATAL', 
                    l_object_name, 
                    'Unable to get pm information for prod_id <' || r_short.float_no || '>', 
                    SQLCODE, 
                    SQLERRM);

                RAISE_APPLICATION_ERROR (pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
            END;

            l_split_weight := r_short.weight / l_spc;

            FOR r_ordcw IN c_get_ordcw (r_short.order_id, r_short.prod_id) LOOP
                pl_log.ins_msg ('INFO', l_object_name, 'inside c_get_ordcw loop ', SQLCODE, SQLERRM);
                l_counter := 1;
                
                WHILE TRUE LOOP
                    l_message := 'l_tmp_qty_short:' || l_tmp_qty_short || ' l_qty_short:' || l_qty_short || ' l_counter:' || l_counter;
                    pl_log.ins_msg ('INFO', l_object_name, l_message, SQLCODE, SQLERRM);

                    IF r_short.uom = 1 THEN
                        l_extra_weight := l_counter * l_split_weight;
                    ELSE
                        l_extra_weight := l_counter * (l_split_weight * l_spc);
                    END IF;

                    l_expected_weight := r_short.weight + l_extra_weight;

                    l_expected_lower := l_expected_weight - l_split_weight;

                    l_message := 'entered weight:' || r_ordcw.catch_weight || ' l_expected_lower:' || l_expected_lower || ' expected:' || l_expected_weight;
                    pl_log.ins_msg ('INFO', l_object_name, l_message, SQLCODE, SQLERRM);

                    IF r_ordcw.catch_weight < l_expected_lower THEN 
                        -- Scanned weight is less than expected weight, short.
                        EXIT;
                    ELSE
                        -- 1 qty is accounted for in the weight.
                        l_counter := l_counter + 1;
                        l_qty_short := l_qty_short - 1;
                    END IF;

                    IF l_counter >= l_qty_short THEN
                        EXIT;
                    END IF;
                END LOOP;

            END LOOP; --end c_get_ordercw loop

            pl_log.ins_msg ('INFO', l_object_name, 'l_qty_short:' || l_qty_short, SQLCODE, SQLERRM);
            IF l_qty_short > 0 THEN
                l_message := utl_lms.format_message('qtyshort:%s, batch_no:%s, orderseq:%s, location:%s, picktype:%s, float_no:%s, fd_seqno:%s',
                        to_char(l_qty_short), to_char(i_batch_no), to_char(r_short.orderseq), to_char(r_short.location),
                        to_char(r_short.picktype), to_char(r_short.float_no), to_char(r_short.float_detail_seq_no));
                pl_log.ins_msg('INFO', l_object_name, l_message, SQLCODE, SQLERRM);

                create_sos_short (
                    l_qty_short,
                    i_batch_no,
                    r_short.orderseq,
                    r_short.location,
                    r_short.picktype,
                    r_short.float_no,
                    r_short.float_detail_seq_no);
            END IF;

        END LOOP; -- end c_get_finish_good_shorts

    END process_finish_good_shorts;


    ------------------------------------------------------------------------
    --  Procedure:
    --      create_sos_short
    --
    --  Description:
    --      This procedure will create the sos_short, and update all other related tables.
    --    
    --
    --  Parameters:
    --      i_qty_short
    --      i_batch_no
    --      i_orderseq
    --      i_location
    --      i_picktype
    --      i_float_no
    --      i_float_detail_seq_no
    --
    --  Modification Log
    --  Date        Developer  Comments
    --  ----------- ---------  ---------------------------------------------
    --  01-AUG-2018 mpha8134   Initial Creation
    ------------------------------------------------------------------------
    PROCEDURE create_sos_short (
        i_qty_short IN sos_short.qty_short%TYPE,
        i_batch_no IN sos_short.batch_no%TYPE,
        i_orderseq IN sos_short.orderseq%TYPE,
        i_location IN sos_short.location%TYPE,
        i_picktype IN sos_short.picktype%TYPE,
        i_float_no IN sos_short.float_no%TYPE,
        i_float_detail_seq_no IN sos_short.float_detail_seq_no%TYPE )
    IS
        l_message varchar(1000);
        l_object_name VARCHAR(30) := 'create_sos_short';
        l_spc pm.spc%TYPE;
        l_float_seq floats.float_seq%TYPE;
        l_dock_float_loc sos_finish_good_short.dock_float_loc%TYPE;
    BEGIN
        l_message := utl_lms.format_message(
            'i_qty_short[%s] i_batch_no[%s] i_orderseq[%s] i_location[%s] i_picktype[%s]  i_float_no[%s] i_float_detail_seq_no[%s]',
            to_char(i_qty_short),
            to_char(i_batch_no),
            to_char(i_orderseq),
            to_char(i_location),
            to_char(i_picktype),
            to_char(i_float_no),
            to_char(i_float_detail_seq_no));

        pl_log.ins_msg ('INFO', l_object_name, 'Creating SOS short. ' || l_message ,
            SQLCODE, SQLERRM);

        BEGIN
            SELECT NVL(spc, 1)
            INTO l_spc
            FROM pm
            WHERE prod_id = (SELECT distinct prod_id
                                FROM float_detail
                                WHERE order_seq = i_orderseq);

            SELECT f.float_seq
            INTO l_float_seq
            FROM floats f, float_detail fd
            WHERE f.float_no = fd.float_no
            AND fd.order_seq = i_orderseq
            AND fd.seq_no = i_float_detail_seq_no;

            SELECT dock_float_loc
            INTO l_dock_float_loc
            FROM sos_finish_good_short
            WHERE orderseq = i_orderseq
              AND location = i_location
              AND picktype = i_picktype
              AND float_no = i_float_no
              AND float_detail_seq_no = i_float_detail_seq_no
              AND rownum = 1;

        EXCEPTION WHEN OTHERS THEN
            pl_log.ins_msg ('INFO', l_object_name, 'Exception when others', SQLCODE, SQLERRM);
            l_spc := 1;
        END;

        UPDATE sos_finish_good_short
        SET qty_short = i_qty_short,
            pik_status = 'C'
        WHERE orderseq = i_orderseq
          AND location = i_location
          AND picktype = i_picktype
          AND float_no = i_float_no
          AND float_detail_seq_no = i_float_detail_seq_no;
        
        pl_log.ins_msg ('INFO', l_object_name, 'After update sos_finish_good_short', SQLCODE, SQLERRM);

        INSERT INTO sos_short (
            area, orderseq, picktype, batch_no, truck, location,
            dock_float_loc, qty_total, qty_short, sos_status,
            short_time, short_reason, pik_status, float_no, float_detail_seq_no)
            SELECT area, orderseq, picktype, batch_no, truck, location,
                dock_float_loc, qty_total, qty_short, sos_status,
                short_time, short_reason, pik_status, float_no, float_detail_seq_no
            FROM sos_finish_good_short
            WHERE orderseq = i_orderseq
              AND location = i_location
              AND picktype = i_picktype
              AND float_no = i_float_no
              AND float_detail_seq_no = i_float_detail_seq_no
              AND rownum = 1;

        pl_log.ins_msg ('INFO', l_object_name, 'After insert sos_short', SQLCODE, SQLERRM);

        UPDATE float_detail
           SET qty_short = i_qty_short
         WHERE order_seq = i_orderseq
           AND seq_no = i_float_detail_seq_no
           AND float_no in (SELECT float_no 
                              FROM floats 
                             WHERE batch_no = i_batch_no);

        pl_log.ins_msg ('INFO', l_object_name, 'After update float_detail', SQLCODE, SQLERRM);

        UPDATE  float_hist fl
        SET qty_short = NVL(qty_short, 0) +
            i_qty_short * DECODE(fl.uom, 1, 1, l_spc),
	        float_seq = NVL(float_seq, l_dock_float_loc)
        WHERE batch_no = RTRIM (i_batch_no)
            AND src_loc = RTRIM (i_location)           
            AND fh_order_seq = i_orderseq
	        AND float_no = i_float_no
	        /* IS NULL takes care of the selection merge location (**MERG) */
	        AND  (float_seq = l_dock_float_loc OR float_seq IS NULL)
            AND qty_alloc >= NVL(qty_short, 0) + i_qty_short * DECODE(fl.uom, 1, 1, l_spc);

        pl_log.ins_msg ('INFO', l_object_name, 'After update float_hist', SQLCODE, SQLERRM);

        COMMIT;
    END create_sos_short;

END pl_sos;
/

SHOW ERRORS;

SET SCAN ON

