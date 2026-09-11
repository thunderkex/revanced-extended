import { execCommand } from './api';
import { renderStatusCard } from './components/StatusCard';
import { renderAppList, BundledApp } from './components/AppList';

export class App {
  private root: HTMLElement;
  private apps: BundledApp[] = [
    { id: 'youtube', name: 'YouTube ReVanced', package: 'com.google.android.youtube', mounted: true },
    { id: 'youtube_music', name: 'YouTube Music', package: 'com.google.android.apps.youtube.music', mounted: true },
    { id: 'microg', name: 'MicroG RE', package: 'app.revanced.android.gms', mounted: true },
  ];

  constructor(root: HTMLElement) {
    this.root = root;
    this.render();
  }

  render() {
    this.root.innerHTML = `
      <header>
        <h1>ReVanceX</h1>
        <p style="margin:0;font-size:0.85rem;color:#888;">KernelSU / Magisk Module Manager</p>
      </header>
    `;

    const statusSection = renderStatusCard(
      'System Overlay Status',
      'Operational',
      'Apps mounted under /system/app and active.'
    );
    this.root.appendChild(statusSection);

    const appSection = renderAppList(this.apps, async (app) => {
      app.mounted = !app.mounted;
      try {
        await execCommand(`echo "Toggled ${app.package} to ${app.mounted}"`);
      } catch (e) {
        console.error(e);
      }
      this.render();
    });
    this.root.appendChild(appSection);
  }
}

const appElement = document.getElementById('app');
if (appElement) {
  new App(appElement);
}
