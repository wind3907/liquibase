create or replace PACKAGE pl_receive_return AS
/*******************************************************************************
**Package:
**        pl_receive_return. Migrated from receive_ret.pc
**
**Description:
**        Opens Credit Memos downloaded by POREADER.
**
**Called by:
**        This is called from Forms/UI
*******************************************************************************/
    PROCEDURE p_execute_frm (
        i_user_id   IN   VARCHAR2,
        i_params   IN   VARCHAR2,
        o_result   OUT  VARCHAR2
    );

    PROCEDURE receive_return_main (
        i_erm_id   IN erm.erm_id%TYPE,
        o_status   OUT VARCHAR2
    );

    FUNCTION process_ret RETURN NUMBER;

END pl_receive_return;
/

create or replace PACKAGE BODY pl_receive_return IS
  ---------------------------------------------------------------------------
  -- pl_receive_return:
  --    Called from Oracle Forms for returns
  --  
  -- Description:
  --- Based on the erm id passed receive returns will be performed
  ---------------------------------------------------------------------------

    normal          NUMBER := 0;
    c_true          CONSTANT NUMBER := 1;
    c_false         CONSTANT NUMBER := 0;
    c_found_false   CONSTANT NUMBER := 0;
    c_found_true    CONSTANT NUMBER := 1;
    g_cpv           pm.cust_pref_vendor%TYPE := '-';   /* since Null cannot be inserted setting it to '-' */
    g_erm_id        erm.erm_id%TYPE;

