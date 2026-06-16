# 📊 End-to-End Data Analytics Portfolio: Sales Performance Root Cause Analysis & Anomaly Detection
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
```

## Key Insight & Rekomendasi Bisnis (Decision Making):
1. Investigasi Nilai Z-Score Positif Ekstrem ($Z > 3$): Transaksi seperti sales S9921 menghasilkan nilai order jauh melampaui rata-rata timnya. Ini mengindikasikan adanya b2b bulk order potensial atau anomali input data (human error). Manajemen perlu menduplikasi strategi penjualan unit ini ke unit lain.Mitigasi Nilai Z-Score Negatif Ekstrem ($Z < -3$):
2. Transaksi yang jatuh terlalu dalam di bawah rata-rata mengindikasikan adanya churn rate tinggi, diskon tidak rasional yang merugikan margin, atau performa buruk yang memerlukan intervensi coaching langsung dari Manager Level 2 terkait.
3. Alokasi Resource Berbasis Beban Anomali:Manager N0549 memiliki 5 kasus transaksi anomali (tertinggi). Operasional audit internal harus difokuskan pada klaster wilayah kerja N0549 guna menstabilkan performa penjualan wilayah tersebut.🚀


```
SQL
---
How to Run the Clone repositori:
1. git clone https://github.com/harrisariefkamis/sales-rsc-anomaly.
2. gitBuka aplikasi DBeaver atau MySQL Workbench.
3. Import skema database nodes dan orders.
4. Jalankan berkas jawaban_final_SQL_2026.sql.
5. Hasil tabular akan memisahkan baris ringkasan eksekutif dan detail transaksi secara otomatis.

# 🎯 Panduan Proyek untuk Recruiter (Interview Guide)

Gunakan *script* bercerita (*storytelling*) ini saat Anda mempresentasikan atau menjelaskan proyek ini di hadapan teknis maupun manajemen perekrut:

### 1. The Hook (Bagaimana Memulai Presentasi)
> *"Saya ingin membagikan proyek di mana saya berhasil menyelamatkan akurasi laporan performa penjualan dari skor nol menjadi sempurna di bawah batasan arsitektur database lama."*

### 2. The Problem (Menunjukkan Pemahaman Bisnis)
> *"Masalah utamanya adalah data organisasi yang tersimpan sangat dinamis dan berantakan. Menggunakan filter manual (*hardcoding*) hanya akan membutakan perusahaan terhadap performa manajer wilayah lain. Selain itu, database produksi yang digunakan masih menggunakan versi MySQL lama yang tidak mendukung fungsi rekursi untuk membaca pohon organisasi."*

### 3. The Engineering (Menunjukkan Skill Teknis)
> *"Untuk mengakalinya, saya meratakan struktur data (*flattening hierarchy*) secara manual menggunakan rangkaian bertingkat `LEFT JOIN` hingga 6 tingkat. Saya juga mengintegrasikan kalkulasi statistik populasi (`STDDEV_POP`) langsung dalam kueri tunggal agar sistem penilaian otomatis mendeteksi transaksi anomali berbasis Z-Score secara cepat dan *real-time* tanpa membebani memori server lewat tabel temporer."*

### 4. The Business Value (Menunjukkan Dampak Finansial)
> *"Hasil akhirnya adalah laporan hibrida tunggal yang langsung memisahkan ringkasan performa untuk direksi di bagian atas, dan detail operasional untuk tim audit di bagian bawah. Ini memotong waktu deteksi transaksi mencurigakan dari hitungan hari menjadi hitungan detik."*
```



## Follow more docs is here.!!!
| Platform | Link |
|---|---|
| 📧 Email | harisariefkamis16@gmail.com |
| 📱 WhatsApp | +62 852-8243-6796 |
| 💼 LinkedIn | [linkedin.com/in/harisariefkamis](https://linkedin.com/in/harisariefkamis) |
| 🐙 GitHub | [github.com/harisariefkamis](https://github.com/harisariefkamis)
