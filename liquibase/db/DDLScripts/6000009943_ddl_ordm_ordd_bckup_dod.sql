--------------------------------------------------------------------
-- File Name : 6000009943_ddl_ordm_ordd_bckup_dod.sql 
-- Description : Adding DOD detail to ORDD and ORDM bckup tables
--
-- Change History:
--    Date     Authour   Description
-- 06-11-16    skam7488  Charm #6000009943. Initial Version
--------------------------------------------------------------------

ALTER TABLE swms.ORDM_BCKUP ADD (DOD_CONTRACT_NO VARCHAR2(13 CHAR));

ALTER TABLE swms.ORDD_BCKUP ADD (DOD_CUST_ITEM_BARCODE VARCHAR2(13 CHAR), DOD_FIC VARCHAR2(3 CHAR));
