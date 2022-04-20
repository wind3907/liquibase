CREATE OR REPLACE PACKAGE PL_RCV_OPEN_PO_MATRIX AS
------------------------------------------------------------------------------------------
-- Package
--   PL_RCV_OPEN_PO_MATRIX
--
-- Description
--   This package contains all the common procedures and functions required for the receiving
--   open po for matrix
--
-- Parameters
--
--  Input:
--
--
--  Output:
--
--
-- Modification History
--
--   Date           Designer         Comments
--  -----------    ---------------  ---------------------------------------------------------
--  07-AUG-2014     sred5131        Initial Version
--  01-JAN-2018     mpha8134        Jira card OPCOF-289: Always set putawaylst.dest_loc to the matrix 
--                                  induction location and create inventory pallets
--                                  directed to the miniloader when the PO is opened
--                                  regardless if Live Receiving is active. We don't
--                                  want the pallets to "LR".
--                      
--                                  Modified "pl_rcv_open_po_types.sql"
--                                    Added field "direct_to_mx_induction_loc_bln" to the pallet RECORD.
--                                    The build pallet processing in "pl_rcv_open_po_pallet_list.sql"
--                                    chagned to set this to TRUE when the pallet is going to the
--                                    matrix induction location.
--
--                                  Modified "pl_rcv_open_po_list.sql"
--                                    Changed procedure "build_pallet_list_from_po" to
--                                    populate "direct_to_mx_induction_loc_bln" in the
--                                    pallet RECORD.
--
--                                  Modified "pl_rcv_open_po_lr.sql"
--                                    Changed procedure "create_putaway_task to call
--                                    "pl_rcv_open_po_ml.direct_mx_plts_to_induct_loc"
--
--                                  Modified "pl_rcv_open_po_matrix.sql"
--                                    Created procedure "direct_mx_plts_to_induct_loc"
--                                    It is called by procedure
--                                    "pl_rcv_open_po_lr.sql.create_putaway_task" to
--                                    send the pallets to the matrix induction location.
--                                    The pallets to send have been flagged in package
--                                    package "pl_rcv_open_po_pallet_list.sql" when
--                                    building the pallet list.
---------------------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    direct_to_induction_location
--
-- 
--
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/07/14 sred5131 Created.
--
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
-- Descripition:
--    This procedure directs the pallets in the pallet list that are
--    flagged to go to the matrix induction location.
--    It was created for live receiving.
--
--    It called procedure "direct_to_induction_location" to do the work.
--    "direct_mx_plts_to_induct_loc" and "direct_to_induction_location"
--    are different in that "direct_to_induction_location" is only called
--    for an item that has pallets going to the induction location.
--    "direct_mx_plts_to_induct_loc" is called for the entire pallet list
--    and calls "direct_to_induction_location" when it encounters a pallet
--    in the pallet list that is flagged to go to the induction location.
---------------------------------------------------------------------------
PROCEDURE direct_mx_plts_to_induct_loc
      (i_r_syspars          IN     pl_rcv_open_po_types.t_r_putaway_syspars,
       i_r_item_info_table  IN     pl_rcv_open_po_types.t_r_item_info_table,
       io_r_pallet_table    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
       o_status             IN OUT PLS_INTEGER);


---------------------------------------------------------------------------
-- Procedure:
--    matrix_qty
--
-- 
--
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/07/14 sred5131 Created.
--
---------------------------------------------------------------------------
Function matrix_qty(
    i_item_number        In Varchar2,
    i_cpv                in Varchar2
     )
  Return Number;


END PL_RCV_OPEN_PO_MATRIX;
/


CREATE OR REPLACE PACKAGE BODY PL_RCV_OPEN_PO_MATRIX AS
------------------------------------------------------------------------------------------
  -- Package
  --   PL_RCV_OPEN_PO_MATRIX
  --
  -- Description
  --   This package contains all the common procedures and functions required for the receiving
  --   open po for matrix
  --
  -- Parameters
  --
  --  Input:
  --
  --
  --  Output:
  --
  --
  -- Modification History
  --
  --   Date           Designer         Comments
  --  -----------    ---------------  ---------------------------------------------------------
  --  07-AUG-2014     sred5131         Initial Version
