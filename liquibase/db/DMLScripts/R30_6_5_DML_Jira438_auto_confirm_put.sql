INSERT INTO RULES (
    rule_id, 
    rule_type, 
    rule_desc, 
    def, 
    rvalue, 
    maintainable)
SELECT 
    9,
    'PUT',
    'RCV INTO STAGING LOC BY CUSTOMER',
    'N',
    null,
    null
FROM dual WHERE NOT EXISTS (SELECT 1 FROM rules WHERE rule_id = 9);
COMMIT;