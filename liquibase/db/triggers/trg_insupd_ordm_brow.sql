------------------------------------------------------------------------------
-- Trigger Name:
--    trg_insupd_ordm_brow
--
-- Table:
--    ORDM
--
-- Description:
--    Before insert or update row trigger on the ORDM table.
--    Assign:
--      - site_from   R1 Xdock Derived from cross_dock_type and site_id
--      - site_to     R1 Xdock Derived from cross_dock_type and site_id
--      - upd_user
--      - upd_date
--
--    R1 Xdock
--    Populate site_from and site_to based on the values of the cross_dock_type and site_id.
--    The site_id is sent by SUS in the OR queue.
--
--          site_id                Sent by SUS in the OR queue.
--                                 Value:  When the cross dock type is 'S' this will be Site 2.
--                                         When the cross dock type is 'X' this will be Site 1.
--                                 The SWMS OR reader program will populate ordm.site_id
--
--          site_from              Fulfillment site.
--                                 When the cross dock type is 'S' this will be the current OpCo.
--                                 When the cross dock type is 'X' this will be set to ordm.site_id.
--                                 Populated by the OR reader program or DB trigger or OP generation ???
--
--          site_to                Last mile site.
--                                 When the cross dock type is 'S' this will be set to ordm.site_id.
--                                 When the cross dock type is 'X' this will be the current OpCo.
--                                 Populated by the OR reader program or DB trigger or OP generation ???
--
-- Exceptions Raised:
--    None.  Error is logged.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/21/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--                      Created.
--    08/25/21 kchi7065 Kiran Chimata
--                      R47-xdock-OPCO3587 Added code to update statuses on table XDOCK_ORDER_XREF.
--    08/26/21 knha8378 Kiet Nhan
--                      Modify script to include route#, customer id and others
------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER swms.trg_insupd_ordm_brow
BEFORE INSERT OR UPDATE ON swms.ordm
FOR EACH ROW

BEGIN

   -- 07/21/21
   -- R1 Xdock
   -- Populate site_from and site_to based on the values of the cross_dock_type and site_id.
   -- The site_id is sent by SUS in the OR queue.
   --
   IF INSERTING OR UPDATING THEN

      IF (:NEW.cross_dock_type = 'S') THEN
         :NEW.site_from := pl_common.get_company_no;
         :NEW.site_to   := :NEW.SITE_ID;

         IF INSERTING THEN 
		INSERT INTO xdock_order_xref 
                       (cross_dock_type, 
		        site_from, 
		        site_to, 
                        delivery_document_id, 
			s_fullfillment_status, 
			route_no_from,
			order_id_from,
			cust_id_from,
			add_user, 
			add_date)
     		values
		       (:NEW.cross_dock_type,
             		pl_common.get_company_no, 
             		:NEW.SITE_ID, 
             		:NEW.DELIVERY_DOCUMENT_ID,
             		'NEW',
			:NEW.ROUTE_NO,
			:NEW.ORDER_ID,
			:NEW.CUST_ID,
			USER,
			SYSDATE);
         END IF;
      ELSIF (:NEW.cross_dock_type = 'X') THEN

         :NEW.site_from := :NEW.site_id;
         :NEW.site_to   := pl_common.get_company_no;

         IF INSERTING THEN 
		INSERT INTO xdock_order_xref 
                       (cross_dock_type, 
		        site_from, 
		        site_to, 
                        delivery_document_id, 
			s_fullfillment_status, 
			x_lastmile_status, 
			route_no_to,
			order_id_to,
			cust_id_to,
			add_user, 
			add_date)
     		values
		       (:NEW.cross_dock_type,
             		:NEW.SITE_ID, 
             		pl_common.get_company_no, 
             		:NEW.DELIVERY_DOCUMENT_ID,
             		'NEW',
             		'NEW',
			:NEW.ROUTE_NO,
			:NEW.ORDER_ID,
			:NEW.CUST_ID,
           		 USER,
            		 sysdate);
         END IF;

      END IF; --new.cross_dock_type S or X condition

      IF UPDATING THEN
        IF :NEW.SITE_TO_TRUCK_NO IS NOT NULL 
            AND :NEW.SITE_TO_STOP_NO IS NOT NULL 
            AND :NEW.cross_dock_type='S' THEN 

            UPDATE xdock_order_xref
               SET s_fullfillment_status = 'ROUTED',
		   route_no_to = :NEW.site_to_route_no
             WHERE delivery_document_id = :NEW.DELIVERY_DOCUMENT_ID
	     AND   cross_dock_type='S';

        END IF;--truck and stop have values

        IF :OLD.status in ('NEW','PND') and :NEW.status in ( 'OPN','SHT') 
           AND :NEW.DELIVERY_DOCUMENT_ID is not NULL AND :new.cross_dock_type = 'X' THEN

            UPDATE xdock_order_xref
               SET x_lastmile_status = 'INTRANSIT',
		   route_no_from = (select distinct route_no 
				    from xdock_ordm_in 
				    where DELIVERY_DOCUMENT_ID=:NEW.DELIVERY_DOCUMENT_ID),
                   order_id_from = (select distinct order_id
				    from xdock_ordm_in 
				    where DELIVERY_DOCUMENT_ID=:NEW.DELIVERY_DOCUMENT_ID),
                   cust_id_from = (select distinct cust_id
				    from xdock_ordm_in 
				    where DELIVERY_DOCUMENT_ID=:NEW.DELIVERY_DOCUMENT_ID)
             WHERE delivery_document_id = :NEW.DELIVERY_DOCUMENT_ID
               AND cross_dock_type = 'X'
               AND x_lastmile_status = 'NEW';

          END IF;
      
      END IF; --UPDATING ONLY

   END IF; --INSERT OR UPDATING CONDITION
 
   IF UPDATING THEN
      :NEW.upd_user := REPLACE(USER, 'OPS$');
      :NEW.upd_date := SYSDATE;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it but don't stop processing.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => 'trg_insupd_ordm_brow',
                i_msg_text         => 'Error occurred in trigger.  NEW.order_id[' || :NEW.order_id || ']'
                               || '  Processing will continue.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => 'ORDER PROCESSING',
                i_program_name     => 'trg_insupd_ordm_brow',
                i_msg_alert        => 'N');

END trg_insupd_ordm_brow;
/
