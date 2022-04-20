-- set define off -	because we have literal ampersand in strings below
set define off

set echo off

BEGIN
$if dbms_db_version.ver_le_11 $then
	EXECUTE IMMEDIATE 'create or replace library RF_lib as ''/swms/curr/lib/libora_rf.so''';
$else
	EXECUTE IMMEDIATE 'create or replace library RF_lib as ''/swms/curr/lib/libora_rf.so'' AGENT ''EXTPROC_LINK''';
$end
END;
/
show sqlcode
show errors

create or replace package rf
as
	subtype STATUS is NATURALN; -- not null non-negative integer

	-- constants from inc/tm_define.h

  STATUS_FOUND                    constant STATUS := 0;   -- record found
  STATUS_NORMAL                   constant STATUS := 0;   -- Normal
  STATUS_NOR_CLUSTER              constant STATUS := 1;   -- Normal cluster
  STATUS_RESUME_NOR               constant STATUS := 2;   -- Normal resume
  STATUS_RESUME_CLS               constant STATUS := 3;   -- Cluster resume
  STATUS_MORE_TASK                constant STATUS := 4;   -- More task
  STATUS_NORMAL_CONSOL            constant STATUS := 5;   -- Normal consolidation
  STATUS_CONFIRM                  constant STATUS := 6;   -- need to confirm
  STATUS_NORMAL_KIT               constant STATUS := 7;   -- Normal kitting
  STATUS_LAST_ONE                 constant STATUS := 8;   -- last task
  STATUS_QA_SAMPLE                constant STATUS := 9;   -- QA Sample

  STATUS_QTY_OVER                 constant STATUS := 10;    -- Qty OVER
  STATUS_UPDATE_FAIL              constant STATUS := 11;    -- update fail
  STATUS_INSERT_FAIL              constant STATUS := 12;    -- insert fail
  STATUS_MORE_PICK                constant STATUS := 13;    -- more pick task
  STATUS_DROP_FULL                constant STATUS := 14;    -- drop full tote

  STATUS_RF_WAIT                  constant STATUS := 20;    -- For server use only
  STATUS_CLOSED                   constant STATUS := 21;    -- file already closed
  STATUS_OPENED                   constant STATUS := 22;    -- file already open
  STATUS_NEW                      constant STATUS := 23;    -- new file
  STATUS_NOT_FOUND                constant STATUS := 24;    -- record not found/no more task
  STATUS_UN_AUTH                  constant STATUS := 25;    -- un-authorized user
  STATUS_ALRDY_EXIST              constant STATUS := 26;    -- file/record already exist
  STATUS_BAD_REC                  constant STATUS := 27;    -- bad record/label
  STATUS_WAIT                     constant STATUS := 28;    -- Wait for manager
  STATUS_INV_OPT                  constant STATUS := 29;    -- invalid operation

  STATUS_BLD_REC                  constant STATUS := 30;    -- blind receiving
  STATUS_INV_LOCATION             constant STATUS := 31;    -- invalid location
  STATUS_CONSOL_FIRST             constant STATUS := 32;    -- need to consolidate first
  STATUS_NEED_REPLEN              constant STATUS := 33;    -- need replenish
  STATUS_NEED_CONTAINER           constant STATUS := 34;    -- need container/destination label
  STATUS_INV_PASSWD               constant STATUS := 35;    -- invalid passwd
  STATUS_INVALID_UOM              constant STATUS := 36;    -- invalid UOM
  STATUS_INV_PRODID               constant STATUS := 37;    -- Invalid Product ID
  STATUS_NO_MORE_TASK             constant STATUS := 38;    -- No more task required for function
  STATUS_INV_LABEL                constant STATUS := 39;    -- Invalid label

  STATUS_LABEL_USED               constant STATUS := 40;    -- Label used by others
  STATUS_INV_PUTLST               constant STATUS := 41;    -- Invalid putaway list
  STATUS_INV_PUTQTY               constant STATUS := 42;    -- Invalid putaway Qty
  STATUS_NEED_UNLOAD              constant STATUS := 43;    -- need to unload
  STATUS_SHIP_ALREADY             constant STATUS := 44;    -- shipped already
  STATUS_QTY_TOO_LARGE            constant STATUS := 45;    -- Qty Too Large
  STATUS_NEED_LABEL               constant STATUS := 46;    -- need label before shipping
  STATUS_FULL                     constant STATUS := 47;    -- Box Full
  STATUS_BAD_SER                  constant STATUS := 48;    -- Bad Serial Number
  STATUS_BAD_TRANS                constant STATUS := 49;    -- Bad Transaction

  STATUS_INV_LOT                  constant STATUS := 50;    -- Invalid Lot
  STATUS_REC_COMP                 constant STATUS := 51;    -- Receipt Completed
  STATUS_MORE_INFO                constant STATUS := 52;    -- need more infomation
  STATUS_INV_LANE                 constant STATUS := 53;    -- Invalid Lane ID
  STATUS_INV_REC_STATUS           constant STATUS := 54;    -- Invalid Receiving Status
  STATUS_ALRDY_CHKIN              constant STATUS := 55;    -- Already checked in
  STATUS_INV_CODE                 constant STATUS := 56;    -- Invalid Code
  STATUS_INV_AISLE                constant STATUS := 57;    -- Invalid Aisle
  STATUS_INV_ORDER                constant STATUS := 58;    -- Invalid Order ID
  STATUS_NO_CARR                  constant STATUS := 59;    -- No Carrier found

  STATUS_QTY_TOO_SMALL            constant STATUS := 60;    -- Qty too small, upd_inv
  STATUS_NOT_RELEASE              constant STATUS := 61;    -- Not release, loading
  STATUS_SERIAL                   constant STATUS := 62;    -- Serialized items, upd_inv
  STATUS_NEED_2_TOTE              constant STATUS := 63;    -- need two container labels
  STATUS_NEED_PACKTOTE            constant STATUS := 64;    -- need pack tote label
  STATUS_QTY_NOT_MATCH            constant STATUS := 65;    -- qty not match
  STATUS_NOT_DONE_PIK             constant STATUS := 66;    -- Not finished picking
  STATUS_NOT_PIK_YET              constant STATUS := 67;    -- Not pick yet
  STATUS_INV_ZONE                 constant STATUS := 68;    -- Invalid Zone
  STATUS_ZONE_NOT_FOUND           constant STATUS := 69;    -- Zone Not done

  STATUS_INV_SRC_LABEL            constant STATUS := 70;    -- Invalid Src label
  STATUS_INV_DEST_LABEL           constant STATUS := 71;    -- Invalid Dest label
  STATUS_INV_SRC_LOCATION         constant STATUS := 72;    -- Invalid Src location
  STATUS_INV_DEST_LOCATION        constant STATUS := 73;    -- Invalid Dest location
  STATUS_INV_LOAD                 constant STATUS := 74;    -- Invalid Load

  STATUS_DATA_ERROR               constant STATUS := 80;    -- Data Error in DataBase
  STATUS_NEED_RECONC              constant STATUS := 81;    -- Receipt need to be reconciled
  STATUS_CHILD_LABEL              constant STATUS := 82;    -- Child label
  STATUS_PACK_FIRST               constant STATUS := 83;    -- pack before print shipping label
  STATUS_INV_WHSE                 constant STATUS := 84;    -- Invalid Warehouse
  STATUS_WEIGHT_OUT_OF_RANGE      constant STATUS := 85;    -- Weight out of range
  STATUS_NO_RF                    constant STATUS := 86;    -- No RF for confirm putaway
  STATUS_WRONG_PUT                constant STATUS := 87;    -- Wrong putaway slot
  STATUS_INV_SLOT                 constant STATUS := 88;    -- Invalid slot

  STATUS_INV_PO                   constant STATUS := 90;    -- Invalid Purchase Order
  STATUS_CLO_PO                   constant STATUS := 91;    -- PO is already closed
  STATUS_MORE_REC_DATA            constant STATUS := 92;    -- more receiving data are needed
  STATUS_HOME_SLOT                constant STATUS := 93;    -- Home slot assigned
  STATUS_PUT_DONE                 constant STATUS := 94;    -- already putaway
  STATUS_INV_AREA                 constant STATUS := 95;    -- Invalid area
  STATUS_NO_TASK                  constant STATUS := 96;    -- No task selected
  STATUS_NOT_HOME_SLOT            constant STATUS := 97;    -- Not a home slot
  STATUS_QTY_ENOUGH               constant STATUS := 98;    -- Enough quantity for dest_slot
  STATUS_SIZE_ERROR               constant STATUS := 99;    -- Enough quantity for dest_slot

  STATUS_ERR_ALLOC                constant STATUS := 100; -- Enough quantity for dest_slot
  STATUS_LOC_ERROR                constant STATUS := 101; -- Enough quantity for dest_slot
  STATUS_QTY_ERROR                constant STATUS := 102; -- Enough quantity for dest_slot
  STATUS_CASE_HOME_EMPTY          constant STATUS := 103; -- Case home slot empty
  STATUS_EXTEND_PO                constant STATUS := 104; -- Case home slot empty
  STATUS_WRONG_EQUIP              constant STATUS := 105; -- Wrong Equipment
  STATUS_LOC_QTYEXP_WARN          constant STATUS := 106; -- Case stock transfer to a LOC with qty expected , syspar = warn
  STATUS_LOC_QTYEXP_PRVN          constant STATUS := 107; -- Case stock transfer to a LOC with qty expected , syspar = prevent
  STATUS_NO_STKXFER_SYSPAR        constant STATUS := 108; -- Case stock transfer to a LOC with qty expected , w/o syspar in sys_config
  STATUS_ITEM_NOCOST_WARN         constant STATUS := 109; -- Case stock qty adjust w/o item cost, syspar = warn

  STATUS_ITEM_NOCOST_PRVN         constant STATUS := 110; -- Case stock qty adjust w/o item cost, syspar = prevent
  STATUS_ITEM_NOCOST_SYSPAR       constant STATUS := 111; -- Case stock qty adjust w/o item cost, without syspar in sys_config
  STATUS_LOCK_PO                  constant STATUS := 112; -- Case when PO is in Use by another user during RF close PO program
  STATUS_UNAVL_PO                 constant STATUS := 113; -- PO is not available
  STATUS_INVALID_JOBCODE          constant STATUS := 114; -- Gagnon Insert Indirect invalid job code
  STATUS_NOT_ENOUGH_TIME          constant STATUS := 115; -- Gagnon Insert Indirect not enough time on a batch
  STATUS_INV_PUTAWAY_OPT          constant STATUS := 116; -- Invalid Putaway option
  STATUS_NOT_ACTIVE_JOB           constant STATUS := 117; -- Gagnon Insert Indirect no active job
  STATUS_INV_UPDATE_FAIL          constant STATUS := 118; -- Update of INV table failed
  STATUS_ERM_UPDATE_FAIL          constant STATUS := 119; -- Update of ERM table failed

  STATUS_ERD_UPDATE_FAIL          constant STATUS := 120; -- Update of ERD table failed
  STATUS_PM_UPDATE_FAIL           constant STATUS := 121; -- Update of PM table failed
  STATUS_SYSCFG_UPDATE_FAIL       constant STATUS := 122; -- Update of SYS_CONFIG table failed
  STATUS_DEL_PUTAWYLST_FAIL       constant STATUS := 123; -- Delete from PUTAWAYLST table failed
  STATUS_SEL_SYSCFG_FAIL          constant STATUS := 124; -- Select from SYS_CONFIG table failed
  STATUS_USE_SWAP                 constant STATUS := 125; -- Case in HSM when attempting to transfer to a Home Slot
  STATUS_EXP_DATE_INFO            constant STATUS := 126; -- Need expiration date information
  STATUS_MFG_DATE_INFO            constant STATUS := 127; -- Need manufacturing date information
  STATUS_QTY_NOT_ENOUGH           constant STATUS := 128; -- Qty not enough in transfers
  STATUS_LOAD_FAIL                constant STATUS := 129; -- Program load on the Host failed

  STATUS_DB_CONN_ERR              constant STATUS := 130; -- Cannot connect to database
  STATUS_ALRDY_LOCATED            constant STATUS := 131; -- Aisle already located
  STATUS_HOME_SLOT_UNAVL          constant STATUS := 132; -- Home Slot not available
  STATUS_USE_ADJUST               constant STATUS := 133; -- User must use adjust instead of Locate screen on the RF
  STATUS_TRN_UPDATE_FAIL          constant STATUS := 134; -- Update of TRANS table failed
  STATUS_RPL_UPDATE_FAIL          constant STATUS := 135; -- Update of REPLENLST table failed
  STATUS_DEL_IND_FAIL             constant STATUS := 136; -- Delete of IND transaction failed
  STATUS_NOT_RES_LOC_CO           constant STATUS := 137; -- Not a Reserve locator company
  STATUS_RES_LOC_CO               constant STATUS := 138; -- Reserve locator company
  STATUS_RLC_ITEM_EXP_OR_FIFO     constant STATUS := 139; -- Not a Reserve locator company

  STATUS_DEL_DLD_FAIL             constant STATUS := 140; -- Delete of DEMANDLST failed
  STATUS_PUTAWAY_FAIL             constant STATUS := 141; -- SLMS dummy putaway failed
  STATUS_SIZE_ERROR_WARN          constant STATUS := 142; -- allow transfer on pallet type mismatch and display warning
  STATUS_LM_NO_ACTIVE_BATCH       constant STATUS := 143; -- User Without Active Batch (Labor)
  STATUS_CTE_RTN_BTCH_FLG_OFF     constant STATUS := 144; -- Create Return Put Batch Flag Off
  STATUS_LM_BATCH_UPD_FAIL        constant STATUS := 145; -- Could not update Labor Mgmt Batch
  STATUS_NO_LM_BATCH_FOUND        constant STATUS := 146; -- Could not find a Labor Mgmt Batch
  STATUS_PALLET_ON_HOLD           constant STATUS := 147; -- Pallet on hold -- Unavailable
  STATUS_NEED_EXPMFG_DATE_INFO    constant STATUS := 148; -- Need expiration/manufactures date
  STATUS_NO_LM_RTN_IND_JBCD       constant STATUS := 149; -- No Labor Return indirect job code

  STATUS_LM_JOBCODE_NOT_FOUND     constant STATUS := 150; -- Unable to find LM jobcode
  STATUS_LM_SCHED_NOT_FOUND       constant STATUS := 151; -- Unable to find LM schedule type
  STATUS_LM_BATCH_COMPLETED       constant STATUS := 152; -- LM batch already completed
  STATUS_LM_ACTIVE_BATCH          constant STATUS := 153; -- LM batch already active
  STATUS_NO_LM_PARENT_FOUND       constant STATUS := 154; -- Could not find a LM Parent Batch
  STATUS_LM_PARENT_UPD_FAIL       constant STATUS := 155; -- Count not update LM Parent Batch
  STATUS_LM_BAD_USER              constant STATUS := 156; -- Either user id or labor group is invalid
  STATUS_LM_INS_ISTART_FAIL       constant STATUS := 157; -- Unable to insert ISTART LM batch
  STATUS_LM_INS_ISTOP_FAIL        constant STATUS := 158; -- Unable to insert ISTOP LM batch
  STATUS_LM_MERGE_BATCH           constant STATUS := 159; -- LM batch already merged

  STATUS_LOC_DAMAGED              constant STATUS := 160; -- Location is Damaged
  STATUS_INV_INSERT_FAILED        constant STATUS := 161; -- Insert into INV table failed
  STATUS_LOC_INSERT_FAILED        constant STATUS := 162; -- Insert into LOC table failed
  STATUS_TRANS_INSERT_FAILED      constant STATUS := 163; -- Insert into TRANS table failed
  STATUS_PM_INSERT_FAILED         constant STATUS := 164; -- Insert into PM table failed
  STATUS_RPL_INSERT_FAILED        constant STATUS := 165; -- Insert into REPLENLST table failed
  STATUS_DLD_INSERT_FAILED        constant STATUS := 166; -- Insert into DEMANDLST table failed
  STATUS_CC_INSERT_FAILED         constant STATUS := 167; -- Insert into CC table failed
  STATUS_WEIGHT_INSERT_FAILED     constant STATUS := 168; -- Insert into TMP_WEIGHT table failed
  STATUS_NO_ERR_MSG_FOUND         constant STATUS := 169; -- No error msg in RF_ERROR_MESSAGES tab

  STATUS_INV_XFR_LABEL            constant STATUS := 170; -- Invalid pallet during stock transer
  STATUS_LOC_UPDATE_FAILED        constant STATUS := 171; -- Update to LOC table failed
  STATUS_CC_UPDATE_FAILED         constant STATUS := 172; -- Update to CC table failed
  STATUS_PUTAWAYLST_UPDATE_FAIL   constant STATUS := 173; -- Update of PUTAWAYLST table failed
  STATUS_INVALID_EXP_DATE         constant STATUS := 174; -- ORA date error when updating exp date
  STATUS_INVALID_MFG_DATE         constant STATUS := 175; -- ORA date error when updating mfg date
  STATUS_DEL_INV_FAIL             constant STATUS := 176; -- Delete from INV table failed
  STATUS_SEL_INV_FAIL             constant STATUS := 177; -- Select from INV table failed
  STATUS_SEL_LOC_FAIL             constant STATUS := 178; -- Select from LOC table failed
  STATUS_SEL_RPL_FAIL             constant STATUS := 179; -- Select from REPLENLST table failed

  STATUS_SEL_DLD_FAIL             constant STATUS := 180; -- Select from DEMANDLST table failed
  STATUS_SEL_PUTAWAYLST_FAIL      constant STATUS := 181; -- Select from PUTAWAYLST table failed
  STATUS_DEL_RPL_FAIL             constant STATUS := 182; -- Delete from REPLENLST table failed
  STATUS_DEL_TRANS_FAIL           constant STATUS := 183; -- Delete from TRANS table failed
  STATUS_DLD_UPDATE_FAIL          constant STATUS := 184; -- Update of DEMANDLST table failed
  STATUS_LM_PT_DIST_BAD_SETUP     constant STATUS := 185; -- LM Point Distance not setup
  STATUS_LM_BAY_DIST_BAD_SETUP    constant STATUS := 186; -- LM Bay Distance not setup
  STATUS_CROSS_AISLE_SEL_FAIL     constant STATUS := 187; -- Select of cross aisle failed for LM
  STATUS_LM_FORKLIFT_NOT_FOUND    constant STATUS := 188; -- Forklift labor function missing
  STATUS_LM_FORKLIFT_NOT_ACTIVE   constant STATUS := 189; -- Forklift labor func. not active

  STATUS_LM_SUSP_BATCH_ACTV       constant STATUS := 190; -- Suspended LM batch activated
  STATUS_LM_INS_FL_DFLT_FAIL      constant STATUS := 191; -- Insert Forklift Ind. batch fail
  STATUS_PENDING_RPL_TSK_FAIL     constant STATUS := 192; -- Failed to get pending rpl tasks
  STATUS_UPCINFO_INSERT_FAILED    constant STATUS := 193; -- Insert into UPCINFO table failed
  STATUS_UPCINFO_UPDATE_FAILED    constant STATUS := 194; -- Update of UPCINFO table failed
  STATUS_UPCINFO_SELECT_FAILED    constant STATUS := 195; -- Select from UPCINFO table failed
  STATUS_LM_PT_DIST_BADSETUP_WTW  constant STATUS := 196; -- LM Point Distance not setup. W to W
  STATUS_LM_PT_DIST_BADSETUP_WFD  constant STATUS := 197; -- LM Point Distance not setup. W to First door
  STATUS_LM_PT_DIST_BADSETUP_DTD  constant STATUS := 198; -- LM Point Distance not setup. door to door
  STATUS_LM_PT_DIST_BADSETUP_DTA  constant STATUS := 199; -- LM Point Distance not setup. door to aisle

  STATUS_LM_PT_DIST_BADSETUP_ATA  constant STATUS := 200; -- LM Point Distance not setup. aisle to aisle
  STATUS_LM_PT_DIST_BADSETUP_ACA  constant STATUS := 201; -- LM Point Distance not setup. Cross aisle to aisle
  STATUS_LM_PT_DIST_BADSETUP_NCA  constant STATUS := 202; -- LM Point Distance not setup. Next Cross aisle to aisle
  STATUS_LM_PT_DIST_BADSETUP_WFA  constant STATUS := 203; -- LM Point Distance not setup. Warehouse to first aisle
  STATUS_LM_PT_DIST_BADSETUP_PT   constant STATUS := 204; -- Point Type not setup
  STATUS_MOV_UPDATE_FAIL          constant STATUS := 205; -- Update of WHMVELOC table failed
  STATUS_MOVED_ALREADY            constant STATUS := 206; -- Pallet/Location moved already
  STATUS_NO_PICK_SLOT_FOUND       constant STATUS := 207; -- No Pick slot found for reserve move
  STATUS_FLOATING_SLOT_MOVE       constant STATUS := 208; -- Reserve pallet belongs to Floating SLOT
  STATUS_USE_RESERVE_MOVE         constant STATUS := 209; -- Used reserve move from the pick menu

  STATUS_ITEM_WO_ZONE             constant STATUS := 210; -- Move item had no zone in pm
  STATUS_ITEM_WO_NEW_ZONE         constant STATUS := 211; -- Move item had no new zone
  STATUS_RSRV_SLOT_UNAVL          constant STATUS := 212; -- Reserve Slot not available
  STATUS_MOVPLT_IN_NEW_WH_WARN    constant STATUS := 213; -- Move pallet exists in new WH, WARN
  STATUS_MIN_PATH_FAILED          constant STATUS := 214; -- Select of put_path for min loc failed
  STATUS_INP_PATH_FAILED          constant STATUS := 215; -- Select of put_path for inp loc failed
  STATUS_MAX_PATH_FAILED          constant STATUS := 216; -- Select of put_path for max loc failed
  STATUS_INV_FLOAT_RANGE          constant STATUS := 217; -- Invalid float range during WH move
  STATUS_LM_MULTI_ACTIVE_BATCH    constant STATUS := 218; -- Multiple active batches found for user
  STATUS_LM_N_STATUS_BATCH        constant STATUS := 219; -- LM N status batch(es) found for user

  STATUS_FLOAT_TRANSFER           constant STATUS := 220; -- Reserve pallet belongs to Floating SLOT
  STATUS_USE_TRANSFER             constant STATUS := 221; -- RF's sent wrong option to the Host
  STATUS_XFR_AVL_SLOT_FAIL        constant STATUS := 222; -- Look up of available transfer slot fail
  STATUS_INVALID_HRV_DATE         constant STATUS := 223; -- Invalid harvest date during data coll
  STATUS_HRV_DATE_WARN            constant STATUS := 224; -- Harvest date warning during data coll
  STATUS_SEL_TRN_FAIL             constant STATUS := 225; -- Select from TRANS table failed
  STATUS_SEL_SEQ_FAIL             constant STATUS := 226; -- Select from oracle sequencer failed
  STATUS_SEL_ERM_FAIL             constant STATUS := 227; -- Select from ERM table failed
  STATUS_SEL_AGING_FAIL           constant STATUS := 228; -- Select from AGING_ITEMS table failed
  STATUS_NEED_AGING               constant STATUS := 229; -- Item need to be aged

  STATUS_INV_EXT_UPC              constant STATUS := 230; -- Invalid external UPC entered from RF
  STATUS_MLT_FLOATING_SLOT_MOVE   constant STATUS := 231; -- Reserve pallet belongs to multiple Floating SLOT
  STATUS_SEL_PROCESS_LOG_FAIL     constant STATUS := 232; -- Select from Process_log table failed
  STATUS_REPLEN_DONE              constant STATUS := 233; -- Demand Replenishment already done
  STATUS_REC_LOCK_BY_OTHER        constant STATUS := 234; -- Demand Replenishment already done
  STATUS_USER_ALREADY_SIGNED_ON   constant STATUS := 235; -- User is already signed on another RF
  STATUS_LM_LAST_IS_ISTOP         constant STATUS := 9999; -- User's last completed batch is an ISTOP


  --  236-267 used by inc/return_dtls.h For RF Returns

  STATUS_CASE_OR_SPLIT            constant STATUS := 236;
  STATUS_INV_FUNC_CODE            constant STATUS := 237;
  STATUS_INV_ITEM_REQUIRED        constant STATUS := 238;
  STATUS_INV_NO_REQUIRED          constant STATUS := 239;

  STATUS_INVALID_DISP             constant STATUS := 240;
  STATUS_INVALID_MF               constant STATUS := 241;
  STATUS_INVALID_MSPK             constant STATUS := 242;
  STATUS_INVALID_RSN              constant STATUS := 243;
  STATUS_INVALID_UPC              constant STATUS := 244;
  STATUS_ITM_NOT_SPLIT            constant STATUS := 245;
  STATUS_MANIFEST_PAD             constant STATUS := 246;
  STATUS_MF_ADD_MSG               constant STATUS := 247;
  STATUS_MF_REQUIRED              constant STATUS := 248;
  STATUS_MSPK_REQUIRED            constant STATUS := 249;

  STATUS_MULTI_ITEMS              constant STATUS := 250;
  STATUS_NEED_TRIPMASTER          constant STATUS := 251;
  STATUS_NO_LOC_FOUND             constant STATUS := 252;
  STATUS_NO_MF_INFO               constant STATUS := 253;
  STATUS_NO_ORDER_FOUND           constant STATUS := 254;
  STATUS_NOT_PKUP_INV             constant STATUS := 255;
  STATUS_QTY_REQUIRED             constant STATUS := 256;
  STATUS_RSN_REQUIRED             constant STATUS := 257;
  STATUS_RTN_QTYSUM_GT_SHIP       constant STATUS := 258;
  STATUS_SHIP_DIFF_UOM            constant STATUS := 259;

  STATUS_TEMP_EXISTED             constant STATUS := 260;
  STATUS_TEMP_NO_RANGE            constant STATUS := 261;
  STATUS_TEMP_OUT_OF_RANGE        constant STATUS := 262;
  STATUS_TEMP_REQUIRED            constant STATUS := 263;
  STATUS_WEIGHT_DESIRED           constant STATUS := 264;
  STATUS_WEIGHT_EXISTED           constant STATUS := 265;
  STATUS_RTN_WT_OUT_OF_RANGE      constant STATUS := 266;
  STATUS_WHOLE_NUMBER_ONLY        constant STATUS := 267;


  -- resuming constants from inc/tm_define.h

  STATUS_MAN_NOT_FOUND            constant STATUS := 241; -- Manifest not found
  STATUS_PAL_DMG_NO_TBATCH        constant STATUS := 268; -- Cannot close damage return TBatch
  STATUS_NO_INV_ADJ_FOR_MX_LOC    constant STATUS := 269; -- Inv adjust for matrix locations not allowed

  STATUS_LM_GET_FORKLIFT_POINT    constant STATUS := 270; -- Get Forklift Point
  STATUS_LM_INS_IND_FAIL          constant STATUS := 271; -- Insert Indirect Batch Fail
  STATUS_LM_INV_FORK_POINT        constant STATUS := 272; -- Invalid Forklift Point
  STATUS_LM_INV_BATCH_NO          constant STATUS := 273; -- Invalid Batch Number
  STATUS_LM_INV_LBR_GRP           constant STATUS := 274; -- Invalid Labor Group
  STATUS_LM_UPD_BATCH_FAIL        constant STATUS := 275; -- Update Batch Fail
  STATUS_LM_INV_MASTER_BATCH      constant STATUS := 276; -- Invalid Master Batch Number
  STATUS_LM_INV_SECOND_BATCH      constant STATUS := 277; -- Invalid Second Batch Number
  STATUS_LM_BATCH_SAME            constant STATUS := 278; -- Master and Second Batch Same
  STATUS_LM_MERGE_FAIL            constant STATUS := 279; -- Merge Batch Fail

  STATUS_LM_BATCH_NOT_READY       constant STATUS := 280; -- Batch Not Ready To Work On
  STATUS_LM_FORKLIFT_BATCH        constant STATUS := 281; -- Forklift Batch. Cannot be Signed On
  STATUS_LM_ISTART_EXIST          constant STATUS := 282; -- ISTART already exist for the user
  STATUS_LM_DUR_EXIST             constant STATUS := 283; -- Duration Exist
  STATUS_LM_BATCH_NOT_EXIST       constant STATUS := 284; -- Batch Not Exist
  STATUS_LM_NO_DIRECT_BATCH       constant STATUS := 285; -- No Direct Batch Exist
  STATUS_LM_COMPLETE_BATCH        constant STATUS := 286; -- Batch is already complete
  STATUS_LM_UN_AUTH_JOBCODE       constant STATUS := 287; -- Unauthorized Job code
  STATUS_LM_LOT_BATCH             constant STATUS := 288; -- LOT Batch
  STATUS_LM_INVALID_PASSWORD      constant STATUS := 289; -- Invalid Password on Indirect batch

  STATUS_LM_INVALID_JOB_CODE      constant STATUS := 290; -- Invalid Job Code on Indirect batch
  STATUS_LM_INVALID_USERID        constant STATUS := 291; -- Invalid User ID
  STATUS_LM_MERGED_BATCH          constant STATUS := 292; -- Batch is already merged
  STATUS_LM_FORKLIFT_FAIL         constant STATUS := 293; -- Forklift Sign off Failed
  STATUS_INV_REC_LOCKED           constant STATUS := 294; -- Inventory Record Locked
  STATUS_INV_INVOICE_NO           constant STATUS := 295; -- Invalid Invoice # input
  STATUS_INV_TEMPERATURE          constant STATUS := 296; -- Invalid Temperature input
  STATUS_NO_MSKU_DEEP             constant STATUS := 297; -- MSKU Pallet cannot be transferred to a deep slot
  STATUS_MSKU_PLT_EXISTS          constant STATUS := 298; -- Cannot transfer pallet to location where MSKU pallet exists
  STATUS_MSKU_PLT_QTY             constant STATUS := 299; -- MSKU license plate can have quantity 0 or 1. (During Inventory Adjustment)

  STATUS_MSKU_REP_PIK             constant STATUS := 300; -- Cannot Pick MSKU pallet since there is a pending replenishment task for NON MSKU pallet
  STATUS_MSKU_PUTPIK              constant STATUS := 301; -- Cannot Pick MSKU pallet since there is a pending put away task for NON MSKU
  STATUS_NON_MKSU_REP_PIK         constant STATUS := 302; -- Cannot Pick pallet since there is a pending replenishment task for MSKU pallet
  STATUS_NON_MKSU_PUR_PIK         constant STATUS := 303; -- Cannot Pick pallet since there is a pending put away task for MSKU pallet
  STATUS_MSKU_LP_NOT_FOUND        constant STATUS := 304; -- Invalid MSKU license
  STATUS_SKU_LP_NOT_FOUND         constant STATUS := 304; -- Invalid MSKU license
  STATUS_CANNOT_DIVIDE_MSKU       constant STATUS := 305; -- MSKU pallet cannot be divided since it has already been put away
  STATUS_SEL_ERD_LPN_FAIL         constant STATUS := 306; -- Unable to select from ERD_LPN table
  STATUS_CHILD_FETCH_FAIL         constant STATUS := 307; -- Unable to select child records for a parent pallet
  STATUS_CHILD_ADJ_STATUS_FAIL    constant STATUS := 308; -- Unable to update status of all child pallets in MSKU pallet, since error in status of one or more child pallets
  STATUS_NO_MSKU_FULL             constant STATUS := 309; -- MSKU Pallet can not be transferred to a slot having full pallet(s)

  STATUS_MSKU_LP                  constant STATUS := 310; -- pallet is a MSKU pallet and can not be handled by the program
  STATUS_MSKU_SUB_FAILED          constant STATUS := 311; -- pallet substitution failed for a license plate in an MSKU pallet
  STATUS_NOT_MSKU_LP              constant STATUS := 312; -- Regular LP scanned in MSKU Putaway mode
  STATUS_LOC_HAS_MSKU             constant STATUS := 313; -- Location has Msku pallet. Use different Location
  STATUS_LOSSPREV_EXIST           constant STATUS := 319; -- Indicates scan loss has been recorded for the LP

  STATUS_LOSSPREV_CREATED         constant STATUS := 320; -- Indicates scan loss record created for this LP
  STATUS_LOSSPREV_LP_IN_OTHER_SN  constant STATUS := 321; -- Indicates chkin_req_server->erm_id or
  STATUS_OSD_PENDING              constant STATUS := 322; -- The SN/PO is in pending status
  STATUS_OSD_LOC_NOT_FOUND        constant STATUS := 323; -- No location found to putaway damage qty
  STATUS_OSD_LOC_FOUND            constant STATUS := 324; -- Location found to putaway damage qty
  STATUS_OSD_REC_NOT_FOUND        constant STATUS := 325; -- No record found in osd table
  STATUS_OSD_RSN_CODE_ASND        constant STATUS := 326; -- OSD damage reason code assigned
  STATUS_OSD_INS_FAILED           constant STATUS := 327; -- Insert OSD record failed
  STATUS_OSD_UPD_FAILED           constant STATUS := 328; -- Update OSD record failed
  STATUS_OSD_DEL_FAILED           constant STATUS := 329; -- Delete OSD record failed

  STATUS_OSD_SEL_FAILED           constant STATUS := 330; -- Select OSD record failed
  STATUS_DFT_QUEUE_NOT_FOUND      constant STATUS := 331; -- Default user print queue is not found
  STATUS_SEL_RFINFO_FAIL          constant STATUS := 332; -- Select from rfinfo table failed
  STATUS_MSKU_LP_LIMIT_WARN       constant STATUS := 336; -- LP count exceeds NUM_MSKU_PALLETS to receive or putaway - warning - must be sub-divided
  STATUS_MSKU_SUBDIV_LIMIT        constant STATUS := 337; -- LP count exceeds NUM_SUBDIV_PALLETS to subdivide
  STATUS_MSKU_LP_LIMIT_ERROR      constant STATUS := 338; -- LP count exceeds NUM_MSKU_PALLETS - this is a fatal error
  STATUS_RDC_ITEM                 constant STATUS := 339; -- The item is a RDC item

  STATUS_ITEM_SN_EXISTS           constant STATUS := 340; -- The item has a NEW or OPN SN
  STATUS_COOL_MUST_VERIFY         constant STATUS := 341; -- Must verify COO labeling
  STATUS_COOL_MUST_COLLECT        constant STATUS := 342; -- Must collect COO data before continuing
  STATUS_RETURN_EXISTED           constant STATUS := 343; -- Return already existed
  STATUS_INV_RETURN_EXISTED       constant STATUS := 344; -- A return existed of this invoice
  STATUS_INVALID_REPLEN_TYPE      constant STATUS := 345; -- Invalid replenishment type
  STATUS_OK_TO_PRINT              constant STATUS := 346; -- Manifest tripped and ready to print
  STATUS_NO_PRINTER_DEFINED       constant STATUS := 347; -- No printer defined for return label
  STATUS_PRINTING_ERROR           constant STATUS := 348; -- Printing encountered error
  STATUS_INVOICE_RETURNED         constant STATUS := 349; -- Entire invoice was returned

  STATUS_UPDATE_NOT_ALLOWED       constant STATUS := 350; -- Rtn cannot be updated (putawayed)
  STATUS_DELETE_NOT_ALLOWED       constant STATUS := 351; -- Rtn cannot be deleted (putawayed)
  STATUS_MANIFEST_WAS_CLOSED      constant STATUS := 352; -- MF in CLS status - no more to do
  STATUS_SEL_MNL_FAIL             constant STATUS := 353; -- Select from REPLENLST table failed
  STATUS_MUST_SCAN_UPC            constant STATUS := 354; -- MNL Replen - must scan UPC (>1 item in src_loc)
  STATUS_MNL_DROP_FAIL            constant STATUS := 355; -- MNL Replen Drop failed
  STATUS_LOGIN_FAIL               constant STATUS := 356; -- login failed and host supplied message in auth_msg
  STATUS_LOGIN_WARN               constant STATUS := 357; -- login successful but host supplied msg in auth_msg
  STATUS_ACC_DONE                 constant STATUS := 358;
  STATUS_ACC_NOT_BEGIN            constant STATUS := 359;

  STATUS_TRACK_TRUCK_ACCESSORY    constant STATUS := 360;
  STATUS_DMD_RPL_FOUND_IN_SWP     constant STATUS := 361; -- Stop the swap when dmd rpl is found
  STATUS_ML_INDUCTION_MOVE        constant STATUS := 362; -- Pallet belongs to Mini Load
  STATUS_QTY_NOT_IN_CASES         constant STATUS := 363; -- Adjusted Quantity must be in Cases
  STATUS_INVALID_DATE             constant STATUS := 364; -- generated due to date conversion error in Oracle
  STATUS_PALLET_UPC_MISMATCH      constant STATUS := 365; -- Pallet id does not match scanned UPC
