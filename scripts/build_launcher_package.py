#!/usr/bin/env python3
"""
Build the launcher Lambda deployment package.

This script prepares build/launcher-package for the Python launcher Lambda.
It is designed to run from Terraform local-exec on Windows/Git Bash while
building Lambda-compatible Linux wheels.

Key behavior:
- Installs dependencies from launcher/requirements.txt.
- Forces manylinux2014_x86_64 wheels for AWS Lambda.
- Uses Python 3.14 / CPython cp314 ABI.
- Uses --ignore-installed so local workstation packages do not pollute the build.
- Copies launcher/lambda_function.py into the package directory.
- Verifies native Linux wheels such as pydantic_core are present.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


def run_command(command: list[str], *, cwd: Path | None = None) -> None:
    """Run a shell command and fail loudly if it exits non-zero."""
    print("\nRunning command:")
    print(" ".join(str(part) for part in command))

    subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        check=True,
    )


def remove_path(path: Path) -> None:
    """Remove a file or directory if it exists."""
    if path.is_dir():
        print(f"Removing directory: {path}")
        shutil.rmtree(path)
    elif path.exists():
        print(f"Removing file: {path}")
        path.unlink()


def copy_launcher_source(source_file: Path, package_dir: Path) -> None:
    """Copy the Lambda handler into the package directory."""
    if not source_file.exists():
        raise FileNotFoundError(f"Launcher source file not found: {source_file}")

    destination = package_dir / source_file.name
    print(f"Copying launcher source: {source_file} -> {destination}")
    shutil.copy2(source_file, destination)


def cleanup_python_cache(package_dir: Path) -> None:
    """Remove Python cache files from the deployment package."""
    for cache_dir in package_dir.rglob("__pycache__"):
        remove_path(cache_dir)

    for pattern in ("*.pyc", "*.pyo"):
        for compiled_file in package_dir.rglob(pattern):
            remove_path(compiled_file)


def verify_required_files(package_dir: Path) -> None:
    """
    Verify that required files exist in the package.

    pydantic_core contains a native .so file. If this is missing, the Lambda
    function can fail at runtime with:
    No module named 'pydantic_core._pydantic_core'
    """
    lambda_handler = package_dir / "lambda_function.py"
    if not lambda_handler.exists():
        raise FileNotFoundError(
            f"lambda_function.py was not copied into the package: {lambda_handler}"
        )

    pydantic_core_dir = package_dir / "pydantic_core"
    if not pydantic_core_dir.exists():
        raise FileNotFoundError(
            "pydantic_core directory was not found in the launcher package."
        )

    pydantic_core_native_files = list(
        pydantic_core_dir.glob("_pydantic_core*.so")
    )

    if not pydantic_core_native_files:
        raise FileNotFoundError(
            "pydantic_core native Linux .so file was not found. "
            "The launcher package may have been built with the wrong platform."
        )

    print("Verified pydantic_core native files:")
    for file_path in pydantic_core_native_files:
        print(f"  - {file_path}")

    jiter_native_files = list(package_dir.rglob("jiter*.so"))
    if jiter_native_files:
        print("Verified jiter native files:")
        for file_path in jiter_native_files:
            print(f"  - {file_path}")

    print("Launcher package verification complete.")


def main() -> None:
    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent

    launcher_dir = project_root / "launcher"
    build_dir = project_root / "build"
    package_dir = build_dir / "launcher-package"

    requirements_file = launcher_dir / "requirements.txt"
    launcher_source_file = launcher_dir / "lambda_function.py"

    python_command = os.environ.get("PYTHON_COMMAND", sys.executable)

    if not requirements_file.exists():
        raise FileNotFoundError(f"requirements.txt not found: {requirements_file}")

    print("Preparing launcher Lambda package")
    print(f"Project root:       {project_root}")
    print(f"Launcher dir:       {launcher_dir}")
    print(f"Build dir:          {build_dir}")
    print(f"Package dir:        {package_dir}")
    print(f"Requirements file:  {requirements_file}")
    print(f"Python command:     {python_command}")

    build_dir.mkdir(parents=True, exist_ok=True)

    remove_path(package_dir)
    package_dir.mkdir(parents=True, exist_ok=True)

    pip_command = [
        python_command,
        "-m",
        "pip",
        "install",
        "--upgrade",
        "--ignore-installed",
        "--no-warn-conflicts",
        "--no-cache-dir",
        "--only-binary=:all:",
        "--platform",
        "manylinux2014_x86_64",
        "--implementation",
        "cp",
        "--python-version",
        "3.14",
        "--abi",
        "cp314",
        "-r",
        str(requirements_file),
        "-t",
        str(package_dir),
    ]

    env = os.environ.copy()
    env["PYTHONNOUSERSITE"] = "1"
    env["PIP_DISABLE_PIP_VERSION_CHECK"] = "1"

    print("\nInstalling launcher dependencies for AWS Lambda:")
    print(" ".join(pip_command))

    subprocess.run(
        pip_command,
        check=True,
        env=env,
    )

    copy_launcher_source(launcher_source_file, package_dir)
    cleanup_python_cache(package_dir)
    verify_required_files(package_dir)

    print(f"\nLauncher package prepared at {package_dir}")


if __name__ == "__main__":
    main()