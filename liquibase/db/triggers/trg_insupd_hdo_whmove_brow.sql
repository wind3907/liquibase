
CREATE OR REPLACE TRIGGER swms.trg_insupd_hdo_whmove_brow
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_hdo_whmove_brow.sql, swms, swms.9, 10.1.1 7/31/08 1.1
--
-- Table:
--    SWMS.HDO
--
-- Description:
--    This trigger "flips" the location to the temporary
--    new location, when necessary, when processing messages
--    sent from the miniloader during a warehouse move.
--
--    During a warehouse move product will be inducted into the miniloader.
--    The miniloader will have the true locations.  SWMS will have the
--    temporary location.  For message types InventoryPlannedMove and
--    InventoryArrival, which flow from the miniloader to SWMS, the
--    SOURCE_LOC, PLANNED_LOC and the DEST_LOC will be changed to the
--    temporary new warehouse location during insert if syspar
--    ENABLE_WAREHOUSE_MOVE is Y.
--
--    *********************************************************
--    **** This trigger will be enabled only when doing
--    **** a warehouse move into a miniloader.
--    *********************************************************
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/16/08 prpbcb   DN 12401
--                      Project: 562935-Warehouse Move MiniLoad Enhancement
--                      Created.
--                       
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON swms.hdo
FOR EACH ROW
DECLARE
   l_enable_warehouse_move   sys_config.config_flag_val%TYPE;
   l_message_type            miniload_message.message_type%TYPE;
   l_field_start             PLS_INTEGER;

   CURSOR c_warehouse_move_syspar IS
      SELECT config_flag_val
        FROM swms.sys_config
       WHERE config_flag_name = 'ENABLE_WAREHOUSE_MOVE';

   --
   -- Local function
   --
   FUNCTION flip_location(i_ml_data      miniload_message.ml_data%TYPE,
                          i_field_start  PLS_INTEGER)
   RETURN VARCHAR2
   IS
      l_ml_data  miniload_message.ml_data%TYPE;
      l_loc      miniload_message.source_loc%TYPE;
   BEGIN
      l_ml_data := i_ml_data;
      l_loc := TRIM(SUBSTR(l_ml_data, i_field_start,
                           pl_miniload_processing.ct_location_size));

      IF (l_loc IS NOT NULL) THEN
         l_loc := pl_wh_move.get_temp_new_wh_loc(l_loc);

         l_ml_data := SUBSTR(l_ml_data, 1, i_field_start - 1)
                 || RPAD(l_loc, pl_miniload_processing.ct_location_size, ' ')
                 || SUBSTR(l_ml_data, l_field_start + pl_miniload_processing.ct_location_size);
      END IF;

      RETURN(l_ml_data);
   END flip_location;

BEGIN
   IF (INSERTING OR UPDATING) THEN
      OPEN c_warehouse_move_syspar;
      FETCH c_warehouse_move_syspar INTO l_enable_warehouse_move;
      IF (c_warehouse_move_syspar%NOTFOUND) THEN
         l_enable_warehouse_move := 'N';
      END IF;
      CLOSE c_warehouse_move_syspar;

      IF (l_enable_warehouse_move = 'Y') THEN
         l_message_type :=
           TRIM(SUBSTR(:NEW.data, 1, pl_miniload_processing.ct_msg_type_size));

         IF (l_message_type = pl_miniload_processing.ct_inv_plan_mov) THEN
            --
            -- Planned Move message
            --
            --
            -- Source location
            --
            l_field_start := 1
                 + pl_miniload_processing.ct_msg_type_size
                 + pl_miniload_processing.ct_label_size;
            :NEW.data := flip_location(:NEW.data, l_field_start);

            --
            -- Planned location
            --
            l_field_start := 1
                 + pl_miniload_processing.ct_msg_type_size
                 + pl_miniload_processing.ct_label_size
                 + pl_miniload_processing.ct_location_size
                 + pl_miniload_processing.ct_sku_size
                 + pl_miniload_processing.ct_qty_size
                 + pl_miniload_processing.ct_date_size;
            :NEW.data := flip_location(:NEW.data, l_field_start);
         ELSIF (l_message_type = pl_miniload_processing.ct_inv_arr) THEN
            --
            --  Inventory Arrival message
            --
            --
            -- Planned location
            --
            l_field_start := 1
                 + pl_miniload_processing.ct_msg_type_size
                 + pl_miniload_processing.ct_label_size
                 + pl_miniload_processing.ct_location_size
                 + pl_miniload_processing.ct_sku_size
                 + pl_miniload_processing.ct_qty_size
                 + pl_miniload_processing.ct_date_size;
            :NEW.data := flip_location(:NEW.data, l_field_start);

            --
            -- Destination location
            --
            l_field_start := 1
                 + pl_miniload_processing.ct_msg_type_size
                 + pl_miniload_processing.ct_label_size;
            :NEW.data := flip_location(:NEW.data, l_field_start);

         END IF;
      END IF;  -- end IF (l_enable_warehouse_move = 'Y') THEN
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg('WARN', 'trg_insupd_hdo_whmove_brow',
           'WHEN-OTHERS catch all',
           SQLCODE, SQLERRM, 'INVENTORY', 'trg_insupd_hdo_whmove_brow');

      RAISE_APPLICATION_ERROR(-20001, 'trg_insupd_hdo_whmove_brow: '
           || SQLERRM);
END trg_insupd_hdo_whmove_brow;
/