--  STATUS_PALLET_LOCATION_MISMATCH constant STATUS := 366; -- Pallet id does not match scanned location (variable name too long, shortened below)
  STATUS_PALLET_LOCN_MISMATCH     constant STATUS := 366; -- Pallet id does not match scanned location
  STATUS_INV_MANIFEST             constant STATUS := 367; -- Invalid Manifest Number
  STATUS_MANIFEST_NO_COOLER_ITEM  constant STATUS := 368; -- Manifest has no cooler item
  STATUS_DEL_FSO_FAIL             constant STATUS := 369; -- Delete of Food Safety record failed

  STATUS_INVALID_STOP             constant STATUS := 370; -- Stop not found for the manifest
  STATUS_NOT_COOLER_ITEM          constant STATUS := 371; -- Item not a cooler item
--  STATUS_DUPLICATE_TEMP_COLLECTION constant STATUS := 372; -- Duplicate temperature collection (variable name too long, shortened below)
  STATUS_DUP_TEMP_COLLECTION      constant STATUS := 372; -- Duplicate temperature collection
  STATUS_ITEM_NOT_ON_THIS_STOP    constant STATUS := 373; -- Item valid for the manifest but not for the stop
  STATUS_NEED_FOOD_SAFETY_TEMPS   constant STATUS := 374; -- Manifest cannot be closed without Food safety temps

  STATUS_NO_NEW_TASK              constant STATUS := 396; -- No new task generated
  STATUS_TASK_ALREADY_PICKED      constant STATUS := 397; -- Task is already picked by someone else
  STATUS_INCONSISTENT_MF          constant STATUS := 398; -- Inconsistent Manifest data


  -- Message numbers ranging from 401 to 550 are reserved for SOS/SLS.
  -- These are defined in inc/sos_sls_define.h.
  -- Note, 457 appears to have been used twice.

  STATUS_NO_NEED_EQUIP_CHECK      constant STATUS := 401; -- SOS/SLS equipment need not check
  STATUS_INV_FLOAT_SEQ            constant STATUS := 402; -- Float seq not found
  STATUS_TRAILER_CHECK_NEED       constant STATUS := 403; -- Need trailer check to be performed
  STATUS_TRK_EQUIP_COUNT_NEED     constant STATUS := 404; -- Need truck equip count list
  STATUS_TRK_SEAL_NEED            constant STATUS := 405; -- Need truck seal list
  STATUS_NO_FLOAT_SUMMARY         constant STATUS := 406; -- Float summary information returned
  STATUS_NO_LOAD_SUMMARY          constant STATUS := 407; -- Load summary information returned
  STATUS_TRUCK_NOT_AVAIL          constant STATUS := 408; -- Truck info not found
  STATUS_MEMORY_OUT_SERVER        constant STATUS := 409; -- Cannot alloc. more memory for serv

  STATUS_PALLET_LOADED            constant STATUS := 410; -- Truck pallet has been loaded
  STATUS_MISSING_INFO_CHECK       constant STATUS := 411; -- There are missing info for float
  STATUS_FLOAT_OUT_SEQ            constant STATUS := 412; -- Truck float load out of sequence
  STATUS_TRAILER_USED             constant STATUS := 413; -- Trailer is used by another truck
  STATUS_TRK_COMPARTMENT_CLOSED   constant STATUS := 414; -- Truck compartment was closed
  STATUS_TRAILER_UPD_FAIL         constant STATUS := 415; -- Trailer update failed
  STATUS_TRK_ZONE_UPD_FAIL        constant STATUS := 416; -- Truck zone and pal status upd failed
  STATUS_TRAILER_HIST_UPD_FAIL    constant STATUS := 417; -- Trailer history update failed
  STATUS_TRK_EQ_COUNT_UPD_FAIL    constant STATUS := 418; -- Truck equip count update failed
  STATUS_TRK_SEAL_UPD_FAIL        constant STATUS := 419; -- Truck seal update failed

  STATUS_FLOAT_UNLOAD_FAIL        constant STATUS := 420; -- Cannot unload float for truck
  STATUS_TRK_UNLOAD_FAIL          constant STATUS := 421; -- Cannot unload a truck
  STATUS_COMP_COMPLETE_FAIL       constant STATUS := 422; -- Cannot close a compartment
  STATUS_TRK_COMPLETE_FAIL        constant STATUS := 423; -- Cannot close a truck
  STATUS_MISSING_FLOAT            constant STATUS := 424; -- At least one float is not loaded
  STATUS_MISSING_COMPARTMENT      constant STATUS := 425; -- At least one compartment not close
  STATUS_TRK_EQUIP_COUNT_RENEED   constant STATUS := 426; -- Redo the accessory tracking
  STATUS_TRAILER_CHECK_NEED_N_LM  constant STATUS := 427; -- Need to perform trailer check
  STATUS_CS_EXCEPTION_INS_FAIL    constant STATUS := 428; -- Case exception insert failed
  STATUS_CS_EXCEPTION_UPD_FAIL    constant STATUS := 429; -- Case exception update failed

  STATUS_TRAILER_ZONE_OUT_RANGE   constant STATUS := 430; -- Zone is'nt within trl zone range
  STATUS_LM_NOT_ACTIVE            constant STATUS := 431; -- LBR_MGMT_FLAG is N
  STATUS_MISSING_INFO_NEED_N_LM   constant STATUS := 432; -- Missing cs/wt and LM batch not found
  STATUS_IS_CASE_LABEL            constant STATUS := 433; -- Scan is a case label
  STATUS_ERR_NO_TRL_CHKLIST       constant STATUS := 434; -- No data available of trailer checklist
  STATUS_PALLET_NOT_LOADED        constant STATUS := 435; -- Truck pallet is not loaded
  STATUS_NO_PALLETS               constant STATUS := 436; -- No pallets for the truck
  STATUS_NO_LOADED_PALLETS        constant STATUS := 437; -- No pallets loaded on the truck
  STATUS_PALLET_NOT_FOUND         constant STATUS := 438; -- Pallet does not exist
  STATUS_INVALID_TRAILER          constant STATUS := 439; -- Trailer does not match the one assigned to the truck

  STATUS_ERR_NULL_ORD_SEQ         constant STATUS := 440; -- Bad ORD sequence
  STATUS_ERR_NULL_CASE_SEQ        constant STATUS := 441; -- Bad CASE Sequence
  STATUS_ERR_CASE_ON_WRONG_FLOAT  constant STATUS := 442; -- Case on Wrong FLoat
  STATUS_NO_CASE_DROP_INFO        constant STATUS := 443; -- No Case drop information
  STATUS_NO_TRUCK_ZONE_INFO       constant STATUS := 444; -- No truck number information
  STATUS_TRUCK_IS_EMPTY           constant STATUS := 445; -- Truck is empty
  STATUS_COOLER_NOT_CLOSED        constant STATUS := 446; -- Cooler is not closed
  STATUS_DRY_NOT_CLOSED           constant STATUS := 447; -- Dry is not closed
  STATUS_FREEZER_NOT_CLOSED       constant STATUS := 448; -- Freezer is not closed
  STATUS_ERR_TRUCK_SEAL_INS       constant STATUS := 449; -- Error during truck seal insertion

  STATUS_HOTKEY_FUNC_NOT_AVAIL    constant STATUS := 450; -- Hot key function is not available
  STATUS_PALLET_SCANNED           constant STATUS := 451; -- Pallet has been scanned but not loaded yet
  STATUS_ERR_NO_LM_BATCH          constant STATUS := 452; -- No LM Batch found 1403
  STATUS_ERR_LM_BATCH_UPD_FAIL    constant STATUS := 453;
  STATUS_ERR_INVALID_FLOAT_ID     constant STATUS := 454;
  STATUS_CASE_SCANNED             constant STATUS := 455; -- Case sequence has been scanned
  STATUS_NO_ACC_LIST              constant STATUS := 456; -- Accessory list/collection not avail*/
  STATUS_ACC_UPD_INS_FAIL         constant STATUS := 457; -- Accessory collection upd/ins fail
  STATUS_MISSING_CATCHWEIGHT      constant STATUS := 458; -- There is missing catch weight
  STATUS_SLS_E_USER_NOT_FND       constant STATUS := 459; -- SLS User not found

  STATUS_SLS_E_UNEXPECTED         constant STATUS := 460; -- Unexpected error in SLS loading
  STATUS_SLS_E_NO_AUTH            constant STATUS := 461; -- User not authorized to use new SLS
  STATUS_SLS_E_LOAD_ASSIGNED      constant STATUS := 462; -- Loader Batch is assigned to another user
  STATUS_INVALID_FLOAT_LABEL      constant STATUS := 463; -- Float Label input is invalid
  STATUS_TRUCK_UNLOADED           constant STATUS := 464; -- Truck is unloaded for acc update
  STATUS_DUPLICATE_BARCODE        constant STATUS := 465; -- Barcode existed in diff trck/float

  -- SOS --

  STATUS_SEQ_NOT_FOUND            constant STATUS := 501; -- Sequence number not found
  STATUS_BATCH_NOT_FOUND          constant STATUS := 502; -- Batch number not found
  STATUS_FLOAT_HIST_UPD_FAIL      constant STATUS := 503; -- Can not create file or table
  STATUS_CANNOT_CREATE_FILE       constant STATUS := 504; -- cannot create /u/wps/tmp/short.XXXXX file
  STATUS_NO_DEFAULT_PRINTER       constant STATUS := 505; -- No detault printer defined
  STATUS_PARENT_KEY_NOTFOUND      constant STATUS := 506; -- invalid item/country/wild farm code
  STATUS_INVALID_HARVEST_DATE     constant STATUS := 507; -- Invalid (harvest) date
  STATUS_LAS_PALLET_UPD_FAIL      constant STATUS := 508; -- cannot update LAS_PALLET table
  STATUS_SOS_BATCH_UPD_FAIL       constant STATUS := 509; -- cannot update SOS batch data

  STATUS_BATCH_NOT_ACTIVE         constant STATUS := 510; -- SOS batch not in active status
  STATUS_TRAILER_NOT_FOUND        constant STATUS := 511; -- Trailer not found (to deliver shorts)
  STATUS_SOS_E_NEXT_BATCH         constant STATUS := 512; -- Error in retrieving next batch info
  STATUS_SOS_E_UPD_BATCH_STA      constant STATUS := 513; -- Error in updating the batch status
  STATUS_SOS_E_TEMP_TBL           constant STATUS := 514; -- Error in temporary table creation
  STATUS_SOS_E_PREV_BATCH         constant STATUS := 515; -- Error in retrieving previous batch info
  STATUS_SOS_E_UPC                constant STATUS := 516; -- Error in retrieving UPC info
  STATUS_SOS_E_ITEM               constant STATUS := 517; -- Error in retrieving Item info
  STATUS_SOS_E_CUST               constant STATUS := 518; -- Error in retrieving Cust info
  STATUS_SOS_E_COO                constant STATUS := 519; -- Error in retrieving Coo info

  STATUS_SOS_E_FLOATS             constant STATUS := 520; -- Error in retrieving Floats info
  STATUS_SOS_E_FLT_DTL            constant STATUS := 521; -- Error in retrieving Float Detail info
  STATUS_SOS_E_FLT_QTY            constant STATUS := 522; -- Error in retrieving Float Detail Quantity info
  STATUS_SOS_E_SEND_BATCH         constant STATUS := 523; -- Error in sending the batch info
  STATUS_SOS_E_AISLE              constant STATUS := 524; -- Error in retrieving Aisle Info
  STATUS_SOS_E_DATA_COLL          constant STATUS := 525; -- Error in retrieving Data Collection Info
  STATUS_SOS_E_CTRY               constant STATUS := 526; -- Error in retrieving Country Name Info
  STATUS_SOS_E_USER_NOT_FND       constant STATUS := 527; -- User not found
  STATUS_SOS_E_INS_FLT_HIST       constant STATUS := 528; -- Error inserting into FLOAT_HIST table
  STATUS_SOS_E_UPD_FLT_HIST       constant STATUS := 529; -- Error in update of FLOAT_HIST table

  STATUS_SOS_E_CONFIG_INFO        constant STATUS := 530; -- Error in retrieving SOS_Config_Info
  STATUS_SOS_E_LBR_MGMT_FLAG      constant STATUS := 531; -- Error in retrieving Lbr Mgmt Flag
  STATUS_SOS_E_LBR_FUNC           constant STATUS := 532; -- Error in retrieving data from Lbr Func
  STATUS_SOS_E_PREV_BATCH_SCH     constant STATUS := 533; -- Error in create schedule for prev batch
  STATUS_SOS_E_NO_AUTH            constant STATUS := 534; -- Error user not authorized to use new SOS
  STATUS_SOS_E_DEACTIVATED        constant STATUS := 535; -- Error New SOS is deactivated
  STATUS_SOS_E_UNEXPECTED         constant STATUS := 536; -- Unexpected error in Batch selection program
  STATUS_SOS_E_BCH_ASSIGNED       constant STATUS := 537; -- Batch is assigned to another user
  STATUS_WRONG_CLIENT_OPTION      constant STATUS := 538; -- Wrong client option sent by client devices during login
  STATUS_SOS_PREV_BATCH_ACTIVE    constant STATUS := 539; -- Previous selection batch is still active

  STATUS_SOS_E_BCH_OPT_PULL       constant STATUS := 540; -- User is not allowed to download OPT batch
  STATUS_SOS_E_FD_UPDATE          constant STATUS := 541; -- Float Detail Update Failed
  STATUS_EQUIP_IN_USE             constant STATUS := 542; -- SOS/SLS equipment is currently in use
  STATUS_SOS_E_TEMP_TBL_EMPTY     constant STATUS := 543; -- Temporary table is empty
  STATUS_NO_EQPAR_DEFINED         constant STATUS := 544; -- Equipment Parameters not defined
  STATUS_SOS_E_BATCH_EMPTY        constant STATUS := 545; -- Batch number is null, but must Specify a Batch Number
