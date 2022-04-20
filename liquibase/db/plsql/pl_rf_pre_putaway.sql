create or replace PACKAGE pl_rf_pre_putaway AS
/*******************************************************************************
**Package:
**        pl_rf_pre_putaway. Migrated from pre_putaway.pc
**
**Description:
**       Function pre_putaway service.
**
**Called by:
**        This package is called from java web service.
*******************************************************************************/
    FUNCTION pre_putaway_main(
        i_rf_log_init_record        IN      rf_log_init_record,
        i_client_obj                IN      pre_putaway_client_obj,
        o_server	                OUT	    pre_putaway_server_obj
        )RETURN rf.STATUS;
    
    FUNCTION pre_putaway_msku(
    i_rf_log_init_record        	IN      rf_log_init_record,
    i_client_obj                	IN      pre_putaway_client_obj,
    o_msku_server  	            	OUT	    pre_putaway_MSKU_server_obj,
    o_add_msg_server            	OUT     add_msg_server_result_obj)RETURN rf.STATUS;
    
    FUNCTION preputaway RETURN rf.STATUS;
    
    FUNCTION func1_for_returns (
        i_batch_no       IN batch.parent_batch_no%TYPE,
        i_batch_no_len   IN NUMBER,
        i_merge_flag     IN VARCHAR2,
        i_dest_loc       IN putawaylst.dest_loc%TYPE,
        i_credit_memo    IN putawaylst.rec_id%TYPE,
        i_user_id        IN VARCHAR2) RETURN rf.status; 
      
        
    FUNCTION attach_to_fklift_putaway_batch (
        i_user_id        IN batch.user_id%TYPE,
        i_equip_id       IN equip.equip_id%TYPE,
        i_pallet_id      IN putawaylst.pallet_id%TYPE,
        i_haul_flag      IN VARCHAR2,
        i_merge_flag     IN VARCHAR2,
        i_put_batch_no   IN batch.batch_no%TYPE) RETURN rf.status;    
        
    FUNCTION reset_forklift_batch(
        i_user_id       IN      VARCHAR2, 
        i_equip_id      IN      equip.equip_id%TYPE,
        i_drop_loc      IN      VARCHAR2, 
        i_haul_flag     IN      VARCHAR2)RETURN rf.STATUS;
        
    FUNCTION Check_Scan_Loss  RETURN rf.STATUS;
    
    FUNCTION vldt_and_populate_msku_info RETURN rf.STATUS;
    
    PROCEDURE set_labor_mgmt_flags(
            o_lbr_mgmt_flag             OUT 	VARCHAR2,
            o_cte_rtn_put_batch_flag    OUT 	VARCHAR2);
    
    FUNCTION get_pallet_id_on_batch(
        i_batch_no      IN 		batch.parent_batch_no%TYPE,
        i_batch_no_len  IN 		NUMBER,
        o_pallet_id     OUT 	putawaylst.pallet_id%TYPE,
        i_merge_flag    IN 		VARCHAR2) RETURN rf.STATUS;
END pl_rf_pre_putaway;
/

create or replace PACKAGE BODY pl_rf_pre_putaway AS

  ------------------------------------------------------------------------------
/*       CONSTANT VARIABLES FOR PRE PUTAWAY FUNCTIONS                  */
  ------------------------------------------------------------------------------ 

    NUM_PALLETS_MSKU         CONSTANT NUMBER := 60;
    NORMAL                   CONSTANT NUMBER := 0;
    MSKU_LP_LIMIT_ERROR      CONSTANT NUMBER := 338;
    PUTAWAY                  CONSTANT NUMBER := 1;
	ORACLE_NOT_FOUND         CONSTANT NUMBER := 1403;
	
	LMF_SIGNON_BATCH    VARCHAR2(1) := 'N';
    LMF_MERGE_BATCH     VARCHAR2(1) := 'M';
    LMF_SUSPEND_BATCH   VARCHAR2(1) := 'S';
	
	HAUL_BATCH_ID       VARCHAR2(1) := 'H';
    FORKLIFT_BATCH_ID   VARCHAR2(1) := 'F';
    FORKLIFT_PUTAWAY    VARCHAR2(1) := 'P';
	
  ------------------------------------------------------------------------------
