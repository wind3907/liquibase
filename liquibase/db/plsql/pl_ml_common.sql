CREATE OR REPLACE PACKAGE swms.pl_ml_common
AS

-- *********************** <Package Specifications> ****************************

-- ************************* <Prefix Documentations> ***************************

--  This package specification is used mainly for Mini Load processing. It also
--  include some common functions for use by other nonMini-load processing.
  
--  @(#) pl_ml_common.sql
--  @(#) src/schema/plsql/pl_ml_common.sql, swms, swms.9, 11.2 12/17/09 1.9
 
--  Modification History
--  Date      User   Defect  Comment
--  --------  ------ ------  --------------------------------------------------
--  02/08/06  prplhj 12055   Initial version
--  03/15/06  prplhj 12072   Modified handle_cc_ml_loc_changes() to look at 2
--			     messages from MINILOAD_MESSAGE table to update the
--			     cycle count task locations and/or pallets to the
--			     latest from the Mini-load system. Added
--			     a new procedure called handle_special_cc_info()
--			     to handle the cycle count special handling methods
--			     during edit and/or adjustment processes.
--  04/10/06  prplhj 12080   Modified handle_special_cc_info() to correct
--			     mispicked item problem for cycle counts.
--
--  04/28/06  prplhj 12087   Modified inv insert statement to use 2 - uom
--			     instead of just uom for inv_uom column. Fixed
--			     handle_special_cc_info() to only make inv off hold
--			     for those records that have Mini-load slots.
--
--  03/07/07  prpbcb 12114   DN: 12214
--                           Ticket: 326211
--                           Project: 326211-Miniload Induction Qty Incorrect
--
--                           Added the following procedure to validate if
--                           and item is in the miniloader.
--                              - is_miniload_item()
-- 
--                           Added the following constants to use in
--                           procedure is_miniload_item().
--                              - CT_CHECK_ITEM
--                              - CT_CHECK_ITEM_CPV
--                              - CT_CHECK_ITEM_CPV_UOM
--
--  09/05/07  prpbcb 12280  DN 12280
--                          Ticket: 458478
--                          Project: 458478-Miniload Fixes
--                          Removed assignment of add_date, add_user, upd_date
--                          and upd_user.  Default values have been added
--                          to the table columns for add_date and add_user and
--                          a database trigger created to assign the upd_date
--                          and upd_user.
--
--                          Removed UPPER applied to the message type.
--                          The UPPER is not necessary because the message
--                          types have defined values.
--
-- 12/17/09   prpbcb        DN 12533
--                          Removed AUTHID CURRENT_USER.  We found a problem in
--                          pl_rcv_open_po_cursors.f_get_inv_qty when using it.
--
--
-- ******************** <End of Prefix Documentations> *************************

-- ************************* <Constant Definitions> ****************************

C_ML_RULEID		CONSTANT NUMBER := 3;
C_ML_SLOT_TYPE		CONSTANT VARCHAR2(3) := 'MLS';

C_NORMAL		CONSTANT NUMBER := 0;
C_NO_DATA_FOUND		CONSTANT NUMBER := 1403;

-- From tm_define.h
C_INV_LOCATION		CONSTANT NUMBER := 31;	-- Invalid location
C_INV_PRODID		CONSTANT NUMBER := 37;	-- Invalid item
C_HOME_SLOT_UNVAL	CONSTANT NUMBER := 132; -- Home slot is not available
C_LOC_DAMAGED		CONSTANT NUMBER := 160;	-- Location is damaged

-- Other information/warning/error codes
C_ML_INV_NOT_EXISTS	CONSTANT NUMBER := 1;	-- Mini-load induction slot but
						-- inventory is not there
C_ML_NOT_ML_SLOT	CONSTANT NUMBER := 2;	-- Location is not a ML slot
C_ML_NO_CC_EXC		CONSTANT NUMBER := 3;	-- Mini-load slot but no MIS
						-- transaction (i.e., no cycle
						-- count exception)

--
-- What to check when checking if an item is in the miniloader.
--
CT_CHECK_ITEM           CONSTANT  VARCHAR2(20) := 'CHECK_ITEM';
CT_CHECK_ITEM_CPV       CONSTANT  VARCHAR2(20) := 'CHECK_ITEM_CPV';
CT_CHECK_ITEM_CPV_UOM   CONSTANT  VARCHAR2(20) := 'CHECK_ITEM_CPV_UOM';


-- *************************** <Type Definitions> *****************************

-- To hold the package defined error code and its coresponding string
TYPE recTypPkgError IS RECORD (
  iErrorCode		NUMBER,
  sErrorStr		VARCHAR2(50)
);

-- An array of error codes and their corresponding strings
TYPE tabTypPkgErrors IS TABLE OF recTypPkgError
  INDEX BY BINARY_INTEGER;

-- ************************* <Variable Definitions> ****************************

gtabTypPkgErrors		tabTypPkgErrors;	-- For error handling

-- =============================================================================
-- Function
--   f_is_induction_loc 
--
-- Description
--   The function checks if the input location is an induction location
--
-- Parameters
--
--  Input:
--	psLoc   		location       
--
--  Return:
--	psRtnCode       Y=loc is induction, N=loc is not induction location 
--
-- Modification History
-- Date      User   Defect  Comment
-- 11/16/05  PRPHQB         create f_is_induction_loc          
--
FUNCTION f_is_induction_loc(
  	psLoc   			IN	loc.logi_loc%TYPE)
RETURN VARCHAR2;                            


-- =============================================================================
-- Function
--   f_is_mls_loc
--
-- Description
--   The function checks whether the input location is a Mini-load location
--   (including internal Mini-load slots and induction slots.)
--
-- Parameters
--
--  Input:
--	psLoc		Location
--
--  Output:
--	Y=loc is Mini-load slot, N=loc is not Mini-load location 
--
-- Modification History
-- Date      User   Defect  Comment
-- 12/01/05  prplhj         Initial version
--
FUNCTION f_is_mls_loc(
  	psLoc				IN	loc.logi_loc%TYPE)
RETURN VARCHAR2;


-- =============================================================================
-- Function
--   f_get_mls_zone
--
-- Description
--   The function retrieves the zone ID along with its type for a Mini-load
--   slot/item, including internal Mini-load slots (if piInductOnly flag is set)
--   and/or induction slots (if piInductOnly is not set.) If the zone
--   is found, the caller must use a way to seperate the returned string to
--   get the zone ID.
--
--   Note: If the input piUom is either 0 or 2 and the zone is found, the
--         function will only return the type as 2 and the PM.zone_id unless
--	   the piSplitZoneOnly flag is set (>0) and split zone ID is found.
--
-- Parameters
--
--  Input:
--	psLoc		Location
--	psItem		Item #
--	psCpv		Customer Preference Vendor
--	piUom		Unit of measure, default to 0
--      piSplitZoneOnly	When piUom is 0 or 2, still return the case zone ID if
--			found (0, default), or return the split zone ID if
--			found (1), or return the case zone ID if split zone ID
--			is not found (> 1).
--	piInductOnly	Whether to check induction location only (=0, default)
--			or not (>0)
--
--  Output:
--      NULL		The slot/item is in Mini-load but there is no zone
--			associate with it or the item is not in the system.
--	-1		If error has occurred or the slot is not a Mini-load
--			slot. 
--	-2		Item shouldn't be in the Mini-load system.
--	-3		The slot is not an induction slot when the piInductOnly
--			is 0.
--      <Type><ZoneID>	<Type> is either 1 (split zone) or 2 (case zone).
--			<ZoneID> is the found zone ID.
--
-- Modification History
-- Date      User   Defect  Comment
-- 12/01/05  prplhj         Initial version
--
FUNCTION f_get_mls_zone(
  	psLoc				IN	loc.logi_loc%TYPE,
  	psItem				IN	pm.prod_id%TYPE,
  	psCpv				IN	pm.cust_pref_vendor%TYPE,
  	piUom				IN	loc.uom%TYPE DEFAULT 0,
  	piSplitZoneOnly			IN	NUMBER DEFAULT 0,
  	piInductOnly			IN	NUMBER DEFAULT 0)
RETURN VARCHAR2;


-- =============================================================================
-- Function
--   f_get_miniload_ind 
--
-- Description
--   The function returns the miniload_storage_ind from pm table       
--
-- Parameters
--
--  Input:
--	psProdID	product ID
--	psCPV        	cpv                                 
--
--  Output:
--	psInd           B=both, S=Split only, N=neither                             
--
-- Modification History
-- Date      User   Defect  Comment
-- 11/15/05  PRPHQB         create get_miniload_ind            
--
FUNCTION f_get_miniload_ind(
  	psProdID			IN	pm.prod_id%TYPE,
  	psCPV    			IN	pm.cust_pref_vendor%TYPE)
RETURN pm.miniload_storage_ind%TYPE;
--
--
-- =============================================================================
-- Function
--   f_check_ml_exp_receipt_sent
--
-- Description
--   The function checks whether the input license plate (psLP) has been sent
--   to the Mini-load system for the "ExpectedReceipt" message.
--
-- Parameters
--
--  Input:
--	psLP		pallet_id; license plate
--
--  Output:
--	-1	Database error occurred
--	0	The license plate has not been sent to the Mini-load system or
--		it never sent
--	1	The license plate has been sent to the Mini-load system
--
-- Modification History
-- Date      User	Comment
-- 01/11/06  prplhj	Initial version   
--
FUNCTION f_check_ml_exp_receipt_sent(
	psLP			IN miniload_message.expected_receipt_id%TYPE)
RETURN NUMBER;
--
--
-- =============================================================================
-- Function
--   f_get_pkg_error_str
--
-- Description
--   The function returns an error string (not error message!) corresponding to
--   the input code. The result can be NULL if no error code is found.
--
-- Parameters
--
--  Input:
--	piCode		a numeric code
--
--  Output:
--	A VARCHAR2 string for the corresponding piCode or NULL if cannot find.
--
-- Modification History
-- Date      User	Comment
-- 01/11/06  prplhj	Initial version   
--
FUNCTION f_get_pkg_error_str(piCode     IN NUMBER)
RETURN VARCHAR2;
--
--
-- =============================================================================
-- Procedure
--   get_induction_loc
--
-- Description
--   The procedure returns the induction location for a SKU             
--
-- Parameters
--
--  Input:
--		psProdID	product ID
--		psCPV    	cpv                                 
--		piUOM 		UOM = 1, 2, or 0      
--
--  Output:
--		piStatus	=0 means SKU is in ML, induction location is
--                      	valid data NO_DATA_FOUND if SKU is not in ML
--                      	SQLCODE if database error or EXCEPTION
--		psInductionLoc	induction location as from the zone table
--
--
-- Modification History
-- Date      User   Defect  Comment
-- 11/15/05  PRPHQB         create get_induction_loc procedure
--
PROCEDURE get_induction_loc(
  	psProdID			IN	pm.prod_id%TYPE,
  	psCPV    			IN	pm.cust_pref_vendor%TYPE,
  	piUOM 				IN  	uom.uom%TYPE,
 	piStatus			OUT	NUMBER,  
  	psInductionLoc			OUT	zone.induction_loc%TYPE); 
--
--
-- =============================================================================
-- Procedure
--   get_outbound_loc
--
-- Description
--   The procedure returns the outbound location for a SKU             
--
-- Parameters
--
--  Input:
--		psProdID	product ID
--		psCPV    	cpv                                 
--		piUOM 		UOM = 1, 2, or 0      
--
--  Output:
--		piStatus	=0 means SKU is in ML, outbound location is
--                      	valid data NO_DATA_FOUND if SKU is not in ML
--                      	SQLCODE if database error or EXCEPTION
--		psOutboundLoc	outbound location as from the zone table
--
--
-- Modification History
-- Date      User   Comment
-- 01/25/06  prplhj Initial version
--
PROCEDURE get_outbound_loc(
  	psProdID			IN	pm.prod_id%TYPE,
  	psCPV    			IN	pm.cust_pref_vendor%TYPE,
  	piUOM 				IN  	uom.uom%TYPE,
 	piStatus			OUT	NUMBER,  
  	psOutboundLoc			OUT	zone.outbound_loc%TYPE); 
--
--
-- =============================================================================
-- Function
--   get_mls_zones
--
-- Description
--   The function retrieves the case zone ID and split zone ID regardless of
--   their values for the slot/item input when the slot is a Mini-load slot.
--   This is an overloaded procedure.
--
-- Parameters
--
--  Input:
--	psLoc		Location
--	psItem		Item #
--	psCpv		Customer Preference Vendor
--	posCaseZone	Output value for PM.zone_id. It can be NULL
--	posSplitZone	Output value for PM.split_zone_id. It can be NULL
--	poiStatus	Output value for processing status. It has one of the
--			following values:
--			  0	Retrieve of zone IDs are successful
--			  -1	If error has occurred or the slot is not a
--				Mini-load slot. posCaseZone and posSplitZone
--				will be set to NULL
--			  -2	Item shouldn't be in the Mini-load system.
--				posCaseZone and posSplitZone will be set to NULL
--			  -3	Item is not in the system
--
--  Output:
--	See Input for Output fields
--
-- Modification History
-- Date      User   Defect  Comment
-- 12/01/05  prplhj         Initial version
--
PROCEDURE get_mls_zones(
  	psLoc				IN	loc.logi_loc%TYPE,
	psItem				IN	pm.prod_id%TYPE,
	psCpv				IN	pm.cust_pref_vendor%TYPE,
	posCaseZone			OUT	pm.zone_id%TYPE,
	posSplitZone			OUT	pm.split_zone_id%TYPE,
	poiStatus			OUT	NUMBER);
--
--
-- =============================================================================
-- Function
--   get_mls_zones
--
-- Description
--   The function retrieves the case zone ID and split zone ID regardless of
--   their values for the slot/item input when the slot is a Mini-load slot.
--   This is an overloaded procedure.
--
-- Parameters
--
--  Input:
--	psItem		Item #
--	psCpv		Customer Preference Vendor
--	posCaseZone	Output value for PM.zone_id. It can be NULL
--	posSplitZone	Output value for PM.split_zone_id. It can be NULL
--	poiStatus	Output value for processing status. It has one of the
--			following values:
--			  0	Retrieve of zone IDs are successful
--			  -2	Item shouldn't be in the Mini-load system.
--				posCaseZone and posSplitZone will be set to NULL
--			  -3	Item is not in the system
--
--  Output:
--	See Input for Output fields
--
-- Modification History
-- Date      User   Defect  Comment
-- 12/01/05  prplhj         Initial version
--
PROCEDURE get_mls_zones(
	psItem				IN	pm.prod_id%TYPE,
	psCpv				IN	pm.cust_pref_vendor%TYPE,
	posCaseZone			OUT	pm.zone_id%TYPE,
	posSplitZone			OUT	pm.split_zone_id%TYPE,
	poiStatus			OUT	NUMBER);
--
--
-- =============================================================================
-- Procedure
--   validate_loc
--
-- Description
--   The procedure checks the validity of the input location along with other
--   input parameters. It will return a nonzero error code if location is
--   invalid or as a warning and the error message. The error codes are defined
--   as public package constants so the caller can access to them.
--   The procedure is mainly used to check user location input when the original
--   location is "*" during receiving or proforma correction time.
--   See Output Parameters for details on the returned code.
--
-- Parameters
--
--  Input:
--		psProdID	product ID
--		psCPV    	customer preference vendor
--              psLoc           location to be checked
--              psPalletID	pallet ID to be checked
--		piUOM 		unit of measure, either 0 (default), 1, or 2
--		piChkExistedInv
--				Check if input LP already existed in INV (1)
--				or not (0, default) for reserved, bulk pull or
--				floating location only
--
--  Output:
--		posLocType	Location type of checked input location. If
--				error has occurred (posMsgType = 'F',) the
--				output parameter value is undefined. Otherwise,
--				the output value is consisted of 3 characters
--				in this order:
--				  1st character: X, F, or B
--				    X: not front or back location
--				    F: Carton Flow front location
--				    B: Carton Flow back location
--				  2nd character: X, H, O, R, F, B, I, or L
--				    X: location type is unknown
--				    H: home slot
--				    O: outside storage location
--				    R: reserved slot
--				    F: floating slot
--				    B: slot in bulk pull zone
--				    I: Mini-load induction slot
--				    L: Mini-load slot (other than induction slt)
--				  3rd character: Y, or N
--				    Y: MSKU pallet location
--				    N: non-MSKU pallet location
--		posCFLoc	Output Carton Flow front or back location.
--				If the 1st character of posLocType is:
--				  X: The value will be NULL.
--				  F: The value will be its back location.
--				  B: The value will be its front location.
--		posMsgType	If serious error has occurred, the value is "F".
--				Other values include "W"arning and
--				"I"nformation. This parameter is used to notify
--				user the severity of the error and the caller
--				should or shouldn't do something about it.
--		poiStatus	=0 The location is good to be used. <> 0 if
--				location shouldn't be used or the location
--				might still can be used providing that it's
--				agreeable by the user. The output has one of
--				the following values for the checked location:
--				  < 0
--				    This is Oracle database error code.
--				  C_INV_PRODID
--				    Item is not in the system.
--				  C_INV_LOCATION with one of the following
--				  conditions (error conditions):
--				    1. Location is not in the LOC table.
--				    2. Home slot already had other item in it.
--				    3. A case home slot but received uom is in
--				       splits.
--				    4. A split home slot but received uom is in
--				       cases.
--				    5. Pallet already existed in the inventory.
--				    6. Pallet is on hold and cannot go to home
--				       slot.
--				    7. Home slot cannot have rank > 1.
--				    8. Cannot be in home slot with item in the
--				       floating zone.
--				    9. Cannot put FIFO item to home slot
--				   10. A floating slot but item has a home slot.
--				   11. A floating/Mini-load slot that doesn't
--				       have specific zone set up. For Mini-load
--				       slot: a) If 'S' but no PM split_zone_id.
--				       b) If 'B' and item is not splitable but
--				       no PM zone_id. c) If 'B' and item is
--				       splitable but no either PM zone_id or
--				       PM split_zone_id.
--				   12. A Mini-load (induction) slot but item can
--				       only be in the main warehouse.
--				   13. Item can only have splts in the Mini-load
--				       (induction) slot but received uom is in
--				       cases.
--				   14. MSKU pallets exist in the location.
--				   15. Full MSKU pallets exist in the location.
--				   16. MSKU pallets are not allowed in deep
--				       slots.
--				   17. The MSKU pallet already had a slot to it
--				       (already existed in database.)
--				   18. Outside storage warehouse doesn't match.
--				  C_INV_LOCATION with one of the following
--				  conditions (warning conditions):
--				    1. Item is not slotted yet but location is
--				       a reserved slot.
--				  C_LOC_DAMAGED
--				    Location is damaged or on hold.
--				  C_HOME_SLOT_UNVAL
--				    The item has no home slot set up
--				  C_ML_INV_NOT_EXISTS
--				    Location is an induction location but there
--				    is no inventory record for it. It's up to
--				    the caller to decide whether this is a
--				    serious error or can pass it.
--				  
--		posErrMsg	NULL if piStatus = 0 or error message otherwise.
--
-- Modification History
-- Date      User   Defect  Comment
-- 12/01/05  prplhj         Initial version
--
PROCEDURE validate_loc(
  	psProdID			IN	pm.prod_id%TYPE,
  	psCPV    			IN	pm.cust_pref_vendor%TYPE,
  	psLoc    			IN	loc.logi_loc%TYPE,
  	psPalletID   			IN	inv.logi_loc%TYPE,
  	posLocType   			OUT	VARCHAR2,
  	posCFLoc			OUT	loc.logi_loc%TYPE,
  	posMsgType			OUT	VARCHAR2,
 	poiStatus			OUT	NUMBER,  
  	posErrMsg			OUT	VARCHAR2,
  	piUOM 				IN  	uom.uom%TYPE DEFAULT 0,
	piChkExistedInv		IN	NUMBER DEFAULT 0);
