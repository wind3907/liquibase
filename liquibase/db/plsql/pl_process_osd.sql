/***********************************************************************
* TYPE               : Package                                         *
* NAME               : pl_process_OSD                                  *
* SCCS ID            : @(#) src/schema/plsql/pl_process_osd.sql, swms, swms.9, 10.1.1 9/7/06 1.4                                 *
* INPUT Parameters   : None                                            *
* OUTPUT Parameters  : None                                            *
* PURPOSE            : To combine all procedures and functions that do *
*                      the processing for OSD                          *
* Global variables   : None                                            *
* Procs./Fns. Used   : None                                            *
* Used in Procs./Fns.: None                                            *
*                                                                      *
* Author Date       Ver   Description                                  *
* ------ ---------- ---   ---------------------------------------------*
* acpppk 07/03/2003 1.00  Created D# 11336                             *
*                                                                      *
***********************************************************************/

CREATE OR REPLACE PACKAGE swms.pl_process_OSD 
AS

/* This package specification is used to do processing of overages,
   shortages and damages.*/


/*****************
  Public Constants
*****************/

/*****************
  Public Variables
*****************/

/********************************
  Public Functions and Procedures
********************************/

/* Delete from OSD table all records with matching reason code 
   and orig_pallet_id.
   If osd_type of new record is 'OVG' or 'SRT' delete all 'SRT' and 
   'OVG' records for that old pallet_id from the OSD table.
   Insert new record into OSD table.*/

PROCEDURE p_update_osd_table(
in_v_prod_id IN osd.prod_id%TYPE,
in_v_cpv IN osd.cust_pref_vendor%TYPE,
in_n_osd_qty IN osd.osd_qty%TYPE,
in_v_pallet_id IN osd.orig_pallet_id%TYPE,
in_v_new_pallet_id  osd.new_pallet_id%TYPE,
in_v_reason_code IN osd.reason_code%TYPE,
in_v_osd_type IN osd.osd_type%TYPE,
in_n_auto_call_flag number);


/* Retrieve the priv corresponding to the user 
   from the userauth table.*/

PROCEDURE p_check_osd_auth
(out_n_priv OUT number);


/*Insert into trans table a CSQ or COR with quantity sign negative and  
  same quantity and reason code as that of the current OSD record.
  Delete the record from OSD table if display_record='N'.*/
   
PROCEDURE p_Create_Neg_corrxns_for_OSD
(in_v_rec_id IN erm.erm_id%TYPE,
in_v_orig_pallet_id IN osd.orig_pallet_id%TYPE,
in_v_osd_type IN osd.osd_type%TYPE,
in_v_erm_type IN erm.erm_type%TYPE,
in_n_osd_qty IN osd.osd_qty%TYPE,
in_v_old_reason_code IN osd.reason_code%TYPE);


/* Insert into trans table a CSQ or COR with same quantity sign 
   and quantity  = qty corr - qty rcv  if this quantity <>0 
   and blank reason code.
   Get the value of qty corr + qty dmg - qty ord as input parameter.
   Insert into trans table a CSQ or COR with this quantity(if it's not 0)  
   and reason code as overage or shortage depending on whether  
   qty corr + dmg > qty ord.*/

PROCEDURE p_Create_OS_corrxns_for_OSD
(in_v_rec_id IN erm.erm_id%TYPE,
in_v_orig_pallet_id IN osd.orig_pallet_id%TYPE,
in_v_osd_type IN osd.osd_type%TYPE,
in_v_erm_type IN erm.erm_type%TYPE,
in_n_osd_qty IN osd.osd_qty%TYPE,
in_v_reason_code IN osd.reason_code%TYPE,
in_n_diff_qty IN trans.qty%TYPE);


/*For each of the dmg osd_type entries in OSD table for given  
  orig_pallet_id with non default reason codes
     Insert into trans table a CSQ with positive quantity sign 
  and quantity  = qty osd  and reason code*/

PROCEDURE p_Create_dmg_corrxns_for_OSD
(in_v_rec_id IN erm.erm_id%TYPE,
in_v_orig_pallet_id IN osd.orig_pallet_id%TYPE,
in_v_erm_type IN erm.erm_type%TYPE,
in_n_osd_qty IN osd.osd_qty%TYPE,
in_v_reason_code IN osd.reason_code%TYPE);

END pl_process_osd;
/

