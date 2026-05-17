/// Backend API base URL.
///
/// • Android emulator → host machine:   http://10.0.2.2:8000
/// • iOS simulator    → host machine:   http://localhost:8000
/// • Physical device (same Wi-Fi)       http://<your-LAN-IP>:8000
/// • Production                          https://api.scorvo.ai
///
/// To find your LAN IP on Linux:   ip -4 addr show | grep inet
/// On macOS:                       ipconfig getifaddr en0
///
/// IMPORTANT: when running the backend for a physical device, start it with
/// `--host 0.0.0.0` (not 127.0.0.1), and make sure your laptop's firewall
/// allows inbound TCP 8000.
const String apiBaseUrl = 'http://192.168.1.11:8000';
