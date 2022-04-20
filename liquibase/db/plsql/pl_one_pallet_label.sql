create or replace PACKAGE     pl_one_pallet_label                               
AS
PROCEDURE p_all_pallet_label(l_status OUT NUMBER);
PROCEDURE p_one_pallet_label(p_po IN VARCHAR2,l_status OUT NUMBER);
PROCEDURE p_retrieve_label_content;
PROCEDURE p_clear_array;
PROCEDURE p_insert_table( p_dest_loc IN VARCHAR2,  home IN number);
PROCEDURE p_split_find_putaway_slot;
PROCEDURE p_get_num_next_zones (p_area IN VARCHAR2);
PROCEDURE p_split_putaway;
FUNCTION f_deep_slot_assign_loop ( p_same_diff_prod_flag NUMBER) RETURN NUMBER;
FUNCTION f_split_hi_rise_open_assign RETURN NUMBER;
FUNCTION f_two_d_three_d_open_slot RETURN VARCHAR2;
FUNCTION f_two_d_three_d (p_dest_loc VARCHAR2) RETURN NUMBER;
FUNCTION f_bulk_avail_slot_same_prod RETURN NUMBER;
FUNCTION f_bulk_open_slot_assign_loop RETURN NUMBER;
FUNCTION f_bulk_open_slot_assign RETURN NUMBER;
FUNCTION f_retrieve_aging_item RETURN NUMBER;
FUNCTION f_is_tti_tracked_item RETURN NUMBER;
FUNCTION f_is_clam_bed_tracked_item(category IN VARCHAR2) RETURN NUMBER;
FUNCTION f_split_hi_rise_rule RETURN NUMBER;
FUNCTION f_split_check_float_item(days IN NUMBER) RETURN VARCHAR2;
FUNCTION f_bulk_avail_slot_assign RETURN NUMBER;
FUNCTION f_avail_slot_assign_loop RETURN VARCHAR2;
FUNCTION f_assign_msku_putaway_slots (c_sn_no VARCHAR2 ) RETURN NUMBER;
FUNCTION f_locator_rule RETURN VARCHAR2;
FUNCTION f_general_rule(flag IN VARCHAR2) RETURN VARCHAR2;
FUNCTION f_check_avail_slot_same_prod RETURN VARCHAR2 ;
FUNCTION f_avail_slot_assign_loop (flag NUMBER) RETURN VARCHAR2;
FUNCTION f_hi_rise_open_assign RETURN NUMBER;
FUNCTION f_check_home_item (days NUMBER) RETURN VARCHAR2;
FUNCTION f_check_home_slot( p_dest_loc VARCHAR2, p_home_loc_cube NUMBER) RETURN VARCHAR2;
FUNCTION f_hi_rise_rule RETURN NUMBER;
FUNCTION f_bulk_rule ( i_zone_id  VARCHAR2, i_prod_id VARCHAR2, i_cpv VARCHAR2) RETURN NUMBER;
PROCEDURE p_po_reprocessing(p_po IN VARCHAR2, p_prod_id IN VARCHAR2, p_putaway_dimension IN VARCHAR2, 
                            p_ca_dmg_status IN VARCHAR2, l_status OUT NUMBER);

PROCEDURE p_reprocess_po(i_uom NUMBER,i_ca_dmg_status VARCHAR2,l_pallet_flag VARCHAR2,i_rec_id VARCHAR2,
                          i_prod_id VARCHAR2, i_cpv VARCHAR2, i_qty_rec NUMBER, i_pallet_type VARCHAR2, 
                          i_putaway_dimension VARCHAR2);
 
FUNCTION f_find_putaway_slot (p_prod_id IN pm.zone_id%TYPE, p_cpv IN pm.cust_pref_vendor%TYPE) RETURN NUMBER;   
                          
END pl_one_pallet_label;
/

create or replace PACKAGE BODY    pl_one_pallet_label AS 

  /************************************************************************ 
  ** 
  **    File: pallet_label2.pc converted to pl_one_pallet_label 
  ** 
  **    Description: Create putawaylst tasks while opening a receipt using 
  **                 Method2 putaway method. 
  **    Called By : pl_rcv_po_open 
  **    Function reprocess and find_damage_zone_location will be handled 
  **         in another story card - 506 
  ****************************************************************/

    ADD_RESERVE          CONSTANT NUMBER := 0;
    C_FALSE              CONSTANT NUMBER := 0;
    C_TRUE               CONSTANT NUMBER := 1;
    ADD_HOME             CONSTANT NUMBER := 1;
    ADD_NO_INV           CONSTANT NUMBER := 2;
    aging_days                     INTEGER;
    split_dest_loc                 VARCHAR2(20);
    total_qty                      NUMBER(15);
    g_prod_id                      VARCHAR2(10);
    g_cpv                          VARCHAR2(10);
    brand                          VARCHAR2(7);
    l_cust_pref_vendor             VARCHAR2(10);
    mfg                            VARCHAR2(14);
    pm_category                    VARCHAR2(15);
    g_c_cool_trk                   VARCHAR2(2);
    g_erm_num                      VARCHAR2(12);
    l_zone_id                      VARCHAR2(7);
    seq_no                         NUMBER(5);
    temp_trk                       VARCHAR2(2);
    g_clam_bed_tracked_flag        VARCHAR(1);
    pallet_cube                    NUMBER(12, 4);
    l_pallet_type                  VARCHAR2(5);
    phys_loc                       VARCHAR2(10);
    loc_cube                       NUMBER(12, 4);
    put_aisle2                     VARCHAR2(10);
    put_slot2                      VARCHAR2(10);
    put_level2                     VARCHAR2(10);
    put_path2                      VARCHAR2(10);
    loc_deep_positions             VARCHAR2(10);
    pcube                          NUMBER(12, 4);
    length_unit                    VARCHAR2(10);
    abc                            VARCHAR2(5) := ' ';
    skid_cube                      NUMBER(12, 4);
    g_last_put_aisle1              VARCHAR2(10) := 0;
    put_slot1                      NUMBER := 0;
    put_aisle1                     NUMBER := 0;
    g_last_put_slot1               VARCHAR2(10) := 0;
    g_last_put_level1              VARCHAR2(10) := 0;
    put_level1                     VARCHAR2(10);
    g_last_pik_cube                NUMBER(12, 4) := 0;
    split_pallet_id                VARCHAR2(20);
    area                           VARCHAR2(5);
    err_code                       VARCHAR2(20);
    err_msg                        VARCHAR2(20);
    put_slot_type2                 VARCHAR2(20);
    put_deep_ind2                  VARCHAR2(20);
    l_index                        NUMBER := 0;
    sz_previous_prod_id            NUMBER;
    rcv_prod_id_len                NUMBER := 7;
    cust_pref_vendor               VARCHAR2(10);
    sz_previous_cust_pref_vendor   VARCHAR2(10);
    rcv_cust_prev_vendor_len       NUMBER := 6;
    ti                             NUMBER(5);
    hi                             NUMBER(5);
    lot_trk                        VARCHAR2(2);
    fifo_trk                       VARCHAR2(2);
    spc                            NUMBER(5);
    case_cube                      NUMBER(12, 4);
    stackable                      NUMBER(10);
    pallet_stack                   NUMBER(10);
    max_slot                       NUMBER(10);
    max_slot_flag                  VARCHAR2(5);
    exp_date_trk                   VARCHAR2(5);
    catch_wt                       VARCHAR2(5);
    date_code                      VARCHAR2(5);
    last_ship_slot                 VARCHAR2(12);
    ext_case_cube_flag             VARCHAR2(2);
    last_pik_slot_type             VARCHAR2(10);
    rule_id                        PLS_INTEGER;
    home_loc_cube                  NUMBER := 0.0;
    home_slot_cube                 NUMBER := 0.0;
    std_pallet_cube                NUMBER := 0.0;
    lst_pallet_cube                NUMBER := 0.0;
    put_deep_factor2               NUMBER;
    current_pallet                 NUMBER := 0;
    num_pallet                     NUMBER := 0;
    each_pallet_qty                NUMBER(10);
   
    last_pallet_qty                NUMBER := 0;
    g_mix_same_prod_deep_slot      VARCHAR(20);
    partial_pallet                 NUMBER;
    total_cnt                      NUMBER := 0;
    slot_cnt                       NUMBER(10) := 0;
    first_home_assign              VARCHAR2(5) := 'FALSE';
    deep_ind                       VARCHAR2(2);
    slot_type                      VARCHAR2(3);
    home_slot_flag                 NUMBER;
    num_next_zones                 NUMBER;
    run_strg                       VARCHAR2(256);
    g_pallet_type_flag             VARCHAR2(2);
    revisit_open_slot              VARCHAR2(10);
    done                           NUMBER;
    ca_dmg_ind                     VARCHAR2(3);
    l_erm_type                     erm.erm_type%TYPE;
    po_num                         VARCHAR2(12);
    g_allow_flag                   VARCHAR2(5); 
    g_erm_line_id                  NUMBER(5);
    g_reprocess_flag               NUMBER := C_FALSE;


PROCEDURE p_reprocess_po (
    i_uom             NUMBER,
    i_ca_dmg_status   VARCHAR2,
    l_pallet_flag     VARCHAR2,
    i_rec_id          VARCHAR2,
    i_prod_id         VARCHAR2,
    i_cpv             VARCHAR2,
    i_qty_rec         NUMBER,
    i_pallet_type     VARCHAR2,
    i_putaway_dimension VARCHAR2
) IS
    l_status       VARCHAR2(100);
    l_func_name    VARCHAR2(30) := 'p_reprocess_po';
    l_aging_days   NUMBER;
    l_loc_key      sys_config.config_flag_val%TYPE;
    l_ca_dest_loc  loc.logi_loc%TYPE := ' ';
    o_status       NUMBER;
    l_dummy        VARCHAR2(1) := 'Z';
    l_done         NUMBER;
    l_catch_wt     putawaylst.catch_wt%TYPE;
    l_zone_done    BOOLEAN := true;
    l_find_done    NUMBER;
    BEGIN
     pl_text_log.ins_msg_async('INFO', l_func_name, ' Starting pl_reprocess_po.reprocess with rec id = '
                                            || i_rec_id
                                            || ' Prod id = '
                                            || i_prod_id
                                            || ' CPV = '
                                            || i_cpv
                                            || ' Qty Received = '
                                            || i_qty_rec
                                            || ' UOM = '
                                            || i_uom
                                            || ' CA Status = '
                                            || i_ca_dmg_status 
                                            || ' Pallet type = ' 
                                            || i_pallet_type
                                            || 'Putaway Dimension = ' 
                                            || i_putaway_dimension, sqlcode, sqlerrm);
            p_po_reprocessing(i_rec_id, i_prod_id ,i_putaway_dimension,i_ca_dmg_status, l_status);
             /*
             **  Get aging days for item that needs to be aged 
             */

            BEGIN
                 l_aging_days := f_retrieve_aging_item();
            EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception at f_retrieve_aging_item', sqlcode, sqlerrm);
            END;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'l_aging_days value = ' || l_aging_days, sqlcode, sqlerrm); 

          /*
          ** if splits then split_putaway is called
          ** else then convert quantity to splits
          */
            IF i_uom = 1 THEN    /* i_uom  =1 starts */
              /*
              ** OSD changes ..begin
              ** for damaged pallet dest_loc should be found in slots
              ** reserved for damages or in the ones with slot height 999
              */
                IF i_ca_dmg_status = 'DMG' THEN   /* i_ca_dmg_status  = 'DMG' starts */
                 /*
                 **selecting smallest reserve slot for which slot_height is 999
                 **for the damaged pallet
                 */
                    each_pallet_qty := i_qty_rec;
                    BEGIN
                        l_loc_key := pl_common.f_get_syspar('LOC_CUBE_KEY_VALUE', '999');
                    EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get LOC_CUBE_KEY_VALUE syspar flag ', sqlcode, sqlerrm);
                    END;
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Syspar LOC_CUBE_KEY_VALUE value =  ' || l_loc_key, sqlcode, sqlerrm);
                    
                    BEGIN
                        SELECT
                            logi_loc
                        INTO l_ca_dest_loc
                        FROM
                            (
                                SELECT
                                    c.logi_loc
                                FROM
                                    loc     c,
                                    lzone   l,
                                    zone    e
                                WHERE
                                    c.cube = l_loc_key
                                    AND c.pallet_type = l_pallet_flag
                                    AND c.status = 'AVL'
                                    AND l.logi_loc = c.logi_loc
                                    AND e.zone_id = l.zone_id
                                    AND e.zone_type = 'PUT'
                                ORDER BY
                                    c.cube
                            )
                        WHERE
                            ROWNUM = 1;
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'l_ca_dest_loc value =  ' || l_ca_dest_loc, sqlcode, sqlerrm);
                        
                        BEGIN
                        pl_text_log.ins_msg_async('INFO', l_func_name, ' p_insert_table in  LOC_CUBE_KEY_VALUE' , sqlcode, sqlerrm);
 
                            p_insert_table(l_ca_dest_loc, ADD_RESERVE);
                        EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception at p_insert_table', sqlcode, sqlerrm);
                        END;
                  EXCEPTION
                  WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get select reserve location for damaged pallet = '
                                                                || l_pallet_flag
                                                                || ' and cube = '
                                                                || l_loc_key, sqlcode, sqlerrm);
                 WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'OTHERS : Unable to get select reserve location for damaged pallet = '
                            || l_pallet_flag, sqlcode, sqlerrm);
                            o_status := -1; /* Unsucessfull so returning -1 as output */
                            RETURN;
                END;
        
             /*
             **if reserve slot to fit the damaged pallet is not found
             **then selecting smallest slot to put in the pallet
             **in damage zone of the prod if a damage zone for that
             ** product exists
             */
                   BEGIN
                        SELECT
                            'X'
                        INTO l_dummy
                        FROM
                            pm           p,
                            swms_areas   s
                        WHERE
                            prod_id = i_prod_id
                            AND p.area = s.area_code
                            AND s.def_dmg_zone IS NOT NULL;

                    EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get select reserve location for damaged pallet for prod id ", = '
                        || i_prod_id, sqlcode, sqlerrm);
                        ROLLBACK;
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'OTHERS : Unable to get select reserve location for damaged pallet for Prod id = '
                        || i_prod_id, sqlcode, sqlerrm);
                        ROLLBACK;
                        o_status := -1; /* Unsucessfull so returning -1 as output */
                        RETURN;
                    END;

                    IF ( l_dummy = 'X' AND i_ca_dmg_status = 'DMG' ) THEN
                        each_pallet_qty := i_qty_rec;
                        l_zone_done := pl_demand_pallet.find_damage_zone_location(i_uom, i_prod_id, i_cpv, i_pallet_type);
                    END IF;
                ELSE   /* else for  i_ca_dmg_status  = 'DMG' starts */
                 pl_text_log.ins_msg_async('WARN', l_func_name, 'calling p_split_find_putaway_slot ', sqlcode, sqlerrm);
                    p_split_find_putaway_slot;
                END IF;  /* i_ca_dmg_status  = 'DMG' end */
            ELSE  /* else for UOM = 1  */
             /*
             ** Set correct catch weight flag for
             ** demand printed license plate
             */
                BEGIN
                    SELECT
                        nvl(MIN(p.catch_wt), 'N')
                    INTO l_catch_wt
                    FROM
                        putawaylst p
                    WHERE
                        p.catch_wt IN (
                            'Y',
                            'C'
                        )
                        AND p.prod_id = i_prod_id
                        AND p.cust_pref_vendor = i_cpv
                        AND p.rec_id = i_rec_id;

                EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get cacht wt from putawaylst for  prod id =  '
                                                            || i_prod_id
                                                            || ' CPV =  '
                                                            || i_cpv
                                                            || ' Rec id = '
                                                            || i_rec_id, sqlcode, sqlerrm);
                END;
     
             /*
             ** Need to convert quantity to split qty
             */

              num_pallet := TRUNC(( i_qty_rec / ( ti * hi ) ));
    
             /*
             ** check if the qty fits on even number of pallets
             */
             IF ( ( i_qty_rec MOD ( ti * hi ) ) != 0 ) THEN
                partial_pallet := C_TRUE;
                num_pallet := num_pallet + 1;
             ELSE
                partial_pallet := C_FALSE;
             END IF;
             pl_text_log.ins_msg_async('INFO', l_func_name, 'partial_pallet value =  ' || i_rec_id, sqlcode, sqlerrm);
             
                IF num_pallet = 1 THEN   /* l_num_pallet = 1  starts  */
                    each_pallet_qty := i_qty_rec;
                    last_pallet_qty := each_pallet_qty;
                    lst_pallet_cube := ( ( ceil(last_pallet_qty / ti) ) * ti * case_cube ) + skid_cube;

                    std_pallet_cube := lst_pallet_cube;
                ELSE
                    each_pallet_qty := ti * hi;
                    IF ( partial_pallet = C_TRUE ) THEN
                        last_pallet_qty := ( i_qty_rec / spc ) MOD ( ti * hi );
                    ELSE
                        last_pallet_qty := each_pallet_qty;
                    END IF;

                    lst_pallet_cube := ( ( ( ceil(last_pallet_qty / ti) ) * ti * case_cube ) + skid_cube );

                    std_pallet_cube := ( ( ti * hi * case_cube ) + skid_cube );
                END IF; /* l_num_pallet = 1  Ends  */

                current_pallet := 0;
             /*
             **OSD changes ..begin
             ** for damaged pallet dest_loc should be found in slots
             ** reserved for damages or in the ones with slot height 999
             */
               pl_text_log.ins_msg_async('INFO', l_func_name, 'at else for UOM i_ca_dmg_status =  ' || i_ca_dmg_status, sqlcode, sqlerrm);
         
                IF i_ca_dmg_status = 'DMG' THEN /*  l_ca_dmg_ind = 'DMG' */
                 /*
                 **selecting smallest reserve slot for which slot_height is 999
                 **for the damaged pallet
                 */
                    each_pallet_qty := i_qty_rec;
                    BEGIN
                        SELECT
                            logi_loc
                        INTO l_ca_dest_loc
                        FROM
                            (
                                SELECT
                                    c.logi_loc
                                FROM
                                    loc     c,
                                    lzone   l,
                                    zone    e
                                WHERE
                                    c.cube = l_loc_key
                                    AND c.pallet_type = l_pallet_type
                                    AND c.status = 'AVL'
                                    AND l.logi_loc = c.logi_loc
                                    AND e.zone_id = l.zone_id
                                    AND e.zone_type = 'PUT'
                                ORDER BY
                                    c.cube
                            )
                        WHERE
                            ROWNUM = 1;

                        BEGIN
                         pl_text_log.ins_msg_async('INFO', l_func_name, 'p_insert_table = smallest reserve slot ' , sqlcode, sqlerrm);
        
                            p_insert_table(l_ca_dest_loc, ADD_RESERVE);
                            RETURN;
                        EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception Occured at p_insert_table', 
                            sqlcode, sqlerrm);
                        END;

                    EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get select reserve location for damaged pallet = '
                                                                || l_pallet_flag
                                                                || ' and cube = '
                                                                || l_loc_key, sqlcode, sqlerrm);
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'OTHERS : Unable to get select reserve location for damaged pallet = '
                                                                || l_pallet_flag
                                                                || ' and cube = '
                                                                || l_loc_key, sqlcode, sqlerrm);

                        o_status := -1; /* Unsucessfull so returning -1 as output */
                        RETURN;
                    END;

                    BEGIN
                        SELECT
                            'X'
                        INTO l_dummy
                        FROM
                            pm           p,
                            swms_areas   s
                        WHERE
                            prod_id = i_prod_id
                            AND p.area = s.area_code
                            AND s.def_dmg_zone IS NOT NULL;

                    EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get select reserve location for damaged pallet for prod id ", = '
                        || i_prod_id, sqlcode, sqlerrm);
                        ROLLBACK;
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'OTHERS : Unable to get select reserve location for damaged pallet for Prod id = '
                        || i_prod_id, sqlcode, sqlerrm);
                        ROLLBACK;
                        o_status := -1; /* Unsucessfull so returning -1 as output */
                        RETURN;
                    END;       
        
                  /*
                  **if a damage zone exists for that product
                  **then find the smallest slot
                  **in that zone which will fit the pallet
                  */
                 pl_text_log.ins_msg_async('INFO', l_func_name, 'l_dummy =  ' || l_dummy, sqlcode, sqlerrm);
        
                    IF ( l_dummy = 'X' AND i_ca_dmg_status = 'DMG' ) THEN
                        l_zone_done := pl_demand_pallet.find_damage_zone_location(i_uom, i_prod_id, i_cpv, i_pallet_type);
                        IF l_zone_done = false THEN
                            l_find_done := f_find_putaway_slot(i_prod_id, i_cpv);
                        END IF;
                    END IF;

                END IF;    /*  l_ca_dmg_ind = 'DMG' */
           /*
           **OSD changes ...end
           */
    
                BEGIN
         /*
         **if the pallet is not damaged then
         **follow the normal processing
         ** put each item away
         */
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Calling f_find_putaway_slot  when UOM != 1' , sqlcode, sqlerrm);
                    l_find_done := f_find_putaway_slot(i_prod_id, i_cpv);
                EXCEPTION
                WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'OTHERS : Unable to get value f_find_putaway_slot ', sqlcode, sqlerrm );
                END;
          END IF;   /* i_uom  =1 ends */
    END;

/************************************************************************* 
  ** p_all_pallet_label 
  **  Description: Create putawaylst tasks while opening a receipt using 
  **                 Method2 putaway method. 
  **  Called By : pl_rcv_po_open 
  **  PARAMETERS: 
  **      l_status - Output Parameter 
  **  RETURN VALUES: 
  **      Success or Failure message will be sent 
  **     
  **     
  ****************************************************************/

    PROCEDURE p_all_pallet_label (
        l_status   OUT        NUMBER
    ) IS
        l_func_name                 VARCHAR2(30)        := 'p_all_pallet_label';
        l_erm_id                    erm.erm_id%TYPE;
        l_found                     VARCHAR2(5)         := 'TRUE';
        l_pallet_status             VARCHAR2(100);
        CURSOR c_all_pallet_label IS
            SELECT erm_id FROM erm
            WHERE status IN ('NEW','SCH')
               FOR UPDATE OF status NOWAIT;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Procedure execution', sqlcode, sqlerrm);

        OPEN c_all_pallet_label;
        WHILE l_found= 'TRUE' LOOP
            FETCH c_all_pallet_label INTO l_erm_id;
            IF SQL%NOTFOUND THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'W01 %s TABLE=erm  KEY=NEW,SCH  ACTION=FETCH  MESSAGE=ORACLE unable to find SN/POs to open', sqlcode, sqlerrm);
                l_found := 'FALSE';
            END IF;
            EXIT WHEN c_all_pallet_label%notfound;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'l_erm_id=[' || l_erm_id || '];', sqlcode, sqlerrm);
            pl_one_pallet_label.p_one_pallet_label(l_erm_id, l_pallet_status);
            l_status := l_pallet_status;
        END LOOP;
        
        CLOSE c_all_pallet_label;
    EXCEPTION WHEN OTHERS THEN
        pl_text_log.ins_msg_async('FAILURE', l_func_name, 'Exception Raised at Error Fetching c_all_pallet_label', sqlcode, sqlerrm);
        l_status := -1;
    END p_all_pallet_label;

