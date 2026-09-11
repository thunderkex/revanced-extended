export interface KsuExecResult {
  errno: number;
  stdout: string;
  stderr: string;
}

declare global {
  interface Window {
    ksu?: {
      exec: (command: string) => Promise<KsuExecResult>;
    };
  }
}

export async function execCommand(command: string): Promise<string> {
  if (window.ksu && typeof window.ksu.exec === 'function') {
    const res = await window.ksu.exec(command);
    if (res.errno !== 0) {
      throw new Error(res.stderr || `Exit code ${res.errno}`);
    }
    return res.stdout;
  }
  console.log(`[ksu-exec] ${command}`);
  return "success";
}