--  STATUS_USER_ALREADY_SIGNED_ON_SLS constant STATUS := 546; -- User is already signed on to SLS (variable name too long, shortened below)
  STATUS_USR_ALRDY_SIGNED_ON_SLS  constant STATUS := 546; -- User is already signed on to SLS
--  STATUS_USER_ALREADY_SIGNED_ON_SOS constant STATUS := 547; -- User is already signed on to SOS (variable name too long, shortened below)
  STATUS_USR_ALRDY_SIGNED_ON_SOS  constant STATUS := 547; -- User is already signed on to SOS
  STATUS_TRUCK_ALREADY_CLOSED     constant STATUS := 548; -- Truck already closed


  -- resuming constants from inc/tm_define.h

  STATUS_AREA_MISMATCH            constant STATUS := 457; -- Area of "From Aisle" and "To Aisle" don't match

  STATUS_INV_TO_AISLE             constant STATUS := 557; -- Invalid "To Aisle"
  STATUS_SOS_DOOR_UPDATE_FAILED   constant STATUS := 558; -- Update batch.sos_door failed
  STATUS_INVALID_TRUCK_NO         constant STATUS := 559; -- Truck number supplied from RF is invalid

  STATUS_NOT_WEIGHT_TRACKED       constant STATUS := 560; -- Item/Pallet is not weight tracked
  STATUS_ERROR_ALLOC_MEM          constant STATUS := 561; -- Error in memory allocation
  STATUS_ERROR_CW_ACTIVE          constant STATUS := 562; -- Another user is collecting catch weight for this pallet
  STATUS_ERROR_NO_CW_RECS         constant STATUS := 563; -- No records in ORDCW table for the bulk pull
  STATUS_BAD_ROUTE_STATUS         constant STATUS := 564; -- Route status is not OPN or SHT
  STATUS_BAD_FLOAT_NO             constant STATUS := 565; -- Invalid Float number
  STATUS_BULK_NOT_DONE            constant STATUS := 566; -- Bulk Pull is not done yet
  STATUS_ERROR_CW_NOT_ACTIVE      constant STATUS := 567; -- Bulk Record is not active for Catch Weight Collection
  STATUS_INV_NOT_FOUND            constant STATUS := 568; -- Inventory not found to reprint the pallet label (Symbotic)
  STATUS_INV_HLD_FOUND_IN_SWP     constant STATUS := 569; -- Stop the swap when Inventory is found in HLD status for one of SWAP location
  STATUS_NDM_REL_FOUND_IN_SWP     constant STATUS := 570; -- Stop the swap when NDM RPL is in progress for one of SWAP location
  STATUS_NDM_PRE_NEW_CHK_IN_SWP   constant STATUS := 571; -- Stop the swap when INV qty allocation exists for other than NDM
  STATUS_UPD_INV_RMV_NDM_FAIL     constant STATUS := 572; -- Unable to remove NDM RPL for inv
  STATUS_UPC_NOT_UNIQUE           constant STATUS := 573; -- Scanned UPC is associated with more than one product

    -- Tue May  9 10:20:19 CDT 2017 Brian Bent  Added 574, 575, 576, 577
    STATUS_RCV_TRAILER_CHECK_NEED   constant STATUS := 574; -- Receiving trailer needs trailer check performed.
    STATUS_RCV_LOAD_NOT_FOUND       constant STATUS := 575; -- Receiving load number not found.
    STATUS_RCV_LOAD_ALREADY_CLOSED  constant STATUS := 576; -- Receiving load already closed.
    STATUS_PO_NOT_OPEN              constant STATUS := 577; -- Load is not open.  Meaning status is NEW/SCH.
    STATUS_INVALID_TASKING_FUNC     constant STATUS := 578; -- Invalid Tasking Function
    STATUS_UNEXPECTED               constant STATUS := 579; -- Unexpected Error
    STATUS_LOCATION_OCCUPIED        constant STATUS := 580; -- Destination Location in use/Occupied.
    STATUS_RECEIVING_VARIANCE       constant STATUS := 581; -- Send Receiving Variance report to RF device.
    STATUS_ZONE_RESTRICTED			constant STATUS := 582; -- Put zone has a restriction (column ZONE.code_name_restrict)
    STATUS_TASK_NOT_COMPLETE        constant STATUS := 583; -- Task Not Complete
    STATUS_TASK_NOT_ELIGIBLE        constant STATUS := 584; -- Task Not Eligible
    STATUS_DOOR_NOT_ASSIGNED        constant STATUS := 585; -- Door not assigned
    STATUS_WRONG_PALLET_SCANNED     constant STATUS := 586; -- Wrong Pallet Scanned
    STATUS_TRAILER_NOT_ATDOOR       constant STATUS := 587; -- Trailer not at door
    -- 900 to 949 used by RFTCP server - network layer.  See inc/rftcp.h.
    -- 950 to 999 used by RFTCP server - SWMS layer.   See inc/rftcp.h.

  -- resuming constants from inc/tm_define.h

  STATUS_NO_CHANGE                  constant STATUS := 1001;  -- No change between old status and adjusted status
  STATUS_MANIFEST_CLOSE             constant STATUS := 1002;  -- Manifest must be closed for confirm putaway
  STATUS_SYS_CUST_WARN              constant STATUS := 1003;  -- Warning to user that item is past cust + sysco shelf life
  STATUS_MFR_SHELF_WARN             constant STATUS := 1004;  -- Warning to user that item is past mfg shelf life
  STATUS_PAST_SHELF_WARN            constant STATUS := 1005;  -- Warning to user that item is past cust + sysco or mfg shelf life
  STATUS_EXP_WARN                   constant STATUS := 1006;  -- Warning to user that item will appear on expiration date warning report
  STATUS_ER_SEND_FAILED             constant STATUS := 1007;  -- Expected Receipt Message Failed
  STATUS_INVALID_MINILOAD_ITEM      constant STATUS := 1008;  -- Not a miniload item
