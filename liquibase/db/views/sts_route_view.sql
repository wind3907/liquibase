CREATE OR REPLACE VIEW SWMS.STS_ROUTE_VIEW AS
SELECT DISTINCT ROUTE_NO, ROUTE_DATE, SI.STOP_NO, 1 AS STS_SORT, FLOAT_SEQ,
       TRUCK_NO, SI.MANIFEST_NO, SI.CUST_ID, trim(NVL(MS.CUSTOMER, C.SHIP_NAME)) AS SHIP_NAME,
	   -- As per Jira574 made changes to address to eliminate duplicates
  trim(NVL(MS.ADDR_LINE_1, TRIM(C.SHIP_ADDR1)))  AS SHIP_ADDR1,
  trim(NVL(MS.ADDR_LINE_2, TRIM(C.SHIP_ADDR2)) ) AS SHIP_ADDR2,
  trim(NVL(MS.ADDR_CITY, C.SHIP_CITY) )          AS SHIP_CITY,
  trim(NVL(MS.ADDR_STATE,C.SHIP_STATE))          AS SHIP_STATE,
  trim(NVL(MS.ADDR_POSTAL_CODE,C.SHIP_ZIP))      AS SHIP_ZIP,
  trim(C.CUST_CONTACT)                           AS CUST_CONTACT,  
       NVL(MS.INVOICE_NO, SI.OBLIGATION_NO) AS OBLIGATION_NO, SI.PROD_ID, SI.CUST_PREF_VENDOR, UOM,
       ORDD_SEQ, (PM.BRAND || ' ' || PM.DESCRIP) AS DESCRIP, PM.CONTAINER,
       QTY_ORDERED, QTY_ALLOC, WH_OUT_QTY, PALLET_PULL,
       CUST_PO, UNITIZE_IND, SI.AREA, PICKTIME, TRUCK_ZONE, SI.OTHER_ZONE_FLOAT,
       PM.SPLIT_TRK, PM.CATCH_WT_TRK, PM.VENDOR_ID, PM.PACK, PM.SPC, SUBSTR( CONCAT(PM.PROD_SIZE, PM.PROD_SIZE_UNIT ), 1, 6 ) AS PROD_SIZE,
       NULL AS ORIG_INVOICE, 0 AS SHIPPED_QTY, NULL AS DISPOSITION,
       NULL AS RETURN_REASON_CD, NULL AS RETURN_PROD_ID, 0 AS CASE_SEQ, 
       ORDER_LINE_STATE, ORDER_LINE_DUP_QTY, MULTI_NO,
       FLOAT_NO, FLOAT_SEQ_NO, FLOAT_ZONE, BC_ST_PIECE_SEQ,
       QTY_SHORT, TOTAL_QTY, SOS_STATUS, SELECTOR_ID, MS.SALESPERSON_ID, MS.TIME_IN, MS.TIME_OUT,
       MS.SALESPERSON, MS.TERMS, MS.BUSINESS_HRS_FROM, MS.BUSINESS_HRS_TO, TO_CHAR(MS.INVOICE_AMT) AS INVOICE_AMT, 
       TO_CHAR(MS.INVOICE_CUBE) AS INVOICE_CUBE, TO_CHAR(MS.INVOICE_WGT) AS INVOICE_WGT, MS.NOTES,
       NULL AS BARCODE, 0 AS QTY_AT_STOP
        FROM STS_ITEMS SI, CUSTOMERS C, PM, MANIFEST_STOPS MS
           WHERE SI.CUST_ID = C.CUST_ID (+)
             AND SI.PROD_ID = PM.PROD_ID
             AND SI.CUST_PREF_VENDOR = PM.CUST_PREF_VENDOR
             AND SI.MANIFEST_NO = MS.MANIFEST_NO (+)
             AND SI.OBLIGATION_NO = MS.OBLIGATION_NO (+)