--
--
-- =============================================================================
-- Function
--   handle_cc_ml_loc_changes
--
-- Description
--   The procedure update the locations of cycle count tasks and/or cycle count
--   edit (before adjustment) to use the latest locations from inventory if
--   somehow they have been changed by the Mini-load system. There is no effect
--   if there is no Mini-load locations currently in the cycle count tasks or
--   edit.
--
-- Parameters
--
--  Input:
--	psSearch	Search criteria. Valid search criteria depends on
--			the piAdjustMode input. The valid value is as follows:
--			'ALL': Search all records from the cycle count related
--			       tables such as CC, CC_EXCEPTION_LIST and CC_EDIT.
--			       This is the default setting.
--			'ONE': Search a particular record from the cycle count
--			       related tables such as CC, CC_EXCEPTION_LIST and
--			       CC_EDIT. The value will be treated as searching
--			       for particular license plate.
--			<group #>: Treat it as a cycle count group # search if
--				   piAdjustMode is not equal to zero.
--				   Otherwise, treat it as a cycle count task
--				   edit date if piAdjustMode is zero.
--			<date>: Treat it as a cycle count edit date search if
--				piAdjustMode is zero. The string must be in
--				MMDDYYYY format if available.	
--	psLP		License plate if available. If psSearch is ONE, the
--			value must be provided. Otherwise, NULL is the default.
--	piAdjustMode	Zero, which is the default, means that the search is
--			for cycle count generation date or addition date. Other
--                      value means that the search is for cycle count group.
--                      The psSearch parameter will hold either the date or the
--                      group #.
--	piUpdateAlso	Whether the caller want to check if there is any
--			Mini-load location changes and also perform the
--                      corresponding updates on cycle count related tables
--                      (=1, default) or just want to check if there is any
--			change since last time (<> 1.) If change has occurred
--                      when the value is other than 1 (query mode only,) the
--                      poiStatus value will be 2.
--
--  Output:
--	poiStatus	0: No data have been changed according to the criteria.
--			1: Database values have been updated according to the
--			   criteria.
--			2: Mini-load location has been changed from original
--			   when the query mode is requested.
--			<0: Database error occurred.
--	posUpdLoc	The latest Mini-load location from inventory if any.
--			The value can only be exacted if psSearch is ONE.
--			Otherwise, the value will be from the last found record.
--	  
--
-- Modification History
-- Date      User   Defect  Comment
-- 01/21/06  prplhj         Initial version
--
PROCEDURE handle_cc_ml_loc_changes(
	poiStatus	OUT NUMBER,
	posUpdLoc	OUT inv.plogi_loc%TYPE,
        psSearch        IN  VARCHAR2 DEFAULT 'ALL',
	psLP		IN  inv.logi_loc%TYPE DEFAULT NULL,
        piAdjustMode    IN  NUMBER DEFAULT 0,
	piUpdateAlso	IN  NUMBER DEFAULT 1);
--
-- =============================================================================
-- Procedure
--   handle_special_cc_info
--
-- Description
--   This procedure handle special situations for cycle count exceptions during
--   cycle coun edit or adjustment time.
--   If the input LP doesn't belong to a Mini-load slot, there is nothing to
--   change. A zero returned coded will be assigned. Otherwise, the following
--   validations will occur:
--   1. The corresponding location of the input LP/carrier ID currently is
--      a Mini-load slot (including induction and outbound slot.)
--   2. The current cycle count task, either in the CC table or CC_EDIT table,
--      has an exception reason code of CC, or reason code from Returns
--      processing that will generate RTN transaction. The RTN transaction
--      should be the latest one that corresponds to the search item and was
--      created prior or at the same time of cycle count task was created.
--   If the above conditions are met, the procedure will perform the following
--   changes:
--   1. For all returned qty from the found RTN transaction,
--        For each on hold (status = HLD) inventory on the item,
--          Update the inventory record status to AVL.
--   2. Return a flag to the caller to indicate that the found RTN for the
--      corresponding LP is an invoiced item (1) or a mispicked item (0).
--   3. Return a status to the caller on the search and/or update.
--
-- Parameters
--
--  Input:
--				being found.
--		psPalletID	LP
--		psItem		Item #
--		psCpv		Cust Pref Vendor
--
--  Output:
--		poiInvItem	Indicate whether the item # in the found RTN
--				transaction from the input LP is corresponding
--				to an invoiced item or a mispicked item.
--		poiStatus	=0 means that the input LP/carrier ID was
--                     		handled by the Mini-load system before and it
--				was from returns with a RTN transaction. The
--				on hold inventory record(s), if available, can
--                              be updated to AVL status(es).
--				<0 means database error occurred.
--				C_ML_NOT_ML_SLOT means that the LP/carrier ID
--				is never a Mini-load slot.
--
-- Modification History
-- Date      User   Defect  Comment
-- 03/13/06  prplhj         Initial version
--
PROCEDURE handle_special_cc_info(
  	psPalletID          	IN  inv.logi_loc%TYPE,
	psItem			IN  pm.prod_id%TYPE,
	psCpv			IN  pm.cust_pref_vendor%TYPE,
        poiInvItem		OUT NUMBER,
	poiStatus		OUT NUMBER);
--
-- =============================================================================
-- Procedure
--   gen_ml_tasks_for_mis
--
-- Description
--   This procedure accepts input SWMS-generated LP. The corresponding
--   putaway task has the following characteristics:
--     1. Putaway location is a Mini-load slot
--     2. The putaway task is for a saleable return with exceptions which will
--        create MIS transaction.
--   If the condition is met, the procedure will do the following tasks:
--     1. Create an inventory record related to the LP. The inventory record
--        status will be put to on hold (HLD.)
--     2. Send an ExpectedReceipt message to Mini-load to notify the inventory.
--   Note that after creating the inventory record in SWMS, we will have
--   inventory qty descrepancy between SWMS and SUS. This will need to do some
--   special handling during cycle count edit and/or adjustment.
--
-- Parameters
--
--  Input:
--		psPalletID	LP
--
--  Output:
--		poiStatus	=0 means the location for the LP is either not
--                     		a Mini-load slot or creation of the tasks as
--				mentioned above is ok.
--				<0 means database error has occurred.
--				C_ML_INV_NOT_EXISTS means that the
--				ExpectedReceipt message cannot be sent to
--				Mini-load due to unknown errors.
--
-- Modification History
-- Date      User   Defect  Comment
-- 02/24/06  prplhj         Initial version
--
PROCEDURE gen_ml_tasks_for_mis(
  	psPalletID          	IN  trans.pallet_id%TYPE,
 	poiStatus		OUT NUMBER);
--
-- =============================================================================
-- Procedure
--   write_expected_receipt
--
-- Description
--   This procedure accepts input LP, validate need, then call a pl to write
--   record Validation is via reading TRANS table.
--
-- Parameters
--
--  Input:
--		psPalletID	LP
--
--  Output:
--		piStatus	=0 means the database record is written OK
--                     		also means the SKU is not in mini loader,
--				there's no need to write
--                 		!=0 means there is some problem 
--
-- Modification History
-- Date      User   Defect  Comment
-- 11/16/05  PRPHQB         create get_induction_loc procedure
--
PROCEDURE write_expected_receipt(
  	psPalletID          	IN  trans.pallet_id%TYPE,
 	piStatus		OUT NUMBER);  
--
-- =============================================================================


PROCEDURE is_miniload_item
        (i_what_to_check         IN  VARCHAR2,
         i_prod_id               IN  pm.prod_id%TYPE,
         i_cust_pref_vendor      IN  pm.cust_pref_vendor%TYPE,
         i_uom                   IN  uom.uom%TYPE,
         o_is_miniload_item_bln  OUT BOOLEAN,
         o_msg                   OUT VARCHAR2);

END pl_ml_common;
/

-- ***************************** <Package Body> ********************************

CREATE OR REPLACE PACKAGE BODY swms.pl_ml_common AS

-- ************************* <Package Body Constants> **************************

-- ************************* <Package Body Variables> **************************

gl_pkg_name   VARCHAR2(30) := 'pl_ml_common';  -- Package name.
                                               --  Used in error messages.


-- ********************** <Package Body Type Defines> **************************

-- ***************************** <Package Body> ********************************
FUNCTION f_is_induction_loc(
  	psLoc    		IN	loc.logi_loc%TYPE)
RETURN VARCHAR2 IS
  sRtnCode VARCHAR2(1) := 'N';
BEGIN
  SELECT 'Y' INTO sRtnCode
  FROM	zone z
  WHERE	induction_loc = psLoc
  AND   z.rule_id = C_ML_RULEID
  AND	z.zone_type = 'PUT';

  RETURN sRtnCode;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    sRtnCode := 'N';
    RETURN sRtnCode;
  WHEN OTHERS THEN
    RAISE;
END;

-- =============================================================================
FUNCTION f_is_mls_loc(
	psLoc				IN	loc.logi_loc%TYPE)
RETURN VARCHAR2 IS
  sExists	VARCHAR2(1) := 'N';
BEGIN
  SELECT 'Y' INTO sExists
  FROM loc
  WHERE logi_loc = psLoc
  AND   slot_type = C_ML_SLOT_TYPE;

  RETURN sExists;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 'N';
  WHEN OTHERS THEN
    RAISE;
END;

-- =============================================================================
FUNCTION f_get_mls_zone(
  	psLoc				IN	loc.logi_loc%TYPE,
  	psItem				IN	pm.prod_id%TYPE,
  	psCpv				IN	pm.cust_pref_vendor%TYPE,
  	piUom				IN	loc.uom%TYPE DEFAULT 0,
  	piSplitZoneOnly			IN	NUMBER DEFAULT 0,
  	piInductOnly			IN	NUMBER DEFAULT 0)
RETURN VARCHAR2 IS
  sInd			pm.miniload_storage_ind%TYPE := NULL;
  sZone			pm.zone_id%TYPE := NULL;
  sSplitZone		pm.split_zone_id%TYPE := NULL;
