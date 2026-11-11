const { execSync, spawn } = require('child_process');
const path = require('path');

const localAppData = process.env.LOCALAPPDATA || 'C:\\Users\\taner\\AppData\\Local';
const adbPath = path.join(localAppData, 'Android', 'Sdk', 'platform-tools', 'adb.exe');
const emulatorPath = path.join(localAppData, 'Android', 'Sdk', 'emulator', 'emulator.exe');

function isDeviceAttached() {
  try {
    const output = execSync(`"${adbPath}" devices`, { encoding: 'utf-8' });
    const lines = output.split('\n').map(l => l.trim()).filter(l => l.length > 0);
    // İlk satır "List of devices attached"
    return lines.some(line => line.includes('\tdevice'));
  } catch (e) {
    return false;
  }
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  console.log('\n==========================================');
  console.log('🚀 UstamBurada Başlatıcı');
  console.log('==========================================\n');

  if (!isDeviceAttached()) {
    console.log('📱 Bağlı cihaz veya emülatör bulunamadı.');
    console.log('⚡ Pixel_9_Pro_XL emülatörü arka planda başlatılıyor...');

    try {
      // Windows'ta emülatörü tamamen bağımsız bir masaüstü penceresi olarak başlat
      execSync(`cmd.exe /c start "" "${emulatorPath}" -avd Pixel_9_Pro_XL`);
    } catch (err) {
      console.log('Emülatör başlatma hatası:', err.message);
    }

    console.log('⏳ Emülatörün cihaz listesine gelmesi bekleniyor...');
    try {
      execSync(`"${adbPath}" wait-for-device`, { stdio: 'ignore', timeout: 90000 });
    } catch (e) {}

    console.log('⏳ Android sisteminin açılışı (boot) tamamlanıyor...');
    for (let i = 0; i < 45; i++) {
      try {
        const boot = execSync(`"${adbPath}" shell getprop sys.boot_completed`, {
          encoding: 'utf-8',
          stdio: ['pipe', 'pipe', 'ignore']
        }).trim();
        if (boot === '1') {
          break;
        }
      } catch (e) {}
      await sleep(1500);
    }

    // Android servislerinin tamamen stabil hale gelmesi için kısa bir bekleme
    console.log('⏳ Servisler hazırlanıyor...');
    await sleep(4000);
    console.log('✅ Emülatör tamamen hazır!');
  } else {
    console.log('✅ Aktif Android emülatörü/cihazı algılandı.');
  }

  console.log('🔥 Flutter uygulaması çalıştırılıyor (Hot Reload aktif)...\n');

  const flutter = spawn('cmd.exe', ['/c', 'flutter', 'run'], {
    stdio: 'inherit'
  });

  flutter.on('exit', code => {
    process.exit(code || 0);
  });
}

main().catch(err => {
  console.error('Başlatma hatası:', err);
  process.exit(1);
});
