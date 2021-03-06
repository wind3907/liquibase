CREATE OR REPLACE TRIGGER "SWMS"."TRG_UPD_PM_LAST_REC_DATE" AFTER
UPDATE OF "LAST_REC_DATE" ON "SWMS"."PM" FOR EACH ROW BEGIN
  UPDATE PM_UPC
     SET LAST_REC_DATE = :NEW.LAST_REC_DATE
   WHERE PROD_ID = :NEW.PROD_ID
     AND CUST_PREF_VENDOR = :NEW.CUST_PREF_VENDOR
     AND VENDOR_ID = :NEW.VENDOR_ID;
END;
/

