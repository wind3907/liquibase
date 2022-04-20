/****************************************************************************
** File:
**    R47_0-xdock-OPCOF-3567_XDK_Add_forklift_task_priorities.sql
**
** Description:
**    Project: R1 Cross Docking  (Xdock)
**             R47_0-xdock-OPCOF-3567_XDK_Add_forklift_task_priorities
**
**    This scripta inserts the forklift task priorites for XDK tasks.
**    Records are inserted into table FORKLIFT_TASK_PRIORITY.
**
**    -------- -------- ---------------------------------------------------
**    11/05/21 bben0556 Brian Bent
**                      R1 cross dock.
**                      Card: R47_0-xdock-OPCOF-3567_XDK_Add_forklift_task_priorities
**                      Created.
**
**                      Records currentlty in FORKLIFT_TASK_PRIORITY:
**
FORKLIFT_TASK_TYPE SEVERITY           PRIORITY REMARKS
------------------ ---------------- ---------- -------------------------------------------------------
DMD                CRITICAL                  5 Selection batch for this item is active or complete.
                                               The user has shorted this item.

NDM                CRITICAL                  7 A selector has shorted this item. Non Demand
                                               replenishment is forced from the short screen

BLK                CRITICAL                 10 At least one of the selection batches completed for
                                               this truck has a stop number lower than the stop number
                                               for this bulk pull

DMD                URGENT                   15 Selection batch for this item is active or complete.
                                               The user has not picked this item yet or fully picked
                                               this item. So, another user may get a short soon.

BLK                URGENT                   20 At least one of the selection batches for this truck is
                                               in complete status

DMD                HIGH                     25 Selection batch for this item is not active yet. There
                                               is a miniload replenishment depending on this

DMD                MEDIUM                   35 Selection batch for this item is not active yet. There
                                               is a split home replenishment depending on this

DMD                NORMAL                   45 All other demand replenishments
BLK                NORMAL                   50 All other bulk pulls
SWP                NORMAL                   53 Swap task
NDM                URGENT                   55 Non Demand replenishment for an actual order for the
                                               day

NDM                HIGH                     60 Non Demand replenishment for anticipated orders for the
                                               day

NDM                NORMAL                   75 User created Non Demand replenishments (Using Min/Max,
                                               Location cube etc.)
**
****************************************************************************/


INSERT INTO forklift_task_priority(forklift_task_type, severity, priority, remarks) 
SELECT 'XDK'                   forklift_task_type,
       'NORMAL'                severity,
       50                      priority,
       'All other XDK tasks'   remarks
  FROM DUAL
 WHERE NOT EXISTS (SELECT 'x' from forklift_task_priority f2 where f2.forklift_task_type = 'XDK' and f2.severity = 'NORMAL')
/


INSERT INTO forklift_task_priority(forklift_task_type, severity, priority, remarks) 
SELECT 'XDK'                   forklift_task_type,
       'URGENT'                severity,
       20                      priority,
       'At least one of the selection batches for this truck is in complete status' remarks
  FROM DUAL
 WHERE NOT EXISTS (SELECT 'x' from forklift_task_priority f2 where f2.forklift_task_type = 'XDK' and f2.severity = 'URGENT')
/


INSERT INTO forklift_task_priority(forklift_task_type, severity, priority, remarks) 
SELECT 'XDK'                   forklift_task_type,
       'CRITICAL'              severity,
       10                      priority,
       'At least one of the selection batches completed for this truck has a stop number lower than the stop number for this bulk pull' remarks
  FROM DUAL
 WHERE NOT EXISTS (SELECT 'x' from forklift_task_priority f2 where f2.forklift_task_type = 'XDK' and f2.severity = 'CRITICAL')
/
   

COMMIT;

