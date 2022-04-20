/*******************************************************************************
**Package:
**        pl_rf_chkin_req. Migrated from chkin_req.pc
**
**Description:
		  Functions for Check-in Request. 
**
**Called by:
**        This is a Common package called from Java.
*******************************************************************************/ 

create or replace PACKAGE pl_rf_chkin_req AS
     FUNCTION chkin_req_main (
        i_rf_log_init_record   IN       rf_log_init_record,
        i_client               IN       chkin_req_client_obj,
        o_server               OUT      chkin_req_server_obj
    ) RETURN rf.status;

    FUNCTION chkin_req_msku_main (
        i_rf_log_init_record   IN       rf_log_init_record,
        i_client               IN       chkin_req_client_obj,
        o_server_msku          OUT      chkin_req_server_msku_obj,
        o_add_msku             OUT      add_chk_servmsku_result_obj
    ) RETURN rf.status;

    FUNCTION chkin_req (
        i_client   IN            chkin_req_client_obj,
        io_server  IN OUT        chkin_req_server_obj
    ) RETURN rf.status;

    FUNCTION chkin_req_msku (
        i_client         IN           chkin_req_client_obj,
        io_server_msku   IN OUT       chkin_req_server_msku_obj,
        io_add_msku      IN OUT       add_chk_servmsku_result_obj
    ) RETURN rf.status;

    FUNCTION tm_chkin_req (
        i_pallet_id   IN		    putawaylst.pallet_id%TYPE,
		io_server     IN OUT     chkin_req_server_obj
    ) RETURN rf.status;

    FUNCTION populate_msku_info (
        i_pallet_id		  IN 	   putawaylst.pallet_id%TYPE,
		io_server_msku    IN OUT    chkin_req_server_msku_obj,
        io_add_msku       IN OUT    add_chk_servmsku_result_obj
    ) RETURN rf.status;

    FUNCTION chkinmsku (
        i_pallet_id 	  IN     putawaylst.pallet_id%TYPE,
        i_pallet_id_len   IN     NUMBER,
		io_server_msku    IN OUT chkin_req_server_msku_obj,
        io_add_msku       IN OUT add_chk_servmsku_result_obj
    ) RETURN rf.status;

    PROCEDURE get_rf_catch_wt_flag (
        o_rf_catch_wt_flag    OUT    VARCHAR2
    );

    FUNCTION check_scan_loss (
		i_pallet_id   IN       putawaylst.pallet_id%TYPE,
        io_server     IN OUT   chkin_req_server_obj
	)RETURN rf.status;
    
    FUNCTION tm_temp_check (
        i_pallet_id         IN putawaylst.pallet_id%TYPE,
        o_trailer_temp_ind  OUT VARCHAR2,
        o_erm_id            OUT putawaylst.rec_id%TYPE
    ) RETURN rf.status;
END pl_rf_chkin_req;
/

create or replace PACKAGE BODY pl_rf_chkin_req AS
    NUM_PALLETS_MSKU         CONSTANT NUMBER := 60;
    MSKU_SUBDIV_MULTIPLIER   CONSTANT NUMBER := 5;
    RECEIVING                CONSTANT NUMBER := 2;
    PUTAWAY                  CONSTANT NUMBER := 1;
    
