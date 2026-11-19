export function confirmBlock(name: string): boolean {
  return window.confirm(`If you block ${name}, you’ll no longer see their posts or comments.`);
}