--  STATUS_INVALID_INDUCTION_LOCATION constant STATUS := 1009;  -- Invalid Induction location (variable name too long, shortened below)
  STATUS_INVALID_INDUCTION_LOCN     constant STATUS := 1009;  -- Invalid Induction location

  STATUS_MSG_PENDING                constant STATUS := 1010;  -- For SOAP web services, user or broadcast msg(s) are pending
  STATUS_USER_ON_OTHER_EQUIP        constant STATUS := 1011;  -- user is already logged into another equipment
  STATUS_PENDING_PUTAWAY            constant STATUS := 1012;  -- PO line re-edits disabled for pending putaway tasks
  STATUS_PO_IS_NOT_OPEN             constant STATUS := 1013;  -- PO must be open to edit/re-edit purchase order lines
  STATUS_INVALID_PARENT_LP		    constant STATUS := 1014;  -- For Build Master pallet if the parent pallet id is invalid
  STATUS_LP_ALREADY_LINKED          constant STATUS := 1015;  -- For Build Master pallet if the child LP is already linked
  STATUS_POD_RETURN_NOT_ALLOWED     constant STATUS := 1017;  -- For Driver Check-in
  STATUS_PALLET_ALREADY_DROPPED     constant STATUS := 1018;  -- Pallet cannot be dropped again, once it has already been dropped

  STATUS_MANIFEST_NOT_DCI_READY     constant STATUS := 1019;  -- retunrs on RF project; when manifests.sts_completed_ind is not Y; i.e. not ready for DCI.
  STATUS_INVALID_SLEEVE			    constant STATUS := 1020;  -- 12/08/20 Invalid selection sleeve
  STATUS_SLEEVE_IN_USE			    constant STATUS := 1021;  -- 12/08/20 Selection sleeve already in use
  STATUS_RTN_NOT_CMP       		    constant STATUS := 1022;  -- returns on RF project; manifest has at least one return with status not CMP.

  -- Swap (Labor Management) Statuses
  STATUS_OUTSIDE_SWAP_WINDOW	    constant STATUS := 1023;  -- When outside the time allowed by the SWAP_WINDOW_START/END syspars
  STATUS_SWAP_BAD_SEQUENCE		    constant STATUS := 1024;  -- When an attempt to start from sequence 2 is found.
  STATUS_NOT_IN_PM_TABLE		    constant STATUS := 1025;  -- When product_id + cust_pref_vendor not found in PM table
  STATUS_SWAP_BATCH_INACTIVE	    constant STATUS := 1026;  -- Swap batch has not been started yet
  STATUS_INV_ALLOCATED_QTY		    constant STATUS := 1027;  -- qty_alloc or qty_planned is not 0 i.e: something else is running on this inv item

  STATUS_USER_MULTI_YARD_TASKS      constant STATUS := 1028; -- More than one Yard task assigned to the user

  STATUS_XDOCK_BLPN_MISSING		    constant STATUS := 1029;

  STATUS_XDOCK_PUT_INV_LOC     constant STATUS := 1030;    -- Cross Dock PO to be putaway has location not in LOC table.
  STATUS_XDOCK_PUT_REQUIRE     constant STATUS := 1031;    -- Cross Dock PO to be putaway must use separate RF logic.
  

	SERIALIZED_DATE_BUF_SIZE       constant NATURAL := 6;            -- # buffer characters needed for string using std format
	SERIALIZED_DATE_PATTERN        constant VARCHAR2(6) := 'MMDDYY'; -- Negotiated date format between host & RF

	-- these names match those used by UNIX syslog() - ref /usr/include/sys/syslog.h

	subtype LOG_PRIORITY is VARCHAR2(8);

	LOG_EMERG		constant LOG_PRIORITY := 'EMERG';	-- 0   /* system is unusable */
	LOG_ALERT		constant LOG_PRIORITY := 'ALERT';	-- 1   /* action must be taken immediately */
	LOG_CRIT		constant LOG_PRIORITY := 'CRIT';	-- 2   /* critical conditions */
	LOG_ERR			constant LOG_PRIORITY := 'ERR';		-- 3   /* error conditions */
	LOG_WARNING		constant LOG_PRIORITY := 'WARNING';	-- 4   /* warning conditions */
	LOG_NOTICE		constant LOG_PRIORITY := 'NOTICE';	-- 5   /* normal but signification condition */
	LOG_INFO		constant LOG_PRIORITY := 'INFO';	-- 6   /* informational */
	LOG_DEBUG		constant LOG_PRIORITY := 'DEBUG';	-- 7   /* debug-level messages */


	subtype LOG_EVENT is VARCHAR2(10);

	LOG_EVENT_INIT		constant LOG_EVENT := 'Initialize';
	LOG_EVENT_CMPLT		constant LOG_EVENT := 'Complete';
	LOG_EVENT_EXCP		constant LOG_EVENT := 'Exception';
	LOG_EVENT_APP_MSG	constant LOG_EVENT := 'AppMsg';

	STALE_BROADCAST_MSG	constant number	:= 120;	-- in minutes

	RF_CLIENT_IP_ADDRESS		varchar2(45);

	procedure LogMsg(
		message_priority	LOG_PRIORITY,
		message_text		varchar2
	);

	function Initialize(
		rf_init_record		rf_log_init_record
	)
	return STATUS;	 --	must be	rf	status value

	procedure Complete(
		rf_status			in STATUS
	);

	procedure LogException;

	function NoNull(			-- overloaded function
		arg1				number
	) return number;

	function NoNull(			-- overloaded function
		arg1				varchar2
	) return varchar2;

	procedure SendUserMsg(
		msg_text			varchar2,
		to_user				varchar2
	);

	procedure BroadcastMsg(
		msg_text			varchar2
	);
	
	function SendUserMsgRftcp(
		msg_text			IN varchar2,
		to_user				IN varchar2,
		sender				IN varchar2,
		when_queued			IN varchar2
	) return pls_integer;

	function GetMsg
	(
		i_rf_log_init_record	in rf_log_init_record,
		o_msg_collection		out	rf_msg_obj
	) return rf.STATUS;

	procedure GetMsgTmConnect;

	function GetMsgInternal
	(
		o_msg_collection		out	rf_msg_obj
	) return rf.STATUS;

