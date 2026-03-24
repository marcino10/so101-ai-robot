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

        if [ ! -s "$model_list_file" ]; then
            echo "No saved model names found."
            exit 1
        fi

        read -r -p "Enter repo ID: " repoName

        echo "Saved model names:"
        nl -w2 -s') ' "$model_list_file"
        read -r -p "Choose model number: " modelNumber

        modelName=$(sed -n "${modelNumber}p" "$model_list_file")

        if [ -z "$modelName" ]; then
            echo "Invalid model selection."
            exit 1
        fi

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
            --policy.path="/home/user/lerobot/outputs/train/act_so101_$modelName/checkpoints/090000/pretrained_model" \
        ;;

    4)
        echo "Starting TRAIN..."

        if [ ! -s "$repo_list_file" ]; then
            echo "No saved repo IDs found."
            exit 1
        fi

        echo "Saved repo IDs:"
        nl -w2 -s') ' "$repo_list_file"
        read -r -p "Choose repo number: " repoNumber

        selectedRepoId=$(sed -n "${repoNumber}p" "$repo_list_file")

        if [ -z "$selectedRepoId" ]; then
            echo "Invalid repo selection."
            exit 1
        fi

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