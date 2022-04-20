
  CREATE TABLE SWMS.MX_INV_REQUEST 
   (    
     REQUEST_ID     NUMBER, 
     BATCH_NO       VARCHAR2(14), 
     PROD_ID        VARCHAR2(10), 
     PALLET_ID      VARCHAR2(18), 
     QTY_REQUESTED  NUMBER, 
     STATUS         VARCHAR2(50), 
     SYS05_STATUS   VARCHAR2(1), 
     SYM07_STATUS   VARCHAR2(1), 
     SPUR_LOC       VARCHAR2(10), 
     REQUEST_DATE   DATE, 
     QTY_SHORT      NUMBER,
     ADD_DATE       DATE            DEFAULT SYSDATE   NOT NULL,
     ADD_USER       VARCHAR2(30)    DEFAULT USER      NOT NULL,
     UPD_DATE       DATE            DEFAULT SYSDATE,
     UPD_USER       VARCHAR2(30)    DEFAULT USER
   );

grant all on SWMS.MX_INV_REQUEST to swms_user;
grant all on SWMS.MX_INV_REQUEST to swms_mx;
create or replace public synonym MX_INV_REQUEST for SWMS.MX_INV_REQUEST;

CREATE SEQUENCE MX_INV_REQ_SEQ
MINVALUE 1000
MAXVALUE 99999999999
ORDER
START WITH 1000
INCREMENT BY 1;

create or replace public synonym MX_INV_REQ_SEQ for SWMS.MX_INV_REQ_SEQ;
               
grant all on SWMS.mx_inv_request to swms_user;
 
/      