-- Relational equivalent of queries/04-affected-vehicles.cypher, run in DuckDB.
-- Track edge IDs to avoid reusing an edge, matching Cypher path semantics.
WITH RECURSIVE upstream(part_id, depth, used_edges) AS (
    SELECT parent_id, 1, [edge_id]
    FROM supply_chain.contains
    WHERE child_id = 'urn:uuid:ff827b41-9718-47c2-9786-e4f866889f60'
    UNION ALL
    SELECT c.parent_id, u.depth + 1, list_append(u.used_edges, c.edge_id)
    FROM upstream u
    JOIN supply_chain.contains c ON c.child_id = u.part_id
    WHERE u.depth < 5 AND NOT list_contains(u.used_edges, c.edge_id)
)
SELECT DISTINCT p.part_id AS vehicle_id, p.name AS vehicle_name
FROM upstream u JOIN supply_chain.part p ON p.part_id = u.part_id
WHERE p.name = 'Vehicle Fully Electric'
ORDER BY vehicle_id;
