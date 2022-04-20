/****************************************************************************
** Date:       29-NOV-2019
** File:       type_rf_tm_close_receipt.sql
**
**             Script for creating objects for tm_close_receipt
**             server &client
**    - SCRIPTS
**
**    Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**    29/11/19   CHYD9155  type_rf_tm_close_receipt.sql
**                  

****************************************************************************/

/********    Server Objects  ************/
CREATE OR REPLACE TYPE close_rec_server_obj FORCE AS OBJECT (
    erm_id              VARCHAR2(12),
    prod_id             VARCHAR2(9),
    cust_pref_vendor    VARCHAR2(10),
    exp_splits          VARCHAR2(6),
    rec_splits          VARCHAR2(7),
    rec_qty             VARCHAR2(7),
    exp_qty             VARCHAR2(7),
    hld_cases           VARCHAR2(4),
    hld_splits          VARCHAR2(4),
    hld_pallet          VARCHAR2(4),
    total_pallet        VARCHAR2(4),
    num_pallet          VARCHAR2(4),
    sp_current_total    VARCHAR2(4),       /* special pallet qty in db */
    sp_supplier_count   VARCHAR2(4),      /* Number of suppliers in array */
    defaultweightunit   VARCHAR2(2) 		/* Added to pass the Weight unit to RF */
);
/

CREATE OR REPLACE TYPE str_supplier_name_obj1 FORCE AS OBJECT (
    name       VARCHAR2(20),
    required   VARCHAR2(1)
);
/

CREATE OR REPLACE TYPE str_supplier_name_table FORCE AS
    TABLE OF str_supplier_name_obj1;
/

CREATE OR REPLACE TYPE str_supplier_name_obj FORCE AS OBJECT (
    result_table str_supplier_name_table
);
/
	
	/********    client Objects  ************/

CREATE OR REPLACE TYPE close_rec_client_obj FORCE AS OBJECT (
    erm_id     VARCHAR2(12),
    flag       VARCHAR2(1),
    sp_flag    VARCHAR2(1),                     /*  Y, N (or null), C */
    sp_count   VARCHAR2(4)                 /* How many sp just entered */
);
/

CREATE OR REPLACE TYPE str_supplier_qty_obj1 FORCE AS OBJECT (
    name   VARCHAR2(20),
    qty    VARCHAR2(4)
);
/

CREATE OR REPLACE TYPE str_supplier_qty_table FORCE AS
    TABLE OF str_supplier_qty_obj1;
/

CREATE OR REPLACE TYPE str_supplier_qty_obj FORCE AS OBJECT (
    result_table str_supplier_qty_table
);
/

GRANT EXECUTE ON close_rec_server_obj TO swms_user;
GRANT EXECUTE ON str_supplier_name_obj1 TO swms_user;
GRANT EXECUTE ON str_supplier_name_table TO swms_user;
GRANT EXECUTE ON str_supplier_name_obj TO swms_user;
GRANT EXECUTE ON close_rec_client_obj TO swms_user;
GRANT EXECUTE ON str_supplier_qty_obj1 TO swms_user;
GRANT EXECUTE ON str_supplier_qty_table TO swms_user;
GRANT EXECUTE ON str_supplier_qty_obj TO swms_user;
