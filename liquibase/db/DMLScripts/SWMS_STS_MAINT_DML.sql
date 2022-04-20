/****************************************************************************
** File:       SWMS_STS_MAINT_DML.sql
**
** Desc: Script to insert Maintenance data for swms-sts interface
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    24-Oct-2018 Vishnupriya K.     setup sts Maintenance data for Opco  
**    
****************************************************************************/
DECLARE
  v_exists NUMBER := 0;
  v_template varchar2(500);
  v_dcid varchar2(50);
  v_data varchar2(5) :='Y';
BEGIN
  SELECT COUNT(*)
  INTO v_exists
  from  maintenance b
  where b.APPLICATION = 'SWMS'
  and b.COMPONENT = 'DCID'
  and b.ATTRIBUTE = 'MACHINE' ;

IF (v_exists = 0)  THEN 

BEGIN
 select a.DCID, a.TMPLT
 into v_dcid,  v_template
  from  maintenance b, STS_OPCO_DCID a
  where b.APPLICATION = 'SWMS'
  and b.COMPONENT = 'COMPANY'
  and b.ATTRIBUTE = 'MACHINE'  
  and a.OPCO_ID = substr(b.ATTRIBUTE_VALUE,1,3);
  
Exception when others then 

   v_data := 'N'; 
  
End;  

  If v_data = 'Y' then
  
   Insert into maintenance(CREATE_DATE, COMPONENT ,APPLICATION , ATTRIBUTE , ATTRIBUTE_VALUE )
   Values(trunc(sysdate), 'DCID', 'SWMS','MACHINE', v_dcid);

   Insert into maintenance(CREATE_DATE, COMPONENT ,APPLICATION , ATTRIBUTE , ATTRIBUTE_VALUE )
   Values(trunc(sysdate), 'STS_TMPLT', 'SWMS','MACHINE', v_template);
   
   Commit;
  
 End If;  
  
                         
End If;
End;					
/		  