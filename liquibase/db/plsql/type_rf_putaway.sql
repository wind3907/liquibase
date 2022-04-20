/****************************************************************************
** Date:       20-DEC-2019
** File:       type_rf_putaway.sql
**
**             Script for creating objects for putaway
**             server & client
**    - SCRIPTS
**
**    Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**    20/12/19   CHYD9155  type_rf_putaway.sql
**
****************************************************************************/

	/*******Client object************/
	
CREATE OR REPLACE TYPE putaway_client_obj FORCE AS OBJECT (
    pallet_id           VARCHAR2(18),
    plogi_loc           VARCHAR2(10),
    real_put_path_val   VARCHAR2(10),
    rlc_flag            VARCHAR2(1),
    rtn_putaway_conf    VARCHAR2(1),
    door_no             VARCHAR2(4),
    cte_door_trans      VARCHAR2(1),
    first_pass_flag     VARCHAR2(1),
    haul_flag           VARCHAR2(1),
    equip_id            VARCHAR2(10),
    sub_flag            VARCHAR2(1),
    scan_method         VARCHAR2(1),       /* for PUT transaction */
    last_put            VARCHAR2(1)
);
/
	/*******server object************/

CREATE OR REPLACE TYPE putaway_server_obj FORCE AS OBJECT (
    list_status          VARCHAR2(6),
    pending_rpl_flag     VARCHAR2(1),
    loc_cnt              VARCHAR2(6),
    prompt_for_hst_qty   VARCHAR2(2),		 /* RDC non dep */
    cpv                  VARCHAR2(10),
    prod_id              VARCHAR2(9),
    qty                  VARCHAR2(7),
    spc                  VARCHAR2(5),
    max_qty              VARCHAR2(4)
);
/

CREATE OR REPLACE TYPE putaway_loc_result_record FORCE AS OBJECT (
    src_loc    VARCHAR2(10),
    dest_loc   VARCHAR2(10)
);
/

CREATE OR REPLACE TYPE putaway_loc_result_table FORCE AS
    TABLE OF putaway_loc_result_record;
/

CREATE OR REPLACE TYPE putaway_loc_result_obj FORCE AS OBJECT (
    result_table   putaway_loc_result_table
);
/

GRANT EXECUTE ON putaway_client_obj TO swms_user;
GRANT EXECUTE ON putaway_server_obj TO swms_user;
GRANT EXECUTE ON putaway_loc_result_record TO swms_user;
GRANT EXECUTE ON putaway_loc_result_table TO swms_user;
GRANT EXECUTE ON putaway_loc_result_obj TO swms_user;
