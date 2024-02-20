#!/usr/bin/env bash
# Dev environment settings not defined elsewhere

test -r /usr/local/geoserver && export GEOSERVER_HOME=$_
test -r /usr/local/geoserver_data_dir && export GEOSERVER_DATA_DIR=$_
