
--*****************************************************************
-- SCE012-Enhancement Check Trailer and Product Temperatures
-- Script to add four new columns to the ERM table
--*****************************************************************
-- Table changes 

ALTER TABLE ERM
ADD 
(
	COOLER_TRAILER_TRK CHAR(1),
	FREEZER_TRAILER_TRK CHAR(1),
	COOLER_TRAILER_TEMP NUMBER(6,1),
	FREEZER_TRAILER_TEMP NUMBER(6,1)
);


--*****************************************************************
-- SCE018 - Load multiple routes per trailer
-- Script to add two new columns to ROUTE Table
-- Script to add a new column ORDM Table
--*****************************************************************
-- Table changes 

ALTER TABLE ROUTE
ADD 
(
	ADD_ON_ROUTE_SEQ NUMBER(3),
	OLD_TRUCK_NO VARCHAR2(10)
);

ALTER TABLE ORDM
ADD OLD_STOP_NO NUMBER(7,2);

--*****************************************************************
-- SCE027 - Product Shorted
-- Script to add three new columns to SOS_SHORT
--*****************************************************************
-- Table changes 

ALTER TABLE SOS_SHORT 
ADD 
   (
      SHORT_ON_SHORT_STATUS VARCHAR2(1),
      WHOUT_DATE DATE,
      WHOUT_BY VARCHAR2(30)   
   );   
   
--*****************************************************************
-- SCE045-SWMS Enhancement For Returns Processing
-- Script to add a new column to MANIFEST_DTLS Table
--*****************************************************************
-- Table changes 

ALTER  TABLE MANIFEST_DTLS
ADD 
    (
      INVOICE_NO VARCHAR2(14)
    );
     
     
--*****************************************************************
-- SCE042-Customer Id expansion
-- Script to modify the data type of CUST_ID across various tables 
--*****************************************************************
-- Table changes 

ALTER TABLE CLAM_BED_SHIPPING_HIST
MODIFY CUST_ID varchar2(10);

ALTER TABLE CUSTOMERS
MODIFY (
CUST_ID varchar2(10),
SHIP_ADDR1 varchar2(80),
SHIP_ADDR3 varchar2(160)
);

ALTER TABLE OB1RA_TMP
MODIFY CUST_ID varchar2(10);

ALTER TABLE ORDM
MODIFY (
CUST_ID varchar2(10),
SHIP_ADDR1 varchar2(80),
SHIP_ADDR3 varchar2(160)  
);

ALTER TABLE ORDM_HISTORY
MODIFY CUST_ID varchar2(10);

ALTER TABLE REC_ORDER_HDRS
MODIFY CUST_ID varchar2(10);

ALTER TABLE "RETURNS"
MODIFY CUST_ID varchar2(10);

ALTER TABLE STS_CASH_ITEM
MODIFY CUST_ID varchar2(10);

ALTER TABLE STS_ITEMS
MODIFY CUST_ID varchar2(10);

ALTER TABLE STS_ORDER_HIST
MODIFY CUST_ID varchar2(10);

ALTER TABLE STS_PICKUPS
MODIFY CUST_ID varchar2(10);

ALTER TABLE SPL_RQST_CUSTOMER
MODIFY CUSTOMER_ID varchar2(10);

--*****************************************************************
-- SCE057 – Add UOM Field to SWMS
-- Script to add  a new column in PM table
--*****************************************************************
-- Table changes

ALTER TABLE PM
ADD 
   (
      PROD_SIZE_UNIT varchar2(3)   
   );

--*****************************************************************
-- SCE020 – Non-Inventory Asset Tracking In STS
-- Script to Create a new Table and add a new column to LAS_TRUCK_EQUIPMENT_TYPE Table
--*****************************************************************
-- Table changes

CREATE TABLE STS_EQUIPMENT
(
    ROUTE_NO     VARCHAR2(10),
    TRUCK_NO     VARCHAR2(3),
    CUST_ID      VARCHAR2(14),
    BARCODE      VARCHAR2(8),
    STATUS       VARCHAR2(1),
    QTY          NUMBER(3,0),
    QTY_RETURNED NUMBER(3,0),
    ADD_DATE  DATE
);

-- Index creation
CREATE INDEX STS_EQUIPMENT_IDX1 ON STS_EQUIPMENT (CUST_ID, STATUS) NOPARALLEL;


ALTER TABLE LAS_TRUCK_EQUIPMENT_TYPE
ADD 
   (
      BARCODE  VARCHAR2(8),
      ASSET_COUNT NUMBER
   );
   
