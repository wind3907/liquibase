create or replace PACKAGE pl_rf_putaway AS

/*******************************************************************************

**Package:

**        pl_rf_putaway. Migrated from putaway.pc

**

**Description:

**        Functions for putaway service.

**

**Called by:

**        This package is called from java web service.

*******************************************************************************/

    FUNCTION putaway_main (
        i_rf_log_init_record   IN    rf_log_init_record,
        i_putaway_client       IN    putaway_client_obj,
        o_loc_collection       OUT   putaway_loc_result_obj,
        o_putaway_server       OUT   putaway_server_obj
    ) RETURN rf.status;

    FUNCTION putaway_service (
        i_putaway_client   IN    putaway_client_obj,
        o_loc_collection   OUT   putaway_loc_result_obj,
        o_putaway_server   OUT   putaway_server_obj
    ) RETURN rf.status;

    FUNCTION put_away RETURN rf.status;

    FUNCTION get_hst_qty_prompt (
        i_option      IN   VARCHAR2,
        i_plogi_loc   IN   inv.plogi_loc%TYPE,
        i_qty_rec     IN   putawaylst.qty_received%TYPE
    ) RETURN VARCHAR2;

    FUNCTION data_collect_check (
        i_plogi_loc        IN   inv.plogi_loc%TYPE,
        i_logi_loc         IN   inv.logi_loc%TYPE,
        i_home_slot_flag   IN   NUMBER
    ) RETURN rf.status;

    FUNCTION update_inv (
        i_plogi_loc        IN   inv.plogi_loc%TYPE,
        i_logi_loc         IN   inv.logi_loc%TYPE,
        i_flag             IN   NUMBER,
        i_home_slot_flag   IN   NUMBER
    ) RETURN rf.status;

    FUNCTION update_cdk_inv (
        i_plogi_loc        IN   inv.plogi_loc%TYPE,
        i_logi_loc         IN   inv.logi_loc%TYPE,
        i_flag             IN   NUMBER,
        i_home_slot_flag   IN   NUMBER
    ) RETURN rf.status;

    FUNCTION check_new_float RETURN rf.status;

    FUNCTION check_global_rf RETURN rf.status;

    PROCEDURE check_rtn_bfr_mfc;

    FUNCTION check_putawaylist RETURN rf.status;

    FUNCTION check_home_slot RETURN rf.status;

    FUNCTION check_put_path RETURN rf.status;

    PROCEDURE get_rf_info;

    FUNCTION get_putaway_info RETURN rf.status;

    FUNCTION get_product_info RETURN rf.status;

    FUNCTION delete_putaway_task (
        i_finish_good_po_flag IN VARCHAR2
    ) RETURN rf.status;

    FUNCTION confirm_putaway_task RETURN rf.status;

    FUNCTION process_pallet_and_send_er RETURN rf.status;

    FUNCTION delete_inv RETURN rf.status;

    FUNCTION update_inv_zero_rcv (
        i_flag IN NUMBER
    ) RETURN rf.status;

    FUNCTION write_transaction (
        i_trans_type IN trans.trans_type%TYPE
    ) RETURN rf.status;

    FUNCTION update_put_trans RETURN rf.status;

    PROCEDURE update_manifest_dtls_status;

    FUNCTION check_po_status RETURN rf.status;

    FUNCTION update_rlc_inv (
        i_plogi_loc        IN   inv.plogi_loc%TYPE,
        i_logi_loc         IN   inv.logi_loc%TYPE,
        i_home_slot_flag   IN   NUMBER,
        i_move_flag        IN   NUMBER
    ) RETURN rf.status;

    FUNCTION check_rlc_put RETURN rf.status;

    FUNCTION check_reserve_loc RETURN rf.status;

    FUNCTION check_ei_loc RETURN rf.status;

    FUNCTION upd_cdk_xref_status (
        i_erm_id erm.erm_id%TYPE
    ) RETURN rf.status;

    PROCEDURE delete_ppu_trans_for_haul (
        i_psz_pallet_id putawaylst.pallet_id%TYPE
    );

    FUNCTION check_pallet_type RETURN rf.status;

    FUNCTION insert_door_tran RETURN rf.status;

    FUNCTION find_pending_replen_tasks (
        i_plogi_loc         IN      inv.plogi_loc%TYPE,
        i_putaway_client    IN      putaway_client_obj,
        o_loc_collection    OUT     putaway_loc_result_obj,
        io_putaway_server   IN OUT  putaway_server_obj
    ) RETURN rf.status;

    FUNCTION get_syspar_frc_rpl_putaway (
        o_syspar_value       OUT   sys_config.config_flag_val%TYPE,
        o_pending_rpl_flag   OUT   VARCHAR2
    ) RETURN rf.status;

    FUNCTION drop_haul_pallet (
        i_pallet_id    IN   putawaylst.pallet_id%TYPE,
        i_drop_point   IN   inv.plogi_loc%TYPE
    ) RETURN rf.status;

    FUNCTION get_source_location (
        i_erm_id      IN    erm.erm_id%TYPE,
        i_pallet_id   IN    putawaylst.pallet_id%TYPE,
        o_src_loc     OUT   trans.src_loc%TYPE
    ) RETURN rf.status;

    PROCEDURE check_strip_loc;

    FUNCTION mskuputaway RETURN rf.status;

    FUNCTION gt_syspar_rpl_aftr_ech_ptaway (
        o_syspar_value OUT sys_config.config_flag_val%TYPE
    ) RETURN rf.status;

    FUNCTION calc_exp_dt_for_shlf_lfe_item RETURN rf.status;

    PROCEDURE get_front_or_back_loc (
        i_in_plogi_loc    IN    loc_reference.plogi_loc%TYPE,
        o_out_plogi_loc   OUT   loc_reference.plogi_loc%TYPE,
        i_options         IN    NUMBER,
        i_n_func          IN    NUMBER,
        o_rc              OUT   NUMBER
    );

    FUNCTION check_suspend (
        i_user_id    IN   batch.user_id%TYPE,
        i_equip_id   IN   equip.equip_id%TYPE
    ) RETURN rf.status;

    PROCEDURE get_po_info;

    PROCEDURE delete_ppu_trans (
        i_erm_id      IN   erm.erm_id%TYPE,
        i_pallet_id   IN   putawaylst.pallet_id%TYPE
    );

END pl_rf_putaway;
/

create or replace PACKAGE BODY pl_rf_putaway AS

------------------------------------------------------------------------------
/*       CONSTANT VARIABLES FOR LABOR MANAGEMENT FUNCTIONS                  */
------------------------------------------------------------------------------ 
------------------------------------------------------------------------------ 

    PUTAWAY                    CONSTANT NUMBER := 1;
    MAX_PENDING_REPLEN_TASKS   CONSTANT NUMBER := 10;
    LMF_SIGNON_BATCH           CONSTANT VARCHAR2(1) := 'N';
--------------------------------------------------------------------------------
------------------------------------------------------------------------------
/*                      GLOBAL DECLARATIONS                                */
------------------------------------------------------------------------------
	
	g_application_func		   swms_log.application_func%TYPE := 'Receiving';
	g_program_name			   swms_log.program_name%TYPE := 'pl_rf_putaway';
    g_dest_loc                 putawaylst.dest_loc%TYPE;
    g_pallet_id                putawaylst.pallet_id%TYPE;
    g_plogi_loc                inv.plogi_loc%TYPE;
    g_logi_loc                 inv.logi_loc%TYPE;
    g_real_put_path_val        VARCHAR2(11);			/* The put path sent by the RF gun.
													This value was sent to the RF gun
													by pre_putaway. The format is:
													Put aisle: positions 1-3
													Put slot:  positions 4-6
													Put level: positions 7-9 */
    g_prod_id                  pm.prod_id%TYPE;
    g_cust_pref_vendor         putawaylst.cust_pref_vendor%TYPE;
    g_rec_type                 returns.rec_type%TYPE;
    g_reason_code              returns.return_reason_cd%TYPE;
    g_uom                      putawaylst.uom%TYPE;
    g_receive_id               inv.rec_id%TYPE;
    g_des_loc                  putawaylst.dest_loc%TYPE;
    g_bck_dest_loc             trans.bck_dest_loc%TYPE;
    g_rlc_loc                  loc.logi_loc%TYPE;
    g_qty_rec                  putawaylst.qty_received%TYPE;
    g_qty_exp                  NUMBER;
    g_exp_ind                  putawaylst.exp_date_trk%TYPE;
    g_mfg_ind                  putawaylst.date_code%TYPE;
    g_lot_ind                  putawaylst.lot_trk%TYPE;
    g_temp_ind                 putawaylst.temp_trk%TYPE;
    g_inv_status               inv.status%TYPE;
    g_putawaylst_status        putawaylst.status%TYPE;
    g_loc_status               NUMBER;
    g_vc_exp_date              VARCHAR2(15);
    g_s_exp_date_ind           NUMBER;
    g_mfg_date                 VARCHAR2(15);
    g_temp                     NUMBER;
    g_weight                   putawaylst.weight%TYPE;
    g_lot_id                   putawaylst.lot_id%TYPE;
    g_orig_invoice             putawaylst.orig_invoice%TYPE;
    g_case_cube                pm.case_cube%TYPE;
    g_spc                      pm.spc%TYPE;
    g_max_qty                  pm.max_qty%TYPE;
    g_shelf_life               NUMBER;
    g_sysco_shelf_life         pm.sysco_shelf_life%TYPE;
    g_cust_shelf_life          pm.cust_shelf_life%TYPE;
    g_mfr_shelf_life           pm.mfr_shelf_life%TYPE;
    g_erm_status               erm.status%TYPE;
    g_erm_type                 erm.erm_type%TYPE;
    g_warehouse_id             erm.warehouse_id%TYPE;
    g_erm_id                   erm.erm_id%TYPE;
    g_put                      VARCHAR2(1);
    g_mispick                  putawaylst.mispick%TYPE;
    g_order_id                 VARCHAR2(9);
    g_order_line_id            NUMBER;
    g_put_aisle                loc.put_aisle%TYPE;
    g_put_slot                 loc.put_slot%TYPE;
    g_strip_loc                VARCHAR2(1);
    g_door_no                  VARCHAR2(4);
    						/* New pallet type validation for R,L.C. */
    g_rtn_bfr_mfc              VARCHAR2(1);
    g_pallet_id_msku           putawaylst.pallet_id%TYPE;
    g_msku_pallet              NUMBER := 0;
    g_is_parent_pallet         NUMBER := 0;
    g_lv_prod_id               putawaylst.prod_id%TYPE;
    g_lv_reason_code           putawaylst.reason_code%TYPE;
    g_returns_lm_flag          VARCHAR2(1) := 'N'; 				/* 11741 RETURNs LM track putaway */
    g_exprec_sent              VARCHAR2(1) := 'N'; 				/* Tracks Expected receipt messages.*/
    g_rule_id                  NUMBER; 							/* Destination location rule id */
    g_item_not_aging           NUMBER := 0;
    g_ei_pallet                VARCHAR2(1) := 'N';
    g_is_matrix_putaway        NUMBER := 0; 						/*Matrix*/
    g_m_rule_id                zone.rule_id%TYPE;				/*Matrix*/
    g_putaway_client           putaway_client_obj;
    g_o_putaway_server         putaway_server_obj := putaway_server_obj(' ', ' ', ' ', ' ', ' ',
                   ' ', ' ', ' ', ' ');  

-------------------------------------------------------------------------------
/**                     LOCAL MODULES                                      **/
-------------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Function:
--    f_check_location
-- 
-- Description:
--    This function checks the location
---------------------------------------------------------------------------
FUNCTION f_check_location (i_location IN loc.logi_loc%TYPE)
RETURN VARCHAR2
IS
   l_count NUMBER := 0;
   l_return_value VARCHAR2(1);
BEGIN

   SELECT count(1)
   INTO l_count
   FROM lzone lz, zone z
   WHERE lz.zone_id = z.zone_id
   AND z.zone_type = 'PUT'
   AND lz.logi_loc = i_location;

   IF l_count > 0 THEN

      l_return_value := 'Y';

   ELSE

      l_return_value := 'N';

   END IF;

   RETURN l_return_value;

END f_check_location;

---------------------------------------------------------------------------
-- Function:
--    f_check_order_gen
-- 
-- Description:
--    This function checks the location
---------------------------------------------------------------------------
FUNCTION f_check_order_gen (i_pallet_id putawaylst.pallet_id%TYPE)
RETURN VARCHAR2
IS
   l_count NUMBER := 0;
   l_return_value VARCHAR2(1);
BEGIN

   l_return_value := 'N';
   
   RETURN l_return_value;

END f_check_order_gen;

-------------------------------------------------------------------------------
/**                     PUBLIC MODULES                                      **/
-------------------------------------------------------------------------------

/*****************************************************************************
**  FUNCTION:
**      putaway_main()
**  DESCRIPTION:
**       Wrapper function for Putaway service.
**	CALLED BY: java web service
**  PARAMETERS:
**      i_rf_log_init_record -- Object to get the RF status
**		i_putaway_client  	-- client message
**      o_loc_collection  	-- server message
**      o_putaway_server  	-- server message
**  RETURN VALUES:
**      rf_status code
*********************************************************************************/

    FUNCTION putaway_main (
        i_rf_log_init_record   IN    rf_log_init_record,
        i_putaway_client       IN    putaway_client_obj,
        o_loc_collection       OUT   putaway_loc_result_obj,
        o_putaway_server       OUT   putaway_server_obj
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'putaway_main';
        l_rf_status   rf.status := rf.status_normal;
    BEGIN
        l_rf_status := rf.initialize(i_rf_log_init_record);
        IF l_rf_status = rf.status_normal THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting putaway', sqlcode, sqlerrm, g_application_func, g_program_name);
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Input from scanner. pallet_id = '
                                                || i_putaway_client.pallet_id
                                                || ' plogi_loc = '
                                                || i_putaway_client.plogi_loc
                                                || ' real_put_path_val = '
                                                || i_putaway_client.real_put_path_val
                                                || ' rlc_flag = '
                                                || i_putaway_client.rlc_flag
                                                || ' rtn_putaway_conf = '
                                                || i_putaway_client.rtn_putaway_conf
                                                || ' door_no = '
                                                || i_putaway_client.door_no
                                                || ' cte_door_trans = '
                                                || i_putaway_client.cte_door_trans
                                                || ' first_pass_flag = '
                                                || i_putaway_client.first_pass_flag
                                                || ' haul_flag = '
                                                || i_putaway_client.haul_flag
                                                || ' equip_id = '
                                                || i_putaway_client.equip_id
                                                || ' sub_flag = '
                                                || i_putaway_client.sub_flag
                                                || ' scan_method = '
                                                || i_putaway_client.scan_method
                                                || ' last_put = '
                                                || i_putaway_client.last_put, sqlcode, sqlerrm, g_application_func, g_program_name);
				
			o_putaway_server := putaway_server_obj(' ', ' ', ' ', ' ', ' ',' ', ' ', ' ', ' ');
            l_rf_status := putaway_service(i_putaway_client, o_loc_collection, o_putaway_server);
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending putaway_main. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        END IF; --end l_rf_status is normal

        rf.complete(l_rf_status);
        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('FATAL', l_func_name, 'Call to putaway_service failed', sqlcode, sqlerrm, g_application_func, g_program_name);
            rf.logexception();  -- log it
            RAISE;
    END putaway_main;
	
/*****************************************************************************
**  FUNCTION:
**      putaway_service()
**  DESCRIPTION:
**       Main function for Putaway service.
**CALLED BY: putaway_main
**  PARAMETERS:
**      
**		i_putaway_client  	-- client message
**      o_loc_collection  	-- server message
**      o_putaway_server  	-- server message
**  RETURN VALUES:
**      rf_status code
*********************************************************************************/

    FUNCTION putaway_service (
        i_putaway_client   IN    putaway_client_obj,
        o_loc_collection   OUT   putaway_loc_result_obj,
        o_putaway_server   OUT   putaway_server_obj
    ) RETURN rf.status AS

        l_func_name               VARCHAR2(50) := 'putaway_service';
        l_hi_loc_cnt              NUMBER := 0;
        l_i_rule_id               NUMBER;
        l_pallet_sub_active_bln   NUMBER := 0;
        l_n_status                BOOLEAN := true;
        l_b_status                BOOLEAN := true;
        l_replen_list_status      rf.status := rf.status_normal;
        l_rf_status               rf.status := rf.status_normal;
        l_loc_collection          putaway_loc_result_obj;
        l_slot_type               loc.slot_type%TYPE;
        l_cust_pref_vendor        putawaylst.cust_pref_vendor%TYPE;
        l_v_parent_pallet_id      putawaylst.parent_pallet_id%TYPE;
        l_plogi_loc_msku          putawaylst.dest_loc%TYPE;
        l_dummy                   NUMBER;
        l_dummy2                  VARCHAR2(2);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Processing putaway', sqlcode, sqlerrm, g_application_func, g_program_name);
        g_pallet_id := i_putaway_client.pallet_id;
        g_plogi_loc := i_putaway_client.plogi_loc;
        g_pallet_id_msku := g_pallet_id;
        g_putaway_client := i_putaway_client;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Source pallet id is '
                                            || g_pallet_id
                                            || ' pallet id(pallet_id_msku) value is '
                                            || g_pallet_id_msku
                                            || ' and length is '
                                            || length(g_pallet_id_msku), sqlcode, sqlerrm, g_application_func, g_program_name);

        g_ei_pallet := pl_rcv_cross_dock.f_is_crossdock_pallet(g_pallet_id, 'P');
        SELECT
            COUNT(*)
        INTO l_dummy
        FROM
            putawaylst
        WHERE
            parent_pallet_id = g_pallet_id_msku;

        IF l_dummy > 0 THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'pallet id  '
                                                || g_pallet_id_msku
                                                || ' is a parent pallet id(MSKU)', sqlcode, sqlerrm, g_application_func, g_program_name);

            g_is_parent_pallet := 1;
        ELSE
            l_n_status := pl_msku.f_is_msku_pallet(g_pallet_id, 'P');
            IF l_n_status = true THEN
                g_msku_pallet := 1;
            END IF;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Substitution flag is '
                                                || i_putaway_client.sub_flag
                                                || ' msku pallet = '
                                                || g_msku_pallet, sqlcode, sqlerrm, g_application_func, g_program_name);

            IF ( g_ei_pallet = 'Y' ) THEN
                g_is_parent_pallet := 1;
            END IF;
		   /*
           ** Get the parent pallet id and prod_id based on the scanned LP.
           **
           ** 05/02/05 prpbcb Modified the stmt to return the rule id of
           ** the destination location.  If the rule id designates a floating
           ** zone then pallet substitution does not apply.
           */
            IF g_msku_pallet = 1 AND i_putaway_client.sub_flag = 'Y' THEN
                BEGIN
                    SELECT
                        p.parent_pallet_id,
                        p.prod_id,
                        p.cust_pref_vendor,
                        nvl(z.rule_id, 0) 		/* Ideally rule id not null */
                    INTO
                        l_v_parent_pallet_id,
                        g_lv_prod_id,
                        l_cust_pref_vendor,
                        l_i_rule_id
                    FROM
                        zone         z,
                        lzone        lz,
                        putawaylst   p
                    WHERE
                        p.pallet_id = g_pallet_id_msku
                        AND lz.logi_loc = p.dest_loc
                        AND z.zone_id = lz.zone_id
                        AND z.zone_type = 'PUT';

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Cannot select parent LP from scanned LP.  Verify PUT zone setup. msku_pallet_id = '
                        || g_pallet_id_msku, sqlcode, sqlerrm, g_application_func, g_program_name);
                        l_rf_status := rf.status_inv_label;
                END;

                pl_text_log.ins_msg_async('INFO', l_func_name, 'parent LP, prod id, dest loc rule id selected. rule_id = '
                                                    || l_i_rule_id
                                                    || ' prod_id = '
                                                    || g_lv_prod_id
                                                    || ' cust_pref_vendor = '
                                                    || l_cust_pref_vendor, sqlcode, sqlerrm, g_application_func, g_program_name);
				/*
				   ** 05/02/05 prpbcb
				   ** Pallet substitution does not apply for a floating item.
				   */
				   /* D12249 add check for floating item: any item not slotted are treated
				   ** as floating item no matter what the rule_id is (include bulk rule zone). */

                BEGIN
                    SELECT
                        'x'
                    INTO l_dummy2
                    FROM
                        loc
                    WHERE
                        prod_id = g_lv_prod_id
                        AND cust_pref_vendor = l_cust_pref_vendor;

					l_pallet_sub_active_bln := 1;
					BEGIN
						SELECT 
							p.dest_loc
						INTO l_plogi_loc_msku
						FROM
							putawaylst   p,
							loc          l
						WHERE
							p.dest_loc = l.logi_loc
							AND p.parent_pallet_id = l_v_parent_pallet_id
							AND p.prod_id = g_lv_prod_id
							AND p.cust_pref_vendor = l_cust_pref_vendor
							AND ( l.perm = 'Y'
								  OR l.logi_loc IN (
								SELECT
									induction_loc
								FROM
									zone
								WHERE
									rule_id IN (
										3,
										5
									)
							) )
							AND ROWNUM = 1;
							
						pl_text_log.ins_msg_async('INFO', l_func_name, 'Location selected. plogi_loc_msku = ' || l_plogi_loc_msku, sqlcode, sqlerrm, g_application_func, g_program_name);	
					EXCEPTION
						WHEN OTHERS THEN
							pl_text_log.ins_msg_async('WARN', l_func_name, 'Cannot select the assigned dest loc from putawaylst. parent_pallet_id = '
							|| l_v_parent_pallet_id, sqlcode, sqlerrm, g_application_func, g_program_name);
							l_rf_status := rf.status_inv_label;
					END;
									
				EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        IF ( l_i_rule_id != 3 AND l_i_rule_id != 5 ) THEN
                            l_pallet_sub_active_bln := 0;
                        END IF;
                    WHEN OTHERS THEN
                        IF ( l_i_rule_id != 3 AND l_i_rule_id != 5 ) THEN
                            l_rf_status := rf.status_inv_label;
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'failure in select from loc. prod_id = '
                                                                || g_lv_prod_id
                                                                || ' cust_pref_vendor = '
                                                                || l_cust_pref_vendor, sqlcode, sqlerrm, g_application_func, g_program_name);

                        END IF;
                END;
                IF ( l_rf_status = rf.status_normal AND l_pallet_sub_active_bln = 1 ) THEN
                    BEGIN
                        l_b_status := pl_msku.f_substitute_msku_pallet(g_pallet_id_msku, l_plogi_loc_msku);
                        IF l_b_status = false THEN
                            l_rf_status := rf.status_nor_cluster;
                        ELSE
                            l_rf_status := rf.status_normal;
                        END IF;
						
                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'TABLE=None KEY=['
                                                                || g_pallet_id_msku
                                                                || ']['
                                                                || l_plogi_loc_msku
                                                                || ']'
                                                                || ' MESSAGE=Pallet could not be substituted'
                                                                || ' REASON='
                                                                || sqlerrm, NULL, NULL, g_application_func, g_program_name);

                            l_rf_status := rf.status_nor_cluster;
                    END;
					/*Change the status to the error code */
                        IF ( l_rf_status = rf.status_nor_cluster ) THEN
                            l_rf_status := rf.status_inv_dest_location;
                        END IF;
                END IF; /*Ending l_rf_status = rf.status_normal AND l_pallet_sub_active_bln = 1 */

                IF ( l_rf_status = rf.status_nor_cluster AND l_pallet_sub_active_bln = 1 ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'pallet id  '
                                                        || g_pallet_id
                                                        || ' and destination location '
                                                        || g_plogi_loc
                                                        || ' mismatch', sqlcode, sqlerrm, g_application_func, g_program_name);

                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending putaway. l_rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
                    RETURN l_rf_status;
                END IF;

            END IF;

        END IF;

        BEGIN
            IF g_is_parent_pallet = 1 THEN
                SELECT
                    nvl(z.rule_id, 0),/* Ideally rule id not null */
                    p.prod_id,
                    p.reason_code
                INTO
                    g_m_rule_id,
                    g_lv_prod_id,
                    g_lv_reason_code
                FROM
                    zone         z,
                    lzone        lz,
                    putawaylst   p
                WHERE
                    p.parent_pallet_id = g_pallet_id_msku
                    AND lz.logi_loc = p.dest_loc
                    AND z.zone_id = lz.zone_id
                    AND z.zone_type = 'PUT'
                    AND ROWNUM = 1;

            ELSE
                SELECT
                    nvl(z.rule_id, 0),/* Ideally rule id not null */
                    p.prod_id,
                    p.reason_code
                INTO
                    g_m_rule_id,
                    g_lv_prod_id,
                    g_lv_reason_code
                FROM
                    zone         z,
                    lzone        lz,
                    putawaylst   p
                WHERE
                    p.pallet_id = g_pallet_id_msku
                    AND lz.logi_loc = p.dest_loc
                    AND z.zone_id = lz.zone_id
                    AND z.zone_type = 'PUT';

            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                l_rf_status := rf.status_inv_label;
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Cannot select parent LP from scanned LP.  Verify PUT zone setup. pallet_id_msku = '
                || g_pallet_id_msku, sqlcode, sqlerrm, g_application_func, g_program_name);
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Debug Message to print rule_id for Matrix. plogi_loc = '
                                            || g_plogi_loc
                                            || ' rule_id = '
                                            || g_m_rule_id
                                            || ' reason_code = '
                                            || g_lv_reason_code
                                            || ' pallet_id_msku = '
                                            || g_pallet_id_msku, sqlcode, sqlerrm, g_application_func, g_program_name);

        IF ( g_m_rule_id = 5 ) THEN  --If matrix destination location
            BEGIN
                SELECT
                    COUNT(*)
                INTO g_is_matrix_putaway
                FROM
                    lzone   lz,
                    zone    z,
                    loc     l
                WHERE
                    lz.zone_id = z.zone_id
                    AND l.logi_loc = lz.logi_loc
                    AND l.logi_loc = g_plogi_loc
                    AND z.z_area_code = nvl(pl_matrix_common.f_get_pm_area(g_lv_prod_id), 'XX')
                    AND l.slot_type IN (
                        'MXI',
                        'MXT'
                    )
                    AND z.zone_type = 'PUT';

            EXCEPTION
                WHEN OTHERS THEN
                    l_rf_status := rf.status_inv_dest_location;
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Failure in select from loc for slot_type MXI,MXT. prod_id = ' 
															|| g_lv_prod_id, sqlcode, sqlerrm, g_application_func, g_program_name);
                    
            END;

            IF ( g_is_matrix_putaway = 0 ) THEN
                l_rf_status := rf.status_inv_dest_location;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending putaway. l_rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
                RETURN l_rf_status;
            END IF;

            IF ( g_is_matrix_putaway > 0 AND g_is_parent_pallet = 1 ) THEN
                BEGIN
                    SELECT
                        l.slot_type
                    INTO l_slot_type
                    FROM
                        lzone   lz,
                        zone    z,
                        loc     l
                    WHERE
                        lz.zone_id = z.zone_id
                        AND l.logi_loc = lz.logi_loc
                        AND l.logi_loc = g_plogi_loc
                        AND z.z_area_code = pl_matrix_common.f_get_pm_area(g_lv_prod_id)
                        AND l.slot_type IN (
                            'MXI',
                            'MXT'
                        )
                        AND z.zone_type = 'PUT'
                        AND z.rule_id = 5;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to find slot_type of matrix location for MSKU Putaway. plogi_loc = '
                        || g_plogi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);
                        l_rf_status := rf.status_sel_loc_fail;
                        RETURN l_rf_status;
                END;

                IF ( l_slot_type = 'MXT' ) THEN
                    UPDATE inv
                    SET
                        mx_parent_pallet_id = parent_pallet_id,
                        mx_xfer_type = 'PUT'
                    WHERE
                        parent_pallet_id = g_pallet_id_msku;

                    IF ( SQL%rowcount = 0 ) THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to set mx_parent_pallet_id in inv. parent_pallet_id = ' || g_pallet_id_msku
                        , sqlcode, sqlerrm, g_application_func, g_program_name);
                    END IF;

                END IF;

            END IF;

        END IF;

        IF ( i_putaway_client.haul_flag = 'Y' ) THEN
            l_rf_status := drop_haul_pallet(g_pallet_id, g_plogi_loc);
        ELSE
            l_rf_status := check_suspend(user, i_putaway_client.equip_id);
            IF l_rf_status = rf.status_normal THEN
                IF g_is_parent_pallet = 1 THEN
                    l_rf_status := mskuputaway;
                ELSE
                    l_rf_status := put_away;
                END IF;

            END IF;

            IF l_rf_status = rf.status_normal THEN
                l_rf_status := check_po_status;
            END IF;
        END IF;

        IF ( l_rf_status = rf.status_normal ) THEN
            COMMIT;
			/* Get pending replenishment tasks. */
            /***************************************************************
            * NOTE: NO CHECK IS MADE TO SEE IF THE LABOR FUNCTION FLAG
            *       IS TURNED ON OR OFF THEREFORE FINDING THE PENDING
            *       REPLENISHMENT TASKS IS INDEPENDENT OF LABOR MANAGEMENT
            ****************************************************************/
            
            /*acpvxg*************Miniload changes start********************************
            
               Replenishments during putaway will always be off when dropping to the induction location 
               regardless of the setting of syspar "Replenishment during putaway".
               
               Following is the pseudocode for the same:
           1.Set the flag in case expected receipt transaction is sent. 
             Something like "Is_exprcpt-sent". If the flag is set to true(or "Y") 
             then following function call will be skipped.
                  
             Current code:
                   
               If NOT msku pallet (for MSKU pallets also this call is skipped)  
                  replen_list_status = Find_pending_replen_tasks(plogi_loc,client, server);
           
             Modified Condition will be:
           
               If NOT msku pallet and Is_exprcpt-sent = false(or "N") then
                  replen_list_status = Find_pending_replen_tasks(plogi_loc,client, server);
               Else
                  This call will be skipped.
           
            ***********************Miniload changes end***************************/
			
            pl_text_log.ins_msg_async('INFO', l_func_name, 'before find_pending_replen_tasks. is_msku_pallet = '
                                                || g_msku_pallet
                                                || ' is_parent_pallet '
                                                || g_is_parent_pallet
                                                || ' exprec_sent = '
                                                || g_exprec_sent, sqlcode, sqlerrm, g_application_func, g_program_name);

            IF ( g_msku_pallet = 0 AND g_is_parent_pallet = 0 AND g_exprec_sent = 'N' ) THEN
                l_replen_list_status := find_pending_replen_tasks(g_plogi_loc, g_putaway_client, l_loc_collection, g_o_putaway_server);
                IF l_replen_list_status = rf.status_normal THEN
                    COMMIT;
                ELSE
                    ROLLBACK;
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'ROLLBACK b/c bad status from replen_list_status. is_parent_pallet = '
                                                        || g_is_parent_pallet
                                                        || ' exprec_sent = '
                                                        || g_exprec_sent, sqlcode, sqlerrm, g_application_func, g_program_name);

                    l_rf_status := l_replen_list_status;
                END IF;

            ELSE
                g_o_putaway_server.loc_cnt := rf.nonull(l_hi_loc_cnt);
            END IF;

            g_o_putaway_server.list_status := rf.nonull(l_replen_list_status);
            g_o_putaway_server.qty := rf.nonull(g_qty_rec);
            g_o_putaway_server.spc := rf.nonull(g_spc);
            g_o_putaway_server.prod_id := rf.nonull(g_prod_id);
            g_o_putaway_server.cpv := rf.nonull(g_cust_pref_vendor);
            g_o_putaway_server.max_qty := rf.nonull(g_max_qty);
            o_loc_collection := l_loc_collection;
        ELSE
            ROLLBACK;
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending putaway. l_rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        o_putaway_server := g_o_putaway_server;
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending putaway. Output server message.  list_status = '||o_putaway_server.list_status
										||' pending_rpl_flag = '
										||o_putaway_server.pending_rpl_flag
										||' loc_cnt = '
										||o_putaway_server.loc_cnt
										||' prompt_for_hst_qty = '
										||o_putaway_server.prompt_for_hst_qty
										||' cpv = '
										||o_putaway_server.cpv
										||' prod_id = '
										||o_putaway_server.prod_id
										||' qty = '
										||o_putaway_server.qty
										||' spc = '
										||o_putaway_server.spc
										||' max_qty = '
										||o_putaway_server.max_qty, sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN l_rf_status;
    END putaway_service;
	
