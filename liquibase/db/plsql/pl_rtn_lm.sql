/**************************************************************************/
-- Package Specification
/**************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_rtn_lm IS

   --  sccs_id=@(#) src/schema/plsql/pl_rtn_lm.sql, swms, swms.9, 10.1.1 9/7/06 1.7

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_rtn_lm
   --
   -- Description:
   --    Returns labor management package.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/20/04 prplhj   D#11741 Initial version
   --    09/09/05 prplhj   D#11996 Fixed delete batch problems
   --    10/14/05 prplhj   D#12012 Don't create T-batch for damage returns
   --    01/20/06 prplhj   D#12055 During new return batch creation, if an
   --                      existing batch is found in BATCH table but there is
   --                      no record in PUTAWAYLST pertaining to the batch,
   --                      update the existing batch status to Future before
   --                      new batch is created. Fixed the problem to check on
   --			   # of pallets against the preset NUM_PALLETS_MSKU
   --			   during merge batch. Fixed get_batch_no() to include
   --			   the handling of damage return.
   --    05/12/06 prplhj   D#12093 Fixed unload_pallet_batch() to not retrieve
   --                      reason group on the select statement to prevent
   --                      Oracle -1422 error.
   --

   ---------------------------------------------------------------------------
   -- Global Type Declarations
   ---------------------------------------------------------------------------

   -- A table contents all columns from PALLET_RET_CNTRL table
   TYPE ttabRetCtlRows IS TABLE OF pallet_ret_cntrl%ROWTYPE
     INDEX BY BINARY_INTEGER;

   -- A record of syspar flags related to the package
   TYPE trecRtnLmFlags IS RECORD (
     szLbrMgmtFlag		sys_config.config_flag_val%TYPE,
     szCrtBatchFlag		lbr_func.create_batch_flag%TYPE,
     szLmRtnDfltIndJobCode	sys_config.config_flag_val%TYPE
   );

   -- Logi_loc has PUTAWAYLST.DEST_LOC value
   -- BatchNo has PUTAWAYLST.PALLET_BATCH_NO value
   -- Worksheet and newBatch have either 'Y' or 'N' values
   TYPE trecBatches IS RECORD (
     logi_loc   loc.logi_loc%TYPE,
     batchNo	putawaylst.parent_pallet_id%TYPE,
     worksheet	VARCHAR2(1),
     newBatch   VARCHAR2(1),
     dmgPallet  inv.logi_loc%TYPE);

   -- A table contents all existing or newly generated T-batches and flags
   TYPE ttabBatches IS TABLE OF trecBatches
     INDEX BY BINARY_INTEGER;

   -- A table contents varchar values
   TYPE ttabValues IS TABLE OF VARCHAR2(100)
     INDEX BY BINARY_INTEGER;

   ---------------------------------------------------------------------------
   -- Global Variables
   ---------------------------------------------------------------------------

   gszPkgMessage	VARCHAR2(2000);	/* Use for error message to caller */
   giCode		NUMBER;		/* Use for setting public constants */
					/*   to a variable */

   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------

   SYSPAR_NOT_SET		CONSTANT NUMBER := -20001;
   INV_LABEL			CONSTANT NUMBER := 39;
   PUT_DONE			CONSTANT NUMBER := 87;
   CTE_RTN_BTCH_FLG_OFF		CONSTANT NUMBER := 144;
   LM_BATCH_UPD_FAIL		CONSTANT NUMBER := 145;
   NO_LM_BATCH_FOUND		CONSTANT NUMBER := 146;
   LM_ACTIVE_BATCH		CONSTANT NUMBER := 153;
   PAL_DMG_NO_TBATCH		CONSTANT NUMBER := 268;
   LM_OVER_LPS_PER_BATCH	CONSTANT NUMBER := 335;

   NUM_PALLETS_MSKU		CONSTANT NUMBER := 60;

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ------------------------------------------------------------------------
   -- Function:
   --    find_pallet_batch
   --
   -- Description:
   --    Look for an existing batch and its total cube according to the input
   --    seq_no for a return.
   --
   -- Parameters:
   --    piPrcSeqNo (input)
   --      The returned control seq_no to be searched
   --    poszBatchNo (output)
   --      Batch # to be returned. NULL or a valid batch #.
   --    poiBatchCube (output)
   --      Total batch cube related to the seq_no to be returned. 0 or > 0.
   --    poiStatus (output)
   --      0: The batch is found
   --      <> 0: Batch is not found or database error happens. gszPkgMessage is
   --            set.
   --
   ------------------------------------------------------------------------
   PROCEDURE find_pallet_batch(
     piPrcSeqNo   IN pallet_ret_cntrl.prc_seq_no%TYPE,
     poszBatchNo  OUT putawaylst.parent_pallet_id%TYPE,
     poiBatchCube OUT batch.kvi_cube%TYPE,
     poiStatus    OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    create_pallet_batch
   --
   -- Description:
   --    Get the next unique T batch # and insert information to BATCH table.
   --
   -- Parameters:
   --    piPrcSeqNo (input)
   --      The returned control seq_no to be inserted 
   --    pszJobCode (input)
   --      Job code to be inserted
   --    pszDoor (input)
   --      Door # or location to be inserted (into kvi_from_loc)
   --    poszBatchNo (output)
   --      New Batch # to be returned. NULL or a unique batch #.
   --    poiStatus (output)
   --      0: The new batch # is inserted to BATCH table.
   --      <> 0: Database error happens. gszPkgMessage is set.
   --
   ------------------------------------------------------------------------
   PROCEDURE create_pallet_batch(
     piPrcSeqNo  IN pallet_ret_cntrl.prc_seq_no%TYPE,
     pszJobCode  IN batch.jbcd_job_code%TYPE,
     pszDoor	 IN batch.kvi_from_loc%TYPE,
     poszBatchNo OUT putawaylst.parent_pallet_id%TYPE,
     poiStatus   OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    attach_line_item_to_batch
   --
   -- Description:
   --    Add the input batch # to PUTAWAYLST table according to the pallet ID.
   --
   -- Parameters:
   --    pszPalletID (input)
   --      The pallet ID to be searched from PUTAWAYLST table.
   --    pszBatchNo (input)
   --      Batch # to be updated into PUTAWAYLST.PALLET_BATCH_NO.
   --    poiStatus (output)
   --      0: The update to PUTAWAYLST table is ok.
   --      <> 0: The pallet is not found or database error happens.
   --            gszPkgMessage is set.
   --
   ------------------------------------------------------------------------
   PROCEDURE attach_line_item_to_batch(
     pszPalletID IN putawaylst.pallet_id%TYPE,
     pszBatchNo  IN putawaylst.parent_pallet_id%TYPE,
     poiStatus   OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    get_rtn_cntrl
   --
   -- Description:
   --    Overloaded function to retrieve all data from PALLET_RET_CNTRL table
   --    according to the input seq_no.
   --
   -- Parameters:
   --    piPrcSeqNo (input)
   --      The returned control seq_no to be searched
   --    poRow (output)
   --      All record information pertaining to the found seq_no or NULL.
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      0: The record is found
   --      <> 0: The record is not found or database error happens.
   --            gszPkgMessage is set.
   --
   ------------------------------------------------------------------------
   PROCEDURE get_rtn_cntrl(
     piPrcSeqNo IN pallet_ret_cntrl.prc_seq_no%TYPE,
     poRow      OUT pallet_ret_cntrl%ROWTYPE,
     poszErrMsg OUT VARCHAR2,
     poiStatus  OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    get_rtn_cntrl
   --
   -- Description:
   --    Overloaded function to retrieve all data from PALLET_RET_CNTRL table
   --    according to the inputs from aisle and to aisle.
   --
   -- Parameters:
   --    pszFmAisle (input)
   --      The from aisle (or the 1st 2 characters of the location) to be
   --      searched
   --    pszToAisle (input)
   --      The to aisle (or the 1st 2 characters of the location) to be
   --      searched. If the value is not provided, it will be defaulted to the
   --      value of the from aisle.
   --    poRow (output)
   --      All record information pertaining to the found aisles or NULL.
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      0: The record is found
   --      <> 0: The record is not found or database error happens.
   --            gszPkgMessage is set.
   --
   ------------------------------------------------------------------------
   PROCEDURE get_rtn_cntrl(
     pszFmAisle IN pallet_ret_cntrl.from_aisle%TYPE,
     pszToAisle IN pallet_ret_cntrl.to_aisle%TYPE DEFAULT NULL,
     poRow      OUT pallet_ret_cntrl%ROWTYPE,
     poszErrMsg OUT VARCHAR2,
     poiStatus  OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    get_rtn_cntrl
   --
   -- Description:
   --    Overloaded function to retrieve all data from PALLET_RET_CNTRL table
   --    according to the input valid location (not aisle).
   --
   -- Parameters:
   --    pszLoc (input)
   --      The location to be searched
   --    poRow (output)
   --      All record information pertaining to the found seq_no or NULL.
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      0: The record is found
   --      <> 0: The record is not found or database error happens.
   --            gszPkgMessage is set.
   --
   ------------------------------------------------------------------------
   PROCEDURE get_rtn_cntrl(
     pszLoc     IN loc.logi_loc%TYPE,
     poRow      OUT pallet_ret_cntrl%ROWTYPE,
     poszErrMsg OUT VARCHAR2,
     poiStatus  OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    get_rtn_cntrl
   --
   -- Description:
   --    Overloaded function to retrieve all data from PALLET_RET_CNTRL table
   --    according to the input job code. Since the same job code can be used
   --    in different aisles, an array of PALLET_RET_CNTRL table rows must be
   --    returned.
   --
   -- Parameters:
   --    pszJobCode (input)
   --      The job code to be searched
   --    poiNumRows (output)
   --      # of PALLET_RET_CNTRL table rows matched the job code. 0 or > 0.
   --    poRows (output)
   --      All record information pertaining to the job code.
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      0: At least one record is found
   --      <> 0: No record is found or database error happens.
   --            gszPkgMessage is set.
   --
   ------------------------------------------------------------------------
   PROCEDURE get_rtn_cntrl(
     pszJobCode IN pallet_ret_cntrl.job_code%TYPE,
     poiNumRows OUT NUMBER,
     poRows     OUT ttabRetCtlRows,
     poszErrMsg OUT VARCHAR2,
     poiStatus  OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    create_rtn_lm_batches
   --
   -- Description:
   --    Overloaded function to create Labor Management batches for the input
   --    manifest #. Return a total count and its array of batch #s and whether
   --    the indicated batch needs to have worksheet print also. Basically the
   --    procedure calls its another overloaded procedure for each pallet ID
   --    on the input manifest #.
   --
   -- Parameters:
   --    piMfNo (input)
   --      The valid manifest # to be used to create LM batches.
   --    poiNumRows (output)
   --      # of existing or new batch #s to be returned. 0 or > 0.
   --    poszBatches (output)
   --      An array of batch #s and worksheet flags to be returned.
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      0: The LM batches are created ok.
   --      <> 0: At least one LM batch is not found or cannot be created or
   --            database error happens. gszPkgMessage is set.
   --
   ------------------------------------------------------------------------
   PROCEDURE create_rtn_lm_batches(
     piMfNo        IN manifests.manifest_no%TYPE,
     poiNumBatches OUT NUMBER,
     poszBatches   OUT ttabBatches,
     poszErrMsg    OUT VARCHAR2,
     poiStatus     OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    create_rtn_lm_batches
   --
   -- Description:
   --    Overloaded function to create a Labor Management batch for the input
   --    pallet ID. Return a total count and its array of batch #s and whether
   --    the indicated batch needs to have worksheet print also.
   --
   -- Parameters:
   --    pszPalletID (input)
   --      The pallet ID to be used to create a LM batch.
   --    poiNumRows (output)
   --      # of existing or new batch #s to be returned. 0 or > 0.
   --    poszBatches (output)
   --      An array of batch #s and worksheet flags to be returned.
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      0: The LM batch is created ok.
   --      <> 0: At least one LM batch is not found or cannot be created or
   --            database error happens. gszPkgMessage is set.
   --
   ------------------------------------------------------------------------
   PROCEDURE create_rtn_lm_batches(
     pszPalletID   IN inv.logi_loc%TYPE,
     poiNumBatches IN OUT NUMBER,
     poszBatches   IN OUT ttabBatches,
     poszErrMsg    OUT VARCHAR2,
     poiStatus     OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    get_batch_no
   --
   -- Description:
   --    Overloaded function to get all the T-batches (including null or
   --    nonull) for the input manifest_no.
   --
   -- Parameters:
   --    piMfNo (input)
   --      The manifest # that is used for search the T-batches.
   --    poszBatches (output)
   --      An array of batch #s and worksheet flags to be returned. The # of
   --      batches can be retrieved from the poszBatches.COUNT function. The
   --      worksheet and newBatch flags are set to 'N's since there will have
   --      no use for the caller.
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      0: All LM batches (null or nonnull) related to the manifest # are
   --         retrieved ok.
   --      NO_LM_BATCH_FOUND: At least one LM batch is not found or cannot be
   --         retrieved due to database error happens. gszPkgMessage is set.
   --
   ------------------------------------------------------------------------
   PROCEDURE get_batch_no(
     piMfNo      IN manifests.manifest_no%TYPE,
     poszBatches OUT ttabBatches,
     poszErrMsg  OUT VARCHAR2,
     poiStatus   OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    get_batch_no
   --
   -- Description:
   --    Overloaded function to get a particular T-batch (either null or
   --    nonull) for the input manifest_no, item #, cust_pref_vendor and line #.
   --
   -- Parameters:
   --    piMfNo (input)
   --      The manifest # that is used for search the T-batches.
   --    pszItem, pszCpv (input)
   --      The item # and its cust_pref_vendor to be used for T-batch search.
   --    piLineNo (input)
   --      The line # to be used for T-batch search.
   --    poszBatch (output)
   --      One batch record to be returned if data is found or null will be
   --      returned.
   --    poszDmgID (output)
   --      Contains the pallet_id if the pallet is a damage return or NULL if
   --      not.
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      0: The search return exactly one record, no matter if the T-batch #
   --         in the found record is null or not.
   --      NO_LM_BATCH_FOUND: batch is not found or cannot be retrieved due to
   --         database error happens. gszPkgMessage is set.
   --
   -- Modification History:
   --    Date	  Name	 Comments
   --    02/06/06 prplhj D#12055 Add parameter poszDmgID to handle damage
   --			 return pallet.
   --
   ------------------------------------------------------------------------
   PROCEDURE get_batch_no(
     piMfNo     IN manifests.manifest_no%TYPE,
     pszItem    IN pm.prod_id%TYPE,
     pszCpv     IN pm.cust_pref_vendor%TYPE,
     piLineNo   IN putawaylst.erm_line_id%TYPE,
     poszBatch  OUT trecBatches,
     poszDmgID  OUT inv.logi_loc%TYPE,
     poszErrMsg OUT VARCHAR2,
     poiStatus  OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    get_batch_no
   --
   -- Description:
   --    Overloaded function to get a particular batch # (either null or
   --    nonull) for the input pallet ID from PUTAWAYLST table.
   --
   -- Parameters:
   --    pszPalletID (input)
   --      The pallet ID that is used for retrieving the batch #.
   --    poszBatchNo (output)
   --      The found batch # or null if error occurred or no batch #.
   --    poszDmgID (output)
   --      Contains the pallet_id if the pallet is a damage return or NULL if
   --      not.
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      0: The retrival perform successfully with nonnull batch #.
   --      NO_LM_BATCH_FOUND: batch is not found or cannot be retrieved due to
   --         database error happens. gszPkgMessage is set.
   --
   -- Modification History:
   --    Date	  Name	 Comments
   --    02/06/06 prplhj D#12055 Add parameter poszDmgID to handle damage
   --			 return pallet.
   --
   ------------------------------------------------------------------------
   PROCEDURE get_batch_no(
     pszPalletID IN putawaylst.pallet_id%TYPE,
     poszBatchNo OUT putawaylst.parent_pallet_id%TYPE,
     poszDmgID   OUT inv.logi_loc%TYPE,
     poszErrMsg  OUT VARCHAR2,
     poiStatus   OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    client_merge_pallet_batches
   --
   -- Description:
   --    Merge a list of pallet IDs or batch #s from the 2nd listed pallet IDs
   --    or batch #s to the 1st listed pallet ID or batch #. This function is
   --    mainly used by caller that cannot accept PL/SQL table (of either
   --    pallet IDs or batch #s) but a long string of characters as inputs.
   --    The function then seperate the inputs into individual value fields
   --    according to the input value size (piValueSize) and then call the
   --    actual processing function merge_pallet_batches().
   --
   -- Parameters:
   --    piNumValues (input)
   --      # of input pallet IDs or batch #s to be merged together.
   --    pszValues (input)
   --      List of pallet IDs or batch #s to be merged together. The 1st member
   --      in the list serves as the destination batch # to be merged with. The
   --      other members of the list serve as the source batch #s to be merged
   --      with the destination batch #. Each member is in fixed length denoting
   --      by the value piValueSize so the function can seperate them easily.
   --    piValueSize (input)
   --      The maximum size of each member in pszValues. It's used to do
   --      seperation on the pszValues string.
   --    piBatchFlag (input)
   --      Denote if pallet ID is the input (nonnull value) or batch # is the
   --      input (null value and as default.)
   --    poszBadValue (output)
   --      The bad license plate or batch # that cannot be merged due to errors
   --      or if successful, the found batch # from the 1st member of the list.
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      ORACLE_NORMAL: The merge is ok
   --      -20001: Only one input pallet or batch #. No merge is done.
   --      -20002: Duplicated batch # encountered or source batch # has the same
   --              batch # as the destination batch #.
   --      other nonzero values: Database problems
   --
   ------------------------------------------------------------------------
   PROCEDURE client_merge_pallet_batches(
     piNumValues  IN NUMBER,
     pszValues    IN VARCHAR2,
     piValueSize  IN NUMBER,
     piBatchFlag  IN NUMBER DEFAULT 0,
     poszBadValue OUT VARCHAR2,
     poszErrMsg   OUT VARCHAR2,
     poiStatus    OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    merge_pallet_batches
   --
   -- Description:
   --    Merge a list of pallet IDs or batch #s from the 2nd listed pallet IDs
   --    or batch #s to the 1st listed pallet ID or batch #. The PUTAWAYLST
   --    table parent_pallet_id values from the 2nd list will be updated to
   --    the 1st matched batch # from the list. The BATCH kvi values will be
   --    recalculated to refect the updates.
   --
   -- Parameters:
   --    piNumValues (input)
   --      # of input pallet IDs or batch #s to be merged together.
   --    pszValues (input)
   --      List of pallet IDs or batch #s to be merged together. The 1st member
   --      in the list serves as the destination batch # to be merged with. The
   --      other members of the list serve as the source batch #s to be merged
   --      with the destination batch #.
   --    piBatchFlag (input)
   --      Denote if pallet ID is the input (nonnull value) or batch # is the
   --      input (null value and as default.)
   --    poszBadValue (output)
   --      The bad license plate or batch # that cannot be merged due to errors
   --      or if successful, the found batch # from the 1st member of the list.
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      ORACLE_NORMAL: The merge is ok
   --      -20001: Only one input pallet or batch #. No merge is done.
   --      -20002: Duplicated batch # encountered or source batch # has the same
   --              batch # as the destination batch #.
   --      other nonzero values: Database problems
   --
   ------------------------------------------------------------------------
   PROCEDURE merge_pallet_batches(
     piNumValues  IN NUMBER,
     pszValues    IN ttabValues,
     piBatchFlag  IN NUMBER DEFAULT 0,
     poszBadValue OUT VARCHAR2,
     poszErrMsg   OUT VARCHAR2,
     poiStatus    OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    close_pallet_batch
   --
   -- Description:
   --    Accumulate the total counts of some fields for the input batch # or
   --    input license plate from PUTAWAYLST table (load_pallet_batch()) and
   --    update the goal time and target time for the batch and also set the
   --    batch to 'F' status.
   --
   -- Parameters:
   --    pszValue (input)
   --      Batch # or Pallet ID to be used for update.
   --    piBatchFlag (input)
   --      Flag to indicate whether the input pszValue is a pallet ID (nonnull
   --      value) or a batch # (null value).
   --    piCallDirect (input)
   --      Flag to indicate whether the the procedure is a direct call by the
   --      caller (default as 0) or an indirect call by other procedure(s)
   --      inside this package (<> 0.)
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      0: The retrival perform successfully with nonnull batch #.
   --      <> 0: batch is not found or cannot be retrieved due to
   --         database error happens. gszPkgMessage is set.
   --
   ------------------------------------------------------------------------
   PROCEDURE close_pallet_batch(
     pszValue		IN VARCHAR2,
     piBatchFlag	IN NUMBER DEFAULT 0,
     piCallDirect	IN NUMBER DEFAULT 0,
     poszErrMsg		OUT VARCHAR2,
     poiStatus		OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    unload_pallet_batch
   --
   -- Description:
   --    Subtract the KVI values for the input batch # or for the input
   --    license plate (if flag is set) from BATCH. If all kvi values related
   --    to the found batch is 0, the batch will be deleted from the system and
   --    the parent_pallet_ids of all returned putaway tasks related to the
   --    batch will be updated to NULL. 
   --
   -- Parameters:
   --    pszValue (input)
   --      Current batch #/pallet ID to be used for update.
   --    piBatchFlag (input)
   --      Denote if pallet ID is the input (nonnull value) or batch # is the
   --      input (null value and as default.)
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      0: The update perform successfully with nonnull batch #.
   --      <> 0: batch is not found or cannot be retrieved due to
   --         database error happens. gszPkgMessage is set.
   --
   ------------------------------------------------------------------------
   PROCEDURE unload_pallet_batch(
     pszValue    IN VARCHAR2,
     piBatchFlag IN NUMBER DEFAULT 0,
     poszErrMsg  OUT VARCHAR2,
     poiStatus   OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    check_pallet_batch
   --
   -- Description:
   --    Check the input pallet ID or batch # to see if the pallet is a damage
   --    return or the pallet has been confirmed putawayed. If the pallet is
   --    not a damage return and hasn't been putawayed, the batch # will be
   --    returned.
   --
   -- Parameters:
   --    pszValue (input)
   --      Batch # or Pallet ID to be used for search.
   --    piBatchFlag (input)
   --      Flag to indicate whether the input pszValue is a pallet ID (nonnull
   --      value) or a batch # (null value).
   --    poszBatchNo (output)
   --      The returned batch # that pass simple validation.
   --    poszErrMsg (output)
   --      NULL or error message if error happens
   --    poiStatus (output)
   --      0: The retrival perform successfully with nonnull batch #.
   --      NO_LM_BATCH_FOUND: If the pallet/batch cannot be found from
   --        PUTAWAYLST.
   --      PUT_DONE: If the pallet/batch has been confirmed putawayed.
   --      INV_LABEL: If the pallet/batch is a damage return.
   --      <> 0: Database errors. gszPkgMessage is set.
   --
   ------------------------------------------------------------------------
   PROCEDURE check_pallet_batch(
     pszValue	 IN VARCHAR2,
     piBatchFlag IN NUMBER DEFAULT 0,
     poszBatchNo OUT putawaylst.parent_pallet_id%TYPE,
     poszErrMsg  OUT VARCHAR2,
     poiStatus   OUT NUMBER);

   ------------------------------------------------------------------------
   -- Function:
   --    reset_rtn_lm_batch
   --
   -- Description:
   --    Reset LM batch information according to the input batch #, merge flag
   --    and user ID.
   --
   -- Parameters:
   --    poszBatchNo (input)
   --      Batch # to be used for update.
   --    poszMergeFlag (input)
   --      Merge flag (Y or N) to be used for update.
   --    poszUser (input)
   --      User ID to be used for update.
   --
   -- Returns:
   --    0: The update is ok
   --    <> 0: Batch # is not found or database error happens. gszPkgMessage is
   --          set. Return values are LM_BATCH_UPDATE_FAIL, NO_LM_BATCH_FOUND or
   --          other values.
   --
   ------------------------------------------------------------------------
   FUNCTION reset_rtn_lm_batch(
     pszBatchNo   IN putawaylst.parent_pallet_id%TYPE,
     pszMergeFlag IN VARCHAR2 DEFAULT 'N',
     pszUser      IN usr.user_id%TYPE DEFAULT USER)
   RETURN NUMBER;

   ------------------------------------------------------------------------
   -- Function:
   --    move_puts_to_batch
   --
   -- Description:
   --    Update the input current batch # to the input new batch # in PUTAWAYLST
   --    table.
   --    target time for the batch.
   --
   -- Parameters:
   --    pszCurBatchNo (input)
   --      Current batch # to be used for update.
   --    pszNewBatchNo (input)
   --      New batch # to be used for update.
   --
   -- Returns:
   --    0: The update is ok
   --    <> 0: Batch # is not found or database error happens. gszPkgMessage is
   --          set.
   --
   ------------------------------------------------------------------------
   FUNCTION move_puts_to_batch(
     pszCurBatchNo IN putawaylst.parent_pallet_id%TYPE,
     pszNewBatchNo IN putawaylst.parent_pallet_id%TYPE)
   RETURN NUMBER;

   ------------------------------------------------------------------------
   -- Function:
   --    load_pallet_batch
   --
   -- Description:
   --    Retrieve specific values from PUTAWAYLST for the current input pallet
   --    ID or batch # and update the values to specific kvi values for BATCH
   --    table.
   --
   -- Parameters:
   --    pszValue (input)
   --      Current batch #/pallet ID to be used for update.
   --    piBatchFlag (input)
   --      Denote if pallet ID is the input (nonnull value) or batch # is the
   --      input (null value and as default.)
   --
   -- Returns:
   --    0: The update is ok
   --    <> 0: Batch # is not found or database error happens. gszPkgMessage is
   --          set.
   --
   ------------------------------------------------------------------------
   FUNCTION load_pallet_batch(
     pszValue    IN VARCHAR2,
     piBatchFlag IN NUMBER DEFAULT 0)
   RETURN NUMBER;

   ------------------------------------------------------------------------
   -- Function:
   --    get_pkg_errors
   --
   -- Description:
   --    Get the error message produced by the package.
   --
   -- Parameters:
   --    None
   --
   -- Returns:
   --    NULL or contents in gszPkgMessage.
   --
   ------------------------------------------------------------------------
   FUNCTION get_pkg_errors
   RETURN VARCHAR2;

   ------------------------------------------------------------------------
   -- Function:
   --    get_pkg_code
   --
   -- Description:
   --    Get the current giCode value set by the package.
   --
   -- Parameters:
   --    None
   --
   -- Returns:
   --    NULL, 0 or public constants
   --
   ------------------------------------------------------------------------
   FUNCTION get_pkg_code
   RETURN NUMBER;

   ------------------------------------------------------------------------
   -- Function:
   --    check_rtn_lm_syspars
   --
   -- Description:
   --    Retrieve and check Returns LM related syspars (LBR_MGMT_FLAG,
   --    LBR_FUNC.CREATE_BATCH_FLAG (RP)).
   --
   -- Parameters:
   --    None
   --
   -- Returns:
   --    trecRtnLmFlags record with syspar values.
   --
   ------------------------------------------------------------------------
   FUNCTION check_rtn_lm_syspars
   RETURN trecRtnLmFlags;

   ------------------------------------------------------------------------
   -- Function:
   --    delete_pallet_batch
   --
   -- Description:
   --    The function delete the batch from BATCH table according to the input
   --    criteria. The input is either a batch # (if piBatchFlag = 0) or a
   --    pallet ID. If piForceDeleteFlag is set, the found batch # will be
   --    deleted from BATCH table even if at least one of its kvi values has
   --    nonzero value.
   --
   -- Parameters:
   --    pszValue (input)
   --      Current batch #/pallet ID to be used for update.
   --    piBatchFlag (input)
   --      Denote if pallet ID is the input (nonnull value) or batch # is the
   --      input (null value and as default.)
   --
   -- Returns:
   --    0: Criteria is met and deletion is performed.
   --    <> 0: The batch is not found or database error occurred.
   --
   ------------------------------------------------------------------------
   FUNCTION delete_pallet_batch (
     pszValue		IN VARCHAR2,
     piBatchFlag	IN NUMBER DEFAULT 0,
     piForceDeleteFlag	IN NUMBER DEFAULT 0)
   RETURN NUMBER;

   ------------------------------------------------------------------------
   -- Function:
   --    check_pallets_limit
   --
   -- Description:
   --    Retrieve the # of pallets currently in the input batch #.
   --
   -- Parameters:
   --    pszBatchNo (input)
   --      Current batch # to be used for search.
   --
   -- Returns:
   --   -1: Database error occurred.
   --    0: No pallets for the batch or no input batch #.
   --  > 0: # of pallets for the input batch # so far.
   --
   ------------------------------------------------------------------------
   FUNCTION check_pallets_limit (
     pszBatchNo		IN putawaylst.parent_pallet_id%TYPE)
   RETURN NUMBER;

END pl_rtn_lm;
/

/**************************************************************************/
-- Package Body
/**************************************************************************/
CREATE OR REPLACE PACKAGE BODY swms.pl_rtn_lm IS

   ---------------------------------------------------------------------------
   -- Package body used-only structures
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Package body used-only global variables
   ---------------------------------------------------------------------------

   ORACLE_NOT_FOUND	CONSTANT NUMBER := 1403;
   ANSI_NOT_FOUND	CONSTANT NUMBER := 100;
   ORACLE_NORMAL	CONSTANT NUMBER := 0;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE find_pallet_batch(
  piPrcSeqNo   IN pallet_ret_cntrl.prc_seq_no%TYPE,
  poszBatchNo  OUT putawaylst.parent_pallet_id%TYPE,
  poiBatchCube OUT batch.kvi_cube%TYPE,
  poiStatus    OUT NUMBER) IS
  szFuncName	VARCHAR2(50) := 'find_pallet_batch';
  szBatchNo	putawaylst.parent_pallet_id%TYPE := NULL;
  iCube		NUMBER := 0;
BEGIN
  poszBatchNo := NULL;
  poiBatchCube := 0;
  poiStatus := ORACLE_NORMAL;
  gszPkgMessage := NULL;

  -- Search the T-batch for the input seq_no
  BEGIN
    SELECT b.batch_no INTO szBatchNo
    FROM batch b
    WHERE b.ref_no = TO_CHAR(piPrcSeqNo)
    AND   b.status = 'X'
    AND   b.batch_no >= 'T'
    AND   b.batch_no < 'U';
    DBMS_OUTPUT.PUT_LINE('Find batch ' || szBatchNo || ' for seq ' ||
      TO_CHAR(piPrcSeqNo) || ' status ' || TO_CHAR(SQLCODE) || ' cnt ' ||
      TO_CHAR(SQL%ROWCOUNT));
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Cannot find batch for seq ' ||
        TO_CHAR(piPrcSeqNo) || ' status: ' || TO_CHAR(SQLCODE));
      poiStatus := SQLCODE;
      gszPkgMessage := 'Cannot find Returns batch for seq_no ' ||
        TO_CHAR(piPrcSeqNo);
      pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
  END;

  -- Batch is found. Get its total cube
  BEGIN
    SELECT SUM(pt.qty * p.case_cube / p.spc) INTO iCube 
    FROM pm p, putawaylst pt
    WHERE p.prod_id = pt.prod_id
    AND p.cust_pref_vendor = pt.cust_pref_vendor
    AND pt.parent_pallet_id = szBatchNo
    AND pt.putaway_put = 'N'
    GROUP BY pt.parent_pallet_id;
    poiBatchCube := iCube;
    DBMS_OUTPUT.PUT_LINE('Get cube ' || TO_CHAR(iCube) || ' for batch ' ||
      szBatchNo);
  EXCEPTION
    WHEN OTHERS THEN
      poiBatchCube := 0;
      poiStatus := SQLCODE;
      DBMS_OUTPUT.PUT_LINE('Find_pallet_batch cannot get total cube for seq ' ||
        TO_CHAR(piPrcSeqNo) || ' batch ' || szBatchNo || ' status ' ||
        TO_CHAR(SQLCODE));
      gszPkgMessage := 'Cannot get Returns batch total cube for seq: ' ||
        TO_CHAR(piPrcSeqNo) || ', batch: ' || szBatchNo;
      pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
  END;

  poszBatchNo := szBatchNo;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE create_pallet_batch(
  piPrcSeqNo  IN pallet_ret_cntrl.prc_seq_no%TYPE,
  pszJobCode  IN batch.jbcd_job_code%TYPE,
  pszDoor     IN batch.kvi_from_loc%TYPE,
  poszBatchNo OUT putawaylst.parent_pallet_id%TYPE,
  poiStatus   OUT NUMBER) IS
  szFuncName	VARCHAR2(50) := 'create_pallet_batch';
  szBatchNo	putawaylst.parent_pallet_id%TYPE := NULL;
BEGIN
  poszBatchNo := NULL;
  poiStatus := ORACLE_NORMAL;
  gszPkgMessage := NULL;

  pl_log.ins_msg('D', szFuncName,
                 'Creating batch for prcSeq: ' || TO_CHAR(piPrcSeqNo) ||
                 ', jobc: ' || pszJobCode, NULL, NULL);

  -- Retrieve a unique T batch #
  BEGIN
    SELECT 'T' || LTRIM(TO_CHAR(pallet_batch_no_seq.NEXTVAL)) INTO szBatchNo
    FROM DUAL;
  EXCEPTION
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      gszPkgMessage := 'Cannot get next T batch_no from pallet_batch_no_seq';
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
  END;

  -- Next unique T batch # is retrieved. Create the batch
  BEGIN
    INSERT INTO batch(batch_no, batch_date, status,
                      ref_no, jbcd_job_code, kvi_from_loc)
      VALUES(szBatchNo, TRUNC(SYSDATE), 'X',
             LTRIM(TO_CHAR(piPrcSeqNo)), pszJobCode, pszDoor);
    gszPkgMessage := 'create_pallet_batch T batch: ' || szBatchNo ||
                     ', prcSeq: ' || TO_CHAR(piPrcSeqNo) || ', jobc: ' ||
                     pszJobCode || ', door: ' || pszDoor || ' insert on ' ||
                     TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS');
    pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
  EXCEPTION
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      gszPkgMessage := 'Cannot create T batch for batch_no: ' || szBatchNo ||
                       ', prcSeq: ' || TO_CHAR(piPrcSeqNo) || ', jobc: ' ||
                       pszJobCode || ', door: ' || pszDoor;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
  END;

  pl_log.ins_msg('D', szFuncName,
                 'Batch for prcSeq: ' || TO_CHAR(piPrcSeqNo) ||
                 ', jobc: ' || pszJobCode || ' created', NULL, NULL);

  poszBatchNo := szBatchNo;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE attach_line_item_to_batch(
  pszPalletID IN putawaylst.pallet_id%TYPE,
  pszBatchNo  IN putawaylst.parent_pallet_id%TYPE,
  poiStatus   OUT NUMBER) IS
  szFuncName	VARCHAR2(50) := 'attach_line_item_to_batch';
BEGIN
  poiStatus := ORACLE_NORMAL;
  gszPkgMessage := NULL;

  pl_log.ins_msg('D', szFuncName,
                 'Attaching line item for batch_no: ' || pszBatchNo ||
                 ', palletID: ' || pszPalletID, NULL, NULL);

  UPDATE putawaylst
  SET pallet_batch_no = pszBatchNo,
      parent_pallet_id = pszBatchNo
  WHERE pallet_id = pszPalletID;

  pl_log.ins_msg('D', szFuncName,
                 'Batch for batch_no: ' || pszBatchNo ||
                 ', palletID: ' || pszPalletID || ' attached', NULL, NULL);
EXCEPTION
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
    gszPkgMessage := 'Cannot update PUTAWAYLST for batch_no: ' || pszBatchNo ||
                     ', pallet: ' || pszPalletID;
    pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
END;


/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE get_rtn_cntrl(
  piPrcSeqNo IN pallet_ret_cntrl.prc_seq_no%TYPE,
  poRow      OUT pallet_ret_cntrl%ROWTYPE,
  poszErrMsg OUT VARCHAR2,
  poiStatus  OUT NUMBER) IS
  szFuncName	VARCHAR2(50) := 'get_rtn_cntrl(prcSeqNo)';
BEGIN
  poiStatus := ORACLE_NORMAL;
  poRow := NULL;
  poszErrMsg := NULL;
  gszPkgMessage := NULL;

  SELECT from_aisle, to_aisle, pallet_cube,
         report_queue, label_queue, job_code, piPrcSeqNo,
         stage_loc
  INTO poRow.from_aisle, poRow.to_aisle, poRow.pallet_cube,
       poRow.report_queue, poRow.label_queue, poRow.job_code, poRow.prc_seq_no,
       poRow.stage_loc
  FROM pallet_ret_cntrl
  WHERE prc_seq_no = piPrcSeqNo;
EXCEPTION
  WHEN TOO_MANY_ROWS THEN
    poiStatus := SQLCODE;
    gszPkgMessage := 'More than 1 record match seq: ' || TO_CHAR(piPrcSeqNo);
    poszErrMsg := gszPkgMessage;
    pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
    gszPkgMessage := 'Cannot get PALLET_RET_CNTRL info for seq: ' ||
                     TO_CHAR(piPrcSeqNo);
    poszErrMsg := gszPkgMessage;
    pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE get_rtn_cntrl(
  pszFmAisle IN pallet_ret_cntrl.from_aisle%TYPE,
  pszToAisle IN pallet_ret_cntrl.to_aisle%TYPE DEFAULT NULL,
  poRow      OUT pallet_ret_cntrl%ROWTYPE,
  poszErrMsg OUT VARCHAR2,
  poiStatus  OUT NUMBER) IS
  szFuncName	VARCHAR2(50) := 'get_rtn_cntrl(aisle)';
  szToAisle	pallet_ret_cntrl.to_aisle%TYPE := pszToAisle;
BEGIN
  poiStatus := ORACLE_NORMAL;
  poRow := NULL;
  poszErrMsg := NULL;
  gszPkgMessage := NULL;

  -- No To aisle is present, set it like from aisle
  IF pszToAisle IS NULL THEN
    szToAisle := pszFmAisle;
  END IF;
  SELECT pszFmAisle, szToAisle, pallet_cube,
         report_queue, label_queue, job_code, prc_seq_no,
         stage_loc
  INTO poRow.from_aisle, poRow.to_aisle, poRow.pallet_cube,
       poRow.report_queue, poRow.label_queue, poRow.job_code, poRow.prc_seq_no,
       poRow.stage_loc
  FROM pallet_ret_cntrl
  WHERE from_aisle = pszFmAisle
  AND   to_aisle = pszToAisle;
EXCEPTION
  WHEN TOO_MANY_ROWS THEN
    poiStatus := SQLCODE;
    gszPkgMessage := 'More than 1 record match from aisle: ' || pszFmAisle ||
                     ' to ' || szToAisle;
    poszErrMsg := gszPkgMessage;
    pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
    gszPkgMessage := 'Cannot get PALLET_RET_CNTRL info for aisle(s): ' ||
                     pszFmAisle || ' to ' || szToAisle;
    poszErrMsg := gszPkgMessage;
    pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE get_rtn_cntrl(
  pszLoc     IN loc.logi_loc%TYPE,
  poRow      OUT pallet_ret_cntrl%ROWTYPE,
  poszErrMsg OUT VARCHAR2,
  poiStatus  OUT NUMBER) IS
  szFuncName	VARCHAR2(50) := 'get_rtn_cntrl(loc)';
BEGIN
  poiStatus := ORACLE_NORMAL;
  poRow := NULL;
  poszErrMsg := NULL;
  gszPkgMessage := NULL;

  SELECT from_aisle, to_aisle, pallet_cube,
         report_queue, label_queue, job_code, prc_seq_no,
         stage_loc
  INTO poRow.from_aisle, poRow.to_aisle, poRow.pallet_cube,
       poRow.report_queue, poRow.label_queue, poRow.job_code, poRow.prc_seq_no,
       poRow.stage_loc
  FROM pallet_ret_cntrl
  WHERE SUBSTR(pszLoc, 1, 2) BETWEEN from_aisle AND to_aisle;
EXCEPTION
  WHEN TOO_MANY_ROWS THEN
    poiStatus := SQLCODE;
    gszPkgMessage := 'More than 1 record match from loc: ' || pszLoc;
    poszErrMsg := gszPkgMessage;
    pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
    gszPkgMessage := 'Cannot get PALLET_RET_CNTRL info for loc: ' || pszLoc;
    poszErrMsg := gszPkgMessage;
    pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE get_rtn_cntrl(
  pszJobCode IN pallet_ret_cntrl.job_code%TYPE,
  poiNumRows OUT NUMBER,
  poRows     OUT ttabRetCtlRows,
  poszErrMsg OUT VARCHAR2,
  poiStatus  OUT NUMBER) IS
  szFuncName	VARCHAR2(50) := 'get_rtn_cntrl(jobCode)';
  iIndex	NUMBER := 0;
  CURSOR c_get_rtncntrls IS
    SELECT from_aisle, to_aisle, pallet_cube,
           report_queue, label_queue, job_code, prc_seq_no, stage_loc
    FROM pallet_ret_cntrl
    WHERE job_code = pszJobCode;
BEGIN
  poiStatus := ORACLE_NORMAL;
  poiNumRows := 0;
  poszErrMsg := NULL;
  gszPkgMessage := NULL;

  iIndex := 1;
  FOR c_retcntrls IN c_get_rtncntrls LOOP
    poRows(iIndex).from_aisle := c_retcntrls.from_aisle;
    poRows(iIndex).to_aisle := c_retcntrls.to_aisle;
    poRows(iIndex).pallet_cube := c_retcntrls.pallet_cube;
    poRows(iIndex).report_queue := c_retcntrls.report_queue;
    poRows(iIndex).label_queue := c_retcntrls.label_queue;
    poRows(iIndex).job_code := c_retcntrls.job_code;
    poRows(iIndex).prc_seq_no := c_retcntrls.prc_seq_no;
    poRows(iIndex).stage_loc := c_retcntrls.stage_loc;
    iIndex := iIndex + 1;
  END LOOP;
  poiNumRows := iIndex;
EXCEPTION
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
    gszPkgMessage := 'Cannot get PALLET_RET_CNTRL info for jobcode: ' ||
                     pszJobCode;
    poszErrMsg := gszPkgMessage;
    pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
END;

/**************************************************************************/
--
-- Function:
--    add_batches
--
-- Description:
--    Add the input location, batch #, worksheet flag and new batch flag to an
--    array for outputs to the caller. If the input batch # already existed in
--    the array before, just update the worksheet flag and the new batch flag;
--    otherwise create a new index for the batch #.
--
-- Parameters:
--    pszLoc (input)
--      Location to be used for search and insert.
--    pszBatchNo (input)
--      Batch # to be used for search and insert.
--    pszWorksheet (input)
--      Worksheet flag (Y to print or N to not print) to be updated or inserted.
--    pszNewBatch (input)
--      New batch # flag (Yes for newly created batch or N for existing one) to
--      be updated or inserted.
--    pioNumBatches (input, output)
--      Total # of array elements accmulated so far. 0 or > 0.
--    pioszBatches (input, output)
--      Array of batch #s and worksheet flags accumulated so far.
--    pszDmgID (input)
--      Whether the to-be-searched or to-be-inserted T-batch belongs to a
--	damage return or not. We still will add to the
--	batch array even if there is a location (pszLoc, as of "DDDDDD"
--	currently) but no batch # (pszBatchNo.) In this case, the caller needs
--	to explicitly input the paramater value as the damage return license
--	plate. Otherwise, the paramater value should always be NULL (default).
--
-- Modification History:
--    Date	Name	Comments
--    02/06/06	prplhj	D#12055 Add parameter pszDmgRtn to handle damage return
--			pallet.
--
/**************************************************************************/
PROCEDURE add_batches(
  pszLoc        IN loc.logi_loc%TYPE,
  pszBatchNo    IN putawaylst.parent_pallet_id%TYPE,
  pszWorksheet  IN VARCHAR2 DEFAULT 'Y',
  pszNewBatch   IN VARCHAR2 DEFAULT 'N',
  pioNumBatches IN OUT NUMBER,
  pioszBatches  IN OUT ttabBatches,
  pszDmgID	IN inv.logi_loc%TYPE DEFAULT NULL) IS
  szFuncName	VARCHAR2(50) := 'add_batches';
  iIndex	NUMBER;
  blnFound	BOOLEAN;
BEGIN
  iIndex := 1;
  blnFound := FALSE;
  -- Only add the batch # in if it is not existed before
  WHILE NOT blnFound AND iIndex <= pioNumBatches LOOP
    IF pioszBatches(iIndex).batchNo = pszBatchNo THEN
      blnFound := TRUE;
    ELSE
      iIndex := iIndex + 1;
    END IF;
  END LOOP;
  IF blnFound THEN
    IF pioszBatches(iIndex).worksheet <> 'Y' THEN
      pioszBatches(iIndex).worksheet := pszWorksheet;
    END IF;
    IF pioszBatches(iIndex).newBatch <> 'Y' THEN
      pioszBatches(iIndex).newBatch := pszNewBatch;
    END IF;
  ELSE
    pioszBatches(iIndex).logi_loc := pszLoc;
    pioszBatches(iIndex).batchNo := pszBatchNo;
    pioszBatches(iIndex).worksheet := pszWorksheet;
    pioszBatches(iIndex).newBatch := pszNewBatch;
    pioNumBatches := iIndex;
  END IF;
  pioszBatches(iIndex).dmgPallet := pszDmgID;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE create_rtn_lm_batches(
  piMfNo        IN manifests.manifest_no%TYPE,
  poiNumBatches OUT NUMBER,
  poszBatches   OUT ttabBatches,
  poszErrMsg    OUT VARCHAR2,
  poiStatus     OUT NUMBER) IS
  szFuncName		VARCHAR2(50) := 'create_rtn_lm_batches(mf)';
  tSyspars		trecRtnLmFlags := NULL;
  iStatus		NUMBER := ORACLE_NORMAL;
  iNumBatches		NUMBER := 0;
  tBatchNos		ttabBatches;
  CURSOR c_get_mf_put_info IS
    SELECT pt.dest_loc, pt.pallet_id
    FROM putawaylst pt
    WHERE pt.parent_pallet_id IS NULL
    AND   SUBSTR(pt.rec_id, 2) = TO_CHAR(piMfNo)
    ORDER BY pt.dest_loc, pt.pallet_id;
BEGIN
  poiNumBatches := 0;
  poiStatus := ORACLE_NORMAL;
  poszErrMsg := NULL;
  gszPkgMessage := NULL;
  giCode := 0;

  -- Retrieve related syspar flags
  tSyspars := check_rtn_lm_syspars;
  IF tSyspars.szLbrMgmtFlag = 'N' OR tSyspars.szCrtBatchFlag = 'N' THEN
    giCode := CTE_RTN_BTCH_FLG_OFF;
    poiStatus := giCode;
    IF tSyspars.szLbrMgmtFlag = 'N' AND tSyspars.szCrtBatchFlag = 'N' THEN
      gszPkgMessage := 'Both LBR_MGMT_FLAG and LBR_FUNC.CREATE_BATCH_FLAG ' ||
                       'are not set';
    ELSIF tSyspars.szLbrMgmtFlag = 'N' THEN
      gszPkgMessage := 'LBR_MGMT_FLAG is not set';
    ELSE
      gszPkgMessage := 'LBR_FUNC.CREATE_BATCH_FLAG is not set';
    END IF;
    poszErrMsg := gszPkgMessage;
    RETURN;
  END IF;

  -- For each pallet without pallet batch yet of the mainfest
  FOR cMfInfo IN c_get_mf_put_info LOOP
    iStatus := ORACLE_NORMAL;
    create_rtn_lm_batches(cMfInfo.pallet_id, iNumBatches, tBatchNos,
                          poszErrMsg, iStatus);
    IF iStatus <> ORACLE_NORMAL THEN
      pl_log.ins_msg('F', szFuncName,
                     'Error calling create_rtn_lm_batches(PalletID) for mf: ' ||
                     TO_CHAR(piMfNo) || ', loc: ' || cMfInfo.dest_loc ||
                     ', pallet: ' || cMfInfo.pallet_id,
                     iStatus, NULL);
    END IF;
    EXIT WHEN iStatus <> ORACLE_NORMAL;
    DBMS_OUTPUT.PUT_LINE('------------');
  END LOOP;

  IF iStatus <> ORACLE_NORMAL THEN
    poiNumBatches := 0;
  ELSE
    poiNumBatches := iNumBatches;
  END IF;
  poszBatches := tBatchNos;
  poiStatus := iStatus;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE create_rtn_lm_batches(
  pszPalletID   IN inv.logi_loc%TYPE,
  poiNumBatches IN OUT NUMBER,
  poszBatches   IN OUT ttabBatches,
  poszErrMsg    OUT VARCHAR2,
  poiStatus     OUT NUMBER) IS
  szFuncName		VARCHAR2(50) := 'create_rtn_lm_batches(PalletID)';
  tSyspars		trecRtnLmFlags := NULL;
  szLoc			loc.logi_loc%TYPE := NULL;
  iLineItemCube		NUMBER := 0;
  iCasePalletCube	NUMBER := 0;
  iTiHiPalletCube	NUMBER := 0;
  iStatus		NUMBER := ORACLE_NORMAL;
  tPalRtnCtl		pallet_ret_cntrl%ROWTYPE := NULL;
  szBatchNo		putawaylst.parent_pallet_id%TYPE := NULL;
  iCurBatchCube		NUMBER := 0;
  blnFound		BOOLEAN;
  iNumBatches		NUMBER := poiNumBatches;
  tBatchNos		ttabBatches := poszBatches;
  szItem		putawaylst.prod_id%TYPE := NULL;
  szMessage		VARCHAR2(2000) := NULL;
  szNewBatch		VARCHAR2(1) := 'N';
  iNumPalletExceeds	NUMBER;
  szRsnGrp		reason_cds.reason_group%TYPE := NULL;
  szBatchStatus		batch.status%TYPE := NULL;
BEGIN
  poiNumBatches := 0;
  poszErrMsg := NULL;
  poiStatus := 0;
  gszPkgMessage := NULL;

  tSyspars := check_rtn_lm_syspars;
  IF tSyspars.szLbrMgmtFlag = 'N' OR tSyspars.szCrtBatchFlag = 'N' THEN
    giCode := CTE_RTN_BTCH_FLG_OFF;
    poiStatus := giCode;
    IF tSyspars.szLbrMgmtFlag = 'N' AND tSyspars.szCrtBatchFlag = 'N' THEN
      gszPkgMessage := 'Both LBR_MGMT_FLAG and LBR_FUNC.CREATE_BATCH_FLAG ' ||
                       'are not set';
    ELSIF tSyspars.szLbrMgmtFlag = 'N' THEN
      gszPkgMessage := 'LBR_MGMT_FLAG is not set';
    ELSE
      gszPkgMessage := 'LBR_FUNC.CREATE_BATCH_FLAG is not set';
    END IF;
    poszErrMsg := gszPkgMessage;
    RETURN;
  END IF;

  -- Get the putaway info from the pallet ID
  BEGIN
    SELECT pt.dest_loc, pt.qty * (p.case_cube / p.spc),
           NVL(p.case_pallet, 100000) * p.case_cube, p.ti * p.hi * p.case_cube,
           pt.prod_id, r.reason_group
    INTO szLoc, iLineItemCube, iCasePalletCube, iTiHiPalletCube, szItem,
         szRsnGrp
    FROM putawaylst pt, pm p, reason_cds r
    WHERE pt.parent_pallet_id IS NULL
    AND   pt.prod_id = p.prod_id
    AND   pt.cust_pref_vendor = p.cust_pref_vendor
    AND   pt.pallet_id = pszPalletID
    AND   pt.reason_code = r.reason_cd
    AND   r.reason_cd_type = 'RTN';
  EXCEPTION
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      gszPkgMessage := 'Error getting PUTAWAYLST info for location: ' ||
                       szLoc || '/' || pszPalletID || ', item: ' || szItem;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
    RETURN;
  END;

  szMessage := 'location: ' || szLoc || '/' || pszPalletID || ', item: ' ||
               szItem;
  DBMS_OUTPUT.PUT_LINE('PalletID: ' || pszPalletID || ', loc: ' ||
    szLoc || ', item: ' || szItem || ', itemCube: ' ||
    TO_CHAR(ROUND(iLineItemCube, 5)) ||
    ', casePalCube: ' || TO_CHAR(ROUND(iCasePalletCube, 5)) ||
    ', tihiPalCube: ' || TO_CHAR(ROUND(iTiHiPalletCube, 5)));

  -- D#11997 Don't create T-batch for damage reason code
  IF szRsnGrp = 'DMG' THEN
    RETURN;
  END IF;

  -- Get the unique seq_no for the location
  get_rtn_cntrl(szLoc, tPalRtnCtl, poszErrMsg, iStatus);
  IF iStatus <> ORACLE_NORMAL THEN
    DBMS_OUTPUT.PUT_LINE('Error retrieving PALLET_RET_CNTRL: ' ||
      TO_CHAR(iStatus));
    poiStatus := iStatus;
    gszPkgMessage := gszPkgMessage || ', ' || szMessage;
    poszErrMsg := gszPkgMessage;
    pl_log.ins_msg('F', szFuncName,
                   'Error getting PALLET_RET_CNTRL info for ' || szMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
    RETURN;
  END IF;

  DBMS_OUTPUT.PUT_LINE('PALLET_RET_CNTRL seq: ' ||
    TO_CHAR(tPalRtnCtl.prc_seq_no) || ', palCube: ' ||
    TO_CHAR(tPalRtnCtl.pallet_cube) || ', jobCode: ' || tPalRtnCtl.job_code ||
    ', door: ' || tPalRtnCtl.stage_loc);

  -- Check if batch exists and also retrieve the found batch total cube
  szNewBatch := 'N';
  find_pallet_batch(tPalRtnCtl.prc_seq_no, szBatchNo, iCurBatchCube,
                    iStatus);
  IF iStatus <> ORACLE_NORMAL AND iStatus <> ORACLE_NOT_FOUND AND
     iStatus <> ANSI_NOT_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Error finding batch_no status: ' ||
      TO_CHAR(iStatus) || ', pallet: ' || pszPalletID || ', seq: ' ||
      TO_CHAR(tPalRtnCtl.prc_seq_no));
    poiStatus := iStatus;
    gszPkgMessage := gszPkgMessage || ', ' || szMessage;
    poszErrMsg := gszPkgMessage;
    pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
    RETURN;
  END IF;

  blnFound := TRUE;
  IF (iStatus = ORACLE_NOT_FOUND) OR (iStatus = ANSI_NOT_FOUND) THEN
    -- Existing Batch not found. Create a new batch. Check if the existing
    -- batch is still in 'X' status. If yes, change to future status so we
    -- won't have multiple batches with X status later on.
    BEGIN
      SELECT status INTO szBatchStatus
      FROM batch
      WHERE batch_no = szBatchNo
      AND   ref_no = tPalRtnCtl.prc_seq_no;
      DBMS_OUTPUT.PUT_LINE('Found batch/seq ' || szBatchNo || '/' ||
        TO_CHAR(tPalRtnCtl.prc_seq_no) || ' in BATCH status: ' ||
        szBatchStatus);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Not found/error batch/seq ' || szBatchNo || '/' ||
          TO_CHAR(tPalRtnCtl.prc_seq_no) || ' in BATCH: ' || TO_CHAR(SQLCODE));
        szBatchStatus := 'X';
    END;
    IF szBatchStatus = 'X' THEN
      BEGIN
        UPDATE batch
        SET status = 'F'
        WHERE batch_no = szBatchNo
        AND   ref_no = tPalRtnCtl.prc_seq_no;
        DBMS_OUTPUT.PUT_LINE('Batch/seq ' || szBatchNo || '/' ||
          TO_CHAR(tPalRtnCtl.prc_seq_no) || ' is updated to F status before ' ||
          'creating new one since no putawaylst for batch is found. Count: ' ||
          TO_CHAR(SQL%ROWCOUNT));
        pl_log.ins_msg('I', szFuncName,
                       'Update batch ' || szBatchNo || ' to F status (' ||
                       TO_CHAR(SQL%ROWCOUNT) || ') before creating new one ' ||
                       'since no putawaylst for batch is found',
                       0, NULL);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          gszPkgMessage := 'Unable to update batch ' ||
            szBatchNo || ' to F status before creating new batch since ' ||
            'no putawaylst for batch is found';
          poszErrMsg := gszPkgMessage;
          DBMS_OUTPUT.PUT_LINE(gszPkgMessage);
          pl_log.ins_msg('I', szFuncName, gszPkgMessage,
                         SQLCODE, SUBSTR(SQLERRM, 1, 2000));
          RETURN;
      END;
    END IF;
    blnFound := FALSE;
    create_pallet_batch(tPalRtnCtl.prc_seq_no, tPalRtnCtl.job_code,
                        tPalRtnCtl.stage_loc, szBatchNo, iStatus);
    DBMS_OUTPUT.PUT_LINE('New batch status: ' || TO_CHAR(iStatus) ||
      ', pallet: ' || pszPalletID || ', seq: ' ||
      TO_CHAR(tPalRtnCtl.prc_seq_no) || ', jobCode: ' ||
      tPalRtnCtl.job_code || ', batch: ' || szBatchNo);
    iCurBatchCube := 0;
    IF iStatus = ORACLE_NORMAL THEN
      -- Update PUTAWAYLST with the new batch
      attach_line_item_to_batch(pszPalletID, szBatchNo, iStatus);
    END IF;
    IF iStatus <> ORACLE_NORMAL THEN
      DBMS_OUTPUT.PUT_LINE('Cannot attach new batch status: ' ||
        TO_CHAR(iStatus) || ', pallet: ' || pszPalletID || ', seq: ' ||
        TO_CHAR(tPalRtnCtl.prc_seq_no) || ', jobCode: ' ||
        tPalRtnCtl.job_code || ', batch: ' || szBatchNo);
      poiStatus := iStatus;
      gszPkgMessage := gszPkgMessage || szMessage;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
    END IF;
    szNewBatch := 'Y';
  END IF;
  IF (iCurBatchCube + iLineItemCube > tPalRtnCtl.pallet_cube) OR
     ((iLineItemCube > tPalRtnCtl.pallet_cube) OR
      (iLineItemCube > iCasePalletCube) OR
      (iLineItemCube > iTiHiPalletCube)) THEN
    -- Current location cube or will-be-accumulated cube batch is too big.

    iNumPalletExceeds := check_pallets_limit(szBatchNo);
    DBMS_OUTPUT.PUT_LINE('Item cube is over the limit. # of Pallets exceeds ' ||
      'limit of ' || TO_CHAR(NUM_PALLETS_MSKU) || ': ' ||
      TO_CHAR(iNumPalletExceeds) || ' for batch: ' ||
      szBatchNo);
    IF iNumPalletExceeds = -1 THEN
      poiStatus := LM_BATCH_UPD_FAIL;
      gszPkgMessage := 'Error getting # of pallets for batch ' || szBatchNo;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
    ELSIF iNumPalletExceeds > NUM_PALLETS_MSKU THEN
      poiStatus := LM_OVER_LPS_PER_BATCH;
      gszPkgMessage := '# of pallets exceeds limit of ' ||
                       TO_CHAR(NUM_PALLETS_MSKU) || ' for batch ' || szBatchNo;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
    END IF;

    DBMS_OUTPUT.PUT_LINE('Item cube is over the limit. Close the batch ' ||
      'pallet: ' || pszPalletID || ', batch: ' || szBatchNo || ', totalcub: ' ||
      TO_CHAR(iCurBatchCube)); 
    -- Update goal time for the found/new batch (0) and is called by the
    -- procedure inside the package (1).
    close_pallet_batch(szBatchNo, 0, 1, poszErrMsg, iStatus);
    IF iStatus <> ORACLE_NORMAL THEN
      DBMS_OUTPUT.PUT_LINE('Cannot close batch status: ' ||
        TO_CHAR(iStatus) || ', pallet: ' || pszPalletID || ', seq: ' ||
        TO_CHAR(tPalRtnCtl.prc_seq_no) || ', jobCode: ' ||
        tPalRtnCtl.job_code || ', batch: ' || szBatchNo);
      poiStatus := iStatus;
      gszPkgMessage := gszPkgMessage || szMessage;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
    END IF;
    -- Add found/new batch to returned array and need to have worksheet
    add_batches(szLoc, szBatchNo, 'Y', szNewBatch, iNumBatches, tBatchNos);
    DBMS_OUTPUT.PUT_LINE('After overcube #batches: ' || TO_CHAR(iNumBatches));

    -- Create a new batch for the current location that's over-cubed
    IF blnFound THEN
      create_pallet_batch(tPalRtnCtl.prc_seq_no, tPalRtnCtl.job_code,
                          tPalRtnCtl.stage_loc, szBatchNo, iStatus);
      DBMS_OUTPUT.PUT_LINE('Item cube is over the limit. Create new batch ' ||
        'status: ' || TO_CHAR(iStatus) || ', pallet: ' || pszPalletID ||
        ', batch: ' || szBatchNo); 
      iCurBatchCube := 0;
      IF iStatus = ORACLE_NORMAL THEN
        -- Update PUTAWAYLST with the new batch
        attach_line_item_to_batch(pszPalletID, szBatchNo, iStatus);
      END IF;
      DBMS_OUTPUT.PUT_LINE('Attach batch status: ' || TO_CHAR(iStatus) ||
        ', pallet: ' || pszPalletID || ', batch: ' || szBatchNo);
      IF iStatus = ORACLE_NORMAL THEN
        -- Recalculate and save the new batch to BATCH
        iStatus := load_pallet_batch(szBatchNo);
      END IF;
      DBMS_OUTPUT.PUT_LINE('Load batch status: ' || TO_CHAR(iStatus) ||
        ', pallet: ' || pszPalletID || ', batch: ' || szBatchNo);
      IF iStatus = ORACLE_NORMAL THEN
        -- Add the new batch to returned array and don't need worksheet yet
        add_batches(szLoc, szBatchNo, 'N', 'Y', iNumBatches, tBatchNos);
        DBMS_OUTPUT.PUT_LINE('After overcube and new batch #batches: ' ||
          TO_CHAR(iNumBatches));
      ELSE
        gszPkgMessage := gszPkgMessage || szMessage;
      END IF;
    END IF;
  ELSE
    -- Current location cube or will-be-accumulated cube is not over the limit

    DBMS_OUTPUT.PUT_LINE('Item cube is within the limit ' ||
      'pallet: ' || pszPalletID || ', batch: ' || szBatchNo); 
    IF blnFound THEN
      -- Update PUTAWAYLST with the found batch
      attach_line_item_to_batch(pszPalletID, szBatchNo, iStatus);
    END IF;
    IF iStatus <> ORACLE_NORMAL THEN
      DBMS_OUTPUT.PUT_LINE('Error attaching batch status: ' ||
        TO_CHAR(iStatus) || ', pallet: ' || pszPalletID || ', batch: ' ||
        szBatchNo);
      poiStatus := iStatus;
      gszPkgMessage := gszPkgMessage || szMessage;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
    END IF;
    -- Recalculate and save the found batch
    DBMS_OUTPUT.PUT_LINE('Attach batch status: ' || TO_CHAR(iStatus) ||
      ', pallet: ' || pszPalletID || ', batch: ' || szBatchNo);
    iStatus := load_pallet_batch(szBatchNo);
    IF iStatus <> ORACLE_NORMAL THEN
      DBMS_OUTPUT.PUT_LINE('Error loading batch status: ' ||
        TO_CHAR(iStatus) || ', pallet: ' || pszPalletID || ', batch: ' ||
        szBatchNo);
      poiStatus := iStatus;
      gszPkgMessage := gszPkgMessage || szMessage;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
    END IF;
    DBMS_OUTPUT.PUT_LINE('Load batch status: ' || TO_CHAR(iStatus) ||
      ', pallet: ' || pszPalletID || ', batch: ' || szBatchNo);

    iNumPalletExceeds := check_pallets_limit(szBatchNo);
    IF iNumPalletExceeds = -1 THEN
      poiStatus := LM_BATCH_UPD_FAIL;
      gszPkgMessage := 'Error getting # of pallets for batch ' || szBatchNo;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
    ELSIF iNumPalletExceeds > NUM_PALLETS_MSKU THEN
      poiStatus := LM_OVER_LPS_PER_BATCH;
      gszPkgMessage := '# of pallets exceeds limit of ' ||
                       TO_CHAR(NUM_PALLETS_MSKU) || ' for batch ' || szBatchNo;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
    END IF;

    -- Add found batch to returned array and don't need worksheet
    add_batches(szLoc, szBatchNo, 'N', 'N', iNumBatches, tBatchNos);
    DBMS_OUTPUT.PUT_LINE('After normal cube #batches: ' ||
      TO_CHAR(iNumBatches));
  END IF;

  poiNumBatches := iNumBatches;
  poszBatches := tBatchNos;
  poiStatus := iStatus;
  poszErrMsg := gszPkgMessage;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE get_batch_no(
  piMfNo      IN manifests.manifest_no%TYPE,
  poszBatches OUT ttabBatches,
  poszErrMsg OUT VARCHAR2,
  poiStatus   OUT NUMBER) IS
  szFuncName		VARCHAR2(50) := 'get_batch_no(all)';
  szBatch		trecBatches := NULL;
  iStatus		NUMBER := ORACLE_NORMAL;
  iNumBatches		NUMBER := 0;
  szDmgID		inv.logi_loc%TYPE := NULL;
  CURSOR c_get_batches IS
    SELECT parent_pallet_id, prod_id, cust_pref_vendor, erm_line_id, dest_loc
    FROM putawaylst
    WHERE SUBSTR(rec_id, 2) = TO_CHAR(piMfNo);
BEGIN
  gszPkgMessage := NULL;
  giCode := 0;
  poiStatus := ORACLE_NORMAL;
  poszErrMsg := NULL;

  FOR cBatch IN c_get_batches LOOP
    szBatch := NULL;
    iStatus := ORACLE_NORMAL;
    szDmgID := NULL;
    get_batch_no(piMfNo, cBatch.prod_id, cBatch.cust_pref_vendor,
                 cBatch.erm_line_id, szBatch, szDmgID, poszErrMsg, iStatus);
    IF iStatus = ORACLE_NORMAL THEN
      add_batches(cBatch.dest_loc, szBatch.batchNo, 'N', 'N',
                  iNumBatches, poszBatches, szDmgID);
    ELSE
      giCode := iStatus;
      EXIT WHEN iStatus <> ORACLE_NORMAL;
    END IF;
  END LOOP;

  poiStatus := iStatus;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE get_batch_no(
  piMfNo     IN manifests.manifest_no%TYPE,
  pszItem    IN pm.prod_id%TYPE,
  pszCpv     IN pm.cust_pref_vendor%TYPE,
  piLineNo   IN putawaylst.erm_line_id%TYPE,
  poszBatch  OUT trecBatches,
  poszDmgID  OUT inv.logi_loc%TYPE,
  poszErrMsg OUT VARCHAR2,
  poiStatus  OUT NUMBER) IS
  szFuncName		VARCHAR2(50) := 'get_batch_no(one)';
  szLoc			loc.logi_loc%TYPE := NULL;
  szPalletID		inv.logi_loc%TYPE := NULL;
  szBatchNo		putawaylst.parent_pallet_id%TYPE := NULL;
  iStatus		NUMBER := ORACLE_NORMAL;
  szRsnGrp		reason_cds.reason_group%TYPE := NULL;
BEGIN
  gszPkgMessage := NULL;
  giCode := 0;
  poszBatch := NULL;
  poszDmgId := NULL;
  poiStatus := ORACLE_NORMAL;
  poszErrMsg := NULL;

  SELECT parent_pallet_id, dest_loc, pallet_id, reason_group
  INTO szBatchNo, szLoc, szPalletID, szRsnGrp
  FROM putawaylst, reason_cds
  WHERE SUBSTR(rec_id, 2) = TO_CHAR(piMfNo)
  AND   prod_id = pszItem
  AND   cust_pref_vendor = pszCpv
  AND   erm_line_id = piLineNo
  AND   reason_code = reason_cd
  AND   reason_cd_type = 'RTN';

  poszBatch.logi_loc := szLoc;
  poszBatch.batchNo := szBatchNo;
  IF szBatchNo IS NULL AND szRsnGrp <> 'DMG' THEN
    iStatus := NO_LM_BATCH_FOUND;
    gszPkgMessage := 'No T-batch exists for mf: ' || TO_CHAR(piMfNo) ||
                     ', item: ' || pszItem || '/' || pszCpv || ', line: ' ||
                     TO_CHAR(piLineNo) || ', loc: ' || szLoc || '/' ||
                     szPalletID;
  END IF;

  poiStatus := iStatus;
  poszErrMsg := gszPkgMessage;
  IF szRsnGrp = 'DMG' THEN
    poszDmgID := szPalletID;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    gszPkgMessage := 'Error (' || TO_CHAR(SQLCODE) || ') finding T-batch ' ||
                     'for mf: ' || TO_CHAR(piMfNo) || ', item: ' || pszItem ||
                     '/' || pszCpv || ', line: ' || TO_CHAR(piLineNo);
    IF SQLCODE = ORACLE_NOT_FOUND OR SQLCODE = ANSI_NOT_FOUND THEN
      gszPkgMessage := 'Unable to find T-batch for mf: ' || TO_CHAR(piMfNo) ||
                       ', item: ' || pszItem || '/' || pszCpv || ', line: ' ||
                       TO_CHAR(piLineNo);
    END IF;
    pl_log.ins_msg('W', szFuncName, gszPkgMessage, SQLCODE, NULL);
    giCode := NO_LM_BATCH_FOUND;
    poiStatus := giCode;
    poszErrMsg := gszPkgMessage;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE get_batch_no(
  pszPalletID IN putawaylst.pallet_id%TYPE,
  poszBatchNo OUT putawaylst.parent_pallet_id%TYPE,
  poszDmgID   OUT inv.logi_loc%TYPE,
  poszErrMsg  OUT VARCHAR2,
  poiStatus   OUT NUMBER) IS
  szFuncName		VARCHAR2(50) := 'get_batch_no(one)';
  szBatchNo		putawaylst.parent_pallet_id%TYPE := NULL;
  szRsnGrp		reason_cds.reason_group%TYPE := NULL;
BEGIN
  gszPkgMessage := NULL;
  poszBatchNo := NULL;
  poszDmgID := NULL;
  poiStatus := ORACLE_NORMAL;
  poszErrMsg := NULL;

  SELECT parent_pallet_id, reason_group INTO szBatchNo, szRsnGrp
  FROM putawaylst, reason_cds
  WHERE pallet_id = pszPalletID
  AND   reason_code = reason_cd
  AND   reason_cd_type = 'RTN';

  IF szBatchNo IS NULL AND szRsnGrp <> 'DMG' THEN
    gszPkgMessage := 'No batch is available for pallet ID: ' || pszPalletID;
    pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
    giCode := NO_LM_BATCH_FOUND;
    poiStatus := giCode;
    poszErrMsg := gszPkgMessage;
  END IF;
  poszBatchNo := szBatchNo;
  IF szRsnGrp = 'DMG' THEN
    poszDmgID := pszPalletID;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    gszPkgMessage := 'Error (' || TO_CHAR(SQLCODE) || ') finding T-batch ' ||
                     'for pallet ID: ' || pszPalletID;
    pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
    giCode := NO_LM_BATCH_FOUND;
    poiStatus := giCode;
    poszErrMsg := gszPkgMessage;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE client_merge_pallet_batches(
  piNumValues  IN NUMBER,
  pszValues    IN VARCHAR2,
  piValueSize  IN NUMBER,
  piBatchFlag  IN NUMBER DEFAULT 0,
  poszBadValue OUT VARCHAR2,
  poszErrMsg   OUT VARCHAR2,
  poiStatus    OUT NUMBER) IS
  szFuncName            VARCHAR2(50) := 'client_merge_pallet_batches';
  szValues              ttabValues;
  iIndex                NUMBER;
  iNumValues            NUMBER := 0;
  iStart                NUMBER;
BEGIN
  gszPkgMessage := NULL;
  poszBadValue := NULL;
  poiStatus := ORACLE_NORMAL;
  poszErrMsg := NULL;

  iStart := 1;
  FOR iIndex IN 1 .. piNumValues LOOP
    szValues(iIndex) := LTRIM(RTRIM(SUBSTR(pszValues, iStart, piValueSize)));
    iStart := iStart + piValueSize;
  END LOOP;

  merge_pallet_batches(piNumValues, szValues, piBatchFlag,
                       poszBadValue, poszErrMsg, poiStatus);
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE merge_pallet_batches(
  piNumValues  IN NUMBER,
  pszValues    IN ttabValues,
  piBatchFlag  IN NUMBER DEFAULT 0,
  poszBadValue OUT VARCHAR2,
  poszErrMsg   OUT VARCHAR2,
  poiStatus    OUT NUMBER) IS
  szFuncName		VARCHAR2(50) := 'merge_pallet_batches';
  tBatchRec		trecBatches := NULL;
  szPalletID		putawaylst.pallet_id%TYPE := NULL;
  szPalletID2		putawaylst.pallet_id%TYPE := NULL;
  szBatchNo		putawaylst.parent_pallet_id%TYPE := NULL;
  szBatchNo2		putawaylst.parent_pallet_id%TYPE := NULL;
  iStatus		NUMBER := ORACLE_NORMAL;
  iIndex		NUMBER;
  szMessage		VARCHAR2(2000) := NULL;
  iNumBatches		NUMBER := 0;
  tBatches		ttabBatches;
  iOldNumBatches	NUMBER := 0;
  szDoor		batch.kvi_from_loc%TYPE := NULL;
  szDoor2		batch.kvi_from_loc%TYPE := NULL;
  iNumPallets		NUMBER := 0;
  CURSOR c_get_tbatch(cpszValue VARCHAR2, cpBatchFlag NUMBER) IS
    SELECT pt.pallet_id, pt.parent_pallet_id, b.kvi_from_loc
    FROM putawaylst pt, batch b
    WHERE pt.parent_pallet_id = b.batch_no
    AND   pt.putaway_put = 'N'
    AND   SUBSTR(pt.rec_id, 1, 1) = 'S'
    AND   b.status IN ('X', 'F', 'M')
    AND   (((cpBatchFlag <> 0) AND (pt.pallet_id = cpszValue)) OR
           ((cpBatchFlag = 0) AND (pt.parent_pallet_id = cpszValue)));
BEGIN
  gszPkgMessage := NULL;
  poszBadValue := NULL;
  poiStatus := ORACLE_NORMAL;
  poszErrMsg := NULL;

  -- If no pallet ID come in, do nothing
  IF piNumValues <= 0 OR pszValues.COUNT = 0 THEN
    RETURN;
  END IF;

  -- Retrieve the T-batch # for the 1st pallet ID/batch # since it will be the
  -- destined batch # while all other later pallet ID/batch # inputs will merge
  -- with it.
  IF pszValues.EXISTS(1) THEN
    -- szValue is either the 1st pallet ID or the 1st batch #
    OPEN c_get_tbatch(pszValues(1), piBatchFlag);
    FETCH c_get_tbatch INTO szPalletID, szBatchNo, szDoor;
    CLOSE c_get_tbatch;
  END IF;
  DBMS_OUTPUT.PUT_LINE('Destination: pal/btch: ' || szPalletID || '/' ||
    szBatchNo || ' flag: ' || TO_CHAR(piBatchFlag) || ', input: ' ||
    pszValues(1));

  -- The 1st input has no batch # or only 1 value is input (so no merge needed)
  IF szBatchNo IS NULL OR piNumValues = 1 OR pszValues.COUNT = 1 THEN
    iStatus := -20001;
    gszPkgMessage := 'batch #: ';
    szMessage := 'only 1 pallet/batch input. No need merge';
    IF piBatchFlag <> 0 THEN
      gszPkgMessage := 'pallet ID: ';
      szMessage := 'batch is not available';
    END IF;
    gszPkgMessage := szMessage || ' for ' || gszPkgMessage || pszValues(1);
    pl_log.ins_msg('W', szFuncName, gszPkgMessage, iStatus, NULL);
    poszBadValue := pszValues(1);
    poiStatus := iStatus;
    poszErrMsg := gszPkgMessage;
    RETURN;
  END IF;
  -- Add the 1st batch to temporary batch # holder
  add_batches(NULL, szBatchNo, 'N', 'N', iNumBatches, tBatches);
  DBMS_OUTPUT.PUT_LINE('Destination batch ' || szBatchNo || ' is added');
  iOldNumBatches := iNumBatches;

  FOR iIndex IN 2 .. piNumValues LOOP
    szPalletID2 := NULL;
    szBatchNo2 := NULL;
    szDoor2 := NULL;
    iStatus := ORACLE_NORMAL;
    OPEN c_get_tbatch(pszValues(iIndex), piBatchFlag);
    FETCH c_get_tbatch INTO szPalletID2, szBatchNo2, szDoor2;
    CLOSE c_get_tbatch;
    DBMS_OUTPUT.PUT_LINE('Src pal/btch: ' || szPalletID2 || '/' ||
      szBatchNo2 || ', flg: ' || TO_CHAR(piBatchFlag) || ', inp: (' ||
      TO_CHAR(iIndex) || ')' || pszValues(iIndex));
    IF szBatchNo2 IS NULL OR szBatchNo2 = szBatchNo THEN
      -- The current pallet doesn't have batch # or the current batch is
      -- invalid or the current batch is the same as the 1st batch
      iStatus := -20002;
      gszPkgMessage := 'batch #: ';
      szMessage := 'Invalid batch or batch not available';
      IF piBatchFlag <> 0 THEN
        gszPkgMessage := 'pallet ID: ';
        szMessage := 'Same batch # as the destination batch';
      END IF;
      gszPkgMessage := szMessage || ' for ' || gszPkgMessage ||
                       pszValues(iIndex);
      pl_log.ins_msg('F', szFuncName, gszPkgMessage, iStatus, NULL);
      poszBadValue := pszValues(iIndex);
      poiStatus := iStatus;
      poszErrMsg := gszPkgMessage;
    ELSE
      -- Add the current batch to the temporary batch # holder
      iOldNumBatches := iNumBatches;
      add_batches(NULL, szBatchNo2, 'N', 'N', iNumBatches, tBatches);
      DBMS_OUTPUT.PUT_LINE('Src Batch ' || szBatchNo2 || ' is added');
      IF iNumBatches = iOldNumBatches THEN
        -- The current batch already existed in the temporary holder
        iStatus := -20002;
        gszPkgMessage := 'batch #: ';
        szMessage := 'Found duplicated batch #';
        IF piBatchFlag <> 0 THEN
          gszPkgMessage := 'pallet ID: ';
        END IF;
        gszPkgMessage := szMessage || ' for ' || gszPkgMessage ||
                         pszValues(iIndex);
        pl_log.ins_msg('F', szFuncName, gszPkgMessage, iStatus, NULL);
        poszBadValue := pszValues(iIndex);
        poiStatus := iStatus;
        poszErrMsg := gszPkgMessage;
      END IF;
    END IF;
    EXIT WHEN iStatus <> ORACLE_NORMAL;
  END LOOP;

  IF iStatus <> ORACLE_NORMAL THEN
    RETURN;
  END IF;

  FOR iIndex IN 2 .. tBatches.COUNT LOOP
    -- Reduce KVI values for the source batches
    unload_pallet_batch(tBatches(iIndex).batchNo, 0, szMessage, iStatus);
    DBMS_OUTPUT.PUT_LINE('Unload batch (' || TO_CHAR(iIndex) || ')' ||
      tBatches(iIndex).batchNo || ', status: ' || TO_CHAR(iStatus));
    IF iStatus <> ORACLE_NORMAL THEN
      poiStatus := iStatus;
      poszBadValue := tBatches(iIndex).batchNo;
      gszPkgMessage := 'Error (' || TO_CHAR(iStatus) ||
                       ') unloading batch: ' || tBatches(iIndex).batchNo ||
                       ' while merging to ' || szBatchNo || ', err: ' ||
                       szMessage;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage, iStatus, szMessage);
      EXIT WHEN iStatus <> ORACLE_NORMAL;
    END IF;
    -- Update PUTAWAYLST pallet_batch_no for the current pallet/batch
    BEGIN
      UPDATE putawaylst
      SET pallet_batch_no = szBatchNo,
          parent_pallet_id = szBatchNo
      WHERE pallet_batch_no = tBatches(iIndex).batchNo;
      IF SQL%ROWCOUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Update parent batch for (' || TO_CHAR(iIndex) ||
          ')' || tBatches(iIndex).batchNo || ' to ' || szBatchNo);
      END IF;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        iStatus := SQLCODE;
        poiStatus := SQLCODE;
        poszBadValue := tBatches(iIndex).batchNo;
        gszPkgMessage := 'Error (' || TO_CHAR(SQLCODE) ||
                         ') merging batch ' || tBatches(iIndex).batchNo ||
                         ' to ' || szBatchNo;
        poszErrMsg := gszPkgMessage;
        pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                       SQLCODE, SUBSTR(SQLERRM, 1, 2000));
        EXIT WHEN iStatus <> ORACLE_NORMAL;
    END;
    -- Update BATCH parent_batch_no and door for the current pallet/batch
    BEGIN
      UPDATE batch
      SET parent_batch_no = szBatchNo,
          kvi_from_loc = szDoor
      WHERE batch_no = tBatches(iIndex).batchNo
      OR    parent_batch_no = tBatches(iIndex).batchNo;
      IF SQL%ROWCOUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Update parent batch and door for (' ||
          TO_CHAR(iIndex) || ')' || tBatches(iIndex).batchNo || ' to ' ||
          szBatchNo);
      END IF;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        iStatus := SQLCODE;
        poiStatus := SQLCODE;
        poszBadValue := tBatches(iIndex).batchNo;
        gszPkgMessage := 'Error (' || TO_CHAR(SQLCODE) ||
                         ') updating parent batch while merging batch ' ||
                         tBatches(iIndex).batchNo || ' to ' || szBatchNo;
        poszErrMsg := gszPkgMessage;
        pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                       SQLCODE, SUBSTR(SQLERRM, 1, 2000));
        EXIT WHEN iStatus <> ORACLE_NORMAL;
    END;
  END LOOP;

  IF iStatus = ORACLE_NORMAL THEN
    -- After the putaway task has been successfully updated to destination
    -- batch #, recalculate kvi values for the destination batch #
    iStatus := load_pallet_batch(szBatchNo, 0);
    DBMS_OUTPUT.PUT_LINE('Load batch ' || szBatchNo || ', status: ' ||
      TO_CHAR(iStatus));
    IF iStatus <> ORACLE_NORMAL THEN
      poiStatus := iStatus;
      poszBadValue := szBatchNo;
      poszErrMsg := gszPkgMessage;
    END IF;
  END IF;

  -- Recalculate goal/target time for all merged batches. Don't update status
  -- to 'F' for all merged batches (parameter TRUE).
  IF iStatus = ORACLE_NORMAL THEN
    FOR iIndex IN 1 .. tBatches.COUNT LOOP
      BEGIN
        pl_lm_time.load_goaltime(tBatches(iIndex).batchNo, TRUE);
        DBMS_OUTPUT.PUT_LINE('Set goal time for batch (' || TO_CHAR(iIndex) ||
          ')' || tBatches(iIndex).batchNo);
      EXCEPTION
        WHEN OTHERS THEN
          iStatus := SQLCODE;
          poiStatus := SQLCODE;
          poszBadValue := tBatches(iIndex).batchNo;
          gszPkgMessage := SQLERRM || ', Error (' || TO_CHAR(SQLCODE) ||
                           ') in calculating goal time during merging batch ' ||
                           tBatches(iIndex).batchNo;
          poszErrMsg := gszPkgMessage;
      END;
      EXIT WHEN iStatus <> ORACLE_NORMAL;
    END LOOP; 
  END IF;

  IF iStatus = ORACLE_NORMAL THEN
    -- Update status to Future for destination batch
    BEGIN
      UPDATE batch
      SET status = 'F'
      WHERE batch_no = tBatches(1).batchNo;
      IF SQL%ROWCOUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Update dest batch ' || tBatches(1).batchNo ||
          ' to status F');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        iStatus := SQLCODE;
        poiStatus := SQLCODE;
        poszBadValue := tBatches(1).batchNo;
        gszPkgMessage := 'Error (' || TO_CHAR(SQLCODE) ||
                         ') updating to F status during merging batch for ' ||
                         tBatches(1).batchNo;
        poszErrMsg := gszPkgMessage;
        RETURN;
    END;
    -- Update status to Merge for source batch(es)
    FOR iIndex IN 2 .. tBatches.COUNT LOOP
      BEGIN
        UPDATE batch
        SET status = 'M'
        WHERE batch_no = tBatches(iIndex).batchNo;
        IF SQL%ROWCOUNT > 0 THEN
          DBMS_OUTPUT.PUT_LINE('Update src batch (' || TO_CHAR(iIndex) ||
            ')' || tBatches(iIndex).batchNo || ' to status M');
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          iStatus := SQLCODE;
          poiStatus := SQLCODE;
          poszBadValue := tBatches(iIndex).batchNo;
          gszPkgMessage := 'Error (' || TO_CHAR(SQLCODE) ||
                           ') updating to M status during merging batch for ' ||
                           tBatches(iIndex).batchNo;
          poszErrMsg := gszPkgMessage;
      END;
      EXIT WHEN iStatus <> ORACLE_NORMAL;
    END LOOP;
  END IF;

  IF iStatus = ORACLE_NORMAL THEN
    iNumPallets := check_pallets_limit(szBatchNo);
    IF iNumPallets > NUM_PALLETS_MSKU THEN
      iStatus := LM_OVER_LPS_PER_BATCH;
      poiStatus := iStatus;
      poszBadValue := szBatchNo;
      gszPkgMessage := '# of pallets per batch ' || szBatchNo ||
                       ' exceeds limit of ' || TO_CHAR(NUM_PALLETS_MSKU);
      poszErrMsg := gszPkgMessage;
    END IF;
  END IF;

  IF iStatus = ORACLE_NORMAL THEN
    poszBadValue := szBatchNo;
  END IF;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE close_pallet_batch(
  pszValue	IN VARCHAR2,
  piBatchFlag	IN NUMBER DEFAULT 0,
  piCallDirect	IN NUMBER DEFAULT 0,
  poszErrMsg	OUT VARCHAR2,
  poiStatus	OUT NUMBER) IS
  szFuncName	VARCHAR2(50) := 'close_pallet_batch';
  szBatchNo	putawaylst.parent_pallet_id%TYPE := pszValue;
  iStatus	NUMBER := ORACLE_NORMAL;
  szStatus	batch.status%TYPE := NULL;
  szRsnGrp	reason_cds.reason_group%TYPE := NULL;
BEGIN
  gszPkgMessage := NULL;
  poszErrMsg := NULL;
  poiStatus := ORACLE_NORMAL;

  IF piBatchFlag <> 0 THEN
    -- Input is a Pallet ID
    BEGIN
      SELECT parent_pallet_id, reason_group INTO szBatchNo, szRsnGrp
      FROM putawaylst, reason_cds
      WHERE pallet_id = pszValue
      AND   reason_cd_type = 'RTN'
      AND   reason_code = reason_cd;
    EXCEPTION
      WHEN OTHERS THEN
        gszPkgMessage := 'Cannot retrieve PUTAWAYLST.parent_pallet_id for ' ||
                         'pallet ID: ' || pszValue || ' (' ||
                         TO_CHAR(SQLCODE) || ')';
        poiStatus := SQLCODE;
        poszErrMsg := gszPkgMessage;
        pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                       SQLCODE, SUBSTR(SQLERRM, 1, 2000));
        RETURN;
    END;
    IF szRsnGrp = 'DMG' THEN
      -- The input LP is a damage return. It shouldn't be closed since there is
      -- no T-batch associated with it
      gszPkgMessage := 'Pallet ' || pszValue || ' is a damage return and no ' ||
        'T-batch associated with it';
      poiStatus := PAL_DMG_NO_TBATCH;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('W', szFuncName, gszPkgMessage, NULL, NULL);
      RETURN;
    END IF;
  END IF;

  IF piCallDirect = 0 THEN
    -- Call directly by the caller outside of this package. Check if the
    -- batch is in Future status. The load_goaltime() won't handle batch that
    -- is already in Future status.
    BEGIN
      SELECT status INTO szStatus
      FROM batch
      WHERE batch_no = szBatchNo;
    EXCEPTION
      WHEN OTHERS THEN
        szStatus := NULL;
    END;
    IF szStatus IS NULL OR szStatus = 'F' THEN
      gszPkgMessage := 'Cannot retrieve status for batch: ' || szBatchNo ||
                       ' (' || TO_CHAR(SQLCODE) || ')';
      IF szStatus IS NULL THEN
        poiStatus := NO_LM_BATCH_FOUND;
      ELSE
        poiStatus := LM_ACTIVE_BATCH;
      END IF;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
    END IF;
  END IF;

  iStatus := load_pallet_batch(szBatchNo);
  IF iStatus = ORACLE_NORMAL THEN
    BEGIN
      pl_lm_time.load_goaltime(szBatchNo);
    EXCEPTION
      WHEN OTHERS THEN
        gszPkgMessage := SQLERRM || ', Error loading goaltime for batch: ' ||
                         szBatchNo;
        pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                       SQLCODE, SUBSTR(SQLERRM, 1, 2000));
        poiStatus := SQLCODE;
        poszErrMsg := gszPkgMessage;
        RETURN;
    END;
  ELSE
    poiStatus := iStatus;
    poszErrMsg := gszPkgMessage;
  END IF;

  pl_log.ins_msg('D', szFuncName,
                 'Batch for batch_no: ' || szBatchNo || ' is closed',
                 NULL, NULL);
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE unload_pallet_batch (
  pszValue    IN VARCHAR2,
  piBatchFlag IN NUMBER DEFAULT 0,
  poszErrMsg  OUT VARCHAR2,
  poiStatus   OUT NUMBER) IS
  szFuncName		VARCHAR2(50) := 'unload_pallet_batch';
  szBatchNo		VARCHAR2(50) := pszValue;
  iTotalCube		NUMBER := 0;
  iTotalWeight		NUMBER := 0;
  iNumPallets		NUMBER := 0;
  iNumPieces		NUMBER := 0;
  iNumItems		NUMBER := 0;
  iNumLocs		NUMBER := 0;
  iNumCases		NUMBER := 0;
  iNumSplits		NUMBER := 0;
  iNumAisles		NUMBER := 0;
  iNumPos		NUMBER := 0;
  szRsnGrp		reason_cds.reason_group%TYPE := NULL;
BEGIN
  gszPkgMessage := NULL;
  poszErrMsg := NULL;
  poiStatus := ORACLE_NORMAL;

  -- Get current total kvis according to either pallet ID or batch #
  BEGIN
    SELECT SUM(pt.qty * (p.case_cube / p.spc)), SUM(pt.qty * p.avg_wt),
           COUNT(*), COUNT(DISTINCT pt.prod_id),
           COUNT(DISTINCT pt.dest_loc),
           SUM(DECODE(pt.uom, 0, (pt.qty / p.spc), 0)),
           SUM(DECODE(pt.uom, 1, pt.qty, 0)),
           COUNT(DISTINCT SUBSTR(pt.dest_loc, 1, 2)),
           COUNT(DISTINCT pt.rec_id)
     INTO iTotalCube, iTotalWeight,
          iNumPallets, iNumItems,
          iNumLocs,
          iNumCases,
          iNumSplits,
          iNumAisles,
          iNumPos
     FROM pm p, putawaylst pt, reason_cds r
     WHERE p.prod_id = pt.prod_id
     AND   p.cust_pref_vendor = pt.cust_pref_vendor
     AND   SUBSTR(pt.rec_id, 1, 1) IN ('S', 'P', 'D')
     AND   pt.reason_code = r.reason_cd
     AND   r.reason_cd_type = 'RTN'
     AND   (((piBatchFlag = 0) AND (pt.parent_pallet_id = pszValue)) OR
            ((piBatchFlag <> 0) AND (pt.pallet_id = pszValue)));
  EXCEPTION
    WHEN OTHERS THEN
      gszPkgMessage := 'Error calculating KVI values on completed batch: ' ||
                       szBatchNo;
      poiStatus := SQLCODE;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
  END;

  -- D#11997 Don't need to do anything for damage reason code
  IF szRsnGrp = 'DMG' THEN
    RETURN;
  END IF;

  IF piBatchFlag <> 0 THEN
    BEGIN
      SELECT parent_pallet_id INTO szBatchNo
      FROM putawaylst
      WHERE pallet_id = pszValue;
    EXCEPTION
      WHEN OTHERS THEN
        szBatchNo := pszValue;
    END;
  END IF;

  -- Reduce the found batch # by the calculated kvi amounts
  BEGIN
    UPDATE batch
    SET kvi_cube = kvi_cube - iTotalCube, kvi_wt = kvi_wt - iTotalWeight,
        kvi_no_piece = kvi_no_piece - (iNumCases + iNumSplits),
        kvi_no_pallet = kvi_no_pallet - iNumPallets,
        kvi_no_item = kvi_no_item - iNumItems,
        kvi_no_po = kvi_no_po - iNumPos,
        kvi_no_loc = kvi_no_loc - iNumLocs,
        kvi_no_case = kvi_no_case - iNumCases,
        kvi_no_split = kvi_no_split - iNumSplits,
        kvi_no_aisle = kvi_no_aisle - iNumAisles 
    WHERE batch_no = szBatchNo
    AND   status IN ('X', 'F');
  EXCEPTION
    WHEN OTHERS THEN
      gszPkgMessage := 'Error removing KVIs for batch: ' || szBatchNo;
      poiStatus := SQLCODE;
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN;
  END;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
PROCEDURE check_pallet_batch(
  pszValue	IN VARCHAR2,
  piBatchFlag	IN NUMBER DEFAULT 0,
  poszBatchNo	OUT putawaylst.parent_pallet_id%TYPE,
  poszErrMsg	OUT VARCHAR2,
  poiStatus	OUT NUMBER) IS
  szFuncName	VARCHAR2(50) := 'check_pallet_batch';
  szBatchNo	putawaylst.parent_pallet_id%TYPE := NULL;
  szPutaway	putawaylst.putaway_put%TYPE := 'N';
  szRsnGroup	reason_cds.reason_group%TYPE := NULL;
BEGIN
  gszPkgMessage := NULL;
  poszBatchNo := NULL;
  poszErrMsg := NULL;
  poiStatus := ORACLE_NORMAL;

  BEGIN
    SELECT pt.parent_pallet_id, NVL(pt.putaway_put, 'N'), rc.reason_group
    INTO szBatchNo, szPutaway, szRsnGroup
    FROM putawaylst pt, reason_cds rc
    WHERE SUBSTR(pt.rec_id, 1, 1) IN ('S', 'P', 'D')
    AND   (((piBatchFlag <> 0) AND (pt.pallet_id = pszValue)) OR
           ((piBatchFlag = 0) AND (pt.parent_pallet_id = pszValue)))
    AND   pt.reason_code = rc.reason_cd
    AND   rc.reason_cd_type = 'RTN';

    IF szBatchNo IS NULL THEN
      gszPkgMessage := 'No Batch available for ' || pszValue; 
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      poiStatus := NO_LM_BATCH_FOUND;
      RETURN;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      gszPkgMessage := 'Pallet/Batch ' || pszValue || ' not found. Error: ' ||
        TO_CHAR(SQLCODE);
      poszErrMsg := gszPkgMessage;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      poiStatus := NO_LM_BATCH_FOUND;
      RETURN;
  END;

  IF szPutaway = 'Y' THEN
    gszPkgMessage := 'Pallet/Batch ' || pszValue || ' has been putawayed'; 
    poszErrMsg := gszPkgMessage;
    pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
    poiStatus := PUT_DONE;
    RETURN;
  END IF;

  IF szRsnGroup = 'DMG' THEN
    gszPkgMessage := 'Pallet/Batch ' || pszValue || ' is a damage return';
    poszErrMsg := gszPkgMessage;
    pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
    poiStatus := INV_LABEL;
    RETURN;
  END IF;

  poszBatchNo := szBatchNo;
EXCEPTION
  WHEN OTHERS THEN
    gszPkgMessage := 'Error (' || TO_CHAR(SQLCODE) ||
      ') occurred for Pallet/Batch ' || pszValue || ' during checking';
    poszErrMsg := gszPkgMessage;
    pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
    poiStatus := SQLCODE;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
FUNCTION load_pallet_batch (
  pszValue    IN VARCHAR2,
  piBatchFlag IN NUMBER DEFAULT 0)
RETURN NUMBER IS
  szFuncName	VARCHAR2(50) := 'load_pallet_batch';
  szBatchNo	putawaylst.parent_pallet_id%TYPE := pszValue;
  iStatus	NUMBER := ORACLE_NORMAL;
  iTotalCube	NUMBER := 0;
  iTotalWt	NUMBER := 0;
  iNumPallets	NUMBER := 0;
  iNumItems	NUMBER := 0;
  iNumLocs	NUMBER := 0;
  iNumCases	NUMBER := 0;
  iNumSplits	NUMBER := 0;
  iNumAisles	NUMBER := 0;
  iNumPos	NUMBER := 0;
BEGIN
  gszPkgMessage := NULL;

  BEGIN
    SELECT SUM(pt.qty * (p.case_cube / p.spc)),
           SUM(pt.qty * p.avg_wt),
           COUNT(*),
           COUNT(DISTINCT pt.prod_id),
           COUNT(DISTINCT pt.dest_loc),
           SUM(DECODE(pt.uom, 0, (pt.qty / p.spc), 0)),
           SUM(DECODE(pt.uom, 1, pt.qty, 0)),
           COUNT(DISTINCT SUBSTR(pt.dest_loc, 1, 2)),
           COUNT(DISTINCT pt.rec_id)
    INTO iTotalCube, iTotalWt,
         iNumPallets, iNumItems, iNumLocs, iNumCases, iNumSplits, iNumAisles,
         iNumPos
    FROM pm p, putawaylst pt 
    WHERE p.prod_id = pt.prod_id
    AND   p.cust_pref_vendor = pt.cust_pref_vendor
    AND   SUBSTR(pt.rec_id, 1, 1) IN ('S', 'P', 'D')
    AND   (((piBatchFlag <> 0) AND (pt.pallet_id = pszValue)) OR
           ((piBatchFlag = 0) AND (pt.parent_pallet_id = pszValue)));
  EXCEPTION
    WHEN OTHERS THEN
      gszPkgMessage := 'batch_no: ';
      IF piBatchFlag <> 0 THEN
        gszPkgMessage := 'pallet ID: ';
      END IF;
      gszPkgMessage := 'Cannot get Returns summary info for ' ||
                       gszPkgMessage || pszValue;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN SQLCODE;
  END;

  IF piBatchFlag <> 0 THEN
    -- A pallet ID value is input. Get its batch #
    BEGIN
      SELECT parent_pallet_id INTO szBatchNo
      FROM putawaylst
      WHERE pallet_id = pszValue;
    EXCEPTION
      WHEN OTHERS THEN
        szBatchNo := pszValue;
    END;
  END IF;
  BEGIN
    UPDATE batch
    SET kvi_cube = iTotalCube, kvi_wt = iTotalWt,
        kvi_no_piece = iNumCases + iNumSplits,
        kvi_no_pallet = iNumPallets,
        kvi_no_item = iNumItems,
        kvi_no_po = iNumPos,
        kvi_no_loc = iNumLocs,
        kvi_no_case = iNumCases,
        kvi_no_split = iNumSplits,
        kvi_no_aisle = iNumAisles 
    WHERE batch_no = szBatchNo;
  EXCEPTION
    WHEN OTHERS THEN
      gszPkgMessage := 'batch_no: ';
      IF piBatchFlag <> 0 THEN
        gszPkgMessage := 'pallet ID: ';
      END IF;
      gszPkgMessage := 'Cannot update Returns summary info ' || gszPkgMessage ||
                       pszValue;
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN SQLCODE;
  END;

  pl_log.ins_msg('D', szFuncName,
                 'Batch for batch_no: ' || szBatchNo || ' loaded', NULL, NULL);
  RETURN iStatus;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
FUNCTION create_def_rtn_lm_batch(
  pszUser    IN usr.user_id%TYPE,
  pszBatchNo IN putawaylst.parent_pallet_id%TYPE)
RETURN NUMBER IS
  szFuncName	VARCHAR2(50) := 'create_def_rtn_lm_batch';
  tSyspars	trecRtnLmFlags := NULL;
  iStatus	NUMBER := ORACLE_NORMAL;
  szBatchNo	putawaylst.parent_pallet_id%TYPE := NULL;
BEGIN
  gszPkgMessage := NULL;

  tSyspars := check_rtn_lm_syspars;
  IF tSyspars.szLmRtnDfltIndJobCode = 'N' THEN
    RETURN CTE_RTN_BTCH_FLG_OFF;
  END IF;

  BEGIN
    SELECT 'I' || seq1.NEXTVAL INTO szBatchNo
    FROM DUAL;
  EXCEPTION
    WHEN OTHERS THEN
      gszPkgMessage := 'Cannot get next Indirect batch #';
      pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN NO_LM_BATCH_FOUND;
  END;

  BEGIN
    INSERT INTO batch
      (batch_no, batch_date, status,
       jbcd_job_code, actl_start_time, user_id,
       user_supervsr_id,
       kvi_doc_time,
       kvi_cube, kvi_wt, kvi_no_piece,
       kvi_no_pallet, kvi_no_item,
       kvi_no_data_capture, kvi_no_po,
       kvi_no_stop, kvi_no_zone, kvi_no_loc,
       kvi_no_case, kvi_no_split, kvi_no_merge,
       kvi_no_aisle, kvi_no_drop,
       kvi_order_time, kvi_distance,
       kvi_no_cart, kvi_no_pallet_piece,
       kvi_no_cart_piece,
       goal_time, target_time,
       ref_no)
      SELECT szBatchNo, trunc(SYSDATE), 'A',
       tSyspars.szLmRtnDfltIndJobCode, b.actl_stop_time, b.user_id,
       b.user_supervsr_id,
       0,
       0, 0, 0,
       0, 0,
       0, 0,
       0, 0, 0,
       0, 0, 0,
       0, 0,
       0, 0,
       0, 0,
       0,
       0, 0,
       pszBatchNo 
      FROM batch b
      WHERE ROWNUM = 1
      AND   b.actl_stop_time = (SELECT MAX(actl_stop_time)
                                FROM batch b2
                                WHERE b2.batch_no = b.batch_no
                                AND   b2.batch_date = b.batch_date
                                AND   b2.status = 'C'
                                AND   REPLACE(b2.user_id,'OPS$',NULL) =
                                        REPLACE(pszUser,'OPS$',NULL));
    gszPkgMessage := 'create_def_rtn_lm_batch T batch: ' || pszBatchNo ||
                     ' is inserted on ' ||
                     TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS');
    pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
  EXCEPTION
    WHEN OTHERS THEN
      IF SQL%ROWCOUNT = 0 THEN
        gszPkgMessage := 'Indirect batch creation cannot be completed for ' ||
                         'batch: ' || pszBatchNo || ', user: ' || pszUser ||
                         ', jobcode: ' || tSyspars.szLmRtnDfltIndJobCode;
      ELSE
        gszPkgMessage := 'Error creating Indirect batch for ' ||
                         'batch: ' || pszBatchNo || ', user: ' || pszUser ||
                         ', jobcode: ' || tSyspars.szLmRtnDfltIndJobCode;
      END IF;
      pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      iStatus := NO_LM_BATCH_FOUND;
  END;

  RETURN iStatus;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
FUNCTION reset_rtn_lm_batch(
  pszBatchNo   IN putawaylst.parent_pallet_id%TYPE,
  pszMergeFlag IN VARCHAR2 DEFAULT 'N',
  pszUser      IN usr.user_id%TYPE DEFAULT USER)
RETURN NUMBER IS
  szFuncName	VARCHAR2(50) := 'reset_rtn_lm_batch';
  iStatus	NUMBER := ORACLE_NORMAL;
  CURSOR c_merge_batch IS
    SELECT batch_no
    FROM batch
    WHERE parent_batch_no = pszBatchNo
    AND   batch_no <> parent_batch_no;
BEGIN
  gszPkgMessage := NULL;

  IF pszMergeFlag = 'Y' THEN
    FOR cMerge IN c_merge_batch LOOP
      BEGIN
        UPDATE batch
        SET status = 'X',
            user_id = NULL,
            parent_batch_no = NULL,
            parent_batch_date = NULL,
            kvi_from_loc = NULL,
            actl_start_time = NULL,
            actl_stop_time = NULL
        WHERE batch_no = pszBatchNo;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          iStatus := ORACLE_NORMAL;
        WHEN OTHERS THEN
          gszPkgMessage := 'Cannot reset child batch from parent for batch: ' ||
                           pszBatchNo;
          pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                         SQLCODE, SUBSTR(SQLERRM, 1, 2000));
          iStatus := LM_BATCH_UPD_FAIL;
      END;
      IF iStatus = ORACLE_NORMAL THEN
        BEGIN
          pl_lm_time.load_goaltime(pszBatchNo);
        EXCEPTION
          WHEN OTHERS THEN
            gszPkgMessage := SQLERRM ||
                             ', Cannot reset goal/target time for batch: ' ||
                             pszBatchNo;
            pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                           SQLCODE, SUBSTR(SQLERRM, 1, 2000));
            iStatus := LM_BATCH_UPD_FAIL;
        END;
      END IF;
      EXIT WHEN iStatus <> ORACLE_NORMAL;
    END LOOP;
    IF iStatus = ORACLE_NORMAL THEN
      BEGIN
        DELETE batch
        WHERE batch_no = pszBatchNo;
      EXCEPTION
        WHEN OTHERS THEN
          gszPkgMessage := 'Cannot delete parent batch for batch: ' ||
                           pszBatchNo;
          pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                         SQLCODE, SUBSTR(SQLERRM, 1, 2000));
          iStatus := NO_LM_BATCH_FOUND;
      END;
    END IF;
  ELSE
    -- Batch is not merge
    BEGIN
      UPDATE batch
      SET status = 'F',
          user_id = NULL,
          parent_batch_no = NULL,
          parent_batch_date = NULL,
          kvi_from_loc = NULL,
          actl_stop_time = NULL,
          actl_start_time = NULL
      WHERE batch_no = pszBatchNo;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        iStatus := ORACLE_NORMAL;
      WHEN OTHERS THEN
        gszPkgMessage := 'Cannot reset batch: ' || pszBatchNo;
        pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                       SQLCODE, SUBSTR(SQLERRM, 1, 2000));
        iStatus := LM_BATCH_UPD_FAIL;
    END;
  END IF;

  IF iStatus = ORACLE_NORMAL THEN
    iStatus := create_def_rtn_lm_batch(pszUser, pszBatchNo);
  END IF;

  RETURN iStatus;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
FUNCTION move_puts_to_batch(
  pszCurBatchNo IN putawaylst.parent_pallet_id%TYPE,
  pszNewBatchNo IN putawaylst.parent_pallet_id%TYPE)
RETURN NUMBER IS
  szFuncName	VARCHAR2(50) := 'move_puts_to_batch';
BEGIN
  gszPkgMessage := NULL;

  UPDATE putawaylst
  SET pallet_batch_no = pszNewBatchNo,
      parent_pallet_id = pszNewBatchNo
  WHERE parent_pallet_id = pszCurBatchNo;

  RETURN ORACLE_NORMAL;
EXCEPTION
  WHEN OTHERS THEN
    gszPkgMessage := 'Cannot reattach putaway task to new batch: ' ||
                     pszNewBatchNo || ' from current batch: ' || pszCurBatchNo;
    pl_log.ins_msg('F', szFuncName, gszPkgMessage,
                   SQLCODE, SUBSTR(SQLERRM, 1, 2000));
    RETURN SQLCODE;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
FUNCTION get_pkg_errors
RETURN VARCHAR2 IS
BEGIN
  RETURN gszPkgMessage;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
FUNCTION get_pkg_code
RETURN NUMBER IS
BEGIN
  RETURN giCode;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
FUNCTION check_rtn_lm_syspars
RETURN trecRtnLmFlags IS
  szFuncName		VARCHAR2(50) := 'check_rtn_lm_syspars';
  tSyspars		trecRtnLmFlags := NULL;
BEGIN
  tSyspars.szLbrMgmtFlag := pl_common.f_get_syspar('LBR_MGMT_FLAG');
  IF tSyspars.szLbrMgmtFlag IS NULL OR UPPER(tSyspars.szLbrMgmtFlag) <> 'Y' THEN
    pl_log.ins_msg('I', szFuncName, 'LBR_MGMT_FLAG syspar is not set',
                   NULL, NULL);
    tSyspars.szLbrMgmtFlag := 'N';
  END IF;

  BEGIN
    SELECT create_batch_flag INTO tSyspars.szCrtBatchFlag
    FROM lbr_func
    WHERE lfun_lbr_func = 'RP';
  EXCEPTION
    WHEN OTHERS THEN
      tSyspars.szCrtBatchFlag := 'N';
  END;
  IF tSyspars.szCrtBatchFlag IS NULL OR
     UPPER(tSyspars.szCrtBatchFlag) <> 'Y' THEN
    pl_log.ins_msg('I', szFuncName, 'LBR_FUNC.CREATE_BATCH_FLAG is not set',
                   NULL, NULL);
    tSyspars.szCrtBatchFlag := 'N';
  END IF;

  tSyspars.szLmRtnDfltIndJobCode :=
    pl_common.f_get_syspar('LM_RTN_DFLT_IND_JOBCODE');
  IF tSyspars.szLmRtnDfltIndJobCode IS NULL OR
     UPPER(tSyspars.szLmRtnDfltIndJobCode) <> 'Y' THEN
    pl_log.ins_msg('I', szFuncName, 'LM_RTN_DFLT_IND_JOBCODE syspar is not set',
                   NULL, NULL);
    tSyspars.szLmRtnDfltIndJobCode := 'N';
  END IF;

  RETURN tSyspars;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
FUNCTION delete_pallet_batch (
  pszValue		IN VARCHAR2,
  piBatchFlag		IN NUMBER DEFAULT 0,
  piForceDeleteFlag	IN NUMBER DEFAULT 0)
RETURN NUMBER IS
  szFuncName	VARCHAR2(50) := 'delete_pallet_batch';
  iStatus	NUMBER := ORACLE_NORMAL;
  szBatchNo	putawaylst.parent_pallet_id%TYPE := pszValue;
  iTotalCube	NUMBER := 0;
  iTotalWeight	NUMBER := 0;
  iNumPallets	NUMBER := 0;
  iNumPieces	NUMBER := 0;
  iNumItems	NUMBER := 0;
  iNumLocs	NUMBER := 0;
  iNumCases	NUMBER := 0;
  iNumSplits	NUMBER := 0;
  iNumAisles	NUMBER := 0;
  iNumPos	NUMBER := 0;
  szRsnGrp	reason_cds.reason_group%TYPE := NULL;
BEGIN
  gszPkgMessage := NULL;

  IF piBatchFlag <> 0 THEN
    BEGIN
      SELECT pt.parent_pallet_id, r.reason_group INTO szBatchNo, szRsnGrp
      FROM putawaylst pt, reason_cds r
      WHERE pt.pallet_id = pszValue
      AND   pt.reason_code = r.reason_cd
      AND   r.reason_cd_type = 'RTN';
    EXCEPTION
      WHEN OTHERS THEN
        szBatchNo := pszValue;
    END;
    -- No need to delete batch for damage reason code
    IF szRsnGrp = 'DMG' THEN
      RETURN ORACLE_NORMAL;
    END IF;
  END IF;

  -- Get current total kvis according to either pallet ID or batch #
  BEGIN
    SELECT kvi_cube, kvi_wt, kvi_no_pallet, kvi_no_item, kvi_no_loc,
           kvi_no_case, kvi_no_split, kvi_no_aisle, kvi_no_po
     INTO iTotalCube, iTotalWeight,
          iNumPallets, iNumItems,
          iNumLocs,
          iNumCases,
          iNumSplits,
          iNumAisles,
          iNumPos
     FROM batch
     WHERE batch_no = szBatchNo;
  EXCEPTION
    WHEN OTHERS THEN
      gszPkgMessage := 'Error retrieving KVI values from BATCH to delete ' ||
                       'pallet/batch: ' || pszValue;
      pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                     SQLCODE, SUBSTR(SQLERRM, 1, 2000));
      RETURN SQLCODE;
  END;

  IF (piForceDeleteFlag <> 0) OR
     (iNumPallets <= 0 AND iNumItems <= 0 AND
      iNumLocs <= 0 AND iNumCases <= 0 AND
      iNumSplits <= 0 AND iNumAisles <= 0 AND iNumPos <= 0) THEN
    BEGIN
      DELETE batch
      WHERE batch_no = szBatchNo;
    EXCEPTION
      WHEN OTHERS THEN
        gszPkgMessage := 'Error deleting from BATCH for batch: ' || szBatchNo;
        pl_log.ins_msg('W', szFuncName, gszPkgMessage,
                       SQLCODE, SUBSTR(SQLERRM, 1, 2000));
        RETURN SQLCODE;
    END;
  END IF;

  RETURN ORACLE_NORMAL;
END;

/**************************************************************************/
/*                                                                        */
/**************************************************************************/
FUNCTION check_pallets_limit (
  pszBatchNo         IN putawaylst.parent_pallet_id%TYPE)
RETURN NUMBER IS
  iNumPallets	NUMBER := 0;
BEGIN
  IF pszBatchNo IS NULL THEN
    RETURN 0;
  END IF;

  SELECT COUNT(pt.pallet_id) INTO iNumPallets
  FROM putawaylst pt, batch b
  WHERE pt.parent_pallet_id = b.batch_no
  AND   pt.putaway_put = 'N'
  AND   SUBSTR(pt.rec_id, 1, 1) = 'S'
  AND   b.status IN ('X', 'F', 'M')
  AND   b.batch_no = pszBatchNo;

  RETURN iNumPallets;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;

-- Package initialization codes
BEGIN
  pl_log.g_application_func := 'RTNLBR';
  pl_log.g_program_name := 'pl_rtn_lm.sql';
  gszPkgMessage := NULL;
  giCode := 0;
END pl_rtn_lm;
/

SHOW ERRORS

--LIST 