/*******************************************************************************
   NAME        :  chkin_req_main
   DESCRIPTION :  Login service for Chkin_req
   CALLED BY   :  Java service  
   PARAMETERS:
   INPUT :
      i_rf_log_init_record      
      i_client
	OUTPUT :
	  o_server
   RETURN VALUE:
     rf.status 
********************************************************************************/

    FUNCTION chkin_req_main (
        i_rf_log_init_record   IN       rf_log_init_record,
        i_client               IN       chkin_req_client_obj,
        o_server               OUT      chkin_req_server_obj
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(30) := 'chkin_req_main';
        rf_status     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Check in Request ', sqlcode, sqlerrm);
        rf_status := rf.initialize(i_rf_log_init_record);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Check in rf_status ' || rf_status, sqlcode, sqlerrm);
        IF rf_status = rf.status_normal THEN
            o_server  := chkin_req_server_obj(' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ');
            rf_status := chkin_req(i_client, o_server);
        END IF;
        rf.complete(rf_status);
        RETURN rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('FATAL', l_func_name, 'Check in Request failed', sqlcode, sqlerrm);
            rf.logexception();
            RAISE;
    END chkin_req_main;	
	
/*******************************************************************************
   NAME        :  chkin_req_msku_main
   DESCRIPTION :  Login service for Chkin_req_msku
   CALLED BY   :  Java service  
   PARAMETERS:
   INPUT :
      i_rf_log_init_record      
      i_client
	OUTPUT :
	  o_server_msku,
	  o_add_msku
   RETURN VALUE:
     rf.status 
********************************************************************************/

    FUNCTION chkin_req_msku_main (
        i_rf_log_init_record   IN                     rf_log_init_record,
        i_client               IN                     chkin_req_client_obj,
        o_server_msku          OUT                    chkin_req_server_msku_obj,
        o_add_msku             OUT                    add_chk_servmsku_result_obj
   ) RETURN rf.status AS
        l_func_name   VARCHAR2(30) := 'chkin_req_msku_main';
        rf_status     rf.status := rf.status_normal;
    BEGIN
        rf_status := rf.initialize(i_rf_log_init_record);
        IF rf_status = rf.status_normal THEN
            o_server_msku   := chkin_req_server_msku_obj(' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ');
        	o_add_msku      := add_chk_servmsku_result_obj(add_chk_servmsku_result_table(
                               add_chk_servmsku_result_record(' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
                                                                ' ' , ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
                                                                ' ', ' ', ' ', ' ')));
            rf_status := chkin_req_msku(i_client, o_server_msku, o_add_msku);
        END IF;
        rf.complete(rf_status);
        RETURN rf_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('FATAL', l_func_name, 'Check in  Request MSKU failed', sqlcode, sqlerrm);
            rf.logexception();
            RAISE;
    END chkin_req_msku_main;		

/*******************************************************************************
   NAME        :  chkin_req
   DESCRIPTION :  To check the Check-in Request
   CALLED BY   :  chkin_req_main 
   PARAMETERS:
   INPUT :
     i_client
	OUTPUT :
	  o_server
   RETURN VALUE:
     rf.status 
********************************************************************************/

    FUNCTION chkin_req (
        i_client    IN         chkin_req_client_obj,
        io_server   IN OUT     chkin_req_server_obj
   ) RETURN rf.status AS
        rf_status              rf.status := rf.status_normal;
        l_func_name            VARCHAR2(30) := 'chkin_req';
        l_trailer_temp_ind     VARCHAR2(1);
        l_erm_id               putawaylst.rec_id%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'start chkin_req', sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Input from scanner. Client pallet = '
                                            || i_client.pallet_id
                                            || ' req_option= '
                                            || i_client.req_option, sqlcode, sqlerrm);
        io_server.req_option := i_client.req_option;
        rf_status := tm_temp_check(i_client.pallet_id, l_trailer_temp_ind, l_erm_id);
        io_server.trailer_temp_ind := l_trailer_temp_ind;
        io_server.erm_id := l_erm_id;
        IF rf_status = rf.status_normal THEN
            BEGIN
				IF pl_msku.f_is_msku_pallet(i_client.pallet_id, 'P') = TRUE THEN
                    rf_status := pl_exc.f_get_rf_errcode(pl_exc.ct_msku_lp);
                END IF;
            END;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Client Pallet id= '
                                                 || i_client.pallet_id
                                                 || ' Req option= '
                                                 || i_client.req_option
                                                 || ' MSKU Pallet= '
                                                 || rf_status, sqlcode, sqlerrm);
            IF rf_status != rf.status_msku_lp THEN
                rf_status := tm_chkin_req(i_client.pallet_id, io_server);
                pl_text_log.ins_msg_async('INFO', l_func_name, 'SERVER status. Pallet= '
                                                    || io_server.pallet_id
                                                    || ' prod id= '
                                                    || io_server.prod_id
                                                    || ' CPV= '
                                                    || io_server.cust_pref_vendor
                                                    || ' QTY= '
                                                    || io_server.exp_qty
                                                    || ' cust_shelf_life= '
                                                    || io_server.cust_shelf_life
                                                    || ' sysco_shelf_life= '
                                                    || io_server.sysco_shelf_life
                                                    || ' mfr_shelf_life= '
                                                    || io_server.mfr_shelf_life
                                                    || ' erm_id= '
                                                    || io_server.erm_id
                                                    || ' lot ind= '
                                                    || io_server.lot_ind
                                                    || ' exp date ind= '
                                                    || io_server.exp_date_ind
                                                    || ' clam_bed_ind= '
                                                    || io_server.clam_bed_ind
                                                    || ' tti_ind= '
                                                    || io_server.tti_ind
                                                    || ' mfg date ind= '
                                                    || io_server.mfg_date_ind
                                                    || ' catch wt ind= '
                                                    || io_server.catch_wt_ind
                                                    || ' temp ind= '
                                                    || io_server.temp_ind
                                                    || ' cool_ind= '
                                                    || io_server.cool_ind
                                                    || ' Today date= '
                                                    || io_server.today, sqlcode, sqlerrm);
            END IF; /*status =MSKU_LP*/
        END IF;     /*rf_status = rf.STATUS_NORMAL*/
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Checkin Request complete', sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending Checkin Req', sqlcode, sqlerrm);
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Checkin Request Output Values. req_option= '		
												|| io_server.req_option			
												||' pallet_id= '
												|| io_server.pallet_id			
												||' erm_id= '
												|| io_server.erm_id				
												||' prod_id= ' 
												|| io_server.prod_id				
												||' exp_qty= '		
												|| io_server.exp_qty				
												||' sysco_shelf_life= '
												|| io_server.sysco_shelf_life	
												||' lot_ind= '		
												|| io_server.lot_ind          	
												||' mfg_date_ind= '	
												|| io_server.mfg_date_ind     	
												||' exp_date_ind= '	
												|| io_server.exp_date_ind     	
												||' catch_wt_ind= '	
												|| io_server.catch_wt_ind     	
												||' temp_ind= '		
												|| io_server.temp_ind         	
												||' overage_flag= '	
												|| io_server.overage_flag     	
												||' today= '			
												|| io_server.today				
												||' max_temp=	'		
												|| io_server.max_temp			
												||' min_temp= '		
												|| io_server.min_temp			
												||' ti= '				
												|| io_server.ti					
												||' qty_allowed= '	
												|| io_server.qty_allowed			
												||' cust_pref_vendor= '
												|| io_server.cust_pref_vendor	
												||' uom= '			
												|| io_server.uom					
												||' spc= '			
												|| io_server.spc					
												||' cust_shelf_life= '
												|| io_server.cust_shelf_life		
												||' mfr_shelf_life= '	
												|| io_server.mfr_shelf_life		
												||' upc_comp_flag= '	
												|| io_server.upc_comp_flag		
												||' upc_scan_function= '
												|| io_server.upc_scan_function	
												||' rf_catch_wt_flag= ' 
												|| io_server.rf_catch_wt_flag 	
												||' clam_bed_ind= '	  
												|| io_server.clam_bed_ind     	
												||' tti_ind= '		  
												|| io_server.tti_ind          	
												||' tti_value= ' 		  
												|| io_server.tti_value        	
												||' cryovac_value= '	  
												|| io_server.cryovac_value    	
												||' total_wt= '		  
												|| io_server.total_wt			
												||' lot_id= '			  
												|| io_server.lot_id				
												||' exp_date=	'		  
												|| io_server.exp_date			
												||' mfg_date=	'		  
												|| io_server.mfg_date			
												||' temp= '			  
												|| io_server.temp				
												||' clam_bed_num= '	  
												|| io_server.clam_bed_num		
												||' harvest_date= '	  
												|| io_server.harvest_date		
												||' total_cases= '	  
												|| io_server.total_cases			
												||' total_splits= '	  
												|| io_server.total_splits		
												||' cool_ind= '		  
												|| io_server.cool_ind           
												||' trailer_temp_ind= ' 
												|| io_server.trailer_temp_ind   
												||' DefaultWeightUnit= '
												|| io_server.DefaultWeightUnit, sqlcode, sqlerrm); 
        RETURN rf_status;
    END chkin_req;

/*******************************************************************************
   NAME        :  chkin_req_msku
   DESCRIPTION :  To check the Check-in Request MSKU
   CALLED BY   :  chkin_req_msku_main 
   PARAMETERS:
   INPUT :
     i_client
	OUTPUT :
	  o_server_msku,
	  o_add_msku
   RETURN VALUE:
     rf.status 
********************************************************************************/

    FUNCTION chkin_req_msku (
        i_client        IN                 chkin_req_client_obj,
        io_server_msku   IN OUT             chkin_req_server_msku_obj,
        io_add_msku      IN OUT             add_chk_servmsku_result_obj
   ) RETURN rf.status AS
        rf_status              rf.status := rf.status_normal;
        l_func_name            VARCHAR2(30) := 'chkin_req_msku';
        l_trailer_temp_ind     VARCHAR2(1);
        l_erm_id               putawaylst.rec_id%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Input from scanner. Client pallet ='
                                            || i_client.pallet_id
                                            || ' req_option= '
                                            || i_client.req_option, sqlcode, sqlerrm);
        io_server_msku.req_option := i_client.req_option;
            rf_status := tm_temp_check(i_client.pallet_id, l_trailer_temp_ind, l_erm_id);
            io_server_msku.trailer_temp_ind := l_trailer_temp_ind;
            io_server_msku.erm_id := l_erm_id;
            IF rf_status = rf.status_normal THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Client Pallet id= '
                                                    || i_client.pallet_id
                                                    || ' Req option= '
                                                    || i_client.req_option
                                                    || ' MSKU Pallet= '
                                                    || rf_status, sqlcode, sqlerrm);
                
                    rf_status := populate_msku_info(i_client.pallet_id, io_server_msku, io_add_msku);
            END IF;/*rf_status = rf.STATUS_NORMAL*/
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Checkin Request complete', sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending Checkin Req', sqlcode, sqlerrm);
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Checkin Request MSKU output values. req_option= '		
												|| io_server_msku.req_option			
												||' pallet_id= '
												|| io_server_msku.pallet_id			
												||' erm_id= '
												|| io_server_msku.erm_id				
												||' today= ' 
												|| io_server_msku.today				
												||' upc_comp_flag= '		
												|| io_server_msku.upc_comp_flag				
												||' upc_scan_function= '
												|| io_server_msku.upc_scan_function	
												||' rf_catch_wt_flag= '		
												|| io_server_msku.rf_catch_wt_flag          	
												||' count_item= '	
												|| io_server_msku.count_item     	
												||' count_lp= '	
												|| io_server_msku.count_lp     	
												||' data_col_flag= '	
												|| io_server_msku.data_col_flag     	
												||' trailer_temp_ind= '	
												|| io_server_msku.trailer_temp_ind , sqlcode, sqlerrm);     	
        RETURN rf_status;
    END chkin_req_msku;
	
