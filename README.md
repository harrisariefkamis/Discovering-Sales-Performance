# Discovering-Sales-Performance
________________________________________
PT XYZ, perusahaan distributor makanan kering tengah kebingungan karena kelihatan pemesanannya baik dari purchase order, tapi banyak aktual penjualan mandek. Ini kemungkinan diakibatkan oleh pemesanan yang tidak merata.
Oleh karena itu kita perlu mencari tahu dari banyak hal, untuk kali ini kita akan mencari apakah terdapat anomali berupa outlier dari pemesanan sales lapangan, dimana setiap sales tersebut memiliki manajernya tersendiri. Dan untuk outlier ini kita akan melihat kepada sales manager di tingkat menengah atau tingkat dua.
Anda akan diberi data yang relatif kecil yang merupakan data order dari tiap sales, dan tugas Anda mencari sales outlier ini dengan metode averaging dan standard deviation. 
Outlier dan perhitungannya seluruhnya dilakukan melalui SQL dan pada saat submission, dilampirkan di dalam email nama file script jawaban.sql ke tugastest@ujikompetensi.com dengan subjek email persis sebagai berikut:

Solusi Hackathon untuk soal 'HACK-2026-SQL-01'
Catatan: case ini merupakan simplifikasi dari use case yang sebenarnya, namun teknik yang digunakan akan sangat berguna dan mampu dilakukan oleh perintah SQL dengan produk seperti MySQL 5.
Persiapan: Import Database
Untuk task ini diperlukan script SQL berisi table dan data yang perlu Anda import ke dalam database MySQL 5 Anda.

File script tersebut bernama dqlabsql.sql yang dapat Anda download dari link berikut:

https://drive.google.com/drive/u/0/folders/1MvWEPBmWdl2kyIeIAmtkM7N2LOFwJT2n

 

Penjelasan Tabel Database 
Database yang telah di-restore atau di-import memiliki dua tabel, yaitu nodes dan orders.
Berikut penjelasan dari kedua tabel tersebut:
nodes
Tabel ini menyimpan struktur hierarki organisasi sales. Setiap baris merepresentasikan satu node (sales atau kepala sales) beserta hubungan dengan atasannya.
Kolom	Tipe Data	Keterangan
id	varchar(10)	Kode unik node/sales
parent_id	varchar(10)	Kode atasan langsung dari node tersebut
Contoh data:
id	parent_id
S0001	NULL
S0002	S0001
S0003	S0001
S0004	S0002
Pada contoh di atas:
●	S0001 merupakan root (tidak memiliki atasan).
●	S0002 dan S0003 berada di bawah S0001.
●	S0004 berada di bawah S0002.
Berikut adalah contoh screenshot sebagian data riil yang diberikan untuk tugas kali ini.
 
orders
Tabel ini menyimpan transaksi pemesanan yang dilakukan oleh sales paling bawah (leaf node).
Kolom	Tipe Data	Keterangan
no_urut	int	Nomor urut transaksi
node_id	varchar(20)	Kode sales yang melakukan pemesanan
nilai_order	double	Nilai pemesanan dalam bentuk rupiah
Berikut adalah contoh screenshot sebagian data riil dari table orders yang diberikan untuk tugas kali ini.
 

Task: Temukan Outlier Pemesanan dari Sales
Setiap nilai order yang tercatat memiliki pola distribusi yang berbeda.??? Untuk mengidentifikasi adanya pemesanan yang tidak wajar (outlier), kita perlu melihat seberapa jauh suatu nilai order menyimpang dari pola normal kelompoknya.
Terdapat berbagai pendekatan untuk mendeteksi outlier, seperti menggunakan median dan quantile. Namun, pada kasus ini kita akan menggunakan pendekatan average (rata-rata) dan standard deviation (simpangan baku).
Karena struktur organisasi sales berbentuk hierarki, perhitungan tidak dilakukan secara keseluruhan. Setiap transaksi harus terlebih dahulu dikelompokkan berdasarkan Sales Manager Level 2, yaitu seluruh node yang berada tepat di bawah node ROOT. 
 
