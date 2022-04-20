
-- set echo on

-- CREATE OR REPLACE LIBRARY SWMS.libswmslm AS '/swms/dvlp30/lib/libswmslm.so';
BEGIN
$if dbms_db_version.ver_le_11 $then
	EXECUTE IMMEDIATE 'create or replace library SWMS.libswmslm as ''/swms/curr/lib/libswmslm.so''';
$else
	EXECUTE IMMEDIATE 'create or replace library SWMS.libswmslm as ''/swms/curr/lib/libswmslm.so'' AGENT ''EXTPROC_LINK''';
$end
END;
/
show sqlcode
show errors

CREATE OR REPLACE PACKAGE SWMS.pl_libswmslm
AS
-----------------------------------------------------------------------------
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    04/13/16 bbbe0556 Brian Bent
--                      Project:
--                R30.4--WIB#625--Charm6000011676_Symbotic_Throttling_enhancement
--
--                      Having issue with the IN paramaters with CHAR datatype.
--                      The value is getting "trashed".
--                      Change CHAR to VARCHAR2 and will make the appropriate
--                      changes to "lm_extproc.pc".
--
--                      FUNCTION lmf_signon_to_forklift_batch
--                         i_cmd   IN CHAR
--                      changed to
--                         i_cmd   IN VARCHAR2
--
--                      FUNCTION attach_to_OP_forklift_batch
--                         i_pallet_pull    IN CHAR
--                         i_suspend_flag   IN CHAR
--                         i_merge_flag     IN CHAR
--                      changed to
--                         i_pallet_pull    IN VARCHAR2
--                         i_suspend_flag   IN VARCHAR2
--                         i_merge_flag     IN VARCHAR2
--
--                      FUNCTION attach_to_OP_dmd_fk_batch
--                         i_c_suspend_flag  IN CHAR
--                         i_c_merge_flag    IN CHAR
--                      changed to
--                         i_suspend_flag  IN VARCHAR2
--                         i_merge_flag    IN VARCHAR2
--
--                      In the programs that were calling "pl_libswmslm.sql"
--                      passing i_cmd and the suspend and merge flags made
--                      sure the datatype was VARCHAR2.
-----------------------------------------------------------------------------




-- ---------------------------------------------------------------------
--                                                                     -
-- Prototype in inc/lmc.h:                                             -
--     int lmc_batch_istart(char *, char *, char *);                   -
--                                                                     -
-- Function source in lib/libswmslm/lm_common.pc:                      -
--     int                                                             -
--     lmc_batch_istart(char *i_user_id, char *o_prev_batch_no,        -
--     char *o_supervisor_id)                                          -
--                                                                     -
-- ---------------------------------------------------------------------

	FUNCTION lmc_batch_istart
	(
		i_user_id		IN VARCHAR2,
		o_prev_batch_no		OUT VARCHAR2,
		o_supervisor_id		OUT VARCHAR2
	) RETURN PLS_INTEGER;


-- ---------------------------------------------------------------------
--                                                                     -
-- Prototype in inc/lmf.h:                                             -
--     int lmf_signon_to_forklift_batch(char, char *, char *, char *,  -
--         char *, char *);                                            -
--                                                                     -
-- Function source in lib/libswmslm/lm_forklift.pc:                    -
--     int                                                             -
--     lmf_signon_to_forklift_batch(                                   -
--         char i_cmd,                                                 -
--         char *i_batch_no,                                           -
--         char *i_parent_batch_no,                                    -
--         char *i_user_id,                                            -
--         char *i_supervisor,                                         -
--         char *i_equip_id)                                           -
--                                                                     -
-- ---------------------------------------------------------------------

	FUNCTION lmf_signon_to_forklift_batch
	(
		i_cmd			IN VARCHAR2,
		i_batch_no		IN VARCHAR2,
		i_parent_batch_no	IN VARCHAR2,
		i_user_id		IN VARCHAR2,
		i_supervisor		IN VARCHAR2,
		i_equip_id		IN VARCHAR2
	) RETURN PLS_INTEGER;


