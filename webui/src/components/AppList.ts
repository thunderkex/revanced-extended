export interface BundledApp {
  id: string;
  name: string;
  package: string;
  mounted: boolean;
}

export function renderAppList(apps: BundledApp[], onToggle: (app: BundledApp) => void): HTMLElement {
  const container = document.createElement('div');
  container.style.cssText = 'background:#1e1e1e;border-radius:8px;padding:16px;border:1px solid #333;';

  const header = document.createElement('h3');
  header.style.cssText = 'margin:0 0 12px;font-size:1.1rem;';
  header.textContent = 'Installed Module Apps';
  container.appendChild(header);

  apps.forEach(app => {
    const item = document.createElement('div');
    item.style.cssText = 'display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px solid #2a2a2a;';
    item.innerHTML = `
      <div>
        <div style="font-weight:600;">${app.name}</div>
        <div style="font-size:0.75rem;color:#888;">${app.package}</div>
      </div>
    `;

    const btn = document.createElement('button');
    btn.style.cssText = `padding:6px 12px;border-radius:4px;border:none;cursor:pointer;font-weight:600;background:${app.mounted ? '#03dac6' : '#555'};color:#000;`;
    btn.textContent = app.mounted ? 'Active' : 'Disabled';
    btn.onclick = () => onToggle(app);

    item.appendChild(btn);
    container.appendChild(item);
  });

  return container;
}
