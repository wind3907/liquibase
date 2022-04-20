/****************************************************************************
**
** Description:
**    Project: R47-R1_cross_dock
**
**    The goal is to use this script when adding columns to existing tables.
**
**    Creating new tables will be in the DDL script for the card.
**
**    Note: New tables created for this project and related to cross docking
**          with have the table name starting with XDOCK.
**          We will continue to use column CROSS_DOCK_TYPE.
**
**    New columns:
**       ----------------------------
**       ROUTE table
**       ----------------------------
**          add_date               DATE
**          add_user               VARCHAR2(30 CHAR)
**          upd_date               DATE
**          upd_user               VARCHAR2(30 CHAR)
**
**
**       ----------------------------
**       ORDM table
**       ----------------------------
**          cross_dock_type        This is an existing column.  See the description below on how it is
**                                 used with the R1 cross dock project.
**          delivery_document_id   VARCHAR2(30 CHAR)
**          site_id                VARCHAR2(5  CHAR)
**          site_from              VARCHAR2(5  CHAR)
**          site_to                VARCHAR2(5  CHAR)
**          site_to_route_no       VARCHAR2(10 CHAR)
**          site_to_truck_no       VARCHAR2(10 CHAR)
**          site_to_stop_no        NUMBER(7,2)
**          site_to_door_no        VARCHAR2(10 CHAR)
**          add_date               DATE
**          add_user               VARCHAR2(30 CHAR)
**          upd_date               DATE
**          upd_user               VARCHAR2(30 CHAR)
**
**
**          Description:
**          cross_dock_type        This is populated in the OR reader program with the document type sent by SUS.
**                                 Valid values are 'S' or 'X'.
**                                 This lets SWMS know the type of the cross dock order as this affects the processing.
**                                 Note: SUS folks will be calling this the document type.  On SWMS it is
**                                       the cross dock type.
**
**                                 Value Meaning
**                                 ----- -------------------------------------------------------------
**                                 S     Site 1 OpCo.  This is the fulfillment OpCo--the Opco picking the order.
**                                       The picking process will be almost identical to a non-cross dock order
**                                       with the exception of a few changes on how the floats are built.
**
**                                 X     Site 2 OpCo.  This is the OpCo where the pallet will be cross
**                                       docked.  A shuttle will deliver the pallet(s) from Site 1 to
**                                       Site 2.  Site 2 will receive (special receiving for cross dock pallets)
**                                       the cross pallets via SN sent from Site 1 and then load the pallets
**                                       onto the truck going to the end customer.  The cross dock pallets
**                                       can first go to a staging area before loading onto the truck
**                                       depending on the timing of events.
**                                       Site 2 will treat the cross dock pallets similar to a bulk pull.
**
**          delivery_document_id   Sent by SUS in the OR queue. This is an ID that SUS uses to link the
**                                 order at Site 1 with the corresponding order at Site 2.
**                                 It will be the same value for Site 1 and Site 2.  This allow SWMS to tie
**                                 the cross dock orders together.
**                                 The SWMS OR reader program will populate ordm.delivery_document_id
**
**          site_id                Sent by SUS in the OR queue.
**                                 Value:  When the cross dock type is 'S' this will be Site 2.
**                                         When the cross dock type is 'X' this will be Site 1.
**                                 The SWMS OR reader program will populate ordm.site_id
**
**          site_from              Fulfillment site.
**                                 When the cross dock type is 'S' this will be the current OpCo.
**                                 When the cross dock type is 'X' this will be set to ordm.site_id.
**                                 Populated DB trigger using derived from cross_dock_type and site_id,
**
**          site_to                Last mile site.
**                                 When the cross dock type is 'S' this will be set to ordm.site_id.
**                                 When the cross dock type is 'X' this will be the current OpCo.
**                                 Populated DB trigger using derived from cross_dock_type and site_id,
**
**          site_to_route_no       Last mile site route number.
**                                 Populated when the cross dock type is 'S'.
**                                 It will be null when the cross dock type is 'X'.
**                                 Site 2 will send this to Site 1 when the 'X' order reaches Site 2.
**
**          site_to_truck_no       Last mile site truck number.
**                                 This is the truck number to print on the pick label set when picking at Site 1 for 'S' cross dock type.
**                                 Site 2 will send this to Site 1 when the 'X' order reaches Site 2.
**
**          site_to_stop_no        Last mile site stop number.
**                                 This is the stop number to print on the pick label set when picking at Site 1 for 'S cross dock type.
**                                 Site 2 will send this to Site 1 when the 'X' order reaches Site 2.
**                                 At Site 1 Floats will be built based on the Site 2 stop number.
**
**          site_to_door_no        Last mile site truck number.
**                                 This is the door at Site 2 the cross dock pallet will be loaded at.  This could be null.
**                                 Site 2 will send this to Site 1 when the 'X' order reaches Site 2.
**
**
**       ----------------------------
**       ORDD table
**       ----------------------------
**          add_date               DATE
**          add_user               VARCHAR2(30 CHAR)
**          upd_date               DATE
**          upd_user               VARCHAR2(30 CHAR)
**
**
**       ----------------------------
**       SAP_OR_IN table
**       ----------------------------
**          cross_dock_type        VARCHAR2(2  CHAR)
**          delivery_document_id   VARCHAR2(30 CHAR)
**          site_id                VARCHAR2(5  CHAR)
**          site_from              VARCHAR2(5  CHAR)     -- Not sure we need this in this table ???
**          site_to                VARCHAR2(5  CHAR)     -- Not sure we need this in this table ???
**          site_to_route_no       VARCHAR2(10 CHAR)
**          site_to_truck_no       VARCHAR2(10 CHAR)
**          site_to_stop_no        NUMBER(7,2)
**          site_to_door_no        VARCHAR2(10 CHAR)
**
**
**       ----------------------------
**       PM table
**       ----------------------------
**          read_only_flag         VARCHAR2(1 CHAR)
**
**          Description:
**          read_only_flag         Cards 3399, 3401, 3413
**                                 If 'Y' then the item cannot be updated using
**                                 the screens-- item maintenance, receiving, inv edit, case dimensions edit.
**
**                                 Site 2 most likely will not have the cross dock item in PM.
**                                 There is a new interface from Site 1 to Site 2 sending the cross dock items.
**                                 If the item does not exist in the Site 2 PM table then a
**                                 record is inserted into PM table and "read_only_flag" set to 'Y'.
**                                 If the item exists in the Site 2 PM table and "read_only_flag" is 'Y'
**                                 then the item is updated.
**                                 If the item exists in the Site 2 PM table and "read_only_flag" is 'N' or blank
**                                 then the item is not updated.
**
**                                 If the item comes down to Site 2 in the IM queue and and ""read_only_flag" is 'Y' then
**                                 "read_only_flag" will be cleared and the item processed normally.
**
**       ----------------------------
**       FLOATS table
**       ----------------------------
**          site_from              VARCHAR2(5 CHAR)
**          site_to                VARCHAR2(5 CHAR)
**          cross_dock_type        VARCHAR2(2 CHAR)
**          add_date               DATE
**          add_user               VARCHAR2(30 CHAR)
**          upd_date               DATE
**          upd_user               VARCHAR2(30 CHAR)
**          cross_dock_type        VARCHAR2(2 CHAR)  
**          xdock_pallet_id        VARCHAR2(18 CHAR)  
**          site_from_pallet_pull  VARCHAR2(1 CHAR)  
**          site_from_fl_sel_type  VARCHAR2(2 CHAR)  
**
**          Description:
**          site_from              Fulfillment OpCo.  Populated during order generation.
**          site_to                Last mile OpCo.  Populated during order generation.
**          cross_dock_type        Type of cross dock.  Either 'S' or 'X'.  Populated during order generation.
**          xdock_pallet_id        Unique pallet id assigned to the cross dock pallet.  It is unique across all OpCos.
**                                 Populated during order generation.
**          site_from_pallet_pull  Site 1 pallet pull.  When orders merged at Site 2 the Site 1 floats pallet pull
**                                 is saved here.
**                                 Site 2 STS needs to know if the cross dock pallet was
**                                 a pallet pull or bulk pull at Site 1.
**          site_from_fl_sel_type  Site 1 sel type--NOR, PAL, UNI, etc.  When orders merged at Site 2 the Site 1 floats
**                                 sel type is saved here.
**                                 Site 2 STS may need to know the Site 1 sel type.
**
**       ----------------------------
**       FLOAT_DETAIL table
**       ----------------------------
**          add_date               DATE
**          add_user               VARCHAR2(30 CHAR)
**          upd_date               DATE
**          upd_user               VARCHAR2(30 CHAR)
**
**          Description:
**          site_from              Fulfillment OpCo.  Populated during order generation.
**          site_to                Last mile OpCo.  Populated during order generation.
**
**       ----------------------------
**       REPLENLST table
**       ----------------------------
**          site_from              VARCHAR2(5 CHAR)
**          site_to                VARCHAR2(5 CHAR)
**          cross_dock_type        VARCHAR2(2 CHAR)  
**          xdock_pallet_id        VARCHAR2(18 CHAR)  
**
**          Description:
**          cross_dock_type        Type of cross dock.  Either 'S' or 'X' or null.  Populated when the replenlst record is created
**          xdock_pallet_id        Unique pallet id assigned to the cross dock pallet.  It is unique across all OpCos.
**                                 Populated when the replenlst record is created
**
**       ----------------------------
**       TRANS table
**       ----------------------------
**          cross_dock_type        VARCHAR2(2 CHAR)
**
**       ----------------------------
**       OP_TRANS table
**       ----------------------------
**          cross_dock_type        VARCHAR2(2 CHAR)
**
**       ----------------------------
**       MINILOAD_TRANS table
**       ----------------------------
**          cross_dock_type        VARCHAR2(2 CHAR)
**
**
**    FYI - Notes from card OPCOF-3372:
**       As a SWMS Warehouse Supervisor,
**       I want the Xdock orders from SUS to include the Delivery Document #,
**       a Xdock indicator and the OpCo shipping the product (last mile OpCo #),
**       So that when I generate the order, SWMS will identify Xdock orders and process
**       them differently than non-Xdock orders.
**
**       This is the interface for the route information coming from SUS to SWMS.
**       SUS will send 3 new WHOR fields at the end of the existing message.
**       Doc Type field - 1 Char - S for the Fulfillment site (Site1) and X for the Last Mile site (site2)
**       Delivery Document ID -30 Var Char - 123456789012345678901234567890
**       Last Mile OpCo - 5 digit
**
**       Examples
**          At Site 1:
**             Doc type - S
**             Delivery ID - 123456789012345678901234567890
**             Site ID - xx003   (this is the last mile site)
**
**          At Site 2:
**             Doc type - X
**             Delivery ID - 123456789012345678901234567890
**             Site ID - xx016   (this is the fulfillment site)
**
**
**    FYI - Notes from card OPCOF-3399:
**       As a system administer,
**       I want the cross docked item updated when we decide to start shipping it to our customers
**       (no longer just a cross docked item for another OpCo),
**       So that the items attributes can be updated in the item master.
**
**       When there is an item in SWMS (site2) that is being crossed docked for another OpCo,
**       and it is not a item that site 2 ships for it's customers, then the item record is
**       prevented from updates.  This story is to allow the updates, when SUS2 determines it
**       will be shipped to the SWMS2 customers and sends the item to SWMS2.  Then the item will
**       need to accept the updates.
**
**    FYI - Notes from card OPCOF-3401 LP- Block Item Master from Updates (at site2)
**       As a system administrator,
**       I want to block an cross dock item that is from updates in the item master, if the item is not sold to customers at site2,
**       So that it will retain the item attributes from site1.
**
**       If the Site 2 OpCo does not sell the product to their customers, then it should not be updatable unless it is sent to them from SUS.
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    04/20/21 bben0556 Brian Bent
**                      Created.
**
**	  07/21/21 ECLA1411 Ben Clark
** 		R1-OPCOF-3383 and OPCOF-3384 LP-Associate BLPN To Float - Site 1
**
**    05/20/21 bben0556 Brian Bent
**                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
**                      Add colums to FLOATS and FLOATS_BCKUP.
**
**    08/07/21 pdas8114 Card: 3553/3385 Added cols to sap_mf_in,manifest_dtls, manifest_stops and returns
**    08/18/21 bben0556 Brian Bent
**                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
**                      Add cross_dock_type to REPLENLST.
**                      Add site_from to REPLENLST.
**                      Add site_to to REPLENLST.
**
**    09/10/21 bben0556 Brian Bent
**                      R1 cross dock.
**                      Card: R47-xdock-OPCOF3663_OP_Site_2_Merge_float_ordcw_sent_from_Site_1
**                      Add site_from_pallet_pull to FLOATS
**                      Add site_from_fl_sel_type to FLOATS
**
**    10/14/21 bben0556 Brian Bent
**                      R1 cross dock.
**                      Card: R47_0-xdock-OPCOF3725_Site_2_Create_PIK_transaction_for_cross_dock_pallet
**                      Add cross_dock_type to TRANS, OP_TRANS and MINILOAD_TRANS.
**
**    10/25/21 bben0556 Brian Bent
**                      R1 cross dock.
**                      Card: R47_0-xdock-OPCOF3752_Site_1_put_site_2_truck_no_stop_no_on_RF_bulk_pull_label
**                      Add site_to_route_no, site_to_truck_no to FLOATS and REPLENLST.
**
**    11/16/21 bben0556 Brian Bent
**                      R1 cross dock.
**                      Card: R47_0_Xdock_OPCOF-3567_Site_2_Order_recovery_xdock_orders
**                      Add "site_from_float_no" column to FLOATS table.
**                      This column will be populated when the floats are merged at Site 2.
**
**                      Having the Site 1 float_no in the FLOATS table simplifies the order
**                      recovery process when a route is recoved at Site 2 as this float
**                      number can be used to easily identify the records in staging tables
**                      XDOCK_FLOATS_IN, XDOCK_FLOAT_DETAIL_IN and XDOCK_ORDCW_IN that need
**                      the record status set back to 'N'.
**     
****************************************************************************/

