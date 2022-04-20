/* Formatted on 2015/10/14 15:05 (Formatter Plus v4.8.8) */
CREATE OR REPLACE TRIGGER swms.trg_insupd_loc_brow
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_loc_brow.sql, swms, swms.9, 11.2 3/26/10 1.5
--
-- Table:
--    LOC(Location table)
--
-- Description:
--    This trigger calculates the LOC.AVAILABLE_HEIGHT column and the
--    LOC.AVAILABLE height columns whenever there is a change in the
--    SLOT HEIGHT,PALLET TYPE,SLOT TYPE AND WIDTH POSITIONS columns in
--    the location table or a new location is added.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/18/02 acppxp   DN# 10994  Created.
--                      For RDC non-dependent changes.
--    10/16/02 acppxp   DN# 10994  Added assignment to upd_date and
--                      upd_user when updating.
--                      For RDC non-dependent changes.
--    10/21/02 acppxp   Allowed negative values in Available height
--                      field.
--    03/03/03 acpppp   DN# 11994 Added following checks:
--                      1. The true_slot_height will be greater than
--                         liftoff_height and slot_height.
--                      2. Only Liftoff_height cannot be updated.
--                      3. True_slot_height minus liftoff_height should
--                         be equal to slot_height.
--    07/29/03 prppxx   DN# 11331 Update put/pick path in accordance with
--            the changed put/pick slot/aisle/level.
--    09/20/06 prpbcb   DN 12161
--                      Project:
--                        237626-Do not compute heights for miniload locations
--                      Do not calculate the available height and occupied
--                      height for miniloader locations.  Some errors are
--                      occurring with the height calculation for miniload
--                      locations and since there is no need to keep track
--                      of the these heights they will be set as follows:
--                         available_height := slot_height
--                         occupied_height  := 0
--                      Miniload locations have a slot type of MLS.
--
--                      Clear out the uom and and rank when inserting or
--                      updating and the prod_id is null.  There is code
--                      that expects the rank to be null for reserve and
--                      floating locations so the rank needs to be cleared
--                      and may as well clear the uom too.
--    03/25/10 prplhj   D#12561. Comment out the "Only liftoff height is
--            updated" if statement.
--    12/06/11 jluo5859    CR29306 Added the statement(s) that if a pick slot
--            is updated or inserted, we should make sure its
--            status is always defaulted to AVL if there is an
--            item slotted.
--    10/16/15 avij3336 6000009529 - check for outside location and skip available height calculation
--    01/05/16 ayad5195 The available_height will always be set to the slot_height and occupied_height will always be 0
--                      for Symbotic locations MXF, MXC, MXI, MXT and MXS (Same as Miniload locations MLS) 
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE
   ON swms.loc
   FOR EACH ROW
DECLARE
   l_object_name              VARCHAR2 (30)          := 'trg_insupd_loc_brow';
   l_msg_text                 VARCHAR2 (500);
   l_skid_height              pallet_type.skid_height%TYPE;
   l_deep_positions           slot_type.deep_positions%TYPE;
   --Total Occupied height in the location
   l_total_occ_height         number;
   l_total_available_height   number;
   /* 6000009529 - check for outside location and skip available height calculation*/ 
   l_out_loc              number(2);
   
   CURSOR c_slot_info (cp_slot_type slot_type.slot_type%TYPE)
   IS
      SELECT NVL (st.deep_positions, 1)
        FROM slot_type st
       WHERE st.slot_type = cp_slot_type;

   CURSOR c_loc_ht_info (cp_loc loc.logi_loc%TYPE)
   IS
      SELECT SUM (NVL (pallet_height, 0))
        FROM inv i
       WHERE i.plogi_loc = cp_loc;
       
    CURSOR c_chk_out_loc (cp_loc loc.logi_loc%TYPE)
    IS
     SELECT count(1)
              FROM  lzone lz, ZONE z
             WHERE z.warehouse_id <> '000'
               AND z.zone_id = lz.zone_id              
               AND zone_type = 'PUT'
               AND lz.logi_loc = cp_loc;   
