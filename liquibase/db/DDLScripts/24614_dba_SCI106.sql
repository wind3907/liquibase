
-- For SCI106  

CREATE TABLE SWMS.SAP_PM_MISC_IN
(
    sequence_number NUMBER(10),
    fricew_id VARCHAR2(8),
    record_status VARCHAR2(1),
    attribute_ind VARCHAR2(30),
    func_code VARCHAR2(1),
    prod_id	VARCHAR2(9),
    pm_attribute VARCHAR2(10),
    msg_id varchar2(36),	
    add_user VARCHAR2(30),
    add_date DATE,
    upd_user VARCHAR2(30),
    upd_date DATE,
    constraint sap_pm_misc_in_pk primary key(sequence_number,fricew_id,record_status)
);

CREATE SEQUENCE SWMS.SAP_PM_MISC_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PUBLIC SYNONYM SAP_PM_MISC_SEQ FOR SWMS.SAP_PM_MISC_SEQ;

CREATE OR REPLACE PUBLIC SYNONYM SAP_PM_MISC_IN FOR SWMS.SAP_PM_MISC_IN;

