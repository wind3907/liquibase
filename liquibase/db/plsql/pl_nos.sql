CREATE OR REPLACE PACKAGE swms.pl_nos AS

-- *********************** <Package Specifications> ****************************

-- ************************* <Prefix Documentations> ***************************

--  This package specification is used to do SOS processing.
--  Mainly use by RF that mimics the available functionalities in the original
--  SOS share memory processing.
  
--  %Z% %W% %G% %I%
 
--  Modification History
--  Date      User      Defect  Comment
--  05/29/06  prplhj    12252   Initial creation
--  06/18/07  prplhj    12257   Get rid of new columns related to las_pallet.
--  07/18/07  prplhj    12263   For sos_config SHORT_JOBCODE retrieval, not
--                              to look at sos_usr_config for user ID.
--  08/29/07  prplhj    12276   Add "swms." to package name.
--  07/31/08  prfxa000  12402   Added codes for SLS.
--  03/22/10  ssha0443  DN12554 - 212 Enh - SCE042- Customer Id  
--                      expansion SWMS changes  
--                      Changed customer id field length  to 10 characters 
--  04/01/10   sth0458  DN12554 - 212 Enh - SCE057
--                      Add UOM field to SWMS
--                      Expanded the length of prod size to accomodate 
--                      for prod size unit.
--                      Changed queries to fetch prod_size_unit along 
--                      with prod_size
-- ******************** <End of Prefix Documentations> *************************

-- ************************* <Constant Definitions> ****************************

C_NORMAL		CONSTANT NUMBER := 0;
C_NOT_FOUND		CONSTANT NUMBER := 1403;
C_ANSI_NOT_FOUND	CONSTANT NUMBER := 100;

C_DFT_CPV		CONSTANT VARCHAR2(1) := '-';
C_APPL_SOS		CONSTANT VARCHAR2(3) := 'SOS';
C_APPL_SLS		CONSTANT VARCHAR2(3) := 'SLS';
C_APPL_TRL		CONSTANT VARCHAR2(3) := 'TRL';
C_DFT_UNSAFE_MARK	CONSTANT VARCHAR2(1) := 'X';
C_LOADING_STATUS	CONSTANT las_pallet.loader_status%TYPE := 'L';
C_LOADED_STATUS		CONSTANT las_pallet.loader_status%TYPE := '*';
C_SELECT_STATUS		CONSTANT las_pallet.selection_status%TYPE := 'S';
C_SELMISCASE_STATUS	CONSTANT las_pallet.selection_status%TYPE := 'C';

C_BATCH_NO_LEN		CONSTANT NUMBER := 13;
C_CPV_LEN		CONSTANT NUMBER := 10;
-- 03/22/10 - 12554 - ssha0443 - Added for 212 Enh - SCE042 - Begin 
--Changed the length of customer ID from 6 to 10
C_CUST_ID_LEN		CONSTANT NUMBER := 10;
-- 03/22/10 - 12554 - ssha0443 - Added for 212 Enh - SCE042 - End
C_DESCRIP_LEN		CONSTANT NUMBER := 30;
C_INV_NO_LEN		CONSTANT NUMBER := 14;
C_LINE_ID_LEN		CONSTANT NUMBER := 4;
C_LOC_LEN		CONSTANT NUMBER := 10;
C_LP_LEN		CONSTANT NUMBER := 18;
C_MF_NO_LEN		CONSTANT NUMBER := 7;
C_ONECHAR_LEN		CONSTANT NUMBER := 1;
C_ORDD_SEQ_LBL_LEN	CONSTANT NUMBER := 11;
C_ORDD_SEQ_DB_LEN	CONSTANT NUMBER := 8;
C_PALLET_TYPE_LEN	CONSTANT NUMBER := 2;
C_PROD_ID_LEN		CONSTANT NUMBER := 9;
C_PALLET_ID_LEN		CONSTANT NUMBER := 18;
C_QTY_LEN		CONSTANT NUMBER := 4;
C_REASON_LEN		CONSTANT NUMBER := 3;
C_REASON_GROUP_LEN	CONSTANT NUMBER := 3;
C_REC_TYP_LEN		CONSTANT NUMBER := 1;
C_ROUTE_NO_LEN		CONSTANT NUMBER := 10;
C_STOP_NO_LEN		CONSTANT NUMBER := 7;
c_TEMP_LEN		CONSTANT NUMBER := 6;
C_TIHI_LEN		CONSTANT NUMBER := 4;
C_TRAILER_NO_LEN	CONSTANT NUMBER := 6;
C_TRUCK_NO_SLS_LEN	CONSTANT NUMBER := 4;
C_UOM_LEN		CONSTANT NUMBER := 1;
C_UPC_LEN		CONSTANT NUMBER := 14;
C_WEIGHT_LEN		CONSTANT NUMBER := 9;

C_LBL_TYPE_FLOAT	  CONSTANT	NUMBER := 1;
C_LBL_TYPE_CASE           CONSTANT	NUMBER := 2;
C_LBL_TYPE_ZONE           CONSTANT	NUMBER := 3;
C_LBL_TYPE_COMPARTMENT    CONSTANT      NUMBER := 4;
C_LBL_TYPE_TRUCK          CONSTANT      NUMBER := 5;
C_LBL_TYPE_COMPRT_ACC     CONSTANT      NUMBER := 6;
C_LBL_TYPE_FLOAT_UNLOAD   CONSTANT      NUMBER := 7;
C_LBL_TYPE_TRUCK_UNLOAD   CONSTANT      NUMBER := 8;
C_LBL_TYPE_ZONE_EXIT      CONSTANT      NUMBER := 9;

C_OPT_CL_RESCAN_FLOAT     CONSTANT      NUMBER := 1;
C_OPT_CL_IGNORE_MIS_CW    CONSTANT      NUMBER := 2;
C_OPT_CL_IGNORE_MIS_FLT   CONSTANT      NUMBER := 3;
C_OPT_CL_ACCESSORY_RECALL CONSTANT      NUMBER := 4;
C_OPT_CL_CLOSE_TRUCK      CONSTANT      NUMBER := 5;
C_OPT_CL_UNLOAD_FLOAT     CONSTANT      NUMBER := 6;
C_OPT_CL_UNLOAD_FLOAT_2ND CONSTANT      NUMBER := 7;
C_OPT_CL_UNLOAD_TRUCK     CONSTANT      NUMBER := 8;
C_OPT_CL_ZONE_FUNC1       CONSTANT      NUMBER := 9;

C_MIN_FLOAT_SEQ_ZONE	  CONSTANT	NUMBER := 1;
C_MAX_FLOAT_SEQ_ZONE	  CONSTANT	NUMBER := 24;

-- Code from tm_define.h
C_INV_ZONE		CONSTANT NUMBER := 68;
C_WRONG_EQUIP		CONSTANT NUMBER := 105;
C_NO_LM_BATCH_FOUND	CONSTANT NUMBER := 146;
C_LM_INVALID_USERID	CONSTANT NUMBER := 291;
C_NO_NEED_EQUIP_CHECK	CONSTANT NUMBER := 401;
C_INV_FLOAT_SEQ		CONSTANT NUMBER := 402;
C_PALLET_LOADED		CONSTANT NUMBER := 403;
C_FLOAT_OUT_SEQ		CONSTANT NUMBER := 404;
C_TRUCK_NOT_AVAIL	CONSTANT NUMBER := 408;
C_TRAILER_USED		CONSTANT NUMBER := 413;
C_LM_NOT_ACTIVE		CONSTANT NUMBER := 431;
C_EQUIP_IN_USE		CONSTANT NUMBER := 542;

-- *************************** <Type Definitions> *****************************

-- A record holds SOS/SLS configuration parameter names and values
TYPE recTypConfig IS RECORD (
  config_name		sos_config.config_flag_name%TYPE,
  config_val		sos_config.config_flag_val%TYPE
);

-- A record to hold missing information
TYPE recTypMissing IS RECORD (
  orderseq		ordd.seq%TYPE,
  prod_id		pm.prod_id%TYPE,
  cust_pref_vendor	pm.cust_pref_vendor%TYPE,
  descrip		pm.descrip%TYPE,
  uom			ordd.uom%TYPE,
  qty			sos_short.qty_short%TYPE,
  stop_no		VARCHAR2(7),
  prod_size		pm.prod_size%TYPE,
/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
/*
** Declare  prod size unit
*/
	prod_size_unit		pm.prod_size_unit%TYPE,
/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
  cust_id		ordm.cust_id%TYPE,
  flag			VARCHAR2(1)
);

-- A record holds some type parameter fields
TYPE recTypFTypParam IS RECORD (
  name			equip_param.name%TYPE,
  descrip		equip_param.descrip%TYPE,
  abbr			equip_param.abbr%TYPE,
  scannable		equip_param.scannable%TYPE
);

-- A record holds float summary fields
TYPE recTypFloatSummary IS RECORD (
  truck_no		route.truck_no%TYPE,
  truck_zone		las_pallet.truck_zone%TYPE,
  palletno		las_pallet.palletno%TYPE,
  door			route.f_door%TYPE,
  batch			las_pallet.batch%TYPE,
  loader_status		las_pallet.loader_status%TYPE,
  selection_status	las_pallet.selection_status%TYPE
);

-- A record holds truck accessory information
TYPE recTypTruckAccessory IS RECORD (
  compartment		las_truck_equipment.compartment%TYPE,
  name			equip_param.name%TYPE,
  loader_count		las_truck_equipment.loader_count%TYPE,
  inbound_count		las_truck_equipment.inbound_count%TYPE,
  ship_date		las_truck_equipment.ship_date%TYPE,
  barcode		las_truck_equipment.barcode%TYPE,
  manifest_no		las_truck_equipment.manifest_no%TYPE,
  route_no		las_truck_equipment.route_no%TYPE,
  scannable		equip_param.scannable%TYPE
);

TYPE recTypLoaderLM IS RECORD (
  lbr_mgmt_flag		sys_config.config_flag_val%TYPE,
  calc_unload_goal_time	sys_config.config_flag_val%TYPE,
  las_active		sys_config.config_flag_val%TYPE,
  need_istart		NUMBER(1),
  supervsr_id		batch.user_supervsr_id%TYPE,
  batch_no		batch.batch_no%TYPE,
  status		batch.status%TYPE,
  batch_date		batch.batch_date%TYPE,
  job_code		batch.jbcd_job_code%TYPE,
  labor_group		usr.lgrp_lbr_grp%TYPE,
  start_time		batch.actl_start_time%TYPE,
  stop_time		batch.actl_stop_time%TYPE,
  equip_id		batch.equip_id%TYPE,
  parent_batch_no	batch.parent_batch_no%TYPE,
  float_seq		floats.float_seq%TYPE,
  upd_user		sos_usr_config.user_id%TYPE,
  loader_status		las_pallet.loader_status%TYPE
);

TYPE recDrInfo IS RECORD (
  door			route.f_door%TYPE,
  truck			route.truck_no%TYPE,
  f_status		las_truck.freezer_status%TYPE,
  c_status		las_truck.cooler_status%TYPE,
  d_status		las_truck.dry_status%TYPE);

TYPE recPalInfo IS RECORD (
  pallet		las_pallet.palletno%TYPE,
  zone			sls_load_map.map_zone%TYPE);

-- A table type (array) of up to 500 characters
TYPE tabString IS TABLE OF VARCHAR2(500)
  INDEX BY BINARY_INTEGER;

-- A table type (array) of SOS/SLS parameter configuration information
TYPE tabTypConfig IS TABLE OF recTypConfig
  INDEX BY BINARY_INTEGER;

-- A table type (array) of all rows of SOS/SLS safety check parameter
-- information for certain equipment types
TYPE tabTypETRSfList IS TABLE OF equip_type_param%ROWTYPE
  INDEX BY BINARY_INTEGER;

-- A table type (array) of only SOS/SLS safety check parameter name
-- information for certain equipment types
TYPE tabTypETNmSfList IS TABLE OF equip_type_param.name%TYPE
  INDEX BY BINARY_INTEGER;

-- A table type (array) of only SOS/SLS safety check parameter name
-- information for certain equipment types
TYPE tabTypSfHist IS TABLE OF equip_safety_hist%ROWTYPE
  INDEX BY BINARY_INTEGER;

-- A table type (array) of missing information (including case and weight)
TYPE tabTypMissing IS TABLE OF recTypMissing
  INDEX BY BINARY_INTEGER;

-- A table type (array) of equipment type parameter information
TYPE tabTypFTypParam IS TABLE OF recTypFTypParam
  INDEX BY BINARY_INTEGER;

-- A table type (array) of equipment type parameter name information
TYPE tabTypPTypParam IS TABLE OF equip_param.name%TYPE
  INDEX BY BINARY_INTEGER;

-- A table type (array) of float summary information
TYPE tabTypFloatSummary IS TABLE OF recTypFloatSummary
  INDEX BY BINARY_INTEGER;

TYPE tabTypTruckAccessory IS TABLE OF recTypTruckAccessory
  INDEX BY BINARY_INTEGER;

-- A table type (array) of door information
TYPE tabDrInfo IS TABLE OF recDrInfo INDEX BY BINARY_INTEGER;

-- A table type (array) of pallet information
TYPE tabPalInfo IS TABLE OF recPalInfo INDEX BY BINARY_INTEGER;

-- A table type (array) of trailer note information
TYPE tabNoteInfo IS TABLE OF las_truck.note1%TYPE INDEX BY BINARY_INTEGER;

-- ************************* <Variable Definitions> ****************************

-- =============================================================================
-- Function
--   check_equip
--
-- Description
--   Check if the enter equipment ID sEquipID is valid in SWMS or not
--   from the EQUIPMENT table.
--
-- Parameters
--   sEquipID (input)
--     Equipment ID
--   sApplType (input)
--     Application type of the equipment ID
--
-- Returns
--   0 - The input equipment ID is valid associated with the sApplType.
--   C_WRONG_EQUIP - There is no such equipment ID in the system.
--   <other values> - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION check_equip(
  psEquipID		IN equipment.equip_id%TYPE,
  psApplType		IN equipment.appl_type%TYPE DEFAULT 'ALL')
RETURN NUMBER;

-- =============================================================================
-- Function
--   login_equip
--
-- Description
--   User logins to the current equipment. Put the input psEquipID to either
--   SOS_USR_CONFIG or LAS_USR_CONFIG table for the input psUserID depending on
--   the input psApplType and the input psUpdateConfig flag. If caller doesn't
--   provide psApplType and/or psUserID, their values will be defaulted to
--   'ALL' and/or current user, respectively. If caller doesn't provide
--   psUpdateConfig, it will be defaulted to 'Y' which means that the input
--   data will be updated to the SOS/LAS_USR_CONFIG table. Also put the input
--   psUserID to the EQUIPMENT table for the input psEquipID so user can check
--   on who is using the particular piece of equipment later if needed. If the
--   psUpdateConfig flag is set and the input psApplType or the database
--   value for the input psEquipID is 'SOL which means that the equipment
--   can be used as either SOS or SLS equipment, the psEquipID value will go
--   into both the SOS_USR_CONFIG and LAS_USR_CONFIG tables for the same
--   psUserID.
--
-- Parameters
--   psEquipID (input)
--     Equipment ID
--   psApplType (input)
--     Application type of the equipment ID. Default to 'ALL' if no input.
--   psUserID (input)
--     User ID who is using or try to use the input equipment ID. Default to
--     currrent user who is calling the function if no input.
--   psUpdateConfig (input)
--     A flag to indicate whether the SOS/LAS_USR_CONFIG table needs to be
--     updated with the input equipment ID for the input user ID or not. The
--     action only will be performed if the flag value is 'Y'. This is to
--     include consideration that applications other than SOS and SLS might
--     use this function. 
--
-- Returns
--   0 - The input data have been updated to respected tables successfully
--   C_WRONG_EQUIP - There is no such equipment ID in the system.
--   C_LM_INVALID_USERID - User is not set up to perform SOS or SLS functions.
--   <>0 - Fail to update the input data to respected tables
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION login_equip(
  psEquipID		IN equipment.equip_id%TYPE,
  psApplType		IN equipment.appl_type%TYPE DEFAULT 'ALL',
  psUserID		IN sos_usr_config.user_id%TYPE
                             DEFAULT REPLACE(USER, 'OPS$', ''),
  psUpdateConfig	IN VARCHAR2 DEFAULT 'Y')
RETURN NUMBER;

-- =============================================================================
-- Function
--   logout_equip
--
-- Description
--   User logs out from the current equipment. Clear the pallet_jack_id column
--   from either SOS_USR_CONFIG or LAS_USR_CONFIG table for the input psUserID
--   depending on the input psApplType and the input psUpdateConfig flag. If
--   caller doesn't provide psApplType and/or psUserID, their values will be
--   defaulted to 'ALL' and/or current user, respectively. If caller doesn't
--   provide psUpdateConfig, it will be defaulted to 'Y' which means that the
--   input data will be updated to the SOS/LAS_USR_CONFIG table. If
--   psUpdateConfig flag is set and the input psApplType or the database
--   value for the input psEquipID is 'SOL' which means that the equipment
--   can be used as either SOS or SLS equipment, the pallet_jack_id columns
--   from both the SOS_USR_CONFIG and LAS_USR_CONFIG tables for the same
--   psUserID will be cleared.
--
-- Parameters
--   psEquipID (input)
--     Equipment ID
--   psApplType (input)
--     Application type of the equipment ID. Default to 'ALL' if no input.
--   psUserID (input)
--     User ID who is using the input equipment ID. Default to
--     currrent user who is calling the function if no input.
--   psUpdateConfig (input)
--     A flag to indicate whether the SOS/LAS_USR_CONFIG table needs to be
--     cleared for the input user ID or not. The action only will be performed
--     if the flag value is 'Y'. This is to include consideration that
--     applications other than SOS and SLS might use this function. 
--
-- Returns
--   0 - The input data have been cleared from the respected tables successfully
--   C_WRONG_EQUIP - There is no such equipment ID in the system.
--   C_LM_INVALID_USERID - User is not set up to perform SOS or SLS functions.
--   <>0 - Fail to clear the input data from the respected tables
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION logout_equip(
  psEquipID		IN equipment.equip_id%TYPE,
  psApplType		IN equipment.appl_type%TYPE DEFAULT 'ALL',
  psUserID		IN sos_usr_config.user_id%TYPE
                             DEFAULT REPLACE(USER, 'OPS$', ''),
  psUpdateConfig	IN VARCHAR2 DEFAULT 'Y')
RETURN NUMBER;

-- =============================================================================
-- Function
--   get_sos_config
--
-- Description
--   Retrieve syspar configuration values for SOS according to input
--   psValueSearch criteria if any.
--
-- Parameters
--   ptbTypConfig (output)
--     A SQL table type of value pairs: syspar name + syspar value or no table
--     contents if no syspar is available or found or database error occurred.
--   poiStatus (output)
--     Procedure execution status.
--       0 - Successful. No error has occurred
--       C_LM_INVALID_USERID - The error only happens if the request is for
--         SOS configuration parameters. The error indicates that either the
--         user ID is not set up in the system or the user is not set up a
--         primary job code.
--       < 0 - Database error has occurred
--   psUserID (input)
--     User ID who wants to retrieve the configuration data. This is mainly
--     used on the SOS configuration parameters to retrieve the right area
--     configuration data. It has no effect on the SLS data retrieval. The
--     value is default to the user ID who is executing the procedure.
--   psValueSearch (input)
--     Syspar flag name to be search or NULL if none
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_sos_config(
  ptbTypConfig		OUT tabTypConfig,
  poiStatus		OUT NUMBER,
  psUserID		IN  sos_usr_config.user_id%TYPE DEFAULT USER,
  psValueSearch		IN  sos_config.config_flag_name%TYPE DEFAULT NULl);

-- =============================================================================
-- Function
--   get_sls_config
--
-- Description
--   Retrieve syspar configuration values for SLS according to input
--   psValueSearch criteria if any.
--
-- Parameters
--   ptbTypConfig (output)
--     A SQL table type of value pairs: syspar name + syspar value or no table
--     contents if no syspar is available or found or database error occurred.
--   poiStatus (output)
--     Procedure execution status.
--       0 - Successful. No error has occurred
--       < 0 - Database error has occurred
--   psUserID (input)
--     User ID who wants to retrieve the configuration data. This is mainly
--     used on the SOS configuration parameters to retrieve the right area
--     configuration data. It has no effect on the SLS data retrieval. The
--     value is default to the user ID who is executing the procedure.
--   psValueSearch (input)
--     Syspar flag name to be search or NULL if none
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_sls_config (
  ptbTypConfig		OUT tabTypConfig,
  poiStatus		OUT NUMBER,
  psUserID		IN  las_usr_config.user_id%TYPE DEFAULT USER,
  psValueSearch		IN las_config.config_flag_name%TYPE DEFAULT NULL);

-- =============================================================================
-- Function
--   get_config
--
-- Description
--   Retrieve the syspar configuration settings (syspar names and the
--   corresponding values) according to the application type psApplType and
--   search criteria psValueSearch if available. If psValueSearch is NULL,
--   all syspars related to the psApplType will be returned.
--   Note that as of the initial version only the SOS and SLS application
--   syspars are supported.
--
-- Parameters
--   psApplType (input)
--     Application type
--   ptbTypConfig (output)
--     A SQL table type of value pairs: syspar name + syspar value or no table
--     contents if no syspar is available or found or database error occurred.
--   poiStatus (output)
--     Procedure execution status.
--       0 - Successful. No error has occurred
--       C_LM_INVALID_USERID - The error only happens if the request is for
--         SOS configuration parameters. The error indicates that either the
--         user ID is not set up in the system or the user is not set up a
--         primary job code.
--       < 0 - Database error has occurred
--   psUserID (input)
--     User ID who wants to retrieve the configuration data. This is mainly
--     used on the SOS configuration parameters to retrieve the right area
--     configuration data. It has no effect on the SLS data retrieval. The
--     value is default to the user ID who is executing the procedure.
--   psValueSearch (input)
--     Syspar value to be searched if any
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_config(
  psApplType		IN equip_safety_hist.appl_type%TYPE,
  ptbTypConfig		OUT tabTypConfig,
  poiStatus		OUT NUMBER,
  psUserID		IN  sos_usr_config.user_id%TYPE DEFAULT USER,
  psValueSearch		IN sos_config.config_flag_name%TYPE DEFAULT NULL);

-- =============================================================================
-- Function
--   get_sos_equip_safety_list
--
-- Description
--   Retrieve SOS equipment safety check list row items according to the input
--   psEquipID, and psValueSearch1 criteria.
--
-- Parameters
--   psEquipID (input)
--     Equipment ID to be searched. The ID should be unique among different
--     application types. It will be validated using the EQUIPMENT table.
--   poiStatus (output)
--     Procedure returned status. Value is one of the following:
--       0 - Normal, no error occurred
--       C_WRONG_EQUIP - Input psEquipID is not found or the found application
--         type is different from the entered psApplType value.
--       < 0 - Database error has occurred
--   potbTypETRSfList (output)
--     A table results of entired row types of the EQUIP_TYPE_PARAM table.
--     Caller should check the poiStatus first before checking on the table
--     output. The potbTypETRSfList.COUNT will be > 0 if there is at least one
--     parameter found for the input equipment ID and the data will be ordered
--     by the found parameters' sequence #s.
--   psValueSearch1 (input)
--     Optional equipment safety check list name to be searched. If it's
--     NULL, records that match other input criteria are returned.
--   piInitCap (input)
--     Whether the equipment safety check name is initially capitalized (1,
--     default) or not (<> 1).
--
-- Returns
--   See output parameters above for details.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_sos_equip_safety_list (
  psEquipID		IN  equipment.equip_id%TYPE,
  poiStatus		OUT NUMBER,
  potbTypETRSfList	OUT tabTypETRSfList,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1);

