-- MDI005-C --

CREATE TABLE SWMS.SAP_IM_IN 
(
	sequence_number number(10), 
	interface_type varchar2(3), 
	record_status varchar2(1), 
	datetime date, 
	func_code varchar2(1), 
	prod_id varchar2(9), 
	cust_pref_vendor varchar2(10), 
	mfr_shelf_life varchar2(4),  
	sysco_shelf_life varchar2(4), 
	cust_shelf_life varchar2(4), 
	container varchar2(4), 
	pack varchar2(4), 
	prod_size varchar2(6), 
	prod_size_unit varchar2(3), 
	brand varchar2(7), 
	descrip varchar2(30), 
	mfg_sku varchar2(14), 
	vendor_id varchar2(10), 
	catch_wt_trk varchar2(1), 
	weight varchar2(8), 
	g_weight varchar2(9), 
	master_case varchar2(4), 
	units_per_case varchar2(4), 
	category varchar2(11), 
	hazardous varchar2(6), 
	replace varchar2(9), 
	buyer varchar2(3), 
	min_qty varchar2(3), 
	case_cube varchar2(7), 
	stage varchar2(1), 
	pallet_type varchar2(2), 
	ti varchar2(3), 
	hi varchar2(3), 
	last_rec_date varchar2(6), 
	last_ship_date varchar2(6), 
	min_temp varchar2(6), 
	max_temp varchar2(6), 
	lot_trk varchar2(1), 
	fifo_trk varchar2(1), 
	mfg_date_trk varchar2(1), 
	exp_date_trk varchar2(1), 
	temp_trk varchar2(1), 
	abc varchar2(1), 
	master_sku varchar2(9), 
	master_qty varchar2(6), 
	repack_ind varchar2(1), 
	external_upc varchar2(14), 
	internal_upc varchar2(14), 
	stock_type varchar2(1), 
	filler1 varchar2(1), 
	cubitron varchar2(1), 
	dmd_status varchar2(1), 
	auto_ship_flag varchar2(1), 
	case_height varchar2(9), 
	case_length varchar2(9), 
	case_width varchar2(9), 
	ims_status varchar2(1), 
	case_qty_per_carrier varchar2(4), 
	item_cost varchar2(10), 
	add_user varchar2(30) default USER,  
	add_date date default SYSDATE, 
	upd_user varchar2(30), 
	upd_date date, 
	constraint sap_im_in_pk primary key(sequence_number,interface_type,record_status,datetime)
);

CREATE SEQUENCE SWMS.SAP_IM_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PUBLIC SYNONYM SAP_IM_SEQ FOR SWMS.SAP_IM_SEQ;

CREATE OR REPLACE PUBLIC SYNONYM SAP_IM_IN FOR SWMS.SAP_IM_IN;

-- MDI012-C --

CREATE TABLE SWMS.SAP_CU_IN
(
    sequence_number number(10),
    interface_type varchar2(3),
    record_status varchar2(1),
    datetime date,
    cust_ind varchar2(1),
    cust_id varchar2(10),
    monday_route_no	varchar2(10),
    tuesday_route_no varchar2(10),
    wednesday_route_no varchar2(10),
    thursday_route_no varchar2(10),
    friday_route_no	varchar2(10),
    saturday_route_no varchar2(10),
    sunday_route_no	varchar2(10),
    cust_name varchar2(30),
    cust_contact varchar2(30),
    cust_addr1 varchar2(40),
    cust_addr2 varchar2(40),
    cust_addr3 varchar2(40),
    cust_city varchar2(20),
    cust_state varchar2(2),
    cust_zip varchar2(10),
    cust_cntry varchar2(10),
    ship_name varchar2(30),
    ship_addr1 varchar2(80),
    ship_addr2 varchar2(40),
    ship_addr3 varchar2(160),
    ship_city varchar2(20),
    ship_state varchar2(2),
    ship_zip varchar2(10),
    ship_cntry varchar2(10),
    status varchar2(1),
    monday_stop_no varchar2(10),
    tuesday_stop_no varchar2(10),
    wednesday_stop_no varchar2(10),
    thursday_stop_no varchar2(10),
    friday_stop_no varchar2(10),
    saturday_stop_no varchar2(10),
    sunday_stop_no varchar2(10),
    add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
    upd_user varchar2(30),
    upd_date date,
    CONSTRAINT SAP_CU_IN_PK PRIMARY KEY(sequence_number,interface_type,record_status,datetime)
);

CREATE SEQUENCE SWMS.SAP_CU_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PUBLIC SYNONYM SAP_CU_IN FOR SWMS.SAP_CU_IN;

CREATE OR REPLACE PUBLIC SYNONYM SAP_CU_SEQ FOR SWMS.SAP_CU_SEQ;

-- SCI016-C --

CREATE TABLE SWMS.SAP_OW_OUT 
(
    batch_id number(8),
    bypass_flag varchar2(1) default 'N',
	sequence_number number(10),
	interface_type varchar2(3),
	record_status varchar2(1),
	datetime varchar2(16),
	trans_type varchar2(3),
	trans_date date,
	order_id varchar2(16),
	order_line_id varchar2(3),
	prod_id varchar2(9),
	cust_pref_vendor varchar2(10),
	route_no varchar2(10),
	truck_no varchar2(10),
	stop_no	varchar2(3),
	reason_code varchar2(3),
	new_status varchar2(3),
	sys_order_id varchar2(7),
	sys_order_line_id varchar2(5),
	uom varchar2(1),
	qty_expected varchar2(8),
	qty varchar2(8),
	weight varchar2(9),
	clam_bed_no varchar2(10),
	user_id	varchar2(20),
	harvest_date date,
	wild_farm_desc varchar2(11),
	country_of_origin varchar2(50),
    sys_order_id_ext varchar2(10),
	add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
	upd_user varchar2(30),
	upd_date date,
    PRIMARY KEY(sequence_number, interface_type, record_status, datetime)
);

CREATE OR REPLACE TYPE SWMS.SAP_OW_OBJECT IS OBJECT 
(
    batch_id number(8) ,
    bypass_flag varchar2(1),
	TRANS_TYPE VARCHAR2(3),
	TRANS_DATE DATE,
	ORDER_ID VARCHAR2(16),
	ORDER_LINE_ID VARCHAR2(3),
	PROD_ID VARCHAR2(9),
	CUST_PREF_VENDOR VARCHAR2(10),
	ROUTE_NO VARCHAR2(10),
	TRUCK_NO VARCHAR2(4),
	STOP_NO	VARCHAR2(3),
	REASON_CODE VARCHAR2(3),
	NEW_STATUS VARCHAR2(3),
	SYS_ORDER_ID VARCHAR2(7),
	SYS_ORDER_LINE_ID VARCHAR2(5),
	UOM VARCHAR2(1),
	QTY_EXPECTED VARCHAR2(8),
	QTY VARCHAR2(8),
	WEIGHT VARCHAR2(9),
	CLAM_BED_NO VARCHAR2(10),
	USER_ID	VARCHAR2(20),
	HARVEST_DATE DATE,
	WILD_FARM_DESC VARCHAR2(11),
	COUNTRY_OF_ORIGIN VARCHAR2(50),
   	SYS_ORDER_ID_EXT VARCHAR2(10)
);
/