END rf;
/
SHOW ERRORS

create or replace package body rf as

	/*--------------------------------------------------------------------*/
	/* procedure LogMsg_Internal()                                        */
	/*                                                                    */
	/*--------------------------------------------------------------------*/

	procedure LogMsg_Internal(	-- this should only be called by procedures/functions internal to this package
		owner				varchar2,
		name				varchar2,
		lineno				number,
		caller_t			varchar2,
		rf_status			number,
		event				varchar2,
		message_priority	LOG_PRIORITY,
		message_text		varchar2,
		rf_init_record		rf_log_init_record
	)
	as
		pragma autonomous_transaction;
	
		session_serial_no	number;

	begin
		select serial#
			into session_serial_no
			from v$session vs
			where vs.sid = sys_context('userenv','sid');
		
		insert into rf_log values(
			current_timestamp,
			rf_log_sequence.nextval,
			user,
			RF_CLIENT_IP_ADDRESS,
			sys_context('userenv','sid'),
			session_serial_no,
			owner,
			name,
			lineno,
			caller_t,
			rf_status,
			event,
			message_priority,
			message_text,
			rf_init_record);
		
		commit;
	end LogMsg_Internal;


	/*--------------------------------------------------------------------*/
	/* procedure LogMsg()                                                 */
	/*                                                                    */
	/*--------------------------------------------------------------------*/

	procedure LogMsg(
		message_priority	LOG_PRIORITY,
		message_text		varchar2
	)
	as
