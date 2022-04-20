------------------------------------------------------------------------------
-- File:
--    v_replen_xdock.sql
--
-- View:
--    v_replen_xdock
--
-- Description:
--    View listing the available XDK bulk pull tasks with a door as the source location.
--    NOTE: View V_REPLEN_BULK selects the XDK tasks that have a slot location as the source location.
--
--    FYI  If the Site 2 cross dock pallet has different items then
--         replenlst.prod_id will be MULTI.
--         If the Site 2 cross dock pallet has only one item then
--         replenlst.prod_id is set to the item.
--
--   Notes about bulk pulls--type BLK or XDK
--   For an Opco:
--      - replenlst record.dest_loc is always null.
--      - replenlst.inv_dest_loc is always null.
--      - replenlst.door_no is always populated.
--
-- Used By:
--    pl_rf_replen_list.sql
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/01/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--
--                      Select replenlst:
--                         - site_from
--                         - site_to
--                         - cross_dock_type,
--                         - xdock_pallet_id
--
--    09/01/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: R47-xdock-OPCOF3663_OP_Site_2_Merge_float_ordcw_sent_from_Site_1
--
--                      Selects the 'X' cross dock pallet twice if the pallet has only 1 item on it.
--                      Does not select the 'X' cross dock pallet if the pallet has different items.
--
--    09/22/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: R47-xdock-OPCOF3611_Site_2_Bulk_pull_door_to_door_replen_pick_fails
--
--                      XDK tasks with a door for the replenlst.src_loc are not being selected.  The door
--                      will not be in the LOC table.
--                      In the "select" that selects XDK tasks:
--                         - Add outer joins to LOC, AISLE_INFO and SWMS_SUB_AREAS tables.
--                         - Select r.replen_area when r.src_loc is a door--basically if src_loc not
--                           in LOC table select r.replen_area for the area_code.
--
--    09/27/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: R47_0-xdock-OPCOF3611_Site_2_Bulk_pull_door_to_door_replen_shows_all_XDK_tasks
--
--                      Select only the XDK tasks that have a door as the source location.
--
--    10/25/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3752_Site_1_put_site_2_truck_no_stop_no_on_RF_bulk_pull_label
--
--                      Columns site_to_route_no and site_to_truck_no were added to tables FLOATS and REPLENLST.
--                      Select from replenlst:
--                         - site_to_route_no
--                         - site_to_truck_no
--
--
--    11/12/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_Xdock_day2-OPCOF-3849_Bug_Duplicate_task_on_ RF_XDK_Door_to_Door_screen
--
--                      Had places lookig for 'XDK' instead of 'DMD'.
--
--                      This view selects only door to door XDK tasks.
--                      It has UNIONS that will never select a record and conditions that will never be true.
--                      I guess at some time we should clean it up.
------------------------------------------------------------------------------
CREATE OR REPLACE FORCE VIEW SWMS.V_REPLEN_XDOCK
(
	"TASK_ID",
	"TYPE",
	"REPLEN_TYPE",
	"REPLEN_AREA",
	"STATUS",
	"PROD_ID",
	"CUST_PREF_VENDOR",
	"PALLET_ID",
	"SRC_LOC",
	"DEST_LOC",
	"UOM",
	"DEST_UOM",
	"QTY",
	"DROP_QTY",
	"ROUTE_NO",
	"TRUCK_NO",
	"DOOR_NO",
	"ORDER_ID",
	"FLOAT_NO",
	"EXP_DATE",
	"MFG_DATE",
	"DESCRIP",
	"MFG_SKU",
	"D_PIKPATH",
	"S_PIKPATH",
	"MINILOAD_STORAGE_IND",
	"AREA_CODE",
	"SRC_PIK_AISLE",
	"DEST_PIK_AISLE",
	"SRC_PUT_AISLE",
	"DEST_PUT_AISLE",
	"SRC_PUT_SLOT",
	"DEST_PUT_SLOT",
	"NAME",
	"INV_DEST_LOC",
	"ROUTE_BATCH_NO",
	"SEQ_NO",
        site_from,
        site_to,
        cross_dock_type,
        xdock_pallet_id,
        site_to_route_no,
        site_to_truck_no,
	"LAST_STOP_NO",
	"ROUTE_ACTIVE",
	"PRIORITY"
)
AS
	SELECT Repls."TASK_ID",
	       Repls."TYPE",
	       Repls."REPLEN_TYPE",
	       Repls."REPLEN_AREA",
	       Repls."STATUS",
	       Repls."PROD_ID",
	       Repls."CUST_PREF_VENDOR",
	       Repls."PALLET_ID",
	       Repls."SRC_LOC",
	       Repls."DEST_LOC",
	       Repls."UOM",
	       Repls."DEST_UOM",
	       Repls."QTY",
	       Repls."DROP_QTY",
	       Repls."ROUTE_NO",
	       Repls."TRUCK_NO",
	       Repls."DOOR_NO",
	       Repls."ORDER_ID",
	       Repls."FLOAT_NO",
	       Repls."EXP_DATE",
	       Repls."MFG_DATE",
	       Repls."DESCRIP",
	       Repls."MFG_SKU",
	       Repls."D_PIKPATH",
	       Repls."S_PIKPATH",
	       Repls."MINILOAD_STORAGE_IND",
	       Repls."AREA_CODE",
	       Repls."SRC_PIK_AISLE",
	       Repls."DEST_PIK_AISLE",
	       Repls."SRC_PUT_AISLE",
	       Repls."DEST_PUT_AISLE",
	       Repls."SRC_PUT_SLOT",
	       Repls."DEST_PUT_SLOT",
	       Repls."NAME",
	       Repls."INV_DEST_LOC",
	       Repls."ROUTE_BATCH_NO",
	       Repls."SEQ_NO",
	       repls.site_from,
	       repls.site_to,
	       repls.cross_dock_type,
	       Repls.xdock_pallet_id,
               repls.site_to_route_no,
               repls.site_to_truck_no,
	       Last_Stop.Last_Stop_No,
	       Last_Stop.Route_Active,
	       Fltp.Priority
	  FROM( SELECT R.Task_Id,
	               R.Type,
	               R.Replen_Type,
	               R.Replen_Area,
	               R.Status,
	               R.Prod_Id,
	               R.Cust_Pref_Vendor,
	               R.Pallet_Id,
	               R.Src_Loc,
	               R.Dest_Loc,
	               2 Uom,
	               Dest.Uom Dest_Uom,
	               Decode( R.Type, 'NDM', Ceil( R.Qty / P.Spc ), R.Qty )Qty,
	               Nvl( R.Drop_Qty, 0 )Drop_Qty,
	               R.Route_No,
	               R.Truck_No,
	               R.Door_No,
	               R.Order_Id,
	               R.Float_No,
	               R.Exp_Date,
	               R.Mfg_Date,
	               P.Descrip,
	               Nvl( P.Mfg_Sku, '*' ) Mfg_Sku,
	               Dest.Pik_Path         D_Pikpath,
	               Src.Pik_Path          S_Pikpath,
	               P.Miniload_Storage_Ind,
	               Sa.Area_Code,
	               Src.Pik_Aisle         Src_Pik_Aisle,
	               Dest.Put_Aisle        Dest_Pik_Aisle,
	               Src.Put_Aisle         Src_Put_Aisle,
	               Dest.Put_Aisle        Dest_Put_Aisle,
	               Src.Put_Slot          Src_Put_Slot,
	               Dest.Put_Slot         Dest_Put_Slot,
	               Ai.Name,
	               R.Inv_Dest_Loc,
	               NVL(R1.Route_Batch_No, 0 )  Route_Batch_No,
	               NVL(R1.Seq_No, 0)           Seq_No,
                       r.site_from,
                       r.site_to,
                       r.cross_dock_type,
                       r.xdock_pallet_id,
                       r.site_to_route_no,
                       r.site_to_truck_no
	        FROM Route                 R1,
	             Swms.Swms_Sub_Areas   Sa,
	             Swms.Aisle_Info       Ai,
	             Swms.Loc              Src,
	             Swms.Loc              Dest,
	             Swms.Pm               P,
	             Swms.Replenlst        R
	       WHERE
                     1=2 AND                                                       -- 11/12/2021  Brian Bent We do not want any records from this select.
                     R.Type                            = 'XDK'               AND
	             R.Status                          = 'NEW'               AND
	             R.User_Id                         IS NULL               AND
	             P.Prod_Id                         = R.Prod_Id           AND
	             P.Cust_Pref_Vendor                = R.Cust_Pref_Vendor  AND
	             Src.Logi_Loc                      = R.Src_Loc           AND
	             R.Dest_Loc                        IS NOT NULL           AND   -- XDK replenlst dest_loc is always null so this select will never select anything
	             NVL(R.Inv_Dest_Loc, R.Dest_Loc)   = Dest.Logi_Loc       AND
	             Dest.Prod_Id                      = R.Prod_Id           AND
	             R.Route_No                        = R1.Route_No (+)     AND
	             Sa.Sub_Area_Code                  = Ai.Sub_Area_Code
	      UNION ALL
	      SELECT R.Task_Id,
	             R.Type,
	             R.Replen_Type,
	             R.Replen_Area,
	             R.Status,
	             R.Prod_Id,
	             R.Cust_Pref_Vendor,
	             R.Pallet_Id,
	             R.Src_Loc,
	             R.Dest_Loc,
	             2 Uom,
	             Dest.Uom Dest_Uom,
	             DECODE(R.Type, 'XDK', CEIL(R.Qty / P.Spc ), R.Qty) Qty,
	             NVL(R.Drop_Qty, 0) Drop_Qty,
	             R.Route_No,
	             R.Truck_No,
	             R.Door_No,
	             R.Order_Id,
	             R.Float_No,
	             R.Exp_Date,
	             R.Mfg_Date,
	             P.Descrip,
	             NVL(P.Mfg_Sku, '*')       Mfg_Sku,
	             Dest.Pik_Path             D_Pikpath,
	             Src.Pik_Path              S_Pikpath,
	             P.Miniload_Storage_Ind,
	             Sa.Area_Code,
	             Src.Pik_Aisle             Src_Pik_Aisle,
	             Dest.Put_Aisle            Dest_Pik_Aisle,
	             Src.Put_Aisle             Src_Put_Aisle,
	             Dest.Put_Aisle            Dest_Put_Aisle,
	             Src.Put_Slot              Src_Put_Slot,
	             Dest.Put_Slot             Dest_Put_Slot,
	             Ai.Name,
	             R.Inv_Dest_Loc,
	             R1.Route_Batch_No,
	             R1.Seq_No,
                     r.site_from,
                     r.site_to,
                     r.cross_dock_type,
                     r.xdock_pallet_id,
                     r.site_to_route_no,
                     r.site_to_truck_no
	        FROM
	             Route                 R1,
	             Loc_Reference         Lr,
	             Swms.Swms_Sub_Areas   Sa,
	             Swms.Aisle_Info       Ai,
	             Swms.Loc              Src,
	             Swms.Loc              Dest,
	             Swms.Pm               P,
	             Swms.Replenlst        R
	       WHERE
                     1=2 AND                                                        -- 11/12/2021  Brian Bent We do not want any records from this select.
                     R.Type                         = 'XDK'               AND
	             R.Status                       = 'NEW'               AND
	             R.User_Id                      IS NULL               AND
	             P.Prod_Id                      = R.Prod_Id           AND
	             P.Cust_Pref_Vendor             = R.Cust_Pref_Vendor  AND
	             Src.Logi_Loc                   = R.Src_Loc           AND
	             R.Dest_Loc                     = Lr.Bck_Logi_Loc (+) AND
	             NVL(Lr.Plogi_Loc, R.Dest_Loc)  = Dest.Logi_Loc       AND   -- XDK replenlst dest_loc is always null so this select will never select anything
	             Dest.Prod_Id                   = R.Prod_Id           AND
	             R.Route_No                     = R1.Route_No (+)     AND
	             Sa.Sub_Area_Code               = Ai.Sub_Area_Code
	      UNION ALL
	      SELECT R.Task_Id,
	             R.Type,
	             R.Replen_Type,
	             R.Replen_Area,
	             R.Status,
	             R.Prod_Id,
	             R.Cust_Pref_Vendor,
	             R.Pallet_Id,
	             R.Src_Loc,
	             R.Dest_Loc,
	             2 Uom,
	             2,
	             Qty,
	             0 Drop_Qty,
	             R.Route_No,
	             R.Truck_No,
	             R.Door_No,
	             R.Order_Id,
	             R.Float_No,
	             R.Exp_Date,
	             R.Mfg_Date,
	             P.Descrip,
	             NVL(P.Mfg_Sku, '*')   Mfg_Sku,
	             0,
	             Src.Pik_Path,
	             P.Miniload_Storage_Ind,
	             Sa.Area_Code,
	             Src.Pik_Aisle,
	             0                   dest_pik_aisle,
	             Src.Put_Aisle,
	             0                   dest_put_aisle,
	             Src.Put_Slot,
	             0                   dest_put_slot,
	             Ai.Name,
	             R.Inv_Dest_Loc,
	             R1.Route_Batch_No,
	             R1.Seq_No,
                     r.site_from,
                     r.site_to,
                     r.cross_dock_type,
                     r.xdock_pallet_id,
                     r.site_to_route_no,
                     r.site_to_truck_no
	        FROM
                     Route                 R1,
	             Swms.Swms_Sub_Areas   Sa,
	             Swms.Aisle_Info       Ai,
	             Swms.Loc              Src,
	             Swms.Pm               P,
	             Swms.Replenlst        R
	       WHERE
                     1=2 AND                                            -- 11/12/2021  Brian Bent We do not want any records from this select.
                     R.Type               = 'XDK'                AND
	             R.Dest_Loc           IS NULL                AND
	             R.Status             = 'NEW'                AND
	             R.User_Id            IS NULL                AND
	             P.Prod_Id            = R.Prod_Id            AND
	             P.Cust_Pref_Vendor   = R.Cust_Pref_Vendor   AND
	             Src.Logi_Loc         = R.Src_Loc            AND     -- XDK replenlst src_loc could be a door and if so this select will not select it
	             R.Route_No           = R1.Route_No (+)      AND
	             Ai.Pick_Aisle        = Src.Pik_Aisle        AND
	             Sa.Sub_Area_Code     = Ai.Sub_Area_Code
	      UNION ALL
	      SELECT R.Task_Id,                -- This is the select that gets the XDK tasks.
	             R.Type,
	             R.Replen_Type,
	             R.Replen_Area,
	             R.Status,
	             R.Prod_Id,
	             R.Cust_Pref_Vendor,
	             R.Pallet_Id,
	             R.Src_Loc,
	             R.Dest_Loc,
	             2 Uom,
	             2,
	             Qty,
	             0 Drop_Qty,
	             R.Route_No,
	             R.Truck_No,
	             R.Door_No,
	             R.Order_Id,
	             R.Float_No,
	             R.Exp_Date,
	             R.Mfg_Date,
	             C.Description,
	             '*' Mfg_Sku,
	             0,
	             Src.Pik_Path,
	             'N',
                     NVL(Sa.Area_Code, r.replen_area)   area_code,   -- 09/22/21  Brian Bent  NVL because the replenlst src_loc could be a door which is not in the LOC table.
	             NVL(Src.Pik_Aisle, 0) pik_aisle,
	             0                     dest_pik_aisle,
	             NVL(Src.Put_Aisle, 0) put_aisle,
	             0                     dest_put_aisle,
	             NVL(Src.Put_Slot, 0)  put_slot,
	             0                     dest_put_slot,
	             Ai.Name,
	             R.Inv_Dest_Loc,
	             R1.Route_Batch_No,
	             R1.Seq_No,
                     r.site_from,
                     r.site_to,
                     r.cross_dock_type,
                     r.xdock_pallet_id,
                     r.site_to_route_no,
                     r.site_to_truck_no
	        FROM 
                     Route                   R1,
	             Swms.Swms_Sub_Areas     Sa,
	             Swms.Aisle_Info         Ai,
	             Swms.Cross_Dock_Type    C,
	             Swms.Loc                Src,
	             Swms.Replenlst          R,
	             Swms.Ordm               Om,
                     swms.pm                 pm         -- 09/10/21 Brian Bent Not sure we will use anything from PM.
	       WHERE
                     R.Type                   = 'XDK'               AND
	             R.Dest_Loc               IS NULL               AND
	             R.Status                 = 'NEW'               AND
	             R.User_Id                IS NULL               AND
	             Src.Logi_Loc        (+)  = R.Src_Loc           AND     -- Outer join because XDK replenlst src_loc could be a door
	             R.Route_No               = R1.Route_No         AND
	             Ai.Pick_Aisle       (+)  = Src.Pik_Aisle       AND     -- Outer join because XDK replenlst src_loc could be a door
	             Sa.Sub_Area_Code    (+)  = Ai.Sub_Area_Code    AND     -- Outer join because XDK replenlst src_loc could be a door
	             R.Route_No               = Om.Route_No         AND
                     pm.prod_id          (+)  = r.prod_id           AND     -- Outer join because replenlst.prod_id will be MULTI if the XDK pallet has different items.
                     pm.cust_pref_vendor (+)  = r.cust_pref_vendor  AND
	             Om.Cross_Dock_Type       = C.Cross_Dock_Type   AND
                     src.logi_loc             IS NULL               AND     -- If null then we consider the replenlst.src_loc as a door.  We only want XDK tasks from a door.
	             Om.Order_Id              = R.Order_Id) Repls,
              --
	      ( SELECT DISTINCT Rp.Task_Id,
	                        Rp.Prod_Id,
	                        Pl_Replen_Rf.F_Last_Selected_Stop(Blk.Route_No, Fd.Stop_No) Blk_Stop,
	                        Substr(LTRIM(RTRIM(Pl_Replen_Rf.F_Route_Active(Blk.Route_No ))), 1, 1) Blk_Rt_Active
	          FROM
                       Swms.Replenlst      Blk,
	               Swms.Replenlst      Rp,
	               Swms.Float_Detail   Fd
	         WHERE
                       Rp.Type         = 'DMD'           AND            -- 11/12/2021 Brian Bent Bug fix was 'XDK'
	               Rp.Status       = 'NEW'           AND
	               Blk.Order_Id    = Rp.Order_Id     AND
	               Blk.Prod_Id     = Rp.Prod_Id      AND
	               Blk.Type        = 'XDK'           AND
	               Blk.Status      IN ('NEW','PIK')  AND
	               Fd.Float_No     = Blk.Float_No) Dmd_4_Blk,
              --
	      ( SELECT R4.Task_Id,
	               Pl_Replen_Rf.F_Last_Selected_Stop(R4.Route_No, MAX( Fd.Stop_No))      Last_Stop_No,      -- latest
	               SUBSTR(LTRIM( RTRIM(Pl_Replen_Rf.F_Route_Active(R4.Route_No))), 1, 1) Route_Active
	          FROM
                       Swms.Replenlst     R4,
	               Swms.Float_Detail  Fd
	         WHERE
                       R4.Type     = 'XDK'        AND                  -- 11/12/2021 Brian Bent Bug fix was 'BLK'
	               R4.Status   = 'NEW'        AND
	               Fd.Float_No = R4.Float_No
	         GROUP BY
                       R4.Task_Id,
	               R4.Route_No) Last_Stop,
              --
	      ( SELECT DISTINCT Fd.Order_Id,
	                        Fd.Prod_Id
	          FROM
                       Swms.Float_Detail  Fd,
	               Swms.Floats        F,
	               Swms.Sos_Short     S
	         WHERE
                       Fd.Order_Seq   = S.Orderseq     AND
	               F.Float_No     = Fd.Float_No    AND
	               F.Pallet_Pull  != 'R') Shorts,
              --
	      ( SELECT DISTINCT R1.Task_Id,
	                        B.Status
	          FROM
                       Swms.Floats         F,
	               Swms.Float_Detail   Fd,
	               Swms.Batch          B,
	               Swms.Replenlst      R1
	         WHERE 
                       R1.Type          = 'DMD'                              AND          -- 11/12/2021 Brian Bent Bug fix was 'XDK'
	               Fd.Route_No      = R1.Route_No                        AND
	               Fd.Float_No      != R1.Float_No                       AND
	               Fd.Prod_Id       = R1.Prod_Id                         AND
	               Fd.Src_Loc       = NVL(R1.Inv_Dest_Loc, R1.Dest_Loc)  AND
	               F.Float_No       = Fd.Float_No                        AND
	               F.Pallet_Pull    = 'N'                                AND
	               B.Batch_No       = 'S' || F.Batch_No) Selections,
              --
	      ( SELECT DISTINCT R2.Task_Id,
	                        R3.Type
	          FROM 
                       Swms.Replenlst R2,
	               Swms.Replenlst R3
	         WHERE 
                       R2.Type       = 'DMD'             AND                               -- 11/12/2021 Brian Bent Bug fix was 'XDK'
	               R3.Type       IN ('MNL', 'NDM')   AND                               -- 11/12/2021 Brian Bent Bug fix was 'XDK'
	               R3.Prod_Id    = R2.Prod_Id        AND
                       R3.Status     = 'NEW'             AND
	               R3.Src_Loc    = NVL(R2.Inv_Dest_Loc, R2.Dest_Loc)) Otherreplens,
              --
	      forklift_task_priority fltp
	 WHERE 
               Repls.Task_Id           = Selections.Task_Id    (+)  AND
	       Repls.Task_Id           = Otherreplens.Task_Id  (+)  AND
	       Repls.Task_Id           = Dmd_4_Blk.Task_Id     (+)  AND
	       Repls.Prod_Id           = Dmd_4_Blk.Prod_Id     (+)  AND
	       Repls.Order_Id          = Shorts.Order_Id       (+)  AND
	       Repls.Prod_Id           = Shorts.Prod_Id        (+)  AND
	       Repls.Task_Id           = Last_Stop.Task_Id     (+)  AND
	       fltp.forklift_task_type = Repls.Type                 AND
	       (
                  ( Repls.Type = 'XDK' AND
	            UPPER(Fltp.Severity) = CASE NVL(Last_Stop_No, - 1)
                                              WHEN - 1 THEN DECODE(Route_Active, 'Y', 'URGENT', 'NORMAL')
                                              ELSE 'CRITICAL'
                                           END
                  )
                 OR
	          ( Repls.Type = 'DMD' AND               -- 11/12/2021 Brian Bent Bug fix was 'XDK'
	            UPPER(Fltp.Severity) =
		            CASE WHEN Shorts.Order_Id IS NOT NULL OR NVL(Dmd_4_Blk.Blk_Stop, - 1) != - 1 THEN 'CRITICAL'
			         WHEN Selections.Status IN ('C', 'A') OR NVL(Dmd_4_Blk.Blk_Rt_Active, 'N')= 'Y' THEN 'URGENT'
			         WHEN Otherreplens.Type = 'MNL' THEN 'HIGH'
			         WHEN Otherreplens.Type = 'NDM' THEN 'MEDIUM'
			         ELSE 'NORMAL'
                            END
                  )
                 OR
	          (Repls.Type = 'NDM' AND
	           UPPER(Fltp.Severity) = DECODE(Repls.Replen_Type, 'S', 'CRITICAL', 'O', 'URGENT', 'H', 'HIGH', 'NORMAL')
                  )
               );
			  

CREATE OR REPLACE PUBLIC SYNONYM v_replen_xdock FOR swms.v_replen_xdock;

GRANT SELECT ON swms.v_replen_xdock TO swms_user;
GRANT SELECT ON swms.v_replen_xdock TO swms_viewer;