CREATE OR REPLACE TYPE SWMS.SAP_OW_OBJECT_TABLE AS TABLE OF SAP_OW_OBJECT;
/

CREATE SEQUENCE SWMS.SAP_OW_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PUBLIC SYNONYM SAP_OW_OUT FOR SWMS.SAP_OW_OUT;

CREATE OR REPLACE PUBLIC SYNONYM SAP_OW_SEQ FOR SWMS.SAP_OW_SEQ;


-- For SCI042- MQ

CREATE TABLE SWMS.SAP_SN_IN
(
    SEQUENCE_NUMBER 	NUMBER(10),
    INTERFACE_TYPE	 	VARCHAR2(3),
    RECORD_STATUS 		VARCHAR2(1),
    DATETIME 		DATE,
    BATCH_NUMBER            VARCHAR2(10),
    RECTYPE			VARCHAR2(1),
    FUNCCODE		VARCHAR2(1),
    SN_NO			VARCHAR2(10),
    TRANSACTION_TYPE	VARCHAR2(2),
    OPCO_NBR		VARCHAR2(3),
    ANTICIPATED_RECEIPT_DATE VARCHAR2(8),
    ANTICIPATED_RECEIPT_TIME VARCHAR2(8),
    SHIP_DATE		VARCHAR2(8),
    NO_PALLETS		VARCHAR2(6),
    NO_CASES		VARCHAR2(6),
    CARR_ID			VARCHAR2(4),
    VEND_NAME		VARCHAR2(25),
    VENDOR_NBR		VARCHAR2(5),
    VEND_ADDR		VARCHAR2(25),
    VEND_CITYSTATEZIP	VARCHAR2(30),
    RDC_NBR			VARCHAR2(5),
    SHIPMENT_ID		VARCHAR2(20),
    PO_NO			VARCHAR2(12),
    PO_LINE_ID		VARCHAR2(4), 
    ERM_LINE_ID		VARCHAR2(4),
    PROD_ID			VARCHAR2(9),
    WEIGHT			VARCHAR2(10),
    QTY			VARCHAR2(4),
    UOM			VARCHAR2(1),
    CUST_PREF_VENDOR	VARCHAR2(10),
    LOT_ID			VARCHAR2(30),
    PARENT_PALLET_ID	VARCHAR2(18),
    PALLET_ID		VARCHAR2(18),
    PALLET_TYPE		VARCHAR2(2),
    SHIPPED_TI		VARCHAR2(4),
    SHIPPED_HI		VARCHAR2(4),
    EXP_DATE		VARCHAR2(8),
    MFG_DATE		VARCHAR2(8),
    MSG_ID       VARCHAR2(32),
    DTL_REC_COUNT   VARCHAR2(4),
    EOB             VARCHAR2(1),
    ADD_USER varchar2(30) default USER, 
	ADD_DATE date default SYSDATE,
    UPD_USER		VARCHAR2(30),
    UPD_DATE		DATE,
    CONSTRAINT SAP_SN_IN_PK PRIMARY KEY(SEQUENCE_NUMBER,INTERFACE_TYPE,RECORD_STATUS,DATETIME)
);

CREATE SEQUENCE SWMS.SAP_SN_SEQ START WITH 1 INCREMENT BY 1;

CREATE SEQUENCE SWMS.SAP_SN_BATCH_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PUBLIC SYNONYM SAP_SN_IN FOR SWMS.SAP_SN_IN;

CREATE OR REPLACE PUBLIC SYNONYM SAP_SN_SEQ FOR SWMS.SAP_SN_SEQ;

CREATE OR REPLACE PUBLIC SYNONYM SAP_SN_BATCH_SEQ FOR SWMS.SAP_SN_BATCH_SEQ;

-- SCI039-C --

CREATE TABLE SWMS.SAP_MF_IN
(
	sequence_number number(10),
	interface_type varchar2(3),
	record_status varchar2(1),
	datetime date,
	rec_type varchar2(1),
	manifest_no varchar2(7),
	obligation_no varchar2(16),
	prod_id varchar2(9),
	cust_pref_vendor varchar2(10),
	stop_no varchar2(3),
	route_no varchar2(10),
	shipped_split_cd varchar2(1),
	shipped_qty varchar2(5),
	reason_code varchar2(3),
	disposition varchar2(3),
	orig_invoice varchar2(16),
	invoice_no varchar2(16),
	customer_id varchar2(14),
	customer varchar2(30),
	addr_line_1 varchar2(80),
	addr_line_2 varchar2(40),
	addr_line_3 varchar2(160),
	addr_city varchar2(20),
	addr_state varchar2(3),
	addr_postal_code varchar2(10),
	salesperson_id varchar2(9),
	salesperson varchar2(30),
	time_in varchar2(6),
	time_out varchar2(6),
	business_hrs_from varchar2(4),
	business_hrs_to varchar2(4),
	terms varchar2(30),
	invoice_amt varchar2(9),
	invoice_cube varchar2(9),
	invoice_wgt varchar2(9),
	notes varchar2(160),
	manifest_record_count number(5),
	batch_record_count number(5),
	msg_id varchar2(32),
	add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
	upd_user varchar2(30),
	upd_date date,
    CONSTRAINT SAP_MF_IN_PK PRIMARY KEY(sequence_number, interface_type, record_status, datetime)
);

CREATE SEQUENCE SWMS.SAP_MF_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PUBLIC SYNONYM SAP_MF_IN FOR SWMS.SAP_MF_IN;

CREATE OR REPLACE PUBLIC SYNONYM SAP_MF_SEQ FOR SWMS.SAP_MF_SEQ;


-- For SCI004 - Queue 'RT'.