BEGIN
   --
   -- Determine the available height and the occupied height
   -- whenever there is a change in slot height,width positions,
   -- slot type or pallet type
   --
   l_deep_positions := 1;
   /* 6000009529 - check for outside location and skip available height calculation*/ 
   l_out_loc := 0;

   --
   -- Separate processing for miniload slots.
   -- The available_height will always be set to the slot_height.
   -- The occupied_height will always be 0.
   --
   IF (:NEW.slot_type IN ('MLS', 'MXF', 'MXC', 'MXT', 'MXI', 'MXS') )
   THEN
      IF (INSERTING OR UPDATING)
      THEN
         IF (INSERTING)
         THEN
            :NEW.slot_height := :NEW.true_slot_height - :NEW.liftoff_height;
         ELSIF (   NVL (:NEW.true_slot_height, 0) !=
                                                NVL (:OLD.true_slot_height, 0)
                OR NVL (:NEW.liftoff_height, 0) !=
                                                  NVL (:OLD.liftoff_height, 0)
               )
         THEN
            :NEW.slot_height := :NEW.true_slot_height - :NEW.liftoff_height;
         END IF;

         IF (:NEW.occupied_height != 0)
         THEN
            :NEW.occupied_height := 0;
         END IF;

         IF (:NEW.available_height != :NEW.slot_height)
         THEN
            :NEW.available_height := :NEW.slot_height;
         END IF;

         IF (NVL (:NEW.width_positions, 0) = 0)
         THEN
            :NEW.width_positions := 1;
         END IF;
      END IF;
   ELSE
      IF (   (INSERTING)
          OR (    UPDATING
              AND (   ((NVL (:OLD.slot_height, 0)) !=
                                                  (NVL (:NEW.slot_height, 0)
                                                  )
                      )
                   OR ((NVL (:OLD.true_slot_height, 0)) !=
                                             (NVL (:NEW.true_slot_height, 0)
                                             )
                      )
                   OR ((NVL (:OLD.liftoff_height, 0)) !=
                                               (NVL (:NEW.liftoff_height, 0)
                                               )
                      )
                   OR (NVL (:OLD.width_positions, 0) !=
                                                 NVL (:NEW.width_positions, 0)
                      )
                   OR (NVL (:OLD.slot_type, ' ') != NVL (:NEW.slot_type, ' ')
                      )
                   OR (NVL (:OLD.pallet_type, ' ') !=
                                                   NVL (:NEW.pallet_type, ' ')
                      )
                  )
             )
         )
      THEN
         DBMS_OUTPUT.put_line (   'Slot ht '
                               || :OLD.slot_height
                               || '--'
                               || :NEW.slot_height
                              );

         OPEN c_slot_info (:NEW.slot_type);

         FETCH c_slot_info
          INTO l_deep_positions;

         IF (c_slot_info%NOTFOUND)
         THEN
            l_msg_text :=
                  'Oracle Unable to Retrieve deep positions  
           for slot:'
               || :NEW.slot_type
               || SQLCODE
               || SQLERRM;
            pl_log.ins_msg ('WARN', l_object_name, l_msg_text, NULL, SQLERRM);
         --RAISE;.
         END IF;

         CLOSE c_slot_info;

         OPEN c_loc_ht_info (:NEW.logi_loc);

         FETCH c_loc_ht_info
          INTO l_total_occ_height;

         CLOSE c_loc_ht_info;

         IF (NVL (:NEW.width_positions, 0) = 0)
         THEN
            :NEW.width_positions := 1;
         END IF;

         --
         -- Check to ensure that the true slot height will
         -- be greater than the slot height or liftoff height
         --
         IF    NVL (:NEW.true_slot_height, 0) < NVL (:NEW.slot_height, 0)
            OR NVL (:NEW.true_slot_height, 0) < NVL (:NEW.liftoff_height, 0)
         THEN
            l_msg_text :=
                  'True slot height can not be less than '
               || 'Liftoff height or Slot height for location '
               || :NEW.logi_loc;
            raise_application_error (-20201, l_msg_text);
         END IF;

         --
         -- Check to ensure that only liftoff height can not be updated
         -- kwithout updating any or both slot height and true slot height.
         --
         IF (NVL (:NEW.true_slot_height, 0) - NVL (:NEW.liftoff_height, 0)) !=
                                                     NVL (:NEW.slot_height, 0)
         THEN
            :NEW.slot_height :=
                 NVL (:NEW.true_slot_height, 0)
                 - NVL (:NEW.liftoff_height, 0);
         END IF;
         
      
       /* 6000009529 - check for outside location and skip available height calculation */
        /* 1- outside storage location
           0- warehouse location */
          open  c_chk_out_loc(:NEW.logi_loc);
          fetch c_chk_out_loc into l_out_loc;
     --     dbms_output.put_line('out location'|| l_out_loc);
          
               
          IF l_out_loc = 0 THEN /* warehouse location */     
       
     --  dbms_output.put_line('Inside IF processing normal location');
       
         l_total_available_height :=
            (  (:NEW.slot_height * l_deep_positions * :NEW.width_positions)
             - (NVL (l_total_occ_height, 0))
            );
         -- Changed as per discussion with Kiet. The available height can
         -- go negative.
         --IF(l_total_available_height >0) THEN
         --   :new.available_height:=l_total_available_height;
         --ELSE
         --   :new.available_height:=0;
         --END IF;
         :NEW.available_height := l_total_available_height;
         :NEW.occupied_height := NVL (l_total_occ_height, 0);
                     
         
       END IF;
       
       close c_chk_out_loc;
       /* 6000009529  - check for outside location and skip available height calculation */
       
      END IF;                            -- end if inserting or height changed
   END IF;                             -- end IF (:new.slot_type = 'MLS') THEN

   -- DN# 11331 Update put/pick path
   IF INSERTING
   THEN
      :NEW.put_path :=
            LPAD (TO_CHAR (:NEW.put_aisle), 3, '0')
         || LPAD (TO_CHAR (:NEW.put_slot), 3, '0')
         || LPAD (TO_CHAR (:NEW.put_level), 3, '0');
      :NEW.pik_path :=
            LPAD (TO_CHAR (:NEW.pik_aisle), 3, '0')
         || LPAD (TO_CHAR (:NEW.pik_slot), 3, '0')
         || LPAD (TO_CHAR (:NEW.pik_level), 3, '0');
   ELSIF UPDATING
   THEN
      :NEW.upd_user := REPLACE (USER, 'OPS$');
      :NEW.upd_date := SYSDATE;

      IF    :NEW.put_aisle != :OLD.put_aisle
         OR :NEW.put_slot != :OLD.put_slot
         OR :NEW.put_level != :OLD.put_level
      THEN
         :NEW.put_path :=
               LPAD (TO_CHAR (:NEW.put_aisle), 3, '0')
            || LPAD (TO_CHAR (:NEW.put_slot), 3, '0')
            || LPAD (TO_CHAR (:NEW.put_level), 3, '0');
      END IF;

      IF    :NEW.pik_aisle != :OLD.pik_aisle
         OR :NEW.pik_slot != :OLD.pik_slot
         OR :NEW.pik_level != :OLD.pik_level
      THEN
         :NEW.pik_path :=
               LPAD (TO_CHAR (:NEW.pik_aisle), 3, '0')
            || LPAD (TO_CHAR (:NEW.pik_slot), 3, '0')
            || LPAD (TO_CHAR (:NEW.pik_level), 3, '0');
      END IF;
   END IF;

   -- If the location is not a home slot for an item then clear the rank
   -- and uom.
   IF (INSERTING OR UPDATING)
   THEN
      IF (:NEW.prod_id IS NULL)
      THEN
         :NEW.RANK := NULL;
         :NEW.uom := NULL;
      END IF;
   END IF;

   IF (INSERTING OR UPDATING)
   THEN
      IF     NVL (:NEW.perm, 'N') = 'Y'
         AND :NEW.prod_id IS NOT NULL
         AND NVL (:NEW.status, ' ') <> 'AVL'
      THEN
         :NEW.status := 'AVL';
      END IF;
   END IF;
EXCEPTION
   WHEN OTHERS
   THEN
      --raise_application_error (-20001, l_object_name || ': ' || SQLERRM);
      Pl_Text_log.ins_Msg('W','trg_insupd_loc_brow', 'Trigger trg_insupd_loc_brow failed ', SQLCODE, SQLERRM);
      
END trg_insupd_loc_brow;
/