BEGIN
  -- Check if the location is a Mini-load slot
  IF f_is_mls_loc(psLoc) = 'N' THEN
    RETURN '-1';
  END IF;

  -- Check if the slot is an induction slot when the flag is set
  IF piInductOnly = 0 AND f_is_induction_loc(psLoc) = 'N' THEN
    RETURN '-3';
  END IF;

  BEGIN
    SELECT NVL(miniload_storage_ind, 'N'), zone_id, split_zone_id
    INTO sInd, sZone, sSplitZone
    FROM pm
    WHERE prod_id = psItem
    AND   cust_pref_vendor = psCpv;

    IF sInd = 'N' THEN
      -- The item shouldn't be in the Mini-load system
      RETURN '-2';
    END IF;

    IF piUom = 1 THEN
      IF sSplitZone IS NOT NULL THEN
        RETURN TO_CHAR(piUom) || sSplitZone;
      ELSE
        RETURN NULL;
      END IF;
    ELSE
      IF piSplitZoneOnly = 0 THEN
        IF sZone IS NOT NULL THEN
          RETURN '2' || sZone;
        ELSE
          RETURN NULL;
        END IF;
      ELSE
        -- piSplitZoneOnly >= 1
        IF sSplitZone IS NOT NULL THEN
          RETURN '1' || sSplitZone;
        ELSE
          IF piSplitZoneOnly > 1 THEN
            -- No split zone is found but user can accept case zone if available
            IF sZone IS NOT NULL THEN
              RETURN '2' || sZone;
            ELSE
              RETURN NULL;
            END IF;
          ELSE
            -- No split zone is found and user need only the split zone
            RETURN NULL;
          END IF;
        END IF;
      END IF;
    END IF;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RAISE;
  END;

EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;

-- =============================================================================
FUNCTION f_get_miniload_ind(
  	psProdID			IN	pm.prod_id%TYPE,
  	psCPV    			IN	pm.cust_pref_vendor%TYPE)
RETURN pm.miniload_storage_ind%TYPE IS
  sMlInd	pm.miniload_storage_ind%TYPE := 'N';
BEGIN
  SELECT NVL(miniload_storage_ind, 'N') INTO sMlInd
  FROM	pm p
  WHERE	p.prod_id = psProdID
  AND	p.cust_pref_vendor = psCPV;

  RETURN sMlInd;

EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;

-- =============================================================================
FUNCTION f_check_ml_exp_receipt_sent(
	psLP			IN miniload_message.expected_receipt_id%TYPE)
RETURN NUMBER IS
  iStatus	NUMBER := 0;
BEGIN
  SELECT 1 INTO iStatus
  FROM miniload_message
  WHERE expected_receipt_id = psLP
  AND   message_type =pl_miniload_processing.CT_EXP_REC
  AND   status = 'S'
  AND   ROWNUM = 1
  ORDER BY add_date
  FOR UPDATE NOWAIT;

  RETURN iStatus;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 0;
  WHEN OTHERS THEN
    RETURN SQLCODE;
END;

-- =============================================================================
FUNCTION f_get_pkg_error_str(piCode	IN NUMBER)
RETURN VARCHAR2 IS
  sStr		VARCHAR2(50) := NULL;
BEGIN
  FOR i IN 1 .. gtabTypPkgErrors.COUNT LOOP
    IF gtabTypPkgErrors(i).iErrorCode = piCode THEN
      sStr := gtabTypPkgErrors(i).sErrorStr;
    END IF;
    EXIT WHEN sStr IS NOT NULL;
  END LOOP;

  RETURN sStr;
END;

-- =============================================================================
PROCEDURE get_induction_loc(
  	psProdID			IN	pm.prod_id%TYPE,
  	psCPV    			IN	pm.cust_pref_vendor%TYPE,
  	piUOM 				IN  	uom.uom%TYPE,
 	piStatus			OUT	NUMBER,  
  	psInductionLoc			OUT	zone.induction_loc%TYPE) IS
BEGIN
  piStatus := C_NORMAL;

  SELECT induction_loc INTO psInductionLoc  
  FROM   pm p, zone z
  WHERE  p.prod_id = psProdID 
  AND    p.cust_pref_vendor = psCPV 
  AND    z.zone_id = DECODE(piUOM, 1, p.split_zone_id, p.zone_id)
  AND    z.rule_id = C_ML_RULEID; 

EXCEPTION
  WHEN NO_DATA_FOUND THEN 
    piStatus := C_NO_DATA_FOUND;
    psInductionLoc := ' ';
  WHEN OTHERS THEN
    piStatus := SQLCODE;
    psInductionLoc := ' ';
END;

-- =============================================================================
PROCEDURE get_outbound_loc(
  	psProdID			IN	pm.prod_id%TYPE,
  	psCPV    			IN	pm.cust_pref_vendor%TYPE,
  	piUOM 				IN  	uom.uom%TYPE,
 	piStatus			OUT	NUMBER,  
  	psOutboundLoc			OUT	zone.outbound_loc%TYPE) IS
BEGIN
  piStatus := C_NORMAL;

  SELECT outbound_loc INTO psOutboundLoc  
  FROM   pm p, zone z
  WHERE  p.prod_id = psProdID 
  AND    p.cust_pref_vendor = psCPV 
  AND    z.zone_id = DECODE(piUOM, 1, p.split_zone_id, p.zone_id)
  AND    z.rule_id = C_ML_RULEID; 

EXCEPTION
  WHEN NO_DATA_FOUND THEN 
    piStatus := C_NO_DATA_FOUND;
    psOutboundLoc := ' ';
  WHEN OTHERS THEN
    piStatus := SQLCODE;
    psOutboundLoc := ' ';
END;

-- =============================================================================
PROCEDURE get_mls_zones(
  	psLoc				IN	loc.logi_loc%TYPE,
	psItem				IN	pm.prod_id%TYPE,
	psCpv				IN	pm.cust_pref_vendor%TYPE,
	posCaseZone			OUT	pm.zone_id%TYPE,
	posSplitZone			OUT	pm.split_zone_id%TYPE,
	poiStatus			OUT	NUMBER) IS
  sInd			pm.miniload_storage_ind%TYPE := NULL;
  sZone			pm.zone_id%TYPE := NULL;
  sSplitZone		pm.split_zone_id%TYPE := NULL;
BEGIN
  poiStatus := C_NORMAL;
  posCaseZone := NULL;
  posSplitZone := NULL;

  -- Check if the location is a Mini-load slot
  IF psLoc IS NOT NULL AND f_is_mls_loc(psLoc) = 'N' THEN
    poiStatus := -1; 
    RETURN;
  END IF;

  get_mls_zones(psItem, psCpv, posCaseZone, posSplitZone, poiStatus);

EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;

-- =============================================================================
PROCEDURE get_mls_zones(
	psItem				IN	pm.prod_id%TYPE,
	psCpv				IN	pm.cust_pref_vendor%TYPE,
	posCaseZone			OUT	pm.zone_id%TYPE,
	posSplitZone			OUT	pm.split_zone_id%TYPE,
	poiStatus			OUT	NUMBER) IS
  sInd			pm.miniload_storage_ind%TYPE := NULL;
  sZone			pm.zone_id%TYPE := NULL;
  sSplitZone		pm.split_zone_id%TYPE := NULL;
BEGIN
  poiStatus := C_NORMAL;
  posCaseZone := NULL;
  posSplitZone := NULL;

  BEGIN
    SELECT NVL(miniload_storage_ind, 'N'), zone_id, split_zone_id
    INTO sInd, sZone, sSplitZone
    FROM pm
    WHERE prod_id = psItem
    AND   cust_pref_vendor = psCpv;

    IF sInd = 'N' THEN
      -- The item shouldn't be in the Mini-load system
      poiStatus := -2; 
      RETURN;
    END IF;

    posCaseZone := sZone;
    posSplitZone := sSplitZone;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      poiStatus := -3; 
      RETURN;
    WHEN OTHERS THEN
      RAISE;
  END;

EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;

-- =============================================================================
PROCEDURE validate_loc(
  	psProdID			IN	pm.prod_id%TYPE,
  	psCPV    			IN	pm.cust_pref_vendor%TYPE,
  	psLoc    			IN	loc.logi_loc%TYPE,
  	psPalletID   			IN	inv.logi_loc%TYPE,
  	posLocType			OUT	VARCHAR2,
  	posCFLoc			OUT	loc.logi_loc%TYPE,
 	posMsgType			OUT	VARCHAR2,
 	poiStatus			OUT	NUMBER,
  	posErrMsg			OUT	VARCHAR2,
  	piUOM 				IN  	uom.uom%TYPE DEFAULT 0,
	piChkExistedInv		IN	NUMBER DEFAULT 0) IS
  sLocItem		loc.prod_id%TYPE := NULL;
  sLocCpv		loc.cust_pref_vendor%TYPE := NULL;
  iLocUom		loc.uom%TYPE := NULL;
  sLocStatus		loc.status%TYPE := NULL;
  sPerm			loc.perm%TYPE := NULL;
  iRank			loc.rank%TYPE := NULL;
  sLocZone		zone.zone_id%TYPE := NULL;
  iLocRule		zone.rule_id%TYPE := NULL;
  sMLInductLoc		zone.induction_loc%TYPE := NULL;
  sLocWhsID		zone.warehouse_id%TYPE := NULL;
  sCFLoc		loc.logi_loc%TYPE := NULL;
  iExists		NUMBER := 0;
  sPutInvStatus		putawaylst.inv_status%TYPE := NULL;
  sParPalletID		putawaylst.parent_pallet_id%TYPE := NULL;
  sPutWhsID		zone.warehouse_id%TYPE := NULL;
  sTransNewStatus	trans.new_status%TYPE := NULL;
  sTransWhsID		zone.warehouse_id%TYPE := NULL;
  sPMZone		pm.zone_id%TYPE := NULL;
  sPMSplitZone		pm.split_zone_id%TYPE := NULL;
  sLastLoc		pm.last_ship_slot%TYPE := NULL;
  sPMMLInd		pm.miniload_storage_ind%TYPE := NULL;
  sFifoTrk		pm.fifo_trk%TYPE := NULL;
  sSplitTrk		pm.split_trk%TYPE := NULL;
  iPMZoneRule		zone.rule_id%TYPE := NULL;
  iPMSplitZoneRule	zone.rule_id%TYPE := NULL;
  sIsMSKU		VARCHAR2(1) := 'N';
  iIsAgingItem		NUMBER := 0;
