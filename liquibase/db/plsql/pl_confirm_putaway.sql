create or replace PACKAGE pl_confirm_putaway AS
/*******************************************************************************
**Package:
**        pl_confirm_putaway. Migrated from confirm_putaway.pc
**
**Description:
**        Putaway service for non rf companies.
**
**Called by:
**        This is called from Forms/UI
*******************************************************************************/
    PROCEDURE p_execute_frm (
        i_userid   IN   VARCHAR2,
        i_paramv   IN   VARCHAR2,
        o_status   OUT  VARCHAR2
    );

    PROCEDURE confirm_putaway_main (
        i_pallet_id   IN            VARCHAR2,
        i_user_id     IN            VARCHAR2,
        o_status      OUT           VARCHAR2
    );

    FUNCTION putaway RETURN NUMBER;

    FUNCTION check_putawaylist RETURN NUMBER;

    PROCEDURE get_putaway_info;

    PROCEDURE get_product_info;

    PROCEDURE get_po_info;

    FUNCTION check_home_slot RETURN NUMBER;

    FUNCTION confirm_putaway_task RETURN NUMBER;

    FUNCTION write_transaction (
        i_trans_type IN VARCHAR2
    ) RETURN NUMBER;

    FUNCTION update_inv_zero_rcv (
        i_flag IN NUMBER
    ) RETURN NUMBER;

    FUNCTION update_inv (
        i_plogi_loc   IN            VARCHAR2,
        i_logi_loc    IN            VARCHAR2,
        i_flag        IN            NUMBER
    ) RETURN NUMBER;

    FUNCTION delete_inv RETURN NUMBER;

    FUNCTION data_collect_check (
        i_plogi_loc   IN            VARCHAR2,
        i_logi_loc    IN            VARCHAR2
    ) RETURN NUMBER;

    FUNCTION pop_date (
        i_hsf IN NUMBER
    ) RETURN NUMBER;

    FUNCTION update_put_trans RETURN NUMBER;

    FUNCTION check_po_status RETURN NUMBER;

    FUNCTION delete_putaway_task RETURN NUMBER;

    FUNCTION check_new_float RETURN NUMBER;

END pl_confirm_putaway;
/

create or replace PACKAGE BODY pl_confirm_putaway IS

    normal                   NUMBER := 0;
    c_true                   CONSTANT NUMBER := 1;
    c_false                  CONSTANT NUMBER := 0;
    put_done                 CONSTANT NUMBER := 94;
    wrong_put                CONSTANT NUMBER := 87;
    putawaylst_update_fail   CONSTANT NUMBER := 173;
    lock_po                  CONSTANT NUMBER := 112;
    inv_update_fail          CONSTANT NUMBER := 118;
    del_inv_fail             CONSTANT NUMBER := 176;
    unavl_po                 CONSTANT NUMBER := 113;
    del_putawylst_fail       CONSTANT NUMBER := 123;
    inv_po                   CONSTANT NUMBER := 90;
    g_pallet_id              putawaylst.pallet_id%TYPE;
    g_cust_pref_vendor       pm.cust_pref_vendor%TYPE;
    g_prod_id                pm.prod_id%TYPE;
    g_erm_status             erm.status%TYPE;
    g_qty_rec                putawaylst.qty_expected%TYPE;
    g_dest_loc               putawaylst.dest_loc%TYPE;
    g_erm_type               erm.erm_type%TYPE;
    g_uom                    putawaylst.uom%TYPE;
    g_receive_id             putawaylst.rec_id%TYPE;
    g_lot_id                 putawaylst.lot_id%TYPE;
    g_inv_exp_date           putawaylst.exp_date%TYPE;
    g_weight                 putawaylst.weight%TYPE;
    g_mfg_date               putawaylst.mfg_date%TYPE;
    g_qty_exp                putawaylst.qty_expected%TYPE;
    g_temp                   putawaylst.temp%TYPE;
    g_inv_status             putawaylst.inv_status%TYPE;
    g_orig_invoice           putawaylst.orig_invoice%TYPE;
    g_order_id               putawaylst.lot_id%TYPE;
    g_order_line_id          putawaylst.seq_no%TYPE;
    g_case_cube              pm.case_cube%TYPE;
    g_spc                    pm.spc%TYPE;
    g_logi_loc               putawaylst.dest_loc%TYPE;
    g_mfg_ind                putawaylst.date_code%TYPE;
    g_exp_ind                putawaylst.exp_date_trk%TYPE;
    g_lot_ind                putawaylst.lot_trk%TYPE;
    g_temp_ind               putawaylst.temp_trk%TYPE;
    g_exp_date               putawaylst.exp_date%TYPE;
    g_sysco_shelf_life       pm.sysco_shelf_life%TYPE;
    g_cust_shelf_life        pm.cust_shelf_life%TYPE;
    g_mfr_shelf_life         pm.mfr_shelf_life%TYPE;
    g_erm_id                 erm.erm_id%TYPE;
    g_mispick                putawaylst.mispick%TYPE;
    g_home_slot_flag         NUMBER;
    r_exp_rcv                pl_miniload_processing.t_exp_receipt_info;
    row_locked EXCEPTION;
    PRAGMA exception_init ( row_locked, -54 );

