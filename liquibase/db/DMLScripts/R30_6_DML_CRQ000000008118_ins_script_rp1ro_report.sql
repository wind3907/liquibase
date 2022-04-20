/* 
***************************************************************************
** Date:       02-Feb-2017
** Programmer: Sunil Ontipalli
** File:       R30_6_DML_CRQ000000008118_ins_script_rp1ro_report.sql
**
** This scripts inserts records for new report "rp1ro.sql" report which
** is the "Print Wksht and Pallet Wksht" report.
**
** Records are inserted into tables:
**    - PRINT_QUEUE_TYPES    New type created call rp1ro and
**                           filter programs needs to be specifed in
**                           PRINT_QUEUES.
**    - PRINT_REPORTS
**    - PRINT_QUEUES
**
** Modification History:
**    Date     Designer                 Comments
**    -------- -------------------      ---------------------------------------------------
**    11/16/16 sont9212 & aalb7675      Initial Creation
**                      Project:
**    R30.6--WIE#669--CRQ000000008118_Live_receiving_story_310_Worksheet and Pallet Worksheet
**
**                      Created.
**
***************************************************************************
*/

--
-- Insert queue type WKWP into PRINT_QUEUE_TYPES but only if it is not
-- already there.
--
Insert into PRINT_QUEUE_TYPES (QUEUE_TYPE,DESCRIP)  
select 'WKWP','Print Wksht and Pallet Wksht' FROM Dual 
WHERE NOT EXISTS(SELECT 'x' FROM print_queue_types WHERE queue_type = 'WKWP');



--
-- Insert "rp1ro" report into PRINT_REPORTS but only if it is
-- not already there.
--


Insert into PRINT_REPORTS (REPORT,QUEUE_TYPE,DESCRIP,COMMAND,FIFO,FILTER,COPIES,DUPLEX) 
SELECT 'rp1ro','WKWP','Purchase Order Worksheets/Lumper Worksheet','rp1re -c :c -t :t -u :u -o :p/:f :r','Y','b',1,'N' 
FROM DUAL 
WHERE NOT EXISTS
             (SELECT 'x' FROM print_reports WHERE report = 'rp1ro');


--
-- Insert into PRINT_QUEUES.
-- Insert records for filters rp1ro_pcl5 and rp1ro_xppm
-- Based on existing WKWP entries.
--

---------
-- pcl5
---------
 INSERT INTO print_queues
(
   user_queue,
   system_queue,
   queue_type,
   queue_filter,
   descrip,
   command,
   directory
)
SELECT
   p1.user_queue,
   p1.system_queue,
   'WKWP',
   'rp1ro_pcl5',
   p1.descrip,
   p1.command,
   p1.directory
  FROM print_queues p1
 WHERE p1.queue_type = 'SQLP'
   AND p1.user_queue LIKE 'wrkl%'
   AND (   SUBSTR(p1.user_queue, 5) BETWEEN '1' AND '9' AND LENGTH(p1.user_queue) = 5
        OR SUBSTR(p1.user_queue, 5) BETWEEN '10' AND '99' AND LENGTH(p1.user_queue) = 6 )
   AND NOT EXISTS
            (SELECT 'x'
               FROM print_queues p2
              WHERE p2.queue_type = 'WKWP'
                AND p2.user_queue = p1.user_queue)
/


---------
-- xppm
---------
INSERT
INTO print_queues
  (
    user_queue,
    system_queue,
    queue_type,
    queue_filter,
    descrip,
    command,
    directory
  )
SELECT p1.user_queue,
  p1.system_queue,
  'WKWP',
  'rp1ro_xppm',
  p1.descrip,
  p1.command,
  p1.directory
FROM print_queues p1
WHERE p1.queue_type = 'SQLP'
AND p1.user_queue LIKE 'wrkl%'
AND ( SUBSTR(p1.user_queue, 5) BETWEEN 'A' AND 'Z'
AND LENGTH(p1.user_queue) = 5)
AND NOT EXISTS
  (SELECT 'x'
  FROM print_queues p2
  WHERE p2.queue_type = 'WKWP'
  AND p2.user_queue   = p1.user_queue
  )
  
/


--
-- Insert record into GLOBAL_REPORT_DICT table for the TITLE field
-- for lang id 3 (ENGLISH) but only if the entry is not already there.
-- This entry is needed for the file name to appear in the lpstat command.
-- NOTE: I am aware rp1ro is not "globalized" yet.
--
-- Example lpstat output:
-- lpstat -pwrkl1
-- Queue   Dev   Status    Job Files                           User         PP %   Blks  Cp Rnk
-- ------- ----- --------- --- ------------------             ---------- ---- -- ----- --- ---
-- wrkl1   hp@ib DOWN
--               QUEUED    770 Print Wksht and Pallet Wksht   sont9212        2   1   6
--


insert into global_report_dict
(
   lang_id,
   report_name,
   fld_lbl_name,
   fld_lbl_desc,
   max_len,
   fld_lbl_no
)
SELECT
  3                                  lang_id,
  'rp1ro'                            report_name,
  'TITLE'                            fld_lbl_name,
  'Print Wksht and Pallet Wksht'     fld_lbl_desc,
  LENGTH('Print Wksht and Pallet Wksht') max_len,
  1                                  fld_lbl_no
  FROM DUAL
 WHERE NOT EXISTS
     (SELECT 'x'
        FROM global_report_dict g
       WHERE g.lang_id    = 3
         AND report_name  = 'rp1ro'
         AND fld_lbl_name = 'TITLE');
/

