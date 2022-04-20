----------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_lxli_exception.sql, swms, swms.9, 9.9 11/27/07 1.1
--
-- View:
--    v_lxli_exception.sql
--
-- Description:
--    This is a view to compute the cube and weight for loader 
--    merged information.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/21/07 prpakp/  Initial version.
--             prfxa000
----------------------------------------------------------------------------

CREATE OR REPLACE VIEW SWMS.V_LXLI_EXCEPTION AS
SELECT fd.FLOAT_NO, f1.FLOAT_SEQ act_float_seq,
	l.FLOAT_SEQ new_float_seq,
	sum(DECODE(fd.merge_alloc_flag,'M',0,'S',0,DECODE(uom,1,fd.qty_alloc*p.split_cube,0) ) )+
	sum(DECODE(fd.merge_alloc_flag,'M',0,'S',0,DECODE(uom,2,(fd.qty_alloc/nvl(p.spc,1))*p.case_cube, null, (fd.qty_alloc/nvl(p.spc,1))*p.case_cube, 0) ) ) cube,
	sum(DECODE(fd.merge_alloc_flag,'M',0,'S',0,DECODE(uom,1,fd.qty_alloc*(p.g_weight/nvl(p.spc,1)),0) ) ) +
	sum(DECODE(fd.merge_alloc_flag,'M',0,'S',0,DECODE(uom,2,fd.qty_alloc*(p.g_weight/nvl(p.spc,1)), null, fd.qty_alloc*(p.g_weight/nvl(p.spc,1)), 0) ) )
	weight
 from float_detail fd,floats f1,las_case l, pm p
 where fd.order_seq = l.order_seq
 and f1.float_no = fd.float_no
 and nvl(l.float_seq,f1.float_seq) <> f1.float_seq
 and fd.prod_id = p.prod_id
 group by fd.float_no,f1.float_seq,l.float_seq
UNION
 select f1.float_no ,f1.float_seq act_float_seq,
        l.float_seq new_float_seq,
	sum(DECODE(fd.merge_alloc_flag,'M',0,'S',0,DECODE(uom,1,fd.qty_alloc*p.split_cube,0) ) )+
	sum(DECODE(fd.merge_alloc_flag,'M',0,'S',0,DECODE(uom,2,(fd.qty_alloc/nvl(p.spc,1))*p.case_cube, null, (fd.qty_alloc/nvl(p.spc,1))*p.case_cube, 0) ) ) cube,
	sum(DECODE(fd.merge_alloc_flag,'M',0,'S',0,DECODE(uom,1,fd.qty_alloc*(p.g_weight/nvl(p.spc,1)),0) ) ) +
	sum(DECODE(fd.merge_alloc_flag,'M',0,'S',0,DECODE(uom,2,fd.qty_alloc*(p.g_weight/nvl(p.spc,1)), null, fd.qty_alloc*(p.g_weight/nvl(p.spc,1)), 0) ) )
	weight
 from float_detail fd,floats f1,las_case l, floats f2, pm p
 where fd.order_seq = l.order_seq
 and f1.float_seq = l.float_seq
 and f1.route_no = fd.route_no
 and fd.float_no = f2.float_no
 and f2.float_seq <> f1.float_seq
 and fd.prod_id = p.prod_id
 group by f1.float_no,f1.float_seq,l.float_seq,f2.float_seq
/