/*************************************************************************
** p_execute_frm
**  Description: Main Program to be called from the PL/SQL wrapper/Forms
**  Called By : DBMS_HOST_COMMAND_FUNC
**  PARAMETERS:
**      i_userid - User id passed from Frontend
**      i_paramv - Function parameters passed from Frontend as Input
**      o_status   - Output parameter returned to front end
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    PROCEDURE p_execute_frm (
        i_userid   IN   VARCHAR2,
        i_paramv   IN   VARCHAR2,
        o_status   OUT  VARCHAR2
    ) IS
        l_func_name         VARCHAR2(50)    := 'pl_confirm_putaway.p_execute_frm';
        v_count             NUMBER          := 0;
        l_pallet_id VARCHAR2(18);
        v_prams_list c_prams_list;
    BEGIN
        v_prams_list := F_SPLIT_PRAMS(i_paramv);
        v_count := v_prams_list.count;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'F_SPLIT_PRAMS invoked...', sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'F_SPLIT_PRAMS size:' || v_count, sqlcode, sqlerrm);

        IF v_count < 2 THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Usage : ' || v_prams_list(1) || 'User', sqlcode, sqlerrm);
            o_status := '-1';
        ELSE
        l_pallet_id := SUBSTR( v_prams_list(2), 1, 18);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Invoking confirm_putaway_main', sqlcode, sqlerrm);
        confirm_putaway_main(l_pallet_id, v_prams_list(1), o_status);
        END IF;

    EXCEPTION WHEN OTHERS THEN
        pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Raised at ' || l_func_name || 'for params ' || i_paramv, sqlcode, sqlerrm);
        o_status := 'FAILURE';
    END p_execute_frm;

/*****************************************************************
** putaway_main
**  Description:  main program for putaway service.
**  Called By : API Service
**  PARAMETERS :
**      i_pallet_id - Pallet id passed from UI screen
**      i_user_id   - User id passed from UI screen
**      o_status    - Output parameter returned to front end
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    PROCEDURE confirm_putaway_main (
        i_pallet_id   IN            VARCHAR2,
        i_user_id     IN            VARCHAR2,
        o_status      OUT           VARCHAR2
    ) IS
    
        l_func_name   VARCHAR2(30) := 'confirm_putaway_main';
        l_logi_loc    inv.logi_loc%TYPE;
        l_skid_cube   pallet_type.skid_cube%TYPE;
        l_cube        pallet_type.cube%TYPE;
        l_status      NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Processing putaway', sqlcode, sqlerrm);
        g_pallet_id := i_pallet_id;
        l_status := putaway;
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Ending putaway', sqlcode, sqlerrm);
        o_status := l_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, ' Processing putaway Failed', sqlcode, sqlerrm);
            o_status := l_status;
    END confirm_putaway_main;

/*************************************************************************
** putaway
**  Description:  main program for putaway service.
**  Called By : confirm_putaway_main
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION putaway RETURN NUMBER IS

        l_func_name        VARCHAR2(30) := 'putaway';
        l_status           NUMBER := normal;
        l_istatus          NUMBER;
        l_new_float_flag   NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' putaway starts ', sqlcode, sqlerrm);
/*
**  Check putawaylst for the following conditions -
**  1. pallet does not exist 2. putaway already confirmed 3. dest loc undefined
*/
        l_status := check_putawaylist;
        IF ( l_status != normal ) THEN
            RETURN l_status;
        END IF;
        get_putaway_info;
        get_product_info;
        get_po_info;
        IF ( g_erm_status = 'OPN' ) THEN    /* PO is OPEN */
            g_home_slot_flag := check_home_slot;
            pl_text_log.ins_msg_async('INFO', l_func_name, ' g_home_slot_flag value = ' || g_home_slot_flag, sqlcode, sqlerrm);
            
            IF ( g_erm_type != 'CM' ) THEN    /* Receiving PO - NOT a return */
                l_status := confirm_putaway_task;
                IF ( l_status != normal ) THEN
                    RETURN l_status;
                END IF;
                IF ( g_qty_rec > 0 ) THEN        /* qty rec if starts */
                    IF ( g_home_slot_flag > 0 ) THEN    /*  Checking Homeslot */
                        l_status := update_inv(g_dest_loc, g_dest_loc, c_true);
                    ELSE
                        l_status := update_inv(g_dest_loc, g_pallet_id, c_true);
                    END IF;

                    IF ( l_status != normal ) THEN
                        RETURN l_status;
                    END IF;
                    l_status := write_transaction('PUT');
                    l_istatus := normal;
                    BEGIN
                        IF ( pl_ml_common.f_is_induction_loc(g_dest_loc) = 'Y' ) THEN 	/* pl_ml_common package starts */
                            r_exp_rcv.v_expected_receipt_id := g_pallet_id;
                            r_exp_rcv.v_prod_id := g_prod_id;
                            r_exp_rcv.v_cust_pref_vendor := g_cust_pref_vendor;
                            r_exp_rcv.n_uom := g_uom;
                            IF ( g_uom = 0 ) THEN
                                r_exp_rcv.n_uom := 2;
                            END IF;
                            r_exp_rcv.n_qty_expected := g_qty_rec;
                            r_exp_rcv.v_inv_date := TO_DATE(g_inv_exp_date, 'FXDD-MON-YYYY');
                            pl_text_log.ins_msg_async('INFO', l_func_name, '< receipt_id = '
                                                                || r_exp_rcv.v_expected_receipt_id
                                                                || ' prod_id = '
                                                                || r_exp_rcv.v_prod_id
                                                                || ' cpv =  '
                                                                || r_exp_rcv.v_cust_pref_vendor
                                                                || ' uom =  '
                                                                || TO_CHAR(r_exp_rcv.n_uom)
                                                                || ' qty exp =  '
                                                                || TO_CHAR(r_exp_rcv.n_qty_expected)
                                                                || ' inv date = '
                                                                || TO_CHAR(r_exp_rcv.v_inv_date, 'FXDD-MON-YYYY')
                                                                || '>', sqlcode, sqlerrm);

                            pl_miniload_processing.p_send_exp_receipt(r_exp_rcv, l_istatus);
                            IF ( l_istatus = pl_miniload_processing.ct_er_duplicate ) THEN
                                l_istatus := pl_miniload_processing.ct_success;
                            END IF;

                        END IF;  /* pl_ml_common package ends */
                    EXCEPTION
                        WHEN OTHERS THEN
                            IF ( l_istatus != normal ) THEN
                                pl_text_log.ins_msg_async('WARN', l_func_name, 'p_send_exp_receipt =  '
                                                                    || g_pallet_id
                                                                    || ' Status = '
                                                                    || l_istatus, sqlcode, sqlerrm);

                            ELSE
                                l_istatus := sqlcode;
                            END IF;
                    END;

                ELSIF ( g_qty_rec = 0 ) THEN   /* qty rec = 0  starts */
                    IF ( g_home_slot_flag > 0 ) THEN    /* g_home_slot_flag cond starts */
                        l_status := update_inv_zero_rcv(c_true);
                    ELSE
                        l_status := delete_inv;
                    END IF;     /* g_home_slot_flag cond starts */

                    IF ( l_status != normal ) THEN
                        RETURN l_status;
                    END IF;
                END IF;       /* qty rec if ends */

            ELSE      /* return PO */
                l_status := delete_putaway_task();
                IF ( l_status != normal ) THEN
                    RETURN l_status;
                END IF;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Mispick = ' || g_mispick || ' qty_rec = ' || g_qty_rec, sqlcode, sqlerrm);
                IF ( g_mispick != 'Y' ) THEN      /*    g_mispick if starts  */
                    IF ( g_qty_rec > 0 ) THEN
                        IF ( g_home_slot_flag > 0 ) THEN          /* g_home_slot_flag starts after qty_rec >0 */
                            l_status := update_inv(g_dest_loc, g_dest_loc, c_false);
                        ELSE
                            l_new_float_flag := check_new_float();
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'new_float_flag = ' || l_new_float_flag, sqlcode, sqlerrm);
                            IF ( l_new_float_flag > 0 ) THEN        /*  l_new_float_flag starts */
                                l_status := update_inv(g_dest_loc, g_dest_loc, c_true);
                            ELSE
                                l_status := update_inv(g_dest_loc, 'FFFFFF', c_false);
                            END IF;    /*  l_new_float_flag ends */

                        END IF;

                        IF ( l_status != normal ) THEN
                            RETURN l_status;
                        END IF;
                         l_status := write_transaction('PUT');
                         l_istatus := normal;
                        BEGIN
                            IF ( pl_ml_common.f_is_induction_loc(g_dest_loc) = 'Y' ) THEN
                                r_exp_rcv.v_expected_receipt_id := g_pallet_id;
                                r_exp_rcv.v_prod_id := g_prod_id;
                                r_exp_rcv.v_cust_pref_vendor := g_cust_pref_vendor;
                                r_exp_rcv.n_uom := g_uom;
                                IF ( g_uom = 0 ) THEN
                                    r_exp_rcv.n_uom := 2;
                                END IF;
                                r_exp_rcv.n_qty_expected := g_qty_rec;
                                r_exp_rcv.v_inv_date := TO_DATE(g_inv_exp_date, 'FXDD-MON-YYYY');
                                pl_text_log.ins_msg_async('INFO', l_func_name, '< receipt_id = '
                                                                    || r_exp_rcv.v_expected_receipt_id
                                                                    || ' prod_id = '
                                                                    || r_exp_rcv.v_prod_id
                                                                    || ' cpv =  '
                                                                    || r_exp_rcv.v_cust_pref_vendor
                                                                    || ' uom =  '
                                                                    || TO_CHAR(r_exp_rcv.n_uom)
                                                                    || ' qty exp =  '
                                                                    || TO_CHAR(r_exp_rcv.n_qty_expected)
                                                                    || ' inv date = '
                                                                    || TO_CHAR(r_exp_rcv.v_inv_date, 'FXDD-MON-YYYY')
                                                                    || '>', sqlcode, sqlerrm);

                                pl_miniload_processing.p_send_exp_receipt(r_exp_rcv, l_istatus);
                                IF ( l_istatus = pl_miniload_processing.ct_er_duplicate ) THEN
                                    l_istatus := pl_miniload_processing.ct_success;
                                END IF;

                            END IF;
                        EXCEPTION
                            WHEN OTHERS THEN
                                IF ( l_istatus != normal ) THEN
                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'p_send_exp_receipt =  '
                                                                        || g_pallet_id
                                                                        || ' Status = '
                                                                        || l_istatus, sqlcode, sqlerrm);

                                ELSE
                                    l_istatus := sqlcode;
                                END IF;
                        END;

                    ELSIF ( g_qty_rec = 0 ) THEN
                        IF ( g_home_slot_flag > 0 ) THEN           /* g_home_slot_flag starts */
                            l_status := update_inv_zero_rcv(c_true);
                        ELSE
                            l_new_float_flag := check_new_float;
                            IF ( l_new_float_flag > 0 ) THEN
                                l_status := delete_inv;
                            ELSE
                                l_status := update_inv_zero_rcv(c_false);
                            END IF;

                            IF ( l_status != normal ) THEN
                                RETURN l_status;
                            END IF;
                        END IF;
                    END IF;
                ELSE
                    l_status := write_transaction('MIS');
                END IF;

            END IF;

        ELSIF ( g_erm_status = 'CLO' ) THEN /* PO is CLOSED */
            l_status := delete_putaway_task;
            l_status := update_put_trans;
            IF ( g_erm_type = 'CM' ) THEN   /* a CM even closed did not have PUT */
                l_istatus := normal;
                BEGIN
                    IF ( pl_ml_common.f_is_induction_loc(g_dest_loc) = 'Y' ) THEN
                        r_exp_rcv.v_expected_receipt_id := g_pallet_id;
                        r_exp_rcv.v_prod_id := g_prod_id;
                        r_exp_rcv.v_cust_pref_vendor := g_cust_pref_vendor;
                        r_exp_rcv.n_uom := g_uom;
                        IF ( g_uom = 0 ) THEN
                            r_exp_rcv.n_uom := 2;
                        END IF;
                        r_exp_rcv.n_qty_expected := g_qty_rec;
                        r_exp_rcv.v_inv_date := TO_DATE(g_inv_exp_date, 'FXDD-MON-YYYY');
                        pl_text_log.ins_msg_async('INFO', l_func_name, '< receipt_id = '
                                                            || r_exp_rcv.v_expected_receipt_id
                                                            || ' prod_id = '
                                                            || r_exp_rcv.v_prod_id
                                                            || ' cpv =  '
                                                            || r_exp_rcv.v_cust_pref_vendor
                                                            || ' uom =  '
                                                            || TO_CHAR(r_exp_rcv.n_uom)
                                                            || ' qty exp =  '
                                                            || TO_CHAR(r_exp_rcv.n_qty_expected)
                                                            || ' inv date = '
                                                            || TO_CHAR(r_exp_rcv.v_inv_date, 'FXDD-MON-YYYY')
                                                            || '>', sqlcode, sqlerrm);

                        pl_miniload_processing.p_send_exp_receipt(r_exp_rcv, l_istatus);
                        IF ( l_istatus = pl_miniload_processing.ct_er_duplicate ) THEN
                            l_istatus := pl_miniload_processing.ct_success;
                        END IF;

                    END IF;

                EXCEPTION
                    WHEN OTHERS THEN
                        IF ( l_istatus != normal ) THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'p_send_exp_receipt =  '
                                                                || g_pallet_id
                                                                || ' Status = '
                                                                || l_istatus, sqlcode, sqlerrm);

                        ELSE
                            l_istatus := sqlcode;
                        END IF;
                END;

            END IF;

        ELSE
            pl_text_log.ins_msg_async('WARN', l_func_name, 'PO is not in OPN or CLO status', sqlcode, sqlerrm);
            l_status := inv_po;
        END IF;   /* PO is OPEN  ENDS*/

        RETURN l_status;
    END putaway;

 /*************************************************************************
** check_putawaylist
**  Description:  Checks the details of the pallet_id in putawaylst
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION check_putawaylist RETURN NUMBER IS

        l_func_name   VARCHAR2(30) := 'check_putawaylist';
        l_status      NUMBER := normal;
        l_put         putawaylst.putaway_put%TYPE;
        l_pik_aisle   loc.pik_aisle%TYPE;
        l_pik_slot    loc.pik_slot%TYPE;
    BEGIN
     pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting check_putawaylist', sqlcode, sqlerrm);
        BEGIN
            SELECT
                dest_loc,
                putaway_put,
                pik_aisle,
                pik_slot
            INTO
                g_dest_loc,
                l_put,
                l_pik_aisle,
                l_pik_slot
            FROM
                putawaylst   p,
                loc          l
            WHERE
                pallet_id = g_pallet_id
                AND logi_loc = p.dest_loc;

        EXCEPTION
            WHEN no_data_found THEN
                BEGIN
                    SELECT
                        dest_loc
                    INTO g_dest_loc
                    FROM
                        putawaylst
                    WHERE
                        pallet_id = g_pallet_id;

                    IF ( g_dest_loc = 'DDDDDD' ) THEN
                        UPDATE putawaylst
                        SET
                            putaway_put = 'Y'
                        WHERE
                            pallet_id = g_pallet_id;

                        IF ( SQL%rowcount = 0 ) THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, ' Update of putaway_put flag failed when pallet id = ' || g_pallet_id, sqlcode, sqlerrm);
                            l_status := putawaylst_update_fail;
                        END IF;

                        l_status := put_done;
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Putaway task already performed for pallet id = ' || g_pallet_id, sqlcode, sqlerrm);
                        RETURN l_status;
                    END IF;

                EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Validation of pallet_id in putawaylst failed when pallet id = ' || g_pallet_id, sqlcode, sqlerrm);
                END;


        END;
        
       IF l_put = 'Y' THEN
           pl_text_log.ins_msg_async('WARN', l_func_name, 'Putaway task already performed for pallet id = ' || g_pallet_id, sqlcode, sqlerrm);
           l_status := put_done;
       ELSIF ( g_dest_loc = '*' ) THEN
           pl_text_log.ins_msg_async('WARN', l_func_name, 'Destination location not yet assigned for pallet id = ' || g_pallet_id,  sqlcode, sqlerrm);
           l_status := wrong_put;
       END IF;
         pl_text_log.ins_msg_async('INFO', l_func_name, 'check_putawaylist status = ' || l_status, sqlcode, sqlerrm);
        RETURN l_status;
    END check_putawaylist;

/*************************************************************************
** get_putaway_info
**  Description:  To get putaway information from putawaylst
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    PROCEDURE get_putaway_info IS

        l_func_name    VARCHAR2(30) := 'get_putaway_info';
        l_status       NUMBER := normal;
        l_weight_ind   putawaylst.catch_wt%TYPE;
        l_jexp_date    putawaylst.exp_date%TYPE;
    BEGIN
        BEGIN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting get_putaway_info ', sqlcode, sqlerrm);
            SELECT
                p.rec_id,
                p.prod_id,
                p.cust_pref_vendor,
                p.uom,
                p.dest_loc,
                p.qty_received,
                p.qty_expected,
                p.exp_date_trk,
                p.date_code,
                p.lot_trk,
                p.temp_trk,
                p.catch_wt,
                p.inv_status,
                TO_CHAR(p.exp_date, 'FXDD-MON-YYYY'),
                TO_CHAR(p.exp_date, 'FXDD-MON-YYYY'),
                TO_CHAR(p.mfg_date, 'FXDD-MON-YYYY'),
                p.temp,
                p.weight,
                p.lot_id,
                p.orig_invoice,
                p.mispick,
                substr(p.lot_id, 1, 9),
                p.seq_no
            INTO
                g_receive_id,
                g_prod_id,
                g_cust_pref_vendor,
                g_uom,
                g_dest_loc,
                g_qty_rec,
                g_qty_exp,
                g_exp_ind,
                g_mfg_ind,
                g_lot_ind,
                g_temp_ind,
                l_weight_ind,
                g_inv_status,
                g_exp_date,
                l_jexp_date,
                g_mfg_date,
                g_temp,
                g_weight,
                g_lot_id,
                g_orig_invoice,
                g_mispick,
                g_order_id,
                g_order_line_id
            FROM
                putawaylst p
            WHERE
                pallet_id = g_pallet_id;
         
        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of putaway task information failed for pallet id = ' || g_pallet_id, sqlcode, sqlerrm);
        END;
    END get_putaway_info;

  /*************************************************************************
** get_product_info
**  Description:  To get product information from pm
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    PROCEDURE get_product_info IS

        l_func_name   VARCHAR2(30) := 'get_product_info';
        l_status      NUMBER := normal;
        l_sysd        VARCHAR2(11);
        l_abc         pm.abc%TYPE;
    BEGIN
        BEGIN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting get_product_info ', sqlcode, sqlerrm);
            SELECT
                nvl(p.case_cube, 1.0),
                nvl(p.spc, 1),
                nvl(p.sysco_shelf_life, 0),
                nvl(p.cust_shelf_life, 0),
                nvl(p.mfr_shelf_life, 0),
                TO_CHAR(SYSDATE, 'FXDD-MON-YYYY'),
                nvl(p.abc, 'A')
            INTO
                g_case_cube,
                g_spc,
                g_sysco_shelf_life,
                g_cust_shelf_life,
                g_mfr_shelf_life,
                l_sysd,
                l_abc
            FROM
                pm p
            WHERE
                prod_id = g_prod_id
                AND cust_pref_vendor = g_cust_pref_vendor;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of product support information for putaway task failed when prod id = ' ||
                g_prod_id || ' and CPV = ' || g_cust_pref_vendor, sqlcode,
                sqlerrm);
        END;
    END get_product_info;

/*************************************************************************
** get_po_info
**  Description:  To get PO information
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    PROCEDURE get_po_info IS

        l_func_name   VARCHAR2(30) := 'get_po_info';
        l_status      NUMBER := normal;
        l_cust_id     erd.cust_id%TYPE;
    BEGIN
        BEGIN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting get_po_info ', sqlcode, sqlerrm);
            SELECT distinct
                e.status,
                e.erm_id,
                e.erm_type,
                d.cust_id
            INTO
                g_erm_status,
                g_erm_id,
                g_erm_type,
                l_cust_id
            FROM
                erm          e,
                erd          d,
                putawaylst   p
            WHERE
                e.erm_id = p.rec_id
                AND e.erm_id = d.erm_id
                AND p.pallet_id = g_pallet_id;
             pl_text_log.ins_msg_async('INFO', l_func_name, ' g_erm_type = ' || g_erm_type, sqlcode, sqlerrm);
            IF  g_erm_status NOT IN ('OPN','CLO') THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' PO not in OPN or CLO status.', sqlcode, sqlerrm);
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of receipt support information for putaway task failed when pallet id = ' || 
                g_pallet_id, sqlcode, sqlerrm);
        END;
    END get_po_info;

/*************************************************************************
** check_home_slot
**  Description:  To check the location is home slot
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION check_home_slot RETURN NUMBER IS

        l_func_name   VARCHAR2(30) := 'check_home_slot';
        l_status      NUMBER := c_true;
        l_dummy       VARCHAR2(1);
    BEGIN
      pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting check_home_slot', sqlcode, sqlerrm);
        BEGIN
            SELECT
                'x'
            INTO l_dummy
            FROM
                loc
            WHERE
                logi_loc = g_dest_loc
                AND perm = 'Y'
                AND rank = 1;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Select of home location from RF failed when logi_loc = ' || g_dest_loc, sqlcode, sqlerrm);
                l_status := c_false;
        END;

        RETURN l_status;
    END check_home_slot;

/*************************************************************************
** confirm_putaway_task
**  Description:  To update the putaway_putfield to Y
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION confirm_putaway_task RETURN NUMBER IS
        l_func_name   VARCHAR2(30) := 'confirm_putaway_task';
        l_status      NUMBER := normal;
    BEGIN
     pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting confirm_putaway_task', sqlcode, sqlerrm);
        UPDATE putawaylst
        SET
            putaway_put = 'Y'
        WHERE
            pallet_id = g_pallet_id;

        IF ( SQL%rowcount = 0 ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, ' Update of putaway_put flag failed.', sqlcode, sqlerrm);
            l_status := putawaylst_update_fail;
        END IF;

        RETURN l_status;
    END confirm_putaway_task;

/*************************************************************************
** write_transaction
**  Description:  Checks the details of the pallet_id in putawaylst
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION write_transaction (
        i_trans_type IN VARCHAR2
    ) RETURN NUMBER IS

        l_func_name        VARCHAR2(30) := 'write_transaction';
        l_status           NUMBER := normal;
        l_trans_type       trans.trans_type%TYPE;
        l_trans_date       VARCHAR2(11);
        l_trans_date_ind   NUMBER := 0;
        l_pallet_id        putawaylst.pallet_id%TYPE;
        l_rec_type         returns.rec_type%TYPE;
        l_reason_code      returns.return_reason_cd%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting write_transaction with trans_type = ' || i_trans_type, sqlcode, sqlerrm);
        l_trans_type := i_trans_type;
        IF g_erm_type = 'CM' THEN
/*
**  Since a return only goes to the home slot and is absorbed,
**  the pallet_id in the transaction will hold the cust_id
**  because the cust_id is needed when sending PUT back to mainframe.
*/
            BEGIN
                SELECT
                    d.cust_id
                INTO l_pallet_id
                FROM
                    erm          e,
                    erd          d,
                    putawaylst   p
                WHERE
                    e.erm_id = p.rec_id
                    AND e.erm_id = d.erm_id
                    AND d.erm_line_id = p.seq_no
                    AND p.pallet_id = g_pallet_id;

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Select of Cust_id failed for pallet id = ' || g_pallet_id, sqlcode, sqlerrm);
            END;

            BEGIN
                SELECT
                    rec_type,
                    return_reason_cd
                INTO
                    l_rec_type,
                    l_reason_code
                FROM
                    returns
                WHERE
                    obligation_no = g_lot_id
                    AND erm_line_id = g_order_line_id;

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to select rec_type from returns for obligation no = ' ||
                    g_lot_id || ' and erm_line_id = ' || g_order_line_id, sqlcode, sqlerrm);
            END;

        ELSE
            l_rec_type := '';
            l_reason_code := '   ';
        END IF;
         IF l_trans_type = 'PUT' THEN
            l_trans_date := '01-JAN-1980';
         ELSE
            l_trans_date_ind := -1;
        END IF;
        
        BEGIN  
        INSERT INTO trans (
            trans_id,
            trans_type,
            prod_id,
            cust_pref_vendor,
            uom,
            order_type,
            rec_id,
            lot_id,
            exp_date,
            weight,
            mfg_date,
            qty_expected,
            temp,
            qty,
            pallet_id,
            new_status,
            reason_code,
            dest_loc,
            trans_date,
            user_id,
            order_id,
            order_line_id,
            upload_time
        ) VALUES (
            trans_id_seq.NEXTVAL,
            l_trans_type,
            g_prod_id,
            g_cust_pref_vendor,
            g_uom,
            l_rec_type,
            g_receive_id,
            g_lot_id,
            TO_CHAR(g_inv_exp_date, 'FXDD-MON-YYYY'),
            g_weight,
            TO_CHAR(g_mfg_date, 'FXDD-MON-YYYY'),
            g_qty_exp,
            g_temp,
            g_qty_rec,
            l_pallet_id,
            g_inv_status,
            l_reason_code,
            g_dest_loc,
            SYSDATE,
            user,
            g_orig_invoice,
            g_order_line_id,
            TO_DATE(l_trans_date, 'FXDD-MON-YYYY')
         );

        EXCEPTION
        WHEN OTHERS THEN
         pl_text_log.ins_msg_async('WARN', l_func_name, ' Unable to create '
                                                || l_trans_type
                                                || ' transaction', sqlcode, sqlerrm);
        END;
     return l_status;     
    END write_transaction;