/*******************************************************************************
   NAME        :  tm_chkin_req
   DESCRIPTION :  To check the tm_chkin_req
   CALLED BY   :  chkin_req
   PARAMETERS:
   INPUT :
     i_pallet_id
   OUTPUT :
	o_server
   RETURN VALUE:
     rf.status 
********************************************************************************/

   FUNCTION tm_chkin_req (
        i_pallet_id            IN           putawaylst.pallet_id%TYPE,
		io_server              IN OUT       chkin_req_server_obj
   ) RETURN rf.status AS
        l_func_name           VARCHAR2(30) := 'tm_chkin_req';
        rf_status             rf.status := rf.status_normal;
        l_overage_left        NUMBER := 0;
        l_erm_status          VARCHAR2(3);
        l_put_status          VARCHAR2(3);
        l_dummy               VARCHAR2(1);
        l_ordered_qty         NUMBER;
        l_overage_qty         NUMBER;
        l_received_qty        NUMBER;
        l_pv_qty_rcv          NUMBER;
        l_plt_limit           NUMBER;
        l_cdk_status          VARCHAR2(1);
		l_erm_type            erm.erm_type%TYPE;
		l_ti                  pm.ti%TYPE;
		l_hi                  pm.hi%TYPE;
		l_spc                 pm.spc%TYPE;
        l_rf_catch_wt_flag    VARCHAR2(1);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_pallet_id= '
                                            || i_pallet_id, sqlcode, sqlerrm);
        
        io_server.rf_catch_wt_flag := 'N';
        BEGIN
            SELECT
                'x'
            INTO l_dummy
            FROM
                erm          e,
                putawaylst   p
            WHERE
                e.erm_type = 'CM'
                AND p.rec_id = e.erm_id
                AND p.pallet_id = i_pallet_id;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Invalid pallet id.Returned pallets are not checked in.pallet_id = ' || i_pallet_id, sqlcode, sqlerrm);
            RETURN rf.status_qty_error;
        EXCEPTION
            WHEN OTHERS THEN
                BEGIN
                    l_cdk_status := pl_rcv_cross_dock.f_is_crossdock_pallet(i_pallet_id, 'P');
                END;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Cross Dock Pallet. Cross dock pallets status', sqlcode, sqlerrm);
                IF l_cdk_status = 'Y' THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Cross Dock Pallet. Cross dock pallets status', sqlcode, sqlerrm);
                    RETURN rf.status_inv_label;
                END IF;
                BEGIN
					/*  Check to see if the pallet is already putaway */
                    SELECT
                        'x'
                    INTO l_dummy
                    FROM
                        putawaylst p
                    WHERE
                        p.putaway_put = 'Y'
                        AND p.pallet_id = i_pallet_id;
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Invalid pallet id', sqlcode, sqlerrm);
                    RETURN rf.status_put_done;
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Valid pallet id.Putaway_put flag is set to N ', sqlcode, sqlerrm);
                END;
                BEGIN
					/*
					**  Check to see if the pallet is in putawaylst
					*/
                    SELECT
                        rf.NoNull(qty_expected),
                        rf.NoNull(qty_received),
                        rf.NoNull(lot_trk),
                        rf.NoNull(date_code),
                        rf.NoNull(catch_wt),
                        rf.NoNull(temp_trk),
                        rf.NoNull(putawaylst.prod_id),
                        rf.NoNull(status),
                        rf.NoNull(exp_date_trk),
                        rf.NoNull(clam_bed_trk),
                        rf.NoNull(uom),
                        rf.NoNull(putawaylst.cust_pref_vendor),
                        rf.NoNull(TO_CHAR(exp_date, 'MMDDYY')),
                        rf.NoNull(TO_CHAR(mfg_date, 'MMDDYY')),
                        rf.NoNull(lot_id),
                        rf.NoNull(temp),
                        rf.NoNull(total_weight),
                        rf.NoNull(total_cases),
                        rf.NoNull(total_splits),
                        rf.NoNull(tti_trk),
                        rf.NoNull(tti),
                        rf.NoNull(cryovac),
                        rf.NoNull(cool_trk)
                    INTO
                        io_server.exp_qty,
                        l_pv_qty_rcv,
                        io_server.lot_ind,
                        io_server.mfg_date_ind ,
                        io_server.catch_wt_ind,
                        io_server.temp_ind,
                        io_server.prod_id,
                        l_put_status,
                        io_server.exp_date_ind,
                        io_server.clam_bed_ind,
                        io_server.uom,
                        io_server.cust_pref_vendor,
                        io_server.exp_date,
                        io_server.mfg_date,
                        io_server.lot_id,
                        io_server.temp,
                        io_server.total_wt,
                        io_server.total_cases,
                        io_server.total_splits,
                        io_server.tti_ind,
                        io_server.tti_value,
                        io_server.cryovac_value,
                        io_server.cool_ind
                    FROM
                        putawaylst,
                        tmp_weight
                    WHERE
                        pallet_id = i_pallet_id
                        AND putawaylst.rec_id = tmp_weight.erm_id (+)
                        AND putawaylst.prod_id = tmp_weight.prod_id (+)
                        AND putawaylst.cust_pref_vendor = tmp_weight.cust_pref_vendor (+)
                        AND putaway_put = 'N';
                    BEGIN
                        SELECT
							/*
							** The pallet is in putawaylst.
							*/
							/* Check po# from erm and get erm status */
                            rf.NoNull(e.erm_id),
                            rf.NoNull(e.status),
                            rf.NoNull(e.erm_type)
                        INTO
                            io_server.erm_id,
                            l_erm_status,
                            l_erm_type
                        FROM
                            erm          e,
                            putawaylst   p
                        WHERE
                            e.erm_id = p.rec_id
                            AND p.pallet_id = i_pallet_id;
                        IF l_erm_status != 'CLO' AND l_erm_status != 'PND' THEN
                            IF io_server.clam_bed_ind = 'C' THEN
                                BEGIN
                                    SELECT
                                        rf.NoNull(clam_bed_no),
                                        rf.NoNull(TO_CHAR(exp_date, 'MMDDYY'))
                                    INTO
                                        io_server.clam_bed_num,
                                        io_server.harvest_date
                                    FROM
                                        trans
                                    WHERE
                                        trans_type = 'RHB'
                                        AND prod_id = io_server.prod_id
                                        AND cust_pref_vendor = io_server.cust_pref_vendor
                                        AND rec_id = io_server.erm_id
                                        AND ROWNUM = 1;

                                EXCEPTION
                                    WHEN OTHERS THEN
                                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection from trans table failed', sqlcode, sqlerrm);
                                        RETURN rf.status_sel_trn_fail;
                                END;
                            END IF; /* End of io_server.clam_bed_ind = 'C'*/
                            BEGIN
                                SELECT
                                    rf.NoNull(sysco_shelf_life),
                                    rf.NoNull(cust_shelf_life),
                                    rf.NoNull(mfr_shelf_life),
                                    rf.NoNull(spc),
                                    rf.NoNull(max_temp),
                                    rf.NoNull(min_temp),
                                    rf.NoNull(ti),
                                    rf.NoNull(hi),
                                    rf.NoNull(default_weight_unit)
                                INTO
                                    io_server.sysco_shelf_life,
                                    io_server.cust_shelf_life,
                                    io_server.mfr_shelf_life,
                                    l_spc,
                                    io_server.max_temp,
                                    io_server.min_temp,
                                    l_ti,
                                    l_hi,
                                    io_server.defaultweightunit
                                FROM
                                    pm
                                WHERE
                                    cust_pref_vendor = io_server.cust_pref_vendor
                                    AND prod_id = io_server.prod_id;
                                IF (l_erm_type = 'SN') OR (l_erm_type = 'VN') THEN
                                    BEGIN
                                        SELECT
                                            shipped_ti,
                                            shipped_hi
                                        INTO
                                            l_ti,
                                            l_hi
                                        FROM
                                            erd_lpn
                                        WHERE
                                            sn_no = io_server.erm_id
                                            AND prod_id = io_server.prod_id
                                            AND cust_pref_vendor = io_server.cust_pref_vendor
                                            AND pallet_id = i_pallet_id;
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of shipped ti and hi failed', sqlcode, sqlerrm);
                                    END;
                                END IF;/* End of l_erm_type =  'SN'  and 'VN' */
								/*
								**  plt_limit should be a split quantity
								*/
                                l_plt_limit := l_ti * l_hi * l_spc;
                                BEGIN
                                    SELECT
                                        rf.NoNull(DECODE(config_flag_val, 'T', l_ti * l_spc, 'P', l_plt_limit, 'U', 1000000, 0)),
                                        rf.NoNull(config_flag_val)
                                    INTO
                                        l_overage_qty,
                                        io_server.overage_flag
                                    FROM
                                        sys_config
                                    WHERE
                                        config_flag_name = 'OVERAGE_FLG';

                                    IF l_overage_qty != 0 THEN
                                        BEGIN
                                            SELECT
                                                SUM(qty)
                                            INTO l_ordered_qty
                                            FROM
                                                erd
                                            WHERE
                                                erm_id = io_server.erm_id
                                                AND cust_pref_vendor = io_server.cust_pref_vendor
                                                AND prod_id = io_server.prod_id;
                                            BEGIN
                                                SELECT
                                                    SUM(qty_received)
                                                INTO l_received_qty
                                                FROM
                                                    putawaylst
                                                WHERE
                                                    rec_id = io_server.erm_id
                                                    AND cust_pref_vendor = io_server.cust_pref_vendor
                                                    AND prod_id = io_server.prod_id;
												/*
												** Leave quantities in splits
												*/
												l_overage_left := (l_ordered_qty - l_received_qty + l_overage_qty - io_server.exp_qty + l_pv_qty_rcv);
                                            EXCEPTION
                                                WHEN OTHERS THEN
                                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of sum of qty received failed', sqlcode, sqlerrm);
                                                    rf_status := rf.status_update_fail;
                                            END;
                                        EXCEPTION
                                            WHEN OTHERS THEN
                                                pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of sum of qty ordered failed', sqlcode, sqlerrm);
                                                rf_status := rf.status_update_fail;
                                        END;
                                    ELSE
                                        l_overage_left := 0;
                                    END IF; /* End of l_overage_qty != 0 */
									/*
									**  qty_allowed should be a split quantity
									*/
                                    IF ((l_plt_limit) < (io_server.exp_qty + l_overage_left)) THEN
                                         io_server.qty_allowed := rf.NoNull(l_plt_limit);
                                    ELSE
                                         io_server.qty_allowed := (io_server.exp_qty + rf.NoNull(l_overage_left));
                                    END IF;						
                                    SELECT
                                        rf.NoNull(TO_CHAR(SYSDATE, 'DD-MON-YY'))
                                    INTO  io_server.today
                                    FROM
                                        dual;
									/*	Calc_avw converts the total case qty in splits and updates
										in "tmp_weight" so while sending it back to RF client
										server program needs to divide it by spc
									*/
                                    io_server.total_cases := io_server.total_cases / (l_spc);
                                    pl_text_log.ins_msg_async('INFO', l_func_name, 'The number of total cases= ' || io_server.total_cases, sqlcode, sqlerrm);
                                    io_server.pallet_id := rf.NoNull(i_pallet_id);
									io_server.ti  := rf.NoNull(l_ti);
									io_server.spc := rf.NoNull(l_spc);
                                    get_rf_catch_wt_flag(l_rf_catch_wt_flag);
                                    io_server.rf_catch_wt_flag := l_rf_catch_wt_flag;
									IF  io_server.clam_bed_ind <> 'C' THEN
                                        io_server.clam_bed_num := ' ';
                                        io_server.harvest_date := ' ';
                                    END IF;
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of overage flag failed', sqlcode, sqlerrm);
                                        rf_status := rf.status_update_fail;
                                END;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of item from pm table failed', sqlcode, sqlerrm);
                                    rf_status := rf.STATUS_INV_PRODID;
                            END;
                        ELSE
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'PO is already closed or in pending status', sqlcode, sqlerrm);
                            IF l_erm_status = 'CLO' THEN
                                rf_status := rf.status_clo_po;
                            ELSE
                                IF l_erm_status = 'PND' THEN
                                    rf_status := rf.status_osd_pending;
                                END IF; /* End of Else l_erm_status = 'PND' */
                            END IF; /* End of Else l_erm_status = 'CLO' */
                        END IF; /*End of l_erm_status = 'CLO' and 'PND'*/
                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of erm_id and status failed', sqlcode, sqlerrm);
                    END;
                EXCEPTION
                    WHEN OTHERS THEN
						/*
						** The pallet is not in putawaylst.
						*/
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of putawaylst values failed', sqlcode, sqlerrm);
                        rf_status := check_scan_loss(i_pallet_id, io_server);
                END;
				/*
				**  Check to see if UPC data has been collected and sent up to AS400
				**  for the item on this purchase order
				*/
                pl_check_upc.check_upc_data_collection(io_server.prod_id, io_server.erm_id, RECEIVING, io_server.upc_comp_flag, io_server.upc_scan_function);
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Flags returned from the check_upc function', sqlcode, sqlerrm);
        END;
		RETURN rf_status;
    END tm_chkin_req;