UNION
  SELECT DISTINCT ROUTE_NO, ROUTE_DATE, SP.STOP_NO, 2 AS STS_SORT, NULL,
         TRUCK_NO, SP.MANIFEST_NO, SP.CUST_ID, 
		 -- As per Jira574 made changes to address to eliminate duplicates
  trim(NVL(MS.CUSTOMER, C.SHIP_NAME)) AS SHIP_NAME,
  trim(NVL(MS.ADDR_LINE_1, TRIM(C.SHIP_ADDR1)))  AS SHIP_ADDR1,
  trim(NVL(MS.ADDR_LINE_2, TRIM(C.SHIP_ADDR2)) ) AS SHIP_ADDR2,
  trim(NVL(MS.ADDR_CITY, C.SHIP_CITY) )          AS SHIP_CITY,
  trim(NVL(MS.ADDR_STATE,C.SHIP_STATE))          AS SHIP_STATE,
  trim(NVL(MS.ADDR_POSTAL_CODE,C.SHIP_ZIP))      AS SHIP_ZIP,
  trim(C.CUST_CONTACT)                           AS CUST_CONTACT, 
  ('~' || SP.OBLIGATION_NO) AS OBLIGATION_NO, 
         SP.PROD_ID, SP.CUST_PREF_VENDOR, UOM,
         ORDD_SEQ, (PM.BRAND || ' ' || PM.DESCRIP) AS DESCRIP, PM.CONTAINER,
         0, 0, 0, NULL,
         NULL, NULL, NULL, TO_DATE(NULL), NULL, NULL,
         NULL, NULL, NULL, NULL, 0 AS SPC, NULL,
         SP.ORIG_INVOICE, SP.SHIPPED_QTY, DISPOSITION,
         RETURN_REASON_CD, RETURN_PROD_ID, 0 AS CASE_SEQ, NULL, 0, 0,
         0, 0, 0, 0, 0, 0, NULL, NULL, MS.SALESPERSON_ID, MS.TIME_IN, MS.TIME_OUT,
       MS.SALESPERSON, MS.TERMS, MS.BUSINESS_HRS_FROM, MS.BUSINESS_HRS_TO, TO_CHAR(MS.INVOICE_AMT), 
       TO_CHAR(MS.INVOICE_CUBE), TO_CHAR(MS.INVOICE_WGT), MS.NOTES,
       NULL AS BARCODE, 0 AS QTY_AT_STOP
         FROM STS_PICKUPS SP, CUSTOMERS C, PM, MANIFEST_STOPS MS
           WHERE SP.CUST_ID = C.CUST_ID (+)
             AND SP.PROD_ID = PM.PROD_ID
             AND SP.CUST_PREF_VENDOR = PM.CUST_PREF_VENDOR
             AND SP.MANIFEST_NO = MS.MANIFEST_NO (+)
             AND SP.OBLIGATION_NO = MS.OBLIGATION_NO (+)
UNION
  SELECT DISTINCT SC.ROUTE_NO, SC.ROUTE_DATE, SC.STOP_NO, 3 AS STS_SORT,
         NULL,
         NULL, 0, NULL, NULL,
         NULL, NULL, NULL, NULL, NULL,
         NULL, SI.OBLIGATION_NO AS OBLIGATION_NO, NULL, NULL, 0,
         SC.ORDD_SEQ, NULL AS DESCRIP, NULL,
         0, 0, 0, NULL,
         NULL, NULL, NULL, TO_DATE(NULL), SC.TRUCK_ZONE, NULL,
         NULL, NULL, NULL, NULL, 0 AS SPC, NULL,
         NULL AS ORIG_INVOICE, 0 AS SHIPPED_QTY, NULL AS DISPOSITION,
         NULL AS RETURN_REASON_CD, NULL AS RETURN_PROD_ID, SC.CASE_SEQ, NULL,
         0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL,
         NULL, NULL, NULL, NULL, NULL, NULL,
         NULL, NULL, NULL, NULL, NULL,
         NULL AS BARCODE, 0 AS QTY_AT_STOP        
         FROM STS_CASES SC, STS_ITEMS SI
         WHERE SC.ROUTE_NO   = SI.ROUTE_NO 
           AND SC.ROUTE_DATE = SI.ROUTE_DATE
           AND SC.ORDD_SEQ   = SI.ORDD_SEQ
UNION
  SELECT DISTINCT SQ.ROUTE_NO, SQ.ROUTE_DATE, SQ.STOP_NO, 4 AS STS_SORT,
         NULL,
         NULL, 0, SQ.CUST_ID, NULL,
         NULL, NULL, NULL, NULL, NULL,
         NULL, NULL AS OBLIGATION_NO, NULL, NULL, 0,
         0, NULL AS DESCRIP, NULL,
         0, 0, 0, NULL,
         NULL, NULL, NULL, TO_DATE(NULL), NULL, NULL,
         NULL, NULL, NULL, NULL, 0 AS SPC, NULL,
         NULL AS ORIG_INVOICE, 0 AS SHIPPED_QTY, NULL AS DISPOSITION,
         NULL AS RETURN_REASON_CD, NULL AS RETURN_PROD_ID, 0 AS CASE_SEQ, NULL,
         0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL,
         NULL, NULL, NULL, NULL, NULL, NULL,
         NULL, NULL, NULL, NULL, NULL,
         SQ.BARCODE AS BARCODE, SQ.QTY AS QTY_AT_STOP
         FROM STS_STOP_EQUIPMENT SQ
ORDER BY 1,2,3,16,4,5,19 Desc
/
GRANT SELECT ON STS_ROUTE_VIEW TO PUBLIC
/
CREATE OR REPLACE PUBLIC SYNONYM STS_ROUTE_VIEW
                            FOR SWMS.STS_ROUTE_VIEW
/