/*                      GLOBAL DECLARATIONS                                */
  ------------------------------------------------------------------------------
  
    g_pallet_count           NUMBER;
    g_returns_flag           VARCHAR2(1);
    g_msku                   VARCHAR2(1);
    g_loss_prev_created      NUMBER := 0;
    g_server                 pre_putaway_server_obj := pre_putaway_server_obj(' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ');
    g_client_obj             pre_putaway_client_obj;
    g_msku_server            pre_putaway_msku_server_obj := pre_putaway_msku_server_obj(' ',' ',' ',' ',' ',' ',' ',' ',' ',' ');
    g_add_msg_server         add_msg_server_result_obj;
    g_add_msg_result_table   add_msg_result_table := add_msg_result_table ();
    g_erm_id                 erm.erm_id%type;
    g_erm_type               erm.erm_type%type;
    g_prod_id                putawaylst.prod_id%TYPE;
	
  /*************************************************************************
    NAME:  pre_putaway_main
    CALLED BY: Java web service
    DESC:  Pre putaway service
  
    PARAMETERS:
      i_rf_log_init_record -- Object to get the RF status
      i_client_obj		 --  client message
      o_server			 --  server message
    OUTPUT Parameters:   
	rf.status - Output value returned by the package
	
     DATE          USER                COMMENT                             
    11/21/2019     CHYD9155      Created pre_putaway_main                 
    
  **************************************************************************/

    FUNCTION pre_putaway_main (
        i_rf_log_init_record   IN 	rf_log_init_record,
        i_client_obj           IN 	pre_putaway_client_obj,
        o_server               OUT 	pre_putaway_server_obj
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'pre_putaway_main';
        rf_status     rf.status := rf.status_normal;
    BEGIN
        rf_status := rf.initialize(i_rf_log_init_record);
        IF rf_status = rf.status_normal THEN
            pl_text_log.ins_msg_async('INFO',l_func_name,'Starting pre_putaway',sqlcode,sqlerrm);
			pl_text_log.ins_msg_async('INFO',l_func_name,'Input from scanner. pallet_id = '
															||i_client_obj.pallet_id
															||' equip_id = '
															||i_client_obj.equip_id
															||' batch_no = '
															||i_client_obj.batch_no
															||' regular_putaway = '
															||i_client_obj.regular_putaway
															||' merge_flag = '
															||i_client_obj.merge_flag
															||' func1_flag = '
															||i_client_obj.func1_flag
															||' haul_flag = '
															||i_client_obj.haul_flag
															||' drop_loc = '
															||i_client_obj.drop_loc,sqlcode,sqlerrm);
            g_client_obj := i_client_obj;
            g_msku := 'N';
            g_pallet_count := 0;
            rf_status := preputaway;
            IF rf_status = rf.status_normal OR g_loss_prev_created = 1 THEN
                COMMIT;
            ELSE
                ROLLBACK;
            END IF;

            pl_text_log.ins_msg_async('INFO',l_func_name,'Ending pre_putaway_main',sqlcode,sqlerrm);
        END IF;

        o_server := g_server;
        rf.complete(rf_status);
        RETURN rf_status;
    EXCEPTION
        WHEN OTHERS THEN
			pl_text_log.ins_msg_async('FATAL',l_func_name, 'Call to preputaway failed', sqlcode, sqlerrm);
            rf.logexception (); -- log it
            RAISE;
    END pre_putaway_main;
	
  /*************************************************************************
    NAME:  pre_putaway_msku
    CALLED BY: Java web service
    DESC:  Pre putaway msku service
  
    PARAMETERS:
      i_rf_log_init_record   -- Object to get the RF status
      i_client_obj		     --  client message
      o_msku_server			 --  server message
	  o_add_msg_server		 -- add_msg_preputaway_server message
    OUTPUT Parameters:   rf.status - Output value returned by the package
     
  **************************************************************************/

    FUNCTION pre_putaway_msku (
        i_rf_log_init_record   IN 	rf_log_init_record,
        i_client_obj           IN 	pre_putaway_client_obj,
        o_msku_server          OUT 	pre_putaway_msku_server_obj,
        o_add_msg_server       OUT 	add_msg_server_result_obj
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'pre_putaway_msku';
        rf_status     rf.status := rf.status_normal;
    BEGIN
        rf_status := rf.initialize(i_rf_log_init_record);
        IF rf_status = rf.status_normal THEN
            pl_text_log.ins_msg_async('INFO',l_func_name,' Starting pre_putaway_msku',sqlcode,sqlerrm);
			pl_text_log.ins_msg_async('INFO',l_func_name,'Input from scanner. pallet_id = '
															||i_client_obj.pallet_id
															||' equip_id = '
															||i_client_obj.equip_id
															||' batch_no = '
															||i_client_obj.batch_no
															||' regular_putaway = '
															||i_client_obj.regular_putaway
															||' merge_flag = '
															||i_client_obj.merge_flag
															||' func1_flag = '
															||i_client_obj.func1_flag
															||' haul_flag = '
															||i_client_obj.haul_flag
															||' drop_loc = '
															||i_client_obj.drop_loc,sqlcode,sqlerrm);
            g_client_obj := i_client_obj;
            g_msku := 'Y';
            g_pallet_count := 0;
            rf_status := preputaway;
            IF rf_status = rf.status_normal OR g_loss_prev_created = 1 THEN
                COMMIT;
            ELSE
                ROLLBACK;
            END IF;

        END IF;

        o_msku_server := g_msku_server;
        o_add_msg_server := g_add_msg_server;
        pl_text_log.ins_msg_async('INFO',l_func_name,'Ending pre_putaway_msku',sqlcode,sqlerrm);
        rf.complete(rf_status);
        RETURN rf_status;
    EXCEPTION
        WHEN OTHERS THEN
			pl_text_log.ins_msg_async('FATAL',l_func_name, 'Call to preputaway failed', sqlcode, sqlerrm);
            rf.logexception (); -- log it
            RAISE;
    END pre_putaway_msku;
	
  /*************************************************************************
    NAME:  preputaway
    CALLED BY:pre_putaway_main() and pre_putaway_msku()
    DESC:  Pre putaway service
  
    OUTPUT Parameters:   rf_status 

    MODIFICATION LOG:

    Date           Developer      Comment    
    ------------------------------------------------------------------------
    17-Mar-2021    pkab6563       Jira 3173 - Added condition to call
                                  attach_to_fklift_putaway_batch() for
                                  returns putaway as well. Also added
                                  l_regular_put local variable to be used
                                  in place of the regular_putaway flag from
                                  the client. The client sends Y even for
                                  returns putaway since they are done from the 
                                  same RF screen. It needs to be N for 
                                  returns putaway.

    28-Jul-2021   pkab6563        Jira 3562 - Fixed condition to set
                                  g_returns_flag. It was not getting set to
                                  Y for returns puts when flag to create
                                  return batches in lbr_func was turned off.
  
  **************************************************************************/

    FUNCTION preputaway RETURN rf.status AS

        l_func_name                   VARCHAR2(50) := 'preputaway';
        l_pallet_check_flag           NUMBER := 0; 						/* For Pallet_id comparision */
        l_put_path_val                loc.put_path%TYPE;
        l_strip_put                   loc.put_aisle%TYPE;
        l_strip_slot                  loc.put_slot%TYPE;
        l_strip_level                 loc.put_level%TYPE;
        l_temp_pallet_id              putawaylst.pallet_id%TYPE;
        l_upc_comp_flag               VARCHAR2(1) := ' ';
        l_upc_scan_function           VARCHAR2(1) := ' ';
        l_cdk_status                  VARCHAR2(1);						/*  Cross Dock  Pallet Status  Y/N */
        rf_status                     rf.status := rf.status_normal;
        l_pallet_id                   putawaylst.pallet_id%TYPE;
        l_src_loc                     trans.src_loc%TYPE;
        l_dest_loc                    putawaylst.dest_loc%TYPE;
        l_equip_id                    equip.equip_id%TYPE;
        l_put                         putawaylst.putaway_put%TYPE;
        dummy                         VARCHAR2(8);
        dummy1                        VARCHAR2(18);
        dummy2                        VARCHAR2(13);
        dummy3                        VARCHAR2(30);
        l_qty_rec                     putawaylst.qty_received%TYPE;
        l_spc                         pm.spc%TYPE;
        l_put_aisle                   loc.put_aisle%TYPE;
        l_put_slot                    loc.put_slot%TYPE;
        l_put_level                   loc.put_level%TYPE;
        l_prod_id                     putawaylst.prod_id%TYPE;
        l_cust_pref_vendor            pm.cust_pref_vendor%TYPE;
        l_rlc_loc                     loc.logi_loc%TYPE;
        l_rlc_flag                    VARCHAR2(1);
        l_rtn_putaway_conf            VARCHAR2(1);					/* Returns Putaway Confirmation flag */
        l_rec_id                      putawaylst.rec_id%TYPE;
        l_door_no                     erm.door_no%TYPE;
        l_exp_date                    putawaylst.exp_date%TYPE;
        l_uom                         putawaylst.uom%TYPE;
        l_p_batch_no                  batch.batch_no%TYPE;
        l_batch_no                    batch.batch_no%TYPE;
        l_lbr_mgmt_flag               VARCHAR2(1);
        l_cte_rtn_put_batch_flag      lbr_func.create_batch_flag%TYPE;
        l_cte_forklift_batch_flag     VARCHAR2(1);
        l_pallet_cnt                  NUMBER := 0;
        l_inv_status                  putawaylst.inv_status%TYPE;
        l_exp_date_trk                putawaylst.exp_date_trk%TYPE;
        l_mfg_date_trk                putawaylst.date_code%TYPE;
        l_force_date_collect_flag     VARCHAR2(1);
        l_merge_flag                  VARCHAR2(1);
--        l_erm_type                    erm.erm_type%TYPE;
        l_to_wh_id                    erm.warehouse_id%TYPE;
        l_put_batch_no                putawaylst.pallet_batch_no%TYPE;
        l_qty_zero_flag               VARCHAR2(1) := ' ';
        l_hi_msku                     NUMBER;
        l_host_num_pallets_msku       NUMBER := NUM_PALLETS_MSKU;
        l_host_status_normal          NUMBER := NORMAL;
        l_host_status_msku_lp_limit   NUMBER := MSKU_LP_LIMIT_ERROR;
        l_descrip                     VARCHAR2(30);
        l_ml_flag                     VARCHAR2(1);					/* Putaway task dest loc is the miniloader induction location, Y or N */
        l_mx_flag                     VARCHAR2(1);					/* Putaway task dest loc is the matrix induction location, Y or N */
        l_regular_put                 VARCHAR2(1);

    BEGIN
        pl_text_log.ins_msg_async('INFO',l_func_name,'Starting preputaway service',sqlcode,sqlerrm);

        l_regular_put := g_client_obj.regular_putaway;
        g_erm_type := NULL;
        g_erm_id := NULL;

		/*
		**  Retrieve pallet_id from msg
		*/
        l_pallet_id := g_client_obj.pallet_id;
        l_equip_id := g_client_obj.equip_id;
        l_p_batch_no := g_client_obj.batch_no;

        BEGIN

            SELECT
                e.erm_id,
                e.erm_type, 
                p.prod_id, 
                p.pallet_batch_no, 
                p.qty_received,
                p.dest_loc,
                p.putaway_put,
                1,
                p.inv_status,
                lpad(ltrim(rtrim(TO_CHAR(l.put_aisle) ) ),3,'0'),
                lpad(ltrim(rtrim(TO_CHAR(l.put_slot) ) ),3,'0'),
                lpad(ltrim(rtrim(TO_CHAR(l.put_level) ) ),3,'0'),
                p.uom,
                p.cust_pref_vendor,
                pl_ml_common.f_is_induction_loc(p.dest_loc)
            INTO
                g_erm_id,
                g_erm_type,
                g_prod_id, 
                l_put_batch_no, 
                l_qty_rec,
                l_dest_loc,
                l_put,
                l_spc,
                l_inv_status,
                l_put_aisle,
                l_put_slot,
                l_put_level,
                l_uom,
                l_cust_pref_vendor, 
                l_ml_flag
           FROM erm          e,
                putawaylst   p, 
                loc l
            WHERE
                e.erm_id = p.rec_id
            AND p.dest_loc = l.logi_loc(+)
            AND ( p.pallet_id = l_pallet_id
             OR p.parent_pallet_id = l_pallet_id );


          IF ( g_erm_type = 'XN' ) THEN

              pl_text_log.ins_msg_async('WARN',l_func_name,'X-dock pallet. Use X-Dock Putaway.',sqlcode,sqlerrm);
              rf_status:=RF.STATUS_XDOCK_PUT_REQUIRE;
              return rf_status;            

          END IF;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to retrieve ERM id and ERM type.',sqlcode,sqlerrm);
		rf_status:=check_scan_loss;
                return rf_status;
        END;
  
		/*  Check the LP is MSKU or not and set the flag accordingly */
        BEGIN

            IF pl_msku.f_is_msku_pallet(l_pallet_id,'P') THEN

                l_hi_msku := 1; /*Valid MSKU pallet */
                                /* Make sure MSKU pallet is not too large */
                IF ( g_erm_type = 'XN' OR ( g_erm_type = 'CM' AND g_erm_id LIKE 'X%' )) THEN

                    rf_status := l_host_status_normal;
                    l_pallet_cnt := 1;

                ELSE

                    pl_msku.p_is_msku_too_large(l_pallet_id,l_host_num_pallets_msku,l_host_status_normal,l_host_status_msku_lp_limit,
                    rf_status,l_pallet_cnt);

                    /*Force to subdivide MSKU, if MSKU have child pallets for both Symbotic induction and warehouse */
                    IF rf_status = l_host_status_normal THEN
                        pl_msku.p_is_msku_symb_multi_loc(l_pallet_id,l_host_status_normal,l_host_status_msku_lp_limit,rf_status);
                    END IF;

                END IF;

            ELSE
                l_hi_msku := 0; /*NON MSKU LP */
                rf_status := l_host_status_normal;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'pl_msku returned error code = ' || sqlcode,sqlcode,sqlerrm);
        END;

        pl_text_log.ins_msg_async('INFO',l_func_name,'Count MSKU LPs for '
                                            || l_pallet_id
                                            || ' Status = '
                                            || rf_status
                                            || ' count = '
                                            || l_pallet_cnt,sqlcode,sqlerrm);


        IF rf_status != rf.status_normal THEN

            IF g_msku = 'N' THEN

                g_server.pallet_cnt := rf.NoNull(l_pallet_cnt);

            ELSE

                g_msku_server.pallet_cnt := rf.NoNull(l_pallet_cnt);

            END IF;

            IF ( g_erm_type = 'XN' OR ( g_erm_type = 'CM' AND g_erm_id LIKE 'X%' )) THEN 

                rf_status := l_host_status_normal;

              ELSE

                RETURN rf_status;

            END IF;

        END IF;

		/* 
		** Check if the scanned pallet is EI or not, If EI, perform actions related to 
		** EI by calling validate_cross_dock_pallet method 
		*/

        l_cdk_status := pl_rcv_cross_dock.f_is_crossdock_pallet(l_pallet_id,'P');

		/*
		**  Determine whether or not the receipt is a return.
		**   
		*/

        g_returns_flag := 'N';

        BEGIN
            IF ( g_erm_type = 'XN' ) THEN 

                IF g_client_obj.regular_putaway != 'Y' THEN
                    IF g_client_obj.func1_flag != 'Y' THEN
                        RETURN rf.status_inv_putaway_opt;
                    END IF;
                ELSE
                    pl_text_log.ins_msg_async('INFO',l_func_name,'PO is not a return on NO_DATA_FOUND.',sqlcode,sqlerrm);
                    g_returns_flag := 'N';
                END IF;

            ELSIF ( g_erm_type = 'CM' ) THEN 

                -- putaway is for a return
                g_returns_flag := 'Y';
                l_regular_put  := 'N';
    
                set_labor_mgmt_flags(l_lbr_mgmt_flag,l_cte_rtn_put_batch_flag);                

            ELSE
                SELECT
                    'x'
                INTO dummy
                FROM
                    erm e,
                    putawaylst p
                WHERE
                    e.erm_type = 'CM'
                    AND ( p.pallet_id = l_pallet_id
                          OR p.parent_pallet_id = l_pallet_id )
                    AND e.erm_id = p.rec_id;

                -- putaway is for a return
                g_returns_flag := 'Y';
                l_regular_put  := 'N';
    
                set_labor_mgmt_flags(l_lbr_mgmt_flag,l_cte_rtn_put_batch_flag);
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                IF g_client_obj.regular_putaway != 'Y' THEN
                    IF g_client_obj.func1_flag != 'Y' THEN
                        RETURN rf.status_inv_putaway_opt;
                    END IF;
                ELSE
                    pl_text_log.ins_msg_async('INFO',l_func_name,'PO is not a return on NO_DATA_FOUND.',sqlcode,sqlerrm);
                    g_returns_flag := 'N';
                END IF;
            WHEN OTHERS THEN    
                pl_text_log.ins_msg_async('INFO',l_func_name,'PO is not a return on OTHER Exception',sqlcode,sqlerrm);
                g_returns_flag := 'N'; 
        END;

        -- Setting global to use special XN logic.
        IF ( g_erm_type = 'XN' OR ( g_erm_type = 'CM' AND g_erm_id LIKE 'X%' )) AND ( g_prod_id = 'MULTI' ) THEN 
            g_msku := 'M';
        END IF;

        IF g_msku = 'N' THEN
            IF ( l_hi_msku = 1 ) THEN
                rf_status := rf.status_msku_lp;
            END IF;

			  /*
			  If the func1 flag is set to 'Y'
			  then server program should not throw error MSKU_LP.
			  */
            pl_text_log.ins_msg_async('INFO',l_func_name,'Pallet id = '
                                                || l_pallet_id
                                                || ' STATUS = '
                                                || rf_status
                                                || ' FUNC1_FLAG = '
                                                || g_client_obj.func1_flag,sqlcode,sqlerrm);

            IF ( ( rf_status = rf.status_msku_lp ) AND ( g_client_obj.func1_flag != 'Y' ) ) THEN
				/*   
				In case the qty_received in putawaylst is 0 for scanned MSKU LP
				then throw the error "INVALID_LP"
				*/
                BEGIN
                    SELECT
                        'X'
                    INTO l_qty_zero_flag
                    FROM
                        putawaylst
                    WHERE
                        pallet_id = l_pallet_id
                        AND qty_received = 0;

                    pl_text_log.ins_msg_async('WARN',l_func_name,'Scanned pallet id was zero received during checkin.Pallet_id = '
																|| l_pallet_id,sqlcode,sqlerrm);
                   
                    rf_status := rf.status_inv_label;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'Scanned pallet id does not have zero quantity. Pallet id=' || l_pallet_id,
                        sqlcode,sqlerrm);
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'ORACLE Unable to select from putawaylst.pallet_id = ' || l_pallet_id,sqlcode,
                        sqlerrm);
                        rf_status := rf.status_sel_putawaylst_fail;
                END;

                RETURN rf_status;
			 /*
			  func1 processing for MSKU.
			  In this case MSKU_LP error should not be returned to RF.
			  Func1 processing should be done.
			 */
            ELSIF ( ( rf_status = rf.status_msku_lp ) AND ( g_client_obj.func1_flag = 'Y' ) ) THEN
				/*set the forklift batch flag*/
                IF ( pl_lm_forklift.lmf_forklift_active () != 0 ) THEN
                    l_cte_forklift_batch_flag := 'N';
                ELSE
                    l_cte_forklift_batch_flag := 'Y';
                END IF;

                IF ( l_cte_forklift_batch_flag = 'Y' ) THEN
                    rf_status := reset_forklift_batch(USER,l_equip_id,g_client_obj.drop_loc,g_client_obj.haul_flag);

					/* Log the message*/
                    pl_text_log.ins_msg_async('INFO',l_func_name,'Status from reset forklift batch is ' || rf_status,sqlcode,sqlerrm);
                    RETURN rf_status;
                ELSE /* if the forklift batch  flag is off */
					/* Log the message*/
                    pl_text_log.ins_msg_async('INFO',l_func_name,'Forklift batch flag is off, returning normal status ' || rf_status,sqlcode,
                    sqlerrm);
                    rf_status := rf.status_normal;
                    RETURN rf_status;
                END IF;

            END IF;

        END IF;

        IF g_msku = 'Y' THEN
			  /*
			  ** 
			  **  Following change is for supporting the putaway design change on
			  **  RF client.  Putaway aaplication will be broken down to two parts
			  **  on RF client.  One part will be Non-MSKU putaway and other part
			  **  will be MSKU putaway.  If user scans Non-MSKU LP in MSKU mode throw
			  **  the "NOT_MSKU_LP" error.
			  */
            IF ( l_hi_msku = 1 ) THEN
				/* MSKU processing */
                IF ( g_client_obj.merge_flag = 'Y' ) THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'pallet_id = '
                                                        || l_pallet_id
                                                        || ' merge_flag = '
                                                        || g_client_obj.merge_flag
                                                        || ' can not pick MSKU pallet along with non-MSKU pallet(s)',sqlcode,sqlerrm);

                    RETURN rf.status_non_mksu_pur_pik;
                ELSIF ( g_client_obj.merge_flag != 'Y' ) THEN
                    rf_status := vldt_and_populate_msku_info;
                    RETURN rf_status;
                END IF;

            ELSE
				/*
					Check the scanned LP is present in the system or not.
					If its not present do the scan loss processing
				*/
                BEGIN
                    SELECT
                        'x'
                    INTO dummy
                    FROM
                        putawaylst p
                    WHERE
                        p.pallet_id = l_pallet_id;

					/* This indicates the lP is a non-MSKU LP */

                    pl_text_log.ins_msg_async('INFO',l_func_name,'Regular LP has been scanned in the MSKU mode. Pallet_id = ' 
																	|| l_pallet_id,sqlcode,sqlerrm);                   
                    rf_status := rf.status_not_msku_lp;
                    RETURN rf_status;
                EXCEPTION
                    WHEN OTHERS THEN
                        RETURN check_scan_loss;
                END;
            END IF;
        -- Special Logic for XN PO 
        ELSIF g_msku = 'M' THEN
				/*set the forklift batch flag*/
            IF ( pl_lm_forklift.lmf_forklift_active () != 0 ) THEN
                l_cte_forklift_batch_flag := 'N';
            ELSE
                l_cte_forklift_batch_flag := 'Y';
                g_server.forklift_lbr_trk := l_cte_forklift_batch_flag;
            END IF;

            IF ( l_cte_forklift_batch_flag = 'Y' ) THEN
                rf_status := attach_to_fklift_putaway_batch(USER,l_equip_id,l_pallet_id,g_client_obj.haul_flag,g_client_obj.merge_flag,
                l_put_batch_no);

					/* Log the message*/
                pl_text_log.ins_msg_async('INFO',l_func_name,'Status from reset forklift batch is ' || rf_status,sqlcode,sqlerrm);
            ELSE /* if the forklift batch  flag is off */
					/* Log the message*/
                pl_text_log.ins_msg_async('INFO',l_func_name,'Forklift batch flag is off, returning normal status ' || rf_status,sqlcode,
                sqlerrm);
                rf_status := rf.status_normal;
            END IF;

            l_strip_put := l_put_aisle;
            l_strip_slot := l_put_slot;
            l_strip_level := l_put_level;
            l_put_path_val := l_strip_put
                              || l_strip_slot
                              || l_strip_level;

            g_server.dest_loc := rf.NoNull(l_dest_loc);
            g_server.put_path_val := rf.NoNull(substr(l_put_path_val,1,10));

            dummy := pl_common.f_get_syspar('RES_LOC_CO','N');
            IF dummy = 'Y' THEN
                l_rlc_flag := 'Y';
                pl_text_log.ins_msg_async('INFO',l_func_name,'This is a reserve locator company.',sqlcode,sqlerrm);
            ELSE
                l_rlc_flag := 'N';
            END IF;

            g_server.rlc_flag := rf.NoNull(l_rlc_flag);

            dummy := pl_common.f_get_syspar('RTN_PUTAWAY_CONF','N');
            IF dummy = 'N' THEN
                pl_text_log.ins_msg_async('INFO',l_func_name,'Returns putaway flag is set to N',sqlcode,sqlerrm);
                l_rtn_putaway_conf := 'N';
            ELSE
                l_rtn_putaway_conf := 'Y';
                pl_text_log.ins_msg_async('INFO',l_func_name,'Returns putaway flag is set to Y',sqlcode,sqlerrm);
            END IF;

            g_server.rtn_putaway_conf := rf.NoNull(l_rtn_putaway_conf);
            g_server.door_no := rf.NoNull(substr(l_src_loc,1,4));
            g_server.ml_flag := 'N';
            IF ( g_returns_flag = 'Y' ) THEN
                g_server.ml_flag := 'N';
            ELSIF ( l_ml_flag = 'Y' ) THEN
                g_server.ml_flag := 'Y';
            ELSIF ( l_mx_flag = 'Y' ) THEN
                g_server.ml_flag := 'N';
            ELSE
                g_server.ml_flag := 'N';
            END IF;
            g_server.po_no := rf.NoNull(g_erm_id);
            g_server.pallet_cnt := rf.NoNull(l_pallet_cnt);
            g_pallet_count := rf.NoNull(l_pallet_cnt);
            g_server.qty_rec := l_qty_rec;
            g_server.spc := rf.NoNull(l_spc);
            g_server.descrip := 'XN PO MULTI';

            pl_check_upc.check_upc_data_collection(g_prod_id,g_erm_id,putaway,l_upc_comp_flag,l_upc_scan_function);
            g_server.upc_comp_flag := rf.NoNull(l_upc_comp_flag);
            g_server.upc_scan_function := rf.NoNull(l_upc_scan_function);

            RETURN rf_status;

        ELSE
            SELECT
                l_p_batch_no
            INTO l_batch_no
            FROM
                dual;

            l_merge_flag := g_client_obj.merge_flag;
            pl_text_log.ins_msg_async('INFO',l_func_name,'Pallet_id = '
                                                || l_pallet_id
                                                || ' equip_id = '
                                                || l_equip_id
                                                || ' batch_no = '
                                                || l_batch_no
                                                || ' merge_flag = '
                                                || l_merge_flag
                                                || ' func1 = '
                                                || g_client_obj.func1_flag
                                                || ' haul_flag = '
                                                || g_client_obj.haul_flag
                                                || ' drop_loc = '
                                                || g_client_obj.drop_loc
                                                || ' reg_put = '
                                                || l_regular_put,sqlcode,sqlerrm);

            dummy := pl_common.f_get_syspar('RES_LOC_CO','N');
            IF dummy = 'Y' THEN
                l_rlc_flag := 'Y';
                pl_text_log.ins_msg_async('INFO',l_func_name,'This is a reserve locator company.',sqlcode,sqlerrm);
            ELSE
                l_rlc_flag := 'N';
            END IF;

            dummy := pl_common.f_get_syspar('FORCE_DATE_COLLECT','N');
            IF dummy = 'Y' THEN
                l_force_date_collect_flag := 'Y';
                pl_text_log.ins_msg_async('INFO',l_func_name,'Force date collection before putaway flag is Y ',sqlcode,sqlerrm);
            ELSE
                pl_text_log.ins_msg_async('INFO',l_func_name,'Force date collection before putaway flag is off ',sqlcode,sqlerrm);
                l_force_date_collect_flag := 'N';
            END IF;

            dummy := pl_common.f_get_syspar('RTN_PUTAWAY_CONF','N');
            IF dummy = 'N' THEN
                pl_text_log.ins_msg_async('INFO',l_func_name,'Returns putaway flag is set to N',sqlcode,sqlerrm);
                l_rtn_putaway_conf := 'N';
            ELSE
                l_rtn_putaway_conf := 'Y';
                pl_text_log.ins_msg_async('INFO',l_func_name,'Returns putaway flag is set to Y',sqlcode,sqlerrm);
            END IF;

		  /*
		  ** Set the labor mgmt flags.
		  */

            set_labor_mgmt_flags(l_lbr_mgmt_flag,l_cte_rtn_put_batch_flag);

		  /*
		  **  Check forklift create flag.
		  */
            IF ( pl_lm_forklift.lmf_forklift_active != 0 ) THEN
                l_cte_forklift_batch_flag := 'N';
            ELSE
                l_cte_forklift_batch_flag := 'Y';
                g_server.forklift_lbr_trk := l_cte_forklift_batch_flag;
            END IF;

		  /*
		  **  Show system flags.
		  */

            pl_text_log.ins_msg_async('INFO',l_func_name,'RES_LOC_CO = '
                                                || l_rlc_flag
                                                || ' FORCE_DATE_COLLECT = '
                                                || l_force_date_collect_flag
                                                || ' LABOR_MGMT_FLAG = '
                                                || l_lbr_mgmt_flag
                                                || ' RETURNS_PUTAWAY_TRK = '
                                                || l_cte_rtn_put_batch_flag
                                                || ' FORKLIFT_CREATE_BATCH_FLAG = '
                                                || l_cte_forklift_batch_flag,sqlcode,sqlerrm);

            IF ( ( length(l_pallet_id) = 18 ) AND ( l_pallet_id = '                  ' ) ) THEN
                l_pallet_check_flag := 1;
            ELSIF ( ( length(l_pallet_id) = 10 ) AND ( l_pallet_id = '          ' ) ) THEN
                l_pallet_check_flag := 1;
            END IF;

            IF ( ( l_lbr_mgmt_flag = 'Y' ) AND ( l_cte_rtn_put_batch_flag = 'Y' ) AND ( g_client_obj.func1_flag = 'Y' ) 
											AND ( l_pallet_check_flag= 1 ) ) THEN
            
                rf_status := get_pallet_id_on_batch(l_batch_no,length(l_batch_no),l_pallet_id,l_merge_flag);
                IF ( rf_status != 0 ) THEN
                    RETURN rf_status;
                END IF;
            END IF;

            IF ( l_cdk_status = 'Y' ) THEN
                BEGIN
                    SELECT DISTINCT
                        dest_loc,
                        'MULTI'
                    INTO
                        l_dest_loc,
                        l_prod_id
                    FROM
                        putawaylst
                    WHERE
                        parent_pallet_id = l_pallet_id;

                EXCEPTION
                    WHEN OTHERS THEN
                        RETURN rf.status_inv_location;
                END;
			/*
			** The Qty sent back to RF should be total cases. 
			**  Description should be CROSS DOCK
			** Single PPU transaction should be created for a physical pallet.
			*/

                BEGIN
                    SELECT
                        SUM(p.qty_received / pm.spc)
                    INTO l_qty_rec
                    FROM
                        putawaylst p,
                        pm pm
                    WHERE
                        p.prod_id = pm.prod_id
                        AND p.parent_pallet_id = l_pallet_id
                    GROUP BY
                        p.dest_loc;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'unable to get total cases for pallet_id = ' || l_pallet_id,sqlcode,sqlerrm);
                        
                END;

                BEGIN
                    SELECT DISTINCT
                        p.pallet_batch_no,
                        p.putaway_put,
                        1,
                        p.inv_status,
                        lpad(ltrim(rtrim(TO_CHAR(l.put_aisle) ) ),3,'0'),
                        lpad(ltrim(rtrim(TO_CHAR(l.put_slot) ) ),3,'0'),
                        lpad(ltrim(rtrim(TO_CHAR(l.put_level) ) ),3,'0'),
                        p.rec_id,
                        p.uom,
                        TO_CHAR(p.exp_date,'DD-MON-YYYY'),
                        p.exp_date_trk,
                        p.date_code,
                        p.cust_pref_vendor,
                        'CROSSDOCK PALLET',
                        pl_ml_common.f_is_induction_loc(p.dest_loc)
                    INTO
                        l_put_batch_no,
                        l_put,
                        l_spc,
                        l_inv_status,
                        l_put_aisle,
                        l_put_slot,
                        l_put_level,
                        l_rec_id,
                        l_uom,
                        l_exp_date,
                        l_exp_date_trk,
                        l_mfg_date_trk,
                        l_cust_pref_vendor,
                        l_descrip,
                        l_ml_flag
                    FROM
                        loc l,
                        putawaylst p
                    WHERE
                        l.logi_loc = l_dest_loc
                        AND p.parent_pallet_id = l_pallet_id;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'No records found for pallet_id '
                                                            || l_pallet_id
                                                            || ' dest_loc = '
                                                            || l_dest_loc,sqlcode,sqlerrm);
                END;

            ELSE
                BEGIN
				/* 
				**  Check if pallet_id is in the putawaylist, and if so get pick aisle
				**  and pick slot
				*/
                    pl_text_log.ins_msg_async('INFO',l_func_name,'HIEP ready to select from list',sqlcode,sqlerrm);
                    SELECT
                        p.dest_loc,
                        p.putaway_put,
                        p.qty_received,
                        spc,
                        p.inv_status,
                        lpad(ltrim(rtrim(TO_CHAR(l.put_aisle) ) ),3,'0'),
                        lpad(ltrim(rtrim(TO_CHAR(l.put_slot) ) ),3,'0'),
                        lpad(ltrim(rtrim(TO_CHAR(l.put_level) ) ),3,'0'),
                        p.rec_id,
                        p.uom,
                        TO_CHAR(p.exp_date,'DD-MON-YYYY'),
                        p.exp_date_trk,
                        p.date_code,
                        p.prod_id,
                        p.cust_pref_vendor,
                        p.pallet_batch_no,
                        pm.descrip,
                        pl_ml_common.f_is_induction_loc(p.dest_loc),
                        pl_matrix_common.f_is_induction_loc_yn(p.dest_loc)
                    INTO
                        l_dest_loc,
                        l_put,
                        l_qty_rec,
                        l_spc,
                        l_inv_status,
                        l_put_aisle,
                        l_put_slot,
                        l_put_level,
                        l_rec_id,
                        l_uom,
                        l_exp_date,
                        l_exp_date_trk,
                        l_mfg_date_trk,
                        l_prod_id,
                        l_cust_pref_vendor,
                        l_put_batch_no,
                        l_descrip,
                        l_ml_flag,
                        l_mx_flag
                    FROM
                        loc l,
                        putawaylst p,
                        pm
                    WHERE
                        l.logi_loc = p.dest_loc
                        AND p.pallet_id = l_pallet_id
                        AND p.prod_id = pm.prod_id
                        AND p.cust_pref_vendor = pm.cust_pref_vendor;

                    -- pl_text_log.ins_msg_async('INFO',l_func_name,'HIEP done select from list',sqlcode,sqlerrm);
                    pl_text_log.ins_msg_async('INFO',l_func_name,'HIEP done select from list'
                                              || ' - l_dest_loc ['
                                              || l_dest_loc
                                              || '] l_prod_id ['
                                              || l_prod_id
                                              || '] l_put_batch_no ['
                                              || l_put_batch_no
                                              || ']' ,
                                              sqlcode,sqlerrm);
				/*
				**  If pallet_id is not in the putawaylist then returns "NOT_FOUND"
				*/
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'HIEP in IF 2  select from list',sqlcode,sqlerrm);
--                        DECLARE
--                          l_erm_type                 erm.erm_type%TYPE;
--                          l_erm_id                   erm.erm_id%TYPE;
                        BEGIN