CREATE TABLE SWMS.SAP_RT_OUT 
(
    batch_id number(8),
	sequence_number number(10),
	interface_type  varchar2(3),
	record_status   varchar2(1),
	datetime        date,
    Trans_type	varchar2(3),  
	Item 		varchar2(9),
	Cpv 		varchar2(10),
	Trans_date 	date,
	Stop_no	        number(3),
	Route_no   	varchar2(10),
	Order_id 	varchar2(16),
	Reason_code     varchar2(3),
	New_status      varchar2(3),
	Adj_flag        varchar2(1),
	Order_type      varchar2(1),
	Split_ind       number(1),
	Qty             number(4),
	Weight          number(9,3),
	Returned_item   varchar2(9),
	Manifest_no     number(12),
	add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
	upd_user        varchar2(30),
	upd_date        date,
    CONSTRAINT SAP_RT_OUT_PK PRIMARY KEY(sequence_number, interface_type, record_status, datetime)
);

CREATE OR REPLACE TYPE SWMS.SAP_RT_OBJECT is OBJECT
(
    batch_id      number(8),
    Trans_type	  varchar2(3),  
	Item 		  varchar2(9),
	Cpv 		  varchar2(10),
	Trans_date 	  date,
	Stop_no	      number(3),
	Route_no   	  varchar2(10),
	Order_id 	  varchar2(16),
	Reason_code   varchar2(3),
	New_status    varchar2(3),
	Adj_flag      varchar2(1),
	Order_type    varchar2(1),
	Split_ind     number(1),
	Qty           number(4),
	Weight        number(9,3),
	Returned_item varchar2(9),
	Manifest_no   number(12)
);
/

CREATE SEQUENCE SWMS.SAP_RT_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TYPE SWMS.SAP_RT_OBJECT_TABLE as TABLE of SAP_RT_OBJECT;
/
CREATE OR REPLACE PUBLIC SYNONYM SAP_RT_OUT FOR SWMS.SAP_RT_OUT;

CREATE OR REPLACE PUBLIC SYNONYM SAP_RT_SEQ FOR SWMS.SAP_RT_SEQ;

-- For SCI003 and SCI006 - Queue 'IA'.

CREATE TABLE SWMS.SAP_IA_OUT 
(
    batch_id number(8),
    bypass_flag varchar2(1) default 'N',
	sequence_number NUMERIC(10),
	interface_type VARCHAR2(3),   
	record_status VARCHAR2(1),    
	datetime VARCHAR2(16),    
	trans_type VARCHAR2 (3),    
	erm_id VARCHAR2 (16),    
	prod_id VARCHAR2 (9),    
	cust_pref_vendor VARCHAR2 (10),    
	reason_code VARCHAR2 (3),    
	item_seq VARCHAR2(3),    
	uom VARCHAR2(1),    
	qty_expected_sign VARCHAR2(1),    
	qty_expected VARCHAR2(8),    
	qty_sign VARCHAR2(1),    
	qty VARCHAR2(8),    
	weight_sign VARCHAR2(1),    
	weight VARCHAR2(7),    
	order_id VARCHAR2(16),    
	new_status VARCHAR2(3),    
	warehouse_id VARCHAR2(3),    
	mfg_date DATE,    
	mfg_date_trk VARCHAR2(1),    
	exp_date DATE,    
	exp_date_trk VARCHAR2(1),    
	pallet_id VARCHAR2(18),    
	trans_id VARCHAR2(8),    
	trailer_temp VARCHAR2(6),    
	item_temp VARCHAR2(6),    
	rdc_no VARCHAR2(5),
    shipment_id VARCHAR2(20),
	sn_no VARCHAR2(12),    
	rec_date DATE,    
	erm_type VARCHAR2(2),    
	erm_line_id VARCHAR2(3),    
	user_id VARCHAR2(30),    
	home_reserve_flag VARCHAR2(1),    
	add_user VARCHAR2(30) default USER, 
	add_date DATE default SYSDATE,    
	upd_user VARCHAR2(30),    
	upd_date DATE,    
	CONSTRAINT SAP_IA_OUT_PK PRIMARY KEY(sequence_number,interface_type,record_status,datetime)
);

CREATE SEQUENCE SWMS.SAP_IA_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TYPE SWMS.SAP_IA_OBJECT AS OBJECT
(
    batch_id number(8),
    bypass_flag varchar2(1),
	trans_type VARCHAR2 (3),    
	erm_id VARCHAR2 (16),    
	prod_id VARCHAR2 (9),    
	cust_pref_vendor VARCHAR2 (10),    
	reason_code VARCHAR2 (3),    
	item_seq VARCHAR2(3),    
	uom VARCHAR2(1),    
	qty_expected_sign VARCHAR2(1),    
	qty_expected VARCHAR2(8),    
	qty_sign VARCHAR2(1),    
	qty VARCHAR2(8),    
	weight_sign VARCHAR2(1),    
	weight VARCHAR2(7),    
	order_id VARCHAR2(16),    
	new_status VARCHAR2(3),    
	warehouse_id VARCHAR2(3),    
	mfg_date DATE,    
	mfg_date_trk VARCHAR2(1),    
	exp_date DATE,    
	exp_date_trk VARCHAR2(1),    
	pallet_id VARCHAR2(18),    
	trans_id VARCHAR2(8),    
	trailer_temp VARCHAR2(6),    
	item_temp VARCHAR2(6),    
	rdc_no VARCHAR2(5),    
	sn_no VARCHAR2(12),    
	rec_date DATE,    
	erm_type VARCHAR2(2),    
	erm_line_id VARCHAR2(3),    
	user_id VARCHAR2(30),    
	home_reserve_flag VARCHAR2(1)
);
/

CREATE OR REPLACE TYPE SWMS.SAP_IA_OBJECT_TABLE AS TABLE of SAP_IA_OBJECT;
/

CREATE OR REPLACE PUBLIC SYNONYM SAP_IA_OUT FOR SWMS.SAP_IA_OUT;

CREATE OR REPLACE PUBLIC SYNONYM SAP_IA_SEQ FOR SWMS.SAP_IA_SEQ;

-- For SCI015 - Queue 'CR'.

CREATE TABLE SWMS.SAP_CR_OUT
(
    batch_id number(8),
	sequence_number NUMBER(10),
	interface_type  VARCHAR2(3),
	record_status	VARCHAR2(1),
	datetime 		DATE,
	batch_no 		VARCHAR2(9),
	batch_type 		VARCHAR2(1),
	item_seq 		VARCHAR2(3),
	cust_id 		VARCHAR2(14),
	amount 		    VARCHAR2(9),
	invoice_num 	VARCHAR2(16),
	invoice_date 	DATE,
	check_num 		VARCHAR2(8),
	manifest_no 	VARCHAR2(7),
	add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
	upd_user 		VARCHAR2(30),
	upd_date 		DATE,
    CONSTRAINT SAP_CR_OUT_PK PRIMARY KEY(sequence_number, interface_type, record_status, datetime)
);

