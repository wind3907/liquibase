CREATE OR REPLACE  PACKAGE "SWMS"."STS_STORE"   IS
  last_route_index NUMBER;
  last_stop_index NUMBER;
  last_di_index NUMBER;
  last_route_id VARCHAR2(4);
  last_stop_number NUMBER;
  last_invoice_num VARCHAR2(9);
  last_item_id VARCHAR2(12);
  last_transaction_date VARCHAR2(8);
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_DEL_ROUTE_ITEM_BROW" BEFORE
DELETE ON "STS_ROUTE_DELIVER_ITEM" FOR EACH ROW BEGIN
  DELETE FROM STS_ROUTE_SPLIT_ITEM
   WHERE DI_INDEX = :OLD.DI_INDEX;
  DELETE FROM STS_ROUTE_REJECTED_ITEM
   WHERE DI_INDEX = :OLD.DI_INDEX;
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_DEL_ROUTE_PALLET_BROW" 
    BEFORE
DELETE ON "STS_ROUTE_DELIVER_PALLET" FOR EACH ROW BEGIN
  DELETE FROM STS_ROUTE_SPLIT_ITEM
   WHERE DI_INDEX = :OLD.DI_INDEX;
  DELETE FROM STS_ROUTE_REJECTED_ITEM
   WHERE DI_INDEX = :OLD.DI_INDEX;
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_DEL_STS_ROUTE_HEADER_BROW" 
    BEFORE
DELETE ON "STS_ROUTE_HEADER" FOR EACH ROW BEGIN
  DELETE FROM STS_ROUTE_STOPS
   WHERE ROUTE_INDEX = :OLD.ROUTE_INDEX;
  DELETE FROM STS_TRANSACTION
   WHERE ROUTE_INDEX = :OLD.ROUTE_INDEX;
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_DEL_STS_ROUTE_STOPS_BROW" 
    BEFORE
DELETE ON "STS_ROUTE_STOPS" FOR EACH ROW BEGIN
  DELETE FROM STS_ROUTE_STOP_CHECK
   WHERE STOP_INDEX = :OLD.STOP_INDEX;
  DELETE FROM STS_ROUTE_SCHEDULED_RETURN
   WHERE STOP_INDEX = :OLD.STOP_INDEX;
  DELETE FROM STS_ITEM_BARCODE
   WHERE STOP_INDEX = :OLD.STOP_INDEX;
  DELETE FROM STS_ROUTE_DELIVER_ITEM
   WHERE STOP_INDEX = :OLD.STOP_INDEX;
  DELETE FROM STS_ROUTE_DELIVER_PALLET
   WHERE STOP_INDEX = :OLD.STOP_INDEX;
  DELETE FROM STS_ROUTE_INVOICE
   WHERE STOP_INDEX = :OLD.STOP_INDEX;
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_INS_ROUTE_ITEM_BROW" BEFORE
INSERT ON "STS_ROUTE_DELIVER_ITEM" FOR EACH ROW BEGIN
  SELECT sts_di_seq.nextval, :new.item_id
    INTO sts_store.last_di_index, sts_store.last_item_id
    FROM dual;
  :new.stop_index := sts_store.last_stop_index;
  :new.di_index := sts_store.last_di_index;
  INSERT INTO sts_audit (trans_id, trans_date, rec_type, route_index, stop_index,
                         di_index, route_id, stop_number, invoice_num, item_id)
  VALUES (sts_audit_seq.nextval, SYSDATE, 'DI', sts_store.last_route_index,
          sts_store.last_stop_index, sts_store.last_di_index, sts_store.last_route_id,
          sts_store.last_stop_number, :new.invoice_num, :new.item_id);
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_INS_ROUTE_PALLET_BROW" 
    BEFORE
INSERT ON "STS_ROUTE_DELIVER_PALLET" FOR EACH ROW BEGIN
  SELECT sts_di_seq.nextval, :new.item_id
    INTO sts_store.last_di_index, sts_store.last_item_id
    FROM dual;
  :new.stop_index := sts_store.last_stop_index;
  :new.di_index := sts_store.last_di_index;
  INSERT INTO sts_audit (trans_id, trans_date, rec_type, route_index, stop_index,
                         di_index, route_id, stop_number, invoice_num, item_id)
  VALUES (sts_audit_seq.nextval, SYSDATE, 'DI', sts_store.last_route_index,
          sts_store.last_stop_index, sts_store.last_di_index, sts_store.last_route_id,
          sts_store.last_stop_number, :new.invoice_num, :new.item_id);
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_INS_ROUTE_STOP_CHECK_BROW" 
    BEFORE
INSERT ON "STS_ROUTE_STOP_CHECK" FOR EACH ROW BEGIN
  :new.stop_index := sts_store.last_stop_index;

  INSERT INTO sts_audit (trans_id, trans_date, rec_type, route_index, stop_index,
                         route_id, stop_number)
  VALUES (sts_audit_seq.nextval, SYSDATE, 'CN', sts_store.last_route_index,
          sts_store.last_stop_index, sts_store.last_route_id, sts_store.last_stop_number);
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_INS_STS_ITEM_BARCODE_BROW" 
    BEFORE
INSERT ON "STS_ITEM_BARCODE" FOR EACH ROW WHEN (NEW.DI_INDEX IS NULL AND NEW.STOP_INDEX IS NULL) DECLARE
  l_invoice_num sts_route_deliver_item.invoice_num%TYPE;
  l_item_id     sts_route_deliver_item.item_id%TYPE;
