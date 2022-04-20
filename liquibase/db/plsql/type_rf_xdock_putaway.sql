
--
-- Fri Jan 28 08:44:30 CST 2022
--

----------------------------------------------------------------------------
-- Object for putaway data from RF
----------------------------------------------------------------------------
CREATE OR REPLACE TYPE swms.xdock_putaway_client_obj FORCE AS OBJECT
(
   equip_id                VARCHAR2(10),
   pallet_id               VARCHAR2(18),
   task_type               VARCHAR2(3),       -- Either PUT or XDK ???.  To help in the host deciding what to do.
   task_id                 VARCHAR2(10),      -- Either putawaylst.task_id or replenlst.task_id depending on the task_type.
   dest_loc                VARCHAR2(10),     -- If the task_type is PUT then the staging location.
                                              -- If the task_type is XDK then the outbound door number.
   scan_method             VARCHAR2(1)        -- User scanned/keyed the destination location.
);
/

-- Don't think a server object needed for putaway as the server only needs to return a status code.




----------------------------------------------------------------------------
-- Object for haul data from RF.  After traveling the user selected to  haul
-- a pallet.
-- On the RF the user chooses what pallet to undo.
-- The RF prompts for a drop point.
----------------------------------------------------------------------------
CREATE OR REPLACE TYPE swms.xdock_haul_client_obj FORCE AS OBJECT
(
   pallet_id           VARCHAR2(18),
   task_type           VARCHAR2(3),        -- Either PUT or XDK.  What the host sent when the pallet was picked.
   task_id             VARCHAR2(10),       -- What the host sent when the pallet was picked.
   drop_point          VARCHAR2(10),
   scan_method         VARCHAR2(1)         -- User scanned/keyed the drop point.
);
/

-- Don't think a server object needed for haul as the server only needs to return a status code.



----------------------------------------------------------------------------
-- Object for putaway undo data from RF.  User decided to backout of the putaway process
-- before traveling.
-- On the RF the user chooses what pallet to undo.
-- The RF uses the task source location as the drop point.
----------------------------------------------------------------------------
CREATE OR REPLACE TYPE swms.xdock_putaway_undo_client_obj FORCE AS OBJECT
(
   pallet_id           VARCHAR2(18),
   task_type           VARCHAR2(3),       -- Either PUT or XDK.  What the host sent when the pallet was picked.
   task_id             VARCHAR2(10),      -- What the host sent when the pallet was picked.
   drop_point          VARCHAR2(10)
);
/

-- Don't think a server object needed for the undo as the server only needs to return a status code.




GRANT EXECUTE ON swms.xdock_putaway_client_obj       TO swms_user;
GRANT EXECUTE ON swms.xdock_haul_client_obj          TO swms_user;
GRANT EXECUTE ON swms.xdock_putaway_undo_client_obj  TO swms_user;


