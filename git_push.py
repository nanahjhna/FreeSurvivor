import os
import subprocess
from pathlib import Path


def run_git(cmd: list[str], cwd: Path) -> str:
    """Git 명령어를 실행하고 결과를 반환합니다."""
    result = subprocess.run(
        ["git", *cmd],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=True,
    )
    return result.stdout.strip()


def commit_and_push(
    repo_url: str,
    local_dir: str = ".",
    commit_message: str = "Update files",
    branch: str = "main",
) -> None:
    target_path = Path(local_dir).resolve()
    target_path.mkdir(parents=True, exist_ok=True)

    # 1. .git 폴더가 없으면 초기화
    if not (target_path / ".git").exists():
        run_git(["init"], target_path)
        run_git(["branch", "-M", branch], target_path)

    # 2. origin 원격 저장소 설정(이미 있으면 URL 업데이트)
    remotes = run_git(["remote"], target_path).splitlines()
    if "origin" in remotes:
        run_git(["remote", "set-url", "origin", repo_url], target_path)
    else:
        run_git(["remote", "add", "origin", repo_url], target_path)

    # 3. 변경사항 스테이징
    run_git(["add", "."], target_path)

    # 4. 커밋할 변경사항이 있는지 확인 후 커밋
    status = run_git(["status", "--porcelain"], target_path)
    if not status:
        print("커밋할 변경사항이 없습니다.")
    else:
        run_git(["commit", "-m", commit_message], target_path)
        print(f"커밋 완료: {commit_message}")

    # 5. 원격 저장소로 푸시 (원격에 기존 커밋이 있다면 필요 시 --rebase 활용)
    run_git(["push", "-u", "origin", branch], target_path)
    print(f"푸시 완료: {repo_url} ({branch})")


if __name__ == "__main__":
    repo_url = input("리포지토리 주소를 입력하세요: ").strip()
    local_dir = input("작업 폴더 경로 (기본값 현재 폴더 '.'): ").strip() or "."
    commit_msg = input("커밋 메시지를 입력하세요 (기본값 'Update files'): ").strip() or "Update files"
    branch_name = input("브랜치 이름 (기본값 'main'): ").strip() or "main"

    try:
        commit_and_push(
            repo_url=repo_url,
            local_dir=local_dir,
            commit_message=commit_msg,
            branch=branch_name,
        )
    except subprocess.CalledProcessError as e:
        print("Git 명령 실행 중 오류가 발생했습니다.")
        print("STDOUT:", e.stdout)
        print("STDERR:", e.stderr)