/*****************************************************************************
**  FUNCTION:
**      put_away()
**  DESCRIPTION:
**       Main function for Putaway service.
** CALLED BY: putaway_service
**  RETURN VALUES:
**      l_rf_status code
*********************************************************************************/

    FUNCTION put_away RETURN rf.status IS

        l_func_name             VARCHAR2(50) := 'put_away';
        l_rf_status               rf.status := rf.status_normal;
        l_home_slot_flag        NUMBER;
        l_new_float_flag        NUMBER := 1;
        icmhldinvcreated        NUMBER := 0;
        icmputdelete            NUMBER := 0;
        l_pit_pallet_flag       VARCHAR2(1) := 'N';
        l_ret_val               NUMBER;
        l_sys_msg_id            NUMBER;
        l_prod_id               pm.prod_id%TYPE;
        l_rec_id                inv.rec_id%TYPE;
        l_qoh                   inv.qoh%TYPE;
        l_spc                   pm.spc%TYPE;
        l_exp_date              DATE;
        l_inv_status            inv.status%TYPE;
        l_finish_good_po_flag   VARCHAR2(1) := 'N';
        l_slot_type             loc.slot_type%TYPE;
        l_temp                  NUMBER := 0; 						--Matrix
        l_dummy                 VARCHAR2(1);
    BEGIN
		--Check if RF devices can be used
        l_rf_status := check_global_rf();
        IF ( l_rf_status != rf.status_normal ) THEN
            RETURN l_rf_status;
        END IF;

		  
		   -- Retrieve pallet_id, plogi_loc, real_put_path_val, user_id from msg
		  
        get_rf_info;

		--Check sys_config for the value of strip_loc
        check_strip_loc;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'After Check Strip loc.', sqlcode, sqlerrm, g_application_func, g_program_name);

		/* 
		**  Check putawaylst for the following conditions - 
		**  1. pallet does not exist 
		**  2. putaway already confirmed 
		**  3. dest loc undefined
		*/
        l_rf_status := check_putawaylist;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'After Check putawaylst', sqlcode, sqlerrm, g_application_func, g_program_name);
        IF ( l_rf_status != rf.status_normal ) THEN
            RETURN l_rf_status;
        END IF;

		/* 
		**  Prepare user put aisle and put slot values of the scanned location
		**  and check if they match that of the destination location
		*/
        l_rf_status := check_put_path;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'After Check_put_path', sqlcode, sqlerrm, g_application_func, g_program_name);
        IF ( l_rf_status != rf.status_normal ) THEN
            RETURN l_rf_status;
        END IF;
        l_rf_status := get_putaway_info;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'After get_putaway_info,'
                                            || ' Exp_date = '
                                            || g_vc_exp_date
                                            || ' Mfg_date = '
                                            || g_mfg_date, sqlcode, sqlerrm, g_application_func, g_program_name);

        IF ( l_rf_status != rf.status_normal ) THEN
            RETURN l_rf_status;
        END IF;
        l_rf_status := get_product_info;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'After get_product_info', sqlcode, sqlerrm, g_application_func, g_program_name);
        IF ( l_rf_status != rf.status_normal ) THEN
            RETURN l_rf_status;
        END IF;
        get_po_info;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'After PO info', sqlcode, sqlerrm, g_application_func, g_program_name);
        l_rf_status := check_po_status;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'After PO status. rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        IF ( l_rf_status != rf.status_normal ) THEN
            RETURN l_rf_status;
        END IF;
        g_loc_status := 1;
        IF ( g_loc_status = 1 ) THEN
            l_home_slot_flag := check_home_slot;
        END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'After check_home_slot. home_slot_flag = '||l_home_slot_flag, sqlcode, sqlerrm, g_application_func, g_program_name);
        
        IF pl_common.f_is_internal_production_po(g_receive_id) = TRUE THEN
            /* igoo9289 07/29/2020 Applying the change done in putaway.pc as per the below comment by Kiet
            /* knha8378 Nov 4, 2019 remove function to auto confirm and auto open so treat like normal PO */
            /* :finish_good_po_flag := 'Y';     */
            /* default fake to minimize changes as N below by knha8378 */
            l_finish_good_po_flag := 'N';
        ELSE
            l_finish_good_po_flag := 'N';
        END IF;
        
        IF ( ( g_erm_status = 'OPN' ) OR l_finish_good_po_flag = 'Y' ) THEN
            IF ( g_erm_type != 'CM' ) THEN
				/*
				**  Regular PO (not a RETURNs PO).
				**
				**  SPLIT put-confirm into old INV should not
				**  check palletid.
				*/
                l_rf_status := confirm_putaway_task;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'After confirm_putaway_task. 1 l_rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
                IF ( l_rf_status != rf.status_normal ) THEN
                    RETURN l_rf_status;
                END IF;
               
				-- Dont call update_inv for finish good POs
                IF ( g_qty_rec > 0 AND l_finish_good_po_flag = 'N' ) THEN
                    IF ( l_home_slot_flag = 1 ) THEN
						  
						  -- Destination location is a home slot.
						  
                        IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
                            l_rf_status := check_rlc_put;
                            IF ( l_rf_status != rf.status_normal ) THEN
                                RETURN l_rf_status;
                            END IF;
                            l_rf_status := update_inv(g_plogi_loc, g_pallet_id, 1, l_home_slot_flag);
                        ELSE
                            l_rf_status := update_inv(g_plogi_loc, g_plogi_loc, 1, l_home_slot_flag);
                        END IF;
                    ELSIF ( ( g_uom = 1 ) AND ( check_new_float() = 0 ) ) THEN
						  /*
						  ** Putaway of splits not going to a home slot and
						  ** not going to a rule 1 floating slot.
						  */
                        IF ( l_home_slot_flag = 1 ) THEN
                            l_rf_status := update_inv(g_plogi_loc, g_plogi_loc, 0, l_home_slot_flag);
                        ELSE
                            l_rf_status := update_inv(g_plogi_loc, g_pallet_id, 0, l_home_slot_flag);
                        END IF;
                    ELSE
                        l_rf_status := check_reserve_loc;
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'After check_reserve_loc. l_rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
                        
                        IF ( l_rf_status != rf.status_normal ) THEN
                            RETURN l_rf_status;
                        END IF;
                        IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
                            l_rf_status := check_pallet_type;
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'After check_pallet_type. l_rf_status = ' || l_rf_status, sqlcode, sqlerrm
                            , g_application_func, g_program_name);
                        END IF;

                        IF ( l_rf_status != rf.status_normal ) THEN
                            RETURN l_rf_status;
                        END IF;
                        l_rf_status := update_inv(g_plogi_loc, g_pallet_id, 1, l_home_slot_flag);
                    END IF; --End l_home_slot_flag = 1

                    IF ( l_rf_status != rf.status_normal ) THEN
                        RETURN l_rf_status;
                    END IF;
					
                    l_pit_pallet_flag := pl_putaway_utilities.f_is_pallet_in_pit_location(g_pallet_id);

                    pl_log.ins_msg('INFO', l_func_name, '  g_erm_type =  '
                                                        || g_erm_type
                                                        || ' g_erm_type =  '
                                                        || g_erm_type
                                                        || ' g_erm_id = '
                                                        || g_erm_id,
                                    NULL,NULL );


                    IF ( l_pit_pallet_flag = 'Y' ) THEN
                        l_rf_status := write_transaction('PIT');
                      -- 2021.08.11 (kchi7065) Story 3577 Check if this is a Cross Dock pallet.
                      ELSIF ( g_erm_type = 'XN' OR ( g_erm_type = 'CM' AND g_erm_id LIKE 'X%' )) THEN 

                        -- If it is Cross Dock check if Destinatin Location is valid.
                        IF ( f_check_location (g_dest_loc) = 'Y' ) THEN

                            -- If the Location is valid, create a PUX transaction.
                            l_rf_status := write_transaction('PUX');

                          ELSE 
                        
                            -- If the location is invalid, check if the order generation occurred.
                            -- If no, create a PUX transaction.
                            -- If yes, error   

                            IF ( f_check_order_gen(g_pallet_id) = 'Y' ) THEN
                                -- Raise error
                                -- Please use the RF Replen and Bulk Pull option
                                pl_text_log.ins_msg_async('INFO', 
                                                          l_func_name, 
                                                          'Order Generation has already occurred. Please use the RF Replen and Bulk Pull option ', 
                                                          sqlcode, 
                                                          sqlerrm, 
                                                          g_application_func, 
                                                          g_program_name);

                                return RF.STATUS_XDOCK_PUT_INV_LOC;

                              ELSE

                                l_rf_status := write_transaction('PUX');

                            END IF;

                        END IF;

                    ELSE

                        l_rf_status := write_transaction('PUT');

                    END IF;

                    IF ( l_rf_status != rf.status_normal ) THEN
                        RETURN l_rf_status;
                    END IF;

					-- RDC nondep Get the HST qty prompt flag qty in splits 
                    IF ( g_msku_pallet = 0 AND g_is_parent_pallet = 0 ) THEN
                        g_o_putaway_server.prompt_for_hst_qty := get_hst_qty_prompt('P', g_plogi_loc, g_qty_rec);
                    END IF;

                ELSIF ( g_qty_rec = 0 ) THEN
                    IF ( l_home_slot_flag = 1 ) THEN
                        l_rf_status := update_inv_zero_rcv(1);
                    ELSE
                        l_rf_status := delete_inv;
                    END IF;

                    IF ( l_rf_status != rf.status_normal ) THEN
                        RETURN l_rf_status;
                    END IF;
				END IF; --End g_qty_rec > 0 AND l_finish_good_po_flag = 'N'
            ELSE
						
				-- RETURNs PO.
						
                    check_rtn_bfr_mfc;
                    l_dummy := 'N';
                   
						  /*
						  **  Putaway is not allowed for RETURNs if the manifest
						  **  is not closed and syspar RTN_BFR_MFC is set to N.
						  */
                    BEGIN
                        SELECT
                            'Y'
                        INTO l_dummy
                        FROM
                            manifests
                        WHERE
                            manifest_no = to_number(substr(g_receive_id, 2))
                            AND manifest_status = 'CLS';

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            IF g_rtn_bfr_mfc = 'N' THEN
                                pl_text_log.ins_msg_async('WARN', l_func_name, 'Putaway is not allowed before the MANIFEST is closed. receive_id = ' 
								|| g_receive_id, sqlcode, sqlerrm, g_application_func, g_program_name);                               
                                RETURN rf.status_manifest_close;
                            ELSE
                                l_dummy := 'N';
                            END IF;
                        WHEN OTHERS THEN
                            IF g_rtn_bfr_mfc = 'N' THEN
                                pl_text_log.ins_msg_async('WARN', l_func_name, ' unable to select from manifests for this rec-id of putawaylst. receive_id = ' || g_receive_id
                                , sqlcode, sqlerrm, g_application_func, g_program_name);
                                RETURN rf.status_manifest_close;
                            ELSE
                                pl_text_log.ins_msg_async('WARN', l_func_name, ' unable to select from manifests for this rec-id of putawaylst (RTN_BFR_MFC=Y).'
                                || g_receive_id, sqlcode, sqlerrm, g_application_func, g_program_name);
                                RETURN rf.status_manifest_close;
                            END IF;
                    END;
                    

				  /*Don't delete putaway task during put for RETURNs. Just
				  ** update the putaway_put flag and inventory weight and temp if any.
				  ** Delete the task only when it's putawayed and the manifest has
				  ** been closed.
				  */

                    IF l_dummy = 'Y' THEN
                        BEGIN
                            pl_ml_common.gen_ml_tasks_for_mis(g_pallet_id, l_rf_status);
                            IF g_mispick = 'Y' THEN
                                icmhldinvcreated := 1;                                
                            END IF;
							icmputdelete := 1;
                        EXCEPTION
                            WHEN OTHERS THEN
                                pl_text_log.ins_msg_async('WARN', l_func_name, 'Execution of pl_ml_common.gen_ml_tasks_for_mis RETURN errors. receive_id = '
                                || g_receive_id, sqlcode, sqlerrm, g_application_func, g_program_name);
                                RETURN sqlcode;
                        END;
                    ELSE
                        l_rf_status := confirm_putaway_task;
                    END IF;

                    IF ( l_rf_status != rf.status_normal ) THEN
                        RETURN l_rf_status;
                    END IF;
					
                    IF ( g_mispick != 'Y' ) THEN
                        IF ( g_putaway_client.rtn_putaway_conf = 'N' ) THEN
                            l_rf_status := update_put_trans;
                            IF ( l_rf_status = rf.status_normal ) THEN
                                pl_text_log.ins_msg_async('INFO', l_func_name, 'Performed dummy putaway for SLMS with rtn_putaway_conf set to N'
                                , sqlcode, sqlerrm, g_application_func, g_program_name);
                                RETURN l_rf_status;
                            ELSE
                                RETURN rf.status_putaway_fail;
                            END IF;

                        END IF;

                        pl_text_log.ins_msg_async('INFO', l_func_name, 'After mispick,  = g_qty_rec '||g_qty_rec, sqlcode, sqlerrm, g_application_func, g_program_name);
                        IF ( g_qty_rec > 0 ) THEN
                            IF ( l_home_slot_flag = 1 ) THEN
                                l_rf_status := update_inv(g_plogi_loc, g_plogi_loc, 0, l_home_slot_flag);
                            ELSE
								  /*
								  **  Changes to take care of RETURNs to existing
								  **  locations.
								  */
                                l_new_float_flag := check_new_float;
                                IF ( l_new_float_flag = 1 ) THEN
                                    l_rf_status := update_inv(g_plogi_loc, g_pallet_id, 1, l_home_slot_flag);
                                ELSE
                                    l_rf_status := update_inv(g_plogi_loc, g_pallet_id, 0, l_home_slot_flag);
                                END IF;

                            END IF;

                            IF ( l_rf_status != rf.status_normal ) THEN
                                RETURN l_rf_status;
                            END IF;

                            -- 2021.08.11 (kchi7065) Story 3577 Check if this is a Cross Dock pallet.
                            IF ( g_erm_type = 'XN' OR ( g_erm_type = 'CM' AND g_erm_id LIKE 'X%' )) THEN 

                              -- If it is Cross Dock check if Destinatin Location is valid.
                              IF ( f_check_location (g_dest_loc) = 'Y' ) THEN

                                  -- If the Location is valid, create a PUX transaction.
                                  l_rf_status := write_transaction('PUX');

                                ELSE 
                        
                                  -- If the location is invalid, check if the order generation occurred.
                                  -- If no, create a PUX transaction.
                                  -- If yes, error   

                                  IF ( f_check_order_gen(g_pallet_id) = 'Y' ) THEN
                                      -- Raise error
                                      -- Please use the RF Replen and Bulk Pull option
                                      pl_text_log.ins_msg_async('INFO', 
                                                                l_func_name, 
                                                                'Order Generation has already occurred. Please use the RF Replen and Bulk Pull option ', 
                                                                sqlcode, 
                                                                sqlerrm, 
                                                                g_application_func, 
                                                                g_program_name);

                                      return RF.STATUS_XDOCK_PUT_INV_LOC;

                                    ELSE

                                      l_rf_status := write_transaction('PUX');

                                  END IF;
      
                              END IF;

                              ELSE

                                l_rf_status := write_transaction('PUT');

                            END IF;

                            IF ( ( l_rf_status = rf.status_normal ) AND ( icmputdelete = 1 ) ) THEN
                                l_rf_status := confirm_putaway_task;
                                IF ( l_rf_status = rf.status_normal ) THEN
                                    l_rf_status := delete_putaway_task(l_finish_good_po_flag);
                                END IF;

                            END IF;

                            IF ( l_rf_status != rf.status_normal ) THEN
                                RETURN l_rf_status;
                            END IF;
                        ELSIF ( g_qty_rec = 0 ) THEN
                            IF ( l_home_slot_flag = 1 ) THEN
                                l_rf_status := update_inv_zero_rcv(1);
                            ELSE
                                l_new_float_flag := check_new_float;
                                IF ( l_new_float_flag = 1 ) THEN
                                    l_rf_status := delete_inv;
                                ELSE
                                    l_rf_status := update_inv_zero_rcv(0);
                                END IF;

                            END IF;

                            IF ( l_rf_status != rf.status_normal ) THEN
                                RETURN l_rf_status;
                            END IF;
                        END IF;

                    ELSE -- mispicked pallet 
                        IF ( icmputdelete = 1 ) THEN
                            l_rf_status := confirm_putaway_task;
                            IF ( l_rf_status = rf.status_normal ) THEN

                                -- Story 3577 Use PUX for XN POs.
                                IF ( g_erm_type = 'CM' AND g_erm_id LIKE 'X%' ) THEN

                                    l_rf_status := write_transaction('PUX');

                                ELSE 

                                    l_rf_status := write_transaction('MIS');

                                END IF;

                                IF ( l_rf_status = rf.status_normal ) THEN
                                    l_rf_status := delete_putaway_task(l_finish_good_po_flag);
                                END IF;

                            END IF;

                        END IF;

                        IF ( ( l_rf_status = rf.status_normal ) AND ( icmhldinvcreated = 0 ) ) THEN
                            BEGIN
                                pl_ml_common.gen_ml_tasks_for_mis(g_pallet_id, l_rf_status);
                            EXCEPTION
                                WHEN OTHERS THEN
                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Execution of pl_ml_common.gen_ml_tasks_for_mis RETURN errors sqlcode',
									sqlcode, sqlerrm, g_application_func, g_program_name);                                    
                                    RETURN sqlcode;
                            END;

                        END IF; -- End (l_rf_status = rf.status_normal ) AND ( icmhldinvcreated = 0 )

                    END IF; --End g_mispick != 'Y'

                    IF ( l_rf_status != rf.status_normal ) THEN
                        RETURN l_rf_status;
                    END IF;
                END IF; --End g_erm_type != 'CM'
			
        ELSIF ( g_erm_status = 'CLO' ) OR ( g_erm_status = 'VCH' ) THEN -- PO is CLOSED 
            IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
                IF ( l_home_slot_flag = 0 ) THEN
                    l_rf_status := check_reserve_loc;
                ELSE
                    l_rf_status := check_rlc_put;
                END IF;

                IF ( l_rf_status = rf.status_normal ) THEN
                    l_rf_status := update_rlc_inv(g_plogi_loc, g_pallet_id, l_home_slot_flag, 1);
                END IF;

            END IF;

            IF ( l_rf_status = rf.status_normal ) THEN
                l_rf_status := update_put_trans;
            END IF;
            IF ( l_rf_status = rf.status_normal ) THEN
                l_rf_status := delete_putaway_task(l_finish_good_po_flag);
            END IF;

            IF ( l_rf_status != rf.status_normal ) THEN
                RETURN l_rf_status;
            END IF;

			--  needs to prompt even for PO closed 
			-- RDC nondep Get the HST qty prompt flag qty in splits 
			
            g_o_putaway_server.prompt_for_hst_qty := get_hst_qty_prompt('P', g_plogi_loc, g_qty_rec);
			
        ELSE -- ERROR: PO is not OPEN or CLOSED 
		
            pl_text_log.ins_msg_async('WARN', l_func_name, 'PO is not in OPN or CLO or VCH status. erm_id = ' || g_erm_id,
											sqlcode, sqlerrm, g_application_func, g_program_name);
            l_rf_status := rf.status_inv_po;
			
        END IF; --End g_erm_status = 'OPN' OR l_finish_good_po_flag = 'Y'

        IF ( g_msku_pallet = 1 AND l_rf_status = rf.status_normal ) THEN
            UPDATE putawaylst
            SET
                parent_pallet_id = NULL
            WHERE
                pallet_id = g_pallet_id;

            IF ( SQL%rowcount = 0 ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to set parent_pallet_id to null. pallet_id = ' || g_pallet_id, sqlcode, 
                sqlerrm, g_application_func, g_program_name);
            END IF;

        END IF; --End g_msku_pallet = 1 AND l_rf_status = rf.status_normal

        IF ( l_rf_status = rf.status_normal ) THEN
            delete_ppu_trans(g_erm_id, g_pallet_id);
        END IF;

		/*------------------Matrix Changes Start -----------------------*/

        IF ( g_is_matrix_putaway > 0 AND g_lv_reason_code NOT IN ('T30','W10','W45','W40')) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Debug message for Matrix Change table for puaway.', sqlcode, sqlerrm);
            BEGIN
				--check if the target location is matrix induction location 
                SELECT
                    l.slot_type
                INTO l_slot_type
                FROM
                    lzone   lz,
                    zone    z,
                    loc     l
                WHERE
                    lz.zone_id = z.zone_id
                    AND l.logi_loc = lz.logi_loc
                    AND l.logi_loc = g_plogi_loc
                    AND z.z_area_code = pl_matrix_common.f_get_pm_area(g_lv_prod_id)
                    AND l.slot_type IN (
                        'MXI',
                        'MXT'
                    )
                    AND z.zone_type = 'PUT'
                    AND z.rule_id = 5;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to find slot_type of matrix location for putaway. plogi_loc = ' 
											|| g_putaway_client.plogi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);
                    l_rf_status := rf.status_sel_loc_fail;
                    RETURN l_rf_status;
            END;

            IF ( l_slot_type = 'MXT' ) THEN
                BEGIN
                    UPDATE inv
                    SET
                        mx_xfer_type = 'PUT'
                    WHERE
                        logi_loc = g_pallet_id;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to update mx_xfer_type for inv for putaway. pallet_id = ' 
											|| g_putaway_client.pallet_id, sqlcode, sqlerrm, g_application_func, g_program_name);                      
                        l_rf_status := rf.status_inv_update_fail;
                        RETURN l_rf_status;
                END;
            END IF;

			--if target location is matrix induction location, insert record into matrix_out table

            IF ( l_slot_type = 'MXI' ) THEN
                l_temp := 0;
                BEGIN
                    l_sys_msg_id := mx_sys_msg_id_seq.nextval;
                    SELECT
                        i.prod_id,
                        i.rec_id,
                        i.qoh,
                        p.spc,
                        i.exp_date,
                        i.status
                    INTO
                        l_prod_id,
                        l_rec_id,
                        l_qoh,
                        l_spc,
                        l_exp_date,
                        l_inv_status
                    FROM
                        inv   i,
                        pm    p
                    WHERE
                        i.prod_id = p.prod_id
                        AND logi_loc = g_pallet_id;

                    l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
																		i_interface_ref_doc => 'SYS03',
																		i_label_type => 'LPN', --MSKU
																		i_parent_pallet_id => NULL,
																		i_rec_ind => 'S', ---H OR D  
																		i_pallet_id => g_pallet_id, 
																		i_prod_id => l_prod_id, 
																		i_case_qty => trunc(l_qoh / l_spc), 
																		i_exp_date => l_exp_date,
																		i_erm_id => l_rec_id,
																		i_batch_id => mx_batch_no_seq.NEXTVAL,
																		i_trans_type => 'PUT',	
																		i_inv_status => l_inv_status);

                    IF l_ret_val = 1 THEN --failure
                        l_temp := 1;
                    ELSE
                        pl_text_log.ins_msg('INFO', l_func_name, 'Insert into matrix_out completed for pallet_id' || g_pallet_id,
                        sqlcode, sqlerrm, g_application_func, g_program_name);
                        l_temp := 0;
                        l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);
                        IF l_ret_val = 1 THEN --failure
                            l_temp := 1;
                        ELSE
                            COMMIT;
                        END IF;
                    END IF;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        l_temp := 1;
                END;

                IF ( l_temp = 1 ) THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to insert record into matrix_out table for putaway. pallet_id = ' 
													|| g_putaway_client.pallet_id, sqlcode, sqlerrm, g_application_func, g_program_name);
                    

                    l_rf_status := rf.status_insert_fail;
                    RETURN l_rf_status;
                END IF;

            END IF;

        END IF;

		/*------------------Matrix Changes End -----------------------*/

        RETURN l_rf_status;
    END put_away;
	
