CREATE OR REPLACE PACKAGE swms.pl_gen_batch IS
/*****************************************************************/
/* sccs_id=@(#) src/schema/plsql/pl_gen_batch.sql, swms, swms.9, 10.1.1 11/7/06 1.3 */
/*****************************************************************/
   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_sos
   --
   -- Description:
   --    Package for SOS processing on RF
   --
	FUNCTION  F_GetFloatCount  (chrRouteNo	IN	floats.route_no%TYPE,
				    intGroupNo	IN	floats.group_no%TYPE)
	RETURN	INTEGER;

	FUNCTION  F_GetFloatCount  (chrRouteNo	IN	floats.route_no%TYPE,
				    chrEquipID	IN	floats.equip_id%TYPE)
	RETURN	INTEGER;

END pl_gen_batch;
/
CREATE OR REPLACE
PACKAGE BODY swms.pl_gen_batch
IS

	FUNCTION  F_GetFloatCount  (chrRouteNo	IN	floats.route_no%TYPE,
				    intGroupNo	IN	floats.group_no%TYPE)
	RETURN	INTEGER IS
		lNoFloats	INTEGER;
	BEGIN
		SELECT	COUNT (0)
		  INTO	lNoFloats
		  FROM	floats
		 WHERE	route_no = chrRouteNo
		   AND	group_no = intGroupNo
		   AND	NVL (batch_no, 0) = 0
		   AND	pallet_pull = 'N';
		RETURN lNoFloats;
		EXCEPTION
			WHEN OTHERS THEN
				RETURN (-1);
	END F_GetFloatCount;

	FUNCTION  F_GetFloatCount  (chrRouteNo	IN	floats.route_no%TYPE,
				    chrEquipID	IN	floats.equip_id%TYPE)
	RETURN	INTEGER IS
		lNoFloats	INTEGER;
	BEGIN
		SELECT	COUNT (0)
		  INTO	lNoFloats
		  FROM	floats
		 WHERE	route_no = chrRouteNo
		   AND	equip_id = chrEquipID
		   AND	NVL (batch_no, 0) = 0
		   AND	pallet_pull = 'N';
		RETURN lNoFloats;
		EXCEPTION
			WHEN OTHERS THEN
				RETURN (-1);
	END F_GetFloatCount;

END pl_gen_batch;
/
CREATE OR REPLACE PUBLIC SYNONYM pl_gen_batch FOR swms.pl_gen_batch
/
