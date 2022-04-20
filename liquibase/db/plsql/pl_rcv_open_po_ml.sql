
SET DOC OFF

--------------------------------------------------------------------------
-- Package Specification
--------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE swms.pl_rcv_open_po_ml
AS

-- sccs_id=@(#) src/schema/plsql/pl_rcv_open_po_ml.sql, swms, swms.9, 11.2 12/17/09 1.6

---------------------------------------------------------------------------
-- Package Name:
--    pl_rcv_open_po_ml
--
-- Description:
--    This package directs mini-loader items to the induction location.
--    It is one of the packages used in the open PO/SN process.
--
--    See file pl_rcv_open_po_find_slot for more information.
--
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/20/06 prpbcb   Oracle 8 rs239b swms9 DN 12048
--                      Created.
--    03/24/06 prpbcb   Oracle 8 rs239b swms9 DN 12078
--                      The pallet record inv_uom was not set correctly.
--                      Moved the assignment of inv_uom to package
--                      pl_rcv_open_po_pallet_list.sql
--    11/08/09 prpbcb   Added AUTHID CURRENT_USER so things work correctly
--                      when pre-receiving into the new warehouse for a
--                      warehouse move.
--
--    12/17/09 prpbcb   DN 12533
--                      Removed AUTHID CURRENT_USER.  We found a problem in
--                      pl_rcv_open_po_cursors.f_get_inv_qty when using it.
--
--    07/20/17 bben0556 Brian Bent
--                      Project: 
--         30_6_Story_2030_Direct_miniload_items_to_induction_location_when_PO_opened
--
--                      Live Receiving change.
--                      Always set the putawaylst.dest_loc to the miniloader
--                      induction location and create inventory for pallets
--                      directed to the miniloader when the PO is opened
--                      regardless if Live Receiving is active.
--                      We don't want the pallets to "LR". 
--                      We need to do this because for the miniloader
--                      the expected receipts are sent to the
--                      miniloader when the PO is opened and syspar
--                      MINILOAD_AUTO_FLAG is set to Y.  If we use the
--                      "LR" logic then the creating of the expected receipts
--                      will fail because "LR" is not a valid location.
--                      Also since we know what pallets are going to the miniloader
--                      why use the "LR" logic.
--
--                      Modified "pl_rcv_open_po_types.sql"
--                         Added field "direct_to_ml_induction_loc_bln" to the pallet RECORD.
--                         The build pallet processing in "pl_rcv_open_po_list.sql"
--                         changed to set this to TRUE when the pallet is going to the miniloader
--                         induction location.
--
--                      Modified "pl_rcv_open_po_list.sql"
--                         Changed procedure "build_pallet_list_from_po" to
--                         populate "direct_to_ml_induction_loc_bln" in the
--                         pallet RECORD.
--
--                      Modified "pl_rcv_open_po_lr.sql"
--                         Changed procedure "create_putaway_task" adding
--                         parameter pl_rcv_open_po_types.t_r_item_info_table
--                         and calling "pl_rcv_open_po_ml.direct_ml_plts_to_induct_loc"
--
--                      Modified "pl_rcv_open_po_find_slot.sql"
--                         Changed call to pl_rcv_open_po_lr.create_putaway_task
--                         from
--                            pl_rcv_open_po_lr.create_putaway_task
--                                 (l_r_item_info_table,
--                                  l_r_pallet_table);
--                         to
--                            pl_rcv_open_po_lr.create_putaway_task
--                                 (i_r_syspars         => l_r_syspars,
--                                  i_r_item_info_table => l_r_item_info_table,
--                                  io_r_pallet_table   => l_r_pallet_table);
--
--                      Modified "pl_rcv_open_po_ml.sql"
--                         Created procedure "direct_ml_plts_to_induct_loc"
--                         It is called by procedure
--                         "pl_rcv_open_po_lr.sql.create_putaway_task" to
--                         send the pallets to the miniloader induction location.
--                         The pallets to send have been flagged in package
--                         package "pl_rcv_open_po_pallet_list.sql" when
--                         building the pallet list.
--
---------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Type Declarations
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Constants
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Procedure:
--    direct_to_induction_location
--
-- Description:
--    This procedure directs pallets to the mini-loader induction location.
---------------------------------------------------------------------------
PROCEDURE direct_to_induction_location
     (i_r_syspars        IN     pl_rcv_open_po_types.t_r_putaway_syspars,
      i_r_item_info      IN     pl_rcv_open_po_types.t_r_item_info,
      io_r_pallet_table  IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
      io_pallet_index    IN OUT PLS_INTEGER,
      o_status           IN OUT PLS_INTEGER);


---------------------------------------------------------------------------
-- Procedure:
--    direct_ml_plts_to_induct_loc
--
-- Description:
--    This procedure directs the pallets in the pallet list that are
--    flagged to go to the miniloader induction location.
--    It was created for live receiving.
--
--    It calls procedure "direct_to_induction_location" to do the work.
--    "direct_ml_plts_to_induct_loc" and "direct_to_induction_location"
--    are different in that "direct_to_induction_location" is only called
--    for an item that has pallets going to the induction location.
--    "direct_to_induction_location" is called for the entire pallet list
--    and calls "direct_to_induction_location" when it encounters a pallet
--    in the pallet list that is flagged to go to the induction location.
--
---------------------------------------------------------------------------
PROCEDURE direct_ml_plts_to_induct_loc
     (i_r_syspars          IN     pl_rcv_open_po_types.t_r_putaway_syspars,
      i_r_item_info_table  IN     pl_rcv_open_po_types.t_r_item_info_table,
      io_r_pallet_table    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
      o_status             IN OUT PLS_INTEGER);

END pl_rcv_open_po_ml;  -- end package specification
/

SHOW ERRORS



--------------------------------------------------------------------------
-- Package Body
--------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY swms.pl_rcv_open_po_ml
AS

-- sccs_id=@(#) src/schema/plsql/pl_rcv_open_po_ml.sql, swms, swms.9, 11.2 12/17/09 1.6

---------------------------------------------------------------------------
-- Package Name:
--    pl_rcv_open_po_ml
--
-- Description:
--    This package directs mini-loader items to the induction location.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/20/06 prpbcb   Oracle 8 rs239b swms9 DN 12048
--                      Created.
--                      
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := 'pl_rcv_open_po_ml';  -- Package name.
                                             --  Used in error messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- End Private Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    direct_to_induction_location
--
-- Description:
--    This procedure directs the pallets to the induction location.
--    
-- Parameters:
--    i_r_syspars          - Syspars
--    i_r_item_info        - Record of current item. 
--    io_r_pallet_table    - Table of pallet records to find slots for.
--    io_pallet_index      - The index of the pallet to process.
--                           This will be incremented by the number of pallets
--                           directed to the induction location.
--    o_status             - Status of directing the pallets to the induction
--                           location for the item.
--                           The value will be one of the following:
--                             - ct_no_pallets_left - All the pallets have been
--                                                    processed.
--                             - ct_new_item        - The next pallet to process
--                                                    is for a different item.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_pallets_to_slots
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/20/06 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE direct_to_induction_location
     (i_r_syspars        IN     pl_rcv_open_po_types.t_r_putaway_syspars,
      i_r_item_info      IN     pl_rcv_open_po_types.t_r_item_info,
      io_r_pallet_table  IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
      io_pallet_index    IN OUT PLS_INTEGER,
      o_status           IN OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61) := gl_pkg_name ||
                                       '.direct_to_induction_location';

   l_induction_loc      loc.logi_loc%TYPE; -- The induction location.  Assigned
                                           -- based on the UOM.

   l_previous_prod_id   pm.prod_id%TYPE;   -- The first item processed.  Used
                                           -- to check when the next pallet is
                                           -- for a different item or uom.

   l_previous_cust_pref_vendor  pm.cust_pref_vendor%TYPE;  -- The first CPV
                                           -- processed.  Used to check when
                                           -- the next pallet is for a
                                           -- different item or uom.

   l_previous_uom  erd.uom%TYPE;   -- The first uom processed.  Used to check
                                   -- when the next pallet is for a different
                                   -- item or uom.

   l_previous_partial_pallet_flag  VARCHAR2(1); -- The first value.  Used to
                                           -- check when the next pallet is for
                                           -- a different item or uom.

   l_num_pallets            PLS_INTEGER;  -- Number of pallets sent to the
                                          -- induction location.
   l_original_pallet_index  PLS_INTEGER;  -- Used to save the initial value of
                                          -- io_pallet_index.  It is used in 
                                          -- an aplog message.
BEGIN
   --
   -- Initialization
   -- 
   l_previous_prod_id := io_r_pallet_table(io_pallet_index).prod_id;
   l_previous_cust_pref_vendor :=
                        io_r_pallet_table(io_pallet_index).cust_pref_vendor;
   l_previous_uom := io_r_pallet_table(io_pallet_index).uom;
   l_previous_partial_pallet_flag :=
                        io_r_pallet_table(io_pallet_index).partial_pallet_flag;
   l_original_pallet_index := io_pallet_index;
   l_num_pallets := 0;
   o_status := pl_rcv_open_po_types.ct_same_item;

   --
   -- Validate the miniloader information.
   --

   --
    -- Assign the location for the inventory record.
   --
   IF (io_r_pallet_table(io_pallet_index).uom = 1) THEN
      --
      -- Directing splits to the induction location.
      --
      l_induction_loc := i_r_item_info.split_induction_loc;
   ELSE
      --
      -- Directing cases to the induction location.
      --
      l_induction_loc := i_r_item_info.case_induction_loc;
   END IF;

   --
   -- Direct the pallets to the induction location.
   --
   WHILE (o_status = pl_rcv_open_po_types.ct_same_item) LOOP

      io_r_pallet_table(io_pallet_index).dest_loc := l_induction_loc;

      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
       'LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
       || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
       || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
       || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
       || '  Type[' || io_r_pallet_table(io_pallet_index).erm_type || ']'
       || '  Destination loc[' || io_r_pallet_table(io_pallet_index).dest_loc
       || '  UOM[' || TO_CHAR(io_r_pallet_table(io_pallet_index).uom) || ']'
       || ']  Direct pallet to induction location.',
       NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      pl_rcv_open_po_find_slot.insert_records
                                       (i_r_item_info,
                                        io_r_pallet_table(io_pallet_index));

      --
      -- See if the last pallet was processed.
      --
      IF (io_pallet_index = io_r_pallet_table.LAST) THEN
         o_status := pl_rcv_open_po_types.ct_no_pallets_left;
      ELSE
         --
         -- Advance to the next pallet.
         --
         io_pallet_index := io_r_pallet_table.NEXT(io_pallet_index);

         --
         -- If the next pallet to process is for a different item or uom
         -- then the processing is done for the current item.
         -- If the next pallet is going to main warehouse reserve then the
         -- processing is done.
         --
         IF (   l_previous_prod_id != io_r_pallet_table(io_pallet_index).prod_id
             OR l_previous_cust_pref_vendor !=
                    io_r_pallet_table(io_pallet_index).cust_pref_vendor
             OR l_previous_uom !=
                    io_r_pallet_table(io_pallet_index).uom
             OR l_previous_partial_pallet_flag !=
                    io_r_pallet_table(io_pallet_index).partial_pallet_flag
             OR io_r_pallet_table(io_pallet_index).miniload_reserve = TRUE) THEN
            --
            -- The next pallet is for a different item or uom or is going to
            -- the main warehouse reserve.
            --
            o_status := pl_rcv_open_po_types.ct_new_item;
         ELSE
            --
            -- The next pallet is for the same item and uom.
            --
            NULL;
         END IF;
      END IF;
   END LOOP;

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
       || 'LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
       || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
       || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
       || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                    l_object_name || ': ' || SQLERRM);
END direct_to_induction_location;


---------------------------------------------------------------------------
-- Procedure:
--    direct_ml_plts_to_induct_loc
--
-- Description:
--    This procedure directs the pallets in the pallet list that are
--    flagged to go to the miniloader induction location.
--    It was created for live receiving.
--
--    It calls procedure "direct_to_induction_location" to do the work.
--    "direct_ml_plts_to_induct_loc" and "direct_to_induction_location"
--    are different in that "direct_to_induction_location" is only called
--    for an item that has pallets going to the induction location.
--    "direct_to_induction_location" is called for the entire pallet list
--    and calls "direct_to_induction_location" when it encounters a pallet
--    in the pallet list that is flagged to go to the induction location.
--
-- Parameters:
--    i_r_syspars          - Syspars
--    i_r_item_info        - Record of current item. 
--    io_r_pallet_table    - Table of pallet records to find slots for.
--    io_pallet_index      - The index of the pallet to process.
--                           This will be incremented by the number of pallets
--                           directed to the induction location.
--    o_status             - Status of directing the pallets to the induction
--                           location.
--                           The resulting value value should be:
--                             - ct_no_pallets_left - All the pallets have been
--                                                    processed.
--                           since we are looking at all pallets in the list.    
--                            
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - pl_rcv_open_po_lr.sql.create_putaway_tasks
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/17/17 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE direct_ml_plts_to_induct_loc
     (i_r_syspars          IN     pl_rcv_open_po_types.t_r_putaway_syspars,
      i_r_item_info_table  IN     pl_rcv_open_po_types.t_r_item_info_table,
      io_r_pallet_table    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
      o_status             IN OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61) := gl_pkg_name ||
                                       '.direct_ml_plts_to_induct_loc';

   l_done_bln      BOOLEAN;      -- Flag when done processing
   l_pallet_index  PLS_INTEGER;
   l_status        PLS_INTEGER;
BEGIN
   --
   -- For pallets going to the miniloader induction location use the regular
   -- logic.  They will be assigned to the induction location and inventory
   -- created.  There will be no "LR" logic.
   --
   l_pallet_index := io_r_pallet_table.FIRST;
   l_done_bln     := FALSE;

   WHILE (l_pallet_index <= io_r_pallet_table.LAST AND l_done_bln = FALSE)
   LOOP
      IF (io_r_pallet_table(l_pallet_index).direct_to_ml_induction_loc_bln = TRUE)
      THEN
         DBMS_OUTPUT.PUT_LINE('DEBUG ' || l_object_name || ' In loop sending to ML induction location  LP['
             || io_r_pallet_table(l_pallet_index).pallet_id || ']');

         --
         -- Log a message to track whats happening.
         --
         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
              'Item['    || io_r_pallet_table(l_pallet_index).prod_id          || ']'
           || '  CPV['   || io_r_pallet_table(l_pallet_index).cust_pref_vendor || ']'
           || '  LP['    || io_r_pallet_table(l_pallet_index).pallet_id        || ']'
           || '  PO/SN[' || io_r_pallet_table(l_pallet_index).erm_id           || ']'
           || '  The LP is flagged to go to the miniloader induction location.  Call procedure'
           || ' "direct_to_induction_location" to send it there.'
           || '  "direct_to_induction_location" will also send to the induction location'
           || ' any subsequent pallets of the item that are flagged to go to the miniloader.',
              NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

         --
         -- Note that pl_rcv_open_po_ml.direct_to_induction_location will
         -- process multiple pallets of the same item thus l_pallet_index
         -- gets changed.
         --
         direct_to_induction_location
                     (i_r_syspars,
                      i_r_item_info_table(io_r_pallet_table(l_pallet_index).item_index),
                      io_r_pallet_table,
                      l_pallet_index,
                      l_status);

         IF (l_status = pl_rcv_open_po_types.ct_no_pallets_left) THEN
            l_done_bln := TRUE;
         END IF;
      ELSE
         l_pallet_index := io_r_pallet_table.NEXT(l_pallet_index);  
      END IF;
   END LOOP;

   o_status := l_status;

EXCEPTION
   WHEN OTHERS THEN
       --
       -- Got some kind of error.  Log a somewhat coherent messase then raise an exception.
       --
      l_message := l_object_name || '(i_r_syspars,i_r_item_info_table,io_r_pallet_table,o_status)'
        || '  i_r_item_info_table.COUNT[' || TO_CHAR(i_r_item_info_table.COUNT)        || ']'
        || '  io_r_pallet_table.COUNT['   || TO_CHAR(io_r_pallet_table.COUNT)          || ']'
        || '  PO/SN['                     || io_r_pallet_table(1).erm_id               || ']';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                    l_object_name || ': ' || SQLERRM);
END direct_ml_plts_to_induct_loc;

END pl_rcv_open_po_ml;  -- end package body
/


SHOW ERRORS

