CREATE OR REPLACE PACKAGE swms.pl_acc_track AS

-- *********************** <Package Specifications> ****************************

-- ************************* <Prefix Documentations> ***************************

--  This package specification is used to do inbound accessory processing.

-- ******************** <End of Prefix Documentations> *************************

-- ************************* <Constant Definitions> ****************************

C_NORMAL		CONSTANT NUMBER := 0;
C_NOT_FOUND		CONSTANT NUMBER := 1403;
C_ANSI_NOT_FOUND	CONSTANT NUMBER := 100;

C_INV_MF		CONSTANT NUMBER := 241;	-- Invalid manifest #

C_MF_NO_LEN		CONSTANT NUMBER := 7;
C_BARCODE_LEN		CONSTANT NUMBER := 14;
C_ACCESSORY_NAME_LEN	CONSTANT NUMBER := 20;
C_SCANNABLE_LEN		CONSTANT NUMBER := 1;

-- *************************** <Type Definitions> *****************************

TYPE trecLdCnt IS RECORD (
  szField1	VARCHAR2(20),
  szField2	VARCHAR2(1),
  szField3	VARCHAR2(14),
  szField4	NUMBER(3)
);

TYPE trecEqTyp IS RECORD (
  szField1	VARCHAR2(20),
  szField2	VARCHAR2(1)
);

TYPE trecInbCnt IS RECORD (
  szField1	VARCHAR2(20),
  szField2	VARCHAR2(14),
  szField3	NUMBER(3)
);

TYPE trecCnt IS RECORD (
  szField1	VARCHAR2(20),
  szField2	VARCHAR2(1),
  szField3	VARCHAR2(14),
  szField4	NUMBER(3),
  szField5	NUMBER(3)
);



TYPE ttabLdCnt IS TABLE OF trecLdCnt
  INDEX BY BINARY_INTEGER;

TYPE ttabEqTyp IS TABLE OF trecEqTyp
  INDEX BY BINARY_INTEGER;

TYPE ttabInbCnt IS TABLE OF trecInbCnt
  INDEX BY BINARY_INTEGER;

TYPE ttabCnt IS TABLE OF trecCnt
  INDEX BY BINARY_INTEGER;

TYPE ttabValues IS TABLE OF VARCHAR2(4000)
  INDEX BY BINARY_INTEGER;


-- ************************* <Variable Definitions> ****************************
-- =============================================================================
-- Function
--   get_mf_info
--
-- Description
--   Retrieve truck number, route number, manifest status information from the
--   MANIFESTS table for a given manifest number.
--
-- Parameters
--   pszManifestNo (input)
--     Manifest number.
--   poszTruckNo (output)
--     Truck number corresponding to the manifest number.
--   poszRouteNo (output)
--     Route number corresponding to the manifest number.
--   pszManifestSts (pitput)
--     Status of the manifest in the manifest table.
--   poiStatus (input)
--     Return status is one of the following:
--       0 - The manifest details retreived without any problem
--       C_INV_MF - The manifest is invalid
--       <0 - Database error occurred
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_mf_info (
  pszManifestNo IN manifests.manifest_no%TYPE ,
  poszTruckNo OUT manifests.truck_no%TYPE,
  poszRouteNo	OUT manifests.route_no%TYPE,
  poszManifestSts OUT manifests.manifest_status%TYPE,
  poiStatus OUT NUMBER);

-- =============================================================================
-- Function
--   get_equip_cnt
--
-- Description
--   Retrieve the list of all equipments in a truck corresponding to a given
--   truck number, route number and manifest number and the inbound/outbound
--   passed. The function is mainly used by a caller that cannot accept
--   PL/SQL table type as return parameter. This function retrieve the list
--   of equipments and related count details from the LAS_TRUCK_EQUIPMENT
--   table and converts the data to a long string to be returned to the
--   caller. It's up to the caller to seperate each group of equipment
--   information for usage (see poszValues paramter for fields).
--
-- Parameters
--   pszManifestNo (input)
--     Manifest number.
--   pszTruckNo (input)
--     Truck number corresponding to the manifest number.
--   pszRouteNo (input)
--     Route number corresponding to the manifest number.
--   poiNumFetchRows (output)
--     The number of equipments fetched. The value should match the total
--     count of the poszValues.
--   poszValues (output)
--     An array of equipments and the count information to be returned. Each
--     record includes Equipment type (20)+Scannable(1)+Barcode(14)+Count(3)
--   poiStatus (input)
--     Return status is one of the following:
--       0 - The manifest details retreived without any problem
--       <0 - Database error occurred
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_equip_cnt (
  pszManifestNo IN manifests.manifest_no%TYPE ,
  pszTruckNo IN manifests.truck_no%TYPE,
  pszRouteNo IN manifests.route_no%TYPE,
  poiNumFetchRows	OUT NUMBER,
  poszValues		OUT ttabValues,
  poiStatus OUT NUMBER);

