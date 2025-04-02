#!/usr/bin/make -f

geth:
	cp ../bsc/build/bin/geth ./bin/geth

clear:
	rm -rf ./.local ./genesis ./keys && mkdir ./genesis
	git submodule update --init --recursive
	git submodule update --remote --recursive
	cd genesis && git reset --hard 70c6c5a5c8d7a06f968a7635d54687c4311c76e0

reset:
	bash -x ./bsc_cluster.sh reset

start:
	bash -x ./bsc_cluster.sh start

restart:
	bash -x ./bsc_cluster.sh restart

stop:
	bash -x ./bsc_cluster.sh stop

format:
	shfmt -l -w -i 4 ./bsc_cluster.sh