/*************************************************************************
** update_inv
**  Description:  Checks the details of the pallet_id in putawaylst
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION update_inv (
        i_plogi_loc   IN            VARCHAR2,
        i_logi_loc    IN            VARCHAR2,
        i_flag        IN            NUMBER
    ) RETURN NUMBER IS

        l_func_name   VARCHAR2(30) := 'update_inv';
        l_status      NUMBER := normal;
        l_plogi_loc   inv.plogi_loc%TYPE;
        l_logi_loc    inv.logi_loc%TYPE;
    BEGIN
     pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting update_inv with flag = ' || i_flag || ' plogi_loc = ' || i_plogi_loc ||
     ' and logi_loc = ' || i_logi_loc, sqlcode, sqlerrm);
        l_plogi_loc := i_plogi_loc;
        l_logi_loc := i_logi_loc;
        IF ( i_flag = 0 ) THEN     /* flag = 0 starts */
            IF ( l_logi_loc != ' FFFFFF' ) THEN 
/*Changes to take care of returns to existing locations.
** For existing floating slot assume one pallet in one slot.
*/
                UPDATE inv
                SET
                    qoh = qoh + g_qty_rec,
                    qty_planned = DECODE(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0, 0),
                    cube = cube + ( ( g_qty_rec - g_qty_exp ) / g_spc ) * g_case_cube
                WHERE
                    plogi_loc = l_plogi_loc;

                IF ( SQL%rowcount = 0 ) THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Update of inventory location failed for plogi_loc = ' || l_plogi_loc, sqlcode, sqlerrm);
                    l_status := inv_update_fail;
                    RETURN l_status;
                END IF;

            ELSE
                UPDATE inv
                SET
                    qoh = qoh + g_qty_rec,
                    qty_planned = DECODE(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0, 0),
                    cube = cube + ( ( g_qty_rec - g_qty_exp ) / g_spc ) * g_case_cube
                WHERE
                    plogi_loc = l_plogi_loc
                    AND logi_loc = l_logi_loc;

                IF ( SQL%rowcount = 0 ) THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Update of inventory location failed for plogi_loc = ' || l_plogi_loc, sqlcode, sqlerrm);
                    l_status := inv_update_fail;
                    RETURN l_status;
                END IF;

            END IF;
        ELSE    /* else of flag = 0 starts */
            UPDATE inv
            SET
                qoh = qoh + g_qty_rec,
                qty_planned = DECODE(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0, 0),
                inv_date = SYSDATE,
                rec_date = SYSDATE,
                rec_id = g_receive_id,
                status = g_inv_status,
                cube = cube + ( ( g_qty_rec - g_qty_exp ) / g_spc ) * g_case_cube
            WHERE
                plogi_loc = l_plogi_loc
                AND logi_loc = l_logi_loc;

            IF ( SQL%rowcount = 0 ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Update of inventory location failed for plogi_loc = ' || l_plogi_loc, sqlcode, sqlerrm);
                l_status := inv_update_fail;
                RETURN l_status;
            END IF;

        END IF;   /* flag = 0 ends */

        IF ( i_flag <> 0 ) THEN
            l_status := data_collect_check(l_plogi_loc, l_logi_loc);
             pl_text_log.ins_msg_async('WARN', l_func_name, l_status, sqlcode, sqlerrm);
            RETURN l_status;
        END IF;
      RETURN l_status;
    END update_inv;

/*************************************************************************
** update_inv
**  Description:  Checks the details of the pallet_id in putawaylst
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION update_inv_zero_rcv (
        i_flag IN NUMBER
    ) RETURN NUMBER IS
        l_func_name   VARCHAR2(30) := 'update_inv_zero_rcv';
        l_status      NUMBER := normal;
    BEGIN
    pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting update_inv_zero_rcv with flag = ' || i_flag, sqlcode, sqlerrm);
        IF ( i_flag <> 0 ) THEN
            UPDATE inv
            SET
                qty_planned = DECODE(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0, 0),
                cube = cube - ( g_qty_exp / g_spc ) * g_case_cube
            WHERE
                plogi_loc = g_dest_loc
                AND logi_loc = g_dest_loc;

        ELSE
            UPDATE inv
            SET
                qty_planned = DECODE(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0, 0)
            WHERE
                plogi_loc = g_dest_loc
                AND logi_loc = g_logi_loc;

        END IF;

        IF ( SQL%rowcount = 0 ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, ' Unable to update home location when plogi_loc = ' || g_dest_loc ||
            ' and logi_loc = ' || g_logi_loc , sqlcode, sqlerrm);
            l_status := inv_update_fail;
        END IF;

        RETURN l_status;
    END update_inv_zero_rcv;

/*************************************************************************
** delete_inv
**  Description:  Deletes the reserve location in  inv table
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION delete_inv RETURN NUMBER IS
        l_func_name   VARCHAR2(30) := 'delete_inv';
        l_status      NUMBER := normal;
    BEGIN
      pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting delete_inv', sqlcode, sqlerrm);
        DELETE FROM inv
        WHERE
            logi_loc = g_pallet_id
            AND plogi_loc = g_dest_loc;

        IF ( SQL%rowcount = 0 ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, ' Unable to delete reserve location for logi_loc = ' || g_pallet_id ||
            ' and plogi_loc = ' || g_dest_loc, sqlcode, sqlerrm);
            l_status := del_inv_fail;
        END IF;

        RETURN l_status;
    END delete_inv;

/*************************************************************************
** data_collect_check
**  Description:  to collect data in inv table
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION data_collect_check (
        i_plogi_loc   IN            VARCHAR2,
        i_logi_loc    IN            VARCHAR2
    ) RETURN NUMBER IS

        l_func_name   VARCHAR2(30) := 'data_collect_check';
        l_status      NUMBER := normal;
        l_plogi_loc   inv.plogi_loc%TYPE;
        l_logi_loc    inv.logi_loc%TYPE;
    BEGIN
    pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting data_collect_check with plogi_loc = ' || i_plogi_loc ||
    ' and i_logi_loc = '|| i_logi_loc, sqlcode, sqlerrm);
        l_plogi_loc := i_plogi_loc;
        l_logi_loc := i_logi_loc;
        IF ( g_mfg_ind = 'C' ) THEN
    /* g_mfg_ind  'C' starts */
            l_status := pop_date(g_home_slot_flag);
            UPDATE inv
            SET
                mfg_date = TO_DATE(g_mfg_date, 'FXDD-MON-YYYY'),
                exp_date = TO_DATE(g_inv_exp_date, 'FXDD-MON-YYYY')
            WHERE
                plogi_loc = l_plogi_loc
                AND logi_loc = l_logi_loc;

            IF ( SQL%rowcount = 0 ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' Update of mfg_date for inventory location failed when  plogi_loc = ' || i_plogi_loc ||
                ' and i_logi_loc = '|| i_logi_loc, sqlcode, sqlerrm);
                l_status := inv_update_fail;
            END IF;

            RETURN l_status;
        END IF; /* g_mfg_ind  'C' Ends */

        IF ( g_temp_ind = 'C' ) THEN     /* temp_ind  'C' starts */
            UPDATE inv
            SET
                temperature = g_temp
            WHERE
                plogi_loc = l_plogi_loc
                AND logi_loc = l_logi_loc;

            IF ( SQL%rowcount = 0 ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' Update of temperature for inventory location failed when  plogi_loc = ' || i_plogi_loc ||
                ' and i_logi_loc = '|| i_logi_loc, sqlcode, sqlerrm);
                l_status := inv_update_fail;
            END IF;

            RETURN l_status;
        END IF;   /* temp_ind  'C' Ends */

        IF ( g_lot_ind = 'C' ) THEN      /* lot_ind  'C' starts */
            UPDATE inv
            SET
                lot_id = g_lot_id
            WHERE
                plogi_loc = l_plogi_loc
                AND logi_loc = l_logi_loc;

            IF ( SQL%rowcount = 0 ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' Update of lot_id for inventory location failed when plogi_loc = ' || i_plogi_loc ||
               ' and i_logi_loc = '|| i_logi_loc, sqlcode, sqlerrm);
                l_status := inv_update_fail;
            END IF;

            RETURN l_status;
        END IF;   /* lot_ind  'C' Ends */

        UPDATE inv
        SET
            exp_ind = 'Y'
        WHERE
            plogi_loc = l_plogi_loc
            AND logi_loc = l_logi_loc;

        IF ( SQL%rowcount = 0 ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, ' Update exp_ind to Y for inventory location failed  plogi_loc = ' || i_plogi_loc ||
            ' and i_logi_loc = '|| i_logi_loc, sqlcode, sqlerrm);
            l_status := inv_update_fail;
            RETURN l_status;
        END IF;

        IF ( g_exp_ind = 'C' ) THEN     /* exp_ind  'C' starts */
            UPDATE inv
            SET
                exp_date = TO_DATE(g_exp_date, 'FXDD-MON-YYYY')
            WHERE
                plogi_loc = l_plogi_loc
                AND logi_loc = l_logi_loc;

            IF ( SQL%rowcount = 0 ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' Update exp_date for inventory location failed  plogi_loc = ' || i_plogi_loc ||
                ' and i_logi_loc = '|| i_logi_loc, sqlcode, sqlerrm);
                l_status := inv_update_fail;
            END IF;

            RETURN l_status;
        END IF;  /* exp_ind  'C' Ends */
      RETURN l_status;
    END data_collect_check;

/*************************************************************************
** pop_date
**  Description:  to set dates in putawaylst for fields related to dates
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION pop_date (
        i_hsf IN NUMBER
    ) RETURN NUMBER IS

        l_func_name      VARCHAR2(30) := 'pop_date';
        l_status         NUMBER := normal;
        l_pop_date_loc   putawaylst.pallet_id%TYPE;
    BEGIN
      pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting pop_date with hsf = ' || i_hsf, sqlcode, sqlerrm);
        l_pop_date_loc := g_pallet_id;
        IF ( g_sysco_shelf_life != 0 AND g_cust_shelf_life != 0 ) THEN
            SELECT
                TO_CHAR(SYSDATE + g_sysco_shelf_life + g_cust_shelf_life, 'DD-MON-YYYY')
            INTO g_inv_exp_date
            FROM
                dual;
            UPDATE putawaylst
            SET
                exp_date = TO_DATE(g_inv_exp_date, 'FXDD-MON-YYYY')
            WHERE
                dest_loc = g_dest_loc
                AND pallet_id = l_pop_date_loc;
                

            IF ( SQL%rowcount = 0 ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Set exp_date to sysdate+cust_shelf_life+sysco_shelf_life failed when dest_loc = ' ||
                g_dest_loc || ' and pallet_id = ' || l_pop_date_loc , sqlcode, sqlerrm );
                l_status := putawaylst_update_fail;
                RETURN l_status;
            END IF;

        ELSIF ( g_mfr_shelf_life != 0 ) THEN
            SELECT
                TO_CHAR(SYSDATE + g_mfr_shelf_life, 'FXDD-MON-YYYY')
            INTO g_inv_exp_date
            FROM
                dual;

            UPDATE putawaylst
            SET
                exp_date = TO_DATE(g_inv_exp_date, 'FXDD-MON-YYYY')
            WHERE
                dest_loc = g_dest_loc
                AND pallet_id = l_pop_date_loc;

            IF ( SQL%rowcount = 0 ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Set exp_date to sysdate+mfr_shelf_life failed when dest_loc = ' ||
                g_dest_loc || ' and pallet_id = ' || l_pop_date_loc , sqlcode, sqlerrm);
                l_status := putawaylst_update_fail;
                RETURN l_status;
            END IF;

        ELSE
            SELECT
                TO_CHAR(SYSDATE, 'FXDD-MON-YYYY')
            INTO g_inv_exp_date
            FROM
                dual;

            UPDATE putawaylst
            SET
                exp_date = SYSDATE
            WHERE
                dest_loc = g_dest_loc
                AND pallet_id = l_pop_date_loc;

            IF ( SQL%rowcount = 0 ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Set exp_date to sysdate failed when dest_loc = ' ||
                g_dest_loc || ' and pallet_id = ' || l_pop_date_loc , sqlcode, sqlerrm);
                l_status := putawaylst_update_fail;
                RETURN l_status;
            END IF;

        END IF;
         RETURN l_status;
    END pop_date;

/*************************************************************************
** update_put_trans
**  Description:  to update put transaction in trans
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION update_put_trans RETURN NUMBER IS
        l_func_name   VARCHAR2(30) := 'update_put_trans';
        l_status      NUMBER := normal;
    BEGIN
      pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting update_put_trans', sqlcode, sqlerrm);
        UPDATE trans
        SET
            user_id = user,
            trans_date = SYSDATE
        WHERE
            rec_id = g_erm_id
            AND trans_type = 'PUT'
            AND pallet_id = g_pallet_id;

        IF ( SQL%rowcount = 0 ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to update user_id for PUT transaction when rec_id = ' || g_erm_id ||
            ' and pallet_id = ' || g_pallet_id, sqlcode, sqlerrm);
            l_status := putawaylst_update_fail;
            RETURN l_status;
        END IF;
       RETURN l_status;
    END update_put_trans;

/*************************************************************************
** update_put_trans
**  Description:  to set dates in putawaylst for fields related to dates
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION check_po_status RETURN NUMBER IS

        l_func_name   VARCHAR2(30) := 'check_po_status';
        l_status      NUMBER := normal;
        l_dummy       VARCHAR2(1);
    BEGIN
     pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting check_po_status', sqlcode, sqlerrm);
        BEGIN
            SELECT
                'x'
            INTO l_dummy
            FROM
                erm
            WHERE
                erm_id = g_erm_id
                AND status = 'OPN'
            FOR UPDATE OF status NOWAIT;

            l_status := normal;
        EXCEPTION
            WHEN no_data_found THEN
                BEGIN
                    SELECT
                        'x'
                    INTO l_dummy
                    FROM
                        erm
                    WHERE
                        erm_id = g_erm_id
                        AND status = 'CLO'
                    FOR UPDATE OF status NOWAIT;

                    l_status := normal;
                EXCEPTION
                    WHEN no_data_found THEN
                        l_status := unavl_po;
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to select PO = '
                                                            || g_erm_id
                                                            || ' for CLO status', sqlcode, sqlerrm);

                END;
            WHEN row_locked THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to update user_id for PUT transaction.', sqlcode, sqlerrm);
                l_status := lock_po;
        END;

        RETURN l_status;
    END check_po_status;

/*************************************************************************
** delete_putaway_task
**  Description:  deletes putaway data from putawaylst
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION delete_putaway_task RETURN NUMBER IS
        l_func_name   VARCHAR2(30) := 'delete_putaway_task';
        l_status      NUMBER := normal;
    BEGIN
    pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting delete_putaway_task', sqlcode, sqlerrm);
        DELETE FROM putawaylst
        WHERE
            pallet_id = g_pallet_id;

        IF ( SQL%rowcount = 0 ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Deletion of putaway task for closed PO failed.', sqlcode, sqlerrm);
            l_status := del_putawylst_fail;
        END IF;

        RETURN l_status;
    END delete_putaway_task;

/*************************************************************************
** check_new_float
**  Description:  selects floating slot from zone,lzone and inv
**  Called By : putaway
**  PARAMETERS :
**
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/

    FUNCTION check_new_float RETURN NUMBER IS
        l_func_name   VARCHAR2(30) := 'check_new_float';
        l_status      NUMBER := c_true;
    BEGIN
      pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting check_new_float', sqlcode, sqlerrm);
        BEGIN
            SELECT
                inv.logi_loc
            INTO g_logi_loc
            FROM
                lzone,
                zone,
                inv
            WHERE
                inv.plogi_loc = g_dest_loc
                AND inv.logi_loc = g_pallet_id
                AND lzone.logi_loc = inv.plogi_loc
                AND lzone.zone_id = zone.zone_id
                AND zone.zone_type = 'PUT'
                AND zone.rule_id = 1;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Select of floating slot for returns  failed.', sqlcode, sqlerrm);
                l_status := c_false;
        END;

        RETURN l_status;
    END check_new_float;

END pl_confirm_putaway;
/

GRANT Execute on pl_confirm_putaway to swms_user;