CREATE SEQUENCE SWMS.SAP_CR_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TYPE SWMS.SAP_CR_OBJECT AS OBJECT
(
    batch_id        number(8),
	batch_no 		VARCHAR2(9),
	batch_type 		VARCHAR2(1),
	item_seq 		VARCHAR2(3),
	cust_id 		VARCHAR2(14),
	amount 		    VARCHAR2(9),
	invoice_num 	VARCHAR2(16),
	invoice_date 	DATE,
	check_num 		VARCHAR2(8),
	manifest_no 	VARCHAR2(7)
);
/

CREATE OR REPLACE TYPE SWMS.SAP_CR_OBJECT_TABLE AS TABLE of SAP_CR_OBJECT;
/
CREATE OR REPLACE PUBLIC SYNONYM SAP_CR_OUT FOR SWMS.SAP_CR_OUT;

CREATE OR REPLACE  PUBLIC SYNONYM SAP_CR_SEQ FOR SWMS.SAP_CR_SEQ;

-- For SMI004 - Queue 'ML'.

CREATE TABLE SWMS.SAP_ML_IN
(
	sequence_number     number(10),
	interface_type      varchar2(3),
	record_status	    varchar2(1),
	datetime 	    date,
	message_type 	    varchar2(50),
	order_id            varchar2(35),
	description         varchar2(50),
	order_priority      varchar2(2),
	order_type          varchar2(10),
	order_date          varchar2(10),
	order_item_id       varchar2(10),
	uom                 varchar2(1),
	prod_id             varchar2(9),
	cust_pref_vendor    varchar2(10),
	quantity_requested  varchar2(15),
	sku_priority        varchar2(2),
	order_item_id_count varchar2(18),
	dtl_rec_count       number(5),
	eob                 varchar2(1),
	add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
	upd_user 	    varchar2(30),
	upd_date 	    date,
	CONSTRAINT SAP_ML_IN_PK PRIMARY KEY(SEQUENCE_NUMBER,INTERFACE_TYPE,RECORD_STATUS,DATETIME)
);

CREATE SEQUENCE SWMS.SAP_ML_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PUBLIC SYNONYM SAP_ML_IN FOR SWMS.SAP_ML_IN;

CREATE OR REPLACE PUBLIC SYNONYM SAP_ML_SEQ FOR SWMS.SAP_ML_SEQ;

-- Alter statments

ALTER TABLE 
SWMS.customers 
MODIFY 
( 
  	cust_id varchar2(10),
  	ship_addr1 varchar2(80),
   	ship_addr3 varchar2(160)
)
;

ALTER TABLE 
SWMS.ORDD 
MODIFY 
sys_order_id NUMBER(10);

ALTER TABLE SWMS.ORDM 
MODIFY sys_order_id NUMBER(10);

ALTER TABLE SWMS.TRANS 
MODIFY sys_order_id NUMBER(10);

ALTER TABLE SWMS.swms_log
ADD MSG_ALERT VARCHAR2(1);

--For PRI004

CREATE TABLE SWMS.SAP_PO_IN
(
	sequence_number number(10),
	interface_type varchar2(3),
	record_status varchar2(1),
	datetime date,
	rec_type varchar2(1),            
	erm_id varchar2(16),
	erm_type varchar2(2),
	prod_id varchar2(9),
	cust_pref_vendor varchar2(10),
	item_seq varchar2(3),
	uom varchar2(1),
	ord_qty_sign varchar2(1),
	qty varchar2(4),
	cust_id varchar2(10),
	cust_name varchar2(17),
	order_id varchar2(9),
	cmt varchar2(30),
	saleable varchar2(1),
	mispick varchar2(1),
	master_case_ind varchar2(2),	
	func_code varchar2(1),
	source_id varchar2(10),
	sched_date varchar2(6),
	sched_time varchar2(8),
	ship_date varchar2(6),
	phone_no varchar2(14),
	ship_via varchar2(3),
	line_no varchar2(3),
	carr_id varchar2(10),
	ship_addr1 varchar2(25),
	ship_addr2 varchar2(25),
	ship_addr3 varchar2(30),
	exp_arriv_date varchar2(6),
	warehouse_id varchar2(3),
	from_warehouse_id varchar2(3),
	to_warehouse_id varchar2(3),
	freight varchar2(1),
	erm_line_id varchar2(3),
	sched_area varchar2(1),
	door_no varchar2(4),
	status varchar2(3),
	proc_line_no varchar2(2),
	inbound_sched_date varchar2(8),
    inbound_sched_time varchar2(6),
    msg_id varchar2(36),
	record_count number(5),
	add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
	upd_user varchar2(30),
	upd_date date,
	CONSTRAINT SAP_PO_IN_PK PRIMARY KEY(SEQUENCE_NUMBER,INTERFACE_TYPE,RECORD_STATUS,DATETIME)
);


CREATE SEQUENCE SWMS.SAP_PO_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE  PUBLIC SYNONYM SAP_PO_IN FOR SWMS.SAP_PO_IN;

CREATE OR REPLACE  PUBLIC SYNONYM SAP_PO_SEQ FOR SWMS.SAP_PO_SEQ;

--for SCI025

CREATE TABLE SWMS.SAP_WH_OUT
(
    batch_id number(8),
	Sequence_number number(10),
	interface_type varchar2(3),
	record_status varchar2(1),
	datetime date,
    rec_type  varchar(3),
    prod_id  varchar2(9),
    case_on_hand number(5),
    split_on_hand number(3),
    case_on_hold number(5),
    split_on_hold number(3),
    brand varchar2(7),
    pack varchar2(4),
    prod_size varchar2(6),
    descrip varchar2(30),
    buyer varchar2(3),
    cust_pref_vendor varchar2(10),
    upc varchar2(4),
	add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
	upd_user varchar2(30),
	upd_date date,
	CONSTRAINT SAP_WH_OUT_PK PRIMARY KEY(sequence_number, interface_type, record_status, datetime)
);

CREATE SEQUENCE SWMS.SAP_WH_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TYPE SWMS.SAP_WH_OBJECT as OBJECT
(
    batch_id number(8) ,
    rec_type  varchar(3),
    prod_id  varchar2(9),
    case_on_hand number(5),
    split_on_hand number(3),
    case_on_hold number(5),
    split_on_hold number(3),
    brand varchar2(7),
    pack varchar2(4),
    prod_size varchar2(6),
    descrip varchar2(30),
    buyer varchar2(3),
    cust_pref_vendor varchar2(10),
    upc varchar2(4)    
);
/

CREATE OR REPLACE TYPE SWMS.SAP_WH_OBJECT_TABLE as TABLE of SAP_WH_OBJECT;
/

CREATE OR REPLACE PUBLIC SYNONYM SAP_WH_OUT FOR SWMS.SAP_WH_OUT;

