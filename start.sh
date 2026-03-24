#!/bin/bash

cd /home/user/lerobot || exit 1

width=640
height=480
fps=30
format="MJPG"

frontPath="/dev/video4"
topPath="/dev/video0"
sidePath="/dev/video2" 

followerType="so101_follower"
followerPort="/dev/ttyACM0"
followerId="my_awesome_follower_arm"

leaderType="so101_leader"
leaderPort="/dev/ttyACM1"
leaderId="my_awesome_leader_arm"

repo_list_file="/home/user/lerobot/repo_ids.txt"
model_list_file="/home/user/lerobot/model_names.txt"

camerasConfig="{ front: {type: opencv, index_or_path: \"$frontPath\", width: $width, height: $height, fps: $fps, fourcc: \"$format\"}, top: {type: opencv, index_or_path: \"$topPath\", width: $width, height: $height, fps: $fps, fourcc: \"$format\"}, side: {type: opencv, index_or_path: \"$sidePath\", width: $width, height: $height, fps: $fps, fourcc: \"$format\"} }"
camerasConfig2="{ front: {type: opencv, index_or_path: '$frontPath', width: $width, height: $height, fps: $fps, fourcc: '$format'}, top: {type: opencv, index_or_path: '$topPath', width: $width, height: $height, fps: $fps, fourcc: '$format'} }"

echo $camerasConfig2 >> test.txt

touch "$repo_list_file"
touch "$model_list_file"

sudo chmod 666 /dev/ttyACM*

echo "Choose an option:"
echo "1) operate"
echo "2) record"
echo "3) validate"
echo "4) train"

read -r -p "Enter number: " option

case $option in
    1)
        echo "Starting OPERATE..."

        lerobot-teleoperate \
            --robot.type="$followerType" \
            --robot.port="$followerPort" \
            --robot.id="$followerId" \
            --robot.cameras="$camerasConfig" \
            --teleop.type="$leaderType" \
            --teleop.port="$leaderPort" \
            --teleop.id="$leaderId" \
            --display_data=true
        ;;

    2)
        echo "Starting RECORD..."

        read -r -p "Enter repo ID: " repoName
        repoId="train/$repoName"

        read -r -p "Enter number of episodes [1]: " numEpisodes
        numEpisodes=${numEpisodes:-1}

        read -r -p "Enter episode time in seconds [15]: " episodeTime
        episodeTime=${episodeTime:-15}

        read -r -p "Enter reset time in seconds [5]: " resetTime
        resetTime=${resetTime:-5}

        if ! grep -Fxq "$repoId" "$repo_list_file"; then
            echo "$repoId" >> "$repo_list_file"
        fi

        lerobot-record \
            --robot.type="$followerType" \
            --robot.port="$followerPort" \
            --robot.id="$followerId" \
            --robot.cameras="$camerasConfig" \
            --teleop.type="$leaderType" \
            --teleop.port="$leaderPort" \
            --teleop.id="$leaderId" \
            --display_data=true \
            --dataset.repo_id="$repoId" \
            --dataset.num_episodes="$numEpisodes" \
            --dataset.episode_time_s="$episodeTime" \
            --dataset.reset_time_s="$resetTime" \
            --dataset.single_task="Grab The Cube" \
            --dataset.push_to_hub=false
        ;;

    3)
        echo "Starting VALIDATE..."

        models_dir="/home/user/lerobot/outputs/train"
        if [ ! -d "$models_dir" ]; then
            echo "No saved models found in $models_dir."
            exit 1
        fi

        models=()
        for dir in "$models_dir"/*; do
            if [ -d "$dir" ]; then
                models+=("$(basename "$dir")")
            fi
        done

        if [ ${#models[@]} -eq 0 ]; then
            echo "No saved models found in $models_dir."
            exit 1
        fi

        read -r -p "Enter repo ID: " repoName

        echo "Saved models:"
        for i in "${!models[@]}"; do
            echo "$((i+1))) ${models[$i]}"
        done

        read -r -p "Choose model number: " modelNumber

        if ! [[ "$modelNumber" =~ ^[0-9]+$ ]] || [ "$modelNumber" -lt 1 ] || [ "$modelNumber" -gt "${#models[@]}" ]; then
            echo "Invalid model selection."
            exit 1
        fi

        modelName="${models[$((modelNumber-1))]}"

        read -r -p "Enter number of episodes for validation [1]: " numEpisodes
        numEpisodes=${numEpisodes:-1}

        repoShortName="${selectedRepoId#train/}"

        lerobot-record \
            --robot.type="$followerType" \
            --robot.port="$followerPort" \
            --robot.id="$followerId" \
            --robot.cameras="$camerasConfig" \
            --teleop.type="$leaderType" \
            --teleop.port="$leaderPort" \
            --teleop.id="$leaderId" \
            --display_data=true \
            --dataset.repo_id="seed/eval_$repoName" \
            --dataset.num_episodes="$numEpisodes" \
            --dataset.single_task="Grab The Cube" \
            --dataset.push_to_hub=false \
            --policy.path="/home/user/lerobot/outputs/train/$modelName/checkpoints/last/pretrained_model"
        ;;

    4)
        echo "Starting TRAIN..."

        cache_dir="/home/user/.cache/huggingface/lerobot/train"
        if [ ! -d "$cache_dir" ]; then
            echo "No saved repos found in $cache_dir."
            exit 1
        fi

        repos=()
        for dir in "$cache_dir"/*; do
            if [ -d "$dir" ]; then
                repos+=("$(basename "$dir")")
            fi
        done

        if [ ${#repos[@]} -eq 0 ]; then
            echo "No saved repos found in $cache_dir."
            exit 1
        fi

        echo "Saved repos:"
        for i in "${!repos[@]}"; do
            echo "$((i+1))) train/${repos[$i]}"
        done

        read -r -p "Choose repo number: " repoNumber

        if ! [[ "$repoNumber" =~ ^[0-9]+$ ]] || [ "$repoNumber" -lt 1 ] || [ "$repoNumber" -gt "${#repos[@]}" ]; then
            echo "Invalid repo selection."
            exit 1
        fi

        selectedRepoId="train/${repos[$((repoNumber-1))]}"

        read -r -p "Enter model name: " modelName

        if [ -z "$modelName" ]; then
            echo "Model name cannot be empty."
            exit 1
        fi

        read -r -p "Enter number of training steps [30000]: " steps
        steps=${steps:-30000}

        if ! grep -Fxq "$modelName" "$model_list_file"; then
            echo "$modelName" >> "$model_list_file"
        fi

        echo "Selected repo: $selectedRepoId"
        echo "Model name: $modelName"
        echo "Steps: $steps"

        lerobot-train \
            --dataset.repo_id="$selectedRepoId" \
            --policy.type=act \
            --output_dir="outputs/train/act_so101_$modelName" \
            --job_name="act_so101_$modelName" \
            --policy.device=cuda \
            --wandb.enable=false \
            --policy.push_to_hub=false \
            --steps="$steps"
        ;;

    *)
        echo "Invalid option!"
        exit 1
        ;;
esac