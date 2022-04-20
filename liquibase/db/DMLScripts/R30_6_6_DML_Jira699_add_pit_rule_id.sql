INSERT INTO RULES (
    rule_id, 
    rule_type, 
    rule_desc, 
    def, 
    rvalue, 
    maintainable)
SELECT 
    11,
    'PUT',
    'PIT PRODUCTION LINE AREA',
    'N',
    null,
    null
FROM dual WHERE NOT EXISTS (SELECT 1 FROM rules WHERE rule_id = 11);

INSERT INTO RULES (
    rule_id, 
    rule_type, 
    rule_desc, 
    def, 
    rvalue, 
    maintainable)
SELECT 
    13,
    'PUT',
    'CUSTOMER RACK AREA',
    'N',
    null,
    null
FROM dual WHERE NOT EXISTS (SELECT 1 FROM rules WHERE rule_id = 13);
COMMIT;
