#!/bin/bash

# Создать и подложить в директорию наблюдения файл с фейковыми "данными от спутника"
OBS_ID=1248702 && mkdir -p /tmp/.soniks/output/${OBS_ID} && echo 'some first data' > /tmp/.soniks/output/${OBS_ID}/data_${OBS_ID}_$(date -u -d "+3 minutes" +"%Y-%m-%dT%H-%M-%S").dat