-- =============================================================================
-- Function
--   get_sos_equip_safety_list
--
-- Description
--   Retrieve SOS equipment safety check list parameter names only according to
--   the input psEquipID, and psValueSearch1 criteria.
--
-- Parameters
--   psEquipID (input)
--     Equipment ID to be searched. The ID should be unique among different
--     application types. It will be validated using the EQUIPMENT table.
--   poiStatus (output)
--     Procedure returned status. Value is one of the following:
--       0 - Normal, no error occurred
--       C_WRONG_EQUIP - Input psEquipID is not found or the found application
--         type is different from the entered psApplType value.
--       < 0 - Database error has occurred
--   potbTypETNmSfList (output)
--     A table results of parameter names from the EQUIP_TYPE_PARAM table.
--     Caller should check the poiStatus first before checking on the table
--     output. The potbTypETRSfList.COUNT will be > 0 if there is at least one
--     parameter found for the input equipment ID and the data will be ordered
--     by the found parameters' sequence #s.
--   posEquipType (output)
--     Found equipment type for the search equipment ID criteria to be returned.
--   psValueSearch1 (input)
--     Optional equipment safety check list name to be searched. If it's
--     NULL, records that match other input criteria are returned.
--   piInitCap (input)
--     Whether the equipment safety check name is initially capitalized (1,
--     default) or not (<> 1).
--
-- Returns
--   See output parameters above for details.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_sos_equip_safety_list (
  psEquipID		IN  equipment.equip_id%TYPE,
  poiStatus		OUT NUMBER,
  potbTypETNmSfList	OUT tabTypETNmSfList,
  posEquipType		OUT equipment.equip_type%TYPE,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1);

-- =============================================================================
-- Function
--   get_sls_equip_safety_list
--
-- Description
--   Retrieve SLS equipment safety check list row items according to the input
--   psEquipID, and psValueSearch1 criteria.
--
-- Parameters
--   psEquipID (input)
--     Equipment ID to be searched. The ID should be unique among different
--     application types. It will be validated using the EQUIPMENT table.
--   poiStatus (output)
--     Procedure returned status. Value is one of the following:
--       0 - Normal, no error occurred
--       C_WRONG_EQUIP - Input psEquipID is not found or the found application
--         type is different from the entered psApplType value.
--       < 0 - Database error has occurred
--   potbTypETRSfList (output)
--     A table results of entired row types of the EQUIP_TYPE_PARAM table.
--     Caller should check the poiStatus first before checking on the table
--     output. The potbTypETRSfList.COUNT will be > 0 if there is at least one
--     parameter found for the input equipment ID and the data will be ordered
--     by the found parameters' sequence #s.
--   psValueSearch1 (input)
--     Optional equipment safety check list name to be searched. If it's
--     NULL, records that match other input criteria are returned.
--   piInitCap (input)
--     Whether the equipment safety check name is initially capitalized (1,
--     default) or not (<> 1).
--
-- Returns
--   See output parameters above for details.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_sls_equip_safety_list (
  psEquipID		IN  equipment.equip_id%TYPE,
  poiStatus		OUT NUMBER,
  potbTypETRSfList	OUT tabTypETRSfList,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1);

-- =============================================================================
-- Function
--   get_sls_equip_safety_list
--
-- Description
--   Retrieve SLS equipment safety check list parameter names only according to
--   the input psEquipID, and psValueSearch1 criteria.
--
-- Parameters
--   psEquipID (input)
--     Equipment ID to be searched. The ID should be unique among different
--     application types. It will be validated using the EQUIPMENT table.
--   poiStatus (output)
--     Procedure returned status. Value is one of the following:
--       0 - Normal, no error occurred
--       C_WRONG_EQUIP - Input psEquipID is not found or the found application
--         type is different from the entered psApplType value.
--       < 0 - Database error has occurred
--   potbTypETNmSfList (output)
--     A table results of parameter names from the EQUIP_TYPE_PARAM table.
--     Caller should check the poiStatus first before checking on the table
--     output. The potbTypETRSfList.COUNT will be > 0 if there is at least one
--     parameter found for the input equipment ID and the data will be ordered
--     by the found parameters' sequence #s.
--   posEquipType (output)
--     Found equipment type for the search equipment ID criteria to be returned.
--   psValueSearch1 (input)
--     Optional equipment safety check list name to be searched. If it's
--     NULL, records that match other input criteria are returned.
--   piInitCap (input)
--     Whether the equipment safety check name is initially capitalized (1,
--     default) or not (<> 1).
--
-- Returns
--   See output parameters above for details.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_sls_equip_safety_list (
  psEquipID		IN  equipment.equip_id%TYPE,
  poiStatus		OUT NUMBER,
  potbTypETNmSfList	OUT tabTypETNmSfList,
  posEquipType		OUT equipment.equip_type%TYPE,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1);

-- =============================================================================
-- Function
--   get_trl_equip_safety_list
--
-- Description
--   Retrieve SLS trailer equipment safety check list rows according to
--   the input psValueSearch1 criteria.
--
-- Parameters
--   poiStatus (output)
--     Procedure returned status. Value is one of the following:
--       0 - Normal, no error occurred
--       < 0 - Database error has occurred
--   potbTypETRSfList (output)
--     A table results of item rows from the EQUIP_TYPE_PARAM table.
--     Caller should check the poiStatus first before checking on the table
--     output. The potbTypETRSfList.COUNT will be > 0 if there is at least one
--     parameter found and the data will be ordered by the found parameters'
--     sequence #s.
--   psValueSearch1 (input)
--     Optional equipment safety check list name to be searched. If it's
--     NULL, records that match other input criteria are returned.
--   piInitCap (input)
--     Whether the equipment safety check name is initially capitalized (1,
--     default) or not (<> 1).
--
-- Returns
--   See output parameters above for details.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_trl_equip_safety_list (
  poiStatus		OUT NUMBER,
  potbTypETRSfList	OUT tabTypETRSfList,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1);

-- =============================================================================
-- Function
--   get_trl_equip_safety_list
--
-- Description
--   Retrieve SLS trailer equipment safety check list rows according to
--   the input psValueSearch1 criteria.
--
-- Parameters
--   poiStatus (output)
--     Procedure returned status. Value is one of the following:
--       0 - Normal, no error occurred
--       < 0 - Database error has occurred
--   potbTypETNmSfList (output)
--     A table results of parameter names from the EQUIP_TYPE_PARAM table.
--     Caller should check the poiStatus first before checking on the table
--     output. The potbTypETNmSfList.COUNT will be > 0 if there is at least one
--     parameter found and the data will be ordered by the found parameters'
--     sequence #s.
--   psValueSearch1 (input)
--     Optional equipment safety check list name to be searched. If it's
--     NULL, records that match other input criteria are returned.
--   piInitCap (input)
--     Whether the equipment safety check name is initially capitalized (1,
--     default) or not (<> 1).
--
-- Returns
--   See output parameters above for details.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_trl_equip_safety_list (
  poiStatus		OUT NUMBER,
  potbTypETNmSfList	OUT tabTypETNmSfList,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1);

-- =============================================================================
-- Function
--   get_equip_safety_list
--
-- Description
--   This is an overloaded function. Retrieve the safety list row items from the
--   table EQUIP_TYPE_PARAM according to the input search criteria psApplType,
--   psEquipID, and psValueSearch1.
--
-- Parameters
--   psEquipID (input)
--     Equipment ID to be searched. The ID should be unique among different
--     application types. It will be validated using the EQUIPMENT table if
--     the application type criteria psApplType is not a trailer (TRL).
--   poiStatus (output)
--     Procedure returned status. Value is one of the following:
--       0 - Normal, no error occurred
--       C_WRONG_EQUIP - Input psEquipID is not found or the found application
--         type is different from the entered psApplType value.
--       < 0 - Database error has occurred
--   potbTypETRSfList (output)
--     A table results of entired row types of the EQUIP_TYPE_PARAM table.
--     Caller should check the poiStatus first before checking on the table
--     output. The potbTypETRSfList.COUNT will be > 0 if there is at least one
--     parameter found for the input equipment ID and the data will be ordered
--     by the found parameters' sequence #s.
--   psApplType (input)
--     Optional application type input. As of the inital version, only 'SOS',
--     'SLS', or 'TRL' (for SLS Trailer) value is supported. The input is used
--     to perform more validation by comparing with the application type from
--     the system according to the equipment ID if the application type is
--     SOS or SLS.
--   psValueSearch1 (input)
--     Optional equipment safety check list name to be searched. If it's
--     NULL, records that match other input criteria are returned.
--   piInitCap (input)
--     Whether the equipment safety check name is initially capitalized (1,
--     default) or not (<> 1).
--
-- Returns
--   See output parameters above for details.
--   
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_equip_safety_list (
  psEquipID		IN  equipment.equip_id%TYPE,
  poiStatus		OUT NUMBER,
  potbTypETRSfList	OUT tabTypETRSfList,
  psApplType		IN  equip_safety_hist.appl_type%TYPE DEFAULT NULL,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1);

-- =============================================================================
-- Function
--   get_equip_safety_list
--
-- Description
--   This is an overloaded function. Retrieve the safety list parameter names
--   from the table EQUIP_TYPE_PARAM according to the input search criteria
--   psApplType, psEquipID, and psValueSearch1.
--   It calls the overloaded get_equip_safety_list() to get all the rows that
--   match the criteria and only return the parameter names.
--
-- Parameters
--   psEquipID (input)
--     Equipment ID to be searched. The ID should be unique among different
--     application types. It will be validated using the EQUIPMENT table if
--     the application type criteria psApplType is not a trailer (TRL).
--   poiStatus (output)
--     Procedure returned status. Value is one of the following:
--       0 - Normal, no error occurred
--       C_WRONG_EQUIP - Input psEquipID is not found or the found application
--         type is different from the entered psApplType value.
--       < 0 - Database error has occurred
--   potbTypETNmSfList (output)
--     A table results of parameter names from the EQUIP_TYPE_PARAM table.
--     Caller should check the poiStatus first before checking on the table
--     output. The potbTypETNmSfList.COUNT will be > 0 if there is at least one
--     parameter found for the input equipment ID and the data will be ordered
--     by the found parameters' sequence #s.
--   posEquipType (output)
--     Returned equipment type that matches the input equipment ID criteria.
--   psApplType (input)
--     Optional application type input. As of the inital version, only 'SOS',
--     'SLS', or 'TRL' (for SLS Trailer) value is supported. The input is used
--     to perform more validation by comparing with the application type from
--     the system according to the equipment ID.
--   psValueSearch1 (input)
--     Optional equipment safety check list name to be searched. If it's
--     NULL, records that match other input criteria are returned.
--   piInitCap (input)
--     Whether the equipment safety check name is initially capitalized (1,
--     default) or not (<> 1).
--
-- Returns
--   See output parameters above for details.
--   
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_equip_safety_list (
  psEquipID		IN  equipment.equip_id%TYPE,
  poiStatus		OUT NUMBER,
  potbTypETNmSfList	OUT tabTypETNmSfList,
  posEquipType		OUT equipment.equip_type%TYPE,
  psApplType		IN  equip_safety_hist.appl_type%TYPE DEFAULT NULL,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1);

-- =============================================================================
-- Function
--   add_sos_equip_safety_hist
--
-- Description
--   This is an overloaded function.
--   Add SOS equipment safety check history record to EQUIP_SAFETY_HIST table
--   according to the input criteria prwTypSfHist.
--
-- Parameters
--   prwTypSfHist (input)
--     Equipment safety check history record to be added to the database
--   psName (input)
--     The parameter name to be added to the safety check history table. If
--     it's not provided, the seq field in the prwTypSfHist should be provided.
--     If it's provided, it will take precedence for the one in prwTypSfHist.
--   piCheckEquip (input)
--     Whether to validate the input equipment ID (1) or not (0, default).
--
-- Returns
--   0 - The addition of record action is performed successfully without errors.
--   1 - Input sApplType is invalid or input equipment ID is invalid or not
--       found.
--   1403 (C_NOT_FOUND) - Input safety check item sequence # is invalid.
--   <other values> - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION add_sos_equip_safety_hist (
  prwTypSfHist		IN equip_safety_hist%ROWTYPE,
  psName		IN equip_param.name%TYPE DEFAULT NULL,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER;

-- =============================================================================
-- Function
--   add_sos_equip_safety_hist
--
-- Description
--   This is an overloaded function.
--   Add SOS equipment safety check history record to EQUIP_SAFETY_HIST table
--   according to the input criteria ptbTypSfHist. The function calls
--   add_sos_equip_safety_hist('SOS', ...) to loop through all the records
--   in the SQL table.
--
-- Parameters
--   ptbTypSfHist (input)
--     Equipment safety check history table recordS to be added to the database
--   piCheckEquip (input)
--     Whether to validate the input equipment ID (1) or not (0, default).
--
-- Returns
--   0 - The addition of record action is performed successfully without errors.
--   1 - Input sApplType is invalid or input equipment ID is invalid or not
--       found.
--   1403 (C_NOT_FOUND) - Input safety check item sequence # is invalid.
--   <other values> - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION add_sos_equip_safety_hist (
  ptbTypSfHist		IN tabTypSfHist,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER;

-- =============================================================================
-- Function
--   add_sls_equip_safety_hist
--
-- Description
--   This is an overloaded function.
--   Add SLS equipment safety check history record to EQUIP_SAFETY_HIST table
--   according to the input criteria prwTypSfHist.
--
-- Parameters
--   prwTypSfHist (input)
--     Equipment safety check history record to be added to the database
--   psName (input)
--     The parameter name to be added to the safety check history table. If
--     it's not provided, the seq field in the prwTypSfHist should be provided.
--     If it's provided, it will take precedence for the one in prwTypSfHist.
--   piCheckEquip (input)
--     Whether to validate the input equipment ID (1) or not (0, default).
--
-- Returns
--   0 - The addition of record action is performed successfully without errors.
--   1 - Input sApplType is invalid or input equipment ID is invalid or not
--       found.
--   1403 (C_NOT_FOUND) - Input safety check item sequence # is invalid.
--   <other values> - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION add_sls_equip_safety_hist (
  prwTypSfHist		IN equip_safety_hist%ROWTYPE,
  psName		IN equip_param.name%TYPE DEFAULT NULL,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER;

-- =============================================================================
-- Function
--   add_sls_equip_safety_hist
--
-- Description
--   This is an overloaded function.
--   Add SLS equipment safety check history record to EQUIP_SAFETY_HIST table
--   according to the input criteria ptbTypSfHist. The function calls
--   add_sls_equip_safety_hist('SLS', ...) to loop through all the records
--   in the SQL table.
--
-- Parameters
--   ptbTypSfHist (input)
--     Equipment safety check history table recordS to be added to the database
--   piCheckEquip (input)
--     Whether to validate the input equipment ID (1) or not (0, default).
--
-- Returns
--   0 - The addition of record action is performed successfully without errors.
--   1 - Input sApplType is invalid or input equipment ID is invalid or not
--       found.
--   1403 (C_NOT_FOUND) - Input safety check item sequence # is invalid.
--   <other values> - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION add_sls_equip_safety_hist (
  ptbTypSfHist		IN tabTypSfHist,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER;

-- =============================================================================
-- Function
--   add_trl_equip_safety_hist
--
-- Description
--   This is an overloaded function.
--   Add trailer check history record to EQUIP_SAFETY_HIST table
--   according to the input criteria prwTypSfHist.
--
-- Parameters
--   prwTypSfHist (input)
--     Trailer check history record to be added to the database
--   psName (input)
--     The parameter name to be added to the trailer check history table. If
--     it's not provided, the seq field in the prwTypSfHist should be provided.
--     If it's provided, it will take precedence for the one in prwTypSfHist.
--   piCheckEquip (input)
--     Whether to validate the input equipment ID (1) or not (0, default).
--
-- Returns
--   0 - The addition of record action is performed successfully without errors.
--   1 - Input sApplType is invalid or input equipment ID is invalid or not
--       found.
--   1403 (C_NOT_FOUND) - Input trailer check item sequence # is invalid.
--   <other values> - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION add_trl_equip_safety_hist (
  prwTypSfHist		IN equip_safety_hist%ROWTYPE,
  psName		IN equip_param.name%TYPE DEFAULT NULL,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER;

-- =============================================================================
-- Function
--   add_trl_equip_safety_hist
--
-- Description
--   This is an overloaded function.
--   Add trailer check history record to EQUIP_SAFETY_HIST table
--   according to the input criteria ptbTypSfHist. The function calls
--   add_trl_equip_safety_hist('TRL', ...) to loop through all the records
--   in the SQL table.
--
-- Parameters
--   ptbTypSfHist (input)
--     Equipment safety check history table recordS to be added to the database
--   piCheckEquip (input)
--     Whether to validate the input equipment ID (1) or not (0, default).
--
-- Returns
--   0 - The addition of record action is performed successfully without errors.
--   1 - Input sApplType is invalid or input equipment ID is invalid or not
--       found.
--   1403 (C_NOT_FOUND) - Input trailer check item sequence # is invalid.
--   <other values> - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION add_trl_equip_safety_hist (
  ptbTypSfHist		IN tabTypSfHist,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER;

-- =============================================================================
-- Function
--   add_equip_safety_hist
--
-- Description
--   This is an overloaded function.
--   Add equipment safety check history to the EQUIP_SAFETY_HIST table
--   according to the input record prwTypSfHist which contents all columns
--   of the EQUIP_SAFETY_HIST table.
--
-- Parameters
--   sApplType (input)
--     Application type
--   prwTypSfHist (input)
--     Equipment safety check history record to be added to the database
--   psName (input)
--     The parameter name to be added to the safety check history table. If
--     it's not provided, the seq field in the prwTypSfHist should be provided.
--     If it's provided, it will take precedence for the one in prwTypSfHist.
--   piCheckEquip (input)
--     Whether to validate the input equipment ID (1) or not (0, default).
--
-- Returns
--   0 - The addition of record action is performed successfully without errors.
--   1 - Input sApplType is invalid or input equipment ID is invalid or not
--       found.
--   1403 (C_NOT_FOUND) - Input safety check item sequence # is invalid.
--   <other values> - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION add_equip_safety_hist (
  psApplType		IN equip_safety_hist.appl_type%TYPE,
  prwTypSfHist		IN equip_safety_hist%ROWTYPE,
  psName		IN equip_param.name%TYPE DEFAULT NULL,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER;

-- =============================================================================
-- Function
--   add_equip_safety_hist
--
-- Description
--   This is an overloaded function.
--   Add equipment safety check history to the EQUIP_SAFETY_HIST table
--   according to the input SQL table ptbTypSfHist which contents a list of
--   safety check history records of the EQUIP_SAFETY_HIST table. The function
--   calls the overloaded add_equip_safety_hist function with rwTypSfHist
--   parameter record which derives from each record in the SQL table.
--
-- Parameters
--   sApplType (input)
--     Application type
--   ptBTypSfHist (input)
--     Equipment safety check history table to be added to the database
--   piCheckEquip (input)
--     Whether to validate the input equipment ID (1) or not (0, default).
--
-- Returns
--   0 - The addition of record action is performed successfully without errors.
--   1 - Input sApplType is invalid or input equipment ID is invalid or not
--       found.
--   1403 (C_NOT_FOUND) - Input safety check item sequence # is invalid.
--   <other values> - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION add_equip_safety_hist (
  psApplType		IN equip_safety_hist.appl_type%TYPE,
  ptbTypSfHist		IN tabTypSfHist,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER;

-- =============================================================================
-- Function
--   get_truck_func_sort
--
-- Description
--   The function is used to retrieve the sorting orders of data conditions
--   from the LAS_TRUCK table. It's mainly used by the "Truck Status" CRT
--   screen functions but it can be used as needed somewhere else. The sorting
--   mechanism is as follows:
--     1) The truck which is still active is the 1st to be listed. "Active"
--        means that any of the truck area status (freezer/cooler/dry) is
--        still in "A" status or at least one pallet for the area has been
--        loaded. This might include "Loading" or "Waiting" status. "Waiting"
--	  status takes precedence if there exists at least one pallet in the
--        current loading door that is still being "selected".
--     2) The truck which hasn't been started yet is the 2nd to be listed.
--        "Not started" means that the total number of pallets and the
--        remaining pallets for all truck areas should be the same.
--     3) The truck which has been completed is the 3rd to be listed.
--        "Completed" means that all truck areas are in "C" statuses.
--     4) Anything else will be put to the last order. This includes the
--        "M"(apped) or no statuses for all truck areas.
--
-- Parameters
--   psTruck (input)
--     Truck # to be searched
--
-- Returns
--   1 - The specified truck is in active status.
--   2 - The specified truck is in "not start" status.
--   3 - The specified truck is in complete status.
--   4 - Any other status for the truck.
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION get_truck_func_sort (psTruck sls_load_map.truck_no%TYPE)
RETURN NUMBER;

-- =============================================================================
-- Function
--   insert_slt_action_log
--
-- Description
--   Insert a record to the SLT_ACTION_LOG table according to the input data
--   criteria. The table is mainly used for research and debug purposes.
--
-- Parameters
--   psAction (input)
--     Action name. It will be converted to all captial letters during add.
--   psMsgText (input)
--     Message text to be added
--   psMsgType (input)
--     Message text type to be added. Valid value is either INFO (default),
--     WARN, or FATAL.
--   psLogRequired (input)
--     Whether forced logging feature is turned on (Y) or off (N, default).
--     If the value is Y, logging will occur no matter whether the caller
--     commit action succeses or fails later.
--
-- Returns
--   none
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE insert_slt_action_log (
  psAction		IN slt_action_log.action%TYPE,
  psMsgText		IN slt_action_log.msg_text%TYPE,
  psMsgType		IN slt_action_log.msg_type%TYPE DEFAULT 'INFO',
  psLogRequired		IN VARCHAR2 DEFAULT 'N');

-- =============================================================================
-- Function
--   get_sls_mis_cases
--
-- Description
--   Retrieve missing cases for SLS processing. Missing cases come from the
--   SOS_SHORT table.
--
-- Parameters
--   piOption (input)
--     Search option (work with psExtraData)
--       1 - Float Seq
--       2 - Compartment Code
--       3 - Truck #
--       4 - Order sequence #
--   psTruck (input)
--     Truck #
--   tbMsCase (output)
--     Output of missing case records as table. Each record includes qty,
--     stop #, item #, cust pref vendor, item description, float #, and uom.
--   psExtraData (input)
--     The extra data can be one of the following:
--       <null> - This is the default. It means that we should search for all
--                floats.
--       length between 2 and 4 - We should search for records that
--                                match the truck and the float sequence data.
--       length is 1 - We should search for records that match the truck and
--                     the compartment code.
--       length between 8 and 11 - We should search for records that match the
--                                 truck and the order sequence #. 
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_sls_mis_cases (
  piOption    IN  NUMBER,
  psTruck     IN  sls_load_map.truck_no%TYPE,
  tbMsCase    OUT tabTypMissing,
  psExtraData IN  VARCHAR2 DEFAULT NULL);

-- =============================================================================
-- Function
--   get_sls_mis_weights
--
-- Description
--   Retrieve missing weights for SLS processing. Missing weights come from the
--   SOS_SHORT and/or ORDCW tables.
--
-- Parameters
--   psTruck (input)
--     Truck #
--   tbMsWeight (output)
--     Output of missing weight records as table. Each record includes item #,
--     cust pref vendor, item description, uom, and customer ID.
--   psExtraData (input)
--     The extra data can be one of the following:
--       <null> - This is the default. It means that we should search for all
--                floats.
--       length between 2 and 4 - We should search for records that
--                                match the truck and the float sequence data.
--       length is 1 - We should search for records that match the truck and
--                     the compartment code.
--       length between 8 and 11 - We should search for records that match the
--                                 truck and the order sequence #. 
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
--PROCEDURE get_sls_mis_weights (
--  psTruck     IN  sls_load_map.truck_no%TYPE,
--  tbMsWeight  OUT tabTypMissing,
--  psExtraData IN  VARCHAR2 DEFAULT NULL);

-- =============================================================================
-- Function
--   get_sls_mis_cswts
--
-- Description
--   Retrieve missing cases and/or weights for SLS processing. The procedure
--   basically unites the missing cases (from get_sls_mis_cases()) and missing
--   weights (from get_sls_mis_weights()) and set the appropriated flags.
--
-- Parameters
--   psTruck (input)
--     Truck #
--   tbMsInfo (output)
--     Output of missing case and/or weight records as table. Each record
--     includes item #, cust pref vendor, item description, uom, and customer
--     ID.
--   psExtraData (input)
--     The extra data can be one of the following:
--       <null> - This is the default. It means that we should search for all
--                floats.
--       length between 2 and 4 - We should search for records that
--                                match the truck and the float sequence data.
--       length is 1 - We should search for records that match the truck and
--                     the compartment code.
--       length between 8 and 11 - We should search for records that match the
--                                 truck and the order sequence #. 
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
--PROCEDURE get_sls_mis_cswts (
--  psTruck     IN  sls_load_map.truck_no%TYPE,
--  tbMsInfo    OUT tabTypMissing,
--  psExtraData IN  VARCHAR2 DEFAULT NULL);

-- =============================================================================
-- Function
--   get_type_params
--
-- Description
--   Retrieve some columns from EQUIP_TYPE_PARAM and EQUIP_PARAM tables
--   according to the input equipment type (psEquipType) value.
--
-- Parameters
--   tbTypFTypParam (output)
--     Output of equipment parameter fields as a table include parameter name, 
--     parameter name description and its abbreviation
--   psEquipType (input)
--     Truck #. Default to retrieve all parameters for all equipment types.
--   psInitCap (input)
--     Whether to make (Y, default) the 1st character of the found equipment
--     parameter name capital letter (while the rest is small letters) or not
--     (N or other value)
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_type_params (
  tbTypFTypParam OUT tabTypFTypParam,
  psEquipType    IN  equip_type_param.equip_type%TYPE DEFAULT NULL,
  psInitCap	 IN  VARCHAR2 DEFAULT 'Y');

-- =============================================================================
-- Function
--   get_type_params
--
-- Description
--   Retrieve equipment parameter names from EQUIP_TYPE_PARAM and EQUIP_PARAM 
--   tables according to the input equipment type (psEquipType) value.
--
-- Parameters
--   tbTypPTypParam (output)
--     Output of equipment parameter names as a table.
--   psEquipType (input)
--     Truck #. Default to retrieve all parameters for all equipment types.
--   psInitCap (input)
--     Whether to make (Y, default) the 1st character of the found equipment
--     parameter name capital letter (while the rest is small letters) or not
--     (N or other value)
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_type_params (
  tbTypPTypParam OUT tabTypPTypParam,
  psEquipType    IN  equip_type_param.equip_type%TYPE DEFAULT NULL,
  psInitCap	 IN  VARCHAR2 DEFAULT 'Y');

-- =============================================================================
-- Function
--   get_float_summary
--
-- Description
--   Retrieve float summary information. Summary information include truck zone,
--   float #, loader status and selector status.
--
-- Parameters
--   psTruck (input)
--     Truck #
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_float_summary (
  psTruck	    IN  las_pallet.truck%TYPE,
  tbTypFloatSummary OUT tabTypFloatSummary);

-- =============================================================================
-- Function
--   get_basic_loader_info
--
-- Description
--   Retrieve general batch information for loader and some syspar setups.
--
-- Parameters
--   psTruck (input)
--     Truck #
--   psFloat (input)
--     Float sequence 
--   psUser (input)
--     Current user
--   porcTypLoaderLM (output)
--     A record of loader LM related information back to caller if any.
--     Information includes related syspar flags and loader batch information.
--   poiStatus (output)
--     0 - Loader batch retrieval action is successful.
--     C_LM_INVALID_USERID - Current user ID is not in the system.
--     C_NO_LM_BATCH_FOUND - Cannot find the loader batch.
--     <0 - Database error has occurred.
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_basic_loader_info (
  psTruck		IN  las_pallet.truck%TYPE,
  psFloat		IN  las_pallet.truck%TYPE,
  psUser		IN  usr.user_id%TYPE DEFAULT REPLACE(USER, 'OPS$', ''),
  porcTypLoaderLM	OUT recTypLoaderLM,
  poiStatus		OUT NUMBER);

-- =============================================================================
-- Function
--   get_active_batch
--
-- Description
--   Retrieve an existing active batch for current user along with extra
--   information for the batch and some syspar setups.
--
-- Parameters
--   porcTypLoaderLM (output)
--     A record of loader LM related information back to caller if any.
--     Information includes related syspar flags and loader batch information.
--   poiStatus (output)
--     0 - The active batch retrieval action is successful.
--     <0 - Database error has occurred.
--     C_LM_NOT_ACTIVE - LM flag is not active.
--     C_NO_LM_BATCH_FOUND - Cannot find the active batch.
--   psUser (input)
--     Current User ID
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_active_batch (
  porcActiveLM	OUT recTypLoaderLM,
  poiStatus     OUT NUMBER,
  psUser        IN  usr.user_id%TYPE DEFAULT REPLACE(USER, 'OPS$', ''));

-- =============================================================================
-- Function
--   write_lm_float_stop
--
-- Description
--   Complete a batch by using pl_lm1.create_schedule().
--
-- Parameters
--   psUser (input)
--     Current user
--   pdtStopTime (input)
--     Last stop time for a to-be-found batch.
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION write_lm_float_stop (
  pdtStopTime   IN  batch.actl_stop_time%TYPE,
  psUser        IN  usr.user_id%TYPE DEFAULT REPLACE(USER, 'OPS$', ''))
RETURN NUMBER;

-- =============================================================================
-- Function
--   write_lm_float_start
--
-- Description
--   Retrieve float summary information. Summary information include truck zone,
--   float #, loader status and selector status.
--
-- Parameters
--   psTruck (input)
--     Truck #
--   psFloat (input)
--     Float sequence 
--   psUser (input)
--     Current user
--   psAction (input)
--     Whether the batch is to-be-loaded (L, default) or to-be-unloaded (U).
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION write_lm_float_start (
  psTruck       IN  las_pallet.truck%TYPE,
  psFloat       IN  las_pallet.truck%TYPE,
  psUser        IN  usr.user_id%TYPE DEFAULT REPLACE(USER, 'OPS$', ''),
  psAction      IN  VARCHAR2 DEFAULT 'L')
RETURN NUMBER;

-- =============================================================================
-- Function
--   get_truck_accessory_list
--
-- Description
--   Retrieve previously-saved truck accessory list if any according to the
--   input criteria.
--
-- Parameters
--   psTruck (input)
--     Truck #
--   potbAccessory (output)
--     An array of truck accessory to be returned if any
--   psCompartment (input)
--     Compartment for the truck to be searched. If no input, search for all
--     compartments of the truck.
--   psSourceType (input)
--     Source type to be searched. 'O' means searching for Outbound accessory
--     information only. 'I' means searching for Inbound accessory information
--     only or No Value means searching for both Outbound and Inbound.
--   piManifest (input)
--     Manifest # to be searched. The value is only used for inbound. If no
--     input, search for all manifests of the truck.
--   psRoute (input)
--     Route # to be searched. If no input, search for all routes of the truck.
--   psIgnrBarcode (input)
--     Whether to retrieve total counts for an accessory regardless of some
--     of records have barcodes and some don't for the accessory (Y) or not
--     (N, default.)
--   psInitCap (input)
--     Determine whether the found accessory name should be capitalized for
--     the 1st character (Y, default) or not (<> Y).
--   piIncNoAcc (input)
--     Determine whether to include only the accessory history for the truck
--     (0, default) or also include all other accessory that has no history
--     for the truck.
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_truck_accessory_list (
  psTruck       IN  las_truck_equipment.truck%TYPE,
  potbAccessory OUT tabTypTruckAccessory,
  psCompartment IN  las_truck_equipment.compartment%TYPE DEFAULT NULL,
  piManifest    IN  las_truck_equipment.manifest_no%TYPE DEFAULT NULL,
  psRoute       IN  las_truck_equipment.route_no%TYPE DEFAULT NULL,
  psIgnrBarcode	IN  VARCHAR2 DEFAULT 'N',
  psInitCap     IN  VARCHAR2 DEFAULT 'Y',
  piIncNoAcc    IN  NUMBER DEFAULT 0);

-- =============================================================================
-- Function
--   get_compartment_status
--
-- Description
--   Retrieve compartment statuses for dry, cooler and freezer compartments
--   for the input truck.
--
-- Parameters
--   psTruck (input)
--     Truck #
--   posDry (output)
--     Return dry compartment status. 'X' if the compartment is not available
--     for the truck. 'B' if database error occured (include no data found)
--     or compartment status.
--   posCooler (output)
--     Return cooler compartment status. 'X' if the compartment is not
--     available for the truck. 'B' if database error occured (include no data
--     found) or compartment status.
--   posFreezer (output)
--     Return freezer compartment status. 'X' if the compartment is not
--     available for the truck. 'B' if database error occured (include no data
--     found) or compartment status.
--   posTruck (output)
--     Return truck status. 'B' if database error occurred.
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_compartment_status(
  psTruck	IN  las_pallet.truck%TYPE,
  posDry	OUT VARCHAR2,
  posCooler	OUT VARCHAR2,
  posFreezer	OUT VARCHAR2,
  posTruck	OUT VARCHAR2);

-- =============================================================================
-- Function
--   get_sls_label_type
--
-- Description
--   Retrieve the label type for the scanned label. The procedure is mainly
--   used in determining what kind of label the user is working on so
--   appropriated action is taken.
--
-- Parameters
--   psFloatLabel (input)
--     The label input
--   piOption (input)
--     Extra option as input to indentify specific label
--   posField1 (output)
--     Return the front part of the label (normally truck #) if the label has
--     2 parts which are separated by at least one space
--   posField2 (output)
--     Return the rear part of the label (normally pallet) if the label has
--     2 parts which are separated by at least one space
--   poiLblType (output)
--     The returned label type as a numeric value
--   psTruck (input)
--     Truck #
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
--PROCEDURE get_sls_label_type (
--  psFloatLabel		IN  VARCHAR2,
--  piOption		IN  NUMBER,
--  posField1		OUT VARCHAR2,
--  posField2		OUT VARCHAR2,
--  poiLblType		OUT NUMBER,
--  psTruck		IN  sls_load_map.truck_no%TYPE DEFAULT NULL);

-- =============================================================================
-- Function
--   get_dock_pallets
--
-- Description
--   The function retrieves all the pallets in the dock for the specified
--   truck psTruck. The retrieved pallets will be in sorting orders: 1) area
--   sorting orders from the LAS_PALLET_SORT table; 2) pallet numeric orders.
--   A pallet is in the dock when all the items inside it are either picked
--   or shorted.
--
-- Parameters
--   psTruck (input)
--     The truck # input
--   potbPallets (output)
--     The pallets in the dock if any are returned. The zone value will be empty
--     here since the pallets are still in the dock and not loaded yet.
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_dock_pallets (
   psTruck	IN  route.truck_no%TYPE,
   potbPallets	OUT tabPalInfo);

-- =============================================================================
-- Function
--   get_loaded_pallets
--
-- Description
--   The function retrieves all the pallets and their corresponding loaded zones
--   that have been loaded for the specified truck psTruck. The retrieved
--   pallets will be in sorting orders: 1) the latest loaded pallet is at the
--   top; 2) area sorting orders from the LAS_PALLET_SORT table; 3) pallet
--   numeric orders.
--
-- Parameters
--   psTruck (input)
--     Truck #
--   potbPallets (output)
--     The loaded pallets if any are returned. The zone value will have the
--     zone # (without the Z) where it was loaded.
--   piZone (input)
--     If the value is present, only those loaded pallets that are in the
--     specified zone are returned if any.
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_loaded_pallets (
   psTruck	IN  route.truck_no%TYPE,
   potbPallets	OUT tabPalInfo,
   piZone	IN  NUMBER DEFAULT NULL);

