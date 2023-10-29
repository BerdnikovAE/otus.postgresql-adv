# ДЗ 04. Тюнинг Постгреса

``` sql 
-- делаем Yandex VM как в ДЗ 02
-- ставим 15 postgresql

-- запускаем тест несколько раз (для каждого конфига) 
sudo -u postgres pgbench -i postgres
sudo -u postgres  pgbench -c 8 -P 30 -T 120 -U postgres postgres
systemctl restart postgresql

-- #1. тестируем с настройками по дефолту
tps = 481.710114 (without initial connection time)

-- #2. настройка https://pgconfigurator.cybertec.at/
sudo touch /var/lib/postgresql/15/main/postgresql.auto.conf
cat << EOF | sudo tee /var/lib/postgresql/15/main/postgresql.auto.conf
# DISCLAIMER - Software and the resulting config files are provided AS IS - IN NO EVENT SHALL
# BE THE CREATOR LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
# DAMAGES, INCLUDING LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION.

# Connectivity
max_connections = 100
superuser_reserved_connections = 3

# Memory Settings
shared_buffers = '512 MB'
work_mem = '32 MB'
maintenance_work_mem = '320 MB'
huge_pages = off
effective_cache_size = '1 GB'
effective_io_concurrency = 100 # concurrent IO only really activated if OS supports posix_fadvise function
random_page_cost = 1.25 # speed of random disk access relative to sequential access (1.0)

# Monitoring
shared_preload_libraries = 'pg_stat_statements'    # per statement resource usage stats
track_io_timing=on        # measure exact block IO times
track_functions=pl        # track execution times of pl-language procedures if any

# Replication
wal_level = replica		# consider using at least 'replica'
max_wal_senders = 0
synchronous_commit = on

# Checkpointing: 
checkpoint_timeout  = '15 min' 
checkpoint_completion_target = 0.9
max_wal_size = '1024 MB'
min_wal_size = '512 MB'


# WAL writing
wal_compression = on
wal_buffers = -1    # auto-tuned by Postgres till maximum of segment size (16MB by default)
wal_writer_delay = 200ms
wal_writer_flush_after = 1MB


# Background writer
bgwriter_delay = 200ms
bgwriter_lru_maxpages = 100
bgwriter_lru_multiplier = 2.0
bgwriter_flush_after = 0

# Parallel queries: 
max_worker_processes = 8
max_parallel_workers_per_gather = 4
max_parallel_maintenance_workers = 4
max_parallel_workers = 8
parallel_leader_participation = on

# Advanced features 
enable_partitionwise_join = on 
enable_partitionwise_aggregate = on
jit = on
max_slot_wal_keep_size = '1000 MB'
track_wal_io_timing = on
maintenance_io_concurrency = 100
wal_recycle = on


# General notes:
# Note that not all settings are automatically tuned.
#   Consider contacting experts at 
#   https://www.cybertec-postgresql.com 
#   for more professional expertise.
EOF

tps = 485.965239 (without initial connection time)
-- не сильно лучше


-- #3. включим асинхронный режим
cat << EOF >> /var/lib/postgresql/15/main/postgresql.auto.conf
synchronous_commit = off
EOF

tps = 3098.876218 (without initial connection time)
-- ожидаемо хорошо