BEGIN
  IF :new.product_id = '000000000' THEN
    SELECT stop_index, di_index, invoice_num, item_id
      INTO :new.stop_index, :new.di_index, l_invoice_num, l_item_id
      FROM sts_route_deliver_pallet
     WHERE item_id = :new.item_id
       AND ROWNUM = 1;
  ELSE
    SELECT stop_index, di_index, invoice_num, item_id
      INTO :new.stop_index, :new.di_index, l_invoice_num, l_item_id
      FROM sts_route_deliver_item
     WHERE item_id = :new.item_id
       AND ROWNUM = 1;
  END IF;
  INSERT INTO sts_audit (trans_id, trans_date, rec_type, route_index, stop_index,
                         di_index, invoice_num, item_id)
  VALUES (sts_audit_seq.nextval, SYSDATE, 'BC', sts_store.last_route_index,
          :new.stop_index, :new.di_index, l_invoice_num, l_item_id);
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_INS_STS_ROUTE_HEADER_BROW" 
    BEFORE
INSERT ON "STS_ROUTE_HEADER" FOR EACH ROW BEGIN
  SELECT sts_route_seq.nextval, :new.route_id
    INTO sts_store.last_route_index, sts_store.last_route_id
    FROM DUAL;
  :new.route_index := sts_store.last_route_index;
  INSERT INTO sts_audit (trans_id, trans_date, rec_type, route_index, route_id)
  VALUES (sts_audit_seq.nextval, SYSDATE, 'RT', sts_store.last_route_index, :new.route_id);
  :new.route_filename := :new.route_id || '-' ||
    TO_CHAR(:new.sch_rls_time,'YYYYMMDDHH24MISS') || '.rt';
  :new.timestamp := SYSDATE;
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_INS_STS_ROUTE_STOPS_BROW" 
    BEFORE
INSERT ON "STS_ROUTE_STOPS" FOR EACH ROW BEGIN
  SELECT sts_stop_seq.nextval
    INTO sts_store.last_stop_index
    FROM DUAL;

  :new.route_index := sts_store.last_route_index;
  :new.stop_index := sts_store.last_stop_index;

  INSERT INTO sts_audit (trans_id, trans_date, rec_type, route_index, stop_index,
                         route_id, stop_number)
  VALUES (sts_audit_seq.nextval, SYSDATE, 'ST', sts_store.last_route_index,
          sts_store.last_stop_index, sts_store.last_route_id, :new.stop_number);
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_INS_STS_TRANSACTION_BROW" 
    BEFORE
INSERT ON "STS_TRANSACTION" FOR EACH ROW BEGIN
  IF :new.route_id IS NOT NULL THEN
    BEGIN
      SELECT route_index INTO :new.route_index
        FROM sts_route_header
       WHERE route_id = :new.route_id
         AND TRUNC(sch_rls_time) = TRUNC(:new.transaction_time);
    EXCEPTION
      WHEN OTHERS THEN
        :new.route_index := SQLCODE;
    END;
  END IF;

  IF :new.transaction_type = 'WRNSTP' THEN
    :new.wrnstp_stop_id := SUBSTR(:new.item_desc,1,INSTR(:new.item_desc,':')-1);
  END IF;

  IF :new.transaction_type = 'INVITM' THEN
    :new.invitm_barcode := :new.item_desc;
  END IF;

END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_ROUTE_REJECTED_ITEM_BROW" 
    BEFORE
INSERT ON "STS_ROUTE_REJECTED_ITEM" FOR EACH ROW BEGIN
  :new.di_index := sts_store.last_di_index;
  INSERT INTO sts_audit (trans_id, trans_date, rec_type, route_index, stop_index,
                         di_index, route_id, stop_number, invoice_num, item_id)
  VALUES (sts_audit_seq.nextval, SYSDATE, 'RJ', sts_store.last_route_index,
          sts_store.last_stop_index, :new.di_index, sts_store.last_route_id,
          sts_store.last_stop_number, sts_store.last_invoice_num, :new.item_id);
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_ROUTE_SCHED_RETURN_BROW" 
    BEFORE
INSERT ON "STS_ROUTE_SCHEDULED_RETURN" FOR EACH ROW BEGIN
  :new.stop_index := sts_store.last_stop_index;

  INSERT INTO sts_audit (trans_id, trans_date, rec_type, route_index, stop_index,
                         route_id, stop_number)
  VALUES (sts_audit_seq.nextval, SYSDATE, 'SR', sts_store.last_route_index,
          :new.stop_index, sts_store.last_route_id, sts_store.last_stop_number);
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_ROUTE_SPLIT_ITEM_BROW" 
    BEFORE
INSERT ON "STS_ROUTE_SPLIT_ITEM" FOR EACH ROW BEGIN
  :new.di_index := sts_store.last_di_index;
  INSERT INTO sts_audit (trans_id, trans_date, rec_type, route_index, stop_index,
                         di_index, route_id, stop_number, invoice_num, item_id)
  VALUES (sts_audit_seq.nextval, SYSDATE, 'SP', sts_store.last_route_index,
          sts_store.last_stop_index, sts_store.last_di_index, sts_store.last_route_id,
          sts_store.last_stop_number, sts_store.last_invoice_num, :new.item_id);
END;
/

CREATE OR REPLACE TRIGGER "SWMS"."TRG_STS_ROUTE_INVOICE_BROW" 
    BEFORE
INSERT ON "STS_ROUTE_INVOICE" FOR EACH ROW BEGIN
  :new.stop_index := sts_store.last_stop_index;

  INSERT INTO sts_audit (trans_id, trans_date, rec_type, route_index, stop_index,
                         route_id, stop_number, invoice_num)
  VALUES (sts_audit_seq.nextval, SYSDATE, 'IV', sts_store.last_route_index,
          sts_store.last_stop_index, sts_store.last_route_id, :new.stop_number,
          :new.invoice_num);
END;
/
