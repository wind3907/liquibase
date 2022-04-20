CREATE OR REPLACE TYPE swms.print_lp_result_record force AS OBJECT(
    location            VARCHAR2(10),
    pallet_id           VARCHAR2(18),
    ti                  NUMBER(4),
    hi                  NUMBER(4),
    case_qty            NUMBER(7),
    split_qty           NUMBER(7),
    prod_id             VARCHAR2(10),
    descrip             VARCHAR2(100), --   widened to allow for XML escaped characters
    mfg_sku             VARCHAR2(14),
    cust_pref_vendor    VARCHAR2(10),
    brand               VARCHAR2(7),
    exp_date            VARCHAR2(10),
    pallet_type         VARCHAR2(2),
    uom                 NUMBER(2),
    erm_id              VARCHAR2(12),
    erm_date            VARCHAR2(10),
    pack                VARCHAR2(4),
    prod_size           VARCHAR2(6),
    message             VARCHAR2(30),
    ucn                 VARCHAR2(5),
    logi_loc            VARCHAR2(10)
);
/

CREATE OR REPLACE TYPE swms.print_lp_result_table force
    AS TABLE OF swms.print_lp_result_record;
/

CREATE OR REPLACE TYPE swms.print_lp_result_obj force AS OBJECT(
    result_table swms.print_lp_result_table
);
/

GRANT EXECUTE ON swms.print_lp_result_obj TO swms_user;