/*****************************************************************************
**  FUNCTION:
**      get_hst_qty_prompt()
** Called by: put_away
**  DESCRIPTION:
**       This function selects HST prompt flag for loc
**	IN PARAMETERS:
**
**  RETURN VALUES:
**      l_rf_status code
*********************************************************************************/

    FUNCTION get_hst_qty_prompt (
        i_option      IN   VARCHAR2,
        i_plogi_loc   IN   inv.plogi_loc%TYPE,
        i_qty_rec     IN   putawaylst.qty_received%TYPE
    ) RETURN VARCHAR2 IS

        l_func_name   VARCHAR2(50) := 'Get_HST_qty_prompt';
        l_sret        VARCHAR2(1);
        l_sopt        VARCHAR2(1);
        l_sprompt     VARCHAR2(1) := 'N';
        l_sloc        VARCHAR2(18);
        l_nqty        NUMBER;
    BEGIN
        l_nqty := i_qty_rec; -- in splits 
        l_sopt := i_option;
        l_sloc := i_plogi_loc;		
        l_sprompt := pl_putaway_utilities.f_get_hst_prompt(l_sopt, 'N', l_sloc, l_nqty);
        l_sret := l_sprompt;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'HST prompt flag for loc. plogi_loc = '
                                            || g_plogi_loc
                                            || ' qty_rec = '
                                            || g_qty_rec
                                            || ' sRet = '
                                            || l_sret, sqlcode, sqlerrm, g_application_func, g_program_name);

        RETURN l_sret;
		
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_sret := 'N';
			pl_text_log.ins_msg_async('WARN', l_func_name, ' Unable to get pl_putaway_utilities.f_get_HST_Prompt. Processing will continue. plogi_loc = '
                                                || g_plogi_loc
                                                ||' sRet = '
                                                || l_sret, sqlcode, sqlerrm, g_application_func, g_program_name);

            RETURN l_sret;
        WHEN OTHERS THEN
            l_sret := l_sprompt;
            pl_text_log.ins_msg_async('WARN', l_func_name, ' Error calling selecting pl_putaway_utilities.f_get_HST_Prompt. Processing will continue. plogi_loc = '
                                                || g_plogi_loc
                                                ||' sRet = '
                                                || l_sret, sqlcode, sqlerrm, g_application_func, g_program_name);

            RETURN l_sret;
			
    END get_hst_qty_prompt;
	