CREATE OR REPLACE PUBLIC SYNONYM SAP_WH_SEQ FOR SWMS.SAP_WH_SEQ;

-- SCI014 -- 
CREATE TABLE SWMS.SAP_OR_IN
(
    SEQUENCE_NUMBER NUMBER(10),
	INTERFACE_TYPE  VARCHAR2(3),
	RECORD_STATUS   VARCHAR2(1),
	DATETIME        DATE,
    REC_IND  	    varchar2(1),
    ORDER_ID        varchar2(16),
    CUST_ID         varchar2(14),
    SHIP_DATE	    varchar2(6),
    DEL_DATE	    varchar2(6),
    DEL_TIME	    varchar2(4),
    ROUTE_NO	    varchar2(10),
    TRUCK_NO	    varchar2(8),
    STOP_NO	        varchar2(7),
    TRUCK_TYPE	    varchar2(3),
    WEIGHT	        varchar2(9),
    ORDER_TYPE	    varchar2(3),
    IMMEDIATE_IND	varchar2(1),
    DELIVERY_METHOD	varchar2(1),
    cust_po	        varchar2(20),
    CUST_NAME	    varchar2(30),
    CUST_ADDR1	    varchar2(30),
    CUST_ADDR2	    varchar2(30),
    CUST_CITY	    varchar2(20),
    CUST_STATE	    varchar2(3),
    CUST_ZIP	    varchar2(10),
    SLSM	        varchar2(5),
    UNITIZE_IND	    varchar2(1),
    FRZ_SPECIAL	    varchar2(1),
    DRY_SPECIAL	    varchar2(1),
    CLR_SPECIAL	    varchar2(1),
    ORDER_LINE_ID	varchar2(3),
    SYS_ORDER_ID	varchar2(10),
    SYS_ORDER_LINE_ID	varchar2(5),
    PROD_ID	        varchar2(9),
    CUST_PREF_VENDOR	varchar2(10),
    QTY_ORDERED	    varchar2(4),
    UOM	            varchar2(1),
    AREA	        varchar2(1),
    CW_TYPE	        varchar2(1),
    QA_TICKET_IND	varchar2(1),
    PARTIAL	        varchar2(1),
    PCL_FLAG	    varchar2(1),
    PCL_ID	        varchar2(14),
    msg_id          varchar2(36),
    batch_record_count    number(5),
    route_count     number(5), 
    add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
	upd_user        varchar2(30),
	upd_date        date,
	CONSTRAINT SAP_OR_IN_PK PRIMARY KEY(SEQUENCE_NUMBER,INTERFACE_TYPE,RECORD_STATUS,DATETIME)
);

CREATE SEQUENCE SWMS.SAP_OR_SEQ START WITH 1 INCREMENT BY 1; 

CREATE OR REPLACE PUBLIC SYNONYM SAP_OR_IN FOR SWMS.SAP_OR_IN;

CREATE OR REPLACE PUBLIC SYNONYM SAP_OR_SEQ FOR SWMS.SAP_OR_SEQ;


-- MDI031 -- 
CREATE TABLE SWMS.SAP_CS_IN
(
    sequence_number number(10),
	interface_type varchar2(3),
	record_status varchar2(1),
	datetime Varchar2(16),
    func_Code varchar2(1),
	prod_id varchar2(9),
    item_cost Varchar2(10),
    add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
	upd_user varchar2(30),
	upd_date date,
	CONSTRAINT SAP_CS_IN_PK PRIMARY KEY(sequence_number,interface_type,record_status,datetime)
);

CREATE SEQUENCE SWMS.SAP_CS_SEQ START WITH 1 INCREMENT BY 1; 

CREATE OR REPLACE PUBLIC SYNONYM SAP_CS_IN FOR SWMS.SAP_CS_IN;

CREATE OR REPLACE PUBLIC SYNONYM SAP_CS_SEQ FOR SWMS.SAP_CS_SEQ;

--------------------------------- SYNTELIC INTERFACES ------------------------------------
------------------------------------------------------------------------------------------

-- SCI044-A
CREATE TABLE SWMS.SYNTELIC_LOADMAPPING_IN
(
	SEQUENCE_NUMBER number(10),
	INTERFACE_TYPE varchar2(3),
	RECORD_STATUS varchar2(1),
	DATETIME date,
	ROUTE_NO varchar2(10),
	TRUCK_NO varchar2(10),
	TRAILER_TYPE varchar2(20),
	FLOAT_SEQUENCE varchar2(3),
	LOAD_TYPE varchar2(1),
	TRAILER_ZONE varchar2(2),
    ORIENTATION varchar2(1),
	PROD_ID varchar2(9),
	ORDER_ID varchar2(14),
	ORDER_LINE_ID varchar2(3),
	CUSTOMER_ID varchar2(10),
	STOP_NO varchar2(8),
	QTY_ORDER varchar2(7),
	SHIP_DATE varchar2(8),
	UOM varchar2(1),
	add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
	UPD_USER varchar2(30),
	UPD_DATE date,
	CONSTRAINT SYNTELIC_LOADMAPPING_IN_PK PRIMARY KEY(sequence_number,interface_type,record_status,datetime)
);

CREATE TABLE SWMS.SLS_LOAD_MAP_DETAIL
(
	ROUTE_NO varchar2(10),
	TRUCK_NO varchar2(10),
	TRAILER_TYPE varchar2(20),
	FLOAT_SEQUENCE varchar2(3),
	LOAD_TYPE varchar2(1),
	TRAILER_ZONE number(2),
    ORIENTATION varchar2(1),
	PROD_ID varchar2(9),
	ORDER_ID varchar2(14),
	ORDER_LINE_ID number(3),
	CUSTOMER_ID number(10),
	STOP_NO number(7,2),
	QTY_ORDER number(7),
	SHIP_DATE date,
	UOM number(1)
);

CREATE SEQUENCE SWMS.SYNTELIC_LOADMAPPING_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PUBLIC SYNONYM SYNTELIC_LOADMAPPING_IN for SWMS.SYNTELIC_LOADMAPPING_IN;

CREATE OR REPLACE PUBLIC SYNONYM SYNTELIC_LOADMAPPING_SEQ for SWMS.SYNTELIC_LOADMAPPING_SEQ;

CREATE OR REPLACE PUBLIC SYNONYM SLS_LOAD_MAP_DETAIL for SWMS.SLS_LOAD_MAP_DETAIL;