-----------------------------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := 'pl_rcv_open_po_matrix';  -- Package name.
                                             --  Used in error messages.

Gl_E_Parameter_Null  Exception;  -- A required parameter to a procedure or
                                 -- function is null.
---------------------------------------------------------------------------
-- Procedure:
--    direct_to_induction_location
--
-- 
--
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/07/14 sred5131 Created.
--
---------------------------------------------------------------------------
PROCEDURE direct_to_induction_location
     (i_r_syspars        In     pl_rcv_open_po_types.t_r_putaway_syspars,
      i_r_item_info      In     pl_rcv_open_po_types.t_r_item_info,
      io_r_pallet_table  In Out Nocopy pl_rcv_open_po_types.t_r_pallet_table,
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
   l_qty_to_mx              pls_integer;
   Item_Not_Found Exception;

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


   --l_item_index := io_r_pallet_table(l_pallet_index).item_index;
  --l_item := pl_rcv_open_po_types.t_r_item_info_table;

   --
    -- Assign the location for the inventory record.
   --
   IF (io_r_pallet_table(io_pallet_index).uom = 0) THEN

      -- Directing cases to the induction location.
      --
      L_Induction_Loc := I_R_Item_Info.Case_Induction_Loc;
   End If;


   --
   -- Direct the pallets to the induction location.
   --
   WHILE (o_status = pl_rcv_open_po_types.ct_same_item) LOOP

      io_r_pallet_table(io_pallet_index).dest_loc := 'LX1111';--l_induction_loc;

      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
       'LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
       || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
       || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
       || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
       || '  Type[' || io_r_pallet_table(io_pallet_index).erm_type || ']'
       || '  Destination loc[' || io_r_pallet_table(io_pallet_index).dest_loc
       || '  UOM[' || To_Char(Io_R_Pallet_Table(Io_Pallet_Index).Uom) || ']'
       || ']  Direct pallet to induction location.',
       Null, Null);

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
         io_pallet_index := io_r_pallet_table.Next(io_pallet_index);

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
           --  OR io_r_pallet_table(io_pallet_index).miniload_reserve = TRUE) THEN
		   OR io_r_pallet_table(io_pallet_index).matrix_reserve = TRUE) THEN      
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
                     SQLCODE, SQLERRM);
      Raise_Application_Error(Pl_Exc.Ct_Database_Error,
                                    L_Object_Name || ': ' || Sqlerrm);
    
END direct_to_induction_location;


---------------------------------------------------------------------------
-- Procedure:
--    direct_ml_plts_to_induct_loc
--
-- Descripition:
--    This procedure directs the pallets in the pallet list that are
--    flagged to go to the matrix induction location.
--    It was created for live receiving.
--
--    It called procedure "direct_to_induction_location" to do the work.
--    "direct_mx_plts_to_induct_loc" and "direct_to_induction_location"
--    are different in that "direct_to_induction_location" is only called
--    for an item that has pallets going to the induction location.
--    "direct_mx_plts_to_induct_loc" is called for the entire pallet list
--    and calls "direct_to_induction_location" when it encounters a pallet
--    in the pallet list that is flagged to go to the induction location.
-- Parameters:
--    i_r_syspars           - Syspars
--    i_r_item_info         - Record of current item.
--    io_r_pallet_table     - Table of pallet records to find slots for.
--    io_pallet_index       - The index of the pallet to process.
--                            This will be incremented by the number of pallets
--                            directed to the induction location.
--    o_status              - Status of directing the pallets to the induction
--                            location.
--                            The resulting value shsould be:
--                              - ct_no_pallets_left - All the pallets have been 
--                                                     processed.
--                            since we are looking at all pallets in the list.
--
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--     - pl_rcv_open_po_lr.sql.create_putaway_tasks
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/25/18 mpha8134 Created
---------------------------------------------------------------------------
PROCEDURE direct_mx_plts_to_induct_loc
      (i_r_syspars          IN     pl_rcv_open_po_types.t_r_putaway_syspars,
       i_r_item_info_table  IN     pl_rcv_open_po_types.t_r_item_info_table,
       io_r_pallet_table    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
       o_status             IN OUT PLS_INTEGER)
