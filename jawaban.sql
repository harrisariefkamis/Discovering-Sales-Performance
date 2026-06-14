-- Step 1: Find Level 2 manager for each sales using recursive approach
-- This handles any depth in the hierarchy tree
WITH RECURSIVE hierarchy AS (
    -- Base case: All direct children of ROOT are Level 2 managers
    SELECT 
        id,
        id AS level2_manager,
        1 AS depth
    FROM nodes
    WHERE parent_id = 'ROOT'
    
    UNION ALL
    
    -- Recursive case: Get all descendants and their Level 2 manager
    SELECT 
        n.id,
        h.level2_manager,
        h.depth + 1
    FROM nodes n
    JOIN hierarchy h ON n.parent_id = h.id
    WHERE h.depth < 20  -- Prevent infinite recursion
),

-- Step 2: Map each order to its Level 2 manager
orders_with_manager AS (
    SELECT 
        o.no_urut,
        o.node_id,
        o.nilai_order,
        h.level2_manager
    FROM orders o
    JOIN nodes n ON o.node_id = n.id
    LEFT JOIN hierarchy h ON n.id = h.id
    WHERE h.level2_manager IS NOT NULL OR n.parent_id = 'ROOT'
),

-- Step 3: Calculate group statistics and Z-scores using window functions
orders_with_stats AS (
    SELECT 
        no_urut,
        node_id,
        nilai_order,
        level2_manager,
        AVG(nilai_order) OVER (PARTITION BY level2_manager) AS group_avg,
        STDDEV_POP(nilai_order) OVER (PARTITION BY level2_manager) AS group_std,
        nilai_order - AVG(nilai_order) OVER (PARTITION BY level2_manager) AS jarak_average,
        (nilai_order - AVG(nilai_order) OVER (PARTITION BY level2_manager)) / 
            NULLIF(STDDEV_POP(nilai_order) OVER (PARTITION BY level2_manager), 0) AS z_score
    FROM orders_with_manager
),

-- Step 4: Filter outliers (|z-score| > 3)
outliers AS (
    SELECT 
        no_urut,
        node_id,
        nilai_order,
        level2_manager,
        group_avg,
        group_std,
        jarak_average,
        z_score
    FROM orders_with_stats
    WHERE STDDEV_POP(nilai_order) OVER (PARTITION BY level2_manager) > 0
      AND (z_score > 3 OR z_score < -3)
),

-- Step 5: Summary - count outliers per Level 2 manager
summary AS (
    SELECT 
        level2_manager AS level2,
        COUNT(DISTINCT no_urut) AS jumlah_anomali,
        NULL AS id,
        NULL AS nilai_order,
        NULL AS average,
        NULL AS stdev,
        NULL AS jarak_average,
        NULL AS z_score,
        level2_manager AS sort_group,
        1 AS sort_priority
    FROM outliers
    GROUP BY level2_manager
),

-- Step 6: Detail - individual outlier records
detail AS (
    SELECT 
        NULL AS level2,
        NULL AS jumlah_anomali,
        node_id AS id,
        nilai_order,
        group_avg AS average,
        group_std AS stdev,
        jarak_average,
        z_score,
        level2_manager AS sort_group,
        2 AS sort_priority
    FROM outliers
)

-- Final output: Combine summary and detail
SELECT 
    level2,
    jumlah_anomali,
    id,
    nilai_order,
    average,
    stdev,
    jarak_average,
    z_score
FROM summary

UNION ALL

SELECT 
    level2,
    jumlah_anomali,
    id,
    nilai_order,
    average,
    stdev,
    jarak_average,
    z_score
FROM detail

ORDER BY sort_group DESC, sort_priority ASC, id ASC;