/*************************************************************************
** p_execute_frm
**  Description: Main Program to be called from the PL/SQL wrapper/Forms
**  Called By : DBMS_HOST_COMMAND_FUNC
**  PARAMETERS:
**      i_user_id - User id passed from Frontend
**      i_params - Function parameters passed from Frontend as Input
**      o_status   - Output parameter returned to front end
**  RETURN VALUES:
**      Success or Failure message will be sent
**
****************************************************************/
   PROCEDURE p_execute_frm (
      i_user_id   IN VARCHAR2,
      i_params   IN VARCHAR2,
      o_result   OUT VARCHAR2
  ) IS
      l_func_name   VARCHAR2(50)    := 'pl_receive_return.p_execute_frm';
      i_erm_id   erm.erm_id%TYPE := trim(i_params);
  BEGIN
      pl_text_log.ins_msg_async('INFO', l_func_name, 'Invoking receive_return_main', sqlcode, sqlerrm);
      receive_return_main(i_erm_id,o_result) ;
  END p_execute_frm;

  /*************************************************************************
  ** receive_return_main
  **  Description: Main Program to be called from the API rapper/Forms
  **  Called By : pl_receive_return
  **  PARAMETERS:
  **      i_erm_id - ERM# passed from Frontend as Input
  **      o_out_status   - Output parameter returned to front end
  **  RETURN VALUES:
  **      Success or Failure message will be sent
  **
  ****************************************************************/
    PROCEDURE receive_return_main (
        i_erm_id   IN erm.erm_id%TYPE,
        o_status   OUT VARCHAR2
    ) IS
        l_func_name   VARCHAR2(30) := 'receive_return_main';
        l_status      NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Receive return', sqlcode, sqlerrm);
        g_erm_id := i_erm_id;
        l_status := process_ret;
        IF ( l_status = c_true ) THEN
            COMMIT;
        ELSE
            ROLLBACK;
        END IF;
        o_status := l_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Processing Receive return Failed', sqlcode, sqlerrm);
            RAISE;
    END receive_return_main;

  /*************************************************************************
  ** process_ret
  **  Description: Processing the returns
  **  Called By : process_ret
  **  PARAMETERS:
  **  RETURN VALUES:
  **      Success or Failure message will be sent
  **
  ****************************************************************/

    FUNCTION process_ret RETURN NUMBER IS

        l_func_name        VARCHAR2(30) := 'process_ret';
        l_status           NUMBER := normal;
        i                  NUMBER;
        x                  NUMBER;
        l_new_float_flag   NUMBER;
        l_saleable         erd.saleable%TYPE;
        l_qty              putawaylst.qty%TYPE;
        l_uom              putawaylst.uom%TYPE;
        l_mispick          putawaylst.mispick%TYPE;
        l_prod_id          putawaylst.rec_id%TYPE;
        l_zone_id          zone.zone_id%TYPE;
        l_skid_cube        pallet_type.skid_cube%TYPE;
        l_weight           putawaylst.weight%TYPE;
        l_case_cube        pm.case_cube%TYPE;
        l_dest_loc         putawaylst.dest_loc%TYPE;
        l_abc              pm.abc%TYPE;
        l_logi_loc         inv.logi_loc%TYPE;
        l_pallet_id        putawaylst.pallet_id%TYPE;
        l_order_id         putawaylst.lot_id%TYPE;
        l_erm_status       erm.status%TYPE;
        l_pallet_type      pm.pallet_type%TYPE;
        l_erm_line_id      erd.erm_line_id%TYPE;
        l_found_float      NUMBER := c_false;
        l_erm_id           erd.erm_id%TYPE;
        CURSOR c_line_item IS SELECT
                                  nvl(saleable,'N') saleable,
                                  mispick,
                                  prod_id,
                                  uom,
                                  qty,
                                  nvl(weight,0) weight,
                                  erm_line_id,
                                  order_id
                              FROM
                                  erd
                              WHERE
                                  erm_id = g_erm_id
                              ORDER BY
                                  erm_line_id;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'putaway starts ', sqlcode, sqlerrm);

      /*
      **  This was move to top of this function, instead of the end, 
      **  to facilitate use of record locking.
      */
        BEGIN
            SELECT
                status
            INTO l_erm_status
            FROM
                erm
            WHERE
                erm_id = g_erm_id
            FOR UPDATE OF status;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Select status of ERM failed.', sqlcode, sqlerrm);
        END;

        IF ( l_erm_status = 'OPN' ) THEN
            RETURN c_false;
        END IF;
        SELECT
            COUNT(*)
        INTO x
        FROM
            putawaylst
        WHERE
            rec_id = g_erm_id;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'putawaylst count = ' || x, sqlcode, sqlerrm);
        IF ( x != 0 ) THEN
            RETURN c_false;
        END IF;

      /*
      **  Order Id is very important for returns for accounting reasons.
      */
        FOR rec IN c_line_item LOOP
            l_saleable := rec.saleable;
            l_mispick := rec.mispick;
            l_prod_id := rec.prod_id;
            l_uom := rec.uom;
            l_qty := rec.qty;
            l_weight := rec.weight;
            l_erm_line_id := rec.erm_line_id;
            l_order_id := rec.order_id;
            SELECT
                TO_CHAR(pallet_id_seq.NEXTVAL)
            INTO l_pallet_id
            FROM
                dual;

            IF ( l_saleable = 'N' ) THEN
            /*
            **  BE AWARE:  order_id is being loaded into lot_id.
            */
                BEGIN
                    INSERT INTO putawaylst (
                        rec_id,
                        prod_id,
                        dest_loc,
                        qty,
                        uom,
                        status,
                        inv_status,
                        pallet_id,
                        qty_expected,
                        qty_received,
                        equip_id,
                        rec_lane_id,
                        seq_no,
                        putaway_put,
                        lot_id,
                        cust_pref_vendor
                    ) VALUES (
                        g_erm_id,
                        l_prod_id,
                        'DDDDDD',
                        l_qty,
                        l_uom,
                        ' ',
                        ' ',
                        l_pallet_id,
                        l_qty,
                        l_qty,
                        ' ',
                        ' ',
                        l_erm_line_id,
                        'N',
                        l_order_id,
                        g_cpv
                    );

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Insert of Damaged pallet failed.', sqlcode, sqlerrm);
                        RETURN c_false;
                END;
            ELSIF ( l_saleable = 'Y' ) THEN
            /*
            ** Look for a home slot for the item
            */
                BEGIN
                    SELECT
                        logi_loc
                    INTO l_dest_loc
                    FROM
                        loc
                    WHERE
                        prod_id = l_prod_id
                        AND perm = 'Y'
                        AND rank = 1;

                    l_logi_loc := l_dest_loc;
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Location = ' || l_logi_loc, sqlcode, sqlerrm);

                /*
                **  BE AWARE:  order_id is being loaded into lot_id.
                */
                    BEGIN
                        INSERT INTO putawaylst (
                            rec_id,
                            prod_id,
                            dest_loc,
                            qty,
                            uom,
                            status,
                            inv_status,
                            pallet_id,
                            qty_expected,
                            qty_received,
                            equip_id,
                            rec_lane_id,
                            seq_no,
                            putaway_put,
                            weight,
                            mispick,
                            lot_id,
                            cust_pref_vendor
                        ) VALUES (
                            g_erm_id,
                            l_prod_id,
                            l_dest_loc,
                            l_qty,
                            l_uom,
                            'NEW',
                            'AVL',
                            l_pallet_id,
                            l_qty,
                            l_qty,
                            ' ',
                            ' ',
                            l_erm_line_id,
                            'N',
                            l_weight,
                            l_mispick,
                            l_order_id,
                            g_cpv
                        );

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Insert of saleable pallet failed.', sqlcode, sqlerrm);
                            RETURN c_false;
                    END;

                EXCEPTION
                    WHEN no_data_found THEN
                  /*
                  ** Look for a reserve location with item in it
                  */
                        BEGIN
                            SELECT
                                plogi_loc,
                                logi_loc
                            INTO
                                l_dest_loc,
                                l_logi_loc
                            FROM
                                inv i
                            WHERE
                                i.prod_id = l_prod_id
                            ORDER BY
                                i.exp_date,
                                i.qoh;

                        EXCEPTION
                            WHEN no_data_found THEN
                        /*** no inventory record exists for item
                        ** 
                        ** since no home slot found and no inventory record 
                        ** exists, check if the item's put zone is a floating zone
                        ** MIGHT NOT NEED PALLET_TYPE BELOW IF NO PALLET-TYPE CHECK
                        ***/
                                BEGIN
                                    SELECT
                                        p.zone_id,
                                        p.case_cube,
                                        p.abc,
                                        p.pallet_type,
                                        pa.skid_cube
                                    INTO
                                        l_zone_id,
                                        l_case_cube,
                                        l_abc,
                                        l_pallet_type,
                                        l_skid_cube
                                    FROM
                                        pallet_type pa,
                                        zone z,
                                        pm p
                                    WHERE
                                        p.prod_id = l_prod_id
                                        AND p.zone_id = z.zone_id
                                        AND z.zone_type = 'PUT'
                                        AND z.rule_id = 1
                                        AND p.pallet_type = pa.pallet_type;

                                    pl_text_log.ins_msg_async('INFO', l_func_name, 'PUT zone for prode id =  '
                                                                        || l_prod_id
                                                                        || 'is '
                                                                        || l_zone_id, sqlcode, sqlerrm);

                            /* 
                            ** since the PUT zone is a floating zone,
                            ** find the first available slot,
                            ** in a floating, PUT zone and send item there.
                            ** Floating zones use rule_id = 1 in putaway
                            */

                                    SELECT
                                        l.logi_loc,
                                        l.logi_loc
                                    INTO
                                        l_dest_loc,
                                        l_logi_loc
                                    FROM
                                        loc l,
                                        lzone lz
                                    WHERE
                                        lz.zone_id = l_zone_id
                                        AND lz.logi_loc = l.logi_loc
                                        AND l.status = 'AVL'
                                        AND l.pallet_type = l_pallet_type
                                        AND NOT EXISTS (
                                            SELECT
                                                'x'
                                            FROM
                                                inv
                                            WHERE
                                                inv.plogi_loc = l.logi_loc
                                        )
                                        AND ROWNUM = 1;

                                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Selection of floating slot for  prod_id = '
                                                                        || l_prod_id
                                                                        || 'is '
                                                                        || l_zone_id, sqlcode, sqlerrm);

                                    pl_text_log.ins_msg_async('INFO', l_func_name, 'NON home_slot (floating) plogi_loc = '
                                                                        || l_dest_loc
                                                                        || 'logi_loc =  '
                                                                        || l_logi_loc, sqlcode, sqlerrm);

                                    l_found_float := c_found_true;
                                    BEGIN
                                        INSERT INTO putawaylst (
                                            rec_id,
                                            prod_id,
                                            dest_loc,
                                            qty,
                                            uom,
                                            status,
                                            inv_status,
                                            pallet_id,
                                            qty_expected,
                                            qty_received,
                                            equip_id,
                                            rec_lane_id,
                                            seq_no,
                                            putaway_put,
                                            weight,
                                            mispick,
                                            lot_id,
                                            cust_pref_vendor
                                        ) VALUES (
                                            l_erm_id,
                                            l_prod_id,
                                            l_dest_loc,
                                            l_qty,
                                            l_uom,
                                            'NEW',
                                            'AVL',
                                            l_pallet_id,
                                            l_qty,
                                            l_qty,
                                            ' ',
                                            ' ',
                                            l_erm_line_id,
                                            'N',
                                            l_weight,
                                            l_mispick,
                                            l_order_id,
                                            g_cpv
                                        );

                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            pl_text_log.ins_msg_async('WARN', l_func_name,
                                             'Insert of pallet w/o home and inventory w/ floating slot failed.', sqlcode,
                                              sqlerrm);
                                            RETURN c_false;
                                    END;

                                EXCEPTION
                                    WHEN no_data_found THEN
                  /* 
                  ** Here if 
                  ** 1. No floating PUT zone found for the item
                  ** OR
                  ** 2. No OPEN slot found in the FLOATING zone for the item
                  **
                  **  BE AWARE:  order_id is being loaded into lot_id.
                  */
                                        pl_text_log.ins_msg_async('WARN', l_func_name, 'No location was found for floating zone. ',
                                        sqlcode, sqlerrm);
                                        
                                        BEGIN
                                            INSERT INTO putawaylst (
                                                rec_id,
                                                prod_id,
                                                dest_loc,
                                                qty,
                                                uom,
                                                status,
                                                inv_status,
                                                pallet_id,
                                                qty_expected,
                                                qty_received,
                                                equip_id,
                                                rec_lane_id,
                                                seq_no,
                                                putaway_put,
                                                weight,
                                                mispick,
                                                lot_id,
                                                cust_pref_vendor
                                            ) VALUES (
                                                l_erm_id,
                                                l_prod_id,
                                                '*         ',
                                                l_qty,
                                                l_uom,
                                                'NEW',
                                                'AVL',
                                                l_pallet_id,
                                                l_qty,
                                                l_qty,
                                                ' ',
                                                ' ',
                                                l_erm_line_id,
                                                'N',
                                                l_weight,
                                                l_mispick,
                                                l_order_id,
                                                g_cpv
                                            );

                                        EXCEPTION
                                            WHEN OTHERS THEN
                                                pl_text_log.ins_msg_async('WARN', l_func_name, 
                                                ' Insert of pallet w/o home and inventory w/ floating slot failed.', sqlcode,
                                                 sqlerrm);
                                                RETURN c_false;
                                        END;

                                END;
            /*end of when no data found for selection of floating location */

                                IF ( l_mispick = 'Y' ) THEN /* mispick starts */
                                    IF l_found_float = c_true THEN
                                        l_found_float := c_false;

                /*
                ** insert inventory record for the floating slot 
                ** with 0 qoh, 0 qty_planned, 0 qty_alloc
                */
                                        BEGIN
                                            INSERT INTO inv (
                                                plogi_loc,
                                                logi_loc,
                                                prod_id,
                                                rec_id,
                                                qty_planned,
                                                qoh,
                                                qty_alloc,
                                                min_qty,
                                                inv_date,
                                                rec_date,
                                                abc,
                                                status,
                                                cube,
                                                abc_gen_date
                                            ) VALUES (
                                                l_dest_loc,
                                                l_pallet_id,
                                                l_prod_id,
                                                l_erm_id,
                                                0,
                                                0,
                                                0,
                                                0,
                                                SYSDATE,
                                                SYSDATE,
                                                l_abc,
                                                'AVL',
                                                l_qty * l_case_cube + l_skid_cube,
                                                SYSDATE
                                            );

                                        EXCEPTION
                                            WHEN OTHERS THEN
                                                pl_text_log.ins_msg_async('WARN', l_func_name, 
                                                'Insert of float inv record for item w/o home, w/o reserve failed.', sqlcode,
                                                 sqlerrm);
                                                RETURN c_false;
                                        END;

                                        BEGIN
                                            UPDATE inv
                                            SET
                                                qty_planned = qty_planned + l_qty
                                            WHERE
                                                plogi_loc = l_dest_loc
                                                AND logi_loc = l_pallet_id;

                                        EXCEPTION
                                            WHEN OTHERS THEN
                                                pl_text_log.ins_msg_async('WARN', l_func_name, 'Update of inv  failed.', sqlcode, sqlerrm);
                                                RETURN c_false;
                                        END;

                                    END IF;

                                ELSE /* mispick else */
                                    BEGIN
                                        UPDATE inv
                                        SET
                                            qty_planned = qty_planned + l_qty
                                        WHERE
                                            plogi_loc = l_dest_loc
                                            AND logi_loc = l_logi_loc;

                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            pl_text_log.ins_msg_async('WARN', l_func_name,' Update of inv failed.', sqlcode, sqlerrm);
                                            RETURN c_false;
                                    END;
                                END IF;

                        END;
                END;
            END IF;

            BEGIN
                UPDATE erm
                SET
                    status = 'OPN'
                WHERE
                    erm_id = g_erm_id;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Update of Erm status failed.', sqlcode, sqlerrm);
            END;

            BEGIN
                INSERT INTO trans (
                    trans_id,
                    trans_type,
                    rec_id,
                    trans_date,
                    user_id
                ) VALUES (
                    trans_id_seq.NEXTVAL,
                    'ROP',
                    g_erm_id,
                    SYSDATE,
                    user
                );

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Insert of trans failed.', sqlcode, sqlerrm);
            END;

        END LOOP;

        RETURN c_true;
    END process_ret;

END pl_receive_return;
/

grant execute on pl_receive_return to swms_user;