IS
    l_message       VARCHAR2(256);  -- Message buffer
    l_object_name   VARCHAR(61) := gl_pkg_name ||
                                        '.direct_mx_plts_to_induct_loc';
    l_done_bln      BOOLEAN;  -- Flag when done processing
    l_pallet_index  PLS_INTEGER;
    l_status        PLS_INTEGER;
BEGIN
    --
    -- For pallets going to the matrix induction location use the regular
    -- logic. They will be assigned to the induction location and inventory
    -- created. There will be no "LR" logic.
    --

    l_pallet_index := io_r_pallet_table.FIRST;
    l_done_bln := FALSE;

    WHILE(l_pallet_index <= io_r_pallet_table.LAST AND l_done_bln = FALSE)
    LOOP
        IF (io_r_pallet_table(l_pallet_index).direct_to_mx_induction_loc_bln = TRUE)
        THEN
            DBMS_OUTPUT.PUT_LINE('DEBUG ' || l_object_name || ' In loop sending to MX induction location LP['
                || io_r_pallet_table(l_pallet_index).pallet_id || ']');

            --
            -- Log a message to track whats happening.
            --
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                  'Item['    || io_r_pallet_table(l_pallet_index).prod_id          || ']'
                || '  CPV['   || io_r_pallet_table(l_pallet_index).cust_pref_vendor || ']'
                || '  LP['    || io_r_pallet_table(l_pallet_index).pallet_id        || ']'
                || '  PO/SN[' || io_r_pallet_table(l_pallet_index).erm_id           || ']'
                || '  The LP is flagged to go to the matrix induction location.  Call procedure'
                || ' "direct_to_induction_location" to send it there.'
                || '  "direct_to_induction_location" will also send to the induction location'
                || ' any subsequent pallets of the item that are flagged to go to the matrix.',
                    NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

            --
            -- Note that pl_rcv_open_po_matrix.direct_to_induction_location will
            -- process multiple pallets of the same item thus l_pallet_index
            -- gets changed.
            -- 
            direct_to_induction_location(
                i_r_syspars,
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
        -- Got some kind of error. Log a somewhat coherent message then raise an exception.
        --
        l_message := l_object_name || '(i_r_syspars,i_r_item_info_table,io_r_pallet_table,o_status)'
            || '  i_r_item_info_table.COUNT[' || TO_CHAR(i_r_item_info_table.COUNT)        || ']'
            || '  io_r_pallet_table.COUNT['   || TO_CHAR(io_r_pallet_table.COUNT)          || ']'
            || '  PO/SN['                     || io_r_pallet_table(1).erm_id               || ']';
            
        pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
            SQLCODE,
            SQLERRM,
            pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
            
        RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
    
END direct_mx_plts_to_induct_loc;
  
---------------------------------------------------------------------------
-- Procedure:
--    matrix_qty
--
-- 
--
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/07/14 sred5131 Created.
--
---------------------------------------------------------------------------

Function matrix_qty(
    i_item_number        In Varchar2,
    i_cpv                in Varchar2
     )
  Return Number
Is
l_qty Number;

    Cursor C1 Is
   Select Nvl(Sum(Decode(Inv.Inv_Uom,1, Inv.Qoh, Inv.Qoh/Pm.Spc) +
        decode(inv.inv_uom,1, inv.qty_planned, inv.qty_planned/pm.spc)),0) qty
        FROM inv inv, pm pm
       Where Inv.Prod_Id          = I_Item_Number
         And Inv.Cust_Pref_Vendor = I_Cpv
         And Inv.Status           = 'AVL'
         AND inv.prod_id = pm.prod_id;

Begin
    Open C1;
   Fetch C1 Into L_Qty;

   If C1%Notfound Then
      RAISE NO_DATA_FOUND;
   end if;
   close c1;

RETURN L_Qty;

EXCEPTION
When NO_DATA_FOUND Then
   raise_application_error(-20001,'An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

end Matrix_Qty;


END PL_RCV_OPEN_PO_MATRIX;
/
