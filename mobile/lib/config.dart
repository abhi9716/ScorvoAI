/// Backend API base URL.
///
/// Production:                          https://scorvoai-production.up.railway.app
/// Android emulator → local backend:   http://10.0.2.2:8000
/// iOS simulator    → local backend:   http://localhost:8000
/// Physical device on Wi-Fi → laptop:  http://<your-LAN-IP>:8000
///
/// To find your LAN IP on Linux:   ip -4 addr show | grep inet
/// On macOS:                       ipconfig getifaddr en0
///
/// For local backend on a physical device, start with --host 0.0.0.0
/// (not 127.0.0.1) and open TCP 8000 in your firewall.
const String apiBaseUrl = 'https://scorvoai-production.up.railway.app';