-- ---------------------------------------------------------------------
--                                                                     -
-- Prototype in inc/lmf.h:                                             -
--     int lmf_forklift_active(void);                                  -
--                                                                     -
-- Function source in lib/libswmslm/lm_forklift.pc:                    -
--     int                                                             -
--     lmf_forklift_active()                                           -
--                                                                     -
-- ---------------------------------------------------------------------

	FUNCTION lmf_forklift_active
	RETURN PLS_INTEGER;



-- ---------------------------------------------------------------------
--                                                                     -
-- Prototype in (no prototype in any .h file)                          -
--                                                                     -
-- Function source in lib/libswmslm/lm_fork.pc:                        -
--     int                                                             -
--     attach_to_OP_forklift_batch(                                    -
--        long i_float_no,                                             -
--        char i_pallet_pull,                                          -
--        char *i_user_id                                              -
--        char *i_equip_id,                                            -
--        char i_suspend_flag,                                         -
--        long i_drop_qty)                                             -
--                                                                     -
-- merge_flag is a global variable referenced in the Pro*C code, so it -
-- is also a required parameter for the PL/SQL caller.                 -
--                                                                     -
-- ---------------------------------------------------------------------

	FUNCTION attach_to_OP_forklift_batch
	(
		i_float_no		IN PLS_INTEGER,
		i_pallet_pull		IN VARCHAR2,
		i_user_id		IN VARCHAR2,
		i_equip_id		IN VARCHAR2,
		i_suspend_flag		IN VARCHAR2,
		i_drop_qty		IN PLS_INTEGER,
		i_merge_flag		IN VARCHAR2
	) 
	RETURN PLS_INTEGER;


-- ---------------------------------------------------------------------
--                                                                     -
-- Prototype in (no prototype in any .h file)                          -
--                                                                     -
-- Function source in lib/libswmslm/lm_fork.pc:                        -
--     int                                                             -
--     attach_to_OP_dmd_forklift_batch(                                -
--         char *i_psz_batch_no,                                       -
--         char *i_psz_user_id,                                        -
--         char *i_psz_equip_id,                                       -
--         char i_c_suspend_flag)                                      -
--                                                                     -
-- merge_flag is a global variable referenced in the Pro*C code, so it -
-- is also a required parameter for the PL/SQL caller.                 -
--                                                                     -
-- ---------------------------------------------------------------------

	FUNCTION attach_to_OP_dmd_fk_batch
	(
		i_psz_batch_no		IN VARCHAR2,
		i_psz_user_id		IN VARCHAR2,
		i_psz_equip_id		IN VARCHAR2,
		i_suspend_flag		IN VARCHAR2,
		i_merge_flag		IN VARCHAR2
	)
	RETURN PLS_INTEGER;


-- ---------------------------------------------------------------------
--                                                                     -
-- Prototype in (no prototype in any .h file)                          -
--                                                                     -
-- Function source in lib/libswmslm/lm_fork.pc:                        -
--     int                                                             -
--     reset_OP_forklift_batch(                                        -
--         char *i_user_id,                                            -
--         char *i_equip_id)                                           -
--                                                                     -
-- ---------------------------------------------------------------------

	FUNCTION reset_OP_forklift_batch
	(
		i_user_id			IN VARCHAR2,
		i_equip_id			IN VARCHAR2
	)
	RETURN PLS_INTEGER;

END pl_libswmslm;
/
SHOW ERRORS

