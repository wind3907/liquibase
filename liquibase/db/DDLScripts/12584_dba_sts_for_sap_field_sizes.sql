ALTER TABLE SWMS.STS_ITEMS
MODIFY (
    CUST_ID              VARCHAR2(14),
    OBLIGATION_NO        VARCHAR2(16) );

ALTER TABLE SWMS.STS_PICKUPS
MODIFY (
    CUST_ID              VARCHAR2(14),
    OBLIGATION_NO        VARCHAR2(16) );

ALTER TABLE SWMS.STS_CASH_ITEM
MODIFY (
    CUST_ID              VARCHAR2(14),
    INVOICE_NUM          VARCHAR2(16) );

