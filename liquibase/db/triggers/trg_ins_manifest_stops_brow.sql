CREATE OR REPLACE TRIGGER "SWMS"."TRG_INS_MANIFEST_STOPS_BROW" 
------------------------------------------------------------------------------
-- Trigger Name:
--    trg_ins_manifest_stops_brow
--
-- Table:
--    MANIFEST_STOPS
--
-- Description:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/30/21 kchi7065 Kiran Chimata
--                      
------------------------------------------------------------------------------
BEFORE
INSERT ON "MANIFEST_STOPS" FOR EACH ROW 
DECLARE
  v_sql_count binary_integer;
  l_route_no  ROUTE.ROUTE_NO%TYPE;
BEGIN
  IF :NEW.CUSTOMER IS NOT NULL THEN
    :NEW.CUSTOMER := TRANSLATE(:NEW.CUSTOMER, CHR(26)||CHR(130)||CHR(144)||CHR(160)||CHR(164)||CHR(165)||UNISTR('\0019'), ' eE nN ');
  END IF;

  IF :NEW.ADDR_LINE_1 IS NOT NULL THEN
    :NEW.ADDR_LINE_1 := TRANSLATE(:NEW.ADDR_LINE_1, CHR(26)||CHR(130)||CHR(144)||CHR(160)||CHR(164)||CHR(165)||UNISTR('\0019'), ' eE nN ');
  END IF;

  IF :NEW.ADDR_LINE_2 IS NOT NULL THEN
    :NEW.ADDR_LINE_2 := TRANSLATE(:NEW.ADDR_LINE_2, CHR(26)||CHR(130)||CHR(144)||CHR(160)||CHR(164)||CHR(165)||UNISTR('\0019'), ' eE nN ');
  END IF;

  IF :NEW.ADDR_CITY IS NOT NULL THEN
    :NEW.ADDR_CITY := TRANSLATE(:NEW.ADDR_CITY, CHR(26)||CHR(130)||CHR(144)||CHR(160)||CHR(164)||CHR(165)||UNISTR('\0019'), ' eE nN ');
  END IF;

  IF :NEW.SALESPERSON IS NOT NULL THEN
    :NEW.SALESPERSON := TRANSLATE(:NEW.SALESPERSON, CHR(26)||CHR(130)||CHR(144)||CHR(160)||CHR(164)||CHR(165)||UNISTR('\0019'), ' eE nN ');
  END IF;

  IF :NEW.NOTES IS NOT NULL THEN
    :NEW.NOTES := TRANSLATE(:NEW.NOTES, CHR(26)||CHR(130)||CHR(144)||CHR(160)||CHR(164)||CHR(165)||UNISTR('\0019'), ' eE nN ');
  END IF;

  -- Story 3644
  IF :NEW.XDOCK_IND = 'S' THEN

     /* type R is a pick up request that will not process thru WHOR queue */
     IF :new.rec_type = 'R' THEN
	select route_no into l_route_no
	from manifests
	where manifest_no = :new.manifest_no;

	INSERT into xdock_order_xref
	 (DELIVERY_DOCUMENT_ID,CROSS_DOCK_TYPE,SITE_FROM,SITE_TO,MANIFEST_NO_FROM,ROUTE_NO_FROM,
	  S_FULLFILLMENT_STATUS,OBLIGATION_NO,CUST_ID_FROM,ADD_USER,ADD_DATE,ORDER_ID_FROM)
	VALUES
	 (:new.delivery_document_id,:new.xdock_ind,pl_common.get_company_no,:NEW.SITE_ID,:new.manifest_no, l_route_no,
	  'ROUTED',:new.obligation_no,:new.customer_id,USER,SYSDATE,:new.invoice_no);

     ELSE
         UPDATE xdock_order_xref
         SET manifest_no_from = :NEW.MANIFEST_NO,
             obligation_no = :NEW.OBLIGATION_NO
         WHERE delivery_document_id = :NEW.DELIVERY_DOCUMENT_ID
         AND cross_dock_type = :NEW.XDOCK_IND;
    
         v_sql_count := SQL%ROWCOUNT;
     END IF;
  ELSIF :NEW.XDOCK_IND = 'X' THEN
     /* type R is a pick up request that will not process thru WHOR queue */
     IF :new.rec_type = 'R' THEN
	select route_no into l_route_no
	from manifests
	where manifest_no = :new.manifest_no;

	INSERT into xdock_order_xref
	 (DELIVERY_DOCUMENT_ID,CROSS_DOCK_TYPE,SITE_TO, SITE_FROM, MANIFEST_NO_TO,ROUTE_NO_TO,
	  X_LASTMILE_STATUS,OBLIGATION_NO,CUST_ID_TO,ADD_USER,ADD_DATE,ORDER_ID_TO)
	VALUES
	 (:new.delivery_document_id,:new.xdock_ind,pl_common.get_company_no,:NEW.SITE_ID,:new.manifest_no, l_route_no,
	  'ARRIVED',:new.obligation_no,:new.customer_id,USER,SYSDATE,:new.invoice_no);
     ELSE

         UPDATE xdock_order_xref
         SET manifest_no_to = :NEW.MANIFEST_NO,
             obligation_no = :NEW.OBLIGATION_NO
         WHERE delivery_document_id = :NEW.DELIVERY_DOCUMENT_ID
         AND cross_dock_type = :NEW.XDOCK_IND;

         v_sql_count := SQL%ROWCOUNT;
     END IF;
  END IF;

  IF ( :NEW.XDOCK_IND IN ('S', 'X') ) AND v_sql_count = 0 THEN

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => 'TRG_INS_MANIFEST_STOPS_BROW',
                i_msg_text         => 'No manifest cross dock update for delivery_document_id '||:NEW.DELIVERY_DOCUMENT_ID||' for cross doct type '||:NEW.XDOCK_IND,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => 'ORDER PROCESSING',
                i_program_name     => 'TRG_INS_MANIFEST_STOPS_BROW',
                i_msg_alert        => 'N');
      
  END IF;

END;
/
