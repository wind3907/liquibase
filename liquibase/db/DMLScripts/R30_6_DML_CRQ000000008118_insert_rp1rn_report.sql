
/****************************************************************************
** Date:       09-AUG-2011
** Programmer: Brian Bent
** File:       R30_6_DML_CRQ000000008118_ins_script_rp1rn_report.sql
**
** This scripts inserts records for new report "rp1rn.sql" report which
** is the "Receiving Load Worksheet" report.
**
** Records are inserted into tables:
**    - PRINT_QUEUE_TYPES    New type created call SQLF which is for
**                           SQL scripts that need a barcode thus a
**                           filter programs needs to be specifed in
**                           PRINT_QUEUES.
**    - PRINT_REPORTS
**    - PRINT_QUEUES
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    11/16/16 bben0556 Brian Bent
**                      Project:
**    R30.6--WIE#669--CRQ000000008118_Live_receiving_story_11_rcv_load_worksheet
**
**                      Created.
**
**    01/03/17 bben0556 Brian Bent
**                      Project:
**   R30.6--WIE#669--CRQ000000008118_Live_receiving_story_37_print_load_worksheet
**
**                      Insert record into GLOBAL_REPORT_DICT table for the
**                      TITLE field.
**
**    01/03/17 bben0556 Brian Bent
**                      Project:
**   R30.6--WIE#669--CRQ000000008118_Live_receiving_story_237_print_load_worksheet_from_CRT
**
**                      I initially had "Description" for the report
**                      description.  Changed it to "Receiving Load Worksheet"
**
****************************************************************************/

--
-- Insert queue type SQLF into PRINT_QUEUE_TYPES but only if it is not
-- already there.
--
INSERT INTO print_queue_types
(
   queue_type,
   descrip
)
SELECT 'SQLF'                        queue_type,
       'SQL*PLUS/PLSQL USING FILTER' descrip
 FROM dual
 WHERE NOT EXISTS
    (SELECT 'x' FROM print_queue_types WHERE queue_type = 'SQLF')

/


--
-- Insert "rp1rn" report into PRINT_REPORTS but only if it is
-- not already there.
--
INSERT INTO PRINT_REPORTS
(
   report,
   queue_type,
   descrip,
   command,
   fifo,
   filter,
   copies,
   duplex
)
SELECT 'rp1rn'                     report,
       'SQLF'                      queue_type,
       'Receiving Load Worksheet'  descrip,
       'runsqlrpt -c :c :p/:f :r'  command,
       'N'                         fifo,
       NULL                        filter,
       '1'                         copies,
       'N'                         duplex
  FROM dual
 WHERE NOT EXISTS
             (SELECT 'x' FROM print_reports WHERE report = 'rp1rn')
/


--
-- Insert into PRINT_QUEUES.
-- Insert records for filters rp1fz_pcl5 and rp1fz_xppm
-- Based on existing SQLP entries.
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
   'SQLF',
   'rp1fz_pcl5',
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
              WHERE p2.queue_type = 'SQLF'
                AND p2.user_queue = p1.user_queue)
/

---------
-- xppm
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
   'SQLF',
   'rp1fz_xppm',
   p1.descrip,
   p1.command,
   p1.directory
  FROM print_queues p1
 WHERE p1.queue_type = 'SQLP'
   AND p1.user_queue LIKE 'wrkl%'
   AND (   SUBSTR(p1.user_queue, 5) BETWEEN 'A' AND 'Z' AND LENGTH(p1.user_queue) = 5)
   AND NOT EXISTS
            (SELECT 'x'
               FROM print_queues p2
              WHERE p2.queue_type = 'SQLF'
                AND p2.user_queue = p1.user_queue)
/



--
-- Insert record into GLOBAL_REPORT_DICT table for the TITLE field
-- for lang id 3 (ENGLISH) but only if the entry is not already there.
-- This entry is needed for the file name to appear in the lpstat command.
-- NOTE: I am aware rp1rn is not "globalized" yet.
--
-- Example lpstat output:
-- lpstat -pwrkl1
-- Queue   Dev   Status    Job Files              User         PP %   Blks  Cp Rnk
-- ------- ----- --------- --- ------------------ ---------- ---- -- ----- --- ---
-- wrkl1   hp@ib DOWN
--               QUEUED    770 'Receiving Load Wo bben0556               2   1   6
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
  'rp1rn'                            report_name,
  'TITLE'                            fld_lbl_name,
  'Receiving Load Worksheet'         fld_lbl_desc,
  LENGTH('Receiving Load Worksheet') max_len,
  1                                  fld_lbl_no
  FROM DUAL
 WHERE NOT EXISTS
     (SELECT 'x'
        FROM global_report_dict g
       WHERE g.lang_id    = 3
         AND report_name  = 'rp1rn'
         AND fld_lbl_name = 'TITLE')
/

