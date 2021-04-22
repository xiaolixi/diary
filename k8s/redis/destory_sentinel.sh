#!/bin/bash
### 销毁redis sentinel
docker rm -vf \
sentinel_26381 \
sentinel_26380 \
sentinel_26379 \
master_16381 \
master_16380 \
master_16379

rm -rf redis_16379 \
redis_16380 \
redis_16381 \
sentinel_26379 \
sentinel_26380 \
sentinel_26381 
