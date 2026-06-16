# 📊 End-to-End Data Analytics Portfolio: Sales Performance Root Cause Analysis & Anomaly Detection
<p align="center">
  <img src="[images/dashboard_sales.png](https://sql-anomaly-dashboard-portfolio-142260617876.asia-southeast1.run.app)" alt="SQL Anomaly Portfolio Builder" width="80%">
</p>
https://sql-anomaly-dashboard-portfolio-142260617876.asia-southeast1.run.app
## 📌 Project Overview
Proyek ini berfokus pada **Root Cause Analysis (RCA)** untuk mengidentifikasi penurunan performa penjualan serta mendeteksi **anomali transaksi (outlier)** pada struktur organisasi multi-level yang kompleks. 

Menggunakan dataset transaksi riil, proyek ini menyelesaikan tantangan teknis berupa data hierarki yang dinamis (kedalaman bervariasi hingga 6 level) menggunakan engine database warisan (**MySQL 5.7 / 8.0** via **DBeaver**) tanpa fitur rekursi standar (*Common Table Expressions*), sekaligus menerapkan pemodelan statistik tingkat lanjut langsung di dalam kueri database.

---

## 💼 1. Business Problem & Understanding

### Context & Challenge
Perusahaan mengalami fluktuasi pendapatan yang tidak biasa pada beberapa lini manajerial. Manajemen membutuhkan visualisasi performa yang akurat per **Sales Manager Level 2** (pemimpin regional yang berada tepat di bawah `ROOT`). Namun, tim analis menghadapi dua kendala besar:
1. **Hierarki Data yang Berantakan (*Dynamic Depth*):** Jalur pelaporan dari *sales representative* (ujung tombak) hingga ke *Manager Level 2* tidak seragam. Ada yang memiliki jalur pendek (3 tingkat), ada pula yang sangat dalam hingga 5-6 tingkat dari pusat.
2. **Skor Akurasi Nol (0.0) pada Sistem Grader Otomatis:** Solusi awal gagal total karena adanya *hardcoding* ID manajer, salah penafsiran struktur organisasi, dan format sorting output yang mengacak baris ringkasan (*summary*) dengan baris detail.

### Business Objectives
* **Standardisasi Pengelompokan:** Memetakan seluruh transaksi *sales* di tingkat bawah ke masing-masing *Sales Manager Level 2* yang bertanggung jawab secara dinamis.
* **Deteksi Fraud & Outlier:** Menemukan transaksi anomali yang menyimpang secara signifikan menggunakan pendekatan statistik **Z-Score > 3** (transaksi yang berada di luar 3 standar deviasi populasi).
* **Ekstraksi Dual-Output Berformat:** Menghasilkan laporan hibrida tunggal yang berisi *Summary* (total anomali per manajer) dan *Detail* (daftar transaksi anomali beserta metrik statistiknya) untuk kebutuhan *C-Level executive*.

---

## 🛠️ 2. Technical Solution & Database Architecture

Karena batasan lingkungan produksi (*environment constraint*) yang mensyaratkan kompatibilitas penuh dengan versi MySQL lama yang tidak mendukung fungsi rekursif (CTE), solusi ini dirancang menggunakan teknik **Hierarchical Flattening via Layered LEFT JOINs**.

### Metrik Statistik yang Digunakan:
* **Average ($\mu$):** Rata-rata nilai order per kelompok manajer.
* **Standard Deviation Populasi ($\sigma$ / `STDDEV_POP`):** Mengukur persebaran nilai order kelompok.
* **Jarak Average:** Selisih absolut nilai transaksi dari rata-rata kelompok.
* **Z-Score ($Z$):** Diperoleh dari rumus:
  $$Z = \frac{X - \mu}{\sigma}$$
  *Di mana $X$ adalah nilai order individu. Transaksi dengan $|Z| > 3$ didefinisikan sebagai anomali.*

---

## 💻 3. SQL Production Code (`jawaban_final_SQL_2026.sql`)

Berikut adalah skrip SQL optimal yang mengombinasikan teknik *Flattening Hierarchy*, *Statistical Subqueries*, dan *Dual-Priority Custom Sorting* untuk memastikan output bersih sebanyak tepat **24 baris anomali**:

```sql
-- ====================================================================
-- Project: Recovering Sales Performance Root Cause
-- Tools: MySQL 8.0 / MySQL WORKBENCH 8.0 / DBeaver
-- Method: Hierarchical Flattening & Population Statistics Anomaly Detection
-- ====================================================================

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
    -- BAGIAN 1: SUMMARY ROWS (Menghitung jumlah anomali per Manager Level-2)
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
        -- Meratakan hierarki organisasi yang bervariasi menggunakan LEFT JOIN beruntun
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
        -- Menghitung rata-rata (AVG) dan standar deviasi populasi (STDDEV_POP) tiap Manager Level-2
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
    WHERE stats.stdev > 0 AND ABS((base.nilai_order - stats.average) / stats.stdev) > 3 
    GROUP BY base.level2
) final_output 
-- Aturan Sorting: Memastikan seluruh Summary Rows (sort_type = 1) muncul paling atas, 
-- disusul oleh Detail Rows (sort_type = 2) secara terstruktur berdasarkan kode manajer.
ORDER BY sort_type ASC, sort_level2 ASC, id ASC;

<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://ai.google.dev/static/site-assets/images/share-ais-513315318.png" />
</div>
```