Sebagai contoh, apabila dilakukan penelusuran hierarki terhadap sales N0007, akan diperoleh jalur sebagai berikut:
N0007 ← N0505 ← N0517 ← N0528 ← N0548 ← ROOT
Dari jalur tersebut dapat dilihat bahwa node pertama setelah ROOT adalah N0548. Dengan demikian, seluruh transaksi yang dilakukan oleh N0007 termasuk ke dalam kelompok Sales Manager Level 2 dengan ID N0548.
Setelah seluruh transaksi berhasil dipetakan ke kelompok manager level 2 masing-masing, barulah dilakukan perhitungan:
●	Average (rata-rata) nilai order pada kelompok tersebut.
●	Standard deviation nilai order pada kelompok tersebut. Pada kasus ini, gunakan standard deviation populasi (STDDEV_POP) yang tersedia di MySQL. 
●	Hitung Z-score untuk setiap transaksi guna mengukur seberapa jauh nilai order tersebut menyimpang dari rata-rata kelompoknya. 
Suatu transaksi dianggap sebagai outlier apabila nilainya berada di luar rentang:
Average ± 3 × Standard Deviation
atau secara matematis:
●	Nilai order > Average + 3 × Standard Deviation, atau
●	Nilai order < Average − 3 × Standard Deviation.
________________________________________
Task: Tampilan Data Outlier
Query yang dibuat hanya menghasilkan satu output, namun output tabular tersebut memuat dua jenis informasi, yaitu:
1.	Ringkasan (summary) berupa kode manager level 2 beserta jumlah transaksi outlier yang berada di bawahnya.
2.	Detail outlier, yaitu daftar sales yang terdeteksi sebagai outlier beserta informasi statistik yang terkait dengan kelompok manager level 2 tempat sales tersebut berada.
Berikut detail kolom yang ditampilkan dengan tipe dan keterangannya: 
1.	level2 varchar: Kode Sales Manager Level 2. 
2.	jumlah_anomali int: Jumlah transaksi outlier yang berada di bawah manager level 2 tersebut. Bernilai NULL pada baris detail outlier.
3.	id varchar: Kode sales yang terdeteksi sebagai outlier. Bernilai NULL pada baris summary. 
4.	nilai_order double: Nilai order milik sales yang terdeteksi sebagai outlier. Bernilai NULL pada baris summary. 
5.	average double: Nilai rata-rata (average) dari seluruh nilai order yang berada pada kelompok manager level 2 terkait. 
6.	stdev double: Nilai standard deviation populasi (STDDEV_POP) dari seluruh nilai order pada kelompok manager level 2 terkait. 
7.	jarak_average double: Selisih antara nilai order dengan average, yaitu seberapa jauh nilai order outlier tersebut dari nilai rata-rata kelompoknya. 
8.	z_score double: Nilai Z-score dari transaksi outlier, yang menunjukkan seberapa jauh nilai order tersebut menyimpang dari rata-rata dalam satuan standard deviation. Nilai ini dapat bernilai positif maupun negatif. 


level2	jumlah_anomali	id	nilai_order	average	stdev	jarak_average	z_score
N0601	2	NULL	NULL	NULL	NULL	NULL	NULL
N0602	1	NULL	NULL	NULL	NULL	NULL	NULL
N0123	NULL	N0601	7.200.000	4.000.000	800.000	3.200.000	4.00
N0456	NULL	N0601	1.300.000	4.000.000	800.000	-2.700.000	-3.38
N0789	NULL	N0602	8.500.000	5.000.000	900.000	3.500.000	3.89

 
Batasan Spesifik untuk MySQL 5
Perhitungan dan tampilan hasil harus menggunakan query yang dimengerti oleh MySQL 5.7 pada sistem scoring Hackathon ini. 
Beberapa aturan penggunaan script dengan MySQL 5:
●	Tidak bisa menggunakan:
○	window function 
○	CTE (Common Table Expression)
○	recursion 
○	use database di file script
○	perintah untuk menghapus data atau create table baru, kecuali temporary table

●	Contoh beberapa menggunakan konstruksi dan function berikut
○	Create temporary table
○	Pengelompokan dengan GROUP BY dan fungsi agregasi (avg, count, dll)
○	Subquery
○	Join dan union
○	Fungsi statistik (STDDEV_POP, Z-score, dll)
○	Variable
○	Dan lain-lain