BEGIN
  posLocType := 'X';
  posCFLoc := NULL;
  posMsgType := 'F';
  poiStatus := C_NORMAL;
  posErrMsg := NULL;

  -- Check if location exists in the LOC table 
  BEGIN
    SELECT l.prod_id, l.cust_pref_vendor, l.uom, l.status, NVL(l.perm, 'N'),
           l.rank, z.zone_id, z.rule_id, z.induction_loc, z.warehouse_id
    INTO sLocItem, sLocCpv, iLocUom, sLocStatus, sPerm, iRank,
         sLocZone, iLocRule, sMLInductLoc, sLocWhsID
    FROM loc l, zone z, lzone lz
    WHERE l.logi_loc = psLoc
    AND   z.zone_id = lz.zone_id
    AND   z.zone_type = 'PUT'
    AND   lz.logi_loc = l.logi_loc;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      poiStatus := C_INV_LOCATION;
      posErrMsg := 'Location ' || psLoc || ' doesn''t exist';
      RETURN;
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      posErrMsg := SUBSTR(SQLERRM, 1, 70);
      RETURN;
  END;
  DBMS_OUTPUT.PUT_LINE('Loc p: ' || sLocItem || '/' || sLocCpv || ', u: ' ||
    TO_CHAR(iLocUom) || ', sta: ' || sLocStatus || ', pe: ' || sPerm ||
    ', rk: ' || TO_CHAR(iRank) || ', z/rl: ' || sLocZone || '/' || 
    TO_CHAR(iLocRule) || ', ind: ' || sMLInductLoc || ', w: ' || sLocWhsID);

  -- Entered location is a back location. Set the output flag and return the
  -- front location to the caller
  IF sLocStatus = 'BCK' THEN
    posLocType := 'B';
    sCFLoc := pl_pflow.f_get_pick_loc(psLoc);
    IF sCFLoc != 'NONE' THEN
      posCFLoc := sCFLoc;
    END IF;
  END IF;

  IF sLocStatus NOT IN ('AVL', 'BCK') THEN
    poiStatus := C_LOC_DAMAGED;
    posErrMsg := 'Location ' || psLoc || ' is not available for use due to ' ||
      'damaged';
    RETURN;
  END IF;

  IF sLocStatus <> 'BCK' THEN
    -- Enter location probably is a front location or a regular location. If
    -- back location is available, return it to the caller
    sCFLoc := pl_pflow.f_get_back_loc(psLoc);
    IF sCFLoc != 'NONE' THEN
      posLocType := 'F';
      posCFLoc := sCFLoc;
    END IF;
  END IF;

  DBMS_OUTPUT.PUT_LINE('CFLoc: ' || sCFLoc);

  IF (sLocItem || sLocCpv) IS NOT NULL AND
     ((psProdID || psCPV) <> (sLocItem || sLocCpv)) THEN
    poiStatus := C_INV_LOCATION;
    posErrMsg := 'Location ' || psLoc || ' already had item ' || sLocItem ||
      '/' || sLocCpv || ' in it';
    RETURN;
  END IF;

  IF NVL(piUom, 0) = 1 AND NVL(iLocUom, 0) = 2 THEN
    poiStatus := C_INV_LOCATION;
    posErrMsg := 'Location ' || psLoc || ' is a case home slot but checking ' ||
      'uom is in splits';
    RETURN;
  END IF;

  IF NVL(piUom, 0) = 2 AND NVL(iLocUom, 0) = 1 THEN
    poiStatus := C_INV_LOCATION;
    posErrMsg := 'Location ' || psLoc || ' is a split home slot but ' ||
      'checking uom is in cases';
    RETURN;
  END IF;

  IF NVL(sPerm, 'N') = 'N' AND iLocRule <> 3 THEN
    iExists := 0;
    BEGIN
      SELECT 1 INTO iExists
      FROM inv
      WHERE plogi_loc = psLoc
      AND   logi_loc = psPalletID;

      IF piChkExistedInv = 1 THEN
        poiStatus := C_INV_LOCATION;
        posErrMsg := 'Inventory already existed for location ' || psLoc ||
          '/' || psPalletID;
        RETURN;
      END IF;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        posErrMsg := SUBSTR(SQLERRM, 1, 70);
        RETURN;
    END;
  ELSE
    iExists := 0;
    BEGIN
      SELECT 1 INTO iExists
      FROM inv i
      WHERE EXISTS (SELECT logi_loc
                    FROM loc
                    WHERE prod_id = psProdID
                    AND   cust_pref_vendor = psCPV
                    AND   perm = 'Y')
      AND   ROWNUM = 1;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        iExists := 0;
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        posErrMsg := SUBSTR(SQLERRM, 1, 70);
        RETURN;
    END;
  END IF;
  DBMS_OUTPUT.PUT_LINE('After checking inv for pallet/item: ' ||
    TO_CHAR(iExists));

  IF NVL(sPerm, 'N') = 'Y' THEN
    BEGIN
      SELECT 1 INTO iIsAgingItem
      FROM aging_items
      WHERE prod_id = psProdID
      AND   cust_pref_vendor = psCpv;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        iIsAgingItem := 0;
      WHEN TOO_MANY_ROWS THEN
        iIsAgingItem := 1;
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        posErrMsg := SUBSTR(SQLERRM, 1, 70);
        RETURN;
    END;
    DBMS_OUTPUT.PUT_LINE('After checking for aging item status: ' ||
      TO_CHAR(iIsAgingItem));
    IF iIsAgingItem = 1 THEN
      poiStatus := C_INV_LOCATION;
      posErrMsg := 'Pallet ' || psPalletID || ' should be aged. Cannot be ' ||
        'in home slot';
      RETURN;
    END IF;
  END IF;

  BEGIN
    SELECT pt.inv_status, pt.parent_pallet_id, z.warehouse_id
    INTO sPutInvStatus, sParPalletID, sPutWhsID
    FROM putawaylst pt, zone z, lzone lz
    WHERE pt.pallet_id = psPalletID
    AND   z.zone_id = lz.zone_id
    AND   z.zone_type = 'PUT'
    AND   lz.logi_loc = pt.dest_loc;

    IF sPerm = 'Y' AND sPutInvStatus = 'HLD' THEN
      poiStatus := C_INV_LOCATION;
      posErrMsg := 'Pallet ' || psPalletID || ' is on hold. Cannot go to ' ||
        'home slot';
      RETURN;
    END IF;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      sPutInvStatus := NULL;
      sParPalletID := NULL;
      sPutWhsID := NULL;
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      posErrMsg := SUBSTR(SQLERRM, 1, 70);
      RETURN;
  END;
  IF sParPalletID IS NULL THEN
    BEGIN
      SELECT parent_pallet_id, new_status, warehouse_id
      INTO sParPalletID, sTransNewStatus, sTransWhsID
      FROM trans
      WHERE trans_type = 'PUT'
      AND   pallet_id = psPalletID;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        sParPalletID := NULL;
        sTransNewStatus := 'AVL';
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        posErrMsg := SUBSTR(SQLERRM, 1, 70);
        RETURN;
    END;
  END IF;
  IF sPutInvStatus IS NULL THEN
    sPutInvStatus := sTransNewStatus;
  END IF;
  IF sPutWhsID IS NULL THEN
    sPutWhsID := sTransWhsID;
  END IF;
  DBMS_OUTPUT.PUT_LINE('Put sta: ' || sPutInvStatus || ', w: ' || sPutWhsID ||
    ', par: ' || sParPalletID);

  IF sPerm = 'Y' AND iRank > 1 THEN
    poiStatus := C_INV_LOCATION;
    posErrMsg := 'Cannot go to home slot with rank greater than 1';
    RETURN;
  END IF;

  IF sPutInvStatus = 'OUT' AND sLocWhsID <> sPutWhsID THEN
    poiStatus := C_INV_LOCATION;
    posErrMsg := 'Outside storage warehouse should be in ' || sPutWhsID ||
      ', not ' || sLocWhsID;
    RETURN;
  END IF;

  BEGIN
    SELECT zone_id, split_zone_id, last_ship_slot,
           NVL(miniload_storage_ind, 'N'), NVL(fifo_trk, 'N'),
           NVL(split_trk, 'N')
    INTO sPMZone, sPMSplitZone, sLastLoc, sPMMLInd, sFifoTrk, sSplitTrk
    FROM pm
    WHERE prod_id = psProdID
    AND   cust_pref_vendor = psCPV;

    IF sPMZone IS NOT NULL THEN
      BEGIN
        SELECT rule_id INTO iPMZoneRule
        FROM zone z
        WHERE zone_type = 'PUT'
        AND   zone_id = sPMZone;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          iPMZoneRule := NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          posErrMsg := SUBSTR(SQLERRM, 1, 70);
          RETURN;
      END;
    END IF;

    IF sPMSplitZone IS NOT NULL THEN
      BEGIN
        SELECT rule_id INTO iPMSplitZoneRule
        FROM zone z
        WHERE zone_type = 'PUT'
        AND   zone_id = sPMSplitZone;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          iPMSplitZoneRule := NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          posErrMsg := SUBSTR(SQLERRM, 1, 70);
          RETURN;
      END;
    END IF;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      poiStatus := C_INV_PRODID;
      posErrMsg := 'Item ' || psProdID || '/' || psCPV || ' doesn''t exist ' ||
        'in the system';
      RETURN;
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      posErrMsg := SUBSTR(SQLERRM, 1, 70);
      RETURN;
  END;
  DBMS_OUTPUT.PUT_LINE('PM zone/r: ' || sPMZone || '/' ||
    TO_CHAR(iPMZoneRule) ||', szone/r: ' || sPMSplitZone || '/' ||
    TO_CHAR(iPMSplitZoneRule) ||
    ', lastloc: ' || sLastLoc || ', ind: ' || sPMMLInd || ', fifo: ' ||
    sFifoTrk || ', split: ' || sSplitTrk);

  IF sPerm = 'Y' AND iPMZoneRule = 1 THEN
    poiStatus := C_INV_LOCATION;
    posErrMsg := 'Location ' || psLoc || ' is a home slot but item is in ' ||
      'floating zone';
    RETURN;
  END IF;

  IF sPerm = 'Y' AND sFifoTrk IN ('A', 'S') THEN
    poiStatus := C_INV_LOCATION;
    posErrMsg := 'Item is FIFO tracked and cannot go to home slot';
    RETURN;
  END IF;

  IF iLocRule = 1 AND iExists = 1 THEN
    poiStatus := C_INV_LOCATION;
    posErrMsg := 'Location ' || psLoc || ' is a floating slot but item ' ||
      psProdID || '/' || psCPV || ' has a home slot';
    RETURN;
  END IF;

  IF iLocRule = 1 AND iPMZoneRule IS NULL THEN
    poiStatus := C_INV_LOCATION;
    posErrMsg := 'Floating location ' || psLoc ||
      ' doesn''t have a zone set up';
    RETURN;
  END IF;

  IF sPMMLInd IN ('S', 'B') AND
     ((iLocRule IS NULL) OR (iLocRule <> C_ML_RULEID)) THEN
    IF sPMMLInd = 'B' THEN
      posErrMsg := 'Item ' || psProdID || '/' || psCPV ||
        ' can only be resided in the Mini-load system';
    ELSE
      IF piUom = 1 THEN
        posErrMsg := 'Item ' || psProdID || '/' || psCPV ||
        ' can only content splits in the Mini-load system';
      END IF;
    END IF;
    poiStatus := C_INV_LOCATION;
    RETURN;
  END IF;

  IF iLocRule = C_ML_RULEID THEN
    IF sPMMLInd = 'N' THEN
      poiStatus := C_INV_LOCATION;
      posErrMsg := 'Location ' || psLoc || ' is a Mini-load slot but item ' ||
        'can only be in the main warehouse';
      RETURN;
    END IF;
    IF sPMMLInd = 'S' AND NVL(piUom, 0) = 2 THEN
      poiStatus := C_INV_LOCATION;
      posErrMsg := 'Item can only accept splits in its Mini-load location ' ||
        psLoc; 
      RETURN;
    END IF;
    IF sPMMLInd = 'S' AND sPMSplitZone IS NULL THEN
      poiStatus := C_INV_LOCATION;
      posErrMsg := 'Mini-load slot has no split zone set up';
      RETURN;
    END IF;
    IF sPMMLInd = 'B' AND sSplitTrk = 'N' AND sPMZone IS NULL THEN
      poiStatus := C_INV_LOCATION;
      posErrMsg := 'Mini-load slot has no case zone set up';
      RETURN;
    END IF;
    IF sPMMLInd = 'B' AND
       sSplitTrk = 'Y' AND
       (sPMZone IS NULL OR sPMSplitZone IS NULL) THEN
      poiStatus := C_INV_LOCATION;
      posErrMsg := 'Mini-load slot has no case zone AND/OR split zone set up';
      RETURN;
    END IF;
    IF psLoc = sMLInductLoc THEN
      -- Enter location is a Mini-load induction location. Check to see if the
      -- pallet is in inventory
      iExists := 0;
      BEGIN
        SELECT 1 INTO iExists
        FROM inv
        WHERE prod_id = psProdID
        AND   cust_pref_vendor = psCPV
        AND   plogi_loc = psLoc
        AND   logi_loc = psPalletID;

        -- The pallet hasn't been inducted into Mini-load system yet. Do nothng.
        -- The caller might be able to used the location.
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          -- The pallet might have been inducted into the Mini-load system.
          posMsgType := 'W';
          posLocType := posLocType || 'I';	-- It's an induction location
          poiStatus := C_ML_INV_NOT_EXISTS;
          posErrMsg := psPalletID || '/' || psProdID || '/' || psCPV ||
            CHR(10) || ' might have been inducted to the Mini-load system';
          RETURN;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          posErrMsg := SUBSTR(SQLERRM, 1, 70);
          RETURN;
      END;
    END IF;
  END IF;

  IF pl_msku.f_is_msku_pallet(psPalletID, 'P') THEN
    sIsMSKU := 'Y';
    iExists := 0;
    BEGIN
      SELECT 1 INTO iExists
      FROM inv
      WHERE plogi_loc = psLoc
      AND   parent_pallet_id IS NOT NULL
      AND   ROWNUM = 1;
  
      poiStatus := C_INV_LOCATION;
      posErrMsg := 'MSKU pallet(s) exist(s) in location ' || psLoc;
      RETURN;
  
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        posErrMsg := SUBSTR(SQLERRM, 1, 70);
        RETURN;
    END;
    iExists := 0;
    BEGIN
      SELECT 1 INTO iExists
      FROM inv i, pm p
      WHERE i.plogi_loc = psLoc
      AND   i.prod_id = p.prod_id
      AND   i.cust_pref_vendor = p.cust_pref_vendor
      AND   (i.qoh + i.qty_planned) = (p.ti * p.hi * p.spc)
      AND   ROWNUM = 1;
  
      poiStatus := C_INV_LOCATION;
      posErrMsg := 'Full MSKU pallet(s) exist(s) in location ' || psLoc;
      RETURN;
  
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        posErrMsg := SUBSTR(SQLERRM, 1, 70);
        RETURN;
    END;
    iExists := 0;
    BEGIN
      SELECT 1 INTO iExists
      FROM loc l, slot_type s
      WHERE l.logi_loc = psLoc
      AND   l.slot_type = s.slot_type
      AND   s.deep_ind = 'Y';
  
      poiStatus := C_INV_LOCATION;
      posErrMsg := 'MSKU pallet(s) is/are not allowed in deep slots';
      RETURN;
  
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        posErrMsg := SUBSTR(SQLERRM, 1, 70);
        RETURN;
    END;
    IF sParPalletID IS NOT NULL THEN
      iExists := 0;
      BEGIN
        SELECT 1 INTO iExists
        FROM putawaylst
        WHERE parent_pallet_id = sParPalletID
        AND   dest_loc <> '*'
        AND   ROWNUM = 1;

        poiStatus := C_INV_LOCATION;
        posErrMsg := 'A slot already identified for the MSKU pallet';
        RETURN;

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          BEGIN
            SELECT 1 INTO iExists
            FROM trans
            WHERE parent_pallet_id = sParPalletID
            AND   trans_type = 'PUT'
            AND   dest_loc <> '*'
            AND   ROWNUM = 1;

            poiStatus := C_INV_LOCATION;
            posErrMsg := 'A slot already identified for the MSKU pallet';
            RETURN;

          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              NULL;
            WHEN OTHERS THEN
              poiStatus := SQLCODE;
              posErrMsg := SUBSTR(SQLERRM, 1, 70);
              RETURN;
          END;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          posErrMsg := SUBSTR(SQLERRM, 1, 70);
          RETURN;
      END;
    END IF;
  END IF;

  IF iLocRule = 0 THEN
    -- Location is a reserved slot
    iExists := 0;
    BEGIN
      SELECT 1 INTO iExists
      FROM inv i
      WHERE EXISTS (SELECT 1
                    FROM loc
                    WHERE prod_id = psProdID
                    AND   cust_pref_vendor = psCPV
                    AND   perm = 'Y');

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        posMsgType := 'W';
        poiStatus := C_HOME_SLOT_UNVAL;
        posErrMsg :=
          'Item is not slotted yet but location is a home/reserved slot.';
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        posErrMsg := SUBSTR(SQLERRM, 1, 70);
        RETURN;
    END;
  END IF;
  DBMS_OUTPUT.PUT_LINE('After checking rule=0 perm=N: ' || TO_CHAR(iExists) ||
    ', msgtype: ' || posMsgType);

  -- Set the location type flag
  IF sPerm = 'Y' THEN
    posLocType := posLocType || 'H';
  ELSE
    IF iLocRule = 0 THEN
      IF sLocWhsID <> '000' THEN
        posLocType := posLocType || 'O';
      ELSE
        posLocType := posLocType || 'R';
      END IF;
    ELSIF iLocRule = 1 THEN
      posLocType := posLocType || 'F';
    ELSIF iLocRule = 2 THEN
      posLocType := posLocType || 'B';
    ELSIF iLocRule = 3 THEN
      IF f_is_induction_loc(psloc) = 'Y' THEN
        posLocType := posLocType || 'I';
      ELSE
        posLocType := posLocType || 'L';
      END IF;
    ELSE
      posLocType := posLocType || 'X';
    END IF;
  END IF;
  posLocType := posLocType || sIsMSKU;

  IF posMsgType <> 'W' THEN
    posMsgType := 'I';
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
    posErrMsg := SUBSTR(SQLERRM, 1, 70);
    RAISE;
END;

-- =============================================================================
PROCEDURE set_pkg_error_info IS
BEGIN
  gtabTypPkgErrors(1).iErrorCode := C_INV_LOCATION;
  gtabTypPkgErrors(1).sErrorStr := 'C_INV_LOCATION';
  gtabTypPkgErrors(2).iErrorCode := C_INV_PRODID;
  gtabTypPkgErrors(2).sErrorStr := 'C_INV_PRODID';
  gtabTypPkgErrors(3).iErrorCode := C_HOME_SLOT_UNVAL;
  gtabTypPkgErrors(3).sErrorStr := 'C_HOME_SLOT_UNVAL';
  gtabTypPkgErrors(4).iErrorCode := C_LOC_DAMAGED;
  gtabTypPkgErrors(4).sErrorStr := 'C_LOC_DAMAGED';
  gtabTypPkgErrors(5).iErrorCode := C_ML_INV_NOT_EXISTS;
  gtabTypPkgErrors(5).sErrorStr := 'C_ML_INV_NOT_EXISTS';
  gtabTypPkgErrors(6).iErrorCode := C_ML_NOT_ML_SLOT;
  gtabTypPkgErrors(6).sErrorStr := 'C_ML_NOT_ML_SLOT';
  gtabTypPkgErrors(7).iErrorCode := C_ML_NO_CC_EXC;
  gtabTypPkgErrors(7).sErrorStr := 'C_ML_NO_CC_EXC';
