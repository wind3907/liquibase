CREATE TABLE SWMS.SAP_PW_OUT 
(
    batch_id number(8),
    sequence_number NUMERIC(10),
    interface_type VARCHAR2(5),
    record_status VARCHAR2(1),
    datetime VARCHAR2(16),
    erm_id VARCHAR2(16),
    status VARCHAR2(3),
    add_user varchar2(30) default USER, 
	add_date date default SYSDATE,
    upd_user VARCHAR2(30),
    upd_date DATE,
    CONSTRAINT SAP_PW_OUT_PK PRIMARY KEY(sequence_number,interface_type,record_status,datetime)
);

CREATE INDEX SWMS.SAP_PW_OUT_IDX1
ON SAP_PW_OUT(RECORD_STATUS);


CREATE SEQUENCE SWMS.SAP_PW_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TYPE SWMS.SAP_PW_OBJECT AS OBJECT
(
    batch_id number(8) ,
    erm_id VARCHAR2(16),
    status VARCHAR2(3)
);
/

CREATE OR REPLACE TYPE SWMS.SAP_PW_OBJECT_TABLE AS TABLE of SAP_PW_OBJECT;
/

CREATE OR REPLACE PUBLIC SYNONYM SAP_PW_OUT for SWMS.SAP_PW_OUT;
/

CREATE OR REPLACE PUBLIC SYNONYM SAP_PW_SEQ for SWMS.SAP_PW_SEQ;
/