-- =============================================================================
-- Function
--   get_trailer_notes
--
-- Description
--   The function retrieves all available trailer notes for the specified
--   truck from LAS_TRUCK table. If no note is available, the system will
--   look for historical notes from SLS_NOTE_HIST table.
--
-- Parameters
--   psTruck (input)
--     Truck #
--   potbNotes (output)
--     The trailer notes if any are returned.
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_trailer_notes (
   psTruck	IN  route.truck_no%TYPE,
   potbNotes	OUT tabNoteInfo);

-- =============================================================================
-- Function
--   get_in_selection_pallets
--
-- Description
--   Retrieve pallets from LAS_PALLET table for the input truck psTruck that
--   are still in selection (selection_status = 'S').
--   The pallets are sorted by the sorting order from LAS_PALLET_SORT table
--   according to the 1st character of the palletno. If the 1st sorted order
--   is the same between 2 different pallets, the pallets are then sorted in
--   pallet # ascending orders.
--   If input zone # piZone is provided, the returned table only includes
--   pallets for the specified zone. Otherwise, it include all zones.
--
-- Parameters
--   psTruck (input)
--     Truck #
--   poiNumPallets (output)
--     Return # of pallets found for the truck
--   potbPallets (output)
--     Return an array of pallets found for the truck. The total # is in
--     poiNumPallets
--   piZone (input)
--     If piZone is NULL, get all loaded pallets for the input truck psTruck;
--     otherwise, get loaded pallets for the specified zone piZone for the
--     input truck psTruck only.
--   piNoDuplicated (input)
--     Whether if duplicated pallets should (not null) or shouldn't (null) be
--     in the returned array of pallets
--
-- Returns
--   See output paramaters above for details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_in_selection_pallets (
  psTruck	route.truck_no%TYPE,
  poiNumPallets	OUT NUMBER,
  potbPallets	OUT pl_nos.tabTypFloatSummary,
  piZone	IN  NUMBER DEFAULT NULL,
  piNoDuplicate	IN  NUMBER DEFAULT NULL);

-- =============================================================================
-- Function
--   get_total_truck_count
--
-- Description
--   Retrieve the total # of trucks according to the input SQL statement (where
--   clause.) The function uses the DBMS_SQL built-in package to do the job.
--
-- Parameters
--   psStmt (input)
--     Where clause statement(s) to be executed
--
-- Returns
--   >= 0	# of trucks returned
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION get_total_truck_count (psStmt	IN  VARCHAR2)
RETURN NUMBER;