/*******************************************************************************
   NAME        :  populate_msku_info
   DESCRIPTION :  To check the populate_msku_info
   CALLED BY   :  chkin_req_msku
   PARAMETERS:
   INPUT :
     i_pallet_id
   OUTPUT:
	o_server_msku
   RETURN VALUE:
     rf.status 
********************************************************************************/

FUNCTION populate_msku_info (
    i_pallet_id		  IN 	   putawaylst.pallet_id%TYPE,
	io_server_msku     IN OUT   chkin_req_server_msku_obj,
    io_add_msku        IN OUT   add_chk_servmsku_result_obj
   ) RETURN rf.status AS
       l_func_name             VARCHAR2(30) := 'populate_msku_info';
        rf_status               rf.status := rf.status_normal;
        l_c_upc_comp_flag       VARCHAR2(1) := '';
        l_is_parent_lpn         VARCHAR2(1) := 'N';
        l_vc_parent_pallet_id   VARCHAR2(18);
        l_hi_prod_count         NUMBER;
        l_po_no                 VARCHAR2(12);
        l_c_upc_scan_function   VARCHAR2(1) := ' ';
        l_hi_total_pallets      NUMBER;
		l_prod_id               pm.prod_id%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_pallet_id= '
                                            || i_pallet_id, sqlcode, sqlerrm);
       
        BEGIN
			/*
			** Get the parent pallet id
			*/
            SELECT DISTINCT
                parent_pallet_id
            INTO l_vc_parent_pallet_id
            FROM
                putawaylst
            WHERE
                pallet_id = i_pallet_id;
			IF (length(l_vc_parent_pallet_id) = 0) THEN
				l_is_parent_lpn := 'N';
			ELSE
				l_is_parent_lpn := 'Y';
				io_server_msku.pallet_id := rf.NoNull(l_vc_parent_pallet_id);
			END IF;
        EXCEPTION
            WHEN OTHERS THEN
				/*
				** The LP scanned is the parent LP.
				*/
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to select parent pallet id for pallet id', sqlcode, sqlerrm);
                l_vc_parent_pallet_id := i_pallet_id;
                l_is_parent_lpn := 'Y';
                io_server_msku.pallet_id := rf.NoNull(i_pallet_id);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Obtained parent pallet id= ' || l_vc_parent_pallet_id, sqlcode, sqlerrm);
         /*
		 **  Check to see if UPC data has been collected and sent up to AS400
		 **  for the item on this purchase order
		 */
		IF l_is_parent_lpn = 'Y' THEN
            io_server_msku.upc_comp_flag := 'Y';
            BEGIN
                l_c_upc_scan_function := pl_common.f_get_syspar('UPC_SCAN_FUNCTION', 'X');
                IF l_c_upc_scan_function = 'X' THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'ORACLE Unable to select from sys_config', sqlcode, sqlerrm);
                    rf_status := rf.status_sel_syscfg_fail;
                END IF; /*End of l_c_upc_scan_function = 'X'  */
                io_server_msku.upc_scan_function := rf.NoNull(l_c_upc_scan_function);
            END;
            BEGIN
				/* Change made to copy the SN number and not the PO number*/
                SELECT DISTINCT
                    sn_no
                INTO l_po_no
                FROM
                    erd_lpn
                WHERE
                    parent_pallet_id = l_vc_parent_pallet_id;
            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Invalid pallet id', sqlcode, sqlerrm);
                    RETURN rf.status_inv_label;
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'ORACLE Unable to select from erd_lpn', sqlcode, sqlerrm);
                    RETURN rf.status_sel_erd_lpn_fail;
            END;
            io_server_msku.erm_id := rf.NoNull(l_po_no);
        ELSE
            BEGIN
				/*
				** LP scanned not a parent LP.
				*/
                SELECT
                    rf.NoNull(prod_id),
                    sn_no
                INTO
                    l_prod_id,
                    l_po_no
                FROM
                    erd_lpn
                WHERE
                    pallet_id = i_pallet_id;
            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Input pallet id is invalid', sqlcode, sqlerrm);
                    RETURN rf.status_inv_label;
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'ORACLE Unable to select values from erd_lpn.', sqlcode, sqlerrm);
                    RETURN rf.status_sel_erd_lpn_fail;
            END;
            io_server_msku.erm_id := rf.NoNull(l_po_no);
            pl_check_upc.check_upc_data_collection(l_prod_id, l_po_no, PUTAWAY, l_c_upc_comp_flag, l_c_upc_scan_function);
            io_server_msku.upc_comp_flag := rf.NoNull(l_c_upc_comp_flag);
            io_server_msku.upc_scan_function := rf.NoNull(l_c_upc_scan_function);
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Flags returned from the check_upc function.', sqlcode, sqlerrm);
        END IF; /*End of l_is_parent_lpn = 'Y' */
        BEGIN
			/*
			** Get the total count of child pallets
			*/
			/*
				The condition qty_rcvd <>0 has been removed as per the business reqmts.
			*/
            SELECT
                COUNT(DISTINCT(pallet_id))
            INTO l_hi_total_pallets
            FROM
                putawaylst
            WHERE
                parent_pallet_id = l_vc_parent_pallet_id;
        EXCEPTION
            WHEN OTHERS THEN
				/*
				** Got an error looking for the parent LP in putawaylst.
				*/
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to select parent pallet id from putawaylst table.', sqlcode, sqlerrm);
                rf_status := rf.STATUS_SKU_LP_NOT_FOUND;
        END;
        IF l_hi_total_pallets > NUM_PALLETS_MSKU THEN
            io_server_msku.count_lp := 0;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Found large MSKU:.', sqlcode, sqlerrm);
            IF (l_hi_total_pallets > NUM_PALLETS_MSKU * MSKU_SUBDIV_MULTIPLIER) THEN
                RETURN rf.STATUS_MSKU_SUBDIV_LIMIT;
            ELSE
                RETURN rf.STATUS_MSKU_LP_LIMIT_WARN;
            END IF;  /* End of l_hi_total_pallets > NUM_PALLETS_MSKU * MSKU_SUBDIV_MULTIPLIER */
        END IF; /* End of l_hi_total_pallets > NUM_PALLETS_MSKU */
        BEGIN 
			/*
			** Get the total count of prod_id's
			*/
			/* The condition qty_rcvd <>0 has been removed as per the business reqmts.
			*/
            SELECT
                COUNT(DISTINCT(prod_id))
            INTO l_hi_prod_count
            FROM
                putawaylst
            WHERE
                parent_pallet_id = l_vc_parent_pallet_id;
            io_server_msku.count_item := rf.NoNull(l_hi_prod_count);
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to select count of prod_ids for parent pallet', sqlcode, sqlerrm);
        END;
        io_server_msku.count_lp := rf.NoNull(l_hi_total_pallets);
        rf_status := chkinmsku(l_vc_parent_pallet_id, length(l_vc_parent_pallet_id), io_server_msku, io_add_msku);      
		RETURN rf_status;
    END populate_msku_info;

