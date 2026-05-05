import type { TimingData } from "./timing";

export class DebugStore {
  private buffer: TimingData[] = [];
  private readonly capacity: number;

  constructor(capacity = 100) {
    this.capacity = capacity;
  }

  push(data: TimingData): void {
    if (this.buffer.length >= this.capacity) {
      this.buffer.shift();
    }
    this.buffer.push(data);
  }

  getAll(): TimingData[] {
    return [...this.buffer];
  }
}
