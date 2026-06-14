-- Temporary table for hierarchy mapping (Level 2 managers for each sales)
CREATE TEMPORARY TABLE IF NOT EXISTS temp_hierarchy (
    no_urut DOUBLE,
    node_id VARCHAR(20),
    nilai_order DOUBLE,
    level2_manager VARCHAR(10)
);

-- Clear any existing data
TRUNCATE TABLE temp_hierarchy;

-- Populate hierarchy: Find Level 2 manager for each sales transaction
-- Traverse up to 6 levels to accommodate deep hierarchies
INSERT INTO temp_hierarchy
SELECT 
    o.no_urut,
    o.node_id,
    o.nilai_order,
    COALESCE(
        -- Direct children of ROOT
        CASE WHEN n.parent_id = 'ROOT' THEN n.id END,
        -- Grandchildren of ROOT
        CASE WHEN n1.parent_id = 'ROOT' THEN n1.id END,
        -- Great-grandchildren
        CASE WHEN n2.parent_id = 'ROOT' THEN n2.id END,
        -- Great-great-grandchildren
        CASE WHEN n3.parent_id = 'ROOT' THEN n3.id END,
        -- Great-great-great-grandchildren
        CASE WHEN n4.parent_id = 'ROOT' THEN n4.id END,
        -- And deeper levels
        CASE WHEN n5.parent_id = 'ROOT' THEN n5.id END
    ) AS level2_manager
FROM orders o
JOIN nodes n ON o.node_id = n.id
LEFT JOIN nodes n1 ON n.parent_id = n1.id
LEFT JOIN nodes n2 ON n1.parent_id = n2.id
LEFT JOIN nodes n3 ON n2.parent_id = n3.id
LEFT JOIN nodes n4 ON n3.parent_id = n4.id
LEFT JOIN nodes n5 ON n4.parent_id = n5.id;

-- Main query: Summary + Detail of outliers
SELECT 
    level2,
    jumlah_anomali,
    id,
    nilai_order,
    average,
    stdev,
    jarak_average,
    z_score
FROM (
    -- ====================================================================
    -- PART 1: SUMMARY (Count outliers per Level 2 manager)
    -- ====================================================================
    SELECT 
        CAST(stats.level2_manager AS CHAR) AS level2,
        CAST(COUNT(DISTINCT outliers.no_urut) AS SIGNED) AS jumlah_anomali,
        NULL AS id,
        NULL AS nilai_order,
        NULL AS average,
        NULL AS stdev,
        NULL AS jarak_average,
        NULL AS z_score,
        stats.level2_manager AS sort_group,
        1 AS sort_priority
    FROM (
        -- Calculate group statistics
        SELECT 
            th.level2_manager,
            AVG(th.nilai_order) AS group_avg,
            STDDEV_POP(th.nilai_order) AS group_std
        FROM temp_hierarchy th
        WHERE th.level2_manager IS NOT NULL
        GROUP BY th.level2_manager
    ) stats
    LEFT JOIN (
        -- Identify outliers using subquery (no window functions)
        SELECT 
            th.no_urut,
            th.node_id,
            th.level2_manager,
            th.nilai_order
        FROM temp_hierarchy th
        JOIN (
            SELECT 
                level2_manager,
                AVG(nilai_order) AS group_avg,
                STDDEV_POP(nilai_order) AS group_std
            FROM temp_hierarchy
            WHERE level2_manager IS NOT NULL
            GROUP BY level2_manager
        ) g ON th.level2_manager = g.level2_manager
        WHERE g.group_std > 0
          AND (th.nilai_order > g.group_avg + 3 * g.group_std
               OR th.nilai_order < g.group_avg - 3 * g.group_std)
    ) outliers ON stats.level2_manager = outliers.level2_manager
    GROUP BY stats.level2_manager

    UNION ALL

    -- ====================================================================
    -- PART 2: DETAIL (Show individual outliers with statistics)
    -- ====================================================================
    SELECT 
        NULL AS level2,
        NULL AS jumlah_anomali,
        CAST(th.node_id AS CHAR) AS id,
        CAST(th.nilai_order AS DOUBLE) AS nilai_order,
        CAST(stats.group_avg AS DOUBLE) AS average,
        CAST(stats.group_std AS DOUBLE) AS stdev,
        CAST(th.nilai_order - stats.group_avg AS DOUBLE) AS jarak_average,
        CAST((th.nilai_order - stats.group_avg) / stats.group_std AS DOUBLE) AS z_score,
        th.level2_manager AS sort_group,
        2 AS sort_priority
    FROM temp_hierarchy th
    JOIN (
        -- Group statistics
        SELECT 
            level2_manager,
            AVG(nilai_order) AS group_avg,
            STDDEV_POP(nilai_order) AS group_std
        FROM temp_hierarchy
        WHERE level2_manager IS NOT NULL
        GROUP BY level2_manager
    ) stats ON th.level2_manager = stats.level2_manager
    WHERE stats.group_std > 0
      AND (th.nilai_order > stats.group_avg + 3 * stats.group_std
           OR th.nilai_order < stats.group_avg - 3 * stats.group_std)

) final_data
ORDER BY sort_group DESC, sort_priority ASC, id ASC;