/*******************************************************************************
   NAME        :  chkinmsku
   DESCRIPTION :  To check the chkinmsku
   CALLED BY   :  populate_msku_info
   PARAMETERS:
   INPUT :
     i_pallet_id,
	 i_pallet_id_len
   OUTPUT :
	o_server_msku 
	o_add_msku    
   RETURN VALUE:
     rf.status 
********************************************************************************/
  
 FUNCTION chkinmsku (
        i_pallet_id       IN         putawaylst.pallet_id%TYPE,
        i_pallet_id_len   IN         NUMBER,
		io_server_msku    IN OUT     chkin_req_server_msku_obj,
        io_add_msku       IN OUT     add_chk_servmsku_result_obj
	
   ) RETURN rf.status AS
        rf_status                 rf.status := rf.status_normal;
        l_func_name               VARCHAR2(30) := 'chkinmsku';
        l_c_collect_data_flag     VARCHAR2(1);
        l_i_data_collection_ind   NUMBER := 0;
        l_i_count_pallets         NUMBER := 0;
        l_old_prod_id             VARCHAR2(9);
        l_vi_pallet_id            VARCHAR2(18);
        l_hsz_erm_status          VARCHAR2(3);
        l_hsz_put_status          VARCHAR2(3);
        l_dest_loc                VARCHAR2(10);
        l_pv_qty_rcv              NUMBER := 0;
        l_weight                  VARCHAR2(9);
        l_exp_date                VARCHAR2(6);
        l_mfg_date                VARCHAR2(6);
        l_lot_id                  VARCHAR2(30);
        l_temp                    VARCHAR(6) := 0;
        l_clam_bed                VARCHAR(10):= 0;
        l_harvest_date            VARCHAR(6);
        l_hsz_today_date          VARCHAR(9);
        l_hc_dummy                VARCHAR2(1);
        l_result_table            add_chk_servmsku_result_table := add_chk_servmsku_result_table();
        l_hi_qty_allowed          NUMBER;
        l_hi_total_cases          NUMBER := 0;
        l_desc                    VARCHAR2(30);
		l_ti                 	  pm.ti%TYPE;
		l_hi                 	  pm.hi%TYPE;
		l_spc                	  pm.spc%TYPE;
		l_rf_catch_wt_flag        VARCHAR2(1);
		l_exp_qty                 putawaylst.qty_expected%TYPE;
		l_lot_ind                 putawaylst.lot_trk%TYPE;
		l_tti_ind                 putawaylst.tti_trk%TYPE;
		l_tti_value               putawaylst.tti%TYPE;
		l_cryovac_value           putawaylst.cryovac%TYPE;
		l_mfg_date_ind            putawaylst.date_code%TYPE;
		l_catch_wt_ind            putawaylst.catch_wt%TYPE;
		l_temp_ind                putawaylst.temp_trk%TYPE;
		l_cool_ind                putawaylst.cool_trk%TYPE;
		l_exp_date_ind            putawaylst.exp_date_trk%TYPE;
		l_clam_bed_ind            putawaylst.clam_bed_trk%TYPE;
		l_uom                     putawaylst.uom%TYPE;
		l_prod_id                 pm.prod_id%TYPE;
		l_cust_pref_vendor        pm.cust_pref_vendor%TYPE;
		l_erm_id                  erm.erm_id%TYPE;
		l_sysco_shelf_life        pm.sysco_shelf_life%TYPE;
		l_cust_shelf_life         pm.cust_shelf_life%TYPE;
		l_mfr_shelf_life          pm.mfr_shelf_life%TYPE;
		l_max_temp                pm.max_temp%TYPE;
		l_min_temp                pm.min_temp%TYPE;
		l_defaultweightunit       pm.default_weight_unit%TYPE;
        CURSOR c_child_pallets_cur IS
        SELECT
            pallet_id
        FROM
            putawaylst
        WHERE
            parent_pallet_id = i_pallet_id
        ORDER BY
            prod_id;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'chkinmsku i_pallet_id= '
                                            || i_pallet_id
                                            || ' vi_pallet_id= '
                                            || l_vi_pallet_id, sqlcode, sqlerrm);
		
        /*
		** Cursor for handling child pallet id's
		*/
		/*  As per the business requirement, the condition
			which checks for qty_received <>0 needs to be removed.
			However in case of putaway it should be there
		*/
        OPEN c_child_pallets_cur;
        LOOP
            FETCH c_child_pallets_cur INTO l_vi_pallet_id;
            EXIT WHEN c_child_pallets_cur%notfound;
            l_rf_catch_wt_flag := 'N';
            l_exp_qty := 0;
            l_pv_qty_rcv := 0;
            l_lot_ind := ' ';
            l_tti_ind := ' ';
            l_tti_value := ' ';
            l_cryovac_value := ' ';
            l_mfg_date_ind  := ' ';
            l_catch_wt_ind := ' ';
            l_temp_ind := ' ';
            l_cool_ind := ' ';
            l_exp_date_ind := ' ';
            l_clam_bed_ind := ' ';
            l_uom := 0;
            l_hi_total_cases := 0;
            BEGIN
                SELECT
                    'x'
                INTO l_hc_dummy
                FROM
                    erm          e,
                    putawaylst   p
                WHERE
                    e.erm_type = 'CM'
                    AND p.rec_id = e.erm_id
                    AND p.pallet_id = l_vi_pallet_id;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Invalid pallet id. Returned pallets are not checked in', sqlcode, sqlerrm);
                RETURN rf.status_qty_error;
            EXCEPTION
                WHEN OTHERS THEN
					/*
					**  Check to see if the pallet is already putaway
					*/
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Check to see if the pallet is already putaway', sqlcode, sqlerrm);
                    BEGIN
                        SELECT
                            'x'
                        INTO l_hc_dummy
                        FROM
                            putawaylst p
                        WHERE
                            p.putaway_put = 'Y'
                            AND p.pallet_id = l_vi_pallet_id;
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Pallet is already putaway.', sqlcode, sqlerrm);
                        RETURN rf.status_put_done;
                    EXCEPTION
                        WHEN no_data_found THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection from putawaylst table gets failed.', sqlcode, sqlerrm);
                    END;
                    BEGIN
						/*
						**  Check to see if the pallet is in putawaylst
						*/
						/* Populate the weight from tmp_weight.total_weight field and
						   total_cases from tmp_weight.total_cases field.
						*/
                        SELECT
                            rf.NoNull(dest_loc),
                            rf.NoNull(qty_expected),
                            rf.NoNull(qty_received),
                            rf.NoNull(p.lot_trk),
                            rf.NoNull(date_code),
                            rf.NoNull(p.catch_wt),
                            rf.NoNull(p.temp_trk),
                            rf.NoNull(p.cool_trk),
                            rf.NoNull(p.prod_id),
                            rf.NoNull(p.status),
                            rf.NoNull(p.exp_date_trk),
                            rf.NoNull(p.clam_bed_trk),
                            rf.NoNull(p.uom),
                            rf.NoNull(p.cust_pref_vendor),
                            rf.NoNull(total_weight),
                            rf.NoNull(TO_CHAR(p.exp_date, 'MMDDYY')),
                            rf.NoNull(TO_CHAR(p.mfg_date, 'MMDDYY')),
                            rf.NoNull(p.lot_id),
                            rf.NoNull(p.temp),
                            rf.NoNull(total_cases),
                            rf.NoNull(p.tti_trk),
                            rf.NoNull(p.tti),
                            rf.NoNull(p.cryovac),
                            rf.NoNull(m.descrip)
                        INTO
                            l_dest_loc,
                            l_exp_qty,
                            l_pv_qty_rcv,
                            l_lot_ind,
                            l_mfg_date_ind ,
                            l_catch_wt_ind,
                            l_temp_ind,
                            l_cool_ind,
                            l_prod_id,
                            l_hsz_put_status,
                            l_exp_date_ind,
                            l_clam_bed_ind,
                            l_uom,
                            l_cust_pref_vendor,
                            l_weight,
                            l_exp_date,
                            l_mfg_date,
                            l_lot_id,
                            l_temp,
                            l_hi_total_cases,
                            l_tti_ind,
                            l_tti_value,
                            l_cryovac_value,
                            l_desc
                        FROM
                            putawaylst   p,
                            tmp_weight   t,
                            pm           m
                        WHERE
                            pallet_id = l_vi_pallet_id
                            AND p.rec_id = t.erm_id (+)
                            AND p.prod_id = t.prod_id (+)
                            AND p.cust_pref_vendor = t.cust_pref_vendor (+)
                            AND p.prod_id = m.prod_id
                            AND p.cust_pref_vendor = m.cust_pref_vendor
                            AND putaway_put = 'N';
                    EXCEPTION
                        WHEN OTHERS THEN                            
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of putawaylst values failed', sqlcode, sqlerrm);
                            RETURN rf.status_inv_label;
                    END;
					/* Check po# from erm and get erm status */
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Check po# from erm and get erm status', sqlcode, sqlerrm);
                    BEGIN
                        SELECT
                            rf.NoNull(m.erm_id),
                            m.status
                        INTO
                            l_erm_id,
                            l_hsz_erm_status
                        FROM
                            erm          m,
                            putawaylst   p
                        WHERE
                            m.erm_id = p.rec_id
                            AND p.pallet_id = l_vi_pallet_id;
                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Select erm_id and status failed', sqlcode, sqlerrm);
                            RETURN rf.status_inv_po;
                    END;
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Select erm_id successful', sqlcode, sqlerrm);
                    IF (l_hsz_erm_status != 'CLO') AND (l_hsz_erm_status != 'PND') THEN
						/*
                        ** Get the product details only if a different prod_id
                        */
                        IF l_prod_id IS NOT NULL THEN
                            /* There will be one "RHB" transaction in trans table
               				   for product id and sn_no combination.
							   Please add the sn_number check also in the where clause
							   of the query.
							   condition should be :
							   "and sn_no = <sn_no coresponding to LP>"
                            */
                            IF l_clam_bed_ind = 'C' THEN
                                BEGIN
                                    SELECT
                                        clam_bed_no,
                                        TO_CHAR(exp_date, 'MMDDYY')
                                    INTO
                                        l_clam_bed,
                                        l_harvest_date
                                    FROM
                                        trans
                                    WHERE
                                        prod_id = l_prod_id
                                        AND cust_pref_vendor = l_cust_pref_vendor
                                        AND trans_type = 'RHB'
                                        AND rec_id = l_erm_id
                                        AND ROWNUM = 1;

                                EXCEPTION
                                    WHEN OTHERS THEN
                                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of Clam_bed_no from trans gets failed', sqlcode, sqlerrm);
                                        RETURN rf.status_sel_trn_fail;
                                END;
                            END IF; /* End of l_clam_bed_ind = 'C' */
                            BEGIN
                                SELECT
                                    rf.NoNull(sysco_shelf_life),
                                    rf.NoNull(cust_shelf_life),
                                    rf.NoNull(mfr_shelf_life),
                                    rf.NoNull(spc),
                                    rf.NoNull(max_temp),
                                    rf.NoNull(min_temp),
                                    rf.NoNull(ti),
                                    rf.NoNull(hi),
                                    rf.NoNull(default_weight_unit)
                                INTO
                                    l_sysco_shelf_life,
                                    l_cust_shelf_life,
                                    l_mfr_shelf_life,
                                    l_spc,
                                    l_max_temp,
                                    l_min_temp,
                                    l_ti,
                                    l_hi,
                                    l_defaultweightunit
                                FROM
                                    pm
                                WHERE
                                    cust_pref_vendor = l_cust_pref_vendor
                                    AND prod_id = l_prod_id;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection from pm table gets failed', sqlcode, sqlerrm);
									return rf.STATUS_INV_PRODID;
                            END;
							/* Save prod_id for comparison in next iteration */
                            l_old_prod_id := l_prod_id;
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'PROD_ID ' || l_prod_id, sqlcode, sqlerrm);
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'OLD PROD_ID ' || l_old_prod_id, sqlcode, sqlerrm);
                        END IF; 
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Select shelf life etc...successful..', sqlcode, sqlerrm);
                        BEGIN
                            SELECT
                                shipped_ti,
                                shipped_hi
                            INTO
                                l_ti,
                                l_hi
                            FROM
                                erd_lpn
                            WHERE
                                sn_no = l_erm_id
                                AND prod_id = l_prod_id
                                AND cust_pref_vendor = l_cust_pref_vendor
                                AND pallet_id = l_vi_pallet_id;
                        EXCEPTION
                            WHEN OTHERS THEN
                                pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection from erd_lpn table gets failed', sqlcode, sqlerrm);
                        END;
						/*
                        **  qty_allowed should be a split quantity
                        */
                        l_hi_qty_allowed := l_ti * l_hi * l_spc;
                        IF (l_catch_wt_ind = 'Y' OR l_mfg_date_ind  = 'Y' OR l_temp_ind = 'Y' OR l_lot_ind = 'Y' OR l_exp_date_ind= 'Y' OR l_clam_bed_ind = 'Y' OR l_tti_ind = 'Y' OR l_cool_ind = 'Y') THEN
                            l_c_collect_data_flag := 'Y';
                            l_i_data_collection_ind := 1;
                        ELSE
                            IF l_i_data_collection_ind != 1 THEN
                                l_i_data_collection_ind := 0;
                            END IF;
                            l_c_collect_data_flag := 'N';
                        END IF; 
						/* Calc_avw converts the total case qty in splits and updates
							in "tmp_weight" so while sending it back to RF client
							server program needs to divide it by spc
                        */
                        l_hi_total_cases := l_hi_total_cases / l_spc;
						/* Add qty_received in the structure.
							Qty_received will be used on the RF client
                         	to prevent user from selecting zero received LPs during sybdivide
							process.Originally server program will send zero rcvd LPs to RF device so that
							user can correct the qty_received in case previously he had checked it in
							as zero by mstake
                        */
                        l_result_table.extend;
                        l_result_table(l_result_table.count) := add_chk_servmsku_result_record(rf.NoNull(l_vi_pallet_id), rf.NoNull(l_prod_id), rf.NoNull(l_exp_qty), rf.NoNull(l_sysco_shelf_life), rf.NoNull(l_lot_ind), rf.NoNull(l_mfg_date_ind) ,
																							rf.NoNull(l_exp_date_ind), rf.NoNull(l_catch_wt_ind), rf.NoNull(l_temp_ind), rf.NoNull(l_max_temp), rf.NoNull(l_min_temp), rf.NoNull(l_ti), rf.NoNull(l_hi_qty_allowed),
																							  rf.NoNull(l_cust_pref_vendor), rf.NoNull(l_uom), rf.NoNull(l_spc), rf.NoNull(l_cust_shelf_life), rf.NoNull(l_mfr_shelf_life), rf.NoNull(l_clam_bed_ind), rf.NoNull(l_c_collect_data_flag),
																							  rf.NoNull(l_pv_qty_rcv), rf.NoNull(l_dest_loc), rf.NoNull(l_weight), rf.NoNull(l_lot_id), rf.NoNull(l_exp_date), rf.NoNull(l_mfg_date), rf.NoNull(l_temp), rf.NoNull(l_clam_bed), rf.NoNull(l_harvest_date),
																							  rf.NoNull(l_hi_total_cases), rf.NoNull(l_tti_ind), rf.NoNull(l_tti_value), rf.NoNull(l_desc), rf.NoNull(l_cryovac_value), rf.NoNull(l_cool_ind), rf.NoNull(l_defaultweightunit));
						l_i_count_pallets := l_i_count_pallets + 1;
                    ELSE
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'PO is already closed or in pending status', sqlcode, sqlerrm);
                        IF l_hsz_erm_status = 'CLO' THEN
                            rf_status := rf.status_clo_po;
                        ELSIF l_hsz_erm_status = 'PND' THEN
                            rf_status := rf.status_osd_pending;
                        END IF; /* End of else l_hsz_erm_status = 'CLO' and l_hsz_erm_status = 'PND' */
                    END IF; /* End of l_hsz_erm_status != 'CLO' and  'PND'*/ 
                    IF l_i_count_pallets <= 1 THEN
                        get_rf_catch_wt_flag(l_rf_catch_wt_flag);
                        io_server_msku.rf_catch_wt_flag := l_rf_catch_wt_flag;
						/*
						** Copy today's date into server variable
						*/
                        BEGIN
                            SELECT
                                TO_CHAR(SYSDATE, 'DD-MON-YY')
                            INTO l_hsz_today_date
                            FROM
                                dual;
                            io_server_msku.today := rf.NoNull(l_hsz_today_date);
                        EXCEPTION
                            WHEN OTHERS THEN
                                pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection of sysdate failed', sqlcode, sqlerrm);
                        END;
                    END IF; /*End of l_i_count_pallets <= 1*/
            END;
        END LOOP;/* End of Loop */
        CLOSE c_child_pallets_cur;
        io_add_msku := add_chk_servmsku_result_obj(l_result_table);
        IF l_i_data_collection_ind IS NOT NULL THEN
            io_server_msku.data_col_flag := 'Y';
        ELSE
            io_server_msku.data_col_flag := 'N';
        END IF;
        RETURN rf_status;
    END chkinmsku;