-- SCI056-A
CREATE TABLE SWMS.SYNTELIC_MATERIAL_OUT 
(
    batch_id number(8),
	sequence_number Numeric(10),
	interface_type varchar2(3),
	record_status varchar2(1),
	datetime date, 
	prod_id varchar2(9),
	descrip varchar2(30),
	area varchar2(2),
	case_cube varchar2(7),
	g_weight varchar2(8),
	spc varchar2(4),
	catch_wt_trk varchar2(1),
	ti varchar2(4),
	hi varchar2(4),
	zone_id varchar2(5),
	split_trk varchar2(1),
	uom varchar2(2),
	mfg_sku varchar2(14),
	prod_size varchar2(9),
	prod_size_unit	varchar2(3),
	pack varchar2(4),
	logi_loc varchar2(10),
	add_user varchar2(30) default USER, 
	add_date date default SYSDATE, 
	upd_user varchar2(30), 
	upd_date date,
	PRIMARY KEY(sequence_number,interface_type,record_status,datetime)
);

CREATE SEQUENCE SWMS.SYNTELIC_MATERIAL_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TYPE SWMS.SYNTELIC_MATERIAL_OBJECT AS OBJECT
(
    batch_id number(8),
	prod_id varchar2(9),
	descrip varchar2(30),
	area varchar2(2),
	case_cube varchar2(7),
	g_weight varchar2(8),
	spc varchar2(4),
	catch_wt_trk varchar2(1),
	ti varchar2(4),
	hi varchar2(4),
	zone_id varchar2(5),
	split_trk varchar2(1),
	uom varchar2 (2),
	mfg_sku varchar2 (14),
	prod_size varchar2(9),
	prod_size_unit	varchar2(3),
	pack varchar2(4),
	logi_loc varchar2(10)
);
/

CREATE OR REPLACE TYPE SWMS.SYNTELIC_MATERIAL_OBJECT_TABLE AS TABLE of SYNTELIC_MATERIAL_OBJECT;
/

CREATE OR REPLACE PUBLIC SYNONYM SYNTELIC_MATERIAL_OUT for SWMS.SYNTELIC_MATERIAL_OUT;

CREATE OR REPLACE PUBLIC SYNONYM SYNTELIC_MATERIAL_SEQ for SWMS.SYNTELIC_MATERIAL_SEQ;

-- SCI043-A
CREATE TABLE SWMS.SYNTELIC_ROUTE_ORDER_OUT
(
    batch_id NUMBER(8),
    sequence_number number(10),
    interface_type varchar2(3),
    record_status varchar2(1),
    datetime date,
    route_order_flag  varchar2(1),
    route_no        varchar2(10),
    route_date      date,
    truck_no        varchar2(10),
    f_door		   varchar2(3),
    c_door		   varchar2(3),
    d_door		   varchar2(3),
    cust_id		   varchar2(10),
    stop_no		   varchar2(7),
    order_id		   varchar2(14),
    order_line_id   varchar2(3),
    prod_id		   varchar2(9),
    float_seq       varchar2(4),
    uom			   varchar2(2),
    qty_order       varchar2(9),
    spc			   varchar2(4),
    unitize_ind	   varchar2(1),
    sel_type		   varchar2(3),
    zone_id		   varchar2(5),
    area			   varchar2(2),
    src_loc		   varchar2(10),
    seq_no		   varchar2(3),
    immediate_ind  varchar2(1),
    selection_batch_no  varchar2(9),
    loader_batch_no  varchar2(9),
    method_id       varchar2(10),
    route_status    varchar2(3),
    add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
    upd_user varchar2(30),
    upd_date date,
    CONSTRAINT SYNTELIC_ROUTE_ORDER_OUT_PK PRIMARY KEY(SEQUENCE_NUMBER,INTERFACE_TYPE,RECORD_STATUS,DATETIME)
);

CREATE SEQUENCE SWMS.SYNTELIC_ROUTE_ORDER_SEQ start with 1 increment by 1;

CREATE OR REPLACE TYPE SWMS.SYNTELIC_ROUTE_OBJECT AS OBJECT
(
    BATCH_ID NUMBER(8),
	ROUTE_NO VARCHAR2 (10),
	ROUTE_DATE DATE, 
	TRUCK_NO VARCHAR2 (10),
	F_DOOR VARCHAR2 (3),
	C_DOOR VARCHAR2 (3),
	D_DOOR VARCHAR2 (3)
);
/

CREATE OR REPLACE TYPE SWMS.SYNTELIC_ORDER_OBJECT AS OBJECT
(
    BATCH_ID NUMBER(8),
	ROUTE_NO varchar2(10),
	ROUTE_DATE DATE,
	CUST_ID varchar2(10),
	STOP_NO varchar2(7),
	ORDER_ID varchar2(14),
	ORDER_LINE_ID varchar2(3),
	PROD_ID varchar2(9),
	FLOAT_SEQ varchar2(4),
	UOM varchar2(2),
	QTY_ORDER varchar2(9),
	SPC varchar2(4),
	UNITIZE_IND varchar2(1),
	SEL_TYPE varchar2(3),
	ZONE_ID varchar2(5),
	AREA varchar2 (2),
	SRC_LOC varchar2(10),
	SEQ_NO varchar2(3),
	IMMEDIATE_IND varchar2(1),
	SELECTION_BATCH_NO varchar2(9),
	LOADER_BATCH_NO varchar2(9),
	METHOD_ID varchar2(10)
);
/

CREATE OR REPLACE TYPE SWMS.SYNTELIC_ROUTE_OBJECT_TABLE AS TABLE of SYNTELIC_ROUTE_OBJECT;
/

CREATE OR REPLACE TYPE SWMS.SYNTELIC_ORDER_OBJECT_TABLE AS TABLE of SYNTELIC_ORDER_OBJECT;
/

CREATE OR REPLACE PUBLIC SYNONYM SYNTELIC_ROUTE_ORDER_OUT for SWMS.SYNTELIC_ROUTE_ORDER_OUT;

CREATE OR REPLACE PUBLIC SYNONYM SYNTELIC_ROUTE_ORDER_SEQ for SWMS.SYNTELIC_ROUTE_ORDER_SEQ;

-- For SCI068-C

CREATE TABLE SWMS.CUBITRON_MEASUREMENT_IN
(
	SEQUENCE_NUMBER number(10),
	INTERFACE_TYPE varchar2(3),
	RECORD_STATUS varchar2(1),
	DATETIME date,
	PROD_ID varchar2(9),
	G_WEIGHT varchar(9),
	CASE_CUBE varchar2(8),
	TI varchar2(4),
	HI varchar2(4),
	SCAN_DATE varchar2(16),
	CASE_HEIGHT varchar2(10),
	CASE_LENGTH varchar2(10),
	CASE_WIDTH varchar2(10),
	CASE_QTY_PER_CARRIER varchar2(4),
	add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
	UPD_USER varchar2(30),
	UPD_DATE date,
	CONSTRAINT CUBITRON_MEASUREMENT_IN_PK PRIMARY KEY 
	(sequence_number, interface_type, record_status, datetime)
);