-- =============================================================================
-- Function
--   get_dynamic_one_value
--
-- Description
--   Retrieve the specific value according to the dynamic execution of the 
--   input SQL statement. Return the execution result as a string (only one
--   and 1st string is returned if the dynamic execution returns more than one
--   rows of the value.
--
-- Parameters
--   psStmt (input)
--     Where clause statement(s) to be executed
--   piAction (input)
--     The action to be taken after the execution of the dynamic SQL statement.
--       1: The one-row query result should be treated as # of total rows
--          returned for the execution of the SQL statement.
--       2: The one-row query result should be treated as a string value
--          returned for the execution of the SQL statement.
--   piValueSize (input)
--     The maximum length of the string result that is defined for the returned
--     result as a string value. If the value is not specified, it is defaulted
--     to 4000.
--
-- Returns
--   >= 0	# of trucks returned
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION get_dynamic_one_value (
  psStmt        IN  VARCHAR2,
  piAction      IN  NUMBER,
  piValueSize   IN  NUMBER DEFAULT 4000)
RETURN VARCHAR2;

-- =============================================================================
-- Function
--   get_sls_load_map_queue
--
-- Description
--   Retrieve the printer queue name for the load map report according to the
--   input psWhere value.
--
-- Parameters
--   psWhere (input)
--     Syspar flag name (printer queue related) of LAS_CONFIG table. If it's
--     empty (default), the system will retrieve the queue name from the
--     AUTOMAPPTR syspar flag; otherwise the queue name is from the psWhere
--     value (i.e., currently MAPPRINTER is the only supported one.)
--   psQueueOnly (input)
--     The flag is used to indicate to the function whether all the parameters
--     listed on the queue should be returned (N) if they exists or only the
--     queue name should be returned (Y, default).
--
-- Returns
--   The printer queue name with or without its flags or NULL
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION get_sls_load_map_queue (
  psWhere	IN  VARCHAR2 DEFAULT NULL,
  psQueueOnly	IN  VARCHAR2 DEFAULT 'Y')
RETURN VARCHAR2;

-- =============================================================================
-- Function
--   last_query
--
-- Description
--   The procedure retrieves the condition/where part of the SELECT SQL
--   statement from the input psStmt and put the condition to output variable
--   posCond. The SELECT SQL statement, if present, must be in a valid SQL
--   statement format. Namely, it should have something like 'select ... from
--   ... [where ...] [group by ...] [having ...] [order by ...]' formats. The
--   statement(s) between [ and ] are optional. The procedure doesn't support
--   subquery statement(s) after the first 'where' word. If piAddSeq is 0
--   (default), it means that the next print query sequence will be generated
--   and the resulting condition statement(s) in posCond will be put into
--   the PRINT_QUERY table (the insertion will be automatically commited) and
--   the not -1 poiSeq value is returned. Procedure processing result is
--   returned as in poiStatus. If psAddStmt is present, it will be added to
--   the resulting posCond by connecting through the psAddStmtConnector
--   value.
--
-- Parameters
--   psStmt (input)
--     Valid SELECT SQL statement to be extracted for its condition statement(s)
--   posCond (output)
--     The extracted conditional statement(s)
--   poiSeq (output)
--     The next PRINT_QUERY table sequence to be returned if piAddSeq is used
--   poiStatus (output)
--     Return status of processing the procedure.
--       0: Successful
--      -1: Unable to get next PRINT_QUERY table sequence
--      -2: Unable to update to new condition to PRINT_QUERY table for the
--          found sequence
--      -3: Unable to add the next condition to the PRINT_QUERY table
--   piAddSeq (input)
--     If the value is 0 (default), the next sequence will be generated for
--     the PRINT_QUERY table and extracted condition will be put there
--   psAddStmt (input)
--     Any addition condition statement that user wants to add to the extracted
--     conditional statement(s) from the input psStmt. Default is NULL.
--   psAddStmtConnector (input)
--     If psAddStmt is present, what statement connector to use to connect it
--     to the extracted conditional statement(s). Default is 'AND'. Acceptable
--     value can be 'OR', or 'NOT', etc..
--
-- Returns
--   See output parameters above for more details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE last_query (
  psStmt		IN  VARCHAR2,
  posCond		OUT VARCHAR2,
  poiSeq		OUT NUMBER,
  poiStatus		OUT NUMBER,
  piAddSeq		IN  NUMBER DEFAULT 0,
  psAddStmt		IN  VARCHAR2 DEFAULT NULL,
  psAddStmtConnector	IN  VARCHAR2 DEFAULT 'AND');

-- =============================================================================
-- Function
--   get_report_info
--
-- Description
--   The procedure retrieves information about the input report psRptName from
--   the PRINT_REPORTS table and put to porwRptInfo. According to the
--   PRINT_REPORTS.queue_type and input psRqstUser, it also retrieves the
--   default printer queue name if any for the user.
--
-- Parameters
--   psRptName (input)
--     Report name
--   porwRptInfo (output)
--     The report information as PRINT_REPORTS%ROWTYPE or NULL
--   posUser (output)
--     The user ID who is set up to use a default printer for the report. It
--     will be the same as the user who is calling the procedure if no other
--     user ID is used.
--   posUserQueue (output)
--     The default user printer queue name for posUser or psRqstUser
--   psRqstUser (input)
--     The user ID who is used to get the default printer queue. If it's not
--     set, the procedure calling user ID is used.
--
-- Returns
--   See output parameters above for more details
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_report_info (
  psRptName     IN  print_reports.report%TYPE,
  porwRptInfo   OUT print_reports%ROWTYPE,
  porwQueueInfo	OUT print_queues%ROWTYPE,
  posUser       OUT print_report_queues.user_id%TYPE,
  posUserQueue  OUT print_report_queues.queue%TYPE,
  psRqstUser	IN  usrauth.user_id%TYPE DEFAULT REPLACE(USER, 'OPS$', ''));

-- =============================================================================
-- Function
--   get_min_truck_zone
--
-- Description
--   Retrieve the minimum truck zone for SLS functions.
--
-- Parameters
--   none
--
-- Returns
--   From constant C_MIN_FLOAT_SEQ_ZONE.
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION get_min_truck_zone RETURN NUMBER;

-- =============================================================================
-- Function
--   get_max_truck_zone
--
-- Description
--   Retrieve the maximum truck zone for SLS functions.
--
-- Parameters
--   none
--
-- Returns
--   From constant C_MAX_FLOAT_SEQ_ZONE.
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION get_max_truck_zone RETURN NUMBER;

-- =============================================================================
-- Function
--   get_map_status
--
-- Description
--   Get mapping status for the input truck
--
-- Parameters
--   psTruck (input)
--     Truck # to be searched
--
-- Returns
--   Y - if the truck is mapped or N if not
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION get_map_status (psTruck       IN  las_truck.truck%TYPE)
RETURN VARCHAR2;

-- ******************** <End of Package Specifications> ************************

END pl_nos;
/
SHOW ERRORS;

CREATE OR REPLACE PACKAGE BODY swms.pl_nos AS

-- ***************************** <Package Body> ********************************

-- ************************** <Constant Definitions> ***************************

-- ********************** <Private Variable Definitions> ***********************

-- ********************** <Function/Procedure Prototypes> **********************

-- ********************** <Private Database Cursors> ***************************

--CURSOR c_get_door(csTruck sls_load_map.truck_no%TYPE,
--                  csArea  las_pallet.palletno%TYPE) IS
--  SELECT DECODE(csArea,
--                'F', DECODE(f_door,
--                            NULL, DECODE(c_door, NULL, d_door, c_door),
--                            f_door),
--                'C', DECODE(c_door,
--                            NULL, DECODE(f_door, NULL, d_door, f_door),
--                            c_door),
--                'D', DECODE(d_door,
--                            NULL, DECODE(f_door, NULL, d_door, f_door),
--                            d_door)) door
--  FROM route
--  WHERE truck_no = csTruck;

-- -----------------------------------------------------------------------------

--CURSOR c_get_las_pallet_asc (
--  csTruck        sls_load_map.truck_no%TYPE DEFAULT NULL,
--  csLoadStatus	 las_pallet.loader_status%TYPE DEFAULT '*',
--  csSelectStatus las_pallet.selection_status%TYPE DEFAULT 'S',
--  ciZone         sls_load_map.map_zone%TYPE DEFAULT NULL,
--  csLoader       las_truck.loader%TYPE DEFAULT NULL,
--  csPallet       las_pallet.palletno%TYPE DEFAULT NULL,
--  csBatch        batch.batch_no%TYPE DEFAULT NULL) IS
--  SELECT truck,
--         LTRIM(RTRIM(v.palletno)) palletno,
--         DECODE(INSTR(LTRIM(RTRIM(v.truck_zone)), 'Z'),
--                0, SUBSTR(LTRIM(RTRIM(v.truck_zone)),
--                          LENGTH(LTRIM(RTRIM(v.truck_zone))), 1),
--                REPLACE(LTRIM(RTRIM(v.truck_zone)), 'Z', '')) truck_zone,
--         RTRIM(v.loader_status) loader_status,
--         RTRIM(v.selection_status) selection_status,
--         v.sort_seq, RTRIM(v.batch) batch,
--         v.upd_date, v.status, v.selector_id
--  FROM v_las_pallet v
--  WHERE ((csTruck IS NULL) OR
--         ((csTruck IS NOT NULL) AND (v.truck = csTruck)))
--  AND   (((csLoadStatus = 'X') AND (LTRIM(RTRIM(loader_status)) IS NULL)) OR
--         ((csLoadStatus <> 'X') AND
--          (((csLoadStatus = '*') AND (loader_status = '*')) OR
--           (csLoadStatus <> '*'))))
--  AND   (((csSelectStatus = 'X') AND
--          (LTRIM(RTRIM(selection_status)) IS NULL)) OR
--         ((csSelectStatus <> 'X') AND
--          (((csSelectStatus = 'S') AND (selection_status = 'S')) OR
--           ((csSelectStatus = 'W') AND (selection_status = 'W')) OR
--           ((csSelectStatus = 'C') AND (selection_status = 'C')) OR
--           (csSelectStatus <> 'S'))))
--  AND   ((csLoader IS NULL) OR
--         ((csLoader IS NOT NULL) AND
--          (REPLACE(LTRIM(RTRIM(upd_user)), 'OPS$', '') =
--           REPLACE(csLoader, 'OPS$', ''))))
--  AND   ((csPallet IS NULL) OR
--         ((csPallet IS NOT NULL) AND (LTRIM(RTRIM(palletno)) = csPallet)))
--  AND   ((csBatch IS NULL) OR
--         ((csBatch IS NOT NULL) AND (LTRIM(RTRIM(batch)) = csBatch)))
--  AND   ((ciZone IS NULL) OR
--         ((ciZone IS NOT NULL) AND
--          (TO_NUMBER(DECODE(INSTR(LTRIM(RTRIM(v.truck_zone)), 'Z'),
--                     0, SUBSTR(LTRIM(RTRIM(v.truck_zone)),
--                               LENGTH(LTRIM(RTRIM(v.truck_zone))), 1),
--                     REPLACE(LTRIM(RTRIM(v.truck_zone)), 'Z', ''))) =
--           ciZone)))
--  ORDER BY TO_NUMBER(DECODE(INSTR(LTRIM(RTRIM(v.truck_zone)), 'Z'),
--                            0, SUBSTR(LTRIM(RTRIM(v.truck_zone)),
--                                      LENGTH(LTRIM(RTRIM(v.truck_zone))), 1),
--                            REPLACE(LTRIM(RTRIM(v.truck_zone)), 'Z', ''))),
--           v.upd_date, v.sort_seq,
--           TO_NUMBER(SUBSTR(v.palletno, 2));

-- -----------------------------------------------------------------------------

--CURSOR c_get_las_pallet_desc (
--  csTruck        sls_load_map.truck_no%TYPE DEFAULT NULL,
--  csLoadStatus	 las_pallet.loader_status%TYPE DEFAULT '*',
--  csSelectStatus las_pallet.selection_status%TYPE DEFAULT 'S',
--  ciZone         sls_load_map.map_zone%TYPE DEFAULT NULL,
--  csLoader       las_truck.loader%TYPE DEFAULT NULL,
--  csPallet       las_pallet.palletno%TYPE DEFAULT NULL,
--  csBatch        batch.batch_no%TYPE DEFAULT NULL) IS
--  SELECT truck,
--         LTRIM(RTRIM(v.palletno)) palletno,
--         DECODE(INSTR(LTRIM(RTRIM(v.truck_zone)), 'Z'),
--                0, SUBSTR(LTRIM(RTRIM(v.truck_zone)),
--                          LENGTH(LTRIM(RTRIM(v.truck_zone))), 1),
--                REPLACE(LTRIM(RTRIM(v.truck_zone)), 'Z', '')) truck_zone,
--         RTRIM(v.loader_status) loader_status,
--         RTRIM(v.selection_status) selection_status,
--         v.sort_seq, RTRIM(v.batch) batch,
--         v.upd_date, v.status, v.selector_id
--  FROM v_las_pallet v
--  WHERE ((csTruck IS NULL) OR
--         ((csTruck IS NOT NULL) AND (v.truck = csTruck)))
--  AND   (((csLoadStatus = 'X') AND (LTRIM(RTRIM(loader_status)) IS NULL)) OR
--         ((csLoadStatus <> 'X') AND
--          (((csLoadStatus = '*') AND (loader_status = '*')) OR
--           (csLoadStatus <> '*'))))
--  AND   (((csSelectStatus = 'X') AND
--          (LTRIM(RTRIM(selection_status)) IS NULL)) OR
--         ((csSelectStatus <> 'X') AND
--          (((csSelectStatus = 'S') AND (selection_status = 'S')) OR
--           ((csSelectStatus = 'W') AND (selection_status = 'W')) OR
--           ((csSelectStatus = 'C') AND (selection_status = 'C')) OR
--           (csSelectStatus <> 'S'))))
--  AND   ((csLoader IS NULL) OR
--         ((csLoader IS NOT NULL) AND
--          (REPLACE(LTRIM(RTRIM(upd_user)), 'OPS$', '') =
--           REPLACE(csLoader, 'OPS$', ''))))
--  AND   ((csPallet IS NULL) OR
--         ((csPallet IS NOT NULL) AND (LTRIM(RTRIM(palletno)) = csPallet)))
--  AND   ((csBatch IS NULL) OR
--         ((csBatch IS NOT NULL) AND (LTRIM(RTRIM(batch)) = csBatch)))
--  AND   ((ciZone IS NULL) OR
--         ((ciZone IS NOT NULL) AND
--          (TO_NUMBER(DECODE(INSTR(LTRIM(RTRIM(v.truck_zone)), 'Z'),
--                     0, SUBSTR(LTRIM(RTRIM(v.truck_zone)),
--                               LENGTH(LTRIM(RTRIM(v.truck_zone))), 1),
--                     REPLACE(LTRIM(RTRIM(v.truck_zone)), 'Z', ''))) =
--           ciZone)))
--  ORDER BY TO_NUMBER(DECODE(INSTR(LTRIM(RTRIM(v.truck_zone)), 'Z'),
--                            0, SUBSTR(LTRIM(RTRIM(v.truck_zone)),
--                                      LENGTH(LTRIM(RTRIM(v.truck_zone))), 1),
--                            REPLACE(LTRIM(RTRIM(v.truck_zone)), 'Z', ''))),
--           NVL(v.upd_date, TO_DATE('01011980', 'MMDDYYYY')) DESC, v.sort_seq,
--           TO_NUMBER(SUBSTR(v.palletno, 2));

-- -----------------------------------------------------------------------------

-- ********************** <Private Functions/Procedures> ***********************

-- =============================================================================
-- Function
--   insert_slt_action_log_auto
--
-- Description
--   Insert a record to the SLT_ACTION_LOG table according to the input data
--   criteria. The table is mainly used for research and debug purposes. The
--   function includes a autonomous clause which means that the input data
--   will be logged to the table regarless that the caller's commit action
--   later being success or fail.
--
-- Parameters
--   psAction (input)
--     Action name. It will be converted to all captial letters during add.
--   psMsgText (input)
--     Message text to be added
--   psMsgType (input)
--     Message text type to be added. Valid value is either INFO (default),
--     WARN, or FATAL.
--
-- Returns
--   none
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE insert_slt_action_log_auto (
  psAction              IN slt_action_log.action%TYPE,
  psMsgText             IN slt_action_log.msg_text%TYPE,
  psMsgType             IN slt_action_log.msg_type%TYPE DEFAULT 'INFO') IS
  sMsgType		VARCHAR2(1) := NULL;
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  sMsgType := UPPER(SUBSTR(psMsgType, 1, 1));
  IF UPPER(psMsgType) NOT IN ('INFO', 'WARN', 'FATAL') THEN
    sMsgType := 'I';
  END IF;

  BEGIN
    INSERT INTO slt_action_log
      (seq, action,msg_type, msg_text,
       add_date, add_user)
      VALUES (
       slt_action_log_seq.nextval, UPPER(psAction), sMsgType, psMsgText,
       SYSDATE, REPLACE(USER, 'OPS$', ''));
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
  END;
END;
-- -----------------------------------------------------------------------------

-- *********************** <Public Functions/Procedures> ***********************

FUNCTION check_equip(
  psEquipID		IN equipment.equip_id%TYPE,
  psApplType		IN equipment.appl_type%TYPE DEFAULT 'ALL')
RETURN NUMBER IS
  iExists		NUMBER := 0;
BEGIN
  SELECT 1 INTO iExists 
  FROM equipment
  WHERE equip_id = psEquipID
  AND   ((psApplType = 'ALL') OR
         ((psApplType <> 'ALL') AND (appl_type = psApplType)));

  RETURN 0;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    BEGIN
      SELECT 1 INTO iExists 
      FROM equipment
      WHERE equip_id = psEquipID
      AND   ((psApplType = 'ALL') OR
             (psApplType IN ('SOS', 'SLS') AND (appl_type = 'SOL')));
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN C_WRONG_EQUIP;
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;
  WHEN OTHERS THEN
    RETURN SQLCODE;
END;
-- -----------------------------------------------------------------------------

FUNCTION login_equip(
  psEquipID		IN equipment.equip_id%TYPE,
  psApplType		IN equipment.appl_type%TYPE DEFAULT 'ALL',
  psUserID		IN sos_usr_config.user_id%TYPE
                             DEFAULT REPLACE(USER, 'OPS$', ''),
  psUpdateConfig	IN VARCHAR2 DEFAULT 'Y')
RETURN NUMBER IS
  sApplType		equipment.appl_type%TYPE := psApplType;
  sUsingUser		sos_usr_config.user_id%TYPE := NULL;
  CURSOR c_get_equip_info(
    csEquipID  equipment.equip_id%TYPE,
    csApplType equipment.appl_type%TYPE) IS
    SELECT 'SOS' appl_type, user_id inuse_user
    FROM sos_usr_config
    WHERE pallet_jack_id = csEquipID
    AND   csApplType IN ('SOS', 'SOL')
    UNION
    SELECT 'SLS' appl_type, user_id inuse_user
    FROM las_usr_config
    WHERE pallet_jack_id = csEquipID
    AND   csApplType IN ('SLS', 'SOL');
BEGIN
  -- Retrieve application type for the equipment ID
  BEGIN
    SELECT appl_type
    INTO sApplType
    FROM equipment
    WHERE equip_id = psEquipID;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN C_WRONG_EQUIP;
  END;

  -- See if the equipment is being used
  OPEN c_get_equip_info(psEquipID, sApplType);
  FETCH c_get_equip_info INTO sApplType, sUsingUser;
  IF c_get_equip_info%FOUND THEN
    -- The equipment might be being used
    IF sUsingUser IS NOT NULL THEN
      CLOSE c_get_equip_info;
      RETURN C_EQUIP_IN_USE;
    END IF;
  END IF;
  CLOSE c_get_equip_info;
    
  IF psUpdateConfig = 'Y' THEN
    IF sApplType IN ('SOS', 'SOL') THEN
      BEGIN
        UPDATE sos_usr_config
          SET pallet_jack_id = psEquipID
          WHERE user_id = psUserID;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RETURN C_LM_INVALID_USERID;
        WHEN OTHERS THEN
          RETURN SQLCODE;
      END;
    END IF;
    IF sApplType IN ('SLS', 'SOL') THEN
      BEGIN
        UPDATE las_usr_config
          SET pallet_jack_id = psEquipID
          WHERE user_id = psUserID;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RETURN C_LM_INVALID_USERID;
        WHEN OTHERS THEN
          RETURN SQLCODE;
      END;
    END IF;
  END IF;

  BEGIN
    insert_slt_action_log('PL_NOS_LOGIN_EQUIP',
      'User ' || psUserID || ' logged into equipment ' || psEquipID);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END;

  RETURN C_NORMAL;
END;
-- -----------------------------------------------------------------------------

FUNCTION logout_equip(
  psEquipID		IN equipment.equip_id%TYPE,
  psApplType		IN equipment.appl_type%TYPE DEFAULT 'ALL',
  psUserID		IN sos_usr_config.user_id%TYPE
                             DEFAULT REPLACE(USER, 'OPS$', ''),
  psUpdateConfig	IN VARCHAR2 DEFAULT 'Y')
RETURN NUMBER IS
  sApplType		equipment.appl_type%TYPE := psApplType;
BEGIN
  BEGIN
    SELECT appl_type INTO sApplType
    FROM equipment
    WHERE equip_id = psEquipID;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN C_WRONG_EQUIP;
  END;

  IF psUpdateConfig = 'Y' THEN
    IF sApplType IN ('SOS', 'SOL') THEN
      BEGIN
        UPDATE sos_usr_config
          SET pallet_jack_id = NULL
          WHERE user_id = psUserID;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RETURN C_LM_INVALID_USERID;
        WHEN OTHERS THEN
          RETURN SQLCODE;
      END;
    END IF;
    IF sApplType IN ('SLS', 'SOL') THEN
      BEGIN
        UPDATE las_usr_config
          SET pallet_jack_id = NULL
          WHERE user_id = psUserID;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RETURN C_LM_INVALID_USERID;
        WHEN OTHERS THEN
          RETURN SQLCODE;
      END;
    END IF;
  END IF;

  BEGIN
    insert_slt_action_log('EQUIP_LOGOUT',
      'User ' || psUserID || ' logs out equipment ' || psEquipID);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END;

  RETURN C_NORMAL;
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_sos_config(
  ptbTypConfig		OUT tabTypConfig,
  poiStatus		OUT NUMBER,
  psUserID		IN  sos_usr_config.user_id%TYPE DEFAULT USER,
  psValueSearch		IN  sos_config.config_flag_name%TYPE DEFAULT NULL) IS
BEGIN
  get_config('SOS', ptbTypConfig, poiStatus, psUserID, psValueSearch);
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_sls_config(
  ptbTypConfig		OUT tabTypConfig,
  poiStatus		OUT NUMBER,
  psUserID		IN  las_usr_config.user_id%TYPE DEFAULT USER,
  psValueSearch		IN  las_config.config_flag_name%TYPE DEFAULT NULL) IS
BEGIN
  get_config('SLS', ptbTypConfig, poiStatus, psUserID, psValueSearch);
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_config(
  psApplType		IN  equip_safety_hist.appl_type%TYPE,
  ptbTypConfig		OUT tabTypConfig,
  poiStatus		OUT NUMBER,
  psUserID		IN  sos_usr_config.user_id%TYPE DEFAULT USER,
  psValueSearch		IN  sos_config.config_flag_name%TYPE DEFAULT NULL) IS
  CURSOR c_get_sos_config IS
    SELECT DISTINCT c.seq_no, c.config_flag_name, c.config_flag_val
    FROM sos_config c, sos_usr_config u, job_code j
    WHERE u.user_id (+) = REPLACE(psUserID, 'OPS$', '')
    AND   u.primary_jc (+) = j.jbcd_job_code
    AND   ((psValueSearch IS NULL) OR
           ((psValueSearch IS NOT NULL) AND
            (config_flag_name = UPPER(psValueSearch))))
    ORDER BY seq_no;
  CURSOR c_get_sls_config IS
    SELECT DISTINCT seq_no, config_flag_name, config_flag_val
    FROM las_config
    WHERE (psValueSearch IS NULL)
    OR    ((psValueSearch IS NOT NULL) AND
           (config_flag_name = UPPER(psValueSearch)))
    ORDER BY seq_no;
  sFuncName		VARCHAR2(100) := 'pl_sos.get_config';
  blnExists		BOOLEAN := FALSE;
  iIndex		NUMBER := 0;
  sCurVal		sos_config.config_flag_name%TYPE := NULL;
  sTmpVal		sos_config.config_flag_val%TYPE := NULL;
BEGIN
  poiStatus := C_NORMAL;

  IF psApplType = C_APPL_SOS THEN
    FOR cgsoc IN c_get_sos_config LOOP
      blnExists := TRUE;
      IF cgsoc.config_flag_name <> NVL(sCurVal, ' ') THEN
        iIndex := iIndex + 1;
        IF cgsoc.config_flag_name IS NULL THEN
          sTmpVal := 'NO_CONFIG_FLAG';
        ELSE
          sTmpVal := cgsoc.config_flag_name;
        END IF;
        ptbTypConfig(iIndex).config_name := sTmpVal;
        IF cgsoc.config_flag_val IS NULL THEN
          sTmpVal := ' ';
        ELSE
          sTmpVal := cgsoc.config_flag_val;
        END IF;
        ptbTypConfig(iIndex).config_val := sTmpVal;
      END IF;
      IF cgsoc.config_flag_name <> NVL(sCurVal, ' ') THEN
        sCurVal := cgsoc.config_flag_name;
      END IF;
    END LOOP;
    IF NOT blnExists THEN
      pl_log.ins_msg('FATAL', sFuncName,
        'Invalid SOS user ID or no primary job code for user: ' ||
        REPLACE(psUserID, 'OPS$', ''), C_LM_INVALID_USERID, NULL);
      DBMS_OUTPUT.PUT_LINE(TO_CHAR(C_LM_INVALID_USERID) ||
        ': Invalid SOS user ID or no primary job code for user: ' ||
        REPLACE(psUserID, 'OPS$', ''));
      poiStatus := C_LM_INVALID_USERID;
      RETURN;
    END IF;
  ELSIF psApplType = C_APPL_SLS THEN
    FOR cgslc IN c_get_sls_config LOOP
      IF cgslc.config_flag_name <> NVL(sCurVal, ' ') THEN
        iIndex := iIndex + 1;
        IF cgslc.config_flag_name IS NULL THEN
          sTmpVal := 'NO_CONFIG_FLAG';
        ELSE
          sTmpVal := cgslc.config_flag_name;
        END IF;
        ptbTypConfig(iIndex).config_name := sTmpVal;
        IF cgslc.config_flag_val IS NULL THEN
          sTmpVal := ' ';
        ELSE
          sTmpVal := cgslc.config_flag_val;
        END IF;
        ptbTypConfig(iIndex).config_val := sTmpVal;
      END IF;
      IF cgslc.config_flag_name <> NVL(sCurVal, ' ') THEN
        sCurVal := cgslc.config_flag_name;
      END IF;
    END LOOP;
  ELSE
    NULL;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    pl_log.ins_msg('FATAL', sFuncName, 'Error executing procedure',
                   SQLCODE, NULL);
    DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) || ': Error executing ' || sFuncName);
    poiStatus := SQLCODE;
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_sos_equip_safety_list (
  psEquipID		IN  equipment.equip_id%TYPE,
  poiStatus		OUT NUMBER,
  potbTypETRSfList	OUT tabTypETRSfList,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1) IS
BEGIN
  get_equip_safety_list(psEquipID, poiStatus, potbTypETRSfList,
    C_APPL_SOS, psValueSearch1, piInitCap);
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_sos_equip_safety_list (
  psEquipID		IN  equipment.equip_id%TYPE,
  poiStatus		OUT NUMBER,
  potbTypETNmSfList	OUT tabTypETNmSfList,
  posEquipType		OUT equipment.equip_type%TYPE,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1) IS
BEGIN
  get_equip_safety_list(psEquipID, poiStatus, potbTypETNmSfList, posEquipType,
    C_APPL_SOS, psValueSearch1, piInitCap);
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_sls_equip_safety_list (
  psEquipID		IN  equipment.equip_id%TYPE,
  poiStatus		OUT NUMBER,
  potbTypETRSfList	OUT tabTypETRSfList,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1) IS
BEGIN
  get_equip_safety_list(psEquipID, poiStatus, potbTypETRSfList,
    C_APPL_SLS, psValueSearch1, piInitCap);
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_sls_equip_safety_list (
  psEquipID		IN  equipment.equip_id%TYPE,
  poiStatus		OUT NUMBER,
  potbTypETNmSfList	OUT tabTypETNmSfList,
  posEquipType		OUT equipment.equip_type%TYPE,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1) IS
BEGIN
  get_equip_safety_list(psEquipID, poiStatus, potbTypETNmSfList, posEquipType,
    C_APPL_SLS, psValueSearch1, piInitCap);
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_trl_equip_safety_list (
  poiStatus		OUT NUMBER,
  potbTypETRSfList	OUT tabTypETRSfList,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1) IS
  sEquipType		equipment.equip_type%TYPE := NULL;
BEGIN
  get_equip_safety_list(NULL, poiStatus, potbTypETRSfList,
    C_APPL_TRL, psValueSearch1, piInitCap);
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_trl_equip_safety_list (
  poiStatus		OUT NUMBER,
  potbTypETNmSfList	OUT tabTypETNmSfList,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1) IS
  sEquipType		equipment.equip_type%TYPE := NULL;
BEGIN
  get_equip_safety_list(NULL, poiStatus, potbTypETNmSfList, sEquipType,
    C_APPL_TRL, psValueSearch1, piInitCap);
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_equip_safety_list (
  psEquipID		IN  equipment.equip_id%TYPE,
  poiStatus		OUT NUMBER,
  potbTypETNmSfList	OUT tabTypETNmSfList,
  posEquipType		OUT equipment.equip_type%TYPE,
  psApplType		IN  equip_safety_hist.appl_type%TYPE DEFAULT NULL,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1) IS
  sFuncName		VARCHAR2(100) := 'pl_sos.get_equip_safety_list(Nm)';
  iStatus		NUMBER := C_NORMAL;
  iIndex		NUMBER := 0;
  tbTypASfList		tabTypETRSfList;
BEGIN
  poiStatus := C_NORMAL;
  posEquipType := NULL;

  get_equip_safety_list(psEquipID, iStatus, tbTypASfList,
    psApplType, psValueSearch1, piInitCap);
  IF iStatus = C_NORMAL THEN
    FOR iIndex IN 1 .. tbTypASfList.COUNT LOOP
      posEquipType := tbTypASfList(iIndex).equip_type;
      potbTypETNmSfList(iIndex) := tbTypASfList(iIndex).name;
    END LOOP;
  END IF;
  poiStatus := iStatus;

EXCEPTION
  WHEN OTHERS THEN
    pl_log.ins_msg('FATAL', sFuncName, 'Error executing procedure',
                   SQLCODE, NULL);
    DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) || ': Error executing ' || sFuncName);
    poiStatus := SQLCODE;
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_equip_safety_list (
  psEquipID		IN  equipment.equip_id%TYPE,
  poiStatus		OUT NUMBER,
  potbTypETRSfList	OUT tabTypETRSfList,
  psApplType		IN  equip_safety_hist.appl_type%TYPE DEFAULT NULL,
  psValueSearch1	IN  equip_type_param.name%TYPE DEFAULT NULL,
  piInitCap		IN  NUMBER DEFAULT 1) IS
  sApplType		equip_safety_hist.appl_type%TYPE := NULL;
  sEquipType		equipment.equip_type%TYPE := NULL;
  sNeedParamCheck	equip_type.need_param_check%TYPE := NULL;
  CURSOR c_get_equip_type (csEquipID  equipment.equip_id%TYPE) IS
    SELECT equip_type
    FROM equipment
    WHERE equip_id = csEquipID
    AND   status IN ('AVL');
  CURSOR c_get_equip_type_flag (csEquipType equip_type.equip_type%TYPE) IS
    SELECT NVL(need_param_check, 'N')
    FROM equip_type
    WHERE equip_type = csEquipType;
  CURSOR c_get_equip_type_safety_list (
     csEquipType    equip_type_param.equip_type%TYPE,
     csValueSearch1 equip_type_param.name%TYPE,
     ciInitCap	    NUMBER) IS
    SELECT tp.equip_type,
           DECODE(ciInitCap, 1, INITCAP(tp.name), tp.name) name,
           tp.add_date, tp.add_user, tp.upd_date, tp.upd_user
    FROM equip_type_param tp, equip_type t, equip_param p
    WHERE t.equip_type = tp.equip_type
    AND   p.name = tp.name
    AND   t.equip_type = csEquipType
    AND   ((csValueSearch1 IS NULL) OR
           ((csValueSearch1 IS NOT NULL) AND (tp.name = csValueSearch1)))
    ORDER BY p.seq;
  sFuncName		VARCHAR2(100) := 'pl_sos.get_equip_safety_list(A)';
  iIndex		NUMBER := 0;
BEGIN
  poiStatus := C_NORMAL;

  -- Validate SOS and SLS input equipment ID
  IF psApplType IN (C_APPL_SOS, C_APPL_SLS) THEN
    sApplType := psApplType;
    OPEN c_get_equip_type(psEquipID);
    FETCH c_get_equip_type INTO sEquipType;
    IF c_get_equip_type%NOTFOUND THEN
      CLOSE c_get_equip_type;
      pl_log.ins_msg('WARN', sFuncName,
        'Cannot find equipment type for equipment ID ' || psEquipID,
        C_WRONG_EQUIP, NULL);
      DBMS_OUTPUT.PUT_LINE(TO_CHAR(C_WRONG_EQUIP) ||
        ': Cannot find equipment type for equipment ID ' || psEquipID);
      poiStatus := C_WRONG_EQUIP;
      RETURN;
    END IF;
    IF c_get_equip_type%ISOPEN THEN
      CLOSE c_get_equip_type;
    END IF;
    OPEN c_get_equip_type_flag(sEquipType);
    FETCH c_get_equip_type_flag INTO sNeedParamCheck;
    CLOSE c_get_equip_type_flag;
  ELSIF psApplType IN (C_APPL_TRL) THEN
    sApplType := C_APPL_TRL;
    sEquipType := C_APPL_TRL;
    sNeedParamCheck := 'Y';
  END IF;

  -- Validate input application type 
  IF psApplType IS NOT NULL AND
     sApplType IN (C_APPL_SOS, C_APPL_SLS) AND
     sApplType <> psApplType THEN
    pl_log.ins_msg('WARN', sFuncName,
      'To-be-searched application type ' || psApplType ||
      ' is different from the system value: ' || sApplType ||
      ' for equipment ID ' || psEquipID, C_WRONG_EQUIP, NULL);
    DBMS_OUTPUT.PUT_LINE(TO_CHAR(C_WRONG_EQUIP) ||
      ': To-be-searched application type ' || psApplType ||
      ' is different from the system value: ' || sApplType ||
      ' for equipment ID ' || psEquipID);
    poiStatus := C_WRONG_EQUIP;
    RETURN;
  END IF;

  DBMS_OUTPUT.PUT_LINE('Equip ID/type/appl: ' || psEquipID || '/' ||
    sEquipType || '/' || sApplType);

  IF NVL(sNeedParamCheck, 'N') = 'N' THEN
    DBMS_OUTPUT.PUT_LINE('Equipment doesn''t need to have parameter check');
    poiStatus := C_NO_NEED_EQUIP_CHECK;
  END IF;

  -- Retrieve the data
  FOR cgetsl IN c_get_equip_type_safety_list(sEquipType,
                                             psValueSearch1, piInitCap) LOOP
    iIndex := iIndex + 1;
    potbTypETRSfList(iIndex).equip_type := NVL(cgetsl.equip_type, 'X');
    potbTypETRSfList(iIndex).name := NVL(cgetsl.name, 'X');
    potbTypETRSfList(iIndex).add_date := NVL(cgetsl.add_date, TRUNC(SYSDATE));
    potbTypETRSfList(iIndex).add_user :=
      NVL(cgetsl.add_user, REPLACE(USER, 'OPS$', ''));
    potbTypETRSfList(iIndex).upd_date := NVL(cgetsl.upd_date, TRUNC(SYSDATE));
    potbTypETRSfList(iIndex).upd_user :=
      NVL(cgetsl.upd_user, REPLACE(USER, 'OPS$', ''));
  END LOOP;

  IF iIndex = 0 AND NVL(sNeedParamCheck, 'N') = 'Y' THEN
    DBMS_OUTPUT.PUT_LINE('Equipment need parameter check but don''t have any');
    poiStatus := C_WRONG_EQUIP;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    pl_log.ins_msg('FATAL', sFuncName, 'Error executing procedure',
                   SQLCODE, NULL);
    DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) || ': Error executing ' || sFuncName);
    poiStatus := SQLCODE;
