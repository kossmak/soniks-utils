from pathlib import Path

dir_path: Path = Path(__file__).resolve().parent

file_path = dir_path / "../_dev2_conf/.env.dev2"

with open(file_path, "r") as f:
    lines = f.readlines()

lines.sort()

with open(file_path, "w") as f:
    for line in lines:
        f.write(line)
