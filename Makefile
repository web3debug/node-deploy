#!/usr/bin/make -f

geth:
	cp ../bsc/build/bin/geth ./bin/geth

clear:
	rm -rf ./.local ./genesis ./keys && mkdir ./genesis
	git submodule update --init --recursive
	git submodule update --remote --recursive
	cd genesis && git reset --hard 64b0efdd66afeaa34591d5483c4b8b9979f7b8f7

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