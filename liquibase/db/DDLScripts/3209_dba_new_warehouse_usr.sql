/****************************************************************************
** sccs_id=%Z% %W% %G% %I%
**
** Date:       27-JUL-2011
** Programmer: Brian Bent
** File:       3209_dba_new_warehouse_usr.sql
** Problem #:  3209
** Clearcase Activity: PBI3209-Identifying_new_warehouse user
**
** This script has the DDL operations for this project.
** 
** This script creates a table to store users who will be working in the
** new warehouse during the pre-receiving time as part of a warehouse move.
** These users can only work in the new warehouse.
** This table will be populated as part of setting up the OpCo to
** pre-receive into the new warehouse.  Special user id's for the new
** warehouse will be created and will need to go in this table.
**
** If the OpCo is not pre-receivng into the new warehouse then nothing goes
** in this table.
**
*************************************************************
** READ THIS:  Do not include the OPS$ in the user id.
**             Though the function in pl_whmove_utilities
**             which looks at this table will handle the OPS$.
*************************************************************
**
** NOTE:
** Before we were determining if a user was a new warehouse user
** by checking if their user id started with WH, TR or RT.
** But now we have regular warehouse users with user id's
** starting with WH so this approach no longer works.
**
**
** Tables Created:
**
**    - NEW_WAREHOUSE_USR 
**
****************************************************************************/


/****************************************************************************
* Create table NEW_WAREHOUSE_USR
****************************************************************************/
CREATE TABLE swms.new_warehouse_usr
(
   user_id         VARCHAR2(30)   NOT NULL,      -- Primary key
   add_date        DATE         DEFAULT SYSDATE NOT NULL,  -- Date and time
                                             -- record inserted into database.
   add_user        VARCHAR2(10) DEFAULT REPLACE(USER, 'OPS$') NOT NULL, 
                                                   -- User inserting record.
   upd_date        DATE,                     -- Date and time of last update.
                                             -- Assigned by database trigger.
   upd_user        VARCHAR2(10)              -- User updating record.  The
                                             -- OPS$ will be stripped off.
                                             -- Assigned by database trigger.
)
TABLESPACE SWMS_DTS2
PCTFREE 5
STORAGE (INITIAL 8K NEXT 8K PCTINCREASE 0 MINEXTENTS 1 MAXEXTENTS 100);

------------------------
-- Create primary key.
------------------------
ALTER TABLE swms.new_warehouse_usr ADD CONSTRAINT new_warehouse_usr_pk
   PRIMARY KEY (user_id)
   USING INDEX
       TABLESPACE SWMS_ITS2
       PCTFREE 5
       STORAGE (INITIAL 16K NEXT 16K PCTINCREASE 0 MINEXTENTS 1 MAXEXTENTS 100);


-------------------------------------
-- Create foreign key constraints.
-------------------------------------
/***** Don't want this since the USR table has the OPS$.
ALTER TABLE swms.new_warehouse_usr ADD CONSTRAINT new_warehouse_usr_user_id_fk
   FOREIGN KEY (user_id) REFERENCES swms.usr(user_id);
*****/


-------------------------------------
-- Create public synonym
-------------------------------------
CREATE OR REPLACE PUBLIC SYNONYM new_warehouse_usr FOR swms.new_warehouse_usr;


