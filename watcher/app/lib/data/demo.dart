// Sample data copied from the UI kit so screens can be built before the
// server API exists. Replace with live data when the backend is wired up.
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

enum FileKind { dir, jpg, mkv, pdf, zip }

extension FileKindStyle on FileKind {
  String get ext => name.toUpperCase();
  Color get bg => switch (this) {
        FileKind.dir => WColors.tint(WColors.primary, .18),
        FileKind.jpg => WColors.tint(WColors.data),
        FileKind.mkv => WColors.tint(WColors.warning),
        FileKind.pdf => WColors.tint(WColors.down),
        FileKind.zip => WColors.raised,
      };
  Color get fg => switch (this) {
        FileKind.dir => WColors.primary,
        FileKind.jpg => WColors.data,
        FileKind.mkv => WColors.warning,
        FileKind.pdf => WColors.down,
        FileKind.zip => WColors.secondary,
      };
  String get kind => switch (this) {
        FileKind.dir => 'Folder',
        FileKind.jpg => 'JPEG image',
        FileKind.mkv => 'Video',
        FileKind.pdf => 'PDF document',
        FileKind.zip => 'Archive',
      };
}

class DemoFile {
  const DemoFile(this.type, this.name, this.size, this.date, this.role);
  final FileKind type;
  final String name;
  final String size;
  final String date;
  final WRole role;
  bool get isDir => type == FileKind.dir;
}

const demoFiles = [
  DemoFile(FileKind.dir, 'Summer trip', '—', '12 Oct', WRole.family),
  DemoFile(FileKind.dir, 'Birthday', '—', '03 Sep', WRole.family),
  DemoFile(FileKind.jpg, 'IMG_2041.jpg', '4.2 MB', '21 Oct 18:02', WRole.family),
  DemoFile(FileKind.jpg, 'IMG_2042.jpg', '3.9 MB', '21 Oct 18:03', WRole.family),
  DemoFile(FileKind.mkv, 'Beach clip.mkv', '1.8 GB', '20 Oct 14:40', WRole.family),
  DemoFile(FileKind.pdf, 'Insurance 2026.pdf', '412 KB', '02 Oct 09:15', WRole.admin),
  DemoFile(FileKind.zip, 'Raw exports.zip', '6.3 GB', '28 Sep 22:10', WRole.admin),
  DemoFile(FileKind.jpg, 'Cover.jpg', '2.1 MB', '18 Sep 11:30', WRole.user),
];

class DemoStat {
  const DemoStat(this.label, this.value, this.unit, this.delta, this.deltaColor, this.series);
  final String label;
  final String value;
  final String unit;
  final String delta;
  final Color deltaColor;
  final Map<String, List<double>> series; // keyed by range: 24h / 7d / 30d
}

// Sparkline points are SVG y-values in a 0..32 box (lower = higher value).
const demoStats = [
  DemoStat('CPU', '23', '%', '−4% vs avg', WColors.ok, {
    '24h': [24, 22, 25, 18, 20, 14, 16, 10, 13, 8, 11, 6, 9],
    '7d': [16, 18, 14, 20, 12, 15, 10, 14, 18, 12, 9, 13, 11],
    '30d': [20, 16, 18, 14, 16, 12, 15, 11, 13, 10, 12, 9, 10],
  }),
  DemoStat('Memory', '11.4', 'GB', '+0.8 GB', WColors.secondary, {
    '24h': [12, 14, 13, 16, 15, 18, 17, 20, 19, 22, 21, 23, 24],
    '7d': [22, 20, 21, 18, 19, 16, 17, 15, 16, 13, 14, 12, 12],
    '30d': [26, 24, 22, 22, 20, 19, 18, 17, 16, 15, 14, 13, 12],
  }),
  DemoStat('Network', '84', 'Mb/s', '3 streams', WColors.secondary, {
    '24h': [20, 20, 19, 21, 20, 22, 21, 20, 21, 19, 20, 20, 21],
    '7d': [18, 19, 20, 18, 21, 20, 19, 22, 21, 20, 22, 21, 20],
    '30d': [21, 20, 20, 21, 20, 21, 20, 20, 21, 20, 21, 20, 20],
  }),
  DemoStat('Disk 2', '91', '%', '+2% today', WColors.warning, {
    '24h': [28, 26, 27, 22, 24, 25, 20, 18, 21, 16, 18, 14, 15],
    '7d': [20, 24, 18, 22, 26, 20, 24, 18, 22, 20, 16, 18, 17],
    '30d': [24, 22, 26, 20, 24, 22, 18, 22, 20, 18, 20, 16, 18],
  }),
];

// CPU chart points, SVG y-values in a 0..160 box.
const demoCpu = {
  '24h': <double>[120, 118, 124, 110, 112, 100, 104, 96, 108, 90, 94, 84, 88, 96, 80, 86, 104, 92, 98, 110, 106, 114, 108, 112, 118],
  '7d': <double>[110, 104, 116, 98, 120, 100, 92, 108, 114, 96, 88, 102, 94, 110, 100, 90, 106, 98, 112, 104, 96, 108, 100, 94, 102],
  '30d': <double>[100, 108, 96, 104, 98, 110, 102, 96, 106, 100, 94, 104, 98, 108, 96, 102, 100, 94, 104, 98, 106, 100, 96, 102, 98],
};

