rem *****************************************************
rem @(#) src/schema/plsql/pl_sos_reassign.sql, swms, swms.9, 10.1.1 9/7/06 1.9

rem @(#) File : pl_sos_reassign.sql
rem @(#) Usage: sqlplus USR/PWD pl_sos_reassign.sql

rem ---  Maintenance history  ---
rem 10-OCT-2004 prpakp Initial version
rem                    This will create new batches when batches are reassigned.
rem                    calculates the goal time for reassigned batches and
rem                    short batches. This is called from sosdb.pc
rem 25-FEB-2005 prpakp Added change to calculate cool data collection.
rem 31-OCT-2005 prpakp Corrected the reassign total pallet and cases count for reassigned batch.
rem 26-JUN-2006 prppxx Handle NULL value in parent_batch_no for optimum pull
rem		       batch (MULTI). D#12103.
rem 28-OCT-2014 spot3255 Charm# 6000003789 - Ireland Cubic values - Metric conversion project
rem                          Increased length of below variables to hold Cubic centimeter.
rem                          total_cube Changed data type from NUMBER (8,4) to NUMBER (12,4)
rem                          split_cube  Changed data type from NUMBER (8,4) to NUMBER (12,4)
rem                          case_cube Changed data type from NUMBER (8,4) to NUMBER (12,4)


CREATE OR REPLACE PACKAGE swms.pl_sos_reassign IS
/*==================================================================================*/
procedure sos_reassign( i_batch_no in arch_batch.batch_no%TYPE);

PROCEDURE calc_kvi(i_type in varchar,
                   i_batch_no in arch_batch.batch_no%TYPE,
                   i_user_id in arch_batch.user_id%TYPE,
                   o_num_stops out arch_batch.kvi_no_stop%TYPE,
                   o_num_zones  out arch_batch.kvi_no_zone%TYPE,
                   o_num_locs out arch_batch.kvi_no_loc%TYPE,
                   o_num_splits out arch_batch.kvi_no_split%TYPE,
                   o_num_cases out arch_batch.kvi_no_case%TYPE, 
                   o_num_merges out arch_batch.kvi_no_merge%TYPE, 
                   o_num_data_captures out arch_batch.kvi_no_data_capture%TYPE,
                   o_num_aisles out arch_batch.kvi_no_aisle%TYPE, 
                   o_num_items out arch_batch.kvi_no_item%TYPE,
                   o_total_wt  out arch_batch.kvi_wt%TYPE, 
                   o_total_cube out arch_batch.kvi_cube%type,
                   o_num_pieces out arch_batch.kvi_no_piece%TYPE,
                   o_num_floats out arch_batch.kvi_no_pallet%TYPE,
                   o_success out varchar);

PROCEDURE calc_kvi_short(i_type in varchar,
                   i_batch_no in arch_batch.batch_no%TYPE,
                   i_user_id in arch_batch.user_id%TYPE,
                   o_num_stops out arch_batch.kvi_no_stop%TYPE,
                   o_num_zones  out arch_batch.kvi_no_zone%TYPE,
                   o_num_locs out arch_batch.kvi_no_loc%TYPE,
                   o_num_splits out arch_batch.kvi_no_split%TYPE,
                   o_num_cases out arch_batch.kvi_no_case%TYPE, 
                   o_num_merges out arch_batch.kvi_no_merge%TYPE, 
                   o_num_data_captures out arch_batch.kvi_no_data_capture%TYPE,
                   o_num_aisles out arch_batch.kvi_no_aisle%TYPE, 
                   o_num_items out arch_batch.kvi_no_item%TYPE,
                   o_total_wt  out arch_batch.kvi_wt%TYPE, 
                   o_total_cube out arch_batch.kvi_cube%type,
                   o_num_pieces out arch_batch.kvi_no_piece%TYPE,
                   o_num_floats out arch_batch.kvi_no_pallet%TYPE,
                   o_success out varchar);

PROCEDURE calc_goal_time(i_batch_no in arch_batch.batch_no%Type);

END pl_sos_reassign;
/

/*====================================================================================*/
CREATE OR REPLACE PACKAGE BODY swms.pl_sos_reassign IS
/* ========================================================================== */
procedure sos_reassign ( i_batch_no arch_batch.batch_no%TYPE) is

      user_id		arch_batch.user_id%TYPE;
      num_stops 	number(5) := NULL;
      num_zones 	number(5) := NULL;
      num_locs 		number(5) := NULL;
      num_splits 	number(5) := NULL;
      num_cases 	number(5) := NULL;
      num_merges 	number(5) := NULL;
      num_data_captures number(5) := NULL;
      num_aisles	number(5) := NULL;
      num_items		number(5) := NULL;
      num_pieces	number(5) := NULL;
      num_floats	number(5) := NULL;
      total_wt		number(8,4) := NULL;
      total_cube	number(12,4) := NULL;
      error_prob     	varchar2(200) := SQLERRM;
      l_success      	varchar2(1);
      batch_ext      	number(2);
      l_batch_no     	arch_batch.batch_no%Type;
      l_batch_noS    arch_batch.batch_no%Type;
      l_dummy       	arch_batch.batch_no%Type;
      l_ref_no          arch_batch.ref_no%TYPE;
      short_yn      	varchar2(1);

      cursor c1 is select batch_no from batch
		   where batch_no = l_batch_no;

begin
     l_success := 'N';
      begin
	 SELECT USER_ID,decode(substr(jbcd_job_code,2,5),'SHORT','S','N'), ref_no
         INTO user_id,short_yn, l_ref_no
         FROM BATCH
         WHERE BATCH_NO= 'S'||i_batch_no
         and   status ='C';
	 begin
	    	if short_yn = 'S' then
 			calc_kvi_short('N',i_batch_no,user_id,num_stops,num_zones,num_locs,
                        	 num_splits,num_cases, num_merges, num_data_captures,
                         	num_aisles, num_items,total_wt, total_cube,num_pieces, num_floats, l_success);
	    	else
 			calc_kvi('N',i_batch_no,user_id,num_stops,num_zones,num_locs,
                        	 num_splits,num_cases, num_merges, num_data_captures,
                         	num_aisles, num_items,total_wt, total_cube,num_pieces, num_floats, l_success);
            	end if;
                if l_success = 'Y' then

                    begin
                       select count(batch_no) into batch_ext
                       from batch
                       where batch_no like 'S'||i_batch_no||'%';
                        
                       exception
                         when others then
                             batch_ext := 1;
                     end;

		     select 'S'||i_batch_no||to_char(batch_ext), i_batch_no||to_char(batch_ext) 
		     into l_batch_no,l_batch_noS from dual;

		     loop
			open c1;
			fetch c1 into l_dummy;
			if c1%found then
				batch_ext := batch_ext +1;
		     		select 'S'||i_batch_no||to_char(batch_ext),i_batch_no||to_char(batch_ext)
			        into l_batch_no,l_batch_noS from dual;
			else
				exit;
			end if;
			close c1;
		     end loop;

		    INSERT INTO BATCH ( batch_no, batch_date, status,
                          jbcd_job_code, ref_no,actl_start_time,
                          actl_stop_time,actl_time_spent,
                          user_id,user_supervsr_id,kvi_cube, kvi_wt,
                          kvi_no_piece, kvi_no_case, kvi_no_split,
                          kvi_no_merge, kvi_no_item, kvi_no_stop,
                          kvi_no_zone, kvi_no_loc, kvi_no_aisle,
                          kvi_no_data_capture, kvi_no_pallet )
                    SELECT l_batch_no,
                          BATCH_DATE, STATUS, JBCD_JOB_CODE,
                          REF_NO, ACTL_START_TIME, ACTL_STOP_TIME,
                          ACTL_TIME_SPENT, USER_ID, USER_SUPERVSR_ID,
                          total_cube, total_wt,
                          num_pieces, num_cases, num_splits,
                          num_merges, num_items, num_stops,
                          num_zones, num_locs, num_aisles,
                          num_data_captures, num_floats
                    FROM BATCH
                    WHERE batch_no = 'S'||i_batch_no;
                  
		    if short_yn ='S' then
                    	UPDATE FLOAT_HIST
                    	SET SHORT_BATCH_NO = l_batch_noS
                    	WHERE  short_batch_no = i_batch_no
                    	AND    short_user_id = user_id
                    	AND    short_picktime is not null;

			UPDATE SOS_SHORT
			SET SHORT_BATCH_NO = l_batch_noS
			WHERE SHORT_BATCH_NO= i_batch_no
                        AND   ORDERSEQ IN (SELECT v.ORDERSEQ 
					   FROM V_SOS_SHORT v,FLOAT_HIST h
					   WHERE v.BATCH_NO = h.BATCH_NO
                                           AND   v.INVOICENO= h.ORDER_ID
					   AND   v.ORDER_LINE_ID = h.ORDER_LINE_ID
 					   AND   v.ITEM = h.PROD_ID
				 	   AND   h.SHORT_BATCH_NO = l_batch_noS);
		    else
                    	UPDATE FLOAT_HIST
                    	SET BATCH_NO = l_batch_noS
                    	WHERE  batch_no = i_batch_no
                    	AND    user_id = user_id
                    	AND    picktime is not null;
		    end if;	
		    calc_goal_time(l_batch_no);

		    if short_yn ='S' then
 		   	 calc_kvi_short('R',i_batch_no,null,num_stops,num_zones,num_locs,
                        	 num_splits,num_cases, num_merges, num_data_captures,
                         	 num_aisles, num_items,total_wt, total_cube,num_pieces,num_floats,  l_success);
                    else 
 		         calc_kvi('R',i_batch_no,null,num_stops,num_zones,num_locs,
                        	 num_splits,num_cases, num_merges, num_data_captures,
                         	 num_aisles, num_items,total_wt, total_cube,num_pieces,num_floats,  l_success);
                    end if;
                    if l_success = 'Y'  then

			UPDATE BATCH
                	SET kvi_cube 		= total_cube,
		    		kvi_wt 		= total_wt,
                    		kvi_no_piece 	= num_pieces, 
                    		kvi_no_case 	= num_cases, 
                    		kvi_no_split 	= num_splits,
                    		kvi_no_merge 	= num_merges, 
                    		kvi_no_item 	= num_items, 
                    		kvi_no_stop 	= num_stops,
                    		kvi_no_zone 	= num_zones, 
                    		kvi_no_loc 	= num_locs, 
                    		kvi_no_aisle 	= num_aisles,
                    		kvi_no_data_capture = num_data_captures, 
                    		kvi_no_pallet	= num_floats,
				user_id =null,
				user_supervsr_id = null,
				actl_start_time = null,
				actl_stop_time = null,
				actl_time_spent =null
                	WHERE batch_no = 'S'||i_batch_no;

                        if l_ref_no = 'MULTI' then
                            begin
                                select sum(nvl(kvi_no_piece,0)),
					sum(nvl(kvi_no_case,0)),
					sum(nvl(kvi_no_split,0)),
					sum(nvl(kvi_no_merge,0)),
					sum(nvl(kvi_no_aisle,0)),
					sum(nvl(kvi_no_loc,0)),
					sum(nvl(kvi_no_stop,0)),
					sum(nvl(kvi_no_zone,0)),
					sum(nvl(kvi_no_item,0)),
					sum(nvl(kvi_no_data_capture,0)),
					sum(nvl(kvi_no_pallet,0))
                                into num_pieces,num_cases,num_splits,num_merges, num_aisles,
				     num_locs,num_stops, num_zones,num_items,num_data_captures,num_floats
                                from batch
                                where parent_batch_no = 'S'||i_batch_no
                                and batch_no <> parent_batch_no;
                                begin

				   UPDATE BATCH
                        	   SET 	kvi_cube     = 0.0,
					kvi_wt       = 0.0,
					kvi_no_piece = kvi_no_piece - num_pieces,
					kvi_no_case  = kvi_no_case - num_cases,
					kvi_no_split = kvi_no_split - num_splits,
					kvi_no_merge = kvi_no_merge - num_merges,
					kvi_no_aisle = kvi_no_aisle - num_aisles,
					kvi_no_loc   = kvi_no_loc - num_locs,
					kvi_no_stop  = kvi_no_stop - num_stops,
					kvi_no_zone  = kvi_no_zone - num_zones,
					kvi_no_item  = kvi_no_item - num_items,
					kvi_no_data_capture = kvi_no_data_capture
                      					- num_data_captures,
					kvi_no_pallet = kvi_no_pallet -num_floats
                	            WHERE batch_no = 'S'||i_batch_no;
                                    exception
                                       when others then
                                             null;
                                end;
                                exception
                                   when others then
                                       null;
                            end;

                        end if;

		        calc_goal_time('S'||i_batch_no);
                   end if;
            else

                   INSERT INTO BATCH (BATCH_NO, BATCH_DATE, JBCD_JOB_CODE, STATUS,
                	REF_NO,ACTL_START_TIME, ACTL_STOP_TIME,
                	ACTL_TIME_SPENT, USER_ID, USER_SUPERVSR_ID,
                	KVI_DOC_TIME,KVI_CUBE,KVI_WT,KVI_NO_PIECE,
                	KVI_NO_PALLET,KVI_NO_ITEM,KVI_NO_DATA_CAPTURE,
                	KVI_NO_PO,KVI_NO_STOP,KVI_NO_ZONE,KVI_NO_LOC,
                	KVI_NO_CASE,KVI_NO_SPLIT,KVI_NO_MERGE,KVI_NO_AISLE,
                	KVI_NO_DROP,KVI_ORDER_TIME,NO_LUNCHES, NO_BREAKS,DAMAGE)
                   SELECT  'I'||TO_CHAR(SEQ1.NEXTVAL), BATCH_DATE, 'IRASGN', 'C',
                	i_batch_no, ACTL_START_TIME, ACTL_STOP_TIME,
                	ACTL_TIME_SPENT, USER_ID, USER_SUPERVSR_ID,
               		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                   FROM BATCH
        	   WHERE BATCH_NO = 'S'||i_batch_no;
            end if;
	 end;
         EXCEPTION
    		when others then
       			error_prob := SQLERRM;
       			rollback;
       			pl_log.ins_msg('F','sos_reassign', 'Batch_no is '||i_batch_no , null,null);
       			pl_log.ins_msg('F','sos_reassign',error_prob,null,null);
       			commit;
     end;
end sos_reassign;

/* ========================================================================== */

PROCEDURE calc_kvi(i_type in varchar,
                   i_batch_no in arch_batch.batch_no%TYPE,
                   i_user_id in arch_batch.user_id%TYPE,
                   o_num_stops out arch_batch.kvi_no_stop%TYPE,
                   o_num_zones  out arch_batch.kvi_no_zone%TYPE,
                   o_num_locs out arch_batch.kvi_no_loc%TYPE,
                   o_num_splits out arch_batch.kvi_no_split%TYPE,
                   o_num_cases out arch_batch.kvi_no_case%TYPE, 
                   o_num_merges out arch_batch.kvi_no_merge%TYPE, 
                   o_num_data_captures out arch_batch.kvi_no_data_capture%TYPE,
                   o_num_aisles out arch_batch.kvi_no_aisle%TYPE, 
                   o_num_items out arch_batch.kvi_no_item%TYPE,
                   o_total_wt  out arch_batch.kvi_wt%TYPE, 
                   o_total_cube out arch_batch.kvi_cube%type,
                   o_num_pieces out arch_batch.kvi_no_piece%TYPE,
                   o_num_floats out arch_batch.kvi_no_pallet%TYPE,
                   o_success out varchar) is

      split_wt		number(8,4);
      split_cube	number(12,4);
      case_wt		number(8,4);
      case_cube		number(12,4);
      num_routes	number(5);
      num_s_merges      number(5);
      cool_kvi          number(5);
      l_type            varchar2(1);
begin
        case_wt :=0;
        split_wt := 0;
        case_cube := 0;
        split_cube := 0;
        cool_kvi :=0;
        l_type := i_type;

 	SELECT COUNT(DISTINCT (d.float_no||d.stop_no)),
                COUNT(DISTINCT (d.float_no||d.zone)),
                COUNT(DISTINCT d.float_no),
                COUNT(DISTINCT d.src_loc),
                SUM(DECODE(d.merge_alloc_flag,'M',0,'S',0,DECODE(d.uom,1,d.qty_alloc,0) ) ),
                SUM(DECODE(d.merge_alloc_flag,'M',0,'S',0,DECODE(d.uom,2,d.qty_alloc/nvl(p.spc,1), null,
                                                                 d.qty_alloc/nvl(p.spc,1),0) ) ),
                SUM(DECODE(d.merge_alloc_flag,'M',DECODE(d.uom,2,round(d.qty_alloc/nvl(p.spc,1)),1,d.qty_alloc,0),'S',0,0) ),
                SUM(DECODE(p.catch_wt_trk, 'Y', DECODE(d.uom,1,d.qty_alloc,d.qty_alloc/nvl(spc,1)),0) )+
		SUM (DECODE (nvl (sysp.config_flag_val, 'N'), 'Y',
                                DECODE (NVL (ha.clambed_trk, 'N'),
                                        'Y', DECODE (d.uom, 1, d.qty_alloc, d.qty_alloc / nvl (spc, 1)),
                                        0),
                                 0)
                        ),
                SUM(DECODE(d.merge_alloc_flag,'M',0,'S',0,DECODE(d.uom,1,round(d.qty_alloc*(p.weight/nvl(p.spc,1))),0))),
                SUM(DECODE(d.merge_alloc_flag,'M',0,'S',0,DECODE(d.uom,1,d.qty_alloc*p.split_cube,0) ) ),
                SUM(DECODE(d.merge_alloc_flag,'M',0,'S',0,DECODE(d.uom,2,d.qty_alloc*p.weight,null, d.qty_alloc*p.weight,0) ) ),
                SUM(DECODE(d.merge_alloc_flag,'M',0,'S',0,
                    DECODE(d.uom,2,round((d.qty_alloc/nvl(p.spc,1))*p.case_cube),null,round((d.qty_alloc/nvl(p.spc,1))*p.case_cube),0) ) ),
                COUNT(DISTINCT SUBSTR(d.src_loc, 1, 2) ),
                COUNT(DISTINCT d.prod_id||d.cust_pref_vendor) ,
                COUNT(DISTINCT f.route_no)
            INTO o_num_stops,o_num_zones,o_num_floats,o_num_locs,o_num_splits,o_num_cases,
                 o_num_merges,o_num_data_captures,split_wt,split_cube,case_wt,
                 case_cube,o_num_aisles,o_num_items,num_routes
            FROM  pm p, float_detail d,floats f,float_hist h, sys_config sysp,haccp_codes ha
            WHERE p.prod_id = d.prod_id
            AND p.cust_pref_vendor = d.cust_pref_vendor
            AND d.float_no = f.float_no
            AND f.pallet_pull not in ('D','R')
            AND to_char(f.batch_no)=i_batch_no
            AND d.order_id = h.order_id
            AND d.order_line_id = h.order_line_id
            AND d.route_no = h.route_no
            AND ((i_type = 'N' AND h.picktime is not null) OR (i_type ='R' AND h.picktime is null))
            AND ((i_type = 'N' AND h.user_id =i_user_id) OR (i_type ='R'))
            AND h.prod_id = d.prod_id
            AND h.batch_no = to_char(f.batch_no)
	    AND sysp.config_flag_name = 'CLAM_BED_TRACKED'
	    AND p.category = ha.haccp_code (+)
            AND ha.haccp_type(+) = 'C';


            begin
		 SELECT  SUM (DECODE (sr.cool_trk,
                         'Y', DECODE (NVL (h.cool_trk, 'N'),'Y', 
				DECODE (fd.uom, 1, fd.qty_alloc, fd.qty_alloc/nvl(spc,1)), 0), 0))
                  INTO  cool_kvi
                  FROM  haccp_codes h,  spl_rqst_customer sr,
                        pm p, ordm o, floats f, float_detail fd, float_hist fh 
                 WHERE  fh.order_id = fd.order_id
		   AND  fh.order_line_id = fd.order_line_id
                   AND  fh.route_no= fd.route_no
                   AND  fh.prod_id =fd.prod_id
                   AND  fh.batch_no = to_char(f.batch_no)
		   AND  to_char(f.batch_no) = i_batch_no
                   AND ((i_type = 'N' AND fh.picktime is not null) OR (i_type ='R' AND fh.picktime is null))
                   AND ((i_type = 'N' AND fh.user_id =i_user_id) OR (i_type ='R'))
                   AND  fd.merge_alloc_flag NOT IN ('M', 'S')
                   AND  fd.float_no = f.float_no
                   AND  fd.order_id = o.order_id
                   AND  sr.customer_id = o.cust_id
                   AND  EXISTS (select 1 from cool_item ci
                   		WHERE  ci.prod_id = fd.prod_id
                   		AND  ci.cust_pref_vendor = fd.cust_pref_vendor)
                   AND  p.prod_id = fd.prod_id
                   AND  p.cust_pref_vendor = fd.cust_pref_vendor
                   AND  p.category = h.haccp_code
                   AND  sr.cool_trk = 'Y'
                   AND  h.haccp_type ='O'
                   AND  f.pallet_pull NOT IN ('D', 'R')
		   AND  h.haccp_code = p.category
                   and h.cool_trk='Y';
			select nvl(o_num_data_captures,0) + nvl(cool_kvi,0) 
                        into o_num_data_captures 
                        from dual;

                 EXCEPTION
                        when others then
                           cool_kvi :=0;
            end;

	    if (o_num_locs > 0) then
		o_success := 'Y';
                o_total_wt := case_wt + split_wt;
                o_total_cube :=  case_cube + split_cube;
                o_num_pieces := o_num_cases + o_num_splits + o_num_merges;
            	begin
                	num_s_merges := 0;
                 	SELECT COUNT(DISTINCT f.merge_loc) 
			INTO num_s_merges
                   	FROM float_detail d, floats f, float_hist h
                  	WHERE d.order_id = h.order_id
                    	AND d.order_line_id = h.order_line_id
                    	AND d.merge_alloc_flag = 'S'
                    	AND d.prod_Id = h.prod_Id
                    	AND d.float_no = f.float_no
                    	AND f.route_no = h.route_no
                    	AND to_char(f.batch_no) = h.batch_no
                    	AND to_char(f.batch_no) = i_batch_no;
                  	EXCEPTION
                     		when others then
                          		num_s_merges := 0;
            	end;
            	o_num_merges  := num_s_merges + o_num_merges;
	    else
                o_success :='N';
            end if;


         EXCEPTION
            when others then
                 o_success := 'N';
                 dbms_output.put_line(sqlerrm);
end calc_kvi;
/* ========================================================================== */

PROCEDURE calc_kvi_short(i_type in varchar,
                   i_batch_no in arch_batch.batch_no%TYPE,
                   i_user_id in arch_batch.user_id%TYPE,
                   o_num_stops out arch_batch.kvi_no_stop%TYPE,
                   o_num_zones  out arch_batch.kvi_no_zone%TYPE,
                   o_num_locs out arch_batch.kvi_no_loc%TYPE,
                   o_num_splits out arch_batch.kvi_no_split%TYPE,
                   o_num_cases out arch_batch.kvi_no_case%TYPE, 
                   o_num_merges out arch_batch.kvi_no_merge%TYPE, 
                   o_num_data_captures out arch_batch.kvi_no_data_capture%TYPE,
                   o_num_aisles out arch_batch.kvi_no_aisle%TYPE, 
                   o_num_items out arch_batch.kvi_no_item%TYPE,
                   o_total_wt  out arch_batch.kvi_wt%TYPE, 
                   o_total_cube out arch_batch.kvi_cube%type,
                   o_num_pieces out arch_batch.kvi_no_piece%TYPE,
                   o_num_floats out arch_batch.kvi_no_pallet%TYPE,
                   o_success out varchar) is
	no_clam number(5);
	no_cool number(5);
begin
	no_clam :=0;	
	no_cool :=0;	
	o_success := 'Y';
   	SELECT sum(v.cube),
                sum(decode(v.picktype,'04',v.case_weight/spc,'06',v.case_weight/v.spc,v.case_weight)*v.qty_short),
                sum(nvl(v.qty_short,0)),
                count(distinct v.item),
		sum(nvl(decode(v.picktype,'05',v.qty_short,'06',v.qty_short,'21',v.qty_short),0)),
                count(distinct v.location),
                nvl(sum(decode(v.picktype,'04',0,'06',0,v.qty_short)),0),
                nvl(sum(decode(v.picktype,'04',v.qty_short,'06',v.qty_short)),0),
                count(distinct(substr(v.location,1,2)))
	INTO 	o_total_cube,o_total_wt,o_num_pieces,o_num_items,o_num_data_captures,
		o_num_locs,o_num_cases,o_num_splits,o_num_aisles
        FROM v_sos_short v,float_hist h
	WHERE v.short_batch_no = i_batch_no
        AND   v.short_batch_no= h.short_batch_no
	AND   v.invoiceno = h.order_id
        AND   v.order_line_id = h.order_line_id
	AND   v.item = h.prod_id
        AND   ((i_type = 'N' AND h.short_user_id =i_user_id) OR (i_type ='R'))
	AND   ((i_type ='N' and short_picktime is not null) or (i_type ='R' and short_picktime is null));
	if (o_num_locs > 0) then
		begin
		    select nvl(sum(nvl(v.qty_short,0)),0)
		    into no_clam
                    from v_sos_short v,pm,haccp_codes h, float_hist fh
                    where v.short_batch_no = i_batch_no
                    AND   fh.short_batch_no = v.short_batch_no
		    AND   v.invoiceno = fh.order_id
                    AND   v.order_line_id = fh.order_line_id
                    and   v.item = pm.prod_id
	            AND   v.item = fh.prod_id
	            AND   ((i_type = 'N' AND fh.short_user_id =i_user_id) OR (i_type ='R'))
        	    AND   ((i_type ='N' and fh.short_picktime is not null) or (i_type ='R' and fh.short_picktime is null))		
                    and   pm.category = h.haccp_code
                    and   h.haccp_type ='C'
                    and   v.picktype <> '21';
                    exception
                       when others then
                          no_clam := 0;
                end;
                begin
		    select nvl(sum(nvl(v.qty_short,0)),0)
                    into no_cool
                    from v_sos_short v, float_hist fh
                    where v.short_batch_no = i_batch_no
                    AND   fh.short_batch_no = v.short_batch_no
		    AND   v.invoiceno = fh.order_id
                    AND   v.order_line_id = fh.order_line_id
	            AND   v.item = fh.prod_id
	            AND   ((i_type = 'N' AND fh.short_user_id =i_user_id) OR (i_type ='R'))
        	    AND   ((i_type ='N' and fh.short_picktime is not null) or (i_type ='R' and fh.short_picktime is null))		
                    and   exists (select 1 from v_ord_cool v1
				 where v.invoiceno = v1.order_id
                                 and   v.order_line_id = v1.order_line_id
                                 and   v.item = v1.prod_id);
		    exception
                       when others then
                         no_cool := 0;
                end;
		select nvl(o_num_data_captures,0)+ nvl( no_clam,0) + nvl(no_cool,0)
                into o_num_data_captures
                from dual;

		o_success := 'Y';
	else
                o_success := 'N';
        end if;


	EXCEPTION
		when others then
			dbms_output.put_line(sqlcode);
			o_success := 'N';

end calc_kvi_short;
/* ========================================================================== */
Procedure calc_goal_time(i_batch_no in arch_batch.batch_no%Type) is

	l_jbcd_job_code 	arch_batch.jbcd_job_code%type;
	l_status 		arch_batch.status%type;
	l_ref_no 		arch_batch.ref_no%type;
	l_parent_batch_no 	arch_batch.parent_batch_no%type;
	l_doc_time 		arch_batch.kvi_doc_time%type;
	l_cube 			arch_batch.kvi_cube%type;
	l_wt 			arch_batch.kvi_wt%type;
	l_no_piece 		arch_batch.kvi_no_piece%type;
	l_no_pallet 		arch_batch.kvi_no_pallet%type;
	l_no_item 		arch_batch.kvi_no_item%type;
	l_no_data 		arch_batch.kvi_no_data_capture%type;
	l_no_po 		arch_batch.kvi_no_po%type;
	l_no_stop 		arch_batch.kvi_no_stop%type;
	l_no_zone 		arch_batch.kvi_no_zone%type;
	l_no_loc 		arch_batch.kvi_no_loc%type;
	l_no_case 		arch_batch.kvi_no_case%type;
	l_no_split 		arch_batch.kvi_no_split%type;
	l_no_merge 		arch_batch.kvi_no_merge%type;
	l_no_aisle 		arch_batch.kvi_no_aisle%type;
	l_no_drop 		arch_batch.kvi_no_drop%type;
	l_no_order_time 	arch_batch.kvi_order_time%type;
	l_actl_time_spent 	arch_batch.actl_time_spent%type;
	l_no_cart 		arch_batch.kvi_no_cart%type;
	l_no_pallet_piece 	arch_batch.kvi_no_pallet_piece%type;
	l_no_cart_piece 	arch_batch.kvi_no_cart_piece%type;
        l_user_id		arch_batch.user_id%TYPE;
        l_supervsr_id		arch_batch.user_id%TYPE;

	l_print_goal_flag	varchar2(1);
	l_success               varchar2(1);

	t_engr_std_flag         job_code.engr_std_flag%TYPE;
        t_doc_time              job_code.tmu_doc_time%TYPE;
        t_cube                  job_code.tmu_cube%TYPE;
        t_wt                    job_code.tmu_wt%TYPE;
        t_no_piece              job_code.tmu_no_piece%TYPE;
        t_no_pallet             job_code.tmu_no_pallet%TYPE;
        t_no_item               job_code.tmu_no_item%TYPE;
        t_no_data               job_code.tmu_no_data_capture%TYPE;
        t_no_po                 job_code.tmu_no_po%TYPE;
        t_no_stop               job_code.tmu_no_stop%TYPE;
        t_no_zone               job_code.tmu_no_zone%TYPE;
        t_no_loc                job_code.tmu_no_loc%TYPE;
        t_no_case               job_code.tmu_no_case%TYPE;
        t_no_split              job_code.tmu_no_split%TYPE;
        t_no_merge              job_code.tmu_no_merge%TYPE;
        t_no_aisle              job_code.tmu_no_aisle%TYPE;
        t_no_drop               job_code.tmu_no_drop%TYPE;
        t_order_time            job_code.tmu_order_time%TYPE;
        t_no_cart               job_code.tmu_no_cart%TYPE;
        t_no_cart_piece         job_code.tmu_no_cart_piece%TYPE;
        t_no_pallet_piece	job_code.tmu_no_pallet_piece%TYPE;

	l_gt_time		arch_batch.goal_time%type;
        l_total_pallet          arch_batch.total_pallet%Type;
        l_total_piece           arch_batch.total_piece%Type;
begin
	l_success:= 'N';
    begin
	select 	jbcd_job_code, status, ref_no,
       		parent_batch_no, NVL(kvi_doc_time,0),
       		NVL(kvi_cube,0), NVL(kvi_wt,0),
       		NVL(kvi_no_piece,0), NVL(kvi_no_pallet,0),
       		NVL(kvi_no_item,0), NVL(kvi_no_data_capture,0),
       		NVL(kvi_no_po,0), NVL(kvi_no_stop,0),
       		NVL(kvi_no_zone,0), NVL(kvi_no_loc,0),
       		NVL(kvi_no_case,0), NVL(kvi_no_split,0),
       		NVL(kvi_no_merge,0), NVL(kvi_no_aisle,0),
       		NVL(kvi_no_drop,0), NVL(kvi_order_time,0),
       		user_id, user_supervsr_id,
       		nvl(actl_time_spent,0), nvl(kvi_no_cart, 0),
       		nvl(kvi_no_pallet_piece, 0), nvl(kvi_no_cart_piece, 0)
	into    l_jbcd_job_code, l_status, l_ref_no,
		l_parent_batch_no, l_doc_time,
		l_cube, l_wt,
		l_no_piece, l_no_pallet,
		l_no_item, l_no_data,
		l_no_po, l_no_stop,
		l_no_zone, l_no_loc,
		l_no_case, l_no_split,
		l_no_merge, l_no_aisle,
		l_no_drop, l_no_order_time,
		l_user_id, l_supervsr_id,
		l_actl_time_spent, l_no_cart,
		l_no_pallet_piece, l_no_cart_piece
	from	batch
	where   batch_no = i_batch_no;
		l_success := 'Y';
        	begin
		   Select nvl(lf.print_goal_flag,'Y')
		   into l_print_goal_flag
		   from lbr_func lf, job_code jc
		   where jc.lfun_lbr_func = lf.lfun_lbr_func
		   and   jc.jbcd_job_code = l_jbcd_job_code;
		   exception
                     when others then
			l_print_goal_flag := 'N';
	        end;
		
        exception
           when others then
		l_success :='N';
    end;
    if (l_print_goal_flag = 'Y' and l_success = 'Y') then
    	begin
		SELECT engr_std_flag,
       			NVL(tmu_doc_time,0),
       			NVL(tmu_cube,0),
       			NVL(tmu_wt,0),
       			NVL(tmu_no_piece,0),
       			NVL(tmu_no_pallet,0),
       			NVL(tmu_no_item,0),
       			NVL(tmu_no_data_capture,0),
       			NVL(tmu_no_po,0),
       			NVL(tmu_no_stop,0),
       			NVL(tmu_no_zone,0),
       			NVL(tmu_no_loc,0),
       			NVL(tmu_no_case,0),
       			NVL(tmu_no_split,0),
       			NVL(tmu_no_merge,0),
       			NVL(tmu_no_aisle,0),
       			NVL(tmu_no_drop,0),
       			NVL(tmu_order_time,0),
       			NVL(tmu_no_cart,0),
       			NVL(tmu_no_cart_piece,0),
       			NVL(tmu_no_pallet_piece,0)
		INTO    t_engr_std_flag, t_doc_time,
			t_cube, t_wt,
			t_no_piece, t_no_pallet,
			t_no_item, t_no_data,
			t_no_po, t_no_stop,
			t_no_zone, t_no_loc,
			t_no_case, t_no_split,
			t_no_merge, t_no_aisle,
			t_no_drop, t_order_time,
			t_no_cart, t_no_cart_piece,
			t_no_pallet_piece
		FROM    job_code
		where   jbcd_job_code=l_jbcd_job_code;
		   begin
			l_gt_time :=0;
			l_gt_time := l_gt_time + t_doc_time;
			l_gt_time := l_gt_time + t_order_time;
			
			if (l_ref_no = 'MULTI') then
				begin
				    SELECT NVL(SUM(kvi_cube),0),
					   NVL(SUM(kvi_wt),0),
					   NVL(SUM(kvi_no_piece),0),
					   NVL(SUM(kvi_no_pallet),0),
					   NVL(SUM(kvi_no_item),0),
					   NVL(SUM(kvi_no_data_capture),0),
					   NVL(SUM(kvi_no_po),0),
					   NVL(SUM(kvi_no_stop),0),
					   NVL(SUM(kvi_no_zone),0),
					   NVL(SUM(kvi_no_loc),0),
					   NVL(SUM(kvi_no_case),0),
					   NVL(SUM(kvi_no_split),0),
					   NVL(SUM(kvi_no_merge),0),
					   NVL(SUM(kvi_no_aisle),0),
					   NVL(SUM(kvi_no_drop),0),
					   NVL(SUM(kvi_no_cart),0),
					   NVL(SUM(kvi_no_cart_piece),0),
					   NVL(SUM(kvi_no_pallet_piece),0)
				    INTO   l_cube, l_wt,
					   l_no_piece, l_no_pallet,
					   l_no_item, l_no_data,
					   l_no_po, l_no_stop,
					   l_no_zone, l_no_loc,
					   l_no_case, l_no_split,
					   l_no_merge, l_no_aisle,
					   l_no_drop, l_no_cart,
					   l_no_cart_piece, l_no_pallet_piece
				    FROM batch
				    WHERE nvl(parent_batch_no,batch_no) = i_batch_no;
				    EXCEPTION
					when others then
						null;
				end;
			end if;

		 	l_gt_time := l_gt_time + (t_cube * l_cube);
 			l_gt_time := l_gt_time + (t_wt * l_wt);
 			l_gt_time := l_gt_time + (t_no_piece * l_no_piece);
 			l_gt_time := l_gt_time + (t_no_pallet * l_no_pallet);
 			l_gt_time := l_gt_time + (t_no_item * l_no_item);
 			l_gt_time := l_gt_time + (t_no_data * l_no_data);
 			l_gt_time := l_gt_time + (t_no_po * l_no_po);
 			l_gt_time := l_gt_time + (t_no_stop * l_no_stop);
 			l_gt_time := l_gt_time + (t_no_zone * l_no_zone);
 			l_gt_time := l_gt_time + (t_no_loc * l_no_loc);
 			l_gt_time := l_gt_time + (t_no_case * l_no_case);
 			l_gt_time := l_gt_time + (t_no_split * l_no_split);
 			l_gt_time := l_gt_time + (t_no_merge * l_no_merge);
 			l_gt_time := l_gt_time + (t_no_aisle * l_no_aisle);
 			l_gt_time := l_gt_time + (t_no_drop * l_no_drop);
 			l_gt_time := l_gt_time + (t_no_cart * l_no_cart);
 			l_gt_time := l_gt_time + (t_no_cart_piece * l_no_cart_piece);
 			l_gt_time := l_gt_time + (t_no_pallet_piece * l_no_pallet_piece);
			
			/* convert to minutes */
			if l_gt_time > 0 then
				l_gt_time := l_gt_time/1667;
			end if;

		   end;

		EXCEPTION
			when others then
				l_success :='N';
 
        end;
    end if;
    begin
      if (l_print_goal_flag = 'Y') then
	if l_success = 'Y' then
	   if t_engr_std_flag ='Y' then
		update batch
		set goal_time = l_gt_time,
		    target_time = 0
		where batch_no = i_batch_no;
	   else
		update batch
		set  target_time = l_gt_time,
		     goal_time = 0
		where batch_no = i_batch_no;
	   end if;
	else
		update batch
		set goal_time = 0,
		    target_time = 0
		where batch_no = i_batch_no;
	end if;
 
      else
		update batch
		set goal_time = 0,
		    target_time = 0
		where batch_no = i_batch_no;
      end if;
      exception
	when others then
		null;
    end;
    begin
       select sum(nvl(kvi_no_piece,0)),sum(nvl(kvi_no_pallet,0))
       into l_total_piece,l_total_pallet
       from batch
       where nvl(parent_batch_no,batch_no) = i_batch_no;
       	   UPDATE  batch
   	   SET  total_count = 1,
       		total_pallet = l_total_pallet,
       		total_piece = l_total_piece
 	   WHERE batch_no = i_batch_no;
       exception
          when others then
                null;
    end;  
end calc_goal_time;

/* ========================================================================== */
END pl_sos_reassign;
/


