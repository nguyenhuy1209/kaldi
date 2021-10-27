#!/usr/bin/env bash

# Copyright 2019 National Institute of Informatics (Hieu-Thi Luong)
#  Apache 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

. ./path.sh || exit 1;
# . ./cmd.sh || exit 1;

# general configuration
stage=1           # start from 1 to download VIVOS corpus
stop_stage=10
use_noise_aug=true

# data
datadir=./data
vivos_root=${datadir}/vivos
vivos_aug=${datadir}/vivos_aug
noise_path=noise/xe34.wav
data_url=https://ailab.hcmus.edu.vn/assets/vivos.tar.gz

# Speed perturbation related
# speed_perturb_factors="0.9 1.0 1.1"  # perturbation factors, e.g. "0.9 1.0 1.1" (separated by space).

# exp tag
tag=""

. utils/parse_options.sh || exit 1;

set -e
set -u
set -o pipefail

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    echo "stage 1: Data download"

    mkdir -p ${datadir}
    local/download_and_untar.sh ${datadir} ${data_url}
fi

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    echo "stage 2: Noise augumentation"

    if [ ${use_noise_aug} == true ]; then 
        if [ -d $vivos_aug ]; then
            echo "$0: noise augumentation directory already exists in $vivos_aug"
        else
            for x in test train; do
                python3 local/add_noise.py                    \
                    --audio_folder_path ${vivos_root}/$x       \
                    --noise_path ${noise_path}          \
                    --output_folder_path ${vivos_aug}/$x       \
                    --alpha 0.9
            done
        fi
    else
        echo "Skipping noise augumentation..."
    fi
fi

if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    echo "stage 3: Data preparation"

    mkdir -p data/{train,test} exp

    if [ ! -f ${vivos_root}/README ]; then
        echo "Cannot find vivos root! Exiting..."
        exit 1;
    fi
    
    for x in test train; do
        if [ ${use_noise_aug} == true ]; then
            awk -v dir=${vivos_aug}/$x '{ split($1,args,"_"); spk=args[1]; print $1" "dir"/waves/"spk"/"$1".wav" }' ${vivos_root}/$x/prompts.txt | sort > data/$x/wav.scp
        else
            awk -v dir=${vivos_root}/$x '{ split($1,args,"_"); spk=args[1]; print $1" "dir"/waves/"spk"/"$1".wav" }' ${vivos_root}/$x/prompts.txt | sort > data/$x/wav.scp
        fi
        awk '{ split($1,args,"_"); spk=args[1]; print $1" "spk }' ${vivos_root}/$x/prompts.txt | sort > data/$x/utt2spk
        sort ${vivos_root}/$x/prompts.txt > data/$x/text
        utils/utt2spk_to_spk2utt.pl data/$x/utt2spk > data/$x/spk2utt
    done
fi

# if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then
#     if [ -n "${speed_perturb_factors}" ]; then
#         echo "Stage 4: Speed perturbation: ${datadir}/train -> ${datadir}/train_sp"
#         for factor in ${speed_perturb_factors}; do
#             if [[ $(bc <<<"${factor} != 1.0") == 1 ]]; then
#                 utils/perturb_data_dir_speed.sh "${factor}" "${datadir}/train" "${datadir}/train_sp${factor}"
#                 _dirs+="${datadir}/train_sp${factor} "
#             else
#                 # If speed factor is 1, same as the original
#                 _dirs+="${datadir}/train "
#             fi
#         done
#         utils/combine_data.sh "${datadir}/train_sp" ${_dirs}
#     else
#         log "Skip stage 4: Speed perturbation"
#     fi
# fi