/*****************************************************************************
**  FUNCTION:
**      data_collect_check()
**  DESCRIPTION:
**       This function perform data_collect_check.
**	CALLED BY: update_inv
**	IN PARAMETERS:
**		i_plogi_loc
**      i_logi_loc
**		i_home_slot_flag
**  RETURN VALUES:
**      l_rf_status code
*********************************************************************************/

    FUNCTION data_collect_check (
        i_plogi_loc        IN   inv.plogi_loc%TYPE,
        i_logi_loc         IN   inv.logi_loc%TYPE,
        i_home_slot_flag   IN   NUMBER
    ) RETURN rf.status IS

        l_func_name   	VARCHAR2(50) := 'Data_collect_check';
        l_rf_status     rf.status := rf.status_normal;
        l_plogi_loc   	inv.plogi_loc%TYPE;
        l_logi_loc    	inv.logi_loc%TYPE;
    BEGIN
        l_plogi_loc := i_plogi_loc;
        l_logi_loc := i_logi_loc;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside Data collect check. i_plogi_loc = '||i_plogi_loc
											||' i_logi_loc = '
											|| i_logi_loc
											||' Mfg_ind = '
                                            || g_mfg_ind
                                            || ' exp_ind = '
                                            || g_exp_ind
                                            || ' lot_ind = '
                                            || g_lot_ind
                                            || ' temp_ind = '
                                            || g_temp_ind, sqlcode, sqlerrm, g_application_func, g_program_name);

        IF ( g_temp_ind = 'C' ) THEN
            BEGIN
                IF ( g_m_rule_id = 5 ) THEN --If matrix destination location
                    UPDATE inv
                    SET
                        temperature = round(g_temp, 1)
                    WHERE
                        logi_loc = l_logi_loc;

                ELSE
                    UPDATE inv
                    SET
                        temperature = round(g_temp, 1)
                    WHERE
                        plogi_loc = l_plogi_loc
                        AND logi_loc = l_logi_loc;
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' update of temperature for inventory location failed. plogi_loc = '
                                                        || l_plogi_loc
                                                        || ' logi_loc = '
                                                        || l_logi_loc
														||' rule_id = '
														||g_m_rule_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                    l_rf_status := rf.status_inv_update_fail;
                    RETURN l_rf_status;
            END;
        END IF;-- end temp_ind = 'C' 		

        IF ( g_lot_ind = 'C' ) THEN
            BEGIN
                IF ( g_m_rule_id = 5 ) THEN --If matrix destination location
                    UPDATE inv
                    SET
                        lot_id = g_lot_id
                    WHERE
                        logi_loc = l_logi_loc;

                ELSE
                    UPDATE inv
                    SET
                        lot_id = g_lot_id
                    WHERE
                        plogi_loc = l_plogi_loc
                        AND logi_loc = l_logi_loc;

                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' update of lot_id for inventory location failed. '
                                                        || ' plogi_loc = '
                                                        || l_plogi_loc
                                                        || ' logi_loc = '
                                                        || l_logi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                    l_rf_status := rf.status_inv_update_fail;
                    RETURN l_rf_status;
            END;
        END IF; -- end lot_ind = 'C' 

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Going to update inv. '
                                            || ' plogi_loc = '
                                            || l_plogi_loc
                                            || ' logi_loc = '
                                            || l_logi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

        BEGIN
            IF ( g_m_rule_id = 5 ) THEN --If matrix destination location
                UPDATE inv
                SET
                    exp_ind = 'Y'
                WHERE
                    logi_loc = l_logi_loc;

            ELSE
                UPDATE inv
                SET
                    exp_ind = 'Y'
                WHERE
                    plogi_loc = l_plogi_loc
                    AND logi_loc = l_logi_loc;

            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' set exp_ind to Y for inventory location failed. '
                                                    || ' plogi_loc = '
                                                    || l_plogi_loc
                                                    || ' logi_loc = '
                                                    || l_logi_loc
													|| ' rule_id = '
													|| g_m_rule_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                l_rf_status := rf.status_inv_update_fail;
                RETURN l_rf_status;
        END;

        IF ( g_mfg_ind = 'C' ) THEN
		  /*
		  **  The exp_date has been calculated in either the collect_data form
		  **  or in the validate RF program.
		  */
            BEGIN
                IF ( g_m_rule_id = 5 ) THEN --If matrix destination location
                    UPDATE inv
                    SET
                        mfg_date = to_date(g_mfg_date, 'FXDD-MON-YYYY'),
                        exp_date = to_date(g_vc_exp_date, 'FXDD-MON-YYYY')
                    WHERE
                        logi_loc = l_logi_loc;

                ELSE
                    UPDATE inv
                    SET
                        mfg_date = to_date(g_mfg_date, 'FXDD-MON-YYYY'),
                        exp_date = to_date(g_vc_exp_date, 'FXDD-MON-YYYY')
                    WHERE
                        plogi_loc = l_plogi_loc
                        AND logi_loc = l_logi_loc;

                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' update of mfg_date and exp_date for inventory location failed. '
                                                        || ' plogi_loc = '
                                                        || l_plogi_loc                                                        
                                                        || ' logi_loc = '
                                                        || l_logi_loc
														|| ' rule_id ='
														|| g_m_rule_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                    l_rf_status := rf.status_inv_update_fail;
                    RETURN l_rf_status;
            END; -- End mfg_ind == 'C' 
			
        ELSIF ( g_exp_ind = 'C' ) THEN
            BEGIN
                IF ( g_m_rule_id = 5 ) THEN --If matrix destination location
                    UPDATE inv
                    SET
                        exp_date = to_date(g_vc_exp_date, 'FXDD-MON-YYYY')
                    WHERE
                        logi_loc = l_logi_loc;

                ELSE
                    UPDATE inv
                    SET
                        exp_date = to_date(g_vc_exp_date, 'FXDD-MON-YYYY')
                    WHERE
                        plogi_loc = l_plogi_loc
                        AND logi_loc = l_logi_loc;

                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' set exp_date to exp_date for inventory location failed.' 
                                                        || ' plogi_loc = '
                                                        || l_plogi_loc
                                                        || ' logi_loc = '
                                                        || l_logi_loc
														|| ' rule_id = '
														|| g_m_rule_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                    l_rf_status := rf.status_inv_update_fail;
                    RETURN l_rf_status;
            END; -- End exp_ind == 'C' 
        ELSE
            
			BEGIN
				IF ( g_m_rule_id = 5 ) THEN --If matrix destination location
					UPDATE inv
					SET
						exp_date = to_date(g_vc_exp_date, 'FXDD-MON-YYYY')
					WHERE
						logi_loc = l_logi_loc;

				ELSE
					UPDATE inv
					SET
						exp_date = to_date(g_vc_exp_date, 'FXDD-MON-YYYY')
					WHERE
						plogi_loc = l_plogi_loc
						AND logi_loc = l_logi_loc;

				END IF;
			EXCEPTION
				WHEN OTHERS THEN
					pl_text_log.ins_msg_async('WARN', l_func_name, ' set exp_date to default for inventory location failed.'
														|| ' plogi_loc = '
														|| l_plogi_loc
														|| ' logi_loc = '
														|| l_logi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

					l_rf_status := rf.status_inv_update_fail;
					RETURN l_rf_status;
			END;
		END IF;	-- End defaults
		
        BEGIN
            IF ( g_m_rule_id = 5 ) THEN --If matrix destination location
                UPDATE inv
                SET
                    exp_ind = 'N'
                WHERE
                    logi_loc = l_logi_loc;

            ELSE
                UPDATE inv
                SET
                    exp_ind = 'N'
                WHERE
                    plogi_loc = l_plogi_loc
                    AND logi_loc = l_logi_loc;

            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'set exp_ind to N for inventory location failed.'
                                                    || ' plogi_loc = '
                                                    || l_plogi_loc
                                                    || ' logi_loc = '
                                                    || l_logi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                l_rf_status := rf.status_inv_update_fail;
                RETURN l_rf_status;
        END;

        RETURN l_rf_status;
    END data_collect_check; -- end Data_collect_check 

/*******************************<+>******************************************
**  Function:
**     Update_inv
**
**  Description:
**     This function updates the inventory as part of the putaway
**     confirmation process.
**
**  Parameters:
**     i_plogi_loc
**     p_logi_loc
**     flag
**     home_slot_flag
**	CALLED BY: put_away
**  RETURN Values:
**     NORMAL if update made succesfully
**     Anything else indicates an issue with the update.
********************************************************************************/

    FUNCTION update_inv (
        i_plogi_loc        IN   inv.plogi_loc%TYPE,
        i_logi_loc         IN   inv.logi_loc%TYPE,
        i_flag             IN   NUMBER,
        i_home_slot_flag   IN   NUMBER
    ) RETURN rf.status IS

        l_func_name   VARCHAR2(30) := 'Update_inv';
        l_rf_status     rf.status := rf.status_normal;
        l_plogi_loc   VARCHAR2(10);
        l_logi_loc    VARCHAR2(18);
    BEGIN
        IF ( i_flag = 1 ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'flag true', sqlcode, sqlerrm, g_application_func, g_program_name);
        ELSE
            pl_text_log.ins_msg_async('INFO', l_func_name, 'flag false', sqlcode, sqlerrm, g_application_func, g_program_name);
        END IF;	
		
		   -- Initialize Oracle variables from parameters.
		 
        l_plogi_loc := i_plogi_loc;
        l_logi_loc := i_logi_loc;
        BEGIN
            IF ( i_flag = 0 ) THEN
                IF ( l_logi_loc = 'FFFFFF' ) THEN
				  /*
				  **  Changes to take care of RETURNs to existing locations.
				  **  For existing floating slot assume one pallet in one slot.
				  */
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'l_logi_loc = FFFFFF.'
                                                        || ' plogi_loc = '
                                                        || l_plogi_loc
                                                        || 'l_logi_loc = '
                                                        || l_logi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                    UPDATE inv
                    SET
                        qoh = qoh + g_qty_rec,
                        qty_planned = decode(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0,
                                             0),
                        cube = cube + ( ( g_qty_rec - g_qty_exp ) / g_spc ) * g_case_cube,
                        parent_pallet_id = NULL
                    WHERE
                        plogi_loc = l_plogi_loc;

                ELSE
                    IF ( g_m_rule_id = 5 ) THEN --If matrix destination location
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside g_m_rule_id ==5.'
                                                            || 'plogi_loc = '
                                                            || l_plogi_loc
															|| 'logi_loc = '
                                                            || l_logi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                        UPDATE inv
                        SET
                            qoh = qoh + g_qty_rec,
                            qty_planned = decode(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0,
                                                 0),
                            cube = cube + ( ( g_qty_rec - g_qty_exp ) / g_spc ) * g_case_cube,
                            parent_pallet_id = NULL,
                            plogi_loc = l_plogi_loc
                        WHERE
                            logi_loc = l_logi_loc;

                    ELSE
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside g_m_rule_id ==5 ELSE.'
                                                            || ' plogi_loc = '
                                                            || l_plogi_loc
                                                            || ' logi_loc = '
                                                            || l_logi_loc
                                                            || ' dest = '
                                                            || g_dest_loc
                                                            || ' inv_dest = '
                                                            || g_bck_dest_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                            UPDATE inv
                            SET
                                qoh = qoh + g_qty_rec,
                                qty_planned = decode(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0,
                                                     0),
                                cube = cube + ( ( g_qty_rec - g_qty_exp ) / g_spc ) * g_case_cube,
                                parent_pallet_id = NULL
                            WHERE
                                plogi_loc = l_plogi_loc
                                AND logi_loc = l_logi_loc;
                    END IF;	--End g_m_rule_id=5
                END IF;	--End l_logi_loc = 'FFFFFF'

            ELSE -- i_flag !=0
                IF ( g_putaway_client.rlc_flag = 'N' ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'DEBUG stuff.'
                                                        || ' plogi_loc = '
                                                        || l_plogi_loc
                                                        || ' logi_loc = '
                                                        || l_logi_loc
                                                        || ' dest  = '
                                                        || g_dest_loc
                                                        || ' inv_dest = '
                                                        || g_bck_dest_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                    IF ( g_m_rule_id = 5 ) THEN --If matrix destination location
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside g_m_rule_id == 5 BELOW.'
                                                            || ' plogi_loc=  '
                                                            || l_plogi_loc
                                                            || ' logi_loc =  '
                                                            || l_logi_loc
                                                            || ' dest =  '
                                                            || g_dest_loc
                                                            || ' inv_dest = '
                                                            || g_bck_dest_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                        UPDATE inv
                        SET
                            qoh = qoh + g_qty_rec,
                            qty_planned = decode(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0,
                                                 0),
                            inv_date = trunc(sysdate),
                            rec_date = trunc(sysdate),
                            rec_id = g_receive_id,
                            status = g_inv_status,
                            cube = cube + ( ( g_qty_rec - g_qty_exp ) / g_spc ) * g_case_cube,
                            parent_pallet_id = NULL,
                            plogi_loc = l_plogi_loc
                        WHERE
                            logi_loc = l_logi_loc;

                    ELSE --g_m_rule_id != 5
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside g_m_rule_id ==5 BELOW ELSE.'
                                                            || ' plogi_loc '
                                                            || l_plogi_loc
                                                            || ' logi_loc = '
                                                            || l_logi_loc
                                                            || ' dest = '
                                                            || g_dest_loc
                                                            || ' inv_dest = '
                                                            || g_bck_dest_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                        UPDATE inv
                        SET
                            qoh = qoh + g_qty_rec,
                            qty_planned = decode(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0,
                                                 0),
                            inv_date = trunc(sysdate),
                            rec_date = trunc(sysdate),
                            rec_id = g_receive_id,
                            status = g_inv_status,
                            cube = cube + ( ( g_qty_rec - g_qty_exp ) / g_spc ) * g_case_cube,
                            parent_pallet_id = NULL
                        WHERE
                            plogi_loc = l_plogi_loc
                            AND logi_loc = l_logi_loc;

                    END IF; --End g_m_rule_id = 5

                ELSE -- rlc_flag = 'Y' Reserved Locator Company 
                    l_rf_status := update_rlc_inv(l_plogi_loc, l_logi_loc, i_home_slot_flag, 0);
                    IF ( l_rf_status != rf.status_normal ) THEN
                        RETURN l_rf_status;
                    END IF;
                END IF; -- End g_putaway_client.rlc_flag = 'N'
            END IF; -- End i_flag=0
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' update of inventory location failed.'
                                                    || ' plogi_loc = '
                                                    || l_plogi_loc                                                   
                                                    || ' logi_loc = '
                                                    || l_logi_loc
                                                    || ' dest = '
                                                    || g_dest_loc
                                                    || ' inv_dest = '
                                                    || g_bck_dest_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                l_rf_status := rf.status_inv_update_fail;
                RETURN l_rf_status;
        END;

        IF ( i_flag = 1 ) THEN
            IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
                IF ( i_home_slot_flag = 1 ) THEN
                    l_rf_status := data_collect_check(g_rlc_loc, g_rlc_loc, i_home_slot_flag);
                ELSE
                    l_rf_status := data_collect_check(g_rlc_loc, l_logi_loc, i_home_slot_flag);
                END IF;

            ELSE -- g_putaway_client.rlc_flag != 'Y'
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Before data collect', sqlcode, sqlerrm, g_application_func, g_program_name);
                l_rf_status := data_collect_check(l_plogi_loc, l_logi_loc, i_home_slot_flag);
            END IF; --end g_putaway_client.rlc_flag = 'Y'
        END IF; --end i_flag = 1
		pl_text_log.ins_msg_async('INFO', l_func_name, 'End update_inv. rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN l_rf_status;
    END update_inv; -- end Update_inv 
	
  /*******************************<+>******************************************
  **  Function:
  **     Update_CDK_inv
  **
  **  Description:
  **     This function update the  cross dock inventory as part of the putaway
  **     confirmation process.
  **
  **  Parameters:
  **     p_plogi_loc
  **     p_logi_loc
  **     flag
  **     home_slot_flag
  **CALLED BY: mskuputaway
  **  RETURN Values:
  **     NORMAL if update made succesfully
  **     Anything else indicates an issue with the update.
  ***************************************************************************/

    FUNCTION update_cdk_inv (
        i_plogi_loc        IN   inv.plogi_loc%TYPE,
        i_logi_loc         IN   inv.logi_loc%TYPE,
        i_flag             IN   NUMBER,
        i_home_slot_flag   IN   NUMBER
    ) RETURN rf.status IS

        l_func_name   VARCHAR2(50) := 'Update_CDK_inv';
        l_rf_status   rf.status := rf.status_normal;
        l_plogi_loc   inv.plogi_loc%TYPE;
        l_logi_loc    inv.logi_loc%TYPE;
    BEGIN
        IF ( i_flag = 1 ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'flag true', sqlcode, sqlerrm, g_application_func, g_program_name);
        ELSE
            pl_text_log.ins_msg_async('INFO', l_func_name, 'flag FALSE', sqlcode, sqlerrm, g_application_func, g_program_name);
        END IF;
      
       --Initialize Oracle variables from parameters.
     
        l_plogi_loc := i_plogi_loc;
        l_logi_loc := i_logi_loc;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'DEBUG stuff. Table = inv '
                                            || ' plogi_loc = '
                                            || l_plogi_loc                                           
                                            || ' logi_loc = '
                                            || l_logi_loc
                                            || ' dest = '
                                            || g_des_loc
                                            || ' inv_dest = '
                                            || g_bck_dest_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

        UPDATE inv
        SET
            qoh = qoh + g_qty_rec,
            qty_planned = decode(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0,
                                 0),
            inv_date = trunc(sysdate),
            rec_date = trunc(sysdate),
            rec_id = g_receive_id,
            status = g_inv_status,
            cube = cube + ( ( g_qty_rec - g_qty_exp ) / g_spc ) * g_case_cube,
            parent_pallet_id = g_pallet_id_msku
        WHERE
            plogi_loc = l_plogi_loc
            AND logi_loc = l_logi_loc;

        IF ( i_flag = 1 ) THEN
            IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
                IF ( i_home_slot_flag = 1 ) THEN
                    l_rf_status := data_collect_check(g_rlc_loc, g_rlc_loc, i_home_slot_flag);
                ELSE
                    l_rf_status := data_collect_check(g_rlc_loc, l_logi_loc, i_home_slot_flag);
                END IF;

            ELSE -- g_putaway_client.rlc_flag != 'Y' 
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Before data collect', sqlcode, sqlerrm, g_application_func, g_program_name);
                l_rf_status := data_collect_check(g_plogi_loc, l_logi_loc, i_home_slot_flag);
            END IF; -- end g_putaway_client.rlc_flag = 'Y'
        END IF; -- end  i_flag = 1
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending update_cdk_inv . rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, ' update of inventory location failed.'
                                                || ' plogi_loc = '
                                                || l_plogi_loc                                               
                                                || ' logi_loc = '
                                                || l_logi_loc
                                                || ' dest = '
                                                || g_des_loc
                                                || ' inv_dest = '
                                                || g_bck_dest_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

            l_rf_status := rf.status_inv_update_fail;
            RETURN l_rf_status;
			
    END update_cdk_inv;
	
  /*******************************<+>******************************************
  **  Function:
  **     check_new_float
  **
  **  Description:
  **     This function update the  cross dock inventory as part of the putaway
  **     confirmation process.
  **CALLED BY: put_away
  **  RETURN Values:
  **     NORMAL if update made succesfully
  **     Anything else indicates an issue with the update.
  ***************************************************************************/

    FUNCTION check_new_float RETURN rf.status IS
        l_func_name   VARCHAR2(50) := 'Check_new_float';
        l_rf_status     rf.status := rf.status_nor_cluster;
    BEGIN
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting check_new_float.', sqlcode, sqlerrm, g_application_func, g_program_name);
		
        SELECT
            inv.logi_loc
        INTO g_logi_loc 
        FROM
            lzone,
            zone,
            inv
        WHERE
            inv.plogi_loc = g_plogi_loc
            AND inv.logi_loc = g_pallet_id
            AND lzone.logi_loc = inv.plogi_loc
            AND lzone.zone_id = zone.zone_id
            AND zone.zone_type = 'PUT'
            AND zone.rule_id = 1;
		
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending check_new_float . rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
		
        RETURN l_rf_status;
		
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, ' select of floating slot for RETURNs failed. '
                                                || ' plogi_loc = '
                                                || g_plogi_loc                                              
                                                || ' logi_loc = '
                                                || g_logi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

            l_rf_status := rf.status_normal;
            RETURN l_rf_status;
    END check_new_float;
	
/*******************************<+>******************************************
  **  Function:
  **     check_global_rf
  **
  **  Description:
  **     This function get global_rf_conf flag from sys_config
  **CALLED BY: put_away   
  **  RETURN Values:
  **     NORMAL if update made succesfully
  **    If RF is not available then RETURNs NO_RF status
  ***************************************************************************/

    FUNCTION check_global_rf RETURN rf.status IS

        l_func_name   VARCHAR2(50) := 'Check_global_rf';
        l_rf_status     rf.status := rf.status_normal;
        l_dummy       VARCHAR2(1);
    BEGIN
        l_dummy := pl_common.f_get_syspar('GLOBAL_RF_CONF', 'x');
        IF l_dummy != 'Y' THEN			
			   -- If RF is not available then RETURNs NO_RF status
			l_rf_status := rf.status_no_rf;
			
            pl_text_log.ins_msg_async('WARN', l_func_name, ' unable to get global_rf_conf flag from sys_config. rf_status = '||l_rf_status,
				sqlcode, sqlerrm, g_application_func, g_program_name);
            
        END IF;
		
		pl_text_log.ins_msg_async('WARN', l_func_name, 'ending check_global_rf . rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
            
        RETURN l_rf_status;
    END check_global_rf;
	
  /*******************************<+>******************************************
  **  PROCEDURE:
  **     check_rtn_bfr_mfc
  **
  **  Description:
  **     This function gets value for rtn_bfr_mfc flag
  **  CALLED BY: put_away   
  ** 
  ***************************************************************************/

    PROCEDURE check_rtn_bfr_mfc IS
        l_func_name VARCHAR2(50) := 'Check_rtn_bfr_mfc';
    BEGIN
        g_rtn_bfr_mfc := pl_common.f_get_syspar('RTN_BFR_MFC', 'N');
        IF g_rtn_bfr_mfc != 'Y' or g_rtn_bfr_mfc IS NULL THEN
			
			 --  The default value for this is N 
			
            pl_text_log.ins_msg_async('WARN', l_func_name, 'unable to get rtn_bfr_mfc flag.  Using value of N', sqlcode, sqlerrm, g_application_func, g_program_name);
            g_rtn_bfr_mfc := 'N';
			
        END IF;
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending check_rtn_bfr_mfc. rtn_bfr_mfc = '||g_rtn_bfr_mfc, sqlcode, sqlerrm, g_application_func, g_program_name);
            
    END check_rtn_bfr_mfc;
	
  /*******************************<+>******************************************
  **  Function:
  **     check_putawaylist
  ** Called by: put_away
  **  Description:
  **     This function checks PO info from putawaylst
  **     
  **  RETURN Values:
  **     NORMAL if update made succesfully
  **    Anything else indicates an issue with the update.
  ***************************************************************************/

    FUNCTION check_putawaylist RETURN rf.status IS

        l_func_name      VARCHAR2(50) := 'Check_putawaylist';
        l_dummy          VARCHAR2(1);
        l_tmp_erm_type   erm.erm_type%TYPE;
        l_v_prod_id      putawaylst.prod_id%TYPE;
        l_v_cpv          putawaylst.cust_pref_vendor%TYPE;
        l_rf_status        rf.status := rf.status_normal;
    BEGIN
		
		--Get PO info from putawaylst for the pallet ID
        BEGIN
            SELECT
                erm_type,
                prod_id,
                cust_pref_vendor
            INTO
                l_tmp_erm_type,
                l_v_prod_id,
                l_v_cpv
            FROM
                putawaylst,
                erm
            WHERE
                pallet_id = g_pallet_id
                AND rec_id = erm_id;

        EXCEPTION
            WHEN OTHERS THEN				
				--Note that at this point a record not found should not happen.If something wrong or not found. Return invalid pallet ID
                pl_text_log.ins_msg_async('WARN', l_func_name, ' select of erm_type and prod_id failed. pallet_id = ' || g_pallet_id, sqlcode,
                 sqlerrm, g_application_func, g_program_name);
                RETURN rf.status_inv_label;
        END;
		-- RDC Copy prodID, cpv, qty to return buffer 
        g_o_putaway_server.prod_id := rf.nonull(l_v_prod_id);
        g_o_putaway_server.cpv := rf.nonull(l_v_cpv);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'pallet_id = '
                                            || g_pallet_id
                                            || ' erm_type = '
                                            || l_tmp_erm_type
                                            || ' item = '
                                            || l_v_prod_id, sqlcode, sqlerrm, g_application_func, g_program_name);
		--Check if item is in aging
											
        l_dummy := 'N';
        BEGIN
            SELECT
                'Y'
            INTO l_dummy
            FROM
                aging_items
            WHERE
                prod_id = l_v_prod_id
                AND cust_pref_vendor = l_v_cpv;

            g_item_not_aging := 0;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                g_item_not_aging := 1;
				pl_text_log.ins_msg_async('INFO', l_func_name, ' No record found in aging_items for prod_id = ' || l_v_prod_id, sqlcode, sqlerrm,
                 g_application_func, g_program_name);
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' unable to get AGING_ITEMS record. pallet_id = ' || g_pallet_id
						||' prod_id = '
						||l_v_prod_id
						||' cpv = '
						||l_v_cpv, sqlcode, sqlerrm, g_application_func, g_program_name);
                RETURN rf.status_sel_aging_fail;
        END;

        IF ( g_putaway_client.rlc_flag != 'Y' ) THEN
            BEGIN
                IF ( g_m_rule_id = 5 ) THEN --If matrix destination location
                    SELECT
                        nvl(g_dest_loc, p.dest_loc),
                        p.putaway_put,
                        lpad(ltrim(rtrim(to_char(l.put_aisle))), 3, '0'),
                        lpad(ltrim(rtrim(to_char(l.put_slot))), 3, '0'),
                        p.inv_status
                    INTO
                        g_plogi_loc,
                        g_put,
                        g_put_aisle,
                        g_put_slot,
                        g_inv_status
                    FROM
                        loc          l,
                        putawaylst   p
                    WHERE
                        l.logi_loc = g_dest_loc
                        AND p.pallet_id = g_pallet_id;

                ELSE -- end g_m_rule_id != 5
                    IF ( g_strip_loc = 'Y' ) THEN --Check for first five character of location 						
                        SELECT
                            nvl(p.inv_dest_loc, p.dest_loc),
                            p.putaway_put,
                            lpad(ltrim(rtrim(to_char(l.put_aisle))), 3, '0'),
                            lpad(ltrim(rtrim(to_char(l.put_slot))), 3, '0'),
                            p.inv_status
                        INTO
                            g_plogi_loc,
                            g_put,
                            g_put_aisle,
                            g_put_slot,
                            g_inv_status
                        FROM
                            loc          l,
                            putawaylst   p
                        WHERE
                            p.pallet_id = g_pallet_id
                            AND p.dest_loc = l.logi_loc
                            AND substr(l.logi_loc, 1, 5) = substr(g_dest_loc, 1, 5);

                    ELSE --  g_strip_loc != 'Y'
                        IF ( g_strip_loc = 'P' ) THEN
                            SELECT
                                nvl(p.inv_dest_loc, p.dest_loc),
                                p.putaway_put,
                                lpad(ltrim(rtrim(to_char(l.put_aisle))), 3, '0'),
                                lpad(ltrim(rtrim(to_char(l.put_slot))), 3, '0'),
                                p.inv_status
                            INTO
                                g_plogi_loc,
                                g_put,
                                g_put_aisle,
                                g_put_slot,
                                g_inv_status
                            FROM
                                loc          l,
                                putawaylst   p
                            WHERE
                                l.logi_loc = g_dest_loc
                                AND p.pallet_id = g_pallet_id;

                        ELSE -- g_strip_loc != 'P'
                            SELECT
                                nvl(p.inv_dest_loc, p.dest_loc),
                                p.putaway_put,
                                lpad(ltrim(rtrim(to_char(l.put_aisle))), 3, '0'),
                                lpad(ltrim(rtrim(to_char(l.put_slot))), 3, '0'),
                                p.inv_status
                            INTO
                                g_plogi_loc,
                                g_put,
                                g_put_aisle,
                                g_put_slot,
                                g_inv_status
                            FROM
                                loc          l,
                                putawaylst   p
                            WHERE
                                p.dest_loc = l.logi_loc
                                AND p.pallet_id = g_pallet_id
                                AND l.logi_loc = g_dest_loc;

                        END IF; -- End g_strip_loc = 'P'
                    END IF;	--END g_strip_loc = 'Y'
                END IF; --End g_m_rule_id=5

                IF ( g_inv_status = 'HLD' ) THEN --If item is not aged, no putaway.
                    IF ( l_tmp_erm_type = 'CM' ) THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, ' pallet is unavailable. Pallet is on hold = '
                                                            || g_pallet_id
                                                            || ' plogi_loc = '
                                                            || g_plogi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                        RETURN rf.status_pallet_on_hold;
                    END IF;

                END IF;

            EXCEPTION
				--  If pallet_id is not in the putawaylist then RETURNs "NOT_FOUND"
                WHEN OTHERS THEN
                    l_rf_status := rf.status_inv_location;
                    IF g_strip_loc = 'P' THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, ' validation of pallet_id in putawaylst for strip_loc failed. pallet_id = '
                                                            || g_pallet_id
                                                            || ' g_strip_loc = '
                                                            || g_strip_loc
                                                            || ' g_dest_loc = '
                                                            || g_dest_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                    ELSE -- end g_strip_loc != 'P'
                        pl_text_log.ins_msg_async('WARN', l_func_name, ' validation of pallet_id in putawaylst failed. pallet_id = '
                                                            || g_pallet_id
                                                            || ' g_strip_loc = '
                                                            || g_strip_loc
                                                            || ' g_dest_loc = '
                                                            || g_dest_loc, sqlcode, sqlerrm, g_application_func, g_program_name);
                    END IF;

            END;
        ELSIF ( g_putaway_client.rlc_flag = 'Y' ) THEN  -- rls_flag = 'Y'
            g_rlc_loc := g_plogi_loc;
            BEGIN
                SELECT
                    p.dest_loc,
                    p.putaway_put,
                    p.inv_status
                INTO
                    g_plogi_loc,
                    g_put,
                    g_inv_status
                FROM
                    putawaylst p
                WHERE
                    p.pallet_id = g_pallet_id;

			  
			    --If pallet_id is not in the putawaylist then RETURNs "NOT_FOUND"
			  

                IF g_inv_status = 'HLD' THEN --If item is not aged, no putaway.
                    IF g_item_not_aging = 1 OR l_tmp_erm_type = 'CM' THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, ' pallet is unavailable.Pallet is on hold. pallet_id = '
                                                            || g_pallet_id
                                                            || ' plogi_loc = '
                                                            || g_plogi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                        RETURN rf.status_pallet_on_hold;
                    END IF;

                ELSE
                    g_des_loc := g_plogi_loc;
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' validation of pallet_id in putawaylst failed. pallet_id = '
                                                        || g_pallet_id
                                                        || ' plogi_loc = '
                                                        || g_plogi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                    RETURN rf.status_inv_label;
            END;

            BEGIN
                SELECT
                    lpad(ltrim(rtrim(to_char(l.put_aisle))), 3, '0'),
                    lpad(ltrim(rtrim(to_char(l.put_slot))), 3, '0')
                INTO
                    g_put_aisle,
                    g_put_slot
                FROM
                    loc l
                WHERE
                    l.logi_loc = g_rlc_loc;

            EXCEPTION
                WHEN OTHERS THEN
                    l_rf_status := rf.status_inv_location;
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' select of RLC Dest location from RF failed. rlc_loc = ' || g_rlc_loc, sqlcode,
                     sqlerrm, g_application_func, g_program_name);
            END;

        ELSIF ( g_putaway_client.rlc_flag != 'Y' OR g_putaway_client.rlc_flag != 'N' ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, ' Wrong rlc_flag sent by the RF device. plogi_loc = ' || g_plogi_loc,
							sqlcode, sqlerrm, g_application_func, g_program_name);
            l_rf_status := rf.status_update_fail;
			
			  --If already confirmed put, terminate 
			
        ELSIF ( g_put = 'Y' ) THEN --put flag is 'Y'
            pl_text_log.ins_msg_async('WARN', l_func_name, ' putaway task already performed. pallet_id = ' || g_pallet_id,
							sqlcode, sqlerrm, g_application_func, g_program_name);
            l_rf_status := rf.status_put_done;
		
		  --If dest_loc equals '*', terminate.
		
        ELSIF ( g_des_loc = '*         ' ) THEN  -- dest_loc = *
            pl_text_log.ins_msg_async('WARN', l_func_name, ' destination location not yet assigned for pallet. pallet_id = ' || g_pallet_id, sqlcode,
             sqlerrm, g_application_func, g_program_name);
            l_rf_status := rf.status_wrong_put;
        END IF; -- End rlc_flag validation
		
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Ending check_putawaylist. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
            
        RETURN l_rf_status;
    END check_putawaylist; -- end Check_putawaylist 
	
  /*******************************<+>******************************************
  **  Function:
  **     check_home_slot
  **
  **  Description:
  **     This function checks PO info from putawaylst
  **  CALLED BY: put_away 
  **  RETURN Values:
  **     NORMAL if update made succesfully
  **    Anything else indicates an issue with the update.
  ***************************************************************************/

    FUNCTION check_home_slot RETURN rf.status IS

        l_func_name    VARCHAR2(50) := 'Check_home_slot';
        l_rf_status      rf.status := 1;
        l_loc_status   NUMBER := 1;
        l_dummy        VARCHAR2(1);
        l_locstat      loc.status%TYPE;
    BEGIN
        IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
            BEGIN
                SELECT
                    status
                INTO l_locstat
                FROM
                    loc
                WHERE
                    rank = 1
                    AND perm = 'Y'
                    AND ( ( uom = 1
                            AND uom IN (
                        0,
                        1
                    ) )
                          OR ( uom IN (
                        0,
                        2
                    ) ) )
                    AND prod_id = g_prod_id
                    AND cust_pref_vendor = g_cust_pref_vendor
                    AND logi_loc = g_rlc_loc;

                IF ( l_locstat = 'DMG' ) THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'RLC Home LOC unavailable. rlc_loc = '
                                                        || g_rlc_loc
                                                        || ' cust_pref_vendor = '
                                                        || g_cust_pref_vendor
                                                        || ' prod_id = '
                                                        || g_prod_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                    l_loc_status := 0;
                    RETURN rf.status_loc_damaged;
                END IF;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    l_rf_status := rf.status_normal;
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' Table = LOC . RLC location from RF not home slot for item. rlc_loc =  '
                                                        || g_rlc_loc
                                                        || ' cust_pref_vendor = '
                                                        || g_cust_pref_vendor
                                                        || ' prod_id ='
                                                        || g_prod_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' Table = LOC . select of RLC location as home slot for item failed. rlc_loc = '
                                                        || g_rlc_loc
                                                        || ' cust_pref_vendor = '
                                                        || g_cust_pref_vendor
                                                        || ' prod_id = '
                                                        || g_prod_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                    l_rf_status := rf.status_normal;
            END;
        ELSE -- rlc_flag != Y
		  
		  --Not a reserve locator company.
		  
            BEGIN
                SELECT
                    'x'
                INTO l_dummy
                FROM
                    loc
                WHERE
                    uom IN (
                        0,
                        1,
                        2
                    )
                    AND rank = 1
                    AND perm = 'Y'
                    AND prod_id = g_prod_id
                    AND cust_pref_vendor = g_cust_pref_vendor
                    AND logi_loc = g_plogi_loc;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = LOC. location from RF not home slot for item. plogi_loc = '
                                                        || g_plogi_loc
                                                        || ' cust_pref_vendor = '
                                                        || g_cust_pref_vendor
                                                        || ' prod_id = '
                                                        || g_prod_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                    l_rf_status := rf.status_normal;
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = LOC . location from RF as home slot for item failed. plogi_loc = '
                                                        || g_plogi_loc
                                                        || ' cust_pref_vendor = '
                                                        || g_cust_pref_vendor
                                                        || ' prod_id = '
                                                        || g_prod_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                    l_rf_status := rf.status_normal;
            END;
        END IF; --End g_putaway_client.rlc_flag = 'Y'
		
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Ending check_home_slot. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
		
        RETURN l_rf_status;
		
    END check_home_slot; -- end Check_home_slot 
	
  /*******************************<+>******************************************
  **  Function:
  **     check_put_path
  ** Called by:put_away
  **  Description:
  **     This function checks if destination location for pallet matches location from RF
  **     
  **  RETURN Values:
  **     NORMAL if update made succesfully
  **    Anything else indicates an issue with the update.
  ***************************************************************************/

    FUNCTION check_put_path RETURN rf.status IS

        l_func_name           VARCHAR2(50) := 'Check_put_path';
        l_user_put_path_val   VARCHAR2(20);			/* Put_path value for the location scanned
														by the RF gun.  It will only include
														the put aisle and the put slot. */
        l_rf_status             rf.status := rf.status_normal;
    BEGIN
        l_user_put_path_val := g_put_aisle || g_put_slot;
        IF ( g_strip_loc = 'P' ) THEN
			/*
			**  If put_aisle and put_loc of the two locations don't match,
			**  terminate.
			*/
            IF ( g_real_put_path_val != l_user_put_path_val ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'destination location for pallet does not match location from RF. real_put_path_val = '
                                                    || g_real_put_path_val
                                                    || ' user_put_path_val = '
                                                    || l_user_put_path_val, sqlcode, sqlerrm, g_application_func, g_program_name);

                l_rf_status := rf.status_wrong_put;
            END IF;

        END IF;
		
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Ending check_put_path. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
		
        RETURN l_rf_status;
    END check_put_path; -- end Check_put_path 
	
  /*******************************<+>******************************************
  **  PROCEDURE:
  **     get_rf_info
  **
  **  Description:
  **     The host variable g_dest_loc is defined to handle the 'P' value for
  **	 strip_loc. Although there are only a few companies using this setup, 
  **	but it was necessary to define this variable to handle putaway when
  **    the forklift operator did not scan a right location, Input from 
  **    Kansas City. When strip_loc is set to 'P', RF devices do not perform
  **	any validation. The validation is done on the host in putaway program
  **  
  ** CALLED BY: put_away
  **  
  ***************************************************************************/

    PROCEDURE get_rf_info IS
        l_func_name           VARCHAR2(50) := 'Get_RF_info';
        l_front_or_back_loc   VARCHAR2(11);
        l_rc                  NUMBER;
    BEGIN
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Starting get_rf_info.', sqlcode, sqlerrm, g_application_func, g_program_name);
        g_pallet_id := g_putaway_client.pallet_id;

		  /*
			 In putaway funtion from the RF's, for Baltimore the back location
			 is scanned from the RF's
		  */
        g_plogi_loc := g_putaway_client.plogi_loc;

		  /*
			The host variable g_dest_loc is defined to handle the 'P' value for
			strip_loc. Although there are only a few companies using this setup, 
			but it was necessary to define this variable to handle putaway when
			the forklift operator did not scan a right location, Input from 
			Kansas City. When strip_loc is set to 'P', RF devices do not perform
			any validation. The validation is done on the host in putaway program.
		  */
        g_dest_loc := g_putaway_client.plogi_loc;
       

		  /* This conversion is done to cover the back location for Baltimore. It's  
			 done because plogi_loc has been used as a global variable.  Option 1
			 will ask for the front location
		  */
		  /*
		  ** If a location is found then Get_front_or_back_loc will null terminate
		  ** it thus front_or_back_loc will be null terminated.
		  **
		  ** The '1' in the parameter list signifies to look up the front location
		  ** so plogi_loc will be interpreted as a back location.
		  */
        get_front_or_back_loc(g_plogi_loc, l_front_or_back_loc, 1, PUTAWAY, l_rc);
        IF ( l_rc = 0 ) THEN
            g_plogi_loc := l_front_or_back_loc;
        END IF;
        g_real_put_path_val := g_putaway_client.real_put_path_val;
        g_door_no := g_putaway_client.door_no;
		
    END get_rf_info; --end Get_RF_info
	
  /*******************************<+>******************************************
  **  FUNCTION:
  **     get_putaway_info
  **
  **  Description:
  **     This function does selection of putaway task information
  **   CALLED BY: put_away  
  **  RETURN value:
  **	l_rf_status code
  ***************************************************************************/

    FUNCTION get_putaway_info RETURN rf.status IS

        l_func_name    VARCHAR2(50) := 'Get_putaway_info';
        l_rf_status      rf.status := rf.status_normal;
        l_weight_ind   putawaylst.catch_wt%TYPE;
    BEGIN
		/*
		  **   The order_id for RETURNs is stored in the lot_id of the putawaylst
		  **   record by receive_ret.
		  **   The erm_line_id is stored in seq_no by receive_ret.  This is to be
		  **   placed into the order_line_id of the PUT transaction.
		  */
        SELECT
            p.rec_id,
            p.dest_loc,
            p.qty_received,
            p.qty_expected,
            p.exp_date_trk,
            p.date_code,
            p.lot_trk,
            p.temp_trk,
            p.catch_wt,
            p.inv_status,
            to_char(p.exp_date, 'DD-MON-YYYY'),
            to_char(p.mfg_date, 'DD-MON-YYYY'),
            p.temp,
            p.weight,
            p.lot_id,
            p.mispick,
            substr(p.lot_id, 1, 9),
            p.seq_no,
            p.prod_id,
            p.cust_pref_vendor,
            p.uom,
            p.orig_invoice,
            p.dest_loc,
            p.status,
            z.rule_id
        INTO
            g_receive_id,
            g_dest_loc,
            g_qty_rec,
            g_qty_exp,
            g_exp_ind,
            g_mfg_ind,
            g_lot_ind,
            g_temp_ind,
            l_weight_ind,
            g_inv_status,
            g_vc_exp_date,
            g_mfg_date,
            g_temp,
            g_weight,
            g_lot_id,
            g_mispick,
            g_order_id,
            g_order_line_id,
            g_prod_id,
            g_cust_pref_vendor,
            g_uom,
            g_orig_invoice,
            g_bck_dest_loc,
            g_putawaylst_status,
            g_rule_id
        FROM
            zone         z,
            lzone        lz,
            putawaylst   p
        WHERE
            z.zone_type = 'PUT'
            AND z.zone_id = lz.zone_id
            AND lz.logi_loc = p.dest_loc
            AND p.pallet_id = g_pallet_id;
			
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Ending check_put_path. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
		
        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            l_rf_status := rf.status_sel_putawaylst_fail;
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = putawaylst. selection of putaway task information failed.  
										LP not in putawaylst or dest loc has no PUT zone. pallet_id = '||g_pallet_id, 
										sqlcode, sqlerrm, g_application_func, g_program_name);
            RETURN l_rf_status;
			
    END get_putaway_info;
	
	/*******************************<+>******************************************
  **  FUNCTION:
  **     get_product_info
  ** CALLED BY : put_away
  **  Description:
  **     This function does selection of product support information for putaway task
  **     
  **  RETURN value:
  **	l_rf_status code
  ***************************************************************************/

    FUNCTION get_product_info RETURN rf.status IS

        l_func_name   VARCHAR2(50) := 'Get_product_info';
        l_rf_status     rf.status := rf.status_normal;
        l_abc         pm.abc%TYPE;
    BEGIN
    
        IF ( g_prod_id = 'MULTI' ) THEN 

                g_case_cube := 1.0;
                g_spc := 1;
                l_abc := 'A';
                g_sysco_shelf_life := 0;
                g_cust_shelf_life := 0;
                g_mfr_shelf_life := 0;
                g_max_qty := 1;

                l_rf_status := rf.status_normal;

        ELSE
            SELECT
                nvl(p.case_cube, 1.0),
                nvl(p.spc, 1),
                nvl(p.abc, 'A'),
                nvl(p.sysco_shelf_life, 0),
                nvl(p.cust_shelf_life, 0),
                nvl(p.mfr_shelf_life, 0),
                p.max_qty
            INTO
                g_case_cube,
                g_spc,
                l_abc,
                g_sysco_shelf_life,
                g_cust_shelf_life,
                g_mfr_shelf_life,
                g_max_qty
            FROM
                pm p
            WHERE
                prod_id = g_prod_id
                AND cust_pref_vendor = g_cust_pref_vendor;

            IF ( l_rf_status = rf.status_normal ) THEN
                l_rf_status := calc_exp_dt_for_shlf_lfe_item;
            END IF;
        END IF;

	pl_text_log.ins_msg_async('INFO', l_func_name, ' Ending get_product_info. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);

        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            l_rf_status := rf.status_inv_prodid;
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = pm. selection of product support information for putaway task failed. cust_pref_vendor = '
                                                || g_cust_pref_vendor
                                                || ' prod_id = '
                                                || g_prod_id, sqlcode, sqlerrm, g_application_func, g_program_name);

            RETURN l_rf_status;
			
    END get_product_info;
	
	/*******************************<+>******************************************
  **  FUNCTION:
  **     get_product_info
  **
  **  Description:
  **     This function does deletion of putaway task for closed PO 
  **   CALLED BY: put_away  
  **  RETURN value:
  **	l_rf_status code
  ***************************************************************************/

    FUNCTION delete_putaway_task (
        i_finish_good_po_flag IN VARCHAR2
    ) RETURN rf.status IS
        l_func_name   VARCHAR2(50) := 'Delete_putaway_task';
        l_rf_status     rf.status := rf.status_normal;
    BEGIN
      -- If the it's a finished good po, then do not delete. This flag is initialized to 'N' and could be set to 'Y' in Putaway()
        IF ( i_finish_good_po_flag = 'Y' ) THEN
            RETURN l_rf_status;
        END IF;
        DELETE FROM putawaylst
        WHERE
            pallet_id = g_pallet_id;
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Ending delete_putaway_task. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = putawaylst. deletion of putaway task for closed PO failed. pallet_id = ' || g_pallet_id, 
			sqlcode, sqlerrm, g_application_func, g_program_name);            
            l_rf_status := rf.status_del_putawylst_fail;
            RETURN l_rf_status;
			
    END delete_putaway_task; -- end Delete_putaway_task 