END;

-- =============================================================================
PROCEDURE handle_cc_ml_loc_changes(
	poiStatus	OUT NUMBER,
	posUpdLoc	OUT inv.plogi_loc%TYPE,
	psSearch	IN  VARCHAR2 DEFAULT 'ALL',
	psLP		IN  inv.logi_loc%TYPE DEFAULT NULL,
	piAdjustMode	IN  NUMBER DEFAULT 0,
	piUpdateAlso	IN  NUMBER DEFAULT 1) IS
  sObjectName	     VARCHAR2(100) := 'pl_ml_common.handle_cc_ml_loc_changes';
  iInvAdjIncrCnt	NUMBER := 0;
  iTransID		trans.trans_id%TYPE := NULL;

  CURSOR c_get_cc_ml_recs IS
    SELECT c.phys_loc, c.logi_loc, c.prod_id, c.cust_pref_vendor, c.type,
           c.batch_no, c.status, c.cc_reason_code, c.group_no, c.group_sort,
           c.cc_gen_date, c.upd_date, p.spc
    FROM cc c, loc l, zone z, lzone lz, pm p
    WHERE c.phys_loc = l.logi_loc
    AND   c.prod_id IS NOT NULL
    AND   l.logi_loc = lz.logi_loc
    AND   z.zone_id = lz.zone_id
    AND   z.zone_type = 'PUT'
    AND   z.rule_id = C_ML_RULEID
    AND   c.prod_id = p.prod_id
    AND   c.cust_pref_vendor = p.cust_pref_vendor
    AND   ((psSearch = 'ALL') OR
           ((psSearch = 'ONE') AND (c.logi_loc = psLP)) OR
           (psSearch NOT IN ('ALL', 'ONE') AND
            (((piAdjustMode = 0) AND (TO_CHAR(c.cc_gen_date) = psSearch)) OR
             ((piAdjustMode <> 0) AND (c.group_no = TO_NUMBER(psSearch))))))
    AND   EXISTS (SELECT 1
                  FROM miniload_message
                  WHERE prod_id = c.prod_id
                  AND   cust_pref_vendor = c.cust_pref_vendor
                  AND   (((message_type =
                              pl_miniload_processing.CT_INV_ADJ_INC) AND
                          (expected_receipt_id = c.logi_loc)) OR
                         ((message_type =
                              pl_miniload_processing.CT_INV_ARR) AND
                          (carrier_id = c.logi_loc)))
                  AND   status = 'S'
                  AND   NVL(add_date, SYSDATE) >=
                          NVL(c.upd_date, c.cc_gen_date));

  CURSOR c_get_mm_recs(cpiType    NUMBER,
                       cpsItem    inv.prod_id%TYPE,
                       cpsCpv     inv.cust_pref_vendor%TYPE,
                       cpsPallet  inv.logi_loc%TYPE,
                       cpdUpdDate DATE,
                       cpdAddDate DATE) IS
    SELECT uom, qty_received, carrier_id, inv_date, dest_loc,
           expected_receipt_id
    FROM miniload_message
    WHERE prod_id = cpsItem
    AND   cust_pref_vendor = cpsCpv
    AND   status = 'S'
    AND   (((cpiType = 1) AND
            (message_type = pl_miniload_processing.CT_INV_ADJ_INC AND
            (expected_receipt_id = cpsPallet))
           OR
           ((cpiType = 2) AND
            (message_type = pl_miniload_processing.CT_INV_ARR) AND
            (carrier_id = cpsPallet))))
    AND   NVL(add_date, SYSDATE) >= NVL(cpdUpdDate, cpdAddDate)
    ORDER BY add_date;

  CURSOR c_get_cc_edit_ml_recs IS
    SELECT c.trans_id, c.group_no, c.prod_id, c.cust_pref_vendor,
           c.phys_loc, c.logi_loc, c.reason_code, c.cc_gen_date,
           c.add_date, c.upd_date, p.spc, c.adj_flag, c.old_qty, c.gen_user_id
    FROM cc_edit c, loc l, zone z, lzone lz, pm p
    WHERE c.phys_loc = l.logi_loc
    AND   c.prod_id IS NOT NULL
    AND   l.logi_loc = lz.logi_loc
    AND   z.zone_id = lz.zone_id
    AND   z.zone_type = 'PUT'
    AND   z.rule_id = C_ML_RULEID
    AND   c.prod_id = p.prod_id
    AND   c.cust_pref_vendor = p.cust_pref_vendor
    AND   ((psSearch = 'ALL') OR
           ((psSearch = 'ONE') AND (c.logi_loc = psLP)) OR
           (psSearch NOT IN ('ALL', 'ONE') AND
            (((piAdjustMode = 0) AND (TO_CHAR(c.add_date) = psSearch)) OR
             ((piAdjustMode <> 0) AND (c.group_no = TO_NUMBER(psSearch))))))
    AND   c.prod_id = p.prod_id
    AND   c.cust_pref_vendor = p.cust_pref_vendor
    AND   c.adj_flag = 'Y'
    AND   EXISTS (SELECT 1
                  FROM miniload_message
                  WHERE prod_id = c.prod_id
                  AND   cust_pref_vendor = c.cust_pref_vendor
                  AND   (((message_type =
                              pl_miniload_processing.CT_INV_ADJ_INC) AND
                          (expected_receipt_id = c.logi_loc)) OR
                         ((message_type =
                              pl_miniload_processing.CT_INV_ARR) AND
                          (carrier_id = c.logi_loc)))
                  AND   status = 'S'
                  AND   NVL(add_date, SYSDATE) >=
                          NVL(c.upd_date, c.add_date));
BEGIN
  poiStatus := C_NORMAL;
  posUpdLoc := NULL;

  FOR cgcmr IN c_get_cc_ml_recs LOOP
    -- For each found cycle count task that has Mini-load slot and it's
    -- inventory loc or LP hasn't been changed but an inventory change message
    -- has been sent from Mini-load system ...

    -- Caller want to query only to see if any Mini-load slot location got
    -- changed so we shouldn't do any update or create
    IF piUpdateAlso <> 1 THEN
      poiStatus := 2;
      EXIT;
    END IF;

    FOR cgmr IN c_get_mm_recs(1, cgcmr.prod_id, cgcmr.cust_pref_vendor,
                              cgcmr.logi_loc,
                              cgcmr.upd_date, cgcmr.cc_gen_date) LOOP
      -- For each cycle task LP that has successfully perform inventory carrier
      -- update to SWMS ...
      IF iInvAdjIncrCnt = 0 THEN
        -- 1st found carrier. Since we have the CC table record, update info
        BEGIN
          UPDATE cc
             SET logi_loc = cgmr.carrier_id
           WHERE logi_loc = cgcmr.logi_loc;

          IF SQL%ROWCOUNT > 0 THEN
            pl_log.ins_msg('INFO', sObjectName,
              'ML carrier has changed from ' || cgcmr.logi_loc || ' to ' ||
              cgmr.carrier_id || ', new q/u: ' || TO_CHAR(cgmr.qty_received) ||
              TO_CHAR(cgmr.uom) || ' for CC grp/loc/item ' ||
              TO_CHAR(cgcmr.group_no) || '/' || cgcmr.phys_loc ||
              cgcmr.prod_id || '/' || cgcmr.cust_pref_vendor ||
              ', old LP: ' || cgmr.expected_receipt_id ||
              ' due to msg InventoryAdjustmentIncrease',
              NULL, NULL);
            poiStatus := 1;
            posUpdLoc := cgcmr.phys_loc;
          END IF;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NULL;
          WHEN OTHERS THEN
            poiStatus := SQLCODE;
            RETURN;
        END;
        BEGIN
          UPDATE cc_exception_list
          SET logi_loc = cgmr.carrier_id,
              qty = cgmr.qty_received / DECODE(cgmr.uom, 1, 1, cgcmr.spc),
              uom = cgmr.uom
          WHERE logi_loc = cgcmr.logi_loc;
          IF SQL%ROWCOUNT > 0 THEN
            poiStatus := 1;
          END IF;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NULL;
          WHEN OTHERS THEN
            poiStatus := SQLCODE;
            RETURN;
        END;
      ELSE
        -- More than 1 carrier was introduced for the original LP. For each
        -- new carrier, we will add a new CC table record by reusing some info
        -- from the 1st CC table record
        BEGIN
          INSERT INTO cc
            (type, batch_no, logi_loc, phys_loc, status, prod_id, user_id,
             cc_gen_date, cc_reason_code, group_no, group_sort,
             cust_pref_vendor, qty)
          VALUES
            (cgcmr.type, cgcmr.batch_no, cgmr.carrier_id, cgcmr.phys_loc,
             cgcmr.status, cgcmr.prod_id, NULL, SYSDATE, cgcmr.cc_reason_code,
             cgcmr.group_no, cgcmr.group_sort, cgcmr.cust_pref_vendor,
             NULL);

          pl_log.ins_msg('INFO', sObjectName,
            'CC new ML loc/carrier due to msg InventoryAdjustmentIncrease' ||
            'for grp/loc/LP/item/rsn ' ||
            TO_CHAR(cgcmr.group_no) || '/' || cgcmr.phys_loc || '/' ||
            cgcmr.logi_loc || '/' || cgcmr.prod_id || '/' ||
            cgcmr.cust_pref_vendor || cgcmr.cc_reason_code ||
            ', new LP/qty/u: ' || cgmr.carrier_id || '/' ||
            TO_CHAR(cgmr.qty_received) || '/' || TO_CHAR(cgmr.uom),
            NULL, NULL);
          poiStatus := 1;
          posUpdLoc := cgcmr.phys_loc;
        EXCEPTION
          WHEN OTHERS THEN
            poiStatus := SQLCODE;
            RETURN;
        END;
        BEGIN
          INSERT INTO cc_exception_list
            (prod_id, cust_pref_vendor, phys_loc, logi_loc,
             cc_except_code, cc_except_date, qty, uom) VALUES
            (cgcmr.prod_id, cgcmr.cust_pref_vendor, cgcmr.phys_loc,
             cgmr.carrier_id, cgcmr.cc_reason_code, cgcmr.cc_gen_date,
             cgmr.qty_received / DECODE(cgmr.uom, 1, 1, cgcmr.spc), cgmr.uom);
          poiStatus := 1;
        EXCEPTION
          WHEN OTHERS THEN
            poiStatus := SQLCODE;
            RETURN;
        END;
      END IF;
    END LOOP;
  END LOOP;
  FOR cgcmr IN c_get_cc_ml_recs LOOP

    -- Caller want to query only to see if any Mini-load slot location got
    -- changed so we shouldn't do any update or create
    IF piUpdateAlso <> 1 THEN
      poiStatus := 2;
      EXIT;
    END IF;

    FOR cgmr IN c_get_mm_recs(2, cgcmr.prod_id, cgcmr.cust_pref_vendor,
                              cgcmr.logi_loc,
                              cgcmr.upd_date, cgcmr.cc_gen_date) LOOP
      -- For each cycle task LP that has successfully perform inventory
      -- location update to SWMS ...
      BEGIN
        UPDATE cc
           SET phys_loc = cgmr.dest_loc
         WHERE logi_loc = cgcmr.logi_loc;

        IF SQL%ROWCOUNT > 0 THEN
          pl_log.ins_msg('INFO', sObjectName,
            'ML loc has changed from ' || cgcmr.phys_loc || ' to ' ||
            cgmr.dest_loc || ', new q/u: ' || TO_CHAR(cgmr.qty_received) ||
            TO_CHAR(cgmr.uom) || ' for CC grp/LP/item ' ||
            TO_CHAR(cgcmr.group_no) || '/' || cgcmr.logi_loc ||
            cgcmr.prod_id || '/' || cgcmr.cust_pref_vendor ||
            ' due to msg InventoryArrival',
            NULL, NULL);
          poiStatus := 1;
          posUpdLoc := cgmr.dest_loc;
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END;
      BEGIN
        UPDATE cc_exception_list
        SET phys_loc = cgmr.dest_loc,
            qty = cgmr.qty_received / DECODE(cgmr.uom, 1, 1, cgcmr.spc),
            uom = cgmr.uom
        WHERE logi_loc = cgcmr.logi_loc;
        IF SQL%ROWCOUNT > 0 THEN
          poiStatus := 1;
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END;
    END LOOP;
  END LOOP;
  iInvAdjINcrCnt := 0;
  FOR cgcemr IN c_get_cc_edit_ml_recs LOOP
    -- For each found cycle count edit task that has Mini-load slot and it's
    -- inventory loc or LP hasn't been changed but an inventory change message
    -- has been sent from Mini-load system ...

    -- Caller want to query only to see if any Mini-load slot location got
    -- changed so we shouldn't do any update or create
    IF piUpdateAlso <> 1 THEN
      poiStatus := 2;
      EXIT;
    END IF;

    FOR cgmr IN c_get_mm_recs(1, cgcemr.prod_id, cgcemr.cust_pref_vendor,
                              cgcemr.logi_loc,
                              cgcemr.upd_date, cgcemr.cc_gen_date) LOOP
      -- For each cycle task edit LP that has successfully perform inventory
      -- carrier update to SWMS ...
      IF iInvAdjIncrCnt = 0 THEN
        -- 1st found carrier. Since we have the CC_EDIT table record,
        -- update info
        BEGIN
          UPDATE cc_edit
          SET logi_loc = cgmr.carrier_id,
              new_qty = cgmr.qty_received
          WHERE logi_loc = cgcemr.logi_loc;

          IF SQL%ROWCOUNT > 0 THEN
            pl_log.ins_msg('INFO', sObjectName,
              'ML carrier has changed from ' || cgcemr.logi_loc || ' to ' ||
              cgmr.carrier_id || ', new q/u: ' || TO_CHAR(cgmr.qty_received) ||
              TO_CHAR(cgmr.uom) || ' for CC_EDIT grp/loc/item/rsn ' ||
              TO_CHAR(cgcemr.group_no) || '/' || cgcemr.phys_loc ||
              cgcemr.prod_id || '/' || cgcemr.cust_pref_vendor || '/' ||
              cgcemr.reason_code ||
              ', old LP: ' || cgmr.expected_receipt_id ||
              ' due to msg InventoryAdjustmentIncrease',
              NULL, NULL);
            poiStatus := 1;
            posUpdLoc := cgcemr.phys_loc;
          END IF;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NULL;
          WHEN OTHERS THEN
            poiStatus := SQLCODE;
            RETURN;
        END;
        BEGIN
          UPDATE cc_exception_list
          SET logi_loc = cgmr.carrier_id,
              qty = cgmr.qty_received / DECODE(cgmr.uom, 1, 1, cgcemr.spc),
              uom = cgmr.uom
          WHERE logi_loc = cgcemr.logi_loc;
          IF SQL%ROWCOUNT > 0 THEN
            poiStatus := 1;
          END IF;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NULL;
          WHEN OTHERS THEN
            poiStatus := SQLCODE;
            RETURN;
        END;
      ELSE
        -- More than 1 carrier was introduced for the original LP. For each
        -- new carrier, we will add a new CC_EDIT table record and a new CYC
        -- transaction record by reusing some info
        -- from the 1st CC_EIDT table record
        iTransID := NULL;
        BEGIN
          SELECT trans_id_seq.nextval INTO iTransID FROM DUAL;
        EXCEPTION
          WHEN OTHERS THEN
            poiStatus := SQLCODE;
            RETURN;
        END;
        BEGIN
          INSERT INTO cc_edit
            (trans_id, group_no, prod_id, cust_pref_vendor, phys_loc, logi_loc,
             reason_code, cc_gen_date, gen_user_id, adj_flag, 
             old_qty, new_qty) VALUES
            (iTransID, cgcemr.group_no, cgcemr.prod_id, cgcemr.cust_pref_vendor,
             cgcemr.phys_loc, cgmr.carrier_id, cgcemr.reason_code,
             cgcemr.cc_gen_date, cgcemr.gen_user_id, cgcemr.adj_flag,
             0, cgmr.qty_received);

          pl_log.ins_msg('INFO', sObjectName,
            'CC_EDIT new ML loc/carrier due to msg ' ||
            'InventoryAdjustmentIncrease for grp/loc/LP/item/rsn ' ||
            TO_CHAR(cgcemr.group_no) || '/' || cgcemr.phys_loc || '/' ||
            cgcemr.logi_loc || '/' || cgcemr.prod_id || '/' ||
            cgcemr.cust_pref_vendor || cgcemr.reason_code ||
            ', new LP/qty/u: ' || cgmr.carrier_id || '/' ||
            TO_CHAR(cgmr.qty_received) || '/' || TO_CHAR(cgmr.uom),
            NULL, NULL);
          poiStatus := 1;
          posUpdLoc := cgcemr.phys_loc;
        EXCEPTION
          WHEN OTHERS THEN
            poiStatus := SQLCODE;
            RETURN;
        END;
        BEGIN
          INSERT INTO trans
            (trans_id, trans_type, trans_date, prod_id, mfg_date,
             qty_expected, qty, uom, src_loc, user_id, reason_code,
             adj_flag, pallet_id, batch_no, cust_pref_vendor)
          VALUES
            (iTransID, 'CYC', SYSDATE, cgcemr.prod_id, cgcemr.cc_gen_date,
             0, cgmr.qty_received, cgmr.uom, cgcemr.phys_loc, USER,
             cgcemr.reason_code, cgcemr.adj_flag, cgmr.carrier_id,
             TO_CHAR(cgcemr.group_no), cgcemr.cust_pref_vendor);
        EXCEPTION
          WHEN OTHERS THEN
            poiStatus := SQLCODE;
            RETURN;
        END;
        BEGIN
          INSERT INTO cc_exception_list
            (prod_id, cust_pref_vendor, phys_loc, logi_loc,
             cc_except_code, cc_except_date, qty, uom) VALUES
            (cgcemr.prod_id, cgcemr.cust_pref_vendor, cgcemr.phys_loc,
             cgmr.carrier_id, cgcemr.reason_code, cgcemr.cc_gen_date,
             cgmr.qty_received / DECODE(cgmr.uom, 1, 1, cgcemr.spc), cgmr.uom);
        EXCEPTION
          WHEN OTHERS THEN
            poiStatus := SQLCODE;
            RETURN;
        END;
      END IF;
    END LOOP;
  END LOOP;
  FOR cgcemr IN c_get_cc_edit_ml_recs LOOP

    -- Caller want to query only to see if any Mini-load slot location got
    -- changed so we shouldn't do any update or create
    IF piUpdateAlso <> 1 THEN
      poiStatus := 2;
      EXIT;
    END IF;

    FOR cgmr IN c_get_mm_recs(2, cgcemr.prod_id, cgcemr.cust_pref_vendor,
                              cgcemr.logi_loc,
                              cgcemr.upd_date, cgcemr.add_date) LOOP
      -- For each cycle task LP that has successfully perform inventory
      -- location update to SWMS ...
      BEGIN
        UPDATE cc_edit
        SET phys_loc = cgmr.dest_loc,
            new_qty = cgmr.qty_received
        WHERE logi_loc = cgcemr.logi_loc;

        IF SQL%ROWCOUNT > 0 THEN
          pl_log.ins_msg('INFO', sObjectName,
            'ML loc has changed from ' || cgcemr.phys_loc || ' to ' ||
            cgmr.dest_loc || ', new q/u: ' || TO_CHAR(cgmr.qty_received) ||
            TO_CHAR(cgmr.uom) || ' for CC_EDIT grp/LP/item ' ||
            TO_CHAR(cgcemr.group_no) || '/' || cgcemr.logi_loc ||
            cgcemr.prod_id || '/' || cgcemr.cust_pref_vendor ||
            ' due to msg InventoryArrival',
            NULL, NULL);
          poiStatus := 1;
          posUpdLoc := cgmr.dest_loc;
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END;
      BEGIN
        UPDATE cc_exception_list
        SET phys_loc = cgmr.dest_loc,
            qty = cgmr.qty_received / DECODE(cgmr.uom, 1, 1, cgcemr.spc),
            uom = cgmr.uom
        WHERE logi_loc = cgcemr.logi_loc;
        IF SQL%ROWCOUNT > 0 THEN
          poiStatus := 1;
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END;
    END LOOP;
  END LOOP;