-- =============================================================================
-- Function
--   get_equip_lst
--
-- Description
--   Retrieve the list of all equipment types available from the
--   LAS_TRUCK_EQUIPMENT_TYPE table. The function is mainly used by a caller that
--   cannot accept PL/SQL table type as return parameter. This function
--   retrieve all equipment type information and convert the data to a long string
--   to be returned to the caller. It's up to the caller to seperate each group
--   of equipment type information for usage (see poszValues paramter for fields).
--
-- Parameters
--   poiNumFetchRows (output)
--     The number of equipment types fetched. The value should match the total
--     count of the poszValues.
--   poszValues (output)
--     An array of equipment type information to be returned. Each record includes
--     Equipment type (20)+Scannable(1)
--   poiStatus (input)
--     Return status is one of the following:
--       0 - The equipment list details retreived without any problem
--       <0 - Database error occurred
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_equip_lst (
  poiNumFetchRows	OUT NUMBER,
  poszValues		OUT ttabValues,
  poiStatus OUT NUMBER);

-- =============================================================================
-- Function
--   upd_inbound_cnt
--
-- Description
--   Updates the LAS_TRUCK_EQUIPMENT with the inbound count sent for a particular
--   equipment type and barcode in a truck number, route number and manifest number
--
-- Parameters
--   pszManifestNo (input)
--     Manifest number.
--   pszTruckNo (input)
--     Truck number corresponding to the manifest number.
--   pszRouteNo (input)
--     Route number corresponding to the manifest number.
--   pszEquipmentType (input)
--     Equipment type for which the inbound count needs to be updated.
--   pszBarCode (input)
--     Barcode number of the equiment type for which count has to be updated.
--   pszCount (input)
--     Inbound count.
--   poiStatus (input)
--     Return status is one of the following:
--       0 - The inbound count has been updated without any problem
--       <0 - Database error occurred
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE upd_inbound_cnt (
  pszManifestNo IN manifests.manifest_no%TYPE,
  pszTruckNo 	IN manifests.truck_no%TYPE,
  pszRouteNo 	IN manifests.route_no%TYPE,
  pszEquipmentType IN las_truck_equipment_type.equipment_type%TYPE,
  pszBarCode	IN las_truck_equipment.barcode%TYPE,
  pszCount	IN las_truck_equipment.loader_count%TYPE,
  poiStatus 	OUT NUMBER);

-- =============================================================================
-- Function
--   ins_inbound_info
--
-- Description
--   Inserts the equipment type, barcode and inbound count details sent for a particular
--   truck, route and manifest number.
--
-- Parameters
--   pszManifestNo (input)
--     Manifest number.
--   pszTruckNo (input)
--     Truck number corresponding to the manifest number.
--   pszRouteNo (input)
--     Route number corresponding to the manifest number.
--   pszEquipmentType (input)
--     Equipment type for which the inbound details needs to be inserted.
--   pszBarCode (input)
--     Barcode number of the equiment type that is to be inserted.
--   pszCount (input)
--     Inbound count.
--   poiStatus (input)
--     Return status is one of the following:
--       0 - The inbound count has been inserted without any problem
--       <0 - Database error occurred
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE ins_inbound_info (
  pszManifestNo IN manifests.manifest_no%TYPE,
  pszTruckNo 	IN manifests.truck_no%TYPE,
  pszRouteNo 	IN manifests.route_no%TYPE,
  pszEquipmentType IN las_truck_equipment_type.equipment_type%TYPE,
  pszBarCode	IN las_truck_equipment.barcode%TYPE,
  pszCount	IN las_truck_equipment.loader_count%TYPE,
  poiStatus 	OUT NUMBER);

-- =============================================================================
-- Function
--   del_inbound_cnt
--
-- Description
--   Deletes the inbound record in LAS_TRUCK_EQUIPMENT for a particular
--   equipment type and barcode in a truck number, route number and manifest number
--
-- Parameters
--   pszManifestNo (input)
--     Manifest number.
--   pszTruckNo (input)
--     Truck number corresponding to the manifest number.
--   pszRouteNo (input)
--     Route number corresponding to the manifest number.
--   pszEquipmentType (input)
--     Equipment type for which the inbound record needs to be deleted.
--   pszBarCode (input)
--     Barcode number of the equiment type which has to be deleted.
--   poiStatus (input)
--     Return status is one of the following:
--       0 - The inbound record has been deleted without any problem
--       <0 - Database error occurred
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--

