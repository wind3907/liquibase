/*******************************************************************************
--
-- type_rf_dci_pod.sql
--
-- Description: Types created for pl_rf_dci_pod.sql (package pl_rf_dci_pod).
-- 
-- Modification log:
--
-- Date         Developer     Change
-- ------------------------------------------------------------------
-- 24-SEP-2020  pkab6563      Initial version.
-- 06-NOV-2020  ECLA1411	  OPCOF-3226 - POD Returns - Print Process For RF Host
--                            Added 'rtn_label_printed', 'pallet_id', 'dest_loc' fields.
--                            Added two (2) constructors
-- 16-NOV-2020  ECLA1411	  OPCOF-3226 - POD Returns - Print Process For RF Host
--                            Added TI, HI And Pallet_Type To RTN_ITEM_REC
-- 01-DEC-2020  pkab6563      Changed temperature fields from varchar2 
--                            to number as they should be.
-- 11-NOV-2021  sban3548	  OPCOF-3739 - POD RF returns sos label scan error
--							  Added RTN_ORDER_SEQ_REC for returning multiple order_seq values 
--							  when order_id, prod_id and UOM matches
--
********************************************************************************/

create or replace TYPE SWMS.RTN_UPC_REC FORCE AS OBJECT
(
    upc_type    VARCHAR2(1),   
    upc_code    VARCHAR2(14)  
);
/

create or replace TYPE SWMS.RTN_UPC_TABLE FORCE AS TABLE OF SWMS.RTN_UPC_REC;
/

create or replace TYPE SWMS.RTN_ORDER_SEQ_REC FORCE AS OBJECT
(
	order_seq    NUMBER
);
/

create or replace TYPE SWMS.RTN_ORDER_SEQ_TABLE FORCE AS TABLE OF SWMS.RTN_ORDER_SEQ_REC;
/

