export function renderStatusCard(title: string, status: string, detail: string): HTMLElement {
  const card = document.createElement('div');
  card.style.cssText = 'background:#1e1e1e;padding:16px;border-radius:8px;margin-bottom:12px;border:1px solid #333;';
  card.innerHTML = `
    <h3 style="margin:0 0 4px;font-size:1rem;color:#bb86fc;">${title}</h3>
    <div style="font-size:0.9rem;font-weight:600;margin-bottom:4px;">Status: ${status}</div>
    <div style="font-size:0.8rem;color:#888;">${detail}</div>
  `;
  return card;
}