CREATE SEQUENCE SWMS.CUBITRON_MEASUREMENT_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PUBLIC SYNONYM CUBITRON_MEASUREMENT_IN for SWMS.CUBITRON_MEASUREMENT_IN;

CREATE OR REPLACE PUBLIC SYNONYM CUBITRON_MEASUREMENT_SEQ for SWMS.CUBITRON_MEASUREMENT_SEQ;

-- For SCI105-C

CREATE TABLE SWMS.CUBITRON_ITEMMASTER_OUT
(
	SEQUENCE_NUMBER number(10),
	INTERFACE_TYPE varchar2(3),
	RECORD_STATUS varchar2(1),
	DATETIME date,
	PROD_ID varchar2(9),
	PACK varchar2(4),
	PROD_SIZE varchar2(6),
	BRAND varchar2(7),
	DESCRIP varchar2(30),
	MFG_SKU varchar2(14),
	TI varchar2(4),
	HI varchar2(4),
	CASE_CUBE varchar2(8),
	WEIGHT varchar2(9),
	G_WEIGHT varchar2(9),
	SPLIT varchar2(1),
	LOCATION varchar2(10),
	CATCH_WT_TRK varchar2(1),
	CONTAINER varchar2(4),
	VENDOR_ID varchar2(10),
	BUYER varchar2(3),
	PALLET_TYPE varchar2(2),
	MASTER_CASE varchar2(4),
	SPC varchar2(4),
	EXTERNAL_UPC varchar2(14),
	INTERNAL_UPC varchar2(14),
	add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
	UPD_USER varchar2(30),
	UPD_DATE date,
	CONSTRAINT CUBITRON_ITEMMASTER_OUT_PK PRIMARY KEY 
	(sequence_number, interface_type, record_status, datetime)
);

CREATE OR REPLACE TYPE SWMS.CUBITRON_ITEMMASTER_OBJECT AS OBJECT
(
	BATCH_ID number(8),
    PROD_ID varchar2(9),
	PACK varchar2(4),
	PROD_SIZE varchar2(6),
	BRAND varchar2(7),
	DESCRIP varchar2(30),
	MFG_SKU varchar2(14),
	TI varchar2(4),
	HI varchar2(4),
	CASE_CUBE varchar2(8),
	WEIGHT varchar2(9),
	G_WEIGHT varchar2(9),
	SPLIT varchar2(1),
	LOCATION varchar2(10),
	CATCH_WT_TRK varchar2(1),
	CONTAINER varchar2(4),
	VENDOR_ID varchar2(10),
	BUYER varchar2(3),
	PALLET_TYPE varchar2(2),
	MASTER_CASE varchar2(4),
	SPC varchar2(4),
	EXTERNAL_UPC varchar2(14),
	INTERNAL_UPC varchar2(14)
);
/

CREATE SEQUENCE SWMS.SWMS_CUBITRON_ITEMMASTER_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TYPE SWMS.CUBI_ITEMMASTER_OBJECT_TABLE AS TABLE of CUBITRON_ITEMMASTER_OBJECT;
/

CREATE OR REPLACE PUBLIC SYNONYM CUBITRON_ITEMMASTER_OUT for SWMS.CUBITRON_ITEMMASTER_OUT;

CREATE OR REPLACE PUBLIC SYNONYM SWMS_CUBITRON_ITEMMASTER_SEQ for SWMS.SWMS_CUBITRON_ITEMMASTER_SEQ;

-- FOR SCI069

CREATE TABLE SWMS.SAP_LM_OUT 
(
    batch_id number(8),
    bypass_flag varchar2(1) default 'N',
    sequence_number NUMERIC(10),
    interface_type VARCHAR2(3),
    record_status VARCHAR2(1),
    datetime VARCHAR2(16),
    prod_id VARCHAR2(9),
    cust_pref_vendor VARCHAR2(10),
    area VARCHAR2(2),
    ti VARCHAR2(4),
    hi VARCHAR2(4),
    abc VARCHAR2(1),
    mfr_shelf_life VARCHAR2(4),
    pallet_type VARCHAR2(2),
    lot_trk VARCHAR2(1),
    sysco_shelf_life VARCHAR2(4),
    fifo_trk VARCHAR2(1),
    cust_shelf_life VARCHAR2(4),
    exp_date_trk VARCHAR2(1),
    mfg_date_trk VARCHAR2(1),
    temp_trk VARCHAR2(1),
    min_temp VARCHAR2(7),
    max_temp VARCHAR2(7),
    miniload_storage_ind VARCHAR2(1),
    case_qty_per_carrier VARCHAR2(4),
    add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
    upd_user varchar2(30),
    upd_date date,  
    CONSTRAINT SAP_LM_OUT_PK PRIMARY KEY(sequence_number,interface_type,record_status,datetime)
);

CREATE SEQUENCE SWMS.SAP_LM_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TYPE SWMS.SAP_LM_OBJECT AS OBJECT
(
    batch_id number(8) ,
    bypass_flag varchar2(1),
    prod_id VARCHAR2(9),
    cust_pref_vendor VARCHAR2(10),
    area VARCHAR2(2),
    ti VARCHAR2(4),
    hi VARCHAR2(4),
    abc VARCHAR2(1),
    mfr_shelf_life VARCHAR2(4),
    pallet_type VARCHAR2(2),
    lot_trk VARCHAR2(1),
    sysco_shelf_life VARCHAR2(4),
    fifo_trk VARCHAR2(1),
    cust_shelf_life VARCHAR2(4),
    exp_date_trk VARCHAR2(1),
    mfg_date_trk VARCHAR2(1),
    temp_trk VARCHAR2(1),
    min_temp VARCHAR2(7),
    max_temp VARCHAR2(7),
    miniload_storage_ind VARCHAR2(1),
    case_qty_per_carrier VARCHAR2(4)
);
/

CREATE OR REPLACE TYPE SWMS.SAP_LM_OBJECT_TABLE AS TABLE of SAP_LM_OBJECT;
/

CREATE OR REPLACE PUBLIC SYNONYM SAP_LM_OUT for SWMS.SAP_LM_OUT;

CREATE OR REPLACE PUBLIC SYNONYM SAP_LM_SEQ for SWMS.SAP_LM_SEQ;

-- FOR SCI098

