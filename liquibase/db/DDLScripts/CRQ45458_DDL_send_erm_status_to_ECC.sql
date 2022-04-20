-- CRQ45458 - Status send back to ECC
ALTER table swms.sap_pw_out ADD (ERM_TYPE VARCHAR2(3));
-- CRQ45458 - Added erm_type variable for returning.

CREATE OR REPLACE
TYPE SWMS.SAP_PW_OBJECT AS OBJECT
(
    batch_id number(8) ,
    erm_id VARCHAR2(16),
    status VARCHAR2(3),
    erm_type VARCHAR2(3)   
);
/
CREATE OR REPLACE TYPE SWMS.SAP_PW_OBJECT_TABLE AS TABLE of SAP_PW_OBJECT;
/
