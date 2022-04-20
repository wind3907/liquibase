CREATE OR REPLACE PROCEDURE SWMS.STS_POPULATE_ROUTE(
    curr_route_no  IN ROUTE.route_no%TYPE,
    curr_method_id IN ROUTE.method_id%TYPE)
IS
  /* ------------------------------------------ */
  /* Procedure STS_POPULATE_ROUTE               */
  /*      (route_no IN ROUTE.route_no%TYPE)     */
  /* ------------------------------------------ */
  --------------------------------------------------------------------------------------------
  -- Modification History:
  --    Date     Designer Comments
  --    -------- -------- -----------------------------------------------------
  --    08/21/14 Infosys  R13.0-Charm#6000000054-
  --   Changes done for Cross Dock Orders to include only one item
  --   on the pallet and build it into STS file
  --
  --    08/28/19 bben0556 Brian Bent
  --                      Project: R30.6.8-Jira-OPCOF-2517-CMU-Project_cross_dock_picking
  --
  --                      Multiple records in CROSS_DOCK_TYPE table causes the insert into
  --                      STS_ITEMS table to fail with unique contraint error.
  --                      Changed the insert stmt changing
  --          AND  ( (OM.CROSS_DOCK_TYPE = CDT.CROSS_DOCK_TYPE AND ROWNUM = 1 )
  --                OR (OM.CROSS_DOCK_TYPE IS NULL));
  --                      to
  --          AND CDT.CROSS_DOCK_TYPE (+) = OM.CROSS_DOCK_TYPE
  --          AND ROWNUM <= DECODE(CDT.CROSS_DOCK_TYPE , 'EI', 1, 100000000);
  --
  --                      CMU cross dock pallets needs to be flagged as normal selection
  --                      picks for STS to allow the driver to scan the case labels.
  --                      Changed the SOS_ITEMS insert stmt changing
  --                         F.PALLET_PULL,
  --                      to
  --                         DECODE(cdt.cross_dock_type, 'MU', 'N', f.pallet_pull) PALLET_PULL,
  --
  --                      When the processing ran that creates the records in STS_ROUTE_OUT
  --                      entries for the individual case barcodes were not created.  Found out
  --                      this was because SOS_ITEMS.SOS_STATUS was 'N' for the cross dock
  --                      pallets.  It needs to be 'C'.
  --                      Changed the SOS_ITEMS insert stmt changing
  --                  DECODE(fd2.float_no, NULL, fd.sos_status, fd2.sos_status)    sos_status,
  --                      to
  --                  DECODE(cdt.cross_dock_type, 'MU', 'C',
  --                                              DECODE(fd2.float_no, NULL, fd.sos_status, fd2.sos_status)) sos_status,
  --
  --    10/21/19 bben0556 Brian Bent
  --                      Project: R30.6.9-Jira-OPCOF-2610-CMU-Project_non_cmu_items_on_order_will_not_bulk_pull
  --
  --                      Bug fix.
  --                      The change I made on 08/28/19 was incorrect.  I treated everything on the order
  --                      as a CMU cross dock pallet with the end results every float tied to the order
  --                      was a normal selection pick--even regular bulk pulls  (we did not see this issue
  --                      because we have a bug were we will not bulk pull any item on a order with a
  --                      CMU item which was fixed today).
  --                      We need to look at the items on the float and if there is a CMU item
  --                      then the entire float is a CMU cross dock.
  --
  --                      Note: We probably should have a flag at the float level to flag the
  --                            float as a cross dock pallet.
  --
  --
  --                      ---- 10/22/2019  ATTENTION   We will not make the below change at this time          ----
  --                      ----                         as we may not want to have this option for a CMU pallet ----
  --                      We found out on STS the driver has the option to scan the float label
  --                      for a unitize pallet which "delivers" all the items on the pallet so
  --                      that the driver does not have to scan each case.  OpCo 037 said that
  --                      for a CMU pallet they do not have this option but should since
  --                      essentially a CMU pallet is a unitize pallet.  After reseaching we
  --                      found STS_ITEMS.UNITIZE_IND is set to Y win this program when the
  --                      selection type for the pallet is 'UNI'.  For a CMU pallet the
  --                      selection type is 'PAL'.  So what we will do is in the STS_ITEMS
  --                      insert statement we will set STS_ITEMS>UNITIZE_IND to 'Y' if it is a CMU palllet.
  --
  --   03/24/2020 vkal9662 Changes made to snd_sts_route_details process to use 
  --                       Ship date used by majority of ordm recordsin a route
  --
  --   09/15/2021 vkl9662  LP Changes done for Jira 3600-LP - Change STS to see 
  --                       Xdock Bulk Pulls as case picks @ site 2
  --------------------------------------------------------------------------------------------
  curr_route_date ORDM.ship_date%TYPE;
  manifest_count INTEGER:=0;
  /*CRQ36383 STS Build Route Routine Code*/
  sts_count         INTEGER := 1;
  undef_pickups     INTEGER := 0;
  open_manifests    INTEGER := 0;
  oblg_no_cnt       INTEGER :=0;
  ordr_id_cnt       INTEGER :=0;
  ordrid_oblg_match INTEGER :=0;
  l_shipdt_count    INTEGER :=0;
  manifest_crt_date MANIFESTS.manifest_create_dt%TYPE;
  Turn_Off BOOLEAN := TRUE;
  return_value PLS_INTEGER;
  v_ordd_seq STS_ITEMS.ordd_seq%TYPE;
  v_shrtqty_sort INTEGER;
  v_float_no STS_ITEMS.float_no%TYPE;
  v_float_seq_no STS_ITEMS.float_seq_no%TYPE;
  v_float_zone STS_ITEMS.float_zone%TYPE;
  v_qty_alloc STS_ITEMS.qty_alloc%TYPE;
  v_qty_short STS_ITEMS.qty_short%TYPE;
  v_wh_out_qty STS_ITEMS.wh_out_qty%TYPE;
  v_uom STS_ITEMS.uom%TYPE;
  v_spc PM.spc%TYPE;
  remaining_wh_outs STS_ITEMS.wh_out_qty%TYPE;
  calc_wh_out_qty STS_ITEMS.wh_out_qty%TYPE;
  prev_ordd_seq STS_ITEMS.ordd_seq%TYPE := 0;
  valid_mf_no MANIFESTS.manifest_no%Type;
  /*CRQ36383 STS Build Route Routine Code*/
  CURSOR wh_outs
  IS
    SELECT SI.ORDD_SEQ,
      DECODE(SI.QTY_SHORT, 0,1,0),
      SI.FLOAT_NO,
      SI.FLOAT_SEQ_NO,
      SI.FLOAT_ZONE,
      SI.QTY_ALLOC,
      SI.QTY_SHORT,
      OD.WH_OUT_QTY,
      SI.UOM,
      NVL(PM.SPC, 1)
    FROM STS_ITEMS SI,
      PM,
      ORDD OD
    WHERE SI.ROUTE_NO       = curr_route_no
    AND SI.ROUTE_DATE       = curr_route_date
    AND MANIFEST_NO         = valid_mf_no
    AND SI.PROD_ID          = PM.PROD_ID
    AND SI.CUST_PREF_VENDOR = PM.CUST_PREF_VENDOR
    AND OD.SEQ              = SI.ORDD_SEQ
    AND OD.WH_OUT_QTY       > 0
    ORDER BY 1,
      2,
      3,
      5 DESC;
  -- The below cursor looks at all the shipdates from ordm for a route
  -- and the shipdate used by majority of ordm records will be used
  CURSOR c_ship_date(p_route_no varchar2)
  IS
    SELECT COUNT(ship_date) shipdt_count,  ship_date
    FROM ORDM
    WHERE 1=1
    and route_no = p_route_no
    GROUP BY ship_date,route_no
    ORDER BY  COUNT(ship_date) DESC , ship_date;