PROCEDURE del_inbound_cnt (
  pszManifestNo IN manifests.manifest_no%TYPE,
  pszTruckNo 	IN manifests.truck_no%TYPE,
  pszRouteNo 	IN manifests.route_no%TYPE,
  pszEquipmentType IN las_truck_equipment_type.equipment_type%TYPE,
  pszBarCode	IN las_truck_equipment.barcode%TYPE,
  poiStatus 	OUT NUMBER);


-- =============================================================================
-- Function
--   get_in_out_count
--
-- Description
--   Retrieve the list of all inbound equipments and the count in a truck
--   corresponding to a given truck, route and manifest number and the
--   corresponding outbound count. The function is mainly used by a caller that
--   cannot accept PL/SQL table type as return parameter. This function retrieve
--   the list of equipments and related count details from the LAS_TRUCK_EQUIPMENT
--   table and converts the data to a long string to be returned to the
--   caller. It's up to the caller to seperate each group of equipment
--   information for usage (see poszValues paramter for fields).
--
-- Parameters
--   pszManifestNo (input)
--     Manifest number.
--   pszTruckNo (input)
--     Truck number corresponding to the manifest number.
--   pszRouteNo (input)
--     Route number corresponding to the manifest number.
--   pszSrcTyp (input)
--     Specifies whether Outbound('O')/Inbound('I') information to be fetched.
--   poiNumFetchRows (output)
--     The number of equipments fetched. The value should match the total
--     count of the poszValues.
--   poszValues (output)
--     An array of equipments and the count information to be returned. Each
--     record includes Equipment type (20)+Scannable(1)+Barcode(14)+
--     Inbound count(3)+Outbound count(3)
--   poiStatus (input)
--     Return status is one of the following:
--       0 - The inbound and outbound count details retreived without any problem
--       <0 - Database error occurred
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_in_out_count (
  pszManifestNo IN manifests.manifest_no%TYPE,
  pszTruckNo 	IN manifests.truck_no%TYPE,
  pszRouteNo 	IN manifests.route_no%TYPE,
  poiNumFetchRows	OUT NUMBER,
  poszValues		OUT ttabValues,
  poiStatus 	OUT NUMBER);

-- =============================================================================
-- ******************** <End of Package Specifications> ************************

END pl_acc_track;
/
SHOW ERRORS
CREATE OR REPLACE PACKAGE BODY swms.pl_acc_track AS

-- ***************************** <Package Body> ********************************

-- ********************** <Private Variable Definitions> ***********************

-- ********************** <Private Functions/Procedures> ***********************

-- *********************** <Public Functions/Procedures> ***********************
PROCEDURE get_mf_info (
  pszManifestNo IN manifests.manifest_no%TYPE,
  poszTruckNo OUT manifests.truck_no%TYPE,
  poszRouteNo	OUT manifests.route_no%TYPE,
  poszManifestSts OUT manifests.manifest_status%TYPE,
  poiStatus OUT NUMBER) IS
BEGIN
  poszTruckNo := ' ';
  poszRouteNo := ' ';
  poszManifestSts := ' ';
  poiStatus := C_NORMAL;

  SELECT
  ROUTE_NO,TRUCK_NO,MANIFEST_STATUS
	INTO poszRouteNo,poszTruckNo,poszManifestSts
	FROM MANIFESTS
	WHERE MANIFEST_NO = pszManifestNo;
EXCEPTION
WHEN NO_DATA_FOUND THEN
  poiStatus := C_INV_MF;
WHEN OTHERS THEN
  poiStatus := SQLCODE;
END;

PROCEDURE get_equip_cnt (
  pszManifestNo IN manifests.manifest_no%TYPE,
  pszTruckNo IN manifests.truck_no%TYPE,
  pszRouteNo IN manifests.route_no%TYPE,
  poiNumFetchRows	OUT NUMBER,
  poszValues		OUT ttabValues,
  poiStatus OUT NUMBER) IS
  szValues	ttabValues;
  szLdCnt	ttabLdCnt;
  iIndex	NUMBER :=0;
  iNumEqp	NUMBER :=0;


CURSOR truck_curr IS
SELECT t.equipment_type eqtype,t.scannable scan,e.barcode barcode,
sum(e.inbound_count) count
FROM v_truck_accessory e,las_truck_equipment_type t
WHERE e.truck_no = pszTruckNo
AND e.manifest_no = pszManifestNo
AND e.route_no = pszRouteNo
AND e.type_seq= t.type_seq
GROUP BY t.type_seq,t.equipment_type,t.scannable,e.barcode
ORDER BY t.type_seq;
-- This last condition in the where clause ensures that only the latest records that are related to the truck
-- and compartment will be chosen. The newly modified las_truck_equipment
-- table is also acted as a history table for those accessory counts. The record
-- will be purged out only after about 1 month. The statement takes cares of the scenario
-- that if opco reuses their route # and truck # within a time period.
-- Please test this scenario too by creating same records with different added dates.

