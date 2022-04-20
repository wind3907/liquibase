set echo off
create or replace package swms.pl_rf_stk_status as
	function ByExternalUpc
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		i_external_upc			in varchar2,
		o_prod_id				out varchar2,
		o_plogi_loc				out varchar2,
		o_qoh					out pls_integer,	-- inv.qoh number(7)
		o_descrip				out varchar2,
		o_pack					out varchar2,
		o_prod_size				out varchar2,
		o_cust_pref_vendor		out varchar2,
		o_spc					out pls_integer		-- pm.spc number(4)
	) return swms.rf.STATUS;

	function ByInternalUpc
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		i_internal_upc			in varchar2,
		o_prod_id				out varchar2,
		o_plogi_loc				out varchar2,
		o_qoh					out pls_integer,	-- inv.qoh number(7)
		o_descrip				out varchar2,
		o_pack					out varchar2,
		o_prod_size				out varchar2,
		o_cust_pref_vendor		out varchar2,
		o_spc					out pls_integer		-- pm.spc number(4)
	) return swms.rf.STATUS;

	function ByLicense
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		i_pallet_id				in varchar2,
		o_prod_id				out varchar2,
		o_plogi_loc				out varchar2,
		o_qoh					out pls_integer,	-- inv.qoh number(7)
		o_descrip				out varchar2,
		o_pack					out varchar2,
		o_prod_size				out varchar2,
		o_cust_pref_vendor		out varchar2,
		o_spc					out pls_integer		-- pm.spc number(4)
	) return swms.rf.STATUS;

	function ByProduct
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		i_product_id			in varchar2,
		i_cpv					in varchar2,
		o_descrip				out varchar2,
		o_detail_collection		out swms.stk_status_result_obj
	) return swms.rf.STATUS;

	function ByLocation
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		i_location				in varchar2,
		o_descrip				out varchar2,
		o_detail_collection		out swms.stk_status_result_obj
	) return swms.rf.STATUS;

	function Test1
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		io_rf_init_data			in out xmltype,
		i_detail_collection		in swms.stk_status_result_obj
	) return swms.rf.STATUS;
	
end pl_rf_stk_status;
/
show errors;


