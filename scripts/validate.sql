-- Snapshot counts for the supplied v1.7.0 reduced dataset.
SELECT CASE WHEN count(*) = 499 THEN true
       ELSE error('Expected 499 parts including placeholders') END FROM supply_chain.part;
SELECT CASE WHEN count(*) FILTER (WHERE NOT is_placeholder) = 494
                 AND count(*) FILTER (WHERE is_placeholder) = 5 THEN true
       ELSE error('Expected 494 source items and 5 placeholders') END FROM supply_chain.part;
SELECT CASE WHEN count(*) = 765 THEN true
       ELSE error('Expected 765 as-built relationships') END FROM supply_chain.contains;
SELECT CASE WHEN count(*) = 0 THEN true
       ELSE error('Relationship with missing endpoint') END
FROM supply_chain.contains c
LEFT JOIN supply_chain.part p ON p.part_id = c.parent_id
LEFT JOIN supply_chain.part q ON q.part_id = c.child_id
WHERE p.part_id IS NULL OR q.part_id IS NULL;

-- Counts are intentionally tied to the two bundled snapshots.
SELECT CASE WHEN count(*) = 42 THEN true
       ELSE error('Expected 42 planned types') END FROM supply_chain.part_type;
SELECT CASE WHEN count(*) = 70 THEN true
       ELSE error('Expected 70 planned relationships') END FROM supply_chain.planned_contains;
SELECT CASE WHEN count(*) = 266 AND count(DISTINCT type_id) = 3 THEN true
       ELSE error('Expected 266 inferred matches to 3 planned types') END FROM supply_chain.part_type_match;
SELECT CASE WHEN count(*) = 0 THEN true
       ELSE error('Planned relationship with missing endpoint') END
FROM supply_chain.planned_contains c
LEFT JOIN supply_chain.part_type p ON p.type_id = c.parent_id
LEFT JOIN supply_chain.part_type q ON q.type_id = c.child_id
WHERE p.type_id IS NULL OR q.type_id IS NULL;
SELECT CASE WHEN count(*) = 0 THEN true
       ELSE error('Invalid inferred match') END
FROM supply_chain.part_type_match m
LEFT JOIN supply_chain.part p ON p.part_id = m.part_id
LEFT JOIN supply_chain.part_type t ON t.type_id = m.type_id
WHERE p.part_id IS NULL OR t.type_id IS NULL OR p.is_placeholder
   OR p.business_partner_id IS DISTINCT FROM t.business_partner_id
   OR p.manufacturer_part_id IS DISTINCT FROM t.manufacturer_part_id
   OR m.match_basis <> 'business_partner_and_part_number' OR NOT m.is_inferred;

SELECT CASE WHEN count(*) = 0 THEN true
       ELSE error('Inferred match targets an ambiguous type key') END
FROM supply_chain.part_type_match m
JOIN supply_chain.part_type t ON t.type_id = m.type_id
WHERE (SELECT count(*) FROM supply_chain.part_type other
       WHERE other.business_partner_id = t.business_partner_id
         AND other.manufacturer_part_id = t.manufacturer_part_id) <> 1;