--*****************************************************************
-- SCE048 -  Item Master Changes
-- Script to create a  new table 
--*****************************************************************
-- Table changes 

CREATE TABLE PM_DIM_EXCEPTION
(
      PROD_ID           VARCHAR2(9),
      CUST_PREF_VENDOR  VARCHAR2(10),
      CASE_HEIGHT       NUMBER,
      CASE_LENGTH       NUMBER,
      CASE_WIDTH        NUMBER,
      CASE_CUBE         NUMBER(7,4),
      CASE_WEIGHT       NUMBER(8,4),
      ADD_DATE          DATE
);

--*****************************************************************
-- SCE053 - Make Plant Number 4 Digits in SWMS
-- Script to modify the data type a OPCO_NO in UPC_INFO Table
--*****************************************************************
-- Table changes 

ALTER TABLE UPC_INFO
MODIFY OPCO_NO varchar2(5) ;

--*****************************************************************
-- SCE072 - SWMS Enhancement Selector Notes
-- Script to add the route_batch_no field to Float_hist tableinmodify
-- Script to add pallet codes in spl_rqst_customer table 
--*****************************************************************
-- Table changes 

ALTER TABLE FLOAT_HIST
ADD 
    (
    FH_ROUTE_BATCH_NO NUMBER(7)
    );

-- Table changes

ALTER TABLE SPL_RQST_CUSTOMER 
ADD 
    (
    FRZ_PALLET_CODE varchar2(1),
    CLR_PALLET_CODE varchar2(1),
    DRY_PALLET_CODE varchar2(1)
    );

--*****************************************************************
-- SCE047-SQL Report in SWMS for Manifest
-- Script to add a new table called manifest_stops
--*****************************************************************
-- Table changes 

CREATE TABLE MANIFEST_STOPS(
    MANIFEST_NO        NUMBER(7)    NOT NULL,
    STOP_NO            NUMBER(7,2)  NOT NULL,
    OBLIGATION_NO      VARCHAR2(16) NOT NULL,
    INVOICE_NO         VARCHAR2(16) NOT NULL,
    CUSTOMER_ID        VARCHAR2(14) NOT NULL,
    CUSTOMER           VARCHAR2(30) NOT NULL,
    ADDR_LINE_1        VARCHAR2(80) NOT NULL,
    ADDR_LINE_2        VARCHAR2(40),  
    ADDR_LINE_3        VARCHAR2(160),  
    ADDR_CITY          VARCHAR2(20) NOT NULL,
    ADDR_STATE         VARCHAR2(3)  NOT NULL,
    ADDR_POSTAL_CODE   VARCHAR2(10),  
    SALESPERSON_ID     VARCHAR2(9),
    SALESPERSON        VARCHAR2(30),  
    TIME_IN            VARCHAR2(6),  
    TIME_OUT           VARCHAR2(6),
    BUSINESS_HRS_FROM  VARCHAR2(4),  
    BUSINESS_HRS_TO    VARCHAR2(4),  
    TERMS              VARCHAR2(30),
    INVOICE_QTY        NUMBER(5)    NOT NULL,
    INVOICE_AMT        NUMBER(9,2)  NOT NULL,
    INVOICE_CUBE       NUMBER(9,2)  NOT NULL,
    INVOICE_WGT        NUMBER(9,2)  NOT NULL,
    NOTES              VARCHAR2(160)
);	

 ALTER TABLE SWMS.MANIFEST_STOPS ADD (
 CONSTRAINT MANIFEST_STOPS_PK
 PRIMARY KEY (MANIFEST_NO, OBLIGATION_NO, INVOICE_NO, STOP_NO ));
 
--*****************************************************************
-- SCE014 - Finalize Goods Receipt in SWMS Receiving shortages, Overages and Damage
-- Script to add a new column demand_flag to PUTAWAYLST Table
--*****************************************************************
-- Table changes 

ALTER  TABLE PUTAWAYLST
ADD 
    (
      DEMAND_FLAG VARCHAR2(1)
    );

--*****************************************************************
-- SCE085 - Non-FIFO non demand replenishment and AWM changes 
-- Script to add a new column demand_flag to PUTAWAYLST Table
--*****************************************************************
-- Table changes 
    
ALTER TABLE PM
ADD 
(
    BUYING_MULTIPLE NUMBER(5),
    MAX_DSO NUMBER(4) 
);