$if dbms_db_version.ver_le_11 $then
		l_owner		varchar2(30);
		l_name		varchar2(30);
$else
		l_owner		rf_log.caller_owner%type;
		l_name		rf_log.caller_name%type;
$end
		l_lineno	number;
		l_caller_t	varchar2(30);

	begin
		owa_util.who_called_me(l_owner,l_name,l_lineno,l_caller_t);

		LogMsg_Internal(
			l_owner,
			l_name,
			l_lineno,
			l_caller_t,
			null,
			LOG_EVENT_APP_MSG,
			message_priority,
			message_text,
			null);
	end logmsg;


	/*--------------------------------------------------------------------*/
	/* function Initialize()                                              */
	/*                                                                    */
	/*--------------------------------------------------------------------*/

	function Initialize(
		rf_init_record		rf_log_init_record
	)
	return STATUS
	as
		pragma autonomous_transaction;

$if dbms_db_version.ver_le_11 $then
		l_owner			varchar2(30);
		l_name			varchar2(30);
$else
		l_owner			rf_log.caller_owner%type;
		l_name			rf_log.caller_name%type;
$end
		l_lineno		number;
		l_caller_t		varchar2(30);
		
		l_msg_count		number;
		l_result		STATUS := STATUS_NORMAL;
	
	begin
		-- In Modernized SWMS, the Java layer will set the true RF client ip address in the client_info field.  We'll
		-- retrieve that, save it in a global, and then update the client_info field with our normal data.

		dbms_application_info.read_client_info(RF_CLIENT_IP_ADDRESS);

		dbms_application_info.set_client_info('RF/' || rf_init_record.device || '/' || RF_CLIENT_IP_ADDRESS || '/' || rf_init_record.mac_address);

		owa_util.who_called_me(l_owner,l_name,l_lineno,l_caller_t);
		dbms_application_info.set_module(l_owner || '.' || l_name || '/' || l_lineno || '/' || l_caller_t, 'RF_Initialize');

		dbms_session.set_identifier('RF/' || rf_init_record.application);

		LogMsg_Internal(
			l_owner,
			l_name,
			l_lineno,
			l_caller_t,
			null,
			LOG_EVENT_INIT,
			LOG_INFO,
			'Initialization',
			rf_init_record);

		-- Insert user records for any broadcast records for us we haven't processed

		insert into rf_msg_status s
		(msg_seq, to_user, when_sent)
			select msg_seq,regexp_replace(user,'^OPS\$'),when_sent
				from rf_msg_status
				where to_user = '*ALL' and
					msg_seq not in (select msg_seq from rf_msg where ((sysdate - add_date) * 24 * 60) > STALE_BROADCAST_MSG) and
					msg_seq not in (select msg_seq from rf_msg_status where to_user = regexp_replace(user,'^OPS\$'));


	-- Check for pending RF user/broadcast messages

		SELECT count(*) into l_msg_count 
		FROM rf_msg m
		WHERE m.msg_seq in (
			SELECT s.msg_seq from rf_msg_status s
				WHERE s.to_user = regexp_replace(user,'^OPS\$') and
				when_sent is null);

		if l_msg_count = 0 then
			l_result := STATUS_NORMAL;
		else
			l_result := STATUS_MSG_PENDING;
		end if;

		commit;
		return l_result;
	end Initialize;


	/*--------------------------------------------------------------------*/
	/* procedure Complete()                                               */
	/*                                                                    */
	/*--------------------------------------------------------------------*/

	procedure Complete(
		rf_status			in STATUS
	)
	as