create or replace package body swms.pl_rf_stk_status as

	/*----------------------------------------------------------------*/
	/* Function ByExternalUpc                                         */
	/*----------------------------------------------------------------*/

	function ByExternalUpc
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		i_external_upc			in varchar2,
		o_prod_id				out varchar2,
		o_plogi_loc				out varchar2,
		o_qoh					out pls_integer,	-- inv.qoh number(7)
		o_descrip				out varchar2,
		o_pack					out varchar2,
		o_prod_size				out varchar2,
		o_cust_pref_vendor		out varchar2,
		o_spc					out pls_integer		-- pm.spc number(4)
	) 
	return swms.rf.STATUS
	IS
		rf_status			swms.rf.STATUS := swms.rf.STATUS_NORMAL;
		host_upc			VARCHAR2(14) := i_external_upc;
		hiUomSort			PLS_INTEGER := 0;

		cursor c_get_item_ext is
			SELECT
				rf.NoNull(
					DECODE (p.miniload_storage_ind,
						'B', DECODE (i.logi_loc, i.plogi_loc, i.plogi_loc, '<MINILD>'),
						'S', DECODE (i.logi_loc, i.plogi_loc, i.plogi_loc, '<MINILD>'),
						'N', DECODE (i.logi_loc, i.plogi_loc, i.plogi_loc, '<FLTING>'),
						'<MINILD>')
				) location,
				rf.NoNull(i.qoh),
				rf.NoNull(p.descrip),
				rf.NoNull(p.pack),
				rf.NoNull(trim(p.prod_size) || trim(p.prod_size_unit)),
				rf.NoNull(NVL(p.spc, '1')),
				rf.NoNull(i.prod_id),
				rf.NoNull(i.cust_pref_vendor),
				rf.NoNull(DECODE(i.inv_uom, 2, 0, 1, 1, 2)) uom_sort
			FROM loc l, pm p, inv i, pm_upc u
			WHERE
				l.logi_loc = i.plogi_loc					AND
				p.cust_pref_vendor = i.cust_pref_vendor		AND
				p.prod_id = i.prod_id						AND
				p.prod_id = u.prod_id						AND
				p.cust_pref_vendor = u.cust_pref_vendor	AND
				(
					(
						(l.perm = 'Y') AND
						(
							(
								(
									NVL(l.uom, 0) IN (0, 2)		AND
									(
										(l.rank = 1)	OR
										(l.rank IS NULL)
									)							AND
									(
										(host_upc IN (u.internal_upc, u.external_upc)) OR
										(host_upc IN (p.internal_upc, p.external_upc))
									)
								)
								OR
								(
									(NVL(l.uom, 0) = 1) AND
									(host_upc = u.internal_upc)
								)
							)
						)
					) OR
					(l.perm = 'N')
				) AND 
				(
					host_upc IN (u.internal_upc, u.external_upc) OR
					host_upc IN (p.internal_upc, p.external_upc)
				)
			ORDER BY uom_sort, l.perm DESC, i.exp_date, i.plogi_loc, i.logi_loc;

	BEGIN
		-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize().

		o_prod_id			:= ' ';
		o_plogi_loc			:= ' ';
		o_qoh				:= 0;
		o_descrip			:= ' ';
		o_pack				:= ' ';
		o_prod_size			:= ' ';
		o_cust_pref_vendor	:= ' ';
		o_spc				:= 0;


		-- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

		rf_status := rf.Initialize(i_rf_log_init_record);
		if rf_status = swms.rf.STATUS_NORMAL then

			-- main business logic begins...

			-- Step 3:  Open cursor, fetch results, close cursor

			open c_get_item_ext;

			fetch c_get_item_ext into
				o_plogi_loc, o_qoh, o_descrip, 
				o_pack, o_prod_size, o_spc, 
				o_prod_id, o_cust_pref_vendor, 
				hiUomSort;

			if c_get_item_ext%NOTFOUND then
				rf_status := rf.STATUS_INV_EXT_UPC;
			else
				rf_status := rf.STATUS_NORMAL;
			end if;

			close c_get_item_ext;

		end if;	/* rf.Initialize() returned NORMAL */


		-- Step 4:  Call rf.Complete() with final status

		rf.Complete(rf_status);
		return rf_status;

		exception
			when others then
				rf.LogException();	-- log it
				raise;				-- then throw up to next handler, if any
	end ByExternalUpc;


	/*----------------------------------------------------------------*/
	/* Function ByInternalUpc                                         */
	/*----------------------------------------------------------------*/

	function ByInternalUpc
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		i_internal_upc			in varchar2,
		o_prod_id				out varchar2,
		o_plogi_loc				out varchar2,
		o_qoh					out pls_integer,	-- inv.qoh number(7)
		o_descrip				out varchar2,
		o_pack					out varchar2,
		o_prod_size				out varchar2,
		o_cust_pref_vendor		out varchar2,
		o_spc					out pls_integer		-- pm.spc number(4)
	) 
	return swms.rf.STATUS
	IS
		rf_status			swms.rf.STATUS := swms.rf.STATUS_NORMAL;
		host_upc			VARCHAR2(14) := i_internal_upc;
		hiUomSort			PLS_INTEGER := 0;

		cursor c_get_item_int is
			SELECT
				rf.NoNull(
					DECODE (p.miniload_storage_ind,
						'B', DECODE (i.logi_loc, i.plogi_loc, i.plogi_loc, '<MINILD>'),
						'S', DECODE (i.logi_loc, i.plogi_loc, i.plogi_loc, '<MINILD>'),
						'N', DECODE (i.logi_loc, i.plogi_loc, i.plogi_loc, '<FLTING>'),
						'<MINILD>')
				) location,
				rf.NoNull(i.qoh),
				rf.NoNull(p.descrip),
				rf.NoNull(p.pack),
				rf.NoNull(trim(p.prod_size) || trim(p.prod_size_unit)),
				rf.NoNull(NVL(p.spc, '1')),
				rf.NoNull(i.prod_id),
				rf.NoNull(i.cust_pref_vendor),
				rf.NoNull(DECODE(i.inv_uom, 2, 0, 1, 1, 2)) uom_sort
			FROM loc l, pm p, inv i, pm_upc u
			WHERE
				l.logi_loc			= i.plogi_loc			AND
				p.prod_id			= i.prod_id				AND
				p.cust_pref_vendor	= i.cust_pref_vendor	AND
				p.prod_id			= u.prod_id				AND
				p.cust_pref_vendor	= u.cust_pref_vendor	AND
				(
					(
						(l.perm = 'Y') AND
						(
							(
								(
									NVL(l.uom, 0) IN (0, 2)		AND
									(
										(l.rank = 1)	OR
										(l.rank IS NULL)
									)							AND
									(
										(host_upc = u.internal_upc) OR
										(host_upc = p.internal_upc)
									)
								)
								OR
								(
									(NVL(l.uom, 0) = 1) AND
									(host_upc = u.internal_upc)
								)
							)
						)
					) OR
					(l.perm = 'N')
				) AND 
				(
					host_upc = u.internal_upc	OR
					host_upc = p.internal_upc
				)
			ORDER BY uom_sort, l.perm DESC, i.exp_date, i.plogi_loc, i.logi_loc;

	BEGIN
		-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize().

		o_prod_id			:= ' ';
		o_plogi_loc			:= ' ';
		o_qoh				:= 0;
		o_descrip			:= ' ';
		o_pack				:= ' ';
		o_prod_size			:= ' ';
		o_cust_pref_vendor	:= ' ';
		o_spc				:= 0;


		-- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

		rf_status := rf.Initialize(i_rf_log_init_record);
		if rf_status = swms.rf.STATUS_NORMAL then

			-- main business logic begins...


			-- Step 3:  open cursor, fetch results, close cursor

			open c_get_item_int;

			fetch c_get_item_int into
				o_plogi_loc, o_qoh, o_descrip, 
				o_pack, o_prod_size, o_spc, 
				o_prod_id, o_cust_pref_vendor, 
				hiUomSort;

			if c_get_item_int%NOTFOUND then
				rf_status := rf.STATUS_INV_EXT_UPC;
			else
				rf_status := rf.STATUS_NORMAL;
			end if;

			close c_get_item_int;

		end if;	/* rf.Initialize() returned NORMAL */


		-- Step 4:  Call rf.Complete() with final status

		rf.Complete(rf_status);
		return rf_status;

		exception
			when others then
				rf.LogException();	-- log it
				raise;				-- then throw up to next handler, if any
	end ByInternalUpc;


	/*----------------------------------------------------------------*/
	/* Function ByLicense                                             */
	/*----------------------------------------------------------------*/

	function ByLicense
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		i_pallet_id				in varchar2,
		o_prod_id				out varchar2,
		o_plogi_loc				out varchar2,
		o_qoh					out pls_integer,	-- inv.qoh number(7)
		o_descrip				out varchar2,
		o_pack					out varchar2,
		o_prod_size				out varchar2,
		o_cust_pref_vendor		out varchar2,
		o_spc					out pls_integer		-- pm.spc number(4)
	) 
	return swms.rf.STATUS
	IS
		rf_status			swms.rf.STATUS := swms.rf.STATUS_NORMAL;

	BEGIN
		-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize().

		o_prod_id			:= ' ';
		o_plogi_loc			:= ' ';
		o_qoh				:= 0;
		o_descrip			:= ' ';
		o_pack				:= ' ';
		o_prod_size			:= ' ';
		o_cust_pref_vendor	:= ' ';
		o_spc				:= 0;


		-- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

		rf_status := rf.Initialize(i_rf_log_init_record);
		if rf_status = swms.rf.STATUS_NORMAL then

			-- main business logic begins...
			begin

				-- Step 3:  Retrieve results

				select
					i.plogi_loc, i.qoh, p.descrip, p.pack, 
					trim(p.prod_size) || trim(p.prod_size_unit),
					NVL(p.spc, '1'), i.prod_id, i.cust_pref_vendor
				into 
					o_plogi_loc,
					o_qoh,
					o_descrip,
					o_pack,
					o_prod_size,
					o_spc,
					o_prod_id,
					o_cust_pref_vendor
				from loc l, pm p, inv i
				where
					l.logi_loc			= i.plogi_loc			AND
					p.cust_pref_vendor	= i.cust_pref_vendor	AND
					p.prod_id			= i.prod_id				AND
					i.logi_loc			= i_pallet_id;

				exception 
					when no_data_found then
					-- OPCOF-3937 Added query to handle XN pallets. Using outer join to handle Putaway records with MULTI items.
					  begin
					    select 
                                                   pa.dest_loc plogi_loc, 
                                                   nvl(pa.qty, 0) qoh, 
                                                   p.descrip, 
                                                   p.pack, 
                                                   trim(p.prod_size) || trim(p.prod_size_unit) prod_size,
                                                   NVL(p.spc, '1') spc, 
                                                   pa.prod_id, 
                                                   pa.cust_pref_vendor
					    into 
                                                   o_plogi_loc,
                                                   o_qoh,
                                                   o_descrip,
                                                   o_pack,
                                                   o_prod_size,
                                                   o_spc,
                                                   o_prod_id,
                                                   o_cust_pref_vendor
                                              from putawaylst pa,
                                                   erm e, 
                                                   pm p
                                             where 
                                                   e.erm_id = pa.rec_id and 
                                                   p.cust_pref_vendor(+) = pa.cust_pref_vendor	AND
                                                   p.prod_id(+) = pa.prod_id  and
                                                   pa.pallet_id = i_pallet_id and 
                                                   e.erm_type = 'XN' and 
                                                   rownum = 1;
					  exception 
					    when no_data_found then 
