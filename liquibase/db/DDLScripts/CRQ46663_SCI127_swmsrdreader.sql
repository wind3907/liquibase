-- CRQ46663 : SCI127  - RD reader to be changed for receiving RDC attributes

CREATE TABLE SWMS.SAP_RD_IN
(  
  	sequence_number number(10),
      	interface_type varchar2(3),
   	record_status varchar2(1),
    	datetime date,
    	func_code varchar2(1),
    	prod_id varchar2(9),
    	cust_pref_vendor varchar2(10),
    	rdc_vendor_id varchar2(10),
    	rdc_address_code varchar2(2),
    	mf_ti varchar2(4),
   	mf_ti_sw varchar2(4),
    	mf_hi varchar2(4),
    	pallet_type varchar2(2),
    	case_length number,
    	case_width number,
    	case_height number,
    	case_cube number(7,4),
    	g_weight number(8,4),
    	cubitron varchar2(1),
     	rdc_effective_date date,
    	add_user varchar2(30) default USER,
    	add_date date default SYSDATE,
    	upd_user varchar2(30),
    	upd_date date,
	constraint sap_rd_in_pk primary key(sequence_number,interface_type,record_status,datetime)
);
CREATE SEQUENCE SWMS.SAP_RD_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PUBLIC SYNONYM SAP_RD_SEQ FOR SWMS.SAP_RD_SEQ;

CREATE OR REPLACE PUBLIC SYNONYM SAP_RD_IN FOR SWMS.SAP_RD_IN;

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_RD_IN', 5, 'RDC Item Attributes', replace(USER,'OPS$',NULL), SYSDATE);

grant all on SAP_RD_IN to SWMS_SAP;
grant all on SAP_RD_SEQ to SWMS_SAP;
grant all on SAP_RD_IN to SWMS_USER;
grant SELECT on SAP_RD_IN to SWMS_VIEWER;
