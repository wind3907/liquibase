REM @(#) src/schema/views/v_sosldhst.sql, swms, swms.9, 10.1.1 9/7/06 1.3
REM File : @(#) src/schema/views/v_sosldhst.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_sosldhst.sql, swms, swms.9, 10.1.1
REM
REM      MODIFICATION HISTORY   
REM 10/22/02 acpakp added the short info in the calculation 
REM

REM
                                
create or replace view swms.v_sosldhst as
SELECT fh.user_id  user_id,
       fh.batch_no batch_no,
       fh.picktime picktime,
       to_char(fh.picktime, 'HH:MI:SS') batch_time,
       to_char(fh.picktime, 'MM/DD/RR HH24:MI') batch_date,
       (floor(decode(fh.uom,1,nvl(fh.qty_order,0),
                              nvl(fh.qty_order,0)/nvl(pm.spc,1)))) qty_order,
       fh.ship_date ship_date,
       ((floor(decode(fh.uom,1,nvl(fh.qty_order,0),
                              nvl(fh.qty_order,0)/nvl(pm.spc,1))))  -
       (floor(decode(fh.uom,1,nvl(fh.qty_alloc,0),
                              nvl(fh.qty_alloc,0)/nvl(pm.spc,1)))))  +
       (floor(decode(fh.uom,1,nvl(fh.qty_short,0),                
                       nvl(fh.qty_short,0)/nvl(pm.spc,1)))) qty_short,
       fh.catchweight catchweight,
       fh.src_loc src_loc,
       pm.spc,
       u.user_name user_name,
       jc.descrip job_desc,
       ab.jbcd_job_code job_code
FROM  job_code jc, usr u, pm, arch_batch ab, float_hist fh
WHERE  u.user_id = 'OPS$' || ab.user_id
AND    u.user_id = 'OPS$' || fh.user_id
AND    pm.prod_id = fh.prod_id
AND    (ab.batch_no = 'S' ||fh.batch_no
        OR ab.batch_no = 'L' || fh.batch_no)
AND    jc.jbcd_job_code = ab.jbcd_job_code;