END;

-- =============================================================================
PROCEDURE handle_special_cc_info(
  	psPalletID          	IN  inv.logi_loc%TYPE,
	psItem			IN  pm.prod_id%TYPE,
	psCpv			IN  pm.cust_pref_vendor%TYPE,
        poiInvItem		OUT NUMBER,
	poiStatus		OUT NUMBER) IS
  iIsMLLoc		NUMBER := 0;
  iRtnQty		NUMBER := 0;
  iStatus		NUMBER := C_NORMAL;
  tabRsnInfo		pl_dci.tabTypReasons;
  iQty			NUMBER := 0;
  iTransID		trans.trans_id%TYPE := NULL;
  iTransID2		trans.trans_id%TYPE := NULL;
  iTransDate		trans.trans_date%TYPE := NULL;
  iTransDate2		trans.trans_date%TYPE := NULL;
  sProd			pm.prod_id%TYPE := NULL;
  iW10InvItem		NUMBER;
  rcTrans		trans%ROWTYPE := NULL;
  CURSOR c_get_cc IS
    SELECT c.logi_loc, c.phys_loc, c.prod_id, c.cc_gen_date, c.cc_reason_code,
           c.group_no, c.cust_pref_vendor, p.spc
    FROM cc c, pm p
    WHERE c.logi_loc = psPalletID
    AND   c.prod_id = psItem
    AND   c.cust_pref_vendor = psCpv
    AND   c.prod_id = p.prod_id
    AND   c.cust_pref_vendor = p.cust_pref_vendor
    AND   (c.cc_reason_code = 'CC' OR
           c.cc_reason_code IN (SELECT cc_reason_code
                                FROM reason_cds
                                WHERE reason_cd_type = 'RTN'
                                AND   reason_group IN ('STM', 'OVR', 'MPR',
                                                       'MPK', 'OVI')));
  CURSOR c_get_cc_edit IS
    SELECT c.trans_id, c.group_no, c.prod_id, c.cust_pref_vendor, c.phys_loc,
           c.logi_loc, c.old_qty, c.new_qty, c.reason_code, c.cc_gen_date,
           c.adj_flag, c.add_date, p.spc
    FROM cc_edit c, pm p
    WHERE c.logi_loc = psPalletID
    AND   c.prod_id = psItem
    AND   c.cust_pref_vendor = psCpv
    AND   c.prod_id = p.prod_id
    AND   c.cust_pref_vendor = p.cust_pref_vendor
    AND   (c.reason_code = 'CC' OR
           c.reason_code IN (SELECT cc_reason_code
                             FROM reason_cds
                             WHERE reason_cd_type = 'RTN'
                             AND   reason_group IN ('STM', 'OVR', 'MPR',
                                                    'MPK', 'OVI')));

  CURSOR c_get_cc_trans_rtn_info(cpsProd	pm.prod_id%TYPE,
                                 cpsCpv		pm.cust_pref_vendor%TYPE,
                                 cpsDate	cc.cc_gen_date%TYPE,
                                 cpiWhatProd	NUMBER,
                                 cpiTransID	trans.trans_id%TYPE) IS
    SELECT t.prod_id, t.cust_pref_vendor, t.reason_code, t.qty, t.uom,
           t.returned_prod_id,
           t.trans_id, t.trans_date, t.rec_id
    FROM trans t
    WHERE t.trans_type = 'RTN'
    AND   t.cust_pref_vendor = cpsCpv
    AND   t.trans_date <= cpsDate
    AND   (((cpiTransID IS NULL) AND
           (((cpiWhatProd = 1) AND (t.returned_prod_id = cpsProd)) OR
            ((cpiWhatProd = 2) AND (t.prod_id = cpsProd)))) OR
           ((cpiTransID IS NOT NULL) AND (t.trans_id = cpiTransID)))
    AND   ROWNUM = 1
    ORDER BY t.trans_date DESC;

  CURSOR c_get_trans_rtn_info(cpsProd		pm.prod_id%TYPE,
                              cpsCpv		pm.cust_pref_vendor%TYPE,
                              cpsDate		cc.cc_gen_date%TYPE,
                              cpsCCRsn		cc.cc_reason_code%TYPE,
                              cpiTransID	trans.trans_id%TYPE) IS 
    SELECT t.prod_id, t.cust_pref_vendor, t.reason_code, t.qty, t.uom,
           t.returned_prod_id,
           t.trans_id, t.trans_date, t.rec_id, r.reason_group
    FROM trans t, reason_cds r
    WHERE t.trans_type = 'RTN'
    AND   t.cust_pref_vendor = cpsCpv
    AND   t.trans_date <= cpsDate
    AND   (((cpiTransID IS NULL) AND
            (t.reason_code = r.reason_cd) AND
            (t.prod_id = cpsProd) AND
            (r.reason_cd_type = 'RTN') AND
            (r.reason_group IN ('STM', 'OVR', 'MPR', 'MPK', 'OVI'))) OR
           ((cpiTransID IS NOT NULL) AND (t.trans_id = cpiTransID)))
    AND   ROWNUM = 1
    ORDER BY t.trans_date DESC;
  CURSOR c_get_hld_inv(cpsProd	pm.prod_id%TYPE,
                       cpsCpv	pm.cust_pref_vendor%TYPE) IS
    SELECT i.rowid, i.plogi_loc, i.logi_loc, i.qoh, i.inv_uom, i.prod_id,
           i.cust_pref_vendor
    FROM inv i
    WHERE i.prod_id = cpsProd
    AND   i.cust_pref_vendor = cpsCpv
    AND   i.status = 'HLD'
    AND   i.qoh > 0
    AND   i.qty_planned = 0
    AND   i.qty_alloc = 0
    AND   EXISTS (SELECT 1
                  FROM zone z, lzone lz
                  WHERE z.zone_id = lz.zone_id
                  AND   z.zone_type = 'PUT'
                  AND   lz.logi_loc = i.plogi_Loc
                  AND   z.rule_id = C_ML_RULEID)
    ORDER BY i.add_date;

  CURSOR c_get_qty(cpsProd	pm.prod_id%TYPE,
                   cpsCpv	pm.cust_pref_vendor%TYPE,
                   cpiQty       NUMBER,
                   cpiUom       NUMBER) IS
    SELECT cpiQty * DECODE(cpiUom, 1, 1, spc)
    FROM pm
    WHERE prod_id = cpsProd
    AND   cust_pref_vendor = cpsCpv;