--						rf_status := rf.STATUS_INV_LABEL;
                                              -- OPCOF-4038 Added new query to handle XDK tasks. 
                                              begin
					        select 
                                                       r.door_no plogi_loc, 
                                                       nvl(r.qty, 0) qoh, 
                                                       p.descrip, 
                                                       p.pack, 
                                                       trim(p.prod_size) || trim(p.prod_size_unit) prod_size,
                                                       NVL(p.spc, '1') spc, 
                                                       r.prod_id, 
                                                       r.cust_pref_vendor
					          into 
                                                       o_plogi_loc,
                                                       o_qoh,
                                                       o_descrip,
                                                       o_pack,
                                                       o_prod_size,
                                                       o_spc,
                                                       o_prod_id,
                                                       o_cust_pref_vendor
                                                  from replenlst r,
                                                       pm p
                                                 where 
                                                       p.cust_pref_vendor(+) = r.cust_pref_vendor	AND
                                                       p.prod_id(+) = r.prod_id  and
                                                       r.pallet_id = i_pallet_id and 
                                                       r.type = 'XDK' and 
                                                       rownum = 1;

					      exception 
					        when no_data_found then 
					          rf_status := rf.STATUS_INV_LABEL;

                                             end;

					  end;
					
			
			end; /* begin */


			-- Step 4:  De-nullify scalar results

			select
				rf.NoNull(o_plogi_loc),
				rf.NoNull(o_qoh),
				rf.NoNull(o_descrip),
				rf.NoNull(o_pack),
				rf.NoNull(o_prod_size),
				rf.NoNull(o_spc),
				rf.NoNull(o_prod_id),
				rf.NoNull(o_cust_pref_vendor)
			into
				o_plogi_loc,
				o_qoh,
				o_descrip,
				o_pack,
				o_prod_size,
				o_spc,
				o_prod_id,
				o_cust_pref_vendor
			from dual;

		end if;	/* rf.Initialize() returned NORMAL */


		-- Step 5:  Call rf.Complete() with final status

		rf.Complete(rf_status);
		return rf_status;

		exception
			when others then
				rf.LogException();	-- log it
				raise;				-- then throw up to next handler, if any
	end ByLicense;


	/*----------------------------------------------------------------*/
	/* Function ByProduct                                             */
	/*----------------------------------------------------------------*/

	function ByProduct
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		i_product_id			in varchar2,
		i_cpv					in varchar2,
		o_descrip				out varchar2,
		o_detail_collection		out swms.stk_status_result_obj
	)
	return swms.rf.STATUS
	IS
		rf_status					swms.rf.STATUS := swms.rf.STATUS_NORMAL;

		l_result_table				swms.stk_status_result_table;
		l_pallet_id_len				constant simple_integer := 18;

	BEGIN
		-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize().

		o_descrip			:= ' '; -- empty string causes ora-01405
		o_detail_collection	:= swms.stk_status_result_obj(swms.stk_status_result_table());


		-- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

		rf_status := rf.Initialize(i_rf_log_init_record);
		if rf_status = swms.rf.STATUS_NORMAL then

			-- main business logic begins...
			begin

				-- Step 3:  Retrieve scalar field(s)

				SELECT rf.NoNull(p.descrip)
				INTO o_descrip						-- output directly into OUT parameter
				FROM pm p
				WHERE
					p.cust_pref_vendor	= i_cpv					and
					p.prod_id			= i_product_id;


				-- Step 4:  Retrieve collection of records

				SELECT swms.stk_status_result_record(
					i.logi_loc,
					i.qoh,
					NVL(p.spc, '1'),
					i.plogi_loc)
				BULK COLLECT INTO l_result_table	-- output into local temporary table
				FROM loc l, pm p, inv i
				WHERE
					l.logi_loc			= i.plogi_loc			AND
					p.cust_pref_vendor	= i.cust_pref_vendor	AND
					p.prod_id			= i.prod_id				AND
					i.cust_pref_vendor	= i_cpv					AND
					i.prod_id			= i_product_id
				ORDER BY i.plogi_loc, i.logi_loc, LPAD(i.logi_loc, l_pallet_id_len, '0');

				o_detail_collection := swms.stk_status_result_obj(l_result_table);	-- set OUT parm to temp table

				exception 
					when no_data_found then
						rf_status := rf.STATUS_INV_PRODID;
			
			end; /* begin */

		end if;	/* rf.Initialize() returned NORMAL */

		
		-- Step 5:  Call rf.Complete() with final status

		rf.Complete(rf_status);
		return rf_status;

		exception
			when others then
				rf.LogException();	-- log it
				raise;				-- then throw up to next handler, if any
	end ByProduct;


	/*----------------------------------------------------------------*/
	/* Function ByLocation                                            */
	/*----------------------------------------------------------------*/

	function ByLocation
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		i_location				in varchar2,
		o_descrip				out varchar2,
		o_detail_collection		out swms.stk_status_result_obj
	)
	return swms.rf.STATUS
	IS
		rf_status					swms.rf.STATUS := swms.rf.STATUS_NORMAL;

		l_result_table				swms.stk_status_result_table;
		l_pallet_id_len				constant simple_integer := 18;

	BEGIN
		-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize().

		o_descrip			:= ' '; -- empty string causes ora-01405
		o_detail_collection	:= swms.stk_status_result_obj(swms.stk_status_result_table());


		-- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

		rf_status := rf.Initialize(i_rf_log_init_record);
		if rf_status = swms.rf.STATUS_NORMAL then

			-- main business logic begins...
			begin

				-- Step 3:  Retrieve scalar field(s)

				begin
					SELECT rf.NoNull(p.descrip)
					INTO o_descrip						-- output directly into OUT parameter
					FROM loc l, pm p, inv i
					WHERE
						l.logi_loc			= i.plogi_loc			and
						p.cust_pref_vendor	= i.cust_pref_vendor	and
						p.prod_id			= i.prod_id				and
						i.plogi_loc			= i_location;

					exception
						when too_many_rows then
							o_descrip := '*More*';
				end;


				-- Step 4:  Retrieve collection of records

				SELECT swms.stk_status_result_record(
					i.logi_loc,
					i.qoh,
					NVL(p.spc, '1'),
					p.prod_id)
				BULK COLLECT INTO l_result_table	-- output into local temporary table
				FROM loc l, pm p, inv i
				WHERE
					l.logi_loc			= i.plogi_loc			AND
					p.cust_pref_vendor	= i.cust_pref_vendor	AND
					p.prod_id			= i.prod_id				AND
					i.plogi_loc			= i_location
				ORDER BY i.prod_id, i.cust_pref_vendor, i.logi_loc, LPAD(i.logi_loc, l_pallet_id_len, '0');

				-- See http://docs.oracle.com/cd/E18283_01/appdev.112/e17126/tuning.htm#BABCCJCB

				if l_result_table is null or l_result_table.count = 0 then
					raise no_data_found;
				else
					o_detail_collection := swms.stk_status_result_obj(l_result_table);	-- set OUT parm to temp table
				end if;

				exception 
					when no_data_found then
						rf_status := rf.STATUS_INV_LOCATION;
			end; /* begin */

		end if;	/* rf.Initialize() returned NORMAL */


		-- Step 5:  Call rf.Complete() with final status

		rf.Complete(rf_status);
		return rf_status;

		exception
			when others then
				rf.LogException();	-- log it
				raise;				-- then throw up to next handler, if any
	end ByLocation;


	/*----------------------------------------------------------------*/
	/* Function Test1 (@@ temp for testing)                           */
	/*----------------------------------------------------------------*/

	function Test1
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		io_rf_init_data			in out xmltype,
		i_detail_collection		in swms.stk_status_result_obj
	)
	return swms.rf.STATUS
	IS
		rf_status					swms.rf.STATUS := swms.rf.STATUS_NORMAL;

	BEGIN
		rf_status := rf.Initialize(i_rf_log_init_record);
		if rf_status = swms.rf.STATUS_NORMAL then

			-- main business logic begins...

			begin
				rf.logmsg(rf.LOG_DEBUG,'count = ' || i_detail_collection.result_table.count);
			end;

		end if;	/* rf.Initialize() returned NORMAL */

		rf.Complete(rf_status);
		return rf_status;

		exception
			when others then
				rf.LogException();	-- log it
				raise;				-- then throw up to next handler, if any
	end Test1;
end pl_rf_stk_status;
/
show errors;


alter package swms.pl_rf_stk_status compile plsql_code_type = native;

grant execute on swms.pl_rf_stk_status to swms_user;
create or replace public synonym pl_rf_stk_status for swms.pl_rf_stk_status;