$if dbms_db_version.ver_le_11 $then
		l_owner		varchar2(30);
		l_name		varchar2(30);
$else
		l_owner		rf_log.caller_owner%type;
		l_name		rf_log.caller_name%type;
$end
		l_lineno	number;
		l_caller_t	varchar2(30);

	begin
		owa_util.who_called_me(l_owner,l_name,l_lineno,l_caller_t);
		dbms_application_info.set_module(l_owner || '.' || l_name || '/' || l_lineno || '/' || l_caller_t, 'RF_Complete/' || rf_status);

		LogMsg_Internal(
			l_owner,
			l_name,
			l_lineno,
			l_caller_t,
			rf_status,
			LOG_EVENT_CMPLT,
			LOG_INFO,
			'Complete',
			null);
	end Complete;


	/*--------------------------------------------------------------------*/
	/* procedure LogException()                                           */
	/*                                                                    */
	/*--------------------------------------------------------------------*/

	procedure LogException
	as
$if dbms_db_version.ver_le_11 $then
		l_owner			varchar2(30);
		l_name			varchar2(30);
$else
		l_owner			rf_log.caller_owner%type;
		l_name			rf_log.caller_name%type;
$end
		l_lineno		number;
		l_caller_t		varchar2(30);

	begin
		owa_util.who_called_me(l_owner,l_name,l_lineno,l_caller_t);
		dbms_application_info.set_module(l_owner || '.' || l_name || '/' || l_lineno || '/' || l_caller_t, 'RF_Exception/' || sqlcode);

		LogMsg_Internal(
			l_owner,
			l_name,
			l_lineno,
			l_caller_t,
			null,
			LOG_EVENT_EXCP,
			LOG_ERR,
			'Exception code='	|| sqlcode || 
				', stack='		|| dbms_utility.format_error_stack || 
				', backtrace='	|| dbms_utility.format_error_backtrace,
			null);
	end LogException;


	/*--------------------------------------------------------------------*/
	/* function NoNull()                                                  */
	/*                                                                    */
	/* Note, this function is overloaded.                                 */
	/*--------------------------------------------------------------------*/

	function NoNull(			-- overloaded function
		arg1				number
	) return number
	as
	begin
		return nvl(arg1,0);
	end NoNull;


	/*--------------------------------------------------------------------*/
	/* function NoNull()                                                  */
	/*                                                                    */
	/* Note, this function is overloaded.                                 */
	/*--------------------------------------------------------------------*/

	function NoNull(			-- overloaded function
		arg1				varchar2
	) return varchar2
	as
	begin
		return nvl(arg1,' ');	-- space will get RTRIM()'ed to zero-length string by RF client code
	end NoNull;


	/*--------------------------------------------------------------------*/
	/* procedure SendUserMsg()                                            */
	/*                                                                    */
	/*--------------------------------------------------------------------*/
	
	procedure SendUserMsg(
		msg_text			varchar2,
		to_user				varchar2
	)
	as
	begin
		insert into rf_msg 
		(msg_seq, msg_text, add_date, add_user)
		values(rf_msg_sequence.nextval,msg_text,current_date,user);
		insert into rf_msg_status
		 (msg_seq, to_user, when_sent)
		 values(rf_msg_sequence.currval,to_user,NULL);
	end SendUserMsg;


	/*--------------------------------------------------------------------*/
	/* procedure BroadcastMsg()                                           */
	/*                                                                    */
	/*--------------------------------------------------------------------*/

	procedure BroadcastMsg(
		msg_text			varchar2
	)
	as
	begin
		-- Note, for Broadcast messages, we'll insert individual user records into rf_msg_status 
		-- when we retrieve the message to be sent to the RF user.

		insert into rf_msg 
		(msg_seq, msg_text, add_date, add_user)
		values(rf_msg_sequence.nextval,msg_text,current_date,user);

		insert into rf_msg_status 
		(msg_seq, to_user, when_sent)
		values(rf_msg_sequence.currval,'*ALL',NULL);
	end BroadcastMsg;


	/*--------------------------------------------------------------------*/
	/* function SendUserMsgRftcp()                                        */
	/*                                                                    */
	/*--------------------------------------------------------------------*/

	function SendUserMsgRftcp(
		msg_text			IN varchar2,
		to_user				IN varchar2,
		sender				IN varchar2,
		when_queued			IN varchar2
	) return pls_integer
	as
	$if swms.platform.SWMS_REMOTE_DB $then
		
			endpoint VARCHAR2(20);
			json_in  VARCHAR2(500);
			outvar   VARCHAR2(500);
			rc PLS_INTEGER;
		BEGIN
				endpoint := 'send_rf_message';
				pl_text_log.ins_msg('INFO', 'RF_GET MSG', '********** Sending message', NULL, NULL); -- for swms.log file     
	            json_in := '{'
	                       || '"msg_text":"'
	                       || msg_text
	                       || '",' -- remember to escape special characters
	                       || '"to_user":"'
	                       || to_user
	                       || '",'
	                       || '"sender":"'
	                       || sender
	                       || '",'
	                       || '"when_queued":"'
	                       || when_queued
	                       || '"'
	                       || '}';
	            rc:= pl_call_rest.call_rest_post(json_in, endpoint, outvar);
	         	pl_text_log.ins_msg('INFO', 'RF_GET MSG', '********** Message sent '|| outvar, NULL, NULL); -- for swms.log file
	         	return rc;
		END;
	$else
			external
			library RF_lib
			name "ora_sendmsg"
			language C
			parameters(
				msg_text	string,
				to_user		string,
				sender		string,
				when_queued	string
			);		
	$end
	

	/*--------------------------------------------------------------------*/
	/* function GetMsg()                                                  */
	/*                                                                    */
	/*--------------------------------------------------------------------*/

	function GetMsg
	(
		i_rf_log_init_record	in rf_log_init_record,
		o_msg_collection		out	rf_msg_obj
	) return rf.STATUS
	as
		rf_status					rf.STATUS := rf.STATUS_NORMAL;

	BEGIN
		-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize().

		o_msg_collection	:= rf_msg_obj(rf_msg_table());


		-- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.
		
		rf_status := rf.Initialize(i_rf_log_init_record);
		if rf_status = rf.STATUS_NORMAL or rf_status = rf.STATUS_MSG_PENDING then
		
		
		-- Step 3:  Call internal function to get the data

			rf_status := GetMsgInternal(o_msg_collection);

		end if;	/* rf.Initialize() returned NORMAL */


		-- Step 4:  Call rf.Complete() with final status

		rf.Complete(rf_status);
		return rf_status;

		exception
			when others then
				rf.LogException();	-- log it
				raise;				-- then throw up to next handler, if any
	end GetMsg;


	/*--------------------------------------------------------------------*/
	/* procedure GetMsgTmConnect()                                        */
	/*                                                                    */
	/*--------------------------------------------------------------------*/

	procedure GetMsgTmConnect
	as
		o_msg_collection	rf_msg_obj;

		l_status			rf.status := rf.STATUS_NORMAL;
		l_msg_table			rf_msg_table;

	BEGIN
		l_status := GetMsgInternal(o_msg_collection);

		if l_status = rf.STATUS_NORMAL then
			l_msg_table := o_msg_collection.msg_table;

			if l_msg_table.count > 0 then
				for i in l_msg_table.FIRST .. l_msg_table.LAST loop
					-- Note, convert when_queued to format expected by rftcp_server, which is strftime() format of "%d%b %I:%M:%S %p"

					l_status := SendUserMsgRftcp(
						l_msg_table(i).msg_text,
						regexp_replace(user,'^OPS\$'),
						l_msg_table(i).sender,
						to_char(to_date(l_msg_table(i).when_queued,'yyyy-mm-dd hh24:mi:ss'),'mmMon hh12:mi:ss AM'));
				end loop;
			end if;
		end if;
	end GetMsgTmConnect;


	/*--------------------------------------------------------------------*/
	/* function GetMsgInternal()                                          */
	/*                                                                    */
	/*--------------------------------------------------------------------*/

	function GetMsgInternal
	(
		o_msg_collection		out	rf_msg_obj
	) return rf.STATUS
	as
		rf_status					rf.STATUS := rf.STATUS_NORMAL;
		l_msg_table					rf_msg_table;

	BEGIN
		-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize().

		o_msg_collection	:= rf_msg_obj(rf_msg_table());


		-- Step 2:  Insert user records for any broadcast records for us we haven't processed

		insert into rf_msg_status s
		(msg_seq, to_user, when_sent)
			select msg_seq,regexp_replace(user,'^OPS\$'),when_sent
				from rf_msg_status
				where to_user = '*ALL' and
					msg_seq not in (select msg_seq from rf_msg where ((sysdate - add_date) * 24 * 60) > STALE_BROADCAST_MSG) and
					msg_seq not in (select msg_seq from rf_msg_status where to_user = regexp_replace(user,'^OPS\$'));


		-- Step 3: Retrieve collection of records (messages we need to send)

		SELECT rf_msg_record(
			regexp_replace(m.add_user,'^OPS\$'),
			to_char(m.add_date,'yyyy-mm-dd hh24:mi:ss'),
			m.msg_text)
		BULK COLLECT INTO l_msg_table	-- output into local temporary table
		FROM rf_msg m
		WHERE m.msg_seq in (
			SELECT s.msg_seq from rf_msg_status s
				WHERE s.to_user = regexp_replace(user,'^OPS\$') and
				when_sent is null)
		ORDER BY m.msg_seq;

		o_msg_collection := rf_msg_obj(l_msg_table);	-- set OUT parm to temp table

		if l_msg_table.count = 0 then
			rf_status := rf.STATUS_NOT_FOUND;

		else
			-- Step 4: Mark those messages as sent

			UPDATE rf_msg_status s
				SET s.when_sent = sysdate WHERE
				s.when_sent IS NULL AND
				s.to_user = regexp_replace(user,'^OPS\$');
		end if;
		commit;
		return rf_status;
	end GetMsgInternal;

END rf;
/
SHOW ERRORS

grant execute on rf to swms_user;
create or replace public synonym rf for swms.rf;