/************************************************************************* 
  ** p_one_pallet_label 
  **  Description: Create putawaylst tasks while opening a receipt using 
  **                 Method2 putaway method. 
  **  Called By : pl_rcv_po_open 
  **  PARAMETERS: 
  **      p_po - ERM# passed from pl_rcv_po_open as Input 
  **      l_status - Output Parameter 
  **  RETURN VALUES: 
  **      Success or Failure message will be sent 
  **     
  **     vkal9662 jira 3896 Dec 22 2021
  ****************************************************************/

    PROCEDURE p_one_pallet_label (
        p_po       IN         VARCHAR2,
        l_status   OUT        NUMBER
    ) IS

        l_func_name           VARCHAR2(30) := 'p_one_pallet_label';
        vc_func_name          VARCHAR2(31);
        lst_pallet_cube       NUMBER(12, 4);
        std_pallet_cube       NUMBER(12, 4);
        parent_pallet_arr     pl_msku.t_parent_pallet_id_arr;
        vc_message            VARCHAR(1025);
        lm_bats_crt           BOOLEAN := false;
        l_done_fetching_bln   BOOLEAN;
        l_opco_type           VARCHAR2(6);
        command               VARCHAR2(256);
        old_dflt_cool_prt     VARCHAR2(10);
        old_dflt_dry_prt      VARCHAR2(10);
        new_dflt_cool_prt     VARCHAR2(10);
        new_dflt_dry_prt      VARCHAR2(10);
        cool_parm_src         VARCHAR2(7);
        dry_parm_src          VARCHAR2(7);
        fname                 VARCHAR2(128);
        buff                  VARCHAR2(1024);
        prt_q                 VARCHAR2(10);
        dest_loc_flg          VARCHAR2(2);
        po                    VARCHAR2(12);
        sz_dest_loc           VARCHAR(10); 
    /* The putaway dest loc when '*' the dest loc. */
        trans_prod_id         VARCHAR2(7);
        trans_cpv             VARCHAR2(6);
        tran_item             LONG;
        l_v_cur_po            VARCHAR2(13);
        l_v_crt_msg           VARCHAR2(500);
        l_v_crt_msg_ind       INT;
        erm_type              VARCHAR2(3);
        freezercount          NUMBER(20);
        coolercount           NUMBER(20);
        l_putaway_dimension   VARCHAR2(5);
        o_error               BOOLEAN;
        o_crt_message         VARCHAR2(4000);
        l_i_putaway_flag      NUMBER(1);
        wh_id                 NUMBER(5);
        to_wh_id              NUMBER(5);
        po_dtl_cnt            NUMBER(10) := 0;
        erm_id                VARCHAR2(12);
        no_splits             BOOLEAN;
        status                NUMBER(5);
        l_loadnumber          VARCHAR2(10);
        l_food_safety_flag    VARCHAR2(2);
        num_pallet            NUMBER(5);
        last_pallet_qty       NUMBER(10);
        r_syspars             pl_rcv_open_po_types.t_r_putaway_syspars;
        CURSOR transfer_items IS
        SELECT
            prod_id,
            cust_pref_vendor,
            qty
        FROM
            erd
        WHERE
            erm_id = p_po
        ORDER BY
            erm_line_id;

        CURSOR split_line_item IS
        SELECT
            erd.prod_id,
            erd.cust_pref_vendor,
            SUM(erd.qty) qty,
            pm.brand,
            pm.mfg_sku,
            pm.category
        FROM
            pm,
            erd
        WHERE
            erd.prod_id = pm.prod_id
            AND erd.cust_pref_vendor = pm.cust_pref_vendor
            AND erd.erm_id = p_po
            AND erd.uom = 1
        GROUP BY
            erd.prod_id,
            erd.cust_pref_vendor,
            pm.brand,
            pm.mfg_sku,
            pm.category;

        CURSOR sn_line_item IS
        SELECT
            erd.prod_id,
            erd.qty,
            pm.brand,
            pm.mfg_sku,
            erd.cust_pref_vendor,
            pm.category,
            erd_lpn.erm_line_id
        FROM
            pm,
            erd,
            erd_lpn
        WHERE
            erd.erm_id = p_po
            AND erd_lpn.sn_no = p_po
            AND erd.uom = 0
            AND pm.prod_id = erd.prod_id
            AND pm.cust_pref_vendor = erd.cust_pref_vendor
            AND erd.erm_line_id = erd_lpn.erm_line_id
            AND erd_lpn.parent_pallet_id IS NULL
        ORDER BY
            erd.prod_id,
            erd.cust_pref_vendor,
            nvl(trunc(erd_lpn.exp_date), trunc(SYSDATE)),
            erd.qty,
            pm.brand,
            pm.mfg_sku,
            pm.category;

        CURSOR line_item IS
        SELECT
            erd.prod_id,
            SUM(erd.qty) qty,
            pm.brand,
            pm.mfg_sku,
            erd.cust_pref_vendor,
            pm.category
        FROM
            pm,
            erd
        WHERE
            pm.prod_id = erd.prod_id
            AND pm.cust_pref_vendor = erd.cust_pref_vendor
            AND erd.uom = 0
            AND erd.erm_id = p_po
        GROUP BY
            erd.prod_id,
            erd.cust_pref_vendor,
            pm.brand,
            pm.mfg_sku,
            pm.category;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Procedure execution', sqlcode, sqlerrm);
        BEGIN
            SELECT
                erm_type
            INTO l_erm_type
            FROM
                erm
            WHERE
                erm_id = p_po;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'Unable to Fetch erm type ', sqlcode, sqlerrm);
                l_status := 200008;
                ROLLBACK;
                return;
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Processing PO..... ', sqlcode, sqlerrm);
        IF ( substr(l_erm_type, 1, 2) = 'SN' ) THEN
            status := f_assign_msku_putaway_slots(po);
            IF status != 0 THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'p_assign_msku_putaway_slots returned with errors ', sqlcode, sqlerrm);
                l_status := 200009;
                ROLLBACK;
                return;
            END IF;

        END IF;

        g_erm_num := p_po;
        l_putaway_dimension := pl_common.f_get_syspar('PUTAWAY_DIMENSION', 'x');
        IF l_putaway_dimension = 'x' THEN
            pl_text_log.ins_msg_async('FATAL', l_func_name, 'Unable to retrieve putaway dimension ', sqlcode, sqlerrm);
            l_status := 5887;
            ROLLBACK;
            return;
        END IF;

        IF ( substr(l_erm_type, 1, 2) != 'TR' ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'erm_type is   ' || l_erm_type, sqlcode, sqlerrm);
            o_error := false;
            o_crt_message := NULL;
            BEGIN
            /* 
			**  Passed pallet id as Null,use_existing_tasks_bln as  False to the find_slot function - SMOD-2496
			*/
                pl_rcv_open_po_find_slot.find_slot(p_po, Null, o_error ,o_error, o_crt_message);
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Package procedure pl_rcv_open_po_find_slot.find_slot had an error ', sqlcode
                    , sqlerrm);
                    l_status := 1;
                    raise_application_error(-20000, sqlcode
                                                    || '-'
                                                    || sqlerrm);
            END;

            pl_text_log.ins_msg_async('INFO', l_func_name, ' AFTER  pl_rcv_open_po_find_slot ', sqlcode, sqlerrm);
            IF ( o_error = false ) THEN
                l_i_putaway_flag := 0; /* Denotes success of putaway. */
                pl_text_log.ins_msg_async('INFO', l_func_name, '  l_i_putaway_flag  ' || l_i_putaway_flag, sqlcode, sqlerrm);
            ELSE
                l_i_putaway_flag := 1;
                l_status := 1;
                pl_text_log.ins_msg_async('INFO', l_func_name, ' l_i_putaway_flag  ' || l_i_putaway_flag, sqlcode, sqlerrm);
            END IF;

        ELSIF ( l_putaway_dimension = 'I' ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, ' Putaway :   ' || l_putaway_dimension, sqlcode, sqlerrm);
            o_error := false;
            o_crt_message := NULL;
            BEGIN
                pl_pallet_label2.p_assign_putaway_slot(p_po, o_error, o_crt_message);
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'pl_pallet_label2.p_assign_putaway_slot had an error ' || l_i_putaway_flag
                    , sqlcode, sqlerrm);
                    l_status := -1;
                    raise_application_error(-20000, sqlcode
                                                    || '-'
                                                    || sqlerrm);
            END;

            IF o_error = false THEN
                l_i_putaway_flag := 0; /* Denotes success of putaway. */
            ELSE
                l_i_putaway_flag := 1;
                l_status := 1;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'After p_assign_putaway_slot - l_i_putaway_flag ' || l_i_putaway_flag, sqlcode
                , sqlerrm);
            END IF;

        ELSE
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Other putaway dimensions  ', sqlcode, sqlerrm);
            SELECT
                erm_type,
                warehouse_id,
                to_warehouse_id
            INTO
                l_erm_type,
                wh_id,
                to_wh_id
            FROM
                erm
            WHERE
                erm_id = p_po;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'erm_type'
                                                || l_erm_type
                                                || 'to_wh_id '
                                                || to_wh_id
                                                || ' wh_id '
                                                || wh_id, sqlcode, sqlerrm);

            BEGIN
                SELECT
                    COUNT(1)
                INTO po_dtl_cnt
                FROM
                    erd
                WHERE
                    erm_id = p_po;

            EXCEPTION
                WHEN no_data_found THEN
                  pl_text_log.ins_msg_async('INFO', l_func_name, 'ORACLE failed to select info', sqlcode, sqlerrm);
                    po_dtl_cnt := 0;
            END;

            IF po_dtl_cnt = 0 THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'No detail available in ERD' , sqlcode, sqlerrm);
                l_status := 'No detail available in ERD';
                return;
            END IF;
                BEGIN
                    g_allow_flag := pl_common.f_get_syspar('HOME_PUTAWAY', 'x');
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, ' Unable to get home putaway ', sqlcode, sqlerrm);
                        l_status := 'Unable to get for home putaway';
                        return;
                END;

                pl_text_log.ins_msg_async('DEBUG', l_func_name, ' HOME_PUTAWAY  ' || g_allow_flag, sqlcode, sqlerrm);
                IF g_allow_flag = 'x' THEN
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'No detail available for home putaway ', sqlcode, sqlerrm);
                    l_status := 'No detail available for home putaway';
                    return;
                END IF;

                BEGIN
                    g_pallet_type_flag := pl_common.f_get_syspar('PALLET_TYPE_FLAG', 'N');
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'No detail available for PALLET TYPE FLAG', sqlcode, sqlerrm);
                        l_status := 'No detail available for PALLET TYPE FLAG';
                        ROLLBACK;
                        return;
                END;

                pl_text_log.ins_msg_async('INFO', l_func_name, ' PALLET_TYPE_FLAG  ' || g_pallet_type_flag, sqlcode, sqlerrm);
                g_clam_bed_tracked_flag := 'N';
                BEGIN
                    g_clam_bed_tracked_flag := pl_common.f_get_syspar('CLAM_BED_TRACKED', 'x');
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'No detail available for CLAM BED TRACK', sqlcode, sqlerrm);
                        l_status := 'No detail available for CLAM BED TRACK';
                        ROLLBACK;
                        return;
                END;

                pl_text_log.ins_msg_async('INFO', l_func_name, ' CLAM_BED_TRACKED  ' || g_clam_bed_tracked_flag, sqlcode, sqlerrm);
      
            IF ( substr(l_erm_type, 1, 2) = 'TR' ) THEN
                pl_text_log.ins_msg_async('DEBUG', l_func_name, ' Inside TR IF  ', sqlcode, sqlerrm);
                FOR trans_rec IN transfer_items LOOP INSERT INTO trans (
                    trans_id,
                    trans_type,
                    trans_date,
                    rec_id,
                    user_id,
                    exp_date,
                    qty,
                    uom,
                    prod_id,
                    cust_pref_vendor,
                    upload_time,
                    new_status,
                    warehouse_id
                ) VALUES (
                    trans_id_seq.NEXTVAL,
                    'TPI',
                    SYSDATE,
                    p_po,
                    user,
                    trunc(SYSDATE),
                    trans_rec.qty,
                    0,
                    trans_rec.prod_id,
                    trans_rec.cust_pref_vendor,
                    TO_DATE('01-JAN-1980', 'DD-MON-YYYY'),
                    'OUT',
                    to_wh_id
                );

                END LOOP;

            END IF;

            g_mix_same_prod_deep_slot := pl_common.f_get_syspar('MIX_SAME_PROD_DEEP_SLOT', 'N');
            seq_no := 0; 

        /* 
              ** for each line item in the po with a uom = 1 for splits 
              ** get the sum of the erd.qty, brand and mfg_sku 
              **/
            FOR spl IN split_line_item LOOP
                g_prod_id := spl.prod_id;
                g_cpv := spl.cust_pref_vendor;
                total_qty := spl.qty;
                brand := spl.brand;
                mfg := spl.mfg_sku;
                pm_category := spl.category;
                l_cust_pref_vendor := spl.cust_pref_vendor;
                pl_text_log.ins_msg_async('INFO', l_func_name, ' split_line_item  '
                                                    || g_prod_id
                                                    || ' '
                                                    || g_cpv
                                                    || ' '
                                                    || total_qty
                                                    || ' '
                                                    || brand
                                                    || ' '
                                                    || mfg
                                                    || ' '
                                                    || pm_category, sqlcode, sqlerrm); 

            /*** Get all the data needed for the product from the pm table. */

                p_retrieve_label_content(); 

            /* *  Get aging days for item that needs to be aged    */
                aging_days := f_retrieve_aging_item();
                p_split_find_putaway_slot(); 
        /* Fixed as part of RDC Changes - . This commit should be placed outside the loop */ 
        /* get next item */
            END LOOP; 

        /* end while that was processing splits*/

            IF total_qty = 0 THEN
                no_splits := true;
            ELSE
                no_splits := false;
            END IF;

            l_done_fetching_bln := false;
            IF ( substr(l_erm_type, 1, 2) = 'SN' ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, ' IF SN  ', sqlcode, sqlerrm);
                FOR sn_line_item_rec IN sn_line_item LOOP
                    g_prod_id := sn_line_item_rec.prod_id;
                    total_qty := sn_line_item_rec.qty;
                    brand := sn_line_item_rec.brand;
                    mfg := sn_line_item_rec.mfg_sku;
                    g_cpv := sn_line_item_rec.cust_pref_vendor;
                    pm_category := sn_line_item_rec.category;
                    g_erm_line_id := sn_line_item_rec.erm_line_id; 

              /* ** Get all the data needed for the product from the pm table.   */
                    p_retrieve_label_content();
                    aging_days := f_retrieve_aging_item();
                    IF ( total_qty > ( ti * hi * spc ) AND l_erm_type = 'SN' ) THEN
                        each_pallet_qty := total_qty / spc;
                        sz_dest_loc := '*';
                        p_insert_table(sz_dest_loc, add_no_inv);
                    END IF;

                     IF ( substr(l_erm_type, 1, 2) = 'SN' ) THEN
                        num_pallet := 1;
                    ELSE
                        num_pallet := TRUNC((total_qty / spc) / (ti * hi));
                    END IF;  
                    IF ( MOD((total_qty / spc),(ti * hi)) <> 0 ) THEN
                        partial_pallet := 'TRUE';
                    ELSE
                        partial_pallet := 'FALSE';
                    END IF; 

              /*** Only add one to num pallets if not a SN.     */

                    each_pallet_qty := ( total_qty / spc );
                    last_pallet_qty := each_pallet_qty;
                    lst_pallet_cube := ( ceil(last_pallet_qty / ti) * ti * case_cube ) + skid_cube;
                    std_pallet_cube := lst_pallet_cube;
                    done := f_find_putaway_slot(g_prod_id, g_cpv);
                END LOOP;

            ELSE
                FOR line_item_record IN line_item LOOP
                    g_prod_id := line_item_record.prod_id;
                    total_qty := line_item_record.qty;
                    brand := line_item_record.brand;
                    mfg := line_item_record.mfg_sku;
                    g_cpv := line_item_record.cust_pref_vendor;
                    pm_category := line_item_record.category; 

              /* ** Get all the data needed for the product from the pm table. */
                    p_retrieve_label_content(); 

              /*   ** Get aging days for item that needs to be aged       */
                    aging_days := f_retrieve_aging_item();
                    num_pallet := ( total_qty / spc ) / ( ti * hi );
                    IF ( MOD((total_qty / spc),(ti * hi)) <> 0 ) THEN
                        partial_pallet := 'TRUE'; 

                /*      ** Only add one to num pallets if not a SN.           */
                        num_pallet := num_pallet + 1;
                    ELSE
                        partial_pallet := 'FALSE';
                    END IF;

                    each_pallet_qty := ti * hi;
                    IF ( partial_pallet = 'TRUE' ) THEN
                        last_pallet_qty := MOD((total_qty / spc),(ti * hi));
                    ELSE
                        last_pallet_qty := each_pallet_qty;
                    END IF; 

              /* A partial pallet will have the cube rounded up 
                 to the nearest ti. */

                    lst_pallet_cube := ( ceil(last_pallet_qty / ti) * ti * case_cube ) + skid_cube;
                    std_pallet_cube := ( case_cube * ti * hi ) + skid_cube;
                    done := f_find_putaway_slot(g_prod_id, g_cpv);
                END LOOP;
            END IF;

        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, ' Before Insert into trans   ', sqlcode, sqlerrm);
        l_opco_type := pl_common.f_get_syspar('HOST_TYPE', 'x');
        IF l_opco_type = 'x' THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'No Value found for HOST_TYPE ', sqlcode, sqlerrm);
            ROLLBACK;
            return;
        END IF;

        IF ( ( substr(l_opco_type, 1, 3) = 'SAP' ) AND ( substr(l_erm_type, 1, 2) = 'TR' ) ) THEN
            BEGIN
                INSERT INTO trans (
                    trans_id,
                    trans_type,
                    rec_id,
                    trans_date,
                    user_id,
                    upload_time
                ) VALUES (
                    trans_id_seq.NEXTVAL,
                    'ROP',
                    g_erm_num,
                    SYSDATE,
                    user,
                    TO_DATE('01-JAN-1980', 'DD-MON-YYYY')
                );

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, ' Unable to create ROP transaction with YYYY - 1980 ', sqlcode, sqlerrm);
                    l_status := 'Unable to create ROP transaction';
                    ROLLBACK;
                    return;
            END;
        ELSE
            pl_text_log.ins_msg_async('INFO', l_func_name, ' Before Insert into trans 2  ', sqlcode, sqlerrm);
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
                    g_erm_num,
                    SYSDATE,
                    user
                );

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, ' Unable to create ROP transaction with sysdate', sqlcode, sqlerrm);
                    l_status := 'Unable to create ROP transaction';
                    ROLLBACK;
                    return;
            END;

        END IF;

        l_food_safety_flag := pl_common.f_get_syspar('FOOD_SAFETY_ENABLE', 'N');
        pl_text_log.ins_msg_async('INFO', l_func_name, '  FOOD_SAFETY_ENABLE value ' || l_food_safety_flag, sqlcode, sqlerrm);
        IF ( l_food_safety_flag = 'Y' ) THEN
            BEGIN
                pl_text_log.ins_msg_async('FATAL', l_func_name, ' before loadnumber ' || g_erm_num, sqlcode, sqlerrm, 'PO PROCESSING', 'pl_po_processing'
                );

                SELECT
                    load_no
                INTO l_loadnumber
                FROM
                    erm
                WHERE
                    erm_id = g_erm_num;

                pl_text_log.ins_msg_async('DEBUG', l_func_name, ' after loadnumber ' || g_erm_num, sqlcode, sqlerrm, 'PO PROCESSING', 'pl_po_processing'

                );

                IF l_loadnumber IS NULL THEN
                    l_loadnumber := 'NL-'
                                    || substr(g_erm_num, -6, 6);
                END IF;

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'No loadnumber available', sqlcode, sqlerrm, 'PO PROCESSING', 'pl_po_processing'
                    );
            END;
        END IF;

      pl_log.ins_msg('INFO', l_func_name, 'Before update erm, putawayflag:'||l_i_putaway_flag,NULL, NULL,'RECEIVING' ,'pl_one_pallet_label'); --vkal9662 jira 3896

      If l_i_putaway_flag <> 0 then
      
        pl_log.ins_msg('FATAL',l_func_name , 'Putaway not successful, putawayflag:'||l_i_putaway_flag, NULL, NULL, 'RECEIVING','pl_one_pallet_label'); 

        Rollback;
        Return;
      End If;  --vkal9662 jira 3896


        BEGIN
            UPDATE erm
                SET
                    erm.status = 'OPN',
                    erm.rec_date = SYSDATE,
                    erm.maint_flag = 'Y',
                    erm.load_no = l_loadnumber,
                    erm.freezer_trailer_trk = 'N',
                    erm.cooler_trailer_trk = 'N'
                WHERE
                    erm.erm_id = g_erm_num;

            pl_text_log.ins_msg_async('INFO', l_func_name, ' ERM  updated to OPN', sqlcode, sqlerrm);
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'Unable to update status to OPN', sqlcode, sqlerrm);
                l_status := 'Unable to update status to OPN';
                ROLLBACK;
                return;
        END;

        IF l_erm_type IN ('SN','VN') THEN
            BEGIN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Updating status for SN Header and ERM to OPN', sqlcode, sqlerrm);
                UPDATE sn_header
                    SET status = 'OPN'
                    WHERE sn_no = g_erm_num;
          
                UPDATE erm
                    SET status = 'OPN',
                    maint_flag = DECODE(l_opco_type,'SAP','Y','N')
                    WHERE erm_id = g_erm_num;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'Unable to update status to OPN', sqlcode, sqlerrm);
                    l_status := 'Unable to update status to OPN For SN/VN';
                    ROLLBACK;
                    return;
            END;
        END IF;
    END p_one_pallet_label; 
    
  /************************************************************************* 
  ** f_retrieve_aging_item 
  **  Description: This function retrieves the # of aging days for an item that 
  **         needs to be aged. 
  **  Called By : pl_rcv_po_open 
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **    -1  The item doesn't need aged or database error 
  **    > 1   The # of aging days for the item 
  **     
  ****************************************************************/

    FUNCTION f_retrieve_aging_item RETURN NUMBER IS
        l_func_name   VARCHAR2(30) := 'f_retrieve_aging_item';
        days          INTEGER := -1;
    BEGIN
      pl_text_log.ins_msg_async('INFO', l_func_name, 'f_retrieve_aging_item g_prod_id =  ' || g_prod_id ||' g_cpv = ' || g_cpv , sqlcode, sqlerrm);
        SELECT
            nvl(aging_days, 0)
        INTO days
        FROM
            aging_items
        WHERE
            prod_id = g_prod_id
            AND cust_pref_vendor = g_cpv;

        IF days = 0 THEN
            days := -1;
        END IF;
        RETURN days;
    EXCEPTION
        WHEN no_data_found THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, ' ORACLE failed to select AGING ITEMS Days =  ' || days, sqlcode, sqlerrm);
            days := -1;
            RETURN days;
    END f_retrieve_aging_item; 
    
  /************************************************************************* 
  ** p_split_find_putaway_slot 
  **  Description: To find the split putaway slots for the items 
  **  Called By :  
  **  PARAMETERS: 
  **       
  **  RETURN VALUES: 
  **      Insert Data into tables putawaylst, trans 
  **     
  **     
  ****************************************************************/

    PROCEDURE p_split_find_putaway_slot AS

        l_func_name                    VARCHAR2(30) := 'p_split_find_putaway_slot';
        status                         INTEGER;
        is_float_item                  VARCHAR2(5) := 'FALSE';
        is_done                        INTEGER;
        i                              INTEGER := 0;
        dest_loc                       VARCHAR(10);
        tmp_check                      VARCHAR2(1);
        clam_bed_trk                   VARCHAR2(30);
        aging_days                     NUMBER;
        catch_wt                       VARCHAR2(1) := 'N';
        pallet_count                   INTEGER;
        count1                         INTEGER;
        is_clam_bed_tracked_item_trk   INTEGER := 0;
        is_tti_tracked_item_trk        NUMBER(2);
        tti_trk                        VARCHAR(1) := 'N';
        done                           NUMBER(5);
        sp_zone_id                     VARCHAR(6);
        split_pallet_num               VARCHAR(20);
        l_status                       VARCHAR2(100);
        
        CURSOR split_each_zone IS
        SELECT
            next_zone_id
        FROM
            next_zones
        WHERE
            zone_id = l_zone_id
        ORDER BY
            sort ASC;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Split putaway inside begin  ', sqlcode, sqlerrm);
        SELECT
            TO_CHAR(pallet_id_seq.NEXTVAL)
        INTO split_pallet_id
        FROM
            dual;

        pallet_count := 0;
        count1 := 0;
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Split putaway - before while  ', sqlcode, sqlerrm);
        WHILE true LOOP
            SELECT
                TO_CHAR(pallet_id_seq.NEXTVAL)
            INTO split_pallet_id
            FROM
                dual;

            SELECT
                COUNT(*)
            INTO pallet_count
            FROM
                inv
            WHERE
                logi_loc = split_pallet_id;

            IF pallet_count = 0 THEN
                EXIT;
            END IF;
        END LOOP;

        is_float_item := f_split_check_float_item(aging_days);
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Split_check_float_item  ' || is_float_item, sqlcode, sqlerrm);
        IF ( is_float_item = 'TRUE' ) THEN
            SELECT
                rule_id
            INTO rule_id
            FROM
                zone
            WHERE
                zone_id = l_zone_id;

            pl_text_log.ins_msg_async('INFO', l_func_name, ' Split putaway - Before  split_hi_rise_rule   ', sqlcode, sqlerrm);
            is_done := f_split_hi_rise_rule();
            IF ( is_done = 0 ) THEN
                FOR split_record IN split_each_zone LOOP
                    sp_zone_id := split_record.next_zone_id;
                    SELECT
                        rule_id
                    INTO rule_id
                    FROM
                        zone
                    WHERE
                        zone_id = sp_zone_id;

                    IF rule_id = 1 OR aging_days > 0 THEN
                        NULL;
                        is_done := f_split_hi_rise_rule();
                    END IF;

                    IF ( is_done <> 0 ) THEN
                        EXIT;
                    END IF;
                END LOOP;

                pl_text_log.ins_msg_async('INFO', l_func_name, ' Split putaway - Inside loop   ', sqlcode, sqlerrm);
            END IF;

            IF ( is_done <> 0 ) THEN
                split_dest_loc := '*         ';
            END IF;
            pl_text_log.ins_msg_async('INFO', l_func_name, ' Split putaway - split_dest_loc   ' || split_dest_loc, sqlcode, sqlerrm);
            is_clam_bed_tracked_item_trk := f_is_clam_bed_tracked_item(pm_category);
            IF ( is_clam_bed_tracked_item_trk = 1 ) THEN
                clam_bed_trk := 'Y';
            ELSE
                clam_bed_trk := 'N';
            END IF;

            is_tti_tracked_item_trk := f_is_tti_tracked_item();
            IF is_tti_tracked_item_trk = 1 THEN
                tti_trk := 'Y';
            ELSE
                tti_trk := 'N';
            END IF;

            pl_text_log.ins_msg_async('INFO', l_func_name, ' Split putaway - sBEfore insert', sqlcode, sqlerrm);
            INSERT INTO putawaylst (
                rec_id,
                prod_id,
                cust_pref_vendor,
                dest_loc,
                qty,
                uom,
                status,
                inv_status,
                pallet_id,
                qty_expected,
                qty_received,
                temp_trk,
                catch_wt,
                lot_trk,
                exp_date_trk,
                date_code,
                equip_id,
                rec_lane_id,
                seq_no,
                putaway_put,
                exp_date,
                clam_bed_trk,
                po_no,
                tti_trk,
                cool_trk
            ) VALUES (
                g_erm_num,
                g_prod_id,
                g_cpv,
                split_dest_loc,
                total_qty,
                1,
                'NEW',
                DECODE(aging_days, - 1, 'AVL', 'HLD'),
                split_pallet_id,
                total_qty,
                total_qty,
                temp_trk,
                catch_wt,
                'N',
                'N',
                'N',
                ' ',
                ' ',
                seq_no,
                'N',
                trunc(SYSDATE),
                clam_bed_trk,
                g_erm_num,
                tti_trk,
                'N'
            );

            IF catch_wt = 'Y' THEN
                BEGIN
                    SELECT
                        'X'
                    INTO tmp_check
                    FROM
                        tmp_weight
                    WHERE
                        erm_id = g_erm_num
                        AND prod_id = g_prod_id
                        AND cust_pref_vendor = g_cpv;

                EXCEPTION
                    WHEN no_data_found THEN
                        INSERT INTO tmp_weight (
                            erm_id,
                            prod_id,
                            cust_pref_vendor,
                            total_cases,
                            total_splits,
                            total_weight
                        ) VALUES (
                            g_erm_num,
                            g_prod_id,
                            g_cpv,
                            0,
                            0,
                            0
                        );

                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Selection of tmp_weight failed ', sqlcode, sqlerrm);
                END;
            END IF;

        ELSE
            p_split_putaway();
            IF l_status IS NOT NULL THEN
                RETURN;
            END IF;
        END IF;

        IF g_reprocess_flag = C_TRUE THEN
            INSERT INTO trans (
                trans_id,
                trans_type,
                rec_id,
                trans_date,
                user_id,
                pallet_id,
                uom,
                qty,
                prod_id,
                cust_pref_vendor,
                exp_date
            ) VALUES (
                trans_id_seq.NEXTVAL,
                'DLP',
                g_erm_num,
                SYSDATE,
                user,
                split_pallet_id,
                1,
                total_qty,
                g_prod_id,
                g_cpv,
                SYSDATE
            );

        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('FATAL', l_func_name, ' Split putaway - failed   ', sqlcode, sqlerrm);
    END p_split_find_putaway_slot; 
    
  /************************************************************************* 
  ** f_is_tti_tracked_item 
  **  Description: This function checks if the current processing item is a tti 
  **      tracked item through the inspection of haccp code. 
  **  Called By : p_split_putaway,p_insert_table,p_split_find_putaway_slot 
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **      1 for success 
  **      0 For Failure 
  **     
  ****************************************************************/

    FUNCTION f_is_tti_tracked_item RETURN NUMBER AS

        l_func_name        VARCHAR(30) := 'f_is_tti_tracked_item';
        count              INTEGER;
        l_c_haccp_flag     VARCHAR(1); 
    /* HACCP_CODES table exists or not and for data exists or not */
        l_c_haccp_data     VARCHAR(1);
        l_c_haccp_exists   VARCHAR(1);
    BEGIN
        l_c_haccp_flag := 'N';
        l_c_haccp_exists := 'N';
        SELECT
            'Y'
        INTO l_c_haccp_flag
        FROM
            user_tables
        WHERE
            table_name = 'HACCP_CODES';

        SELECT
            nvl(MIN('Y'), 'N')
        INTO l_c_haccp_data
        FROM
            haccp_codes
        WHERE
            haccp_type = 'H';

        IF l_c_haccp_data = 'Y' THEN
            SELECT
                h.tti_trk
            INTO l_c_haccp_exists
            FROM
                pm            p,
                haccp_codes   h
            WHERE
                p.prod_id = g_prod_id
                AND p.cust_pref_vendor = cust_pref_vendor
                AND p.hazardous = h.haccp_code;

            IF l_c_haccp_exists = 'Y' THEN
                RETURN 1;
            ELSE
                RETURN 0;
            END IF;
        ELSE
            l_c_haccp_flag := 'N';
        END IF;

        IF l_c_haccp_flag = 'N' THEN
            RETURN 0;
        END IF;
        RETURN 0;
    EXCEPTION
        WHEN no_data_found THEN
            RETURN 0;
        WHEN OTHERS THEN
              pl_text_log.ins_msg_async('FATAL', l_func_name, ' f_is_tti_tracked_item - failed ', sqlcode, sqlerrm);
    END f_is_tti_tracked_item; 
    
  /************************************************************************ 
  ** f_is_clam_bed_tracked_item 
  **  Description:This function checks if the current processing item is a clam bed 
  **      tracked item through the inspection of the syspar CLAM_BED_TRACKED 
  **      flag and the item category value. 
  **  Called By : f_split_hi_rise_open_assign ,p_insert_table,p_split_putaway 
  **                  
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **       
  ****************************************************************/

    FUNCTION f_is_clam_bed_tracked_item (
        category IN VARCHAR2
    ) RETURN NUMBER AS

        l_func_name        VARCHAR(30) := 'f_is_clam_bed_tracked_item';
        count              NUMBER;
        l_c_haccp_flag     VARCHAR(1); /* HACCP_CODES table exists  */
        l_c_haccp_data     VARCHAR(1); /* Category exists in table */
        l_c_haccp_exists   VARCHAR(1);
        l_v_category       VARCHAR(12);
    BEGIN
        IF g_clam_bed_tracked_flag = 'N' OR g_clam_bed_tracked_flag = ' ' THEN
            RETURN 0;
        END IF;
        l_c_haccp_flag := 'N';
        l_c_haccp_exists := 'N';
        SELECT
            'Y'
        INTO l_c_haccp_flag
        FROM
            user_tables
        WHERE
            table_name = 'HACCP_CODES';

        SELECT
            nvl(MIN('Y'), 'N')
        INTO l_c_haccp_data
        FROM
            haccp_codes
        WHERE
            haccp_type = 'C';

        IF l_c_haccp_data = 'Y' THEN
            SELECT
                'Y'
            INTO l_c_haccp_exists
            FROM
                haccp_codes
            WHERE
                haccp_code = l_v_category
                AND haccp_type = 'C';

            IF l_c_haccp_exists = 'Y' THEN
                RETURN 1;
            ELSE
                RETURN 0;
            END IF;
        ELSE
            l_c_haccp_flag := 'N';
        END IF;

        RETURN 0;
    EXCEPTION
        WHEN no_data_found THEN
            RETURN 0;
         WHEN OTHERS THEN
            pl_text_log.ins_msg_async('FATAL', l_func_name, ' f_is_clam_bed_tracked_item - failed   ', sqlcode, sqlerrm);
    END f_is_clam_bed_tracked_item; 
    
  /****************************************************************** 
  ** f_split_hi_rise_rule 
  **  Description:  This function finds open slots for splits for items assigned 
  **      to a floating zone.  If an open slot is found then an inventory 
  **      record is created for the slot. 
  **  Called By : p_split_find_putaway_slot 
  **                  
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **      1- Success 
  **      0 -Failure 
  **       
  ****************************************************************/

    FUNCTION f_split_hi_rise_rule RETURN NUMBER AS

        l_func_name         VARCHAR(30) := 'f_split_hi_rise_rule';
        status              INTEGER := 0;
        index1              INTEGER := 0;
        qoh                 NUMBER;
        qty_planned         NUMBER;
        dest_loc            VARCHAR(10);
        aisle1              INTEGER;
        slot1               INTEGER;
        slot_type1          VARCHAR2(15); /* Dummy Declarartion */
        level1              INTEGER;
        cust_pref_vendor1   VARCHAR2(20); /* Dummy Declarartion */
        prod_id1            VARCHAR2(10); /* Dummy Declarartion */
    BEGIN
        prod_id1 := g_prod_id;
        SELECT
            l.logi_loc,
            l.put_aisle,
            l.put_slot,
            l.put_level,
            l.slot_type
        INTO
            dest_loc,
            aisle1,
            slot1,
            level1,
            slot_type1
        FROM
            slot_type   s,
            loc         l,
            lzone       z,
            inv         i
        WHERE
            s.slot_type = l.slot_type
            AND l.logi_loc = z.logi_loc
            AND z.logi_loc = i.plogi_loc
            AND z.zone_id = l_zone_id
            AND i.prod_id = prod_id1
            AND i.cust_pref_vendor = g_cpv
        ORDER BY
            i.exp_date,
            i.qoh,
            i.logi_loc;

        IF ( aisle1 IS NULL ) THEN
            SELECT
                l.logi_loc,
                l.cube,
                l.put_aisle,
                l.put_slot,
                l.put_level,
                p.cube
            INTO
                phys_loc,
                loc_cube,
                put_aisle2,
                put_slot2,
                put_level2,
                pcube
            FROM
                pallet_type   p,
                slot_type     s,
                loc           l,
                lzone         z
            WHERE
                p.pallet_type = l.pallet_type
                AND s.slot_type = l.slot_type
                AND ( p.cube >= pallet_cube
                      AND l.pallet_type = l_pallet_type )
                AND l.logi_loc = z.logi_loc
                AND l.perm = 'N'
                AND l.status = 'AVL'
                AND l.cube >= nvl(g_last_pik_cube, 0)
                AND z.zone_id = l_zone_id
                AND NOT EXISTS (
                    SELECT
                        'x'
                    FROM
                        inv i
                    WHERE
                        i.plogi_loc = l.logi_loc
                )
            ORDER BY
                p.cube,
                l.cube,
                abs(aisle1 - l.put_aisle),
                l.put_aisle,
                abs(slot1 - l.put_slot),
                l.put_slot,
                abs(level1 - l.put_level),
                l.put_level;

            split_dest_loc := phys_loc;
            length_unit := pl_common.f_get_syspar('LENGTH_UNIT', 'IN');
            
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
                lst_cycle_date,
                cube,
                abc_gen_date,
                cust_pref_vendor,
                exp_date
            ) VALUES (
                split_dest_loc,
                split_pallet_id,
                g_prod_id,
                g_erm_num,
                total_qty,
                0,
                0,
                0,
                SYSDATE,
                SYSDATE,
                abc,
                DECODE(aging_days, - 1, 'AVL', 'HLD'),
                SYSDATE,
                DECODE(length_unit, 'CM', DECODE(sign(999999999.9999 -(total_qty + skid_cube)), - 1, 999999999.9999,(total_qty + skid_cube
                )), DECODE(sign(99999.99 -(total_qty + skid_cube)), - 1, 99999.99,(total_qty + skid_cube))),
                SYSDATE,
                g_cpv,
                trunc(SYSDATE)
            );

            status := f_split_hi_rise_open_assign();
        ELSE
            SELECT
                l.logi_loc,
                l.cube,
                l.put_aisle,
                l.put_slot,
                l.put_level,
                p.cube
            INTO
                phys_loc,
                loc_cube,
                put_aisle2,
                put_slot2,
                put_level2,
                pcube
            FROM
                pallet_type   p,
                slot_type     s,
                loc           l,
                lzone         z
            WHERE
                p.pallet_type = l.pallet_type
                AND ( p.cube >= pallet_cube
                      AND l.pallet_type = l_pallet_type )
                AND s.slot_type = l.slot_type
                AND l.logi_loc = z.logi_loc
                AND l.perm = 'N'
                AND l.status = 'AVL'
                AND l.cube >= nvl(g_last_pik_cube, 0)
                AND z.zone_id = l_zone_id
                AND NOT EXISTS (
                    SELECT
                        'x'
                    FROM
                        inv i
                    WHERE
                        i.plogi_loc = l.logi_loc
                )
            ORDER BY
                p.cube,
                l.cube,
                abs(g_last_put_aisle1 - l.put_aisle),
                l.put_aisle,
                abs(g_last_put_slot1 - l.put_slot),
                l.put_slot,
                abs(g_last_put_level1 - l.put_level),
                l.put_level;

            split_dest_loc := phys_loc;
            length_unit := pl_common.f_get_syspar('LENGTH_UNIT', 'IN');
            
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
                lst_cycle_date,
                cube,
                abc_gen_date,
                cust_pref_vendor,
                exp_date
            ) VALUES (
                split_dest_loc,
                split_pallet_id,
                g_prod_id,
                g_erm_num,
                total_qty,
                0,
                0,
                0,
                SYSDATE,
                SYSDATE,
                abc,
                DECODE(aging_days, - 1, 'AVL', 'HLD'),
                SYSDATE,
                DECODE(length_unit, 'CM', DECODE(sign(999999999.9999 -(total_qty + skid_cube)), - 1, 999999999.9999,(total_qty + skid_cube
                )), DECODE(sign(99999.99 -(total_qty + skid_cube)), - 1, 99999.99,(total_qty + skid_cube))),
                SYSDATE,
                g_cpv,
                trunc(SYSDATE)
            );

        END IF;

        RETURN 1;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN status;
    END f_split_hi_rise_rule; 
    
  /************************************************************************ 
  ** p_retrieve_label_content 
  **  Description: This function retrieves info about the item being received. 
  **  Called By : p_one_pallet_label 
  **                  
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **       
  ****************************************************************/

    PROCEDURE p_retrieve_label_content IS

        l_func_name      VARCHAR2(30) := 'p_retrieve_label_content';
        l_hs_case_cube   NUMBER;
        l_hs_loc_cube    NUMBER(12, 4) := 0.0;
        area             VARCHAR2(3);
        l_pallet_type    VARCHAR2(30);
        l_status         VARCHAR2(30);
    BEGIN 
      /* 
      ** RETURN from the function if the item being processed is the same 
      ** as the previous item which can occur for a SN.  There is no need 
      ** to reselect the information.  I chose to RETURN from the function 
      ** at this point instead of having a giant if-ELSE. 
      */
        IF ( length(g_prod_id) = rcv_prod_id_len AND length(sz_previous_prod_id) = rcv_prod_id_len ) AND ( length(g_cpv) = rcv_cust_prev_vendor_len
        AND length(sz_previous_cust_pref_vendor) = rcv_cust_prev_vendor_len ) THEN
            return;
        END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'p_retrieve_label_content g_prod_id. ' || g_prod_id || ' --cpv = ' || g_cpv,
        sqlcode, sqlerrm);
        BEGIN
            sz_previous_prod_id := g_prod_id;
            sz_previous_cust_pref_vendor := g_cpv;
            SELECT
                ti,
                hi,
                pallet_type,
                nvl(lot_trk, 'N'),
                nvl(fifo_trk, 'N'),
                spc,
                case_cube,
                nvl(stackable, 0),
                pallet_stack,
                max_slot,
                max_slot_per,
                abc,
                zone_id,
                nvl(temp_trk, 'N'),
                nvl(exp_date_trk, 'N'),
                nvl(catch_wt_trk, 'N'),
                nvl(mfg_date_trk, 'N'),
                last_ship_slot,
                area
            INTO
                ti,
                hi,
                l_pallet_type,
                lot_trk,
                fifo_trk,
                spc,
                case_cube,
                stackable,
                pallet_stack,
                max_slot,
                max_slot_flag,
                abc,
                l_zone_id,
                temp_trk,
                exp_date_trk,
                catch_wt,
                date_code,
                last_ship_slot,
                area
            FROM
                pm
            WHERE
                prod_id = g_prod_id
                AND cust_pref_vendor = g_cpv;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, ' Select from pm table failed. ', sqlcode, sqlerrm);
                l_status := 6075;
                return;
        END; 

      /*  SN Receipt changes retrieve shipped Ti and Hi for SN */ 
      /* Do not select the shipped Ti and Hi for a SN. 

         Added erm_line_id to the where clause. */ 
      /*                 Comment out selecting the erd_lpn pallet type. 

      **                 We do not want to use what was sent from the RDC. 

      **                 It causes an issue when the RDC pallet type is LW 

      **                 and the SWMS pallet type is FW.  The putaway process 

      **                 is finding LW slots instead of FW slots. 

      */

        p_get_num_next_zones(area);
        BEGIN
            SELECT
                nvl(p.cube, 0),
                nvl(p.skid_cube, 0),
                nvl(p.ext_case_cube_flag, 'N')
            INTO
                pallet_cube,
                skid_cube,
                ext_case_cube_flag
            FROM
                pallet_type p
            WHERE
                p.pallet_type = l_pallet_type;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, ' selection Failed to get pallet type  ', sqlcode, sqlerrm);
        END; 

      /*       ** put 0 in cube first if in case last ship slot is null        */

        BEGIN
            SELECT
                nvl(l.cube, 0),
                l.slot_type,
                l.put_aisle,
                l.put_slot,
                l.put_level
            INTO
                g_last_pik_cube,
                last_pik_slot_type,
                g_last_put_aisle1,
                g_last_put_slot1,
                g_last_put_level1
            FROM
                loc l
            WHERE
                l.logi_loc = last_ship_slot;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, ' select of cube and slot type failed  ', sqlcode, sqlerrm);
        END;

        BEGIN
            IF ext_case_cube_flag = 'Y' THEN
                BEGIN
                    SELECT
                        l.cube,
                        nvl((((l.cube / s.deep_positions) - skid_cube) /(ti * hi)), 0)
                    INTO
                        l_hs_loc_cube,
                        l_hs_case_cube
                    FROM
                        slot_type   s,
                        loc         l
                    WHERE
                        s.slot_type = l.slot_type
                        AND l.uom IN (
                            0,
                            2
                        )
                        AND l.perm = 'Y'
                        AND l.rank = 1
                        AND l.cust_pref_vendor = cust_pref_vendor
                        AND l.prod_id = g_prod_id;

                         pl_text_log.ins_msg_async('DEBUG', l_func_name, ' Extended case cube: Item' || g_prod_id, sqlcode, sqlerrm);

                EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('DEBUG', l_func_name, 'No Data Found Extended case cube: Floating item ' || g_prod_id, sqlcode
                        , sqlerrm);

                BEGIN
                    SELECT
                        l.cube,
                        nvl((((l.cube / s.deep_positions) - skid_cube) /(ti * hi)), 0)
                    INTO
                        l_hs_loc_cube,
                        l_hs_case_cube
                    FROM
                        slot_type   s,
                        loc         l
                    WHERE
                        s.slot_type = l.slot_type
                        AND l.logi_loc = last_ship_slot;

                EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('DEBUG', l_func_name, 'NO DATA FOUND for  hs_loc_cube and hs_case_cube', sqlcode, sqlerrm)
                        ;
                END;
          END;
                IF ( case_cube = 0.0 ) OR ( l_hs_loc_cube >= 900.0 ) THEN
                    l_hs_case_cube := 0.0;
                END IF;

                BEGIN
                    SELECT
                        DECODE(l_hs_case_cube, 0, case_cube, l_hs_case_cube)
                    INTO case_cube
                    FROM
                        dual;

                EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('INFo', l_func_name, ' No Data Found for case cube  ', sqlcode, sqlerrm);
                END;

            END IF;
        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, ' No Data Available for  case  ', sqlcode, sqlerrm);
        END;

    END p_retrieve_label_content; 
    
  /***************************************************************************** 
  **  FUNCTION: 
  **      f_split_check_float_item 
  **  DESCRIPTION: 
  **      This function determines if a split item on the SN/PO is a floating item. 
  **  PARAMETERS: 
  **      days - # of item aging days 
  **  RETURN VALUES: 
  **      TRUE  - The item is a floating item.  It has no split home and the 
  **              rule id is 1. 
  **       - For aging item, don't put into home slot. 
  **      FALSE - The item is not a floating item. 
  *****************************************************************************/

    FUNCTION f_split_check_float_item (
        days IN NUMBER
    ) RETURN VARCHAR2 AS

        l_func_name   VARCHAR2(30) := 'f_split_check_float_item';
        rule_id       NUMBER(5);
        logi_loc      VARCHAR2(10);
        float_item    VARCHAR2(5) := 'FALSE';
    BEGIN
        rule_id := 0; 

      /* Check if the item has a split home. */
        BEGIN
            SELECT
                l.logi_loc
            INTO logi_loc
            FROM
                loc l
            WHERE
                l.uom IN (
                    0,
                    1
                )
                AND l.cust_pref_vendor = g_cpv
                AND l.prod_id = g_prod_id;

            IF ( days > 0 ) THEN
                float_item := 'TRUE';
            END IF;
            RETURN float_item;
        EXCEPTION
            WHEN no_data_found THEN 
            /* The item does not have a split home.  It the item has a zone 
               and a last ship slot then get the rule id for this combination. 
               If the item has only a zone the get the rule id for the zone. */
                IF ( ( l_zone_id IS NOT NULL ) AND ( last_ship_slot IS NOT NULL ) ) THEN 
              /* Get the rule id using the zone and the last ship slot. */
                    SELECT
                        rule_id
                    INTO rule_id
                    FROM
                        zone    z,
                        lzone   lz
                    WHERE
                        z.zone_id = lz.zone_id
                        AND lz.zone_id = l_zone_id
                        AND lz.logi_loc = last_ship_slot;

                ELSIF ( l_zone_id IS NOT NULL ) THEN 
              /* The item had no last ship slot, get the rule id for the zone. */
                    SELECT
                        rule_id
                    INTO rule_id
                    FROM
                        zone
                    WHERE
                        zone_id = l_zone_id; 

              /* Determine if the item is a floating item. */

                    IF ( rule_id = 1 ) THEN
                        float_item := 'TRUE';
                    ELSE
                        float_item := 'FALSE';
                    END IF;

                END IF;
            WHEN OTHERS THEN
                float_item := 'FALSE';
                RETURN float_item;
        END;
       RETURN float_item;
    END f_split_check_float_item; 
         
  /*********************************************************************** 
  ** f_bulk_rule 
  **  Description:  To find whether the item is avialble in bulk zzone. 
  **  Called By : f_find_putaway_slot 
  **                  
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **      1 - Failure 
  **      0 - Success 
  ****************************************************************/

    FUNCTION f_bulk_rule ( 
    i_zone_id  VARCHAR2,
    i_prod_id  VARCHAR2,
    i_cpv      VARCHAR2
    )  RETURN NUMBER IS

        l_func_name            VARCHAR2(50) := 'f_bulk_rule';
        status                 NUMBER := 0;
        temp_cube              NUMBER := 0;
        l_mix_prod_bulk_area   VARCHAR2(1);
        dummy                  VARCHAR2(1);
    BEGIN
        l_mix_prod_bulk_area := pl_common.f_get_syspar('MIX_PROD_BULK_AREA', 'N'); 

      /* 
      ** Check if this prod_id is a new prod_id in bulk area 
      */
        BEGIN
            SELECT
                'x'
            INTO dummy
            FROM
                lzone   z,
                inv     i
            WHERE
                z.logi_loc = i.plogi_loc
                AND z.zone_id = i_zone_id
                AND i.cust_pref_vendor = i_cpv
                AND i.prod_id = i_prod_id;

        EXCEPTION
            WHEN OTHERS THEN 
            /*       ** The item does not currently exist in the bulk zone.     */
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'Bulk: Item does not currently exist in zone', sqlcode, sqlerrm);
                status := f_bulk_open_slot_assign(); 

            /* slots which already have damaged pallets in them should not be chosen  
            **for putting away regular pallets 
            */
                IF ( status != 0 AND ca_dmg_ind = 'DMG' ) THEN
                    IF ( l_mix_prod_bulk_area = 'Y' ) THEN
                        status := f_bulk_avail_slot_assign();
                    END IF;
                END IF;

        END;

        IF dummy = 'x' THEN
            IF ( status != 0 AND ca_dmg_ind = 'DMG' ) THEN
                status := f_bulk_avail_slot_same_prod();
            END IF;

            IF ( status != 0 ) THEN
                status := f_bulk_open_slot_assign();
                NULL;
            END IF;

            IF ( status != 0 AND ca_dmg_ind = 'DMG' ) THEN
                IF ( l_mix_prod_bulk_area = 'Y' ) THEN
                    status := f_bulk_avail_slot_assign();
                END IF;
            END IF;

            pl_text_log.ins_msg_async('INFO', l_func_name, ' Ending BULK RULE for item ', sqlcode, sqlerrm);
        END IF;

        RETURN status;
    END f_bulk_rule; 
    
  /*********************************************************************** 
  **  f_bulk_open_slot_assign 
  **  Description:  To find whether there is slot open for item in bulk zone. 
  **  Called By : f_bulk_rule 
  **                  
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **      1 - Failure 
  **      0 - Success 
  ****************************************************************/

    FUNCTION f_bulk_open_slot_assign RETURN NUMBER AS
        l_func_name   VARCHAR2(30) := 'f_bulk_open_slot_assign';
        temp_cube     NUMBER;
        status        NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Bulk open slot assign  for item', sqlcode, sqlerrm);
        p_clear_array();
        IF ( ( current_pallet = ( num_pallet - 1 ) ) AND partial_pallet = C_TRUE ) THEN
            temp_cube := lst_pallet_cube;
        ELSE
            temp_cube := std_pallet_cube;
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'temp_cube' || temp_cube, sqlcode, sqlerrm);
        BEGIN
            SELECT
                l.logi_loc,
                l.cube,
                l.put_aisle,
                l.put_slot,
                l.put_level,
                DECODE(s.deep_ind, 'Y', substr(l.slot_type, 1, 1), 1),
                l.slot_type,
                s.deep_ind
            INTO
                phys_loc,
                loc_cube,
                put_aisle2,
                put_slot2,
                put_level2,
                put_deep_factor2,
                put_slot_type2,
                put_deep_ind2
            FROM
                slot_type   s,
                loc         l,
                lzone       z
            WHERE
                s.slot_type = l.slot_type
                AND l.perm = 'N'
                AND l.status = 'AVL'
                AND ( DECODE(l.pallet_type, 'FW', 'LW', l.pallet_type) = DECODE(pallet_type, 'FW', 'LW', pallet_type)
                      OR l.pallet_type IN (
                    SELECT
                        mixed_pallet
                    FROM
                        pallet_type_mixed ptm
                    WHERE
                        ptm.pallet_type = pallet_type
                ) )
                AND l.cube >= temp_cube
                AND l.logi_loc = z.logi_loc
                AND z.zone_id = zone_id
                AND NOT EXISTS (
                    SELECT
                        'x'
                    FROM
                        inv i
                    WHERE
                        i.plogi_loc = l.logi_loc
                )
            ORDER BY
                l.cube,
                abs(put_aisle1 - l.put_aisle),
                l.put_aisle,
                abs(put_slot1 - l.put_slot),
                l.put_slot,
                abs(put_level1 - l.put_level),
                l.put_level;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'BULK RULE open slot Found', sqlcode, sqlerrm);
            status := f_bulk_open_slot_assign_loop();
        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'ORACLE No open bulk slots for item in zone', sqlcode, sqlerrm);
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending BULK RULE open slot assign for item', sqlcode, sqlerrm);
        return(status);
    END f_bulk_open_slot_assign; 
    
  /*********************************************************************** 
  ** f_bulk_open_slot_assign_loop 
  **  Description: Loop through all the open slots and assign 
  **               the putaway slot. 
  **  Called By : f_bulk_open_slot_assign 
  **                  
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **      1 - Failure 
  **      0 - Success 
  ****************************************************************/

    FUNCTION f_bulk_open_slot_assign_loop RETURN NUMBER AS

        l_func_name     VARCHAR2(30) := 'f_bulk_open_slot_assign_loop';
        pallet_cnt      NUMBER := 0;
        position_cube   NUMBER := 0.0;
        total_cnt       NUMBER := 0;
        status          NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Bulk open slot assign loop for item', sqlcode, sqlerrm); 

      /* 
      ** Variable num_pallet has been assigned a value in function 
      **  one_pallet_label or in function reprocess. 
      */
        WHILE ( ( l_index <= total_cnt ) AND ( current_pallet < num_pallet ) ) LOOP
            IF ( ( ( put_deep_ind2 = 'Y' ) AND ( ( loc_cube / put_deep_factor2 ) >= ( ( ceil(each_pallet_qty / ti) * ti * case_cube
            ) + skid_cube ) ) ) OR ( ( put_deep_ind2 = 'N' ) AND ( round(loc_cube, 2) >= round(((ceil(each_pallet_qty / ti) * ti *
            case_cube) + skid_cube), 2) ) ) ) THEN 
            /* 
            ** Found enough space for the pallet.  Update the tables 
            ** which assigns the pallet to the slot. 
            */
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Before insert or update of location'
                                                    || phys_loc
                                                    || 'item'
                                                    || g_prod_id, sqlcode, sqlerrm);

                p_insert_table(phys_loc, ADD_RESERVE);
                current_pallet := current_pallet + 1;
                pallet_cnt := pallet_cnt + 1;
                IF ( current_pallet = ( num_pallet - 1 ) ) THEN
                    each_pallet_qty := last_pallet_qty;
                END IF; 

            /* if deep indicator is on */

                IF ( put_deep_ind2 = 'Y' ) THEN
                    IF ( stackable > 0 ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'loc_cube = '
                                                            || loc_cube
                                                            || 'put_deep_factor2 = '
                                                            || put_deep_factor2, sqlcode, sqlerrm); 

                /*    ** Since item is stackable, put more pallets in each  deep slot position based on cube
                      ** Since slot is deep, fill positions individually  */

                        position_cube := loc_cube / put_deep_factor2;
                        position_cube := position_cube - ( ( ceil(each_pallet_qty / ti) * ti * case_cube ) + skid_cube );

                        WHILE ( ( position_cube >= ( ( ceil(each_pallet_qty / ti) * ti * case_cube ) + skid_cube ) ) AND ( current_pallet

                        < num_pallet ) ) LOOP
                            position_cube := position_cube - ( ( ceil(each_pallet_qty / ti) * ti * case_cube ) + skid_cube );

                            p_insert_table(phys_loc, ADD_RESERVE);
                            current_pallet := current_pallet + 1;
                            pallet_cnt := pallet_cnt + 1;
                            IF ( current_pallet = ( num_pallet - 1 ) ) THEN
                                each_pallet_qty := last_pallet_qty;
                            END IF;

                        END LOOP;

                    END IF; /* end stackable */

                    loc_cube := loc_cube - ( loc_cube / put_deep_factor2 );
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'location phys_loc = '
                                                        || phys_loc
                                                        || 'put_deep_factor2 = '
                                                        || put_deep_factor2, sqlcode, sqlerrm);

                    IF ( put_deep_factor2 = 0 ) THEN
                        pallet_cnt := 0;
                        l_index := l_index + 1;
                    END IF;

                ELSIF ( ( stackable > 0 ) AND ( pallet_stack > pallet_cnt ) AND put_deep_ind2 = 'N' ) THEN
                    loc_cube := loc_cube - ( ( ceil(each_pallet_qty / ti) * ti * case_cube ) + skid_cube );
                ELSE 
              /* if deep indicator is N */
                    IF ( put_deep_ind2 = 'N' ) THEN
                        pallet_cnt := 0;
                        l_index := l_index + 1;
                    END IF;
                END IF;

                IF ( current_pallet = ( num_pallet - 1 ) ) THEN
                    each_pallet_qty := last_pallet_qty;
                END IF; 
          /** end if - cube sufficient **/

            ELSE /* cube not sufficient  */
                pl_text_log.ins_msg_async('INFO', l_func_name, ' cube not sufficient, loc_cube = '
                                                    || loc_cube
                                                    || 'phys_loc = '
                                                    || phys_loc, sqlcode, sqlerrm);

                pallet_cnt := 0;
                l_index := l_index + 1;
            END IF;

            pl_text_log.ins_msg_async('INFO', l_func_name, ' cube not sufficient, loc_cube = '
                                                || total_cnt + 1
                                                || 'phys_loc = '
                                                || l_index, sqlcode, sqlerrm);

        END LOOP; /* end while */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending Bulk open slot assign loop for item '
                                            || g_prod_id
                                            || 'cust_pref_vendor = '
                                            || cust_pref_vendor, sqlcode, sqlerrm);

        IF ( current_pallet >= num_pallet ) THEN
            status := C_TRUE;
        ELSE
            status := C_FALSE;
        END IF;
       RETURN status;
    END f_bulk_open_slot_assign_loop; 

  /*********************************************************************** 
  ** f_bulk_avail_slot_assign_loop  
  **  Description: loop throught all avail slot and check if  
  **               space is enough for a pallet       
  **  Called By :  f_bulk_avail_slot_same_prod,f_bulk_avail_slot_assign 
  **                  
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **      1 - Failure 
  **      0 - Success 
  ****************************************************************/

    FUNCTION f_bulk_avail_slot_assign_loop (
        p_same_diff_prod NUMBER
    ) RETURN VARCHAR2 AS

        position_used     NUMBER := 0.0;
        l_index           NUMBER := 0;
        l_finish          VARCHAR2(5) := 'FALSE';
        i                 NUMBER := 0;
        inv_cnt           NUMBER := 0;
        status            NUMBER := 0;
        l_func_name       VARCHAR2(30) := 'f_bulk_Avail_slot_assign_loop';
        same_diff_prod    NUMBER;
        cube_occupied     NUMBER;
        skid_occupied     NUMBER;
        pallet_cnt        NUMBER := 0;
        exist_item_cube   NUMBER := 0;
        exist_item_flag   VARCHAR2(100);
        position_cube     NUMBER := 0.0;
        l_location        VARCHAR2(10);
        l_status          VARCHAR2(100);

    BEGIN
        same_diff_prod := p_same_diff_prod;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Bulk slot (case when same_diff_prod == SAME  ELSE different product assign loop for item'
                                            || same_diff_prod
                                            || 'g_cpv'
                                            || cust_pref_vendor, sqlcode, sqlerrm); 