CREATE OR REPLACE PACKAGE BODY SWMS.pl_libswmslm
AS
	FUNCTION lmc_batch_istart
	(
		i_user_id		IN  VARCHAR2,
		o_prev_batch_no		OUT VARCHAR2,
		o_supervisor_id		OUT VARCHAR2
	) RETURN PLS_INTEGER
	AS
		EXTERNAL
		LIBRARY		libswmslm
		NAME		"extproc_lmc_batch_istart"
		LANGUAGE	C
		WITH		CONTEXT
		PARAMETERS
		(
			CONTEXT,
			i_user_id		STRING,
			o_prev_batch_no		STRING,
			o_prev_batch_no		LENGTH,
			o_prev_batch_no		MAXLEN,
			o_supervisor_id		STRING,
			o_supervisor_id		LENGTH,
			o_supervisor_id		MAXLEN
		);


	FUNCTION lmf_signon_to_forklift_batch
	(
		i_cmd			IN VARCHAR2,
		i_batch_no		IN VARCHAR2,
		i_parent_batch_no	IN VARCHAR2,
		i_user_id		IN VARCHAR2,
		i_supervisor		IN VARCHAR2,
		i_equip_id		IN VARCHAR2
	) RETURN PLS_INTEGER
	AS
		EXTERNAL
		LIBRARY		libswmslm
		NAME		"extproc_lmf_signon_to_fk_batch" -- name shorted to avoid PLS-00114
		LANGUAGE	C
		WITH		CONTEXT
		PARAMETERS
		(
			CONTEXT,
			i_cmd			STRING,
			i_batch_no		STRING,
			i_parent_batch_no	STRING,
			i_user_id		STRING,
			i_supervisor		STRING,
			i_equip_id		STRING
		);


	FUNCTION lmf_forklift_active
	RETURN PLS_INTEGER
	AS
		EXTERNAL
		LIBRARY		libswmslm
		NAME		"extproc_lmf_forklift_active"
		LANGUAGE	C
		WITH		CONTEXT
		PARAMETERS
		(
			CONTEXT
		);


	FUNCTION attach_to_OP_forklift_batch
	(
		i_float_no		IN PLS_INTEGER,
		i_pallet_pull		IN VARCHAR2,
		i_user_id		IN VARCHAR2,
		i_equip_id		IN VARCHAR2,
		i_suspend_flag		IN VARCHAR2,
		i_drop_qty		IN PLS_INTEGER,
		i_merge_flag		IN VARCHAR2
	) 
	RETURN PLS_INTEGER
	AS
		EXTERNAL
		LIBRARY		libswmslm
		NAME		"extproc_att_to_OP_fk_batch" -- name shorted to avoid PLS-00114
		LANGUAGE	C
		WITH		CONTEXT
		PARAMETERS
		(
			CONTEXT,
			i_float_no		INT,
			i_pallet_pull		STRING,
			i_user_id		STRING,
			i_equip_id		STRING,
			i_suspend_flag		STRING,
			i_drop_qty		INT,
			i_merge_flag		STRING
		);


	FUNCTION attach_to_OP_dmd_fk_batch
	(
		i_psz_batch_no		IN VARCHAR2,
		i_psz_user_id		IN VARCHAR2,
		i_psz_equip_id		IN VARCHAR2,
		i_suspend_flag		IN VARCHAR2,
		i_merge_flag		IN VARCHAR2
	)
	RETURN PLS_INTEGER
	AS
		EXTERNAL
		LIBRARY		libswmslm
		NAME		"extproc_att_to_OP_dmd_fk_batch" -- name shorted to avoid PLS-00114
		LANGUAGE	C
		WITH		CONTEXT
		PARAMETERS
		(
			CONTEXT,
			i_psz_batch_no		STRING,
			i_psz_user_id		STRING,
			i_psz_equip_id		STRING,
			i_suspend_flag		STRING,
			i_merge_flag		STRING
		);


	FUNCTION reset_OP_forklift_batch
	(
		i_user_id			IN VARCHAR2,
		i_equip_id			IN VARCHAR2
	)
	RETURN PLS_INTEGER
	AS
		EXTERNAL
		LIBRARY		libswmslm
		NAME		"extproc_reset_OP_fk_batch" -- name shorted to avoid PLS-00114
		LANGUAGE	C
		WITH		CONTEXT
		PARAMETERS
		(
			CONTEXT,
			i_user_id			STRING,
			i_equip_id			STRING
		);


END pl_libswmslm;
/
show errors;

grant execute on SWMS.pl_libswmslm to public;
create or replace public synonym pl_libswmslm for swms.pl_libswmslm;