CREATE TABLE SWMS.SAP_CONTAINER_OUT 
(
    batch_id number(8),
    sequence_number NUMERIC(10),
    interface_type VARCHAR2(3),
    record_status VARCHAR2(1),
    datetime VARCHAR2(16),
    truck_no VARCHAR(4),
    route_no VARCHAR(10),
    order_id VARCHAR(14),
    order_line_id VARCHAR(4),
    cust_id VARCHAR(14),
    prod_id VARCHAR(9),
    total_qty VARCHAR(7),
    area VARCHAR(2),
    batch_no VARCHAR(9),
    src_loc	VARCHAR(10),
    pallet_qty VARCHAR(7),
    g_weight VARCHAR(9),
    lot_no VARCHAR(30),
    mfg_date VARCHAR(9),
    exp_date VARCHAR(9),
    rcv_date VARCHAR(9),
    temperature VARCHAR(9),
    add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
    upd_user VARCHAR2(30),
    upd_date DATE,
    CONSTRAINT SAP_CONTAINER_OUT_PK PRIMARY KEY(sequence_number,interface_type,record_status,datetime)
);

CREATE SEQUENCE SWMS.SAP_CONTAINER_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TYPE SWMS.SAP_CONTAINER_OBJECT AS OBJECT
(
    batch_id number(8) ,
    truck_no VARCHAR(4),
    route_no VARCHAR(10),
    order_id VARCHAR(14),
    order_line_id VARCHAR(4),
    cust_id VARCHAR(14),
    prod_id VARCHAR(9),
    total_qty VARCHAR(7),
    area VARCHAR(2),
    batch_no VARCHAR(9),
    src_loc	VARCHAR(10),
    pallet_qty VARCHAR(7),
    g_weight VARCHAR(9),
    lot_no VARCHAR(30),
    mfg_date VARCHAR(9),
    exp_date VARCHAR(9),
    rcv_date VARCHAR(9),
    temperature VARCHAR(9)
);
/

CREATE OR REPLACE TYPE SWMS.SAP_CONTAINER_OBJECT_TABLE AS TABLE of SAP_CONTAINER_OBJECT;
/

CREATE OR REPLACE PUBLIC SYNONYM SAP_CONTAINER_OUT for SWMS.SAP_CONTAINER_OUT;

CREATE OR REPLACE PUBLIC SYNONYM SAP_CONTAINER_SEQ for SWMS.SAP_CONTAINER_SEQ;

-- FOR SCI087

CREATE TABLE SWMS.SAP_EQUIP_OUT 
(
    batch_id number(8),
    sequence_number NUMERIC(10),
    interface_type VARCHAR2(5),
    record_status VARCHAR2(1),
    datetime VARCHAR2(16),
    equip_id VARCHAR2(10),
    inspection_date	DATE,	
    equip_name VARCHAR2(20),
    status VARCHAR2(2),
    add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
    upd_user VARCHAR2(30),
    upd_date DATE,
    CONSTRAINT SAP_EQUIP_OUT_PK PRIMARY KEY(sequence_number,interface_type,record_status,datetime)
);

CREATE SEQUENCE SWMS.SAP_EQUIP_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TYPE SWMS.SAP_EQUIP_OBJECT AS OBJECT
(
    batch_id number(8) ,
    equip_id VARCHAR2(10),
    inspection_date	DATE,	
    equip_name VARCHAR2(20),
    status VARCHAR2(2)
);
/

CREATE OR REPLACE TYPE SWMS.SAP_EQUIP_OBJECT_TABLE AS TABLE of SAP_EQUIP_OBJECT;
/

CREATE OR REPLACE PUBLIC SYNONYM SAP_EQUIP_OUT for SWMS.SAP_EQUIP_OUT;

CREATE OR REPLACE PUBLIC SYNONYM SAP_EQUIP_SEQ for SWMS.SAP_EQUIP_SEQ;

-- FOR PURGING THE STAGING TABLES

CREATE TABLE SWMS.SAP_INTERFACE_PURGE
(
    table_name VARCHAR2(30) NOT NULL,
    retention_days NUMBER(3) NOT NULL,
    description VARCHAR2(50),
CONSTRAINT SAP_INTERFACE_PURGE_PK PRIMARY KEY(TABLE_NAME)
);

ALTER TABLE SWMS.SAP_INTERFACE_PURGE ADD(UPD_USER VARCHAR(30) DEFAULT USER);
ALTER TABLE SWMS.SAP_INTERFACE_PURGE ADD(UPD_DATE DATE DEFAULT SYSDATE);
ALTER TABLE SWMS.SAP_SN_IN MODIFY(OPCO_NBR VARCHAR2(4));

CREATE OR REPLACE PUBLIC SYNONYM SAP_INTERFACE_PURGE for SWMS.SAP_INTERFACE_PURGE;

CREATE OR REPLACE PUBLIC SYNONYM PL_PURGE_STAGETABLE for SWMS.PL_PURGE_STAGETABLE;

CREATE OR REPLACE PUBLIC SYNONYM PL_SYNTELIC_INTERFACES for SWMS.PL_SYNTELIC_INTERFACES;

CREATE OR REPLACE PUBLIC SYNONYM PL_CUBITRON_INTERFACES for SWMS.PL_CUBITRON_INTERFACES;

CREATE OR REPLACE PUBLIC SYNONYM PL_SAP_INTERFACES for SWMS.PL_SAP_INTERFACES;

-- SAP_TRACE_STAGING_TABLE --

CREATE TABLE SWMS.SAP_TRACE_STAGING_TBL
(
    staging_table VARCHAR2(30),
    upd_user VARCHAR2(30),
    Ins_upd_flag VARCHAR2(1),
    sequence_number NUMBER(8),
    old_batch_id NUMBER(8),
    new_batch_id NUMBER(8),
    old_record_status VARCHAR2(1),
    new_record_status VARCHAR2(1),
    old_bypass_flag VARCHAR2(1),
    New_bypass_flag VARCHAR2(1),
    add_date DATE,
    SYS_CONTEXT_PARAMETER VARCHAR2(50)
);

create public synonym SAP_TRACE_STAGING_TBL for SWMS.SAP_TRACE_STAGING_TBL;

-- APPL_ERROR_LOG --

CREATE TABLE SWMS.APPL_ERROR_LOG
(
    routing_code VARCHAR2(16) NOT NULL,
    severity VARCHAR2(1) NOT NULL,   
    priority VARCHAR2(1) NOT NULL,
    error_code VARCHAR2(20) NOT NULL,
    error_seq NUMBER(7) NOT NULL, 
    error_status VARCHAR2(1),
    add_time TIMESTAMP,
    update_time TIMESTAMP,
    event_id NUMBER(7),
    error_msg VARCHAR2(70)    
);

create public synonym APPL_ERROR_LOG for SWMS.APPL_ERROR_LOG;

COMMIT;