/*******************************************************************************
   NAME        :  get_rf_catch_wt_flag
   DESCRIPTION :  To check the get_rf_catch_wt_flag
   CALLED BY   :  tm_chkin_req,chkinmsku
   PARAMETERS:
   RETURN VALUE:
     rf.status 
********************************************************************************/

    PROCEDURE get_rf_catch_wt_flag (
        o_rf_catch_wt_flag    OUT    VARCHAR2
    )AS
        l_func_name   			VARCHAR2(30) := 'get_rf_catch_wt_flag';
        rf_status     			rf.status := rf.status_normal;
    BEGIN
        BEGIN
            o_rf_catch_wt_flag := pl_common.f_get_syspar('KEY_WEIGHT_IN_RF_RCV', 'X');
            IF o_rf_catch_wt_flag = 'X' THEN
                o_rf_catch_wt_flag := 'N';
                pl_text_log.ins_msg_async('WARN', l_func_name, ' Failed to select RF_Catch_wt_flag.', sqlcode, sqlerrm);
            END IF;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'RF_Catch_wt_flag= ' || o_rf_catch_wt_flag, sqlcode, sqlerrm);
        END;
    END get_rf_catch_wt_flag;

/*******************************************************************************
   NAME        : check_scan_loss
   DESCRIPTION : If a pallet is not registered as part of the shipment, create a
				 'ILP' transaction to indicate the loss of the pallet.
   CALLED BY   : tm_chkin_req
   PARAMETERS:
   RETURN VALUE:
     rf.status 
********************************************************************************/

   FUNCTION check_scan_loss ( 
        i_pallet_id	 IN        putawaylst.pallet_id%TYPE,
		io_server     IN OUT    chkin_req_server_obj
    )RETURN rf.status AS
        l_func_name      VARCHAR(30) := 'check_scan_loss';
		rf_status        rf.status := rf.status_normal;
        l_hvc_snno       VARCHAR2(12);
        l_sz_dummy       VARCHAR2(1);
    BEGIN
        
        IF (length(i_pallet_id) < 18) THEN
            rf_status := rf.status_inv_label;
        ELSE
            BEGIN
                SELECT
                    'x'
                INTO l_sz_dummy
                FROM
                    trans
                WHERE
                    pallet_id = i_pallet_id
                    AND trans_type = 'ILP';
			/* pallet has been recorded for loss prevention */
			RETURN rf.status_inv_label;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection failed from trans table. Trans type = ILP ', sqlcode, sqlerrm);
            END;
            BEGIN
                SELECT
                    'x'
                INTO l_sz_dummy
                FROM
                    trans
                WHERE
                    pallet_id = i_pallet_id
                    AND trans_type = 'PUT';
				RETURN rf.status_put_done;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection failed from trans table. Trans type = PUT ', sqlcode, sqlerrm);
            END;
            BEGIN
                SELECT
                    sn_no
                INTO l_hvc_snno
                FROM
                    erd_lpn
                WHERE
                    pallet_id = i_pallet_id;
				/* pallet found in other SN */
				io_server.erm_id := l_hvc_snno;
				RETURN rf.status_lossprev_lp_in_other_sn;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Selection failed from erd_lp table', sqlcode, sqlerrm);
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
                    cmt
               ) VALUES (
                    trans_id_seq.NEXTVAL,
                    'ILP',
                    SYSDATE,
                    user,
                    i_pallet_id,
                    99,
                    'Recorded for scan loss prevention'
               );
                COMMIT;
            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'ORACLE failed to create ILP transaction', sqlcode, sqlerrm);
                    RETURN rf.status_trans_insert_failed;
                WHEN OTHERS THEN
                    RETURN rf.status_data_error;
            END;
			rf_status := rf.status_inv_label;
        END IF; /* End of length(i_client.pallet_id) < 18 */
		return rf_status;
    END check_scan_loss;
    
