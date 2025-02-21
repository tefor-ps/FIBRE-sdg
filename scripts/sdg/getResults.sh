#!/bin/bash

for d in $(seq 1 3); do 
	mkdir -pv /DATA/sandbox/C$d; 
	cd /DATA/sandbox/C$d; 
	for i in $(find /DATA/theo/labdata/projects/TA-220-DR/ -name "*C${d}*nrr.nii.gz"); do 
		sudo ln -v $i .
	done
done

tree /DATA/sandbox/C*