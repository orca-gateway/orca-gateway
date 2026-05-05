export interface TimingData {
  path: string;
  method: string;
  stages: Record<string, number>; // stage name -> duration in ms
  componentCount: number;
  responseSizeBytes: number;
  cacheStatus: "hit" | "miss" | "none";
  totalMs: number;
  timestamp: number;
}

export class TimingCollector {
  private marks = new Map<string, number>();
  componentCount = 0;
  responseSizeBytes = 0;
  cacheStatus: "hit" | "miss" | "none" = "none";

  mark(name: string): void {
    this.marks.set(name, performance.now());
  }

  toTimingData(path: string, method: string): TimingData {
    const stages: Record<string, number> = {};
    const pairs = [
      "middleware", "getInfo", "getState", "render", "flatten", "postRender",
    ];
    for (const stage of pairs) {
      const start = this.marks.get(`${stage}Start`);
      const end = this.marks.get(`${stage}End`);
      if (start !== undefined && end !== undefined) {
        stages[stage] = Math.round((end - start) * 100) / 100;
      }
    }

    const requestReceived = this.marks.get("requestReceived") ?? 0;
    const responseSent = this.marks.get("responseSent") ?? requestReceived;
    const totalMs = Math.round((responseSent - requestReceived) * 100) / 100;

    return {
      path,
      method,
      stages,
      componentCount: this.componentCount,
      responseSizeBytes: this.responseSizeBytes,
      cacheStatus: this.cacheStatus,
      totalMs,
      timestamp: Date.now(),
    };
  }
}
