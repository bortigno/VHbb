#!/bin/bash

#Input argument:
#sample you want to run on. It has to match the naming in sample.info.
sample=$1
#sqrt(s) you want to run
energy=$2

task=$3

job_id=$4

additional_arg=$5

if [ $# -lt 3 ]
    then
    echo "ERROR: You passed " $# "arguments while the script needs at least 3 arguments."
    echo "Exiting..."
    echo " ---------------------------------- "
    echo " Usage : ./runAll.sh sample energy task"
    echo " ---------------------------------- "
    exit
fi

#Set the environment for the batch job execution

#cd /shome/peller/CMSSW_5_2_4_patch4/src/
# this doesnt work for me..?

cd $CMSSW_BASE/src/
source /swshare/psit3/etc/profile.d/cms_ui_env.sh
export SCRAM_ARCH="slc5_amd64_gcc462"
source $VO_CMS_SW_DIR/cmsset_default.sh
eval `scramv1 runtime -sh`
#export LD_PRELOAD="libglobus_gssapi_gsi_gcc64pthr.so.0":${LD_PRELOAD}
export LD_LIBRARY_PATH=/swshare/glite/globus/lib/:/swshare/glite/d-cache/dcap/lib64/:$LD_LIBRARY_PATH
export LD_PRELOAD="libglobus_gssapi_gsi_gcc64pthr.so.0:${LD_PRELOAD}"
mkdir $TMPDIR

#back to the working dir
cd -

MVAList=`python << EOF 
import os
from myutils import BetterConfigParser
config = BetterConfigParser()
config.read('./${energy}config/training')
print config.get('MVALists','List_for_submitscript')
EOF`

#Run the scripts

if [ $task = "prep" ]; then
    ./prepare_environment_with_config.py -C ${energy}config/samples_nosplit.cfg -C ${energy}config/paths
fi
if [ $task = "sys" ]; then
    ./write_regression_systematics.py -S $sample -C ${energy}config/general -C ${energy}config/paths
fi
if [ $task = "eval" ]; then
    ./evaluateMVA.py -D $MVAList -S $sample -C ${energy}config/general -C ${energy}config/paths -C ${energy}config/cuts -C ${energy}config/training
fi
if [ $task = "syseval" ]; then
    ./write_regression_systematics.py -S $sample -C ${energy}config/general -C ${energy}config/paths
    ./evaluateMVA.py -D $MVAList -S $sample -C ${energy}config/general -C ${energy}config/paths -C ${energy}config/cuts -C ${energy}config/training
fi
if [ $task = "train" ]; then
    ./train.py -T $sample -C ${energy}config/general -C ${energy}config/paths -C ${energy}config/cuts -C ${energy}config/training -L True
fi
if [ $task = "plot" ]; then
    ./tree_stack.py -R $sample -C ${energy}config/general -C ${energy}config/paths -C ${energy}config/cuts -C ${energy}config/plots
fi
if [ $task = "dc" ]; then
    ./workspace_datacard.py -V $sample -C ${energy}config/general -C ${energy}config/paths -C ${energy}config/cuts -C ${energy}config/datacards -C ${energy}config/plots
fi
if [ $task = "split" ]; then
    ./split_tree.py -S $sample -C ${energy}config/general -C ${energy}config/paths -C ${energy}config/cuts -C ${energy}config/training -M $job_id
fi

if [ $task = "mva_opt" ]; then
    if [ $# -lt 5 ]
	then
	echo "@ERROR: You passed " $# "arguments while BDT optimisation needs at least 5 arguments."
	echo "Exiting..."
	echo " ---------------------------------- "
	echo " Usage : ./runAll.sh sample energy task jo_id bdt_factory_settings"
	echo " ---------------------------------- "
	exit
    fi
    echo "BDT factory settings"
    echo $additional_arg
    echo "Runnning"
    ./train.py -N ${sample} -T ${job_id} -C ${energy}config/general -C ${energy}config/paths -C ${energy}config/training -C ${energy}config/cuts -S ${additional_arg} -L False
fi

rm -rf $TMPDIR