BEGIN
  poiStatus := C_NORMAL;

  poiNumFetchRows := 0;

  FOR cTrk IN truck_curr LOOP
  szLdCnt(iNumEqp + 1).szField1 := cTrk.eqtype;
  szLdCnt(iNumEqp + 1).szField2 := cTrk.scan;
  szLdCnt(iNumEqp + 1).szField3 := cTrk.barcode;
  szLdCnt(iNumEqp + 1).szField4 := cTrk.count;
  iNumEqp := iNumEqp + 1;
  END LOOP;

  FOR iIndex IN 1 .. iNumEqp LOOP
  szValues(iIndex) := RPAD(szLdCnt(iIndex).szField1, C_ACCESSORY_NAME_LEN, ' ') ||
                               RPAD(szLdCnt(iIndex).szField2,
                                    C_SCANNABLE_LEN, ' ') ||
                               RPAD(szLdCnt(iIndex).szField3,
                                    C_BARCODE_LEN, ' ') ||
                               RPAD(TO_CHAR(szLdCnt(iIndex).szField4),3, ' ');
  END LOOP;

  poiNumFetchRows := iNumEqp;
  poszValues := szValues;

EXCEPTION
WHEN OTHERS THEN
  poiStatus := SQLCODE;
END;


PROCEDURE get_equip_lst (
  poiNumFetchRows	OUT NUMBER,
  poszValues		OUT ttabValues,
  poiStatus OUT NUMBER) IS
  szValues	ttabValues;
  szEqTyp	ttabEqTyp;
  iIndex	NUMBER :=0;
  iNumEqp	NUMBER :=0;


CURSOR equip_curr IS
SELECT equipment_type eqtype,scannable scan
FROM las_truck_equipment_type t
ORDER BY type_seq;

BEGIN
  poiStatus := C_NORMAL;

  poiNumFetchRows := 0;

  FOR cEqp IN equip_curr LOOP
  szEqTyp(iNumEqp + 1).szField1 := cEqp.eqtype;
  szEqTyp(iNumEqp + 1).szField2 := cEqp.scan;
  iNumEqp := iNumEqp + 1;
  END LOOP;

  FOR iIndex IN 1 .. iNumEqp LOOP
  szValues(iIndex) := RPAD(szEqTyp(iIndex).szField1, C_ACCESSORY_NAME_LEN, ' ') ||
                               RPAD(szEqTyp(iIndex).szField2,C_SCANNABLE_LEN, ' ');
  END LOOP;

  poiNumFetchRows := iNumEqp;
  poszValues := szValues;

EXCEPTION
WHEN OTHERS THEN
  poiStatus := SQLCODE;
END;

PROCEDURE upd_inbound_cnt (
  pszManifestNo IN manifests.manifest_no%TYPE,
  pszTruckNo 	IN manifests.truck_no%TYPE,
  pszRouteNo 	IN manifests.route_no%TYPE,
  pszEquipmentType IN las_truck_equipment_type.equipment_type%TYPE,
  pszBarCode	IN las_truck_equipment.barcode%TYPE,
  pszCount	IN las_truck_equipment.loader_count%TYPE,
  poiStatus 	OUT NUMBER) IS

  szTypSeq	las_truck_equipment_type.type_seq%TYPE:= 0;
  szEqTyp	las_truck_equipment_type.equipment_type%TYPE:= 0;
  szScannable	las_truck_equipment_type.scannable%TYPE:= 'N';
  szCnt		NUMBER :=0;
  UPDATE_RECORD	BOOLEAN := FALSE;
  temp		NUMBER := 0;
  sAddUser	las_truck_equipment.add_user%TYPE := NULL;