BEGIN
  poiInvItem := 1;
  poiStatus := C_NORMAL;

  -- Do nothing if the current LP doesn't belong to Mini-load system
  BEGIN
    SELECT 1 INTO iIsMLLoc
    FROM inv i, zone z, lzone lz
    WHERE i.prod_id = psItem
    AND   i.cust_pref_vendor = psCpv
    AND   i.logi_loc = psPalletID
    AND   z.zone_id = lz.zone_id
    AND   z.zone_type = 'PUT'
    AND   lz.logi_loc = i.plogi_loc
    AND   z.rule_id = C_ML_RULEID;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      BEGIN
        SELECT 1 INTO iIsMLLoc
        FROM cc i, zone z, lzone lz
        WHERE i.prod_id = psItem
        AND   i.cust_pref_vendor = psCpv
        AND   i.logi_loc = psPalletID
        AND   z.zone_id = lz.zone_id
        AND   z.zone_type = 'PUT'
        AND   lz.logi_loc = i.phys_loc
        AND   z.rule_id = C_ML_RULEID;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          BEGIN
            SELECT 1 INTO iIsMLLoc
            FROM cc_edit i, zone z, lzone lz
            WHERE i.prod_id = psItem
            AND   i.cust_pref_vendor = psCpv
            AND   i.logi_loc = psPalletID
            AND   z.zone_id = lz.zone_id
            AND   z.zone_type = 'PUT'
            AND   lz.logi_loc = i.phys_loc
            AND   z.rule_id = C_ML_RULEID;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              poiStatus := C_ML_NOT_ML_SLOT;
              RETURN;
            WHEN OTHERS THEN
              poiStatus := SQLCODE;
              RETURN;
          END;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END;
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;
  DBMS_OUTPUT.PUT_LINE('Item ' || psItem || ' is in Mini-load slot');

  iStatus := C_NORMAL;
  DBMS_OUTPUT.PUT_LINE('Begin processing cc ....');
  FOR cgc IN c_get_cc LOOP
    DBMS_OUTPUT.PUT_LINE('CC Loc: ' || cgc.phys_loc || '/' || cgc.logi_loc ||
      ', rsn: ' || cgc.cc_reason_code ||
      ', gendate: ' || TO_CHAR(cgc.cc_gen_date, 'MM/DD/RR HH24:MI:SS'));

    iTransID := NULL;
    iTransDate := NULL;
    IF cgc.cc_reason_code = 'CC' THEN
      FOR cgtri IN c_get_cc_trans_rtn_info(cgc.prod_id, cgc.cust_pref_vendor,
                                           cgc.cc_gen_date,
                                           1, NULL) LOOP
        iTransID := cgtri.trans_id;
        iTransDate := cgtri.trans_date;
        DBMS_OUTPUT.PUT_LINE('RTN CC 1 ' || TO_CHAR(iTransID) ||
          ', d: ' || TO_CHAR(iTransDate, 'MM/DD/RR HH24:MI:SS') ||
          ', r: ' || cgtri.reason_code || ', p: ' || cgtri.prod_id || '/' ||
          cgtri.returned_prod_id);
      END LOOP;
      iTransID2 := NULL;
      iTransDate2 := NULL;
      FOR cgtri IN c_get_cc_trans_rtn_info(cgc.prod_id, cgc.cust_pref_vendor,
                                           cgc.cc_gen_date,
                                           2, NULL) LOOP
        iTransID2 := cgtri.trans_id;
        iTransDate2 := cgtri.trans_date;
        DBMS_OUTPUT.PUT_LINE('RTN CC 2 ' || TO_CHAR(iTransID2) ||
          ', d: ' || TO_CHAR(iTransDate2, 'MM/DD/RR HH24:MI:SS') ||
          ', r: ' || cgtri.reason_code || ', p: ' || cgtri.prod_id || '/' ||
          cgtri.returned_prod_id);
      END LOOP;
      IF iTransDate2 > iTransDate THEN
        iTransID := iTransID2;
        iTransDate := iTransDate2;
      END IF;
    ELSE
      FOR cgtri IN c_get_trans_rtn_info(cgc.prod_id, cgc.cust_pref_vendor,
                                        cgc.cc_gen_date,
                                        cgc.cc_reason_code,
                                        NULL) LOOP
        iTransID := cgtri.trans_id;
        iTransDate := cgtri.trans_date;
        DBMS_OUTPUT.PUT_LINE('RTN ' || cgc.cc_reason_code || ' ' ||
          TO_CHAR(iTransID) ||
          ', d: ' || TO_CHAR(iTransDate, 'MM/DD/RR HH24:MI:SS') ||
          ', r: ' || cgtri.reason_code || ', p: ' || cgtri.prod_id || '/' ||
          cgtri.returned_prod_id);
      END LOOP;
    END IF;
    DBMS_OUTPUT.PUT_LINE('Found trans ID: ' || TO_CHAR(iTransID));

    FOR cgtri IN c_get_trans_rtn_info(cgc.prod_id, cgc.cust_pref_vendor,
                                      cgc.cc_gen_date,
                                      cgc.cc_reason_code,
                                      iTransID) LOOP
      DBMS_OUTPUT.PUT_LINE('RTN dt/id: ' ||
        TO_CHAR(cgtri.trans_date, 'MM/DD/RR HH24:MI:SS') || '/' ||
        TO_CHAR(cgtri.trans_id) ||
        ', rsn/grp: ' || cgtri.reason_code || '/' || cgtri.reason_group ||
        ', q: ' || TO_CHAR(cgtri.qty) ||
        '/' || TO_CHAR(cgtri.uom) || ', mf: ' || cgtri.rec_id ||
        ', p/rp: ' || cgtri.prod_id || '/' || cgtri.returned_prod_id);
      tabRsnInfo := pl_dci.get_reason_info('RTN', 'ALL', cgtri.reason_code);
      iQty := 0;
      sProd := cgtri.prod_id;
      IF tabRsnInfo.COUNT = 0 THEN
        iStatus := pl_dci.C_INV_RSN;
      ELSE
        iW10InvItem := 1;
        IF cgc.cc_reason_code = 'CC' THEN
          -- The item might be from mispicked return
          IF tabRsnInfo(1).reason_group IN ('MPR', 'MPK') THEN
            IF cgtri.returned_prod_id = cgc.prod_id AND
               cgtri.cust_pref_vendor = cgc.cust_pref_vendor THEN
              poiInvItem := 0;
              iW10InvItem := 0;
              sProd := cgtri.returned_prod_id;
              OPEN c_get_qty(cgtri.returned_prod_id, cgtri.cust_pref_vendor,
                             cgtri.qty, cgtri.uom);
              FETCH c_get_qty INTO iQty;
              IF c_get_qty%NOTFOUND THEN
                iStatus := pl_dci.C_INV_PRODID;
              END IF;
              CLOSE c_get_qty;
            END IF;
          END IF;
        END IF;
        IF iW10InvItem = 1 THEN
          OPEN c_get_qty(cgtri.prod_id, cgtri.cust_pref_vendor,
                         cgtri.qty, cgtri.uom);
          FETCH c_get_qty INTO iQty;
          IF c_get_qty%NOTFOUND THEN
            iStatus := pl_dci.C_INV_PRODID;
          END IF;
          CLOSE c_get_qty;
        END IF;
      END IF;
      iRtnQty := iQty;
      IF iStatus = C_NORMAL THEN
        DBMS_OUTPUT.PUT_LINE('RsnG ' || tabRsnInfo(1).reason_group ||
          ', rtnq: ' || TO_CHAR(iRtnQty) || ', p: ' || sProd ||
          ', W10InvItem: ' || TO_CHAR(iW10InvItem));
      END IF;
      IF iStatus = C_NORMAL AND iRtnQty > 0 THEN
        FOR cghi IN c_get_hld_inv(sProd, cgtri.cust_pref_vendor) LOOP
          DBMS_OUTPUT.PUT_LINE('Onhold inv: ' || cghi.plogi_loc || '/' ||
            cghi.logi_loc || ', qoh: ' || TO_CHAR(cghi.qoh) ||
            ', restq: ' || TO_CHAR(iRtnQty));
          IF cghi.qoh >= iRtnQty THEN
            BEGIN
              UPDATE inv
              SET status = 'AVL'
              WHERE rowid = cghi.rowid;

              IF SQL%ROWCOUNT > 0 THEN
                iRtnQty := iRtnQty - cghi.qoh;
                DBMS_OUTPUT.PUT_LINE('After inv status update: ' ||
                  TO_CHAR(iRtnQty));

                -- Notify user the status change for research purpose
                rcTrans := NULL;
                rcTrans.trans_type := 'STA';
                rcTrans.prod_id := cghi.prod_id;
                rcTrans.cust_pref_vendor := cghi.cust_pref_vendor;
                rcTrans.qty := cghi.qoh;
                rcTrans.uom := cghi.inv_uom;
                rcTrans.src_loc := cghi.plogi_loc;
                rcTrans.cmt :=
                  'For MIS CC exception count qty. Not send to SUS';
                rcTrans.old_status := 'HLD';
                rcTrans.new_status := 'AVL';
                rcTrans.reason_code := cgc.cc_reason_code;
                rcTrans.pallet_id := cghi.logi_loc;
                BEGIN
                  iStatus := pl_common.f_create_trans(rcTrans, 'NA');
            
                  IF iStatus != C_NORMAL THEN 
                    EXIT;
                  END IF;
                EXCEPTION
                  WHEN OTHERS THEN
                    iStatus := SQLCODE;
                END;
              END IF;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                NULL;
              WHEN OTHERS THEN
                iStatus := SQLCODE;
                EXIT;
            END;
          END IF;
          EXIT WHEN (iRtnQty <= 0) OR (iStatus <> C_NORMAL);
        END LOOP;
        EXIT WHEN iStatus <> C_NORMAL;
      END IF;
      EXIT WHEN iStatus <> C_NORMAL;
    END LOOP;
    EXIT WHEN iStatus <> C_NORMAL;
  END LOOP;
  IF iStatus <> C_NORMAL THEN
    poiStatus := iStatus;
    RETURN;
  END IF;

  iStatus := C_NORMAL;
  iQty := 0;
  FOR cgce IN c_get_cc_edit LOOP
    DBMS_OUTPUT.PUT_LINE('CC_EDIT Loc: ' || cgce.phys_loc || '/' ||
      cgce.logi_loc || ', rsn: ' || cgce.reason_code ||
      ', adddate: ' || TO_CHAR(cgce.add_date, 'MM/DD/RR HH24:MI:SS'));

    iTransID := NULL;
    iTransDate := NULL;

    IF cgce.reason_code = 'CC' THEN
      FOR cgtri IN c_get_cc_trans_rtn_info(cgce.prod_id, cgce.cust_pref_vendor,
                                           cgce.add_date,
                                           1, NULL) LOOP
        iTransID := cgtri.trans_id;
        iTransDate := cgtri.trans_date;
        DBMS_OUTPUT.PUT_LINE('RTNEDIT CC 1 ' || TO_CHAR(iTransID) ||
          ', d: ' || TO_CHAR(iTransDate, 'MM/DD/RR HH24:MI:SS') ||
          ', r: ' || cgtri.reason_code || ', p: ' || cgtri.prod_id || '/' ||
          cgtri.returned_prod_id);
      END LOOP;
      iTransID2 := NULL;
      iTransDate2 := NULL;
      FOR cgtri IN c_get_cc_trans_rtn_info(cgce.prod_id, cgce.cust_pref_vendor,
                                           cgce.add_date,
                                           2, NULL) LOOP
        iTransID2 := cgtri.trans_id;
        iTransDate2 := cgtri.trans_date;
        DBMS_OUTPUT.PUT_LINE('RTNEDIT CC 2 ' || TO_CHAR(iTransID2) ||
          ', d: ' || TO_CHAR(iTransDate2, 'MM/DD/RR HH24:MI:SS') ||
          ', r: ' || cgtri.reason_code || ', p: ' || cgtri.prod_id || '/' ||
          cgtri.returned_prod_id);
      END LOOP;
      IF iTransDate2 > iTransDate THEN
        iTransID := iTransID2;
        iTransDate := iTransDate2;
      END IF;
    ELSE
      FOR cgtri IN c_get_trans_rtn_info(cgce.prod_id, cgce.cust_pref_vendor,
                                        cgce.add_date,
                                        cgce.reason_code,
                                        NULL) LOOP
        iTransID := cgtri.trans_id;
        iTransDate := cgtri.trans_date;
        DBMS_OUTPUT.PUT_LINE('RTNEDIT ' || cgce.reason_code || ' ' ||
          TO_CHAR(iTransID) ||
          ', d: ' || TO_CHAR(iTransDate, 'MM/DD/RR HH24:MI:SS') ||
          ', r: ' || cgtri.reason_code || ', p: ' || cgtri.prod_id || '/' ||
          cgtri.returned_prod_id);
      END LOOP;
    END IF;
    DBMS_OUTPUT.PUT_LINE('Found trans ID: ' || TO_CHAR(iTransID));

    FOR cgtri IN c_get_trans_rtn_info(cgce.prod_id, cgce.cust_pref_vendor,
                                      cgce.add_date,
                                      cgce.reason_code,
                                      iTransID) LOOP
      DBMS_OUTPUT.PUT_LINE('RTN dt/id: ' ||
        TO_CHAR(cgtri.trans_date, 'MM/DD/RR HH24:MI:SS') || '/' ||
        TO_CHAR(cgtri.trans_id) ||
        ', rsn/grp: ' || cgtri.reason_code || '/' || cgtri.reason_group ||
        ', q: ' || TO_CHAR(cgtri.qty) ||
        '/' || TO_CHAR(cgtri.uom) || ', mf: ' || cgtri.rec_id ||
        ', p/rp: ' || cgtri.prod_id || '/' || cgtri.returned_prod_id);

      tabRsnInfo := pl_dci.get_reason_info('RTN', 'ALL', cgtri.reason_code);
      IF tabRsnInfo.COUNT = 0 THEN
        iStatus := pl_dci.C_INV_RSN;
      ELSE
        iW10InvItem := 1;
        sProd := cgtri.prod_id;
        IF cgce.reason_code = 'CC' THEN
          -- The item might be from mispicked return
          IF tabRsnInfo(1).reason_group IN ('MPR', 'MPK') THEN
            DBMS_OUTPUT.PUT_LINE('Rsn CC MPR/K sProd: ' || sProd ||
              ', cgtri.rtnp: ' || cgtri.returned_prod_id || ', cgce.prod: ' ||
              cgce.prod_id);
            IF cgtri.returned_prod_id = cgce.prod_id AND
               cgtri.cust_pref_vendor = cgce.cust_pref_vendor THEN
              poiInvItem := 0;
              iW10InvItem := 0;
              sProd := cgtri.returned_prod_id;
              OPEN c_get_qty(cgtri.returned_prod_id, cgtri.cust_pref_vendor,
                             cgtri.qty, cgtri.uom);
              FETCH c_get_qty INTO iQty;
              IF c_get_qty%NOTFOUND THEN
                iStatus := pl_dci.C_INV_PRODID;
              END IF;
              CLOSE c_get_qty;
            END IF;
          END IF;
        END IF;
        IF iW10InvItem = 1 THEN
          OPEN c_get_qty(cgtri.prod_id, cgtri.cust_pref_vendor,
                         cgtri.qty, cgtri.uom);
          FETCH c_get_qty INTO iQty;
          IF c_get_qty%NOTFOUND THEN
            iStatus := pl_dci.C_INV_PRODID;
          END IF;
          CLOSE c_get_qty;
        END IF;
      END IF;
      iRtnQty := iQty;
      IF iStatus = C_NORMAL THEN
        DBMS_OUTPUT.PUT_LINE('RsnG ' || tabRsnInfo(1).reason_group ||
          ', rtnq: ' || TO_CHAR(iRtnQty) || ', sProd: ' || sProd);
      END IF;
      IF iStatus = C_NORMAL AND iRtnQty > 0 THEN
        FOR cghi IN c_get_hld_inv(sProd, cgtri.cust_pref_vendor) LOOP
          DBMS_OUTPUT.PUT_LINE('Onhold inv: ' || cghi.plogi_loc || '/' ||
            cghi.logi_loc || ', qoh: ' || TO_CHAR(cghi.qoh) ||
            ', restq: ' || TO_CHAR(iRtnQty));
          IF cghi.qoh >= iRtnQty THEN
            BEGIN
              UPDATE inv
              SET status = 'AVL'
              WHERE rowid = cghi.rowid;

              IF SQL%ROWCOUNT > 0 THEN
                iRtnQty := iRtnQty - cghi.qoh;
                DBMS_OUTPUT.PUT_LINE('After inv status update: ' ||
                  TO_CHAR(iRtnQty));

                -- Notify user the status change for research purpose
                rcTrans := NULL;
                rcTrans.trans_type := 'STA';
                rcTrans.prod_id := cghi.prod_id;
                rcTrans.cust_pref_vendor := cghi.cust_pref_vendor;
                rcTrans.qty := cghi.qoh;
                rcTrans.uom := cghi.inv_uom;
                rcTrans.src_loc := cghi.plogi_loc;
                rcTrans.cmt :=
                  'For MIS CC exception count qty. Not send to SUS';
                rcTrans.old_status := 'HLD';
                rcTrans.new_status := 'AVL';
                rcTrans.reason_code := cgce.reason_code;
                rcTrans.pallet_id := cghi.logi_loc;
                BEGIN
                  iStatus := pl_common.f_create_trans(rcTrans, 'NA');
            
                  IF iStatus != C_NORMAL THEN 
                    EXIT;
                  END IF;
                EXCEPTION
                  WHEN OTHERS THEN
                    iStatus := SQLCODE;
                END;
              END IF;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                NULL;
              WHEN OTHERS THEN
                iStatus := SQLCODE;
                EXIT;
            END;
          END IF;
        END LOOP;
      END IF;
      EXIT WHEN iStatus <> C_NORMAL;
    END LOOP;
    EXIT WHEN iStatus <> C_NORMAL;
  END LOOP;

  poiStatus := iStatus;
