import torch
from accelerate import Accelerator

from lerobot.common.utils.utils import init_logging
from lerobot.common.datasets.factory import make_dataset
from lerobot.common.envs.factory import make_env
from lerobot.common.policies.factory import make_policy
from lerobot.common.trainers.factory import make_trainer


def main():
    # ---- Accelerate with W&B integration ----
    accelerator = Accelerator(log_with='wandb')
    device = accelerator.device

    # ---- Config ----
    cfg = {
        'seed': 42,
        'device': device,

        'dataset': {'name': 'lerobot/stack-cups'},
        'env': {'name': 'stack-cups'},

        'policy': {
            'name': 'act',
            'chunk_size': 16,
            'hidden_dim': 512,
        },

        'training': {
            'batch_size': 32,
            'num_steps': 100000,
        },

        'wandb': {
            'project': 'lerobot-act',
            'run_name': 'act-run-1',
        }
    }

    # ---- Initialize logging ----
    init_logging()
    torch.manual_seed(cfg['seed'])

    # ---- Initialize W&B trackers (main process only) ----
    if accelerator.is_main_process:
        accelerator.init_trackers(
            project_name=cfg['wandb']['project'],
            config=cfg,
            init_kwargs={'name': cfg['wandb']['run_name']}
        )

    # ---- Build components ----
    dataset = make_dataset(cfg['dataset'])
    env = make_env(cfg['env']) if cfg.get('env') else None
    policy = make_policy(cfg['policy'], dataset=dataset)
    trainer = make_trainer(cfg['training'], policy=policy, dataset=dataset, env=env)

    # ---- Prepare for multi-GPU ----
    policy, trainer = accelerator.prepare(policy, trainer)

    # ---- Training loop ----
    for step in range(cfg['training']['num_steps']):
        metrics = trainer.train_step()

        # ---- Log metrics safely (multi-GPU aware) ----
        accelerator.log(metrics, step=step)

    # ---- Finish W&B run ----
    if accelerator.is_main_process:
        accelerator.end_training()


if __name__ == '__main__':
    main()