BEGIN
  poiStatus := C_NORMAL;

  SELECT type_seq,scannable
  INTO szTypSeq,szScannable
  FROM las_truck_equipment_type
  WHERE equipment_type = pszEquipmentType;

  -- For a barcode scannable Y item, the barcode can be overriden
  -- after checking-in.  Hence barcode value also needs
  -- to be updated.
	IF (szScannable = 'Y') THEN
	BEGIN
		SELECT	0
		  INTO	temp
		  FROM	v_truck_accessory
		 WHERE	type_seq = szTypSeq
		   AND	manifest_no = pszManifestNo
		   AND	truck_no = pszTruckNo
		   AND	barcode = NVL(pszBarCode, ' ');
		UPDATE_RECORD := TRUE;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				ins_inbound_info (pszManifestNo,
					pszTruckNo, pszRouteNo,
					pszEquipmentType, pszBarCode,
					pszCount, poiStatus);
	END;
	ELSE
		UPDATE_RECORD := TRUE;
	END IF;

	IF (UPDATE_RECORD) THEN
	BEGIN
		temp := 0;
		BEGIN
		  UPDATE	truck_accessory_history
		     SET	inbound_count = pszCount,
				upd_date = SYSDATE,
				upd_user = REPLACE(USER, 'OPS$', '')
		   WHERE	type_seq = szTypSeq
		     AND	manifest_no = pszManifestNo
		     AND	truck = pszTruckNo
		     AND	route_no = pszRouteNo
		     AND	DECODE (szScannable, 'Y', barcode, 'N') =
					DECODE (szScannable,
						'Y', NVL(pszBarCode, ' '), 'N');
		  temp := SQL%ROWCOUNT;

		EXCEPTION
		   WHEN OTHERS THEN
			temp := 0;
		END;

		IF temp = 0 OR SQLCODE NOT IN (C_NORMAL) THEN
		  BEGIN
		    SELECT add_user INTO sAddUser
		    FROM las_truck_equipment e
		   WHERE type_seq = szTypSeq
		     AND manifest_no = pszManifestNo
		     AND truck = pszTruckNo
		     AND route_no = pszRouteNo
		     AND DECODE (szScannable, 'Y', barcode, 'N') =
				DECODE (szScannable,
					'Y', NVL(pszBarCode, ' '), 'N')
		     AND add_date = (SELECT MAX(add_date)
				     FROM las_truck_equipment
				     WHERE type_seq = e.type_seq
				     AND manifest_no = e.manifest_no
				     AND truck = e.truck
				     AND route_no = e.route_no
				     AND NVL(barcode, ' ') =
						NVL(e.barcode, ' '));
		  EXCEPTION
		    WHEN OTHERS THEN
			sAddUser := REPLACE(USER, 'OPS$', '');
		  END;
		  BEGIN
		    INSERT INTO truck_accessory_history
		      (truck, route_no, type_seq, barcode, manifest_no,
			loader_count, inbound_count, ship_date,
			add_date, add_user)
			SELECT pszTruckNo, pszRouteNo, szTypSeq,
				pszBarcode, pszManifestNo,
				SUM(NVL(loader_count, 0)),
				SUM(NVL(inbound_count, 0)),
				NVL(MAX(ship_date), TRUNC(MAX(add_date))),
				MAX(add_date), REPLACE(sAddUser, 'OPS$', '')
			FROM las_truck_equipment
		     	WHERE type_seq = szTypSeq
			AND manifest_no = pszManifestNo
		     	AND truck = pszTruckNo
		     	AND route_no = pszRouteNo
		     	AND DECODE (szScannable, 'Y', barcode, 'N') =
				DECODE (szScannable,
					'Y', NVL(pszBarCode, ' '), 'N');
		    temp := SQL%ROWCOUNT;
		  EXCEPTION
			WHEN OTHERS THEN
				temp := 0;
		  END;
		  IF temp > 0 THEN
			BEGIN
				DELETE las_truck_equipment
		     		WHERE type_seq = szTypSeq
				AND manifest_no = pszManifestNo
			     	AND truck = pszTruckNo
			     	AND route_no = pszRouteNo
			     	AND DECODE (szScannable, 'Y', barcode, 'N') =
					DECODE (szScannable,
						'Y', NVL(pszBarCode, ' '),
						'N');
			EXCEPTION
				WHEN OTHERS THEN
					NULL;
			END;
		  END IF;
		  IF temp > 0 THEN
		    BEGIN
		      UPDATE	truck_accessory_history
		         SET	inbound_count = pszCount,
				upd_date = SYSDATE,
				upd_user = REPLACE(USER, 'OPS$', '')
		       WHERE	type_seq = szTypSeq
		       AND	manifest_no = pszManifestNo
		       AND	truck = pszTruckNo
		       AND	route_no = pszRouteNo
		       AND	DECODE (szScannable, 'Y', barcode, 'N') =
					DECODE (szScannable,
						'Y', NVL(pszBarCode, ' '), 'N');
		    EXCEPTION
			WHEN OTHERS THEN
				poiStatus := SQLCODE;
		    END;
		  END IF;
		END IF;
	END;
	END IF;

	EXCEPTION
	WHEN OTHERS THEN
  		poiStatus := SQLCODE;
	END;