-- 16-NOV-2020  ECLA1411	  OPCOF-3226 - POD Returns - Print Process For RF Host
--                            Added TI, HI And Pallet_Type
create or replace TYPE        "RTN_ITEM_REC" FORCE AS OBJECT
(
    stop_no                NUMBER(7,2),
    rec_type               VARCHAR2(1),
    obligation_no          VARCHAR2(14),
    prod_id                VARCHAR2(9),
    cust_pref_vendor       VARCHAR2(10),
    prod_desc              VARCHAR2(30),
    return_reason_cd       VARCHAR2(3),
    returned_qty           NUMBER(4),
    returned_split_cd      VARCHAR2(1),
    catchweight            NUMBER(9,3),
    disposition            VARCHAR2(3),
    returned_prod_id       VARCHAR2(9),
    returned_prod_cpv      VARCHAR2(10),
    returned_prod_desc     VARCHAR2(30),
    erm_line_id            NUMBER(4),
    shipped_qty            NUMBER(4),
    shipped_split_cd       VARCHAR2(1),
    cust_id                VARCHAR2(10),
    temperature            NUMBER,
    add_source             VARCHAR2(3),
    status                 VARCHAR2(4),
    err_comment            VARCHAR2(1000),
    rtn_sent_ind           VARCHAR2(1),
    pod_rtn_ind            VARCHAR2(1),
    lock_chg               VARCHAR2(1),
    order_seq_list         SWMS.RTN_ORDER_SEQ_TABLE,
    spc                    NUMBER(4),
    split_trk              VARCHAR2(1),
    temp_trk               VARCHAR2(1),
    catch_wt_trk           VARCHAR2(1),
    food_safety_trk        VARCHAR2(1),
    food_safety_temp       NUMBER,
    min_temp               NUMBER,
    max_temp               NUMBER,
    min_weight             NUMBER(8,4),
    max_weight             NUMBER(8,4),
    max_food_safety_temp   NUMBER,
    rtn_label_printed	   VARCHAR2(1),
    pallet_id			   VARCHAR2(18),
    dest_loc			   VARCHAR2(10),
	ti                     NUMBER(4),
	hi                     NUMBER(4),
	pallet_type            VARCHAR2(2),
    upc_list               SWMS.RTN_UPC_TABLE,
	CONSTRUCTOR FUNCTION RTN_ITEM_REC(
		stop_no                NUMBER,
		rec_type               VARCHAR2,
		obligation_no          VARCHAR2,
		prod_id                VARCHAR2,
		cust_pref_vendor       VARCHAR2,
		prod_desc              VARCHAR2,
		return_reason_cd       VARCHAR2,
		returned_qty           NUMBER,
		returned_split_cd      VARCHAR2,
		catchweight            NUMBER,
		disposition            VARCHAR2,
		returned_prod_id       VARCHAR2,
		returned_prod_cpv      VARCHAR2,
		returned_prod_desc     VARCHAR2,
		erm_line_id            NUMBER,
		shipped_qty            NUMBER,
		shipped_split_cd       VARCHAR2,
		cust_id                VARCHAR2,
		temperature            NUMBER,
		add_source             VARCHAR2,
		status                 VARCHAR2,
		err_comment            VARCHAR2,
		rtn_sent_ind           VARCHAR2,
		pod_rtn_ind            VARCHAR2,
		lock_chg               VARCHAR2,
		order_seq_list         SWMS.RTN_ORDER_SEQ_TABLE,
		spc                    NUMBER,
		split_trk              VARCHAR2,
		temp_trk               VARCHAR2,
		catch_wt_trk           VARCHAR2,
		food_safety_trk        VARCHAR2,
		food_safety_temp       NUMBER,
		min_temp               NUMBER,
		max_temp               NUMBER,
		min_weight             NUMBER,
		max_weight             NUMBER,
		max_food_safety_temp   NUMBER,
		rtn_label_printed	   VARCHAR2 DEFAULT ' ',
		pallet_id			   VARCHAR2 DEFAULT ' ',
		dest_loc			   VARCHAR2 DEFAULT ' ',
		ti                     NUMBER DEFAULT 0,
		hi                     NUMBER DEFAULT 0,
		pallet_type            VARCHAR2 DEFAULT ' ',
		upc_list               SWMS.RTN_UPC_TABLE ) RETURN SELF AS RESULT,
	CONSTRUCTOR FUNCTION RTN_ITEM_REC(
		stop_no                NUMBER,
		rec_type               VARCHAR2,
		obligation_no          VARCHAR2,
		prod_id                VARCHAR2,
		cust_pref_vendor       VARCHAR2,
		prod_desc              VARCHAR2,
		return_reason_cd       VARCHAR2,
		returned_qty           NUMBER,
		returned_split_cd      VARCHAR2,
		catchweight            NUMBER,
		disposition            VARCHAR2,
		returned_prod_id       VARCHAR2,
		returned_prod_cpv      VARCHAR2,
		returned_prod_desc     VARCHAR2,
		erm_line_id            NUMBER,
		shipped_qty            NUMBER,
		shipped_split_cd       VARCHAR2,
		cust_id                VARCHAR2,
		temperature            NUMBER,
		add_source             VARCHAR2,
		status                 VARCHAR2,
		err_comment            VARCHAR2,
		rtn_sent_ind           VARCHAR2,
		pod_rtn_ind            VARCHAR2,
		lock_chg               VARCHAR2,
		order_seq_list         SWMS.RTN_ORDER_SEQ_TABLE,
		spc                    NUMBER,
		split_trk              VARCHAR2,
		temp_trk               VARCHAR2,
		catch_wt_trk           VARCHAR2,
		food_safety_trk        VARCHAR2,
		food_safety_temp       NUMBER,
		min_temp               NUMBER,
		max_temp               NUMBER,
		min_weight             NUMBER,
		max_weight             NUMBER,
		max_food_safety_temp   NUMBER,
		upc_list               SWMS.RTN_UPC_TABLE ) RETURN SELF AS RESULT,
	CONSTRUCTOR FUNCTION RTN_ITEM_REC RETURN SELF AS RESULT
);
/

