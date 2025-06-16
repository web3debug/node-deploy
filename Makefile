#!/usr/bin/make -f

geth:
	cp ../bsc/build/bin/geth ./bin/geth

clear:
	rm -rf ./.local ./genesis ./keys && mkdir ./genesis
	git submodule update --init --recursive
	git submodule update --remote --recursive
	cd genesis && git reset --hard 48bd0dba87c45bebd73de3349597697bc921ceb2

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