/*******************************************************************************

  Package:
      pl_xdock_receiving.sql

  Description:
      This package contains the functionality for Xdock receiving at site 2(Last Mile Site)

  Create XSN(s):
    - p_create_xsn Procedure is called by a script xdock_receiving_create_xsn.sh
      which is executed by a cron job
    -	This p_create_xsn is used to check the xdock_order_xref table for new records
      and create XSN(s) at site 2 by populating ERM, ERD, ERD_LPN, RDC_PO Tables.


  Modification History:

  Date        Designer  Comments
  ----------- --------- ------------------------------------------------------
  16-AUG-2021 jkar6681  Initial version

*******************************************************************************/
CREATE OR REPLACE PACKAGE pl_xdock_receiving IS
  PACKAGE_NAME         CONSTANT swms_log.program_name%TYPE := 'PL_XDOCK_RECEIVING';
  APPLICATION_FUNC     CONSTANT swms_log.application_func%TYPE := 'XDOCK';

  PROCEDURE p_create_xsn;

  PROCEDURE p_populate_xsn_data (
    i_manifest_no_from   IN  xdock_order_xref.manifest_no_from%TYPE,
    i_site_from          IN  xdock_order_xref.site_from%TYPE,
    i_route_no_from      IN  xdock_order_xref.route_no_from%TYPE
  );

  FUNCTION validate_xsn_route_info (
    i_route_no           IN  xdock_order_xref.route_no_from%TYPE
  ) RETURN BOOLEAN;

  PROCEDURE p_close_xsn (
    i_erm_id             IN  erm.erm_id%TYPE,
    out_status           OUT VARCHAR2,
    out_code             OUT NUMBER
  );

  PROCEDURE p_close_xsn_rf (
    i_erm_id               IN  erm.erm_id%TYPE,
    i_client_flag          IN  CHAR,
    i_client_sp_flag       IN  CHAR,
    out_status             OUT VARCHAR2,
    out_code               OUT NUMBER,
    o_sp_current_total     OUT NUMBER,
    o_sp_supplier_count    OUT NUMBER,
    o_erm_id               OUT erm.erm_id%TYPE,
    o_prod_id              OUT pm.prod_id%TYPE,
    o_cust_pref_vendor     OUT pm.cust_pref_vendor%TYPE,
    o_exp_splits           OUT NUMBER,
    o_exp_qty              OUT NUMBER,
    o_rec_splits           OUT NUMBER,
    o_rec_qty              OUT NUMBER,
    o_hld_cases            OUT NUMBER,
    o_hld_splits           OUT NUMBER,
    o_hld_pallet           OUT NUMBER,
    o_total_pallet         OUT NUMBER,
    o_num_pallet           OUT NUMBER,
    o_status               OUT NUMBER,
    ot_sp_suppliers        OUT VARCHAR2
  );

  PROCEDURE p_purge_xsn;

  PROCEDURE p_open_xsn (
        xn_po        IN          erm.erm_id%TYPE,
        out_status    OUT         VARCHAR2
    );

    FUNCTION get_xdock_route_no (
        xn_po           IN          VARCHAR2,
        out_status      OUT         VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION get_xdock_route_status (
        xn_po           IN          VARCHAR2,
        out_status      OUT         VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION check_if_A_or_C_btchs_exists (
        xn_po           IN          VARCHAR2,
        out_status      OUT         VARCHAR2
    ) RETURN BOOLEAN;

    FUNCTION find_xn_pallet_staging_loc (
        xn_area         IN          VARCHAR2,
        xn_po           IN          VARCHAR2,
        parent_pallet   IN          VARCHAR2,
        out_status      OUT         VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION calc_tot_split_count (
        parent_pallet   IN    VARCHAR2,
        out_status      OUT   VARCHAR2
    ) RETURN NUMBER;

    FUNCTION xdock_route_given_prnt_plt (
      parent_pallet   IN    VARCHAR2,
      out_status      OUT   VARCHAR2
    ) RETURN VARCHAR2;

    procedure p_create_blkpulls_nd_putaways (
      xn_po       IN        erm.erm_id%TYPE,
      out_status  OUT       VARCHAR2
    );

    FUNCTION get_shipping_door (
      parent_pallet_id     IN   VARCHAR2, 
      xn_area              IN   VARCHAR2,
      out_status           OUT  VARCHAR2
    ) RETURN VARCHAR2;

    procedure p_create_putaway_task_for_plt (
      i_parent_pallet_id   IN   VARCHAR2, 
      receiving_door       IN   VARCHAR2, 
      dest_loc             IN   VARCHAR2,
      out_status           OUT  VARCHAR2
    );

    PROCEDURE p_create_xsn_bulk_pull_tasks (
      i_xdock_pallet_id      IN  floats.parent_pallet_id%TYPE     DEFAULT NULL,
      i_src_loc              IN  loc.logi_loc%TYPE                DEFAULT NULL,
      i_dest_loc             IN  VARCHAR2,
      out_status             OUT VARCHAR2
    );

END pl_xdock_receiving;
/

CREATE OR REPLACE PACKAGE BODY pl_xdock_receiving IS

  PROCEDURE p_create_xsn
  IS
    l_func_name         CONSTANT swms_log.procedure_name%TYPE := 'p_create_xsn';
    l_message           swms_log.msg_text%TYPE;
    l_error_code        swms_log.msg_no%TYPE;
    l_error_msg         swms_log.sql_err_msg%TYPE;

    CURSOR c_xdock_order_ref_details IS
      SELECT
        xr.manifest_no_from,
        xr.site_from,
        xr.route_no_from
      FROM
        xdock_order_xref xr
      WHERE
        (xr.x_lastmile_status in  ('INTRANSIT', 'NEW') or x_lastmile_status is null)
        AND NOT EXISTS (
          SELECT erm_id
          FROM erm
          WHERE erm_id like CONCAT(TRIM(xr.site_from), TRIM(xr.manifest_no_from)) || '-%'
        )
        AND EXISTS (
          SELECT float_no
          FROM xdock_floats_in
          WHERE route_no = xr.route_no_from 
          AND record_status in ('S', 'N')
        );

    BEGIN

      FOR r_xdock_order_ref_detail IN c_xdock_order_ref_details
        LOOP
          BEGIN
            IF r_xdock_order_ref_detail.manifest_no_from IS NOT NULL
              AND r_xdock_order_ref_detail.site_from IS NOT NULL
              AND r_xdock_order_ref_detail.route_no_from IS NOT NULL THEN
              pl_xdock_receiving.p_populate_xsn_data(
                  r_xdock_order_ref_detail.manifest_no_from,
                  r_xdock_order_ref_detail.site_from,
                  r_xdock_order_ref_detail.route_no_from);
            END IF;
          END;
      END LOOP;

    EXCEPTION
      WHEN OTHERS THEN
        l_error_code := SQLCODE;
        l_error_msg  := SQLERRM;
        l_message := 'Error in p_create_xsn procedure';
        pl_log.ins_msg(i_msg_type    => pl_log.ct_fatal_msg
                , i_procedure_name   => l_func_name
                , i_msg_text         => l_message
                , i_msg_no           => l_error_code
                , i_sql_err_msg      => l_error_msg
                , i_application_func => APPLICATION_FUNC
                , i_program_name     => PACKAGE_NAME);

    END p_create_xsn;

    PROCEDURE p_populate_xsn_data(
      i_manifest_no_from    IN  xdock_order_xref.manifest_no_from%TYPE,
      i_site_from           IN  xdock_order_xref.site_from%TYPE,
      i_route_no_from       IN  xdock_order_xref.route_no_from%TYPE
    ) IS
      l_func_name               CONSTANT swms_log.procedure_name%TYPE := 'p_populate_xsn_data';
      l_message                 swms_log.msg_text%TYPE;
      l_error_code              swms_log.msg_no%TYPE;
      l_error_msg               swms_log.sql_err_msg%TYPE;
      l_manifest_no_from        manifests.manifest_no%TYPE := i_manifest_no_from;
      l_site_from               xdock_order_xref.site_from%TYPE := i_site_from;
      l_route_no_from           xdock_order_xref.route_no_from%TYPE := i_route_no_from;
      l_erm_id_main             erm.erm_id%TYPE := CONCAT(TRIM(i_site_from), TRIM(i_manifest_no_from));
      l_route_info_exist        BOOLEAN := FALSE;

      CURSOR c_xdock_erm_details IS
        SELECT
          comp_code,
          (SELECT MIN(attribute_value) FROM maintenance WHERE component = 'COMPANY') AS vend_name,
          (SELECT MIN(ship_date) FROM xdock_ordm_in WHERE route_no = l_route_no_from) AS ship_date
        FROM
          xdock_floats_in xf
        WHERE
          xf.comp_code IS NOT NULL
          AND xf.route_no = l_route_no_from
        GROUP BY comp_code;

      CURSOR c_xdock_erd_details IS
        SELECT
          xf.parent_pallet_id,
          xf.comp_code,
          xfd.item_seq,
          xfd.prod_id,
          pm.ti,
          pm.hi,
          pm.pallet_type,
          xfd.qty_alloc,
          xfd.cust_pref_vendor,
          xfd.lot_id,
          xfd.exp_date,
          xfd.mfg_date,
          xom.cust_id,
          xom.cust_name,
          xom.weight
        FROM
          xdock_floats_in xf,
          xdock_float_detail_in xfd,
          xdock_ordm_in xom,
          pm pm
        WHERE
          xfd.float_no = xf.float_no
          AND xfd.prod_id = pm.prod_id
          AND xfd.order_id = xom.order_id
          AND xf.route_no = xom.route_no
          AND xf.comp_code IS NOT NULL
          AND xf.route_no = l_route_no_from;

    BEGIN

      /* Validating whether corresponding data exist in pm, xdock_ordm_in, xdock_float_detail_in */
      l_route_info_exist := validate_xsn_route_info(l_route_no_from);
      IF NOT l_route_info_exist THEN
        l_message := 'validate_xsn_route_info Failed for [Route]: ' || l_route_no_from || ', Failed to Create XSN(s) for ERM: ' || l_erm_id_main;
        pl_log.ins_msg(i_msg_type   => pl_log.ct_fatal_msg
                , i_procedure_name   => l_func_name
                , i_msg_text         => l_message
                , i_msg_no           => SQLCODE
                , i_sql_err_msg      => SQLERRM
                , i_application_func => APPLICATION_FUNC
                , i_program_name     => PACKAGE_NAME);
        RETURN;
      END IF; 

      FOR r_xdock_erm_detail IN c_xdock_erm_details
        LOOP
          DECLARE
            l_erm_id_erm   erm.erm_id%TYPE := CONCAT(l_erm_id_main, CONCAT('-', TRIM(r_xdock_erm_detail.comp_code)));

          BEGIN
            INSERT
              INTO erm (
                erm_id,
                erm_type,
                po,
                load_no,
                source_id,
                vend_name,
                status,
                data_collect,
                food_safety_print_flag,
                warehouse_id,
                maint_flag,
                ship_date,
                exp_arriv_date
              ) VALUES (
                l_erm_id_erm,
                'XN',
                l_erm_id_erm,
                l_erm_id_main,
                l_site_from,
                r_xdock_erm_detail.vend_name,
                'NEW',
                'N',
                'N',
                '000',
                'N',
                r_xdock_erm_detail.ship_date,
                r_xdock_erm_detail.ship_date
              );

            INSERT
              INTO rdc_po (
                po_no,
                po_status
              ) VALUES (
                l_erm_id_erm,
                'NEW'
              );

          END;
      END LOOP;

      FOR r_xdock_erd_detail IN c_xdock_erd_details
        LOOP

          DECLARE
            l_erd_erm_id        erd.erm_id%TYPE := CONCAT(l_erm_id_main, CONCAT('-', TRIM(r_xdock_erd_detail.comp_code)));
            l_erm_line_id       erd.erm_line_id%TYPE;
            l_pallet_id         erd_lpn.pallet_id%TYPE := pallet_id_seq.nextval;

          BEGIN
              SELECT NVL(MAX(erm_line_id), 0) + 1
              INTO l_erm_line_id
              FROM erd
              WHERE erm_id=l_erd_erm_id;

              INSERT
                INTO erd (
                  erm_id,
                  erm_line_id,
                  item_seq,
                  prod_id,
                  cust_id,
                  cust_name,
                  qty,
                  uom,
                  cust_pref_vendor,
                  master_case_ind,
                  exp_date,
                  mfg_date
                ) VALUES (
                  l_erd_erm_id,
                  l_erm_line_id,
                  r_xdock_erd_detail.item_seq,
                  r_xdock_erd_detail.prod_id,
                  r_xdock_erd_detail.cust_id,
                  SUBSTR(r_xdock_erd_detail.cust_name, 1, 17),
                  r_xdock_erd_detail.qty_alloc,
                  0,
                  r_xdock_erd_detail.cust_pref_vendor,
                  'N',
                  r_xdock_erd_detail.exp_date,
                  r_xdock_erd_detail.mfg_date
                );

              INSERT
                INTO erd_lpn (
                  sn_no,
                  po_no,
                  erm_line_id,
                  po_line_id,
                  pallet_id,
                  parent_pallet_id,
                  pallet_type,
                  exp_date,
                  mfg_date,
                  cust_pref_vendor,
                  shipped_ti,
                  shipped_hi,
                  lot_id,
                  prod_id,
                  qty
                ) VALUES (
                  l_erd_erm_id,
                  l_erd_erm_id,
                  l_erm_line_id,
                  l_erm_line_id,
                  l_pallet_id,
                  r_xdock_erd_detail.parent_pallet_id,
                  r_xdock_erd_detail.pallet_type,
                  r_xdock_erd_detail.exp_date,
                  r_xdock_erd_detail.mfg_date,
                  r_xdock_erd_detail.cust_pref_vendor,
                  r_xdock_erd_detail.ti,
                  r_xdock_erd_detail.hi,
                  r_xdock_erd_detail.lot_id,
                  r_xdock_erd_detail.prod_id,
                  r_xdock_erd_detail.qty_alloc
              );
          END;
      END LOOP;
    pl_log.ins_msg('INFO', l_func_name, 'p_populate_xsn_data completed. Create XSN(s) Success. erm_id main : ' || l_erm_id_main,
                                          SQLCODE, SQLERRM, APPLICATION_FUNC, PACKAGE_NAME);
    COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        l_error_code := SQLCODE;
        l_error_msg  := SQLERRM;
        l_message := 'Failed to Create XSN(s) for ERM: ' || l_erm_id_main;
        pl_log.ins_msg(i_msg_type   => pl_log.ct_fatal_msg
                , i_procedure_name   => l_func_name
                , i_msg_text         => l_message
                , i_msg_no           => l_error_code
                , i_sql_err_msg      => l_error_msg
                , i_application_func => APPLICATION_FUNC
                , i_program_name     => PACKAGE_NAME);

    END p_populate_xsn_data;


  /************************************************************************* 
  ** validate_xsn_route_info 
  **  Description: Validate whether all required data for the given route 
  **               are populated in xdock_float_detail_in, xdock_ordm_in,
  **               pm tables
  **  Called By : p_populate_xsn_data 
  **  PARAMETERS: 
  **      i_route_no - Route no from
  **      out_status - success or failure output status 
  **  RETURN: TRUE/FALSE
  ****************************************************************/
  FUNCTION validate_xsn_route_info (
        i_route_no           IN  xdock_order_xref.route_no_from%TYPE
    ) RETURN BOOLEAN AS
        l_func_name          VARCHAR2(30) := 'validate_xsn_route_info';
        l_vali_order_id      xdock_ordm_in.order_id%TYPE;
        l_vali_prod_id       xdock_float_detail_in.prod_id%TYPE;
        l_vali_float         xdock_floats_in.float_no%TYPE;

  BEGIN

    /* Validating whether the xdock_float_detail_in table data is existing 
       for the float nos in xdock_floats_in table.
       l_vali_float will have a value if the float_no does not exist in xdock_float_detail_in table.
    */
    BEGIN
      SELECT xf.float_no
      INTO l_vali_float
      FROM xdock_floats_in xf
      WHERE xf.route_no = i_route_no
      AND xf.comp_code IS NOT NULL
      AND NOT EXISTS (
            SELECT float_no
            FROM xdock_float_detail_in 
            WHERE float_no = xf.float_no
      )
      AND rownum=1;

      IF l_vali_float IS NOT NULL THEN
        pl_log.ins_msg('WARN', l_func_name, '[XDOCK_FLOATS_IN.FLOAT_NO]:' || l_vali_float || ' Cannot be found in XDOCK_FLOAT_DETAIL_IN table.',
                        SQLCODE, SQLERRM, APPLICATION_FUNC, PACKAGE_NAME); 
        RETURN FALSE;
      END IF;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
    END;


    /* Validating whether the pm table data is existing 
       for the prod ids in xdock_float_detail_in table.
       l_vali_prod_id will have a value if the prod_id does not exist in pm table.
    */
    BEGIN
      SELECT xdf.prod_id
      INTO l_vali_prod_id
      from xdock_floats_in xf, xdock_float_detail_in xdf
      WHERE xdf.float_no = xf.float_no
      AND xf.route_no = i_route_no
      AND NOT EXISTS (
            SELECT prod_id
            FROM pm 
            WHERE prod_id = xdf.prod_id
      )
      AND rownum=1;

      IF l_vali_prod_id IS NOT NULL THEN
        pl_log.ins_msg('WARN', l_func_name, '[XDOCK_FLOAT_DETAIL_IN.PROD_ID]:' || l_vali_prod_id || ' Cannot be found in PM table.',
                        SQLCODE, SQLERRM, APPLICATION_FUNC, PACKAGE_NAME); 
        RETURN FALSE;
      END IF;
    
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
    END;


    /* Validating whether the xdock_ordm_in table data is existing 
       for the order ids in xdock_float_detail_in table.
       l_vali_order_id will have a value if the order_id does not exist in xdock_ordm_in table
    */
    BEGIN
      SELECT xdf.order_id
      INTO l_vali_order_id
      FROM xdock_floats_in xf, xdock_float_detail_in xdf
      WHERE xdf.float_no = xf.float_no
      AND xf.route_no = i_route_no
      AND NOT EXISTS (
            SELECT order_id
            FROM xdock_ordm_in 
            WHERE order_id = xdf.order_id
            AND route_no = xf.route_no
      )
      AND rownum=1;

      IF l_vali_order_id IS NOT NULL THEN
        pl_log.ins_msg('WARN', l_func_name, '[XDOCK_FLOAT_DETAIL_IN.ORDER_ID]:' || l_vali_order_id || ' Cannot be found in XDOCK_ORDM_IN table.',
                        SQLCODE, SQLERRM, APPLICATION_FUNC, PACKAGE_NAME); 
        RETURN FALSE;
      END IF;
       
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
    
    END;
  
    RETURN TRUE;
      
  END validate_xsn_route_info;

  /************************************************************************* 
  ** get_xdock_route_no (XDOCK route no at site 2)
  **  Description: Find and return the xdock route no (site 2). 
  **  Called By : p_xsn, get_xdock_route_status
  **  PARAMETERS: 
  **      xn_po - XSN number
  **      out_status - success or failure output status 
  **  RETURN VALUES: xdock route no 
  ****************************************************************/
  FUNCTION get_xdock_route_no (
        xn_po IN VARCHAR2,
        out_status OUT VARCHAR2
    ) RETURN VARCHAR2 AS
        func_name                   VARCHAR2(30) := 'get_xdock_route_no';
        xdock_route_no_site2        VARCHAR2(10);
        manifest_no_frm            VARCHAR2(7);

  BEGIN
    /* get manifest_from by spliting the XN substring the XN number */
    BEGIN
        select REGEXP_SUBSTR(xn_po, '(\S*[^-CDF])', 4) 
        into manifest_no_frm 
        from dual;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', func_name, 'Cannot get manifest_no_from value for XN: ' || xn_po, sqlcode, sqlerrm);
            out_status := 'FAILURE'; 
            RETURN '';
    END;
    
    BEGIN
        select ROUTE_NO_TO
        INTO xdock_route_no_site2
        FROM XDOCK_ORDER_XREF
        WHERE MANIFEST_NO_FROM = manifest_no_frm;
    EXCEPTION
        WHEN TOO_MANY_ROWS THEN
          pl_text_log.ins_msg_async('WARN', func_name, 'more than one xdock routes present for manifest_no: ' || manifest_no_frm || '. This not an error even though exact fetch exception occurs here', sqlcode, sqlerrm);
          pl_text_log.ins_msg_async('WARN', func_name, 'This is when shuttle route brought xdock orders which goes into more than one route in site2. ', sqlcode, sqlerrm);
          RETURN 'MANY_XDOCK_ROUTES'; /* DON'T FAILURE HERE, INSTEAD SEND RETURN VALUE AS "MANY_ROUTE"*/
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', func_name, 'Cannot get ROUTE_NO_TO value for manifest_no_from: ' || manifest_no_frm, sqlcode, sqlerrm);
            out_status := 'FAILURE'; 
            RETURN '';
            
    END;

    pl_text_log.ins_msg_async('WARN', func_name, 'XDOCK Route no found at site 2: ' || xdock_route_no_site2, sqlcode, sqlerrm);
    RETURN xdock_route_no_site2;

  END get_xdock_route_no;


  /************************************************************************* 
  ** get_xdock_route_status 
  **  Description: Find and return the status of xdock route status (site 2). 
  **  Called By : p_open_xsn 
  **  PARAMETERS: 
  **      xn_po - XSN number
  **      out_status - success or failure output status 
  **  RETURN VALUES: status of xdock route (OPN/SHT/NEW) 
  ****************************************************************/
  FUNCTION get_xdock_route_status (
        xn_po IN VARCHAR2,
        out_status OUT VARCHAR2
    ) RETURN VARCHAR2 AS
        func_name                   VARCHAR2(30) := 'get_xdock_route_status';
        xdock_route_no_site2        VARCHAR2(17); --there is a function which returns a string with 17 chars (MANY_XDOCK_ROUTES)
        manifest_no_frm            VARCHAR2(7);
        xdock_route_status          VARCHAR2(3);

  BEGIN  
      pl_text_log.ins_msg_async('WARN', func_name, 'Fiding relevent Xdock Route no for xn: ' || xn_po, sqlcode, sqlerrm);
      xdock_route_no_site2 := get_xdock_route_no(xn_po, out_status);
      IF xdock_route_no_site2 IS NULL OR out_status = 'FAILURE' THEN
        pl_text_log.ins_msg_async('WARN', func_name, 'ERROR Fiding Xdock Route no for xn: ' || xn_po, sqlcode, sqlerrm);
        RETURN '';
      END IF;
      
      IF xdock_route_no_site2 = 'MANY_XDOCK_ROUTES'  THEN
        RETURN 'MANY_XDOCK_ROUTES';
      END IF;

      BEGIN
          SELECT STATUS
          INTO xdock_route_status
          FROM ROUTE
          WHERE ROUTE_NO = xdock_route_no_site2;
      EXCEPTION
          WHEN OTHERS THEN
              pl_text_log.ins_msg_async('WARN', func_name, 'Cannot get STATUS of xdock route: ' || xdock_route_no_site2, sqlcode, sqlerrm);
              out_status := 'FAILURE';
              RETURN '';
      END;

      RETURN xdock_route_status;
  END get_xdock_route_status;

    /************************************************************************* 
  ** check_if_A_or_C_btchs_exists 
  **  Description: Find if there are Active or Complete batches for xdock route exists (site 2). 
  **  Called By : p_open_xsn 
  **  PARAMETERS: 
  **      xn_po - XSN number
  **      out_status - success or failure output status 
  **  RETURN VALUES: TRUE or FALSE 
  ****************************************************************/
  FUNCTION check_if_A_or_C_btchs_exists (
        xn_po IN VARCHAR2,
        out_status OUT VARCHAR2
    ) RETURN BOOLEAN AS
        func_name                 VARCHAR2(30) := 'check_if_A_or_C_btchs_exists';
        xdock_route_no_site2      VARCHAR2(10);
        manifest_no_frm           VARCHAR2(7);
        sos_batch_status          VARCHAR2(3);
        batches_found             BOOLEAN :=  FALSE;  
  BEGIN
      
      pl_text_log.ins_msg_async('WARN', func_name, 'Fiding relevent Xdock Route no for xn: ' || xn_po, sqlcode, sqlerrm);
      xdock_route_no_site2 := get_xdock_route_no(xn_po, out_status);
      
      IF xdock_route_no_site2 IS NULL OR out_status = 'FAILURE' THEN
        pl_text_log.ins_msg_async('WARN', func_name, 'Error Fiding Xdock Route no for xn: ' || xn_po, sqlcode, sqlerrm);
        RETURN FALSE;
      END IF;

      BEGIN
          SELECT STATUS
          INTO sos_batch_status
          FROM SOS_BATCH
          WHERE ROUTE_NO = xdock_route_no_site2
          AND STATUS IN ('A', 'C')
          AND ROWNUM = 1;
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
            batches_found := FALSE;
            pl_text_log.ins_msg_async('WARN', func_name, 'No Active or closed batches for xdock route: ' || xdock_route_no_site2 || 
            '. Hence will putaway for a staging location', sqlcode, sqlerrm);
          WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', func_name, 'Error selecting from SOS_BATCH table for xdock route: ' || xdock_route_no_site2, sqlcode, sqlerrm);
            out_status := 'FAILURE';
            RETURN FALSE;
      END;

      IF sos_batch_status IS NOT NULL THEN
          batches_found := TRUE;
      END IF;

      RETURN batches_found;

  END check_if_A_or_C_btchs_exists;

  /************************************************************************* 
  ** find_xn_pallet_staging_loc 
  **  Description: Find XN pallet staging destination location. 
  **  Called By : p_create_xn_putaway_tasks 
  **  PARAMETERS: 
  **      xn_area - area of XN (D, F, C) 
  **      xn_po - XN number
  **      parent_pallet- xn pallet id (in erd_lpn parent_pallet_id)
  **  RETURN VALUES: destination location
  **      
  ****************************************************************/
  FUNCTION find_xn_pallet_staging_loc (
      xn_area IN VARCHAR2,
      xn_po IN VARCHAR2,
      parent_pallet IN VARCHAR2,
      out_status OUT VARCHAR2
  ) RETURN VARCHAR2 AS
      func_name           VARCHAR2(30) := 'find_xn_pallet_staging_loc';
      dest_loc            VARCHAR2(10);
      xdock_route_no      VARCHAR2(10);
      xdock_route_status  VARCHAR2(3);
  BEGIN
      pl_text_log.ins_msg_async('INFO', func_name,' Starting Function:' || func_name , sqlcode, sqlerrm);
      BEGIN
          SELECT logi_loc
          INTO dest_loc
          FROM (
              SELECT l.logi_loc
              FROM swms_sub_areas s, aisle_info ai, loc l, lzone lz, zone z
              WHERE z.zone_id=lz.zone_id 
                  AND ai.name=substr(l.logi_loc,1,2) 
                  AND z.zone_type='PUT' 
                  AND z.rule_id=14 
                  AND z.induction_loc is null  --  a induction loc should not be the first choice
                  AND lz.logi_loc=l.logi_loc 
                  AND s.sub_area_code=ai.sub_area_code 
                  AND s.area_code = xn_area
              MINUS
              SELECT dest_loc from putawaylst where dest_loc is not null
          )
          WHERE ROWNUM = 1;
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
              pl_text_log.ins_msg_async('WARN', func_name, 'No obvious staging locations left to putaway for XN = ' || xn_po   
              || '. Next checking locations which has bulk pulled (XDOCK_SHIP_CONFIRM = Y)', sqlcode, sqlerrm);  
              dest_loc := '';
      END;
      
      IF dest_loc is null THEN
          BEGIN
              SELECT dest_loc
              INTO dest_loc
              FROM putawaylst
              WHERE XDOCK_SHIP_CONFIRM = 'Y'
              AND SUBSTR(DEST_LOC, 1, 1) = xn_area
              AND NOT EXISTS (
                SELECT DOOR_NO FROM DOOR 
                WHERE DOOR_NO = putawaylst.dest_loc
              )
              AND ROWNUM = 1;

              -- now make the XDOCK_SHIP_CONFIRM to N as we have selected it again as putaway dest locaion
              UPDATE PUTAWAYLST
              SET XDOCK_SHIP_CONFIRM = NULL
              WHERE DEST_LOC = dest_loc
              and XDOCK_SHIP_CONFIRM = 'Y'
              AND ROWNUM = 1;

          EXCEPTION
              WHEN NO_DATA_FOUND THEN
                  pl_text_log.ins_msg_async('WARN', func_name, 'No any staging locations left to putaway for parent pallet = ' || parent_pallet 
                  || '. Next using the defualt Induction Location for area of parent pallet', sqlcode, sqlerrm);  
                  dest_loc := '';
          END;
      END IF;
  
      IF dest_loc is null THEN
          BEGIN
              SELECT logi_loc 
              INTO dest_loc
              FROM (
                  SELECT l.logi_loc
                  FROM swms_sub_areas s, aisle_info ai, loc l, lzone lz, zone z
                  WHERE substr(z.induction_loc,1,1)=xn_area
                      AND z.zone_id=lz.zone_id 
                      AND ai.name=substr(l.logi_loc,1,2) 
                      AND z.zone_type='PUT' 
                      AND z.rule_id=14 
                      AND lz.logi_loc=l.logi_loc 
                      AND s.sub_area_code=ai.sub_area_code 
                      AND s.area_code = xn_area
              )
              WHERE ROWNUM = 1;

              pl_text_log.ins_msg_async('INFO', func_name, 'Found dest location is :' || dest_loc || ' for parent pallet: ' || parent_pallet , sqlcode, sqlerrm);
         
          EXCEPTION
              WHEN NO_DATA_FOUND THEN
                  pl_text_log.ins_msg_async('WARN', func_name, 'No any staging or backup induction locations available for parent pallet: ' || parent_pallet, sqlcode, sqlerrm);  
                  out_status := 'FAILURE';
                  RETURN '';
          END;
      END IF;
      
      IF dest_loc is not null THEN
          RETURN dest_loc;
      ELSE
        pl_text_log.ins_msg_async('WARN', func_name, 'Incorrect Destination location to putaway for parent pallet: ' || parent_pallet, sqlcode, sqlerrm);  
        out_status := 'FAILURE';
        RETURN '';
      END IF;  
  END find_xn_pallet_staging_loc;


  /*
    This funciton returns the xdock route no that a 
    given parent pallet should go in. 
  */
  FUNCTION xdock_route_given_prnt_plt(
    parent_pallet IN VARCHAR2,
    out_status OUT VARCHAR2
  ) RETURN VARCHAR2 AS
    func_name           VARCHAR2(30) := 'xdock_route_given_prnt_plt';
    xdock_route_no      VARCHAR2(10);
  BEGIN
    pl_text_log.ins_msg_async('INFO', func_name, 'Starting to find xdock route no for given parent_pallet_id: ' || parent_pallet, sqlcode, sqlerrm); 
    BEGIN
        SELECT route_no_to 
        INTO xdock_route_no
        FROM xdock_order_xref 
        WHERE order_id_to IN (
            SELECT order_id 
            FROM xdock_float_detail_in 
            WHERE float_no IN (
                SELECT float_no 
                FROM xdock_floats_in 
                WHERE parent_pallet_id = parent_pallet
            )
        )
        AND ROWNUM = 1;
        
        pl_text_log.ins_msg_async('INFO', func_name, 'Found xdock route no:' || xdock_route_no || ' for given parent_pallet_id: ' || parent_pallet, sqlcode, sqlerrm); 
        
        IF xdock_route_no IS NOT NULL THEN
          RETURN xdock_route_no;
        ELSE
          pl_text_log.ins_msg_async('WARN', func_name, 'Error finding xdock route for given parent_pallet_id: ' || parent_pallet, sqlcode, sqlerrm);  
          out_status := 'FAILURE';
          RETURN '';
        END IF;
    END;
  EXCEPTION
      WHEN OTHERS THEN
      pl_text_log.ins_msg_async('WARN', func_name, 'Exception Raised while finding xdock route no for parent pallet: ' || parent_pallet, sqlcode, sqlerrm);
      out_status := 'FAILURE';
  END xdock_route_given_prnt_plt;


  FUNCTION calc_tot_split_count (
      parent_pallet IN VARCHAR2,
      out_status OUT VARCHAR2
  ) RETURN NUMBER AS
      func_name           VARCHAR2(30) := 'calc_tot_split_count';
      tot_qty_in_splits   NUMBER := 0;

      CURSOR get_prod_spc_uom_and_qty IS 
      SELECT xfd.prod_id, p.spc, xfd.uom, xfd.qty_alloc
      FROM xdock_float_detail_in xfd, xdock_floats_in xf, pm p
      WHERE xfd.float_no = xf.float_no
      AND xfd.prod_id = p.prod_id
      AND xf.parent_pallet_id = parent_pallet;
  BEGIN

    FOR prod_spc_uom_and_qty in get_prod_spc_uom_and_qty LOOP BEGIN
        -- since we manually hard code UOM as 0 when creating ERD records, dont consider UOM value 
        -- in xdock_float_detail_in table. 
        tot_qty_in_splits := tot_qty_in_splits + CEIL(prod_spc_uom_and_qty.qty_alloc / prod_spc_uom_and_qty.spc);
    END;
    END LOOP;   
    
    pl_text_log.ins_msg_async('WARN', func_name, 'Total QTY in splits for parent pallet = ' || parent_pallet || ' is: ' || tot_qty_in_splits, sqlcode, sqlerrm);

    IF tot_qty_in_splits > 0 THEN
      RETURN tot_qty_in_splits;
    ELSE
      RETURN -1;
    END IF;

  EXCEPTION
      WHEN OTHERS THEN
      pl_text_log.ins_msg_async('WARN', func_name, 'Exception Raised while calculating total item count in splits for parent pallet = ' || parent_pallet, sqlcode, sqlerrm);
      out_status := 'FAILURE';
  END calc_tot_split_count;


/************************************************************************* 
  ** p_close_xsn 
  **  Description: Close XSN CRT
  **  Called By : pl_rcv_po_close.mainproc - Only for erm_type = 'XN'
  **  PARAMETERS: 
  **      i_erm_id   - XSN number passed from pl_rcv_po_close.mainproc as Input
  **      out_status - Success / Error Message
  **      out_code   - Success Code / Error Code
  **     
  ****************************************************************/
  PROCEDURE p_close_xsn(
    i_erm_id            IN  erm.erm_id%TYPE,
    out_status          OUT VARCHAR2,
    out_code            OUT NUMBER
  ) IS
    e_po_locked         EXCEPTION;
    PRAGMA              EXCEPTION_INIT(e_po_locked,-54);
    l_func_name         CONSTANT swms_log.procedure_name%TYPE := 'p_close_xsn';
    l_message           swms_log.msg_text%TYPE;
    l_error_code        swms_log.msg_no%TYPE;
    l_error_msg         swms_log.sql_err_msg%TYPE;
    l_erm_status        erm.status%TYPE;

    CURSOR c_po_lock (cp_erm_id VARCHAR2)
    IS
      SELECT erm_id
      FROM erm
      WHERE po = cp_erm_id FOR UPDATE OF status,
        close_date NOWAIT;

    BEGIN

      /* Lock XSN */
      BEGIN
        IF NOT c_po_lock%ISOPEN THEN
          OPEN c_po_lock (i_erm_id);
        END IF;
      EXCEPTION
        WHEN e_po_locked THEN
          out_code := -54;
          out_status := 'ORACLE XSN ' || i_erm_id || ' locked by another user.';
          pl_text_log.ins_msg ('WARN', l_func_name, out_status, -54, SQLERRM );
          RETURN;
        WHEN OTHERS THEN
          out_code := SQLCODE;
          out_status := 'ORACLE Unable to lock XSN ' || i_erm_id || '.';
          pl_text_log.ins_msg ('WARN', l_func_name, out_status, SQLCODE, SQLERRM );
          RETURN;
      END;

      BEGIN
        SELECT status
        INTO l_erm_status
        FROM erm
        WHERE erm_id = i_erm_id;
      EXCEPTION
        WHEN OTHERS THEN
          out_code := SQLCODE;
          out_status := 'Cannot get ERM.STATUS for XSN: ' || i_erm_id || '.';
          pl_text_log.ins_msg('WARN', l_func_name, 'Cannot get ERM.STATUS for XSN: ' || i_erm_id, sqlcode, sqlerrm);
          RETURN;
      END;

      /* Verify the Status of the XSN */
      IF l_erm_status <> 'OPN' THEN
          out_code := SQLCODE;
          out_status := 'Cannot close XSN ' || i_erm_id ||'.' || ' XSN has status of ' || l_erm_status;
          pl_text_log.ins_msg('WARN', l_func_name, 'Cannot close XSN ' || i_erm_id ||'.' || ' XSN has status of ' || l_erm_status, sqlcode, sqlerrm);
          RETURN;
      END IF;


      /* Change XSN status to CLO */
      UPDATE erm
        SET status = 'CLO', close_date = SYSDATE
      WHERE erm_id = i_erm_id;

      UPDATE rdc_po
        SET po_status = 'CLO'
      where po_no	= i_erm_id;	

      /* Create a CLX transaction */
      INSERT INTO trans (
          trans_id, trans_type, rec_id,
          trans_date, user_id, upload_time, batch_no
      ) VALUES (
          trans_id_seq.NEXTVAL, 'CLX', i_erm_id,
          SYSDATE, user, null, '88'
      );

    pl_log.ins_msg('INFO', l_func_name, 'Close XSN Success for erm_id : ' || i_erm_id,
                    SQLCODE, SQLERRM, APPLICATION_FUNC, PACKAGE_NAME);

    /* Release lock on XSN*/
    IF c_po_lock%ISOPEN THEN
      CLOSE c_po_lock;
    END IF;

    out_status := 'SUCCESS';
    out_code := SQLCODE;
    EXCEPTION
      WHEN OTHERS THEN
        /* Release lock on XSN*/
        IF c_po_lock%ISOPEN THEN
          CLOSE c_po_lock;
        END IF;
        l_error_code := SQLCODE;
        l_error_msg  := SQLERRM;
        l_message := 'Failed to Close XSN for ERM: ' || i_erm_id;
        pl_log.ins_msg(i_msg_type    => pl_log.ct_fatal_msg
                , i_procedure_name   => l_func_name
                , i_msg_text         => l_message
                , i_msg_no           => l_error_code
                , i_sql_err_msg      => l_error_msg
                , i_application_func => APPLICATION_FUNC
                , i_program_name     => PACKAGE_NAME);
        out_status := SUBSTR(SQLERRM, 1, 200);
        out_code := SQLCODE;

    END p_close_xsn;

  /************************************************************************* 
  **  p_purge_xsn 
  **  Description: Purge XSNs
  **  Called By : xdock_receiving_purge_xsn.sh - Only for erm_type = 'XN'
  **     
  ****************************************************************/
  PROCEDURE p_purge_xsn IS
    l_func_name         CONSTANT swms_log.procedure_name%TYPE := 'p_purge_xsn';
    l_message           swms_log.msg_text%TYPE;
    l_error_code        swms_log.msg_no%TYPE;
    l_error_msg         swms_log.sql_err_msg%TYPE;
    l_days_before       NUMBER := 7;

    CURSOR c_purge_erm_list IS
      SELECT
        erm_id
      FROM
        erm
      WHERE
        erm_type = 'XN'
        AND ship_date <= SYSDATE - l_days_before;

    BEGIN

      FOR r_erm_detail IN c_purge_erm_list
        LOOP
          BEGIN
            LOOP
              DELETE FROM erd_lpn
              WHERE sn_no = r_erm_detail.erm_id
                AND ROWNUM <= 1000;
              EXIT WHEN SQL%ROWCOUNT = 0;
            END LOOP;

            LOOP
              DELETE FROM erd
              WHERE erm_id = r_erm_detail.erm_id
                AND ROWNUM <= 1000;
              EXIT WHEN SQL%ROWCOUNT = 0;
            END LOOP;

            LOOP
              DELETE FROM erm
              WHERE erm_id = r_erm_detail.erm_id
                AND ROWNUM <= 1000;
              EXIT WHEN SQL%ROWCOUNT = 0;
            END LOOP;

            LOOP
              DELETE FROM rdc_po
              WHERE po_no = r_erm_detail.erm_id
                AND ROWNUM <= 1000;
              EXIT WHEN SQL%ROWCOUNT = 0;
            END LOOP;

            LOOP
              DELETE FROM putawaylst
              WHERE rec_id = r_erm_detail.erm_id
                AND ROWNUM <= 1000;
              EXIT WHEN SQL%ROWCOUNT = 0;
            END LOOP;
          COMMIT;
          END;
      END LOOP;
    
    pl_log.ins_msg('INFO', l_func_name, 'XSN Purge Success for XSNs [ship_date] older than one week : ',
                    SQLCODE, SQLERRM, APPLICATION_FUNC, PACKAGE_NAME);

    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        l_error_code := SQLCODE;
        l_error_msg  := SQLERRM;
        l_message := 'XSN Purge Failed';
        pl_log.ins_msg(i_msg_type    => pl_log.ct_fatal_msg
                , i_procedure_name   => l_func_name
                , i_msg_text         => l_message
                , i_msg_no           => l_error_code
                , i_sql_err_msg      => l_error_msg
                , i_application_func => APPLICATION_FUNC
                , i_program_name     => PACKAGE_NAME);
    END p_purge_xsn;

  /************************************************************************* 
  ** p_close_xsn_rf 
  **  Description: Close XSN RF
  **  Called By : pl_rcv_po_close.mainproc_rf - Only for erm_type = 'XN'
  **  PARAMETERS: 
  **      i_erm_id            -   XSN number passed from pl_rcv_po_close.mainproc_rf as Input              
  **      i_client_flag         
  **      i_client_sp_flag      
  **      out_status  
  **      out_code 
  **   OUT Parameters for mainproc_rf :-   
  **      o_sp_current_total   
  **      o_sp_supplier_count 
  **      o_erm_id       
  **      o_prod_id  
  **      o_cust_pref_vendor
  **      o_exp_splits   
  **      o_exp_qty  
  **      o_rec_splits        
  **      o_rec_qty
  **      o_hld_cases
  **      o_hld_splits
  **      o_hld_pallet
  **      o_total_pallet 
  **      o_num_pallet 
  **      o_status 
  **      ot_sp_suppliers
  **
  **     
  ****************************************************************/
  PROCEDURE p_close_xsn_rf(
    i_erm_id               IN  erm.erm_id%TYPE,
    i_client_flag          IN  CHAR,
    i_client_sp_flag       IN  CHAR,
    out_status             OUT VARCHAR2,
    out_code               OUT NUMBER,
    o_sp_current_total     OUT NUMBER,
    o_sp_supplier_count    OUT NUMBER,
    o_erm_id               OUT erm.erm_id%TYPE,
    o_prod_id              OUT pm.prod_id%TYPE,
    o_cust_pref_vendor     OUT pm.cust_pref_vendor%TYPE,
    o_exp_splits           OUT NUMBER,
    o_exp_qty              OUT NUMBER,
    o_rec_splits           OUT NUMBER,
    o_rec_qty              OUT NUMBER,
    o_hld_cases            OUT NUMBER,
    o_hld_splits           OUT NUMBER,
    o_hld_pallet           OUT NUMBER,
    o_total_pallet         OUT NUMBER,
    o_num_pallet           OUT NUMBER,
    o_status               OUT NUMBER,
    ot_sp_suppliers        OUT VARCHAR2
  ) IS
    e_po_locked         EXCEPTION;
    PRAGMA              EXCEPTION_INIT(e_po_locked,-54);
    l_func_name         CONSTANT swms_log.procedure_name%TYPE := 'p_close_xsn_rf';
    l_message           swms_log.msg_text%TYPE;
    l_error_code        swms_log.msg_no%TYPE;
    l_error_msg         swms_log.sql_err_msg%TYPE;
    l_erm_status        erm.status%TYPE;

    /* Values taken from pl_rcv_po_close.sql */
    ct_LOCKED_PO        NUMBER := 112;
    ct_INV_OPT          NUMBER := 29;
    ct_INV_PO           NUMBER := 90;
    ct_CLO_PO           NUMBER := 91;


    /* Lock XSN Cursor */
    CURSOR c_po_lock (cp_erm_id VARCHAR2)
    IS
      SELECT erm_id
      FROM erm
      WHERE po = cp_erm_id FOR UPDATE OF status,
        close_date NOWAIT;

    CURSOR c_pallet_supplier IS
      SELECT ps.supplier
      FROM pallet_supplier ps
      WHERE NOT EXISTS (SELECT 1
                        FROM sp_pallet sp
                        WHERE sp.erm_id = i_erm_id
                          AND sp.supplier = ps.supplier)
      ORDER BY 1;

    BEGIN

      o_status := NULL;
      /* Lock XSN */
      BEGIN
        IF NOT c_po_lock%ISOPEN THEN
          OPEN c_po_lock (i_erm_id);
        END IF;
      EXCEPTION
        WHEN e_po_locked THEN
          out_code := -54;
          out_status := 'ORACLE XSN ' || i_erm_id || ' locked by another user.';
          pl_text_log.ins_msg ('WARN', l_func_name, out_status, -54, SQLERRM );
          o_status := ct_LOCKED_PO;
          RETURN;
        WHEN OTHERS THEN
          out_code := SQLCODE;
          out_status := 'ORACLE Unable to lock XSN ' || i_erm_id || '.';
          pl_text_log.ins_msg ('WARN', l_func_name, out_status, SQLCODE, SQLERRM );
          o_status := ct_INV_PO;
          RETURN;
      END;

      BEGIN
        SELECT status
        INTO l_erm_status
        FROM erm
        WHERE erm_id = i_erm_id;
      EXCEPTION
        WHEN OTHERS THEN
          out_code := SQLCODE;
          out_status := 'Cannot get ERM.STATUS for XSN: ' || i_erm_id || '.';
          pl_text_log.ins_msg('WARN', l_func_name, 'Cannot get ERM.STATUS for XSN: ' || i_erm_id, sqlcode, sqlerrm);
          o_status := ct_INV_PO;
          RETURN;
      END;

      /* Verify the Status of the XSN */
      IF l_erm_status = 'CLO' THEN
         out_status := 'Cannot close XSN' || i_erm_id || '.' ||
                      '  XSN is already closed.';
         pl_text_log.ins_msg('WARN', l_func_name, out_status, sqlcode, sqlerrm);
         o_status := ct_CLO_PO;
         RETURN;
      ELSIF l_erm_status = 'NEW' THEN
         out_status := 'Cannot close XSN ' || i_erm_id ||'.' ||
                      '  XSN has status of NEW.';
         pl_text_log.ins_msg('WARN', l_func_name, out_status, sqlcode, sqlerrm);
         o_status := ct_INV_OPT;
         RETURN;
      END IF;

      BEGIN
        IF i_client_sp_flag <> 'Y' THEN
          o_sp_current_total := 0;
          o_sp_supplier_count := 0;
        ELSE
          SELECT NVL(SUM(pallet_qty),0)
          INTO o_sp_current_total
          FROM sp_pallet
          WHERE erm_id = i_erm_id;
          o_sp_supplier_count := 0;
          ot_sp_suppliers := NULL;
          FOR r_pallet_supplier IN c_pallet_supplier LOOP
            o_sp_supplier_count := o_sp_supplier_count + 1;
            IF ot_sp_suppliers IS NULL THEN
                ot_sp_suppliers := r_pallet_supplier.supplier;
            ELSE
                ot_sp_suppliers := ot_sp_suppliers || '~' || r_pallet_supplier.supplier;
            END IF;
          END LOOP;
        END IF;
      END;

      BEGIN
        SELECT
          NVL(SUM(DECODE(l.uom,0,l.qty_expected/NVL(p.spc,1),0)),0),
          NVL(SUM(DECODE(l.uom,1,l.qty_expected,0)),0),
          COUNT(DISTINCT NVL(l.parent_pallet_id,l.pallet_id)),
          NVL(SUM(DECODE(l.uom,0,l.qty_received/NVL(p.spc,1),0)),0),
          NVL(SUM(DECODE(l.uom,1,l.qty_received,0)),0),
          COUNT(DISTINCT DECODE(l.qty_received,0,NULL,NVL(l.parent_pallet_id,l.pallet_id)))
        INTO
          o_exp_qty,
          o_exp_splits,
          o_num_pallet,
          o_rec_qty,
          o_rec_splits,
          o_total_pallet
        FROM pm p, putawaylst l, erm e
        WHERE l.prod_id = p.prod_id(+)
          AND l.cust_pref_vendor = p.cust_pref_vendor(+)
          AND l.rec_id = e.erm_id
          AND e.po = i_erm_id;
      END;

      o_erm_id := i_erm_id;
      o_prod_id := 'MULTI';
      o_cust_pref_vendor := '-';

      /* inv status will not be HLD */
      o_hld_cases := 0;
      o_hld_splits := 0;
      o_hld_pallet := 0;

      IF  NVL(i_client_flag,'Y') <> 'N' THEN
        /* Change XSN status to CLO */
        UPDATE erm
          SET status = 'CLO', close_date = SYSDATE
        WHERE erm_id = i_erm_id;

        UPDATE rdc_po
          SET po_status = 'CLO'
        where po_no	= i_erm_id;	

        /* Create a CLX transaction */
        INSERT INTO trans (
            trans_id, trans_type, rec_id,
            trans_date, user_id, upload_time, batch_no
        ) VALUES (
            trans_id_seq.NEXTVAL, 'CLX', i_erm_id,
            SYSDATE, user, null, '99'
        );
      END IF;

    pl_log.ins_msg('INFO', l_func_name, 'Close XSN (RF) Success for erm_id : ' || i_erm_id,
                    SQLCODE, SQLERRM, APPLICATION_FUNC, PACKAGE_NAME);

    /* Release lock on XSN*/
    IF c_po_lock%ISOPEN THEN
      CLOSE c_po_lock;
    END IF;

    out_status := 'SUCCESS';
    out_code := SQLCODE;
    EXCEPTION
      WHEN OTHERS THEN
        /* Release lock on XSN*/
        IF c_po_lock%ISOPEN THEN
          CLOSE c_po_lock;
        END IF;
        l_error_code := SQLCODE;
        l_error_msg  := SQLERRM;
        l_message := 'Failed to Close XSN (RF) for ERM: ' || i_erm_id;
        pl_log.ins_msg(i_msg_type    => pl_log.ct_fatal_msg
                , i_procedure_name   => l_func_name
                , i_msg_text         => l_message
                , i_msg_no           => l_error_code
                , i_sql_err_msg      => l_error_msg
                , i_application_func => APPLICATION_FUNC
                , i_program_name     => PACKAGE_NAME);
        out_status := SUBSTR(SQLERRM, 1, 200);
        out_code := SQLCODE;

    END p_close_xsn_rf;


  /************************************************************************* 
  ** p_open_xsn 
  **  Description: Open the given XSN. 
  **  Called By : Forms / Front end 
  **  PARAMETERS: 
  **      xn_po - XSN number
  **      out_status - success or failure output status 
  ****************************************************************/
  PROCEDURE p_open_xsn (
        xn_po     IN           erm.erm_id%TYPE,
        out_status OUT        VARCHAR2
  ) IS             
        func_name                         VARCHAR2(50) := 'pl_xsn_receive.p_xsn';
        po_locking                        VARCHAR2(5);
        po_chk                            VARCHAR2(5);
        po_exist                          BOOLEAN := TRUE;
        po_status                         VARCHAR2(4);
        labour_batches_created_status     VARCHAR2(100);
        xdock_route_status                VARCHAR2(17);  --there is a function which returns a string with 17 chars (MANY_XDOCK_ROUTES)
        xdck_A_or_C_btchs_exists          BOOLEAN := FALSE;
        xdock_route_no_site2              VARCHAR2(10);

        manifest_no_frm                   VARCHAR2(7);

        l_no_records_processed            PLS_INTEGER;
        l_no_batches_created              PLS_INTEGER;
        l_no_batches_existing             PLS_INTEGER; 
        l_no_not_created_due_to_error     PLS_INTEGER;

        CURSOR c_xn_fsi IS
        SELECT erm_id
        FROM erm
        WHERE erm_id =  xn_po
        AND erm_id in (
          SELECT erm_id FROM erd 
          WHERE prod_id in (
            SELECT prod_id 
            FROM pm 
            WHERE hazardous in (
              SELECT hazardous 
              FROM haccp_codes  
              WHERE food_safety_trk = 'Y'
            )
          )
        );

  BEGIN
      pl_text_log.ins_msg_async('INFO', func_name,' Starting Procedure:' || func_name , sqlcode, sqlerrm);
      BEGIN
          SELECT 'x'
          INTO po_chk
          FROM erm
          WHERE erm_id = xn_po;
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
              pl_text_log.ins_msg_async('FATAL', func_name, xn_po || ' Invalid XSN Number ', sqlcode, sqlerrm);
              out_status := 'Invalid XSN Number' || xn_po;
              po_exist := FALSE;
          WHEN OTHERS THEN
              pl_text_log.ins_msg_async('FATAL', func_name, ' Unable to Check XSN Number ' || xn_po, sqlcode, sqlerrm);
              out_status := 'Unable to Check XSN Number' || xn_po;
              po_exist := FALSE;   
      END;

      IF po_exist = TRUE THEN
          /* IF XSN is available then lock the table */
          BEGIN
              SELECT 'x'
              INTO po_locking
              FROM erm
              WHERE erm_id = xn_po
              AND status IN ('NEW', 'SCH')
              FOR UPDATE OF status NOWAIT;
          EXCEPTION
              WHEN NO_DATA_FOUND THEN
                  pl_text_log.ins_msg_async('INFO', func_name, xn_po || ' XSN is already open ', sqlcode, sqlerrm);
                  out_status := xn_po || ' XSN is already open ';
                  po_exist := FALSE;
                  RETURN;
              WHEN OTHERS THEN
                  pl_text_log.ins_msg_async('INFO', func_name, xn_po || 'Issue in checking the XSN ', sqlcode, sqlerrm);
                  out_status :=  ' Issue in checking the XSN ' || xn_po;
                  po_exist := FALSE;
                  RETURN;     
          END;

          IF po_locking != 'x' THEN 
              pl_text_log.ins_msg_async('FATAL', func_name, 'Unable to lock XSN : ' || xn_po, sqlcode, sqlerrm);
              out_status := 'Unable to lock XSN';
              RETURN;
          ELSE
              pl_text_log.ins_msg_async('INFO', func_name, 'Currently processing request to open XSN: ' ||xn_po, sqlcode,sqlerrm);
              
              p_create_blkpulls_nd_putaways(xn_po, out_status);

              IF (out_status = 'FAILURE') THEN
                  pl_text_log.ins_msg_async('WARN', func_name, 'Creating putaway tasks failed for XN: ' || xn_po, sqlcode, sqlerrm);
                  ROLLBACK;
                  RETURN;
              END IF;


              IF out_status != 'FAILURE' THEN
                /* Jira#3614 */  
                FOR fsi_rec in c_xn_fsi LOOP 
                BEGIN
                  UPDATE erm
                  SET food_safety_print_flag = 'Y'
                  WHERE erm_id = fsi_rec.erm_id;
                END;
                END LOOP; 
              END IF;

              /* Create a ROP transaction */
              BEGIN
                  INSERT INTO trans (
                      trans_id, trans_type, rec_id,
                      trans_date, user_id, upload_time
                  ) VALUES (
                      trans_id_seq.NEXTVAL, 'ROP', xn_po,
                      SYSDATE, user, TO_DATE('01-JAN-1980', 'DD-MON-YYYY')
                  );
              EXCEPTION
                  WHEN OTHERS THEN
                      pl_text_log.ins_msg_async('INFO', func_name, ' Unable to create ROP transaction with YYYY - 1980 ', sqlcode, sqlerrm);
                      out_status := 'FAILURE';
                      ROLLBACK;
                      RETURN;
              END;

              /* CHange XN status to OPN */
              BEGIN
                  UPDATE erm
                  SET erm.status = 'OPN', erm.rec_date = SYSDATE
                  WHERE erm.erm_id = xn_po;

                  pl_text_log.ins_msg_async('INFO', func_name, ' XN updated to OPN', sqlcode, sqlerrm);
              EXCEPTION
                  WHEN OTHERS THEN
                      pl_text_log.ins_msg_async('FATAL', func_name, 'Unable to update status to OPN for XN: ' || xn_po, sqlcode, sqlerrm);
                      out_status := 'FAILURE';
                      ROLLBACK;
                      RETURN;
              END;
              /* Creating putaway tasks and then creating a ROP transction, and then changing the ERM Status to OPN is DONE*/

              BEGIN
                  SELECT status
                  INTO po_status
                  FROM erm
                  WHERE erm_id = xn_po;
              EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                      out_status := 'FAILURE';
                      RETURN;
                  WHEN OTHERS THEN
                      out_status := 'FAILURE';
                      RETURN;    
              END;

              IF po_status = 'OPN' THEN  /* IF PO status is OPN then process creating batches */

                  out_status := 'SUCCESS';
                  commit;
                  --  END IF;

                  pl_lmf.create_putaway_batches_for_po(xn_po,
                                                       l_no_records_processed, 
                                                       l_no_batches_created, 
                                                       l_no_batches_existing, 
                                                       l_no_not_created_due_to_error);

                  pl_text_log.ins_msg_async('INFO', func_name, 'l_no_records_processed '||l_no_records_processed|| 
                                                       'l_no_batches_created '||l_no_batches_created||
                                                       'l_no_batches_existing '||l_no_batches_existing|| 
                                                       'l_no_not_created_due_to_error '||l_no_not_created_due_to_error, sqlcode,sqlerrm);


                  IF ( l_no_not_created_due_to_error > 0 ) THEN

                      out_status := 'FAILURE';
                      pl_text_log.ins_msg_async('INFO', func_name,'Po# ' || xn_po || ' error occurred when creating forklift batches', sqlcode,sqlerrm);
                      RETURN;  

                  ELSIF ( l_no_records_processed = (l_no_batches_created + l_no_batches_existing) ) THEN


                      out_status := 'SUCCESS';
                      commit;

                  ELSIF ( l_no_records_processed <> (l_no_batches_created + l_no_batches_existing) ) THEN

                      out_status := 'FAILURE';
                      pl_text_log.ins_msg_async('INFO', func_name,'Po# ' || xn_po || ' Batches created or existing does not match records processed.', sqlcode,sqlerrm);
                      RETURN;
                      
                  ELSE

                      out_status := 'FAILURE';
                      pl_text_log.ins_msg_async('INFO', func_name,'Po# ' || xn_po || ' Unknow error when creating forklift batches.', sqlcode,sqlerrm);
                      RETURN;

                  END IF;

              ELSE
                  out_status :=   'FAILURE';
              END IF;  /* IF PO status is OPN then process creating batches ends */

          END IF;
      ELSE
        pl_text_log.ins_msg_async('ERROR', func_name,'NO ERM records found in DB for po no:' || xn_po, sqlcode, sqlerrm);
        po_exist := FALSE;
        RETURN;     
      END IF;   /* IF PO/SN is not available then log the error ends */
  end p_open_xsn;

  procedure p_create_putaway_task_for_plt (
      i_parent_pallet_id   IN   VARCHAR2, 
      receiving_door       IN   VARCHAR2, 
      dest_loc             IN   VARCHAR2,
      out_status           OUT  VARCHAR2
  ) is 
      func_name                   VARCHAR2(50) := 'p_create_putaway_task_for_plt';  
      xn_area                     VARCHAR2(1);
      erm_id                      VARCHAR2(12);
      site2_route                 VARCHAR2(10);
      physical_door               NUMBER(3);
      seq_no                            NUMBER := 0;
      no_of_child_pallets               NUMBER := 0;
      multi_or_prod_id                  VARCHAR2(9);
      tot_splt_cnt_in_ppallet           NUMBER := 0;
      xdock_route_no                    VARCHAR2(10);
      xdock_route_status                VARCHAR2(3);

  begin
      pl_text_log.ins_msg_async('INFO', func_name,' Starting Procedure:' || func_name , sqlcode, sqlerrm);
      BEGIN 
          SELECT PO_NO
          INTO erm_id
          FROM erd_lpn
          WHERE parent_pallet_id = i_parent_pallet_id
          AND ROWNUM=1;
      EXCEPTION
      WHEN OTHERS THEN
          pl_text_log.ins_msg_async('WARN', func_name, 'Cannot get ERM_ID of parent pallet: ' || i_parent_pallet_id, sqlcode, sqlerrm);
          out_status := 'FAILURE';
          RETURN;
      END;

       /*getting XN area*/
      BEGIN 
          SELECT REGEXP_SUBSTR(erm_id, '[CDF]', 10) 
          INTO xn_area
          FROM dual;
      EXCEPTION
      WHEN OTHERS THEN
          pl_text_log.ins_msg_async('ERROR', func_name, 'Cannot get area of xn: ' || erm_id, sqlcode, sqlerrm);
          out_status := 'FAILURE';
          RETURN;
      END;

      /* Check if this parent pallet has only one item. If so, instead of "MULTI" we should enter the actual prod_id for prod_id in putawaylst*/
      BEGIN 
          SELECT count(pallet_id)
          INTO no_of_child_pallets
          FROM erd_lpn
          WHERE parent_pallet_id = i_parent_pallet_id;

          IF no_of_child_pallets = 0 THEN
              pl_text_log.ins_msg_async('WARN', func_name, 'No child pallets for parent pallet id: ' || i_parent_pallet_id || '. Cannot Open the XN', sqlcode, sqlerrm);
              out_status := 'FAILURE';
              RETURN;
          ELSIF no_of_child_pallets = 1 THEN
              SELECT prod_id
              INTO multi_or_prod_id
              FROM erd_lpn
              WHERE parent_pallet_id = i_parent_pallet_id;

              IF multi_or_prod_id is null THEN
                  pl_text_log.ins_msg_async('WARN', func_name, 'prod id is null for parent pallet id: ' || i_parent_pallet_id || '. Cannot Open the XN', sqlcode, sqlerrm);
                  out_status := 'FAILURE';
                  RETURN;
              END IF;
          ELSIF no_of_child_pallets > 1 THEN
              multi_or_prod_id := 'MULTI';
          END IF;

      EXCEPTION
          WHEN OTHERS THEN
              pl_text_log.ins_msg_async('WARN', func_name, 'Cannot get number of child pallets for parent pallet id: ' || i_parent_pallet_id, sqlcode, sqlerrm);
      END;

      tot_splt_cnt_in_ppallet := calc_tot_split_count(i_parent_pallet_id, out_status);

      IF tot_splt_cnt_in_ppallet < 1 THEN
        pl_text_log.ins_msg_async('WARN', func_name, 'total split cout should be grater that 0 for parent pallet: ' || i_parent_pallet_id || '. Cannot Open the XN', sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('WARN', func_name, 'Check if you have synced all the products from site1 to site2 which are in parent pallet: ' || i_parent_pallet_id, sqlcode, sqlerrm);
        out_status := 'FAILURE';
        RETURN;
      END IF;

      /* Get the next sequance number in putawaylst. We use 1 + max(seq_no) as seq_no and erm_line_id for XN putaways*/
      BEGIN 
          SELECT MAX(seq_no) + 1 
          INTO seq_no
          FROM putawaylst;
      EXCEPTION
          WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', func_name, 'Cannot get next seq_no value from putawaylst table. Hense use 0 as the next seq_no', sqlcode, sqlerrm);
      END;

      /* Inseart the putaway record to putawaylst table */
      BEGIN
        INSERT INTO PUTAWAYLST (
            pallet_id, rec_id,  prod_id, -- 01
            dest_loc, qty, uom, 
            status, inv_status, equip_id,   -- 03
            putpath, rec_lane_id, zone_id, 
            lot_id, exp_date, weight,    -- 05
            temp, mfg_date, qty_expected, 
            qty_received, date_code, exp_date_trk,   --07
            lot_trk, catch_wt, temp_trk, 
            putaway_put, seq_no, mispick,   -- 09
            cust_pref_vendor, erm_line_id, print_status, 
            reason_code, orig_invoice, pallet_batch_no,    -- 11
            out_src_loc, out_inv_date, rtn_label_printed, 
            clam_bed_trk, inv_dest_loc, add_date,   -- 13
            add_user, upd_date, upd_user, 
            tti_trk, tti, cryovac,     -- 15
            parent_pallet_id, qty_dmg, po_line_id, 
            sn_no, po_no, printed_date,    -- 17
            cool_trk, from_splitting_sn_pallet_flag, demand_flag, 
            qty_produced, master_order_id    -- 19       
        ) VALUES (
            i_parent_pallet_id, erm_id, multi_or_prod_id,  -- 01
            dest_loc, tot_splt_cnt_in_ppallet, 0,
            'NEW', 'AVL', ' ',   -- 03
            null, ' ', null,
            null, TRUNC(SYSDATE), null,   -- 05
            null, TRUNC(SYSDATE), tot_splt_cnt_in_ppallet,
            tot_splt_cnt_in_ppallet, null, null,   -- 07
            'N', 'N', 'N',
            'N', seq_no, 'N',  -- 09
            '-', seq_no, null,
            null, null, null,  -- 11
            null, null, null,
            'N', null, TRUNC(SYSDATE), -- 13
            null, null, null,
            'N', null, null, -- 15, 
            decode(multi_or_prod_id, 'MULTI', ' ', null), null, null,
            null, erm_id, null,  -- 17
            'N', null, null,
            null, null  -- 19
        );
      EXCEPTION
      WHEN OTHERS THEN
          pl_text_log.ins_msg_async('WARN', func_name, 'Creating putaway record failed for XN pallet id: ' || i_parent_pallet_id, sqlcode, sqlerrm);
          out_status := 'FAILURE';
          RETURN;
      END;
  end p_create_putaway_task_for_plt;


  FUNCTION get_shipping_door (
    parent_pallet_id     IN   VARCHAR2, 
    xn_area              IN   VARCHAR2,
    out_status           OUT  VARCHAR2
  ) RETURN VARCHAR2 AS
      func_name       VARCHAR2(50) := 'get_shipping_door';  
      dest_loc        VARCHAR2(10) := '-1';
      site2_route     VARCHAR2(10);
      physical_door   NUMBER(3);

  BEGIN
      pl_text_log.ins_msg_async('INFO', func_name,' Starting Function:' || func_name , sqlcode, sqlerrm);
      site2_route := pl_xdock_common.get_xdk_route_for_xsn_pallet(parent_pallet_id, out_status);

      IF out_status = 'FAILURE' THEN
        pl_text_log.ins_msg_async('ERROR', func_name, 'Cannot get site2 route for pallet ' || parent_pallet_id, sqlcode, sqlerrm);
        dest_loc := '-1';
        RETURN dest_loc;
      END IF;

      IF xn_area = 'F' THEN
        SELECT F_DOOR 
        INTO physical_door
        FROM ROUTE
        WHERE route_no = site2_route;

      ELSIF xn_area = 'C' THEN
        SELECT C_DOOR 
        INTO physical_door
        FROM ROUTE
        WHERE route_no = site2_route;
      ELSIF xn_area = 'D' THEN
        SELECT D_DOOR 
        INTO physical_door
        FROM ROUTE
        WHERE route_no = site2_route;
      ELSE
        pl_text_log.ins_msg_async('ERROR', func_name, 'No door assigned for route: ' || site2_route, sqlcode, sqlerrm);
        out_status := 'FAILURE';
        dest_loc := '-1';
        RETURN dest_loc;
      END IF;

      -- Getting the door location number for physical door
      BEGIN
        SELECT door_no 
        INTO dest_loc
        FROM door 
        WHERE physical_door_no = physical_door;
      EXCEPTION
      WHEN OTHERS THEN
          pl_text_log.ins_msg_async('ERROR', func_name, 'cannot get shipping door location for physical door: ' || physical_door, sqlcode, sqlerrm);
          out_status := 'FAILURE';
          dest_loc := '-1';
          RETURN dest_loc;
      END;

      IF dest_loc is null THEN
        out_status := 'FAILURE';
      END IF;
      RETURN dest_loc;
  END get_shipping_door; 

  procedure p_create_blkpulls_nd_putaways (
      xn_po       IN        erm.erm_id%TYPE,
      out_status  OUT       VARCHAR2
  ) IS 
      func_name                 VARCHAR2(50) := 'p_create_blkpulls_nd_putaways';  
      site2_route               VARCHAR2(10);
      site2_route_status        VARCHAR2(3);
      site2_selection_started   BOOLEAN;
      receiving_door            VARCHAR2(4);
      shipping_door             VARCHAR2(4);
      staging_loc               VARCHAR2(10);
      xn_area                   VARCHAR2(1);
      /* cursor to get all pallets in the xsn*/
      CURSOR c_xn_pallets IS
      SELECT DISTINCT(parent_pallet_id)
      FROM erd_lpn
      WHERE sn_no = xn_po;  

  begin
    pl_text_log.ins_msg_async('INFO', func_name,' Starting Procedure:' || func_name , sqlcode, sqlerrm);

        FOR xn_pallet in c_xn_pallets LOOP BEGIN
            site2_route := pl_xdock_common.get_xdk_route_for_xsn_pallet(xn_pallet.parent_pallet_id, out_status);

            IF out_status = 'FAILURE' THEN
              pl_text_log.ins_msg_async('ERROR', func_name, 'Could not get site2 route for XSN pallet: ' || xn_pallet.parent_pallet_id, sqlcode, sqlerrm);
              RETURN;
            END IF;

            BEGIN
              SELECT status
              INTO site2_route_status
              FROM route
              where route_no = site2_route;

              SELECT door_no
              INTO receiving_door
              FROM erm
              WHERE erm_id = xn_po;

              pl_text_log.ins_msg_async('INFO', func_name, 'XSN pallet: ' || xn_pallet.parent_pallet_id ||
               ' route_no: ' || site2_route || ' route status:' || site2_route_status, sqlcode, sqlerrm);

              pl_text_log.ins_msg_async('INFO', func_name, 'XSN pallet: ' || xn_pallet.parent_pallet_id ||
               'receiving door:' || receiving_door, sqlcode, sqlerrm);

               /*getting XN area*/
              BEGIN 
                  SELECT REGEXP_SUBSTR(xn_po, '[CDF]', 10) 
                  INTO xn_area
                  FROM dual;
              EXCEPTION
              WHEN OTHERS THEN
                  pl_text_log.ins_msg_async('ERROR', func_name, 'Cannot get area of xn: ' || xn_po, sqlcode, sqlerrm);
                  out_status := 'FAILURE';
                  RETURN;
              END;

              staging_loc := find_xn_pallet_staging_loc(xn_area, xn_po, xn_pallet.parent_pallet_id, out_status);

              IF site2_route_status in ('NEW', 'RCV', 'WAT', 'ERR') THEN
                  -- create a putaway task. SRC_LOC = RECEIVING DOOR, DEST_LOC = A STAGING LOC
                  p_create_putaway_task_for_plt(xn_pallet.parent_pallet_id, receiving_door, staging_loc, out_status);         
                  -- do not create a bulk pull task (i.e no record to replenlst table)
              ELSE
                  site2_selection_started := pl_xdock_common.is_route_selection_started(xn_pallet.parent_pallet_id, out_status);
                  
                  IF site2_selection_started THEN
                      pl_text_log.ins_msg_async('ERROR', func_name, 'Site2 route selection is started', sqlcode, sqlerrm);
                      shipping_door := get_shipping_door(xn_pallet.parent_pallet_id, xn_area, out_status);

                      -- create a putawaylst (src = receiving door, dst = shipping door)
                       p_create_putaway_task_for_plt(xn_pallet.parent_pallet_id, receiving_door, shipping_door, out_status);

                      -- create a bulk pull (src = receiving door, dst = shipping door)
                      p_create_xsn_bulk_pull_tasks(xn_pallet.parent_pallet_id, receiving_door, shipping_door, out_status);

                  ELSE
                      pl_text_log.ins_msg_async('ERROR', func_name, 'Site2 route selection is not started', sqlcode, sqlerrm);
                      -- createa a putawaylst (src = receiving door, dst = staging loc)
                       p_create_putaway_task_for_plt(xn_pallet.parent_pallet_id, receiving_door, staging_loc, out_status);

                      -- createa a bulk pull (src = staging door, dst = shipping door)
                      p_create_xsn_bulk_pull_tasks(xn_pallet.parent_pallet_id, staging_loc, shipping_door, out_status);

                  END IF;
              END IF;      
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  pl_text_log.ins_msg_async('ERROR', func_name, 'Site2 Xdock Route not available for XSN pallet: ' || xn_pallet.parent_pallet_id, sqlcode, sqlerrm);
                  out_status := 'FAILURE';
                  RETURN;
            END;
        END;
        END LOOP;
  end;


  PROCEDURE p_create_xsn_bulk_pull_tasks (
      i_xdock_pallet_id      IN  floats.parent_pallet_id%TYPE     DEFAULT NULL,
      i_src_loc              IN  loc.logi_loc%TYPE                DEFAULT NULL,
      i_dest_loc             IN  VARCHAR2,
      out_status             OUT VARCHAR2
  ) IS
      func_name     VARCHAR2(30) := 'create_xsn_bulk_pull_tasks';
      l_message         VARCHAR2(512);        -- Message buffer
      l_task_src_loc             replenlst.src_loc%TYPE;
      l_r_create_batch_stats     pl_lmf.t_create_putaway_stats_rec;    -- Used when creating the forklift labor batch

      -- This selects the Site 2 cross dock float info to create a XDK bulk pull 
      -- task for a specified parent pallet id.
      --
      CURSOR c_floats(
        cp_xdock_pallet_id    floats.xdock_pallet_id%TYPE
      ) IS
      SELECT
        f.float_no, f.route_no, r.truck_no, 
        r.route_batch_no, f.site_from, f.site_to,
        f.cross_dock_type, f.pallet_id, f.xdock_pallet_id,            -- This will be the replenlst.pallet_id
        f.equip_id, f.door_no, f.door_area,
        DECODE(COUNT(DISTINCT fd.prod_id || fd.cust_pref_vendor), 1, MIN(fd.prod_id), 'MULTI')           prod_id,
        DECODE(COUNT(DISTINCT fd.prod_id || fd.cust_pref_vendor), 1, MIN(fd.cust_pref_vendor), '-')      cust_pref_vendor,  -- Just leave CPV at '-'
        SUM(DECODE(fd.uom, 1, fd.qty_alloc, fd.qty_alloc / pm.spc ))                                     qty,
        MIN(fd.src_loc)          src_loc,     -- FYI All the float detail records should have the same location.
        MIN(fd.exp_date)         exp_date,
        MIN(fd.mfg_date)         mfg_date,
        MIN(loc.pik_path)        src_loc_pik_path,
        MIN(fd.order_id)         order_id,
        COUNT(*)                 fd_rec_count,
        put.rec_id               put_rec_id,
        erm.erm_type             erm_type,
        erm.status               erm_status,
        put.dest_loc             put_dest_loc     -- This is will be the replenlst.src_loc
      FROM
        loc          loc, floats       f,
        float_detail fd,  route        r,
        pm           pm,  putawaylst   put,       -- To see if pallet received
        erm                                       -- Info about the XN the pallet is on
      WHERE 
        f.parent_pallet_id    = i_xdock_pallet_id
        AND fd.float_no             = f.float_no
        AND f.pallet_pull           = 'B'           -- Site 2 cross dock pallets are always bulk pulls
        AND f.cross_dock_type       = 'X'           -- Site 2 has 'X' for the cross dock type
        AND loc.logi_loc (+)        = fd.src_loc
        AND pm.prod_id              = fd.prod_id
        AND pm.cust_pref_vendor     = fd.cust_pref_vendor
        AND r.route_no              = f.route_no
        AND put.pallet_id       (+) = f.xdock_pallet_id     -- Outer join to putawaylst because the pallet may not have been received yet.
        AND erm.erm_id          (+) = put.rec_id
      GROUP BY
        f.float_no, f.route_no, r.truck_no, r.route_batch_no,
        f.site_from, f.site_to, f.cross_dock_type, f.pallet_id,
        f.xdock_pallet_id, f.equip_id, f.door_no, f.door_area, 
        put.rec_id, erm.erm_type, erm.status, put.dest_loc;

  BEGIN
      pl_text_log.ins_msg_async('INFO', func_name,' Starting Procedure:' || func_name , sqlcode, sqlerrm);
      pl_text_log.ins_msg_async('INFO', func_name, 'bulk pull for pallet: ' || i_xdock_pallet_id ||
       ' SRC: ' || i_src_loc || ' Dest: ' || i_dest_loc, sqlcode, sqlerrm);
      
      FOR r_floats IN c_floats(i_xdock_pallet_id) LOOP

          INSERT INTO replenlst
          (
            task_id, prod_id, cust_pref_vendor,   --- 01
            uom, qty, type,
            status, src_loc, pallet_id,           --- 03
            dest_loc, s_pikpath, d_pikpath,
            batch_no, equip_id, order_id,         --- 05
            user_id, op_acquire_flag, gen_uid,
            gen_date, exp_date, route_no,         --- 07
            float_no, seq_no, door_no,
            drop_qty, pick_seq, route_batch_no,   --- 09
            truck_no, inv_dest_loc, parent_pallet_id, dmd_repl_attempts,
            labor_batch_no, priority, rec_id,           --- 11
            mfg_date, lot_id, orig_pallet_id,
            replen_type, replen_aisle, replen_area,     --- 13
            mx_batch_no, case_no, print_lpn,
            mx_short_cases, site_from, site_to,         --- 15
            cross_dock_type, xdock_pallet_id
          )
          VALUES(
            repl_id_seq.NEXTVAL, r_floats.prod_id, r_floats.cust_pref_vendor,   --- 01
            -- UOM always 2 for XSNs
            2, r_floats.qty,'XDK', 'NEW',
            i_src_loc, r_floats.xdock_pallet_id, --- 03
            --
            i_dest_loc, r_floats.src_loc_pik_path, NULL,   --- 05
            0, r_floats.equip_id, r_floats.order_id,
            NULl, 'Y', REPLACE(USER, 'OPS$', NULL),       --- 07
            SYSDATE, r_floats.exp_date, r_floats.route_no,
            r_floats.float_no,                              --- 09
            1, r_floats.door_no, 0,   
            NULL, r_floats.route_batch_no, r_floats.truck_no,       --- 11
            NULL, NULL, NULL,                   
            NULL, NULL, NULL,                 --- 13
            r_floats.mfg_date, NULL, NULL,
            'D', NULL, r_floats.door_area,      --- 15
            NULL, NULL, NULL,
            NULL, r_floats.site_from, r_floats.site_to,       --- 17
            r_floats.cross_dock_type, r_floats.xdock_pallet_id
          );
          -- If forkfift labor is active then create the XDK bulk pull labor batch.
          IF (pl_lmf.f_forklift_active = TRUE)
          THEN
              pl_lmf.create_xdk_pallet_pull_batch
                                  (i_float_no             => r_floats.float_no,
                                  o_r_create_batch_stats => l_r_create_batch_stats);
          END IF;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
          pl_text_log.ins_msg_async('ERROR', func_name,'Error creating bulk pull taks for pallet:' || i_xdock_pallet_id , sqlcode, sqlerrm);

    END p_create_xsn_bulk_pull_tasks;

END pl_xdock_receiving;
/

CREATE OR REPLACE PUBLIC SYNONYM pl_xdock_receiving FOR swms.pl_xdock_receiving;
GRANT EXECUTE ON swms.pl_xdock_receiving TO SWMS_USER;