DECLARE
   --
   -- Local procedure to add a column to a table.
   --
   PROCEDURE execute_stmt_add_col(i_stmt IN VARCHAR2)
   IS
      e_column_already_exists  EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_column_already_exists, -1430);
   BEGIN
      EXECUTE IMMEDIATE(i_stmt);
   EXCEPTION
      WHEN e_column_already_exists THEN NULL;
      WHEN OTHERS THEN RAISE;
   END execute_stmt_add_col;

BEGIN
   --
   -- Add columns to tables.
   --
   execute_stmt_add_col('ALTER TABLE swms.route            ADD (add_date                 DATE DEFAULT SYSDATE)'  );
   execute_stmt_add_col('ALTER TABLE swms.route            ADD (add_user                 VARCHAR2(30 CHAR) DEFAULT REPLACE(USER, ''OPS$'', NULL))'  );
   execute_stmt_add_col('ALTER TABLE swms.route            ADD (upd_date                 DATE)'                  );
   execute_stmt_add_col('ALTER TABLE swms.route            ADD (upd_user                 VARCHAR2(30 CHAR))'     );

   execute_stmt_add_col('ALTER TABLE swms.route_bckup      ADD (add_date                 DATE DEFAULT SYSDATE)'  );
   execute_stmt_add_col('ALTER TABLE swms.route_bckup      ADD (add_user                 VARCHAR2(30 CHAR) DEFAULT REPLACE(USER, ''OPS$'', NULL))'  );
   execute_stmt_add_col('ALTER TABLE swms.route_bckup      ADD (upd_date                 DATE)'                  );
   execute_stmt_add_col('ALTER TABLE swms.route_bckup      ADD (upd_user                 VARCHAR2(30 CHAR))'     );


   execute_stmt_add_col('ALTER TABLE swms.ordm             ADD (delivery_document_id     VARCHAR2(30 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm             ADD (site_id                  VARCHAR2(5  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm             ADD (site_from                VARCHAR2(5  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm             ADD (site_to                  VARCHAR2(5  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm             ADD (site_to_route_no         VARCHAR2(10 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm             ADD (site_to_truck_no         VARCHAR2(10 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm             ADD (site_to_stop_no          NUMBER(7,2))'           );
   execute_stmt_add_col('ALTER TABLE swms.ordm             ADD (site_to_door_no          VARCHAR2(10 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm             ADD (add_date                 DATE DEFAULT SYSDATE)'  );
   execute_stmt_add_col('ALTER TABLE swms.ordm             ADD (add_user                 VARCHAR2(30 CHAR) DEFAULT REPLACE(USER, ''OPS$'', NULL))'  );
   execute_stmt_add_col('ALTER TABLE swms.ordm             ADD (upd_date                 DATE)'                  );
   execute_stmt_add_col('ALTER TABLE swms.ordm             ADD (upd_user                 VARCHAR2(30 CHAR))'     );

   execute_stmt_add_col('ALTER TABLE swms.ordm_bckup       ADD (delivery_document_id     VARCHAR2(30 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm_bckup       ADD (site_id                  VARCHAR2(5  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm_bckup       ADD (site_from                VARCHAR2(5  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm_bckup       ADD (site_to                  VARCHAR2(5  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm_bckup       ADD (site_to_route_no         VARCHAR2(10 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm_bckup       ADD (site_to_truck_no         VARCHAR2(10 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm_bckup       ADD (site_to_stop_no          NUMBER(7,2))'           );
   execute_stmt_add_col('ALTER TABLE swms.ordm_bckup       ADD (site_to_door_no          VARCHAR2(10 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.ordm_bckup       ADD (add_date                 DATE DEFAULT SYSDATE)'  );
   execute_stmt_add_col('ALTER TABLE swms.ordm_bckup       ADD (add_user                 VARCHAR2(30 CHAR) DEFAULT REPLACE(USER, ''OPS$'', NULL))'  );
   execute_stmt_add_col('ALTER TABLE swms.ordm_bckup       ADD (upd_date                 DATE)'                  );
   execute_stmt_add_col('ALTER TABLE swms.ordm_bckup       ADD (upd_user                 VARCHAR2(30 CHAR))'     );


   execute_stmt_add_col('ALTER TABLE swms.ordd             ADD (add_date                 DATE DEFAULT SYSDATE)'  );
   execute_stmt_add_col('ALTER TABLE swms.ordd             ADD (add_user                 VARCHAR2(30 CHAR) DEFAULT REPLACE(USER, ''OPS$'', NULL))'  );
   execute_stmt_add_col('ALTER TABLE swms.ordd             ADD (upd_date                 DATE)'                  );
   execute_stmt_add_col('ALTER TABLE swms.ordd             ADD (upd_user                 VARCHAR2(30 CHAR))'     );

   execute_stmt_add_col('ALTER TABLE swms.ordd_bckup       ADD (add_date                 DATE DEFAULT SYSDATE)'  );
   execute_stmt_add_col('ALTER TABLE swms.ordd_bckup       ADD (add_user                 VARCHAR2(30 CHAR) DEFAULT REPLACE(USER, ''OPS$'', NULL))'  );
   execute_stmt_add_col('ALTER TABLE swms.ordd_bckup       ADD (upd_date                 DATE)'                  );
   execute_stmt_add_col('ALTER TABLE swms.ordd_bckup       ADD (upd_user                 VARCHAR2(30 CHAR))'     );


   execute_stmt_add_col('ALTER TABLE swms.sap_or_in        ADD (cross_dock_type          VARCHAR2(2  CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.sap_or_in        ADD (delivery_document_id     VARCHAR2(30 CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.sap_or_in        ADD (site_id                  VARCHAR2(5  CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.sap_or_in        ADD (site_to_stop_no          NUMBER(7,2))');
   execute_stmt_add_col('ALTER TABLE swms.sap_or_in        ADD (site_to_route_no         VARCHAR2(10 CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.sap_or_in        ADD (site_to_truck_no         VARCHAR2(10 CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.sap_or_in        ADD (site_to_door_no          VARCHAR2(10 CHAR))'  );


   execute_stmt_add_col('ALTER TABLE swms.pm               ADD (read_only_flag           VARCHAR2(1  CHAR))'  );


   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (site_from                VARCHAR2(5  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (site_to                  VARCHAR2(5  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (cross_dock_type          VARCHAR2(2  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (add_date                 DATE DEFAULT SYSDATE)'  );
   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (add_user                 VARCHAR2(30 CHAR) DEFAULT REPLACE(USER, ''OPS$'', NULL))'  );
   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (upd_date                 DATE)'                  );
   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (upd_user                 VARCHAR2(30 CHAR))'     );
   -- ECLA1411 07/21/2021 R1-OPCOF-3383 and OPCOF-3384 LP-Associate BLPN To Float - Site 1
   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (xdock_pallet_id          VARCHAR2(18 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (site_from_pallet_pull    VARCHAR2(1 CHAR))'      );
   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (site_from_fl_sel_type    VARCHAR2(3 CHAR))'      );
   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (site_to_route_no         VARCHAR2(10 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (site_to_truck_no         VARCHAR2(10 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats           ADD (site_from_float_no       NUMBER(9))'             );

   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (site_from                VARCHAR2(5  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (site_to                  VARCHAR2(5  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (cross_dock_type          VARCHAR2(2  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (add_date                 DATE DEFAULT SYSDATE)'  );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (add_user                 VARCHAR2(30 CHAR) DEFAULT REPLACE(USER, ''OPS$'', NULL))'  );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (upd_date                 DATE)'                  );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (upd_user                 VARCHAR2(30 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (xdock_pallet_id          VARCHAR2(18 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (site_from_pallet_pull    VARCHAR2(1 CHAR))'      );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (site_from_fl_sel_type    VARCHAR2(3 CHAR))'      );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (site_to_route_no         VARCHAR2(10 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (site_to_truck_no         VARCHAR2(10 CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup     ADD (site_from_float_no       NUMBER(9))'             );


   execute_stmt_add_col('ALTER TABLE swms.float_detail     ADD (add_date                 DATE DEFAULT SYSDATE)'  );
   execute_stmt_add_col('ALTER TABLE swms.float_detail     ADD (add_user                 VARCHAR2(30 CHAR) DEFAULT REPLACE(USER, ''OPS$'', NULL))'  );
   execute_stmt_add_col('ALTER TABLE swms.float_detail     ADD (upd_date                 DATE)'                  );
   execute_stmt_add_col('ALTER TABLE swms.float_detail     ADD (upd_user                 VARCHAR2(30 CHAR))'     );

   execute_stmt_add_col('ALTER TABLE swms.float_detail_bckup  ADD (add_date              DATE DEFAULT SYSDATE)'  );
   execute_stmt_add_col('ALTER TABLE swms.float_detail_bckup  ADD (add_user              VARCHAR2(30 CHAR) DEFAULT REPLACE(USER, ''OPS$'', NULL))'  );
   execute_stmt_add_col('ALTER TABLE swms.float_detail_bckup  ADD (upd_date              DATE)'                  );
   execute_stmt_add_col('ALTER TABLE swms.float_detail_bckup  ADD (upd_user              VARCHAR2(30 CHAR))'     );


   --opcof-3466
   execute_stmt_add_col('ALTER TABLE swms.manifest_dtls   ADD (delivery_document_id     VARCHAR2(30 CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.manifest_dtls   ADD (site_id                  VARCHAR2(5  CHAR))'  );

   execute_stmt_add_col('ALTER TABLE swms.manifest_stops  ADD (xdock_ind                VARCHAR2(2  CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.manifest_stops  ADD (delivery_document_id     VARCHAR2(30 CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.manifest_stops  ADD (site_id                  VARCHAR2(5  CHAR))'  );

   execute_stmt_add_col('ALTER TABLE swms.sap_mf_in      ADD (xdock_ind                VARCHAR2(2  CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.sap_mf_in      ADD (delivery_document_id     VARCHAR2(30 CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.sap_mf_in      ADD (site_id                  VARCHAR2(5  CHAR))'  );

   execute_stmt_add_col('ALTER TABLE swms.returns   ADD (delivery_document_id     VARCHAR2(30 CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.returns   ADD (site_id                  VARCHAR2(5  CHAR))'  );


   execute_stmt_add_col('ALTER TABLE swms.replenlst    ADD (site_from                VARCHAR2(5  CHAR))'   );
   execute_stmt_add_col('ALTER TABLE swms.replenlst    ADD (site_to                  VARCHAR2(5  CHAR))'   );
   execute_stmt_add_col('ALTER TABLE swms.replenlst    ADD (cross_dock_type          VARCHAR2(2  CHAR))'   );
   execute_stmt_add_col('ALTER TABLE swms.replenlst    ADD (xdock_pallet_id          VARCHAR2(18 CHAR))'   );
   execute_stmt_add_col('ALTER TABLE swms.replenlst    ADD (site_to_route_no         VARCHAR2(10 CHAR))'   );
   execute_stmt_add_col('ALTER TABLE swms.replenlst    ADD (site_to_truck_no         VARCHAR2(10 CHAR))'   );

   
   execute_stmt_add_col('ALTER TABLE Pallet_Supplier ADD (Required VARCHAR2(1 CHAR))' );

   execute_stmt_add_col('ALTER TABLE swms.trans            ADD (cross_dock_type          VARCHAR2(2  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.op_trans         ADD (cross_dock_type          VARCHAR2(2  CHAR))'     );
   execute_stmt_add_col('ALTER TABLE swms.miniload_trans   ADD (cross_dock_type          VARCHAR2(2  CHAR))'     );

END;
/