-- 06-NOV-2020  ECLA1411	  OPCOF-3226 - POD Returns - Print Process For RF Host
-- New Constructor to set selected attributes to default values so existing code
-- referencing this Type doesn't have to be modified.
-- 16-NOV-2020  ECLA1411	  OPCOF-3226 - POD Returns - Print Process For RF Host
--                            Added TI, HI And Pallet_Type
create or replace TYPE BODY        "RTN_ITEM_REC" IS
	CONSTRUCTOR FUNCTION RTN_ITEM_REC(
		stop_no                NUMBER,
		rec_type               VARCHAR2,
		obligation_no          VARCHAR2,
		prod_id                VARCHAR2,
		cust_pref_vendor       VARCHAR2,
		prod_desc              VARCHAR2,
		return_reason_cd       VARCHAR2,
		returned_qty           NUMBER,
		returned_split_cd      VARCHAR2,
		catchweight            NUMBER,
		disposition            VARCHAR2,
		returned_prod_id       VARCHAR2,
		returned_prod_cpv      VARCHAR2,
		returned_prod_desc     VARCHAR2,
		erm_line_id            NUMBER,
		shipped_qty            NUMBER,
		shipped_split_cd       VARCHAR2,
		cust_id                VARCHAR2,
		temperature            NUMBER,
		add_source             VARCHAR2,
		status                 VARCHAR2,
		err_comment            VARCHAR2,
		rtn_sent_ind           VARCHAR2,
		pod_rtn_ind            VARCHAR2,
		lock_chg               VARCHAR2,
		order_seq_list         SWMS.RTN_ORDER_SEQ_TABLE,
		spc                    NUMBER,
		split_trk              VARCHAR2,
		temp_trk               VARCHAR2,
		catch_wt_trk           VARCHAR2,
		food_safety_trk        VARCHAR2,
		food_safety_temp       NUMBER,
		min_temp               NUMBER,
		max_temp               NUMBER,
		min_weight             NUMBER,
		max_weight             NUMBER,
		max_food_safety_temp   NUMBER,
		rtn_label_printed	   VARCHAR2 DEFAULT ' ',
		pallet_id			   VARCHAR2 DEFAULT ' ',
		dest_loc			   VARCHAR2 DEFAULT ' ',
		ti                     NUMBER DEFAULT 0,
		hi                     NUMBER DEFAULT 0,
		pallet_type            VARCHAR2 DEFAULT ' ',
		upc_list               SWMS.RTN_UPC_TABLE )
	RETURN SELF AS RESULT
	IS
	BEGIN
		SELF.stop_no := stop_no;
		SELF.rec_type := rec_type;
		SELF.obligation_no := obligation_no;
		SELF.prod_id := prod_id;
		SELF.cust_pref_vendor := cust_pref_vendor;
		SELF.prod_desc := prod_desc;
		SELF.return_reason_cd := return_reason_cd;
		SELF.returned_qty := returned_qty;
		SELF.returned_split_cd := returned_split_cd;
		SELF.catchweight := catchweight;
		SELF.disposition := disposition;
		SELF.returned_prod_id := returned_prod_id;
		SELF.returned_prod_cpv := returned_prod_cpv;
		SELF.returned_prod_desc := returned_prod_desc;
		SELF.erm_line_id := erm_line_id;
		SELF.shipped_qty := shipped_qty;
		SELF.shipped_split_cd := shipped_split_cd;
		SELF.cust_id := cust_id;
		SELF.temperature := temperature;
		SELF.add_source := add_source;
		SELF.status := status;
		SELF.err_comment := err_comment;
		SELF.rtn_sent_ind := rtn_sent_ind;
		SELF.pod_rtn_ind := pod_rtn_ind;
		SELF.lock_chg := lock_chg;
		SELF.order_seq_list := order_seq_list;
		SELF.spc := spc;
		SELF.split_trk := split_trk;
		SELF.temp_trk := temp_trk;
		SELF.catch_wt_trk := catch_wt_trk;
		SELF.food_safety_trk := food_safety_trk;
		SELF.food_safety_temp := food_safety_temp;
		SELF.min_temp := min_temp;
		SELF.max_temp := max_temp;
		SELF.min_weight := min_weight;
		SELF.max_weight := max_weight;
		SELF.max_food_safety_temp := max_food_safety_temp;
		SELF.rtn_label_printed := NVL(rtn_label_printed, ' ');
		SELF.pallet_id := NVL(pallet_id, ' ');
		SELF.dest_loc := NVL(dest_loc, ' ');
		SELF.ti := NVL(ti, 0);
		SELF.hi := NVL(hi, 0);
		SELF.pallet_type := NVL(pallet_type, ' ');
		SELF.upc_list := upc_list;
		RETURN;
	END;
	CONSTRUCTOR FUNCTION RTN_ITEM_REC(
		stop_no                NUMBER,
		rec_type               VARCHAR2,
		obligation_no          VARCHAR2,
		prod_id                VARCHAR2,
		cust_pref_vendor       VARCHAR2,
		prod_desc              VARCHAR2,
		return_reason_cd       VARCHAR2,
		returned_qty           NUMBER,
		returned_split_cd      VARCHAR2,
		catchweight            NUMBER,
		disposition            VARCHAR2,
		returned_prod_id       VARCHAR2,
		returned_prod_cpv      VARCHAR2,
		returned_prod_desc     VARCHAR2,
		erm_line_id            NUMBER,
		shipped_qty            NUMBER,
		shipped_split_cd       VARCHAR2,
		cust_id                VARCHAR2,
		temperature            NUMBER,
		add_source             VARCHAR2,
		status                 VARCHAR2,
		err_comment            VARCHAR2,
		rtn_sent_ind           VARCHAR2,
		pod_rtn_ind            VARCHAR2,
		lock_chg               VARCHAR2,
		order_seq_list         SWMS.RTN_ORDER_SEQ_TABLE,
		spc                    NUMBER,
		split_trk              VARCHAR2,
		temp_trk               VARCHAR2,
		catch_wt_trk           VARCHAR2,
		food_safety_trk        VARCHAR2,
		food_safety_temp       NUMBER,
		min_temp               NUMBER,
		max_temp               NUMBER,
		min_weight             NUMBER,
		max_weight             NUMBER,
		max_food_safety_temp   NUMBER,
		upc_list               SWMS.RTN_UPC_TABLE )
	RETURN SELF AS RESULT
	IS
	BEGIN
		SELF.stop_no := stop_no;
		SELF.rec_type := rec_type;
		SELF.obligation_no := obligation_no;
		SELF.prod_id := prod_id;
		SELF.cust_pref_vendor := cust_pref_vendor;
		SELF.prod_desc := prod_desc;
		SELF.return_reason_cd := return_reason_cd;
		SELF.returned_qty := returned_qty;
		SELF.returned_split_cd := returned_split_cd;
		SELF.catchweight := catchweight;
		SELF.disposition := disposition;
		SELF.returned_prod_id := returned_prod_id;
		SELF.returned_prod_cpv := returned_prod_cpv;
		SELF.returned_prod_desc := returned_prod_desc;
		SELF.erm_line_id := erm_line_id;
		SELF.shipped_qty := shipped_qty;
		SELF.shipped_split_cd := shipped_split_cd;
		SELF.cust_id := cust_id;
		SELF.temperature := temperature;
		SELF.add_source := add_source;
		SELF.status := status;
		SELF.err_comment := err_comment;
		SELF.rtn_sent_ind := rtn_sent_ind;
		SELF.pod_rtn_ind := pod_rtn_ind;
		SELF.lock_chg := lock_chg;
		SELF.order_seq_list := order_seq_list;
		SELF.spc := spc;
		SELF.split_trk := split_trk;
		SELF.temp_trk := temp_trk;
		SELF.catch_wt_trk := catch_wt_trk;
		SELF.food_safety_trk := food_safety_trk;
		SELF.food_safety_temp := food_safety_temp;
		SELF.min_temp := min_temp;
		SELF.max_temp := max_temp;
		SELF.min_weight := min_weight;
		SELF.max_weight := max_weight;
		SELF.max_food_safety_temp := max_food_safety_temp;
		SELF.upc_list := upc_list;
		RETURN;
	END;
	CONSTRUCTOR FUNCTION RTN_ITEM_REC
	RETURN SELF AS RESULT
	IS
	BEGIN
		SELF.stop_no := stop_no;
		SELF.rec_type := rec_type;
		SELF.obligation_no := obligation_no;
		SELF.prod_id := prod_id;
		SELF.cust_pref_vendor := cust_pref_vendor;
		SELF.prod_desc := prod_desc;
		SELF.return_reason_cd := return_reason_cd;
		SELF.returned_qty := returned_qty;
		SELF.returned_split_cd := returned_split_cd;
		SELF.catchweight := catchweight;
		SELF.disposition := disposition;
		SELF.returned_prod_id := returned_prod_id;
		SELF.returned_prod_cpv := returned_prod_cpv;
		SELF.returned_prod_desc := returned_prod_desc;
		SELF.erm_line_id := erm_line_id;
		SELF.shipped_qty := shipped_qty;
		SELF.shipped_split_cd := shipped_split_cd;
		SELF.cust_id := cust_id;
		SELF.temperature := temperature;
		SELF.add_source := add_source;
		SELF.status := status;
		SELF.err_comment := err_comment;
		SELF.rtn_sent_ind := rtn_sent_ind;
		SELF.pod_rtn_ind := pod_rtn_ind;
		SELF.lock_chg := lock_chg;
		SELF.order_seq_list := order_seq_list;
		SELF.spc := spc;
		SELF.split_trk := split_trk;
		SELF.temp_trk := temp_trk;
		SELF.catch_wt_trk := catch_wt_trk;
		SELF.food_safety_trk := food_safety_trk;
		SELF.food_safety_temp := food_safety_temp;
		SELF.min_temp := min_temp;
		SELF.max_temp := max_temp;
		SELF.min_weight := min_weight;
		SELF.max_weight := max_weight;
		SELF.max_food_safety_temp := max_food_safety_temp;
		SELF.rtn_label_printed := NVL(rtn_label_printed, 'N');
		SELF.pallet_id := NVL(pallet_id, ' ');
		SELF.dest_loc := NVL(dest_loc, ' ');
		SELF.ti := NVL(ti, 0);
		SELF.hi := NVL(hi, 0);
		SELF.pallet_type := NVL(pallet_type, ' ');
		SELF.upc_list := upc_list;
		RETURN;
	END;
