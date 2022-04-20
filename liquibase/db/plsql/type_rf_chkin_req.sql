/****************************************************************************
** Date:       10-DEC-2019
** File:       type_rf_chkin_req.sql
**
**             Script for creating objects for Validate
**            
**    - SCRIPTS
**
**    Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**    10/12/19   CHYD9155 type_rf_chkin_req.sql
**                  
****************************************************************************/
/********    Client Objects  ************/
create or replace TYPE chkin_req_client_obj FORCE AS OBJECT (
      
         pallet_id	VARCHAR2(18),
         req_option	VARCHAR2(1)
);
/

/********    Server Objects  ************/
create or Replace TYPE chkin_req_server_obj FORCE AS OBJECT
(
		req_option			VARCHAR2(1),		
        pallet_id			VARCHAR2(18),	
        erm_id				VARCHAR2(12),	
        prod_id				VARCHAR2(7),		
        exp_qty				VARCHAR2(7),		
        sysco_shelf_life	VARCHAR2(4),		
        lot_ind           	VARCHAR2(1),
        mfg_date_ind      	VARCHAR2(1),
        exp_date_ind      	VARCHAR2(1),
        catch_wt_ind      	VARCHAR2(1),
        temp_ind          	VARCHAR2(1),
        overage_flag      	VARCHAR2(1),
        today				VARCHAR2(9),		
        max_temp			VARCHAR2(6),		
        min_temp			VARCHAR2(6),		
        ti					VARCHAR2(4),		
        qty_allowed			VARCHAR2(7),		
        cust_pref_vendor	VARCHAR2(6),		
        uom					VARCHAR2(2),		
        spc					VARCHAR2(4),		
        cust_shelf_life		VARCHAR2(4),		
        mfr_shelf_life		VARCHAR2(4),		
        upc_comp_flag		VARCHAR2(1),		
        upc_scan_function 	VARCHAR2(1),
        rf_catch_wt_flag  	VARCHAR2(1),
        clam_bed_ind      	VARCHAR2(1),
        tti_ind           	VARCHAR2(1),
		tti_value         	VARCHAR2(1),
		cryovac_value     	VARCHAR2(1),
        total_wt			VARCHAR2(9),		
        lot_id				VARCHAR2(30),	
        exp_date			VARCHAR2(6),		
        mfg_date			VARCHAR2(6),		
        temp				VARCHAR2(6),		
        clam_bed_num		VARCHAR2(10),	
        harvest_date		VARCHAR2(6),		
        total_cases			VARCHAR2(7),		
        total_splits		VARCHAR2(7),		
        cool_ind            VARCHAR2(1),
        trailer_temp_ind    VARCHAR2(1),
        DefaultWeightUnit	VARCHAR2(2)	
);
/

create or Replace TYPE chkin_req_server_msku_obj FORCE AS OBJECT
(
	req_option			VARCHAR2(1),		
    pallet_id			VARCHAR2(18),	
    erm_id				VARCHAR2(12),	
    today				VARCHAR2(9),		
    upc_comp_flag		VARCHAR2(1),		
    upc_scan_function 	VARCHAR2(1),
    rf_catch_wt_flag    VARCHAR2(1),
    count_item			VARCHAR2(4),		
    count_lp			VARCHAR2(4),		
    data_col_flag     	VARCHAR2(1),
    trailer_temp_ind  	VARCHAR2(1)
);
/

/*********************************************************************************/
create or Replace TYPE add_chk_servmsku_result_record FORCE AS OBJECT
(	
        pallet_id			VARCHAR2(18),	
	    prod_id				VARCHAR2(7),		
	    exp_qty				VARCHAR2(7),		
	    sysco_shelf_life	VARCHAR2(4),		
	    lot_ind           	VARCHAR2(1),
	    mfg_date_ind        VARCHAR2(1),
	    exp_date_ind       	VARCHAR2(1),
	    catch_wt_ind        VARCHAR2(1),
	    temp_ind            VARCHAR2(1),
	    max_temp			VARCHAR2(6),		
	    min_temp			VARCHAR2(6),		
	    ti					VARCHAR2(4),		
	    qty_allowed			VARCHAR2(7),		
	    cust_pref_vendor	VARCHAR2(6),		
	    uom					VARCHAR2(2),		
	    spc					VARCHAR2(4),		
	    cust_shelf_life		VARCHAR2(4),		
	    mfr_shelf_life		VARCHAR2(4),		
	    clam_bed_ind      	VARCHAR2(1),
	    collect_data_flag 	VARCHAR2(1),
	    rcvd_qty			VARCHAR2(7),		
        dest_loc			VARCHAR2(10),	
        total_wt			VARCHAR2(9),		
        lot_id				VARCHAR2(30),	
        exp_date			VARCHAR2(6),		
        mfg_date			VARCHAR2(6),		
        temp				VARCHAR2(6),		
        clam_bed_num		VARCHAR2(10),	
        harvest_date		VARCHAR2(6),		
        total_cases			VARCHAR2(7),		
        tti_ind             VARCHAR2(1),
        tti_value           VARCHAR2(1),
        description			VARCHAR2(30),	
        cryovac_value       VARCHAR2(1),
        cool_ind            VARCHAR2(1),
        DefaultWeightUnit	VARCHAR2(2)				
	
);
/

create or replace type  add_chk_servmsku_result_table force  as table of add_chk_servmsku_result_record;
/

create or replace type  add_chk_servmsku_result_obj force as object(
     result_table       add_chk_servmsku_result_table );		
/

grant execute on chkin_req_client_obj  		      to swms_user;
grant execute on chkin_req_server_obj  		      to swms_user;
grant execute on chkin_req_server_msku_obj        to swms_user;
grant execute on add_chk_servmsku_result_record   to swms_user;
grant execute on add_chk_servmsku_result_table    to swms_user;
grant execute on add_chk_servmsku_result_obj  	  to swms_user;