/*******************************************************************************
    NAME        : tm_temp_check
    DESCRIPTION : Checks for temperature 
    CALLED BY   : chkin_req,chkin_req_msku
    PARAMETERS:
    INPUT :
	 	i_pallet_id
    RETURN VALUE:
		rf.status 
********************************************************************************/

    FUNCTION tm_temp_check (
        i_pallet_id         IN putawaylst.pallet_id%TYPE,
        o_trailer_temp_ind  OUT VARCHAR2,
        o_erm_id            OUT putawaylst.rec_id%TYPE
   ) RETURN rf.status AS
        l_func_name      VARCHAR2(30) := 'tm_temp_check';
        rf_status        rf.status := rf.status_normal;
        l_coolerflag     VARCHAR2(1);
        l_freezerflag    VARCHAR2(1);
        l_cooler_temp    NUMBER;
        l_freezer_temp   NUMBER;
    BEGIN
        BEGIN
			/* Get the PO number, temperature and track flags from PUTAWAYLST and ERM */
            SELECT DISTINCT
                rf.NoNull(p.rec_id),
                e.cooler_trailer_trk,
                e.freezer_trailer_trk,
                e.cooler_trailer_temp,
                e.freezer_trailer_temp
            INTO
                o_erm_id,
                l_coolerflag,
                l_freezerflag,
                l_cooler_temp,
                l_freezer_temp
            FROM
                putawaylst   p,
                erm          e
            WHERE
                e.erm_id = p.rec_id
                AND (p.pallet_id = i_pallet_id
                      OR p.parent_pallet_id = i_pallet_id);
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'ORACLE unable to get PO number, cooler and freezer track flags and temperature', sqlcode, sqlerrm);
                RETURN rf.status_inv_label;
        END;
		/*  Check if cooler ,freezer flags are set to 'Y' and if respective temperature are null
			If so, set the trailer_temp_ind of server structure accordingly
 		*/
        IF ((l_coolerflag = 'Y') AND (l_freezerflag = 'Y')) THEN
			/* Set the trailer_temp_ind to 'B' indicating both temperatures needs to be collected*/
            o_trailer_temp_ind := 'B';
        ELSIF l_coolerflag = 'Y' THEN
			/* Set the trailer_temp_ind to 'C' indicating only cooler temperature needs to be collected */
            o_trailer_temp_ind := 'C';
        ELSIF l_freezerflag = 'Y' THEN
			/* Set the trailer_temp_ind to 'F' indicating only freezer temperature needs to be collected */
            o_trailer_temp_ind := 'F';
        ELSE
			/* Set the trailer_temp_ind to 'N' indicating no needs to be collected */
            o_trailer_temp_ind := 'N';
        END IF; 
        pl_text_log.ins_msg_async('INFO', l_func_name, 'tm_temp_check. rf_status = ' || rf_status, sqlcode, sqlerrm);
        RETURN rf_status;
    END tm_temp_check;
END pl_rf_chkin_req;
/

grant execute on pl_rf_chkin_req to swms_user;