PROCEDURE ins_inbound_info (
  pszManifestNo IN manifests.manifest_no%TYPE,
  pszTruckNo 	IN manifests.truck_no%TYPE,
  pszRouteNo 	IN manifests.route_no%TYPE,
  pszEquipmentType IN las_truck_equipment_type.equipment_type%TYPE,
  pszBarCode	IN las_truck_equipment.barcode%TYPE,
  pszCount	IN las_truck_equipment.loader_count%TYPE,
  poiStatus 	OUT NUMBER) IS

  szTypSeq	las_truck_equipment_type.type_seq%TYPE:= 0;
  szEqTyp	las_truck_equipment_type.equipment_type%TYPE:= 0;
  szCnt		NUMBER :=0;
  dtShipDate	DATE := NULL;
  iExists	NUMBER := 0;
  sCompartment	las_truck_equipment.compartment%TYPE := NULL;

BEGIN
	poiStatus := C_NORMAL;

	SELECT	type_seq
	  INTO	szTypSeq
	  FROM	las_truck_equipment_type
	 WHERE	equipment_type = pszEquipmentType;

	BEGIN
		SELECT compartment, ship_date INTO sCompartment, dtShipDate
		FROM las_truck_equipment
		WHERE	truck = pszTruckNo
		AND     manifest_no = pszManifestNo
		AND	type_seq = szTypSeq
		AND	route_no = pszRouteNo
		AND	NVL (pszBarCode, 'N') = NVL (barcode, 'N')
		AND	ROWNUM = 1;
		iExists := 1;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			BEGIN
				SELECT ship_date INTO dtShipDate
				FROM truck_accessory_history
				WHERE	truck = pszTruckNo
				AND     manifest_no = pszManifestNo
				AND	type_seq = szTypSeq
				AND	route_no = pszRouteNo
				AND	NVL (pszBarCode, 'N') =
						NVL (barcode, 'N')
				AND	ROWNUM = 1;
				iExists := 2;
				sCompartment := NULL;
			EXCEPTION
				WHEN OTHERS THEN
					iExists := 0;
			END;
		WHEN OTHERS THEN
			iExists := 0;
	END;

	BEGIN
		IF iExists = 0 THEN
			IF dtShipDate IS NULL THEN
			BEGIN
				SELECT TO_CHAR(r.gen_date) INTO dtShipDate
				FROM ordd_for_rtn r, manifests m,
					manifest_dtls d
				WHERE m.manifest_no = d.manifest_no
				AND   r.order_id =
					NVL(d.obligation_no, d.orig_invoice)
				AND   r.prod_id = d.prod_id
				AND   DECODE(r.uom, 2, 0, r.uom) =
					TO_NUMBER(d.shipped_split_cd)
				AND   r.route_no = m.route_no
				AND   r.stop_no = d.stop_no
				AND   m.manifest_no = pszManifestNo
				AND   m.route_no = pszRouteNo
				AND   ROWNUM = 1;
			EXCEPTION
				WHEN OTHERS THEN
					NULL;
			END;
			END IF;
			INSERT	INTO truck_accessory_history
				(truck, type_seq, inbound_count,
				 loader_count, barcode,manifest_no,route_no,
				 add_date, add_user, ship_date)
			VALUES	(pszTruckNo, szTypSeq, pszCount, 0,
				 pszBarCode, pszManifestNo, pszRouteNo,
				 SYSDATE, REPLACE(USER, 'OPS$', ''),
				 NVL(dtShipDate, TRUNC(SYSDATE)));
		ELSE
			IF iExists = 1 THEN
				UPDATE	las_truck_equipment
				   SET	inbound_count = pszCount,
					upd_date = SYSDATE,
					upd_user = REPLACE(USER, 'OPS$', '')
				 WHERE	truck = pszTruckNo
				   AND	type_seq = szTypSeq
				   AND	manifest_no = pszManifestNo
				   AND	route_no = pszRouteNo
				   AND  compartment = sCompartment
				   AND	NVL (pszBarCode, 'N') =
						NVL (barcode, 'N');
			ELSE
				UPDATE	truck_accessory_history
				   SET	inbound_count = pszCount,
					upd_date = SYSDATE,
					upd_user = REPLACE(USER, 'OPS$', '')
				 WHERE	truck = pszTruckNo
				   AND	type_seq = szTypSeq
				   AND	manifest_no = pszManifestNo
				   AND	route_no = pszRouteNo
				   AND	NVL (pszBarCode, 'N') =
						NVL (barcode, 'N');
			END IF;
		END IF;
	EXCEPTION
		WHEN OTHERS THEN
			poiStatus := SQLCODE;
	END;
END;