CREATE OR REPLACE PACKAGE BODY swms.pl_process_osd 
AS

/* This package body is used to do processing of overages, shortages 
   and damages*/

/*********************************
  Private Variables
*********************************/

/*********************************
  Private Functions and Procedures
*********************************/

/***********************************************************************
* TYPE               : Procedure                                       *
* NAME               : p_update_osd_table                              *
* INPUT Parameters   : in_n_osd_qty, in_v_pallet_id, in_v_reason_code, *
*                      in_v_osd_type ,in_v_prod_id,in_v_cpv,           *
*                      in_v_new_pallet_id                              *
* OUTPUT Parameters  : None                                            *
* PURPOSE            : To insert or update OSD records.                *
* Global variables   : None                                            *
* Procs./Fns. Used   : pl_log.ins_msg                                  *
* Used in Procs./Fns.: None                                            *
*                                                                      *
* Author Date       Ver   Description                                  *
* ------ ---------- ---   ---------------------------------------------*
* acpppk 06/17/2003 1.00  Created                                      *
*                                                                      *
***********************************************************************/

/* Delete from OSD table all records with matching reason code 
   and orig_pallet_id.
   If osd_type of new record is 'OVG' or 'SRT' delete all 'SRT' and 
   'OVG' records for that old pallet_id from the OSD table.
   Insert new record into OSD table.*/

PROCEDURE p_update_osd_table(
in_v_prod_id IN osd.prod_id%TYPE,
in_v_cpv IN osd.cust_pref_vendor%TYPE,
in_n_osd_qty IN osd.osd_qty%TYPE,
in_v_pallet_id IN osd.orig_pallet_id%TYPE,
in_v_new_pallet_id  osd.new_pallet_id%TYPE,
in_v_reason_code IN osd.reason_code%TYPE,
in_v_osd_type IN osd.osd_type%TYPE,
in_n_auto_call_flag number) 
IS
   lv_message VARCHAR2(200);
   lv_fname VARCHAR2(50) := 'p_update_osd_table';
BEGIN
/* Automatic call from SN/PO Corrections */
   IF in_n_auto_call_flag = 1 then
      BEGIN
         UPDATE osd
            SET display_record = 'N' 
            WHERE orig_pallet_id = in_v_pallet_id
            AND osd_type=in_v_osd_type;
         IF in_v_osd_type = 'OVG' then
            UPDATE osd
               SET display_record = 'N' 
               WHERE orig_pallet_id = in_v_pallet_id
               AND osd_type in ('SRT','OVG');
         ELSIF in_v_osd_type = 'SRT' then
            UPDATE osd
               SET display_record = 'N' 
               WHERE orig_pallet_id = in_v_pallet_id
               AND osd_type in ('SRT','OVG');
         END IF;
      EXCEPTION
         WHEN OTHERS THEN 
            lv_message:='Unable to update display_record to N';
            pl_log.ins_msg('WARN',lv_fname,lv_message,null,sqlerrm);
            RAISE;
      END;
      
   ELSE
         BEGIN
            IF in_v_osd_type = 'DMG' then
            DELETE FROM osd 
               WHERE orig_pallet_id= in_v_pallet_id
               AND osd_type=in_v_osd_type;
            END IF;
         
            IF in_v_osd_type = 'OVG' then 
               DELETE FROM osd 
               WHERE orig_pallet_id=in_v_pallet_id
        AND new_pallet_id is NULL
               AND osd_type in ('OVG','SRT'); 
           END IF;
             IF in_v_osd_type = 'SRT' then 
               DELETE FROM osd 
               WHERE orig_pallet_id=in_v_pallet_id
        AND new_pallet_id is NULL
               AND osd_type in ('OVG','SRT');
           END IF; 
         EXCEPTION
            WHEN OTHERS THEN
               lv_message:='Unable to update display_record to N';
               pl_log.ins_msg('WARN',lv_fname,lv_message,null,sqlerrm);
               RAISE;
         END;
         
  END IF;
  
   IF in_n_osd_qty <> 0 THEN
      BEGIN
         INSERT into osd
            (prod_id,cust_pref_vendor,orig_pallet_id,new_pallet_id,reason_code,osd_qty,
             osd_type,display_record)
             VALUES (in_v_prod_id,in_v_cpv,in_v_pallet_id,
             in_v_new_pallet_id,in_v_reason_code,in_n_osd_qty,in_v_osd_type,'Y');
      EXCEPTION
         WHEN OTHERS THEN
            lv_message:='insert into osd failed';
            pl_log.ins_msg('WARN',lv_fname,lv_message,null,sqlerrm);
            RAISE;
      END;
   END IF;
      
