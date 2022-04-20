/****************************************************************************
** Date:       02-DEC-2019
** File:       type_rf_pre_putaway.sql
**
**             Script for creating objects for preputaway
**             server &client
**    - SCRIPTS
**
**    Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**    02/12/19   CHYD9155  type_rf_pre_putaway.sql
**
****************************************************************************/

		/*******Client object************/
		
CREATE OR REPLACE TYPE pre_putaway_client_obj FORCE AS OBJECT (
    pallet_id         VARCHAR2(18),
    equip_id          VARCHAR2(10),
    batch_no          VARCHAR2(13),
    regular_putaway   VARCHAR2(1),
    merge_flag        VARCHAR2(1),
    func1_flag        VARCHAR2(1),
    haul_flag         VARCHAR2(1),
    drop_loc          VARCHAR2(4)
);
/

			/*******Server objects************/
CREATE OR REPLACE TYPE pre_putaway_server_obj FORCE AS OBJECT (
    dest_loc            VARCHAR2(10),
    put_path_val        VARCHAR2(10),
    rlc_flag            VARCHAR2(1),
    rtn_putaway_conf    VARCHAR2(1),
    door_no             VARCHAR2(4),
    po_no               VARCHAR2(12),
    pallet_cnt          VARCHAR2(7),
    forklift_lbr_trk    VARCHAR2(1),
    upc_comp_flag       VARCHAR2(1),
    upc_scan_function   VARCHAR2(1),
    qty_rec             VARCHAR2(7),
    spc                 VARCHAR2(5),
    descrip             VARCHAR2(30),
    ml_flag             VARCHAR2(1)
);
/

CREATE OR REPLACE TYPE pre_putaway_msku_server_obj FORCE AS OBJECT (
    rlc_flag            VARCHAR2(1),
    rtn_putaway_conf    VARCHAR2(1),
    door_no             VARCHAR2(4),
    po_no               VARCHAR2(12),
    pallet_cnt          VARCHAR2(7),
    forklift_lbr_trk    VARCHAR2(1),
    upc_comp_flag       VARCHAR2(1),
    upc_scan_function   VARCHAR2(1),
    parent_pallet_id    VARCHAR2(18),
    msku_reserve_loc    VARCHAR2(10)
);
/

CREATE OR REPLACE TYPE add_msg_server_result_record FORCE AS OBJECT (
    pallet_id      VARCHAR2(18),
    dest_loc       VARCHAR2(10),
    put_path_val   VARCHAR2(10),
    prod_id        VARCHAR2(9),
    cpv            VARCHAR2(10),
    descrip        VARCHAR2(30),
    exp_date       VARCHAR2(6),
    qty_rec        VARCHAR2(7),
    spc            VARCHAR2(5),
    ml_flag        VARCHAR2(1)
);
/

CREATE OR REPLACE TYPE add_msg_result_table FORCE AS
    TABLE OF add_msg_server_result_record;
/

CREATE OR REPLACE TYPE add_msg_server_result_obj FORCE AS OBJECT (
    result_table   add_msg_result_table
);
/

GRANT EXECUTE ON add_msg_server_result_record TO swms_user;

GRANT EXECUTE ON add_msg_result_table TO swms_user;

GRANT EXECUTE ON add_msg_server_result_obj TO swms_user;

GRANT EXECUTE ON pre_putaway_msku_server_obj TO swms_user;

GRANT EXECUTE ON pre_putaway_server_obj TO swms_user;

GRANT EXECUTE ON pre_putaway_client_obj TO swms_user;
/