PROCEDURE del_inbound_cnt (
	pszManifestNo IN manifests.manifest_no%TYPE,
	pszTruckNo 	IN manifests.truck_no%TYPE,
	pszRouteNo 	IN manifests.route_no%TYPE,
	pszEquipmentType IN las_truck_equipment_type.equipment_type%TYPE,
	pszBarCode	IN las_truck_equipment.barcode%TYPE,
	poiStatus 	OUT NUMBER) IS
	
	szTypSeq	las_truck_equipment_type.type_seq%TYPE:= 0;
	szEqTyp	las_truck_equipment_type.equipment_type%TYPE:= 0;
	szCnt		NUMBER := 0;
	lCount	NUMBER := 0;
	iCount	NUMBER := 0;
	sTyp	VARCHAR2(1) := NULL;
	sAddUser	las_truck_equipment.add_user%TYPE := NULL;
	iInsCnt	NUMBER := 0;
	iLocked	NUMBER := 0;
	eExcLocked	EXCEPTION;
	PRAGMA EXCEPTION_INIT(eExcLocked, -54);
	CURSOR	curTrk IS
	SELECT	'H' typ, ship_date, add_date, loader_count, inbound_count
	  FROM	truck_accessory_history
	 WHERE	type_seq = szTypSeq
	   AND	manifest_no = pszManifestNo
	   AND	NVL(barcode, ' ') = NVL(pszBarCode, ' ')
	   AND	truck = pszTruckNo
	   AND	route_no = pszRouteNo
	 UNION
	SELECT	'N' typ, NVL(MAX(ship_date), TRUNC(MAX((add_date)))) ship_date,
		MAX(add_date) add_date,
		SUM(NVL(loader_count, 0)) loader_count,
		SUM(NVL(inbound_count, 0)) inbound_count
	  FROM	las_truck_equipment
	 WHERE	type_seq = szTypSeq
	   AND	manifest_no = pszManifestNo
	   AND	NVL(barcode, ' ') = NVL(pszBarCode, ' ')
	   AND	truck = pszTruckNo
	   AND	route_no = pszRouteNo;
BEGIN
	poiStatus := C_NORMAL;

	SELECT	type_seq
	  INTO	szTypSeq
	  FROM	las_truck_equipment_type
	 WHERE	equipment_type = pszEquipmentType;

	FOR ct IN curTrk LOOP
	  lCount := ct.loader_count;
	  iCount := ct.inbound_count;
	  IF ct.typ = 'N' THEN
	    BEGIN
	      SELECT add_user INTO sAddUser
	      FROM las_truck_equipment e
	      WHERE type_seq = szTypSeq
	      AND manifest_no = pszManifestNo
	      AND truck = pszTruckNo
	      AND route_no = pszRouteNo
	      AND NVL(barcode, ' ') = NVL(pszBarCode, ' ')
	      AND add_date = (SELECT MAX(add_date)
				FROM las_truck_equipment
				WHERE type_seq = e.type_seq
				AND manifest_no = e.manifest_no
				AND truck = e.truck
				AND route_no = e.route_no
				AND NVL(barcode, ' ') = NVL(e.barcode, ' '));
	    EXCEPTION
	      WHEN OTHERS THEN
		sAddUser := REPLACE(USER, 'OPS$', '');
	    END;
	    BEGIN
	      INSERT INTO truck_accessory_history
		(truck, route_no, type_seq, barcode, manifest_no,
		 loader_count, inbound_count, ship_date,
		 add_date, add_user)
		SELECT pszTruckNo, pszRouteNo, szTypSeq,
			pszBarcode, pszManifestNo,
			SUM(NVL(loader_count, 0)),
			SUM(NVL(inbound_count, 0)),
			NVL(MAX(ship_date), TRUNC(MAX(add_date))),
			MAX(add_date), sAddUser
		FROM las_truck_equipment
	     	WHERE type_seq = szTypSeq
		AND manifest_no = pszManifestNo
	     	AND truck = pszTruckNo
	     	AND route_no = pszRouteNo
		AND NVL(barcode, ' ') = NVL(pszBarCode, ' ');
	      iInsCnt := SQL%ROWCOUNT;
	    EXCEPTION
	      WHEN OTHERS THEN
		iInsCnt := 0;
	    END;
	    IF iInsCnt > 0 THEN
	      BEGIN
		DELETE las_truck_equipment
		  WHERE type_seq = szTypSeq
		  AND manifest_no = pszManifestNo
		  AND truck = pszTruckNo
		  AND route_no = pszRouteNo
		  AND NVL(barcode, ' ') = NVL(pszBarCode, ' ');
	      EXCEPTION
		WHEN OTHERS THEN
		  NULL;
	      END;
	    END IF;
	  END IF;
	  BEGIN
	    SELECT 1 INTO iLocked
	    FROM truck_accessory_history
	    WHERE type_seq = szTypSeq
	    AND manifest_no = pszManifestNo
	    AND truck = pszTruckNo
	    AND route_no = pszRouteNo
	    AND NVL(barcode, ' ') = NVL(pszBarCode, ' ')
	    FOR UPDATE OF inbound_count NOWAIT;
	  EXCEPTION
	    WHEN eExcLocked THEN
		poiStatus := -54;
		RETURN;
	  END;
	  IF ((lCount = 0) AND (iCount != 0)) THEN
	    BEGIN
		DELETE truck_accessory_history
		WHERE type_seq = szTypSeq
		AND manifest_no = pszManifestNo
		AND truck = pszTruckNo
		AND route_no = pszRouteNo
		AND NVL(barcode, ' ') = NVL(pszBarCode, ' ');
	    EXCEPTION
		WHEN NO_DATA_FOUND THEN
			NULL;
		WHEN OTHERS THEN
			poiStatus := SQLCODE;
	    END;
	  ELSIF ((lCount > 0) AND (iCount > 0)) THEN
	    BEGIN
		UPDATE truck_accessory_history
		SET inbound_count = 0
		WHERE type_seq = szTypSeq
		AND manifest_no = pszManifestNo
		AND truck = pszTruckNo
		AND route_no = pszRouteNo
		AND NVL(barcode, ' ') = NVL(pszBarCode, ' ');
	    EXCEPTION
		WHEN NO_DATA_FOUND THEN
			NULL;
		WHEN OTHERS THEN
			poiStatus := SQLCODE;
	    END;
	  END IF;
	END LOOP;

