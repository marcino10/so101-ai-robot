from lerobot.teleoperators.so_leader import SO101LeaderConfig, SO101Leader
from lerobot.robots.so_follower import SO101FollowerConfig, SO101Follower
from lerobot.common.robot_devices.cameras.opencv import OpenCVCameraConfig

camera_config = {
    "front": OpenCVCameraConfig(
        index_or_path="/dev/video4", 
        width=640, 
        height=480, 
        fps=30, 
        fourcc="MJPG"
    ),
    "top": OpenCVCameraConfig(
        index_or_path="/dev/video0", 
        width=640, 
        height=480, 
        fps=30, 
        fourcc="MJPG"
    )
}

robot_config = SO101FollowerConfig(
    port="/dev/ttyACM0",
    id="follower_arm",
    cameras=camera_config
)

teleop_config = SO101LeaderConfig(
    port="/dev/ttyACM1",
    id="leader_arm",
)

robot = SO101Follower(robot_config)
teleop_device = SO101Leader(teleop_config)