CREATE OR REPLACE PACKAGE swms.pl_replen_rf
AS
	-- sccs_id=%Z% %W% %G% %I%
	-----------------------------------------------------------------------------
	-- Package Name:
	--   pl_replen_rf
	--
	-- Description:
	--    Replenishment RF processing
	--
	-- Modification History:
	--    Date     Designer Comments
	--    -------- -------- -----------------------------------------------------
	--    12/08/11 nkee1876 Initial Version
	--
	--------------------------------------------------------------------------

	--------------------------------------------------------------------------
	-- Public Type Definitions 
	--------------------------------------------------------------------------
	--------------------------------------------------------------------------
	-- Public Functions Definitions 
	--------------------------------------------------------------------------
	FUNCTION f_last_selected_stop (
		p_route_no	IN	VARCHAR2,
		p_stop_no	IN	NUMBER)
	RETURN	NUMBER;

	FUNCTION f_route_active (
		p_route_no	IN	VARCHAR2)
	RETURN	VARCHAR2;

END pl_replen_rf;
/
CREATE OR REPLACE PACKAGE BODY swms.pl_replen_rf
AS
	FUNCTION f_last_selected_stop (
		p_route_no IN VARCHAR2,
		p_stop_no IN NUMBER)
	RETURN NUMBER IS
		last_stop_no	NUMBER (3);
	BEGIN
		SELECT	NVL (MIN (E_STOP_NO), -1)
		  INTO	last_stop_no
		  FROM	floats f, batch b
		 WHERE	f.route_no = p_route_no
		   AND	b.batch_no = 'S' || to_char (f.batch_no)
		   AND	f.pallet_pull = 'N'
		   AND	b.status = 'C'
		 GROUP	BY p_stop_no
		HAVING	p_stop_no > MIN (E_STOP_NO);

		RETURN last_stop_no;

	END f_last_selected_stop;

	FUNCTION f_route_active (
		p_route_no	IN	VARCHAR2)
	RETURN	VARCHAR2 IS
		route_active	VARCHAR2 (1);
	BEGIN
		SELECT	DECODE (COUNT (0), 0, 'N', 'Y')
		  INTO	route_active
		  FROM	floats f, batch b
		 WHERE	f.route_no = p_route_no
		   AND	b.batch_no = 'S' || to_char (f.batch_no)
		   AND	f.pallet_pull = 'N'
		   AND	b.status IN ('A', 'C');

		RETURN route_active;

	END f_route_active;

END pl_replen_rf;
/