/* 
** same_diff_prod = 0 came here for location with different product 
** same_diff_prod = 1 came here for location with same product 
*/

        WHILE ( l_index <= total_cnt ) LOOP
            pallet_cnt := 0;
            l_location := phys_loc;
            SELECT
                COUNT(*)
            INTO pallet_cnt
            FROM
                inv
            WHERE
                plogi_loc = l_location;

            IF ( ( put_deep_ind2 = 'N' ) ) THEN
                BEGIN
                    SELECT
                        SUM((ceil(((i.qoh + i.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i.prod_id, g_prod_id, case_cube, p.case_cube
                        ))
                    INTO cube_occupied
                    FROM
                        pm    p,
                        inv   i
                    WHERE
                        p.prod_id = i.prod_id
                        AND p.cust_pref_vendor = i.cust_pref_vendor
                        AND i.plogi_loc = l_location;

                EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get cube value.', sqlcode, sqlerrm);
                END;

                BEGIN
                    SELECT
                        nvl(SUM(pt.skid_cube), 0)
                    INTO skid_occupied
                    FROM
                        pallet_type   pt,
                        pm            p,
                        inv           i
                    WHERE
                        pt.pallet_type = p.pallet_type
                        AND p.prod_id = i.prod_id
                        AND p.cust_pref_vendor = i.cust_pref_vendor
                        AND i.plogi_loc = l_location;

                EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get skid cube value.', sqlcode, sqlerrm);
                END;

                cube_occupied := cube_occupied + skid_occupied;
                l_finish := 'TRUE';
            ELSIF ( ( put_deep_ind2 = 'Y' ) ) THEN
                BEGIN
                    SELECT
                        ( ( ceil((((i.qoh + i.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i.prod_id, g_prod_id, case_cube, p.case_cube
                        ) ) + skid_cube )
                    INTO exist_item_cube
                    FROM
                        pm    p,
                        inv   i
                    WHERE
                        p.prod_id = i.prod_id
                        AND i.plogi_loc = l_location
                        AND p.cust_pref_vendor = i.cust_pref_vendor
                    ORDER BY
                        1 DESC;

                EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get exist item cube value', sqlcode, sqlerrm);
                END;

                SELECT
                    COUNT(*)
                INTO inv_cnt
                FROM
                    pm    p,
                    inv   i
                WHERE
                    p.prod_id = i.prod_id
                    AND i.plogi_loc = l_location
                    AND p.cust_pref_vendor = i.cust_pref_vendor
                ORDER BY
                    1 DESC;

                cube_occupied := 0;
                BEGIN
                    SELECT
                        l.cube / substr(l.slot_type, 1, 1)
                    INTO position_cube
                    FROM
                        loc l
                    WHERE
                        l.logi_loc = l_location;

                EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get Position cube value', sqlcode, sqlerrm);
                END;

                FOR i IN 0..inv_cnt LOOP exist_item_flag := 'N';
                END LOOP;
                l_finish := 'FALSE';
                WHILE ( ( put_deep_factor2 != 0 ) AND l_finish = 'FALSE' ) LOOP
                    cube_occupied := 0; 
                /* 
                **  Load position with largest remaining pallet. 
                */
                    FOR i IN 0..inv_cnt LOOP IF ( exist_item_flag = 'N' ) THEN
                        cube_occupied := exist_item_cube;
                        exist_item_flag := 'Y';
                    END IF;
                    END LOOP; 
                    /* 
                    **  Determine if can stack a smaller pallet on top. 
                    */

                    FOR i IN 0..inv_cnt LOOP IF ( ( position_cube - cube_occupied >= exist_item_cube ) AND ( exist_item_flag = 'N'

                    ) ) THEN
                        cube_occupied := cube_occupied + exist_item_cube;
                        exist_item_flag := 'Y';
                    END IF;
                    END LOOP; 
                    /* 
                    **  Determine if all pallets putaway. 
                    */

                    FOR i IN 0..inv_cnt LOOP IF ( exist_item_flag = 'N' ) THEN
                        l_finish := 'FALSE';
                    ELSE
                        l_finish := 'TRUE';
                    END IF;
                    END LOOP; 
                    /* 
                    **  If more pallets, then get next position. 
                    */

                    IF ( l_finish = 'TRUE' ) THEN
                        put_deep_factor2 := put_deep_factor2 - 1;
                        loc_cube := loc_cube - position_cube;
                    END IF;

                END LOOP; /* ELSE deep slot */

            ELSE
                pl_text_log.ins_msg_async('INFO', l_func_name, ' ORACLE unable to select inv', sqlcode, sqlerrm);
                l_status := 'Unable to select from inv for plogi_loc';
                ROLLBACK;
                RETURN l_status;
            END IF;

            pl_text_log.ins_msg_async('INFO', l_func_name, '  processing loc: '
                                                || l_location
                                                || 'pallet_cnt : '
                                                || pallet_cnt, sqlcode, sqlerrm);

            IF ( put_deep_ind2 = 'N' ) THEN
                loc_cube := loc_cube - cube_occupied;
            END IF;
            WHILE ( ( l_index <= total_cnt ) AND ( current_pallet < num_pallet ) AND ( l_finish = 'TRUE' ) )
            LOOP 
            IF ( pallet_stack > pallet_cnt ) THEN
                IF ( ( put_deep_ind2 = 'N' ) AND ( round(loc_cube, 2) >= round(((ceil(each_pallet_qty / ti) * ti * case_cube) + skid_cube
                ), 2) ) ) THEN
                    p_insert_table(phys_loc, ADD_RESERVE);
                    current_pallet := current_pallet + 1;
                    pallet_cnt := pallet_cnt + 1;
                    IF ( current_pallet < num_pallet ) THEN
                        IF ( stackable > 0 ) THEN
                            loc_cube := loc_cube - ( ( ceil(each_pallet_qty / ti) * ti * case_cube ) + skid_cube );

                        END IF;
                    END IF;

                    IF ( current_pallet = ( num_pallet - 1 ) ) THEN
                        each_pallet_qty := last_pallet_qty;
                    END IF;

                ELSIF ( ( put_deep_ind2 = 'Y' ) AND ( loc_cube - cube_occupied >= ( ( ceil(each_pallet_qty / ti) * ti * case_cube

                ) + skid_cube ) ) ) THEN
                    IF ( stackable > 0 ) THEN 
              /* 
              ** item is stackable 
              ** put more pallets in the deep slot positions 
              ** based on cube 
              */
                        position_used := position_cube;
                        position_used := position_used - cube_occupied;
                        WHILE ( ( position_used >= ( ( ( ceil(each_pallet_qty / ti) * ti * case_cube ) + skid_cube ) ) ) AND ( current_pallet
                        < num_pallet ) ) LOOP
                            position_used := position_used - ( ( ceil(each_pallet_qty / ti) * ti * case_cube ) + skid_cube );

                            p_insert_table(phys_loc, ADD_RESERVE);
                            current_pallet := current_pallet + 1;
                            pallet_cnt := pallet_cnt + 1;
                            IF ( current_pallet = ( num_pallet - 1 ) ) THEN
                                each_pallet_qty := last_pallet_qty;
                            END IF;

                        END LOOP;

                    END IF; /* if stackable > 0 */

                    cube_occupied := 0;
                    IF ( put_deep_factor2 <= 0 ) THEN 
              /* 
              **  No more positions.  Go to next location 
              */
                        NULL;
                    END IF; 
          /* ELSE if deep slots */
                ELSE 
            /* 
            **  Will not fit.  Go to next location 
            */
                    NULL;
                END IF; 
        /* if can stack more */

            ELSE 
          /* 
          **  Cannot stack any more.  Go to next location 
          */
                NULL;
            END IF;
            END LOOP; /* end while current pallet*/

            l_index := l_index + 1;
        END LOOP; /* end while l_index */

        IF ( current_pallet >= num_pallet ) THEN
            status :=  C_TRUE;
        ELSE
             status :=  C_FALSE;
        END IF;
      RETURN status;
    END f_bulk_avail_slot_assign_loop; 
    
  /*********************************************************************** 
  ** f_bulk_avail_slot_same_prod  
  **  Description:  To Find all avail slot with same prod_id   
  **  Called By :  f_bulk_rule 
  **                  
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **      1 - Failure 
  **      0 - Success 
  ****************************************************************/

    FUNCTION f_bulk_avail_slot_same_prod RETURN NUMBER IS

        l_func_name   VARCHAR2(50) := 'f_bulk_avail_slot_same_prod';
        l_status      NUMBER := 0;
        length_unit   VARCHAR2(50);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Calling f_bulk_avail_slot_same_prod ' , sqlcode, sqlerrm);
        length_unit := pl_common.f_get_syspar('LENGTH_UNIT', 'IN');
        BEGIN
        SELECT DISTINCT
            l.logi_loc,
            l.cube,
            l.put_aisle,
            l.put_slot,
            l.put_level,
            DECODE(s.deep_ind, 'Y', substr(l.slot_type, 1, 1), 1),
            l.slot_type,
            s.deep_ind
        INTO
            phys_loc,
            loc_cube,
            put_aisle2,
            put_slot2,
            put_level2,
            put_deep_factor2,
            put_slot_type2,
            put_deep_ind2
        FROM
            slot_type   s,
            loc         l,
            lzone       z,
            inv         i
        WHERE
            s.slot_type = l.slot_type
            AND NOT EXISTS (
                SELECT
                    'x'
                FROM
                    inv
                WHERE
                    plogi_loc = l.logi_loc
                    AND ( dmg_ind = 'Y'
                          OR parent_pallet_id IS NOT NULL )
            )
            AND ( ( ( s.deep_ind = 'Y' )
                    AND ( lst_pallet_cube ) <= (
                SELECT
                    DECODE(sign(to_number(substr(s.slot_type, 1, 1)) - COUNT(*)), 1,
                    (l.cube -((l.cube / to_number(substr(s.slot_type
                    , 1, 1))) *(to_number(substr(s.slot_type, 1, 1)) - COUNT(*)))), 
                    DECODE(length_unit, 'CM', 99999999.9999, 99999.00))
                FROM
                    pm    p,
                    inv   i2
                WHERE
                    p.prod_id = i2.prod_id
                    AND p.cust_pref_vendor = i2.cust_pref_vendor
                    AND i2.plogi_loc = l.logi_loc
            ) )
                  OR ( ( ( s.deep_ind = 'N' )
                         AND ( l.cube - lst_pallet_cube ) >= (
                SELECT
                    SUM((ceil(((i3.qoh + i3.qty_planned) / p2.spc) / p2.ti)) * p2.ti * DECODE(i3.prod_id, g_prod_id, case_cube, p2
                    .case_cube))
                FROM
                    pm    p2,
                    inv   i3
                WHERE
                    p2.prod_id = i3.prod_id
                    AND p2.cust_pref_vendor = i3.cust_pref_vendor
                    AND i3.plogi_loc = l.logi_loc
            ) )
                       AND ( NOT EXISTS (
                SELECT
                    'x'
                FROM
                    pm    p3,
                    inv   k
                WHERE
                    p3.prod_id = k.prod_id
                    AND p3.cust_pref_vendor = k.cust_pref_vendor
                    AND p3.stackable > stackable
                    AND k.plogi_loc = i.plogi_loc
            ) ) ) )
            AND l.logi_loc = z.logi_loc
            AND l.perm = 'N'
            AND l.status = 'AVL'
            AND ( DECODE(l.pallet_type, 'FW', 'LW', l.pallet_type) = DECODE(pallet_type, 'FW', 'LW', pallet_type)
                  OR l.pallet_type IN (
                SELECT
                    mixed_pallet
                FROM
                    pallet_type_mixed ptm
                WHERE
                    ptm.pallet_type = pallet_type
            ) )
            AND z.logi_loc = i.plogi_loc
            AND z.zone_id = zone_id
            AND i.prod_id = g_prod_id
            AND i.cust_pref_vendor = l_cust_pref_vendor
            AND trunc(i.rec_date) = trunc(DECODE(s.deep_ind, 'Y', DECODE(g_mix_same_prod_deep_slot, 'Y', i.rec_date, SYSDATE), i.
            rec_date))
        ORDER BY
            l.cube,
            abs(put_aisle1 - l.put_aisle),
            l.put_aisle,
            abs(put_slot1 - l.put_slot),
            l.put_slot,
            abs(put_level1 - l.put_level),
            l.put_level;
        EXCEPTION
        WHEN OTHERS THEN
           pl_text_log.ins_msg_async('WARN', l_func_name, 'Exception in f_bulk_avail_slot_same_prod ' , sqlcode, sqlerrm);
        END;
        BEGIN
            l_status := f_bulk_avail_slot_assign_loop(0);
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'Before Selecting put_aisle and put_slot2', sqlcode, sqlerrm);
        END;

        RETURN l_status;
    END f_bulk_avail_slot_same_prod; 
    
  /***************************************************************************** 
  **  FUNCTION: 
  **      f_two_d_three_d 
  **  DESCRIPTION: 
  **      Putaway to deep slots. 
  **      2-D and 3-D putaway logic: 
  **      1. Find available slot with the same slot type and prod id and 
  **         enough cube and if syspar MIX_SAME_PROD_DEEP_SLOT is "N" then 
  **         the pallets in the slot must all have the same receive date. 
  **      2. Find open slot with the same slot type and there is not a pallet 
  **         in the slot. 
  **      3. Find available slot with the same slot type and different 
  **         prod id if the syspar MIXPROD_FLAG allows and their is enough cube. 
  **  PARAMETERS: 
  **      p_dest_loc 
  **  RETURN VALUES: 
  **      TRUE  - All the pallets for the item were successfully assigned 
  **              to a location. 
  **      FALSE - Not all the pallets for the item were successfully assigned 
  **              to a location. 
  *****************************************************************************/

    FUNCTION f_two_d_three_d (
        p_dest_loc VARCHAR2
    ) RETURN NUMBER IS

        l_func_name            VARCHAR2(20) := 'f_two_d_three_d';
        status                 NUMBER := 0;
        more                   VARCHAR2(5) := 'FALSE';
        more_slot              VARCHAR2(5) := 'TRUE';
        dest_loc               VARCHAR2(10);
        temp_cube              NUMBER := 0;
        l_mix_prod_2d3d_flag   VARCHAR2(1);
        partial_pallet         NUMBER := C_TRUE;
        l_status               VARCHAR2(100);
    BEGIN
        dest_loc := p_dest_loc;
        BEGIN
            l_mix_prod_2d3d_flag := pl_common.f_get_syspar('MIXPROD_2D3D_FLAG', 'N');
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to select mix_prod_2d3d_flag', sqlcode, sqlerrm);
                l_status := 'Unable to select mix_prod_2d3d_flag';
                ROLLBACK;
                RETURN l_status;
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'TABLE = sys_config ACTION = SELECT MESSAGE= mix_prod_2d3d_flag', sqlcode, sqlerrm); 

      /* 
      ** 1. Find available slot with the same slot type and prod id and 
      **    enough cube and if syspar MIX_SAME_PROD_DEEP_SLOT is "N" then 
      **    the pallets in the slot must all have the same receive date. 
      */
        WHILE ( more_slot = 'TRUE' ) LOOP
            more_slot := 'FALSE';
            p_clear_array();
            IF ( ( current_pallet = ( num_pallet - 1 ) ) AND partial_pallet = C_TRUE ) THEN
                temp_cube := lst_pallet_cube;
            ELSE
                temp_cube := std_pallet_cube;
            END IF; 

          /* 
          ** Fetch candidate reserve slots into host arrays. 
          */ 
          /** Added populating of loc_deep_positions.        */

            SELECT
                COUNT(*)
            INTO total_cnt
            FROM
                (
                    SELECT
                        l.logi_loc,
                        l.cube,
                        l.put_aisle,
                        l.put_slot,
                        l.put_level,
                        l.put_path,
                        s.deep_positions
                    FROM
                        slot_type   s,
                        lzone       z,
                        loc         l,
                        inv         i
                    WHERE
                        s.slot_type = l.slot_type
                        AND s.deep_ind = 'Y'
                        AND z.logi_loc = l.logi_loc
                        AND z.zone_id = zone_id
                        AND l.perm = 'N'
                        AND l.status = 'AVL'
                        AND ( l.cube - temp_cube ) >= (
                            SELECT
                                SUM((ceil(((i2.qoh + i2.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i2.prod_id, g_prod_id, case_cube
                                , p.case_cube))
                            FROM
                                pm    p,
                                inv   i2
                            WHERE
                                p.prod_id = i2.prod_id
                                AND p.cust_pref_vendor = i2.cust_pref_vendor
                                AND i2.plogi_loc = l.logi_loc
                        )
                        AND l.logi_loc = i.plogi_loc
                        AND i.cust_pref_vendor = l_cust_pref_vendor
                        AND i.prod_id = g_prod_id
                        AND trunc(i.rec_date) = trunc(DECODE(g_mix_same_prod_deep_slot, 'Y', i.rec_date, SYSDATE))
                        AND NOT EXISTS (
                            SELECT
                                'x'
                            FROM
                                inv i3
                            WHERE
                                i3.plogi_loc = i.plogi_loc
                                AND ( i3.prod_id != g_prod_id
                                      OR i3.cust_pref_vendor != l_cust_pref_vendor )
                        )
                    ORDER BY
                        l.cube,
                        abs(put_aisle1 - l.put_aisle),
                        l.put_aisle,
                        abs(put_slot1 - l.put_slot),
                        l.put_slot,
                        abs(put_level1 - l.put_level),
                        l.put_level
                ) tn_cnt;

            SELECT
                l.logi_loc,
                l.cube,
                l.put_aisle,
                l.put_slot,
                l.put_level,
                l.put_path,
                s.deep_positions
            INTO
                phys_loc,
                loc_cube,
                put_aisle2,
                put_slot2,
                put_level2,
                put_path2,
                loc_deep_positions
            FROM
                slot_type   s,
                lzone       z,
                loc         l,
                inv         i
            WHERE
                s.slot_type = l.slot_type
                AND s.deep_ind = 'Y'
                AND z.logi_loc = l.logi_loc
                AND z.zone_id = zone_id
                AND l.perm = 'N'
                AND l.status = 'AVL'
                AND ( l.cube - temp_cube ) >= (
                    SELECT
                        SUM((ceil(((i2.qoh + i2.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i2.prod_id, g_prod_id, case_cube, p
                        .case_cube))
                    FROM
                        pm    p,
                        inv   i2
                    WHERE
                        p.prod_id = i2.prod_id
                        AND p.cust_pref_vendor = i2.cust_pref_vendor
                        AND i2.plogi_loc = l.logi_loc
                )
                AND l.logi_loc = i.plogi_loc
                AND i.cust_pref_vendor = l_cust_pref_vendor
                AND i.prod_id = g_prod_id
                AND trunc(i.rec_date) = trunc(DECODE(g_mix_same_prod_deep_slot, 'Y', i.rec_date, SYSDATE))
                AND NOT EXISTS (
                    SELECT
                        'x'
                    FROM
                        inv i3
                    WHERE
                        i3.plogi_loc = i.plogi_loc
                        AND ( i3.prod_id != g_prod_id
                              OR i3.cust_pref_vendor != l_cust_pref_vendor )
                )
            ORDER BY
                l.cube,
                abs(put_aisle1 - l.put_aisle),
                l.put_aisle,
                abs(put_slot1 - l.put_slot),
                l.put_slot,
                abs(put_level1 - l.put_level),
                l.put_level;

            IF ( loc_cube IS NOT NULL OR ( loc_cube IS NULL AND ( total_cnt > 0 ) ) ) THEN
                IF ( loc_cube IS NOT NULL ) THEN
                    more := 'TRUE';
                ELSE
                    more := 'FALSE';
                END IF;

                total_cnt := total_cnt - 1;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'TABLE = loc,inv  ACTION = SELECT MESSAGE= remaining pallets'
                                                    || num_pallet
                                                    || 'matching same item slots '
                                                    || total_cnt + 1, sqlcode, sqlerrm); 

            /* Process the records selected into the host arrays. */

                status := f_deep_slot_assign_loop(0);
            ELSE
                pl_text_log.ins_msg_async('INFO', l_func_name, 'TABLE = loc,inv  ACTION = SELECT MESSAGE= ORACLE no matching deep slots with same item found in zone'
                , sqlcode, sqlerrm);
            END IF;

        END LOOP; 

/*   ** 2. Find open slot with the same slot type and there is not a pallet   **    in the slot.   */

        more_slot := 'TRUE';
        WHILE ( status = 'FALSE' AND more_slot = 'TRUE' ) LOOP
            more_slot := 'FALSE';
            p_clear_array();
            SELECT
                COUNT(*)
            INTO total_cnt
            FROM
                (
                    SELECT
                        l.logi_loc,
                        l.cube,
                        l.put_slot,
                        l.put_level,
                        p.cube,
                        l.put_path,
                        s.deep_positions
                    FROM
                        pallet_type   p,
                        slot_type     s,
                        loc           l,
                        lzone         z
                    WHERE
                        p.pallet_type = l.pallet_type
                        AND s.slot_type = l.slot_type
                        AND s.deep_ind = 'Y'
                        AND l.perm = 'N'
                        AND l.status = 'AVL'
                        AND round(l.cube / s.deep_positions, 2) >= round(std_pallet_cube, 2)
                        AND l.logi_loc = z.logi_loc
                        AND z.zone_id = zone_id
                        AND NOT EXISTS (
                            SELECT
                                'x'
                            FROM
                                inv
                            WHERE
                                plogi_loc = l.logi_loc
                        )
                    ORDER BY
                        p.cube,
                        l.cube,
                        abs(put_aisle1 - l.put_aisle),
                        l.put_aisle,
                        abs(put_slot1 - l.put_slot),
                        l.put_slot,
                        abs(put_level1 - l.put_level),
                        l.put_level
                ) tn_cnt;

            SELECT
                l.logi_loc,
                l.cube,
                l.put_slot,
                l.put_level,
                p.cube,
                l.put_path,
                s.deep_positions
            INTO
                phys_loc,
                loc_cube,
                put_slot2,
                put_level2,
                pcube,
                put_path2,
                loc_deep_positions
            FROM
                pallet_type   p,
                slot_type     s,
                loc           l,
                lzone         z
            WHERE
                p.pallet_type = l.pallet_type
                AND s.slot_type = l.slot_type
                AND s.deep_ind = 'Y'
                AND l.perm = 'N'
                AND l.status = 'AVL'
                AND round(l.cube / s.deep_positions, 2) >= round(std_pallet_cube, 2)
                AND l.logi_loc = z.logi_loc
                AND z.zone_id = zone_id
                AND NOT EXISTS (
                    SELECT
                        'x'
                    FROM
                        inv
                    WHERE
                        plogi_loc = l.logi_loc
                )
            ORDER BY
                p.cube,
                l.cube,
                abs(put_aisle1 - l.put_aisle),
                l.put_aisle,
                abs(put_slot1 - l.put_slot),
                l.put_slot,
                abs(put_level1 - l.put_level),
                l.put_level;

            IF ( loc_cube IS NOT NULL OR ( loc_cube IS NULL AND ( total_cnt > 0 ) ) ) THEN 
      /*  ** Found open slots meeting the criteria.        */
                IF ( loc_cube IS NOT NULL ) THEN
                    more := 'TRUE'; 
      /* Filled the arrays and there could be more 
                                                            available slots. */
                ELSE
                    more := 'FALSE'; /* Found all the available slots. */
                END IF;

                total_cnt := total_cnt - 1; 

      /* The actual record count is  total_cnt + 1.  1 is 
                                                      substracted because of how  total_cnt is used with the   array index. */
                pl_text_log.ins_msg_async('INFO', l_func_name, 'remaining pallets= '
                                                    || num_pallet
                                                    || ' , open matching deep slots= '
                                                    || total_cnt + 1, sqlcode, sqlerrm); 

      /* Process the records selected into the host arrays. */

                status := f_two_d_three_d_open_slot();
            ELSE
                pl_text_log.ins_msg_async('INFO', l_func_name, 'TABLE = loc,inv  ACTION = SELECT MESSAGE= ORACLE No open matching deep slots found in zone'
                , sqlcode, sqlerrm);
            END IF;

        END LOOP; 

        /* 
        ** 3. Find available slot with different prod if 2d3d_mixprod_flag is on. 
        */

        IF ( l_mix_prod_2d3d_flag = 'Y' ) THEN
            more_slot := 'TRUE';
            WHILE ( ( status = 'FALSE' ) AND more_slot = 'TRUE' ) LOOP
                more_slot := 'FALSE';
                p_clear_array();
                IF ( ( current_pallet = ( num_pallet - 1 ) ) AND partial_pallet = C_TRUE ) THEN
                    temp_cube := lst_pallet_cube;
                ELSE
                    temp_cube := std_pallet_cube;
                END IF;

                SELECT
                    COUNT(*)
                INTO total_cnt
                FROM
                    (
                        SELECT
                            l.logi_loc,
                            l.cube,
                            l.put_aisle,
                            l.put_slot,
                            l.put_level,
                            l.put_path,
                            s.deep_positions
                        FROM
                            pallet_type   pt,
                            slot_type     s,
                            loc           l,
                            lzone         z,
                            inv           i
                        WHERE
                            pt.pallet_type = l.pallet_type
                            AND s.slot_type = l.slot_type
                            AND s.deep_ind = 'Y'
                            AND l.logi_loc = z.logi_loc
                            AND l.perm = 'N'
                            AND l.status = 'AVL'
                            AND ( l.cube - temp_cube ) >= (
                                SELECT
                                    SUM((ceil(((i2.qoh + i2.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i2.prod_id, g_prod_id,
                                    case_cube, p.case_cube))
                                FROM
                                    pm    p,
                                    inv   i2
                                WHERE
                                    p.prod_id = i2.prod_id
                                    AND p.cust_pref_vendor = i2.cust_pref_vendor
                                    AND i2.plogi_loc = l.logi_loc
                            )
                            AND z.logi_loc = i.plogi_loc
                            AND z.zone_id = zone_id
                            AND ( i.prod_id <> g_prod_id
                                  OR i.cust_pref_vendor <> l_cust_pref_vendor )
                            AND ( g_mix_same_prod_deep_slot = 'Y'
                                  OR NOT EXISTS (
                                SELECT
                                    'x'
                                FROM
                                    inv i3
                                WHERE
                                    i3.plogi_loc = i.plogi_loc
                                    AND i3.prod_id = g_prod_id
                                    AND i3.cust_pref_vendor = l_cust_pref_vendor
                                    AND trunc(i3.rec_date) != trunc(SYSDATE)
                            ) )
                        ORDER BY
                            pt.cube,
                            l.cube,
                            abs(put_aisle1 - l.put_aisle),
                            l.put_aisle,
                            abs(put_slot1 - l.put_slot),
                            l.put_slot,
                            abs(put_level1 - l.put_level),
                            l.put_level
                    ) tn_cnt;

                SELECT
                    l.logi_loc,
                    l.cube,
                    l.put_aisle,
                    l.put_slot,
                    l.put_level,
                    l.put_path,
                    s.deep_positions
                INTO
                    phys_loc,
                    loc_cube,
                    put_aisle2,
                    put_slot2,
                    put_level2,
                    put_path2,
                    loc_deep_positions
                FROM
                    pallet_type   pt,
                    slot_type     s,
                    loc           l,
                    lzone         z,
                    inv           i
                WHERE
                    pt.pallet_type = l.pallet_type
                    AND s.slot_type = l.slot_type
                    AND s.deep_ind = 'Y'
                    AND l.logi_loc = z.logi_loc
                    AND l.perm = 'N'
                    AND l.status = 'AVL'
                    AND ( l.cube - temp_cube ) >= (
                        SELECT
                            SUM((ceil(((i2.qoh + i2.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i2.prod_id, g_prod_id, case_cube
                            , p.case_cube))
                        FROM
                            pm    p,
                            inv   i2
                        WHERE
                            p.prod_id = i2.prod_id
                            AND p.cust_pref_vendor = i2.cust_pref_vendor
                            AND i2.plogi_loc = l.logi_loc
                    )
                    AND z.logi_loc = i.plogi_loc
                    AND z.zone_id = zone_id
                    AND ( i.prod_id <> g_prod_id
                          OR i.cust_pref_vendor <> l_cust_pref_vendor )
                    AND ( g_mix_same_prod_deep_slot = 'Y'
                          OR NOT EXISTS (
                        SELECT
                            'x'
                        FROM
                            inv i3
                        WHERE
                            i3.plogi_loc = i.plogi_loc
                            AND i3.prod_id = g_prod_id
                            AND i3.cust_pref_vendor = l_cust_pref_vendor
                            AND trunc(i3.rec_date) != trunc(SYSDATE)
                    ) )
                ORDER BY
                    pt.cube,
                    l.cube,
                    abs(put_aisle1 - l.put_aisle),
                    l.put_aisle,
                    abs(put_slot1 - l.put_slot),
                    l.put_slot,
                    abs(put_level1 - l.put_level),
                    l.put_level;

                IF ( loc_cube IS NOT NULL OR ( loc_cube IS NULL ) AND ( total_cnt > 0 ) ) THEN
                    IF ( loc_cube IS NOT NULL ) THEN
                        more := 'TRUE';
                    ELSE
                        more := 'FALSE';
                    END IF;

                    total_cnt := total_cnt - 1;
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'TABLE = loc,inv  ACTION = SELECT MESSAGE= matching different item deep slots'
                    , sqlcode, sqlerrm); 

  /* Process the records selected into the host arrays. */
                    status := f_deep_slot_assign_loop(0);
                ELSE
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'TABLE = loc,inv  ACTION = SELECT MESSAGE= ORACLE no matching deep slots with different item found in zone'
                    , sqlcode, sqlerrm);
                END IF;

            END LOOP; /* End while more to process */

        END IF; /* If l_mix_prod_2d3d_flag = 'Y' */

        RETURN status;
    END f_two_d_three_d; 
    
  /***************************************************************************** 
  **   f_assign_MSKU_putaway_slots 
  **  DESCRIPTION: 
  **      This function will call PL_MSKU.ASSIGN_MSKU_PUTAWAY_SLOTS passing 
  **      the SN_ID as the input. 
  **  PARAMETERS: 
  **      sn_no           Shipment Notification Id. 
  **  RETURN VALUES: 
  **       0  - if no errors in call to ASSIGN_MSKU_PUTAWAY_SLOTS 
  **      -1  - if call RETURNed with errors. 
  *****************************************************************************/

    FUNCTION f_assign_msku_putaway_slots (
        c_sn_no VARCHAR2
    ) RETURN NUMBER IS

        l_func_name         VARCHAR2(30) := 'f_assign_msku_putaway_slots';
        o_error             BOOLEAN;
        o_crt_message       VARCHAR2(4000);
        parent_pallet_arr   pl_msku.t_parent_pallet_id_arr;
        status              NUMBER := 0;
        hsz_crt_message     VARCHAR2(4000);
        hi_o_error          NUMBER;
        hsz_sn_no           VARCHAR2(13);
    BEGIN
        hsz_sn_no := substr(c_sn_no, 1, 12);
        BEGIN
            pl_msku.p_assign_msku_putaway_slots(hsz_sn_no, parent_pallet_arr, o_error, o_crt_message);
            IF o_error THEN
                hi_o_error := 1;
                hsz_crt_message := o_crt_message;
            ELSE
                hi_o_error := 0;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                hi_o_error := 1;
                hsz_crt_message := o_crt_message
                                   || 'SQLCODE='
                                   || sqlcode
                                   || ' SQLERRM='
                                   || sqlerrm;
        END;

        IF ( hi_o_error = 1 ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'p_assign_msku_putaway_slots Returned with errors' ||
            hsz_crt_message, sqlcode, sqlerrm);
            status := -1;
        ELSE
            status := 0;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Returned from p_assign_msku_putaway_slots successfully', sqlcode, sqlerrm);
        END IF;

        return(status);
    END f_assign_msku_putaway_slots; 
    
  /***************************************************************************** 
  **   f_avail_slot_assign_loop 
  **  DESCRIPTION: 
  **     ** loop through all avail slots and check if 
  ** space is enough for a pallet 
  **  Called by : f_check_avail_slot_same_prod 
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **      TRUE  - Success. 
  **      FALSE - Failure 
  *****************************************************************************/

    FUNCTION f_avail_slot_assign_loop (
        flag NUMBER
    ) RETURN VARCHAR2 AS

        l_func_name     VARCHAR2(30) := 'f_avail_slot_assign_loop';
        cube_occupied   NUMBER;
        skid_occupied   NUMBER;
        location        VARCHAR2(10);
        old_loc         VARCHAR2(10);
        pallet_cnt      NUMBER := 0;
        l_index         NUMBER := 0;
        status           NUMBER := 0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside f_avail_slot_assign_loop with flag = ' || flag, sqlcode, sqlerrm);
        location := phys_loc;
        IF ( flag = 1 ) THEN
            SELECT
                COUNT(*)
            INTO pallet_cnt
            FROM
                inv
            WHERE
                plogi_loc = location;

            SELECT
                SUM((ceil(((i.qoh + i.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i.prod_id, g_prod_id, case_cube, p.case_cube
                ))
            INTO cube_occupied
            FROM
                pm    p,
                inv   i
            WHERE
                p.prod_id = i.prod_id
                AND p.cust_pref_vendor = i.cust_pref_vendor
                AND i.plogi_loc = location;

            SELECT
                nvl(SUM(pt.skid_cube), 0)
            INTO skid_occupied
            FROM
                pallet_type   pt,
                pm            p,
                inv           i
            WHERE
                pt.pallet_type = p.pallet_type
                AND p.prod_id = i.prod_id
                AND p.cust_pref_vendor = i.cust_pref_vendor
                AND i.plogi_loc = location;

            cube_occupied := cube_occupied + skid_occupied;
        END IF;

        IF ( cube_occupied IS NOT NULL ) AND ( skid_occupied IS NOT NULL ) THEN
            BEGIN
                loc_cube := loc_cube - cube_occupied; 

            /* 
                   ** Start putting stuff away in the remaining space 
            */
                IF ( ( l_index <= total_cnt ) AND ( current_pallet < num_pallet ) AND ( ( max_slot > slot_cnt ) OR ( flag = 1 ) )
                ) THEN
                    IF ( ( loc_cube >= ( ( ceil(each_pallet_qty / ti) ) * ti * case_cube ) + skid_cube ) AND pallet_stack > pallet_cnt
                    ) THEN 
                /* 
                              ** update-insert data into tables for locations 
                              */
                        p_insert_table(phys_loc, ADD_RESERVE);
                        current_pallet := current_pallet + 1;
                        pallet_cnt := pallet_cnt + 1;
                        IF ( ( location = old_loc ) AND ( flag = 0 ) ) THEN
                            slot_cnt := slot_cnt + 1;
                            old_loc := location;
                        END IF;

                        IF ( ( current_pallet < num_pallet ) AND ( stackable > 0 ) ) THEN
                            loc_cube := loc_cube - ( ( ( ceil(each_pallet_qty / ti) ) * ti * case_cube ) + skid_cube );

                            IF ( current_pallet = ( num_pallet - 1 ) ) THEN
                                each_pallet_qty := last_pallet_qty;
                            END IF;

                        ELSE
                            pallet_cnt := 0;
                            IF ( l_index <= total_cnt ) THEN
                                location := phys_loc;
                                IF ( flag = 1 ) THEN
                                    BEGIN
                                        SELECT
                                            COUNT(*)
                                        INTO pallet_cnt
                                        FROM
                                            inv
                                        WHERE
                                            plogi_loc = location;

                                        SELECT
                                            nvl(SUM(pt.skid_cube), 0)
                                        INTO skid_occupied
                                        FROM
                                            pallet_type   pt,
                                            pm            p,
                                            inv           i
                                        WHERE
                                            pt.pallet_type = p.pallet_type
                                            AND p.prod_id = i.prod_id
                                            AND p.cust_pref_vendor = i.cust_pref_vendor
                                            AND i.plogi_loc = location;

                                        SELECT
                                            SUM((ceil(((i.qoh + i.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i.prod_id, g_prod_id
                                            , case_cube, p.case_cube))
                                        INTO cube_occupied
                                        FROM
                                            pm    p,
                                            inv   i
                                        WHERE
                                            p.prod_id = i.prod_id
                                            AND p.cust_pref_vendor = i.cust_pref_vendor
                                            AND i.plogi_loc = location; 

                          /* add skid to stuff in location */

                                        cube_occupied := cube_occupied + skid_occupied;
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            loc_cube := loc_cube - cube_occupied;
                                    END;

                                END IF;

                            END IF;

                        END IF;

                    ELSE
                        pallet_cnt := 0;
                        IF ( l_index <= total_cnt ) THEN
                            location := phys_loc;
                            IF ( flag = 1 ) THEN
                                BEGIN
                                    SELECT
                                        COUNT(*)
                                    INTO pallet_cnt
                                    FROM
                                        inv
                                    WHERE
                                        plogi_loc = location;

                                    SELECT
                                        nvl(SUM(pt.skid_cube), 0)
                                    INTO skid_occupied
                                    FROM
                                        pallet_type   pt,
                                        pm            p,
                                        inv           i
                                    WHERE
                                        pt.pallet_type = p.pallet_type
                                        AND p.prod_id = i.prod_id
                                        AND p.cust_pref_vendor = i.cust_pref_vendor
                                        AND i.plogi_loc = location;

                                    SELECT
                                        SUM((ceil(((i.qoh + i.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i.prod_id, g_prod_id
                                        , case_cube, p.case_cube))
                                    INTO cube_occupied
                                    FROM
                                        pm    p,
                                        inv   i
                                    WHERE
                                        p.prod_id = i.prod_id
                                        AND p.cust_pref_vendor = i.cust_pref_vendor
                                        AND i.plogi_loc = location;

                                    cube_occupied := cube_occupied + skid_occupied;
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        loc_cube := loc_cube - cube_occupied;
                                END;

                            END IF;

                        END IF;

                    END IF;

                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'unable to get cube occupied for inventory at loc', sqlcode, sqlerrm);
            END;
        END IF;

        IF ( current_pallet >= num_pallet ) THEN
            status := C_TRUE;
        ELSE
            status := C_FALSE;
        END IF;
        RETURN status;
    END f_avail_slot_assign_loop; 
    
  /***************************************************************************** 
  **   f_avail_slot_assign_loop 
  **  DESCRIPTION: 
  **       Assign items to locations         
  **  
  **  Called by : f_check_avail_slot 
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **      TRUE  - Success. 
  **      FALSE - Failure 
  *****************************************************************************/

    FUNCTION f_avail_slot_assign_loop RETURN VARCHAR2 IS

        l_index         NUMBER := 0;
        l_func_name     VARCHAR2(50) := 'f_avail_slot_assign_loop';
        cube_occupied   NUMBER;
        skid_occupied   NUMBER;
        location        VARCHAR2(10);
        old_loc         VARCHAR2(10);
        pallet_cnt      NUMBER := 0;
        l_status        VARCHAR2(100);
        status         NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside f_avail_slot_diff_prod_assign_loop ', sqlcode, sqlerrm);
        location := phys_loc;
        BEGIN
            SELECT
                SUM((ceil(((i.qoh + i.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i.prod_id, g_prod_id, case_cube, p.case_cube
                ))
            INTO cube_occupied
            FROM
                pm    p,
                inv   i
            WHERE
                p.prod_id = i.prod_id
                AND p.cust_pref_vendor = i.cust_pref_vendor
                AND i.plogi_loc = location;

            SELECT
                nvl(SUM(pt.skid_cube), 0)
            INTO skid_occupied
            FROM
                pallet_type   pt,
                pm            p,
                inv           i
            WHERE
                pt.pallet_type = p.pallet_type
                AND p.prod_id = i.prod_id
                AND p.cust_pref_vendor = i.cust_pref_vendor
                AND i.plogi_loc = location;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'Unable to fetch cube_occupied', sqlcode, sqlerrm);
        END;

        cube_occupied := cube_occupied + skid_occupied;
        IF ( cube_occupied IS NOT NULL ) THEN
            loc_cube := loc_cube - cube_occupied;
            WHILE ( ( l_index <= total_cnt ) AND ( current_pallet < num_pallet ) AND ( max_slot > slot_cnt ) ) LOOP IF ( ( loc_cube
            >= ( ( ( ceil(each_pallet_qty / ti) ) * ti * case_cube ) + skid_cube ) ) AND ( pallet_stack > pallet_cnt ) ) THEN
                p_insert_table(phys_loc, ADD_RESERVE);
                current_pallet := current_pallet + 1;
                pallet_cnt := pallet_cnt + 1;
                IF ( current_pallet = ( num_pallet - 1 ) ) THEN
                    each_pallet_qty := last_pallet_qty;
                END IF;

                IF ( location <> old_loc ) THEN
                    slot_cnt := slot_cnt + 1;
                    old_loc := location;
                END IF;

                IF ( ( current_pallet < num_pallet ) AND ( stackable > 0 ) ) THEN
                    loc_cube := loc_cube - ( ( ( ceil(each_pallet_qty / ti) ) * ti * case_cube ) + skid_cube );

                    IF ( current_pallet = ( num_pallet - 1 ) ) THEN
                        each_pallet_qty := last_pallet_qty;
                    END IF;

                ELSE
                    pallet_cnt := 0;
                    l_index := l_index + 1;
                    IF ( l_index <= total_cnt ) THEN
                        location := phys_loc;
                        SELECT
                            nvl(SUM(pt.skid_cube), 0)
                        INTO skid_occupied
                        FROM
                            pallet_type   pt,
                            pm            p,
                            inv           i
                        WHERE
                            pt.pallet_type = p.pallet_type
                            AND p.prod_id = i.prod_id
                            AND p.cust_pref_vendor = i.cust_pref_vendor
                            AND i.plogi_loc = location;

                        SELECT
                            SUM((ceil(((i.qoh + i.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i.prod_id, g_prod_id, case_cube,
                            p.case_cube))
                        INTO cube_occupied
                        FROM
                            pm    p,
                            inv   i
                        WHERE
                            p.prod_id = i.prod_id
                            AND p.cust_pref_vendor = i.cust_pref_vendor
                            AND i.plogi_loc = location;

                        cube_occupied := cube_occupied + skid_occupied;
                        loc_cube := loc_cube - cube_occupied;
                    END IF;

                END IF;

            ELSE
                l_index := l_index + 1;
                pallet_cnt := 0;
                IF ( l_index <= total_cnt ) THEN
                    location := phys_loc;
                    BEGIN
                        SELECT
                            nvl(SUM(pt.skid_cube), 0)
                        INTO skid_occupied
                        FROM
                            pallet_type   pt,
                            pm            p,
                            inv           i
                        WHERE
                            pt.pallet_type = p.pallet_type
                            AND p.prod_id = i.prod_id
                            AND p.cust_pref_vendor = i.cust_pref_vendor
                            AND i.plogi_loc = location;

                    EXCEPTION
                        WHEN no_data_found THEN
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get skid cube value.', sqlcode, sqlerrm);
                    END;

                    BEGIN
                        SELECT
                            SUM((ceil(((i.qoh + i.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i.prod_id, g_prod_id, case_cube,
                            p.case_cube))
                        INTO cube_occupied
                        FROM
                            pm    p,
                            inv   i
                        WHERE
                            p.prod_id = i.prod_id
                            AND p.cust_pref_vendor = i.cust_pref_vendor
                            AND i.plogi_loc = location;

                    EXCEPTION
                        WHEN no_data_found THEN
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'unable to get cube occupied for slot for inventory', sqlcode, sqlerrm
                            );
                            l_status := 'Unable to select from inv for plogi_loc';
                            ROLLBACK;
                            RETURN l_status;
                    END;

                    cube_occupied := cube_occupied + skid_occupied;
                    loc_cube := loc_cube - cube_occupied;
                END IF;

            END IF;
            END LOOP;

        END IF;

        IF ( current_pallet >= num_pallet ) THEN
            status := C_TRUE;
        ELSE
            status := C_FALSE;
        END IF;
     RETURN status;
    END f_avail_slot_assign_loop;
    
  /***************************************************************************** 
   **   f_avail_slot_assign_loop 
   **  DESCRIPTION: 
   **        Find available (non-open) slot of the same aisle            
   **        with same prod_id as putaway slot  
   **  Called by : f_gereneral_rule 
   **  PARAMETERS: 
   **      
   **  RETURN VALUES: 
   **      TRUE  - Success. 
   **      FALSE - Failure 
   *****************************************************************************/

    FUNCTION f_check_avail_slot_same_prod RETURN VARCHAR2 AS

        l_func_name   VARCHAR2(50) := 'f_check_avail_slot_same_prod';
        status        VARCHAR2(5);
        more          NUMBER := 0;
        more_slot     VARCHAR2(5) := 'TRUE';
        temp_cube     NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside f_check_avail_slot_same_prod ', sqlcode, sqlerrm);
        length_unit := pl_common.f_get_syspar('LENGTH_UNIT', 'IN'); 

      /************************************************************************* 
         ** If there are more pallets need to find putaway slot 
         ** search through locations of the same aisle with enough space for a 
         ** pallet with same prod_id, and put all those location into array from 
         ** nearest to farest 
         **************************************************************************/
        IF ( more_slot = 'TRUE' ) THEN
            more_slot := 'FALSE';
            IF ( ( current_pallet = ( num_pallet - 1 ) ) AND ( partial_pallet = C_TRUE ) ) THEN
                temp_cube := lst_pallet_cube;
            ELSE
                temp_cube := std_pallet_cube;
            END IF;

            p_clear_array(); 

      /* 
      ** OSD changes the slots which have damaged pallets 
      **in them should not be chosen for putting away regular 
      **pallets so introduced the check for dmg_ind which would 
      **be Y if the slot has a damaged pallet in it 
      */ 
        /* Select into host arrays. */
            BEGIN
                SELECT DISTINCT
                    l.logi_loc,
                    l.cube,
                    l.put_aisle,
                    l.put_slot,
                    l.put_level,
                    l.put_path
                INTO
                    phys_loc,
                    loc_cube,
                    put_aisle2,
                    put_slot2,
                    put_level2,
                    put_path2
                FROM
                    slot_type   s,
                    loc         l,
                    lzone       z,
                    inv         i
                WHERE
                    s.slot_type = l.slot_type
                    AND s.deep_ind = 'N'
                    AND l.perm = 'N'
                    AND l.status = 'AVL'
                    AND ( l.cube - temp_cube ) >= (
                        SELECT
                            DECODE(ext_case_cube_flag, 'Y', DECODE(sign(SUM(p.ti * p.hi * DECODE(i2.prod_id, g_prod_id, case_cube
                            , p.case_cube)) - SUM((ceil(((i2.qoh + i2.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i2.prod_id, g_prod_id
                            , case_cube, p.case_cube))), 1, SUM((ceil(((i2.qoh + i2.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE
                            (i2.prod_id, g_prod_id, case_cube, p.case_cube)), DECODE(length_unit, 'CM', 99999999.9999, 99999.99))
                            , SUM((ceil(((i2.qoh + i2.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i2.prod_id, g_prod_id, case_cube
                            , p.case_cube)))
                        FROM
                            pm    p,
                            inv   i2
                        WHERE
                            p.prod_id = i2.prod_id
                            AND p.cust_pref_vendor = i2.cust_pref_vendor
                            AND i2.plogi_loc = l.logi_loc
                    )
                    AND l.logi_loc = z.logi_loc
                    AND z.logi_loc = i.plogi_loc
                    AND z.zone_id = zone_id
                    AND i.prod_id = g_prod_id
                    AND i.cust_pref_vendor = l_cust_pref_vendor
                    AND NOT EXISTS (
                        SELECT
                            'x'
                        FROM
                            inv
                        WHERE
                            plogi_loc = l.logi_loc
                            AND ( dmg_ind = 'Y'
                                  OR parent_pallet_id IS NOT NULL )
                    )
                    AND NOT EXISTS (
                        SELECT
                            'x'
                        FROM
                            pm    p2,
                            inv   k
                        WHERE
                            p2.prod_id = k.prod_id
                            AND ( p2.stackable > stackable
                                  OR p2.stackable = 0 )
                            AND p2.cust_pref_vendor = k.cust_pref_vendor
                            AND k.plogi_loc = i.plogi_loc
                    )
                ORDER BY
                    l.cube,
                    abs(put_aisle1 - l.put_aisle),
                    l.put_aisle,
                    abs(put_slot1 - l.put_slot),
                    l.put_slot,
                    abs(put_level1 - l.put_level),
                    l.put_level;

                more := 'TRUE';
                status := f_avail_slot_assign_loop(1);
            EXCEPTION
                WHEN OTHERS THEN
                    more := 'FALSE';
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'No slots having same item in zone with correct stackability', sqlcode, sqlerrm
                    );
            END;

        END IF;

        RETURN status;
    END f_check_avail_slot_same_prod; 
    
  /***************************************************************************** 
   **      f_check_home_item 
  **  DESCRIPTION: 
  **      This function determines if there are slots to attempt to assign 
  **      the item to. 
  ** 
  **      Called by: f_find_putaway_slot 
  **  PARAMETERS: 
  **      days - # of item aging days 
  **  RETURN VALUES: 
  **      TRUE for the following: 
  **           - The item has a home slot for cases (uom = 0 or 2). 
  **           - The item does not have a home slot but has a putaway zone 
  **             and last ship slot and both are valid and the rule id for the 
  **             putaway zone is 1 (the item is a floating item). 
  **           - The item does not have a home slot but has a putaway zone 
  **             and no last ship slot and the putaway zone is valid and 
  **             the rule id for the putaway zone is 1 (the item is a 
  **             floating item). 
  **      - D#10399 If # of days > 0, no matter what kind of location the 
  **        item has. 
  **      FALSE if the above is not met. 
  *****************************************************************************/

    FUNCTION f_check_home_item (
        days NUMBER
    ) RETURN VARCHAR2 AS

        l_func_name   VARCHAR2(30) := 'f_check_home_item';
        home_item     VARCHAR2(5) := 'FALSE';
        error         NUMBER := 0;
        logi_loc      VARCHAR2(10);
        rule_id       NUMBER := -1;
    BEGIN
    pl_text_log.ins_msg_async('INFO',l_func_name,'statrting f_check_home_item prodid = ' || g_prod_id || ' CPV = ' || cust_pref_vendor , sqlcode, sqlerrm);
        BEGIN
            SELECT
                l.logi_loc
            INTO logi_loc
            FROM
                loc l
            WHERE
                l.uom IN (
                    0,
                    2
                )
                AND l.cust_pref_vendor = cust_pref_vendor
                AND l.prod_id = g_prod_id;
            
        IF ( days > 0) THEN
            home_item := 'TRUE';
        END IF;    
            
        EXCEPTION
            WHEN no_data_found THEN
              pl_text_log.ins_msg_async('INFO',l_func_name,'No data found f_check_home_item' , sqlcode, sqlerrm);
                IF ( ( l_zone_id IS NOT NULL ) AND ( last_ship_slot IS NOT NULL ) ) THEN
                  pl_text_log.ins_msg_async('INFO',l_func_name,'last_ship_slot not null f_check_home_item' , sqlcode, sqlerrm);
                    BEGIN
                        SELECT
                            rule_id
                        INTO rule_id
                        FROM
                            zone    z,
                            lzone   lz
                        WHERE
                            z.zone_id = lz.zone_id
                            AND lz.zone_id = l_zone_id
                            AND lz.logi_loc = last_ship_slot;

                    EXCEPTION
                        WHEN OTHERS THEN
                              pl_text_log.ins_msg_async('INFO',l_func_name,'when others last_ship_slot not null f_check_home_item' , sqlcode, sqlerrm);
                            home_item := 'FALSE';
                            rule_id := '';
                    END;

                ELSIF ( l_zone_id IS NOT NULL ) THEN
                      pl_text_log.ins_msg_async('INFO',l_func_name,'l_zoneid not null f_check_home_item' , sqlcode, sqlerrm);
            
                    BEGIN
                        SELECT
                            rule_id
                        INTO rule_id
                        FROM
                            zone
                        WHERE
                            zone_id = l_zone_id;
                       pl_text_log.ins_msg_async('INFO', l_func_name, ' Rule = ' || rule_id, sqlcode, sqlerrm);
                     EXCEPTION
                        WHEN OTHERS THEN
                              pl_text_log.ins_msg_async('INFO',l_func_name,'when others l_zone_id null f_check_home_item' , sqlcode, sqlerrm);
            
                            home_item := 'FALSE';
                            rule_id := '';
                    END;    
                    
                    pl_text_log.ins_msg_async('INFO',l_func_name,'final rule_id = ' || rule_id, sqlcode, sqlerrm);
            
                    
                IF  rule_id = 1  THEN
                    home_item := 'TRUE';
                ELSE
                    home_item := 'FALSE';
                END IF;
            END IF;
            WHEN OTHERS THEN
            
                error := 1;
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in fetching logi_loc', sqlcode, sqlerrm);
        END;
      pl_text_log.ins_msg_async('INFO', l_func_name, 'days = ' || days || ' error = ' || error || ' Rule = ' || rule_id, sqlcode, sqlerrm);
   
        IF ( home_item = 'FALSE' ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to find home slot for non-floating item. prod_id = '||g_prod_id, sqlcode, sqlerrm);
        END IF;

        return(home_item);
    END f_check_home_item; 
    
  /***************************************************************************** 
     **   f_check_home_slot 
     **  DESCRIPTION: 
     **        Check Home slot             
     **        
     **  Called by : f_gereneral_rule 
     **  PARAMETERS: 
     **      
     **  RETURN VALUES: 
     **      TRUE  - Success. 
     **      FALSE - Failure 
     *****************************************************************************/

    FUNCTION f_check_home_slot (
        p_dest_loc VARCHAR2,
        p_home_loc_cube NUMBER
    ) RETURN VARCHAR2 IS

        l_func_name           VARCHAR2(30) := 'f_check_home_slot';
        pallet_qty            NUMBER;
        home_loc_cube         NUMBER;
        dest_loc              VARCHAR2(10);
        l_ch_threshold_flag   VARCHAR2(5);
        l_i_max_qty           NUMBER := 0;
        qty_planned           NUMBER := 0;
        qty_oh                NUMBER := 0;
        fifo_item_qoh         NUMBER := 0;
        cube_used             NUMBER := 0;
        status                NUMBER := 0;
    BEGIN
        dest_loc := p_dest_loc;
        home_loc_cube := p_home_loc_cube; 

      /* 
      ** Retrieve qty for this prod_id from inv 
      ** Home slot does not need the decode for case_cube because there is only 
      ** one product in home slot. 
      */
        BEGIN
            SELECT
                ( ( qoh + qty_planned ) / spc ) * case_cube,
                nvl(qty_planned, 0),
                nvl(qoh, 0)
            INTO
                cube_used,
                qty_planned,
                qty_oh
            FROM
                inv
            WHERE
                plogi_loc = dest_loc;

        EXCEPTION
            WHEN no_data_found THEN
                BEGIN 
                /* 
                 ** Inventory record does not exist for the item 
                 ** for the location specified - so, insert the record 
                 **  
                 */
                    INSERT INTO inv (
                        prod_id,
                        inv_date,
                        logi_loc,
                        plogi_loc,
                        qoh,
                        qty_alloc,
                        qty_planned,
                        min_qty,
                        status,
                        abc,
                        abc_gen_date,
                        lst_cycle_date,
                        cust_pref_vendor,
                        exp_date
                    ) VALUES (
                        g_prod_id,
                        SYSDATE,
                        dest_loc,
                        dest_loc,
                        0,
                        0,
                        0,
                        0,
                        'AVL',
                        'A',
                        SYSDATE,
                        SYSDATE,
                        cust_pref_vendor,
                        trunc(SYSDATE)
                    );

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('FATAL', l_func_name, 'Table = inv Action= INSERT MEssage= unable to insert inv record for home slot for product.'
                        , sqlcode, sqlerrm);
                END;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Table = inv Action= INSERT MEssage= unable to find home slot inventory record for product.'
                , sqlcode, sqlerrm);
        END; 

        /* process fifo tracked item */

        IF ( ( fifo_trk = 'S' ) OR ( fifo_trk = 'A' ) ) THEN
            fifo_item_qoh := 0;
            BEGIN
                SELECT
                    nvl(SUM(i.qoh + i.qty_planned), 0)
                INTO fifo_item_qoh
                FROM
                    inv i
                WHERE
                    i.cust_pref_vendor = cust_pref_vendor
                    AND i.prod_id = prod_id;

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'Table = inv Action= SELECT MEssage=NO DATA on inv for fifo item leaving home slot.'
                    , sqlcode, sqlerrm);
                    return('FALSE');
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Table = inv Action= SELECT MEssage=error on inv for fifo item leaving home slot.'
                    , sqlcode, sqlerrm);
            END;

            IF ( fifo_item_qoh > 0 ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Table = inv Action= SELECT MEssage=QOH exists for fifo item leaving home slot.'
                , sqlcode, sqlerrm);
                return('FALSE');
            END IF;

        END IF;

        IF ( ( ( lot_trk = 'Y' ) OR ( stackable = 0 ) ) AND ( ( qty_oh + qty_planned ) > 0 ) ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Table = inv Action= SELECT MEssage=QOH exists and either lot tracking or non-stackable leaving home slot.'
            , sqlcode, sqlerrm);
            return('FALSE');
        END IF; 

/* 
  **  Add skid_cube to cube_used for home slot. 
  **  Add skid_cube per number of positions of home slot. 
  */

        IF ( ( deep_ind = 'Y' ) AND ( '0' <= slot_type ) AND ( slot_type <= '9' ) ) THEN
            cube_used := cube_used + ( skid_cube * ( slot_type - '0' ) );
        ELSE
            cube_used := cube_used + skid_cube;
        END IF;

        IF ( ( qty_oh = 0 ) AND ( qty_planned = 0 ) ) THEN
            first_home_assign := 'TRUE'; 

          /* 
          ** Check if full pallet and since home slot is empty 
          ** put the pallet in - don't check the location cube 
          */
            IF ( partial_pallet <> C_TRUE ) THEN 
            /* Update qty_planned for this prod_id on inv */
                p_insert_table(dest_loc, add_home);
                current_pallet := current_pallet + 1;
                cube_used := cube_used + ( each_pallet_qty * case_cube );
                qty_planned := qty_planned + ( each_pallet_qty * spc );
                first_home_assign := 'FALSE';
            END IF;

        ELSE
            first_home_assign := 'FALSE';
        END IF; 

        /* 
        ** Check if space is enough to hold the putaway qty 
        ** Put partial pallet first 
        ** 
        ** Check if home slot has enough cube to hold rest of the qty 
        ** 
        ** If full pallet already received above, the cube will not be sufficient 
        ** If full pallet not received and only partial is being received, 
        ** check cube available whether home slot has qty on hand or not 
        */ 
        /* New Query added to check the threshold flag value for this prod_id 
        ** This query shall be used to determine the program flow in case of 
        ** threshold flag value 
        */

        BEGIN
            SELECT
                nvl(pt.putaway_use_repl_threshold, 'N'),
                nvl(max_qty, 0)
            INTO
                l_ch_threshold_flag,
                l_i_max_qty
            FROM
                pallet_type pt,
                pm
            WHERE
                pt.pallet_type = pm.pallet_type
                AND pm.prod_id = prod_id
                AND pm.cust_pref_vendor = cust_pref_vendor;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'Table = pallet_type,PM  Action= SELECT MEssage=Oracle failed to fetch values for Threshold Flag   Qty in Check_home_slot function'
                , sqlcode, sqlerrm);
        END;

        IF ( partial_pallet = C_TRUE ) THEN 
          /* If existing qty in home slot less than max qty ,putaway the partial pallet 
          ,don't check for avalble cube  
          */
            IF ( l_ch_threshold_flag = 'Y' ) THEN
                IF ( ( qty_oh + qty_planned ) < ( l_i_max_qty * spc ) ) THEN
                    partial_pallet := C_FALSE;
                    pallet_qty := each_pallet_qty;
                    each_pallet_qty := last_pallet_qty;
                    qty_planned := qty_planned + ( last_pallet_qty * spc );
                    p_insert_table(dest_loc, add_home);
                    current_pallet := current_pallet + 1;
                    cube_used := cube_used + ( ( each_pallet_qty * case_cube ) );
                    each_pallet_qty := pallet_qty;
                    last_pallet_qty := pallet_qty;
                END IF;

            ELSIF ( ( p_home_loc_cube - cube_used ) >= ( last_pallet_qty * case_cube ) ) THEN
                partial_pallet := C_FALSE;
                pallet_qty := each_pallet_qty;
                each_pallet_qty := last_pallet_qty;
                qty_planned := qty_planned + ( each_pallet_qty * spc );
                p_insert_table(dest_loc, add_home);
                current_pallet := current_pallet + 1;
                cube_used := cube_used + ( each_pallet_qty * case_cube );
                each_pallet_qty := pallet_qty;
                last_pallet_qty := pallet_qty;
            END IF;
        END IF;

        IF ( NOT ( ( current_pallet = num_pallet - 1 ) AND partial_pallet = C_TRUE ) ) THEN
            IF ( stackable > 0 ) THEN
                IF ( l_ch_threshold_flag = 'Y' ) THEN 
                  /* If existing qty in home slot less than max qty, 
                     putaway the partial pallet,don't check for avalble cube  
                  */
                    WHILE ( ( qty_oh + qty_planned ) < ( l_i_max_qty * spc ) AND ( current_pallet < num_pallet ) ) LOOP
                        p_insert_table(dest_loc, add_home);
                        current_pallet := current_pallet + 1;
                        cube_used := cube_used + ( each_pallet_qty * case_cube );
                        qty_planned := qty_planned + ( each_pallet_qty * spc );
                    END LOOP;

                ELSE
                    WHILE ( ( ( home_loc_cube - cube_used ) >= ( each_pallet_qty * case_cube ) ) AND ( current_pallet < num_pallet
                    ) ) LOOP
                        p_insert_table(dest_loc, add_home);
                        qty_planned := qty_planned + ( each_pallet_qty * spc );
                        current_pallet := current_pallet + 1;
                        cube_used := cube_used + ( each_pallet_qty * case_cube );
                    END LOOP;
                END IF;

            END IF;
        END IF;

        IF ( current_pallet >= num_pallet ) THEN
            status := C_TRUE;
        ELSE
            status := C_FALSE;
        END IF;
      RETURN status;
    END f_check_home_slot; 

  /***************************************************************************** 
    **   f_hi_rise_rule 
    **  DESCRIPTION: 
    **        Check High Rise area            
    **        
    **  Called by : f_find_putaway_slot 
    **  PARAMETERS: 
    **      
    **  RETURN VALUES: 
    **      TRUE  - Success. 
    **      FALSE - Failure 
    *****************************************************************************/

    FUNCTION f_hi_rise_rule RETURN NUMBER IS

        l_func_name   VARCHAR2(20) := 'f_hi_Rise_rule';
        status        NUMBER := 0;
        indexs        NUMBER := 0;
        qoh           VARCHAR2(20);
        qty_planned   VARCHAR2(20);
        dest_loc      VARCHAR2(10);
        aisle1        NUMBER;
        slot1         NUMBER;
        level1        NUMBER;
        slot_type1    VARCHAR2(10);

    BEGIN
         pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside f_hi_Rise_rule ', sqlcode, sqlerrm);
        BEGIN
        SELECT
            l.logi_loc,
            l.put_aisle,
            l.put_slot,
            l.put_level,
            l.slot_type
        INTO
            dest_loc,
            aisle1,
            slot1,
            level1,
            slot_type1
        FROM
            slot_type   s,
            loc         l,
            lzone       z,
            inv         i
        WHERE
            s.slot_type = l.slot_type
            AND l.logi_loc = z.logi_loc
            AND z.logi_loc = i.plogi_loc
            AND z.zone_id = l_zone_id
            AND i.prod_id = g_prod_id
            AND i.cust_pref_vendor = l_cust_pref_vendor
        ORDER BY
            i.exp_date,
            i.qoh,
            i.logi_loc; 

       /*** The item currently exists in the high rise zone.       */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'TABLE = sys_config ACTION = SELECT MESSAGE= Starting from loc closest to FEFO item in zone', 
        sqlcode, sqlerrm);
        p_clear_array(); 

        /*   Find closest open slot  */
        BEGIN
            SELECT
                l.logi_loc,
                l.cube,
                l.put_aisle,
                l.put_slot,
                l.put_level,
                p.cube
            INTO
                phys_loc,
                loc_cube,
                put_aisle2,
                put_slot2,
                put_level2,
                pcube
            FROM
                pallet_type   p,
                slot_type     s,
                loc           l,
                lzone         z
            WHERE
                p.pallet_type = l.pallet_type
                AND s.slot_type = l.slot_type
                AND ( p.cube >= pallet_cube
                      AND l.pallet_type = l_pallet_type )
                AND l.logi_loc = z.logi_loc
                AND l.perm = 'N'
                AND l.status = 'AVL'
                AND l.cube >= DECODE(g_last_pik_cube, 0.0, std_pallet_cube, g_last_pik_cube)
                AND z.zone_id = l_zone_id
                AND NOT EXISTS (
                    SELECT
                        'x'
                    FROM
                        inv i
                    WHERE
                        i.plogi_loc = l.logi_loc
                )
            ORDER BY
                p.cube,
                l.cube,
                abs(aisle1 - l.put_aisle),
                l.put_aisle,
                abs(slot1 - l.put_slot),
                l.put_slot,
                abs(level1 - l.put_level),
                l.put_level;

            SELECT
                COUNT(*)
            INTO total_cnt
            FROM
                (
                    SELECT
                        l.logi_loc,
                        l.cube,
                        l.put_aisle,
                        l.put_slot,
                        l.put_level,
                        p.cube
                    FROM
                        pallet_type   p,
                        slot_type     s,
                        loc           l,
                        lzone         z
                    WHERE
                        p.pallet_type = l.pallet_type
                        AND s.slot_type = l.slot_type
                        AND ( p.cube >= pallet_cube
                              AND l.pallet_type = l_pallet_type )
                        AND l.logi_loc = z.logi_loc
                        AND l.perm = 'N'
                        AND l.status = 'AVL'
                        AND l.cube >= DECODE(g_last_pik_cube, 0.0, std_pallet_cube, g_last_pik_cube)
                        AND z.zone_id = l_zone_id
                        AND NOT EXISTS (
                            SELECT
                                'x'
                            FROM
                                inv i
                            WHERE
                                i.plogi_loc = l.logi_loc
                        )
                    ORDER BY
                        p.cube,
                        l.cube,
                        abs(aisle1 - l.put_aisle),
                        l.put_aisle,
                        abs(slot1 - l.put_slot),
                        l.put_slot,
                        abs(level1 - l.put_level),
                        l.put_level
                ) to_cnt;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'TABLE = sys_config ACTION = SELECT MESSAGE= Hi Rise closest to item in zone', 
            sqlcode, sqlerrm);
            status := f_hi_rise_open_assign();
        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'TABLE = sys_config ACTION = SELECT MESSAGE= No slots near floating pick slot having same pallet_type and cube > last_pik_cube in zone'
                , sqlcode, sqlerrm);
        END;

    EXCEPTION
        WHEN no_data_found THEN 
             /*       ** The item does not exist in the high rise zone.       */
            pl_text_log.ins_msg_async('FATAL', l_func_name, 'No inventory for floating item in zone', sqlcode, sqlerrm);
            p_clear_array(); 

            /* 
            **  Find closest open slot to last ship slot 
            */
            BEGIN
                SELECT
                    l.logi_loc,
                    l.cube,
                    l.put_aisle,
                    l.put_slot,
                    l.put_level,
                    p.cube
                INTO
                    phys_loc,
                    loc_cube,
                    put_aisle2,
                    put_slot2,
                    put_level2,
                    pcube
                FROM
                    pallet_type   p,
                    slot_type     s,
                    loc           l,
                    lzone         z
                WHERE
                    p.pallet_type = l.pallet_type
                    AND ( p.cube >= pallet_cube
                          AND l.pallet_type = l_pallet_type )
                    AND s.slot_type = l.slot_type
                    AND l.logi_loc = z.logi_loc
                    AND l.perm = 'N'
                    AND l.status = 'AVL'
                    AND l.cube >= DECODE(g_last_pik_cube, 0.0, std_pallet_cube, g_last_pik_cube)
                    AND z.zone_id = l_zone_id
                    AND NOT EXISTS (
                        SELECT
                            'x'
                        FROM
                            inv i
                        WHERE
                            i.plogi_loc = l.logi_loc
                    )
                ORDER BY
                    p.cube,
                    l.cube,
                    abs(g_last_put_aisle1 - l.put_aisle),
                    l.put_aisle,
                    abs(g_last_put_slot1 - l.put_slot),
                    l.put_slot,
                    abs(g_last_put_level1 - l.put_level),
                    l.put_level;

                pl_text_log.ins_msg_async('INFO', l_func_name, 'TABLE = sys_config ACTION = SELECT MESSAGE= Hi Rise closest to last ship slot in zone'
                , sqlcode, sqlerrm);
                status := f_hi_rise_open_assign();
            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'TABLE = sys_config ACTION = SELECT MESSAGE= No slots near last ship slot having same pallet_type and cube'
                    , sqlcode, sqlerrm);
                    status := C_TRUE;
            END;
      END;
       RETURN status;
    END f_hi_rise_rule; 

  /***************************************************************************** 
    **   f_deep_slot_assign_loop 
    **  DESCRIPTION: 
    **        Hi rise open assign      
    **        
    **  Called by : f_hi_rise_rule 
    **  PARAMETERS: 
    **      
    **  RETURN VALUES: 
    **      0  - Success. 
    **      1  - Failure 
    *****************************************************************************/

    FUNCTION f_hi_rise_open_assign RETURN NUMBER IS
        l_func_name   VARCHAR2(20) := 'f_hi_rise_open_assign';
        l_index       NUMBER := 0;
        status        NUMBER := 0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Hi Rise open assign for item', sqlcode, sqlerrm);
        WHILE ( ( l_index <= total_cnt ) AND ( current_pallet < num_pallet ) ) LOOP
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Hi Rise Open Loop', sqlcode, sqlerrm);
            IF ( loc_cube >= ( ( ( ceil(each_pallet_qty / ti) ) * ti * case_cube ) + skid_cube ) ) THEN
                p_insert_table(phys_loc, ADD_RESERVE);
                current_pallet := current_pallet + 1;
                l_index := l_index + 1;
                IF ( current_pallet = ( num_pallet - 1 ) ) THEN
                    each_pallet_qty := last_pallet_qty;
                END IF;

            ELSE
                l_index := l_index + 1;
            END IF;

        END LOOP;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending Hi Rise open assign for item', sqlcode, sqlerrm);
        IF ( current_pallet >= num_pallet ) THEN
            status := C_TRUE;
        ELSE
           status := C_FALSE;
        END IF;
      RETURN status;  
    END f_hi_rise_open_assign;

    PROCEDURE p_clear_array IS
        l_func_name VARCHAR2(30) := 'p_clear_array';
    BEGIN
        phys_loc := '';
        loc_cube := 0;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Clearing the array', sqlcode, sqlerrm);
    END p_clear_array; 
    
  /***************************************************************************** 
  **  f_deep_slot_assign_loop 
  **  Description: 
  **     Loop through available deep slots and check if space is enough for 
  **     a pallet. 
  ** 
  **  Parameters: 
  ** 
  **  RETURN Values: 
  **     0 -  Success 
  **     1 - Failure 
  **  Called By: f_two_d_three_d 
  ** 
  *****************************************************************************/

    FUNCTION f_deep_slot_assign_loop (
        p_same_diff_prod_flag NUMBER
    ) RETURN NUMBER AS

        position_used         FLOAT := 0.0;
        l_index               NUMBER := 0;
        finish                BOOLEAN := false;
        i                     NUMBER := 0;
        inv_cnt               NUMBER := 0;
        l_func_name           VARCHAR2(30) := 'f_deep_slot_assign_loop'; 
        num_positions         NUMBER;
        inserted_record       NUMBER;
        put_deep_factor2      NUMBER;
        same_diff_prod_flag   NUMBER;
        cube_occupied         FLOAT;
        skid_occupied         FLOAT;
        location              VARCHAR2(10);
        pallet_cnt            NUMBER := 0;
        exist_item_cube       VARCHAR2(100);
        exist_item_flag       VARCHAR2(100);
        position_cube         FLOAT := 0.0;
        l_status              VARCHAR2(100);
        status                NUMBER := 0;
    BEGIN 
        /* 
        **  num_positions assignment moved inside loop and is based 
        **                 on the slot type of the candidate putaway slot. 
        */
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside f_deep_slot_assign_loop ', sqlcode, sqlerrm);
        IF ( same_diff_prod_flag = 0 ) THEN
            SELECT
                COUNT(DISTINCT i.plogi_loc)
            INTO slot_cnt
            FROM
                lzone   l,
                inv     i
            WHERE
                l.logi_loc = i.plogi_loc
                AND l.zone_id = zone_id
                AND i.cust_pref_vendor = cust_pref_vendor
                AND i.prod_id = prod_id;

        END IF; 

          /* 
          **  slot_cnt is set to 0 when SAME product being processed; because 
          **  of initialization. 
          */

        WHILE ( ( max_slot > slot_cnt ) AND ( l_index <= total_cnt ) AND ( current_pallet < num_pallet ) ) LOOP 
          /* 
          ** The number of positions is that of the candidate open slot. 
          */
            num_positions := loc_deep_positions;
            put_deep_factor2 := num_positions;
            pallet_cnt := 0;
            location := phys_loc;
            SELECT
                COUNT(*)
            INTO pallet_cnt
            FROM
                inv
            WHERE
                plogi_loc = location; 

          /* Get the cube occupied by each pallet in the slot ordering by 
          ** the pallet with the least cube.
          */

            BEGIN
                SELECT
                    ( ( ceil(((i.qoh + i.qty_planned) / p.spc) / p.ti) ) * p.ti * DECODE(i.prod_id, g_prod_id, case_cube, p.case_cube
                    ) ) + skid_cube
                INTO exist_item_cube
                FROM
                    pm    p,
                    inv   i
                WHERE
                    p.prod_id = i.prod_id
                    AND p.cust_pref_vendor = i.cust_pref_vendor
                    AND i.plogi_loc = location
                ORDER BY
                    1 DESC;

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get exist item cube value', NULL, NULL);
            END; 

          /* Save the # of pallets in the slot. */

            cube_occupied := 0; 

          /* Divide the location cube by the number of positions available in 
             the slot.  Example: Location cube is 156, 2 deep pushback slot. 
                                 The cube for each position is 156/2 = 78. */
            BEGIN
                SELECT
                    l.cube / substr(l.slot_type, 1, 1)
                INTO position_cube
                FROM
                    loc l
                WHERE
                    l.logi_loc = location;

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get position cube value', sqlcode, sqlerrm);
                    l_status := 'Unable to select from inv for plogi_loc ';
                    ROLLBACK;
                    RETURN l_status;
            END;

            i := 0;
            WHILE ( i < inv_cnt ) LOOP
                exist_item_flag := 'N';
                i := i + 1;
            END LOOP;

            finish := false;
            WHILE ( ( put_deep_factor2 <> 0 ) AND finish <> true ) LOOP
                cube_occupied := 0; 

              /* 
              **  Load position with largest remaining pallet. 
              */
                i := 0;
                WHILE ( i < inv_cnt ) LOOP
                    IF ( exist_item_flag = 'N' ) THEN
                        cube_occupied := exist_item_cube;
                        exist_item_flag := 'Y';
                        EXIT;
                    END IF;

                    i := i + 1;
                END LOOP; 

              /* 
              **  Determine if can stack a smaller pallet on top. 
              */

                i := 0;
                WHILE ( i < inv_cnt ) LOOP
                    IF ( position_cube - cube_occupied >= exist_item_cube AND exist_item_flag = 'N' ) THEN
                        cube_occupied := cube_occupied + exist_item_cube;
                        exist_item_flag := 'Y';
                    END IF;

                    i := i + 1;
                END LOOP; 

              /* 
              **  Determine if all pallets putaway. 
              */

                i := 0;
                WHILE ( i < inv_cnt ) LOOP IF ( exist_item_flag = 'N' ) THEN
                    finish := false;
                    EXIT;
                ELSE
                    finish := true;
                END IF;
                END LOOP; 

              /* 
                     **  If more pallets, then get next position. 
                     */

                IF ( finish <> true ) THEN
                    put_deep_factor2 := put_deep_factor2 - 1;
                    loc_cube := loc_cube - position_cube;
                END IF;

            END LOOP;

            inserted_record := 0;
            WHILE ( put_deep_factor2 > 0 ) AND ( finish = true ) LOOP
                position_used := position_cube;
                position_used := position_used - cube_occupied;
                WHILE ( position_used >= ( ( ( ( ceil(each_pallet_qty / ti) ) * ti * case_cube ) + skid_cube ) ) ) LOOP
                    position_used := position_used - ( ( ( ceil(each_pallet_qty / ti) ) * ti * case_cube ) + skid_cube );

                    p_insert_table(phys_loc, ADD_RESERVE);
                    inserted_record := inserted_record + 1;
                    current_pallet := current_pallet + 1;
                    pallet_cnt := pallet_cnt + 1;
                    IF ( current_pallet = ( num_pallet - 1 ) ) THEN
                        each_pallet_qty := last_pallet_qty;
                    ELSIF ( current_pallet >= num_pallet ) THEN
                        EXIT;
                    END IF;

                END LOOP;

                cube_occupied := 0;
                IF ( current_pallet >= num_pallet ) THEN
                    EXIT; /* No more pallets */
                END IF;
                put_deep_factor2 := put_deep_factor2 - 1;
            END LOOP;

            IF ( ( same_diff_prod_flag = 0 ) AND ( inserted_record > 0 ) ) THEN
                slot_cnt := slot_cnt + 1;
                l_index := l_index + 1;
            END IF;

        END LOOP;

        IF ( current_pallet >= num_pallet ) THEN
            status := C_TRUE;
        ELSE
             status := C_FALSE;
        END IF;
      RETURN status;
    END f_deep_slot_assign_loop; 
    
  /***************************************************************************** 
  **  FUNCTION: 
  **      f_find_putaway_slot 
  **  DESCRIPTION: 
  **      This function finds the slot for the item to do putaway process 
  **      Called by:  
  **  PARAMETERS: 
  **      None 
  **  RETURN VALUES: 
  **      0 - Success  
  **      1 - Failure 
  *****************************************************************************/

    FUNCTION f_find_putaway_slot(
    p_prod_id IN pm.zone_id%TYPE, 
    p_cpv IN pm.cust_pref_vendor%TYPE
    )
    RETURN NUMBER IS

        i                  NUMBER;
        l_func_name        VARCHAR2(30) := 'f_find_putaway_slot';
        dest_loc           VARCHAR2(10);
        rule_id            NUMBER;
        primary_put_zone   VARCHAR2(5);
        l_status           VARCHAR2(10);
        CURSOR each_zone IS
        SELECT
            next_zone_id
        FROM
            next_zones
        WHERE
            zone_id = l_zone_id
        ORDER BY
            sort ASC;

    BEGIN
        home_slot_flag := 0;
        done := '0';
        IF ( ( f_check_home_item(aging_days) ) = 'TRUE' ) THEN
            BEGIN 
        /* 
        ** The item has a home location or the item is a floating item. 
        */ 
            /* Get the rule id of the items putaway zone. */
           
                SELECT
                    rule_id
                INTO rule_id
                FROM
                    zone
                WHERE
                    zone_id = l_zone_id;
            
                IF ( rule_id = 0 ) THEN
                    done := f_general_rule('FIRST');
                ELSIF ( rule_id = 1 ) THEN
                    done := f_hi_rise_rule();
                ELSIF ( rule_id = 2 ) THEN
                    done := f_bulk_rule(l_zone_id,p_prod_id,p_cpv);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'Unable to get rule_id for zone = ' || l_zone_id, sqlcode, sqlerrm);
                  
            END;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'done = ' || done, sqlcode, sqlerrm);
                 
            IF ( done IS NOT NULL ) THEN 
              /* 
               ** If we are not done yet, find next zone to putaway 
               ** Get a list of all the zones specified as next zones for the 
               ** items primary put zone. 
               ** Only iterate num_next_zones times as specified in the area 
               ** record matching the area of the item. 
               */
               pl_text_log.ins_msg_async('INFO', l_func_name, 'Fetching rule id for zone  = ' || l_zone_id, sqlcode, sqlerrm);
                OPEN each_zone;
                LOOP
                FETCH each_zone INTO l_zone_id;
                EXIT WHEN each_zone%NOTFOUND;
                FOR i IN 1..num_next_zones LOOP
                    BEGIN
                        SELECT
                            rule_id
                        INTO rule_id
                        FROM
                            zone
                        WHERE
                            zone_id = l_zone_id;

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('FATAL', l_func_name, 'Error fetching rule id', sqlcode, sqlerrm);
                    END;
                   pl_text_log.ins_msg_async('INFO', l_func_name, 'when done is not null rule_id = ' || rule_id, sqlcode, sqlerrm);
  
                    IF ( rule_id = 1 ) THEN
                        done := f_hi_rise_rule();
                    ELSIF ( rule_id = 2 ) THEN
                    
                        done := f_bulk_rule(l_zone_id,p_prod_id,p_cpv);
                         pl_text_log.ins_msg_async('FATAL', l_func_name, 'f_bulk_rule done = ' || done, sqlcode, sqlerrm);
                    ELSIF ( rule_id = 0 ) THEN
                        done := f_general_rule('SECOND');
                    END IF;

                    IF ( done IS NOT NULL ) THEN
                      pl_text_log.ins_msg_async('FATAL', l_func_name, 'f_bulk_rule done----> ' || done, sqlcode, sqlerrm);
                        return(0);
                    END IF; 
                END LOOP;
            END LOOP;
                IF ( i = num_next_zones ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Maximum number of next zones reached.', sqlcode, sqlerrm);
                END IF;

            END IF;

        END IF;

        IF ( done IS NOT NULL ) THEN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Could not put away item for prod_id ' || p_prod_id || ' CPV = ' || p_cpv, sqlcode, sqlerrm);
          pl_text_log.ins_msg_async('INFO', l_func_name, 'current_pallet ' || current_pallet || ' num_pallet = ' || num_pallet || 
          ' partial_pallet= ' || partial_pallet, sqlcode, sqlerrm);
       
            WHILE ( current_pallet < num_pallet ) LOOP
                IF ( ( current_pallet = ( num_pallet - 1 ) ) AND partial_pallet IS NOT NULL ) THEN
                  each_pallet_qty := last_pallet_qty;
                    dest_loc := '*';
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'hitting p_insert_table with erm id = ' || g_erm_num, sqlcode, sqlerrm);
                    begin
                    p_insert_table(dest_loc, ADD_NO_INV);
                    EXCEPTION
                    WHEN OTHERS THEN
                     pl_text_log.ins_msg_async('INFO', l_func_name, 'exception p_insert_table  ', sqlcode, sqlerrm);
                     END;
                END IF;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'moved out of  p_insert_table', sqlcode, sqlerrm);
                
                current_pallet := current_pallet + 1;
            END LOOP;
        END IF;
         pl_text_log.ins_msg_async('INFO', l_func_name, 'Exiting f_find_putaway_slot with done = ' || done, sqlcode, sqlerrm);
        return(0);
    END f_find_putaway_slot; 
    
/********************************************************/ 
/*  Gets number of next zones attempts allowed for area */ 
/********************************************************/

    PROCEDURE p_get_num_next_zones (
        p_area IN VARCHAR2
    ) IS
        l_func_name   VARCHAR2(30) := 'p_get_num_next_zones';
        area          VARCHAR2(50);
    BEGIN
      pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside p_get_num_next_zones with area =  ' || p_area, sqlcode, sqlerrm);
        area := p_area;
        BEGIN
            SELECT
                nvl(num_next_zones, 0)
            INTO num_next_zones
            FROM
                swms_areas
            WHERE
                area_code = area;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'Unable to get num_next_zones for items area', sqlcode, sqlerrm);
        END;

    END p_get_num_next_zones; 
    
  /***************************************************************************** 
  **  f_locator_rule 
  **  DESCRIPTION: 
  **      This function assigns the pallets for an item to the locator 
  **      location for the case home slot aisle. 
  ** 
  **      Called by: Find_putaway_slot 
  **  PARAMETERS: 
  **      None 
  **  RETURN VALUES: 
  **      TRUE  - All the pallets for the item were successfully assigned 
  **              to a locator location. 
  **      FALSE - Not all the pallets for the item were successfully assigned 
  **              to a locator location.  This should not happen. 
  *****************************************************************************/

    FUNCTION f_locator_rule RETURN VARCHAR2 AS

        l_func_name   VARCHAR2(30) := 'locator_rule'; 
    /* Function identifier 
                                              in aplog messages. */
        ret_val       VARCHAR2(5) := 'FALSE'; /* Function RETURN value */
        i             NUMBER;
        dest_loc      VARCHAR2(10);
        home_loc      VARCHAR2(10);
    BEGIN 
       pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside locator_rule ', sqlcode, sqlerrm);
      /* Get the case home slot for the item. */
        SELECT
            l.logi_loc
        INTO home_loc
        FROM
            loc l
        WHERE
            l.uom IN (
                0,
                2
            )
            AND l.perm = 'Y'
            AND l.rank = 1
            AND l.cust_pref_vendor = cust_pref_vendor
            AND l.prod_id = prod_id;

        IF ( home_loc IS NULL ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Home slot not found for item', sqlcode, sqlerrm);
            ret_val := 'FALSE';
        ELSE 
        /* ** Found the case home slot for the item. Get the locator location for the case home slot aisle.  */
            SELECT
                a.locator_loc
            INTO dest_loc
            FROM
                aisle_info a
            WHERE
                a.name LIKE substr(home_loc, 1, 2)
                AND EXISTS (
                    SELECT
                        'x'
                    FROM
                        loc l
                    WHERE
                        l.perm = 'N'
                        AND l.logi_loc = a.locator_loc
                );

            IF ( dest_loc IS NULL ) THEN
                ret_val := 'FALSE';
            ELSE
                WHILE ( current_pallet < num_pallet ) LOOP
                    IF ( ( i = ( num_pallet - 1 ) ) AND ( partial_pallet IS NOT NULL ) ) THEN
                        each_pallet_qty := last_pallet_qty;
                        p_insert_table(dest_loc, ADD_RESERVE);
                    END IF;

                    current_pallet := current_pallet + 1;
                END LOOP;

                ret_val := 'TRUE';
            END IF;

        END IF;

        RETURN ret_val;
    END f_locator_rule; 
    
  /***************************************************************** 
  ** f_split_hi_rise_open_assign 
  **  Description: Split Hi rise open assign 
  **  Called By : f_split_hi_rise_rule 
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **       0 for success 
  **      -1 For Failure 
  **     
  ****************************************************************/

    FUNCTION f_split_hi_rise_open_assign RETURN NUMBER AS

        l_index       NUMBER(2) := 0;
        l_func_name   VARCHAR2(40) := 'f_split_hi_rise_open_assign';
        status        NUMBER(2) := 1;
        l_status      VARCHAR2(100);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside f_split_hi_rise_open_assign ', sqlcode, sqlerrm);
        split_dest_loc := phys_loc;
        length_unit := pl_common.f_get_syspar('LENGTH_UNIT', 'IN');
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
                lst_cycle_date,
                cube,
                abc_gen_date,
                cust_pref_vendor,
                exp_date
            ) VALUES (
                split_dest_loc,
                split_pallet_id,
                g_prod_id,
                g_prod_id,
                total_qty,
                0,
                0,
                0,
                SYSDATE,
                SYSDATE,
                abc,
                DECODE(aging_days, - 1, 'AVL', 'HLD'),
                SYSDATE,
                DECODE(length_unit, 'CM', DECODE(sign(999999999.9999 -(total_qty + skid_cube)), - 1, 999999999.9999,(total_qty + skid_cube
                )), DECODE(sign(99999.99 -(total_qty + skid_cube)), - 1, 99999.99,(total_qty + skid_cube))),
                SYSDATE,
                cust_pref_vendor,
                trunc(SYSDATE)
            );

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'ORACLE unable to create inventory record', sqlcode, sqlerrm);
                ROLLBACK;
                l_status := 'Unable to insert into inv with pallet_id and prod_id';
                RETURN l_status;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'ORACLE unable to create inventory record item#' || g_prod_id, sqlcode, sqlerrm
                );
                ROLLBACK;
                l_status := 'Unable to insert into inv with pallet_id and prod_id';
                RETURN l_status;
        END;

        return(status);
    END f_split_hi_rise_open_assign; 
    
  /***************************************************************** 
  **  
  **  Description:  This function forces the received splits to the home slot. 
  ** if there is no home slot for this item a license plate 
  ** will be printed with "*" for a location. 
  **  Called By :p_split_find_putaway_slot 
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **  
  ****************************************************************/

    PROCEDURE p_split_putaway IS

        l_func_name    VARCHAR2(30) := 'p_split_putaway';
        status         NUMBER;
        rule_id        NUMBER;
        dest_loc       VARCHAR2(10);
        pallet_id      VARCHAR2(10);
        tmp_check      VARCHAR2(1);
        clam_bed_trk   VARCHAR(20);
        tti_trk        VARCHAR(1);
        erm_id         VARCHAR2(12);
        l_status       VARCHAR2(100) := NULL;
    BEGIN 
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside p_split_putaway ', sqlcode, sqlerrm);
          /* 
          ** If this item is not in the floating zone then look for a home slot 
          ** Splits should not go to the case home slot. 
          */
        SELECT
            l.logi_loc
        INTO dest_loc
        FROM
            slot_type   s,
            loc         l
        WHERE
            s.slot_type = l.slot_type
            AND l.uom IN (
                0,
                1
            )
            AND l.perm = 'Y'
            AND l.rank = 1
            AND l.prod_id = g_prod_id
            AND l.cust_pref_vendor = g_cpv;

        IF ( dest_loc IS NULL ) THEN 
        /* ** There is no home slot for the product, set the dest_loc = "*"      */
            dest_loc := '*';
        ELSE 
        /*    ** Found a home slot for the splits.  Update the inventory.     */
            UPDATE inv
            SET
                qty_planned = qty_planned + total_qty,
                cube = nvl(cube, 0) + ( total_qty / spc ) * case_cube
            WHERE
                cust_pref_vendor = g_cpv
                AND prod_id = g_prod_id
                AND plogi_loc = dest_loc;

        END IF;

        IF ( f_is_clam_bed_tracked_item(pm_category) = 0 ) THEN
            clam_bed_trk := 'Y';
        ELSE
            clam_bed_trk := 'N';
        END IF;

        IF ( f_is_tti_tracked_item() = 0 ) THEN
            tti_trk := 'Y';
        ELSE
            tti_trk := 'N';
        END IF;

        BEGIN
            INSERT INTO putawaylst (
                rec_id,
                prod_id,
                cust_pref_vendor,
                dest_loc,
                qty,
                uom,
                status,
                inv_status,
                pallet_id,
                qty_expected,
                qty_received,
                temp_trk,
                catch_wt,
                lot_trk,
                exp_date_trk,
                date_code,
                equip_id,
                rec_lane_id,
                seq_no,
                putaway_put,
                exp_date,
                clam_bed_trk,
                po_no,
                tti_trk,
                cool_trk
            ) VALUES (
                erm_id,
                g_prod_id,
                cust_pref_vendor,
                dest_loc,
                total_qty,
                1,
                'NEW',
                'AVL',
                split_pallet_id,
                total_qty,
                total_qty,
                temp_trk,
                catch_wt,
                'N',
                'N',
                'N',
                ' ',
                ' ',
                seq_no,
                'N',
                trunc(SYSDATE),
                clam_bed_trk,
                erm_id,
                tti_trk,
                g_c_cool_trk
            );

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, 'Unable to insert into putawaylst for pallet_id ', sqlcode, sqlerrm);
                l_status := 'Unable to insert into putawaylst for pallet_id ';
        END; 

          /* 
          ** If the item is a catch weight item insert a record into table TMP_WEIGHT if it does not aleady exist.
          */

        IF ( catch_wt = 'Y' ) THEN
            BEGIN
                SELECT
                    'X'
                INTO tmp_check
                FROM
                    tmp_weight
                WHERE
                    erm_id = g_erm_num
                    AND prod_id = g_prod_id
                    AND cust_pref_vendor = g_cpv;

            EXCEPTION
                WHEN no_data_found THEN 
            /* This create record is for the close po screen to */ 
              /* pop up the catch weight entry.                    */
                    BEGIN
                        INSERT INTO tmp_weight (
                            erm_id,
                            prod_id,
                            cust_pref_vendor,
                            total_cases,
                            total_splits,
                            total_weight
                        ) VALUES (
                            g_erm_num,
                            g_prod_id,
                            g_cpv,
                            0,
                            0,
                            0
                        );

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('FATAL', l_func_name, 'Insertion into tmp_weight failed', sqlcode, sqlerrm);
                    END;
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Selection of tmp_weight failed', sqlcode, sqlerrm);
            END;
        END IF;

    END p_split_putaway; 

  /***************************************************************************** 
  ** f_two_d_three_d_open_slot 
  ** 
  **  Description: To find the slot type of the open slot in a loop 
  ** 
  **  Parameters: 
  ** 
  **  RETURN Values: 
  **         1 - Success 
  **         0 - Failure 
  **  Called By: two_d_three_d 
  **     
  *****************************************************************************/

    FUNCTION f_two_d_three_d_open_slot RETURN VARCHAR2 AS

        l_func_name   VARCHAR2(30) := 'f_two_d_three_d_open_slot';
        num_pos       NUMBER := 0;
        i             NUMBER := 0;
        num_inserts   NUMBER;
        slot_cnt      NUMBER := 0;
        status        NUMBER := 0;
    BEGIN 
     pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside f_two_d_three_d_open_slot ', sqlcode, sqlerrm);
      /*    ** num_pos assignment moved inside loop and is based on the 
      **                 slot type of the open slot.   
      */
        IF ( max_slot_flag = 'Z' ) THEN
            SELECT
                COUNT(DISTINCT i.plogi_loc)
            INTO slot_cnt
            FROM
                lzone   l,
                inv     i
            WHERE
                l.logi_loc = i.plogi_loc
                AND l.zone_id = zone_id
                AND i.cust_pref_vendor = cust_pref_vendor
                AND i.prod_id = prod_id;

        END IF;

        WHILE ( ( max_slot > slot_cnt ) AND ( l_index <= total_cnt ) AND ( current_pallet < num_pallet ) ) LOOP
            num_inserts := 0;
            num_pos := loc_deep_positions;
            i := 0;
            WHILE ( i < num_pos ) AND ( current_pallet < num_pallet ) LOOP
                p_insert_table(phys_loc, ADD_RESERVE);
                current_pallet := current_pallet + 1;
                num_inserts := num_inserts + 1;
                IF ( current_pallet = ( num_pallet - 1 ) ) THEN
                    each_pallet_qty := last_pallet_qty;
                END IF;

                i := i + 1;
            END LOOP;

            IF ( num_inserts > 0 ) THEN
                slot_cnt := slot_cnt + 1;
            END IF;
           l_index := l_index + 1;

        END LOOP;

        IF ( current_pallet >= num_pallet ) THEN
           status := C_TRUE;
        ELSE
             status := C_FALSE;
        END IF;
      RETURN status;
    END f_two_d_three_d_open_slot; 

  /***************************************************************** 
  ** f_check_avail_slot 
  **  Description: To Find non-open slot of all aisle as putaway slot  
  **  Called By : f_general_rule 
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **      TRUE for success 
  **      FALSE For Failure 
  **     
  ****************************************************************/

    FUNCTION f_check_avail_slot RETURN NUMBER IS

        l_func_name   VARCHAR2(50) := 'f_check_avail_slot';
        status        NUMBER := 0;
        l_index       NUMBER := 0;
        more          VARCHAR2(10) := 0;
        more_slot     VARCHAR2(10);
        next_aisle    NUMBER;
        lcube         NUMBER;
        pcube1        NUMBER;
        temp_cube     NUMBER;
        slot_cnt      VARCHAR2(50);
        slot_type1    VARCHAR2(15);
        total_rows    VARCHAR2(10); 
        length_unit  VARCHAR2(10);
  /* 
    ** Retrive location from other aisle with enough space for one pallet 
    ** regardless of prod_id.  The locations are put into a array, sorted 
    ** from closest to farest 
    */
    BEGIN
     pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside f_check_avail_slot ', sqlcode, sqlerrm);
         BEGIN
                length_unit := pl_common.f_get_syspar('LENGTH_UNIT', 'IN');
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get Length unit syspar', sqlcode, sqlerrm);
            END;


        IF ( ( max_slot_flag = 'Z' ) AND ( max_slot > slot_cnt ) ) THEN
            more_slot := 'TRUE';
            WHILE ( ( more_slot = 'TRUE' ) AND ( max_slot > slot_cnt ) ) LOOP
                IF ( ( current_pallet = ( num_pallet - 1 ) ) AND partial_pallet = 'TRUE' ) THEN
                    temp_cube := lst_pallet_cube;
                ELSE
                    temp_cube := std_pallet_cube;
                END IF;

                more_slot := 'FALSE';
                p_clear_array();
                BEGIN
                    SELECT
                        l.logi_loc,
                        l.cube,
                        l.put_aisle,
                        l.put_slot,
                        l.put_level,
                        pt.cube,
                        l.put_path
                    INTO
                        phys_loc,
                        loc_cube,
                        put_aisle2,
                        put_slot2,
                        put_level2,
                        pcube,
                        put_path2
                    FROM
                        pallet_type   pt,
                        slot_type     s,
                        loc           l,
                        lzone         z,
                        inv           i
                    WHERE
                        pt.pallet_type = l.pallet_type
                        AND s.slot_type = l.slot_type
                        AND s.deep_ind = 'N'
                        AND NOT EXISTS (
                            SELECT
                                'x'
                            FROM
                                inv
                            WHERE
                                plogi_loc = l.logi_loc
                                AND ( dmg_ind = 'Y'
                                      OR parent_pallet_id IS NOT NULL )
                        )
                        AND ( ( ( g_pallet_type_flag = 'Y'
                                  AND pt.cube >= pallet_cube )
                                AND ( l.pallet_type = l_pallet_type
                                      OR ( l.pallet_type IN (
                            SELECT
                                mixed_pallet
                            FROM
                                pallet_type_mixed pmix
                            WHERE
                                pmix.pallet_type = l_pallet_type
                        ) ) ) )
                              OR ( ( g_pallet_type_flag = 'N'
                                     AND pt.cube >= pallet_cube ) )
                              AND ( s.slot_type = slot_type1 ) )
                        AND l.logi_loc = z.logi_loc
                        AND l.perm = 'N'
                        AND l.status = 'AVL'
                        AND ( l.cube - temp_cube ) >= (
                            SELECT
                                DECODE(ext_case_cube_flag, 'Y', DECODE(sign(SUM(p.ti * p.hi * DECODE(i2.prod_id, g_prod_id, case_cube
                                , p.case_cube)) - SUM((ceil(((i2.qoh + i2.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i2.prod_id
                                , g_prod_id, case_cube, p.case_cube))), 1, SUM((ceil(((i2.qoh + i2.qty_planned) / p.spc) / p.ti))
                                * p.ti * DECODE(i2.prod_id, g_prod_id, case_cube, p.case_cube)),
                                DECODE(length_unit, 'CM', 99999999.9999, 99999.99)), 
                                SUM((ceil(((i2.qoh + i2.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i2.prod_id
                                , g_prod_id, case_cube, p.case_cube)))
                            FROM
                                pm    p,
                                inv   i2
                            WHERE
                                p.prod_id = i2.prod_id
                                AND p.cust_pref_vendor = i2.cust_pref_vendor
                                AND i2.plogi_loc = l.logi_loc
                        )
                        AND z.logi_loc = i.plogi_loc
                        AND z.zone_id = l_zone_id
                        AND ( i.prod_id <> g_prod_id
                              OR i.cust_pref_vendor <> l_cust_pref_vendor )
                        AND NOT EXISTS (
                            SELECT
                                'x'
                            FROM
                                pm    p2,
                                inv   k
                            WHERE
                                p2.prod_id = k.prod_id
                                AND p2.cust_pref_vendor = k.cust_pref_vendor
                                AND k.plogi_loc = l.logi_loc
                                AND ( ( ( stackable > 0 )
                                        AND ( p2.stackable > stackable
                                              OR p2.stackable = 0 ) )
                                      OR ( p2.stackable = 0 ) )
                        )
                    ORDER BY
                        pt.cube,
                        l.cube,
                        abs(put_aisle1 - l.put_aisle),
                        l.put_aisle,
                        abs(put_slot1 - l.put_slot),
                        l.put_slot,
                        abs(put_level1 - l.put_level),
                        l.put_level;

                    more := 'TRUE';
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Number of slots with different item in zone and more_slots =' ||
                    more_slot, sqlcode, sqlerrm);
                    status := f_avail_slot_assign_loop;
                EXCEPTION
                    WHEN no_data_found THEN
                        more := 'FALSE';
                        pl_text_log.ins_msg_async('FATAL', l_func_name, 'Unable to select slots having different item in zone with correct stackability', sqlcode, sqlerrm);
                END;

            END LOOP; /*end of while for max_slot_flag Z*/

        ELSE /* max_slot_flag = 'A' */
            DECLARE
                CURSOR nextaisle IS
                SELECT DISTINCT
                    l.put_aisle,
                    l.cube,
                    p.cube
                FROM
                    pallet_type   p,
                    slot_type     s,
                    loc           l,
                    lzone         z
                WHERE
                    p.pallet_type = l.pallet_type
                    AND s.slot_type = l.slot_type
                    AND s.deep_ind = 'N'
                    AND ( ( ( g_pallet_type_flag = 'Y'
                              AND p.cube >= pallet_cube )
                            AND ( l.pallet_type = l_pallet_type
                                  OR ( l.pallet_type IN (
                        SELECT
                            mixed_pallet
                        FROM
                            pallet_type_mixed pmix
                        WHERE
                            pmix.pallet_type = l_pallet_type
                    ) ) ) )
                          OR ( ( g_pallet_type_flag = 'N'
                                 AND p.cube >= pallet_cube )
                               AND ( s.slot_type = slot_type1 ) ) )
                    AND l.perm = 'N'
                    AND l.status = 'AVL'
                    AND l.cube >= std_pallet_cube
                    AND l.logi_loc = z.logi_loc
                    AND z.zone_id = zone_id
                ORDER BY
                    p.cube,
                    l.cube,
                    abs(put_aisle1 - l.put_aisle),
                    l.put_aisle;

            BEGIN
                OPEN nextaisle;
                total_rows := SQL%rowcount;
                FETCH nextaisle INTO
                    next_aisle,
                    lcube,
                    pcube1;
                FOR nxt_aisle IN 1..total_rows LOOP
                    SELECT
                        COUNT(DISTINCT i.plogi_loc)
                    INTO slot_cnt
                    FROM
                        lzone   z,
                        loc     l,
                        inv     i
                    WHERE
                        z.logi_loc = l.logi_loc
                        AND z.zone_id = zone_id
                        AND l.logi_loc = i.plogi_loc
                        AND l.put_aisle = next_aisle
                        AND i.cust_pref_vendor = l_cust_pref_vendor
                        AND i.prod_id = g_prod_id
                        AND NOT EXISTS (
                            SELECT
                                'x'
                            FROM
                                inv
                            WHERE
                                plogi_loc = l.logi_loc
                                AND ( dmg_ind = 'Y'
                                      OR parent_pallet_id IS NOT NULL )
                        );

                    IF ( max_slot > slot_cnt ) THEN
                        more_slot := 'TRUE';
                        WHILE ( more_slot = 'TRUE' AND ( max_slot > slot_cnt ) ) LOOP
                            IF ( ( current_pallet = ( num_pallet - 1 ) ) AND partial_pallet = 'TRUE' ) THEN
                                temp_cube := lst_pallet_cube;
                            ELSE
                                temp_cube := std_pallet_cube;
                            END IF;

                            more_slot := 'FALSE';
                            p_clear_array(); 

                /* 
                ** Either the cust_pref_vendor or the prod_id can be 
                ** different. 
                */
                            BEGIN
                                SELECT
                                    l.logi_loc,
                                    l.cube,
                                    l.put_aisle,
                                    l.put_slot,
                                    l.put_level,
                                    pt.cube,
                                    l.put_path
                                INTO
                                    phys_loc,
                                    loc_cube,
                                    put_aisle2,
                                    put_slot2,
                                    put_level2,
                                    pcube,
                                    put_path2
                                FROM
                                    pallet_type   pt,
                                    slot_type     s,
                                    loc           l,
                                    lzone         z,
                                    inv           i
                                WHERE
                                    NOT EXISTS (
                                        SELECT
                                            'x'
                                        FROM
                                            inv
                                        WHERE
                                            plogi_loc = l.logi_loc
                                            AND ( dmg_ind = 'Y'
                                                  OR parent_pallet_id IS NOT NULL )
                                    )
                                        AND pt.pallet_type = l.pallet_type
                                        AND pt.cube = pcube1
                                        AND s.slot_type = l.slot_type
                                        AND s.deep_ind = 'N'
                                        AND l.logi_loc = z.logi_loc
                                        AND l.perm = 'N'
                                        AND l.status = 'AVL'
                                        AND l.cube = lcube
                                        AND l.put_aisle = next_aisle
                                        AND ( l.cube - temp_cube ) >= (
                                        SELECT
                                            SUM((ceil(((i2.qoh + i2.qty_planned) / p.spc) / p.ti)) * p.ti * DECODE(i2.prod_id, g_prod_id
                                            , case_cube, p.case_cube))
                                        FROM
                                            pm    p,
                                            inv   i2
                                        WHERE
                                            p.prod_id = i2.prod_id
                                            AND p.cust_pref_vendor = i2.cust_pref_vendor
                                            AND i2.plogi_loc = l.logi_loc
                                    )
                                        AND z.logi_loc = i.plogi_loc
                                        AND z.zone_id = l_zone_id
                                        AND ( i.prod_id <> g_prod_id
                                              OR i.cust_pref_vendor <> l_cust_pref_vendor )
                                        AND NOT EXISTS (
                                        SELECT
                                            'x'
                                        FROM
                                            pm    p2,
                                            inv   k
                                        WHERE
                                            p2.prod_id = k.prod_id
                                            AND p2.cust_pref_vendor = k.cust_pref_vendor
                                            AND ( ( ( stackable > 0 )
                                                    AND ( p2.stackable > stackable
                                                          OR p2.stackable = 0 ) )
                                                  OR ( p2.stackable = 0 ) )
                                            AND k.plogi_loc = l.logi_loc
                                    )
                                ORDER BY
                                    pt.cube,
                                    l.cube,
                                    abs(put_aisle1 - l.put_aisle),
                                    l.put_aisle,
                                    abs(put_slot1 - l.put_slot),
                                    l.put_slot,
                                    abs(put_level1 - l.put_level),
                                    l.put_level;

                                more := 'TRUE';
                            EXCEPTION
                                WHEN no_data_found THEN
                                    pl_text_log.ins_msg_async('INFO', l_func_name, 'NO slots with different item in aisle', sqlcode, sqlerrm
                                    );
                                    more := 'FALSE';
                                    status := f_avail_slot_assign_loop;
                                WHEN too_many_rows THEN
                                    pl_text_log.ins_msg_async('INFO', l_func_name, 'number of slots with different item in aisle'
                                                                        || total_cnt + 1, sqlcode, sqlerrm);
                            END;

                            IF ( status = 'TRUE' ) THEN
                                CLOSE nextaisle;
                                RETURN status;
                            END IF;
                        END LOOP; /* end of while */

                    END IF;

                    FETCH nextaisle INTO
                        next_aisle,
                        lcube,
                        pcube1;
                END LOOP;

                CLOSE nextaisle; 

      /* end max_slot_flag A */
            END;
        END IF;
      RETURN status;
    END f_check_avail_slot; 
    
  /***************************************************************************** 
  **  f_is_cool_tracked_item 
  ** 
  **  DESCRIPTION: 
  **     This function determines if an item is cool tracked and return TRUE 
  **     if it is otherwise FALSE.  If an oracle error occurs then an aplog 
  **     message is written to the log file and log table and FALSE is returned. 
  ** 
  **  PARAMETERS: 
  **      None.  
  ** 
  **  RETURN VALUES: 
  **      TRUE   - Item is COOL tracked. 
  **      FALSE  - Item is not COOL tracked. 
  *****************************************************************************/

    FUNCTION f_is_cool_tracked_item RETURN BOOLEAN AS

        l_func_name        VARCHAR2(30) := 'f_is_cool_tracked_item';
        rule_id            NUMBER(5) := 0;
        logi_loc           VARCHAR2(10);
        float_item         BOOLEAN := false;
        vc_func_name       VARCHAR2(31); /* For swms log table messages */
        vc_message         VARCHAR2(35); /* Message buffer */
        vc_func_name_arr   VARCHAR2(50);
        vc_func_name_len   VARCHAR2(5);
        vc_message_len     VARCHAR2(10);
        c_dummy            VARCHAR2(20); /* Work area */
        i_return_value     BOOLEAN;
    BEGIN
     pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside f_is_cool_tracked_item ', sqlcode, sqlerrm);
        BEGIN
            SELECT
                'x'
            INTO c_dummy
            FROM
                haccp_codes h,
                pm
            WHERE
                h.haccp_code = pm.category
                AND h.cool_trk = 'Y'
                AND pm.prod_id = prod_id
                AND pm.cust_pref_vendor = cust_pref_vendor
                AND ROWNUM = 1;

            i_return_value := true;
        EXCEPTION
            WHEN no_data_found THEN
                i_return_value := false;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Checking if COOL item failed.  Will process item as not COOL tracked.', NULL
                , NULL);
        END;

        RETURN i_return_value;
    END f_is_cool_tracked_item; 
    
  /***************************************************************** 
  ** f_bulk_avail_slot_assign 
  **  Description:  To Find all available slot  
  **  Called By : f_bulk_rule 
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **      0 for success 
  **      1 For Failure 
  **     
  ****************************************************************/

    FUNCTION f_bulk_avail_slot_assign RETURN NUMBER IS
        l_func_name   VARCHAR2(50) := 'f_bulk_avail_slot_assign';
        status        NUMBER := 0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside f_bulk_avail_slot_assign ', sqlcode, sqlerrm);
        length_unit := pl_common.f_get_syspar('LENGTH_UNIT', 'IN');
        BEGIN
            SELECT DISTINCT
                l.logi_loc,
                l.cube,
                l.put_aisle,
                l.put_slot,
                l.put_level,
                DECODE(s.deep_ind, 'Y', substr(l.slot_type, 1, 1), 1),
                l.slot_type,
                s.deep_ind
            INTO
                phys_loc,
                loc_cube,
                put_aisle2,
                put_slot2,
                put_level2,
                put_deep_factor2,
                put_slot_type2,
                put_deep_ind2
            FROM
                slot_type   s,
                loc         l,
                lzone       z,
                inv         i
            WHERE
                s.slot_type = l.slot_type
                AND NOT EXISTS (
                    SELECT
                        'x'
                    FROM
                        inv
                    WHERE
                        plogi_loc = l.logi_loc
                        AND ( dmg_ind = 'Y'
                              OR parent_pallet_id IS NOT NULL )
                )
                AND ( ( ( s.deep_ind = 'Y' )
                        AND lst_pallet_cube <= (
                    SELECT
                        DECODE(sign(to_number(substr(s.slot_type, 1, 1)) - COUNT(*)), 1,
                        (l.cube -((l.cube / to_number(substr(s.slot_type , 1, 1))) *(to_number(substr(s.slot_type, 1, 1)) - COUNT(*)))),
                        DECODE(length_unit, 'CM', 99999999.9999, 99999.00))
                    FROM
                        pm    p,
                        inv   i2
                    WHERE
                        p.prod_id = i2.prod_id
                        AND p.cust_pref_vendor = i2.cust_pref_vendor
                        AND i2.plogi_loc = l.logi_loc
                ) )
                      OR ( ( ( s.deep_ind = 'N' )
                             AND ( l.cube - lst_pallet_cube ) >= (
                    SELECT
                        SUM((ceil(((i3.qoh + i3.qty_planned) / p2.spc) / p2.ti)) * p2.ti * DECODE(i3.prod_id, g_prod_id, case_cube
                        , p2.case_cube))
                    FROM
                        pm    p2,
                        inv   i3
                    WHERE
                        p2.prod_id = i3.prod_id
                        AND p2.cust_pref_vendor = i3.cust_pref_vendor
                        AND i3.plogi_loc = l.logi_loc
                ) )
                           AND NOT EXISTS (
                    SELECT
                        'x'
                    FROM
                        pm    p3,
                        inv   k
                    WHERE
                        p3.prod_id = k.prod_id
                        AND p3.cust_pref_vendor = k.cust_pref_vendor
                        AND k.plogi_loc = i.plogi_loc
                        AND ( ( ( stackable > 0 )
                                AND ( p3.stackable > stackable
                                      OR p3.stackable = 0 ) )
                              OR ( p3.stackable = 0 ) )
                ) ) )
                AND l.logi_loc = z.logi_loc
                AND l.perm = 'N'
                AND l.status = 'AVL'
                AND ( DECODE(l.pallet_type, 'FW', 'LW', l.pallet_type) = DECODE(pallet_type, 'FW', 'LW', pallet_type)
                      OR l.pallet_type IN (
                    SELECT
                        mixed_pallet
                    FROM
                        pallet_type_mixed ptm
                    WHERE
                        ptm.pallet_type = pallet_type
                ) )
                AND z.logi_loc = i.plogi_loc
                AND z.zone_id = zone_id
                AND ( i.prod_id <> g_prod_id
                      OR i.cust_pref_vendor <> l_cust_pref_vendor )
            ORDER BY
                l.cube,
                abs(put_aisle1 - l.put_aisle),
                put_aisle,
                abs(put_slot1 - l.put_slot),
                l.put_slot,
                abs(put_level1 - l.put_level),
                l.put_level;

            status := f_bulk_avail_slot_assign_loop(0);
        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'No bulk slots having different item in zone with correct stackability', sqlcode
                , sqlerrm);
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending Bulk_avail_slot_assign for item', sqlcode, sqlerrm);
        RETURN status;
    END f_bulk_avail_slot_assign; 
    
  /***************************************************************** 
  **  
  **  Description:  loop throught all open slot and check if   
  **                space is enough for a pallet   
  **  Called By : f_check_open_slot 
  **  PARAMETERS: 
  **      
  **  RETURN VALUES: 
  **      TRUE for success 
  **      FALSE For Failure 
  **     
  ****************************************************************/

    FUNCTION f_open_slot_assign_loop RETURN VARCHAR2 AS

        l_index       NUMBER := 0;
        l_func_name   VARCHAR2(50) := 'f_open_slot_assign_loop';
        pallet_cnt    NUMBER := 0;
        location      VARCHAR2(10);
        status        NUMBER := 0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside f_open_slot_assign_loop ', sqlcode, sqlerrm);
        IF ( ( l_index <= total_cnt ) AND ( current_pallet < num_pallet ) AND ( max_slot > slot_cnt ) ) THEN 
        /* If found space for ti-averaged-pallet */
            IF ( ( loc_cube >= home_slot_cube ) AND ( pallet_stack > pallet_cnt ) ) THEN
                IF ( ( current_pallet = ( num_pallet - 1 ) ) AND partial_pallet = C_TRUE AND ( home_slot_flag IS NOT NULL ) AND (
                location = phys_loc ) ) THEN
                    revisit_open_slot := 'TRUE';
                    return('FALSE');
                END IF;

                p_insert_table(phys_loc, ADD_RESERVE);
                IF ( location = phys_loc ) THEN
                    location := phys_loc;
                END IF;
                pallet_cnt := pallet_cnt + 1;
                IF ( current_pallet < num_pallet ) THEN
                    IF ( stackable > 0 ) THEN
                        loc_cube := loc_cube - std_pallet_cube;
                    ELSE
                        slot_cnt := slot_cnt + 1;
                        l_index := l_index + 1;
                        pallet_cnt := 0;
                    END IF;
                END IF;

            ELSE
                slot_cnt := slot_cnt + 1;
                l_index := l_index + 1;
                pallet_cnt := 0;
            END IF;
        END IF;

        IF ( current_pallet >= num_pallet ) THEN
            status := C_TRUE;
        ELSE
             status := C_FALSE;
        END IF;
      RETURN status;
    END f_open_slot_assign_loop; 
    
  /***************************************************************** 
  **  
  **  Description: To  Find open slot of the same aisle as putaway slot 
  **  Called By : f_general_rule 
  **  PARAMETERS:  
  **      
  **  RETURN VALUES: 
  **      TRUE for success 
  **      FALSE For Failure 
  **     
  ****************************************************************/

    FUNCTION f_check_open_slot (
        dest_loc VARCHAR2
    ) RETURN VARCHAR2 AS

        l_func_name             VARCHAR2(30) := 'f_check_open_slot';
        more                    VARCHAR2(5) := 'FALSE';
        more_slot               VARCHAR2(5) := 'TRUE';
        status                  VARCHAR2(5) := 0;
        aisle                   NUMBER;
        lcube                   NUMBER;
        pcubel                  NUMBER;
        slot_type1              VARCHAR2(15);
        d_putaway_pallet_cube   NUMBER; 
    /* Cube of the pallet being putaway.  It could be a full pallet or a partial pallet. */
        CURSOR each_aisle1 IS
        SELECT DISTINCT
            l.put_aisle,
            l.cube,
            p.cube
        FROM
            pallet_type   p,
            slot_type     s,
            loc           l,
            lzone         z
        WHERE
            p.pallet_type = l.pallet_type
            AND s.slot_type = l.slot_type
            AND s.deep_ind = 'N'
            AND ( ( ( g_pallet_type_flag = 'Y'
                      AND p.cube >= pallet_cube )
                    AND ( l.pallet_type = l_pallet_type
                          OR ( l.pallet_type IN (
                SELECT
                    mixed_pallet
                FROM
                    pallet_type_mixed pmix
                WHERE
                    pmix.pallet_type = pallet_type
            ) ) ) )
                  OR ( ( g_pallet_type_flag = 'N'
                         AND p.cube >= pallet_cube )
                       AND ( s.slot_type = slot_type1 ) ) )
            AND l.perm = 'N'
            AND l.status = 'AVL'
            AND l.cube >= home_slot_cube
            AND z.logi_loc = l.logi_loc
            AND z.zone_id = zone_id
        ORDER BY
            p.cube,
            l.cube,
            abs(put_aisle1 - l.put_aisle),
            l.put_aisle;

    BEGIN 
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside f_check_open_slot ', sqlcode, sqlerrm);
         /* 
         **  Load Oracle variables from parameters. 
         */
        IF ( ( current_pallet = ( num_pallet - 1 ) ) AND partial_pallet IS NOT NULL ) THEN
            d_putaway_pallet_cube := lst_pallet_cube;
        ELSE
            d_putaway_pallet_cube := std_pallet_cube;
        END IF; 

      /***************************************************************/ 
      /* Find open slot for standard pallet, the slot count for this */ 
      /* prod_id can not exceed max_slot in this zone. The open slots*/ 
      /* in this aisle are select into array order from nearest to   */ 
      /* farest.                                                     */ 
      /***************************************************************/

        IF ( max_slot_flag = 'Z' ) THEN
            SELECT
                COUNT(DISTINCT i.plogi_loc)
            INTO slot_cnt
            FROM
                lzone   l,
                inv     i
            WHERE
                l.logi_loc = i.plogi_loc
                AND l.zone_id = zone_id
                AND i.cust_pref_vendor = cust_pref_vendor
                AND i.prod_id = prod_id;

            BEGIN
                IF ( slot_cnt IS NOT NULL ) THEN
                    WHILE ( ( more_slot = 'TRUE' ) AND ( max_slot > slot_cnt ) ) LOOP
                        more_slot := 'FALSE';
                        p_clear_array();
                        BEGIN
                            SELECT
                                l.logi_loc,
                                l.cube,
                                l.put_slot,
                                l.put_level,
                                p.cube,
                                l.put_path
                            INTO
                                phys_loc,
                                loc_cube,
                                put_slot2,
                                put_level2,
                                pcube,
                                put_path2
                            FROM
                                pallet_type   p,
                                slot_type     s,
                                loc           l,
                                lzone         z
                            WHERE
                                p.pallet_type = l.pallet_type
                                AND s.slot_type = l.slot_type
                                AND s.deep_ind = deep_ind
                                AND ( ( ( g_pallet_type_flag = 'Y' )
                                        AND ( l.pallet_type = l_pallet_type
                                              OR ( l.pallet_type IN (
                                    SELECT
                                        mixed_pallet
                                    FROM
                                        pallet_type_mixed pmix
                                    WHERE
                                        pmix.pallet_type = l_pallet_type
                                ) ) ) )
                                      OR ( ( g_pallet_type_flag = 'N' )
                                           AND ( s.slot_type = slot_type1 ) ) )
                                AND l.perm = 'N'
                                AND l.status = 'AVL'
                                AND l.cube >= d_putaway_pallet_cube
                                AND l.logi_loc = z.logi_loc
                                AND z.zone_id = zone_id
                                AND NOT EXISTS (
                                    SELECT
                                        'x'
                                    FROM
                                        inv i
                                    WHERE
                                        i.plogi_loc = l.logi_loc
                                )
                            ORDER BY
                                p.cube,
                                l.cube,
                                abs(put_aisle1 - l.put_aisle),
                                l.put_aisle,
                                abs(put_slot1 - l.put_slot),
                                l.put_slot,
                                abs(put_level1 - l.put_level),
                                l.put_level;

                            more := 'FALSE';
                        EXCEPTION
                            WHEN no_data_found THEN
                                more := 'TRUE';
                                pl_text_log.ins_msg_async('FATAL', l_func_name, 'Number of open slots found in zone', sqlcode, sqlerrm); 

                        /* 
                        ** Found an open slot 
                        ** Assign qty to the slot 
                        */
                                status := f_open_slot_assign_loop();
                                IF ( ( status = 'FALSE' ) AND ( more = 'TRUE' ) AND ( revisit_open_slot = 'FALSE' ) ) THEN
                                    more_slot := 'TRUE';
                                END IF;

                        END;

                    END LOOP;

                ELSE
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get count of slots occupied by item in zone', sqlcode, sqlerrm
                    );
                END IF;

            END;

        ELSE
            FETCH each_aisle1 INTO
                aisle,
                lcube,
                pcubel; 

        /* FOR each_aisle1_rec IN each_aisle1  */
            LOOP
                SELECT
                    COUNT(DISTINCT i.plogi_loc)
                INTO slot_cnt
                FROM
                    lzone   z,
                    loc     l,
                    inv     i
                WHERE
                    z.logi_loc = l.logi_loc
                    AND z.zone_id = zone_id
                    AND l.logi_loc = i.plogi_loc
                    AND l.put_aisle = aisle
                    AND i.cust_pref_vendor = l_cust_pref_vendor
                    AND i.prod_id = g_prod_id;

                IF ( max_slot > slot_cnt ) THEN
                    more_slot := 'TRUE';
                    WHILE ( more_slot = 'TRUE' ) AND ( max_slot > slot_cnt ) LOOP
                        more_slot := 'FALSE';
                        p_clear_array(); 

                  /* 
                                 **  Aisle order by not necessary since selecting only 
                                 **  one aisle. 
                                 */
                        BEGIN
                            SELECT
                                l.logi_loc,
                                l.cube,
                                l.put_aisle,
                                l.put_slot,
                                l.put_level,
                                p.cube,
                                l.put_path
                            INTO
                                phys_loc,
                                loc_cube,
                                put_aisle2,
                                put_slot2,
                                put_level2,
                                pcube,
                                put_path2
                            FROM
                                pallet_type   p,
                                slot_type     s,
                                loc           l,
                                lzone         z
                            WHERE
                                p.pallet_type = l.pallet_type
                                AND p.cube = pcubel
                                AND s.slot_type = l.slot_type
                                AND s.deep_ind = 'N'
                                AND l.perm = 'N'
                                AND l.status = 'AVL'
                                AND l.cube = lcube
                                AND l.put_aisle = aisle
                                AND l.logi_loc = z.logi_loc
                                AND z.zone_id = zone_id
                                AND NOT EXISTS (
                                    SELECT
                                        'x'
                                    FROM
                                        inv i
                                    WHERE
                                        i.plogi_loc = l.logi_loc
                                )
                            ORDER BY
                                p.cube,
                                l.cube,
                                abs(put_slot1 - l.put_slot),
                                l.put_slot,
                                abs(put_level1 - l.put_level),
                                l.put_level;

                            more := 'FALSE';
                        EXCEPTION
                            WHEN no_data_found THEN
                                more := 'TRUE';
                                status := f_open_slot_assign_loop();
                                IF ( revisit_open_slot = 'TRUE' ) THEN
                                    return('FALSE');
                                END IF;
                                IF ( ( status = 'FALSE' ) AND more = 'TRUE' ) THEN
                                    more_slot := 'TRUE';
                                END IF;

                        END;

                        IF ( status = 'TRUE' ) THEN
                            return('TRUE');
                        END IF;
                    END LOOP;

                END IF;

            END LOOP;

        END IF;

        return(status);
    END f_check_open_slot; 
    
  /***************************************************************************** 
  **   p_insert_table() 
  **  Description: 
  **     Insert into inv and putawaylst tables. 
  ** 
  **  Parameters: 
  **     p_dest_loc 
  **     home 
  ** 
  **  Return Values:   
  **     None 
  ** 
  **  Called By: p_one_pallet_label,f_general_rule 
  ** 
  *************************************************************************/

    PROCEDURE p_insert_table (
        p_dest_loc   IN           VARCHAR2,
        home         IN           NUMBER
    ) AS

        l_func_name           VARCHAR2(50) := 'p_insert_table';
        status                NUMBER := 1;
        run_strg              VARCHAR2(10);
        i                     NUMBER := 0;
        be_in_loop            NUMBER := 1;
        dest_loc              VARCHAR2(10);
        pallet_id             VARCHAR2(20);
        tmp_check             VARCHAR2(1);
        clam_bed_trk          VARCHAR2(1);
        loop_in_out           VARCHAR2(1);
        ca_parent_pallet_id   VARCHAR2(20);
        ca_lot_id             VARCHAR2(30);
        ca_lot_id_ind         VARCHAR2(30);
        ca_exp_date           VARCHAR2(10);
        ca_exp_date_ind       VARCHAR2(30);
        ca_mfg_date           VARCHAR2(9);
        ca_mfg_date_ind       VARCHAR2(30);
        i_catch_weight        NUMBER := 0;
        i_catch_weight_ind    NUMBER := 0;
        i_po_line_id          NUMBER := 0;
        i_total_cases         NUMBER := 0;
        length_unit           VARCHAR2(5);
        tti_trk               VARCHAR2(1);
        ca_rdc_po             VARCHAR2(10) := '          ';
        i_pallet_qty          NUMBER := 0;
        i_total_weight        NUMBER := 0.0;
        l_status              VARCHAR2(100);
        l_pallet_id           putawaylst.pallet_id%TYPE;
    BEGIN
       pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting p_insert_table with dest loc = ' || p_dest_loc || ca_dmg_ind, sqlcode, sqlerrm); 
        dest_loc := p_dest_loc;
        IF ( ca_dmg_ind = 'DMG' ) THEN
            BEGIN
                SELECT
                    pallet_id
                INTO l_pallet_id
                FROM
                    putawaylst
                WHERE
                    rec_id = g_erm_num
                    AND prod_id = g_prod_id
                    AND cust_pref_vendor = g_cpv
                    AND qty = each_pallet_qty
                    AND dest_loc = '*'
                    AND status = 'DMG';

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get damaged pallet id for prod_id = ' || g_prod_id || 
                    ' CPV = ' || g_cpv, sqlcode, sqlerrm);
                WHEN OTHERS THEN
                  pl_text_log.ins_msg_async('INFO', l_func_name, 'OTHERS : Unable to get damaged pallet id for prod_id = ' || g_prod_id || 
                    ' CPV = ' || g_cpv, sqlcode, sqlerrm);
                
            END;
        /*
        ** processing for regular pallets
        ** the following incorporates the changes for Dont Print LPN ,SN receipt
        */     
        ELSE
        BEGIN
                SELECT
                    erm_type
                INTO l_erm_type
                FROM
                    erm
                WHERE
                    erm_id = g_erm_num;

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get erm type for erm id = ' || g_erm_num, sqlcode, sqlerrm);
                    ROLLBACK;
                    RETURN;
            END;
        /*
         **if erm_id is not SN then pallet_id has to be generated otherwise not.
         ** SN will have pallets with pallet_ids so pallet_id is not to be
         **generated for SN
         */
         
            IF ( ( substr(l_erm_type, 1, 2) != 'SN' ) OR ( g_reprocess_flag = C_TRUE ) ) THEN
                WHILE ( be_in_loop = 1 ) LOOP 
                
                    SELECT
                        TO_CHAR(pallet_id_seq.NEXTVAL)
                    INTO pallet_id
                    FROM
                        dual;

                    IF pallet_id IS NULL THEN
                        pl_text_log.ins_msg_async('FATAL', l_func_name, 'Unable to generate pallet id seq no.', sqlcode, sqlerrm);
                        l_status := 'Unable to generate pallet id seq no';
                        ROLLBACK;
                        return;
                    END IF;
 
                    BEGIN
                        SELECT
                            'X'
                        INTO loop_in_out
                        FROM
                            dual
                        WHERE
                            NOT EXISTS (
                                SELECT
                                    'inv'
                                FROM
                                    inv b
                                WHERE
                                    b.logi_loc = pallet_id
                            )
                                AND NOT EXISTS (
                                SELECT
                                    'putaway'
                                FROM
                                    putawaylst c
                                WHERE
                                    c.pallet_id = pallet_id
                            );

                    EXCEPTION
                        WHEN no_data_found THEN
                            be_in_loop := 0;
                        WHEN OTHERS THEN
                            be_in_loop := 0;
                    END;

                    IF ( loop_in_out = 'X' ) THEN 
                     /* Then break the loop */
                        be_in_loop := 0;
                    END IF;
                END LOOP;

                IF ( ( substr(l_erm_type, 1, 2) = 'SN' ) AND ( g_reprocess_flag = C_TRUE ) ) THEN
                    BEGIN
                        SELECT
                            MIN(po_no),
                            MIN(po_line_id),
                            NULL,
                            NULL
                        INTO
                            ca_rdc_po,
                            i_po_line_id,
                            ca_exp_date,
                            ca_mfg_date
                        FROM
                            erd_lpn
                        WHERE
                            prod_id = g_prod_id
                            AND cust_pref_vendor = g_cpv
                            AND po_no = (
                                SELECT
                                    MIN(po_no)
                                FROM
                                    erd_lpn
                                WHERE
                                    sn_no = g_erm_num
                                    AND prod_id = g_prod_id
                                    AND cust_pref_vendor = g_cpv
                            );

                    EXCEPTION
                        WHEN no_data_found THEN
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get value from erd_pln table', sqlcode, sqlerrm);
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'OTHERS : Unable to get value from erd_pln table', sqlcode, sqlerrm);
                    END;

                END IF;

            ELSE
              /*
               ** SN Receipt and Dont print LPN changes ..begin
               ** for a SN info is sent from RDC which is populated in the
               ** erd_lpn table.  So for SN retrieve the info from erd_lpn table
               ** for the given erm_id,prod_id,qty and CPVN retrieve one pallet
               ** for which dest_loc has not been identified.  This is indicated
               ** by the status of pallet_assigned_flag-N denotes that the
               ** dest_loc for the pallet has not been identified.
               */
                 pl_text_log.ins_msg_async('INFO', l_func_name, 'checking  else of SN ' , sqlcode, sqlerrm); 
                i_pallet_qty := each_pallet_qty * spc;
                BEGIN
                    SELECT
                        pallet_id,
                        parent_pallet_id,
                        catch_weight,
                        lot_id,
                        DECODE(sign(exp_date - SYSDATE - 3650), 1, NULL, TO_CHAR(exp_date, 'MMDDYYYY')),
                        TO_CHAR(mfg_date, 'MMDDYYYY'),
                        po_no,
                        po_line_id
                    INTO
                        l_pallet_id,
                        ca_parent_pallet_id,
                        i_catch_weight,
                        ca_lot_id,
                        ca_exp_date,
                        ca_mfg_date,
                        ca_rdc_po,
                        i_po_line_id
                    FROM
                        erd_lpn
                    WHERE
                        sn_no = g_erm_num
                        AND erm_line_id = g_erm_line_id
                        AND pallet_assigned_flag = 'N';

                EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get value from erd_pln table', sqlcode, sqlerrm);
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'OTHERS : Unable to get value from erd_pln table', sqlcode, sqlerrm);    
                END;

                seq_no := g_erm_line_id;
                   pl_text_log.ins_msg_async('INFO', l_func_name, 'checking seq_no =  ' || seq_no, sqlcode, sqlerrm); 
                BEGIN
                    SELECT
                        nvl(SUM(catch_weight), 0),
                        nvl(SUM(qty), 0)
                    INTO
                        i_total_weight,
                        i_total_cases
                    FROM
                        erd_lpn
                    WHERE
                        prod_id = g_prod_id
                        AND cust_pref_vendor = g_cpv
                        AND sn_no = g_erm_num;

                EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get weight from erd_pln table', sqlcode, sqlerrm);
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'OTHERS : Unable to get weight from erd_pln table', sqlcode, sqlerrm);
    
                END;
                 /*
                 ** the pallet_assigned_flag is updated to Y
                ** to indicate that the dest_loc for this pallet has been identified
                */
                      pl_text_log.ins_msg_async('INFO', l_func_name, 'checking updatin erd_lpn l_pallet_id = ' || l_pallet_id, sqlcode, sqlerrm); 
                BEGIN
                    UPDATE erd_lpn
                    SET
                        pallet_assigned_flag = 'Y'
                    WHERE
                        pallet_id = l_pallet_id;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to update erd_pln table for pallet id = ' || l_pallet_id , sqlcode, sqlerrm);
                END;

            END IF;

        END IF; /* OSD changes end ELSE for damage */
      
        seq_no := seq_no + 1;
        IF ( home = ADD_HOME ) THEN
            BEGIN
                length_unit := pl_common.f_get_syspar('LENGTH_UNIT', 'IN');
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to get Length unit syspar', sqlcode, sqlerrm);
            END;

            IF ( first_home_assign = 'TRUE' ) THEN
                BEGIN
                    UPDATE inv
                    SET
                        qty_planned = qty_planned + each_pallet_qty * spc,
                        cube = DECODE(length_unit, 'CM', DECODE(sign(99999999.9999 -(nvl(cube, 0) +(each_pallet_qty * case_cube) +
                        skid_cube)), - 1, 99999999.9999,(nvl(cube, 0) +(each_pallet_qty * case_cube) + skid_cube)),
                        DECODE(sign(99999.99 -(nvl(cube, 0) +(each_pallet_qty * case_cube) + skid_cube)), - 1, 99999.99,
                        (nvl(cube, 0) +(each_pallet_qty
                        * case_cube) + skid_cube)))
                    WHERE
                        plogi_loc = dest_loc
                        AND cust_pref_vendor = g_cpv
                        AND prod_id = g_prod_id;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to update inv table', sqlcode, sqlerrm);
                END;

            ELSE
                BEGIN
                    UPDATE inv
                    SET
                        qty_planned = qty_planned + each_pallet_qty * spc,
                        cube = DECODE(length_unit, 'CM', DECODE(sign(99999999.9999 -(nvl(cube, 0) +(each_pallet_qty * case_cube))
                        ), - 1, 99999999.9999,(nvl(cube, 0) +(each_pallet_qty * case_cube))), DECODE(sign(99999.99 -(nvl(cube, 0)
                        +(each_pallet_qty * case_cube))), - 1, 99999.99,(nvl(cube, 0) +(each_pallet_qty * case_cube))))
                    WHERE
                        plogi_loc = dest_loc
                        AND cust_pref_vendor = g_cpv
                        AND prod_id = g_prod_id;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to update inv table', sqlcode, sqlerrm);
                END;
            END IF;

        ELSIF ( home = ADD_RESERVE ) THEN
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
                    lst_cycle_date,
                    cube,
                    abc_gen_date,
                    cust_pref_vendor,
                    exp_date
                ) VALUES (
                    dest_loc,
                    pallet_id,
                    g_prod_id,
                    g_erm_num,
                    each_pallet_qty * spc,
                    0,
                    0,
                    0,
                    SYSDATE,
                    SYSDATE,
                    abc,
                    DECODE(aging_days, - 1, 'AVL', 'HLD'),
                    SYSDATE,
                    DECODE(length_unit, 'CM', DECODE(sign(99999999.9999 -((each_pallet_qty * case_cube) + skid_cube)), - 1, 
                    99999999.9999,((each_pallet_qty * case_cube) + skid_cube)),
                    DECODE(sign(99999.99 -((each_pallet_qty * case_cube) + skid_cube
                    )), - 1, 99999.99,((each_pallet_qty * case_cube) + skid_cube))),
                    SYSDATE,
                    g_cpv,
                    trunc(SYSDATE)
                );

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to update inv table', sqlcode, sqlerrm);
            END;
        END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'checking clam_bed_trk = ' , sqlcode, sqlerrm); 
        IF ( f_is_clam_bed_tracked_item(pm_category) = 1 ) THEN
            clam_bed_trk := 'Y';
        ELSE
            clam_bed_trk := 'N';
        END IF;

        IF ( f_is_tti_tracked_item() = 1 ) THEN
            tti_trk := 'Y';
        ELSE
            tti_trk := 'N';
        END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'checked tti_trk = ' || tti_trk, sqlcode, sqlerrm); 
        IF ( ca_dmg_ind = 'DMG' ) THEN
            BEGIN
                UPDATE putawaylst p
                SET
                    p.dest_loc = dest_loc,
                    p.inv_status = 'HLD'
                WHERE
                    p.pallet_id = l_pallet_id;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to update putawaylst ', sqlcode, sqlerrm);
            END;

            BEGIN
                UPDATE inv
                SET
                    status = 'HLD',
                    dmg_ind = 'Y'
                WHERE
                    logi_loc = l_pallet_id;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to update inv status ', sqlcode, sqlerrm);
            END;

        ELSE
        
            pl_text_log.ins_msg_async('INFO', l_func_name, 'checking else of ca_dmg_ind ' , sqlcode, sqlerrm); 
            BEGIN
                UPDATE trans
                SET
                    mfg_date = SYSDATE
                WHERE
                    trans_type = 'RHB'
                    AND prod_id = g_prod_id
                    AND cust_pref_vendor = g_cpv
                    AND rec_id = g_erm_num
                    AND ROWNUM = 1;

                SELECT
                    'C'
                INTO clam_bed_trk
                FROM
                    trans
                WHERE
                    trans_type = 'RHB'
                    AND prod_id = g_prod_id
                    AND cust_pref_vendor = g_cpv
                    AND rec_id = g_erm_num
                    AND ROWNUM = 1;

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Select Failed for clam bed track', sqlcode, sqlerrm);
                WHEN OTHERS THEN
                     pl_text_log.ins_msg_async('INFO', l_func_name, 'OTEHRS Select Failed for clam bed track', sqlcode, sqlerrm);
            END;
            pl_text_log.ins_msg_async('INFO', l_func_name, ' Before putawaylst insert', sqlcode, sqlerrm);
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
                    temp_trk,
                    catch_wt,
                    lot_trk,
                    exp_date_trk,
                    date_code,
                    equip_id,
                    rec_lane_id,
                    seq_no,
                    putaway_put,
                    cust_pref_vendor,
                    exp_date,
                    clam_bed_trk,
                    lot_id,
                    weight,
                    mfg_date,
                    sn_no,
                    po_no,
                    po_line_id,
                    tti_trk,
                    cool_trk
                ) VALUES (
                    g_erm_num,
                    g_prod_id,
                    dest_loc,
                    each_pallet_qty * spc,
                    0,
                    'NEW',
                    DECODE(aging_days, - 1, 'AVL', 'HLD'),
                    pallet_id,
                    each_pallet_qty * spc,
                    each_pallet_qty * spc,
                    temp_trk,
                    DECODE(l_erm_type, 'SN', DECODE(catch_wt, 'N', 'N', DECODE(i_catch_weight_ind, - 1, catch_wt, 'C')), catch_wt
                    ),
                    DECODE(l_erm_type, 'SN', DECODE(lot_trk, 'N', 'N', DECODE(ca_lot_id, NULL, lot_trk, 'C')), lot_trk),
                    DECODE(l_erm_type, 'SN', DECODE(exp_date_trk, 'N', 'N', DECODE(ca_exp_date, NULL, exp_date_trk, 'C')), exp_date_trk
                    ),
                    DECODE(l_erm_type, 'SN', DECODE(date_code, 'N', 'N', DECODE(ca_mfg_date, NULL, date_code, 'C')), date_code),
                    ' ',
                    ' ',
                    seq_no,
                    'N',
                    g_cpv,
                    DECODE(l_erm_type, 'SN', DECODE(exp_date_trk, 'Y', nvl(TO_DATE(ca_exp_date, 'FXMMDDYYYY'), trunc(SYSDATE)), trunc
                    (SYSDATE)), trunc(SYSDATE)),
                    clam_bed_trk,
                    DECODE(l_erm_type, 'SN', DECODE(lot_trk, 'Y', ca_lot_id, NULL), NULL),
                    DECODE(l_erm_type, 'SN', DECODE(catch_wt, 'Y', i_catch_weight, NULL), NULL),
                    DECODE(l_erm_type, 'SN', DECODE(date_code, 'Y', TO_DATE(ca_mfg_date, 'FXMMDDYYYY'), NULL), NULL),
                    DECODE(l_erm_type, 'SN', g_erm_num, NULL),
                    DECODE(l_erm_type, 'SN', ca_rdc_po, g_erm_num),
                    DECODE(l_erm_type, 'SN', i_po_line_id, NULL),
                    tti_trk,
                    'N'
                );

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'ORACLE unable to create putaway record for pallet.', sqlcode, sqlerrm);
                    l_status := 'Unable to insert into putawaylst for pallet id ';
                    ROLLBACK;
                    return;
            END;

        END IF;

        IF ( catch_wt = 'Y' ) THEN
            BEGIN
                SELECT
                    'X'
                INTO tmp_check
                FROM
                    tmp_weight
                WHERE
                    erm_id = g_erm_num
                    AND prod_id = g_prod_id
                    AND cust_pref_vendor = g_cpv;

            EXCEPTION
                WHEN no_data_found THEN
                    INSERT INTO tmp_weight (
                        erm_id,
                        prod_id,
                        cust_pref_vendor,
                        total_cases,
                        total_splits,
                        total_weight
                    ) VALUES (
                        g_erm_num,
                        g_prod_id,
                        g_cpv,
                        DECODE(l_erm_type, 'SN', DECODE(i_total_weight, 0, 0, i_total_cases), 0),
                        0,
                        i_total_weight
                    );
                 WHEN OTHERS THEN
                  pl_text_log.ins_msg_async('INFO', l_func_name, 'OTHERS : Unable to insert data into tmp_weight ' , sqlcode, sqlerrm); 

            END;
        END IF;

        IF ( g_reprocess_flag = C_TRUE ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Before system call for demand print of license plate', sqlcode, sqlerrm);
            BEGIN
                INSERT INTO trans (
                    trans_id,
                    trans_type,
                    rec_id,
                    trans_date,
                    user_id,
                    pallet_id,
                    qty,
                    prod_id,
                    cust_pref_vendor,
                    uom,
                    exp_date
                ) VALUES (
                    trans_id_seq.NEXTVAL,
                    DECODE(ca_dmg_ind, 'DMG', 'DMG', 'DLP'),
                    g_erm_num,
                    SYSDATE,
                    user,
                    pallet_id,
                    each_pallet_qty * spc,
                    g_prod_id,
                    g_cpv,
                    0,
                    trunc(SYSDATE)
                );

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Table = trans Action=Insert Message = insert table failed', sqlcode, sqlerrm
                    );
                    l_status := 'unable to create DMG/DLP transaction';
                    ROLLBACK;
                    RETURN;
            END;

        END IF;

    END p_insert_table; 
    
  /***************************************************************************** 
  **  f_general_rule 
  **  DESCRIPTION: 
  **      Find home slot as putaway slot. 
  **  PARAMETERS: 
  **      flag - Indicates if this function is being called using the 
  **             items primary putaway zone or if it is being called using 
  **             a zone from next zones. 
  **  RETURN VALUES: 
  **      TRUE  - Success. 
  **      FALSE - Failure 
  *****************************************************************************/

    FUNCTION f_general_rule (
        flag IN VARCHAR2
    ) RETURN VARCHAR2 IS

        l_func_name         VARCHAR2(50) := 'f_general_rule';
        dest_loc            VARCHAR2(10);
        dest_loc_array      VARCHAR2(10);
        dest                VARCHAR2(10);
        aisle1              VARCHAR2(5);
        slot1               VARCHAR2(10);
        level1              VARCHAR2(5);
        pcube1              VARCHAR2(10);
        home_slot_flag      VARCHAR2(2);
        done                VARCHAR2(5);
     --   ca_dmg_ind          VARCHAR2(3);
        revisit_open_slot   BOOLEAN;
        put_path1           VARCHAR2(20);
    BEGIN
     pl_text_log.ins_msg_async('INFO', l_func_name, 'f_general_rule with flag = ' || flag, sqlcode, sqlerrm);
        BEGIN
            IF flag = 'FIRST' THEN
                BEGIN
                    SELECT
                        l.logi_loc,
                        nvl(l.cube, 0),
                        l.put_aisle,
                        l.put_slot,
                        l.put_level,
                        l.slot_type,
                        s.deep_ind,
                        l.put_path
                    INTO
                        dest_loc,
                        home_loc_cube,
                        put_aisle1,
                        put_slot1,
                        put_level1,
                        slot_type,
                        deep_ind,
                        put_path1
                    FROM
                        slot_type   s,
                        loc         l
                    WHERE
                        s.slot_type = l.slot_type
                        AND l.uom IN (
                            0,
                            2
                        )
                        AND l.perm = 'Y'
                        AND l.rank = 1
                        AND l.cust_pref_vendor = l_cust_pref_vendor
                        AND l.prod_id = g_prod_id;

                EXCEPTION
                    WHEN no_data_found THEN
                        IF aging_days = -1 THEN
                            pl_text_log.ins_msg_async('FATAL', l_func_name, 'ORACLE No case home slot found for item', sqlcode, sqlerrm);
                        ELSE
                            home_slot_flag := 0;
                            BEGIN
                                SELECT
                                    logi_loc,
                                    nvl(cube, 0),
                                    put_aisle,
                                    put_slot,
                                    put_level,
                                    slot_type,
                                    deep_ind,
                                    put_path
                                INTO
                                    dest_loc,
                                    home_loc_cube,
                                    put_aisle1,
                                    put_slot1,
                                    put_level1,
                                    slot_type,
                                    deep_ind,
                                    put_path1
                                FROM
                                    (
                                        SELECT
                                            l.logi_loc    logi_loc,
                                            nvl(l.cube, 0) cube,
                                            l.put_aisle   put_aisle,
                                            l.put_slot    put_slot,
                                            l.put_level   put_level,
                                            l.slot_type   slot_type,
                                            s.deep_ind    deep_ind,
                                            l.put_path    put_path
                                        FROM
                                            slot_type   s,
                                            loc         l,
                                            lzone       lz,
                                            pm          p
                                        WHERE
                                            s.slot_type = l.slot_type
                                            AND p.pallet_type = l.pallet_type
                                            AND p.prod_id = g_prod_id
                                            AND p.cust_pref_vendor = l_cust_pref_vendor
                                            AND l.status = 'AVL'
                                            AND lz.logi_loc = l.logi_loc
                                            AND lz.zone_id = l_zone_id
                                            AND l.perm = 'N'
                                            AND EXISTS (
                                                SELECT
                                                    NULL
                                                FROM
                                                    inv i
                                                WHERE
                                                    prod_id = g_prod_id
                                                    AND cust_pref_vendor = l_cust_pref_vendor
                                                    AND plogi_loc = l.logi_loc
                                            )
                                            AND NOT EXISTS (
                                                SELECT
                                                    NULL
                                                FROM
                                                    inv i
                                                WHERE
                                                    plogi_loc = l.logi_loc
                                                    AND dmg_ind = 'Y'
                                            ) 
                                /* slots with damaged pallets not to be chosen*/
                                        ORDER BY
                                            l.cube
                                    )
                                WHERE
                                    ROWNUM = 1;

                            EXCEPTION
                                WHEN OTHERS THEN
                                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'ORACLE No reserved or floating slot found for aging item'
                                    , sqlcode, sqlerrm);
                            END;

                        END IF;
                END;
            ELSIF flag = 'SECOND' THEN
                BEGIN
                    SELECT
                        l.logi_loc,
                        l.put_aisle,
                        l.put_slot,
                        l.put_level
                    INTO
                        dest,
                        aisle1,
                        slot1,
                        level1
                    FROM
                        lzone   z,
                        loc     l,
                        inv     i
                    WHERE
                        z.logi_loc = l.logi_loc
                        AND z.zone_id = l_zone_id
                        AND l.logi_loc = i.plogi_loc
                        AND i.cust_pref_vendor = l_cust_pref_vendor
                        AND i.prod_id = g_prod_id 
                /* We are not concern dmg_ind for now (D#11627) 
                    AND i.dmg_ind <> 'Y' */ 
                /*acppzp slots with damaged pallets not to be chosen*/
                    ORDER BY
                        i.exp_date,
                        i.qoh;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('FATAL', l_func_name, 'No inventory found in next zone', sqlcode, sqlerrm);
                        IF home_slot_flag != 0 THEN
                            SELECT
                                l.logi_loc,
                                l.put_aisle,
                                l.put_slot,
                                l.put_level,
                                p.cube
                            INTO
                                dest,
                                aisle1,
                                slot1,
                                level1,
                                pcube1
                            FROM
                                slot_type     s,
                                pallet_type   p,
                                loc           l,
                                lzone         z
                            WHERE
                                s.slot_type = l.slot_type
                                AND s.deep_ind = deep_ind
                                AND p.pallet_type = l.pallet_type
                                AND ( ( ( g_pallet_type_flag = 'Y'
                                          AND p.cube >= pallet_cube )
                                        AND ( l.pallet_type = l_pallet_type
                                              OR ( l.pallet_type IN (
                                    SELECT
                                        mixed_pallet
                                    FROM
                                        pallet_type_mixed pmix
                                    WHERE
                                        pmix.pallet_type = l_pallet_type
                                ) ) ) )
                                      OR ( ( g_pallet_type_flag = 'N'
                                             AND p.cube >= pallet_cube ) ) )
                                AND l.perm = 'N'
                                AND l.status = 'AVL'
                                AND l.cube >= std_pallet_cube
                                AND z.logi_loc = l.logi_loc
                                AND z.zone_id = l_zone_id
                                AND NOT EXISTS (
                                    SELECT
                                        'x'
                                    FROM
                                        inv
                                    WHERE
                                        plogi_loc = l.logi_loc
                                )
                            ORDER BY
                                p.cube,
                                l.cube,
                                abs(put_aisle1 - l.put_aisle),
                                l.put_aisle,
                                abs(put_slot1 - l.put_slot),
                                l.put_slot,
                                abs(put_level1 - l.put_level),
                                l.put_level;

                        ELSE
                            SELECT
                                l.logi_loc,
                                l.put_aisle,
                                l.put_slot,
                                l.put_level
                            INTO
                                dest,
                                aisle1,
                                slot1,
                                level1
                            FROM
                                pallet_type   p,
                                slot_type     s,
                                loc           l,
                                lzone         z
                            WHERE
                                p.pallet_type = l.pallet_type
                                AND s.slot_type = l.slot_type
                                AND s.deep_ind = deep_ind
                                AND ( ( ( g_pallet_type_flag = 'Y'
                                          AND p.cube >= pallet_cube )
                                        AND ( l.pallet_type = l_pallet_type
                                              OR ( l.pallet_type IN (
                                    SELECT
                                        mixed_pallet
                                    FROM
                                        pallet_type_mixed pmix
                                    WHERE
                                        pmix.pallet_type = pallet_type
                                ) ) ) )
                                      OR ( ( g_pallet_type_flag = 'N'
                                             AND p.cube >= pallet_cube ) ) )
                                AND l.perm = 'N'
                                AND l.status = 'AVL'
                                AND l.cube >= std_pallet_cube
                                AND z.logi_loc = l.logi_loc
                                AND z.zone_id = zone_id
                                AND NOT EXISTS (
                                    SELECT
                                        'x'
                                    FROM
                                        inv
                                    WHERE
                                        plogi_loc = l.logi_loc
                                )
                            ORDER BY
                                l.cube,
                                l.put_slot;

                            put_aisle1 := aisle1;
                            put_slot1 := slot1;
                            put_level1 := level1;
                        END IF;

                END;
            END IF;

            home_slot_cube := home_loc_cube;
            
            IF flag = 1 AND aging_days = -1 THEN
                IF case_cube = 0 THEN
                    FOR i IN 1..num_pallet LOOP
                        case_cube := 1;
                        p_insert_table(dest_loc, 1);
                    END LOOP;

                    RETURN 'TRUE';
                END IF;

                home_slot_flag := 1;
                IF g_allow_flag = 'Y' AND ca_dmg_ind = 'DMG' THEN
                    done := f_check_home_slot(dest_loc, home_loc_cube);
                END IF;

                IF done = 'FALSE' AND ca_dmg_ind = 'DMG' AND deep_ind = 'Y' THEN
                    done := f_two_d_three_d(dest_loc);
                    RETURN done;
                END IF;

            END IF;

            IF done = 'FALSE' THEN
                IF num_pallet = 1 AND partial_pallet = C_TRUE AND stackable > 0 AND ca_dmg_ind = 'DMG' THEN
                    done := f_check_avail_slot_same_prod();
                END IF;

                IF ( done = 'FALSE' AND ( num_pallet = 1 ) AND ( partial_pallet = C_TRUE ) AND home_slot_flag != 0 ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, ' Set revisit_open_slot due to only partial pallet not putaway.', sqlcode
                    , sqlerrm);
                    revisit_open_slot := true;
                END IF;

                IF ( done = 'FALSE' AND ( num_pallet = 0 ) AND ( partial_pallet = C_FALSE ) ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, ' Not only partial and find open slots using dest_loc', sqlcode, sqlerrm)
                    ;
                    done := f_check_open_slot(dest_loc);
                END IF;

                IF ( done = 'FALSE' AND ( stackable > 0 ) ) THEN
                    IF ( ( ( num_pallet = 0 ) AND ( partial_pallet = C_FALSE ) ) AND ca_dmg_ind = 'DMG' ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, ' Not only partial and find same product slots', sqlcode, sqlerrm);
                        done := f_check_avail_slot_same_prod();
                    END IF;
                END IF;

                IF ( done = 'FALSE' AND ( stackable > 0 ) AND ca_dmg_ind != 'DMG' ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'find different product slots', sqlcode, sqlerrm);
                    done := f_check_avail_slot();
                END IF;

            END IF;

            IF ( done = 'FALSE' AND revisit_open_slot = true AND ( flag = 1 ) ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'revisiting open slots', sqlcode, sqlerrm);
                BEGIN
                    SELECT
                        l.logi_loc,
                        l.cube,
                        l.put_slot,
                        put_level,
                        p.cube,
                        l.put_path
                    INTO
                        dest_loc_array,
                        loc_cube,
                        put_slot2,
                        put_level2,
                        pcube,
                        put_path2
                    FROM
                        pallet_type   p,
                        slot_type     s,
                        loc           l,
                        lzone         z
                    WHERE
                        p.pallet_type = l.pallet_type
                        AND s.slot_type = l.slot_type
                        AND s.deep_ind = 'N'
                        AND ( ( ( g_pallet_type_flag = 'Y'
                                  AND p.cube >= pallet_cube )
                                AND ( l.pallet_type = l_pallet_type
                                      OR ( l.pallet_type IN (
                            SELECT
                                mixed_pallet
                            FROM
                                pallet_type_mixed pmix
                            WHERE
                                pmix.pallet_type = l_pallet_type
                        ) ) ) )
                              OR ( ( g_pallet_type_flag = 'N'
                                     AND p.cube >= pallet_cube ) ) )
                        AND l.perm = 'N'
                        AND l.status = 'AVL'
                        AND l.cube >= home_slot_cube
                        AND z.logi_loc = l.logi_loc
                        AND z.zone_id = zone_id
                        AND NOT EXISTS (
                            SELECT
                                'x'
                            FROM
                                inv
                            WHERE
                                plogi_loc = l.logi_loc
                        )
                    ORDER BY
                        p.cube,
                        l.cube,
                        abs(put_aisle1 - l.put_aisle),
                        l.put_aisle,
                        abs(put_slot1 - l.put_slot),
                        l.put_slot,
                        abs(put_level1 - l.put_level),
                        l.put_level;

                    each_pallet_qty := last_pallet_qty;
                    dest_loc := dest_loc_array;
                    p_insert_table(dest_loc, ADD_RESERVE);
                    RETURN 'TRUE';
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('FATAL', l_func_name, 'No open slots > than home cube in zone on revisit', sqlcode, sqlerrm
                        );
                END;

            END IF;

            IF ( done = 'FALSE' AND flag = 2 ) THEN
                IF ( deep_ind = 'Y' ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Using deep logic', sqlcode, sqlerrm);
                    done := f_two_d_three_d(dest_loc);
                END IF;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('FATAL', l_func_name, ' NEXT ZONE: No existing inventory and no open slots in zone.', sqlcode, sqlerrm
                );
                home_slot_flag := 0;
        END;

        RETURN done;
    END f_general_rule;

  /***************************************************************************** 
  **  p_po_reprocessing 
  **  DESCRIPTION: 
  **      To reprocess the demand pallet
  **  PARAMETERS: 
  **      p_po - Erm id 
  **      p_prod_id - Item#
  **      p_putaway_dimension - Putaway Dimension for the Po
  **      p_ca_dmg_status - DMG/REG status
  **  RETURN VALUES: 
  **      TRUE  - Success. 
  **      FALSE - Failure 
  *****************************************************************************/

   PROCEDURE p_po_reprocessing (
        p_po                IN         VARCHAR2,
        p_prod_id           IN         VARCHAR2,
        p_putaway_dimension IN         VARCHAR2,
        p_ca_dmg_status     IN         VARCHAR2,
        l_status            OUT        NUMBER
    ) IS

        l_func_name           VARCHAR2(30) := 'p_po_reprocessing';
        vc_func_name          VARCHAR2(31);
        lst_pallet_cube       NUMBER(12, 4);
        std_pallet_cube       NUMBER(12, 4);
        parent_pallet_arr     pl_msku.t_parent_pallet_id_arr;
        vc_message            VARCHAR(1025);
        lm_bats_crt           BOOLEAN := false;
        l_done_fetching_bln   BOOLEAN;
        l_opco_type           VARCHAR2(6);
        command               VARCHAR2(256);
        old_dflt_cool_prt     VARCHAR2(10);
        old_dflt_dry_prt      VARCHAR2(10);
        new_dflt_cool_prt     VARCHAR2(10);
        new_dflt_dry_prt      VARCHAR2(10);
        cool_parm_src         VARCHAR2(7);
        dry_parm_src          VARCHAR2(7);
        fname                 VARCHAR2(128);
        buff                  VARCHAR2(1024);
        prt_q                 VARCHAR2(10);
        dest_loc_flg          VARCHAR2(2);
        po                    VARCHAR2(12);
        sz_dest_loc           VARCHAR(10); 
        trans_prod_id         VARCHAR2(7);
        trans_cpv             VARCHAR2(6);
        tran_item             LONG;
        l_v_cur_po            VARCHAR2(13);
        l_v_crt_msg           VARCHAR2(500);
        l_v_crt_msg_ind       INT;
        erm_type              VARCHAR2(3);
        freezercount          NUMBER(20);
        coolercount           NUMBER(20);
        l_putaway_dimension   VARCHAR2(5);
        o_error               BOOLEAN;
        o_crt_message         VARCHAR2(4000);
        l_i_putaway_flag      NUMBER(1);
        wh_id                 NUMBER(5);
        to_wh_id              NUMBER(5);
        po_dtl_cnt            NUMBER(10) := 0;
        erm_id                VARCHAR2(12);
        no_splits             BOOLEAN;
        status                NUMBER(5);
        l_loadnumber          VARCHAR2(10);
        l_food_safety_flag    VARCHAR2(2);
        num_pallet            NUMBER(5);
        last_pallet_qty       NUMBER(10);
        r_syspars             pl_rcv_open_po_types.t_r_putaway_syspars;
        
        CURSOR transfer_items IS
        SELECT
            prod_id,
            cust_pref_vendor,
            qty
        FROM
            erd
        WHERE
            erm_id = p_po
            AND prod_id = p_prod_id
        ORDER BY
            erm_line_id;

        CURSOR split_line_item IS
        SELECT
            erd.prod_id,
            erd.cust_pref_vendor,
            SUM(erd.qty) qty,
            pm.brand,
            pm.mfg_sku,
            pm.category
        FROM
            pm,
            erd
        WHERE
            erd.prod_id = pm.prod_id
            AND erd.cust_pref_vendor = pm.cust_pref_vendor
            AND erd.erm_id = p_po
            AND erd.prod_id = p_prod_id
            AND erd.uom = 1
        GROUP BY
            erd.prod_id,
            erd.cust_pref_vendor,
            pm.brand,
            pm.mfg_sku,
            pm.category;

        CURSOR sn_line_item IS
        SELECT
            erd.prod_id,
            erd.qty,
            pm.brand,
            pm.mfg_sku,
            erd.cust_pref_vendor,
            pm.category,
            erd_lpn.erm_line_id
        FROM
            pm,
            erd,
            erd_lpn
        WHERE
            erd.erm_id = p_po
            AND erd_lpn.sn_no = p_po
            AND erd.uom = 0
            AND pm.prod_id = erd.prod_id
            AND pm.cust_pref_vendor = erd.cust_pref_vendor
            AND erd.erm_line_id = erd_lpn.erm_line_id
            AND erd_lpn.parent_pallet_id IS NULL
            AND erd.prod_id = p_prod_id
        ORDER BY
            erd.prod_id,
            erd.cust_pref_vendor,
            nvl(trunc(erd_lpn.exp_date), trunc(SYSDATE)),
            erd.qty,
            pm.brand,
            pm.mfg_sku,
            pm.category;

        CURSOR line_item IS
        SELECT
            erd.prod_id,
            SUM(erd.qty) qty,
            pm.brand,
            pm.mfg_sku,
            erd.cust_pref_vendor,
            pm.category
        FROM
            pm,
            erd
        WHERE
            pm.prod_id = erd.prod_id
            AND pm.cust_pref_vendor = erd.cust_pref_vendor
            AND erd.uom = 0
            AND erd.erm_id = p_po
            AND erd.prod_id = p_prod_id
        GROUP BY
            erd.prod_id,
            erd.cust_pref_vendor,
            pm.brand,
            pm.mfg_sku,
            pm.category;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Procedure p_po_reprocessing with po# = ' || p_po ||
                                             ' Prod id = ' ||p_prod_id || ' Putaway Dimension = ' || p_putaway_dimension ||
                                             ' DMG Status' || p_ca_dmg_status, sqlcode, sqlerrm);
      
        g_erm_num := p_po;
        l_putaway_dimension := p_putaway_dimension;
        ca_dmg_ind := p_ca_dmg_status;
        g_reprocess_flag := C_TRUE;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'l_putaway_dimension is   ' || l_putaway_dimension, sqlcode, sqlerrm);
          
       IF ( l_putaway_dimension = 'I' ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, ' Putaway :   ' || l_putaway_dimension, sqlcode, sqlerrm);
            o_error := false;
            o_crt_message := NULL;
            BEGIN
                pl_pallet_label2.p_assign_putaway_slot(p_po, o_error, o_crt_message);
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'pl_pallet_label2.p_assign_putaway_slot had an error ' ||
                    l_i_putaway_flag, sqlcode, sqlerrm);
                    l_status := -1;
                    raise_application_error(-20000, sqlcode
                                                    || '-'
                                                    || sqlerrm);
            END;

            IF o_error = false THEN
                l_i_putaway_flag := 0; /* Denotes success of putaway. */
             ELSE
                l_i_putaway_flag := 1;
                l_status := 1;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'After p_assign_putaway_slot - l_i_putaway_flag ' || l_i_putaway_flag, sqlcode
                , sqlerrm);
            END IF;

        ELSIF ( l_putaway_dimension = 'C' ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Other putaway dimensions  ', sqlcode, sqlerrm);
            SELECT
                erm_type,
                warehouse_id,
                to_warehouse_id
            INTO
                l_erm_type,
                wh_id,
                to_wh_id
            FROM
                erm
            WHERE
                erm_id = p_po;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'erm_type = '
                                                || l_erm_type
                                                || ' to_wh_id = '
                                                || to_wh_id
                                                || ' wh_id =  '
                                                || wh_id, sqlcode, sqlerrm);

            BEGIN
                SELECT
                    COUNT(1)
                INTO po_dtl_cnt
                FROM
                    erd
                WHERE
                    erm_id = p_po;

            EXCEPTION
                WHEN no_data_found THEN
                  pl_text_log.ins_msg_async('INFO', l_func_name, 'ORACLE failed to select info', sqlcode, sqlerrm);
                    po_dtl_cnt := 0;
            END;

            IF po_dtl_cnt = 0 THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'No detail available in ERD' , sqlcode, sqlerrm);
                l_status := 'No detail available in ERD';
                return;
            END IF;
                BEGIN
                    g_allow_flag := pl_common.f_get_syspar('HOME_PUTAWAY', 'x');
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, ' Unable to get home putaway ', sqlcode, sqlerrm);
                        l_status := 'Unable to get for home putaway';
                        return;
                END;

                pl_text_log.ins_msg_async('DEBUG', l_func_name, 'HOME_PUTAWAY  ' || g_allow_flag, sqlcode, sqlerrm);
                IF g_allow_flag = 'x' THEN
                    pl_text_log.ins_msg_async('FATAL', l_func_name, 'No detail available for home putaway ', sqlcode, sqlerrm);
                    l_status := 'No detail available for home putaway';
                    return;
                END IF;

                BEGIN
                    g_pallet_type_flag := pl_common.f_get_syspar('PALLET_TYPE_FLAG', 'N');
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'No detail available for PALLET TYPE FLAG', sqlcode, sqlerrm);
                        l_status := 'No detail available for PALLET TYPE FLAG';
                        ROLLBACK;
                        return;
                END;

                pl_text_log.ins_msg_async('INFO', l_func_name, ' PALLET_TYPE_FLAG  ' || g_pallet_type_flag, sqlcode, sqlerrm);
                g_clam_bed_tracked_flag := 'N';
                BEGIN
                    g_clam_bed_tracked_flag := pl_common.f_get_syspar('CLAM_BED_TRACKED', 'x');
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'No detail available for CLAM BED TRACK', sqlcode, sqlerrm);
                        l_status := 'No detail available for CLAM BED TRACK';
                        ROLLBACK;
                        return;
                END;

            IF ( substr(l_erm_type, 1, 2) = 'TR' ) THEN
                pl_text_log.ins_msg_async('DEBUG', l_func_name, ' Inside TR IF  ', sqlcode, sqlerrm);
                FOR trans_rec IN transfer_items LOOP 
                INSERT INTO trans (
                    trans_id,
                    trans_type,
                    trans_date,
                    rec_id,
                    user_id,
                    exp_date,
                    qty,
                    uom,
                    prod_id,
                    cust_pref_vendor,
                    upload_time,
                    new_status,
                    warehouse_id
                ) VALUES (
                    trans_id_seq.NEXTVAL,
                    'TPI',
                    SYSDATE,
                    p_po,
                    user,
                    trunc(SYSDATE),
                    trans_rec.qty,
                    0,
                    trans_rec.prod_id,
                    trans_rec.cust_pref_vendor,
                    TO_DATE('01-JAN-1980', 'DD-MON-YYYY'),
                    'OUT',
                    to_wh_id
                );

                END LOOP;

            END IF;

            g_mix_same_prod_deep_slot := pl_common.f_get_syspar('MIX_SAME_PROD_DEEP_SLOT', 'N');
            seq_no := 0; 

        /* 
              ** for each line item in the po with a uom = 1 for splits 
              ** get the sum of the erd.qty, brand and mfg_sku 
              **/
                 pl_text_log.ins_msg_async('INFO', l_func_name, 'for loop  split_line_item   ', sqlcode, sqlerrm); 
            FOR spl IN split_line_item LOOP
                g_prod_id := spl.prod_id;
                g_cpv := spl.cust_pref_vendor;
                total_qty := spl.qty;
                brand := spl.brand;
                mfg := spl.mfg_sku;
                pm_category := spl.category;
                l_cust_pref_vendor := spl.cust_pref_vendor;
                pl_text_log.ins_msg_async('INFO', l_func_name, ' split_line_item  g_prod_id = '
                                                    || g_prod_id
                                                    || ' g_cpv = '
                                                    || g_cpv
                                                    || ' total_qty = '
                                                    || total_qty
                                                    || ' brand = '
                                                    || brand
                                                    || ' mfg = '
                                                    || mfg
                                                    || ' pm_category = '
                                                    || pm_category, sqlcode, sqlerrm); 

            /*** Get all the data needed for the product from the pm table. */

                p_retrieve_label_content(); 

            /* *  Get aging days for item that needs to be aged    */
                p_split_find_putaway_slot(); 
        /* Fixed as part of RDC Changes - . This commit should be placed outside the loop */ 
        /* get next item */
            END LOOP; 

        /* end while that was processing splits*/

            IF total_qty = 0 THEN
                no_splits := true;
            ELSE
                no_splits := false;
            END IF;

            l_done_fetching_bln := false;
            IF ( substr(l_erm_type, 1, 2) = 'SN' ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, ' IF l_erm_type is SN  ', sqlcode, sqlerrm);
                FOR sn_line_item_rec IN sn_line_item LOOP
                    g_prod_id := sn_line_item_rec.prod_id;
                    total_qty := sn_line_item_rec.qty;
                    brand := sn_line_item_rec.brand;
                    mfg := sn_line_item_rec.mfg_sku;
                    g_cpv := sn_line_item_rec.cust_pref_vendor;
                    pm_category := sn_line_item_rec.category;
                    g_erm_line_id := sn_line_item_rec.erm_line_id; 

              /* ** Get all the data needed for the product from the pm table.   */
                    p_retrieve_label_content();
                    aging_days := f_retrieve_aging_item();
                    IF ( total_qty > ( ti * hi * spc ) AND l_erm_type = 'SN' ) THEN
                        each_pallet_qty := TRUNC(total_qty / spc);
                        sz_dest_loc := '*';
                        p_insert_table(sz_dest_loc, ADD_NO_INV);
                    END IF;
                    IF ( substr(l_erm_type, 1, 2) = 'SN' ) THEN
                        num_pallet := 1;
                    ELSE
                      num_pallet := TRUNC((total_qty / spc) / (ti * hi));
                    END IF;  
                    
                    IF ( MOD((total_qty / spc),(ti * hi)) <> 0 ) THEN
                        partial_pallet := C_TRUE;
                    ELSE
                        partial_pallet := C_FALSE;
                    END IF; 

              /*** Only add one to num pallets if not a SN.     */

                    each_pallet_qty := TRUNC( total_qty / spc );
                    last_pallet_qty := each_pallet_qty;
                    lst_pallet_cube := ( ceil(last_pallet_qty / ti) * ti * case_cube ) + skid_cube;
                    std_pallet_cube := lst_pallet_cube;
                    done := f_find_putaway_slot(g_prod_id, g_cpv);
                END LOOP;

            ELSE
                FOR line_item_record IN line_item LOOP
                    g_prod_id := line_item_record.prod_id;
                    total_qty := line_item_record.qty;
                    brand := line_item_record.brand;
                    mfg := line_item_record.mfg_sku;
                    g_cpv := line_item_record.cust_pref_vendor;
                    pm_category := line_item_record.category; 

              /* ** Get all the data needed for the product from the pm table. */
                    p_retrieve_label_content(); 

              /*   ** Get aging days for item that needs to be aged       */
                    aging_days := f_retrieve_aging_item();
                    num_pallet := TRUNC(( total_qty / spc ) / ( ti * hi ));
                    IF ( MOD((total_qty / spc),(ti * hi)) <> 0 ) THEN
                        partial_pallet := C_TRUE; 

                /*      ** Only add one to num pallets if not a SN.           */
                        num_pallet := num_pallet + 1;
                    ELSE
                        partial_pallet := C_FALSE;
                    END IF;

                    each_pallet_qty := ti * hi;
                    IF ( partial_pallet = C_TRUE ) THEN
                        last_pallet_qty := MOD((total_qty / spc),(ti * hi));
                    ELSE
                        last_pallet_qty := each_pallet_qty;
                    END IF; 

              /* A partial pallet will have the cube rounded up 
                 to the nearest ti. */

                    lst_pallet_cube := ( ceil(last_pallet_qty / ti) * ti * case_cube ) + skid_cube;
                    std_pallet_cube := ( case_cube * ti * hi ) + skid_cube;
                    done := f_find_putaway_slot(g_prod_id, g_cpv);
                END LOOP;
            END IF;

        END IF;
      pl_text_log.ins_msg_async('INFO', l_func_name, 'Exiting  p_po_reprocessing ', sqlcode, sqlerrm);
          
    END p_po_reprocessing; 



END pl_one_pallet_label;
/

GRANT Execute on pl_one_pallet_label to swms_user;
