/****************************************************************************
**
** Description:
**    Project: R47-R1_cross_dock
**       
**    This script will have DDL for the R1 Cross Dock project when adding
**    columns to existing tables.
**
**    Creating new tables will be in the DDL script for the card.
**
**    Note: New tables created for this project and related to cross docking
**          with have the table name starting with XDOCK.
**          We will continue to use column CROSS_DOCK_TYPE.
**
**    New columns:
**       ORDM table
**          document_type          VARCHAR2(1 CHAR)
**          delivery_document_id   VARCHAR2(30 CHAR)
**          site_id                VARCHAR2(5 CHAR)
**
**          Description:
**          document_type          Cards 3372, 3397
**                                 Sent by SUS in OR queue.  Valid values are 'S' or 'X'
**                                 This lets SWMS know this is a cross dock order.
**
**                                 Value Meaning
**                                 ----- -------------------------------------------------------------
**                                 S     Site 1 OpCo.  This is the fulfillment OpCo--the Opco picking the order.
**                                       The picking process will be almost identical to a non-cross dock order.
**                                       with the exception of how the floats are built based.
**
**                                 X     Site 2 OpCo.  This is the OpCo where the pallet will be cross
**                                       docked.  A shuttle will deliver the pallet(s) from Site 1 to 
**                                       Site 2.  Site 2 will receive (special receiving for cross dock pallets)
**                                       the cross pallets via SN sent from Site 1 and then load the pallets
**                                       onto the truck going to the end customer.  The cross dock pallets
**                                       can first go to a staging area before loading onto the truck
**                                       depending on the timing of events.
**
**                                 The swms OR reader program will ordm.document_type
**                                 The swms OR reader program will populate ordm.cross_dock type
**                                 from this.  As of now (04/21/2021) the cross_dock_type will be set
**                                 this same value.  Further processing in swms will look at ordm.cross_dock_type.
**                                                    
**          delivery_document_id   Card 3372, 3397
**                                 Sent by SUS in the OR queue.  The will be the same for the
**                                 Site 1 and Site 2.  This allow SWMS to tie the cross dock orders
**                                 together.
**                                 The swms OR reader program will ordm.delivery_document_id
**
**          site_id                Card 3372, 3397
**                                 Sent by SUS in the OR queue.
**                                 Value:  When document_type is 'S' this will be the last mile site.
**                                         When document_type is 'X' this will be the fulfillment site.
**                                 The swms OR reader program will ordm.site_id
**              
**                                                    
**
**       SAP_OR_IN table
**          document_type          VARCHAR2(1 CHAR)
**          delivery_document_id   VARCHAR2(30 CHAR)
**          site_id                VARCHAR2(5 CHAR)
**
**
**       PM table
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
**       FLOATS table
**          site_from              VARCHAR2(5 CHAR)
**          site_to                VARCHAR2(5 CHAR)
**          cross_dock_type        VARCHAR2(2 CHAR)
**
**          Description:
**          site_from              Fulfillment OpCo             
**          site_to                Last mile OpCo
**          cross_dock_type        Type of cross dock.  Either 'S' or 'X'
**                                                                      
**
**    Notes from card OPCOF-3372:
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
**    Notes from card OPCOF-3399:
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
**    Notes from card OPCOF-3401 LP- Block Item Master from Updates (at site2)
**       As a system administrator,
**       I want to block an cross dock item that is from updates in the item master, if the item is not sold to customers at site2,
**       So that it will retain the item attributes from site1.
**
**       If the Site2 OpCo does not sell the product to their customers, then it should not be updatable unless it is sent to them from SUS.  
**
**		OPCOF-3372/3397 - LP - Modify SORoute Interface from SUS (WHOR) SUS1 to SWMS1
**		Add new columns to ORDM table for new interface changes
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    04/20/21 bben0556 Brian Bent
**                      Created.
**
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
   execute_stmt_add_col('ALTER TABLE swms.ordm        ADD (document_type            VARCHAR2(1  CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.ordm        ADD (delivery_document_id     VARCHAR2(30 CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.ordm        ADD (site_id                  VARCHAR2(5  CHAR))'  );

   execute_stmt_add_col('ALTER TABLE swms.sap_or_in   ADD (document_type            VARCHAR2(1  CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.sap_or_in   ADD (delivery_document_id     VARCHAR2(30 CHAR))'  );
   execute_stmt_add_col('ALTER TABLE swms.sap_or_in   ADD (site_id                  VARCHAR2(5  CHAR))'  );

   execute_stmt_add_col('ALTER TABLE swms.pm          ADD (read_only_flag           VARCHAR2(1  CHAR))'  );
END;
/