END;
/

create or replace TYPE SWMS.RTN_ITEM_TABLE FORCE AS TABLE OF SWMS.RTN_ITEM_REC;
/

create or replace TYPE SWMS.RTN_VALIDATION_OBJ FORCE AS OBJECT
(
    manifest_no			NUMBER(7),
    dci_ready			VARCHAR2(1),
    route_no			VARCHAR2(10),
    item_list			SWMS.RTN_ITEM_TABLE
);
/

GRANT EXECUTE ON SWMS.RTN_UPC_REC TO swms_user;
GRANT EXECUTE ON SWMS.RTN_UPC_TABLE TO swms_user;
GRANT EXECUTE ON SWMS.RTN_ORDER_SEQ_REC TO swms_user;
GRANT EXECUTE ON SWMS.RTN_ORDER_SEQ_TABLE TO swms_user;
GRANT EXECUTE ON SWMS.RTN_ITEM_REC TO swms_user;
GRANT EXECUTE ON SWMS.RTN_ITEM_TABLE TO swms_user;
GRANT EXECUTE ON SWMS.RTN_VALIDATION_OBJ TO swms_user;
CREATE OR REPLACE PUBLIC SYNONYM RTN_UPC_REC FOR SWMS.RTN_UPC_REC;
CREATE OR REPLACE PUBLIC SYNONYM RTN_UPC_TABLE FOR SWMS.RTN_UPC_TABLE;
CREATE OR REPLACE PUBLIC SYNONYM RTN_ORDER_SEQ_REC FOR SWMS.RTN_ORDER_SEQ_REC;
CREATE OR REPLACE PUBLIC SYNONYM RTN_ORDER_SEQ_TABLE FOR SWMS.RTN_ORDER_SEQ_TABLE;
CREATE OR REPLACE PUBLIC SYNONYM RTN_ITEM_REC FOR SWMS.RTN_ITEM_REC;
CREATE OR REPLACE PUBLIC SYNONYM RTN_ITEM_TABLE FOR SWMS.RTN_ITEM_TABLE;
CREATE OR REPLACE PUBLIC SYNONYM RTN_VALIDATION_OBJ FOR SWMS.RTN_VALIDATION_OBJ;
