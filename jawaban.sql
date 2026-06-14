-- MySQL 8.0 Solution: Find sales outliers using hierarchical grouping
-- Build hierarchy mapping and detect outliers per Level 2 manager

-- Step 1: Identify all Level 2 managers (direct children of ROOT)
-- Step 2: Map each sales to their Level 2 manager (up to 6 levels deep)
-- Step 3: Calculate statistics and Z-scores per group
-- Step 4: Filter and display outliers with summary

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
    -- SUMMARY: Count outliers per Level 2 manager
    SELECT 
        t1.level2_manager AS level2,
        COUNT(DISTINCT t1.no_urut) AS jumlah_anomali,
        NULL AS id,
        NULL AS nilai_order,
        NULL AS average,
        NULL AS stdev,
        NULL AS jarak_average,
        NULL AS z_score,
        t1.level2_manager AS sort_group,
        1 AS sort_priority
    FROM (
        -- Find outliers by checking z-score
        SELECT 
            o.no_urut,
            o.node_id,
            o.nilai_order,
            CASE
                -- Direct child of ROOT
                WHEN n.parent_id = 'ROOT' THEN n.id
                -- Grandchild of ROOT
                WHEN n1.parent_id = 'ROOT' THEN n1.id
                -- Great-grandchild
                WHEN n2.parent_id = 'ROOT' THEN n2.id
                -- Great-great-grandchild
                WHEN n3.parent_id = 'ROOT' THEN n3.id
                -- Great-great-great-grandchild
                WHEN n4.parent_id = 'ROOT' THEN n4.id
                -- Additional levels
                WHEN n5.parent_id = 'ROOT' THEN n5.id
            END AS level2_manager,
            AVG(o.nilai_order) OVER (
                PARTITION BY 
                    CASE
                        WHEN n.parent_id = 'ROOT' THEN n.id
                        WHEN n1.parent_id = 'ROOT' THEN n1.id
                        WHEN n2.parent_id = 'ROOT' THEN n2.id
                        WHEN n3.parent_id = 'ROOT' THEN n3.id
                        WHEN n4.parent_id = 'ROOT' THEN n4.id
                        WHEN n5.parent_id = 'ROOT' THEN n5.id
                    END
            ) AS group_avg,
            STDDEV_POP(o.nilai_order) OVER (
                PARTITION BY 
                    CASE
                        WHEN n.parent_id = 'ROOT' THEN n.id
                        WHEN n1.parent_id = 'ROOT' THEN n1.id
                        WHEN n2.parent_id = 'ROOT' THEN n2.id
                        WHEN n3.parent_id = 'ROOT' THEN n3.id
                        WHEN n4.parent_id = 'ROOT' THEN n4.id
                        WHEN n5.parent_id = 'ROOT' THEN n5.id
                    END
            ) AS group_std,
            (o.nilai_order - AVG(o.nilai_order) OVER (
                PARTITION BY 
                    CASE
                        WHEN n.parent_id = 'ROOT' THEN n.id
                        WHEN n1.parent_id = 'ROOT' THEN n1.id
                        WHEN n2.parent_id = 'ROOT' THEN n2.id
                        WHEN n3.parent_id = 'ROOT' THEN n3.id
                        WHEN n4.parent_id = 'ROOT' THEN n4.id
                        WHEN n5.parent_id = 'ROOT' THEN n5.id
                    END
            )) / NULLIF(STDDEV_POP(o.nilai_order) OVER (
                PARTITION BY 
                    CASE
                        WHEN n.parent_id = 'ROOT' THEN n.id
                        WHEN n1.parent_id = 'ROOT' THEN n1.id
                        WHEN n2.parent_id = 'ROOT' THEN n2.id
                        WHEN n3.parent_id = 'ROOT' THEN n3.id
                        WHEN n4.parent_id = 'ROOT' THEN n4.id
                        WHEN n5.parent_id = 'ROOT' THEN n5.id
                    END
            ), 0) AS z_score
        FROM orders o
        JOIN nodes n ON o.node_id = n.id
        LEFT JOIN nodes n1 ON n.parent_id = n1.id
        LEFT JOIN nodes n2 ON n1.parent_id = n2.id
        LEFT JOIN nodes n3 ON n2.parent_id = n3.id
        LEFT JOIN nodes n4 ON n3.parent_id = n4.id
        LEFT JOIN nodes n5 ON n4.parent_id = n5.id
    ) t1
    WHERE STDDEV_POP(t1.nilai_order) OVER (PARTITION BY t1.level2_manager) > 0
      AND (t1.z_score > 3 OR t1.z_score < -3)
    GROUP BY t1.level2_manager

    UNION ALL

    -- DETAIL: Show individual outlier records
    SELECT 
        NULL AS level2,
        NULL AS jumlah_anomali,
        t2.node_id AS id,
        t2.nilai_order,
        t2.group_avg AS average,
        t2.group_std AS stdev,
        t2.jarak_average,
        t2.z_score,
        t2.level2_manager AS sort_group,
        2 AS sort_priority
    FROM (
        SELECT 
            o.no_urut,
            o.node_id,
            o.nilai_order,
            CASE
                WHEN n.parent_id = 'ROOT' THEN n.id
                WHEN n1.parent_id = 'ROOT' THEN n1.id
                WHEN n2.parent_id = 'ROOT' THEN n2.id
                WHEN n3.parent_id = 'ROOT' THEN n3.id
                WHEN n4.parent_id = 'ROOT' THEN n4.id
                WHEN n5.parent_id = 'ROOT' THEN n5.id
            END AS level2_manager,
            AVG(o.nilai_order) OVER (
                PARTITION BY 
                    CASE
                        WHEN n.parent_id = 'ROOT' THEN n.id
                        WHEN n1.parent_id = 'ROOT' THEN n1.id
                        WHEN n2.parent_id = 'ROOT' THEN n2.id
                        WHEN n3.parent_id = 'ROOT' THEN n3.id
                        WHEN n4.parent_id = 'ROOT' THEN n4.id
                        WHEN n5.parent_id = 'ROOT' THEN n5.id
                    END
            ) AS group_avg,
            STDDEV_POP(o.nilai_order) OVER (
                PARTITION BY 
                    CASE
                        WHEN n.parent_id = 'ROOT' THEN n.id
                        WHEN n1.parent_id = 'ROOT' THEN n1.id
                        WHEN n2.parent_id = 'ROOT' THEN n2.id
                        WHEN n3.parent_id = 'ROOT' THEN n3.id
                        WHEN n4.parent_id = 'ROOT' THEN n4.id
                        WHEN n5.parent_id = 'ROOT' THEN n5.id
                    END
            ) AS group_std,
            o.nilai_order - AVG(o.nilai_order) OVER (
                PARTITION BY 
                    CASE
                        WHEN n.parent_id = 'ROOT' THEN n.id
                        WHEN n1.parent_id = 'ROOT' THEN n1.id
                        WHEN n2.parent_id = 'ROOT' THEN n2.id
                        WHEN n3.parent_id = 'ROOT' THEN n3.id
                        WHEN n4.parent_id = 'ROOT' THEN n4.id
                        WHEN n5.parent_id = 'ROOT' THEN n5.id
                    END
            ) AS jarak_average,
            (o.nilai_order - AVG(o.nilai_order) OVER (
                PARTITION BY 
                    CASE
                        WHEN n.parent_id = 'ROOT' THEN n.id
                        WHEN n1.parent_id = 'ROOT' THEN n1.id
                        WHEN n2.parent_id = 'ROOT' THEN n2.id
                        WHEN n3.parent_id = 'ROOT' THEN n3.id
                        WHEN n4.parent_id = 'ROOT' THEN n4.id
                        WHEN n5.parent_id = 'ROOT' THEN n5.id
                    END
            )) / NULLIF(STDDEV_POP(o.nilai_order) OVER (
                PARTITION BY 
                    CASE
                        WHEN n.parent_id = 'ROOT' THEN n.id
                        WHEN n1.parent_id = 'ROOT' THEN n1.id
                        WHEN n2.parent_id = 'ROOT' THEN n2.id
                        WHEN n3.parent_id = 'ROOT' THEN n3.id
                        WHEN n4.parent_id = 'ROOT' THEN n4.id
                        WHEN n5.parent_id = 'ROOT' THEN n5.id
                    END
            ), 0) AS z_score
        FROM orders o
        JOIN nodes n ON o.node_id = n.id
        LEFT JOIN nodes n1 ON n.parent_id = n1.id
        LEFT JOIN nodes n2 ON n1.parent_id = n2.id
        LEFT JOIN nodes n3 ON n2.parent_id = n3.id
        LEFT JOIN nodes n4 ON n3.parent_id = n4.id
        LEFT JOIN nodes n5 ON n4.parent_id = n5.id
    ) t2
    WHERE STDDEV_POP(t2.nilai_order) OVER (PARTITION BY t2.level2_manager) > 0
      AND (t2.z_score > 3 OR t2.z_score < -3)
) final_result

ORDER BY sort_group DESC, sort_priority ASC, id ASC;