BEGIN
  /* retrieve the Route Date from the ORDM Table */
  /*   SELECT MAX(SHIP_DATE)
  INTO curr_route_date
  FROM ORDM
  WHERE ROUTE_NO = curr_route_no;*/
  BEGIN
    curr_route_date := NULL;
    FOR i IN c_ship_date(curr_route_no)
    LOOP
      curr_route_date    := i.ship_date;
    
      IF curr_route_date IS NOT NULL THEN
        EXIT;
      END IF;
    END LOOP;
    /* if unable to obtain a route date */
    IF ( curr_route_date IS NULL ) THEN
      raise_application_error( -20501, 'Route Date is Undefined' || ' for Route ' || curr_route_no );
    END IF;
  END;
  /* debug */
  STS_WRITE_LOG( SYSDATE, 'TOP ', 'Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
  /*
  BEGIN
  manifest_crt_date := NULL;
  SELECT MAX(MANIFEST_CREATE_DT)
  INTO manifest_crt_date
  FROM MANIFESTS
  WHERE ROUTE_NO = curr_route_no
  AND MANIFEST_STATUS = 'OPN';
  /* debug */
  /*  STS_WRITE_LOG( SYSDATE, 'DBUG', 'manifest_crt_date = ' || TO_CHAR( manifest_crt_date ));
  END;
  */
  /* check to see if there are multiple open manifests */
  BEGIN
    SELECT COUNT (*)
    INTO open_manifests
    FROM MANIFESTS
    WHERE ROUTE_NO      = curr_route_no
    AND MANIFEST_STATUS = 'OPN';
    /* debug */
    STS_WRITE_LOG( SYSDATE, 'DBUG', 'open manifests = ' || TO_CHAR( open_manifests ));
  END;
  /* Does a manifest exist */
  IF ( open_manifests = 0 ) THEN
    raise_application_error( -20504, 'No open manifest exits' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
  END IF;
  IF ( open_manifests = 1 ) THEN
    SELECT manifest_no
    INTO valid_mf_no
    FROM MANIFESTS
    WHERE ROUTE_NO      = curr_route_no
    AND MANIFEST_STATUS = 'OPN';
  END IF;
  /*CRQ36383 STS Build Route Routine Code starts */
  IF ( open_manifests > 1 ) THEN
    BEGIN
      /*CRQ49006 Remove order count validation*/
      /*For checking the obligations and orders for  the route and the latest manifest */
      /*************************
      SELECT COUNT(*) INTO ordrid_oblg_match FROM
      (
      (SELECT OBLIGATION_NO
      FROM MANIFEST_DTLS
      WHERE MANIFEST_NO IN
      (SELECT MANIFEST_NO
      FROM MANIFESTS
      WHERE route_no = curr_route_no
      AND MANIFEST_CREATE_DT IN
      (SELECT max(MANIFEST_CREATE_DT)
      FROM MANIFESTS
      WHERE route_no = curr_route_no
      GROUP BY route_no)
      AND OBLIGATION_NO NOT IN
      (SELECT ORDER_ID
      FROM ORDD
      WHERE ROUTE_NO = curr_route_no)))
      UNION
      (SELECT ORDER_ID
      FROM ORDD
      WHERE ROUTE_NO = curr_route_no
      AND ORDER_ID NOT IN
      (SELECT OBLIGATION_NO
      FROM MANIFEST_DTLS
      WHERE MANIFEST_NO IN
      (SELECT MANIFEST_NO
      FROM MANIFESTS
      WHERE route_no = curr_route_no
      AND MANIFEST_CREATE_DT IN
      (SELECT max(MANIFEST_CREATE_DT)
      FROM MANIFESTS
      WHERE route_no=curr_route_no
      GROUP BY route_no))))
      );
      IF (ordrid_oblg_match = 0) THEN
      SELECT MANIFEST_NO INTO valid_mf_no FROM MANIFESTS WHERE route_no = curr_route_no
      AND MANIFEST_CREATE_DT IN (SELECT max(MANIFEST_CREATE_DT) FROM MANIFESTS WHERE route_no=curr_route_no
      GROUP BY route_no);
      ELSE
      STS_WRITE_LOG( SYSDATE, 'DBUG', 'Either OBLIGATION_NO or ORDER_ID were missing for current route no');
      raise_application_error( -20502,'Either OBLIGATION_NO or ORDER_ID were missing'
      || ' for Route ' || curr_route_no
      || ' Route Date   ' || curr_route_date );
      END IF;
      ***********************/
      /* debug */
      /*STS_WRITE_LOG( SYSDATE, 'DBUG', 'Multiple open Manifest');*/
      /*CRQ49006 Remove order count validation*/
      valid_mf_no := NULL;
      SELECT MAX(manifest_no)
      INTO valid_mf_no
      FROM MANIFESTS
      WHERE sysdate - manifest_create_dt <=0.5
      AND ROUTE_NO                        = curr_route_no
      AND MANIFEST_STATUS                 = 'OPN';
      IF ( valid_mf_no                   IS NULL ) THEN
        raise_application_error( -20504, 'Recent Manifest not received' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
      END IF;
    END;
  END IF;
  /*CRQ36383 STS Build Route Routine Code Ends */
  /*CRQ49006 Remove order count validation*/
  /* check to see if there are STS_PICKUPS records with  */
  /* undefined Customer IDs (i.e. CUST_ID field is NULL) */
  BEGIN
    SELECT COUNT (*)
    INTO undef_pickups
    FROM STS_PICKUPS
    WHERE ROUTE_NO  = curr_route_no
    AND ROUTE_DATE  = curr_route_date
    AND MANIFEST_NO = valid_mf_no --/*CRQ36383 STS Build Route Routine Code  */
    AND CUST_ID    IS NULL;
    /* debug */
    STS_WRITE_LOG( SYSDATE, 'DBUG', 'undef_pickups = ' || TO_CHAR( undef_pickups ));
  END;
  /* if there are any undefined STS_PICKUPS records, cease processing */
  IF ( undef_pickups > 0 ) THEN
    raise_application_error( -20502, 'Undefined Pickup Records Exist' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
  END IF;
  /* check to see if this route has already been populated in STS_ITEMS    */
  BEGIN
    SELECT COUNT (*)
    INTO sts_count
    FROM STS_ITEMS
    WHERE ROUTE_NO  = curr_route_no
    AND ROUTE_DATE  = curr_route_date
    AND MANIFEST_NO = valid_mf_no;
    /*CRQ36383 STS Build Route Routine Code  */
    /* debug */
    STS_WRITE_LOG( SYSDATE, 'DBUG', 'sts_count = ' || TO_CHAR( sts_count ));
  END;
  /* if this route has not yet been populated within */
  /* the STS Historical Tables, populate it now...   */
  /* otherwise, skip over the population.            */
  IF ( sts_count <= 0 ) THEN
    /* query the items on the Route and insert them into the STS_ITEMS Table */
    BEGIN
      INSERT
      INTO STS_ITEMS
        (
          ROUTE_NO,
          ROUTE_DATE,
          STOP_NO,
          TRUCK_NO,
          MANIFEST_NO,
          CUST_ID,
          OBLIGATION_NO,
          FLOAT_SEQ,
          FLOAT_NO,
          FLOAT_SEQ_NO,
          FLOAT_ZONE,
          BC_ST_PIECE_SEQ,
          PALLET_PULL,
          ORDD_SEQ,
          UOM,
          CUST_PO,
          UNITIZE_IND,
          AREA,
          QTY_ORDERED,
          QTY_ALLOC,
          QTY_SHORT,
          TOTAL_QTY,
          WH_OUT_QTY,
          PROD_ID,
          CUST_PREF_VENDOR,
          PICKTIME,
          OTHER_ZONE_FLOAT,
          ORDER_LINE_STATE,
          MULTI_NO,
          SOS_STATUS,
          SELECTOR_ID
        )
      SELECT
        /*+ ORDERED */
        SUBSTR( OM.ROUTE_NO, 1, 4 ),
        curr_route_date,
        OM.STOP_NO,
        OM.TRUCK_NO,
        M.MANIFEST_NO,
        OM.CUST_ID,
        OM.ORDER_ID,
        F.FLOAT_SEQ,
        NVL(FD2.FLOAT_NO, FD.FLOAT_NO),
        NVL(FD2.SEQ_NO, FD.SEQ_NO),
        FD.ZONE,
        NVL(FD2.BC_ST_PIECE_SEQ, NVL(FD.BC_ST_PIECE_SEQ, 1)),
        (
        CASE -- Jira 3600
          WHEN f.cross_dock_type ='X'
          THEN f.site_from_pallet_pull 
          ELSE f.pallet_pull
        END) pallet_pull,
        --
        OD.SEQ,
        NVL(FD2.UOM, NVL(FD.UOM, -1)),
        OM.CUST_PO,
        --
        DECODE( SM.SEL_TYPE, 'UNI', 'Y', 'N' ),
        --
        OD.AREA,
        NVL(FD2.QTY_ORDER, FD.QTY_ORDER),
        NVL( FD2.QTY_ALLOC, FD.QTY_ALLOC),
        NVL( FD2.QTY_SHORT, FD.QTY_SHORT ),
        0,
        0,
        OD.PROD_ID,
        OD.CUST_PREF_VENDOR,
        NULL picktime,
        'N' other_zone_float,
        'N' order_line_state,
        NVL(SE.MULTI_NO, 999) multi_no,
        --
        (
        CASE   --- Jira 3600 
          WHEN f.cross_dock_type ='X'
          THEN 'C'
          ELSE (
            CASE
              WHEN fd2.float_no IS NULL
              THEN fd.sos_status
              ELSE fd2.sos_status
            END)
        END) sos_status,
        --
        DECODE(fd2.float_no, NULL, fd.selector_id, fd2.selector_id) selector_id
      FROM ORDM OM,
        ORDD OD,
        FLOATS F,
        FLOAT_DETAIL FD,
        FLOAT_DETAIL FD2,
        MANIFESTS M,
        SEL_METHOD SM,
        SEL_EQUIP SE,
        CROSS_DOCK_TYPE CDT
      WHERE SUBSTR( F.ROUTE_NO, 1, 4 ) = curr_route_no
      AND F.FLOAT_NO                   = FD.FLOAT_NO
      AND SUBSTR(OM.ROUTE_NO, 1, 4 )   = curr_route_no
      AND M.ROUTE_NO                   = curr_route_no
      AND M.MANIFEST_STATUS            = 'OPN'
        --AND M.MANIFEST_CREATE_DT = manifest_crt_date           -- CRQ36383 STS Build Route Routine Code
      AND M.MANIFEST_NO           = valid_mf_no -- CRQ36383 STS Build Route Routine Code*/
      AND OM.ROUTE_NO             = OD.ROUTE_NO
      AND OM.ORDER_ID             = OD.ORDER_ID
      AND OD.ORDER_ID             = FD.ORDER_ID
      AND OD.ORDER_LINE_ID        = FD.ORDER_LINE_ID
      AND F.PALLET_PULL          <> 'R'
      AND F.MERGE_LOC             = '???'
      AND SM.METHOD_ID            = curr_method_id
      AND SM.GROUP_NO             = F.GROUP_NO
      AND FD.FLOAT_NO             = FD2.MERGE_FLOAT_NO (+)
      AND FD.SEQ_NO               = FD2.MERGE_SEQ_NO (+) -- CRQ32853 Merge Float
      AND FD.ORDER_ID             = FD2.ORDER_ID (+)
      AND FD.ORDER_LINE_ID        = FD2.ORDER_LINE_ID (+)
      AND F.EQUIP_ID              = SE.EQUIP_ID (+)
      AND OD.DELETED             IS NULL
      AND CDT.CROSS_DOCK_TYPE (+) = OM.CROSS_DOCK_TYPE                                -- 08/28/19 Brian Bent Added
      AND ROWNUM                 <= DECODE(CDT.CROSS_DOCK_TYPE , 'EI', 1, 100000000); -- 08/28/19 Brian Bent Added If EI cross dock then we
      -- want only one item.  Does not matter what item.
      --        AND  ( (OM.CROSS_DOCK_TYPE = CDT.CROSS_DOCK_TYPE AND ROWNUM = 1 )   -- 08/28/19 Brian Bent Was this
      --              OR (OM.CROSS_DOCK_TYPE IS NULL));                             -- 08/28/19 Brian Bent Was this
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' inserting into STS_ITEMS' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
    END;
    /* FOR EI cross dock orders, 1 item per float should get inserted into sts_items and
    hence removing additional items per float record */
    BEGIN
      /* Formatted on 12/26/2014 8:55:50 PM (QP5 v5.163.1008.3004) */
      DELETE
      FROM sts_items
      WHERE (ordd_seq, float_no, obligation_no, route_no, manifest_no) IN
        (SELECT t1.ordd_seq,
          t1.float_no,
          t1.obligation_no,
          t1.route_no,
          t1.manifest_no
        FROM sts_items t1,
          ordd t2
        WHERE t1.obligation_no = T2.ORDER_ID
        AND t1.prod_id         = t2.prod_id
        AND t1.ordd_seq        = t2.seq
        AND t1.ordd_seq        >
          (SELECT MIN (od.seq)
          FROM ordd od,
            ordm om
          WHERE od.order_id      = t1.obligation_no
          AND om.order_id        = od.order_id
          AND om.cross_dock_type = 'EI'
          AND om.route_no        = curr_route_no
          )
        );
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' Delete from STS_ITEMS failed for EI order' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
    END;
    BEGIN
      /* Allocate Warehouse outs to STS_ITEM records.  Allocate to records with qty_short first, must be allocated in reverse pallet zone order */
      OPEN wh_outs;
      FETCH wh_outs
      INTO v_ordd_seq,
        v_shrtqty_sort,
        v_float_no,
        v_float_seq_no,
        v_float_zone,
        v_qty_alloc,
        v_qty_short,
        v_wh_out_qty,
        v_uom,
        v_spc;
      WHILE wh_outs%FOUND
      LOOP
        IF prev_ordd_seq    <> v_ordd_seq THEN
          prev_ordd_seq     := v_ordd_seq;
          remaining_wh_outs := v_wh_out_qty;
        END IF;
        IF remaining_wh_outs > 0 THEN
          /* If quantity short is zero then set to full QTY_ALLOC amount, adjust for UOM */
          IF v_qty_short = 0 THEN
            IF v_uom     = 2 THEN
              /* Case */
              v_qty_short := v_qty_alloc / v_spc;
            ELSE
              /* Split */
              v_qty_short := v_qty_alloc;
            END IF;
          END IF;
          /* Allocate by quantity short */
          IF remaining_wh_outs > v_qty_short THEN
            calc_wh_out_qty   := v_qty_short;
            remaining_wh_outs := remaining_wh_outs - v_qty_short;
          ELSE
            calc_wh_out_qty   := remaining_wh_outs;
            remaining_wh_outs := 0;
          END IF;
          UPDATE STS_ITEMS
          SET WH_OUT_QTY   = calc_wh_out_qty
          WHERE ROUTE_NO   = curr_route_no
          AND MANIFEST_NO  = valid_mf_no
          AND ROUTE_DATE   = curr_route_date
          AND FLOAT_NO     = v_float_no
          AND FLOAT_SEQ_NO = v_float_seq_no;
          /* Adjust allocated quantity for splits per case */
          IF v_uom       = 2 THEN
            v_qty_alloc := v_qty_alloc / v_spc;
          END IF;
          /* If completely out, then set the order line state to 'O' so that the hand held will ignore it when scanning  */
          IF calc_wh_out_qty >= v_qty_alloc THEN
            /* The whole record is out */
            UPDATE STS_ITEMS
            SET ORDER_LINE_STATE = 'O'
            WHERE ROUTE_NO       = curr_route_no
            AND MANIFEST_NO      = valid_mf_no
            AND ROUTE_DATE       = curr_route_date
            AND FLOAT_NO         = v_float_no
            AND FLOAT_SEQ_NO     = v_float_seq_no;
          END IF;
        END IF;
        FETCH wh_outs
        INTO v_ordd_seq,
          v_shrtqty_sort,
          v_float_no,
          v_float_seq_no,
          v_float_zone,
          v_qty_alloc,
          v_qty_short,
          v_wh_out_qty,
          v_uom,
          v_spc;
      END LOOP;
    END;
    /* Query any warehouse shorts where the item is completely short and
    do not have float detail records */
    BEGIN
      INSERT
      INTO STS_ITEMS
        (
          ROUTE_NO,
          ROUTE_DATE,
          STOP_NO,
          TRUCK_NO,
          MANIFEST_NO,
          CUST_ID,
          OBLIGATION_NO,
          FLOAT_SEQ,
          FLOAT_NO,
          FLOAT_SEQ_NO,
          FLOAT_ZONE,
          BC_ST_PIECE_SEQ,
          PALLET_PULL,
          ORDD_SEQ,
          UOM,
          CUST_PO,
          UNITIZE_IND,
          AREA,
          QTY_ORDERED,
          QTY_ALLOC,
          QTY_SHORT,
          TOTAL_QTY,
          WH_OUT_QTY,
          PROD_ID,
          CUST_PREF_VENDOR,
          PICKTIME,
          OTHER_ZONE_FLOAT,
          ORDER_LINE_STATE,
          MULTI_NO,
          SOS_STATUS,
          SELECTOR_ID
        )
      SELECT
        /*+ ORDERED */
        DISTINCT SUBSTR( OM.ROUTE_NO, 1, 4 ),
        curr_route_date,
        OM.STOP_NO,
        OM.TRUCK_NO,
        M.MANIFEST_NO,
        OM.CUST_ID,
        OM.ORDER_ID,
        '    ',
        0,
        OD.SEQ,
        0,1,
        NULL,
        OD.SEQ,
        DECODE(OD.UOM, 1, 1, 2 ),
        OM.CUST_PO,
        'N',
        OD.AREA,
        OD.QTY_ORDERED,
        OD.QTY_ALLOC,
        0,
        0,
        OD.WH_OUT_QTY,
        OD.PROD_ID,
        OD.CUST_PREF_VENDOR,
        NULL,
        'N',
        'N',
        999,
        'N',
        '          '
      FROM ORDM OM,
        ORDD OD,
        FLOAT_DETAIL FD,
        MANIFESTS M
      WHERE SUBSTR(OM.ROUTE_NO, 1, 4 ) = curr_route_no
      AND M.ROUTE_NO                   = curr_route_no
      AND M.MANIFEST_STATUS            = 'OPN'
        --AND M.MANIFEST_CREATE_DT = manifest_crt_date  /*CRQ36383 STS Build Route Routine Code*/
      AND M.MANIFEST_NO= valid_mf_no
        /*CRQ36383 STS Build Route Routine Code*/
      AND OM.ROUTE_NO       = OD.ROUTE_NO
      AND OM.ORDER_ID       = OD.ORDER_ID
      AND OD.QTY_ALLOC      = 0
      AND OD.ORDER_ID       = FD.ORDER_ID (+)
      AND OD.ORDER_LINE_ID  = FD.ORDER_LINE_ID (+)
      AND FD.ORDER_LINE_ID IS NULL
      AND OD.DELETED       IS NULL ;
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' inserting complete inventory shorts into STS_ITEMS' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
    END;
    /* Update the Total Qty for the item records.*/
    BEGIN
      UPDATE STS_ITEMS SI
      SET TOTAL_QTY =
        (SELECT
          /*+ ORDERED */
          SUM(QTY_ALLOC)
        FROM STS_ITEMS SI2
        WHERE SI2.ROUTE_NO   = SI.ROUTE_NO
        AND SI2.ROUTE_DATE   = SI.ROUTE_DATE
        AND SI2.ORDD_SEQ     = SI.ORDD_SEQ
        AND SI2.PALLET_PULL <> 'B'
        )
      WHERE SI.ROUTE_NO = curr_route_no
      AND SI.ROUTE_DATE = curr_route_date
      AND SI.MANIFEST_NO= valid_mf_no
        /*CRQ36383 STS Build Route Routine Code*/
      AND SI.PALLET_PULL <> 'B';
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || 'updating TOTAL_QTY' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
    END;
    /* populate the STS_ORDER_HIST Table */
    BEGIN
      INSERT INTO STS_ORDER_HIST
        ( OBLIGATION_NO, INVOICE_DATE, CUST_ID
        )
      SELECT
        /* + ORDERED */
        DISTINCT OBLIGATION_NO,
        ROUTE_DATE,
        CUST_ID
      FROM STS_ITEMS SI
      WHERE SI.ROUTE_NO  = curr_route_no
      AND SI.ROUTE_DATE  = curr_route_date
      AND SI.MANIFEST_NO = valid_mf_no
        /*CRQ36383 STS Build Route Routine Code*/
      AND SI.OBLIGATION_NO NOT IN
        (SELECT OBLIGATION_NO
        FROM STS_ORDER_HIST
        WHERE OBLIGATION_NO = SI.OBLIGATION_NO
        );
    EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      --Duplicate is OK here, this is just a historical table
      NULL;
    WHEN OTHERS THEN
      raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' inserting into STS_ORDER_HIST' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
    END;
    /* update the STS ITEMS Table with the Loading Zone for each Float */
    BEGIN
      UPDATE STS_ITEMS SI
      SET TRUCK_ZONE =
        (SELECT TRUCK_ZONE
        FROM LAS_PALLET LP
        WHERE SI.TRUCK_NO  = LP.TRUCK
        AND SI.ROUTE_NO    = curr_route_no
        AND SI.ROUTE_DATE  = curr_route_date
        AND SI.MANIFEST_NO = valid_mf_no
          /*CRQ36383 STS Build Route Routine Code*/
        AND SI.FLOAT_SEQ = LP.PALLETNO
        )
      WHERE SI.ROUTE_NO  = curr_route_no
      AND SI.ROUTE_DATE  = curr_route_date
      AND SI.MANIFEST_NO = valid_mf_no ;
      /*CRQ36383 STS Build Route Routine Code*/
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || 'updating TRUCK_ZONE' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
    END;
    /* query the case exceptions from the LAS_CASE Table     */
    /* and update the OTHER_FLOAT_ZONE flag within STS ITEMS */
    BEGIN
      UPDATE STS_ITEMS SI
      SET OTHER_ZONE_FLOAT =
        (SELECT 'Y'
        FROM LAS_CASE LC
        WHERE SI.ROUTE_NO  = curr_route_no
        AND SI.ROUTE_DATE  = curr_route_date
        AND SI.MANIFEST_NO = valid_mf_no
          /*CRQ36383 STS Build Route Routine Code*/
        AND SI.ORDD_SEQ = LC.ORDER_SEQ
        AND ROWNUM      = 1
        )
      WHERE SI.ROUTE_NO = curr_route_no
      AND SI.ROUTE_DATE = curr_route_date;
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' updating OTHER_ZONE_FLOAT' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
    END;
    /* query the case exceptions from the LAS_CASE Table     */
    /* and insert records into the STS_CASES table:          */
    BEGIN
      INSERT
      INTO STS_CASES
        (
          ROUTE_NO,
          ROUTE_DATE,
          STOP_NO,
          ORDD_SEQ,
          CASE_SEQ,
          TRUCK_ZONE,
          FLOAT_SEQ
        )
      SELECT SUBSTR( OM.ROUTE_NO, 1, 4 ),
        OM.SHIP_DATE,
        OM.STOP_NO,
        LC.ORDER_SEQ,
        LC.LABEL_SEQ,
        LC.LOCATION,
        LC.FLOAT_SEQ
      FROM ORDM OM,
        LAS_CASE LC,
        ORDD OD
      WHERE SUBSTR( OM.ROUTE_NO, 1, 4 ) = curr_route_no
      AND OM.SHIP_DATE                  = curr_route_date
      AND OM.TRUCK_NO                   = LC.TRUCK
      AND OM.ORDER_ID                   = OD.ORDER_ID
      AND LC.ORDER_SEQ                  = OD.SEQ;
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' inserting STS_CASES' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
    END;
    /* query MANIFEST, MANIFEST_DTLS, RETURNS, tables */
    /* to populate the STS_PICKUPS records for the current route.        */
    BEGIN
      INSERT
      INTO STS_PICKUPS
        (
          ROUTE_NO,
          ROUTE_DATE,
          STOP_NO,
          TRUCK_NO,
          MANIFEST_NO,
          OBLIGATION_NO,
          ORIG_INVOICE,
          PROD_ID,
          CUST_PREF_VENDOR,
          UOM,
          SHIPPED_QTY,
          DISPOSITION,
          RETURN_REASON_CD,
          RETURN_PROD_ID,
          CUST_ID
        )
      SELECT
        /* +ORDERED */
        DISTINCT M.ROUTE_NO,
        curr_route_date,
        MD.STOP_NO,
        M.TRUCK_NO,
        M.MANIFEST_NO,
        MD.OBLIGATION_NO,
        MD.ORIG_INVOICE,
        MD.PROD_ID,
        MD.CUST_PREF_VENDOR,
        MD.SHIPPED_SPLIT_CD,
        MD.SHIPPED_QTY,
        RE.DISPOSITION,
        RE.RETURN_REASON_CD,
        RE.RETURNED_PROD_ID,
        NVL(MS.CUSTOMER_ID, OH.CUST_ID)
      FROM MANIFESTS M,
        MANIFEST_DTLS MD,
        MANIFEST_STOPS MS,
        RETURNS RE,
        STS_ORDER_HIST OH
      WHERE M.ROUTE_NO      = curr_route_no
      AND M.MANIFEST_STATUS = 'OPN'
      AND M.MANIFEST_NO     = MD.MANIFEST_NO
      AND M.MANIFEST_NO     = valid_mf_no
        /*CRQ36383 STS Build Route Routine Code*/
      AND MD.REC_TYPE         = 'P'
      AND MD.OBLIGATION_NO    = RE.OBLIGATION_NO
      AND MD.PROD_ID          = RE.PROD_ID
      AND MD.CUST_PREF_VENDOR = RE.CUST_PREF_VENDOR
      AND MD.SHIPPED_SPLIT_CD = RE.SHIPPED_SPLIT_CD
      AND MD.MANIFEST_NO      = MS.MANIFEST_NO (+)
      AND MD.OBLIGATION_NO    = MS.OBLIGATION_NO (+)
      AND MD.ORIG_INVOICE     = OH.OBLIGATION_NO (+);
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' inserting STS_PICKUPS' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
    END;
    /* query for the Pickup Item barcodes:     */
    /* First Query the ORDD_FOR_RTN table.     */
    BEGIN
      UPDATE STS_PICKUPS SP
      SET ORDD_SEQ =
        (SELECT
          /* +ORDERED */
          OFR.ORDD_SEQ
        FROM ORDD_FOR_RTN OFR
        WHERE SP.ROUTE_NO  = curr_route_no
        AND SP.ROUTE_DATE  = curr_route_date
        AND SP.MANIFEST_NO = valid_mf_no
          /*CRQ36383 STS Build Route Routine Code*/
        AND SP.ORIG_INVOICE     = OFR.ORDER_ID
        AND SP.PROD_ID          = OFR.PROD_ID
        AND SP.CUST_PREF_VENDOR = OFR.CUST_PREF_VENDOR
        AND SP.UOM              = OFR.UOM
        AND ROWNUM              = 1
        )
      WHERE SP.ROUTE_NO  = curr_route_no
      AND SP.ROUTE_DATE  = curr_route_date
      AND SP.MANIFEST_NO = valid_mf_no
        /*CRQ36383 STS Build Route Routine Code*/
        ;
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' updating STS_PICKUPS.ORDD_SEQ from ordd_for_rtn' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
    END;
    /* query for the Pickup Item barcodes:     */
    /* Then try the ORDD for same day pickups. */
    BEGIN
      UPDATE STS_PICKUPS SP
      SET ORDD_SEQ =
        (SELECT
          /* +ORDERED */
          OD.SEQ
        FROM ORDD OD
        WHERE SP.ROUTE_NO  = curr_route_no
        AND SP.ROUTE_DATE  = curr_route_date
        AND SP.MANIFEST_NO = valid_mf_no
          /*CRQ36383 STS Build Route Routine Code*/
        AND SP.ORDD_SEQ        IS NULL
        AND SP.ORIG_INVOICE     = OD.ORDER_ID
        AND SP.PROD_ID          = OD.PROD_ID
        AND SP.CUST_PREF_VENDOR = OD.CUST_PREF_VENDOR
        AND SP.UOM              = OD.UOM
        AND ROWNUM              = 1
        )
      WHERE SP.ROUTE_NO  = curr_route_no
      AND SP.ROUTE_DATE  = curr_route_date
      AND SP.MANIFEST_NO = valid_mf_no
        /*CRQ36383 STS Build Route Routine Code*/
      AND SP.ORDD_SEQ IS NULL ;
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' updating STS_PICKUPS.ORDD_SEQ from ordd' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
    END;
    /* Assigns customer IDs to pickups that are unassigned and are associated
    with a delivery that is not a mall stop */
    BEGIN
      UPDATE STS_PICKUPS PU
      SET CUST_ID =
        (SELECT CUST_ID
        FROM STS_ITEMS SI1
        WHERE PU.ROUTE_NO  = curr_route_no
        AND PU.ROUTE_DATE  = curr_route_date
        AND PU.MANIFEST_NO = valid_mf_no
        AND
          /*CRQ36383 STS Build Route Routine Code*/
          SI1.ROUTE_NO     = PU.ROUTE_NO
        AND SI1.ROUTE_DATE = PU.ROUTE_DATE
        AND SI1.STOP_NO    = PU.STOP_NO
        AND ROWNUM         = 1
        )
      WHERE PU.ROUTE_NO  = curr_route_no
      AND PU.ROUTE_DATE  = curr_route_date
      AND PU.MANIFEST_NO = valid_mf_no
      AND
        /*CRQ36383 STS Build Route Routine Code*/
        PU.CUST_ID IS NULL
      AND 1         =
        (SELECT COUNT(DISTINCT SI2.STOP_NO)
        FROM STS_ITEMS SI2
        WHERE PU.ROUTE_NO  = curr_route_no
        AND PU.ROUTE_DATE  = curr_route_date
        AND PU.MANIFEST_NO = valid_mf_no
        AND
          /*CRQ36383 STS Build Route Routine Code*/
          SI2.ROUTE_NO         = PU.ROUTE_NO
        AND SI2.ROUTE_DATE     = PU.ROUTE_DATE
        AND TRUNC(SI2.STOP_NO) = PU.STOP_NO
        ) ;
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' updating STS_PICKUPS.CUST_ID for non-multiple cust stops' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
    END;
  END IF;
  /* if this route has already been populated */
  /* For pickups at mall stops, change the stop number to match that of SWMS
  example: 1.01, always do this even if the other queries have already been
  run */
  BEGIN
    UPDATE STS_PICKUPS PU
    SET STOP_NO =
      (SELECT STOP_NO
      FROM STS_ITEMS SI1
      WHERE PU.ROUTE_NO  = curr_route_no
      AND PU.ROUTE_DATE  = curr_route_date
      AND PU.MANIFEST_NO = valid_mf_no
      AND
        /*CRQ36383 STS Build Route Routine Code*/
        SI1.ROUTE_NO     = PU.ROUTE_NO
      AND SI1.ROUTE_DATE = PU.ROUTE_DATE
      AND SI1.CUST_ID    = PU.CUST_ID
      AND SI1.STOP_NO   <> PU.STOP_NO
      AND ROWNUM         = 1
      )
    WHERE PU.ROUTE_NO  = curr_route_no
    AND PU.ROUTE_DATE  = curr_route_date
    AND PU.MANIFEST_NO = valid_mf_no
    AND
      /*CRQ36383 STS Build Route Routine Code*/
      NOT (PU.CUST_ID IS NULL )
    AND 0              <
      (SELECT COUNT(STOP_NO)
      FROM STS_ITEMS SI2
      WHERE PU.ROUTE_NO  = curr_route_no
      AND PU.ROUTE_DATE  = curr_route_date
      AND PU.MANIFEST_NO = valid_mf_no
      AND
        /*CRQ36383 STS Build Route Routine Code*/
        SI2.ROUTE_NO     = PU.ROUTE_NO
      AND SI2.ROUTE_DATE = PU.ROUTE_DATE
      AND SI2.CUST_ID    = PU.CUST_ID
      AND SI2.STOP_NO   <> PU.STOP_NO
      ) ;
  EXCEPTION
  WHEN OTHERS THEN
    raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' updating STS_PICKUPS.STOP_NO for multiple cust stops' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
  END;
  /* Create STS_STOP_EQUIPMENT for this route */
  BEGIN
    INSERT
    INTO STS_STOP_EQUIPMENT
      (
        ROUTE_NO,
        ROUTE_DATE,
        STOP_NO,
        CUST_ID,
        BARCODE,
        QTY
      )
    SELECT curr_route_no,
      curr_route_date,
      0,
      EQ.CUST_ID,
      EQ.BARCODE,
      SUM( EQ.QTY - NVL(EQ.QTY_RETURNED, 0 ) )
    FROM STS_EQUIPMENT EQ
    WHERE EQ.CUST_ID IN
      (SELECT DISTINCT CUST_ID
      FROM STS_ITEMS
      WHERE ROUTE_NO  = curr_route_no
      AND ROUTE_DATE  = curr_route_date
      AND MANIFEST_NO = valid_mf_no
      )
    AND
      /*CRQ36383 STS Build Route Routine Code*/
      EQ.STATUS                          = 'D'
    AND EQ.QTY - NVL(EQ.QTY_RETURNED,0) != 0
    GROUP BY curr_route_no,
      curr_route_date,
      EQ.CUST_ID,
      EQ.BARCODE;
  EXCEPTION
  WHEN OTHERS THEN
    raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' inserting into sts_stop_equipment' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
  END;
  /* Update STS_STOP_EQUIPMENT with stop_no given cust_ID*/
  BEGIN
    UPDATE STS_STOP_EQUIPMENT SQ
    SET STOP_NO =
      (SELECT STOP_NO
      FROM STS_ITEMS SI1
      WHERE SQ.ROUTE_NO   = curr_route_no
      AND SQ.ROUTE_DATE   = curr_route_date
      AND SI1.MANIFEST_NO = valid_mf_no
      AND
        /*CRQ36383 STS Build Route Routine Code*/
        SI1.ROUTE_NO     = SQ.ROUTE_NO
      AND SI1.ROUTE_DATE = SQ.ROUTE_DATE
      AND SI1.CUST_ID    = SQ.CUST_ID
      AND ROWNUM         = 1
      )
    WHERE SQ.ROUTE_NO = curr_route_no
    AND SQ.ROUTE_DATE = curr_route_date;
  EXCEPTION
  WHEN OTHERS THEN
    raise_application_error( -20503, 'Error ' || SQLERRM( SQLCODE ) || ' inserting into sts_stop_equipment' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
  END;
  /* pass curr_route_no and curr_route_date parameters to the build_stsroute */
  /* routine.  execute this external C routine to build the sts route files  */
  /* FINAL MESSAGE */
  STS_WRITE_LOG( SYSDATE, 'HAPY', 'Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
  /* Call the External C routine to build the route files */
  $if swms.platform.SWMS_PLATFORM_LINUX $then return_value := 0;
  $else return_value                                       := STS_BUILD_ROUTE_FILES(curr_route_no, TO_CHAR(curr_route_date, 'YYYYMMDD'));
  $end
  IF return_value <> 0 THEN
    raise_application_error( -20504, 'ReturnVal (' || return_value || ') ' || ' Error Building Route Files' || ' for Route ' || curr_route_no || ' Route Date   ' || curr_route_date );
  END IF;
END;
/
---create or replace public synonym STS_POPULATE_ROUTE for swms.STS_POPULATE_ROUTE;
