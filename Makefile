#!/usr/bin/make -f

geth:
	cp ../bsc/build/bin/geth ./bin/geth

clear:
	rm -rf ./.local ./genesis && mkdir ./genesis

reset:
	bash -x ./bsc_cluster.sh reset

start:
	bash -x ./bsc_cluster.sh start

stop:
	bash -x ./bsc_cluster.sh stop