END;

-- =============================================================================
PROCEDURE gen_ml_tasks_for_mis(
  	psPalletID          	IN  trans.pallet_id%TYPE,
 	poiStatus		OUT NUMBER) IS
  iCCBatchNo	cc.batch_no%TYPE := NULL;
  iStatus	NUMBER := C_NORMAL;
  rcTrans	trans%ROWTYPE := NULL;
  rcMLData	pl_miniload_processing.t_exp_receipt_info := NULL;
  CURSOR c_get_puttask IS
    SELECT pt.dest_loc, NVL(z.rule_id, 0) rule_id, pt.rec_id, pt.pallet_id,
           pt.prod_id, pt.cust_pref_vendor, pt.exp_date, pt.mfg_date,
           pt.weight, pt.temp,
           pt.qty, pt.uom, p.spc, p.abc, p.case_cube, p.min_qty, p.exp_date_trk,
           l.pallet_type, rc.cc_reason_code, pty.skid_cube
    FROM putawaylst pt, zone z, lzone lz, pm p, loc l, pallet_type pty,
         reason_cds rc
    WHERE pt.pallet_id = psPalletID
    AND   z.zone_id = lz.zone_id
    AND   z.zone_type = 'PUT'
    AND   lz.logi_loc = pt.dest_loc
    AND   pt.rec_id LIKE 'S%'
    AND   pt.dest_loc = l.logi_loc
    AND   l.pallet_type = pty.pallet_type
    AND   pt.prod_id = p.prod_id
    AND   pt.cust_pref_vendor = p.cust_pref_vendor
    AND   pt.reason_code = rc.reason_cd
    AND   rc.reason_cd_type = 'RTN'
    AND   rc.reason_group IN ('STM', 'OVR', 'MPR', 'MPK', 'OVI');
BEGIN
  poiStatus := C_NORMAL;

  FOR cgp IN c_get_puttask LOOP

    -- The putaway location is not a ML slot. Do nothing
    EXIT WHEN cgp.rule_id <> C_ML_RULEID;

    -- Create a ML location inventory. Note that since this is from a return
    -- and the current location is a ML slot, we send 01012001 as the
    -- inventory's expiration date as required by ML system
    BEGIN
      INSERT INTO inv
        (prod_id, rec_id, mfg_date, rec_date, exp_date, inv_date,
         logi_loc, plogi_loc, qoh, qty_alloc, qty_planned, min_qty,
         cube, lst_cycle_date, abc_gen_date, abc, status,
         weight, temperature,
         exp_ind, cust_pref_vendor, inv_uom)
      VALUES
        (cgp.prod_id, cgp.rec_id, cgp.mfg_date, SYSDATE,
         TO_DATE('01012001', 'MMDDYYYY'),
         SYSDATE,
         cgp.pallet_id, cgp.dest_loc, cgp.qty, 0, 0, cgp.min_qty,
         (cgp.qty / cgp.spc) * cgp.case_cube + cgp.skid_cube, SYSDATE, SYSDATE,
         cgp.abc, 'HLD', cgp.weight, cgp.temp, cgp.exp_date_trk,
         cgp.cust_pref_vendor, 2 - cgp.uom);
    EXCEPTION
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        EXIT;
    END;

    -- Notify user the status change for research purpose
    rcTrans.trans_type := 'STA';
    rcTrans.prod_id := cgp.prod_id;
    rcTrans.cust_pref_vendor := cgp.cust_pref_vendor;
    rcTrans.qty := cgp.qty;
    rcTrans.uom := cgp.uom;
    rcTrans.src_loc := cgp.dest_loc;
    rcTrans.cmt := 'For MIS CC exception count qty. Not send to SUS';
    rcTrans.old_status := 'AVL';
    rcTrans.new_status := 'HLD';
    rcTrans.reason_code := cgp.cc_reason_code;
    rcTrans.pallet_id := cgp.pallet_id;
    BEGIN
      iStatus := pl_common.f_create_trans(rcTrans, 'NA');

      IF iStatus != C_NORMAL THEN 
        poiStatus := iStatus;
        EXIT;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        EXIT;
    END;
  END LOOP;
END;

-- =============================================================================
PROCEDURE write_expected_receipt(
  	psPalletID          	IN  trans.pallet_id%TYPE,
 	piStatus		OUT NUMBER) IS
BEGIN
  piStatus := C_NORMAL;
	 
  -- Log
  pl_log.ins_msg('I', 'pl_ml_common.write_expected_receipt', 
		 'LP: '||psPalletID, 0, 0);

  -- Check to see if LP has destination in the mini loader
  -- Call interface pl to write record
END;

-- -----------------------------------------------------------------------------



-------------------------------------------------------------------------------
-- PROCEDURE
--    is_miniload_item
--
-- Description:
--     This procedure determines if an item is a miniload item.  A check can
--     be made at three different levels.
--        1.  Item level only (no CPV)
--        2.  Item and CPV.
--        3.  Item, CPV and UOM.
--     
-- Parameters:
--    i_what_to_check        - What to check.  It will be one of the following:
--                               - CT_CHECK_ITEM
--                               - CT_CHECK_ITEM_CPV
--                               - CT_CHECK_ITEM_CPV_UOM
--    i_prod_id              - The item to check.
--    i_cust_pref_vendor     - The CPV to check
--    i_uom                  - The UOM to check
--    o_is_miniload_item_bln - Designates if the item is stored in the
--                             miniloader based on what to check.
--                             TRUE  - Cases/splits or splits are in the ML.
--                             FALSE - Nothing is in the ML or the item is
--                                     not valid.
--    o_msg                  - Message stating why the item is not in the ML.
--                             It is populated only when
--                             o_is_miniload_item_bln is FALSE.
--
-- Exceptions Raised:
--    pl_exc.ct_data_error - Bad parameter.
--    The when others exception propagates the exception.
--
-- Called by:
--    Form mm3sa.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/07/06 prpbcb   Created.
--                      The procedure was created to use in form mm3sa.fmb
--                      to validate the item, CPV, UOM when the user is
--                      creating a message to send to the miniloader.
--                      The form is validating each of these as entered--when
--                      the item is entered then only the item is validated,
--                      when the CPV is entered then the item plus the
--                      CPV are validated, when the UOM is entered
--                      then the item plus the CPV plus the UOM are
--                      validated.
----------------------------------------------------------------------------
PROCEDURE is_miniload_item
        (i_what_to_check         IN  VARCHAR2,
         i_prod_id               IN  pm.prod_id%TYPE,
         i_cust_pref_vendor      IN  pm.cust_pref_vendor%TYPE,
         i_uom                   IN  uom.uom%TYPE,
         o_is_miniload_item_bln  OUT BOOLEAN,
         o_msg                   OUT VARCHAR2)
IS
   l_message        VARCHAR2(256);    -- Message buffer
   l_object_name    VARCHAR2(61) := gl_pkg_name ||  '.is_miniload_item';

   l_dummy          VARCHAR2(1);  -- Holding place

   e_bad_parameter  EXCEPTION;    -- Bad parameter.

   --
   -- This cursor is used to determine if the item is stored in the
   -- miniloader.
   --
   CURSOR c_miniload_item
                       (cp_prod_id          pm.prod_id%TYPE,
                        cp_cust_pref_vendor pm.cust_pref_vendor%TYPE,
                        cp_uom              uom.uom%TYPE) IS
       SELECT 'x'
         FROM v_prod_ml_uom
        WHERE prod_id          = cp_prod_id
          AND cust_pref_vendor = NVL(cp_cust_pref_vendor, cust_pref_vendor)
          AND uom              = NVL(cp_uom, uom);

   ------------------------------------------------------------------------
   -- Local Function:
   --    is_valid_item
   --
   -- Description:
   --    This function determines if the item and CPV are valid.
   --    If the CPV argument is null then only the prod id is checked.
   --
   -- Parameters:
   --    i_prod_id           - Item to check
   --    i_cpv               - CPV.  Can be null in which case only the
   --                          prod id needs to exist.
   --
   -- Return Value:
   --    TRUE  when the item, cpv combination exists.
   --    FALSE when the item, cpv combination does not exists.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Some error occurred.
   --
   -- Called By:
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ------------------------------------------------
   --    07/29/03 prpbcb   Created.
   ------------------------------------------------------------------------
   FUNCTION is_valid_item( i_prod_id           IN pm.prod_id%TYPE,
                           i_cust_pref_vendor  IN pm.cust_pref_vendor%TYPE)
   RETURN BOOLEAN
   IS
      l_message       VARCHAR2(256);    -- Message buffer

      l_dummy         VARCHAR2(1);  -- Holding place
      l_return_value  BOOLEAN;

      --
      -- This cursor is used to determine if the item, cpv is valid.
      --
      CURSOR c_valid_item_cpv
                        (cp_prod_id          pm.prod_id%TYPE,
                         cp_cust_pref_vendor pm.cust_pref_vendor%TYPE) IS
         SELECT 'x'
           FROM pm
          WHERE prod_id          = cp_prod_id
            AND cust_pref_vendor = NVL(cp_cust_pref_vendor, cust_pref_vendor);
   BEGIN
      OPEN c_valid_item_cpv(i_prod_id, i_cust_pref_vendor);
      FETCH c_valid_item_cpv INTO l_dummy;

      IF (c_valid_item_cpv%FOUND) THEN
         l_return_value := TRUE;
      ELSE
         l_return_value := FALSE;
      END IF;

      CLOSE c_valid_item_cpv;

      RETURN(l_return_value);
   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name
                     || '(i_prod_id[' || i_prod_id || ']'
                     || ',i_cust_pref_vendor[' || i_cust_pref_vendor || '])';
         pl_log.ins_msg('FATAL', l_object_name, l_message,
                           SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 'is_valid_item: ' || SQLERRM);
   END is_valid_item;  -- end local function
   --------------------------------------------------------------------------

BEGIN
   IF (i_what_to_check = CT_CHECK_ITEM) THEN
      OPEN c_miniload_item(i_prod_id, NULL, NULL);
      FETCH c_miniload_item INTO l_dummy;
      IF (c_miniload_item%FOUND) THEN
         --
         -- Something of the item is stored in the miniloader.
         --
         o_is_miniload_item_bln := TRUE;
      ELSE
         --
         -- The item is not in the miniloader.
         --
         o_is_miniload_item_bln := FALSE;

         IF (is_valid_item(i_prod_id, NULL)) THEN
            o_msg := 'Item[' || i_prod_id
                     || '] is not stored in the miniloader.';
         ELSE
            o_msg := 'Item[' || i_prod_id
                     || '] is not a valid item.';
         END IF;
      END IF;
   ELSIF (i_what_to_check = CT_CHECK_ITEM_CPV) THEN
      OPEN c_miniload_item(i_prod_id, i_cust_pref_vendor, NULL);
      FETCH c_miniload_item INTO l_dummy;
      IF (c_miniload_item%FOUND) THEN
         --
         -- Something of the item, cpv combination is stored in the miniloader.
         --
         o_is_miniload_item_bln := TRUE;
      ELSE
         --
         -- The item, cpv combination is not in the miniloader.
         --
         o_is_miniload_item_bln := FALSE;

         IF (is_valid_item(i_prod_id, i_cust_pref_vendor)) THEN
            o_msg := 'Item[' || i_prod_id || ']'
                     || ' CPV[' || i_cust_pref_vendor || ']'
                     || ' is not stored in the miniloader.';
         ELSE
            o_msg := 'Item[' || i_prod_id || ']'
                     || ' CPV[' || i_cust_pref_vendor || ']'
                     || ' combination does not exist.';
         END IF;
      END IF;
   ELSIF (i_what_to_check = CT_CHECK_ITEM_CPV_UOM) THEN
      OPEN c_miniload_item(i_prod_id, i_cust_pref_vendor, i_uom);
      FETCH c_miniload_item INTO l_dummy;
      IF (c_miniload_item%FOUND) THEN
         --
         -- The item, cpv and uom combination is stored in the miniloader.
         --
         o_is_miniload_item_bln := TRUE;
      ELSE
         --
         -- The item, cpv and uom combination is not in the miniloader.
         --
         o_is_miniload_item_bln := FALSE;

         IF (is_valid_item(i_prod_id, i_cust_pref_vendor)) THEN
            o_msg := 'Item[' || i_prod_id || ']'
                     || ' CPV[' || i_cust_pref_vendor || ']'
                     || ' UOM[' || TO_CHAR(i_uom) || ']'
                     || ' combination is not stored in the miniloader.';
         ELSE
            o_msg := 'Item[' || i_prod_id || ']'
                     || ' CPV[' || i_cust_pref_vendor || ']'
                     || ' UOM[' || TO_CHAR(i_uom) || ']'
                     || ' combination does not exist.';
         END IF;
      END IF;
   ELSE
      --
      -- i_what_to_check has an unhandled value.
      --
      RAISE e_bad_parameter;
   END IF;

   IF (c_miniload_item%ISOPEN) THEN
      CLOSE c_miniload_item;
   END IF;

EXCEPTION
   WHEN e_bad_parameter THEN
      l_message := l_object_name
                     || ': i_what_to_check[' || i_what_to_check || ']'
                     || ' has an unhandled value.'
                     || '  i_prod_id[' || i_prod_id || ']'
                     || ' i_cust_pref_vendor[' || i_cust_pref_vendor || ']'
                     || ' i_uom[' || TO_CHAR(i_uom) || ']';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

   WHEN OTHERS THEN
      --
      -- Got some error.
      --
      -- Log the error.
      l_message := l_object_name
                     || ': i_what_to_check[' || i_what_to_check || ']'
                     || '  i_prod_id[' || i_prod_id || ']'
                     || ' i_cust_pref_vendor[' || i_cust_pref_vendor || ']'
                     || ' i_uom[' || TO_CHAR(i_uom) || ']';
      pl_log.ins_msg ('WARNING', l_object_name,  l_message, SQLCODE, SQLERRM);

      RAISE;  -- Propogate it.
END is_miniload_item;



-- ************************* <End of Package Body> *****************************

-- *********************** <Package Initialization> ****************************

BEGIN
  -- Set up available error information that can be used by caller
  set_pkg_error_info;
END pl_ml_common;
/

SHOW ERRORS

--LIST

--CREATE OR REPLACE PUBLIC SYNONYM pl_ml_common FOR swms.pl_ml_common;

