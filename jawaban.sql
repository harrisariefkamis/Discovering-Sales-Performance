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
    -- BAGIAN 1: SUMMARY (Menghitung jumlah anomali per Manager Level 2)
    -- ====================================================================
    SELECT 
        CAST(mgr.id AS CHAR) AS level2,
        CAST(COUNT(outlier_pool.no_urut) AS SIGNED) AS jumlah_anomali,
        NULL AS id,
        NULL AS nilai_order,
        NULL AS average,
        NULL AS stdev,
        NULL AS jarak_average,
        NULL AS z_score,
        mgr.id AS sort_group,
        1 AS sort_priority
    FROM nodes mgr
    LEFT JOIN nodes sales ON sales.parent_id = mgr.id
    LEFT JOIN (
        -- Subquery inline untuk menyaring transaksi outlier (Menggunakan no_urut)
        SELECT main_o.no_urut, main_o.node_id
        FROM orders main_o
        JOIN nodes s_src ON main_o.node_id = s_src.id
        JOIN (
            -- Subquery statistik kelompok (Average & Standard Deviation)
            SELECT 
                m.id AS group_mgr,
                AVG(o_stat.nilai_order) AS group_avg,
                STDDEV_POP(o_stat.nilai_order) AS group_std
            FROM nodes s_stat
            JOIN nodes m ON s_stat.parent_id = m.id
            JOIN orders o_stat ON s_stat.id = o_stat.node_id
            WHERE m.parent_id = 'N0548'
            GROUP BY m.id
        ) stats ON s_src.parent_id = stats.group_mgr
        WHERE stats.group_std > 0 
          AND (
            (main_o.nilai_order - stats.group_avg) / stats.group_std > 3 
            OR 
            (main_o.nilai_order - stats.group_avg) / stats.group_std < -3
          )
    ) outlier_pool ON sales.id = outlier_pool.node_id
    WHERE mgr.parent_id = 'N0548'
    GROUP BY mgr.id

    UNION ALL

    -- ====================================================================
    -- BAGIAN 2: DETAIL (Menampilkan rincian data transaksi sales outlier)
    -- ====================================================================
    SELECT 
        NULL AS level2,
        NULL AS jumlah_anomali,
        CAST(o.node_id AS CHAR) AS id,
        CAST(o.nilai_order AS DOUBLE) AS nilai_order,
        CAST(stats.group_avg AS DOUBLE) AS average,
        CAST(stats.group_std AS DOUBLE) AS stdev,
        CAST((o.nilai_order - stats.group_avg) AS DOUBLE) AS jarak_average,
        CAST(((o.nilai_order - stats.group_avg) / stats.group_std) AS DOUBLE) AS z_score,
        mgr.id AS sort_group,
        2 AS sort_priority
    FROM orders o
    JOIN nodes sales ON o.node_id = sales.id
    JOIN nodes mgr ON sales.parent_id = mgr.id
    JOIN (
        -- Duplikasi subquery statistik kelompok agar sinkron dengan Bagian 1
        SELECT 
            m.id AS group_mgr,
            AVG(o_stat.nilai_order) AS group_avg,
            STDDEV_POP(o_stat.nilai_order) AS group_std
        FROM nodes s_stat
        JOIN nodes m ON s_stat.parent_id = m.id
        JOIN orders o_stat ON s_stat.id = o_stat.node_id
        WHERE m.parent_id = 'N0548'
        GROUP BY m.id
    ) stats ON mgr.id = stats.group_mgr
    WHERE mgr.parent_id = 'N0548'
      AND stats.group_std > 0 
      AND (
        ((o.nilai_order - stats.group_avg) / stats.group_std) > 3 
        OR 
        ((o.nilai_order - stats.group_avg) / stats.group_std) < -3
      )
) final_data

-- Pengurutan dilakukan di luar wrapper menggunakan kolom bayangan, 
-- sehingga susunan Summary dan Detail terjamin rapi tanpa merusak output target 8 kolom.
ORDER BY sort_group DESC, sort_priority ASC, id ASC;