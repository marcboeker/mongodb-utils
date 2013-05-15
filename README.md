# MongoDB utils

These small scripts helped me to start a development sharding cluster and run some benchmarks on it.

The following utils are includes:

- **mongosharding**: Set up a sharded cluster (with replica sets) within seconds. All configurable via the script
- **fill_shard**: Small script to run a continuous insert loop. Good to test balancing and chunk migration
- **dashboard**: Ugly but helpfull web UI to dive deeper into your sharded cluster
- **benchmarks/insert.(rb|py)**: Insert 10000 documents with 500kb size each