--                            SELECT
--                                e.erm_id,
--                                e.erm_type
--                            INTO
--                                l_erm_id,
--                                l_erm_type
--                            FROM
--                                erm          e,
--                                putawaylst   p
--                            WHERE
--                                e.erm_id = p.rec_id
--                                AND p.pallet_id = l_pallet_id;

                            pl_text_log.ins_msg_async('WARN',l_func_name,'unable to get destination location record.',sqlcode,sqlerrm);
                            
                            IF ( g_erm_type = 'XN' OR ( g_erm_type = 'CM' AND g_erm_id LIKE 'X%' )) THEN 

                                RETURN rf.status_xdock_put_inv_loc;

                            ELSE

                                RETURN rf.status_inv_location;

                            END IF;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                pl_text_log.ins_msg_async('WARN',l_func_name,'HIEP in IF 3 select from list',sqlcode,sqlerrm);
								rf_status:=check_scan_loss;
                                return rf_status;
                        END;

                END;
            END IF;

            IF l_qty_rec = 0 THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'Pallet not putaway.Putaway quantity equal to zero. Pallet_id = ' || l_pallet_id,
                sqlcode,sqlerrm);
                RETURN rf.status_inv_label;
            ELSIF ( l_inv_status = 'HLD' ) THEN
			  /*
			  ** See if item is to-be-aged (in on-hold status 
			  ** already.) Ok to putaway if it is. For returns, cannot putaway
			  ** no matter if the item is in aging or not.
			  **If the pallet is on hold (demand pallet created
			  ** on hold) and not returns then the system should allow the user 
			  ** to put it away. 
			  */
                BEGIN
                    SELECT
                        'Y'
                    INTO dummy
                    FROM
                        aging_items
                    WHERE
                        prod_id = l_prod_id
                        AND cust_pref_vendor = l_cust_pref_vendor;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        IF g_returns_flag = 'Y' THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,'pallet is unavailable.Pallet is on hold.Pallet_id = '
                                                                || l_pallet_id
                                                                || ' dest_loc = '
                                                                || l_dest_loc,sqlcode,sqlerrm);

                            RETURN rf.status_pallet_on_hold;
                        END IF;
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'unable to get AGING_ITEMS record. prod_id = '
                                                            || l_prod_id
                                                            || ' Pallet_id = '
                                                            || l_pallet_id,sqlcode,sqlerrm);

                        RETURN rf.status_sel_aging_fail;
                END;
            END IF;

            IF ( ( l_cte_forklift_batch_flag = 'Y' ) AND ( g_client_obj.func1_flag = 'Y' ) AND ( g_returns_flag = 'N' ) 
													AND ( l_rlc_flag= 'N' ) ) THEN
            
                rf_status := reset_forklift_batch(USER,l_equip_id,g_client_obj.drop_loc,g_client_obj.haul_flag);
                RETURN rf_status;
            END IF;

            IF ( g_returns_flag = 'Y' ) THEN
				/* 
				**  If labor tracking for returns is on then process func1
				*/
                IF ( ( l_lbr_mgmt_flag = 'Y' ) AND ( l_cte_rtn_put_batch_flag = 'Y' ) AND ( g_client_obj.func1_flag = 'Y' ) ) THEN
                    rf_status := func1_for_returns(l_batch_no,length(l_batch_no),l_merge_flag,l_dest_loc,l_rec_id,USER);

                    RETURN rf_status;
                END IF;

			/* 
			**  Check labor management for returns.
			**  1 - If labor management flag is set, check to see if user is
			**      signed on to the batch to perform putaway confirmation.
			**      He/She must have an active batch.
			**  2 - Also check number of pallets on the batch and send the value
			**      back to the RF devices.
			**  3 - If the value of regular_putaway is set to Yes on the RF's,
			**      then logic will continue for regular putaway instead of
			**      Returns Putaway.
			*/

                IF ( ( l_lbr_mgmt_flag = 'Y' ) AND ( l_cte_rtn_put_batch_flag = 'Y' ) AND ( l_regular_put != 'N' ))THEN
                   
                        IF ( l_merge_flag = 'Y' ) THEN
                            SELECT
                                COUNT(*)
                            INTO l_pallet_cnt
                            FROM
                                batch b,
                                putawaylst p
                            WHERE
                                b.status = 'M'
                                AND b.parent_batch_no = l_batch_no
                                AND b.batch_no = p.pallet_batch_no
                                AND p.putaway_put = 'N';

                        ELSE
                            SELECT
                                COUNT(*)
                            INTO l_pallet_cnt
                            FROM
                                putawaylst p
                            WHERE
                                p.pallet_batch_no = l_batch_no
                                AND p.putaway_put = 'N';

                        END IF;

                    IF ( l_pallet_cnt = 0 ) THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'Pallet_batch_no not found.',sqlcode,sqlerrm);
                        RETURN rf.status_no_lm_batch_found;
                    END IF;
				/*
				**  Checking for active batch pallet is attached to.
				*/

                    BEGIN
                        IF ( l_merge_flag = 'Y' ) THEN
                            SELECT
                                p.pallet_batch_no,
                                p.pallet_id,
                                b.batch_no,
                                b.user_id
                            INTO
                                dummy,
                                dummy1,
                                dummy2,
                                dummy3
                            FROM
                                batch pb,
                                batch b,
                                putawaylst p
                            WHERE
                                pb.status = 'A'
                                AND replace(pb.user_id,'OPS$',NULL) = USER
                                AND pb.batch_no = b.parent_batch_no
                                AND b.status = 'M'
                                AND replace(b.user_id,'OPS$',NULL) = USER
                                AND p.pallet_batch_no = b.batch_no
                                AND p.pallet_id = l_pallet_id;

                        ELSE
                            SELECT
                                p.pallet_batch_no,
                                p.pallet_id,
                                b.batch_no,
                                b.user_id
                            INTO
                                dummy,
                                dummy1,
                                dummy2,
                                dummy3
                            FROM
                                batch b,
                                putawaylst p
                            WHERE
                                b.status = 'A'
                                AND replace(b.user_id,'OPS$',NULL) = USER
                                AND p.pallet_batch_no = b.batch_no
                                AND p.pallet_id = l_pallet_id;

                        END IF;

                        pl_text_log.ins_msg_async('INFO',l_func_name,' User has active batch, allow putaway.User = '
                                                            || USER
                                                            || ' Pallet_id = '
                                                            || l_pallet_id
                                                            || ' merge flag = '
                                                            || l_merge_flag,sqlcode,sqlerrm);

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,' User not signed on to LBR MGMT batch.User = '
                                                                || USER
                                                                || ' Pallet_id = '
                                                                || l_pallet_id
                                                                || ' merge flag = '
                                                                || l_merge_flag,sqlcode,sqlerrm);

                            RETURN rf.status_lm_no_active_batch;
                    END;

                END IF;

            END IF; /* Return flag == Y */

            IF ( l_put = 'Y' ) THEN
                IF ( ( g_returns_flag = 'Y' ) AND ( l_rlc_flag = 'Y' ) AND ( l_rtn_putaway_conf = 'N' ) ) THEN
                    pl_text_log.ins_msg_async('INFO',l_func_name,'Performing fake returns putaway for SLMS company.Pallet_id = ' || l_pallet_id,
                    sqlcode,sqlerrm);
                ELSE
                    pl_text_log.ins_msg_async('WARN',l_func_name,'Putaway not performed.Putaway has been already completed for Pallet_id = '
                    || l_pallet_id,sqlcode,sqlerrm);
                    RETURN rf.status_put_done;
                END IF;
            END IF;

			  /*
			  **  Check if door_no is in the erm table, and if so add it to the data
			  **  going back to the RF's. For cross dock pallet use parent pallet id
			  */

            BEGIN
                SELECT
                    e.door_no,
