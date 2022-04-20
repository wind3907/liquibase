

CREATE OR REPLACE
	PACKAGE	SWMS.PL_OP_VRT_ALLOC IS

-- sccs_id=@(#) src/schema/plsql/pl_op_vrt_alloc.sql, swms, swms.9, 10.1.1 2/9/07 1.6

---------------------------------------------------------------------------
-- Package Name:
--    PL_OP_VRT_ALLOC
--
-- Description:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/31/06 prpbcb   DN 12138
--                      Ticket: 232012
--                      Project: 232012-VRT Allocates but no inventory on hold
--                      In procedure PopulateVRTTable(), initialized variable
--                      lprevFloatNo to -999.
--
--                      Modified cursor cChkVRT in procedure ProcessVRTOrder()
--                      to handle situations where the inventory was not
--                      put on hold (no records in vrt_alloc).
--    10/25/06 prpbcb   DN 12179
--                      Ticket: 268428
--                      Project: 268428-Cannot complete allocation for a VRT
--                      Cannot complete VRT allocation when there is another
--                      order on the route that is not a VRT.
--                      I found the validation of the qty allocated for a VRT
--                      is also looking at the non-VRT orders on the route.
--                      This validation takes place in procedure
--                      ProcessVRTOrder.  Cursor cChkVRT is selecting the
--                      records.  The changes I made on 08/31/06 did not
--                      filter out non-VRT orders.  If there are only VRT's on
--                      the route then things work.  The following changes to
--                      the cursor should resolve the issue.
--                      Add to the join tables:
--                         ordm m
--                      Add to the where clause:
--                         and m.order_id = o.order_id
--                         and m.order_type  = 'VRT'
--                      
--    09/24/14 prpbcb   Symbotic changes.
--                      Populate OP_TRANS.FLOAT_DETAIL_SEQ_NO from
--                      FLOAT_DETAIL.SEQ_NO when creating the PIK
--                      transaction.  This is a new column in the
--                      TRANS table.  This column along with the existing
--                      float_no column will be used to find
--                      the PIK transaction corresponding to the
--                      FLOAT_DETAIL record.
--
--                      I found the OP_TRANS.FLOAT_NO was not being
--                      populated so I populated it.
--
--                      Modified:
--                         - ProcessVRTOrder()
--
--    01/18/15 prpbcb   Symbotic changes.
--                      Inventory on hold in Symbotic cannot be allocated
--                      against a VRT.  Changed cursor "cInv" in
--                      procedure "pl_op_vrt_alloc()" to exclude inventory
--                      on hold in a Symbotic location by calling function
--                      "pl_matrix_common.ok_to_alloc_to_vrt_in_this_loc()"
--                      This function returns 'Y' if the inventory is in a
--                      location that can be allocated to a VRT otherwise
--                      'N' is returned.
--
--    07/27/15 prpbcb   Brian Bent
--                      Symbotic project.
--                      Bug fix.  TFS work item 505
--                      FLOAT_DETAIL.ORDER_SEQ not populated.
--                      Change cursor "ccrtFlDtl" to select the order sequence
--                      from the ORDD table.  It is used to populate
--                      FLOAT_DETAIL.ORDER_SEQ.  If not populated then the
--                      ORDCW records for a catch wt item will not get created.
--                      Note: Another option would be to add the order
--                            sequence to table VRT_ALLOC table and populate
--                            it in form "oo1sg".  I elected not to do this
--                            because of the additional changes required. 
--                      
---------------------------------------------------------------------------



		PROCEDURE PopulateVRTTable	(vRouteNo	VARCHAR2);

		FUNCTION f_QtyAvailable	(vOrderId	VARCHAR2,
					 iOrdLineId	INTEGER,
					 vPalletId	VARCHAR2)
		RETURN INTEGER;
		PROCEDURE ProcessVRTOrder	(vRouteNO	VARCHAR2,
						 l_ermsg	IN OUT	VARCHAR2);
	END PL_OP_VRT_ALLOC;
/
CREATE OR REPLACE
	PACKAGE	BODY SWMS.PL_OP_VRT_ALLOC IS
		PROCEDURE PopulateVRTTable	(vRouteNo	VARCHAR2) IS
			CURSOR	cVRTAlloc (pRouteNo VARCHAR2) IS
			SELECT	od.route_no,
				od.order_id,
				od.order_line_id,
				od.prod_id,
				od.cust_pref_vendor,
				od.uom,
				od.qty_ordered,
				od.stop_no,
				p.spc
			  FROM	pm p, ordd od, ordm om
			 WHERE	om.route_no = pRouteNo
			   AND	om.order_type = 'VRT'
			   AND	od.Order_Id = om.order_id
			   AND	p.prod_id = od.prod_id
			   AND	p.cust_pref_vendor = od.cust_pref_vendor
			 ORDER	BY od.order_id, od.order_line_id;

			CURSOR	cInv (	pProdID		VARCHAR2,
					pCustPrefVendor	VARCHAR2) IS
			SELECT	i.plogi_loc,
				i.logi_loc,
				i.qty_alloc,
				i.qoh
			  FROM	inv i
			 WHERE	i.prod_id = pProdId
			   AND	i.cust_pref_vendor = pCustPrefVendor
			   AND	i.status = 'HLD'
                           --
                           --   Some locations the pallet on HLD is in cannot
                           --   be allocated to a VRT.  Such as a
                           --   Symbotic location.
                           AND  pl_matrix_common.ok_to_alloc_to_vrt_in_this_loc(i.plogi_loc) = 'Y'
                           --
			   FOR	UPDATE OF i.qty_alloc
			 ORDER	BY i.exp_date, i.mfg_date, i.logi_loc;

			CURSOR	cchkVRTAlloc (	pOrderId	VARCHAR2,
						pOrderLineId	INTEGER,
						pSrcLoc		VARCHAR2,
						pPalletId	VARCHAR2) IS
			SELECT	0
			  FROM	vrt_alloc
			 WHERE	order_id = pOrderId
			   AND	order_line_id = pOrderLineId
			   AND	src_loc = pSrcLoc
			   AND	pallet_id = pPalletId;

			lQtyReqd	NUMBER := 0;
			lRemainingQty	NUMBER := 0;
			lAvlQty		NUMBER := 0;
			lAllocQty	NUMBER := 0;
			lConfirm	VARCHAR2 (1) := 'N';
			lDummy		INTEGER := 0;
		BEGIN
			FOR rVrtAlloc IN cVRTAlloc (vRouteNo)
			LOOP
			BEGIN
				lQtyReqd := rVrtAlloc.qty_ordered;
				lRemainingQty := 0;
				FOR rInv IN cInv (rVrtAlloc.prod_id, rVrtAlloc.cust_pref_vendor)
				LOOP
				BEGIN
					lAvlQty := rInv.qoh - rInv.qty_alloc;
					IF (lQtyReqd > lAvlQty) THEN
						lAllocQty := lAvlQty;
					ELSE
						lAllocQty := lQtyReqd;
					END IF;
					IF (lAllocQty = 0) THEN
						lConfirm := 'N';
					ELSE
						lConfirm := 'Y';
					END IF;
					OPEN cchkVRTAlloc (rVrtAlloc.order_id,
							   rVrtAlloc.order_line_id,
							   rInv.plogi_loc,
							   rInv.logi_loc);
					FETCH	cchkVRTAlloc INTO lDummy;
					IF (cchkVRTAlloc%NOTFOUND) THEN
					BEGIN
						INSERT INTO vrt_alloc (
							route_no, order_id, order_line_id, prod_id,
							cust_pref_vendor, uom, qty_ordered,
							src_loc, pallet_id, qty_alloc, spc, confirm,
							stop_no)
						VALUES (rVrtAlloc.route_no, rVrtAlloc.order_id,
							rVrtAlloc.order_line_id, rVrtAlloc.prod_id,
							rVrtAlloc.cust_pref_vendor, rVrtAlloc.uom,
							lAllocQty, rInv.plogi_loc, rInv.logi_loc,
							lAllocQty, rVrtAlloc.spc,
							lConfirm, rVrtAlloc.stop_no);
						lQtyReqd := lQtyReqd - lAllocQty;
						UPDATE	inv
						   SET	qty_alloc = qty_alloc + lAllocQty
						 WHERE	CURRENT OF cInv;
					END;
					END IF;
					CLOSE cchkVRTAlloc;
				END;
				END LOOP;
			END;
			END LOOP;
		END PopulateVRTTable;

		FUNCTION f_QtyAvailable	(vOrderId	VARCHAR2,
					 iOrdLineId	INTEGER,
					 vPalletId	VARCHAR2)
		RETURN INTEGER IS
			CURSOR	cVRTAlloc IS
				SELECT	v.prod_id, v.cust_pref_vendor, v.src_loc,
					v.pallet_id,
					o.qty_ordered o_qty_ordered,
					(i.qoh - NVL (i.qty_alloc, 0)) i_qty_avail
				  FROM	inv i, ordd o, vrt_alloc v
				 WHERE	v.order_id = vOrderId
				   AND	v.order_line_id = iOrdLineId
				   AND	o.order_id = v.order_id
				   AND	o.order_line_id = v.order_line_id
				   AND	pallet_id = vPalletId
				   AND	i.prod_id = v.prod_id
				   AND	i.cust_pref_vendor = v.cust_pref_vendor
				   AND	i.logi_loc = v.pallet_id
				   FOR	UPDATE OF v.qty_alloc;

			lUpdQty		NUMBER := 0;
			l_qty_alloc	NUMBER := 0;
		BEGIN
			FOR rVRTAlloc IN cVRTAlloc
			LOOP
				SELECT	SUM (qty_alloc)
				  INTO	l_qty_alloc
				  FROM	vrt_alloc
				 WHERE	order_id = vOrderId
				   AND	order_line_id = iOrdLineId;
				IF (rVRTAlloc.o_qty_ordered - l_qty_alloc > rVRTAlloc.i_qty_avail) THEN
					lUpdQty := rVRTAlloc.i_qty_avail;
				ELSE
					lUpdQty := rVRTAlloc.o_qty_ordered - l_qty_alloc;
				END IF;
			END LOOP;

			RETURN lUpdQty;

		END f_QtyAvailable;

		PROCEDURE ProcessVRTOrder   (vRouteNO  IN       VARCHAR2,
				             l_ermsg   IN OUT	VARCHAR2) IS

                   e_op_ssl_validation_error    EXCEPTION;
                   e_op_route_validation_error  EXCEPTION;
                   e_op_order_status_error      EXCEPTION;
                   e_vrt_allocation_error       EXCEPTION;

                   CURSOR cChkVRT (pRouteNo VARCHAR2) IS
                   SELECT o.order_id, o.order_line_id, o.prod_id, o.uom,
                          o.qty_ordered /
                          DECODE (o.uom, 1, 1,
                                  DECODE (NVL (p.spc, 1), 0, 1,
                                          NVL (p.spc, 1))) qty_ordered,
                          SUM (NVL(v.qty_alloc, 0)) /
                              DECODE (o.uom, 1, 1,
                                      DECODE (NVL (p.spc, 1), 0, 1,
                                              NVL (p.spc, 1))) qty_alloc
                     FROM vrt_alloc v, pm p, ordd o, ordm m
                    WHERE o.route_no          = pRouteNo
                      AND p.prod_id           = o.prod_id
                      AND p.cust_pref_vendor  = o.cust_pref_vendor
                      AND m.order_id          = o.order_id
                      AND m.order_type        = 'VRT'
                      AND v.order_id      (+) = o.order_id
                      AND v.order_line_id (+) = o.order_line_id
                    GROUP BY o.order_id, o.order_line_id, o.prod_id, o.uom,
                             o.qty_ordered,
                             DECODE (o.uom, 1, 1,
                                     DECODE (NVL (p.spc, 1), 0, 1,
                                             NVL (p.spc, 1)))
                   HAVING o.qty_ordered != SUM (nvl(v.qty_alloc, 0));



/*
08/31/06 prpbcb Old cursor
			CURSOR	cChkVRT (pRouteNo VARCHAR2) IS
				SELECT	v.order_id, v.order_line_id, v.prod_id, v.uom,
					o.qty_ordered /
					DECODE (v.uom, 1, 1,
						DECODE (NVL (p.spc, 1), 0, 1,
							NVL (p.spc, 1))) qty_ordered,
					SUM (v.qty_alloc) /
					DECODE (v.uom, 1, 1,
						DECODE (NVL (p.spc, 1), 0, 1,
							NVL (p.spc, 1))) qty_alloc
				  FROM	ordd o, pm p, vrt_alloc v
				 WHERE	v.route_no = pRouteNo
				   AND	p.prod_id = v.prod_id
				   AND	p.cust_pref_vendor = v.cust_pref_vendor
				   AND	o.order_id = v.order_id
				   AND	o.order_line_id = v.order_line_id
				 GROUP	BY v.order_id, v.order_line_id, v.prod_id, v.uom,
					o.qty_ordered,
					DECODE (v.uom, 1, 1,
						DECODE (NVL (p.spc, 1), 0, 1,
							NVL (p.spc, 1)))
				HAVING	o.qty_ordered != SUM (v.qty_alloc);
*/
			
			CURSOR	cRoute IS
				SELECT	status
				  FROM	route
				 WHERE	route_no = vRouteNo;
			CURSOR	cOrdm IS
				SELECT	status, order_id
				  FROM	ordm
				 WHERE	route_no = vRouteNo
				   AND	status != 'NEW';
			CURSOR	ccrtFl IS
				SELECT	v.route_no, v.stop_no, v.src_loc, v.pallet_id, s.group_no,
					s.equip_id, s.door_area, s.comp_code, l.zone_id, r.method_id,
					r.truck_no, decode(s.door_area,'F',r.f_door,'C',r.c_door,'D',r.d_door) door_no,
					SUM (v.qty_alloc) q_alloc, i.qoh, v.prod_id,
					v.cust_pref_vendor,
					SUM (v.qty_alloc) * p.case_cube /
						DECODE (NVL (p.spc, 1), 0, 1, NVL (p.spc, 1)) fCube
				  FROM	pm p, inv i, zone z, lzone l, sel_method s,
					sel_method_zone smz, vrt_alloc v,
					route r
				 WHERE	r.route_no = vRouteNo
				   AND	v.route_no = r.route_no
				   AND	s.method_id = r.method_id
				   AND	s.sel_type = 'PAL'
				   AND	l.logi_loc = v.src_loc
				   AND	i.logi_loc = v.pallet_id
				   AND	z.zone_id = l.zone_id
				   AND	z.zone_type = 'PIK'
				   AND	smz.zone_id = l.zone_id
				   AND	smz.method_id = s.method_id
				   AND	smz.group_no = s.group_no
				   AND	p.prod_id = v.prod_id
				   AND	p.cust_pref_vendor = v.cust_pref_vendor
				   AND	v.qty_alloc > 0
				 GROUP	BY v.route_no, v.stop_no, v.src_loc, v.pallet_id,
					s.group_no, s.equip_id, s.door_area, s.comp_code,
					l.zone_id, r.method_id, r.truck_no, i.qoh,
					decode(s.door_area,'F',r.f_door,'C',r.c_door,'D',r.d_door),
					v.prod_id, v.cust_pref_vendor, p.case_cube,
					DECODE (NVL (p.spc, 1), 0, 1, NVL (p.spc, 1));

			CURSOR	ccrtFlDtl IS
				SELECT	f.float_no, f.b_stop_no, v.prod_id, v.cust_pref_vendor,
					v.src_loc, v.uom, v.qty_ordered, v.qty_alloc, v.order_id,
					v.order_line_id, v.pallet_id,
					v.qty_alloc * p.case_cube /
						DECODE (NVL (p.spc, 1), 0, 1, NVL (p.spc, 1)) fCube,
					i.exp_date, i.rec_id, i.lot_id, i.qoh, i.qty_alloc inv_qty_alloc,
					i.mfg_date,
                                        --
                                        -- 07/27/2015  Brian Bent Get the order sequence.  It is used
                                        -- to populate FLOAT_DETAIL.ORDER_SEQ.  If not populated then
                                        -- the ORDCW records for a catch wt item will not get created.
                                        -- Note: Another option would be to add the order sequence
                                        --       to table VRT_ALLOC table and populate it in form "oo1sg"
                                        --       I elected not to do this because of the additional
                                        --       changes required. 
                                        (SELECT MIN(ordd.seq)  -- MIN as a failsafe
                                           FROM ordd
                                          WHERE ordd.order_id      = v.order_id
                                            AND ordd.order_line_id = v.order_line_id
                                            AND ordd.prod_id       = v.prod_id
                                            AND ordd.uom           = v.uom) order_seq
				  FROM	inv i, vrt_alloc v, pm p, floats f
				 WHERE	f.route_no = vRouteNo
				   AND	v.route_no = f.route_no
				   AND	v.pallet_id = f.pallet_id
				   AND	p.prod_id = v.prod_id
				   AND	p.cust_pref_vendor = v.cust_pref_vendor
				   AND	i.logi_loc = v.pallet_id
				   AND	v.qty_alloc > 0
				   AND	i.qty_alloc > 0
				 ORDER	BY f.float_no, v.order_id, v.order_line_id, i.exp_date, i.qoh desc;

			lSeqNo		NUMBER;
			lprevFloatNo	floats.float_no%TYPE := -999;
			lcurrFloatNo	floats.float_no%TYPE := -999;
		BEGIN
			--
			-- Step 1. Validate VRT against SSL to eliminate setup errors and also add door numbers if missing.
			--
			l_ermsg := NULL;

			pl_order_processing.validate_ordd_against_ssl (
				'VRT', 'PAL', l_ermsg, route_no=>vRouteNO);
			IF (l_ermsg IS NOT NULL) THEN
                                -- Add a little extra to the message.
                                l_ermsg := 'OP SSL validation failed.  '
                                            || l_ermsg;
				RAISE e_op_ssl_validation_error;
			END IF;
                        pl_order_processing.pAssignDoor(vRouteNo);
			--
			-- Step 2. Validate that orders/route are in correct status
			--

			FOR rRoute IN cRoute
			LOOP
				IF (rRoute.status NOT IN ('RCV', 'NEW')) THEN
					l_ermsg := 'OP route validation error.'
                                       || '  Route Status is '
                                       || rRoute.status || '.  Cannot process.';
					RAISE e_op_route_validation_error;
				END IF;
			END LOOP;

			FOR rOrdm IN cOrdm
			LOOP
                                IF (cOrdm%ROWCOUNT = 1) THEn
				   l_ermsg := l_ermsg
                                              || 'OP Order status error.  '  ;
                                END IF;

				l_ermsg := l_ermsg || 'Invalid Status ' || rOrdm.status ||
					   ' for Order ' || rOrdm.order_id || chr (10);
			END LOOP;

			IF (l_ermsg IS NOT NULL) THEN
				RAISE e_op_order_status_error;
			END IF;

			--
			-- Step 3. Validate VRT Allocation 
			--
			FOR rChkVRT IN cChkVRT (vRouteNo)
			LOOP

                                IF (cChkVRT%ROWCOUNT = 1) THEN
				   l_ermsg := l_ermsg || 'VRT alloc error.  ';
                                END IF;

				l_ermsg := l_ermsg || 'Prod. = ' || rChkVRT.prod_id || ', ' ||
					' Tot. Ord. = ' || rChkVRT.qty_ordered;
				IF (rChkVRT.uom = 1) THEN
					l_ermsg := l_ermsg || ' Split(s). ';
				ELSE
					l_ermsg := l_ermsg || ' Cases(s). ';
				END IF;
				l_ermsg := l_ermsg || ' Alloc = ' || rChkVRT.qty_alloc || chr (10);
			END LOOP;

			IF (l_ermsg IS NOT NULL) THEN
				RAISE e_vrt_allocation_error;
			END IF;

			--
			-- Step 4. Create Floats for each distinct pallet
			--
			FOR rcrtFl IN ccrtFl
			LOOP
				SELECT float_no_seq.NEXTVAL into lcurrFloatNo from DUAL;

				INSERT	INTO floats (float_no, route_no, b_stop_no, e_stop_no,
					group_no, zone_id, equip_id, comp_code, pallet_id,
					door_area, fl_method_id, float_cube, merge_loc,
					pallet_pull, split_ind, single_stop_flag, status, drop_qty)
				VALUES	(lcurrFloatNo, vRouteNo, rcrtFl.stop_no,
					 rcrtFl.stop_no, rcrtFl.group_no, rcrtFl.zone_id,
					 rcrtFl.equip_id, rcrtFl.comp_code, rcrtFl.pallet_id,
					 rcrtFl.door_area, rcrtFl.method_id, rcrtFl.fCube,
					 '???', 'D', 'N', 'N', 'NEW', 0);
				INSERT INTO replenlst ( task_id, prod_id, cust_pref_vendor, qty,
					src_loc, pallet_id, route_no, truck_no, dest_loc, status,
					type, float_no, seq_no,door_no, drop_qty, uom)
				VALUES	(repl_id_seq.NEXTVAL, rcrtFl.prod_id, rcrtFl.cust_pref_vendor,
					 rcrtFl.q_alloc, rcrtFl.src_loc, rcrtFl.pallet_id,
					 vRouteNo, rcrtFl.truck_no, '99', 'NEW', 'BLK', lcurrFloatNo, 1,rcrtFl.door_no, 0, 2);
					 
			END LOOP;

			FOR rcrtFlDtl IN ccrtFlDtl
			LOOP
				IF (lprevFloatNo != rcrtFlDtl.float_no) THEN
					lSeqNo := 1;
				ELSE
					lSeqNo := NVL (lSeqNo, 0) + 1;
				END IF;
				lprevFloatNo := rcrtFlDtl.float_no;

				INSERT	INTO float_detail (
					float_no, seq_no, stop_no, prod_id, cust_pref_vendor,
					src_loc, uom, qty_order, qty_alloc, cube, order_id,
					order_line_id, route_no, status, zone, multi_home_seq,
					merge_alloc_flag, merge_loc, copy_no, rec_id, mfg_date,
					exp_date, lot_id, carrier_id,
                                        order_seq)
				VALUES	(rcrtFlDtl.float_no, lSeqNo, rcrtFlDtl.b_stop_no,
					 rcrtFlDtl.prod_id, rcrtFlDtl.cust_pref_vendor,
					 rcrtFlDtl.src_loc, rcrtFlDtl.uom, rcrtFlDtl.qty_ordered,
					 rcrtFlDtl.qty_alloc, rcrtFlDtl.fCube,
					 rcrtFlDtl.order_id, rcrtFlDtl.order_line_id,
					 vRouteNo, 'OPN', 1, 1, 'N', '???', 0,
					 rcrtFlDtl.rec_id, rcrtFlDtl.mfg_date, rcrtFlDtl.exp_date,
					 rcrtFlDtl.lot_id, rcrtFlDtl.pallet_id,
                                         rcrtFlDtl.order_seq);

				INSERT	INTO op_trans (trans_id, prod_id, cust_pref_vendor,
					rec_id, lot_id, exp_date, qty_expected, qty,
					src_loc, order_id, order_line_id, route_no, stop_no,
					pallet_id, uom, user_id, trans_type, trans_date,
                                        float_no, float_detail_seq_no)
				VALUES	(trans_id_seq.NEXTVAL, rcrtFlDtl.prod_id,
					 rcrtFlDtl.cust_pref_vendor, rcrtFlDtl.rec_id,
					 rcrtFlDtl.lot_id, rcrtFlDtl.exp_date,
					 rcrtFlDtl.qty_ordered, rcrtFlDtl.qty_alloc,
					 rcrtFlDtl.src_loc, rcrtFlDtl.order_id,
					 rcrtFlDtl.order_line_id, vRouteNo,
					 rcrtFlDtl.b_stop_no, rcrtFlDtl.pallet_id,
					 rcrtFlDtl.uom, USER, 'PIK', SYSDATE,
                                         rcrtFlDtl.float_no, lSeqNo);
			END LOOP;

			DELETE	inv
			 WHERE	logi_loc IN
				(SELECT	pallet_id
				   FROM	vrt_alloc
				  WHERE	route_no = vRouteNo
				    AND	qty_alloc > 0)
			   AND	qoh = qty_alloc
			   AND	status = 'HLD';

			UPDATE	inv
			   SET	qoh = qoh - qty_alloc,
				qty_alloc = 0
			 WHERE	logi_loc IN 
				(SELECT	pallet_id
				   FROM	vrt_alloc
				  WHERE	route_no = vRouteNo
				    AND	qty_alloc > 0)
			   AND	status = 'HLD';

			UPDATE	ordd
			   SET	status = 'OPN',
				qty_alloc = qty_ordered
			 WHERE	order_id IN
				(SELECT	order_id
				   FROM	ordm
				  WHERE	route_no = vRouteNo
				    AND	order_type = 'VRT');
			UPDATE	ordm
			   SET	status = 'OPN'
			 WHERE	route_no = vRouteNo
			  AND	order_type = 'VRT';

			DELETE	vrt_alloc
			 WHERE	route_no = vRouteNo;

			pl_order_processing.pCreateOrdCW (vRouteNo=>vRouteNo);

                EXCEPTION
                   WHEN e_op_ssl_validation_error THEN
                      NULL;
                   WHEN e_op_route_validation_error THEN
                      NULL;
                   WHEN e_op_order_status_error THEN
                      NULL;
                   WHEN e_vrt_allocation_error THEN
                      NULL;
                   WHEN OTHERS THEN
                      RAISE;

		END ProcessVRTOrder;
						 
	END PL_OP_VRT_ALLOC;
/
