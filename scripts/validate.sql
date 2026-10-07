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