END;
-- -----------------------------------------------------------------------------

FUNCTION add_sos_equip_safety_hist (
  prwTypSfHist		IN equip_safety_hist%ROWTYPE,
  psName		IN equip_param.name%TYPE DEFAULT NULL,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER IS
BEGIN
  RETURN add_equip_safety_hist('SOS', prwTypSfHist, psName, piCheckEquip);
END;
-- -----------------------------------------------------------------------------

FUNCTION add_sos_equip_safety_hist (
  ptbTypSfHist		IN tabTypSfHist,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER IS
BEGIN
  RETURN add_equip_safety_hist('SOS', ptbTypSfHist, piCheckEquip);
END;
-- -----------------------------------------------------------------------------

FUNCTION add_sls_equip_safety_hist (
  prwTypSfHist		IN equip_safety_hist%ROWTYPE,
  psName		IN equip_param.name%TYPE DEFAULT NULL,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER IS
BEGIN
  RETURN add_equip_safety_hist('SLS', prwTypSfHist, psName, piCheckEquip);
END;
-- -----------------------------------------------------------------------------

FUNCTION add_sls_equip_safety_hist (
  ptbTypSfHist		IN tabTypSfHist,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER IS
BEGIN
  RETURN add_equip_safety_hist('SLS', ptbTypSfHist, piCheckEquip);
END;
-- -----------------------------------------------------------------------------

FUNCTION add_trl_equip_safety_hist (
  prwTypSfHist		IN equip_safety_hist%ROWTYPE,
  psName		IN equip_param.name%TYPE DEFAULT NULL,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER IS
BEGIN
  RETURN add_equip_safety_hist('TRL', prwTypSfHist, psName, piCheckEquip);
END;
-- -----------------------------------------------------------------------------

FUNCTION add_trl_equip_safety_hist (
  ptbTypSfHist		IN tabTypSfHist,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER IS
BEGIN
  RETURN add_equip_safety_hist('TRL', ptbTypSfHist, piCheckEquip);
END;
-- -----------------------------------------------------------------------------

FUNCTION add_equip_safety_hist (
  psApplType		IN equip_safety_hist.appl_type%TYPE,
  prwTypSfHist		IN equip_safety_hist%ROWTYPE,
  psName		IN equip_param.name%TYPE DEFAULT NULL,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER IS
  iSeq			equip_safety_hist.seq%TYPE := NULL;
  sFuncName		VARCHAR2(100) := 'pl_sos.add_equip_safety_hist(nm)';
  sMsg1			VARCHAR2(300) := NULL;
  rwTypSfHist		equip_safety_hist%ROWTYPE := prwTypSfHist;
  iExists		NUMBER := 0;
BEGIN
  IF psName IS NOT NULL THEN
    BEGIN
      SELECT seq INTO iSeq
      FROM equip_param
      WHERE UPPER(name) = UPPER(psName);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        sMsg1 := sFuncName || ': Error ' || TO_CHAR(SQLCODE) ||
          ' - Invalid param name to be added: [' || psName || ']';
        DBMS_OUTPUT.PUT_LINE(sMsg1);
        pl_log.ins_msg('FATAL', sFuncName, sMsg1, C_NOT_FOUND, NULL);
        RETURN C_NOT_FOUND;
      WHEN OTHERS THEN
        sMsg1 := sFuncName || ': Error ' || TO_CHAR(SQLCODE) ||
          ' - Invalid param name to be added: [' || psName || ']';
        DBMS_OUTPUT.PUT_LINE(sMsg1);
        pl_log.ins_msg('FATAL', sFuncName, sMsg1, SQLCODE, NULL);
        RETURN SQLCODE;
    END;
  ELSE
    iSeq := prwTypSfHist.seq;
  END IF;

  rwTypSfHist.seq := iSeq;
  IF psApplType NOT IN ('SOS', 'SLS', 'ALL', 'TRL') THEN
    DBMS_OUTPUT.PUT_LINE(sFuncName || ': Invalid appl_type: ' ||
      psApplType);
    RETURN 1;
  END IF;

  IF piCheckEquip <> 0 THEN
    iExists := check_equip(rwTypSfHist.equip_id, psApplType);
    IF iExists <> C_NORMAL THEN
      sMsg1 := sFuncName || ': Error ' || TO_CHAR(iExists) ||
        ' - Invalid equipment ID to be added: ' || psApplType ||
        '/' || rwTypSfHist.equip_id;
      DBMS_OUTPUT.PUT_LINE(sMsg1);
      pl_log.ins_msg('FATAL', sFuncName, sMsg1, iExists, NULL);
      RETURN iExists;
    END IF;
  END IF;

dbms_output.put_line(' inserting to equip_safety_hist table');

  INSERT INTO equip_safety_hist
    (equip_id, appl_type, seq, status, status_type,
     add_date, add_user, upd_date, upd_user)
    VALUES (
     rwTypSfHist.equip_id, psApplType, rwTypSfHist.seq,
     DECODE(rwTypSfHist.status, NULL, NULL, ' ', NULL, C_DFT_UNSAFE_MARK),
     rwTypSfHist.status_type,
     SYSDATE, REPLACE(NVL(rwTypSfHist.add_user, USER), 'OPS$', ''), NULL, NULL);

    if sql%rowcount <> 0 then 
       RETURN C_NORMAL;
    else
       return sqlcode;
    end if;

EXCEPTION
  WHEN OTHERS THEN
    sMsg1 := sFuncName || ': Error ' || TO_CHAR(SQLCODE) ||
        ' - Insert to EQUIP_SAFETY_HIST for ' || psApplType ||
        '/' || rwTypSfHist.equip_id || '->' || TO_CHAR(rwTypSfHist.seq) ||
        '/' || rwTypSfHist.status || '/' || rwTypSfHist.status_type;
    DBMS_OUTPUT.PUT_LINE(sMsg1);
    pl_log.ins_msg('FATAL', sFuncName, sMsg1, SQLCODE, NULL);
    RETURN SQLCODE;
END;
-- -----------------------------------------------------------------------------

FUNCTION add_equip_safety_hist (
  psApplType		IN equip_safety_hist.appl_type%TYPE,
  ptbTypSfHist		IN tabTypSfHist,
  piCheckEquip		IN NUMBER DEFAULT 0)
RETURN NUMBER IS
  iIndex		NUMBER;
  rwTypSfHist		equip_safety_hist%ROWTYPE := NULL;
  iStatus		NUMBER := C_NORMAL;
BEGIN
  FOR iIndex IN 1 .. ptbTypSfHist.COUNT LOOP
    rwTypSfHist := NULL;
    rwTypSfHist.equip_id := ptbTypSfHist(iIndex).equip_id;
    rwTypSfHist.appl_type := psApplType;
    rwTypSfHist.seq := ptbTypSfHist(iIndex).seq;
    rwTypSfHist.status := ptbTypSfHist(iIndex).status;
    rwTypSfHist.status_type := ptbTypSfHist(iIndex).status_type;
    rwTypSfHist.add_date := ptbTypSfHist(iIndex).add_date;
    rwTypSfHist.add_user := ptbTypSfHist(iIndex).add_user;
    rwTypSfHist.upd_date := ptbTypSfHist(iIndex).upd_date;
    rwTypSfHist.upd_user := ptbTypSfHist(iIndex).upd_user;
    iStatus := add_equip_safety_hist(psApplType, rwTypSfHist, piCheckEquip);
    EXIT WHEN iStatus <> C_NORMAL;
  END LOOP;

  RETURN iStatus;
END;  
-- -----------------------------------------------------------------------------

FUNCTION get_truck_func_sort (psTruck sls_load_map.truck_no%TYPE)
RETURN NUMBER IS
  CURSOR c_get_truck_status IS
    SELECT LTRIM(RTRIM(freezer_status)) freezer_status,
           LTRIM(RTRIM(cooler_status)) cooler_status,
           LTRIM(RTRIM(dry_status)) dry_status,
           LTRIM(RTRIM(freezer_remaining)) freezer_remaining,
           LTRIM(RTRIM(cooler_remaining)) cooler_remaining,
           LTRIM(RTRIM(dry_remaining)) dry_remaining,
           LTRIM(RTRIM(freezer_pallets)) freezer_pallets,
           LTRIM(RTRIM(cooler_pallets)) cooler_pallets,
           LTRIM(RTRIM(dry_pallets)) dry_pallets
    FROM las_truck
    WHERE truck = psTruck;
  CURSOR c_get_pallet_status IS
    SELECT COUNT(1) pallet_total,
           SUM(DECODE(NVL(loader_status, ' '),
                      ' ', 0, '*', 1, 0)) loaded_total,
           SUM(DECODE(NVL(selection_status,
                      ' '), ' ', 0, 'S', 1, 0)) selection_total,
           SUM(DECODE(NVL(selection_status,
                      ' '), ' ', 0, 'C', 1, 0)) mis_case_total

    FROM las_pallet
    WHERE LTRIM(RTRIM(truck)) = psTruck;
BEGIN
  FOR cgts IN c_get_truck_status LOOP
    IF NVL(cgts.freezer_status, ' ') = 'A' OR
       NVL(cgts.cooler_status, ' ') = 'A' OR
       NVL(cgts.dry_status, ' ') = 'A' THEN
      RETURN 1;
    ELSIF NVL(TO_NUMBER(cgts.freezer_remaining), 0) =
          NVL(TO_NUMBER(cgts.freezer_pallets), 0) AND
          NVL(TO_NUMBER(cgts.cooler_remaining), 0) =
          NVL(TO_NUMBER(cgts.cooler_pallets), 0) AND
          NVL(TO_NUMBER(cgts.dry_remaining), 0) =
          NVL(TO_NUMBER(cgts.dry_pallets), 0) THEN
      RETURN 2;
    ELSIF NVL(cgts.freezer_status, ' ') = 'C' AND
          NVL(cgts.cooler_status, ' ') = 'C' AND
          NVL(cgts.dry_status, ' ') = 'C' THEN
      RETURN 3;
    ELSE
      FOR cgps  IN c_get_pallet_status LOOP
        IF cgps.loaded_total > 0 OR
           cgps.selection_total + cgps.mis_case_total > 0 THEN
          RETURN 1;
        END IF;
      END LOOP;
      RETURN 4;
    END IF;
  END LOOP;
  RETURN 5;
END;

-- -----------------------------------------------------------------------------

PROCEDURE insert_slt_action_log (
  psAction              IN slt_action_log.action%TYPE,
  psMsgText             IN slt_action_log.msg_text%TYPE,
  psMsgType             IN slt_action_log.msg_type%TYPE DEFAULT 'INFO',
  psLogRequired		IN VARCHAR2 DEFAULT 'N') IS
  sMsgType		VARCHAR2(1) := NULL;
BEGIN
  IF UPPER(psLogRequired) = 'Y' THEN
    -- Log the message even if the caller action might be failed later
    -- during commit
    insert_slt_action_log_auto(psAction, psMsgText, psMsgType);
    RETURN;
  END IF;

  sMsgType := UPPER(SUBSTR(psMsgType, 1, 1));
  IF UPPER(psMsgType) NOT IN ('INFO', 'WARN', 'FATAL') THEN
    sMsgType := 'I';
  END IF;

  BEGIN
    INSERT INTO slt_action_log
      (seq, action,msg_type, msg_text,
       add_date, add_user)
      VALUES (
       slt_action_log_seq.nextval, UPPER(psAction), sMsgType, psMsgText,
       SYSDATE, REPLACE(USER, 'OPS$', ''));
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;
END;
-- -----------------------------------------------------------------------------

PROCEDURE group_shorts (
  poiStatus	OUT NUMBER,
  psUser	IN  batch.user_id%TYPE DEFAULT REPLACE(USER, 'OPS$', ''),
  psBatch	IN  NUMBER DEFAULT '0',
  psJobCode	IN  batch.jbcd_job_code%TYPE DEFAULT '0') IS
  tbTypConfig	tabTypConfig;
  iStatus	NUMBER := C_NORMAL;
  CURSOR c_get_sos_shorts IS
    SELECT s.area, s.orderseq, s.truck, s.location, s.dock_float_loc,
           s.qty_short, s.qty_total, s.customer, s.description, s.item,
           s.weight, s.picktype, s.stop, s.custname, s.invoiceno, s.doors,
			/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
			/*
			** Retrieve prod size unit
			*/
           s.pack, s.prod_size, s.prod_size_unit, s.internal_upc, s.external_upc
		   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
    FROM v_sos_short s, loc l
    WHERE s.location = l.logi_loc
    AND   s.user_id = REPLACE(psUser, 'OPS$', '')
    AND   s.sos_status IS NULL
    ORDER BY l.pik_path;
BEGIN
  poiStatus := C_NORMAL;

  -- Retrieve syspar short job code value
  get_sos_config(tbTypConfig, iStatus, psUser, 'SHORT_JOBCODE');
  IF iStatus <> C_NORMAL THEN
    poiStatus := iStatus;
    RETURN;
  END IF;
END;  
-- ----------------------------------------------------------------------------

PROCEDURE get_sls_mis_cases (
  piOption    IN  NUMBER,
  psTruck     IN  sls_load_map.truck_no%TYPE,
  tbMsCase    OUT tabTypMissing,
  psExtraData IN  VARCHAR2 DEFAULT NULL) IS

  iIndex	NUMBER := 0;

  CURSOR c_get_mis_cases (cpsTruck sls_load_map.truck_no%TYPE) IS
    SELECT s.orderseq, p.prod_id, p.cust_pref_vendor, p.descrip, d.uom,
			/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
			/*
			** Retrieve prod size unit
			*/
           s.qty_short qty, TO_CHAR(d.stop_no) stop_no, p.prod_size, p.prod_size_unit, m.cust_id
			/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
    FROM sos_short s, floats f, ordd d, pm p, ordm m
    WHERE s.batch_no = f.batch_no
    AND   s.truck = psTruck
    AND   s.truck = f.truck_no
    AND   s.dock_float_loc = f.float_seq
    AND   s.orderseq = d.seq
    AND   d.prod_id = p.prod_id
    AND   d.cust_pref_vendor = p.cust_pref_vendor
    AND   m.order_id = d.order_id
    AND   NVL(s.qty_short, 0) > 0
    AND   (((piOption = 1) AND
            (f.float_seq = LTRIM(RTRIM(psExtraData)))) OR
           ((piOption = 2) AND
            (f.comp_code = LTRIM(RTRIM(psExtraData)))) OR
           ((piOption = 3) AND
            (f.truck_no = LTRIM(RTRIM(psExtraData)))) OR
           ((piOption = 4) AND
            (s.orderseq = TO_NUMBER(LTRIM(RTRIM(psExtraData))))))
    AND   (s.sos_status NOT IN ('F', 'O') OR (s.sos_status IS NULL));
BEGIN

  FOR cgmc IN c_get_mis_cases(psTruck) LOOP
    iIndex := iIndex + 1;
    tbMsCase(iIndex).orderseq := NVL(cgmc.orderseq, -1);
    tbMsCase(iIndex).prod_id := NVL(cgmc.prod_id, '-1');
    tbMsCase(iIndex).cust_pref_vendor := NVL(cgmc.cust_pref_vendor, '-1');
    tbMsCase(iIndex).descrip := NVL(cgmc.descrip, 'No desc');
    tbMsCase(iIndex).uom := NVL(cgmc.uom, 0);
    tbMsCase(iIndex).qty := NVL(cgmc.qty, 0);
    tbMsCase(iIndex).stop_no := NVL(cgmc.stop_no, -1);
    tbMsCase(iIndex).prod_size := NVL(cgmc.prod_size, 'No sz');
	/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
	/*
	** Declare prod size unit
	*/
	tbMsCase(iIndex).prod_size_unit := NVL(cgmc.prod_size_unit, 'No szu');
	/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End*/
    tbMsCase(iIndex).cust_id := NVL(cgmc.cust_id, '-1');
    tbMsCase(iIndex).flag := 'C';

    dbms_output.put_line(' tbMsCase(iIndex).flag ' ||tbMsCase(iIndex).flag ||
                ' tbMsCase(iIndex).orderseq = '|| tbMsCase(iIndex).orderseq ||
                ' tbMsCase(iIndex).prod_id  = '|| tbMsCase(iIndex).prod_id );
  END LOOP;

END;
-- ----------------------------------------------------------------------------

--PROCEDURE get_sls_mis_weights (
--  psTruck     IN  sls_load_map.truck_no%TYPE,
--  tbMsWeight  OUT tabTypMissing,
--  psExtraData IN  VARCHAR2 DEFAULT NULL) IS
--  iIndex	NUMBER := 0;
--  CURSOR c_get_mis_weights (cpsTruck sls_load_map.truck_no%TYPE) IS
--    SELECT s.orderseq, p.prod_id, p.cust_pref_vendor, p.descrip, d.uom,
--           s.qty_short qty, TO_CHAR(d.stop_no) stop_no, p.prod_size, m.cust_id
--    FROM sos_short s, floats f, ordd d, pm p, ordm m
--    WHERE s.batch_no = f.batch_no
--    AND   s.truck = psTruck
--    AND   s.truck = f.truck_no
--    AND   m.order_id = d.order_id
--    AND   m.route_no = d.route_no
--    AND   s.dock_float_loc = f.float_seq
--    AND   s.orderseq = d.seq
--    AND   d.prod_id = p.prod_id
--    AND   d.cust_pref_vendor = p.cust_pref_vendor
--    AND   m.order_id = d.order_id
--    AND   NVL(s.qty_short, 0) > 0
--    AND   ((psExtraData IS NULL) OR
--           ((psExtraData IS NOT NULL) AND
--	    (((LENGTH(psExtraData) = 1) AND
--	      (SUBSTR(s.dock_float_loc, 1, 1) = psExtraData)) OR
--	     ((LENGTH(psExtraData)
--                BETWEEN C_ORDD_SEQ_DB_LEN AND C_ORDD_SEQ_LBL_LEN) AND
--              (((LENGTH(psExtraData) = C_ORDD_SEQ_DB_LEN) AND
--                (s.orderseq = TO_NUMBER(psExtraData))) OR
--              (((LENGTH(psExtraData) = C_ORDD_SEQ_LBL_LEN) AND
--                (s.orderseq =
--                   TO_NUMBER(SUBSTR(psExtraData, 1, C_ORDD_SEQ_DB_LEN))))))) OR
--             ((LENGTH(psExtraData) < C_ORDD_SEQ_DB_LEN) AND
--              (s.dock_float_loc = psExtraData)))))
--    AND   EXISTS (SELECT 1
--                  FROM ordcw w
--                  WHERE w.order_id = d.order_id
--                  AND   w.order_line_id = d.order_line_id
--		  AND   w.uom = d.uom
--                  AND   NVL(w.catch_weight, 0) = 0)
--    AND   (s.sos_status NOT IN ('F', 'O') OR (s.sos_status IS NULL));
--BEGIN
--  FOR cgmw IN c_get_mis_weights(psTruck) LOOP
--    iIndex := iIndex + 1;
--    tbMsWeight(iIndex).orderseq := NVL(cgmw.orderseq, -1);
--    tbMsWeight(iIndex).prod_id := NVL(cgmw.prod_id, '-1');
--    tbMsWeight(iIndex).cust_pref_vendor := NVL(cgmw.cust_pref_vendor, '-1');
--    tbMsWeight(iIndex).descrip := NVL(cgmw.descrip, 'No desc');
--    tbMsWeight(iIndex).uom := NVL(cgmw.uom, 0);
--    tbMsWeight(iIndex).qty := NVL(cgmw.qty, 0);
--    tbMsWeight(iIndex).stop_no := NVL(cgmw.stop_no, -1);
--    tbMsWeight(iIndex).prod_size := NVL(cgmw.prod_size, 'No sz');
--    tbMsWeight(iIndex).cust_id := NVL(cgmw.cust_id, '-1');
--    tbMsWeight(iIndex).flag := 'W';
--  END LOOP;
--END;
-- ----------------------------------------------------------------------------

--PROCEDURE get_sls_mis_cswts (
--  psTruck     IN  sls_load_map.truck_no%TYPE,
--  tbMsInfo    OUT tabTypMissing,
--  psExtraData IN  VARCHAR2 DEFAULT NULL) IS
--  tbMsCases	tabTypMissing;
--  tbMsWeights	tabTypMissing;
--  iIndex	NUMBER := 0;
--  iIndex2	NUMBER := 0;
--  iTotal	NUMBER := 0;
--  CURSOR c_get_mis_info (cpsTruck sls_load_map.truck_no%TYPE) IS
--    SELECT s.orderseq, p.prod_id, p.cust_pref_vendor, p.descrip, d.uom,
--           s.qty_short qty, TO_CHAR(d.stop_no) stop_no, p.prod_size, m.cust_id
--    FROM sos_short s, floats f, ordd d, pm p, ordm m
--    WHERE s.batch_no = f.batch_no
--    AND   s.truck = psTruck
--    AND   s.dock_float_loc = f.float_seq
--    AND   s.orderseq = d.seq
--    AND   d.prod_id = p.prod_id
--    AND   d.cust_pref_vendor = p.cust_pref_vendor
--    AND   m.order_id = d.order_id
--    AND   NVL(s.qty_short, 0) > 0
--    AND   ((psExtraData IS NULL) OR
--           ((psExtraData IS NOT NULL) AND
--	    (((LENGTH(psExtraData) = 1) AND
--	      (SUBSTR(s.dock_float_loc, 1, 1) = psExtraData)) OR
--	     ((LENGTH(psExtraData)
--                BETWEEN C_ORDD_SEQ_DB_LEN AND C_ORDD_SEQ_LBL_LEN) AND
--              (((LENGTH(psExtraData) = C_ORDD_SEQ_DB_LEN) AND
--                (s.orderseq = TO_NUMBER(psExtraData))) OR
--              (((LENGTH(psExtraData) = C_ORDD_SEQ_LBL_LEN) AND
--                (s.orderseq =
--                   TO_NUMBER(SUBSTR(psExtraData, 1, C_ORDD_SEQ_DB_LEN))))))) OR
--             ((LENGTH(psExtraData) < C_ORDD_SEQ_DB_LEN) AND
--              (s.dock_float_loc = psExtraData)))))
--    AND   (s.sos_status NOT IN ('F', 'O') OR (s.sos_status IS NULL))
--    UNION
--    SELECT s.orderseq, p.prod_id, p.cust_pref_vendor, p.descrip, d.uom,
--           s.qty_short qty, TO_CHAR(d.stop_no) stop_no, p.prod_size, m.cust_id
--    FROM sos_short s, floats f, ordd d, pm p, ordm m
--    WHERE s.batch_no = f.batch_no
--    AND   s.truck = psTruck
--    AND   s.truck = f.truck_no
--    AND   m.order_id = d.order_id
--    AND   m.route_no = d.route_no
--    AND   s.dock_float_loc = f.float_seq
--    AND   s.orderseq = d.seq
--    AND   d.prod_id = p.prod_id
--    AND   d.cust_pref_vendor = p.cust_pref_vendor
--    AND   m.order_id = d.order_id
--    AND   NVL(s.qty_short, 0) > 0
--    AND   ((psExtraData IS NULL) OR
--           ((psExtraData IS NOT NULL) AND
--	    (((LENGTH(psExtraData) = 1) AND
--	      (SUBSTR(s.dock_float_loc, 1, 1) = psExtraData)) OR
--	     ((LENGTH(psExtraData)
--                BETWEEN C_ORDD_SEQ_DB_LEN AND C_ORDD_SEQ_LBL_LEN) AND
--              (((LENGTH(psExtraData) = C_ORDD_SEQ_DB_LEN) AND
--                (s.orderseq = TO_NUMBER(psExtraData))) OR
--              (((LENGTH(psExtraData) = C_ORDD_SEQ_LBL_LEN) AND
--                (s.orderseq =
--                   TO_NUMBER(SUBSTR(psExtraData, 1, C_ORDD_SEQ_DB_LEN))))))) OR
--             ((LENGTH(psExtraData) < C_ORDD_SEQ_DB_LEN) AND
--              (s.dock_float_loc = psExtraData)))))
--    AND   EXISTS (SELECT 1
--                  FROM ordcw w
--                  WHERE w.order_id = d.order_id
--                  AND   w.order_line_id = d.order_line_id
--		  AND   w.uom = d.uom
--                  AND   NVL(w.catch_weight, 0) = 0)
--    AND   (s.sos_status NOT IN ('F', 'O') OR (s.sos_status IS NULL))
--    ORDER BY 1;
--BEGIN
--  FOR cgmi IN c_get_mis_info(psTruck) LOOP
--    iIndex := iIndex + 1;
--    tbMsInfo(iIndex).orderseq := NVL(cgmi.orderseq, -1);
--    tbMsInfo(iIndex).prod_id := NVL(cgmi.prod_id, '-1');
--    tbMsInfo(iIndex).cust_pref_vendor := NVL(cgmi.cust_pref_vendor, '-1');
--    tbMsInfo(iIndex).descrip := NVL(cgmi.descrip, 'No desc');
--    tbMsInfo(iIndex).uom := NVL(cgmi.uom, 0);
--    tbMsInfo(iIndex).qty := NVL(cgmi.qty, 0);
--    tbMsInfo(iIndex).stop_no := NVL(cgmi.stop_no, -1);
--    tbMsInfo(iIndex).prod_size := NVL(cgmi.prod_size, 'No sz');
--    tbMsInfo(iIndex).cust_id := NVL(cgmi.cust_id, '-1');
--    tbMsInfo(iIndex).flag := 'B';
--  END LOOP;
--  iTotal := iIndex;
--  get_sls_mis_cases(psTruck, tbMsCases, psExtraData);
--  get_sls_mis_weights(psTruck, tbMsWeights, psExtraData);
--  FOR iIndex IN 1 .. tbMsCases.COUNT LOOP
--    FOR iIndex2 IN 1 .. tbMsInfo.COUNT LOOP
--      IF tbMsInfo(iIndex2).orderseq = tbMsCases(iIndex).orderseq AND
--         tbMsInfo(iIndex2).flag = 'B' THEN
--        tbMsInfo(iIndex2).flag := 'C';
--      END IF;
--    END LOOP;
--  END LOOP;
--  FOR iIndex IN 1 .. tbMsWeights.COUNT LOOP
--    FOR iIndex2 IN 1 .. tbMsInfo.COUNT LOOP
--      IF tbMsInfo(iIndex2).orderseq = tbMsWeights(iIndex).orderseq THEN
--        IF tbMsInfo(iIndex2).flag = 'B' THEN
--          tbMsInfo(iIndex2).flag := 'W';
--        ELSIF tbMsInfo(iIndex2).flag = 'C' THEN
--          tbMsInfo(iIndex2).flag := 'B';
--        END IF;
--      END IF;
--    END LOOP;
--  END LOOP;
--END;
-- ----------------------------------------------------------------------------

PROCEDURE get_type_params (
  tbTypFTypParam OUT tabTypFTypParam,
  psEquipType    IN  equip_type_param.equip_type%TYPE DEFAULT NULL,
  psInitCap	 IN  VARCHAR2 DEFAULT 'Y') IS
  iIndex	NUMBER := 0;
  CURSOR c_get_type_param IS
    SELECT DECODE(psInitCap, 'Y', INITCAP(t.name), t.name) name,
           p.descrip, p.abbr, NVL(p.scannable, 'N') scannable
    FROM equip_type_param t, equip_param p
    WHERE t.name = p.name
    AND   ((psEquipType IS NULL) OR
           ((psEquipType IS NOT NULL) AND (t.equip_type = psEquipType)));
BEGIN
  FOR cgtp IN c_get_type_param LOOP
    iIndex := iIndex + 1;
    tbTypFTypParam(iIndex).name := NVL(cgtp.name, 'No name');
    tbTypFTypParam(iIndex).descrip := NVL(cgtp.descrip, 'No desc');
    tbTypFTypParam(iIndex).abbr := NVL(cgtp.abbr, '???');
    tbTypFTypParam(iIndex).scannable := NVL(cgtp.scannable, 'N');
  END LOOP;
END;
-- ----------------------------------------------------------------------------

PROCEDURE get_type_params (
  tbTypPTypParam OUT tabTypPTypParam,
  psEquipType    IN equip_type_param.equip_type%TYPE DEFAULT NULL,
  psInitCap	 IN  VARCHAR2 DEFAULT 'Y') IS
  tbTypFTypParam	tabTypFTypParam;
  iIndex		NUMBER := 0;
BEGIN
  get_type_params(tbTypFTypParam, psEquipType);
  FOR iIndex IN 1 .. tbTypFTypParam.COUNT LOOP
    tbTypPTypParam(iIndex) := tbTypFTypParam(iIndex).name;
  END LOOP;
END;
-- ----------------------------------------------------------------------------

PROCEDURE get_float_summary (
  psTruck	    IN  las_pallet.truck%TYPE,
  tbTypFloatSummary OUT tabTypFloatSummary) IS
  iIndex	NUMBER := 0;
  iDoor		route.f_door%TYPE := NULL;
--  CURSOR c_get_float_summary IS
--    SELECT truck_zone, palletno,
--           RTRIM(loader_status) loader_status,
--           RTRIM(selection_status) selection_status,
--           RTRIM(batch) batch
--    FROM v_las_pallet
--    WHERE truck = psTruck
--    ORDER BY sort_seq, TO_NUMBER(SUBSTR(palletno, 2));
BEGIN
  -- Retrieve all data for all zones from V_LAS_PALLET for the truck
  -- regardless of the loader and/or selection status
  NULL;
--  FOR cglpa IN c_get_las_pallet_desc(psTruck, '?', '?') LOOP
--    iIndex := iIndex + 1;
--    tbTypFloatSummary(iIndex).truck_no:= psTruck;
--    tbTypFloatSummary(iIndex).truck_zone := NVL(cglpa.truck_zone, '-1');
--    tbTypFloatSummary(iIndex).palletno := NVL(cglpa.palletno, '-1');
--    FOR cgd IN c_get_door(psTruck, SUBSTR(cglpa.palletno, 1, 1)) LOOP
--      tbTypFloatSummary(iIndex).door := cgd.door;
--      iDoor := cgd.door;
--    END LOOP;
--    IF iDoor IS NULL THEN
--      tbTypFloatSummary(iIndex).door := -1;
--    END IF;
--    tbTypFloatSummary(iIndex).loader_status := NVL(cglpa.loader_status, 'X');
--    tbTypFloatSummary(iIndex).selection_status :=
--      NVL(cglpa.selection_status, 'X');
--    tbTypFloatSummary(iIndex).batch := NVL(cglpa.batch, '-1');
--  END LOOP;
END;
-- ----------------------------------------------------------------------------

PROCEDURE get_basic_loader_info (
  psTruck		IN  las_pallet.truck%TYPE,
  psFloat		IN  las_pallet.truck%TYPE,
  psUser		IN  usr.user_id%TYPE DEFAULT REPLACE(USER, 'OPS$', ''),
  porcTypLoaderLM	OUT recTypLoaderLM,
  poiStatus		OUT NUMBER) IS
  sLMActive		sys_config.config_flag_val%TYPE := NULL;
  sUnloadSyspar		sys_config.config_flag_val%TYPE := NULL;
  sSLSActive		sys_config.config_flag_val%TYPE := NULL;
  iStartNeed		NUMBER := 0;
  sLDBatch		batch.batch_no%TYPE := NULL;
  sLDBatchStatus	batch.status%TYPE := NULL;
  dtBatchDate		DATE := NULL;
  dtStart		DATE := NULL;
  dtStop		DATE := NULL;
  sEquipID		batch.equip_id%TYPE := NULL;
  sParentBatch		batch.parent_batch_no%TYPE := NULL;
  sSupervisor		batch.user_supervsr_id%TYPE := NULL;
  sFloatSeq		floats.float_seq%TYPE := NULL;
  sLoaderStatus		las_pallet.loader_status%TYPE := NULL;
  sUpdUser		sos_usr_config.user_id%TYPE := NULL;
  sJobCode		batch.jbcd_job_code%TYPE := NULL;
  sLaborGroup		usr.lgrp_lbr_grp%TYPE := NULL;
  iStatus		NUMBER := C_NORMAL;
BEGIN
  porcTypLoaderLM := NULL;
  poiStatus := C_NORMAL;

  BEGIN
    sLMActive := pl_common.f_get_syspar('LBR_MGMT_FLAG', 'N');
  EXCEPTION
    WHEN OTHERS THEN
      sLMActive := 'N';
  END;
  porcTypLoaderLM.lbr_mgmt_flag := sLMActive;

  BEGIN
    sUnloadSyspar := pl_common.f_get_syspar('LAS_CALC_UNLOAD_GOAL_TIME', 'N');
  EXCEPTION
    WHEN OTHERS THEN
      sUnloadSyspar := 'N';
  END;
  porcTypLoaderLM.calc_unload_goal_time := sUnloadSyspar;

  BEGIN
    sSLSActive := pl_common.f_get_syspar('LAS_ACTIVE', 'N');
  EXCEPTION
    WHEN OTHERS THEN
      sSLSActive := 'N';
  END;
  porcTypLoaderLM.las_active := sSLSActive;

  BEGIN
    SELECT REPLACE(suprvsr_user_id, 'OPS$', ''), lgrp_lbr_grp
    INTO sSupervisor, sLaborGroup
    FROM usr
    WHERE REPLACE(user_id, 'OPS$', '') = REPLACE(psUser, 'OPS$', '');
  EXCEPTION
    WHEN OTHERS THEN
      sSupervisor := NULL;
  END;
  IF sSupervisor IS NULL THEN
    sSupervisor := 'NOMGR';
  END IF;
  IF sLaborGroup IS NULL THEN
    sLaborGroup := 'NG';
  END IF;
  porcTypLoaderLM.supervsr_id := sSupervisor;
  porcTypLoaderLM.labor_group := sLaborGroup;

  IF sLMActive = 'Y' THEN
    BEGIN
      SELECT 1 INTO iStartNeed
      FROM batch
      WHERE user_id = REPLACE(psUser,'OPS$', '')
      AND   jbcd_job_code = 'ISTART';
      porcTypLoaderLM.need_istart := 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        porcTypLoaderLM.need_istart := 1;
      WHEN OTHERS THEN
        porcTypLoaderLM.need_istart := 0;
    END;
  
    BEGIN
      SELECT 'L' || f.float_no, f.float_seq INTO sLDBatch, sFloatSeq
      FROM floats f, route r
      WHERE f.truck_no = psTruck
      AND   f.float_seq = psFloat
      AND   f.route_no = r.route_no
      AND   f.zone_id IS NOT NULL;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        iStatus := C_NO_LM_BATCH_FOUND;
      WHEN OTHERS THEN
        iStatus := SQLCODE;
    END;
    porcTypLoaderLM.float_seq := sFloatSeq;
 
    IF iStatus = C_NORMAL THEN 
      BEGIN
        SELECT status, batch_date, actl_start_time, actl_stop_time,
               equip_id, parent_batch_no, jbcd_job_code
        INTO sLDBatchStatus, dtBatchDate, dtStart, dtStop,
             sEquipID, sParentBatch, sJobCode
        FROM batch
        WHERE batch_no = sLDBatch;
      EXCEPTION
        WHEN OTHERS THEN
          iStatus := C_NO_LM_BATCH_FOUND;
      END;
    END IF;

--    IF iStatus = C_NORMAL THEN
--      BEGIN
--        SELECT loader_status, upd_user INTO sLoaderStatus, sUpdUser
--        FROM las_pallet
--        WHERE truck = psTruck
--        AND   palletno = psFloat;
--      EXCEPTION
--        WHEN OTHERS THEN
--          iStatus := SQLCODE;
--      END;
--    END IF;

    IF iStatus = C_NORMAL THEN 
      porcTypLoaderLM.batch_no := sLDBatch;
      porcTypLoaderLM.status := sLDBatchStatus;
      porcTypLoaderLM.batch_date := dtBatchDate;
      porcTypLoaderLM.job_code := sJobCode;
      porcTypLoaderLM.start_time := dtStart;
      porcTypLoaderLM.stop_time := dtStop;
      porcTypLoaderLM.equip_id := sEquipID;
      porcTypLoaderLM.parent_batch_no := sParentBatch;
      porcTypLoaderLM.float_seq := sFloatSeq;
      porcTypLoaderLM.upd_user := sUpdUser;
      porcTypLoaderLM.loader_status := sLoaderStatus;
    END IF;
  END IF;

  -- This is to prevent no data found problem if caller is a Pro*C program
  IF sLDBatch IS NULL OR iStatus <> C_NORMAL THEN
    porcTypLoaderLM.batch_no := '-1';
  END IF;
  IF sLDBatchStatus IS NULL THEN
    porcTypLoaderLM.status := 'F';
  END IF;
  IF dtBatchDate IS NULL THEN
    porcTypLoaderLM.batch_date := TO_DATE('01011980', 'MMDDYYYY');
  END IF;
  IF sJobCode IS NULL THEN
    porcTypLoaderLM.job_code := '-1';
  END IF;
  IF sLaborGroup IS NULL THEN
    porcTypLoaderLM.labor_group := '-1';
  END IF;
  IF dtStart IS NULL THEN
    porcTypLoaderLM.start_time := TO_DATE('01011980', 'MMDDYYYY');
  END IF;
  IF dtStop IS NULL THEN
    porcTypLoaderLM.stop_time := TO_DATE('01011980', 'MMDDYYYY');
  END IF;
  IF sEquipID IS NULL THEN
    porcTypLoaderLM.equip_id := '-1';
  END IF;
  IF sParentBatch IS NULL THEN
    porcTypLoaderLM.parent_batch_no := '-1';
  END IF;
  IF sFloatSeq IS NULL THEN
    porcTypLoaderLM.float_seq := '?';
  END IF;
  IF sUpdUser IS NULL THEN
    porcTypLoaderLM.upd_user := '-1';
  END IF;
  IF sLoaderStatus IS NULL THEN
    porcTypLoaderLM.loader_status := 'X';
  END IF;

  poiStatus := iStatus;
END;
-- ----------------------------------------------------------------------------

PROCEDURE get_active_batch (
  porcActiveLM	OUT recTypLoaderLM,
  poiStatus	OUT NUMBER,
  psUser	IN  usr.user_id%TYPE DEFAULT REPLACE(USER, 'OPS$', '')) IS
  sLMActive	sys_config.config_flag_val%TYPE := NULL;
  sBatch	batch.batch_no%TYPE := NULL;
  dtBatchDate	batch.batch_date%TYPE := NULL;
  dtStartTime	batch.actl_start_time%TYPE := NULL;
  dtStopTime	batch.actl_stop_time%TYPE := NULL;
  sEquipID	batch.equip_id%TYPE := NULL;
  sParentBatch	batch.parent_batch_no%TYPE := NULL;
  sRoute	batch.ref_no%TYPE := NULL;
  sLoaderStatus	las_pallet.loader_status%TYPE := NULL;
  sUpdUser	sos_usr_config.user_id%TYPE := NULL;
  iStatus	NUMBER := C_NORMAL;
BEGIN
  porcActiveLM := NULL;
  poiStatus := C_NORMAL;

  BEGIN
    sLMActive := pl_common.f_get_syspar('LBR_MGMT_FLAG', 'N');
  EXCEPTION
    WHEN OTHERS THEN
      sLMActive := 'N';
  END;
  porcActiveLM.lbr_mgmt_flag := sLMActive;

  BEGIN
    SELECT batch_no, batch_date, actl_start_time, actl_stop_time,
           equip_id, parent_batch_no, ref_no
    INTO sBatch, dtBatchDate, dtStartTime, dtStopTime,
         sEquipID, sParentBatch, sRoute
    FROM batch
    WHERE user_id = REPLACE(psUser, 'OPS$', '')
    AND   status = 'A';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      IF sLMActive = 'N' THEN
        iStatus := C_LM_NOT_ACTIVE;
      ELSE
        iStatus := C_NO_LM_BATCH_FOUND;
      END IF;
    WHEN OTHERS THEN
      iStatus := SQLCODE;
  END;

--  IF iStatus = C_NORMAL AND sBatch LIKE 'L%' THEN
--    BEGIN
--      SELECT DISTINCT REPLACE(p.upd_user, 'OPS$', ''), p.loader_status
--      INTO sUpdUser, sLoaderStatus
--      FROM floats f, las_pallet p
--      WHERE f.route_no = sRoute
--      AND   f.float_seq = LTRIM(RTRIM(palletno))
--      AND   f.float_seq IS NOT NULL
--      AND   f.batch_no = TO_NUMBER(SUBSTR(sBatch, 2))
--      AND   f.truck_no = p.truck;
--    EXCEPTION
--      WHEN NO_DATA_FOUND THEN
--        NULL;
--      WHEN OTHERS THEN
--        iStatus := SQLCODE;
--    END;
--  END IF;

  porcActiveLM.batch_no := NVL(sBatch, '-1');
  porcActiveLM.batch_date := NVL(dtBatchDate, TO_DATE('01011980', 'MMDDYYYY'));
  porcActiveLM.start_time := NVL(dtStartTime, TO_DATE('01011980', 'MMDDYYYY'));
  porcActiveLM.stop_time := NVL(dtStopTime, TO_DATE('01011980', 'MMDDYYYY'));
  porcActiveLM.equip_id := NVL(sEquipID, '-1');
  porcActiveLM.parent_batch_no := NVL(sParentBatch, '-1');
  porcActiveLM.upd_user := NVL(sUpdUser, '-1');
  porcActiveLM.loader_status := NVL(sLoaderStatus, 'x');
  poiStatus := iStatus;
END;

FUNCTION write_lm_float_stop (
  pdtStopTime	IN  batch.actl_stop_time%TYPE,
  psUser	IN  usr.user_id%TYPE DEFAULT REPLACE(USER, 'OPS$', ''))
RETURN NUMBER IS
  rcActiveLM	recTypLoaderLM := NULL;
  iTimeSpent	NUMBER := 0;
  iStatus	NUMBER := 0;
BEGIN
  -- Retrieve current active batch for user
  get_active_batch(rcActiveLM, iStatus, psUser);

  IF iStatus = C_NORMAL THEN
    -- Close the active batch
    pl_lm1.create_schedule(rcActiveLM.batch_no, rcActiveLM.stop_time,
                           iTimeSpent);
  ELSE
    RETURN iStatus;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLCODE;
END;
-- ----------------------------------------------------------------------------

FUNCTION write_lm_float_start (
  psTruck	IN  las_pallet.truck%TYPE,
  psFloat	IN  las_pallet.truck%TYPE,
  psUser	IN  usr.user_id%TYPE DEFAULT REPLACE(USER, 'OPS$', ''),
  psAction	IN  VARCHAR2 DEFAULT 'L')
RETURN NUMBER IS
  iStatus		NUMBER := C_NORMAL;
  rcLoaderLM		recTypLoaderLM := NULL;
  sLMActive		sys_config.config_flag_val%TYPE := NULL;
  iLMNeedIStart		NUMBER := 0;
  sUnloadSyspar		sys_config.config_flag_val%TYPE := NULL;
  sLDBatch		batch.batch_no%TYPE := NULL;
  sLDBatchStatus	batch.status%TYPE := NULL;
  dtBatchDate		batch.batch_date%TYPE := NULL;
  dtBatchStart		batch.actl_start_time%TYPE := NULL;
  dtBatchStop		batch.actl_stop_time%TYPE := NULL;
  sSupervisor		batch.user_supervsr_id%TYPE := NULL;
  iDurStart		NUMBER := 0;
  iDurStop		NUMBER := 0;
  sCLBatch		batch.batch_no%TYPE := NULL;
  iTimeSpent		NUMBER := 0;
  iNextBatchExt		NUMBER := 1;
  iLBatchStatus		NUMBER := C_NORMAL;
  sStatus		VARCHAR2(2) := NULL;
BEGIN
  -- Retrieve loader batch basic information
  get_basic_loader_info (psTruck, psFloat, psUser,rcLoaderLM,
                         iStatus);

  IF iStatus NOT IN (C_NORMAL, C_NO_LM_BATCH_FOUND) THEN
    RETURN iStatus;
  END IF;
  IF rcLoaderLM.lbr_mgmt_flag = 'N' THEN
    RETURN C_LM_NOT_ACTIVE;
  END IF;
  iLBatchStatus := iStatus;

  IF iLBatchStatus = C_NO_LM_BATCH_FOUND THEN
    IF rcLoaderLM.lbr_mgmt_flag = 'Y' THEN
      RETURN iLBatchStatus;
    END IF;
  END IF;








  -- Complete any active batch for user if LM flag is set
  iStatus := write_lm_float_stop(psUser, NULL);

  IF iStatus <> C_NORMAL THEN
    IF iStatus = C_LM_NOT_ACTIVE THEN
      RETURN C_NORMAL;
    END IF;
    RETURN iStatus;
  END IF;

/*
  -- 
  BEGIN
    pl_task_assign.check_for_istart(psUser, sStatus);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END;

  IF sStatus = 'N' THEN
    BEGIN
      pl_task_assign.ins_istart('N', psUser, sSupervisor, '<lbrgroup>',
                                NULL, sStatus, dtIStartStopTime, sIStartBatch);
    EXCEPTION
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;
  END IF;

  IF iLMNeedIStart = 1 THEN
    -- Determine ISTART duration
    BEGIN
      SELECT NVL(st.start_dur, 0) INTO iDurStart
      FROM sched_type st, sched s, usr u, batch b, job_code jc
      WHERE st.sctp_sched_type = s.sched_type
      AND   s.sched_lgrp_lbr_grp = u.lgrp_lbr_grp
      AND   s.sched_jbcl_job_class = jc.jbcl_job_class
      AND   s.sched_actv_flag = 'Y'
      AND   REPLACE(u.user_id, 'OPS$', '') = REPLACE(psUser, 'OPS$', '')
      AND   jc.jbcd_job_code = b.jbcd_job_code
      AND   b.batch_no = sLDBatch;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;

    -- Add ISTART
    BEGIN
      INSERT INTO batch
        (batch_no,
         batch_date, jbcd_job_code, status,
         actl_start_time,
         actl_stop_time,
         actl_time_spent,
         user_id, user_supervsr_id,
         kvi_doc_time, kvi_cube, kvi_wt, kvi_no_piece, kvi_no_pallet,
         kvi_no_item, kvi_no_data_capture, kvi_no_po, kvi_no_stop,
         kvi_no_zone, kvi_no_loc, kvi_no_case, kvi_no_split, kvi_no_merge,
         kvi_no_aisle, kvi_no_drop, kvi_order_time,
         no_lunches, no_breaks, damage)
        VALUES (
         'I' || TO_CHAR(seq1.nextval),
         TRUNC(SYSDATE), 'ISTART', 'C',
         SYSDATE - (iDurStart / 1440),
         SYSDATE,
         iDurStart,
         psUser, sSupervisor,
         0, 0, 0, 0, 0,
         0, 0, 0, 0,
         0, 0, 0, 0, 0,
         0, 0, 0,
         0, 0, 0);
    EXCEPTION
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;
  END IF;

  IF sLDBatchStatus = 'C' THEN
    -- If current loader batch is already in complete status, create a new
    -- one for the original batch # with extension
    BEGIN
      SELECT COUNT(batch_no) INTO iNextBatchExt
      FROM batch
      WHERE batch_no LIKE sLDBatch || DECODE(psAction, 'L', 'R', 'U') || '%';
    EXCEPTION
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;

    BEGIN
      INSERT INTO batch
        (batch_no,
         batch_date, status, user_id, user_supervsr_id,
         jbcd_job_code, ref_no,
         actl_start_time,
         goal_time,
         target_time,
         kvi_cube, kvi_wt, kvi_no_piece, kvi_no_case, kvi_no_split,
         kvi_no_merge, kvi_no_item, kvi_no_stop, kvi_no_pallet,
         kvi_no_pallet_piece, kvi_no_cart, kvi_no_cart_piece,
         total_count, total_pallet, total_piece)
        SELECT batch_no || DECODE(psAction, 'L', 'R', 'U') || 
                 TO_CHAR(iNextBatchExt + 1),
               batch_date, 'A', psUser, sSupervisor,
               jbcd_job_code, ref_no,
               NVL(dtBatchDate, SYSDATE),
               DECODE(sUnloadSyspar, 'N', 0, goal_time),
               DECODE(sUnloadSyspar, 'N', 0, target_time),
               kvi_cube, kvi_wt, kvi_no_piece, kvi_no_case, kvi_no_split,
               kvi_no_merge, kvi_no_item, kvi_no_stop, kvi_no_pallet,
               kvi_no_pallet_piece, kvi_no_cart, kvi_no_cart_piece,
               total_count, total_pallet, total_piece
        FROM batch
        WHERE batch_no = sLDBatch;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;
  ELSE  -- Current loader batch is either Active or Future
    BEGIN
      UPDATE BATCH
      SET actl_start_time = dtBatchDate,
          user_supervsr_id = sSupervisor,
          user_id = REPLACE(psUser, 'OPS$', ''),
          status = 'A'
      WHERE batch_no = sLDBatch 
      AND   actl_start_time IS NULL;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;
  END IF;  -- Current loader batch is in complete status
*/
  RETURN C_NORMAL;
END;
-- ----------------------------------------------------------------------------

PROCEDURE get_truck_accessory_list (
  psTruck	IN  las_truck_equipment.truck%TYPE,
  potbAccessory	OUT tabTypTruckAccessory,  
  psCompartment	IN  las_truck_equipment.compartment%TYPE DEFAULT NULL,
  piManifest	IN  las_truck_equipment.manifest_no%TYPE DEFAULT NULL,
  psRoute	IN  las_truck_equipment.route_no%TYPE DEFAULT NULL,
  psIgnrBarcode	IN  VARCHAR2 DEFAULT 'N',
  psInitCap	IN  VARCHAR2 DEFAULT 'Y',
  piIncNoAcc	IN  NUMBER DEFAULT 0) IS
  dtLatest	DATE := NULL;
  iIndex	NUMBER := 0;
  iIndex2	NUMBER := 0;
  iIndex3	NUMBER := 0;
  tbParam	tabTypPTypParam;
  tbAcc		tabTypTruckAccessory;
  tbAcc2	tabTypTruckAccessory;
  blnFound	BOOLEAN := FALSE;
  sName		equip_param.name%TYPE := NULL;
  sScannable	equip_param.scannable%TYPE := NULL;
  CURSOR c_get_latest IS
    SELECT MAX(e.add_date)
    FROM las_truck_equipment e, equip_param p
    WHERE e.type_seq = p.seq
    AND   e.truck = psTruck
    AND   ((psCompartment IS NULL) OR
           ((psCompartment IS NOT NULL) AND
            (e.compartment = psCompartment)))
    AND   ((piManifest IS NULL) OR
           ((piManifest IS NOT NULL) AND
            (e.manifest_no = piManifest)))
    AND   ((psRoute IS NULL) OR
           ((psRoute IS NOT NULL) AND
            (e.route_no = psRoute)));
  CURSOR c_get_truck_accessory (cpdtDate DATE) IS
    SELECT e.compartment, e.type_seq,
           SUM(NVL(e.loader_count, 0)) loader_count,
           SUM(NVL(e.inbound_count, 0)) inbound_count,
           TRUNC(e.ship_date) ship_date, e.barcode, e.manifest_no,
           e.route_no, p.name
    FROM las_truck_equipment e, equip_param p
    WHERE e.type_seq = p.seq
    AND   e.truck = psTruck
    AND   ((psCompartment IS NULL) OR
           ((psCompartment IS NOT NULL) AND
            (e.compartment = psCompartment)))
    AND   ((piManifest IS NULL) OR
           ((piManifest IS NOT NULL) AND
            (e.manifest_no = piManifest)))
    AND   ((psRoute IS NULL) OR
           ((psRoute IS NOT NULL) AND
            (e.route_no = psRoute)))
    AND   ((cpdtDate IS NULL) OR
           ((cpdtDate IS NOT NULL) AND
            (cpdtDate BETWEEN cpdtDate - 1 / 3 AND cpdtDate)))
    GROUP BY e.route_no, e.compartment, TRUNC(e.ship_date),
             e.manifest_no, e.barcode, p.name, e.type_seq
    ORDER BY e.type_seq;
BEGIN
  OPEN c_get_latest;
  FETCH c_get_latest INTO dtLatest;
  CLOSE c_get_latest;
  IF dtLatest IS NULL THEN
    dtLatest := SYSDATE;
  END IF;
  iIndex := 0;
  sName := '?-1';
  FOR cgta IN c_get_truck_accessory(dtLatest) LOOP
    IF (psIgnrBarcode = 'N') OR
       (psIgnrBarcode = 'Y' AND UPPER(sName) <> UPPER(cgta.name)) THEN
      iIndex := iIndex + 1;
      tbAcc(iIndex).compartment := NVL(cgta.compartment, 'X');
      IF LTRIM(RTRIM(cgta.compartment)) IS NULL THEN
        tbAcc(iIndex).compartment := 'X';
      END IF;
      tbAcc(iIndex).name := NVL(cgta.name, 'No name');
      BEGIN
        SELECT NVL(scannable, 'N') INTO sScannable
        FROM equip_param
        WHERE name = cgta.name;
      EXCEPTION
        WHEN OTHERS THEN
          sScannable := 'N';
      END;
      tbAcc(iIndex).scannable := NVL(sScannable, 'N');
      tbAcc(iIndex).loader_count := NVL(cgta.loader_count, 0);
      tbAcc(iIndex).inbound_count := NVL(cgta.inbound_count, 0);
      tbAcc(iIndex).ship_date :=
        NVL(cgta.ship_date, TO_DATE('01011980', 'MMDDYYYY'));
      tbAcc(iIndex).barcode := NVL(cgta.barcode, '?');
      tbAcc(iIndex).manifest_no := NVL(cgta.manifest_no, -1);
      tbAcc(iIndex).route_no := NVL(cgta.route_no, '-1');
      sName := cgta.name;
    ELSE
      IF psIgnrBarcode = 'Y' THEN
        tbAcc(iIndex).loader_count := NVL(tbAcc(iIndex).loader_count, 0) +
          NVL(cgta.loader_count, 0);
        tbAcc(iIndex).inbound_count := NVL(tbAcc(iIndex).inbound_count, 0) +
          NVL(cgta.inbound_count, 0);
      END IF;
    END IF;
  END LOOP;

  IF piIncNoAcc <> 0 THEN
    get_type_params(tbParam, 'TRK', 'N');
    FOR iIndex2 IN 1 .. iIndex LOOP
      tbAcc2(iIndex2) := tbAcc(iIndex2);
    END LOOP;
    FOR iIndex2 IN 1 .. tbParam.COUNT LOOP
      blnFound := FALSE;
      FOR iIndex3 IN 1 .. tbAcc2.COUNT LOOP
        IF UPPER(tbParam(iIndex2)) = UPPER(tbAcc2(iIndex3).name) THEN
          blnFound := TRUE;
	END IF;
      END LOOP;
      IF NOT blnFound THEN
        iIndex := iIndex + 1;
        tbAcc(iIndex).compartment := 'X';
        tbAcc(iIndex).name := tbParam(iIndex2);
        tbAcc(iIndex).loader_count := -1;
        tbAcc(iIndex).inbound_count := -1;
        tbAcc(iIndex).ship_date := TO_DATE('01011980', 'MMDDYYYY');
        tbAcc(iIndex).barcode := '?';
        tbAcc(iIndex).manifest_no := 0;
        tbAcc(iIndex).route_no := '-1';
        tbAcc(iIndex).scannable := 'N';
      END IF;
    END LOOP;
  END IF;

  FOR iIndex2 IN 1 .. iIndex LOOP
    potbAccessory(iIndex2).compartment := tbAcc(iIndex2).compartment;
    IF psInitCap = 'Y' THEN
      potbAccessory(iIndex2).name := INITCAP(tbAcc(iIndex2).name);
    ELSE
      potbAccessory(iIndex2).name := tbAcc(iIndex2).name;
    END IF;
    potbAccessory(iIndex2).loader_count := tbAcc(iIndex2).loader_count;
    potbAccessory(iIndex2).inbound_count := tbAcc(iIndex2).inbound_count;
    potbAccessory(iIndex2).ship_date := tbAcc(iIndex2).ship_date;
    potbAccessory(iIndex2).barcode := tbAcc(iIndex2).barcode;
    potbAccessory(iIndex2).manifest_no := tbAcc(iIndex2).manifest_no;
    potbAccessory(iIndex2).route_no := tbAcc(iIndex2).route_no;
  END LOOP;
END;
-- ----------------------------------------------------------------------------

PROCEDURE get_compartment_status(
  psTruck	IN  las_pallet.truck%TYPE,
  posDry	OUT VARCHAR2,
  posCooler	OUT VARCHAR2,
  posFreezer	OUT VARCHAR2,
  posTruck	OUT VARCHAR2) IS
  sDryStatus		las_truck.dry_status%TYPE := NULL;
  sCoolerStatus		las_truck.cooler_status%TYPE := NULL;
  sFreezerStatus	las_truck.freezer_status%TYPE := NULL;
  sTruckStatus		las_truck.truck_status%TYPE := NULL;
  iNumDryPallets	NUMBER := 0;
  iNumCoolerPallets	NUMBER := 0;
  iNumFreezerPallets	NUMBER := 0;
BEGIN
  posDry := NULL;
  posCooler := NULL;
  posFreezer := NULL;  
  posTruck := NULL;

  SELECT dry_status, cooler_status, freezer_status,
         NVL(TO_NUMBER(dry_pallets), 0),
         NVL(TO_NUMBER(cooler_pallets), 0),
         NVL(TO_NUMBER(freezer_pallets), 0),
	 NVL(truck_status, 'N')
  INTO sDryStatus, sCoolerStatus, sFreezerStatus,
       iNumDryPallets, iNumCoolerPallets, iNumFreezerPallets,
       sTruckStatus
  FROM las_truck
  WHERE truck = psTruck;

  IF iNumDryPallets = 0 THEN
     posDry := 'X';
  ELSE
    posDry := LTRIM(RTRIM(nvl(sDryStatus, 'A')));
  END IF;

  IF iNumCoolerPallets = 0 THEN
     posCooler := 'X';
  ELSE
    posCooler := LTRIM(RTRIM(nvl(sCoolerStatus, 'A')));
  END IF;

  IF iNumFreezerPallets = 0 THEN
    posFreezer := 'X';
  ELSE
    posFreezer := LTRIM(RTRIM(nvl(sFreezerStatus, 'A')));
  END IF;

  posTruck := sTruckStatus;

EXCEPTION
  WHEN OTHERS THEN
    posDry := 'B';
    posCooler := 'B';
    posFreezer := 'B';
    posTruck := 'B';
END;

-- ----------------------------------------------------------------------------

--PROCEDURE get_sls_label_type (
--  psFloatLabel		IN  VARCHAR2,
--  piOption		IN  NUMBER,
--  posField1		OUT VARCHAR2,
--  posField2		OUT VARCHAR2,
--  poiLblType		OUT NUMBER,
--  psTruck		IN  sls_load_map.truck_no%TYPE DEFAULT NULL) IS
--  -- Format C is character/string. 9 is numeric from 0 to 9
--  sField1	VARCHAR2(50) := NULL;
--  iNum		NUMBER := 0;
--  iExists	NUMBER := 0;
--  sField11	VARCHAR2(50) := NULL;
--  sField12	VARCHAR2(50) := NULL;
--  sTruck	sls_load_map.truck_no%TYPE := NULL;
--  hiType	NUMBER := C_NORMAL;
--  sTruckOut	sls_load_map.truck_no%TYPE := NULL;
--  sField2Out	VARCHAR2(10) := NULL;
--BEGIN
--  posField1 := NULL;
--  posField2 := NULL;
--  poiLblType := C_NORMAL;
--
--  IF LTRIM(RTRIM(psFloatLabel)) IS NULL THEN
--    -- No label or value is input. Treat it as invalid label
--    posField1 := 'x';
--    posField2 := 'x';
--    poiLblType := -1;
--    RETURN;
--  END IF;
--
--  sField1 := SUBSTR(psFloatLabel, 1, INSTR(psFloatLabel, ' ') - 1);
--  IF sField1 IS NULL THEN
--    -- No space in between 2 fields. This can be a case label,
--    -- a zone label, a truck+compartment value, a truck value
--    -- for closing truck or unloading truck.
--    IF INSTR(psFloatLabel, 'Z', C_TRAILER_NO_LEN + 1) <> 0 THEN
--      -- This is a zone label in the format CCCCCCZ9.
--      -- Field1 is the trailer #. Field2 is the zone.
--      sTruckOut := INSTR(psFloatLabel, 1,
--                         INSTR(psFloatLabel, 'Z', C_TRAILER_NO_LEN + 1) - 1);
--      sField2Out := INSTR(psFloatLabel,
--                          INSTR(psFloatLabel, 'Z', C_TRAILER_NO_LEN + 1));
--      posField1 := sTruckOut;
--      posField2 := sField2Out;
--      hiType := C_LBL_TYPE_ZONE;
--    END IF;
--    IF hiType = C_NORMAL AND
--       SUBSTR(psFloatLabel, C_TRUCK_NO_SLS_LEN + 1) IN ('C', 'D', 'F') THEN
--      -- A compartment label format CCCCC.
--      -- Field1 is truck #. Field2 is compartment code.
--      sTruckOut := INSTR(psFloatLabel, 1, C_TRUCK_NO_SLS_LEN);
--      sField2Out := INSTR(psFloatLabel, C_TRUCK_NO_SLS_LEN + 1);
--      posField1 := sTruckOut;
--      posField2 := sField2Out;
--      sTruckOut := INSTR(psFloatLabel, 1, C_TRUCK_NO_SLS_LEN);
--      IF piOption = C_OPT_CL_ACCESSORY_RECALL THEN
--        hiType := C_LBL_TYPE_COMPRT_ACC;
--      ELSE
--        hiType := C_LBL_TYPE_COMPARTMENT;
--      END IF;
--    END IF;
--    IF hiType = C_NORMAL THEN
--      BEGIN
--        SELECT TO_NUMBER(psFloatLabel) INTO iNum FROM DUAL;
--        -- The label contents all digits
--        -- Check if it's a valid case label or truck #
--        IF piOption = C_OPT_CL_CLOSE_TRUCK THEN
--          -- Explicitly specify as a truck # for close
--          hiType := C_LBL_TYPE_TRUCK;
--        ELSIF piOption = C_OPT_CL_UNLOAD_TRUCK THEN
--          -- Explicitly specify as a truck # for unload
--          hiType := C_LBL_TYPE_TRUCK_UNLOAD;
--        ELSE
--          -- Check if it's a case label
--          BEGIN
--            -- Physical label has 11 digits but database has only 8 digits
--            SELECT 1 INTO iNum
--            FROM ordd
--            WHERE seq = TO_NUMBER(SUBSTR(psFloatLabel, 1, C_ORDD_SEQ_DB_LEN))
--            AND   ROWNUM = 1;
--            -- It's a case label and it exists
--            hiType := C_LBL_TYPE_CASE;
--          EXCEPTION
--            WHEN OTHERS THEN
--              -- Error condition
--              hiType := -1;
--          END;
--        END IF;
--      EXCEPTION  -- Label has alphanumeric characters
--        WHEN OTHERS THEN
--          IF piOption = C_OPT_CL_CLOSE_TRUCK THEN
--            -- Explicitly specify as a truck # for close
--            hiType := C_LBL_TYPE_TRUCK;
--          ELSIF piOption = C_OPT_CL_UNLOAD_TRUCK THEN
--            -- Explicitly specify as a truck for unload
--            hiType := C_LBL_TYPE_TRUCK_UNLOAD;
--          ELSE
--            -- The label is invalid
--            hiType := -1;
--          END IF;  
--      END;
--    END IF;
--  ELSE  -- Float label
--    sTruckOut := sField1;
--    sField2Out := LTRIM(RTRIM(SUBSTR(psFloatLabel,
--                                     INSTR(psFloatLabel, ' ') + 1))); 
--    posField1 := sTruckOut;
--    posField2 := sField2Out; 
--    IF piOption IN (C_OPT_CL_UNLOAD_FLOAT, C_OPT_CL_UNLOAD_FLOAT_2ND) THEN
--      -- Explicitly specify as a float for unload
--      hiType := C_LBL_TYPE_FLOAT_UNLOAD;
--    ELSIF piOption = C_OPT_CL_ZONE_FUNC1 THEN
--      -- Explicitly specify as a float for exit
--      hiType := C_LBL_TYPE_ZONE_EXIT;
--    ELSE
--      hiType := C_LBL_TYPE_FLOAT;
--    END IF;
--  END IF;  -- psFloatLabel IS NOT NULL/NULL
--
--  -- This is to prevent the NULL value returned problem of ProC
--  IF sTruckOut IS NULL THEN
--    posField1 := 'x';
--  END IF;
--  IF sField2Out IS NULL THEN
--    posField2 := 'x';
--  END IF;
--  IF hiType <> -1 THEN
--    IF hiType IN (C_LBL_TYPE_FLOAT, C_LBL_TYPE_FLOAT_UNLOAD,
--                  C_LBL_TYPE_ZONE_EXIT, C_LBL_TYPE_ZONE,
--                  C_LBL_TYPE_COMPARTMENT, C_LBL_TYPE_COMPRT_ACC,
--                  C_LBL_TYPE_TRUCK, C_LBL_TYPE_TRUCK_UNLOAD) THEN
--      IF hiType = C_LBL_TYPE_ZONE AND psTruck IS NOT NULL THEN
--        sTruck := psTruck;
--      ELSE
--        sTruck := sTruckOut;
--      END IF;
--      BEGIN
--        SELECT truck, trailer INTO sField11, sField12
--        FROM las_truck
--        WHERE truck = sTruckOut;
--      EXCEPTION
--        WHEN OTHERS THEN
--          hiType := C_TRUCK_NOT_AVAIL;
--      END;
--      IF hiType <> C_TRUCK_NOT_AVAIL THEN
--        IF hiType = C_LBL_TYPE_ZONE THEN
--          IF sField12 IS NOT NULL AND
--             sField12 <> sTruckOut THEN
--            hiType := C_TRAILER_USED;
--          END IF;
--          IF hiType <> C_TRAILER_USED AND
--             TO_NUMBER(REPLACE(LTRIM(RTRIM(sField2Out)), 'Z', ''))
--               NOT BETWEEN C_MIN_FLOAT_SEQ_ZONE AND C_MAX_FLOAT_SEQ_ZONE THEN
--            hiType := C_INV_ZONE;
--          END IF;
--        END IF;
--      END IF;
--    END IF;
--    IF hiType IN (C_LBL_TYPE_FLOAT, C_LBL_TYPE_FLOAT_UNLOAD,
--                  C_LBL_TYPE_ZONE_EXIT) THEN
--      BEGIN
--        SELECT 1 INTO iExists
--        FROM las_pallet
--        WHERE truck = sTruckOut 
--        AND   palletno = sField2Out;
--      EXCEPTION
--        WHEN OTHERS THEN
--          hiType := C_INV_FLOAT_SEQ;
--      END;
--    END IF;
--  END IF;
--
--  poiLblType := hiType;
--END;
-- ----------------------------------------------------------------------------

PROCEDURE get_dock_info (
  psTruck	IN  route.truck_no%TYPE,
  poiNumPallets	OUT NUMBER,
  potbDock	OUT pl_nos.tabString,
  piNoDuplicate	IN  NUMBER DEFAULT 1) IS
  blnFound	BOOLEAN := FALSE;
  i		NUMBER := 0;
  iIndex	NUMBER := 0;
  tbDock	pl_nos.tabString;
BEGIN
  poiNumPallets := 0;

  -- Retrieve pallet data that are not loaded and not in selection for the
  -- truck for all zones
--  FOR cglpd IN c_get_las_pallet_desc(psTruck, 'X', 'X') LOOP
--    blnFound := FALSE;
--    IF piNoDuplicate = 1 THEN
--      FOR i IN 1 .. tbDock.COUNT LOOP
--        IF cglpd.palletno = tbDock(i) THEN
--          blnFound := TRUE;
--          EXIT;
--        END IF;
--      END LOOP;
--    END IF;
--    IF NOT blnFound THEN
--      iIndex := iIndex + 1;
--      tbDock(iIndex) := cglpd.palletno;
--    END IF;
--  END LOOP;

  poiNumPallets := iIndex;
  FOR i IN 1 .. iIndex LOOP
    potbDock(i) := tbDock(i);
  END LOOP;
END;

-- ----------------------------------------------------------------------------

PROCEDURE get_dock_pallets (
   psTruck	IN  route.truck_no%TYPE,
   potbPallets	OUT tabPalInfo) IS
  iIndex	NUMBER := 0;
  tbPallets	tabPalInfo;
  CURSOR c_get_dock_pallets IS
    SELECT LTRIM(RTRIM(p.palletno)) pallet,
           s.sort_seq,
           TO_NUMBER(SUBSTR(LTRIM(RTRIM(p.palletno)), 2)) sortp
    FROM las_pallet p, las_pallet_sort s
    WHERE LTRIM(RTRIM(p.truck)) = psTruck
    AND   SUBSTR(LTRIM(RTRIM(p.palletno)), 1, 1) = s.pallettype
    AND   NVL(p.loader_status, ' ') <> C_LOADED_STATUS
    MINUS
    SELECT f.float_seq pallet,
           s.sort_seq,
           TO_NUMBER(SUBSTR(f.float_seq, 2)) sortp
    FROM floats f, float_detail d, las_pallet_sort s
    WHERE f.float_no = d.float_no
    AND   f.truck_no = psTruck
    AND   SUBSTR(f.float_seq, 1, 1) = s.pallettype
    AND   EXISTS (SELECT 1
                  FROM float_detail d2
                  WHERE d2.float_no = d.float_no
                  AND   d2.src_loc = d.src_loc
                  AND   d2.prod_id = d.prod_id
                  AND   d2.stop_no = d.stop_no
                  AND   d2.order_seq = d.order_seq
                  AND   d2.sos_status NOT IN ('S', 'C'))
    ORDER BY 2, 3;
BEGIN
  FOR cgdp IN c_get_dock_pallets LOOP
    iIndex := iIndex + 1;
    tbPallets(iIndex).pallet := cgdp.pallet;
    tbPallets(iIndex).zone := 0;
  END LOOP;

  potbPallets := tbPallets;
END;
-- ----------------------------------------------------------------------------

PROCEDURE get_loaded_pallets (
   psTruck	IN  route.truck_no%TYPE,
   potbPallets	OUT tabPalInfo,
   piZone	IN  NUMBER DEFAULT NULL) IS
  iIndex	NUMBER := 0;
  tbPallets	tabPalInfo;
  CURSOR c_get_loaded_pallets IS
    SELECT LTRIM(RTRIM(p.palletno)) pallet,
           TO_NUMBER(REPLACE(LTRIM(RTRIM(p.truck_zone)), 'Z', '')) zone
    FROM v_las_pallet p
    WHERE LTRIM(RTRIM(p.truck)) = psTruck
    AND   LTRIM(RTRIM(p.batch)) IS NOT NULL
    AND   LTRIM(RTRIM(p.palletno)) IS NOT NULL
    AND   LTRIM(RTRIM(p.truck_zone)) IS NOT NULL
    AND   NVL(p.loader_status, ' ') = C_LOADED_STATUS
    AND   ((piZone IS NULL) OR
           ((piZone IS NOT NULL) AND
            (NVL(TO_NUMBER(LTRIM(RTRIM(REPLACE(p.truck_zone, 'Z', '')))), 0) =
             piZone)))
    ORDER BY NVL(p.upd_date, p.add_date) DESC, p.sort_seq,
             TO_NUMBER(SUBSTR(LTRIM(RTRIM(p.palletno)), 2));
BEGIN
  FOR cglp IN c_get_loaded_pallets LOOP
    iIndex := iIndex + 1;
    tbPallets(iIndex).pallet := cglp.pallet;
    tbPallets(iIndex).zone := cglp.zone;
  END LOOP;

  potbPallets := tbPallets;
END;
-- ----------------------------------------------------------------------------

PROCEDURE get_trailer_notes (
   psTruck	IN  route.truck_no%TYPE,
   potbNotes	OUT tabNoteInfo) IS
  blnContinue	BOOLEAN;
  sNote1	las_truck.note1%TYPE := NULL;
  sNote2	las_truck.note2%TYPE := NULL;
  sNote3	las_truck.note3%TYPE := NULL;
  iIndex	NUMBER := 0;
  tbNotes	tabNoteInfo;
BEGIN
  blnContinue := FALSE;
  BEGIN
    SELECT note1, note2, note3 INTO sNote1, sNote2, sNote3
    FROM las_truck
    WHERE truck = psTruck;

    IF sNote1 IS NULL AND sNote2 IS NULL AND sNote3 IS NULL THEN
      blnContinue := TRUE;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      blnContinue := TRUE;
  END;

  IF blnContinue THEN
    BEGIN
      SELECT note1, note2, note3 INTO sNote1, sNote2, sNote3
      FROM sls_note_hist h
      WHERE truck_no = psTruck
      AND   add_date = (SELECT MAX(add_date)
                        FROM sls_note_hist
                        WHERE truck_no = h.truck_no);
    EXCEPTION
      WHEN OTHERS THEN
        NULL;     
    END;
  END IF;

  IF sNote1 IS NOT NULL THEN
    iIndex := iIndex + 1;
    tbNotes(iIndex) := sNote1;
  END IF;
  IF sNote2 IS NOT NULL THEN
    iIndex := iIndex + 1;
    tbNotes(iIndex) := sNote2;
  END IF;
  IF sNote3 IS NOT NULL THEN
    iIndex := iIndex + 1;
    tbNotes(iIndex) := sNote3;
  END IF;

  potbNotes := tbNotes;
END;
-- ----------------------------------------------------------------------------

PROCEDURE get_in_selection_pallets (
  psTruck	route.truck_no%TYPE,
  poiNumPallets	OUT NUMBER,
  potbPallets	OUT pl_nos.tabTypFloatSummary,
  piZone	IN  NUMBER DEFAULT NULL,
  piNoDuplicate	IN  NUMBER DEFAULT NULL) IS
  blnFound	BOOLEAN := FALSE;
  i		NUMBER := 0;
  iIndex	NUMBER := 0;
  tbPallets	pl_nos.tabTypFloatSummary;
  iDoor		route.f_door%TYPE := NULL;
BEGIN
  poiNumPallets := 0;

  -- Retrieve all in-selection pallets for all zones of the truck
--  FOR cglpd IN c_get_las_pallet_desc(psTruck, 'X', 'S', piZone) LOOP
--    blnFound := FALSE;
--    IF piNoDuplicate IS NULL THEN
--      FOR i IN 1 .. tbPallets.COUNT LOOP
--        IF cglpd.palletno = tbPallets(i).palletno THEN
--          blnFound := TRUE;
--          EXIT;
--        END IF;
--      END LOOP;
--    END IF;
--    IF NOT blnFound THEN
--      iIndex := iIndex + 1;
--      tbPallets(iIndex).truck_no := cglpd.truck;
--      tbPallets(iIndex).palletno := cglpd.palletno;
--      tbPallets(iIndex).truck_zone := NVL(cglpd.truck_zone, '-1');
--      FOR cgd IN c_get_door(psTruck, SUBSTR(cglpd.palletno, 1, 1)) LOOP
--        tbPallets(iIndex).door := cgd.door;
--        iDoor := cgd.door;
--      END LOOP;
--      IF iDoor IS NULL THEN
--        tbPallets(iIndex).door := -1;
--      END IF;
--      tbPallets(iIndex).loader_status := NVL(cglpd.loader_status, 'X');
--      tbPallets(iIndex).selection_status := NVL(cglpd.selection_status, 'X');
--      tbPallets(iIndex).batch := NVL(cglpd.batch, '-1');
--    END IF;
--  END LOOP;

  poiNumPallets := iIndex;
  FOR i IN 1 .. iIndex LOOP
    potbPallets(i) := tbPallets(i);
  END LOOP;
END;

-- ----------------------------------------------------------------------------

FUNCTION get_total_truck_count (psStmt	IN  VARCHAR2)
RETURN NUMBER IS
  iConnCursor	NUMBER := 0;
  iNumTrucks	NUMBER := 0;
  iStatus	NUMBER := 0;
  sStmt		VARCHAR2(4000) := psStmt;
  iRows		NUMBER := 0;
BEGIN
  sStmt := 'SELECT COUNT(DISTINCT truck) ';
  sStmt := sStmt || 'FROM v_las_truck_sort WHERE ';
  sStmt := sStmt || psStmt;

  iConnCursor := DBMS_SQL.OPEN_CURSOR;
  DBMS_SQL.PARSE(iConnCursor, sStmt, DBMS_SQL.NATIVE);
  DBMS_SQL.DEFINE_COLUMN(iConnCursor, 1, iNumTrucks);
  iStatus := DBMS_SQL.EXECUTE(iConnCursor);
  iRows := DBMS_SQL.FETCH_ROWS(iConnCursor);
  IF iRows > 0 THEN
    DBMS_SQL.COLUMN_VALUE(iConnCursor, 1, iNumTrucks);
  END IF;
  DBMS_SQL.CLOSE_CURSOR(iConnCursor);
  RETURN iNumTrucks;
EXCEPTION
  WHEN OTHERS THEN
    RETURN 0;
END;
-- ----------------------------------------------------------------------------

FUNCTION get_dynamic_one_value (
  psStmt	IN  VARCHAR2,
  piAction	IN  NUMBER,
  piValueSize	IN  NUMBER DEFAULT 4000)
RETURN VARCHAR2 IS
  iConnCursor	NUMBER := 0;
  iValueCnt	NUMBER := 0;
  sValue	VARCHAR2(4000) := NULL;
  iStatus	NUMBER := 0;
  sStmt		VARCHAR2(4000) := psStmt;
  iRows		NUMBER := 0;
BEGIN
  iConnCursor := DBMS_SQL.OPEN_CURSOR;
  DBMS_SQL.PARSE(iConnCursor, sStmt, DBMS_SQL.NATIVE);
  IF piAction = 1 THEN
    -- Retrieve the total # of rows retrieved for the input statement psStmt
    DBMS_SQL.DEFINE_COLUMN(iConnCursor, 1, iValueCnt);
  ELSIF piAction = 2 THEN
    -- Retrieve the appl_type
    DBMS_SQL.DEFINE_COLUMN(iConnCursor, 1, sValue, piValueSize);
  END IF;
  iStatus := DBMS_SQL.EXECUTE(iConnCursor);
  iRows := DBMS_SQL.FETCH_ROWS(iConnCursor);
  IF iRows > 0 THEN
    IF piAction = 1 THEN
      DBMS_SQL.COLUMN_VALUE(iConnCursor, 1, iValueCnt);
    ELSIF piAction = 2 THEN
      DBMS_SQL.COLUMN_VALUE(iConnCursor, 1, sValue);
    END IF;
  END IF;
  DBMS_SQL.CLOSE_CURSOR(iConnCursor);
  IF piAction = 1 THEN
    RETURN TO_CHAR(iValueCnt);
  ELSIF piAction = 2 THEN
    RETURN sValue;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
-- ----------------------------------------------------------------------------

FUNCTION get_sls_load_map_queue (
  psWhere	IN  VARCHAR2 DEFAULT NULL,
  psQueueOnly	IN  VARCHAR2 DEFAULT 'Y')
RETURN VARCHAR2 IS
  tbConfig	tabTypConfig;
  iStatus	NUMBER := 0;
  sQueue	las_config.config_flag_val%TYPE := NULL;
BEGIN
  IF psWhere IS NULL THEN
    get_sls_config(tbConfig, iStatus, REPLACE(USER, 'OPS$', ''), 'AUTOMAPPTR');
  ELSE
    get_sls_config(tbConfig, iStatus, REPLACE(USER, 'OPS$', ''), psWhere);
  END IF;
  IF tbConfig.COUNT > 0 THEN
    sQueue := LTRIM(RTRIM(tbConfig(1).config_val));
    IF NVL(psQueueOnly, 'Y') = 'Y' THEN
      IF INSTR(sQueue, '-') <> 0 THEN
        -- The value contains at least one flag in it. We can assume that
        -- the queue name is at the beginning of the string
        sQueue := SUBSTR(sQueue, 1, INSTR(sQueue, ' ') - 1);
      END IF;
    END IF;
    RETURN sQueue;
  END IF;
  RETURN NULL;
END;
-- ----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   check_in_subquery
--
-- Description
--   The function checks whether the input clause psCheckClause is part of the
--   subquery (return TRUE) in psCond or not (return FALSE.)
--
-- Parameters
--   psCond (input)
--     Partial conditional statement from an original select statement
--   psCheckClause (input)
--     The clause that is used to check against
--
-- Returns
--   TRUE if psCheckClause is part of the subquery in psCond; otherwise FALSE.
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION check_in_subquery (psCond IN VARCHAR2, psCheckClause IN VARCHAR2)
RETURN BOOLEAN IS
  blnInSubquery	BOOLEAN := FALSE;
  iClauseAt	NUMBER := 0;
  iIndex	NUMBER := 0;
  iParCount	NUMBER := 0;
  iLastRPar	NUMBER := 0;
BEGIN
  iClauseAt := INSTR(UPPER(psCond), psCheckClause, -1);
  IF INSTR(UPPER(psCond), ' FROM ', -1) <> 0 THEN
    -- The where clause includes at least one subquery
    -- The search index should start after the from clause
    iIndex := INSTR(UPPER(psCond), ' FROM ', -1) + 6;
    -- Since subquery is found, we will count that at least one '(' present
    iParCount := 1;
    -- Search the whole string for balances of '('s and ')'s until the
    -- total parenthesis count reaches back to zero
    WHILE (iIndex <= LENGTH(psCond)) AND (iParCount > 0) LOOP
      IF SUBSTR(psCond, iIndex, 1) = '(' THEN
        -- Encounter one '(', add to the parenthesis count
        iParCount := iParCount + 1;
      ELSIF SUBSTR(psCond, iIndex, 1) = ')' THEN
        -- Encounter one ')', reduce the parenthesis count
        iParCount := iParCount - 1;
        iLastRPar := iIndex;
      END IF; 
      iIndex := iIndex + 1;
    END LOOP;
    IF iLastRPar > iClauseAt THEN
      -- The psCheckClause clause is part of the subquery, not part of select
      blnInSubquery := TRUE;
    END IF;
  END IF;
  RETURN blnInSubquery;
END;
-- ----------------------------------------------------------------------------

PROCEDURE last_query (
  psStmt		IN  VARCHAR2,
  posCond		OUT VARCHAR2,
  poiSeq		OUT NUMBER,
  poiStatus		OUT NUMBER,
  piAddSeq		IN  NUMBER DEFAULT 0,
  psAddStmt		IN  VARCHAR2 DEFAULT NULL,
  psAddStmtConnector	IN  VARCHAR2 DEFAULT 'AND') IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  sOrigStmt		VARCHAR2(4000) := psStmt;
  sTable		VARCHAR2(4000) := NULL;
  sCond			VARCHAR2(4000) := NULL;
  sCond2		VARCHAR2(4000) := NULL;
  iFromAt       	NUMBER := 0;
  iWhereAt      	NUMBER := 0;
  iTableAt      	NUMBER := 0;
  iGroupByAt		NUMBER := 0;
  iHavingAt		NUMBER := 0;
  iOrderAt      	NUMBER := 0;
  iSeq			NUMBER := 0;
  blnInSubquery		BOOLEAN := FALSE;
  blnInserted		BOOLEAN := FALSE;
BEGIN
  posCond := NULL;
  poiSeq := -1;
  poiStatus := 0;

  IF sOrigStmt IS NULL THEN
    RETURN;
  END IF;

  -- Get basic statement positions. Assume that subquery is not in the select
  -- and from clauses
  iFromAt := INSTR(UPPER(sOrigStmt), ' FROM ');
  iTableAt := iFromAt + 6;
  iWhereAt := INSTR(UPPER(sOrigStmt), ' WHERE ', iTableAt);

  -- Get table name
  sTable := SUBSTR(sOrigStmt, iTableAt,
                   INSTR(sOrigStmt, ' ', iTableAt) - iTableAt);

  IF iWhereAt <> 0 THEN
    -- A where clause exists. The resulting sCond might include clauses
    -- group by, having, and/or order by. Grab all data after the where clause
    sCond := LTRIM(RTRIM(SUBSTR(sOrigStmt, iWhereAt + 7)));
  ELSE
    -- A where clause doesn't exist. The resulting sCond might include clauses
    -- group by, having, and/or order by. Grab data after the table name
    sCond := LTRIM(RTRIM(SUBSTR(sOrigStmt, iTableAt + LENGTH(sTable) + 1)));
  END IF;
  DBMS_OUTPUT.PUT_LINE('Cond0 [' || sCond || ']');

  -- Get extra statement positions. Search backward so it won't get the
  -- subquery in the where clause
  iGroupByAt := INSTR(UPPER(sCond), ' GROUP BY ', -1);
  blnInSubquery := FALSE;
  IF iGroupByAt <> 0 THEN
    -- Have group by clause. Might have having clause
    iHavingAt := INSTR(UPPER(sCond), ' HAVING ', iGroupByAt + 10);
    blnInSubquery := check_in_subquery(sCond, ' GROUP BY ');
    IF blnInSubquery THEN
      -- Group by clause is part of the subquery so no group by clause (and
      -- hence no having clause) for the main select statement
      iGroupByAt := 0;
      iHavingAt := 0;
    ELSE
      -- Group by clause is part of the main select statement
      blnInSubquery := check_in_subquery(sCond, ' HAVING ');
      IF blnInSubquery THEN
        -- Having clause is part of the subquery, not part of the main select
        iHavingAt := 0;
      END IF;
    END IF;
  ELSE
    -- No group by clause. It must not have having clause
    iHavingAt := 0;
  END IF;
  IF iGroupByAt <> 0 THEN
    -- Have group by clause. The where condition can be determined regardless
    -- having order by clause or not
    iOrderAt := 0;
  ELSE
    IF iWhereAt <> 0 THEN
      -- A where clause is there while no group by clause. Search from the
      -- 'where' word. The sCond value is already included everything after
      -- the 'where' word. Search backward for the order by clause to try to
      -- avoid the where clause subquery if any
      iOrderAt := INSTR(UPPER(sCond), ' ORDER BY ', -1);
      blnInSubquery := check_in_subquery(sCond, ' ORDER BY ');
      IF blnInSubquery THEN
        -- Order by clause is part of the subquery, not part of the main select
        iOrderAt := 0;
      END IF;
    ELSE
      -- A where clause is not there while no group by clause neither. Search
      -- from the 'from' (table) word
      iOrderAt := INSTR(UPPER(sCond), ' ORDER BY ',
                        iFromAt + LENGTH(sTable) + 1);
    END IF;
  END IF;

  DBMS_OUTPUT.PUT_LINE('WhereAt: ' || TO_CHAR(iWhereAt) || ', GroupAt: ' ||
    TO_CHAR(iGroupByAt) || ', HavingAt: ' || TO_CHAR(iHavingAt) ||
    ', OrderAt: ' || TO_CHAR(iOrderAt));
  DBMS_OUTPUT.PUT_LINE('Table [' || sTable || ']');
  DBMS_OUTPUT.PUT_LINE('Cond1 [' || sCond || ']');

  IF iGroupByAt <> 0 THEN
    -- A group by clause exists. The where condition is before the clause
    sCond := LTRIM(RTRIM(SUBSTR(sCond, 1, iGroupByAt - 1)));
  END IF;

  IF iHavingAt <> 0 THEN
    -- A having clause exists. A group by clause must preceed it so we don't
    -- need to do anything here
    NULL;
  END IF;
  
  IF iOrderAt <> 0 THEN
    -- An order by clause exists
    IF iGroupByAt <> 0 THEN
      -- A group by clause also exists in addition to the order by clause.
      -- The where condition is already retrieved. Do anything here
      NULL;
    ELSE
      -- The where condition is before the order by clause
      sCond := LTRIM(RTRIM(SUBSTR(sCond, 1, iOrderAt - 1)));
    END IF;
  END IF;
  sCond := LTRIM(RTRIM(sCond));
  IF SUBSTR(sCond, 1, 1) BETWEEN '1' AND '9' THEN
    -- The where clause part starts with a numeric value from 1 to 9. In this
    -- case we assume that the 1=1, 2=2, ... 9=9 clause is immediately after
    -- the where reserved word without a '(' in front. We just add a '(' and
    -- a ')' for the retrieved condition
    sCond := '(' || sCond || ')';
  END IF;

  DBMS_OUTPUT.PUT_LINE('Cond2 [' || sCond || ']');

  IF psAddStmt IS NOT NULL AND sCond IS NOT NULL THEN
    sCond := sCond || ' ' || psAddStmtConnector || ' ' || psAddStmt;
  END IF;
  DBMS_OUTPUT.PUT_LINE('Cond3 [' || sCond || ']');

  IF sCond IS NULL THEN
    RETURN;
  END IF;

  IF piAddSeq = 0 THEN
    BEGIN 
      SELECT print_query_seq.nextval INTO iSeq
      FROM DUAL;
    EXCEPTION
      WHEN OTHERS THEN
        poiStatus := -1;
        RETURN;
    END;

    DBMS_OUTPUT.PUT_LINE('Created seq: ' || TO_CHAR(iSeq));

    BEGIN
      INSERT INTO print_query(print_query_seq, condition) 
        VALUES (iSeq, sCond);

      IF SQL%ROWCOUNT > 0 THEN
        blnInserted := TRUE;
      END IF;
    EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN
        BEGIN
          UPDATE print_query
            SET condition = sCond
            WHERE print_query_seq = iSeq;
          IF SQL%ROWCOUNT > 0 THEN
            blnInserted := TRUE;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            poiStatus := -2;
            ROLLBACK;
            RETURN;
        END;
      WHEN OTHERS THEN
        ROLLBACK;
        poiStatus := -3;
        RETURN;
    END;
  END IF;

  IF blnInserted OR piAddSeq <> 0 THEN
    posCond := sCond;
    IF piAddSeq = 0 THEN
      poiSeq := iSeq;
    END IF;
    DBMS_OUTPUT.PUT_LINE('Add sequence ok');
    IF blnInserted THEN
      COMMIT;
    END IF;
  END IF;
END;
-- ----------------------------------------------------------------------------

PROCEDURE get_report_info (
  psRptName	IN  print_reports.report%TYPE,
  porwRptInfo	OUT print_reports%ROWTYPE,
  porwQueueInfo	OUT print_queues%ROWTYPE,
  posUser	OUT print_report_queues.user_id%TYPE,
  posUserQueue	OUT print_report_queues.queue%TYPE,
  psRqstUser	IN  usrauth.user_id%TYPE DEFAULT REPLACE(USER, 'OPS$', '')) IS
  rwRptInfo	print_reports%ROWTYPE := NULL;
  rwQueueInfo	print_queues%ROWTYPE := NULL;
  sQueue	print_queues.system_queue%TYPE := NULL;
BEGIN
  porwRptInfo := NULL;
  posUser := NULL;
  posUserQueue := NULL;

  IF LTRIM(RTRIM(psRptName)) IS NULL THEN
    RETURN;
  END IF;

  BEGIN
    SELECT report, queue_type, descrip, command, fifo, filter, copies, duplex
    INTO rwRptInfo.report, rwRptInfo.queue_type, rwRptInfo.descrip,
         rwRptInfo.command, rwRptInfo.fifo, rwRptInfo.filter,
         rwRptInfo.copies, rwRptInfo.duplex
    FROM print_reports
    WHERE LOWER(report) = LOWER(psRptName);

    porwRptInfo := rwRptInfo;
  EXCEPTION
    WHEN OTHERS THEN
      porwRptInfo := NULL;
  END;

  IF LTRIM(RTRIM(rwRptInfo.queue_type)) IS NOT NULL THEN
    BEGIN
      SELECT REPLACE(user_id, 'OPS$', ''), queue INTO posUser, sQueue
      FROM print_report_queues
      WHERE queue_type = rwRptInfo.queue_type
      AND   user_id = REPLACE(psRqstUser, 'OPS$', '');
    EXCEPTION
      WHEN OTHERS THEN
        posUser := REPLACE(psRqstUser, 'OPS$', '');
        posUserQueue := NULL;
    END;
    posUserQueue := sQueue;
  END IF;

  IF LTRIM(RTRIM(rwRptInfo.queue_type)) IS NOT NULL AND
     LTRIM(RTRIM(sQueue)) IS NOT NULL THEN
    BEGIN
      SELECT user_queue, system_queue, queue_type, queue_filter, descrip,
             command, directory
      INTO rwQueueInfo.user_queue, rwQueueInfo.system_queue,
           rwQueueInfo.queue_type, rwQueueInfo.queue_filter,
           rwQueueInfo.descrip, rwQueueInfo.command, rwQueueInfo.directory
      FROM print_queues
      WHERE queue_type = rwRptInfo.queue_type
      AND   system_queue = LTRIM(RTRIM(sQueue));

      porwQueueInfo := rwQueueInfo;
    EXCEPTION
      WHEN OTHERS THEN
        porwQueueInfo := NULL;
    END;
  END IF;
END;
-- ----------------------------------------------------------------------------

FUNCTION get_min_truck_zone
RETURN NUMBER IS
BEGIN
  RETURN C_MIN_FLOAT_SEQ_ZONE;
END;
-- ----------------------------------------------------------------------------

FUNCTION get_max_truck_zone
RETURN NUMBER IS
BEGIN
  RETURN C_MAX_FLOAT_SEQ_ZONE;
END;
-- ----------------------------------------------------------------------------

FUNCTION get_map_status (
  psTruck       IN  las_truck.truck%TYPE)
RETURN VARCHAR2 IS
  iCnt		NUMBER := 0;
  iExists	NUMBER := 0;
  iMapped	NUMBER := 0;
  TYPE ttab IS TABLE OF VARCHAR2(1) INDEX BY BINARY_INTEGER;
  tbComp	ttab;
  CURSOR c_get_floats (csCompartment VARCHAR2) IS
    SELECT DISTINCT float_seq
    FROM floats
    WHERE truck_no = psTruck
    AND   SUBSTR(float_seq, 1, 1) = csCompartment
    AND   pallet_pull IN ('N', 'B');
BEGIN
  tbComp(1) := 'F';
  tbComp(2) := 'C';
  tbComp(3) := 'D';
  FOR i IN 1 .. tbComp.COUNT LOOP
    iCnt := 0;
    iMapped := 0;
    FOR cgf IN c_get_floats(tbComp(i)) LOOP
      iCnt := iCnt + 1;
      iExists := 0;
      BEGIN
        SELECT 1 INTO iExists
        FROM sls_load_map
        WHERE truck_no = psTruck
        AND   load_type = 'P'
        AND   pallet = cgf.float_seq
        AND   map_zone IS NOT NULL
        AND   ROWNUM = 1;
        iMapped := iMapped + 1;
      EXCEPTION
        WHEN OTHERS THEN
          iExists := 0;
      END;
      IF iExists = 0 THEN
        BEGIN
          SELECT 1 INTO iExists
          FROM las_default_map
          WHERE LTRIM(RTRIM(truck)) = psTruck
          AND   LTRIM(RTRIM(pallet)) = cgf.float_seq
          AND   REPLACE(LTRIM(RTRIM(mapzone)), 'Z', '') IS NOT NULL;
          iMapped := iMapped + 1;
        EXCEPTION
          WHEN OTHERS THEN
            iExists := 0;
        END;
      END IF;
    END LOOP;

    IF iCnt <> iMapped THEN
      RETURN 'N';
    END IF;
  END LOOP;

  IF iCnt <> 0 AND iCnt = iMapped THEN
    RETURN 'Y';
  END IF;

  RETURN 'N';
END;
-- ----------------------------------------------------------------------------

-- ********************** <Package Initialization> *****************************

-- ************************* <End of Package Body> *****************************

END pl_nos;
/

SHOW ERRORS

--CREATE PUBLIC SYNONYM pl_nos FOR swms.pl_nos;

--GRANT EXECUTE on pl_nos TO PUBLIC;