EXCEPTION
   WHEN OTHERS THEN
      lv_message:='delete from osd failed';
      pl_log.ins_msg('WARN',lv_fname,lv_message,null,sqlerrm);
      RAISE;
END p_update_osd_table;

/***********************************************************************
* TYPE               : Procedure                                       *
* NAME               : p_check_osd_auth                                *
* INPUT Parameters   :                                                 *
* OUTPUT Parameters  : out_n_priv                                      *
* PURPOSE            : To verify the privileges allowed to the user.   *
* Global variables   : :global.priv                                    *
* Procs./Fns. Used   : None                                            *
* Used in Procs./Fns.: None                                            *
*                                                                      *
* Author Date       Ver   Description                                  *
* ------ ---------- ---   ---------------------------------------------*
* acpppk 06/17/2003 1.00  Created                                      *
*                                                                      *
***********************************************************************/

/* Retrieve the priv corresponding to the user 
   from the userauth table*/

PROCEDURE p_check_osd_auth (
out_n_priv OUT number)
IS
   lv_message VARCHAR2(200);
   lv_fname VARCHAR2(50) := 'p_check_osd_auth';
BEGIN
   BEGIN
      SELECT priv into out_n_priv
         FROM usrauth 
            WHERE user_id=user 
            AND auth_id=18;
   EXCEPTION
      WHEN OTHERS THEN
         lv_message:='Unable to determine privileges of user';
         pl_log.ins_msg('WARN',lv_fname,lv_message,null,sqlerrm);
   END;
   
   IF out_n_priv > 2 THEN
      lv_message:='No privileges to access reason codes screen';
      pl_log.ins_msg('WARN',lv_fname,lv_message,null,sqlerrm);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      RAISE;
END p_check_osd_auth;


/***********************************************************************
* TYPE               : Procedure                                       *
* NAME               : p_Create_Neg_corrxns_for_OSD                    *
* INPUT Parameters   : in_v_rec_id,in_v_orig_pallet_id,in_v_osd_type,   *
*                      in_v_erm_type,in_n_osd_qty                      *
* OUTPUT Parameters  :                                                 *
* PURPOSE            : To create COR transactions with negative sign   *
*                      when changes are made to qty from Corrections   *
* Global variables   :                                                 *
* Procs./Fns. Used   : None                                            *
* Used in Procs./Fns.: None                                            *
*                                                                      *
* Author Date       Ver   Description                                  *
* ------ ---------- ---   ---------------------------------------------*
* acpppk 07/23/2003 1.00  Created                                      *
*                                                                      *
***********************************************************************/

/* Insert into trans table a CSQ or COR with quantity sign negative and  
   same quantity and reason code as that of the current OSD record.
   Delete the record from OSD table if display_record='N'*/


PROCEDURE p_Create_Neg_corrxns_for_OSD
(in_v_rec_id IN erm.erm_id%TYPE,
in_v_orig_pallet_id IN osd.orig_pallet_id%TYPE,
in_v_osd_type IN osd.osd_type%TYPE,
in_v_erm_type IN erm.erm_type%TYPE,
in_n_osd_qty IN osd.osd_qty%TYPE,
in_v_old_reason_code IN osd.reason_code%TYPE)
IS
   lv_prod_id trans.prod_id%TYPE;
   lv_cpv trans.cust_pref_vendor%TYPE;
   ln_uom trans.uom%TYPE;
   ln_qty_expected trans.qty_expected%TYPE;
   lv_new_status trans.new_status%TYPE;
   lv_warehouse_id trans.warehouse_id%TYPE;
   lv_dest_loc trans.dest_loc%TYPE;
