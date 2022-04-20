
  CREATE TABLE "SWMS"."BATCH_HOLD" 
   (	"BATCH_NO" VARCHAR2(13 CHAR) NOT NULL ENABLE, 
	"JBCD_JOB_CODE" VARCHAR2(6 CHAR) NOT NULL ENABLE, 
	"STATUS" VARCHAR2(1 CHAR) NOT NULL ENABLE, 
	"BATCH_DATE" DATE, 
  "HOLD_DATE" DATE,
  "CANCEL_HOLD_DATE" DATE,
	"REPORT_DATE" DATE, 
	"MISPICK" NUMBER(6,0), 
	"DAMAGE" NUMBER(6,0), 
	"SHORTS" NUMBER(6,0), 
	"GOAL_TIME" NUMBER(8,2), 
	"TARGET_TIME" NUMBER(8,2), 
	"USER_ID" VARCHAR2(30 CHAR), 
	"USER_SUPERVSR_ID" VARCHAR2(30 CHAR), 
	"ACTL_START_TIME" DATE, 
	"ACTL_STOP_TIME" DATE, 
	"ACTL_TIME_SPENT" NUMBER(12,2), 
	"MOD_DATE" DATE, 
	"MOD_USR" VARCHAR2(30 CHAR), 
	"REF_NO" VARCHAR2(40 CHAR), 
	"PARENT_BATCH_NO" VARCHAR2(13 CHAR), 
	"PARENT_BATCH_DATE" DATE, 
	"NO_BREAKS" NUMBER(2,0), 
	"NO_LUNCHES" NUMBER(2,0), 
	"KVI_DOC_TIME" NUMBER(6,0), 
	"KVI_CUBE" NUMBER(12,4), 
	"KVI_WT" NUMBER(6,0), 
	"KVI_NO_PIECE" NUMBER(6,0), 
	"KVI_NO_PALLET" NUMBER(6,0), 
	"KVI_NO_ITEM" NUMBER(6,0), 
	"KVI_NO_DATA_CAPTURE" NUMBER(6,0), 
	"KVI_NO_PO" NUMBER(6,0), 
	"KVI_NO_STOP" NUMBER(6,0), 
	"KVI_NO_ZONE" NUMBER(6,0), 
	"KVI_NO_LOC" NUMBER(6,0), 
	"KVI_NO_CASE" NUMBER(6,0), 
	"KVI_NO_SPLIT" NUMBER(6,0), 
	"KVI_NO_MERGE" NUMBER(6,0), 
	"KVI_NO_AISLE" NUMBER(6,0), 
	"KVI_NO_DROP" NUMBER(6,0), 
	"KVI_ORDER_TIME" NUMBER(6,0), 
	"KVI_FROM_LOC" VARCHAR2(10 CHAR), 
	"KVI_TO_LOC" VARCHAR2(10 CHAR), 
	"KVI_DISTANCE" NUMBER(10,4), 
	"KVI_NO_CART" NUMBER(6,0), 
	"KVI_NO_PALLET_PIECE" NUMBER(6,0), 
	"KVI_NO_CART_PIECE" NUMBER(6,0), 
	"INS_INDIRECT_DT" DATE, 
	"INS_INDIRECT_JOBCD" VARCHAR2(6 CHAR), 
	"USERENV" VARCHAR2(20 CHAR), 
	"TOTAL_COUNT" NUMBER(6,0), 
	"TOTAL_PALLET" NUMBER(10,0), 
	"TOTAL_PIECE" NUMBER(10,0), 
	"SOS_RESERVED" NUMBER(1,0) DEFAULT 0, 
	"EQUIP_ID" VARCHAR2(10 CHAR), 
	"ABC_DISTANCE" NUMBER(7,1), 
	"BATCH_SUSPEND_DATE" DATE, 
	"CMT" VARCHAR2(60 CHAR), 
	"MSKU_BATCH_FLAG" VARCHAR2(1 CHAR), 
	"LXLI_GOALTIME_UPLOAD" VARCHAR2(1 CHAR), 
	"DS_CASE_TIME" NUMBER(10,4), 
	"DS_SPLIT_TIME" NUMBER(10,4), 
	"KVI_NO_CLAM_BED_DATA_CAPTURE" NUMBER(6,0), 
	"KVI_PICKUP_OBJECT" NUMBER(6,0), 
	"KVI_WALK" NUMBER(8,1), 
	"KVI_WALK_EQUIPMENT" NUMBER(8,1), 
	"LXLI_SEND_FLAG" VARCHAR2(1 CHAR), 
	"LXLI_SEND_TIME1" DATE, 
	"LXLI_SEND_TIME2" DATE, 
	"ADD_DATE" DATE DEFAULT SYSDATE, 
	"ADD_USER" VARCHAR2(30 CHAR) DEFAULT REPLACE (USER, 'OPS$'), 
	"UPD_DATE" DATE, 
	"UPD_USER" VARCHAR2(30 CHAR), 
	"REF_BATCH_NO" VARCHAR2(13 CHAR), 
	"DROPPED_FOR_A_BREAK_AWAY_FLAG" VARCHAR2(1 CHAR), 
	"RESUMED_AFTER_BREAK_AWAY_FLAG" VARCHAR2(1 CHAR), 
	"INITIAL_PICKUP_SCAN_DATE" DATE, 
	"DOOR_DROP_TIME" DATE, 
	"SWMS_GOAL_TIME" NUMBER(8,2), 
	"LXLI_GOAL_UPD_TIME" DATE, 
	 CONSTRAINT "B_HOL_MSKU_BATCH_FLAG_CHK" CHECK (msku_batch_flag IN ('Y', 'N')
                                    OR msku_batch_flag IS NULL) ENABLE, 
	 CONSTRAINT "ARCH_B_MSKU_BATCH_FLAG_CHK" CHECK (msku_batch_flag IN ('Y', 'N')
                                    OR msku_batch_flag IS NULL) ENABLE, 
	 CONSTRAINT "B_HOL_DROPFOR_A_BRKAWAYFLAG" CHECK (dropped_for_a_break_away_flag IN ('N', 'Y')) ENABLE, 
	 CONSTRAINT "B_HOL_RESUME_AFTERBRKAWAYFLAG" CHECK (resumed_after_break_away_flag IN ('N', 'Y')) ENABLE
   ) SEGMENT CREATION IMMEDIATE 
  PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "SWMS_DTS1" ;
 

   COMMENT ON COLUMN "SWMS"."BATCH_HOLD"."BATCH_SUSPEND_DATE" IS 'Date and time the batch was suspended.  Used in the calculation of the travel distance for a batch completed within a suspended batch.';
 
   COMMENT ON COLUMN "SWMS"."BATCH_HOLD"."CMT" IS 'Comments about the batch.';
 
   COMMENT ON COLUMN "SWMS"."BATCH_HOLD"."MSKU_BATCH_FLAG" IS 'Is the batch for a MSKU pallet.';
 

  CREATE INDEX "SWMS"."BATCH_HOLD_NK1" ON "SWMS"."BATCH_HOLD" ("STATUS") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "SWMS_ITS1" ;
 

  CREATE INDEX "SWMS"."BATCH_HOLD_NK2" ON "SWMS"."BATCH_HOLD" ("JBCD_JOB_CODE") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "SWMS_ITS1" ;
 

  CREATE INDEX "SWMS"."BATCH_HOLD_NK3" ON "SWMS"."BATCH_HOLD" ("USER_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "SWMS_ITS1" ;
 

  CREATE INDEX "SWMS"."BATCH_HOLD_NK4" ON "SWMS"."BATCH_HOLD" ("PARENT_BATCH_NO") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "SWMS_ITS1" ;
 

  CREATE INDEX "SWMS"."BATCH_HOLD_NK5" ON "SWMS"."BATCH_HOLD" ("REF_NO") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "SWMS_ITS1" ;
 

  CREATE UNIQUE INDEX "SWMS"."BATCH_HOLD_PK" ON "SWMS"."BATCH_HOLD" ("BATCH_NO", "BATCH_DATE") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "SWMS_ITS1" ;
 

  CREATE OR REPLACE TRIGGER "SWMS"."TRG_INSUPD_BATCH_HOLD_BROW" 
       BEFORE INSERT OR UPDATE ON swms.batch_hold
       FOR EACH ROW
DECLARE
   l_start_dur           NUMBER;
   l_batch_no            batch.batch_no%TYPE;
   l_istart_batch_no     batch.batch_no%TYPE;
   l_job_class           job_code.jbcl_job_class%type;
   l_lm_retro_on         usr.lm_retro_on%TYPE;
   l_actl_start_time     batch.actl_start_time%TYPE;
   l_actl_stop_time      batch.actl_stop_time%TYPE;
   l_cnt                 NUMBER;
begin
/* DN10728 prppxx added */
IF INSERTING THEN
      :new.batch_date := trunc(:new.batch_date);
   IF :new.user_id IS NOT NULL and :new.jbcd_job_code in ('ISTART','ISTOP') THEN

      BEGIN
         IF :new.jbcd_job_code = 'ISTART' THEN
           pl_lm_retro.get_retro_flag(:new.user_id, l_lm_retro_on);
           IF l_lm_retro_on = 'Y' THEN
             pl_lm_retro.get_retro_info(:new.user_id, :new.jbcd_job_code,
                                        l_actl_start_time, l_start_dur);

             IF SYSDATE > (l_actl_start_time + nvl(l_start_dur,0)/1440) THEN
               pl_lm_retro.g_user_id := :new.user_id;
               :new.actl_start_time := l_actl_start_time;
               IF :new.status = 'C' THEN
                 :new.actl_stop_time := l_actl_start_time + nvl(l_start_dur,0)/1440;
                 :new.actl_time_spent := l_start_dur;
                 pl_lm_retro.g_count_retro := 1;
               ELSE
                 pl_lm_retro.g_count_retro := 0;
               END IF;
             END IF;
           END IF; /* lm_retro_on is Y */
         END IF;

      EXCEPTION WHEN NO_DATA_FOUND THEN
         null;
      END;
   END IF;
ELSIF UPDATING THEN
      :new.upd_user := REPLACE(USER, 'OPS$');
      :new.upd_date := SYSDATE;
      if :new.batch_date != :old.batch_date then
         :new.batch_date := trunc(:new.batch_date);
      end if;
      BEGIN
        pl_lm_retro.get_retro_flag(:new.user_id, l_lm_retro_on);
        IF l_lm_retro_on = 'Y' THEN
           IF pl_lm_retro.g_user_id = :new.user_id THEN
             IF pl_lm_retro.g_count_retro = 1 OR :new.jbcd_job_code = 'ISTART' THEN
                  pl_lm_retro.get_retro_info(:new.user_id, :new.jbcd_job_code,
                                             l_actl_start_time, l_start_dur);

                  IF :new.jbcd_job_code = 'ISTART' THEN
                     IF :new.status = 'C' THEN
                        :new.actl_stop_time := l_actl_start_time + nvl(l_start_dur,0)/1440;
                        :new.actl_time_spent := l_start_dur;
                        pl_lm_retro.g_count_retro := 1;
                     END IF;
                  ELSE
                     IF (:old.status != :new.status AND :new.status = 'A') THEN
                        :new.actl_start_time := l_actl_start_time + nvl(l_start_dur,0)/1440;
                        pl_lm_retro.g_count_retro := 0;
                     END IF;
                  END IF;
             ELSE
                  pl_lm_retro.g_count_retro := 0;
             END IF;
           END IF;
        END IF;
      EXCEPTION WHEN NO_DATA_FOUND THEN
         null;
     END;
     IF :new.batch_no LIKE 'S%' THEN
	BEGIN
		UPDATE sos_batch
		SET status = DECODE(status,'X','X',:new.status),
		    picked_by = DECODE(:new.status,
					'F', DECODE(reserved_by,
						NULL, NULL,
						picked_by),
                                         picked_by),
		    end_time = DECODE(:new.status, 'C', SYSDATE, NULL)
		WHERE batch_no = SUBSTR(:new.batch_no, 2);
		IF :new.status = 'F' THEN
			-- If status is not F, keep whatever the start_time
			-- was. This prevents the system updates the start_time
			-- time portion to 00:00:00 due to default date
			-- format setting.
			UPDATE sos_batch
			SET start_time = NULL
			WHERE batch_no = SUBSTR(:new.batch_no, 2);
		END IF;
	EXCEPTION
		WHEN OTHERS THEN
			NULL;
	END;

        IF :new.status = 'F' AND :old.status = 'A' AND :old.lxli_send_flag = '1' THEN
           :new.lxli_send_flag := NULL;
        END IF;
     END IF;
END IF;
end;
/
ALTER TRIGGER "SWMS"."TRG_INSUPD_BATCH_HOLD_BROW" ENABLE;

GRANT select, update, delete, insert on batch_hold to swms_user;
GRANT select on batch_hold to swms_viewer; 

create or replace public synonym batch_hold for swms.batch_hold; 
