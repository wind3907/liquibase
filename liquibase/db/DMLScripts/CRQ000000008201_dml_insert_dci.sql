/********************************************************************
**      To Insert new Reason codes for Donations 
********************************************************************/
INSERT INTO SWMS.REASON_CDS (REASON_CD_TYPE,
                             REASON_CD,
                             REASON_DESC,
                             RESALE,
                             REASON_GROUP,
                             MISC,
                             CC_REASON_CODE)
		  values ('RTN',
			  'D81',
			  'Damage/Donate Delv',
			  '',
			  'DMG',
			  'N',
			  'SE');
INSERT INTO SWMS.REASON_CDS (REASON_CD_TYPE,
                             REASON_CD,
                             REASON_DESC,
                             RESALE,
                             REASON_GROUP,
                             MISC,
                             CC_REASON_CODE)
		  values ('RTN',
			  'D82',
			  'Damage/Donate Sales',
			  '',
			  'DMG',
			  'N',
			  'SE');
INSERT INTO SWMS.REASON_CDS (REASON_CD_TYPE,
                             REASON_CD,
                             REASON_DESC,
                             RESALE,
                             REASON_GROUP,
                             MISC,
                             CC_REASON_CODE)
		  values ('RTN',
			  'D83',
			  'Damage/Donate Whse',
			  '',
			  'DMG',
			  'N',
			  'SE');

INSERT INTO SWMS.REASON_CDS (REASON_CD_TYPE,
                             REASON_CD,
                             REASON_DESC,
                             RESALE,
                             REASON_GROUP,
                             MISC,
                             CC_REASON_CODE)
                  values ('ADJ',
                          'D81',
                          'Damage/Donate Delv',
                          '',
                          'DMG',
                          'N',
                          'SE');
INSERT INTO SWMS.REASON_CDS (REASON_CD_TYPE,
                             REASON_CD,
                             REASON_DESC,
                             RESALE,
                             REASON_GROUP,
                             MISC,
                             CC_REASON_CODE)
                  values ('ADJ',
                          'D82',
                          'Damage/Donate Sales',
                          '',
                          'DMG',
                          'N',
                          'SE');
INSERT INTO SWMS.REASON_CDS (REASON_CD_TYPE,
                             REASON_CD,
                             REASON_DESC,
                             RESALE,
                             REASON_GROUP,
                             MISC,
                             CC_REASON_CODE)
                  values ('ADJ',
                          'D83',
                          'Damage/Donate Whse',
                          '',
                          'DMG',
                          'N',
                          'SE');


COMMIT;
