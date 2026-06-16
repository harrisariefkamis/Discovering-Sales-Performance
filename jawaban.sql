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
    -- BAGIAN 1: SUMMARY ROWS 
    -- Menghitung jumlah anomali per Manager Level 2
    -- ====================================================================
    SELECT 
        base.level2 AS level2,
        COUNT(*) AS jumlah_anomali,
        NULL AS id,
        NULL AS nilai_order,
        NULL AS average,
        NULL AS stdev,
        NULL AS jarak_average,
        NULL AS z_score,
        1 AS sort_type,
        base.level2 AS sort_level2
    FROM (
        -- Meratakan hierarki menggunakan LEFT JOIN beruntun
        SELECT 
            o.no_urut,
            o.node_id,
            o.nilai_order,
            COALESCE(
                CASE WHEN n1.parent_id = 'ROOT' THEN n1.id END,
                CASE WHEN n2.parent_id = 'ROOT' THEN n2.id END,
                CASE WHEN n3.parent_id = 'ROOT' THEN n3.id END,
                CASE WHEN n4.parent_id = 'ROOT' THEN n4.id END,
                CASE WHEN n5.parent_id = 'ROOT' THEN n5.id END,
                CASE WHEN n6.parent_id = 'ROOT' THEN n6.id END
            ) AS level2
        FROM orders o
        JOIN nodes n1 ON o.node_id = n1.id
        LEFT JOIN nodes n2 ON n1.parent_id = n2.id
        LEFT JOIN nodes n3 ON n2.parent_id = n3.id
        LEFT JOIN nodes n4 ON n3.parent_id = n4.id
        LEFT JOIN nodes n5 ON n4.parent_id = n5.id
        LEFT JOIN nodes n6 ON n5.parent_id = n6.id
    ) base
    JOIN (
        -- Menghitung rata-rata dan stddev populasi untuk tiap Manager L2
        SELECT 
            level2,
            AVG(nilai_order) AS average,
            STDDEV_POP(nilai_order) AS stdev
        FROM (
            SELECT 
                o.nilai_order,
                COALESCE(
                    CASE WHEN n1.parent_id = 'ROOT' THEN n1.id END,
                    CASE WHEN n2.parent_id = 'ROOT' THEN n2.id END,
                    CASE WHEN n3.parent_id = 'ROOT' THEN n3.id END,
                    CASE WHEN n4.parent_id = 'ROOT' THEN n4.id END,
                    CASE WHEN n5.parent_id = 'ROOT' THEN n5.id END,
                    CASE WHEN n6.parent_id = 'ROOT' THEN n6.id END
                ) AS level2
            FROM orders o
            JOIN nodes n1 ON o.node_id = n1.id
            LEFT JOIN nodes n2 ON n1.parent_id = n2.id
            LEFT JOIN nodes n3 ON n2.parent_id = n3.id
            LEFT JOIN nodes n4 ON n3.parent_id = n4.id
            LEFT JOIN nodes n5 ON n4.parent_id = n5.id
            LEFT JOIN nodes n6 ON n5.parent_id = n6.id
        ) t_stat
        GROUP BY level2
    ) stats ON base.level2 = stats.level2
    WHERE stats.stdev > 0 
      AND ABS((base.nilai_order - stats.average) / stats.stdev) > 3
    GROUP BY base.level2

    UNION ALL

    -- ====================================================================
    -- BAGIAN 2: DETAIL ROWS 
    -- Menampilkan rincian data transaksi outlier
    -- ====================================================================
    SELECT 
        NULL AS level2,
        NULL AS jumlah_anomali,
        base.node_id AS id,
        base.nilai_order AS nilai_order,
        stats.average AS average,
        stats.stdev AS stdev,
        (base.nilai_order - stats.average) AS jarak_average,
        ((base.nilai_order - stats.average) / stats.stdev) AS z_score,
        2 AS sort_type,
        base.level2 AS sort_level2
    FROM (
        SELECT 
            o.no_urut,
            o.node_id,
            o.nilai_order,
            COALESCE(
                CASE WHEN n1.parent_id = 'ROOT' THEN n1.id END,
                CASE WHEN n2.parent_id = 'ROOT' THEN n2.id END,
                CASE WHEN n3.parent_id = 'ROOT' THEN n3.id END,
                CASE WHEN n4.parent_id = 'ROOT' THEN n4.id END,
                CASE WHEN n5.parent_id = 'ROOT' THEN n5.id END,
                CASE WHEN n6.parent_id = 'ROOT' THEN n6.id END
            ) AS level2
        FROM orders o
        JOIN nodes n1 ON o.node_id = n1.id
        LEFT JOIN nodes n2 ON n1.parent_id = n2.id
        LEFT JOIN nodes n3 ON n2.parent_id = n3.id
        LEFT JOIN nodes n4 ON n3.parent_id = n4.id
        LEFT JOIN nodes n5 ON n4.parent_id = n5.id
        LEFT JOIN nodes n6 ON n5.parent_id = n6.id
    ) base
    JOIN (
        SELECT 
            level2,
            AVG(nilai_order) AS average,
            STDDEV_POP(nilai_order) AS stdev
        FROM (
            SELECT 
                o.nilai_order,
                COALESCE(
                    CASE WHEN n1.parent_id = 'ROOT' THEN n1.id END,
                    CASE WHEN n2.parent_id = 'ROOT' THEN n2.id END,
                    CASE WHEN n3.parent_id = 'ROOT' THEN n3.id END,
                    CASE WHEN n4.parent_id = 'ROOT' THEN n4.id END,
                    CASE WHEN n5.parent_id = 'ROOT' THEN n5.id END,
                    CASE WHEN n6.parent_id = 'ROOT' THEN n6.id END
                ) AS level2
            FROM orders o
            JOIN nodes n1 ON o.node_id = n1.id
            LEFT JOIN nodes n2 ON n1.parent_id = n2.id
            LEFT JOIN nodes n3 ON n2.parent_id = n3.id
            LEFT JOIN nodes n4 ON n3.parent_id = n4.id
            LEFT JOIN nodes n5 ON n4.parent_id = n5.id
            LEFT JOIN nodes n6 ON n5.parent_id = n6.id
        ) t_stat
        GROUP BY level2
    ) stats ON base.level2 = stats.level2
    WHERE stats.stdev > 0 
      AND ABS((base.nilai_order - stats.average) / stats.stdev) > 3
) final_output

-- Sortir berdasarkan jenis baris (1=summary, 2=detail) untuk memastikan 
-- summary teratas, diikuti detail per manager.
ORDER BY sort_type ASC, sort_level2 ASC, id ASC;