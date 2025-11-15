import os
import subprocess
import sys
import tkinter as tk
from tkinter import messagebox, simpledialog


BRANCH_NAME = "vm-snapshots"
SAVE_DIR = r"D:\save"


def get_repo_dir() -> str:
    repo = os.environ.get("GITHUB_WORKSPACE")
    if repo:
        return repo
    here = os.path.abspath(os.path.dirname(__file__))
    return os.path.abspath(os.path.join(here, os.pardir, os.pardir))


REPO_DIR = get_repo_dir()


def git_env() -> dict:
    env = os.environ.copy()
    env.setdefault("GIT_TERMINAL_PROMPT", "0")
    env.setdefault("GIT_INDEX_FILE", os.path.join(REPO_DIR, ".git", "vm-snapshots.index"))
    return env


def run_git(args):
    return subprocess.run(
        ["git"] + args,
        cwd=REPO_DIR,
        text=True,
        capture_output=True,
        env=git_env(),
    )


def run_pwsh_script(script_rel_path, extra_env=None):
    env = os.environ.copy()
    env.setdefault("GITHUB_WORKSPACE", REPO_DIR)
    if extra_env:
        env.update(extra_env)
    script_path = os.path.join(REPO_DIR, script_rel_path)
    cmd = ["pwsh.exe", "-NoLogo", "-ExecutionPolicy", "Bypass", "-File", script_path]
    return subprocess.run(cmd, cwd=REPO_DIR, text=True, capture_output=True, env=env)


def ensure_save_dir():
    if not os.path.isdir(SAVE_DIR):
        os.makedirs(SAVE_DIR, exist_ok=True)


def fetch_snapshots():
    run_git(["fetch", "origin", BRANCH_NAME])
    result = run_git(["ls-tree", "--name-only", f"origin/{BRANCH_NAME}:snapshots"])
    if result.returncode != 0:
        return []
    names = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    return names


def kill_processes_using_save():
    ps_code = rf"""
$ErrorActionPreference = 'SilentlyContinue'
$saveDir = '{SAVE_DIR}'
$procs = @()
foreach ($p in Get-Process) {{
    try {{
        $path = $p.MainModule.FileName
        if ($path -and $path.StartsWith($saveDir, [System.StringComparison]::OrdinalIgnoreCase)) {{
            $procs += $p
        }}
    }} catch {{ }}
}}
foreach ($p in $procs) {{
    try {{ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }} catch {{ }}
}}
"""
    subprocess.run(
        ["pwsh.exe", "-NoLogo", "-Command", ps_code],
        text=True,
        capture_output=True,
    )


class SnapshotManagerGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("D:\\save 快照管理器 (Python GUI)")
        self.geometry("700x400")

        ensure_save_dir()

        top_frame = tk.Frame(self)
        top_frame.pack(fill=tk.X, padx=10, pady=5)

        tk.Label(top_frame, text=f"仓库路径: {REPO_DIR}").pack(anchor="w")
        tk.Label(top_frame, text=f"数据目录: {SAVE_DIR}").pack(anchor="w")

        main_frame = tk.Frame(self)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)

        left_frame = tk.Frame(main_frame)
        left_frame.pack(side=tk.LEFT, fill=tk.Y)

        tk.Label(left_frame, text="快照列表").pack(anchor="w")
        self.listbox = tk.Listbox(left_frame, width=30)
        self.listbox.pack(fill=tk.Y, expand=True)

        tk.Button(left_frame, text="刷新列表", command=self.refresh_list).pack(fill=tk.X, pady=2)

        right_frame = tk.Frame(main_frame)
        right_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10)

        entry_frame = tk.Frame(right_frame)
        entry_frame.pack(fill=tk.X)
        tk.Label(entry_frame, text="快照名称：").pack(side=tk.LEFT)
        self.snapshot_name_var = tk.StringVar()
        self.snapshot_entry = tk.Entry(entry_frame, textvariable=self.snapshot_name_var)
        self.snapshot_entry.pack(side=tk.LEFT, fill=tk.X, expand=True)

        self.kill_var = tk.BooleanVar(value=False)
        tk.Checkbutton(
            right_frame,
            text="保存前结束所有运行在 D:\\save 下的程序",
            variable=self.kill_var,
        ).pack(anchor="w", pady=2)

        btn_frame = tk.Frame(right_frame)
        btn_frame.pack(fill=tk.X, pady=5)

        tk.Button(btn_frame, text="保存到快照", command=self.save_snapshot).pack(fill=tk.X, pady=2)
        tk.Button(btn_frame, text="从选中快照还原", command=self.restore_snapshot).pack(fill=tk.X, pady=2)
        tk.Button(btn_frame, text="删除选中快照", command=self.delete_snapshot).pack(fill=tk.X, pady=2)
        tk.Button(btn_frame, text="重命名选中快照", command=self.rename_snapshot).pack(fill=tk.X, pady=2)

        log_frame = tk.Frame(self)
        log_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        tk.Label(log_frame, text="日志输出：").pack(anchor="w")
        self.log_text = tk.Text(log_frame, height=8)
        self.log_text.pack(fill=tk.BOTH, expand=True)

        self.refresh_list()

    def log(self, text):
        self.log_text.insert(tk.END, text + "\n")
        self.log_text.see(tk.END)

    def get_selected_snapshot(self):
        sel = self.listbox.curselection()
        if not sel:
            return None
        return self.listbox.get(sel[0])

    def refresh_list(self):
        names = fetch_snapshots()
        self.listbox.delete(0, tk.END)
        for n in names:
            self.listbox.insert(tk.END, n)
        if not names:
            self.log("当前分支中没有快照。")
        else:
            self.log(f"已加载 {len(names)} 个快照。")

    def save_snapshot(self):
        name = self.snapshot_name_var.get().strip()
        if not name:
            messagebox.showerror("错误", "快照名称不能为空。")
            return

        if self.kill_var.get():
            self.log("正在结束运行在 D:\\save 下的程序...")
            kill_processes_using_save()

        self.log(f"开始保存快照到 snapshots/{name} ...")
        result = run_pwsh_script(
            r".github\workflows\scripts\win-save-snapshot.ps1",
            extra_env={"SNAPSHOT_TARGET": name},
        )
        self.log(result.stdout.strip())
        if result.returncode != 0:
            self.log(result.stderr.strip())
            messagebox.showerror("保存失败", f"保存快照时出错（退出码 {result.returncode}）。")
        else:
            messagebox.showinfo("保存完成", f"已将 D:\\save 保存到快照 '{name}'。")
            self.refresh_list()

    def restore_snapshot(self):
        name = self.get_selected_snapshot()
        if not name:
            messagebox.showerror("错误", "请先在列表中选择一个快照。")
            return

        if not messagebox.askyesno(
            "确认还原",
            f"确认要用快照 '{name}' 完全覆盖 {SAVE_DIR} 吗？\n\n此操作会删除 D:\\save 中快照外的多余文件。",
        ):
            return

        self.log(f"开始从 snapshots/{name} 还原到 D:\\save ...")
        result = run_pwsh_script(
            r".github\workflows\scripts\win-restore-snapshot.ps1",
            extra_env={"SNAPSHOT_FOLDER": name},
        )
        self.log(result.stdout.strip())
        if result.returncode != 0:
            self.log(result.stderr.strip())
            messagebox.showerror("还原失败", f"还原快照时出错（退出码 {result.returncode}）。")
        else:
            messagebox.showinfo("还原完成", f"已从快照 '{name}' 还原到 D:\\save。")

    def delete_snapshot(self):
        name = self.get_selected_snapshot()
        if not name:
            messagebox.showerror("错误", "请先在列表中选择一个快照。")
            return

        if not messagebox.askyesno(
            "确认删除",
            f"确认要删除快照 '{name}' 吗？此操作不可撤销。",
        ):
            return

        self.log(f"开始删除快照 snapshots/{name} ...")
        result = run_git(["fetch", "origin", BRANCH_NAME])
        if result.returncode != 0:
            self.log(result.stderr.strip())
            messagebox.showerror("删除失败", "获取远端分支失败。")
            return

        result = run_git(["restore", "--source", f"origin/{BRANCH_NAME}", "--", "snapshots"])
        if result.returncode != 0:
            self.log(result.stderr.strip())
            messagebox.showerror("删除失败", "无法恢复 snapshots 目录。")
            return

        target_dir = os.path.join(REPO_DIR, "snapshots", name)
        if not os.path.isdir(target_dir):
            messagebox.showerror("删除失败", f"快照 'snapshots/{name}' 不存在。")
            return

        import shutil

        shutil.rmtree(target_dir, ignore_errors=False)

        result = run_git(["add", "snapshots"])
        if result.returncode != 0:
            self.log(result.stderr.strip())
            messagebox.showerror("删除失败", "git add snapshots 失败。")
            return

        msg = f"Delete snapshot {name}"
        result = run_git(["commit", "-m", msg])
        if result.returncode != 0:
            self.log("没有变化需要提交，可能快照已被删除。")

        result = run_git(["push", "origin", "HEAD:refs/heads/" + BRANCH_NAME, "--force-with-lease=refs/heads/" + BRANCH_NAME])
        if result.returncode != 0:
            self.log(result.stderr.strip())
            messagebox.showerror("删除失败", "推送 vm-snapshots 分支失败。")
            return

        self.log(f"已删除快照 '{name}' 并推送到分支 '{BRANCH_NAME}'。")
        messagebox.showinfo("删除完成", f"快照 '{name}' 已删除。")
        self.refresh_list()

    def rename_snapshot(self):
        old_name = self.get_selected_snapshot()
        if not old_name:
            messagebox.showerror("错误", "请先在列表中选择一个快照。")
            return

        new_name = simpledialog.askstring("重命名快照", f"将快照 '{old_name}' 重命名为：")
        if not new_name:
            return
        new_name = new_name.strip()
        if not new_name or new_name == old_name:
            return

        if not messagebox.askyesno(
            "确认重命名",
            f"确认将快照 '{old_name}' 重命名为 '{new_name}' 吗？",
        ):
            return

        self.log(f"开始重命名快照 {old_name} -> {new_name} ...")
        result = run_git(["fetch", "origin", BRANCH_NAME])
        if result.returncode != 0:
            self.log(result.stderr.strip())
            messagebox.showerror("重命名失败", "获取远端分支失败。")
            return

        result = run_git(["restore", "--source", f"origin/{BRANCH_NAME}", "--", "snapshots"])
        if result.returncode != 0:
            self.log(result.stderr.strip())
            messagebox.showerror("重命名失败", "无法恢复 snapshots 目录。")
            return

        old_dir = os.path.join(REPO_DIR, "snapshots", old_name)
        new_dir = os.path.join(REPO_DIR, "snapshots", new_name)

        if not os.path.isdir(old_dir):
            messagebox.showerror("重命名失败", f"快照 'snapshots/{old_name}' 不存在。")
            return

        if os.path.isdir(new_dir):
            messagebox.showerror("重命名失败", f"目标快照 'snapshots/{new_name}' 已存在。")
            return

        os.rename(old_dir, new_dir)

        result = run_git(["add", "snapshots"])
        if result.returncode != 0:
            self.log(result.stderr.strip())
            messagebox.showerror("重命名失败", "git add snapshots 失败。")
            return

        msg = f"Rename snapshot {old_name} to {new_name}"
        result = run_git(["commit", "-m", msg])
        if result.returncode != 0:
            self.log("没有变化需要提交，重命名可能未生效。")

        result = run_git(["push", "origin", "HEAD:refs/heads/" + BRANCH_NAME, "--force-with-lease=refs/heads/" + BRANCH_NAME])
        if result.returncode != 0:
            self.log(result.stderr.strip())
            messagebox.showerror("重命名失败", "推送 vm-snapshots 分支失败。")
            return

        self.log(f"已将快照 '{old_name}' 重命名为 '{new_name}' 并推送到分支 '{BRANCH_NAME}'。")
        messagebox.showinfo("重命名完成", f"快照已重命名为 '{new_name}'。")
        self.refresh_list()


def main():
    try:
        app = SnapshotManagerGUI()
        app.mainloop()
    except Exception as e:
        messagebox.showerror("异常", f"程序发生错误：{e}")
        raise


if __name__ == "__main__":
    main()