--                    e.erm_type,
                    nvl(e.to_warehouse_id,'000')
                INTO
                    l_door_no,
--                    l_erm_type,
                    l_to_wh_id
                FROM
                    erm e,
                    putawaylst p
                WHERE
                    e.erm_id = l_rec_id
                    AND p.rec_id = e.erm_id
                    AND DECODE(l_cdk_status,'Y',p.parent_pallet_id,p.pallet_id) = l_pallet_id;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'NO door_no found for this PO.',sqlcode,sqlerrm);
                    l_door_no := '0000';
            END;

			  /*
			  Don't allow putaway of pallets belonging to a Transfer PO.
			  */

            IF ( g_erm_type = 'TR' AND ( l_to_wh_id != '000' ) ) THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'Attempted to putaway transfer PO Pallet.Pallet_id = '
                                                    || l_pallet_id
                                                    || 'Rec_id = '
                                                    || l_rec_id,sqlcode,sqlerrm);

                RETURN rf.status_no_rf;
            END IF;

            BEGIN
                SELECT
                    'x'
                INTO dummy
                FROM
                    zequip z,
                    lzone l
                WHERE
                    z.zone_id = l.zone_id
                    AND z.equip_id = l_equip_id
                    AND l.logi_loc = l_dest_loc;

            EXCEPTION
                WHEN TOO_MANY_ROWS THEN
                    NULL;
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'putaway attempted with wrong equipment. Pallet_id = ' || l_pallet_id,sqlcode,
                    sqlerrm);
                    RETURN rf.status_wrong_equip;
            END;

            IF ( ( l_force_date_collect_flag = 'Y' ) AND ( ( l_exp_date_trk = 'Y' ) OR ( l_mfg_date_trk = 'Y' ) ) ) THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'Force on and need exp_date or mfg_date before allowing putaway.force_date_collect_flag = '
                                                    || l_force_date_collect_flag
                                                    || ' pallet_id = '
                                                    || l_pallet_id
                                                    || ' exp_date_trk = '
                                                    || l_exp_date_trk
                                                    || ' mfg_date_trk = '
                                                    || l_mfg_date_trk,sqlcode,sqlerrm);

                RETURN rf.status_need_expmfg_date_info;
            END IF;

		  /*
		  ** Get the location of the pallet if it has been hauled.
		  ** 
		  */

            l_temp_pallet_id := l_pallet_id;
            rf_status := pl_rf_lm_common.lmc_get_haul_location(l_temp_pallet_id,l_src_loc);
            IF ( rf_status != rf.status_normal ) THEN
				/* lmc_get_haul_location generated an oracle error. */
                RETURN rf_status;
            END IF;

			  /*
			  ** If the pallet was not hauled then the trans src_loc will be the door#.
			  ** Function lmc_get_haul_location will set the location to a null string
			  ** if the pallet has not been hauled.
			  */
            IF ( length(l_src_loc) IS NULL ) THEN
				/*
				** The pallet has not been hauled.  The trans src_loc will be
				** the door#.
				*/
                l_src_loc := l_door_no;
            END IF;

			  /*
			  **  Mark the pallet as picked up by the user.
			  */
            BEGIN
                INSERT INTO trans (
                    trans_id,
                    trans_date,
                    trans_type,
                    user_id,
                    rec_id,
                    pallet_id,
                    src_loc,
                    dest_loc,
                    prod_id,
                    cust_pref_vendor,
                    exp_date,
                    qty,
                    uom,
                    cmt,
                    labor_batch_no)
                 VALUES (
                    trans_id_seq.NEXTVAL,
                    SYSDATE,
                    'PPU',
                    user,
                    l_rec_id,
                    l_pallet_id,
                    l_src_loc,
                    l_dest_loc,
                    l_prod_id,
                    l_cust_pref_vendor,
                    TO_DATE(l_exp_date,'DD-MON-YYYY'),
                    l_qty_rec,
                    l_uom,
                    l_put,
                    l_put_batch_no);

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,' unable to create PPU transaction. Pallet_id = ' || l_pallet_id,sqlcode,sqlerrm);
                    RETURN rf.status_trans_insert_failed;
            END;

		  /*
		  **  For reserved locator companies, find the home slot of the product and
		  **  return it to the RF devices to direct the forklift drivers to the pick
		  **  location for that item. If no pick slot found, then the assumption
		  **  is that this is a floating item and so business is normal.
		  */

            IF ( l_rlc_flag = 'Y' ) THEN
                BEGIN
                    SELECT
                        l.logi_loc
                    INTO l_rlc_loc
                    FROM
                        loc l
                    WHERE
                        l.uom IN (
                            0,
                            2)
                        AND l.rank = 1
                        AND l.perm = 'Y'
                        AND l.cust_pref_vendor = l_cust_pref_vendor
                        AND l.prod_id = l_prod_id;

					/*
					**  If the receipt is a return, then act as non-locator company.
					*/

                    IF ( g_returns_flag = 'Y' ) THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'Turning off RCL flag processing.RLC putaway for a return.Rec_id = ' ||
																						l_rec_id,sqlcode,sqlerrm);
                        l_rlc_flag := 'N';
                    ELSIF ( l_uom = 1 ) THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'Turning off RCL flag processing.
														Splits should not go to pit slot.Rec_id = '
														|| l_rec_id,sqlcode,sqlerrm);
                        l_rlc_flag := 'N';
                    ELSE
                        l_dest_loc := l_rlc_loc;
                    END IF;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,' RLC putaway attempted for product with no pick slot. Prod_id = '
                                                            || l_prod_id
                                                            || ' cust_pref_vendor = '
                                                            || l_cust_pref_vendor,sqlcode,sqlerrm);

                        l_rlc_flag := 'N';
					WHEN OTHERS THEN
						pl_text_log.ins_msg_async('WARN',l_func_name,' Unable to get home slot for Prod_id = '
                                                            || l_prod_id
                                                            || ' cust_pref_vendor = '
                                                            || l_cust_pref_vendor,sqlcode,sqlerrm);
						l_rlc_flag := 'N';
                END;
            ELSE
                l_rtn_putaway_conf := 'Y';
            END IF;

            IF ( (( l_cte_forklift_batch_flag = 'Y' AND  g_returns_flag = 'N' ) OR (g_returns_flag = 'Y' AND l_cte_rtn_put_batch_flag = 'Y')) 
                  AND l_rlc_flag = 'N'  ) THEN
                rf_status := attach_to_fklift_putaway_batch(USER,l_equip_id,l_pallet_id,g_client_obj.haul_flag,g_client_obj.merge_flag,
                l_put_batch_no);
            END IF;

            l_strip_put := l_put_aisle;
            l_strip_slot := l_put_slot;
            l_strip_level := l_put_level;
            l_put_path_val := l_strip_put
                              || l_strip_slot
                              || l_strip_level;
            g_server.dest_loc := rf.NoNull(l_dest_loc);
            g_server.put_path_val := rf.NoNull(substr(l_put_path_val,1,10));
            g_server.rlc_flag := rf.NoNull(l_rlc_flag);
            -- Story 3810 (kchi7065) Added back this line that was missing.
            g_server.rtn_putaway_conf := rf.NoNull(l_rtn_putaway_conf);
            g_server.door_no := rf.NoNull(substr(l_src_loc,1,4));
            g_server.ml_flag := 'N';
            IF ( g_returns_flag = 'Y' ) THEN
                g_server.ml_flag := 'N';
            ELSIF ( l_ml_flag = 'Y' ) THEN
                g_server.ml_flag := 'Y';
            ELSIF ( l_mx_flag = 'Y' ) THEN
                g_server.ml_flag := 'N';
            ELSE
                g_server.ml_flag := 'N';
            END IF;

            g_server.po_no := rf.NoNull(g_erm_id);
            g_server.pallet_cnt := rf.NoNull(l_pallet_cnt);
            g_pallet_count := rf.NoNull(l_pallet_cnt);
            g_server.qty_rec := rf.NoNull(l_qty_rec);
            g_server.spc := rf.NoNull(l_spc);
            g_server.descrip := l_descrip;

		  /*
		  ** Check completion of UPC data collection.
		  */
            pl_check_upc.check_upc_data_collection(l_prod_id,l_rec_id,putaway,l_upc_comp_flag,l_upc_scan_function);
             g_server.upc_comp_flag := rf.NoNull(l_upc_comp_flag);
            g_server.upc_scan_function := rf.NoNull(l_upc_scan_function);
            pl_text_log.ins_msg_async('INFO',l_func_name,'Putaway operations.....Flags returned from the check_upc function.upc_comp_flag = '
                                                || g_server.upc_comp_flag
                                                || ' upc_scan_function = '
                                                || g_server.upc_scan_function,sqlcode,sqlerrm);

            RETURN rf_status;
        END IF;

        pl_text_log.ins_msg_async('INFO',l_func_name,'Ending preputaway',sqlcode,sqlerrm);
		RETURN rf_status;
    END preputaway;
	
  /*************************************************************************
    NAME:  func1_for_returns
    CALLED BY:preputaway()
    DESC: performs Returns Putaway tasks
  
    INPUT PARAMETERS:
      i_batch_no      		--  Current active LM batch  	
      i_batch_no_len  		--  Current active LM batch  	 
      i_merge_flag      	--  batch is merged flag  		 
      i_dest_loc        	--  where the pallet is going  	  
      i_credit_memo     	--  what return the pallet is on  
      i_user_id         	--  user performing action   
    RETURN VALUE: 
	rf.status - value returned by the package
             
    
  **************************************************************************/

    FUNCTION func1_for_returns (
        i_batch_no       IN batch.parent_batch_no%TYPE,
        i_batch_no_len   IN NUMBER,
        i_merge_flag     IN VARCHAR2,
        i_dest_loc       IN putawaylst.dest_loc%TYPE,
        i_credit_memo    IN putawaylst.rec_id%TYPE,
        i_user_id        IN VARCHAR2
    ) RETURN rf.status IS

		l_func_name              VARCHAR2(50) := 'func1_for_returns';
        l_ret_val                NUMBER := 0;        
        rf_status                rf.status := rf.status_normal;
        l_new_pallet_batch       putawaylst.pallet_batch_no%TYPE;
        l_new_pallet_batch_len   NUMBER;
        l_parent_batch_no        batch.parent_batch_no%TYPE;
        l_new_pallet_batch_no    putawaylst.pallet_batch_no%TYPE;
        l_cur_pallet_batch_no    putawaylst.pallet_batch_no%TYPE;
        l_report_queue           VARCHAR2(7);
        l_prc_seq_no             NUMBER;
        l_job_code               pallet_ret_cntrl.job_code%TYPE;
        

    BEGIN
        pl_text_log.ins_msg_async('INFO',l_func_name,'Starting FUNC1 processing.',sqlcode,sqlerrm);
        l_report_queue := ' ';
        l_job_code := ' ';
        l_prc_seq_no := 0;
        BEGIN
            SELECT
                prc.report_queue,
                prc.job_code,
                prc.prc_seq_no
            INTO
                l_report_queue,
                l_job_code,
                l_prc_seq_no
            FROM
                pallet_ret_cntrl prc
            WHERE
                substr(i_dest_loc,1,2) BETWEEN prc.from_aisle AND prc.to_aisle;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'No report_queue,job_code,prc_seq_no found for dest_loc '||i_dest_loc,sqlcode,sqlerrm);
        END;

		/*	
		**  Create new batch.
		*/
			/*logic for pl_returns_lm_bats will be done in SMOD-811*/
        rf_status:=pl_returns_lm_bats.create_pallet_batch(l_new_pallet_batch,l_new_pallet_batch_len,l_prc_seq_no,l_job_code,i_credit_memo);
        IF ( rf_status = rf.status_normal ) THEN
            l_new_pallet_batch_no := ' ';
            l_new_pallet_batch_no := l_new_pallet_batch;
            IF ( i_merge_flag = 'Y' ) THEN
				/*
				**  Process merge batch.
				*/
                l_parent_batch_no := i_batch_no;
				DECLARE
					CURSOR c_merge_batch IS SELECT
                                  batch_no
                              FROM
                                  batch
                              WHERE
                                  parent_batch_no = l_parent_batch_no;
                BEGIN
                    OPEN c_merge_batch;
                    LOOP
                        FETCH c_merge_batch INTO l_cur_pallet_batch_no;
                        EXIT WHEN c_merge_batch%notfound;

						/*
						**  Remove KVI's for remaining putaway tasks from current batch.
						*/
						/*logic for pl_returns_lm_bats will be done in SMOD-811*/
						rf_status:= pl_returns_lm_bats.unload_pallet_batch(l_cur_pallet_batch_no,length(l_parent_batch_no));
						/*
						**  Reattach remaining putaway tasks to new batch.
						*/
						/*logic for pl_returns_lm_bats will be done in SMOD-811*/
						IF rf_status!=rf.STATUS_NORMAL THEN 
							rf_status:= pl_returns_lm_bats.move_puts_to_batch(l_cur_pallet_batch_no,
														length(l_cur_pallet_batch_no),
														l_new_pallet_batch_no,
														length(l_new_pallet_batch_no));
						END IF;
						/*
						**  Get next child batch.
						*/
                        IF ( rf_status = ORACLE_NOT_FOUND ) THEN
                            rf_status := rf.status_normal;
                        END IF;
                    END LOOP;
                    CLOSE c_merge_batch;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'FUNC1:No batches found for parent ' || l_parent_batch_no,sqlcode,sqlerrm);
                        rf_status := rf.status_no_lm_batch_found;
                    WHEN INVALID_CURSOR THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'FUNC1:Unable open merge_batch cursor for parent batch ' || l_parent_batch_no,
                        sqlcode,sqlerrm);
                        rf_status := rf.status_lm_batch_upd_fail;
                END;
			ELSE

				/*
				**  Process single batch.
				*/
				/*
				**  Remove KVI's for remaining putaway tasks from current batch.
				*/
				/*logic for pl_returns_lm_bats will be done in SMOD-811*/
				rf_status:= pl_returns_lm_bats.unload_pallet_batch(i_batch_no, i_batch_no_len);
				/*
				**  Reattach remaining putaway tasks to new batch.
				*/
				IF  ( rf_status=rf.STATUS_NORMAL ) THEN
					rf_status:= pl_returns_lm_bats.move_puts_to_batch(i_batch_no, i_batch_no_len,
										  l_new_pallet_batch_no,length(l_new_pallet_batch_no));
										  
				END IF;

            END IF;

        END IF;

		/* 
		**  Load KVI's of remaining putaway tasks to new batch.
		**  Close batch to future.
		*/
		/*logic for pl_returns_lm_bats will be done in SMOD-811*/
		IF  (  rf_status=rf.STATUS_NORMAL) THEN
					rf_status := pl_returns_lm_bats.close_pallet_batch(l_new_pallet_batch_no,
										length(l_new_pallet_batch_no));
		END IF;
		/*
		**  Print worksheet for new pallet batch.
		*/
		/*logic for print_pallet_batch will be handled in pre_putaway Java wrapper.*/
		COMMIT;

        IF ( rf_status = rf.status_normal ) THEN
            l_ret_val := pl_rf_lm_common.lmc_signoff_from_batch(i_batch_no);
        END IF;
		/*logic for pl_returns_lm_bats will be done in SMOD-811*/
		IF  ( rf_status=rf.STATUS_NORMAL ) THEN
			l_ret_val:= pl_returns_lm_bats.create_default_rtn_lm_batch(i_user_id, i_batch_no);		
		END IF;

        pl_text_log.ins_msg_async('INFO',l_func_name,'Ending func1_for_returns',sqlcode,sqlerrm);
        RETURN rf_status;
    END func1_for_returns; /* end func1_for_returns */
	
  /*************************************************************************
   NAME:  attach_to_fklift_putaway_batch
   CALLED BY:preputaway()
   DESC:  Signs user onto putaway batch matching the pallet being
          processed.
          A haul batch must be created before it can be signed on to.
  
   PARAMETERS:
     i_user_id -- User performing operation.
     i_equip_id --  Equipment being used.
     i_pallet_id -- Pallet being processed.
     i_haul_flag -- Haul flag.
     i_merge_flag -- Merge flag.
     i_put_batch_no -- Putaway Task batch no.
  **************************************************************************/

    FUNCTION attach_to_fklift_putaway_batch (
        i_user_id        IN batch.user_id%TYPE,
        i_equip_id       IN equip.equip_id%TYPE,
        i_pallet_id      IN putawaylst.pallet_id%TYPE,
        i_haul_flag      IN VARCHAR2,
        i_merge_flag     IN VARCHAR2,
        i_put_batch_no   IN batch.batch_no%TYPE
    ) RETURN rf.status AS

		l_func_name        		VARCHAR2(50) := 'attach_to_fklift_putaway_batch';
        rf_status           	rf.status := rf.status_normal;       
        l_parent_batch_no   	batch.batch_no%TYPE;
        l_prev_batch_no     	batch.batch_no%TYPE;
        l_pallet_id         	putawaylst.pallet_id%TYPE;
        l_user_id           	batch.user_id%TYPE;
        l_supervisor_id     	batch.user_supervsr_id%TYPE;
        l_equip_id          	equip.equip_id%TYPE;
        l_signon_type       	VARCHAR2(1);
        l_s_batch_no          	batch.batch_no%TYPE;
        l_put_batch_no      	batch.batch_no%TYPE;        
        l_new_batch_no      	batch.batch_no%TYPE;
    BEGIN
        -- pl_text_log.ins_msg_async('INFO',l_func_name,'Starting attach_to_fklift_putaway_batch',sqlcode,sqlerrm);
        pl_text_log.ins_msg_async('INFO',l_func_name,
                                  'Starting attach_to_fklift_putaway_batch'
                                  || ' - i_user_id ['
                                  || i_user_id
                                  || '] i_equip_id ['
                                  || i_equip_id
                                  || '] i_pallet_id ['
                                  || i_pallet_id
                                  || '] i_haul_flag ['
                                  || i_haul_flag
                                  || '] i_merge_flag ['
                                  || i_merge_flag
                                  || '] i_put_batch_no ['
                                  || i_put_batch_no
                                  || ']' ,
                                  sqlcode,sqlerrm);
        l_equip_id := i_equip_id;
        l_user_id := i_user_id;
        l_pallet_id := i_pallet_id;
        IF ( i_haul_flag = 'Y' ) THEN
		  /*
		  **  Haul batch needs to be created before the signon can occur.
		  */
            SELECT
                'HP' || pallet_batch_no_seq.NEXTVAL
            INTO l_new_batch_no
            FROM
                dual;

            l_put_batch_no := i_put_batch_no;
	
			  rf_status:= pl_lm_forklift.lmf_create_haul_forklift_batch(l_new_batch_no, l_put_batch_no,
												   l_pallet_id);			
            l_s_batch_no := l_new_batch_no;
        ELSE
            l_s_batch_no := i_put_batch_no;
        END IF;

        IF ( rf_status = rf.status_normal ) THEN
            l_supervisor_id := ' ';
            l_prev_batch_no := ' ';
			
            rf_status := pl_rf_lm_common.lmc_batch_istart(l_user_id,l_prev_batch_no,l_supervisor_id);
            
            IF ( rf_status = rf.status_normal ) THEN
                l_parent_batch_no := ' ';
                IF ( i_merge_flag = 'Y' ) THEN
                    l_signon_type := LMF_MERGE_BATCH;
                ELSE
                    l_signon_type := LMF_SIGNON_BATCH;
                END IF;

                rf_status := pl_lm_forklift.lmf_signon_to_forklift_batch(l_signon_type,l_s_batch_no,l_parent_batch_no,
    														l_user_id,l_supervisor_id,l_equip_id);
            END IF;

        END IF;

        pl_text_log.ins_msg_async('INFO',l_func_name,'Ending attach_to_fklift_putaway_batch',sqlcode,sqlerrm);
        RETURN rf_status;
    END attach_to_fklift_putaway_batch; /* end attach_to_fklift_putaway_batch */
	
  /*************************************************************************
    NAME:  reset_forklift_batch
    CALLED BY:preputaway()
    DESC:  Resets the users current forklift batch.
  
    PARAMETERS:
       i_user_id   - User performing operation.
       i_equip_id  - Equipment being used.
       i_drop_loc  - Where the pallets were dropped.  Only the first 4
                     characters are used.  This can be door, bay or a slot.
                     A door will be 4 characters.  A bay will be the aisle-bay
                     and the slot will be the complete slot.  If an aisle-bay
                     then most likely the user keyed it in.
                     Examples:
                        Door     Bay     Slot
                        ----     ----    ------
                        D101     DA01    DA01A1
                        D108     DT23    DT23G1
                        F120     CB12    CB12B1
       i_haul_flag - Haul flag.
  **************************************************************************/

    FUNCTION reset_forklift_batch (
        i_user_id     IN VARCHAR2,
        i_equip_id    IN equip.equip_id%TYPE,
        i_drop_loc    IN VARCHAR2,
        i_haul_flag   IN VARCHAR2
    ) RETURN rf.status IS

        l_func_name         VARCHAR2(50) := 'reset_forklift_batch';
        rf_status           rf.status := rf.status_normal;
        l_user_id           VARCHAR2(31);
        l_equip_id          equip.equip_id%TYPE;
        l_drop_loc          VARCHAR2(11);
        l_batch_type_flag   VARCHAR2(1);
        
    BEGIN
        pl_text_log.ins_msg_async('INFO',l_func_name,' Starting reset_forklift_batch',sqlcode,sqlerrm);
        l_equip_id := i_equip_id;
        l_user_id := i_user_id;
        l_drop_loc := i_drop_loc;			/* Use only the first 4 chars of the drop location.  The location can be a door or bay.*/
	
        IF ( i_haul_flag = 'Y' ) THEN
            l_batch_type_flag := HAUL_BATCH_ID;
        ELSE
            l_batch_type_flag := FORKLIFT_PUTAWAY;
        END IF;
        pl_text_log.ins_msg_async('INFO',l_func_name,'Calling reset_forklift_batch.l_batch_type_flag='||l_batch_type_flag||
        'l_drop_loc-->'||l_drop_loc||'l_equip_id--->'||l_equip_id,sqlcode,sqlerrm);
        rf_status := pl_lm_forklift.lm_reset_current_fklft_batch(l_batch_type_flag,l_user_id,l_drop_loc,l_equip_id);
        pl_text_log.ins_msg_async('INFO',l_func_name,'Ending reset_forklift_batch',sqlcode,sqlerrm);
        RETURN rf_status;
    END reset_forklift_batch; /* end reset_forklift_batch */
	
  /*************************************************************************
    NAME: Check_Scan_Loss
	CALLED BY:preputaway()
    DESC: If a pallet is not registered as part of the shipment, create a 
          'ILP' transaction to indicate the loss of the pallet.
    RETURN VALUE:rf_status
  **************************************************************************/

    FUNCTION check_scan_loss RETURN rf.status IS

        l_func_name      VARCHAR2(50) := 'Check_Scan_Loss';
        l_hvc_snno       erd_lpn.sn_no%TYPE;
        l_hvc_palletid   putawaylst.pallet_id%TYPE;
        l_sz_dummy       VARCHAR2(1);
        rf_status        rf.status:=rf.STATUS_NORMAL;
    BEGIN
        pl_text_log.ins_msg_async('INFO',l_func_name,'starting Check_Scan_Loss',sqlcode,sqlerrm);
        l_hvc_palletid := g_client_obj.pallet_id;
        IF ( length(l_hvc_palletid) < 18 ) THEN
            RETURN rf.status_inv_label;
        ELSE
            BEGIN
                SELECT
                    'x'
                INTO l_sz_dummy
                FROM
                    trans
                WHERE
                    pallet_id = l_hvc_palletid
                    AND trans_type = 'ILP';
				/* pallet has been recorded for loss prevention */
				
                RETURN rf.status_inv_label;
				
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'No records for trans type ILP. pallet_id = ' || l_hvc_palletid,sqlcode,sqlerrm);
            END;

            BEGIN
                SELECT
                    'x'
                INTO l_sz_dummy
                FROM
                    trans
                WHERE
                    pallet_id = l_hvc_palletid
                    AND trans_type = 'PUT';

                RETURN rf.status_put_done;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'No PUT transaction in trans for pallet_id = ' || l_hvc_palletid,sqlcode,sqlerrm);
            END;

            BEGIN
                SELECT
                    sn_no
                INTO l_hvc_snno
                FROM
                    erd_lpn
                WHERE
                    pallet_id = l_hvc_palletid;
				/* pallet found in other SN */

                IF g_msku = 'N' THEN
                    g_server.po_no := rf.NoNull(l_hvc_snno);
                    RETURN rf.status_lossprev_lp_in_other_sn;
                ELSE
                    g_msku_server.po_no := rf.NoNull(l_hvc_snno);
                    RETURN rf.status_lossprev_lp_in_other_sn;
                END IF;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'pallet not found in any other SN. Pallet_id = ' || l_hvc_palletid,sqlcode,sqlerrm);
            END;

            BEGIN
				/* Insert record in trans for scan loss prevention */
                INSERT INTO trans (
                    trans_id,
                    trans_type,
                    trans_date,
                    user_id,
                    pallet_id,
                    batch_no,
                    cmt)
                 VALUES (
                    trans_id_seq.NEXTVAL,
                    'ILP',
                    SYSDATE,
                    user,
                    l_hvc_palletid,
                    99,
                    'Recorded for scan loss prevention');

				/*Set the flag. This flag will be used to commit the ILP transaction*/

                g_loss_prev_created := 1;
                RETURN rf.status_inv_label;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'Failed to create ILP transaction.pallet_id = ' || l_hvc_palletid,sqlcode,sqlerrm);
                    RETURN rf.status_trans_insert_failed;
            END;

        END IF;
        pl_text_log.ins_msg_async('INFO',l_func_name,'Ending check_scan_loss',sqlcode,sqlerrm);
		RETURN rf_status;
    END check_scan_loss;
	
  /*************************************************************************
    NAME:  vldt_and_populate_msku_info
	CALLED BY :preputaway for MSKU pallets
    DESC:  data for all the child pallets in the MSKU pallets is retrieved. 
           and then the server structure are populated. 
           List of all the pallets is sorted in put sequence. 
           The locations of these pallets are also passed to server structure
           Finally the reserve pallet location where the remaining pallets 
           (cases that were not put away in home or floating location) 
           must be put is passed to server structure.
  
    IN PARAMETERS: none
    RETURN VALUE :rf_status
      
  **************************************************************************/

    FUNCTION vldt_and_populate_msku_info RETURN rf.status IS

        l_func_name                 VARCHAR2(50) := 'vldt_and_populate_msku_info';
        rf_status                   rf.status := rf.status_normal;
        l_counter                   NUMBER := 0;
        l_strip_put                 loc.put_aisle%TYPE;
        l_strip_slot                loc.put_slot%TYPE;
        l_strip_level               loc.put_level%TYPE;
        l_put_path_val              loc.put_path%TYPE;
        l_cte_forklift_batch_flag   VARCHAR2(1);
        l_upc_comp_flag             VARCHAR2(1) := ' ';
        l_upc_scan_function         VARCHAR2(1) := ' ';
        l_is_parent_lpn             VARCHAR2(1) := 'N';
        l_pallet_id                 putawaylst.pallet_id%TYPE;			/*pallet id passed by the client(can be parent or child)*/
        l_equip_id                  equip.equip_id%TYPE;
        l_p_batch_no                batch.batch_no%TYPE;
        l_batch_no                  batch.batch_no%TYPE;
        l_cte_rtn_put_batch_flag    VARCHAR2(1);
        lbr_mgmt_flag               VARCHAR2(1);
        l_parent_pallet_id          putawaylst.pallet_id%TYPE;
        l_v_pallet_id               putawaylst.pallet_id%TYPE; 			/*for child pallets*/
        l_temp_pallet_id            putawaylst.pallet_id%TYPE; 			/* Work area */
        l_src_loc                   trans.src_loc%TYPE;
        l_v_dest_loc                trans.dest_loc%TYPE;
        l_v_put                     putawaylst.putaway_put%TYPE;
        l_n_qty_rec                 putawaylst.qty_received%TYPE;
        l_n_spc                     pm.spc%TYPE;
        l_v_inv_status              putawaylst.inv_status%TYPE;
        l_v_put_aisle               loc.put_aisle%TYPE;
        l_v_put_slot                loc.put_slot%TYPE;
        l_v_put_level               loc.put_level%TYPE;
        l_n_uom                     putawaylst.uom%TYPE;
        l_v_exp_date                VARCHAR2(6);
        l_v_prod_id                 putawaylst.prod_id%TYPE;
        l_v_po_no                   erd_lpn.po_no%TYPE;
        l_v_cust_pref_vendor        pm.cust_pref_vendor%TYPE;
        l_v_put_batch_no            VARCHAR2(14);						/* Putaway labor mgmt batch number.For returns it will be the
                                               												T batch number. */
        l_returns_put_batch_no      VARCHAR2(14); 						/* Returns putaway batch # */
        l_door_no                   erm.door_no%TYPE;
        l_msku_reserve_loc          putawaylst.dest_loc%TYPE;
        dummy                       VARCHAR2(8);
        l_sn_no                     erm.erm_id%TYPE;
        l_pallet_cnt                NUMBER := 0;
        l_c_upc_scan_function       VARCHAR2(1) := ' ';
        l_v_descrip                 VARCHAR2(31);
        l_force_date_collect_flag   VARCHAR2(1);
        l_exp_date_trk              VARCHAR2(1);
        l_mfg_date_trk              VARCHAR2(1);
        l_ml_flag                   VARCHAR2(1);
        l_mx_flag                   VARCHAR2(1);
        l_no_pallets                NUMBER := 0;
        l_add_msg_result_table      add_msg_result_table := add_msg_result_table ();

    BEGIN
        pl_text_log.ins_msg_async('INFO',l_func_name,' Starting vldt_and_populate_msku_info',sqlcode,sqlerrm);
        l_pallet_id := g_client_obj.pallet_id;
        l_equip_id := g_client_obj.equip_id;
        l_p_batch_no := g_client_obj.batch_no;
        
        SELECT
            l_p_batch_no
        INTO l_batch_no
        FROM
            dual;

        IF ( g_returns_flag != 'Y' ) THEN
            BEGIN
                SELECT DISTINCT
                    parent_pallet_id
                INTO l_parent_pallet_id
                FROM
                    erd_lpn
                WHERE
                    parent_pallet_id = l_pallet_id;

                l_is_parent_lpn := 'Y';
				
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    BEGIN
                        SELECT
                            parent_pallet_id
                        INTO l_parent_pallet_id
                        FROM
                            erd_lpn
                        WHERE
                            pallet_id = l_pallet_id;

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,' invalid pallet id = ' || l_pallet_id,sqlcode,sqlerrm);
                            RETURN rf.status_inv_label;
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,' ORACLE Unable to select from erd_lpn. PALLET_ID = ' || l_pallet_id,
                            sqlcode,sqlerrm);
                            RETURN rf.status_sel_erd_lpn_fail;
                    END;

                    BEGIN
                        SELECT
                            prod_id,
                            sn_no
                        INTO
                            l_v_prod_id,
                            l_v_po_no
                        FROM
                            erd_lpn
                        WHERE
                            pallet_id = l_pallet_id;

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,' invalid pallet id = ' || l_pallet_id,sqlcode,sqlerrm);
                            RETURN rf.status_inv_label;
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,' Unable to select from erd_lpn. PALLET_ID = ' || l_pallet_id,sqlcode,
                            sqlerrm);
                            RETURN rf.status_sel_erd_lpn_fail;
                    END;

                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,' Unable to select from erd_lpn. PALLET_ID = ' || l_pallet_id,sqlcode,sqlerrm);
                    RETURN rf.status_sel_erd_lpn_fail;
            END;
        ELSE /* returns_flag = 'Y': MSKU from returns */
            BEGIN
                SELECT DISTINCT
                    parent_pallet_id
                INTO l_parent_pallet_id
                FROM
                    putawaylst
                WHERE
                    parent_pallet_id = l_pallet_id;

                l_is_parent_lpn := 'Y';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    BEGIN
                        SELECT
                            parent_pallet_id
                        INTO l_parent_pallet_id
                        FROM
                            putawaylst
                        WHERE
                            pallet_id = l_pallet_id;

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,' invalid pallet id = ' || l_pallet_id,sqlcode,sqlerrm);
                            RETURN rf.status_inv_label;
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to select from putawaylst. PALLET_ID = ' || l_pallet_id,sqlcode,
                            sqlerrm);
                            RETURN rf.status_sel_putawaylst_fail;
                    END;

                    BEGIN
                        SELECT
                            prod_id,
                            rec_id
                        INTO
                            l_v_prod_id,
                            l_v_po_no
                        FROM
                            putawaylst
                        WHERE
                            pallet_id = l_pallet_id;

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,' invalid pallet id = ' || l_pallet_id,sqlcode,sqlerrm);
                            RETURN rf.status_inv_label;
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,'ORACLE Unable to select from putawaylst. PALLET_ID = ' || l_pallet_id,
                            sqlcode,sqlerrm);
                            RETURN rf.status_sel_erd_lpn_fail;
                    END;

                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to select from putawaylst.PALLET_ID = ' || l_pallet_id,sqlcode,sqlerrm);
                    RETURN rf.status_sel_erd_lpn_fail;
            END;
        END IF;

			/* end returns_flag = 'Y' */
			/*parent_pallet_id finally determined and set*/
			/*
			Check added to check "PUT_DONE" condition
			*/

        BEGIN

            -- OPCOF-3577 Using pallet id instead parent pallet id because XN PO MSKU records have a space in parent pallet id.
            IF ( g_erm_type = 'XN' OR ( g_erm_type = 'CM' AND g_erm_id LIKE 'X%' )) THEN 

                SELECT
                    'N'
                INTO l_v_put
                FROM
                    putawaylst
                WHERE
                    pallet_id = l_pallet_id
                    AND putaway_put = 'N'
                    AND ROWNUM = 1;

              ELSE

                SELECT
                    'N'
                INTO l_v_put
                FROM
                    putawaylst
                WHERE
                    parent_pallet_id = l_parent_pallet_id
                    AND putaway_put = 'N'
                    AND ROWNUM = 1;

            END IF;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                IF ( g_erm_type = 'XN' OR ( g_erm_type = 'CM' AND g_erm_id LIKE 'X%' )) THEN 
                    pl_text_log.ins_msg_async('WARN',l_func_name,'Putaway already done. pallet id = ' || l_pallet_id,sqlcode,sqlerrm);
                  ELSE
                    pl_text_log.ins_msg_async('WARN',l_func_name,'Putaway already done. Parent pallet id = ' || l_parent_pallet_id,sqlcode,sqlerrm);
                END IF;
                RETURN rf.status_put_done;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,' Unable to select from putawaylst.Parent pallet id = ' || l_parent_pallet_id,sqlcode,
                sqlerrm);
                RETURN rf.status_sel_putawaylst_fail;
        END;

		/*
		Check the location is valid or not.
		Throw error in case location is "*" out for any of the child LP. */

        
            SELECT
                COUNT(pallet_id)
            INTO l_no_pallets
            FROM
                putawaylst p
            WHERE
                p.dest_loc = '*'
                AND p.parent_pallet_id = l_parent_pallet_id;

            IF ( l_no_pallets > 0 ) THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'Some of the child LPs on MSKU have been * out for the putaway dest loc.',sqlcode,
                sqlerrm);
                RETURN rf.status_inv_location;
            END IF;

        IF ( g_returns_flag != 'Y' ) THEN
            IF ( l_is_parent_lpn = 'Y' ) THEN
                g_msku_server.upc_comp_flag := 'Y';
                BEGIN
                    l_c_upc_scan_function := pl_common.f_get_syspar('UPC_SCAN_FUNCTION','x');
                    g_msku_server.upc_scan_function := l_c_upc_scan_function;
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,' Unable to select from sys_config',sqlcode,sqlerrm);
                        RETURN rf.status_sel_syscfg_fail;
                END;

            ELSE
				pl_check_upc.check_upc_data_collection(l_v_prod_id,l_v_po_no,putaway,l_upc_comp_flag,l_upc_scan_function);
                g_msku_server.upc_comp_flag := rf.NoNull(l_upc_comp_flag);
                g_msku_server.upc_scan_function := rf.NoNull(l_upc_scan_function);
                pl_text_log.ins_msg_async('INFO',l_func_name,'VALIDATION:Flags returned from the check_upc function. upc_comp_flag = '
                                                    || g_msku_server.upc_comp_flag
                                                    || ' upc_scan_function = '
                                                    || g_msku_server.upc_scan_function,sqlcode,sqlerrm);

            END IF;
        ELSE /* returns_flag = 'Y' */
            g_msku_server.upc_scan_function := 'W';
        END IF;

		/*
		 Get the sn_no on the basis of parent pallet id
		 only if the input pallet id is parent LPN*/

        IF ( g_returns_flag != 'Y' ) THEN
            BEGIN
                IF ( l_is_parent_lpn = 'Y' ) THEN
                    SELECT
                        sn_no
                    INTO l_sn_no
                    FROM
                        erd_lpn
                    WHERE
                        parent_pallet_id = l_parent_pallet_id
                        AND ROWNUM = 1;

                ELSE
                    SELECT
                        sn_no
                    INTO l_sn_no
                    FROM
                        erd_lpn
                    WHERE
                        pallet_id = l_pallet_id
                        AND ROWNUM = 1;

                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,' Unable to select from erd_lpn ' || l_parent_pallet_id,sqlcode,sqlerrm);
                    RETURN rf.status_sel_erd_lpn_fail;
            END;
        END IF;

		/*
		 Condition added to make sure the zero received pallet
		 won't be sent to RF client program.
		*/

        BEGIN
            SELECT
                COUNT(DISTINCT(pallet_id) )
            INTO l_pallet_cnt
            FROM
                putawaylst
            WHERE
                parent_pallet_id = l_parent_pallet_id
                AND qty_received <> 0;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,' Unable to select from putawaylst.parent_pallet_id = ' || l_parent_pallet_id,sqlcode,
                sqlerrm);
                RETURN rf.status_sel_putawaylst_fail;
        END;

		/*
		** Set the labor mgmt flags.
		*/

        set_labor_mgmt_flags(lbr_mgmt_flag,l_cte_rtn_put_batch_flag);

		/* Check forklift create flag.*/
        IF ( pl_lm_forklift.lmf_forklift_active () != 0 ) THEN
            l_cte_forklift_batch_flag := 'N';
        ELSE
            l_cte_forklift_batch_flag := 'Y';
        END IF;

			
			/*  Check if door_no is in the erm table, and if so add it to the data
			**  going back to the RF's
			** 
			** For returns get the door number from the KVI_FROM_LOC in the BATCH table
			** for the T batch.  Returns will not have the ERM.DOOR_NO populated.
			** The returns processing would have populated BATCH.KVI_FROM_LOC with the
			** staging location which most likely is a door number.  The T batch number
			** is the parent pallet id.
			*/

        IF ( g_returns_flag != 'Y' ) THEN
            BEGIN
                SELECT
                    e.door_no,
                    e.erm_id
                INTO
                    l_door_no,
                    l_sn_no
                FROM
                    erm e,
                    putawaylst p
                WHERE
                    p.rec_id = e.erm_id
                    AND p.parent_pallet_id = l_parent_pallet_id
                    AND p.rec_id = l_sn_no
                    AND e.door_no IS NOT NULL
                    AND ROWNUM = 1;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'NO door_no found for this SN.parent_pallet_id = ' || l_parent_pallet_id,sqlcode,
                    sqlerrm);
                    l_door_no := '0000';
            END;
        ELSE
			  /*
			  ** Processing a return.  Get the door number from the T batch.
			  ** The :parent_pallet_id has the T batch number.
			  ** Use the value of the first record selected.  They should all be
			  ** the same.  Note that we do not necessarily need all the joins but
			  ** they do perform a sanity check.
			  */
            BEGIN
                SELECT
                    b.kvi_from_loc,
                    e.erm_id
                INTO
                    l_door_no,
                    l_sn_no
                FROM
                    batch b,
                    erm e,
                    putawaylst p
                WHERE
                    p.rec_id = e.erm_id
                    AND p.parent_pallet_id = l_parent_pallet_id
                    AND b.kvi_from_loc IS NOT NULL
                    AND b.batch_no = l_parent_pallet_id
                    AND ROWNUM = 1;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'No door#(staging loc) found for this returns PO.  
					The batch.kvi_from_loc should have the staging loc for the returns.  Will use 0000.',
                    sqlcode,sqlerrm);
                    l_door_no := '0000';
            END;
        END IF;

		/*
		  Following labor mgmt functions need to be called only once for 
		  the MSKU pallet
		  attach_to_fklift_putaway_batch
		  lmc_get_haul_location
		*/
		/*
		 ** Get the location of the pallet if it has been hauled.
		 ** The function needs a null terminated pallet id.
		 */

        IF ( g_erm_type = 'XN' OR ( g_erm_type = 'CM' AND g_erm_id LIKE 'X%' )) THEN 
            l_temp_pallet_id := l_pallet_id;
          ELSE
            l_temp_pallet_id := l_parent_pallet_id;
        END IF;
        rf_status := pl_rf_lm_common.lmc_get_haul_location(l_temp_pallet_id,l_src_loc);
        IF ( rf_status != rf.status_normal ) THEN
			/* lmc_get_haul_location generated an oracle error. */
            RETURN rf_status;
        END IF;

		/*
		** If the pallet was not hauled then the trans src_loc will be the door#.
		** Function lmc_get_haul_location will set the location to a null string
		** if the pallet has not been hauled.
		*/
        IF ( length(l_src_loc) = 0 ) THEN
		  /*
		  ** The pallet has not been hauled.  The trans src_loc will be
		  ** the door#.
		  */
            l_src_loc := l_door_no;
        END IF;

		/*Get the force data collection syspar*/
        BEGIN
            dummy := pl_common.f_get_syspar('FORCE_DATE_COLLECT','N');
            IF dummy = 'Y' THEN
                l_force_date_collect_flag := 'Y';
            ELSE
                l_force_date_collect_flag := 'N';
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'FORCE_DATE_COLLECT:Force date collection before putaway flag is off.parent_pallet_id = '
                || l_parent_pallet_id,sqlcode,sqlerrm);
                l_force_date_collect_flag := 'N';
        END;

		/*the following cursor is for selecting the details for child LPs going to
			 floating and pick locations.*/
		DECLARE
		        CURSOR c_child_pallets IS SELECT
                                      p.pallet_id,
                                      p.dest_loc,
                                      p.rec_id,
                                      p.putaway_put,
                                      pm.prod_id,
                                      pm.cust_pref_vendor,
                                      pm.descrip,
                                      pm.spc,
                                      p.inv_status,
                                      lpad(ltrim(rtrim(TO_CHAR(l.put_aisle) ) ),3,'0'),
                                      lpad(ltrim(rtrim(TO_CHAR(l.put_slot) ) ),3,'0'),
                                      lpad(ltrim(rtrim(TO_CHAR(l.put_level) ) ),3,'0'),
                                      p.uom,
                                      TO_CHAR(p.exp_date,'MMDDYY'),
                                      p.pallet_batch_no,
                                      p.qty_received,
                                      p.exp_date_trk,
                                      p.date_code,
                                      pl_ml_common.f_is_induction_loc(p.dest_loc),
                                      pl_matrix_common.f_is_induction_loc_yn(p.dest_loc)
                                  FROM
                                      loc l,
                                      putawaylst p,
                                      pm,
                                      lzone lz,
                                      zone z
                                  WHERE
                                      l.logi_loc = p.dest_loc
                                      AND p.prod_id = pm.prod_id
                                      AND p.parent_pallet_id = l_parent_pallet_id
                                      AND p.putaway_put = 'N'
                                      AND p.cust_pref_vendor = pm.cust_pref_vendor
                                      AND p.qty_received <> 0
                                      AND l.logi_loc = lz.logi_loc
                                      AND lz.zone_id = z.zone_id
                                      AND z.zone_type = 'PUT'
                                      AND ( z.rule_id IN (
                                          1,
                                          2,
                                          3
                                      )
                                            OR l.perm = 'Y'
                                            OR pm.mx_item_assign_flag = 'Y' )
                                  ORDER BY
                                      l.put_aisle,
                                      l.put_slot,
                                      l.put_level;
        BEGIN
            l_counter := 0;
            OPEN c_child_pallets;
            LOOP
                FETCH c_child_pallets INTO
                    l_v_pallet_id,
                    l_v_dest_loc,
                    l_sn_no,
                    l_v_put,
                    l_v_prod_id,
                    l_v_cust_pref_vendor,
                    l_v_descrip,
                    l_n_spc,
                    l_v_inv_status,
                    l_v_put_aisle,
                    l_v_put_slot,
                    l_v_put_level,
                    l_n_uom,
                    l_v_exp_date,
                    l_v_put_batch_no,
                    l_n_qty_rec,
                    l_exp_date_trk,
                    l_mfg_date_trk,
                    l_ml_flag,
                    l_mx_flag;

                EXIT WHEN c_child_pallets%notfound;
                
                BEGIN
                    SELECT
                        'x'
                    INTO dummy
                    FROM
                        zequip z,
                        lzone l
                    WHERE
                        z.zone_id = l.zone_id
                        AND z.equip_id = l_equip_id
                        AND l.logi_loc = l_v_dest_loc;

                    
                EXCEPTION
                    WHEN TOO_MANY_ROWS THEN
                        NULL;
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'putaway attempted with wrong equipment. Pallet_id = ' || l_pallet_id,sqlcode,sqlerrm);
                        RETURN rf.status_wrong_equip;
                END;

				/* See if item is to-be-aged (in on-hold status 
				  ** already.) Ok to putaway if it is. For returns, cannot putaway
				  ** no matter if the item is in aging or not.*/

                IF l_v_inv_status = 'HLD' THEN
                    BEGIN
                        SELECT
                            'Y'
                        INTO dummy
                        FROM
                            aging_items
                        WHERE
                            prod_id = l_v_prod_id
                            AND cust_pref_vendor = l_v_cust_pref_vendor;

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,'VALIDATION:pallet is unavailable.Pallet is on hold. PALLET_ID = ' ||
                             l_v_pallet_id,sqlcode,sqlerrm);
                            RETURN rf.status_pallet_on_hold;
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,'unable to get AGING_ITEMS record. PALLET_ID:'
                                                                || l_v_pallet_id
                                                                || ' PROD_ID = '
                                                                || l_v_prod_id,sqlcode,sqlerrm);

                            RETURN rf.status_sel_aging_fail;
                    END;
                END IF;

                IF l_force_date_collect_flag = 'Y' AND ( l_exp_date_trk = 'Y' OR l_mfg_date_trk = 'Y' ) THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'Force on and need exp_date or mfg_date before allowing putaway. PALLET_ID = '
                                                        || l_v_pallet_id
                                                        || ' force_date_collect_flag = '
                                                        || l_force_date_collect_flag
                                                        || ' exp_date_trk = '
                                                        || l_exp_date_trk
                                                        || ' l_mfg_date_trk = '
                                                        || l_mfg_date_trk,sqlcode,sqlerrm);

                    RETURN rf.status_need_expmfg_date_info;
                END IF;

				/*
				**  Mark the pallet as picked up by the user.
				*/

                BEGIN
                    INSERT INTO trans (
                        trans_id,
                        trans_date,
                        trans_type,
                        user_id,
                        rec_id,
                        pallet_id,
                        src_loc,
                        dest_loc,
                        prod_id,
                        cust_pref_vendor,
                        exp_date,
                        qty,
                        uom,
                        cmt,
                        parent_pallet_id,
                        labor_batch_no)
                     VALUES (
                        trans_id_seq.NEXTVAL,
                        SYSDATE,
                        'PPU',
                        user,
                        l_sn_no,
                        l_v_pallet_id,
                        l_src_loc,
                        l_v_dest_loc,
                        l_v_prod_id,
                        l_v_cust_pref_vendor,
                        TO_DATE(l_v_exp_date,'MMDDRR'),
                        l_n_qty_rec,
                        l_n_uom,
                        l_v_put,
                        l_parent_pallet_id,
                        l_v_put_batch_no);

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'unable to create PPU transaction. PALLET_ID = '
                                                            || l_v_pallet_id
                                                            || ' dest_loc = '
                                                            || l_v_dest_loc,sqlcode,sqlerrm);

                        RETURN rf.status_trans_insert_failed;
                END;

				/*  we need to populate child pallet id in pallet_id field of "add_msg_preputaway_server".*/

                l_add_msg_result_table.extend;
                l_strip_put := l_v_put_aisle;
                l_strip_slot := l_v_put_slot;
                l_strip_level := l_v_put_level;
                l_put_path_val :=l_strip_put||l_strip_slot||l_strip_level;
                l_ml_flag := 'N';
                IF g_returns_flag = 'Y' THEN
                    l_ml_flag := 'N';
                ELSIF l_ml_flag = 'Y' THEN
                    l_ml_flag := 'Y';
                ELSIF l_mx_flag = 'Y' THEN
                    l_ml_flag := 'N';
                ELSE
                    l_ml_flag := 'N';
                END IF;

                l_add_msg_result_table(l_add_msg_result_table.count) := add_msg_server_result_record(rf.NoNull(l_v_pallet_id),
                                                        rf.NoNull(l_v_dest_loc),rf.NoNull(l_put_path_val),
				rf.NoNull(l_v_prod_id),rf.NoNull(l_v_cust_pref_vendor),NVL(l_v_descrip, ' '),rf.NoNull(l_v_exp_date),rf.NoNull(l_n_qty_rec),rf.NoNull(l_n_spc),rf.NoNull(l_ml_flag));

                pl_text_log.ins_msg_async('WARN',l_func_name,'Values l_counter = '
                                                    || l_add_msg_result_table.count
                                                    || 'KEY = exp date value is '
                                                    || l_v_exp_date
                                                    || ' exp date length is '
                                                    || length(l_v_exp_date)
                                                    || ' descrip value is '
                                                    || l_v_descrip
                                                    || ' ml_flag = '
                                                    || l_ml_flag,sqlcode,sqlerrm);

            END LOOP;

            g_add_msg_result_table := l_add_msg_result_table;
            g_add_msg_server := add_msg_server_result_obj(l_add_msg_result_table);
            CLOSE c_child_pallets;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'No child records found for parent pallet which are not going to reserve.parent_pallet_id = '
														|| l_parent_pallet_id,sqlcode,sqlerrm);
                GOTO reserve;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to open c_child_pallets cursor for parent pallet. parent_pallet_id = ' 
								|| l_parent_pallet_id,sqlcode,sqlerrm);               
                rf_status := rf.status_inv_location;
                RETURN rf_status;
        END;

        << reserve >> 
		g_msku_server.rlc_flag := 'N';
        BEGIN
            dummy := pl_common.f_get_syspar('RTN_PUTAWAY_CONF','N');
            IF dummy = 'N' THEN
                g_msku_server.rtn_putaway_conf := 'N';
                pl_text_log.ins_msg_async('INFO',l_func_name,'Returns putaway flag is set to N',sqlcode,sqlerrm);
            ELSE
                g_msku_server.rtn_putaway_conf := 'Y';
                pl_text_log.ins_msg_async('INFO',l_func_name,'Returns putaway flag is set to Y',sqlcode,sqlerrm);
            END IF;

        END;

        g_msku_server.door_no := rf.NoNull(l_door_no);
        g_msku_server.po_no := rf.NoNull(l_sn_no);
        g_msku_server.pallet_cnt := rf.NoNull(l_pallet_cnt);
        g_pallet_count := rf.NoNull(l_pallet_cnt);
        g_msku_server.forklift_lbr_trk := rf.NoNull(l_cte_forklift_batch_flag);
        g_msku_server.parent_pallet_id := rf.NoNull(l_parent_pallet_id);

		/*
		** Check if the MSKU will be going to a reserve location.
		** Some company has floating items in bulk rule zone (rule_id=2).
		*/
        BEGIN
            SELECT
                p.dest_loc
            INTO l_msku_reserve_loc
            FROM
                loc l,
                putawaylst p,
                lzone lz,
                zone z,
                pm
            WHERE
                l.logi_loc = p.dest_loc
                AND p.putaway_put = 'N'
                AND ((z.rule_id = 14 AND p.pallet_id = l_pallet_id)
                 OR (z.rule_id <> 14 AND p.parent_pallet_id = l_parent_pallet_id))
                AND p.rec_id = l_sn_no
                AND p.prod_id = pm.prod_id(+)
                AND pm.last_ship_slot IS NULL
                AND l.logi_loc = lz.logi_loc
                AND lz.zone_id = z.zone_id
                AND z.zone_type = 'PUT'
                AND z.rule_id IN (
                    0,
                    2,
                    5, 
                    14)
                AND l.perm = 'N'
                AND ROWNUM = 1;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
			  /*
			   ** Sanity check to verify the destination location has a PUT zone.
			  */
                BEGIN
                    SELECT
                        p.dest_loc
                    INTO l_msku_reserve_loc
                    FROM
                        loc l,
                        putawaylst p
                    WHERE
                        l.logi_loc = p.dest_loc
                        AND p.putaway_put = 'N'
                        AND p.parent_pallet_id = l_parent_pallet_id
                        AND p.rec_id = l_sn_no
                        AND ROWNUM = 1
                        AND NOT EXISTS (
                            SELECT
                                'x'
                            FROM
                                zone z,
                                lzone lz
                            WHERE
                                z.zone_id = lz.zone_id
                                AND lz.logi_loc = p.dest_loc
                                AND z.zone_type = 'PUT');


                    pl_text_log.ins_msg_async('WARN',l_func_name,'PUT zone has not been set up for reserve/floating location',sqlcode,sqlerrm);

                    RETURN rf.status_inv_location;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'All child pallets on MSKU pallet have been assigned to home or floating locations',
                        sqlcode,sqlerrm);
                        GOTO end1;
                END;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'Error checking if the MSKU is going to a reserve/floating slot',sqlcode,sqlerrm);
                RETURN rf.status_sel_putawaylst_fail;
        END;

        DECLARE
            CURSOR c_reserve IS SELECT
                                    p.pallet_id,
                                    p.dest_loc,
                                    p.putaway_put,
                                    p.inv_status,
                                    p.uom,
                                    pm.prod_id,
                                    pm.cust_pref_vendor,
                                    pm.descrip,
                                    pm.spc,
                                    TO_CHAR(p.exp_date,'FXMMDDRR'),
                                    p.pallet_batch_no,
                                    lpad(ltrim(rtrim(TO_CHAR(l.put_aisle) ) ),3,'0'),
                                    lpad(ltrim(rtrim(TO_CHAR(l.put_slot) ) ),3,'0'),
                                    lpad(ltrim(rtrim(TO_CHAR(l.put_level) ) ),3,'0'),
                                    p.qty_received,
                                    p.exp_date_trk,
                                    p.date_code
                                FROM
                                    putawaylst p,
                                    pm,
                                    loc l,
                                    lzone lz,
                                    zone z
                                WHERE
                                    p.dest_loc = l.logi_loc
                                    AND pm.prod_id = p.prod_id
                                    AND p.putaway_put = 'N'
                                    AND ((z.rule_id = 14 AND p.pallet_id = l_pallet_id)
                                     OR (z.rule_id <> 14 AND p.parent_pallet_id = l_parent_pallet_id))
                                    AND p.rec_id = l_sn_no
                                    AND p.qty_received <> 0
                                    AND l.logi_loc = lz.logi_loc
                                    AND lz.zone_id = z.zone_id
                                    AND z.zone_type = 'PUT'
                                    AND z.rule_id IN (
                                        0,
                                        2,
                                        5, 
                                        14)

                                    AND l.perm = 'N';

        BEGIN
            OPEN c_reserve;
            LOOP
                FETCH c_reserve INTO
                    l_v_pallet_id,
                    l_v_dest_loc,
                    l_v_put,
                    l_v_inv_status,
                    l_n_uom,
                    l_v_prod_id,
                    l_v_cust_pref_vendor,
                    l_v_descrip,
                    l_n_spc,
                    l_v_exp_date,
                    l_v_put_batch_no,
                    l_v_put_aisle,
                    l_v_put_slot,
                    l_v_put_level,
                    l_n_qty_rec,
                    l_exp_date_trk,
                    l_mfg_date_trk;

                EXIT WHEN c_reserve%notfound;
                BEGIN
                    SELECT
                        'x'
                    INTO dummy
                    FROM
                        zequip z,
                        lzone l
                    WHERE
                        z.zone_id = l.zone_id
                        AND z.equip_id = l_equip_id
                        AND l.logi_loc = l_v_dest_loc;

                EXCEPTION
                    WHEN TOO_MANY_ROWS THEN
                        NULL;
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'putaway attempted with wrong equipment. Pallet_id = ' || l_pallet_id,sqlcode,sqlerrm);
                        RETURN rf.status_wrong_equip;
                END;

                IF l_v_inv_status = 'HLD' THEN
                    BEGIN
                        SELECT
                            'Y'
                        INTO dummy
                        FROM
                            aging_items
                        WHERE
                            prod_id = l_v_prod_id
                            AND cust_pref_vendor = l_v_cust_pref_vendor;

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,'pallet is unavailable.Pallet is on hold. PALLET_ID = ' || l_v_pallet_id,
                            sqlcode,sqlerrm);
                            RETURN rf.status_pallet_on_hold;
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,'unable to get AGING_ITEMS record. PALLET_ID = '
                                                                || l_v_pallet_id
                                                                || ' PROD_ID = '
                                                                || l_v_prod_id,sqlcode,sqlerrm);

                            RETURN rf.status_sel_aging_fail;
                    END;
                END IF;

				/*Check for force data collection*/

                IF l_force_date_collect_flag = 'Y' AND ( l_exp_date_trk = 'Y' OR l_mfg_date_trk = 'Y' ) THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'Force on and need exp_date or mfg_date before allowing putaway. PALLET_ID = '
                                                        || l_v_pallet_id
                                                        || ' force_date_collect_flag = '
                                                        || l_force_date_collect_flag
                                                        || ' exp_date_trk = '
                                                        || l_exp_date_trk
                                                        || ' l_mfg_date_trk = '
                                                        || l_mfg_date_trk,sqlcode,sqlerrm);

                    RETURN rf.status_need_expmfg_date_info;
                END IF;

                BEGIN
					/*
					 **  Mark the pallet as picked up by the user.
					 */
                    INSERT INTO trans (
                        trans_id,
                        trans_date,
                        trans_type,
                        user_id,
                        rec_id,
                        pallet_id,
                        src_loc,
                        dest_loc,
                        prod_id,
                        cust_pref_vendor,
                        exp_date,
                        qty,
                        uom,
                        cmt,
                        parent_pallet_id,
                        labor_batch_no)
                     VALUES (
                        trans_id_seq.NEXTVAL,
                        SYSDATE,
                        'PPU',
                        user,
                        l_sn_no,
                        l_v_pallet_id,
                        l_src_loc,
                        l_v_dest_loc,
                        l_v_prod_id,
                        l_v_cust_pref_vendor,
                        TO_DATE(l_v_exp_date,'FXMMDDRR'),
                        l_n_qty_rec,
                        l_n_uom,
                        l_v_put,
                        l_parent_pallet_id,
                        l_v_put_batch_no);

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'unable to create PPU transaction. PALLET_ID = '
                                                            || l_v_pallet_id
                                                            || ' dest_loc = '
                                                            || l_v_dest_loc,sqlcode,sqlerrm);

                        RETURN rf.status_trans_insert_failed;
                END;

                l_add_msg_result_table.extend;
                l_strip_put := l_v_put_aisle;
                l_strip_slot := l_v_put_slot;
                l_strip_level := l_v_put_level;
                l_put_path_val := l_strip_put||l_strip_slot||l_strip_level;
                pl_text_log.ins_msg_async('INFO',l_func_name,'Values l_counter = '
                                                    || l_add_msg_result_table.count
                                                    || ' KEY= exp date value is '
                                                    || l_v_exp_date
                                                    || ' exp date length is '
                                                    || length(l_v_exp_date)
                                                    || ' descrip value is '
                                                    || l_v_descrip,sqlcode,sqlerrm);


                l_add_msg_result_table(l_add_msg_result_table.count) := add_msg_server_result_record(rf.NoNull(l_v_pallet_id),rf.NoNull(l_v_dest_loc),rf.NoNull(l_put_path_val),
				rf.NoNull(l_v_prod_id),rf.NoNull(l_v_cust_pref_vendor),NVL(l_v_descrip, ' '),rf.NoNull(l_v_exp_date),rf.NoNull(l_n_qty_rec),rf.NoNull(l_n_spc),rf.NoNull(l_ml_flag));

            END LOOP;

            g_add_msg_result_table := l_add_msg_result_table;
            g_add_msg_server := add_msg_server_result_obj(l_add_msg_result_table);
            CLOSE c_reserve;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'No child records found for parent pallet which are not going to reserve.parent_pallet_id = '
                || l_parent_pallet_id,sqlcode,sqlerrm);
                rf_status := rf.status_inv_location;
                GOTO end1;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'Unable open c_reserve cursor for parent pallet '|| l_parent_pallet_id,sqlcode,
                sqlerrm);
                rf_status := rf.status_inv_location;
                RETURN rf_status;
        END;

        << end1 >> 
		IF ( rf_status = rf.status_normal ) THEN
		  /*
		  Copy the reseve location in server structure*/
            g_msku_server.msku_reserve_loc := rf.NoNull(l_msku_reserve_loc);

			  /*
			  ** Create the returns putaway labor mgmt batches (almost identical to
			  ** putaway for a RDC MSKU) if this is a return and returns putaway labor
			  ** mgmt is active.  The batches are created using the LP scanned
			  ** by the user.  One batch will be created for each LP on the returns
			  ** MSKU.  The returns processing would have tied the putawaylst records
			  ** together by the parent pallet id.  The last child LP processed is
			  ** used to create the batches.  Any child LP would work.
			  */
            IF ( g_returns_flag = 'Y' AND l_cte_rtn_put_batch_flag = 'Y' ) THEN
				/*
				** Set max length of pl/sql block "out" variables.
				*/
                DECLARE
                    l_message       VARCHAR2(512); -- Message buffer
                    l_object_name   VARCHAR2(60) := 'vldt_and_populate_msku_info()';
                    l_t_batch_no    arch_batch.batch_no%TYPE; -- T batch number.
                BEGIN
					-- At this point parent_pallet_id has the T batch number.
                    l_t_batch_no := l_parent_pallet_id;

					-- pl_lmf.create_returns_putaway_batches will populate
					-- o_batch_no with the labor mgmt batch number created
					-- for i_pallet_id.  This batch number is later used to
					-- attach to all the batches on the returns MSKU.
                    pl_lmf.create_returns_putaway_batches(i_pallet_id => l_v_pallet_id,i_force_creation_bln => false,o_batch_no =>
                     l_returns_put_batch_no);

					-- Now change the T batch status to 'F' which will
					-- make the batch no longer available to be used for more
					-- returns.  The current status should be 'X' or 'F'.
					-- Setting to F again saves having to have another stmt
					-- confirming the status is 'X' or 'F'.
					-- Also set the msku_batch_flag to Y since a T batch is
					-- handled like a MSKU.

                    BEGIN
                        UPDATE batch
                        SET
                            status = 'F',
                            msku_batch_flag = 'Y'
                        WHERE
                            batch_no = l_t_batch_no
                            AND status IN (
                                'X',
                                'F');

						-- Verify the batch was updated.

                        IF ( SQL%notfound ) THEN
                            l_message := l_object_name
                                         || '  TABLE=batch  ACTION=UPDATE  l_t_batch_no=['
                                         || l_t_batch_no
                                         || ']'
                                         || '  MESSAGE="Batch not found or status not X or F."';
                            pl_text_log.ins_msg_async(pl_lmc.ct_fatal_msg,l_object_name,l_message,sqlcode,sqlerrm);
                            RAISE pl_exc.e_lm_batch_upd_fail;
                        END IF;

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,'Error returned from create_returns_putaway_batches ',sqlcode,sqlerrm);
                            RAISE;
                    END;

                EXCEPTION
                    WHEN OTHERS THEN
						/*
							** Got an error in the pl_lmf.create_returns_putaway_batches
						   */
                        pl_text_log.ins_msg_async('WARN',l_func_name,'create_returns_putaway_batches returned an error 
												when creating the returns putaway labor mgmt batches .PALLET_ID = '
											|| l_v_pallet_id,sqlcode,sqlerrm);
                        rf_status := rf.status_lm_batch_upd_fail;
                END;

                l_v_put_batch_no := l_parent_pallet_id;
            END IF;

			  /*
			  ** Attach to the putaway labor mgmt batch if one of the following
			  ** is true:
			  **    - Forklift labor mgmt is active and it is not a return.
			  **    - It is a return and returns putaway labor mgmt is active.
			  */

            IF ( ( rf_status = rf.status_normal ) AND ( ( l_cte_forklift_batch_flag = 'Y' AND g_returns_flag = 'N' ) OR
						( g_returns_flag = 'Y' AND l_cte_rtn_put_batch_flag = 'Y' ) ) ) THEN
          
                rf_status := attach_to_fklift_putaway_batch(USER,l_equip_id,l_parent_pallet_id,g_client_obj.haul_flag,
							g_client_obj.merge_flag,l_v_put_batch_no);
                
                pl_text_log.ins_msg_async('INFO',l_func_name,'after call attach_to_fklift_putaway_batch.rf_status = ' || rf_status,sqlcode,sqlerrm);
              
            END IF;

        END IF;

        pl_text_log.ins_msg_async('INFO',l_func_name,'Ending vldt_and_populate_msku_info with rf_status = ' || rf_status,sqlcode,sqlerrm);
        RETURN rf_status;
    END vldt_and_populate_msku_info; /* end vldt_and_populate_msku_info */
	
  /*******************************<+>******************************************
  **  Function:
  **     set_labor_mgmt_flags
  **
  **  Description:
  **     This function sets the labor mgmt flags.
  **
  **  Parameters:
  **     - o_lbr_mgmt_flag           - Designates if labor tracking is active.
  **     - o_cte_rtn_put_batch_flag  - Designates if the returns labor tracking
  **                                   function is active.  If labor tracking is
  **                                   off then this will be set to off regardless
  **                                   of it's setting.
  **  Called By:
  **			preputaway()
  **  Return Values:
  **     Always NORMAL.  If a select fails then a default value of 'N' is used.
  **
  **  Modification Log:
  **
  **   Date         Developer      Comment
  **   -----------------------------------------------------------------------
  **   8-Mar-2021   pkab6563       Replaced the old return put labor
  **                               function RP by the new (DC).
  **  
  ********************************<->******************************************/

    PROCEDURE set_labor_mgmt_flags (
        o_lbr_mgmt_flag            OUT VARCHAR2,
        o_cte_rtn_put_batch_flag   OUT VARCHAR2
    ) IS

        l_func_name                  VARCHAR2(50) := 'set_labor_mgmt_flags';
        l_c_cte_rtn_put_batch_flag   VARCHAR2(1);		/* Returns putaway tracking labor function flag. */
        dummy                        VARCHAR2(1);
    BEGIN
        pl_text_log.ins_msg_async('INFO',l_func_name,' Starting set_labor_mgmt_flags',sqlcode,sqlerrm);
        dummy := pl_common.f_get_syspar('LBR_MGMT_FLAG','N');
        IF dummy = 'Y' THEN
            o_lbr_mgmt_flag := 'Y';
            BEGIN
                SELECT
                    create_batch_flag
                INTO l_c_cte_rtn_put_batch_flag
                FROM
                    lbr_func
                WHERE
                    lfun_lbr_func = 'DC';

                o_cte_rtn_put_batch_flag := l_c_cte_rtn_put_batch_flag;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'unable to get labor mgmt returns putaway batch flag.Will use N as value.',
                    sqlcode,sqlerrm);
                    o_cte_rtn_put_batch_flag := 'N';
            END;

        ELSE
            o_lbr_mgmt_flag := 'N';
            o_cte_rtn_put_batch_flag := 'N';
        END IF;

        pl_text_log.ins_msg_async('INFO',l_func_name,'Ending set_labor_mgmt_flags',sqlcode,sqlerrm);
    END set_labor_mgmt_flags;
	
  /*************************************************************************
    NAME: get_pallet_id_on_batch
	
	CALLED BY:preputaway()
	 
    DESC:  Finds a pallet id on the specified returns labor batch.
  
    INPUT PARAMETERS:
      i_batch_no -- Current active LM batch -- INPUT.
      i_merge_flag -- batch is merged flag --  INPUT.
    OUTPUT PARAMETER:
  	o_pallet_id --  pallet on batch --  OUTPUT.
	
    RETURN VALUE: rf_status
  **************************************************************************/

    FUNCTION get_pallet_id_on_batch (
        i_batch_no       IN  batch.parent_batch_no%TYPE,
        i_batch_no_len   IN  NUMBER,
        o_pallet_id      OUT putawaylst.pallet_id%TYPE,
        i_merge_flag     IN  VARCHAR2
    ) RETURN rf.status IS

        l_func_name         VARCHAR2(50) := 'get_pallet_id_on_batch';
        rf_status           rf.status := rf.status_normal;
        l_parent_batch_no   batch.parent_batch_no%TYPE;
        l_batch_no          batch.batch_no%TYPE;
        l_pallet_id         putawaylst.pallet_id%TYPE; 
    BEGIN
        pl_text_log.ins_msg_async('INFO',l_func_name,'Starting get_pallet_id_on_batch processing.',sqlcode,sqlerrm);
        IF ( i_merge_flag = 'Y' ) THEN
            l_parent_batch_no := i_batch_no;
            BEGIN
                SELECT
                    p.pallet_id
                INTO l_pallet_id
                FROM
                    putawaylst p,
                    batch b
                WHERE
                    ROWNUM = 1
                    AND p.pallet_batch_no = b.batch_no
                    AND b.parent_batch_no = l_parent_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,' get_pallet_id_on_batch processing.No pallets found for merge batch. parent_batch_no = '
											|| l_parent_batch_no,sqlcode,sqlerrm);
                    rf_status := rf.status_no_lm_batch_found;
            END;

        ELSE
            l_batch_no := i_batch_no;
            BEGIN
                SELECT
                    pallet_id
                INTO l_pallet_id
                FROM
                    putawaylst
                WHERE
                    ROWNUM = 1
                    AND pallet_batch_no = l_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'get_pallet_id_on_batch processing.No pallets found for batch. batch_no = '
																|| l_batch_no,sqlcode,sqlerrm);
                    rf_status := rf.status_no_lm_batch_found;
            END;

        END IF;

        IF ( rf_status = rf.status_normal ) THEN
            o_pallet_id := l_pallet_id;
            pl_text_log.ins_msg_async('INFO',l_func_name,'Next_pallet=' || o_pallet_id,sqlcode,sqlerrm);
        END IF;

        pl_text_log.ins_msg_async('INFO',l_func_name,'Ending get_pallet_id_on_batch',sqlcode,sqlerrm);
        RETURN rf_status;
    END get_pallet_id_on_batch;

END pl_rf_pre_putaway;
/

grant execute on pl_rf_pre_putaway to swms_user;