/*******************************<+>******************************************
  **  FUNCTION:
  **     confirm_putaway_task
  **
  **  Description:
  **     This function validates and confirms putaway task
  **   CALLED BY: put_away 
  **  RETURN value:
  **	l_rf_status code
 ***************************************************************************/

    FUNCTION confirm_putaway_task RETURN rf.status IS
        l_func_name   VARCHAR2(50) := 'Confirm_putaway_task';
        l_rf_status     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Begin Confirm_putaway_task', sqlcode, sqlerrm, g_application_func, g_program_name);
        SELECT
            pallet_id
        INTO g_pallet_id
        FROM
            putawaylst
        WHERE
            pallet_id = g_pallet_id
        FOR UPDATE NOWAIT;

        BEGIN
            IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
                UPDATE putawaylst
                SET
                    putaway_put = 'Y',
                    dest_loc = g_rlc_loc
                WHERE
                    pallet_id = g_pallet_id;

            ELSE --rlc_flag !=Y
                UPDATE putawaylst
                SET
                    putaway_put = 'Y'
                WHERE
                    pallet_id = g_pallet_id;

                pl_text_log.ins_msg_async('INFO', l_func_name, 'after update of putaway_put. pallet_id = ' || g_pallet_id,
								sqlcode, sqlerrm, g_application_func, g_program_name);
				
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'update of putaway_put flag failed. pallet_id = ' || g_pallet_id, sqlcode,
				sqlerrm, g_application_func, g_program_name);
                
                l_rf_status := rf.status_putawaylst_update_fail;
        END;

        IF ( g_erm_status = 'OPN' ) THEN
			  
			  --PO is OPEN (for both regular PO and RETURN PO)
			  
            IF ( g_erm_type = 'CM' ) THEN
				
				--RETURNs PO
				
                pl_text_log.ins_msg_async('INFO', l_func_name, 'DEBUG stuff2 in erm_type= CM. g_vc_exp_date = '
                                                    || g_vc_exp_date
                                                    || ' ,g_rule_id =  '
                                                    || g_rule_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                IF ( g_rule_id = 3 ) THEN
					/*
					** RETURN to the miniloader.  Use 01-JAN-2001 for the 
					** expiration so the inventory will be the first to go out.
					**
					**The expiration may already be set to
					** '01-JAN-2001' by pl_rtn_dtls.p_create_putaway_n_inv().
					** To error on the save side it will be set again.
					**
					*/
                    g_vc_exp_date := '01-JAN-2001';
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'RETURN to the miniloader.  Expiration date changed to '
                                                        || g_vc_exp_date
                                                        || ' g_rule_id = '
                                                        || g_rule_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                END IF;

            END IF; -- END g_erm_type = 'CM'

			  /*
			  ** 
			  ** Call Process_pallet_and_send_ER() only if the rule id of the
			  ** destination slot is 3.
			  */

            IF ( g_rule_id = 3 ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'PUT zone rule id of the dest loc is 3 so call Process_pallet_and_send_ER',
								sqlcode, sqlerrm, g_application_func, g_program_name);                
                l_rf_status := process_pallet_and_send_er;
                               
            ELSE -- g_rule_id!=3
                pl_text_log.ins_msg_async('INFO', l_func_name, 'PUT zone rule id of the dest loc is '
                                                    || g_rule_id
                                                    || ' and not 3 so do not call Process_pallet_and_send_ER',
													sqlcode, sqlerrm, g_application_func, g_program_name);
            END IF;
			pl_text_log.ins_msg_async('INFO', l_func_name, 'After Process_pallet_and_send_ER g_vc_exp_date = ' || g_vc_exp_date,
							sqlcode, sqlerrm, g_application_func, g_program_name);
        END IF; -- End g_erm_status = 'OPN'

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending Confirm_putaway_task. rf_status = '|| l_rf_status,
						sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'update of putaway_put flag failed. pallet_id = ' || g_pallet_id
							, sqlcode, sqlerrm, g_application_func, g_program_name);
            l_rf_status := rf.status_putawaylst_update_fail;
            RETURN l_rf_status;
			
    END confirm_putaway_task; -- end Confirm_putaway_task 
	
  /*******************************<+>******************************************
  **
  **  Function
  **    Process_pallet_and_send_ER
  **
  **  CALLED BY: confirm_putaway_task
  **     
  **    
  **  Description
  **    This function processes each pallet in the putawaylst and sends the 
  **    expected recipt message to Miniloader.
  *********************************<->******************************************/

    FUNCTION process_pallet_and_send_er RETURN rf.status IS

        l_rf_status        rf.status := rf.status_normal;
        l_miniload_ind   VARCHAR2(1) := 'N';
        l_er_info        pl_miniload_processing.t_exp_receipt_info default NULL;
        l_func_name      VARCHAR2(50) := 'process_pallet_and_send_er';
        lv_msg_text      VARCHAR2(256);
        ln_status        NUMBER(1);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Begin Process_pallet_and_send_ER g_exprec_sent. g_exprec_sent = '
                                            || g_exprec_sent
                                            || 'Loc = '
                                            || g_des_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

        l_er_info.v_expected_receipt_id := g_pallet_id;
        l_er_info.v_prod_id := g_prod_id;
        l_er_info.v_cust_pref_vendor := g_cust_pref_vendor;
        l_er_info.n_uom := g_uom;
        l_er_info.n_qty_expected := g_qty_rec;
        l_er_info.v_inv_date := g_vc_exp_date;
        l_miniload_ind := pl_miniload_processing.f_check_miniload_loc(g_dest_loc, g_prod_id, g_cust_pref_vendor, g_uom);
        IF l_miniload_ind = 'Y' THEN
            pl_miniload_processing.p_send_exp_receipt(l_er_info, ln_status, 'N');
            IF ln_status = 0 THEN
                l_rf_status := 0;
                lv_msg_text := 'Expected receipt message for Pallet'
                               || g_pallet_id
                               || ' sent';
                pl_text_log.ins_msg_async('INFO', l_func_name, lv_msg_text, NULL, NULL, g_application_func, g_program_name);
            ELSE
                l_rf_status := rf.status_er_send_failed; 
                lv_msg_text := 'Error Sending Expected receipt message for Pallet' || g_pallet_id;
                pl_text_log.ins_msg_async('WARN', l_func_name, lv_msg_text, NULL, NULL, g_application_func, g_program_name);
            END IF;

        ELSIF l_miniload_ind = 'I' THEN
            l_rf_status := rf.status_invalid_induction_locn; 
            lv_msg_text := 'Invalid Induction Location :' || g_des_loc;
            pl_text_log.ins_msg_async('WARN', l_func_name, lv_msg_text, NULL, NULL, g_application_func, g_program_name);
        ELSIF l_miniload_ind = 'N' THEN
            l_rf_status := 0;
        END IF;

        IF ( ( l_rf_status = rf.status_normal ) AND ( l_miniload_ind = 'Y' ) ) THEN
            g_exprec_sent := 'Y';
            pl_text_log.ins_msg_async('INFO', l_func_name, 'End Process_pallet_and_send_ER. g_exprec_sent = '
                                                || g_exprec_sent
                                                || ' status = '
                                                || l_rf_status
                                                || ' ind = '
                                                || l_miniload_ind, sqlcode, sqlerrm, g_application_func, g_program_name);

        END IF;

        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            l_rf_status := rf.status_er_send_failed;
            lv_msg_text := 'Error Sending Expected receipt message for Pallet' || g_pallet_id;
            pl_text_log.ins_msg_async('FATAL', l_func_name, lv_msg_text, NULL, NULL, g_application_func, g_program_name);
            RETURN l_rf_status;
			
    END process_pallet_and_send_er; -- end Process_pallet_and_send_ER 
	
  /*******************************<+>******************************************
  **
  **  Function
  **    delete_inv
  **
  **   CALLED BY: put_away
  **  Description
  **    This function deletes reserve location
  *********************************<->******************************************/

    FUNCTION delete_inv RETURN rf.status IS
        l_func_name   VARCHAR2(50) := 'Delete_inv';
        l_rf_status     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Begin delete_inv. pallet_id = ' || g_pallet_id, sqlcode, sqlerrm, g_application_func, g_program_name);
        DELETE FROM inv
        WHERE
            logi_loc = g_pallet_id
            AND plogi_loc = g_plogi_loc;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'End delete_inv. rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Table= INV.unable to delete reserve location. pallet_id = ' || g_pallet_id,
							sqlcode, sqlerrm, g_application_func, g_program_name);
            l_rf_status := rf.status_del_inv_fail;
            RETURN l_rf_status;
			
    END delete_inv; -- end Delete_inv 
	
  /*******************************<+>******************************************
  **
  **  Function
  **    update_inv_zero_rcv
  **
  **  CALLED BY: put_away
  **
  **  Description
  **    This function update home location with qty planned.
  *********************************<->******************************************/

    FUNCTION update_inv_zero_rcv (
        i_flag IN NUMBER
    ) RETURN rf.status IS
        l_func_name   VARCHAR2(50) := 'Update_inv_zero_rcv';
        l_rf_status     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Begin update_inv_zero_rcv. ', sqlcode, sqlerrm, g_application_func, g_program_name);
        IF ( i_flag = 1 ) THEN
            IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
                UPDATE inv
                SET
                    qty_planned = decode(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0,
                                         0),
                    cube = cube - ( g_qty_exp / g_spc ) * g_case_cube,
                    parent_pallet_id = NULL
                WHERE
                    plogi_loc = g_rlc_loc
                    AND logi_loc = g_plogi_loc;

            ELSE -- rlc_flag!='Y'
                UPDATE inv
                SET
                    qty_planned = decode(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0,
                                         0),
                    cube = cube - ( g_qty_exp / g_spc ) * g_case_cube,
                    parent_pallet_id = NULL
                WHERE
                    plogi_loc = g_plogi_loc
                    AND logi_loc = g_logi_loc;

            END IF;

        ELSE -- i_flag!=1
            IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
                UPDATE inv
                SET
                    qty_planned = decode(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0,
                                         0),
                    parent_pallet_id = NULL
                WHERE
                    plogi_loc = g_rlc_loc
                    AND logi_loc = g_logi_loc;

            ELSE -- rlc_flag !='Y'
                UPDATE inv
                SET
                    qty_planned = decode(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0,
                                         0),
                    parent_pallet_id = NULL
                WHERE
                    plogi_loc = g_plogi_loc
                    AND logi_loc = g_logi_loc;

            END IF;
        END IF; -- End i_flag = 1

        pl_text_log.ins_msg_async('INFO', l_func_name, ' End update_inv_zero_rcv. rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = inv. unable to update home location. pallet_id = ' || g_pallet_id,
						sqlcode, sqlerrm, g_application_func, g_program_name);
            l_rf_status := rf.status_inv_update_fail;
            RETURN l_rf_status;
    END update_inv_zero_rcv; -- end Update_inv_zero_rcv 
	
  /*******************************<+>******************************************
  **
  **  Function
  **    write_transaction
  ** IN Parameter:
  **		i_trans_type
  **  CALLED BY: put_away
  **  Description
  **    This function creates STA for RF transaction
  *********************************<->******************************************/

    FUNCTION write_transaction (
        i_trans_type IN trans.trans_type%TYPE
    ) RETURN rf.status IS

        l_func_name            VARCHAR2(50) := 'Write_transaction';
        l_rf_status              rf.status := rf.status_normal;
        i                      NUMBER;
        l_src_loc              VARCHAR2(11); -- Source loc for the trans PUT record. 
        l_src_loc_ind          NUMBER;
        l_trans_type           trans.trans_type%TYPE;
        l_trans_date           VARCHAR2(12);
        l_trans_date_ind       NUMBER := 0;
        l_tmp_inv_status       inv.status%TYPE;
        l_tmp_lot_id           putawaylst.lot_id%TYPE;
        l_tmp_pallet_id        putawaylst.pallet_id%TYPE;
        l_tmp_prod_id          putawaylst.prod_id%TYPE;
        l_tmp_cpv              putawaylst.cust_pref_vendor%TYPE;
        l_parent_pallet_id     putawaylst.parent_pallet_id%TYPE;
        l_parent_pallet_ind    NUMBER;
        l_cmt                  VARCHAR2(75);
        l_vc_pallet_batch_no   putawaylst.pallet_batch_no%TYPE;
        l_scan_method          VARCHAR2(1);
        l_dummy                VARCHAR2(1);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting write_transaction. trans_type = '||i_trans_type, sqlcode, sqlerrm, g_application_func, g_program_name);
           pl_log.ins_msg('WARN', l_func_name, 'Inside Write/trans. ttype =  '
                                                        || l_trans_type
                                                        || ' expdate =  '
                                                        || g_vc_exp_date
                                                        || ' mfgdate =  '
                                                        || g_mfg_date
                                                        || ' g_pallet_id = '
                                                        || g_pallet_id
                                                        || ' upload_time = '
                                                        || l_trans_date, sqlcode, sqlerrm, g_application_func, g_program_name);

       -- Initialize Oracle variables from parameters.
      
        l_trans_type := i_trans_type;
        l_scan_method := g_putaway_client.scan_method;
        l_src_loc_ind := -1;
        BEGIN
            IF ( g_erm_type = 'CM' ) THEN
                l_tmp_pallet_id := g_pallet_id;
                l_tmp_prod_id := g_prod_id;
                l_tmp_cpv := g_cust_pref_vendor;
                l_tmp_lot_id := g_lot_id; 

         
            /*
            ** get rec_type and reason_code for RETURNs
            **Get rec_type and reason_code for RETURNs using NVL
            */
                SELECT
                    r.rec_type,
                    r.return_reason_cd
                INTO
                    g_rec_type,
                    g_reason_code
                FROM
                    returns r
                WHERE
                    r.manifest_no = to_number(substr(g_receive_id, 2))
                    AND nvl(decode(instr(r.obligation_no, 'L'), 0, r.obligation_no, substr(r.obligation_no, 1, instr(r.obligation_no
                    , 'L') - 1)), ' ') = nvl(l_tmp_lot_id, ' ')
                    AND r.erm_line_id = g_order_line_id
                    AND nvl(r.returned_prod_id, r.prod_id) = l_tmp_prod_id
                    AND r.cust_pref_vendor = l_tmp_cpv;

            ELSE --g_erm_type !='CM'
                g_rec_type := ' ';
                g_reason_code := '   ';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = returns. unable to select rec_type and reason code. order_line_id = '
                                                    || g_order_line_id
                                                    || ' tmp_cpv = '
                                                    || l_tmp_cpv
                                                    || ' tmp_prod_id = '
                                                    || l_tmp_prod_id
                                                    || ' receive_id = '
                                                    || g_receive_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                RETURN rf.status_sel_putawaylst_fail;
        END;

        -- OPCOF-3577 Added PUX so labor batch is retrieved. 
        IF ( l_trans_type in ('PUT', 'PUX') ) THEN 
            BEGIN
                l_trans_date := '01-JAN-1980';

				  /*
				  ** Get the source location for the TRANS PUT record then set the
				  ** indicator variable.  Get_source_location will set the source
				  ** location to an empty string if unable to get the source location
				  ** either because of no data or an oracle error.
				  ** The RETURN status is ignored.
				  */
                l_rf_status := get_source_location(g_receive_id, g_pallet_id, l_src_loc);
                IF ( length(l_src_loc) = 0 ) THEN
                    l_src_loc_ind := -1;  --No source location. 
                ELSE
                    l_src_loc_ind := 0;  -- Found the source location. 
                    SELECT
                        parent_pallet_id,
                        pallet_batch_no
                    INTO
                        l_parent_pallet_id,
                        l_vc_pallet_batch_no
                    FROM
                        putawaylst
                    WHERE
                        pallet_id = g_pallet_id;

                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' Table = putawaylst. Select of parent_pallet_id failed. pallet_id = ' || g_pallet_id, sqlcode,
                     sqlerrm, g_application_func, g_program_name);
                    l_rf_status := rf.status_sel_putawaylst_fail;
            END;
        ELSE -- l_trans_type != 'PUT'
            l_trans_date_ind := -1;
        END IF; --End l_trans_type = 'PUT'

		/*
		For aging item of a regular PO, the status is HLD. 
		**   The pallet can still be putawayed but the APCOM queue cannot send
		**   HLD status. Change the status temporarily to AVL and send a STA
		**   transaction immediately.
		*/

        IF ( ( g_item_not_aging = 0 ) AND ( g_erm_type != 'CM' ) ) THEN
            l_tmp_inv_status := 'AVL';
        ELSE
            l_tmp_inv_status := g_inv_status;
        END IF;

		/*
		**  Check to see if there is already a 'PUT' transaction in the TRANS
		**  table. If so, RETURN error code 000094 to indicate putaway already done.
		**   Added MIS
		**
		**   Putaway from PIT zone. Since a PUT transaction is already created during
		**  auto open/confirm, do not check trans for an already existing PUT. We will need to create
		**  a PIT transaction for inventory tracking purposes.
		*/

        BEGIN
            IF ( i_trans_type = 'PIT' ) THEN
                SELECT
                    'x'
                INTO l_dummy
                FROM
                    trans
                WHERE
                    rec_id = g_receive_id
                    AND pallet_id = g_pallet_id
                    AND trans_type IN (
                        'PIT'
                    );

            ELSE -- i_trans_type != 'PIT'
                SELECT
                    'x'
                INTO l_dummy
                FROM
                    trans
                WHERE
                    rec_id = g_receive_id
                    AND pallet_id = g_pallet_id
                    AND trans_type IN (
                        'PUT',
                        'MIS', 
                        'PUX' -- 2021.08.11 (kchi7065) 3577
                    );

                pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = Trans. Multiple PUT transactions detected by putaway. pallet_id = ' 
								|| g_pallet_id, sqlcode, sqlerrm, g_application_func, g_program_name);                
                l_rf_status := rf.status_put_done;
                RETURN l_rf_status;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Inside Write/trans. ttype =  '
                                                        || l_trans_type
                                                        || ' expdate =  '
                                                        || g_vc_exp_date
                                                        || ' mfgdate =  '
                                                        || g_mfg_date
                                                        || ' upload_time = '
                                                        || l_trans_date, sqlcode, sqlerrm, g_application_func, g_program_name);
                END IF;

                l_rf_status := insert_door_tran;
                IF ( l_rf_status = 1 ) THEN
                    RETURN l_rf_status;
                END IF;
				
                IF ( g_erm_type = 'TR' ) THEN
                    l_trans_type := 'TRP';
                    SELECT
                        to_warehouse_id
                    INTO g_warehouse_id
                    FROM
                        erm
                    WHERE
                        erm_id = g_receive_id;

                END IF;

				/* For OS and D change on RDC
			  ** If putawayls.status = 'DMG', create 'PUT' transaction with status
			  ** as 'DMG'(instead of 'AVL' or 'HLD'). Create 'STA' transaction with
			  ** status as 'DMG' and won't send to SUS
			  */

                IF ( g_putawaylst_status = 'DMG' ) THEN
                    l_tmp_inv_status := g_putawaylst_status;
                ELSIF ( ( g_ei_pallet = 'Y' ) AND ( g_putawaylst_status != 'CDK' ) ) THEN
                    l_tmp_inv_status := 'AVL';
                END IF;

			/*
			** For pickup RETURN putaway task, the lot_id and the order_id
			** need to be switched because the lot_id from putawaylst has the
			** pickup invoice# and orig_invoice from putawaylst has the original
			** invoice#
			*/
                    BEGIN
                        INSERT INTO trans (
                            trans_id,
                            trans_type,
                            prod_id,
                            cust_pref_vendor,
                            order_type,
                            uom,
                            rec_id,
                            lot_id,
                            exp_date,
                            weight,
                            mfg_date,
                            qty_expected,
                            temp,
                            qty,
                            pallet_id,
                            src_loc,
                            dest_loc,
                            trans_date,
                            user_id,
                            order_id,
                            order_line_id,
                            upload_time,
                            batch_no,
                            reason_code,
                            new_status,
                            cmt,
                            warehouse_id,
                            bck_dest_loc,
                            parent_pallet_id,
                            labor_batch_no,
                            scan_method2
                        ) VALUES (
                            trans_id_seq.NEXTVAL,
                            l_trans_type,
                            g_prod_id,
                            g_cust_pref_vendor,
                            g_rec_type,
                            g_uom,
                            g_receive_id,
                            decode(g_rec_type, 'P', g_orig_invoice, g_lot_id),
                            to_date(g_vc_exp_date, 'FXDD-MON-YYYY'),
                            g_weight,
                            to_date(g_mfg_date, 'FXDD-MON-YYYY'),
                            g_qty_exp,
                            g_temp,
                            g_qty_rec,
                            g_pallet_id,
                            l_src_loc,
                            g_plogi_loc,
                            sysdate,
                            user,
                            decode(g_rec_type, 'D', g_orig_invoice, g_lot_id),
                            g_order_line_id,
                            to_date(l_trans_date, 'FXDD-MON-YYYY'),
                            99,
                            g_reason_code,
                            l_tmp_inv_status,
                            g_pallet_id,
                            g_warehouse_id,
                            g_bck_dest_loc,
                            l_parent_pallet_id,
                            l_vc_pallet_batch_no,
                            l_scan_method
                        );

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, ' unable to create '
                                                                || l_trans_type
                                                                || ' for RF transaction.pallet_id =  '
                                                                || g_pallet_id
                                                                || ' scan_method = '
                                                                || l_scan_method
                                                                || ' plogi_loc = '
                                                                || g_plogi_loc
                                                                || ' bck_dest_loc = '
                                                                || g_bck_dest_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                            l_rf_status := rf.status_trans_insert_failed;
                            RETURN l_rf_status;
                    END;

                

                update_manifest_dtls_status;
                IF ( l_rf_status = rf.status_normal ) THEN
					/*  For OS and D change on RDC 					
						"STA" transaction should not get created 
						for pallets in AVL status. Fixed this defect.*/
                    IF ( ( g_item_not_aging = 0 ) AND ( g_inv_status = 'HLD' ) AND ( g_erm_type != 'CM' ) ) THEN
                        l_cmt := 'Change SUS to HLD status for aging item';
                    ELSIF ( g_putawaylst_status = 'DMG' ) AND ( g_erm_type != 'CM' ) THEN
                        l_cmt := 'Change SWMS to HLD status for damaged item';
                        g_inv_status := 'OSD';
                    END IF;

                    BEGIN
						--Added STA transaction for aging item
                        IF ( ( g_item_not_aging = 0 ) AND /* aging item in regular PO */ ( g_inv_status = 'HLD' ) AND ( g_erm_type != 'CM' ) OR ( g_putawaylst_status = 'DMG' ) AND ( g_erm_type != 'CM' ) ) THEN
                            INSERT INTO trans (
                                trans_id,
                                trans_type,
                                trans_date,
                                user_id,
                                prod_id,
                                cust_pref_vendor,
                                rec_id,
                                reason_code,
                                src_loc,
                                batch_no,
                                pallet_id,
                                old_status,
                                new_status,
                                qty,
                                uom,
                                cmt,
                                upload_time
                            ) VALUES (
                                trans_id_seq.NEXTVAL,
                                'STA',
                                sysdate,
                                user,
                                g_prod_id,
                                g_cust_pref_vendor,
                                g_receive_id,
                                'CC',
                                g_des_loc,
                                99,
                                g_pallet_id,
                                l_tmp_inv_status,
                                g_inv_status,
                                g_qty_rec,
                                g_uom,
                                'Change SUS to HLD status for aging item',
                                to_date(l_trans_date, 'FXDD-MON-YYYY')
                            );

                        END IF; 

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, ' unable to create , STA,  for RF transaction. pallet_id = '
							|| g_pallet_id, sqlcode, sqlerrm, g_application_func, g_program_name);                            
                            l_rf_status := rf.status_trans_insert_failed;
                    END;

                END IF; --  End l_rf_status = rf.status_normal

                pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending write_transaction. rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        END; -- End i_trans_type = 'PIT' 

        RETURN l_rf_status;
		
    END write_transaction;
	
	
  /*******************************<+>******************************************
  **
  **  Function
  **    update_put_trans
  ** CALLED BY: put_away
  **  Description
  **    This function update user_id for PUT transaction
  *********************************<->******************************************/

    FUNCTION update_put_trans RETURN rf.status IS

        l_scan_method   VARCHAR2(1);
        l_func_name     VARCHAR2(50) := 'Update_put_trans';
        l_rf_status     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting update_put_trans.', sqlcode, sqlerrm, g_application_func, g_program_name);
        l_scan_method := g_putaway_client.scan_method;
        l_rf_status := insert_door_tran;
        IF ( l_rf_status != rf.status_normal ) THEN
            RETURN l_rf_status;
        END IF;
        IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
            UPDATE trans
            SET
                user_id = user,
                trans_date = sysdate,
                dest_loc = g_rlc_loc,
                batch_no = 99,
                scan_method2 = l_scan_method
            WHERE
                rec_id = g_erm_id
                AND trans_type = decode(g_erm_type, 'TR', 'TRP', 'PUT')
                AND pallet_id = g_pallet_id;

        ELSE -- rlc_flag!=Y
            UPDATE trans
            SET
                user_id = user,
                trans_date = sysdate,
                batch_no = 99,
                scan_method2 = l_scan_method
            WHERE
                rec_id = g_erm_id
                AND trans_type = decode(g_erm_type, 'TR', 'TRP', 'PUT')
                AND pallet_id = g_pallet_id;

        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending update_put_trans. rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            l_rf_status := rf.status_trn_update_fail;
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = TRANS. unable to update user_id for PUT transaction. pallet_id = '
                                                || g_pallet_id
                                                || ' erm_id = '
                                                || g_erm_id, sqlcode, sqlerrm, g_application_func, g_program_name);

            RETURN l_rf_status;
			
    END update_put_trans; -- end Update_put_trans 
	
  /*******************************<+>******************************************
  **
  **  PROCEDURE
  **    update_manifest_dtls_status
  ** CALLED BY: write_transaction
  **  Description
  **    This function updates status to CLS in manifest detail
  *********************************<->******************************************/

    PROCEDURE update_manifest_dtls_status IS
        l_func_name VARCHAR2(50) := 'update_manifest_dtls_status';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting update_manifest_dtls_status.', sqlcode, sqlerrm, g_application_func, g_program_name);
        IF ( g_erm_type = 'CM' ) THEN
            UPDATE manifest_dtls
            SET
                manifest_dtl_status = 'CLS'
            WHERE
                manifest_no = substr(g_receive_id, 2)
                AND prod_id IN (
                    SELECT
                        nvl(r.returned_prod_id, r.prod_id)
                    FROM
                        returns      r,
                        reason_cds   rc
                    WHERE
                        r.manifest_no = substr(g_receive_id, 2)
                        AND r.return_reason_cd = rc.reason_cd
                        AND rc.reason_cd_type = 'RTN'
                        AND ( ( rc.reason_group IN (
                            'MPR',
                            'MPK'
                        )
                                AND ( r.returned_prod_id = g_prod_id ) )
                              OR ( rc.reason_group NOT IN (
                            'MPR',
                            'MPK'
                        )
                                   AND ( r.prod_id = g_prod_id ) ) )
                        AND decode(r.obligation_no, NULL, ' ', decode(instr(r.obligation_no, 'L'), 0, r.obligation_no, substr(r.obligation_no
                        , 1, instr(r.obligation_no, 'L') - 1))) = nvl(ltrim(rtrim(g_order_id)), ' ')
                        AND r.shipped_split_cd = g_uom
                );

            IF ( SQL%rowcount = 0 ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' unable to update status in manifest detail . receive_id = ' || g_receive_id,
                sqlcode, sqlerrm, g_application_func, g_program_name);
            END IF;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending update_manifest_dtls_status.', sqlcode, sqlerrm, g_application_func, g_program_name);
        END IF; --end g_erm_type = 'CM'

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
			-- Cannnot find the record. Try the opposite uom or without uom
            BEGIN
                UPDATE manifest_dtls
                SET
                    manifest_dtl_status = 'CLS'
                WHERE
                    manifest_no = substr(g_receive_id, 2)
                    AND prod_id IN (
                        SELECT
                            nvl(r.returned_prod_id, r.prod_id)
                        FROM
                            returns      r,
                            reason_cds   rc
                        WHERE
                            r.manifest_no = substr(g_receive_id, 2)
                            AND r.return_reason_cd = rc.reason_cd
                            AND rc.reason_cd_type = 'RTN'
                            AND ( ( rc.reason_group IN (
                                'MPR',
                                'MPK'
                            )
                                    AND ( r.returned_prod_id = g_prod_id ) )
                                  OR ( rc.reason_group NOT IN (
                                'MPR',
                                'MPK'
                            )
                                       AND ( r.prod_id = g_prod_id ) ) )
                            AND decode(r.obligation_no, NULL, ' ', decode(instr(r.obligation_no, 'L'), 0, r.obligation_no, substr
                            (r.obligation_no, 1, instr(r.obligation_no, 'L') - 1))) = nvl(ltrim(rtrim(g_order_id)), ' ')
                    );

                IF ( SQL%rowcount = 0 ) THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = manifest_dtls. unable to update status in manifest detail . receive_id = ' 
							|| g_receive_id, sqlcode, sqlerrm, g_application_func, g_program_name);                    
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = manifest_dtls. unable to update status in manifest detail . receive_id = ' || g_receive_id
                    , sqlcode, sqlerrm, g_application_func, g_program_name);
            END;
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = manifest_dtls. unable to update status in manifest detail .receive_id = ' 
					|| g_receive_id, sqlcode, sqlerrm, g_application_func, g_program_name);
           			
    END update_manifest_dtls_status;
		
  /*******************************<+>******************************************
  **
  **  PROCEDURE
  **    check_po_status
  ** CALLED BY: put_away
  **  Description
  **    This function checks for PO status
  *********************************<->******************************************/

    FUNCTION check_po_status RETURN rf.status IS

        l_func_name   VARCHAR2(50) := 'Check_po_status';
        l_rf_status   rf.status := rf.status_normal;
        l_dummy       VARCHAR2(1);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'starting check_po_status.', sqlcode, sqlerrm, g_application_func, g_program_name);
        SELECT
            'x'
        INTO l_dummy
        FROM
            erm
        WHERE
            status = 'OPN'
            AND erm_id = g_erm_id
        FOR UPDATE OF status NOWAIT;

        l_rf_status := rf.status_normal;
		
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending check_po_status. rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
		
        RETURN l_rf_status;
		
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            BEGIN
                SELECT
                    'x'
                INTO l_dummy
                FROM
                    erm
                WHERE
                    erm_id = g_erm_id
                    AND status IN (
                        'CLO',
                        'VCH'
                    )
                FOR UPDATE OF status NOWAIT;
				l_rf_status := rf.status_normal;
                RETURN l_rf_status;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = ERM . failed to lock po in CLO or VCH status. erm_id = ' || g_erm_id, sqlcode,
                    sqlerrm, g_application_func, g_program_name);
                    l_rf_status := rf.status_unavl_po;
                    RETURN l_rf_status;
            END;
        WHEN OTHERS THEN
            IF sqlcode = -54 THEN
                l_rf_status := rf.status_lock_po;
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = ERM. PO already locked.'
                                                    || ' erm_id = '
                                                    || g_erm_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                RETURN l_rf_status;
            ELSE
                l_rf_status := rf.status_unavl_po;
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = ERM .failed to select PO in OPEN status. erm_id = ' || g_erm_id, sqlcode, sqlerrm,
					g_application_func, g_program_name);
                RETURN l_rf_status;
            END IF;
    END check_po_status;

	 /*******************************************************************
  **  Function:  Update_rlc_inv
  **
  **  Description:  Updates the inventory for reserve locator companies.
  ** CALLED BY: update_inv
  **  Parameters:
  **     i_plogi_loc - Location from the gun.
  **     i_logi_loc - Pallet id from the gun.
  **     i_move_flag - TRUE  - Needs to move reserve inventory
  **                 FALSE - Needs to update inventory with putaway information.
  ******************************************************************/

    FUNCTION update_rlc_inv (
        i_plogi_loc        IN   inv.plogi_loc%TYPE,
        i_logi_loc         IN   inv.logi_loc%TYPE,
        i_home_slot_flag   IN   NUMBER,
        i_move_flag        IN   NUMBER
    ) RETURN rf.status IS

        l_func_name   VARCHAR2(50) := 'Update_rlc_inv';
        l_rf_status     rf.status := rf.status_normal;
        l_plogi_loc   inv.plogi_loc%TYPE;
        l_logi_loc    inv.logi_loc%TYPE;
    BEGIN
        l_plogi_loc := i_plogi_loc;
        l_logi_loc := i_logi_loc;
        IF ( i_home_slot_flag = 1 ) THEN
            BEGIN
                UPDATE inv
                SET
                    qoh = qoh + g_qty_rec,
                    inv_date = trunc(sysdate),
                    rec_date = trunc(sysdate),
                    rec_id = g_receive_id,
                    status = g_inv_status,
                    cube = cube + ( ( g_qty_rec - g_qty_exp ) / g_spc ) * g_case_cube,
                    parent_pallet_id = NULL
                WHERE
                    plogi_loc = g_rlc_loc
                    AND logi_loc = g_rlc_loc;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'update of RLC home inventory location failed. rlc_loc = ' || g_rlc_loc,
						sqlcode, sqlerrm, g_application_func, g_program_name);                    
                    l_rf_status := rf.status_inv_update_fail;
                    RETURN l_rf_status;
            END;

            l_rf_status := delete_inv();
            IF ( l_rf_status != rf.status_normal ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' delete of RLC home inventory location failed. plogi_loc = ' || l_plogi_loc,
				sqlcode, sqlerrm, g_application_func, g_program_name);                
                l_rf_status := rf.status_inv_update_fail;
            END IF;

        ELSE --i_home_slot_flag != 1
            BEGIN
                IF ( i_move_flag = 0 ) THEN
                    UPDATE inv
                    SET
                        qoh = qoh + g_qty_rec,
                        qty_planned = decode(sign(qty_planned - g_qty_exp), 1,(qty_planned - g_qty_exp), - 1, 0,
                                             0),
                        inv_date = trunc(sysdate),
                        rec_date = trunc(sysdate),
                        rec_id = g_receive_id,
                        status = g_inv_status,
                        cube = cube + ( ( g_qty_rec - g_qty_exp ) / g_spc ) * g_case_cube,
                        plogi_loc = g_rlc_loc,
                        parent_pallet_id = NULL
                    WHERE
                        plogi_loc = l_plogi_loc
                        AND logi_loc = l_logi_loc;

                ELSE --  i_move_flag != 0
                    UPDATE inv
                    SET
                        inv_date = trunc(sysdate),
                        rec_date = trunc(sysdate),
                        plogi_loc = g_rlc_loc,
                        parent_pallet_id = NULL
                    WHERE
                        plogi_loc = l_plogi_loc
                        AND logi_loc = l_logi_loc;

                END IF; --End i_move_flag = 0

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = INV. update of RLC reserve inventory location failed. logi_loc = '
								|| l_logi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);                   
                    l_rf_status := rf.status_inv_update_fail;
                    RETURN l_rf_status;
            END;
        END IF;-- End i_home_slot_flag = 1
		
		 pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending update_rlc_inv. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);                    
                   
        RETURN l_rf_status;
    END update_rlc_inv;

  /*******************************************************************
  **  Function:  check_rlc_put
  **
  **  Description:  find RLC home slot inventory record for item
  ** CALLED BY: put_away
  **  RETURN value:
  **        l_rf_status code
  ******************************************************************/

    FUNCTION check_rlc_put RETURN rf.status IS

        l_func_name     VARCHAR2(50) := 'Check_rlc_put';
        l_rf_status       rf.status := rf.status_normal;
        l_qty_oh        NUMBER := 0;
        l_qty_planned   NUMBER := 0;
        l_dummy         VARCHAR2(1);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside Check_rlc_put for home slot. rlc_loc =  ' || g_rlc_loc, sqlcode, sqlerrm,
			g_application_func, g_program_name);
        SELECT
            'x'
        INTO l_dummy
        FROM
            pm p
        WHERE
            fifo_trk IN (
                'A',
                'S'
            )
            AND cust_pref_vendor = g_cust_pref_vendor
            AND prod_id = g_prod_id;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Product is exp_date or FIFO tracked, Checking empty home Slot. prod_id = '
                                            || g_prod_id
                                            || ' cust_pref_vendor = '
                                            || g_cust_pref_vendor, sqlcode, sqlerrm, g_application_func, g_program_name);

        l_rf_status := rf.status_rlc_item_exp_or_fifo;     

		/*
		**  The item is fifo tracked.
		**  1. Check for any existing qoh for item.
		**     If existing qoh, then give fifo track error.
		**  2. If no existing qoh, then check for qty_planned to home slot only.
		**     If existing qty_planned, then give fifo track error.
		*/
        BEGIN
            SELECT
                SUM(qoh)
            INTO l_qty_oh
            FROM
                inv
            WHERE
                cust_pref_vendor = g_cust_pref_vendor
                AND prod_id = g_prod_id;

            IF ( l_qty_oh != 0 ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = INV. Cannot putaway to Home slot.Item is FIFO tracked and inventory exists for item. prod_id = '
                                                    || g_prod_id
                                                    || ' cust_pref_vendor = '
                                                    || g_cust_pref_vendor, sqlcode, sqlerrm, g_application_func, g_program_name);

                RETURN rf.status_rlc_item_exp_or_fifo;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = INV. unable to find inventory for item. prod_id = '
                                                    || g_prod_id
                                                    || ' cust_pref_vendor = '
                                                    || g_cust_pref_vendor, sqlcode, sqlerrm, g_application_func, g_program_name);

                l_qty_oh := 0;
        END;

        BEGIN
            SELECT
                qty_planned
            INTO l_qty_planned
            FROM
                inv
            WHERE
                plogi_loc = g_logi_loc
                AND cust_pref_vendor = g_cust_pref_vendor
                AND prod_id = g_prod_id
                AND plogi_loc = g_rlc_loc;
		EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = INV. unable to find RLC home slot inventory record for item. rlc_loc = '
                                                    || g_rlc_loc
                                                    || ' prod_id = '
                                                    || g_prod_id
                                                    || ' cust_pref_vendor = '
                                                    || g_cust_pref_vendor, sqlcode, sqlerrm, g_application_func, g_program_name);

                l_rf_status := rf.status_inv_slot;
                l_qty_planned := -1;
        END;
            IF ( l_rf_status = rf.status_rlc_item_exp_or_fifo ) THEN
                IF ( l_qty_planned != 0 ) THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = INV. Cannot putaway to Home slot.Item is FIFO tracked and home slot is not empty. rlc_loc = '
                                                        || g_rlc_loc
                                                        || ' prod_id = '
                                                        || g_prod_id
                                                        || ' cust_pref_vendor = '
                                                        || g_cust_pref_vendor, sqlcode, sqlerrm, g_application_func, g_program_name);

                    l_rf_status := rf.status_rlc_item_exp_or_fifo;
                ELSE -- l_qty_planned = 0 
                    l_rf_status := rf.status_normal;
                END IF;

            END IF;
			pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending check_rlc_put. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
			pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get if Product is FIFO tracked. prod_id = '
                                            || g_prod_id
                                            || ' cust_pref_vendor = '
                                            || g_cust_pref_vendor, sqlcode, sqlerrm, g_application_func, g_program_name);
            RETURN l_rf_status;
    END check_rlc_put;
		
 /*******************************<+>******************************************
  **  Function:
  **     check_ei_loc
  **
  **  Description:
  **     This function validates the location to be putawayed is damaged or not.
  **
  **  CALLED BY: mskuputaway
  **
  **  RETURN Values:
  **     l_rf_status code
  **********************************************************************************/

    FUNCTION check_ei_loc RETURN rf.status IS

        l_func_name   VARCHAR2(50) := 'check_ei_loc';
        l_rf_status    rf.status := rf.status_normal;
        l_locstat     loc.status%TYPE;
    BEGIN
        SELECT
            status
        INTO l_locstat
        FROM
            loc
        WHERE
            logi_loc = g_des_loc;

        IF ( l_locstat = 'DMG' ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Table = LOC. RLC Home LOC unavailable. Home Location is Damaged. rlc_loc = '
                                                || g_rlc_loc
                                                || ' prod_id = '
                                                || g_prod_id, sqlcode, sqlerrm, g_application_func, g_program_name);

            g_loc_status := 0;
            l_rf_status := rf.status_loc_damaged;
        END IF;
		
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending check_ei_loc. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
		
        RETURN l_rf_status;
    END check_ei_loc; -- end check_ei_loc 
	
  /*******************************<+>******************************************
  **  Function:
  **     upd_cdk_xref_status
  **
  **  Description:
  **     This function is to update the status of PO after putaway is done in cross dock xref table.
  **  CALLED BY: mskuputaway
  **  Parameters:
  **     erm_id
  **  RETURN Values:
  **     l_rf_status
  ******************************************************************************/

    FUNCTION upd_cdk_xref_status (
        i_erm_id erm.erm_id%TYPE
    ) RETURN rf.status IS

        l_func_name   VARCHAR2(50) := 'upd_cdk_xref_status';
        l_rf_status   rf.status := rf.status_normal;
        ln_count      NUMBER(2);
        lv_msg_text   VARCHAR2(256);
    BEGIN
        SELECT
            COUNT(*)
        INTO ln_count
        FROM
            putawaylst
        WHERE
            rec_id = g_erm_id
            AND putaway_put = 'N';

        IF ( ln_count > 0 ) THEN
            pl_rcv_cross_dock.update_cross_dock_xref(g_erm_id, 'PND');
        ELSE
            pl_rcv_cross_dock.update_cross_dock_xref(g_erm_id, 'PUT');
        END IF;

        COMMIT;
		
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending upd_cdk_xref_status. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
		
        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            lv_msg_text := 'Error updating cross dock xref status for EI po ' || g_erm_id;
            pl_text_log.ins_msg_async('WARN', l_func_name, lv_msg_text, NULL, NULL, g_application_func, g_program_name);
            RETURN rf.status_putaway_fail;
			
    END upd_cdk_xref_status;
	
  /*******************************<+>******************************************
  **  PROCEDURE:
  **     delete_PPU_trans_for_haul
  **
  **  Description:
  **     This function deletes the PPU transaction for a hauled pallet.
  **     The delete is based on the pallet existing in the PUTAWAYLST table.
  **  CALLED BY: drop_haul_pallet
  **  Parameters:
  **     p_pallet_id   - Pallet id being processed.  It will be the parent
  **                     pallet id for a MSKU pallet.
  **                     
  **
  *****************************************************************************/

    PROCEDURE delete_ppu_trans_for_haul (
        i_psz_pallet_id putawaylst.pallet_id%TYPE
    ) IS
        l_func_name    VARCHAR2(50) := 'delete_PPU_trans_for_haul';
        vc_pallet_id   putawaylst.pallet_id%TYPE;
    BEGIN
        vc_pallet_id := i_psz_pallet_id;
        IF ( g_ei_pallet = 'Y' ) THEN
            DELETE trans
            WHERE
                user_id = user -- The PPU must be for the same user who completed the haul 
                AND trans_type = 'PPU' 
                AND pallet_id IN (
                    SELECT
                        p.parent_pallet_id
                    FROM
                        putawaylst p
                    WHERE
                        p.pallet_id = vc_pallet_id
                        OR p.parent_pallet_id = vc_pallet_id
                );

        ELSE -- g_ei_pallet != 'Y'
            DELETE trans
            WHERE
                user_id = user -- The PPU must be for the same user who completed the haul 
                AND trans_type = 'PPU' 
                AND pallet_id IN (
                    SELECT
                        p.pallet_id
                    FROM
                        putawaylst p
                    WHERE
                        p.pallet_id = vc_pallet_id
                        OR p.parent_pallet_id = vc_pallet_id
                );

        END IF;

    EXCEPTION
        WHEN OTHERS THEN
			--Failing to delete the PPU is not a show stopper.
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = trans. unable to delete PPU transaction for user_id and pallet.  Procssing will continue. Pallet_id = '
            || vc_pallet_id, sqlcode, sqlerrm, g_application_func, g_program_name);
    END delete_ppu_trans_for_haul; -- end delete_PPU_trans_for_haul 
	
 /*******************************<+>******************************************
  **
  **  Function
  **    Check_pallet_type
  **
  **  CALLED BY: put_away
  **    
  **  Description
  **    This function is used for (R)eserve (L)ocator (C)ompanies. It allows a  
  **    putaway to be performed even if the pallet types do not match.
  **    Sends back 0=ok, 88=invalid slot, 99=prevent putaway because of mismatch
  **    or 142=warn about pallet mismatch.
  **  Return value:
  **         l_rf_status code
  ********************************<->******************************************/

    FUNCTION check_pallet_type RETURN rf.status IS

        l_func_name         VARCHAR2(50) := 'Check_pallet_type';
        l_rf_status           rf.status := rf.status_normal;
        l_first_pass_flag   VARCHAR2(1);
        l_pt_val_flag       VARCHAR2(8); 							-- New pallet type validation for R,L.C. 
        l_to_pallet_type    loc.pallet_type%TYPE;     				-- New pallet type validation for R,L.C. 
        l_fm_pallet_type    loc.pallet_type%TYPE;
    BEGIN
        l_first_pass_flag := g_putaway_client.first_pass_flag;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside CheckPalletType. lfirstpassflag = ' || l_first_pass_flag,
			sqlcode, sqlerrm, g_application_func, g_program_name);

		--setup the first pass flag to bypass RLC pallet validation 
        IF ( l_first_pass_flag = 'Y' ) THEN
            BEGIN
                SELECT
                    pallet_type
                INTO l_fm_pallet_type
                FROM
                    loc
                WHERE
                    logi_loc = g_rlc_loc;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = LOC . Unable to get pallet type for from location. rlc_loc = ' || g_rlc_loc,
						sqlcode, sqlerrm, g_application_func, g_program_name);                    
                    RETURN rf.status_inv_slot;
            END;

            BEGIN
                SELECT
                    pallet_type
                INTO l_to_pallet_type
                FROM
                    loc
                WHERE
                    logi_loc = g_des_loc;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = LOC .Unable to get pallet type for to location. dest_loc = ' || g_des_loc,
						sqlcode, sqlerrm, g_application_func, g_program_name);                    
                    RETURN rf.status_inv_slot;
            END;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside CheckPalletType. rlc_loc = '
                                                || g_rlc_loc
                                                || 'fm_pallet_type = '
                                                || l_fm_pallet_type
                                                || ' destloc = '
                                                || g_des_loc
                                                || 'to_pallet_type = '
                                                || l_to_pallet_type, sqlcode, sqlerrm, g_application_func, g_program_name);

            IF ( l_fm_pallet_type != l_to_pallet_type ) THEN
                BEGIN
                    l_pt_val_flag := pl_common.f_get_syspar('TRANS_VAL_PT', 'x');
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'TRANS_VAL_PT flag value = ' || l_pt_val_flag, sqlcode, sqlerrm, g_application_func, g_program_name);
                    IF ( l_pt_val_flag = 'PREVENT' ) THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, ' SYSPAR flag is set to PREVENT', sqlcode, sqlerrm, g_application_func, g_program_name);
                        pl_text_log.ins_msg_async('INFO', l_func_name, ' Pallet types do not match.  fm_pallet_type = '
                                                            || l_fm_pallet_type
                                                            || ' to_pallet_type = '
                                                            || l_to_pallet_type, sqlcode, sqlerrm, g_application_func, g_program_name);

                        RETURN rf.status_size_error;
                    ELSIF ( l_pt_val_flag = 'WARN' ) THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, ' SYSPAR flag is set to WARN', sqlcode, sqlerrm, g_application_func, g_program_name);
                        pl_text_log.ins_msg_async('INFO', l_func_name, ' Pallet types do not match.  fm_pallet_type = '
                                                            || l_fm_pallet_type
                                                            || ' to_pallet_type = '
                                                            || l_to_pallet_type, sqlcode, sqlerrm, g_application_func, g_program_name);

                        RETURN rf.status_size_error_warn;
                    ELSIF l_pt_val_flag = 'x' THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, ' Unable to get pallet type validation syspar.', sqlcode, sqlerrm,
						g_application_func, g_program_name);
                        RETURN l_rf_status;
                    END IF;-- end l_pt_val_flag  PREVENT/WARN
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, ' Unable to get pallet type validation syspar(TRANS_VAL_PT)',
						sqlcode, sqlerrm, g_application_func, g_program_name);
                        RETURN l_rf_status;
                END;
            END IF;-- end pallet type comparison 

        END IF;--end first_pass_flag
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending check_pallet_type. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN l_rf_status;
    END check_pallet_type; -- end Check_pallet_type 

  /*******************************<+>******************************************
  **  Function:
  **     insert_door_tran
  **
  **  Description:
  **     This function creates DOR transaction
  **  CALLED BY: write_transaction
  **  Parameters:
  **
  **  RETURN Values:
  **     l_rf_status
  **********************************************************************************/

    FUNCTION insert_door_tran RETURN rf.status IS
        l_func_name   VARCHAR2(50) := 'Insert_door_tran';
        l_rf_status     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Inside Insert_door_tran, ttype DOR expdate = '
                                            || g_vc_exp_date
                                            || ' mfgdate = '
                                            || g_mfg_date, sqlcode, sqlerrm, g_application_func, g_program_name);

        IF ( g_putaway_client.cte_door_trans = 'Y' ) THEN
            INSERT INTO trans (
                trans_id,
                trans_type,
                rec_id,
                src_loc,
                trans_date,
                user_id,
                batch_no
            ) VALUES (
                trans_id_seq.NEXTVAL,
                'DOR',
                g_receive_id,
                g_door_no,
                sysdate,
                user,
                99
            );

        END IF;
		
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending insert_door_tran. rf_status = ' || l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
		
        RETURN l_rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = TRANS. unable to create DOR transaction. receive_id = ' || g_receive_id,
				sqlcode, sqlerrm, g_application_func, g_program_name);            
            l_rf_status := rf.status_insert_fail;
            RETURN l_rf_status;
    END insert_door_tran;
	
  /*******************************<+>******************************************
  **
  **  Function
  **    Find_pending_replen_tasks
  **  CALLED BY: putaway_service
  **  Parameters
  **     p_plogi_loc - The location of the putaway from the RF gun.
  **     server (structure pointer) - The pending replenishment tasks to be
  **                                  populated by this function.
  **    
  **  Description
  **    This function finds pending replenishment tasks that are in the proximity
  **    of a putaway when syspar FORCE_RPL_IN_PUTAWAY is not "IGNORE"
  **    The location range to search taken from syspar RPL_SEARCH_BAY_RANGE.
  **
  **    The pending replenishment tasks (if there are any) are placed in a
  **    structure which can hold up to 10 tasks.  These are then passed to
  **    the RF gun.
  **
  **    Tasks are not retrieved for a RETURNs PO because it is not practical
  **    for the person doing RETURNs to perform a non-demand replenishment.
  *****************************************************************************/

    FUNCTION find_pending_replen_tasks (
        i_plogi_loc         IN      inv.plogi_loc%TYPE,
        i_putaway_client    IN      putaway_client_obj,
        o_loc_collection    OUT     putaway_loc_result_obj,
        io_putaway_server   IN OUT  putaway_server_obj
    ) RETURN rf.status IS

        l_func_name                VARCHAR(50) := 'Find_pending_replen_tasks';
        l_plogi_loc                inv.plogi_loc%TYPE; 										-- The location the item putaway to. 
        l_put_aisle                loc.put_aisle%TYPE;			    						-- The putaway location put aisle. 
        l_put_slot                 loc.put_slot%TYPE; 										-- The putaway location put slot. 
        l_rplbays                  swms_areas.rpl_bay_count%TYPE;
        l_putbays                  swms_areas.put_bay_count%TYPE; 							-- bay counts for putaway location area 
        l_result_table             putaway_loc_result_table := putaway_loc_result_table();
        l_counter                  NUMBER; 													-- Count of replenishments found. 
        l_force_rpl_in_putaway     sys_config.config_flag_val%TYPE;							-- Syspar FORCE_RPL_IN_PUTAWAY 
        l_pending_rpl_flag         VARCHAR2(2);												-- Syspar abbreviation to RETURN to the RF gun.																					 
        l_rpl_after_each_putaway   sys_config.config_flag_val%TYPE; 						-- Syspar RPL_AFTER_EACH_PUTAWAY 
        l_rpl_search_bay_range     VARCHAR2(11); 											-- Syspar RPL_SEARCH_BAY_RANGE 
        l_rf_status                  rf.status := rf.status_normal; 							-- RETURN status 
        l_count                    NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'In Find_pending_replen_tasks PD. i_plogi_loc = ' || i_plogi_loc,
			sqlcode, sqlerrm, g_application_func, g_program_name);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Find_pending_replen_tasks PD testing, i_plogi_loc = ' || i_plogi_loc,
			sqlcode, sqlerrm, g_application_func, g_program_name);
        
        l_plogi_loc := i_plogi_loc;

		/*
		** Select syspar FORCE_RPL_IN_PUTAWAY and the abbreviation of this
		** syspar that will be sent to the RF gun.
		*/
        l_rf_status := get_syspar_frc_rpl_putaway(l_force_rpl_in_putaway, l_pending_rpl_flag);
        IF l_rf_status != rf.status_normal THEN
            RETURN l_rf_status;
        END IF;

			
			-- Select syspar RPL_AFTER_EACH_PUTAWAY 
			
        l_rf_status := gt_syspar_rpl_aftr_ech_ptaway(l_rpl_after_each_putaway);
        IF ( l_rf_status != rf.status_normal ) THEN
            RETURN l_rf_status;
        END IF;

		
		
		-- if a RETURNs PO then ignore pending non-demand replenishments.
		
        IF ( g_erm_type = 'CM' ) THEN
            l_pending_rpl_flag := 'I';
            pl_text_log.ins_msg_async('INFO', l_func_name, 'RETURNs PO.  Always ignore pending replenishments.  pending_rpl_flag = '
							|| io_putaway_server.pending_rpl_flag, sqlcode, sqlerrm, g_application_func, g_program_name);
           
        END IF;

        io_putaway_server.pending_rpl_flag := l_pending_rpl_flag;
        l_counter := 0; -- Initialize counter and place value in the server obj. 
        io_putaway_server.loc_cnt := l_counter;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Server->pending_rpl_flag set to' || io_putaway_server.pending_rpl_flag,
			sqlcode, sqlerrm, g_application_func, g_program_name);

		/*
		** Find pending replenishment tasks if syspar FORCE_RPL_IN_PUTAWAY
		** is not "IGNORE".  The abbreviation for this is 'I'.*/

        IF ( ( l_pending_rpl_flag != 'I' ) AND ( i_putaway_client.haul_flag != 'Y' ) ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'rpl_after_each_put syspar = '
                                                || l_rpl_after_each_putaway
                                                || ' last_put = '
                                                || i_putaway_client.last_put, sqlcode, sqlerrm, g_application_func, g_program_name);

			/* 
			** do not need to go further if syspar is to send after last put
			** but the putaway client flag is not the last putaway of a multi */

            IF ( l_rpl_after_each_putaway = 'Y' OR i_putaway_client.last_put != 'N' ) THEN
                BEGIN
					-- Get the put aisle and put slot for the putaway location. 
                    SELECT
                        put_aisle,
                        put_slot
                    INTO
                        l_put_aisle,
                        l_put_slot
                    FROM
                        loc
                    WHERE
                        logi_loc = l_plogi_loc;

                EXCEPTION
                    WHEN OTHERS THEN
                        IF i_putaway_client.haul_flag = 'Y' THEN --It's OK to fail if Hauling 
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to select put_aisle,put_slot for loc ' || l_plogi_loc,
								sqlcode, sqlerrm, g_application_func, g_program_name);
                           
                            RETURN rf.status_normal;
                        ELSE
                            RETURN rf.status_pending_rpl_tsk_fail;
                        END IF;
                END;
				-- Get the bay counts from swms_areas   

                BEGIN
                    SELECT
                        a.rpl_bay_count,
                        a.put_bay_count
                    INTO
                        l_rplbays,
                        l_putbays
                    FROM
                        aisle_info       ai,
                        swms_sub_areas   sa,
                        swms_areas       a
                    WHERE
                        ai.name = substr(l_plogi_loc, 1, 2)
                        AND ai.sub_area_code = sa.sub_area_code
                        AND sa.area_code = a.area_code;

                EXCEPTION
                    WHEN OTHERS THEN
						--Either an error or no data found.
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to select bay counts for loc ' || l_plogi_loc,
							sqlcode, sqlerrm, g_application_func, g_program_name);                       
                        RETURN rf.status_pending_rpl_tsk_fail;
                END;

                BEGIN
                    SELECT
                        putaway_loc_result_record(rf.nonull(src_loc), rf.nonull(dest_loc))
                    BULK COLLECT
                    INTO l_result_table
                    FROM
                        loc         lpick,
                        loc         lput,
                        replenlst   r
                    WHERE
                        lpick.put_aisle = l_put_aisle
                        AND lput.put_aisle = l_put_aisle
                        AND lpick.logi_loc = r.src_loc
                        AND lput.logi_loc = r.dest_loc
                        AND r.status = 'NEW'
                        AND r.type = 'NDM'
                        AND trunc(l_put_slot / 10) BETWEEN ( trunc(lpick.put_slot / 10) - l_rplbays ) AND ( trunc(lpick.put_slot /
                        10) + l_rplbays )
                        AND trunc(lpick.put_slot / 10) BETWEEN ( trunc(lput.put_slot / 10) - l_putbays ) AND ( trunc(lput.put_slot
                        / 10) + l_putbays )
                        AND NOT EXISTS (
                            SELECT
                                1
                            FROM
                                putawaylst p
                            WHERE
                                pallet_id = r.pallet_id
                                AND p.dest_loc = r.src_loc
                                AND putaway_put = 'N'
                        )
                        AND ROWNUM <= MAX_PENDING_REPLEN_TASKS
                    ORDER BY
                        abs(trunc(l_put_slot / 10) - trunc(lpick.put_slot / 10)),
                        lpick.put_slot,
                        lpick.put_level;

                    l_count := l_result_table.count;
                    o_loc_collection := putaway_loc_result_obj(l_result_table);
                    io_putaway_server.loc_cnt := l_count;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'bulk collect found no records. put_aisle ='||l_put_aisle,
							sqlcode, sqlerrm, g_application_func, g_program_name);
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'error fetching from cursor replen_cur. put_aisle ='||l_put_aisle,
							sqlcode, sqlerrm, g_application_func, g_program_name);																										
                        RETURN rf.status_pending_rpl_tsk_fail;
                END;

            END IF; --end checking last put flag and actual

        END IF; -- end if on force_fpl_flag

        pl_text_log.ins_msg_async('INFO', l_func_name, ' Leaving Find_pending_replen_tasks with NORMAL status',
			sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN rf.status_normal;
    END find_pending_replen_tasks;

 /*******************************<+>******************************************
  **
  **  Function
  **    get_syspar_frc_rpl_putaway
  **  CALLED BY: find_pending_replen_tasks
  **  Parameters
  **     p_syspar_value   - The value of the syspar determined by this function.
  **     p_pending_rpl_flag - The one character abbreviation of this syspar
  **                          which will be sent back to the RF gun.
  **                          The abbreviation and the syspar value are:
  **                             I - IGNORE
  **                             F - FORCE
  **                             P - PREVENT
  **    
  **    
  **  Description
  **    This function gets the value of syspar FORCE_RPL_IN_PUTAWAY.
  ********************************<->******************************************/

    FUNCTION get_syspar_frc_rpl_putaway (
        o_syspar_value       OUT   sys_config.config_flag_val%TYPE,
        o_pending_rpl_flag   OUT   VARCHAR2
    ) RETURN rf.status IS

        l_func_name              VARCHAR2(50) := 'get_syspar_frc_rpl_putaway';
        l_force_rpl_in_putaway   sys_config.config_flag_val%TYPE; 		-- Syspar FORCE_RPL_IN_PUTAWAY 
        l_rf_status                rf.status := rf.status_normal;
    BEGIN
        l_force_rpl_in_putaway := pl_common.f_get_syspar('FORCE_RPL_IN_PUTAWAY', 'x');
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Selected syspar FORCE_RPL_IN_PUTAWAY, value is ' || l_force_rpl_in_putaway,
					sqlcode, sqlerrm, g_application_func, g_program_name);        
        IF ( l_rf_status = rf.status_normal ) AND l_force_rpl_in_putaway != 'x' THEN
            o_syspar_value := l_force_rpl_in_putaway;
 
			-- Determine the abbreviation for the syspar. 
            IF o_syspar_value = 'IGNORE' THEN
                o_pending_rpl_flag := 'I';
            ELSIF o_syspar_value = 'WARN' THEN
                o_pending_rpl_flag := 'W';
            ELSIF o_syspar_value = 'FORCE' THEN
                o_pending_rpl_flag := 'F';
            ELSE
		
				--Unhandled value for the syspar.
		
                l_rf_status := rf.status_sel_syscfg_fail;
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = sys_config . Syspar FORCE_RPL_IN_PUTAWAY has an unhandled value '
                                                    || o_syspar_value
                                                    || ' when determining abbreviation to send to RF gun',
													sqlcode, sqlerrm, g_application_func, g_program_name);

            END IF; -- end syspar value validation

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Abbreviation of syspar FORCE_RPL_IN_PUTAWAY is ' || o_pending_rpl_flag,
						sqlcode, sqlerrm, g_application_func, g_program_name);
           
		ELSE -- invalid syspar value for FORCE_RPL_IN_PUTAWAY
			pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = sys_config. Select config_flag_val FORCE_RPL_IN_PUTAWAY failed.',
					sqlcode, sqlerrm, g_application_func, g_program_name);
            l_rf_status := rf.status_sel_syscfg_fail;
        END IF;
		
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending get_syspar_frc_rpl_putaway. rf_status = ' || l_rf_status,
					sqlcode, sqlerrm, g_application_func, g_program_name);
		
        RETURN l_rf_status;
    
    END get_syspar_frc_rpl_putaway;

 /*******************************<+>******************************************
  **
  **  Function
  **    drop_haul_pallet
  **  CALLED BY: putaway_service
  **  Parameters
  **     i_pallet_id - Pallet being dropped.
  **     i_drop_point - Drop point.
  **    
  **  Description
  **    This function drops a pallet being hauled to the specified destination.
  ***************************************************************************/

    FUNCTION drop_haul_pallet (
        i_pallet_id    IN   putawaylst.pallet_id%TYPE,
        i_drop_point   IN   inv.plogi_loc%TYPE
    ) RETURN rf.status IS

        l_func_name      VARCHAR2(50) := 'drop_haul_pallet';
        l_rf_status        rf.status := rf.status_normal;
        l_s_batch_no     batch.batch_no%TYPE;
        l_s_pallet_id    putawaylst.pallet_id%TYPE;
        l_s_drop_point   batch.kvi_to_loc%TYPE;
        l_s_point_type   point_distance.point_type%TYPE;
        l_s_dock_num     point_distance.point_dock%TYPE;
        l_drop_point     batch.kvi_to_loc%TYPE;
        l_batch_no       batch.batch_no%TYPE;
        l_pallet_id      batch.ref_no%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Starting drop_haul_pallet .pallet_id = '  
                                            || i_pallet_id
                                            || ' i_drop_point = '
                                            || i_drop_point, sqlcode, sqlerrm, g_application_func, g_program_name);

        get_rf_info(); --EI - restrict calling below function for EI po
        IF ( g_ei_pallet != 'Y' ) THEN
            get_po_info;
        END IF;
		
        IF ( pl_lm_forklift.lmf_forklift_active() != rf.status_normal ) THEN
            RETURN l_rf_status;
        END IF;

        l_pallet_id := i_pallet_id;
        BEGIN
            l_s_drop_point := i_drop_point;
            l_drop_point := l_s_drop_point;
            l_rf_status := pl_lm_distance.lmd_get_point_type(l_s_drop_point, l_s_point_type, l_s_dock_num);
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'pl_lmd.get_point_type failed', sqlcode, sqlerrm, g_application_func, g_program_name);
        END;
		IF l_rf_status = rf.status_normal THEN
			l_s_pallet_id := i_pallet_id;
			BEGIN
				SELECT
					batch_no
				INTO l_batch_no
				FROM
					batch
				WHERE
					ref_no = l_pallet_id
					AND user_id = replace(user, 'OPS$')
					AND status IN (
						'A',
						'M'
					)
					AND batch_no LIKE 'HP%';

				pl_text_log.ins_msg_async('INFO', l_func_name, 'Table = batch .Found haul batch. batch_no = ' || l_batch_no,
					sqlcode, sqlerrm, g_application_func, g_program_name);
			EXCEPTION
				WHEN OTHERS THEN
					pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = batch. Unable to find HP haul batch in A or M status. pallet_id = ' || l_pallet_id,
						sqlcode, sqlerrm, g_application_func, g_program_name);					
					l_rf_status := rf.status_no_lm_batch_found;
			END;
		END IF;
		
        IF l_rf_status = rf.status_normal THEN
            BEGIN
                UPDATE batch
                SET
                    kvi_to_loc = l_drop_point
                WHERE
                    batch_no = l_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    l_rf_status := rf.status_lm_batch_upd_fail;
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = batch. Unable to update TO location of haul batch. drop_point = '
                                                        || l_drop_point
                                                        || ' batch_no =  '
                                                        || l_batch_no, sqlcode, sqlerrm, g_application_func, g_program_name);

            END;
        END IF;

		/*
		** Update the putaway batch kvi_from_loc to the location the pallet
		** was dropped at.
		*/

        IF ( l_rf_status = rf.status_normal ) THEN
            BEGIN
                UPDATE batch
                SET
                    kvi_from_loc = l_drop_point
                WHERE
                    batch_no IN (
                        SELECT
                            pallet_batch_no
                        FROM
                            putawaylst
                        WHERE
                            ( pallet_id = l_pallet_id
                              OR parent_pallet_id = l_pallet_id )
                            AND nvl(putaway_put, 'N') != 'Y'
                    );

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = batch. Unable to update FROM location of putaway batch with the haul drop point. Drop_point = '
                                                        || l_drop_point
                                                        || ' pallet_id = '
                                                        || l_pallet_id, sqlcode, sqlerrm, g_application_func, g_program_name);

                    l_rf_status := rf.status_lm_batch_upd_fail;
            END;
        END IF;

        IF ( l_rf_status = rf.status_normal AND g_ei_pallet != 'Y' ) THEN
            l_s_batch_no := l_batch_no;
            l_rf_status := pl_lm_forklift.lmf_insert_haul_trans(l_s_batch_no);
        END IF;

        BEGIN
            IF ( l_rf_status = rf.status_normal AND g_ei_pallet = 'Y' ) THEN
                INSERT INTO trans (
                    trans_id,
                    trans_type,
                    trans_date,
                    prod_id,
                    pallet_id,
                    dest_loc,
                    src_loc,
                    rec_id,
                    user_id,
                    weight,
                    qty,
                    uom,
                    exp_date,
                    cmt,
                    parent_pallet_id,
                    labor_batch_no
                )
                    SELECT
                        trans_id_seq.NEXTVAL,
                        'HAL',
                        sysdate,
                        '*',
                        p.parent_pallet_id,
                        b.kvi_to_loc,
                        b.kvi_from_loc,
                        p.rec_id,
                        user,
                        b.kvi_wt,
                        p.qty,
                        p.uom,
                        p.exp_date,
                        l_batch_no,
                        p.parent_pallet_id,
                        b.batch_no
                    FROM
                        putawaylst   p,
                        batch        b
                    WHERE
                        ( p.pallet_id = b.ref_no
                          OR p.parent_pallet_id = b.ref_no )
                        AND b.batch_no = l_batch_no
                        AND nvl(p.putaway_put, 'N') = 'N';

            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'unable to create haul transaction.Batch_no = ' || l_batch_no,
					sqlcode, sqlerrm, g_application_func, g_program_name);
                l_rf_status := rf.status_trans_insert_failed;
        END;

			/*
			** 
			** Update the trans PUT record src_loc to handle the situation where
			** the PO was closed before the pallet was putaway (thus creating a
			** PUT transaction) and then the pallet was hauled.  The trans PUT
			** record src_loc needs to be updated to the location the pallet
			** was hauled to.
			*/

        IF l_rf_status = rf.status_normal THEN
            l_rf_status := pl_lm_forklift.lmf_update_put_trans(l_s_batch_no);
        END IF;
		
        IF l_rf_status = rf.status_normal THEN
            delete_ppu_trans_for_haul(l_s_pallet_id);
        END IF;
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Leaving drop_haul_pallet. rf_status = '||l_rf_status,
			sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN l_rf_status;
    END drop_haul_pallet; -- end drop_haul_pallet 
	
  /*****************************************************************************
  **  FUNCTION: 
  **      Get_source_location
  **  DESCRIPTION:
  **      This function gets the source location of a pallet from the TRANS
  **      table where the trans_type = 'PPU'.  The PPU record should have
  **      the current location of the pallet in the src_loc column.
  **      The selection of the TRANS record is like that in function
  **      delete_PPU_trans.
  **  CALLED BY: write_transaction
  **  PARAMETERS:
  **      i_erm_id    -- The PO#
  **      i_pallet_id -- The pallet being putaway.
  **      o_src_loc   -- The current location of the pallet determined by
  **                     this function.
  **  RETURN VALUES:  
  **      SWMS_NORMAL  --  Okay.
  **      DATA_ERROR   --  Oracle error occurred.
  *****************************************************************************/

    FUNCTION get_source_location (
        i_erm_id      IN    erm.erm_id%TYPE,
        i_pallet_id   IN    putawaylst.pallet_id%TYPE,
        o_src_loc     OUT   trans.src_loc%TYPE
    ) RETURN rf.status IS

        l_func_name   VARCHAR2(50) := 'Get_source_location';
        l_rf_status     rf.status := rf.status_normal; -- RETURN status. 
        l_erm_id      erm.erm_id%TYPE;
        l_pallet_id   putawaylst.pallet_id%TYPE;
        l_src_loc     trans.src_loc%TYPE;
		/* 
		**  This cursor select the src_loc from the TRANS table for the last
		**  PPU transaction for a pallet for the current user.
		**  The selection of the TRANS record is like that in function
		**  delete_PPU_trans.
		*/
        CURSOR c_trans_cur IS
        SELECT
            src_loc
        FROM
            trans t1
        WHERE
            user_id = user
            AND rec_id = l_erm_id
            AND pallet_id = l_pallet_id
            AND trans_type = 'PPU'
            AND trans_date = (
                SELECT
                    MAX(trans_date)
                FROM
                    trans t2
                WHERE
                    t2.user_id = t1.user_id
                    AND t2.rec_id = t1.rec_id
                    AND t2.pallet_id = t1.pallet_id
                    AND t2.trans_type = t1.trans_type
            );

    BEGIN
      -- Store the parameters in local varchar variables. 
        l_erm_id := i_erm_id;
        l_pallet_id := i_pallet_id;
        OPEN c_trans_cur;

		-- Cursor opened.  Get the src loc. 
        LOOP
            FETCH c_trans_cur INTO l_src_loc;
            EXIT WHEN c_trans_cur%notfound;
            o_src_loc := l_src_loc;
        END LOOP;

      -- Close the cursor. 

        CLOSE c_trans_cur;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Erm Id = '
                                            || l_erm_id
                                            || ' Pallet = '
                                            || l_pallet_id
                                            || ' Selected source locn in trans table = '
                                            || o_src_loc
											||' rf_status = '
											||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);

        RETURN l_rf_status;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_rf_status := rf.status_normal;
            RETURN l_rf_status;
        WHEN invalid_cursor THEN
            l_rf_status := rf.status_data_error;
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Closing cursor c_trans_cur failed', sqlcode, sqlerrm, g_application_func, g_program_name);
            RETURN l_rf_status;
        WHEN OTHERS THEN
            l_rf_status := rf.status_data_error;
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Cursor c_trans_cur fetch failed', sqlcode, sqlerrm, g_application_func, g_program_name);
            RETURN l_rf_status;
    END get_source_location;
	
  /*******************************<+>******************************************
  **  Function:
  **     check_strip_loc
  ** called by:put_away
  **  Description:
  **     This function get strip_loc flag from sys_config
  **     
  **  
  ***************************************************************************/

    PROCEDURE check_strip_loc IS
        l_func_name VARCHAR2(50) := 'Check_strip_loc';
    BEGIN		
		  --   The default value for this is N 		
        g_strip_loc := pl_common.f_get_syspar('STRIP_LOC', 'N');
		IF g_strip_loc != 'Y' OR g_strip_loc IS NULL THEN
			g_strip_loc :='N';
			pl_text_log.ins_msg_async('INFO', l_func_name, 'strip_loc flag = ' || g_strip_loc, sqlcode, sqlerrm, g_application_func, g_program_name);
		END IF;
		pl_text_log.ins_msg_async('INFO', l_func_name, 'strip_loc flag = ' || g_strip_loc, sqlcode, sqlerrm, g_application_func, g_program_name);
    END check_strip_loc;

  /*******************************<+>******************************************
  **  FUNCTION:
  **     mskuputaway
  ** CALLED BY: putaway_service
  **  Description:
  **     Putaway service for MSKU pallets
  **
  **  RETURN Value:
  **    l_rf_status code
  **                     
  *****************************************************************************/

    FUNCTION mskuputaway RETURN rf.status IS

        l_func_name             VARCHAR2(50) := 'MSKUPutaway';
        l_rf_status               rf.status := rf.status_normal;
        l_home_slot_flag        NUMBER; 					-- Home location designator 
        l_new_float_flag        NUMBER := 1; 				-- New floating location designator 
        l_ret_val               NUMBER;
        l_prod_id               pm.prod_id%TYPE;
        l_rec_id                inv.rec_id%TYPE;
        l_qoh                   inv.qoh%TYPE;
        l_spc                   pm.spc%TYPE;
        l_exp_date              DATE;
        l_inv_status            inv.status%TYPE;
        l_sys_msg_id            NUMBER;
        l_slot_type             loc.slot_type%TYPE;
        l_temp                  NUMBER := 0;
        l_finish_good_po_flag   VARCHAR2(1) := 'N';
        CURSOR c_child_pallets IS
        SELECT
            p.pallet_id
        FROM
            putawaylst   p,
            loc          l
        WHERE
            l.logi_loc = p.dest_loc
            AND p.parent_pallet_id = g_pallet_id_msku
            AND p.putaway_put = 'N'
            AND l.perm = 'N';

    BEGIN
		
		   -- Check if RF devices can be used
		
        l_rf_status := check_global_rf;
        IF ( l_rf_status != rf.status_normal ) THEN
            RETURN l_rf_status;
        END IF;

      
        --Retrieve pallet_id, plogi_loc, real_put_path_val, user_id from msg
      
        get_rf_info;

      
        -- Check sys_config for the value of strip_loc   - 
      
        check_strip_loc;

      /* 
      **  Check putawaylst for the following conditions - 
      **  1. pallet does not exist 
      **  2. putaway already confirmed 
      **  3. dest loc undefined
      */
        SAVEPOINT s;
        BEGIN
            OPEN c_child_pallets;
            FETCH c_child_pallets INTO g_pallet_id;
            get_po_info;
            IF ( l_rf_status = rf.status_normal ) THEN
                l_rf_status := check_po_status;
            END IF;
            LOOP
                l_rf_status := check_putawaylist;
                IF ( l_rf_status != rf.status_normal ) THEN
                    ROLLBACK TO s;
                    RETURN l_rf_status;
                END IF;

                 /*
                 **  Prepare user put aisle and put slot values of the scanned location
                 **  and check if they match that of the destination location
                 */

                l_rf_status := check_put_path;
                IF ( l_rf_status != rf.status_normal ) THEN
                    ROLLBACK TO s;
                    RETURN l_rf_status;
                END IF;

                l_rf_status := get_putaway_info;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'After getputinfo, Date_code = '
                                                    || g_mfg_ind
                                                    || ' Exp_date = '
                                                    || g_vc_exp_date
                                                    || ' Mfg_date = '
                                                    || g_mfg_date, sqlcode, sqlerrm, g_application_func, g_program_name);

                l_rf_status := get_product_info;
                IF ( l_rf_status != rf.status_normal ) THEN
                    ROLLBACK TO s;
                    RETURN l_rf_status;
                END IF;

                g_loc_status := rf.status_nor_cluster;
                IF ( g_loc_status = rf.status_nor_cluster ) THEN
                    l_home_slot_flag := check_home_slot;
                END IF;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'After ChkHomeSlot. home_slot_flag = '
                                                    || l_home_slot_flag
                                                    || ' ermstat = '
                                                    || g_erm_status
                                                    || ' ermtyp = '
                                                    || g_erm_type, sqlcode, sqlerrm, g_application_func, g_program_name);

                IF ( g_erm_status = 'OPN' ) THEN -- PO is OPEN 
                    IF ( g_erm_type != 'CM' ) THEN -- Receiving PO - NOT a RETURN 
						/*
						**  SPLIT put-confirm into old INV should not
						**  check palletid.
						*/
                        l_rf_status := confirm_putaway_task;
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'After ConfirmPutawayTask. 5 status = '
                                                            || l_rf_status
                                                            || ' qtyrec = '
                                                            || g_qty_rec
                                                            || ' RLCflag = '
                                                            || g_putaway_client.rlc_flag, sqlcode, sqlerrm, g_application_func, g_program_name);

                        IF ( l_rf_status != rf.status_normal ) THEN
                            ROLLBACK TO s;
                            RETURN l_rf_status;
                        END IF;

                        IF ( g_qty_rec > 0 ) THEN
                            IF ( g_ei_pallet = 'Y' ) THEN
                                l_rf_status := check_ei_loc;
                                pl_text_log.ins_msg_async('INFO', l_func_name, ' After CheckEILoc. status = ' || l_rf_status, sqlcode, sqlerrm
                                , g_application_func, g_program_name);
                                IF ( l_rf_status != rf.status_normal ) THEN
                                    ROLLBACK TO s;
                                    RETURN l_rf_status;
                                END IF;

                                l_rf_status := update_cdk_inv(g_plogi_loc, g_pallet_id, 1, l_home_slot_flag);
                            ELSIF ( ( g_uom = 1 ) AND ( check_new_float() = 0 ) ) THEN
                                l_rf_status := update_inv(g_plogi_loc, g_pallet_id, 0, l_home_slot_flag);
                            ELSE -- g_ei_pallet!=Y
                                l_rf_status := check_reserve_loc;
                                pl_text_log.ins_msg_async('INFO', l_func_name, ' After CheckReserveLoc. status = ' || l_rf_status, sqlcode, sqlerrm
                                , g_application_func, g_program_name);
                                IF ( l_rf_status != rf.status_normal ) THEN
                                    ROLLBACK TO s;
                                    RETURN l_rf_status;
                                END IF;

                                l_rf_status := update_inv(g_plogi_loc, g_pallet_id, 1, l_home_slot_flag);
                            END IF; -- end g_ei_pallet = 'Y'

                            IF ( l_rf_status != rf.status_normal ) THEN
                                ROLLBACK TO s;
                                RETURN l_rf_status;
                            END IF;


                            -- 2021.08.11 (kchi7065) Story 3577 Check if this is a Cross Dock pallet.
                            IF ( g_erm_type = 'XN' OR ( g_erm_type = 'CM' AND g_erm_id LIKE 'X%' )) THEN 

                              -- If it is Cross Dock check if Destinatin Location is valid.
                              IF ( f_check_location (g_dest_loc) = 'Y' ) THEN

                                  -- If the Location is valid, create a PUX transaction.
                                  l_rf_status := write_transaction('PUX');

                                ELSE 
                        
                                  -- If the location is invalid, check if the order generation occurred.
                                  -- If no, create a PUX transaction.
                                  -- If yes, error   

                                  IF ( f_check_order_gen(g_pallet_id) = 'Y' ) THEN
                                      -- Raise error
                                      -- Please use the RF Replen and Bulk Pull option
                                      pl_text_log.ins_msg_async('INFO', 
                                                                l_func_name, 
                                                                'Order Generation has already occurred. Please use the RF Replen and Bulk Pull option ', 
                                                                sqlcode, 
                                                                sqlerrm, 
                                                                g_application_func, 
                                                                g_program_name);

                                      ROLLBACK TO s;
                                      return RF.STATUS_XDOCK_PUT_INV_LOC;

                                    ELSE

                                      l_rf_status := write_transaction('PUX');

                                  END IF;
      
                              END IF;

                              ELSE

                                l_rf_status := write_transaction('PUT');

                            END IF;