BEGIN
   SELECT prod_id,cust_pref_vendor,uom,dest_loc,qty_expected,new_status,warehouse_id
      INTO lv_prod_id,lv_cpv,ln_uom,lv_dest_loc,ln_qty_expected,
           lv_new_status,lv_warehouse_id
         FROM trans
            WHERE pallet_id = in_v_orig_pallet_id
            AND rec_id = in_v_rec_id
            AND trans_type in ('PUT','TRP');
   BEGIN
      INSERT into trans(
         trans_id,trans_type,trans_date,prod_id,cust_pref_vendor,user_id,
         qty,reason_code,rec_id,upload_time,warehouse_id,pallet_id,uom,
         dest_loc,qty_expected,new_status)
      values(trans_id_seq.NEXTVAL,decode(in_v_erm_type,'SN','CSQ','COR'),
         sysdate,lv_prod_id,lv_cpv,
         user,(-1 * in_n_OSD_qty),in_v_old_reason_code,in_v_rec_id,
         to_date('01-JAN-1980','DD-MON-YYYY'),lv_warehouse_id,
         in_v_orig_pallet_id,ln_uom,lv_dest_loc,ln_qty_expected,
         decode(in_v_osd_type,'DMG','DMG',lv_new_status));
   EXCEPTION
      when OTHERS then
         RAISE;
   END;
   
EXCEPTION
   when OTHERS then
      RAISE;
END p_Create_Neg_corrxns_for_OSD;

/***********************************************************************
* TYPE               : Procedure                                       *
* NAME               : p_Create_OS_corrxns_for_OSD                     *
* INPUT Parameters   : in_v_rec_id,in_v_orig_pallet_id,in_v_osd_type,   *
*                      in_v_erm_type,in_n_osd_qty,in_v_reason_code,    *
*                      in_n_diff_qty                                   *
* OUTPUT Parameters  :                                                 *
* PURPOSE            : To create COR transactions with same sign       *
*                      when changes are made to qty from Corrections   *
* Global variables   :                                                 *
* Procs./Fns. Used   : None                                            *
* Used in Procs./Fns.: None                                            *
*                                                                      *
* Author Date       Ver   Description                                  *
* ------ ---------- ---   ---------------------------------------------*
* acpppk 07/23/2003 1.00  Created                                      *
*                                                                      *
***********************************************************************/

/* Insert into trans table a CSQ or COR with same quantity sign 
   and quantity  = qty corr - qty rcv  if this quantity <>0 
   and blank reason code.
   Get the value of qty corr + qty dmg - qty ord as input parameter.
   Insert into trans table a CSQ or COR with this quantity(if it's not 0)  
   and reason code as overage or shortage depending on whether  
   qty corr + dmg > qty ord*/


PROCEDURE p_Create_OS_corrxns_for_OSD
(in_v_rec_id IN erm.erm_id%TYPE,
in_v_orig_pallet_id IN osd.orig_pallet_id%TYPE,
in_v_osd_type IN osd.osd_type%TYPE,
in_v_erm_type IN erm.erm_type%TYPE,
in_n_osd_qty IN osd.osd_qty%TYPE,
in_v_reason_code IN osd.reason_code%TYPE,
in_n_diff_qty IN trans.qty%TYPE)
IS
   lv_prod_id trans.prod_id%TYPE;
   lv_cpv trans.cust_pref_vendor%TYPE;
   ln_uom trans.uom%TYPE;
   ln_qty_expected trans.qty_expected%TYPE;
   lv_new_status trans.new_status%TYPE;
   lv_warehouse_id trans.warehouse_id%TYPE;
   lv_dest_loc trans.dest_loc%TYPE;
BEGIN
   SELECT prod_id,cust_pref_vendor,uom,dest_loc,qty_expected,new_status,warehouse_id
     INTO lv_prod_id,lv_cpv,ln_uom,lv_dest_loc,ln_qty_expected,
          lv_new_status,lv_warehouse_id
        FROM trans
           WHERE pallet_id = in_v_orig_pallet_id
           AND rec_id = in_v_rec_id
           AND trans_type in ('PUT','TRP');
   if in_n_diff_qty <> 0 then
      BEGIN
         INSERT into trans(
            trans_id,trans_type,trans_date,prod_id,cust_pref_vendor,user_id,
            qty,reason_code,rec_id,upload_time,warehouse_id,pallet_id,uom,
            dest_loc,qty_expected,new_status)
          values(trans_id_seq.NEXTVAL,decode(in_v_erm_type,'SN','CSQ','COR'),
            sysdate,lv_prod_id,lv_cpv,
            user,in_n_diff_qty,NULL,in_v_rec_id,
            to_date('01-JAN-1980','DD-MON-YYYY'),lv_warehouse_id,
            in_v_orig_pallet_id,ln_uom,lv_dest_loc,ln_qty_expected,lv_new_status);
      EXCEPTION
         when OTHERS then
           RAISE;
      END;
  end if;
  if in_n_osd_qty <> 0 then
      BEGIN
         INSERT into trans(
            trans_id,trans_type,trans_date,prod_id,cust_pref_vendor,user_id,
            qty,reason_code,rec_id,upload_time,warehouse_id,pallet_id,uom,
            dest_loc,qty_expected,new_status)
          values(trans_id_seq.NEXTVAL,decode(in_v_erm_type,'SN','CSQ','COR'),
            sysdate,lv_prod_id,lv_cpv,
            user,in_n_osd_qty,in_v_reason_code,in_v_rec_id,
            to_date('01-JAN-1980','DD-MON-YYYY'),lv_warehouse_id,
            in_v_orig_pallet_id,ln_uom,lv_dest_loc,ln_qty_expected,lv_new_status);
      EXCEPTION
         when OTHERS then
           RAISE;
      END;
  end if; 
