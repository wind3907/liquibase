
CREATE TABLE SWMS.STS_STOP_EQUIPMENT (
       ROUTE_NO             VARCHAR2(10) NOT NULL,
       ROUTE_DATE           DATE NOT NULL,
       STOP_NO              NUMBER(7,2) NOT NULL,
       CUST_ID              VARCHAR2(10) NOT NULL,
       BARCODE              VARCHAR2(8) NOT NULL,
       QTY                  NUMBER(3) NULL
);

create or replace public synonym sts_stop_equipment for swms.sts_stop_equipment;

ALTER TABLE SWMS.STS_STOP_EQUIPMENT
       ADD  ( PRIMARY KEY (ROUTE_NO, ROUTE_DATE, CUST_ID) ) ;