--                            l_rf_status := write_transaction('PUT');
                            IF ( l_rf_status != rf.status_normal ) THEN
                                ROLLBACK TO s;
                                RETURN l_rf_status;
                            END IF;

                        ELSIF ( g_qty_rec = 0 ) THEN
                            IF ( l_home_slot_flag = 1 ) THEN
                                l_rf_status := update_inv_zero_rcv(1);
                            ELSE
                                l_rf_status := delete_inv;
                            END IF;

                            IF ( l_rf_status != rf.status_normal ) THEN
                                ROLLBACK TO s;
                                RETURN l_rf_status;
                            END IF;

                        END IF; --end g_qty_rec > 0

                    ELSE -- RETURN PO 
                        pl_text_log.ins_msg_async('WARN', l_func_name, g_pallet_id || ' is a part of a MSKU pallet and MSKU pallets cannot arrive on RETURN POs',
							sqlcode, sqlerrm, g_application_func, g_program_name);         
                        ROLLBACK TO s;
                        RETURN rf.status_inv_label;
                    END IF; --g_erm_type != 'CM'
                ELSIF ( g_erm_status = 'CLO' ) OR ( g_erm_status = 'VCH' ) THEN-- PO is CLOSED 
                    IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
                        IF ( l_home_slot_flag = 0 ) THEN
                            l_rf_status := check_reserve_loc;
                        ELSE
                            l_rf_status := check_rlc_put;
                        END IF;

                        IF ( l_rf_status = rf.status_normal ) THEN
                            l_rf_status := update_rlc_inv(g_plogi_loc, g_pallet_id, l_home_slot_flag, 1);
                        END IF;

                    END IF; -- end rlc_flag = 'Y'

                    IF ( l_rf_status = rf.status_normal ) THEN
                        l_rf_status := update_put_trans;
                    END IF;
                    IF ( l_rf_status = rf.status_normal ) THEN
                        l_rf_status := delete_putaway_task(l_finish_good_po_flag);
                    END IF;

                    IF ( l_rf_status != rf.status_normal ) THEN
                        ROLLBACK TO s;
                        RETURN l_rf_status;
                    END IF;

                ELSE -- ERROR: PO is not OPEN or CLOSED 
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'PO is not in OPN or CLO or VCH status. erm_id = ' || g_erm_id, sqlcode, sqlerrm
                    , g_application_func, g_program_name);
                    l_rf_status := rf.status_inv_po;
                END IF; --End g_erm_status = 'OPN'

                IF ( l_rf_status = rf.status_normal ) THEN
                    IF ( g_ei_pallet = 'Y' ) THEN
                        l_rf_status := upd_cdk_xref_status(g_erm_id);
                        IF ( l_rf_status = rf.status_normal ) THEN
							BEGIN
								DELETE trans
								WHERE
									user_id = user
									AND trans_type = 'PPU'
									AND pallet_id = g_pallet_id_msku;
							EXCEPTION
								WHEN OTHERS THEN
								
									pl_text_log.ins_msg_async('WARN', l_func_name, ' unable to delete PPU tranaction for user_id = '||user
																		|| g_erm_id
																		|| ' pallet_id = '
																		|| g_pallet_id_msku
																		||' returns_lm_flag = '
																		||g_returns_lm_flag, sqlcode, sqlerrm, g_application_func, g_program_name);

							END;

                        ELSE --l_rf_status ! = normal
                            ROLLBACK TO s;
                            RETURN l_rf_status;
                        END IF; --End l_rf_status = rf.status_normal

                    ELSE -- g_ei_pallet != 'Y'
                        delete_ppu_trans(g_erm_id, g_pallet_id);
                    END IF; --End g_ei_pallet = 'Y'
                END IF;

                IF ( l_rf_status = rf.status_normal ) THEN
                    BEGIN
                        IF ( g_is_matrix_putaway > 0 ) THEN
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'Debug message for Matrix Change table for MSKUputaway. plogi_loc = '
                                                                || g_plogi_loc
                                                                || ' is_matrix_putaway = '
                                                                || g_is_matrix_putaway, sqlcode, sqlerrm, g_application_func, g_program_name);

							--check if the target location is matrix induction location 

                            SELECT
                                l.slot_type
                            INTO l_slot_type
                            FROM
                                lzone   lz,
                                zone    z,
                                loc     l
                            WHERE
                                lz.zone_id = z.zone_id
                                AND l.logi_loc = lz.logi_loc
                                AND l.logi_loc = g_plogi_loc
                                AND z.z_area_code = pl_matrix_common.f_get_pm_area(g_lv_prod_id)
                                AND l.slot_type IN (
                                    'MXI',
                                    'MXT'
                                )
                                AND z.zone_type = 'PUT'
                                AND z.rule_id = 5;

                            BEGIN
                                IF l_slot_type = 'MXT' THEN
                                    UPDATE inv
                                    SET
                                        mx_xfer_type = 'PUT'
                                    WHERE
                                        logi_loc = g_pallet_id;

                                END IF;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    l_rf_status := rf.status_inv_update_fail;
                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to update mx_xfer_type for inv for MSKUputaway. pallet_id = '
                                    || g_pallet_id, sqlcode, sqlerrm, g_application_func, g_program_name);
                                    RETURN l_rf_status;
                            END;

						--if target location is matrix induction location, insert record into matrix_out table

                            IF l_slot_type = 'MXI' THEN
                                SELECT
                                    COUNT(DISTINCT dest_loc)
                                INTO l_temp
                                FROM
                                    putawaylst
                                WHERE
                                    parent_pallet_id = g_pallet_id_msku;

                                IF ( l_temp > 1 ) THEN
                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Found multiple drop location for MSKU pallet, unable to send MSKU message SYS03. parent_pallet_id = '
                                    || g_pallet_id_msku, sqlcode, sqlerrm, g_application_func, g_program_name);
                                    l_rf_status := rf.status_putaway_fail;
                                    RETURN l_rf_status;
                                END IF;

                                l_temp := 0;
                                BEGIN
                                    l_sys_msg_id := mx_sys_msg_id_seq.nextval;
                                    SELECT
                                        i.prod_id,
                                        i.rec_id,
                                        i.qoh,
                                        p.spc,
                                        i.exp_date,
                                        i.status
                                    INTO
                                        l_prod_id,
                                        l_rec_id,
                                        l_qoh,
                                        l_spc,
                                        l_exp_date,
                                        l_inv_status
                                    FROM
                                        inv   i,
                                        pm    p
                                    WHERE
                                        i.prod_id = p.prod_id
                                        AND logi_loc = g_pallet_id;

                                    l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
																					i_interface_ref_doc=> 'SYS03',
																					i_label_type => 'LPN',  --MSKU
																					i_parent_pallet_id => NULL,
																					i_rec_ind => 'S', ---H OR D  
																					i_pallet_id => g_pallet_id,
																					i_prod_id => l_prod_id,
																					i_case_qty => trunc(l_qoh / l_spc),
																					i_exp_date=> l_exp_date,
																					i_erm_id => l_rec_id,
																					i_batch_id => mx_batch_no_seq.NEXTVAL,
																					i_trans_type => 'PUT',
																					i_inv_status => l_inv_status);

                                    IF l_ret_val = 1 THEN --failure
                                        l_temp := 1;
                                    ELSE
                                        pl_text_log.ins_msg('', 'putaway.pc', 'Insert into matrix_out completed for pallet_id = ' ||
                                        g_pallet_id, sqlcode, sqlerrm);
                                        l_temp := 0;
                                        l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);
                                        IF l_ret_val = 1 THEN --failure
                                            l_temp := 1;
                                        END IF;
                                    END IF; -- end l_ret_val = 1 

                                EXCEPTION
                                    WHEN NO_DATA_FOUND THEN
                                        l_temp := 1;
                                    WHEN OTHERS THEN
                                        l_temp := 1;
                                END;

                                IF ( l_temp = 1 ) THEN
                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = matrix_out. Unable to insert detail record into matrix_out table for MSKUputaway. parent_pallet_id = '
                                    || g_pallet_id_msku, sqlcode, sqlerrm, g_application_func, g_program_name);
                                    l_rf_status := rf.status_insert_fail;
                                    RETURN l_rf_status;
                                END IF;

                            END IF; --End l_slot_type = 'MXI'

                        END IF; -- End g_is_matrix_putaway > 0 

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to find slot_type of matrix location for putaway. plogi_loc = '
                            || g_plogi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);
                            l_rf_status := rf.status_sel_loc_fail;
                            RETURN l_rf_status;
                    END;
                END IF; --End l_rf_status = rf.status_normal
                FETCH c_child_pallets INTO g_pallet_id;
                EXIT WHEN c_child_pallets%notfound;
            END LOOP;
            COMMIT;
            CLOSE c_child_pallets;
            RETURN l_rf_status;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' FUNC1: c_child_pallets found no child records in putawaylst for dest_loc and parent_pallet_id. parent_pallet_id = '
                || g_pallet_id_msku, sqlcode, sqlerrm, g_application_func, g_program_name);
                l_rf_status := rf.status_inv_location;
                RETURN l_rf_status;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'FUNC1:Unable open cursor c_child_pallets parent_pallet_id = ' || g_pallet_id_msku
                , sqlcode, sqlerrm, g_application_func, g_program_name);
                l_rf_status := rf.status_inv_location;
                RETURN l_rf_status;
        END;
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Leaving mskuputaway. rf_status = '||l_rf_status, sqlcode, sqlerrm, g_application_func, g_program_name);
        RETURN l_rf_status;
    END mskuputaway; -- end MSKUPutaway 
	
	
  /*******************************<+>******************************************
  **
  **  Function
  **    gt_syspar_rpl_aftr_ech_ptaway
  **  CALLED BY: find_pending_replen_tasks
  **  Parameters
  **     o_syspar_value - The value of the syspar determined by this function.
  **    
  **  Description
  **    This function gets the value of syspar RPL_AFTER_EACH_PUTAWAY
  **  RETURN value
  **		l_rf_status code
  ********************************<->******************************************/

    FUNCTION gt_syspar_rpl_aftr_ech_ptaway (
        o_syspar_value OUT sys_config.config_flag_val%TYPE
    ) RETURN rf.status IS

        l_func_name      VARCHAR2(50) := 'gt_syspar_rpl_aftr_ech_ptaway';
        lcl_syspar_val   sys_config.config_flag_val%TYPE;
        l_rf_status        rf.status := rf.status_normal;
    BEGIN
        lcl_syspar_val := pl_common.f_get_syspar('RPL_AFTER_EACH_PUTAWAY', 'x');
        IF lcl_syspar_val = 'x' THEN
            l_rf_status := rf.status_sel_syscfg_fail;
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Select config_flag_val RPL_AFTER_EACH_PUTAWAY failed.',
				sqlcode, sqlerrm, g_application_func, g_program_name);
        ELSE
            l_rf_status := rf.status_normal;
            o_syspar_value := lcl_syspar_val;
        END IF;
		
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Leaving gt_syspar_rpl_aftr_ech_ptaway. rf_status = '||l_rf_status,
			sqlcode, sqlerrm, g_application_func, g_program_name);
		
        RETURN l_rf_status;
		
    END gt_syspar_rpl_aftr_ech_ptaway;
	
	 /*******************************<+>******************************************
  **  Function:
  **     calc_exp_dt_for_shlf_lfe_item
  **
  **  Description:
  **     This function calculates the expiration to use for the LP for
  **     a non-date tracked item and the item has shelf lifes.
  **     Global variable g_vc_exp_date is populated with the
  **     expiration date.
  **  CALLED BY: get_product_info
  **  Parameters:
  **     pallet_id   - Pallet id being processed.  It will be the parent
  **                     pallet id for a MSKU pallet.
  **                     IT MUST BE NULL TERMINATED.
  **
  **  RETURN Values:
  **     None
  ******************************************************************************/

    FUNCTION calc_exp_dt_for_shlf_lfe_item RETURN rf.status IS
        l_func_name   VARCHAR2(50) := 'calc_exp_dt_for_shlf_lfe_item';
        l_rf_status   rf.status := rf.status_normal;
    BEGIN
        IF ( g_mfg_ind = 'C' ) THEN
		  /*
		  ** Manufacturer date tracked item.
		  ** Do nothing.
		  */
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Manufacturer date tracked item. mfg_ind = ' || g_mfg_ind,
				sqlcode, sqlerrm, g_application_func, g_program_name);
        ELSIF ( g_exp_ind = 'C' ) THEN
		  /*
		  ** Expiration date tracked item.
		  ** Do nothing.
		  */
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Expiration date tracked item. exp_ind = ' || g_exp_ind,
				 sqlcode, sqlerrm, g_application_func, g_program_name);
        ELSE --g_mfg_ind ! = c and g_exp_ind != C
            BEGIN
                IF ( ( g_sysco_shelf_life != 0 ) AND ( g_cust_shelf_life != 0 ) ) THEN
                    g_shelf_life := g_sysco_shelf_life + g_cust_shelf_life;
                ELSIF ( g_mfr_shelf_life != 0 ) THEN
                    g_shelf_life := g_mfr_shelf_life;
                ELSE
                    g_shelf_life := 0;

              /*
              ** Set g_vc_exp_date to the expiration date.  All places in the
              ** program expect g_vc_exp_date to have the expiration date for
              ** the LP.
              */
                    SELECT
                        to_char(trunc(sysdate) + g_shelf_life, 'DD-MON-YYYY')
                    INTO g_vc_exp_date
                    FROM
                        dual;

                    g_s_exp_date_ind := 0;
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'setting g_vc_exp_date to SYSDATE + shelf_life failed. plogi_loc = '
                                                        || g_plogi_loc
                                                        || ' logi_loc = '
                                                        || g_logi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

                    l_rf_status := rf.status_inv_update_fail;
                    RETURN l_rf_status;
            END;
        END IF; -- end g_mfg_ind = 'C'
		
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Leaving calc_exp_dt_for_shlf_lfe_item. rf_status = '||l_rf_status,
				sqlcode, sqlerrm, g_application_func, g_program_name);
		
        RETURN l_rf_status;
		
    END calc_exp_dt_for_shlf_lfe_item;
	
  /**************************************************************************
  #   PROCEDURE : Get_front_or_back_loc
  #   CALLED BY: get_rf_info
  #   Input    : A location, pointer to a character string, and a option
  #   Output   : Front or back side location looked up from loc_reference table
  #
  #   Option values :   1 Will look up the front location. In this case the
  #                     calling function will pass in the back location.
  #   Option values :   2 Will look up the back location. In this case the
  #                     calling function will pass in the front location.
  ****************************************************************************/

    PROCEDURE get_front_or_back_loc (
        i_in_plogi_loc    IN    loc_reference.plogi_loc%TYPE,
        o_out_plogi_loc   OUT   loc_reference.plogi_loc%TYPE,
        i_options         IN    NUMBER,
        i_n_func          IN    NUMBER,
        o_rc              OUT   NUMBER
    ) IS

        l_func_name          VARCHAR2(50) := 'Get_front_or_back_loc';
        func_name            VARCHAR2(15);
        side                 VARCHAR2(6);
        l_cl_in_plogi_loc    loc_reference.plogi_loc%TYPE;
        l_cl_out_plogi_loc   loc_reference.plogi_loc%TYPE;
    BEGIN
        l_cl_in_plogi_loc := i_in_plogi_loc;
        CASE i_n_func
            WHEN 1 THEN
                func_name := 'PUTAWAY';
            WHEN 2 THEN
                func_name := 'CLOSE_PO';
            WHEN 3 THEN
                func_name := 'DMD_REPLENISH';
            WHEN 4 THEN
                func_name := 'NDM_REPLENISH';
            ELSE
                func_name := 'DFLT_FUNC';
        END CASE;

        CASE i_options
            WHEN 1 THEN
                side := 'Front';
                SELECT
                    plogi_loc
                INTO l_cl_out_plogi_loc
                FROM
                    loc_reference
                WHERE
                    bck_logi_loc = rtrim(l_cl_in_plogi_loc);

                o_rc := sqlcode;
            WHEN 2 THEN
                side := 'Back';
                SELECT
                    bck_logi_loc
                INTO l_cl_out_plogi_loc
                FROM
                    loc_reference
                WHERE
                    plogi_loc = rtrim(l_cl_in_plogi_loc);

                o_rc := sqlcode;
            ELSE
                o_rc := -1;
                pl_text_log.ins_msg_async('WARN', l_func_name, 'option has an unhandled value of ' || i_options,
				sqlcode, sqlerrm, g_application_func, g_program_name);
        END CASE;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Found '
                                            || side
                                            || ' side location. in_plogi_loc = '
                                            || l_cl_in_plogi_loc
                                            || ' out_plogi_loc = '
                                            || l_cl_out_plogi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

        o_out_plogi_loc := l_cl_out_plogi_loc;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, ' No '
                                                || side
                                                || ' side location exist for this location. in_plogi_loc = '
                                                || l_cl_in_plogi_loc, sqlcode, sqlerrm, g_application_func, g_program_name);

            o_rc := sqlcode;
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'error looking for front/back location.', sqlcode, sqlerrm, g_application_func, g_program_name);
            o_rc := sqlcode;
    END get_front_or_back_loc;

  /**************************************************************************
  **   FUNCTION : check_suspend
  **  CALLED BY: putaway_service
  **  DESCRIPTION: This function checks for a suspended batch 
  **				when forklift labor mgmt is active.
  **  Input    : i_user_id
  **			 i_equip_id
  ** RETURN value :
  **		l_rf_status code
  ****************************************************************************/

    FUNCTION check_suspend (
        i_user_id    IN   batch.user_id%TYPE,
        i_equip_id   IN   equip.equip_id%TYPE
    ) RETURN rf.status IS

        l_func_name            VARCHAR2(50) := 'check_suspend';
        l_ret_val              rf.status := rf.status_normal;
        l_suspended_batch_no   batch.batch_no%TYPE;
        l_parent_batch_no      batch.parent_batch_no%TYPE;
        l_prev_batch_no        batch.batch_no%TYPE;
        l_supervisor_id        batch.user_supervsr_id%TYPE;
    BEGIN
	  
	 --Only check for a suspended batch when forklift labor mgmt is active.
	
        IF ( pl_lm_forklift.lmf_forklift_active() = rf.status_normal ) THEN
            l_suspended_batch_no := ' ';
            l_ret_val := pl_lm_forklift.lmf_find_suspended_batch(i_user_id, l_suspended_batch_no);
            IF ( l_ret_val = rf.status_no_lm_batch_found ) THEN
                l_ret_val := rf.status_normal;
            ELSIF ( l_ret_val = rf.status_normal ) THEN
				  				  
					  -- Reactivates the suspended batch.					
                l_supervisor_id := ' ';
                l_prev_batch_no := ' ';
                l_ret_val := pl_rf_lm_common.lmc_batch_istart(i_user_id, l_prev_batch_no, l_supervisor_id);
                IF ( l_ret_val = rf.status_normal ) THEN
                    l_parent_batch_no := ' ';
                    l_ret_val := pl_lm_forklift.lmf_signon_to_forklift_batch(LMF_SIGNON_BATCH, l_suspended_batch_no, l_parent_batch_no,
																i_user_id, l_supervisor_id, i_equip_id);
                                            
                END IF;

            END IF;

        END IF; --forklift labor mgmt validation

        RETURN l_ret_val;
    END check_suspend;

  /**************************************************************************
  **   PROCEDURE : get_po_info
  **  CALLED BY: drop_haul_pallet,mskuputaway,putaway_service
  **  DESCRIPTION: This function checks PO related information.
  **  
  ** RETURN value :
  **		None
  ****************************************************************************/

    PROCEDURE get_po_info IS
        l_func_name   VARCHAR2(50) := 'Get_po_info';
        l_dummy       VARCHAR2(1);
    BEGIN
        SELECT
            e.status,
            e.erm_id,
            e.erm_type,
            e.warehouse_id
        INTO
            g_erm_status,
            g_erm_id,
            g_erm_type,
            g_warehouse_id
        FROM
            erm          e,
            putawaylst   p
        WHERE
            e.erm_id = p.rec_id
            AND p.pallet_id = g_pallet_id;

        IF g_erm_status  NOT IN ('OPN','CLO','VCH') THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = erm,putawaylst. PO not in OPN or CLO or VCH status. pallet_id = ' || g_pallet_id,
				sqlcode, sqlerrm, g_application_func, g_program_name);
            
        ELSE
				-- Check if the LP is msku pallet from return 
            BEGIN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = erm,erd,putawaylst. pallet_id = '
                                                    || g_pallet_id
                                                    || ' PO status = '
                                                    || g_erm_status, sqlcode, sqlerrm, g_application_func, g_program_name);

                SELECT
                    'x'
                INTO l_dummy
                FROM
                    erm          e,
                    putawaylst   p
                WHERE
                    e.erm_type = 'CM'
                    AND p.pallet_id = g_pallet_id
                    AND p.parent_pallet_id LIKE 'T%'
                    AND e.erm_id = p.rec_id
                    AND e.erm_id = erm_id;

                g_returns_lm_flag := 'Y';
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = erm. PO is not return LM track. pallet_id = ' || g_pallet_id,
						sqlcode, sqlerrm, g_application_func, g_program_name);                    
                    g_returns_lm_flag := 'N';
            END;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Table = erd,erm,putawaylst. selection of receipt support information for putaway task failed. pallet_id = '
			|| g_pallet_id, sqlcode, sqlerrm, g_application_func, g_program_name);
    END get_po_info;

 /*******************************<+>******************************************
  **  PROCEDURE:
  **     delete_PPU_trans
  **
  **  Description:
  **     This function deletes the PPU transaction for a pallet.
  **
  **  Parameters:
  **	 i_erm_id	
  **     i_pallet_id
  **  Return Values:
  **     None
  ****************************************************************************/

    PROCEDURE delete_ppu_trans (
        i_erm_id      IN   erm.erm_id%TYPE,
        i_pallet_id   IN   putawaylst.pallet_id%TYPE
    ) IS

        l_func_name   VARCHAR2(50) := 'delete_PPU_trans';
        l_erm_id      erm.erm_id%TYPE;
        l_pallet_id   putawaylst.pallet_id%TYPE;
    BEGIN
        l_erm_id := i_erm_id;
        l_pallet_id := i_pallet_id;
        IF ( g_returns_lm_flag = 'Y' ) THEN
            DELETE trans
            WHERE
                user_id = user
                AND pallet_id = l_pallet_id
                AND trans_type = 'PPU';

        ELSE
            DELETE trans
            WHERE
                user_id = user
                AND rec_id = l_erm_id
                AND pallet_id = l_pallet_id
                AND trans_type = 'PPU';
       END IF;
	EXCEPTION
		WHEN OTHERS THEN
			pl_text_log.ins_msg_async('WARN', l_func_name, ' unable to delete PPU tranaction for user_id. erm_id = '
                                                    || l_erm_id
                                                    || ' pallet_id = '
                                                    || l_pallet_id
                                                    || ' returns_lm_flag = '
                                                    || g_returns_lm_flag, sqlcode, sqlerrm, g_application_func, g_program_name);

    END delete_ppu_trans; -- end delete_PPU_trans 
    
  /*******************************************************************
  **  Function:  check_reserve_loc
  **
  **  Description: This function checks for RLC location
  ** CALLED BY: put_away
  **  RETURN value:
  **        l_rf_status code
  ******************************************************************/

    FUNCTION check_reserve_loc RETURN rf.status IS

        l_func_name   VARCHAR2(50) := 'check_reserve_loc';
        l_rf_status     rf.status := rf.status_normal;
        l_dummy       VARCHAR2(1);
        l_locstat     loc.status%TYPE;
    BEGIN
        IF ( g_putaway_client.rlc_flag = 'Y' ) THEN
            BEGIN
                SELECT
                    'x'
                INTO l_dummy
                FROM
                    loc l
                WHERE
                    l.perm = 'Y'
                    AND l.logi_loc = g_rlc_loc;

                pl_text_log.ins_msg_async('WARN', l_func_name, 'Attempt to direct to a permanent pick slot not the home slot. rlc_loc = ' ||
                g_rlc_loc, sqlcode, sqlerrm, g_application_func, g_program_name);
                l_rf_status := rf.status_inv_location;
                SELECT
                    status
                INTO l_locstat
                FROM
                    loc
                WHERE
                    logi_loc = g_rlc_loc;

                IF ( l_locstat = 'DMG' ) THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'RLC LOC unavailable,Location is Damaged. rlc_loc = ' || g_rlc_loc,
						sqlcode, sqlerrm, g_application_func, g_program_name);                    
                    RETURN rf.status_loc_damaged;
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, ' select of RLC location  failed.rlc_loc = ' || g_rlc_loc,
						sqlcode, sqlerrm, g_application_func, g_program_name);                    
                    RETURN rf.status_inv_location;
            END;
        ELSE -- rlc_flag!= Y
            BEGIN
                SELECT
                    'x'
                INTO l_dummy
                FROM
                    loc l
                WHERE
                    l.perm = 'Y'
                    AND l.logi_loc = nvl(g_bck_dest_loc, g_des_loc);

                pl_text_log.ins_msg_async('INFO', l_func_name, 'Attempt to direct to a permanent pick slot not the home slot. dest_loc = ' || g_des_loc,
					sqlcode, sqlerrm, g_application_func, g_program_name);
                l_rf_status := rf.status_inv_location;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'select failed. dest_loc = ' || g_des_loc, sqlcode, sqlerrm, g_application_func, g_program_name);
            END;
        END IF;

        RETURN l_rf_status;
    END check_reserve_loc;

END pl_rf_putaway;
/

GRANT EXECUTE ON pl_rf_putaway TO swms_user;