EXCEPTION
	WHEN OTHERS THEN
  		poiStatus := SQLCODE;
END;


PROCEDURE get_in_out_count (
  pszManifestNo IN manifests.manifest_no%TYPE,
  pszTruckNo 	IN manifests.truck_no%TYPE,
  pszRouteNo 	IN manifests.route_no%TYPE,
  poiNumFetchRows	OUT NUMBER,
  poszValues		OUT ttabValues,
  poiStatus 	OUT NUMBER) IS

  szTypSeq	las_truck_equipment_type.type_seq%TYPE:= 0;
  szEqTyp	las_truck_equipment_type.equipment_type%TYPE:= 0;
  szCnt		NUMBER :=0;
  szValues	ttabValues;
  szLdCnt	ttabCnt;
  iIndex	NUMBER :=0;
  iNumEqp	NUMBER :=0;

  CURSOR truck_curr IS
  SELECT t.type_seq seqtype, t.equipment_type eqtype,
	 t.scannable scan, NVL(e.barcode,' ') barcode,
	 sum(e.inbound_count) count
  FROM v_truck_accessory e, las_truck_equipment_type t
  WHERE e.manifest_no = pszManifestNo
  AND e.truck_no = pszTruckNo
  AND e.route_no = pszRouteNo
  AND e.type_seq = t.type_seq
  GROUP BY t.type_seq,t.equipment_type,t.scannable,e.barcode
  ORDER BY 1;

BEGIN
  poiStatus := C_NORMAL;

  poiNumFetchRows := 0;

  FOR cTrk IN truck_curr LOOP
  szLdCnt(iNumEqp + 1).szField1 := cTrk.eqtype;
  szLdCnt(iNumEqp + 1).szField2 := cTrk.scan;
  szLdCnt(iNumEqp + 1).szField3 := cTrk.barcode;
  szLdCnt(iNumEqp + 1).szField4 := cTrk.count;

  -- Fetch the corresponding outbound count
  SELECT NVL(sum(e.loader_count),0) INTO szCnt
  FROM las_truck_equipment e
  WHERE e.truck = pszTruckNo
  AND e.type_seq = cTrk.seqtype
  AND NVL(e.barcode, ' ') = NVL(cTrk.barcode, ' ')
  AND manifest_no = pszManifestNo;

  szLdCnt(iNumEqp + 1).szField5 := szCnt;
  iNumEqp := iNumEqp + 1;

  END LOOP;

  FOR iIndex IN 1 .. iNumEqp LOOP
  szValues(iIndex) := RPAD(szLdCnt(iIndex).szField1, C_ACCESSORY_NAME_LEN, ' ') ||
                               RPAD(szLdCnt(iIndex).szField2,
                                    C_SCANNABLE_LEN, ' ') ||
                               RPAD(szLdCnt(iIndex).szField3,
                                    C_BARCODE_LEN, ' ') ||
                               RPAD(TO_CHAR(szLdCnt(iIndex).szField4),3, ' ') ||
                               RPAD(TO_CHAR(szLdCnt(iIndex).szField5),3, ' ');
  END LOOP;

  poiNumFetchRows := iNumEqp;
  poszValues := szValues;

EXCEPTION
WHEN OTHERS THEN
  poiStatus := SQLCODE;
END;



-- ********************** <Package Initialization> *****************************

-- ************************* <End of Package Body> *****************************

END pl_acc_track;
/
SHOW ERRORS
CREATE OR REPLACE PUBLIC SYNONYM pl_acc_track FOR swms.pl_acc_track
/
