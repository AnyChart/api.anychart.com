#/bin/sh
cd ../ && rm -rf log.txt && genadoc convert ACDVF/src/ ACDVF-api-reference/ >> log.txt && genadoc convert ACDVF/contrib/graphics/src/ ACDVF-api-reference/graphics >> log.txt && cd ACDVF-api-reference