EXCEPTION
   when OTHERS then
      RAISE;
END p_Create_OS_corrxns_for_OSD;

/***********************************************************************
* TYPE               : Procedure                                       *
* NAME               : p_Create_dmg_corrxns_for_OSD                    *
* INPUT Parameters   : in_v_rec_id,in_v_orig_pallet_id,                 *
*                      in_v_erm_type,in_n_osd_qty,in_v_reason_code     *
*                                                                      *
* OUTPUT Parameters  :                                                 *
* PURPOSE            : To create COR transactions with new_status 'DMG'*
*                      when changes are made to dmg qty from           *
*                      Corrections                                     *
* Global variables   :                                                 *
* Procs./Fns. Used   : None                                            *
* Used in Procs./Fns.: None                                            *
*                                                                      *
* Author Date       Ver   Description                                  *
* ------ ---------- ---   ---------------------------------------------*
* acpppk 07/23/2003 1.00  Created                                      *
*                                                                      *
***********************************************************************/

/*For each of the dmg osd_type entries in OSD table for given  
  orig_pallet_id with non default reason codes
     Insert into trans table a CSQ or COR with positive quantity  
  sign and quantity  = qty osd  and reason code*/


PROCEDURE p_Create_dmg_corrxns_for_OSD
(in_v_rec_id IN erm.erm_id%TYPE,
in_v_orig_pallet_id IN osd.orig_pallet_id%TYPE,
in_v_erm_type IN erm.erm_type%TYPE,
in_n_osd_qty IN osd.osd_qty%TYPE,
in_v_reason_code IN osd.reason_code%TYPE)
IS
   lv_prod_id trans.prod_id%TYPE;
   lv_cpv trans.cust_pref_vendor%TYPE;
   ln_uom trans.uom%TYPE;
   ln_qty_expected trans.qty_expected%TYPE;
   lv_warehouse_id trans.warehouse_id%TYPE;
   lv_dest_loc trans.dest_loc%TYPE;
BEGIN
   SELECT prod_id,cust_pref_vendor,uom,dest_loc,qty_expected,warehouse_id
     INTO lv_prod_id,lv_cpv,ln_uom,lv_dest_loc,ln_qty_expected,
          lv_warehouse_id
        FROM trans
           WHERE pallet_id = in_v_orig_pallet_id
           AND rec_id = in_v_rec_id
           AND trans_type in ('PUT','TRP');
      
      INSERT into trans(
         trans_id,trans_type,trans_date,prod_id,cust_pref_vendor,user_id,
         qty,reason_code,rec_id,upload_time,warehouse_id,pallet_id,uom,
         dest_loc,qty_expected,new_status)
       values(trans_id_seq.NEXTVAL,decode(in_v_erm_type,'SN','CSQ','COR'),
         sysdate,lv_prod_id,lv_cpv,
         user,in_n_osd_qty,in_v_reason_code,in_v_rec_id,
         to_date('01-JAN-1980','DD-MON-YYYY'),lv_warehouse_id,
         in_v_orig_pallet_id,ln_uom,lv_dest_loc,ln_qty_expected,'DMG');
            
EXCEPTION
   when OTHERS then
      RAISE;
END p_Create_dmg_corrxns_for_OSD;
         

END pl_process_osd;
/