const demoXTicks = {
  '24h': ['00:00', '06:00', '12:00', '18:00', 'now'],
  '7d': ['Fri', 'Sun', 'Tue', 'Wed', 'now'],
  '30d': ['24 Sep', '01 Oct', '08 Oct', '15 Oct', 'now'],
};

class DemoService {
  const DemoService(this.name, this.meta, this.status, this.statusLabel);
  final String name;
  final String meta;
  final WStatus status;
  final String statusLabel;
}

const demoServices = [
  DemoService('Jellyfin', 'Streaming · 3 active', WStatus.ok, 'Online'),
  DemoService('Nextcloud', 'Files · 1.2 TB', WStatus.ok, 'Online'),
  DemoService('Backups', 'Last run 02:00 · slow', WStatus.warn, 'Slow'),
  DemoService('Home Assistant', 'No response 4 min', WStatus.down, 'Down'),
  DemoService('Pi-hole', 'DNS · 14k queries', WStatus.ok, 'Online'),
];

class DemoServiceCard {
  const DemoServiceCard(this.name, this.host, this.status, this.statusLabel, this.uptime, this.resp, this.cpu, this.note, this.noteColor);
  final String name, host, statusLabel, uptime, resp, cpu, note;
  final WStatus status;
  final Color noteColor;
}

const demoServiceCards = [
  DemoServiceCard('Jellyfin', 'media.local:8096', WStatus.ok, 'Online', '41d 6h', '38 ms', '12%', '3 active streams', WColors.secondary),
  DemoServiceCard('Backups', 'restic · nightly', WStatus.warn, 'Degraded', '41d 6h', '—', '4%', 'Last run took 2h 14m (avg 48m)', WColors.warning),
  DemoServiceCard('Home Assistant', 'ha.local:8123', WStatus.down, 'Down', '—', 'timeout', '—', 'No response for 4 min', WColors.down),
  DemoServiceCard('Nextcloud', 'cloud.local:443', WStatus.busy, 'Restarting', '—', '—', '—', 'Started by Alex · 8 s ago', WColors.secondary),
];

class DemoUser {
  const DemoUser(this.initials, this.name, this.role, [this.lastSeen]);
  final String initials, name;
  final WRole role;
  final String? lastSeen;
}

const demoUsers = [
  DemoUser('AL', 'Alex L.', WRole.admin, 'Online now'),
  DemoUser('MK', 'Mira K.', WRole.family, 'Last seen 2 h ago'),
  DemoUser('JT', 'Jonas T.', WRole.user, 'Last seen 3 d ago'),
];

class DemoLog {
  const DemoLog(this.time, this.level, this.message);
  final String time, level, message;
  Color get color => switch (level) {
        'OK' => WColors.ok,
        'WARN' => WColors.warning,
        'ERR' => WColors.down,
        _ => WColors.secondary,
      };
}

const demoLogs = [
  DemoLog('18:02:11', 'INFO', 'jellyfin: transcode started (1080p → 720p)'),
  DemoLog('18:02:14', 'OK', 'backup: snapshot 2026-10-23 verified'),
  DemoLog('18:04:40', 'WARN', 'disk2: usage 91% (threshold 90%)'),
  DemoLog('18:06:02', 'ERR', 'homeassistant: health check timeout :8123'),
  DemoLog('18:06:05', 'INFO', 'alert sent to 2 admins'),
];

class DemoPoster {
  const DemoPoster(this.title, this.meta, this.quality, this.isNew, this.progress, this.bg, {this.watched = false});
  final String title, meta, quality;
  final bool isNew, watched;
  final double progress; // 0..1
  final Color bg;
}

const demoPosters = [
  DemoPoster('Northern Line', 'Series · S2 E4', '4K', true, .64, Color(0xFF1C2A3A)),
  DemoPoster('Slow Harbour', 'Film · 1h 52m', 'HD', false, 0, Color(0xFF2A2420)),
  DemoPoster('Field Notes', 'Docu · 48m', '4K', true, 0, Color(0xFF1E2A26)),
  DemoPoster('Paper Moons', 'Film · 2h 06m', 'HD', false, .22, Color(0xFF2A1E2A)),
];

class DemoBanner {
  const DemoBanner(this.color, this.title, this.body, this.action);
  final Color color;
  final String title, body, action;
}

const demoBanners = [
  DemoBanner(WColors.primary, 'Update available', 'Watcher 2.4 is ready to install.', 'Update'),
  DemoBanner(WColors.ok, 'Backup complete', 'Snapshot verified · 412 GB.', 'View'),
  DemoBanner(WColors.warning, 'Disk 2 at 91%', 'Media volume full in ~6 days.', 'Manage'),
  DemoBanner(WColors.down, 'Home Assistant is down', 'No response on :8123 for 4 min.', 'Restart'),
];

const demoBandwidth = [('M', .42), ('T', .58), ('W', .36), ('T', .72), ('F', .88), ('S', .64), ('S', .50)];
